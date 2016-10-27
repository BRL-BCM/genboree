#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/helpers/sniffer'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/abstract/resources/unlockedGroupResource'
require 'brl/genboree/genboreeUtil'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class CreateHubWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This wrapper creates  a new track hub in a Genboree group.
                        This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "Neethu Shah (neethus@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # [+returns+] nil
    def processJobConf()
      begin
        @targetUri = @outputs.first
        @dbrcKey = @context['apiDbrcKey']
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        @userId = @context['userId']
        @jobId = @context['jobId']
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        
        #Hub settings
        @hubName = @settings['hubName']
        @shortLabel = @settings['shortLabel']
        @longLabel = @settings['longLabel']
        @hubEmail = @settings['Email'] 
       
        @genBigFiles = @settings['genBigFiles']
        @genIndexFiles = @settings['genIndexFiles']
        @lockedDbs = @settings['lockedDbs']
        @privateDbs = @settings['privateDbs']
        @compressedTypes = @settings['compressedTypes']
        @trkTypeHash = {}
        if(@settings.key?('baseWidget'))
          baseWidget = @settings['baseWidget']
          #get the tracktypes from the widget selection
          @settings.keys.each{ |key|
            if(key =~ /#{baseWidget}/)
              trk = key.split("|")[1]
              @trkTypeHash[trk.chomp('?')] = @settings[key]
              @settings.delete(key)
            end
          }
       end
       @fileTypeHash = {}
       if(@settings.key?('fileHash'))
         @settings['fileHash'].each_key{ |file|
         @fileTypeHash[file.chomp('?')] = @settings['fileHash'][file]
         }
       end
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the application
    # [+returns+] nil
    def run()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running Driver .....")
        @exitCode = EXIT_OK
        @uploadedFiles = Array.new()
        # Check the compressed files - these escaped file sniffing in rules helper
        checkCompressedTypes() if(!@compressedTypes.empty?)

        
        # gets 'version', 'gbKey' ... and other attributes
        # from all the input pureDbUris - instead of making API request separately
        # populates @pureDbUri
        getAttrPureDburi()

        #1. Generate big files if any
        #Make the jobconfig files for bigwig and bigbed
        if(!@genBigFiles.empty?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Located bigwig or bigbeds to generate..............")
          createBigFilesJobConf("bigWig")
          createBigFilesJobConf("bigBed")
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "No bigwig or bigbeds to generate..............")
        end
  
        #2. Generate index files if any
        if(!@genIndexFiles.empty?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Generating BAM/VCF index files..............")
          createIndexfiles()
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "No index files to generate..............")
        end
        #3. Unlock/make gbKey public for all the elements in @lockedDbs 
        unless(@lockedDbs.empty?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Unlocking databases..............")
          payload = Array.new()
          @lockedDbs.each{ |dburi|
            puts dburi
            pay = {"public" => true, "url" => dburi}
            grpUri = @grpApiHelper.extractPureUri(dburi)
            grpObj = URI.parse(grpUri)
            apiCaller = WrapperApiCaller.new(grpObj.host, "#{grpObj.path}/unlockedResources", @userId)
            # make the gbKey "public"
            pay = {"public" => true, "url" => dburi}
            apiCaller.put({}, [pay].to_json)
            if(!apiCaller.succeeded?)
              @errUserMsg = "ApiCaller Failed to unlock database, #{@dbApiHelper.extractName(dburi)}. Check: #{apiCaller.respBody.inspect}"
              raise @errUserMsg
            else
              apiCaller.parseRespBody()
              if(apiCaller.apiStatusObj["statusCode"] != "OK")# StatusCode MUST be OK as dburi is either locked or unlocked, but gbKey is not public.
                  @errUserMsg = "ApiCaller Failed to unlock the database, #{@dbApiHelper.extractName(dburi)}. Check : #{apiCaller.apiStatusObj["msg"]}"
                  raise @errUserMsg
              else
                @pureDbUri[dburi]['gbKey'] = apiCaller.parseRespBody['data'][0]['key']
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Unlocked: #{dburi}")
              end
            end
          }
       end
       unless(@privateDbs.empty?) # make all the private dbs public
         $stderr.debugPuts(__FILE__, __method__, "STATUS", "Publishing databases..............")
         @privateDbs.each { |pureUri|
           dbObj = URI.parse(pureUri)
           apiCaller = WrapperApiCaller.new(dbObj.host, "#{dbObj.path}/attribute/public/value?", @userId)
           payload = {"text" => true}
           apiCaller.put({}, payload.to_json)
           if(!apiCaller.succeeded?)
             @errUserMsg = "ApiCaller Failed to make the database, #{@dbApiHelper.extractName(pureUri)} public. Check: #{apiCaller.respBody.inspect}"
             raise @errUserMsg
           else
             $stderr.debugPuts(__FILE__, __method__, "STATUS", "Published: #{@dbApiHelper.extractName(pureUri)}")
           end
          }
        end

        #4. create hub - make the payload json
        createhub()
      rescue => err
        @err = err
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        @errUserMsg = "Unknown Error" if(@errUserMsg.nil? or @errUserMsg.empty?)
        @exitCode = 30
      end
      return @exitCode
    end
    

    #Sniffs the compressed files, that are forwarded by the RulesHelper without any validation.
    def checkCompressedTypes()
      @compressedTypes.each { |compressedFile|
        fileBaseName = File.basename(@fileApiHelper.extractName(compressedFile))
        tmp = fileBaseName.makeSafeStr(:ultra)
        tmpFile = "#{@scratchDir}/#{CGI.escape(tmp)}"
        retVal = @fileApiHelper.downloadFile(compressedFile, @userId, tmpFile)
        if(!retVal)
          @errUserMsg = "Failed to download file: #{compressedFile} from server"
          raise "Failed to download file, #{fileBaseName}."
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Compressed file, #{fileBaseName} downloaded successfully to #{tmpFile}.")
          exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
          exp.extract()
          sniffer = BRL::Genboree::Helpers::Sniffer.new()
          decompFilePath = exp.uncompressedFileName
          sniffer.filePath = decompFilePath
          if(sniffer.detect?('bam'))
            dburi = @dbApiHelper.extractPureUri(compressedFile)
            compObj = URI.parse(dburi)
            newfile = File.basename(decompFilePath)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading the decompressed BAM file #{newfile} to #{dburi}/file/hubDecompressed/#{CGI.escape(newfile)}")
            apiCaller = WrapperApiCaller.new(compObj.host, "#{compObj.path}/file/hubDecompressed/#{CGI.escape(newfile)}/data?", @userId)
            apiCaller.put({}, File.open(decompFilePath))
            if(apiCaller.succeeded?)
              @genIndexFiles << "#{dburi}/file/hubDecompressed/#{CGI.escape(newfile)}?"
              @inputs.delete(compressedFile)#remove the compressed file
              @inputs << "#{dburi}/file/hubDecompressed/#{CGI.escape(newfile)}?"# Add the decompressed uploaded file uri to the inputs
              @fileTypeHash["#{dburi}/file/hubDecompressed/#{CGI.escape(newfile)}"] = 'bam'
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Compressed File Uri removed from inputs.")
            else
              @errUserMsg = "API failed to upload the decompressed file for #{fileBaseName}. Check: #{apiCaller.respBody.inspect}."
              raise @errUserMsg
            end
          elsif(sniffer.detect?('vcf-bgzipped'))
            dburi = @dbApiHelper.extractPureUri(compressedFile)
            compObj = URI.parse(dburi)
            newfile = File.basename(decompFilePath) 
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading the decompressed vcf-bgzipped file #{newfile} to #{dburi}/file/hubDecompressed/#{CGI.escape(newfile)}")
            apiCaller = WrapperApiCaller.new(compObj.host, "#{compObj.path}/file/hubDecompressed/#{CGI.escape(newfile)}/data?", @userId)
            apiCaller.put({}, File.open(decompFilePath)) 
            if(apiCaller.succeeded?) 
              @genIndexFiles << "#{dburi}/file/hubDecompressed/#{CGI.escape(newfile)}?" 
              @inputs.delete(compressedFile)#remove the compressed file 
              @inputs << "#{dburi}/file/hubDecompressed/#{CGI.escape(newfile)}?"# Add the decompressed uploaded file uri to the inputs
              @fileTypeHash["#{dburi}/file/hubDecompressed/#{CGI.escape(newfile)}"] = 'vcfTabix' 
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Compressed File Uri removed from inputs.")
            else 
              @errUserMsg = "API failed to upload the decompressed file for #{fileBaseName}. Check: #{apiCaller.respBody.inspect}."
              raise @errUserMsg
            end
          else
            @errUserMsg = "INVALID_FILE_FORMAT: The compressed input file, #{fileBaseName} is neither a BAM nor a bgzipped VCF file. Please check the input file format specifications to create hub and resubmit your job."            
            raise @errUserMsg
          end
        end
      }
    end


    # gets gbKey, version and other attributes for all pure input DbUris
    def getAttrPureDburi()
      @pureDbUri = {}
      @inputs.each { |inputUri|  
        pureUri = @dbApiHelper.extractPureUri(inputUri)
        unless(@pureDbUri.key?(pureUri))
          @pureDbUri[pureUri] = {}
          pureuriobj = URI.parse(pureUri)
          apiCaller = WrapperApiCaller.new(pureuriobj.host, pureuriobj.path, @userId)
          apiCaller.get() 
          if(!apiCaller.succeeded?)
            @errUserMsg = "ApiCaller failed a get request at #{pureUri}. Check: #{apiCaller.respBody.inspect}"
            raise @errUserMsg
          else 
            resp = apiCaller.parseRespBody['data']
            @pureDbUri[pureUri]['gbKey'] = resp['gbKey']
            @pureDbUri[pureUri]['version'] = resp['version']
            @pureDbUri[pureUri]['public'] = resp['public']
            @pureDbUri[pureUri]['species'] = resp['species']
            @pureDbUri[pureUri]['description'] = resp['description']

          end
        end
      } 
    end


    ## creates respective {type}JobFile.json file where
    ## type is either bigwig or bigbed.
    ## @param [String] type indicating which bigfile - bigwig/bigbed
    def createBigFilesJobConf(type)
      bigFilesJobConf = @jobConf.deep_clone()
      inputTrks = Hash.new {|hh, kk| hh[kk] = []}
      @genBigFiles.each{ |trk|
        if(@trkTypeHash[trk.chomp('?')] == type)
          dbUri = @dbApiHelper.extractPureUri(trk)
          inputTrks[dbUri] << trk
        end
      }
      # Now, create json file and run the tool job for each unique database
      jobCount = 0
      inputTrks.each_key{ |dburi|
        ## Define inputs
        bigFilesJobConf['inputs'] = inputTrks[dburi]
        ## Define settings 
        bigFilesJobConf['settings']['type'] = type.downcase()
        bigFilesJobConf['settings']['suppressEmail'] = "true"
        ## Define context
        bigFilesJobConf['context']['toolIdStr'] = "bigFiles"
        bigFilesScratchDir = "#{@scratchDir}/sub/bigFiles"
        bigFilesJobConf['context']['scratchDir'] = bigFilesScratchDir
        ## Define outputs
        bigFilesJobConf['outputs'] = []
        ## Create job specific scratch and results directories
        `mkdir -p #{bigFilesScratchDir}`
        ## Write jobConf hash to tool specific jobFile.json 
        @bigFilesJobFile = "#{bigFilesScratchDir}/#{type}#{jobCount}.json"
        jobCount += 1
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Making jobconf file for the #{type} tracks from the database #{CGI.escape(@dbApiHelper.extractName(dburi))}")
        File.open(@bigFilesJobFile,"w") { |bigFilesJob|
          bigFilesJob.write(JSON.pretty_generate(bigFilesJobConf))
        }       
        callBigFilesWrapper()
      }
    end

    
    def callBigFilesWrapper()
      errFile = "#{@scratchDir}/bigFiles.err"
      command = "bigFilesWrapper.rb -j #{@bigFilesJobFile} 2> #{errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      if(!exitStatus)
        @errUserMsg = "Could not run BigFiles Wrapper for the jobfile #{@bigFilesJobFile}"
        raise "Command: #{command} died. Check #{errFile} for more information. "
      end
    end
    #generates index files and uploads to the source database 
    def createIndexfiles()
      @genIndexFiles.each {|file|
        command = ""
        uploadPath = ""
        rsrcUri = URI.parse(file)
        rsrcPath = "#{rsrcUri.path}/data?"
        host = rsrcUri.host
        fileName = File.basename(@fileApiHelper.extractName(file))
        dataFile = "#{@scratchDir}/#{fileName}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading file from the database to: #{dataFile}")
        retVal = @fileApiHelper.downloadFile(file, @userId, dataFile)
        if(!retVal)
          @errUserMsg = "Failed to get data file, #{@fileApiHelper.extractName(file)} from the database, #{dbApiHelper.extractName(file)}"
          raise "File Download FAILED!! for the indexfile , #{@fileApiHelper.extractName(file)}"
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "File download complete to: #{dataFile}")
        end

     
        if(@fileTypeHash[file.chomp('?')] =~ /bam/)
          @baiFile = "#{dataFile}.bai"
          @baiErrFile = "#{@scratchDir}/createBaiFromBam.err"

          command = "samtools index #{dataFile} #{@baiFile} 2>> #{@baiErrFile}"
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
          exitStatus = system(command)
          if(!exitStatus)
            @errUserMsg = "Could not generate index for the bam file #{fileName}."
            raise "Command: #{command} died. Check #{@baiErrFile} for more information. "
          else
            #upload BAI file to the source database.
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading the index file,  #{fileName}.bai to the source database")
            uploadPath = "#{rsrcUri.path}.bai/data?"
            @uploadedFiles << "#{file.chomp('?')}.bai"
            apiCaller = WrapperApiCaller.new(host, uploadPath, @userId)
            apiCaller.put({}, File.open(@baiFile))
            if(!apiCaller.succeeded?)
              @errUserMsg = "ApiCaller Failed to upload the file #{fileName}. Check: #{apiCaller.respBody.inspect}"
              raise @errUserMsg
            end
          end
        elsif(@fileTypeHash[file.chomp('?')] =~/vcfTabix/)
          @tbiFile = "#{dataFile}.tbi"
          @tbiErrFile = "#{@scratchDir}/createTbiFromVcf.err"
          command = "tabix -p vcf #{dataFile} 2>> #{@tbiErrFile}"
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
          exitStatus = system(command)
          if(!exitStatus)
            @errUserMsg = "Could not generate tabix index for the VCF file, #{fileName}"
            @errUserMsg << File.read(@tbiErrFile)
            raise "Command: #{command} died. Check #{@tbiErrFile} for more information. \n #{File.read(@tbiErrFile)}"
          else
            #upload tbi
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading the index file,  #{fileName}.tbi to the source database")
            uploadPath = "#{rsrcUri.path}.tbi/data?"
            @uploadedFiles << "#{file.chomp('?')}.tbi"
            apiCaller = WrapperApiCaller.new(host, uploadPath, @userId)
            apiCaller.put({}, File.open(@tbiFile))
            if(!apiCaller.succeeded?)
              @errUserMsg = "ApiCaller Failed to upload the file #{fileName}. Check: #{apiCaller.respBody.inspect}"
              raise @errUserMsg
            end
          end
        end
      }
    end
    

    def createhub()
      @genomes = {}
      @tracks = Array.new()
      @hubKey = nil
      # First, get the track key-value pair for each track
      @inputs.each { |input|
        tmpTrk = Array.new()
        # get the genome version for each track
        dbUri = @dbApiHelper.extractPureUri(input)
        dbVersion = @pureDbUri[dbUri]['version'].downcase
        if(@genomes.key?(dbVersion))
          tmpTrk = getTrkKeys(input)
          @genomes[dbVersion] << tmpTrk
        else
          @genomes[dbVersion] = [dbUri]
          tmpTrk = getTrkKeys(input)
          @genomes[dbVersion] << tmpTrk 
        end
      }
     
      # Second, get the genomes key-value pair for each of the genomes
      gethubGenomes()
    
      # Third, make the hubEntity
      getHubFullEntity()
      
      $stdout.puts JSON.pretty_generate(@hubfullEntity) 
      # Once the hubEntity is made, make the API call
      targetUriObj = URI.parse(@targetUri)
      apiCaller = WrapperApiCaller.new(targetUriObj.host, "#{targetUriObj.path}/hub/#{CGI.escape(@hubName)}?detailed=true", @userId)
      apiCaller.put({}, JSON(@hubfullEntity))
      if(!apiCaller.succeeded?)
        @errUserMsg = "ApiCaller put request failed, at the hub resource #{@targetUriObj}. Check: #{apiCaller.respBody.inspect}"
        raise @errUserMsg
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Hub \"#{@hubName}\" successfully created ..............")

        #unlock the hub
        grpuri = @grpApiHelper.extractPureUri(@targetUri)
        grpobj = URI.parse(grpuri)
        apiCall = WrapperApiCaller.new(grpobj.host, "#{grpobj.path}/unlockedResources", @userId)
        # Check if it is already unlocked
        apiCall.get()
        hubUnlocked = false
        if(apiCall.succeeded?)
          resources = apiCall.parseRespBody["data"]
          hubres = "#{@targetUri}/hub/#{CGI.escape(@hubName)}"
          resources.each{ |res|
            if(res["url"] == hubres and res["public"])
              hubUnlocked = true
              break
            end
          }
          unless(hubUnlocked)
            payload = {"public" => true, "url" => "#{targetUriObj.path}/hub/#{CGI.escape(@hubName)}"}
            apiCall.put({}, [payload].to_json)
            if(!apiCall.succeeded?)
              @errUserMsg = "ApiCaller Failed to unlock the hubresource #{targetUriObj.path}/hub/#{CGI.escape(@hubName)}. Check: #{apiCall.respBody.inspect}"
              raise @errUserMsg
            else
              apiCall.parseRespBody()
              #MUST be "OK" and not "Multiple Choices"
              if(apiCall.apiStatusObj["statusCode"] != "OK")
                @errUserMsg = "ApiCaller Failed to unlock the hubresource, #{targetUriObj.path}/hub/#{CGI.escape(@hubName)}. Check : #{apiCall.apiStatusObj["msg"]}"
                raise @errUserMsg
              else
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Hub \"#{@hubName}\" unlocked ..............")
              end
            end
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Hub \"#{@hubName}\" is ALREADY unlocked ..............")
          end
        else
          @errUserMsg = "ApiCaller Failed at the get request on unlockedResources: #{grpobj.path}/unlockedResources .Check: #{apiCall.respBody.inspect}"
          raise @errUserMsg
        end 
      end
    end

    # Makes the track key-attribute value pair for each input Uri
    # param [+String] inputUri - a track or a file Uri
    # returns [Hash] 
    def getTrkKeys(inputUri)
     inUri = inputUri[/[^?]+/]
     tmpTrkHash = {}
     dburi =  @dbApiHelper.extractPureUri(inUri) 
     # For track
     if(inUri =~ BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP)
       tmpTrkHash['type'] = @trkTypeHash[inUri]
       tmpTrkHash['trkUrl'] = inUri
     # if not track then it is MUST be a file - inputs expanded in rulesHelper.
     else
       if(@fileTypeHash[inUri] =~ /bam/)
         tmpTrkHash['type'] = "bam" 
       else
         tmpTrkHash['type'] = "vcfTabix"
       end
       #replace file resource path with fileData resource
       $stderr.puts inUri

       fileDataUri = inUri.gsub(/\/file\//, '/fileData/')
       $stderr.puts fileDataUri
       tmpTrkHash['dataUrl'] = fileDataUri
     end
     return tmpTrkHash
    end
 
    # makes genome key-value pairs
    def gethubGenomes()
      @hubGenomes = Array.new()
      @genomes.each_key{ |genome|
        tmpGenomeHash = {}
        uri = @genomes[genome].shift
        tmpGenomeHash['genome'] = genome
        tmpGenomeHash['description'] = @pureDbUri[uri]['description']
        tmpGenomeHash['organism'] = @pureDbUri[uri]['species']
        tmpGenomeHash['defaultPos'] = "def"
        tmpGenomeHash['orderKey'] = 4800
        tmpGenomeHash['tracks'] = @genomes[genome]
        @hubGenomes << tmpGenomeHash
      }
    end

    # Makes the full hub entity key-value pairs
    def getHubFullEntity()
      @hubfullEntity = {}
      @hubfullEntity['name'] = @hubName
      @hubfullEntity['shortLabel'] = @shortLabel
      @hubfullEntity['longLabel'] = @longLabel
      @hubfullEntity['email'] = @hubEmail
      @hubfullEntity['public'] = true
      @hubfullEntity['genomes'] = @hubGenomes
    end
   

    def prepSuccessEmail()
      emailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId)
      emailObject.userFirst = @userFirstName
      emailObject.userLast = @userLastName
      emailObject.userFirst = @userFirstName
      emailObject.userFirst = @userFirstName
      inputsText = buildSectionEmailSummary(@inputs)
      emailObject.inputsText = inputsText
      outputsText = buildSectionEmailSummary(@outputs)
      emailObject.outputsText = outputsText
      emailObject.errMessage = @errUserMsg
      emailObject.exitStatusCode = @exitCode
      
      settingsToEmail = ["hubName", "longLabel", "shortLabel", "Email"]
      settings = {}
      settingsToEmail.each { |kk|
        settings[kk] = @settings[kk]
      }
      emailObject.settings = settings

      additionalInfo = ""
      target = URI.parse(@targetUri)
      hubLink = "#{target}/hub/#{CGI.escape(@hubName)}/hub.txt"
      additionalInfo << "  Track Hub Link:\n"+
                        "  #{hubLink}\n"
      ucscLinks = []
      washULinks = []
      @genomes.each_key{|genome|
        ucscLinks << "http://genome.ucsc.edu/cgi-bin/hgTracks?db=#{genome}&hubUrl=#{CGI.escape(hubLink)}"
        washULinks << "http://epigenomegateway.wustl.edu/browser/?genome=#{genome}&datahub_ucsc=#{target}/hub/#{CGI.escape(@hubName)}/hub.txt"
      }
      additionalInfo << "  View Hub in UCSC Genome Browser:\n"+
                        "  #{ucscLinks.join("\n  ")} \n"
                        #"  View Hub in WashU Browser:\n"+
                        #"  #{washULinks.join("\n")}"

      unless(@genBigFiles.empty?)
        additionalInfo << "  \n"+"*"*50+"\n"+
                        "  BigBed/BigWig file(s) generated for:\n"
        @genBigFiles.each{ |big|
          additionalInfo << "    - #{@trkApiHelper.extractName(big)}\n"
        }
        additionalInfo << "  \n"+"*"*50+"\n" 
      end

      unless(@uploadedFiles.empty?)
        additionalInfo << "  \n"+"*"*50+"\n"+
                          "  Index file(s) generated are:\n"
        @uploadedFiles.each{ |uploaded|
          additionalInfo << "    - #{@fileApiHelper.extractName(uploaded)}\n"
        }
        additionalInfo << "  \n"+"*"*50+"\n"
      end

      emailObject.additionalInfo = additionalInfo
      return emailObject
    end

    def prepErrorEmail()
      emailErrorObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId)
      emailErrorObject.userFirst = @userFirstName
      emailErrorObject.userLast = @userLastName
      inputsText = buildSectionEmailSummary(@inputs)
      emailErrorObject.inputsText = inputsText
      outputsText = buildSectionEmailSummary(@outputs)
      emailErrorObject.outputsText = outputsText
      emailErrorObject.errMessage = @errUserMsg
      emailErrorObject.exitStatusCode = @exitCode
      
      settingsToEmail = ["hubName", "longLabel", "shortLabel", "Email"]
      settings = {}
      settingsToEmail.each { |kk|
        settings[kk] = @settings[kk]
      }
      emailErrorObject.settings = settings

      return emailErrorObject
    end
  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::CreateHubWrapper)
end
