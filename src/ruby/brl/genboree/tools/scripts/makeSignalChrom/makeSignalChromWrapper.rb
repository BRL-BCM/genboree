#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class MakeSignalChromWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the pipeline (provided by BCGSC) that generates signal files for chromHMM based analysis.\n Signal files are genome wide vectors with coverage calculated within a specific window size (bin size - row) for each mark (column).",
      :authors      => [ "Neethu Shah (neethus@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode

    # Extract the relevant information to run the job
    # [+returns+] nil
    def processJobConf()
      begin
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        @dbrcKey = @context['apiDbrcKey']
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        ## Genboree specific "context" variables
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        @toolIdStr = @context['toolIdStr']  
        #settings
        @analysisName = @settings['analysisName']     
        #@bin = @settings['binSize']
        #@step = @settings['step']
        @trkAttributes = @settings['trkAttributes']
        @states = @settings['states']
        @numCores = ENV['GB_NUM_CORES'] 
        @mapFilePath = @genbConf.clusterFindERChromHMMAnnoDir
        ##Checking db and proj irrespective of their order
        if(@outputs.first !~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
          outputPrj = @outputs.first
          outputDb = @outputs.last
        else
          outputDb = @outputs.first
          outputPrj = @outputs.last
        end
        @targetUri = outputDb
        @targetprjUri = outputPrj
        @projectName = @prjApiHelper.extractName(outputPrj)

        #Clean up settings for the email Content to look cleaner
        @settings.delete('trkAttributes')
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = "ERROR: Could not set up required variables for running job. Check your jobFile.json to make sure all variables are defined."
        @err = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # [+returns+] nil
    def run()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Wrapper Started ....")
        @errUserMsg = ""
        @makeprojectLink = true
        @fileCounter = Hash.new { |hh,kk| hh[kk] = 0 }
        @trackinputs = {}
        @inputs.each { |trackinput| 
          @trackinputs[trackinput.chomp('?')] = "" 
        }
        @trackNames = {}
        #1. Download wig file from each track uri
        getWig(@inputs)
    
        #2. Get the wig config files ready
        # BCGSC wrapper takes in each sample (chromHMMCell) as a separate config file.
        # Number of wig config files = Number of samples
        # # This is the input for FindERChromHMM.Generate "-wigs:" option
        @wigConfDir = "#{@scratchDir}/wigConfig"
        system("mkdir -p #{@wigConfDir}")
        @mainOutputDir = "#{@scratchDir}/ChromHMMOut"
        system("mkdir -p #{@mainOutputDir}")
        @findERDir = "#{@mainOutputDir}/FindER"
        system("mkdir -p #{@findERDir}")
        makeWigConfigFiles()

        #3. Get the tool config file
        # This is the input for FindERChromHMM.Generate "-tools:" option
        makeToolConfig() 

        #4. run FindERChromHMM
        runFindERChromHMM()
        
        #5. Upload result files to the target database
        uploadData()
   
        #6a. Preparation for setting project page
        # ChromHMM LearnModel Outputs are exposed via the project page
        @tmpDir = "FindERChromHMM_#{Time.now.to_f}_#{rand(10_000)}"
        #ChromHMM LearnModel Outputs are here
        Dir.chdir("#{@mainOutputDir}/ChromHMM")
        zipCmd = "zip -r #{@tmpDir}.zip * > #{@scratchDir}/zip.out"
        $stderr.debugPuts(__FILE__, __method__, "COMMAND", "Zip ChromHMM results dir with this command:\n    #{zipCmd}")

        #Check whether the directory is empty
        chromresults = ["./*"]
        unless(chromresults.empty?)
          system(zipCmd)
        else
          @makeprojectLink = false
        end
        
        if(@makeprojectLink)
          #6b. Transfer compressed output files to "projects" directory in the host server 
          uriObj = URI.parse(@targetprjUri)
          apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path}/additionalPages/file/#{@tmpDir}/#{@tmpDir}.zip?extract=true", @userId)
          $stderr.debugPuts(__FILE__, __method__, "COMMAND", "Transfering files to the project page: #{uriObj.path}/additionalPages/file/#{@tmpDir}/#{@tmpDir}.zip?extract=true ")
          apiCaller.put({}, File.open("#{@tmpDir}.zip"))
          if(!apiCaller.succeeded?)
            @errUserMsg = "Failed to transfer result files to the projects directory: #{@tmpDir}"
            raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
          end

          #6c. Adding links to the project page
          addLinks()
        end

        #7 Remove all the result and input wig files
        removeResultFiles()
         
      rescue => err
        @errUserMsg = err.message
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        @exitCode = 30
      ensure
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Ensuring that the downloaded and intermediate files are compressed before exiting...")
        # Compress the output files if the job fails.
        `tar cvzf mainOutputDir.tar.gz #{@mainOutputDir}/*`
        `rm -rf #{@mainOutputDir}`
        `tar cvzf wigFiles.tar.gz #{@wigDir}/*`
        `rm -rf #{@wigDir}`
      end
      return @exitCode
    end
   

    def getWig(trkUris)
      @wigDir = "#{@scratchDir}/wigFiles"
      system("mkdir -p #{@wigDir}")
      trkUris.each { |trkUri|
         host, rsrcUri, fileName = makeRsrcUriAndFileName(trkUri, "fwig", "wig")
         downloadWigData(host, rsrcUri, fileName)
      }
    end
    
    def makeRsrcUriAndFileName(uri, trkFormat, trkFileExt)
      host = @trkApiHelper.extractHost(uri)
      rsrcName = @trkApiHelper.extractName(uri)
      rsrcUri = "#{@trkApiHelper.extractPath(uri)}/annos?format=#{trkFormat}&spanAggFunction=avg"
      rsrcUri << "&gbKey=#{@dbApiHelper.extractGbKey(uri)}" if(@dbApiHelper.extractGbKey(uri))
      # Make file name we can use for downloading data
      fileNameBase = CGI.escape(rsrcName).gsub(/(?:%[a-fA-F0-9]{2,2})+/, "_")
      # Use @fileCounter if more than one track with same name (different DBs etc)
      fileCounterStr = (@fileCounter[fileNameBase] == 0 ? '' : ".#{@fileCounter[fileNameBase]}")
      @fileCounter[fileNameBase] += 1
      fileName = "#{fileNameBase}#{fileCounterStr}.#{trkFileExt}"
      @trackNames[uri.chomp('?')] = fileName
      return host, rsrcUri, fileName
    end


    def downloadWigData(host, rsrcUri, fileName)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading data to #{File.basename(fileName)}")
      begin
        writer = File.open("#{@wigDir}/#{fileName}", "w+")
        apiCaller = WrapperApiCaller.new(host, rsrcUri, @userId)
        # Get raw data from API call.
        apiCaller.get() { |chunk|
          writer.print(chunk)
        }
        writer.close()
        unless(apiCaller.succeeded?)
          raise "ERROR: API download of track annos #{rsrcUri.inspect} failed. Returned #{apiCaller.httpResponse.inspect}. Internal error state: #{apiCaller.error.inspect}\n#{apiCaller.error.respond_to?(:backtrace) ? apiCaller.error.backtrace.join("\n") : ""}\n\n"
        end
      rescue => err
        @err = err
        @errInternalMsg = err.message
        @errUserMsg = "ERROR: failure during API download of track annos #{rsrcUri.inspect}"
        raise err
      ensure
        if(writer and !writer.closed?)
          writer.close() rescue nil
        end
      end
    end

    #Makes the Wig config files for each sample (alias chromHMmCell).
    # These config files are input to FindERChromHMM.Generate through the "-wigs:" option
    def makeWigConfigFiles()
      begin
        @trkAttributes.each_key {|sample| 
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Making Config file for the sample, #{sample}.")
          ff = File.open("#{@wigConfDir}/#{sample}Wig.config","w")
          ff.puts("sample=#{sample}")  
          ff.puts("out=#{File.expand_path(@findERDir)}") 
          control = 0
          @trkAttributes[sample].each_key{ |trk|
            if(@trackinputs.key?(trk)) # if present only in the input
              if(@trkAttributes[sample][trk]['chromHMMControl'] == 'yes')
                control += 1
                # Only one control per sample allowed. Double checking. Is handled by the rulesHelper actually.
                ff.puts("#{@trkAttributes[sample][trk]['chromHMMMark']}:control=#{File.expand_path(@wigDir)}/#{@trackNames[trk.chomp('?')]}") if(control==1)
              else
                ff.puts("#{@trkAttributes[sample][trk]['chromHMMMark']}=#{File.expand_path(@wigDir)}/#{@trackNames[trk.chomp('?')]}")
              end
            end
          } 
          ff.close()
        }
       rescue => err
        @err = err
        @errInternalMsg = err.message
        @errUserMsg = "ERROR: failure in making wig configuration files"
        raise err
      end
    end
   
    def getChrLengthFile()
      @chromosomeLengthFile = "#{@scratchDir}/chrom.sizes"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading entrypoints...")
      dbUri = URI.parse(@dbApiHelper.extractPureUri(@targetUri))
      host = dbUri.host
      rsrcPath = dbUri.path
      tmpPath = "#{rsrcPath}/eps?"
      apiCaller = WrapperApiCaller.new(host, tmpPath, @userId)
      httpResp = apiCaller.get()
      if(apiCaller.succeeded?)
        refFileWriter = File.open(@chromosomeLengthFile, "w")
        apiCaller.parseRespBody['data']['entrypoints'].each { |rec|
          # need only chr1-22, X, Y
          refFileWriter.puts "#{rec['name']}\t#{rec['length']}" if(rec['name'] =~ /chr([0-9]+$|X|Y)/)
        }
        refFileWriter.close()
      else
        @errUserMsg = "ERROR: API download of entrypoints #{dbUri.inspect} failed. Returned #{httpResp.inspect}. Response payload:\n\n#{apiCaller.respBody}\n\n"
        raise @errUserMsg
      end
    end

    def makeToolConfig()
      # Full path of three jar files to be passed to FindERChromHMM.Generate via the tool config file 
      # To be loaded via the respective modules
      @toolConf = "#{@scratchDir}/tools.config"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Creating tool config file")
      begin
        ff = File.open(@toolConf, "w")
        ff.puts("findER=#{`which FindER.0.9.1.jar`}")
        ff.puts("ChromHMM.jar=#{`which ChromHMM.jar`}")
        ff.puts("genomeCoverageFromBed=#{`which RegionsCoverageFromBEDCalculator.jar`}")
        ff.puts("findERMem=-Xmx60G")
        ff.puts("ChromHMMMem=-Xmx30G")
        ff.puts("genomeCoverageMem=-Xmx60G")
        ff.puts("nChromHMMStates=#{@states}")
        ff.puts("ChromHMMOut=#{@mainOutputDir}/ChromHMM")
        ff.puts("ChromHMMthreads=#{@numCores}")
        getChrLengthFile() 
        ff.puts("chroms=#{@chromosomeLengthFile}")
        # loaded from genbConf
        ff.puts("map=#{@mapFilePath}/mappability_lt_1")
        ff.puts("findERThreshold=1.0")
        ff.close()
      rescue => err
        @err = err
        @errInternalMsg = err.message
        @errUserMsg = "ERROR: failure in making tool configuration files"
        raise err
      end
    end

    # runs the main wrapper FindERChromHMM
    def runFindERChromHMM()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Preparing to run FindERChromHMM....")
      @findEROut = "#{@scratchDir}/FindERChromHMM.err"
      wigs = Dir[File.expand_path("#{@wigConfDir}/*")]
      # loaded from the module makeSignalChrom/1.2
      command = "FindERChromHMM -tools:#{@scratchDir}/tools.config -wigs:#{wigs.join(",")} 2>#{@findEROut}"
       $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
        exitStatus = system(command)
        if(!exitStatus)
          @errUserMsg = "Command: #{command} failed."
          raise "Command: #{command} died. Check #{@findEROut} for more information"
        end
    end
  
    def uploadData()
      # Compress ChromHMM results tree
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Preparing to run Upload Files to the target database, #{@dbApiHelper.extractHost(@targetUri)}")
        @archiveName = "FindERChromHMM.tar.gz"
        Dir.chdir(@mainOutputDir)
        # Zip only the findER and Signal(binary) files. ChromHMM result files are transeferred to the projects directory.
        # Not all files are transferred in this version.
        # Empty log files fails the process job files
        zipCmd = "tar cvzf #{@archiveName} FindER/FindER*/* FindER/ChromHMM*/Signal > tar.out"
        $stderr.debugPuts(__FILE__, __method__, "COMMAND", "Zip Signal results dir with this command:\n    #{zipCmd}")
        system(zipCmd)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Upload results to target Genboree database...")
        rcscNew = @dbApiHelper.extractPath(@targetUri)
        rcscNew << "/file/FindERChromHMM%20-%20Results/#{@analysisName}/FindERChromHMM.tar.gz/data?extract=true"
        apiCaller = WrapperApiCaller.new(@dbApiHelper.extractHost(@targetUri), rcscNew, @userId)
        fileObj = File.open("#{@archiveName}")
        apiCaller.put(fileObj)
        fileObj.close unless(fileObj.closed?)
        if(!apiCaller.succeeded?)
          @errUserMsg = "Apicaller Failed.\n Failed to upload data to the target database."
          raise "ERROR: could not upload Zip archive of results to output database. Tried to upload #{File.basename(@archiveName) unless(fileObj.nil?)} using this resource path: #{rcscNew.inspect}."
        end
      rescue => err
        @err = err
        @errInternalMsg = err.message
        @errUserMsg = "ERROR: failure in uploading result files to the target database."
      end
    end

    def addLinks()
      # First get the existing news items
      # This page is directly linked here
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adding links to project page...")
      uri = URI.parse(@targetprjUri)
      @host = uri.host
      rcscUri = uri.path
      rcscUri = rcscUri.chomp("?")
      rcscUri = "#{rcscUri}/news?"
      rcscUri << "gbKey=#{@dbApiHelper.extractGbKey(@targetprjUri)}" if(@dbApiHelper.extractGbKey(@targetprjUri))
      apiCaller = WrapperApiCaller.new(@host, rcscUri, @userId)
      apiCaller.get()
      if(!apiCaller.succeeded?)
       @errUserMsg = "Failed ApiCaller 'get' news\n"
       raise "ApiCaller 'get' news Failed:\n #{apiCaller.respBody.inspect}"
      end
      existingNews = apiCaller.parseRespBody
      existingItems = existingNews['data']
      payload = nil
      if(!existingItems.empty?)
        existingItems.push(
                            {
                              'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
                              "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a FindERChromHMM job and the report is available at the link below.
                              <ul>
                                <li><b>Analysis Name</b>: #{@analysisName}</li>
                                <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@tmpDir)}/webpage_#{@states}.html\">Link to FindERChromHMMtool job results</a></li>
                              </ul>"
                            }
                          )
        payload = {"data" => existingItems}
      else
        newItems = [
                      {
                        'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
                        "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a FindERChromHMMtool job and the report is available at the link below.
                        <ul>
                          <li><b>Analysis Name</b>: #{@analysisName}</li>
                          <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@tmpDir)}/webpage_#{@states}.html\">Link to FindERChromHMMtool job results</a></li>
                        </ul>"
                      }

                  ]
        payload = {"data" => newItems}
      end
      apiCaller = WrapperApiCaller.new(@host, rcscUri, @userId)
      apiCaller.put(payload.to_json)
      if(!apiCaller.succeeded?)
       @errUserMsg = "Failed ApiCaller 'put' news\n"
       raise "ApiCaller 'put' news Failed:\n #{apiCaller.respBody.inspect}"
      end
    end
   
    def removeResultFiles()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing result files and other intermediate files ...")
      #copy the log files out before removing
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Copying log files prior to removing the FindER result files .....")
      `cp #{@findERDir}/FindER*/*.log #{@scratchDir}/`
      `rm -rf #{@mainOutputDir}`
      `rm -rf #{@wigDir}`
    end

    def prepSuccessEmail()
      emailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst = @userFirstName
      emailObject.userLast = @userLastName
      emailObject.analysisName  = @analysisName
      inputsText = buildSectionEmailSummary(@inputs)
      emailObject.inputsText = inputsText
      outputsText = buildSectionEmailSummary(@outputs)
      emailObject.outputsText = outputsText
      emailObject.settings = @jobConf['settings']
      additionalInfo = ""
      additionalInfo << "FindERChromHMM tool was run for the following sample(s)\n"
      @trkAttributes.each_key{ |sample|
        additionalInfo << "  #{sample}\n"
        @trkAttributes[sample].each_key {|trk|
          additionalInfo << "        #{@trkApiHelper.extractName(trk)}\n"
        }
        additionalInfo << "################################################################\n\n"
      }
      chromHMMresults = ""
      chromHMMresults << "ChromHMM results can be found at the following link" 
      additionalInfo << "FindERChromHMM pipeline ran only the FindER step. ChromHMM LearnModel step was skipped...." if(!@makeprojectLink)
      emailObject.additionalInfo = additionalInfo
      #Make project link 
      projHost = URI.parse(@targetprjUri).host
      emailObject.resultFileLocations = "http://#{projHost}/java-bin/project.jsp?projectName=#{CGI.escape(@prjApiHelper.extractName(@targetprjUri))}" 
      emailObject.exitStatusCode = @exitCode
      return emailObject
    end
  
    def prepErrorEmail()
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      errorEmailObject.userFirst = @userFirstName
      errorEmailObject.userLast = @userLastName
      errorEmailObject.analysisName = @analysisName
      inputsText = buildSectionEmailSummary(@inputs)
      errorEmailObject.inputsText = inputsText
      outputsText = buildSectionEmailSummary(@outputs)
      errorEmailObject.outputsText = outputsText
      errorEmailObject.errMessage = @errUserMsg
      errorEmailObject.exitStatusCode = @exitCode
      return errorEmailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::MakeSignalChromWrapper)
end
