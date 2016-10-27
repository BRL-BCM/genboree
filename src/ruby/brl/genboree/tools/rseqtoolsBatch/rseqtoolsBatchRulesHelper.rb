require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require "brl/genboree/helpers/sniffer"
include BRL::Genboree::REST

module BRL; module Genboree; module Tools
  class RseqtoolsBatchRulesHelper < WorkbenchRulesHelper
    TOOL_ID = "rseqtoolsBatch"
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      errorMsgArr = []
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        # Must pass the rest of the checks as well
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        fileList = @fileApiHelper.expandFileContainers(wbJobEntity.inputs, @userId)
        wbJobEntity.inputs = fileList
        inputs = wbJobEntity.inputs
        # ---------------------------------------------------------------------------------------
        # Check 1: Make sure the genome version is currently supported by the RSeqtools Long RNA-seq Pipeline
        # ---------------------------------------------------------------------------------------
        genomesSatisfied = true
        targetDbUriObj = URI.parse(outputs[0])
        apiCaller = ApiCaller.new(targetDbUriObj.host, "#{targetDbUriObj.path}?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody)['data']
        
        genomeVersion = resp['version'].decapitalize
        wbJobEntity.settings['genomeVersion'] = genomeVersion
        gbRSeqToolsGenomesInfo = JSON.parse(File.read(@genbConf.gbRSeqToolsGenomesInfo))
        if(!gbRSeqToolsGenomesInfo.key?(genomeVersion))
          wbJobEntity.context['wbErrorMsg'] = "INVALID_GENOME: Known gene annotations for this genome assembly version: #{genomeVersion} is not currently available in RSEQtools. Supported genomes include: #{gbRSeqToolsGenomesInfo.keys.join(',')}. Please contact the Genboree Administrator for adding support for this genome."
          genomesSatisfied = false
          rulesSatisfied = false
        end        
        
        if(genomesSatisfied)  # If genome is not supported, then do not process any further
          # If user submits empty folder / entity list, then provide error message
          if(inputs.size < 1)
            wbJobEntity.context['wbErrorMsg'] = "INVALID NUMBER OF INPUTS: If you submit a folder/entity list, you must give at least 1 input FASTQ file (no empty folders!)."
            rulesSatisfied = false
          # ------------------------------------------------------------------
          # Check 2: Are all the input files (including those inside entity lists or folders) 
          # from the same db version?
          # ------------------------------------------------------------------
          # If number of files is correct but files are from different db versions, we reject the job
          elsif(!checkDbVersions(inputs + outputs, skipNonDbUris=true))
            wbJobEntity.context['wbErrorMsg'] =
              {
                :msg => 'Some files are from a different genome assembly version than other files, or from the output database.',
                :type => :versions,
                :info =>
                {
                  :inputs =>  @trkApiHelper.dbVersionsHash(inputs),
                  :outputs => @dbApiHelper.dbVersionsHash(outputs)
                }
              }
            rulesSatisfied = false
          else
            # ------------------------------------------------------------------
            # Check 3: Make sure the right combination of inputs has been selected
            # ------------------------------------------------------------------
            fileSizeSatisfied = true
            fileFormatSatisfied = true
            
            # Ensure manifest file is provided - else rseqtools cannot be run in batch processing mode
            inputFiles = []
            @manifestFileURI = ""
            inputs.each { |inputFile|
              if(inputFile =~ /(.+?)\.(?i)manifest(?-i)\.json/)
                @manifestFileURI = inputFile
              else
                inputFiles << inputFile
              end
            }
            
            if(@manifestFileURI.empty? or @manifestFileURI.nil?)
              errorMsgArr.push("MISSING MANIFEST FILE: Manifest file is not part of the inputs.\nRSEQtools cannot be run in batch processing mode without a valid manifest file.")
              rulesSatisfied = false
            end
            
            inputFiles.each { |file|
              fileSizeSatisfied = checkFileSize(file)
              if(fileSizeSatisfied)
                fileFormatSatisfied = sniffFastqFormat(file)
                unless(fileFormatSatisfied)
                  errorMsgArr.push("INVALID_FILE_FORMAT: Input file #{file} is not in FASTQ format. Please check the file format.")
                  rulesSatisfied = false
                end
              else
                errorMsgArr.push("INVALID_FILE_SIZE: Input file #{file} is empty. You cannot submit an empty file for processing.")
                rulesSatisfied = false
              end
            }
            unless(rulesSatisfied)
              wbJobEntity.context['wbErrorMsg'] = errorMsgArr
            end # unless(rulesSatisfied)
          end # 
        end # if(genomesSatisfied)

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
          rcscUri << "/file/RSEQtoolsBatch/#{CGI.escape(wbJobEntity.settings['analysisName'])}/jobFile.json?"
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{wbJobEntity.settings['analysisName']} has already been launched before. Please select a different job name."
          else
            settings =  wbJobEntity.settings
            # Check 2: If 'doUploadResults' has been checked, the track name should be correctly formatted
            doUploadResults = settings['doUploadResults']
            properTrackName = true
            error = ""
            if(doUploadResults)
              @lffType = settings['lffType']
              @lffSubType = settings['lffSubType']
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
      if(fileSize == 0)
        fileSizeSatisfied = false # File is empty. Reject job immediately.
      end # 
      return fileSizeSatisfied
    end

    # Sniffer for FASTQ/SRA
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
        #outputs = wbJobEntity.outputs
        ###Checking db and proj irrespective of their order
        #if(wbJobEntity.outputs[0] !~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
        #  outputDb = wbJobEntity.outputs[1]
        #else
          outputDb = wbJobEntity.outputs[0]
        #end
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
end ; end ; end
