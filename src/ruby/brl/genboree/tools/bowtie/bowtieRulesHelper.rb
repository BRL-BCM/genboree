require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require "brl/genboree/helpers/sniffer"
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class BowtieRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'bowtie'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs

        # To find database of the output target
        dbUri = nil
        outputs.each { |output|
          if(@dbApiHelper.extractName(output))
            dbUri = output
            break
          end
        }

        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        userId = wbJobEntity.context['userId']
        apiKey = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @genbConf.dbrcFile)
        @user = apiKey.user
        @password = apiKey.password
        fileList = []

        # ------------------------------------------------------------------
        # Check 1: Make sure the genome version is currently supported by BOWTIE 2
        # ------------------------------------------------------------------
        #genomesSatisfied = true
        targetDbUriObj = URI.parse(outputs[0])
        apiCaller = ApiCaller.new(targetDbUriObj.host, "#{targetDbUriObj.path}?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody)['data']
        genomeVersion = resp['version'].decapitalize
        wbJobEntity.settings['genomeVersion'] = genomeVersion
        #gbBowtieGenomesInfo = JSON.parse(File.read(@genbConf.gbBowtieGenomesInfo))
        #if(!gbBowtieGenomesInfo.key?(genomeVersion))
        #  wbJobEntity.context['wbErrorMsg'] = "INVALID_GENOME: The genome assembly version: #{genomeVersion} is not currently supported by BOWTIE 2. Supported genomes include: #{gbBowtieGenomesInfo.keys.join(',')}. Please contact the Genboree Administrator for adding support for this genome."
        #  genomesSatisfied = false
        #  rulesSatisfied = false
        #end

        #if(genomesSatisfied)  # If genome is not supported, then do not process any further
          expandedInputs = inputs.dup
          filesSatisfied = true

          # To make sure all files inside entity list/folder are from same db version
          if(expandedInputs.size == 1 and inputs[0] !~ /\/file\//)
            expInputUri = URI.parse(inputs[0])
            apiCaller = ApiCaller.new(expInputUri.host, expInputUri.path, @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            respInput = JSON.parse(apiCaller.respBody)['data']

            # If input is an entity list or folder, add them to expandedInputs
            # so it can be used by checkDbVersions to ensure all inputs
            # are from same db
            if(expandedInputs[0] =~ /entityList/)
              respInput.each { |file| expandedInputs << file['url'] }
            elsif(@fileApiHelper.extractName(expandedInputs[0]).nil?)
              respInput.each { |file| expandedInputs << file['refs'][BRL::Genboree::REST::Data::DatabaseFileEntity::REFS_KEY] }
            end

            # If total number of inputs including entity list (EL)/folder is
            # less than 2 (1 EL/folder + 1 single-end FASTQ inside that) or
            # more than 3 (1 EL/folder + 2 paired-end FASTQ files)
            # then stop checking any further
            if(expandedInputs.size < 2 or expandedInputs.size > 3)
              filesSatisfied = false
            end
          end # if(expandedInputs.size == 1)

          # If number of files is not satisfied, directly print the error message
          if(!filesSatisfied)
            wbJobEntity.context['wbErrorMsg'] = "INVALID_NUMBER_OF_INPUTS: You can give 1 (single-end) or 2 (paired-end) input FASTQ files or 1 folder/entity list with 1 (single-end) or 2 (paired-end) input FASTQ files."
            rulesSatisfied = false
          # ------------------------------------------------------------------
          # Check 2: Are all the input files (including those inside entity lists or folders)
          # from the same db version?
          # ------------------------------------------------------------------
          # If number of files is correct but files are from different db versions
          elsif(filesSatisfied and !checkDbVersions(expandedInputs + outputs, skipNonDbUris=true))
          # FAILED: No, some versions didn't match
            wbJobEntity.context['wbErrorMsg'] =
             {
               :msg => 'Some files are from a different genome assembly version than other files, or from the output database.',
               :type => :versions,
               :info =>
               {
                 :inputs =>  @trkApiHelper.dbVersionsHash(expandedInputs),
                 :outputs => @dbApiHelper.dbVersionsHash(outputs)
               }
             }
            rulesSatisfied = false
          else
            # ------------------------------------------------------------------
            # Check 3: Make sure the right combination of inputs has been selected
            # ------------------------------------------------------------------
            errorMsg = ""
            fileSizeSatisfied = true
            fileFormatSatisfied = true
            # For exactly 2 inputs, make sure both are FASTQ files
            if(filesSatisfied and inputs.size == 2)
              inputs.each { |file|
                if(!@fileApiHelper.extractName(file))
                  filesSatisfied = false
                  errorMsg = "INVALID_INPUT: For 2 inputs, both need to be files. "
                  break
                else
                  fileName = file
                  fileSizeSatisfied = checkFileSize(fileName)
                  if(fileSizeSatisfied)
                    fileFormatSatisfied = sniffFastqFormat(fileName)
                    unless(fileFormatSatisfied)
                      errorMsg = "INVALID_FILE_FORMAT: Input file is not in FASTQ format. Please check the file format."
                      break
                    else
                      fileList << fileName
                    end
                  else
                    break
                  end # if(fileSizeSatisfied)
                end # if(!fileName)
              }
            # For only one input (single-end FASTQ file or folder/files entity list with 1 (single-end) or 2 (paired-end) files)
            elsif(filesSatisfied and inputs.size == 1)
              # If input is an entity list
              if(inputs[0] =~ /entityList/)
                respInput.each { |file|
                  fileName = file['url']
                  fileSizeSatisfied = checkFileSize(fileName)
                  if(fileSizeSatisfied)
                    fileFormatSatisfied = sniffFastqFormat(fileName)
                    unless(fileFormatSatisfied)
                      errorMsg = "INVALID_FILE_FORMAT: Input file is not in FASTQ format. Please check the file format."
                      break
                    else
                      fileList << fileName
                    end
                  else
                    break
                  end # if(fileSizeSatisfied)
                }

              # If input is a folder with files
              elsif(@fileApiHelper.extractName(inputs[0]).nil?)
                respInput.each { |file|
                  fileName = file['refs'][BRL::Genboree::REST::Data::DatabaseFileEntity::REFS_KEY]
                  fileSizeSatisfied = checkFileSize(fileName)
                  if(fileSizeSatisfied)
                    fileFormatSatisfied = sniffFastqFormat(fileName)
                    unless(fileFormatSatisfied)
                      errorMsg = "INVALID_FILE_FORMAT: Input file is not in FASTQ format. Please check the file format."
                      break
                    else
                      fileList << fileName
                    end
                  else
                    break
                  end # if(fileSizeSatisfied)
                }

              # If input is a single file
              elsif(inputs[0] =~ /\/file\//)
                fileName = inputs[0]
                fileSizeSatisfied = checkFileSize(fileName)
                if(fileSizeSatisfied)
                  fileFormatSatisfied = sniffFastqFormat(fileName)
                  if(fileFormatSatisfied)
                    fileList << fileName
                  end
                end # if(fileSizeSatisfied)

              # If input does not satisfy any of the above conditions
              else
                filesSatisfied = false
                errorMsg = "INVALID_INPUT: You need to drag 1 (single-end) or 2 (paired-end) input FASTQ files. "
              end
            else
              errorMsg = "INVALID_NUMBER_OF_INPUTS: You can give 1 (single-end) or 2 (paired-end) input FASTQ files or 1 folder/entity list with 1 (single-end) or 2 (paired-end) input FASTQ files. "
            end # if(filesSatisfied and inputs.size == 2)

            if(!fileSizeSatisfied)
              errorMsg = "INVALID_FILE: Input file is empty. Tool requires non-empty file(s) to run. Please re-upload non-empty input file(s) and try again. "
              wbJobEntity.context['wbErrorMsg'] = errorMsg
              rulesSatisfied = false
            elsif(!fileFormatSatisfied)
              errorMsg = "INVALID_FILE_FORMAT: Input file is not in FASTQ format. Please check the file format."
              wbJobEntity.context['wbErrorMsg'] = errorMsg
              rulesSatisfied = false
            else
              wbJobEntity.inputs = fileList
              rulesSatisfied = true
            end # if(!fileSizeSatisfied)
          end # if(!filesSatisfied)
        #end # if(genomesSatisfied)

        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end

          rulesSatisfied = false

          # Check1: A job with the same analysis name under the same target db should not exist
          output = @dbApiHelper.extractPureUri(outputs[0])
          uri = URI.parse(output)
          host = uri.host
          rcscUri = uri.path
          rcscUri = rcscUri.chomp("?")
          rcscUri << "/file/Bowtie/#{CGI.escape(wbJobEntity.settings['analysisName'])}/jobFile.json?"
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{wbJobEntity.settings['analysisName']} has already been launched before. Please select a different job name."
          else
            # Check 2: If 'doUploadResults' has been checked, the track name should be correctly formatted
            doUploadResults = wbJobEntity.settings['doUploadResults']
            properTrackName = true
            error = ""
            if(doUploadResults)
              @lffType = wbJobEntity.settings['lffType']
              @lffSubType = wbJobEntity.settings['lffSubType']
              if(@lffType.nil? or @lffType.empty? or @lffType =~ /:/ or @lffType =~ /^\s/ or @lffType =~ /\s$/ or @lffType =~ /\t/)
                error = "INVALID_INPUT: The 'lffType' field is incorrectly formatted"
                properTrackName = false
              end
              if(@lffSubType.nil? or @lffType.empty? or @lffType =~ /:/ or @lffType =~ /^\s/ or @lffType =~ /\s$/ or @lffType =~ /\t/)
                error = "INVALID_INPUT: The 'lffSubType' field is incorrectly formatted"
                properTrackName = false
              end
            end
            unless(properTrackName)
              wbJobEntity.context['wbErrorMsg'] = error
              rulesSatisfied = false
            else
              # Check 3: If 'makeNewIndex' is selected but no entrypoints are chosen
              settings =  wbJobEntity.settings
              useIndex = settings['useIndex']
              baseWidget =  settings['baseWidget']
              selectedEp = false
              makeNewIndex = false
              if(useIndex =~ /makeNewIndex/)
                makeNewIndex = true
                settings.keys.each{ |key|
                  if(key =~ /#{baseWidget}/)
                    selectedEp = true
                    break
                  end
                }
              end # if(useIndex =~ /makeNewIndex/)

              if(makeNewIndex && !selectedEp)
                errorMsg = "INVALID SELECTION: You should select at least one entrypoint to make a custom Bowtie2 index."
                wbJobEntity.context['wbErrorMsg'] = errorMsg
                rulesSatisfied = false
              else
                rulesSatisfied = true
              end # if(makeNewIndex && !selectedEp)
            end # unless(properTrackName)
          end # if(apiCaller.succeeded?)
        end # if(sectionsToSatisfy.include?(:settings))
      end # if(rulesSatisfied)
      return rulesSatisfied
    end

    # Check file size
    def checkFileSize(fileName)
      ## Check if file is not empty
      fileSizeSatisfied = true
      fileUriObj = URI.parse(fileName)
      apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/size?", @hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      fileSize = JSON.parse(apiCaller.respBody)['data']['number'].to_i
      if(fileSize == 0 )
        fileSizeSatisfied = false # File is empty. Reject job immediately.
        return fileSizeSatisfied
      end #
      return fileSizeSatisfied
    end

    # Sniffer for FASTQ
    def sniffFastqFormat(fileName)
      fileFormatSatisfied = true
      fileUriObj = URI.parse(fileName)
      apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/compressionType?", @hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      type = JSON.parse(apiCaller.respBody)['data']['text']
      if(type != 'text')
        fileFormatSatisfied = true # File is compressed (not text), so assume format is true and check if file is FASTQ in the wrapper
      else
      # To check FASTQ format if file is not compressed and not empty
        fileUriObj = URI.parse(fileName)
        apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/sniffedType?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        sniffedType = JSON.parse(apiCaller.respBody)['data']['text']
        if(sniffedType != 'fastq')
          fileFormatSatisfied = false # Since file is not fastq, return false
        end
      end
      return fileFormatSatisfied
    end
=begin
        sniffer = BRL::Genboree::Helpers::Sniffer.new()
        # Get number of records needed by Sniffer
        numRecs = sniffer.getFormatConf('fastq').nRecs
        apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/data?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        tmpFileName = "#{Time.now.to_f}.#{rand(10_000)}.#{CGI.escape(File.basename(@fileApiHelper.extractName(fileName)))}"
        # Make Tempfile. Auto-cleaned up when we call close. Use untainted Dir::tmpdir as a best practice.
        tempFastqFileObj  = Tempfile.new(tmpFileName, Dir::tmpdir.untaint)
        numLines = 0
        apiCaller.get() { |chunk|
          tempFastqFileObj.print(chunk)
          numLines += chunk.count("\n")
          break if(numLines >= numRecs)
        }
        # When all done writing to Tempfile, use flush() to ensure it's written to disk.
        # - otherwise, when things like Sniffer (or whatever) read from the file it may be empty (!!) or much smaller than it should be!
        # - this is important here because we can't close() the tempfile until ALL done with it (close == delete/clean the tempfile!)
        tempFastqFileObj.flush()
        # tempFastqFileObj.path gives the entire path and file name
        sniffer.filePath = tempFastqFileObj.path
        if(!sniffer.detect?('fastq'))
          fileFormatSatisfied = false
        end # if(sniffer.detect?('fastq'))
        # Tempfile should be closed only after Sniffer method is called
        tempFastqFileObj.close()
=end

    # It's a good idea to catch any potential errors now instead of relying on the job to do validation because,
    # the job may get queued and the user wouldn't be notified  for an unnecessarily long time that they have something minor wrong with their inputs.
    #
    # [+returns+] boolean
    def warningsExist?(wbJobEntity)
      warningsExist = true
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else # Look for warnings
        outputDb = wbJobEntity.outputs[0]
        doUploadResults = wbJobEntity.settings['doUploadResults']
        if(doUploadResults) # User checked the box to upload results
          # CHECK: does the output db already have a track with same name
          deleteDupTracks = wbJobEntity.settings['deleteDupTracks']
          if(deleteDupTracks) # User checked the box to delete track with same name
            @lffType = wbJobEntity.settings['lffType']
            @lffSubType = wbJobEntity.settings['lffSubType']
            @trackName = CGI.escape("#{@lffType}:#{@lffSubType}")
            output = @dbApiHelper.extractPureUri(outputDb)
            trackUri = URI.parse(output)
            host = trackUri.host
            trackUriPath = trackUri.path
            trackUriPath = trackUriPath.chomp("?")
            rsrcUri = "#{trackUriPath}/trk/#{@trackName}"
            apiCaller = ApiCaller.new(host, rsrcUri, @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            if(apiCaller.succeeded?) # Warning: Track Name already exists in db
              warnings = true
            end # if(apiCaller.succeeded?)

            if(warnings) # Warning: Track Name already exists in db
              errorMsg = "TrackName <b> #{CGI.unescape(@trackName)} </b> already exists in the database. You have chosen to delete this track. A new track with the same name will be created during this analysis. If you want to add data to the pre-existing track, uncheck the \"Delete pre-existing tracks\" option in the UI settings. Are you sure you want to proceed?"
              wbJobEntity.context['wbErrorMsg'] = errorMsg
              wbJobEntity.context['wbErrorMsgHasHtml'] = true
            else
              warningsExist = false
            end # if(warnings)
          else # If user has not chosen to delete duplicate tracks
            errorMsg = "You have chosen not to delete pre-existing tracks in this db. If a track exists with the same name, data from this current analysis will be appended to the pre-existing track. Are you sure you want to proceed?"
            wbJobEntity.context['wbErrorMsg'] = errorMsg
            wbJobEntity.context['wbErrorMsgHasHtml'] = true
          end # if(deleteDupTracks)
        else
          warningsExist = false
        end # if(doUploadResults)
      end # if(wbJobEntity.context['warningsConfirmed'])

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      return warningsExist
    end # def warningsExist?(wbJobEntity)
  end
end ; end; end # module BRL ; module Genboree ; module Tools
