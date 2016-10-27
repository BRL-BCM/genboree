#!/usr/bin/env ruby
require 'uri'
require 'cgi'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
include BRL::Genboree::REST

module BRL ; module Genboree; module Tools

  class ChromHMMLearnModelWrapper < ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description => "Wrapper to run ChromHMM LearnModel tool",
      :authors      => [ "Tim Charnecki (charneck@bcm.edu), Neethu Shah (neethus@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} --jsonFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode

    # Set variables and set up the job
    def processJobConf()
      begin
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        @numCores = ENV['GB_NUM_CORES']
        @dbrcKey = @context['apiDbrcKey']
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
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
        
        ##Checking db and proj irrespective of their order
        if(@outputs.first !~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
          prjDb = @outputs.first
          outputDb = @outputs.last
        else
          outputDb = @outputs.first
          prjDb = @outputs.last
        end
        
       @targetdbUri = outputDb
       @targetprjUri = prjDb
       @projectName = @prjApiHelper.extractName(prjDb)
       @targetGroupName = @grpApiHelper.extractName(@outputs.first)
       @targetDbName = @dbApiHelper.extractName(outputDb)

        ## LearnModel Required Parameters
        @analysisName = @settings['analysisName']
        @assembly = @settings['assembly']
        @numStates = @settings['numStates']

        ## LearnModel Optional Parameters
        @binsize = @settings['binsize'] #default [200]
        @convergedelta = @settings['convergedelta'] #default [0.001]
        @init = @settings['init'] # values are "information|random|load". Default [information]
        @maxiterations = @settings['maxiterations']# Default [200] 
        @stateordering = @settings['stateordering']# Values are  emission|transition. Default [emission]

        ## Optional conditional parameters
        ## Associated with "load"(init) option only 
        @loadsmoothemission = @settings['loadsmoothemission'] #default [0.02]
        @loadsmoothtransition = @settings['loadsmoothtransition'] #default [0.5]
      
        ## Associated with "information"
        @informationsmooth = @settings['informationsmooth'] # deafault [0.02]

        @inputLocal = @settings['inputLocal'] if(@settings.key?('inputLocal'))
        @suppressEmail  = @settings['suppressEmail'] if(@settings.key?('suppressEmail'))

      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    def run()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running Driver .....")
        exitStatus = EXIT_OK
        @errMsg = ""
        @escAnalysisName = CGI.escape(@analysisName)
        @outputResultsDir = "#{@scratchDir}/results" 
        @transformBedDir = "#{@scratchDir}/transformedBedfiles"
        system("mkdir -p #{@outputResultsDir}")
        system("mkdir -p #{@transformBedDir}")
        #Download data
        
        if(@inputLocal)
          @inputDir = Array.new()
          @inputs.each{|inp|
            if(inp =~ /model/)
              @modelFile = inp
            else
              @inputDir << inp
            end
          }
        else
          @inputDir = "#{@scratchDir}/inputDir"
          system("mkdir -p #{@inputDir}")
          downloadFiles()
        end
        # Run chromHMM LearnModel
        # Separate options set with Parameter Initialization Methods ("load", "information" and "random")
        runChromHMMLearnModel()
       
        # Reformats the chromHMM LearnModel output bed files.
        # Transformed bed files have "-/+" in the 6th column,
        # which is missing in the original LearnModel ouput bedfiles
        #transformBed()
        
        #@trackNames = Array.new()
        # Converts the transformed bed files to lff
        #transformedBedToLff()

        # Upload the lff files
        #Dir.entries(@scratchDir).each{ |file|
        #next if(file == "." or file == "..")
        #upLoadLFF(file) if (file =~ /\.lff/)
        #}
        
        #Creates job configuration file for bigbed generator
        # For all the tracknames captures in "transformedBedToLff" method.
        #@trackNames.each{ |trkName|
          #createBigFilesJobConf(trkName)
          #callBigFilesWrapper()
        #}
        
        # Upload Results to the target database under "ChromHMM-LearnModel-Results" dir.
        transferFiles()
        
        #Compress files to be send to "projects" directory in the host server
        @tmpDir = "chromHMMLearnModel_#{Time.now.to_f}_#{rand(10_000)}"
        Dir.chdir(@outputResultsDir)
        zipCmd = "zip -r #{@tmpDir}.zip * > #{@scratchDir}/zip.out"
        $stderr.debugPuts(__FILE__, __method__, "COMMAND", "Zip ChromHMM results dir with this command:\n    #{zipCmd}")
        system(zipCmd)
       
        # Transfer compressed output files to "projects" directory in the host server 
        uriObj = URI.parse(@targetprjUri)
        apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path}/additionalPages/file/#{@tmpDir}/#{@tmpDir}.zip?extract=true", @userId)
        apiCaller.put({}, File.open("#{@tmpDir}.zip"))
         if(!apiCaller.succeeded?)
          @errUserMsg = "Failed to transfer result files to the projects directory: #{@tmpDir}"
          raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
         end
        
        # Adding links to the project page
        addLinks()
      
        # Clean up the results folder and other intermediate files
        `rm -rf #{@outputResultsDir} #{@transformBedDir}` 
      rescue => err
        @errMsg = err.message
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 121
      ensure
        @exitCode = exitStatus
        $stderr.debugPuts(__FILE__, __method__, "Status", "ChromHMM run completed with #{exitStatus}")
        return exitStatus
      end
    end

    def downloadFiles()
        @inputs.each { |input|
        fileBase = @fileApiHelper.extractName(input)
        ## if @init == load, then the model file has to be present as
        ## one ot the input files.
        ## The "load" loads parameters specified in the model file
        if (fileBase =~ /model/)
          puts "Model file located and downloading model file"
          @modelFile = "#{@scratchDir}/#{CGI.escape(fileBase)}"
          tmpFile = @modelFile
        else
          tmpFile = "#{@inputDir}/#{CGI.escape(fileBase)}"
        end
        ww = File.open(tmpFile, "w")
        inputUri = URI.parse(input)
        rsrcPath = "#{inputUri.path}/data?"
        rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(input)}" if(@dbApiHelper.extractGbKey(input))
        apiCaller = WrapperApiCaller.new(inputUri.host, rsrcPath, @userId)
        apiCaller.get() { |chunk| ww.print(chunk) }
        ww.close()
        if(!apiCaller.succeeded?)
          @errUserMsg = "Failed to download file: #{fileBase} from server"
          raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
        end
        exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
        exp.extract()
        }
    end
    
    # Run chromHMMLearnModel commands
    def runChromHMMLearnModel()
        @outFile = "./chromHMMLearnModel.out"
        @errFile = "./chromHMMLearnModel.err"
        # ChromHMM is the module installation
        # Mem for java is set to 8000m
        # No optional settings for "random" mode.
        command = "ChromHMM LearnModel -p #{@numCores} -b #{@binsize} -d #{@convergedelta} -init #{@init} -r #{@maxiterations} -stateordering #{@stateordering}"
        if(@init =~/information/)
          command << " -h #{@informationsmooth}"
        elsif(@init =~ /load/)
          unless(@modelFile)
            @errUserMsg = "Option \"load\" is on. Failed to locate model file\n"
            raise @errUserMsg  
          end
          command << " -m #{@modelFile} -e #{@loadsmoothemission} -t #{@loadsmoothtransition}"
        end
        # Required params
        command << " #{@inputDir} "
        command << " #{@outputResultsDir} "
        command << " #{@numStates} "
        command << " #{@assembly} "
 
        # Run the command 
        command << " > #{@outFile} 2> #{@errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
        exitStatus = system(command)
        if(!exitStatus) 
          @errUserMsg = "ChromHMM - LearnModel failed to run"
          raise "Command: #{command} died. Check #{@outFile} and #{@errFile} for more information."
        end
    end

    # Bed inputs from chromHMM LearnModel has "." instead of "+/-" in 
    # the 6th column. To upload these bed files as tracks
    # changing the column values of both "xxx_dense.bed" and 
    # "xxx_expanded.bed".
    def transformBed()
      Dir.entries(@outputResultsDir).each{ |file|
        ## Transforming dense and expanded bed files
        if(file =~ /dense\.bed/ or file =~ /expanded\.bed/)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Transforming bed file: #{@outputResultsDir}/#{file}")
          fileName = File.basename(file)
          inbed = File.open( "#{@outputResultsDir}/#{file}","r")
          outbed = File.open("#{@transformBedDir}/#{fileName}","w")
          inbed.each_line { |line|
          next if(line.nil? or line.empty?)
          if(line =~ /^\s*$/ or line =~ /^#/ or line =~ /^track/ or line =~ /^browser/)
          #if(!line.start_with?("chr"))
            outbed.puts(line)
          else
            lineSplit = line.split("\t")
            if(lineSplit[1].to_i < lineSplit[2].to_i)
              lineSplit[5] = "+"
            else
              lineSplit[5] = "-"
            end
            newLine = lineSplit.flatten.join("\t")
            outbed.puts(newLine)
          end
          }
        end
    }
    end

    def transformedBedToLff()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Converting bed to lff...\n")
      @className = CGI.escape("BedClass")
      @coordSystem = 0
      @lffOut = "./bed2lff.out"
      @lffErr = "./bed2lff.err"
      Dir.entries(@transformBedDir).each {|entry|
        next if(entry == "." or entry == "..")
        if(entry =~ /dense\.bed/)
          @lffType = entry.split("_dense.bed").first
          @lffSubType = "Dense"
        elsif(entry =~ /expanded\.bed/)
          @lffType = entry.split("_expanded.bed").first
          @lffSubType = "Expanded"
        else
          @errUserMsg = "Cannot find transformed bed files.\n"
          raise "Failed to find transformed bedfiles............\n"
        end
        @trackNames << CGI.escape("#{@lffType}:#{@lffSubType}")
        inBedFile = "#{@transformBedDir}/#{entry}"
        outLffFile = "#{@scratchDir}/"
        outLffFile << File.basename(entry).chomp(".bed") << ".lff" 
        command = "bed2lff.rb -i #{inBedFile} -o #{outLffFile} -c #{@className} -t #{@lffType} --coordSystem #{@coordSystem} -u #{@lffSubType}"
        command << " > #{@lffOut} 2> #{@lffErr}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command.inspect}\n")
        exitStatus = system(command)
        if(!exitStatus)
          @errUserMsg = "Converting your BED file (#{File.basename(entry).inspect}) to LFF failed.\nTypically because it is not actually a BED file. Error message:\n\n#{File.read(@lffOut)}"
          raise "Sub-process failed with exit code : #{command}\n\nCheck #{@lffOut} and #{@lffErr} for more information."
        end 
      }
    end

    def upLoadLFF(lffFileName)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading lff file: #{lffFileName}\n")
      outputUri = URI.parse(@targetdbUri)
      rsrcUri = outputUri.path
      rsrcUri << "?gbKey=#{@dbApiHelper.extractGbKey(@targetdbUri)}" if(@dbApiHelper.extractGbKey(@targetdbUri))
      apiCaller = WrapperApiCaller.new(outputUri.host, rsrcUri, @userId)
      apiCaller.get()
      if (apiCaller.succeeded?)
        refSeqId = JSON.parse(apiCaller.respBody)['data']['refSeqId']
        uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
        uploadAnnosObj.refSeqId = refSeqId
        uploadAnnosObj.groupName = @targetGroupName
        uploadAnnosObj.userId = @userId
        uploadAnnosObj.outputs = [@targetdbUri]
        uploadAnnosObj.jobId = @jobId 
        begin
          uploadAnnosObj.uploadLff(CGI.escape(File.expand_path("#{@scratchDir}/#{lffFileName}")), false)
          # For multiplte lff uploads, gzip asks to overwrite uniqTrks.txt.gz file and hence stalls
          # So removing it after each upload
          system('rm *.gz')
        rescue => uploadErr
          $stderr.puts "Error: #{uploadErr}"
          $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
          @errUsrMsg = "FATAL ERROR: Could not upload result lff file to target database."
          if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
            @errUsrMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
          end
          raise @errUsrMsg
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "Track Upload - ERROR", @apiCaller.respBody.inspect)
        @errUsrMsg = "Could not obtain refSeqId for #{@targetdbUri}"
        raise @errUsrMsg
      end
    end 
    
    ## creates respective {type}JobFile.json for each trackName
    ## @param [String] trkName for which the bigbed is to be generated
    def createBigFilesJobConf(trkName)
      @bigFilesJobConf = @jobConf.deep_clone()
      @outputUri = URI.parse(@targetdbUri)
      @outputUri.path = "#{@outputUri.path}/trk/#{trkName}"
      @bedTrack = @outputUri.to_s
      ## Define inputs
      @bigFilesJobConf['inputs'] = [@bedTrack]
      ## Define settings 
      @bigFilesJobConf['settings']['type'] = "bigbed"
      @bigFilesJobConf['settings']['suppressEmail'] = "true"
      ## Define context
      @bigFilesJobConf['context']['toolIdStr'] = "bigFiles"
      @bigFilesScratchDir = "#{@scratchDir}/sub/bigFiles"
      @bigFilesJobConf['context']['scratchDir'] = @bigFilesScratchDir
      ## Define outputs
      @bigFilesJobConf['outputs'] = [ ]
      ## Create job specific scratch and results directories
      `mkdir -p #{@bigFilesScratchDir}`
      ## Write jobConf hash to tool specific jobFile.json
      track = CGI.unescape(trkName).gsub(":","") 
      @bigFilesJobFile = "#{@bigFilesScratchDir}/#{track}JobFile.json"
       $stderr.debugPuts(__FILE__, __method__, "STATUS", "Creating jobfile for the track #{trkName}\n")
      File.open(@bigFilesJobFile,"w") { |bigFilesJob|
        bigFilesJob.write(JSON.pretty_generate(@bigFilesJobConf))
      }
    end
         
    def callBigFilesWrapper()
      command = "bigFilesWrapper.rb -j #{@bigFilesJobFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Generating bigbed .... \n")
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      if(!exitStatus)
        @errUserMsg = "Could not run BigWig BigFiles Wrapper"
        raise "Command: #{command} died. Check #{@errFile} for more information. "
      end
    end

    ## Transfers files to the target databae under ChromHMM-LearnModel-Results dir
    def transferFiles()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Transferring files to the database...\n")
      @outputDbFiles = Array.new()
      Dir.entries(@outputResultsDir).each {|entry|
        if(entry =~ /\.txt/ or entry =~ /\.bed/)
          @outputDbFiles.push(entry)
          rsrcNew = @dbApiHelper.extractPath(@targetdbUri)
          rsrcNew << "/file/ChromHMM%20-%20LearnModel%20-%20Results/#{@analysisName}/#{entry}/data?"
          apiCaller = WrapperApiCaller.new(@dbApiHelper.extractHost(@targetdbUri), rsrcNew, @userId)
          fileObj = File.open("#{@outputResultsDir}/#{entry}")
          apiCaller.put(fileObj)
          fileObj.close unless(fileObj.closed?)
          if(!apiCaller.succeeded?)
            @errUserMsg = "Failed to transfer file: #{entry}"
            raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
          end
        end
        }
    end
   
    def addLinks()
      # First get the existing news items
      # "webpage_#{@numStates}.html" is the output of chromHMMLearnModel and it contain links to all the results
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
                              "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a ChromHMM LearnModel job and the report is available at the link below.
                              <ul>
                                <li><b>Analysis Name</b>: #{@analysisName}</li>
                                <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@tmpDir)}/webpage_#{@numStates}.html\">Link to ChromHMMLearnModel results</a></li>
                              </ul>"
                            }
                          )
        payload = {"data" => existingItems}
      else
        newItems = [
                      {
                        'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
                        "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a ChromHMM LearnModeljob and the report is available at the link below.
                        <ul>
                          <li><b>Analysis Name</b>: #{@analysisName}</li>
                          <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@tmpDir)}/webpage_#{@numStates}.html\">Link to ChromHMMLearnModel results</a></li>
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

    # . Prepare successmail
    def prepSuccessEmail()
      if(@suppressEmail or @inputLocal)
        successEmailObject = nil
      else
        unless(@inputs.size > 1)
	        inputInfo = {
	          "File" => File.basename(@fileApiHelper.extractName(@inputs.first))
          }
        else
          inputInfo = {}
            filecount = 1
            @inputs.each { |input|
	            inputInfo["File#{filecount}"] = File.basename(@fileApiHelper.extractName(input))
              filecount += 1
            }
        end
        additionalInfo = ""
        additionalInfo << "  Database: '#{@targetDbName}'\n  Group: '#{@targetGroupName}'\n Project: '#{@projectName}'\n\n" +
                        "You can download result files from the '#{@analysisName}' folder under the 'ChromHMM - LearnModel- Results' directory.\n\n\n"

        resultFileLocations  = <<-EOS
        Host: #{@dbApiHelper.extractHost(@outputs.first)}
          Grp: #{@grpApiHelper.extractName(@outputs.first)}
            Db: #{@dbApiHelper.extractName(@outputs.first)}
              Files Area:
                * ChromHMM - LearnModel - Results/
                  * #{@settings['analysisName']}/
        EOS
         @outputDbFiles.each { |file|
          resultFileLocations << "   \t\t  * #{File.basename(file).chomp('?')}"
          resultFileLocations << "\n"
        }

        if(@init =~ /information/)
          settingsToEmail = ["binsize", "convergedelta", "init", "maxiterations", "stateordering", "informationsmooth", "numStates", "assembly"]
        elsif(@init =~ /load/)
	        settingsToEmail = ["binsize", "convergedelta", "init", "maxiterations", "stateordering", "loadsmoothemission", "loadsmoothtransition", "numStates", "assembly"] 
        end
        settings = {}
        settingsToEmail.each { |kk|
          settings[kk] = @settings[kk]
        }
        successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, @analysisName, inputInfo, outputsText="n/a", settings, additionalInfo, resultFileLocations, resultFileURLs=nil, @shortToolTitle)
        projHost = URI.parse(@targetprjUri).host
        successEmailObject.resultFileLocations << "http://#{projHost}/java-bin/project.jsp?projectName=#{CGI.escape(@prjApiHelper.extractName(@targetprjUri))}"
      end
      return successEmailObject
    end
    
    def prepErrorEmail()
      additionalInfo = @errUserMsg
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      if(@suppressEmail)
        errorEmailObject = nil
      end
      return errorEmailObject
    end

  end
end ; end; end; # module BRL ; module Script

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
puts __FILE__
if($0 and File.exist?($0) )
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::ChromHMMLearnModelWrapper)
end
