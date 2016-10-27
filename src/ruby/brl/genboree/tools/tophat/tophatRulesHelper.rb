require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class TophatRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'tophat'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        outputs = wbJobEntity.outputs
        inputs = wbJobEntity.inputs
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        userId = wbJobEntity.context['userId']
        apiKey = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @genbConf.dbrcFile)
        @user = apiKey.user
        @password = apiKey.password
        fileList = []
        # Check 1: are all the input files from the same db version?
        unless(checkDbVersions(inputs + outputs, skipNonDbUris=true)) # Failed
          wbJobEntity.context['wbErrorMsg'] = "Database version of one or more input file(s) do not match target database."
        else
          # Check 2: Make sure the right combination of inputs has been selected
          errorMsg = ""
          filesSatisfied = true
          if(inputs.size == 2)
            inputs.each { |file|
              if(!@fileApiHelper.extractName(file))
                filesSatisfied = false
                errorMsg = "INVALID_INPUT: For 2 inputs, both need to be files. "
                break
              end
            }
          else # For only one input (folder/files entity list), it should have 2 and only 2 files
            inputUri = URI.parse(inputs[0])
            apiCaller = ApiCaller.new(inputUri.host, inputUri.path, @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            resp = JSON.parse(apiCaller.respBody)['data']
            if(inputs[0] =~ /entityList/)
              resp.each { |file|
                fileName = file['url']
                if(fileName =~ /fastq/)
                  fileList << fileName
                end
              }
              if(fileList.size != 2)
                errorMsg = "INVALID_INPUT: The folder or Files Entity List should contain 2 and only 2 fastq files. "
                filesSatisfied = false
              end
            elsif(@fileApiHelper.extractName(inputs[0]).nil?)
              resp.each { |file|
                fileName = file['refs'][BRL::Genboree::REST::Data::DatabaseFileEntity::REFS_KEY]
                if(fileName =~ /fastq/)
                  fileList << fileName
                end
              }
              if(fileList.size != 2)
                errorMsg = "INVALID_INPUT: The folder or Files Entity List should contain 2 and only 2 fastq files. "
                filesSatisfied = false
              end
            else
              filesSatisfied = false
              errorMsg = "INVALID_INPUT: You need to drag 2 input files. "
            end
          end
          unless(filesSatisfied)
            wbJobEntity.context['wbErrorMsg'] = errorMsg
          else
            if(inputs.size < 2)
              wbJobEntity.inputs = fileList
            end
            rulesSatisfied = true
          end
        end
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
          rcscUri << "/file/TopHat/#{CGI.escape(wbJobEntity.settings['analysisName'])}/jobFile.json?"
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{wbJobEntity.settings['analysisName']} has already been launched before. Please select a different job name."
          else
            # Check 2: If 'duUploadResults' has been checked, the track name should be correcylt formatted
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
            else
              # Check 3: If 'auto-determine inner mean dist' is unchecked, the user MUSt enter a custom value
              innerMeanDistSatisfied = true
              autoDetermineMateInnerDist = wbJobEntity.settings['autoDetermineMateInnerDist']
              if(!autoDetermineMateInnerDist)
                mateInnerDist = wbJobEntity.settings['mateInnerDist']
                mateStdev = wbJobEntity.settings['mateStdev']
                if(mateInnerDist.nil? or mateInnerDist.empty? or mateInnerDist !~ /^\d+$/ or mateStdev.nil? or mateStdev.empty? or mateStdev !~ /^\d+$/)
                  innerMeanDistSatisfied = false
                  wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: You must enter a valid value for 'Mate Inner Dist' and 'Mate Stdev' if 'Auto-Determine Mate Inner Dist ?' is unchecked. "
                end
              end
              if(innerMeanDistSatisfied)
                rulesSatisfied = true
              end
            end
          end
        end
      end
      return rulesSatisfied
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
        # no warnings for now
        warningsExist = false
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
