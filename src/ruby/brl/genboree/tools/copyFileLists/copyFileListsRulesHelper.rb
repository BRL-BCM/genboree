require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class CopyFileListsRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'copyFileLists'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      inputs = wbJobEntity.inputs
      outputs = wbJobEntity.outputs
      if(rulesSatisfied)
        rulesSatisfied = false
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        userId = wbJobEntity.context['userId']
        unless(checkDbVersions(inputs + outputs, skipNonDbUris=true)) # Failed
          wbJobEntity.context['wbErrorMsg'] = "Database version of one or more input file entity lists does not match output database."
        else
          rulesSatisfied = true
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
          # Check 2: If the user checked the 'Move Files' box the user must have write access to all the source dbs
          deleteFiles = wbJobEntity.settings['deleteSourceFilesRadio']
          haveAccess = true
          if(deleteFiles == 'move')
            inputs.each { |input|
              if(!@dbApiHelper.accessibleByUser?(@dbApiHelper.extractPureUri(input), userId, CAN_WRITE_CODES))
                # FAILED: doesn't have write access to source database
                wbJobEntity.context['wbErrorMsg'] =
                {
                  :msg => "Access Denied: You don't have permission to write to all the source databases (Required for move).",
                  :type => :writeableDbs,
                  :info => @dbApiHelper.accessibleDatabasesHash(inputs, userId, CAN_WRITE_CODES)
                }
                haveAccess = false
                break
              end
            }
          end
          if(haveAccess)
            rulesSatisfied = true
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
      inputs = wbJobEntity.inputs
      outputs = wbJobEntity.outputs
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else
        # Check if there are duplicates (track entity lists with the same base name)
        # Check if some of the input entity lists are already present in the target
        uri = URI.parse(outputs[0])
        host = uri.host
        rsrcPath = uri.path
        apiKey = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @genbConf.dbrcFile)
        @user = apiKey.user
        @password = apiKey.password
        userId = wbJobEntity.context['userId']
        dupList = {}
        warnings = false
        filePresentList = []
        multiSelectInputList = wbJobEntity.settings['multiSelectInputList']
        multiSelectInputList.each { |inputUri|
          fileEntityList = @fileEntityListApiHelper.extractName(inputUri)
          if(dupList.has_key?(fileEntityList))
            dupList[fileEntityList] = dupList[fileEntityList] += 1
          else
            dupList[fileEntityList] = 1
          end
          apiCaller = WrapperApiCaller.new(host, "#{rsrcPath}/files/entityList/#{CGI.escape(fileEntityList)}?", userId)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          resp = JSON.parse(apiCaller.respBody)['data']
          if(!resp.empty?)
            warnings = true
            filePresentList.push(fileEntityList)
          end
        }
        if(warnings)
          errorMsg = "The following file entity list(s) are already present in the target database:"
          errorMsg << "<ul>"
          filePresentList.each { |file|
            errorMsg << "<li>#{file}</li>"
          }
          errorMsg << "</ul>  "
          wbJobEntity.context['wbErrorMsg'] = errorMsg
          wbJobEntity.context['wbErrorMsgHasHtml'] = true
        else
          # Check 2: Do any of the input file entity lists have the same name?
          dupFiles = false
          dupList.each_key { |file|
            if(dupList[file] > 1)
              dupFiles = file
              break
            end
          }
          if(dupFiles)
            warningMessage = "You are copying MULTIPLE file entity lists with the same base name: "
            warningMessage << "#{dupFiles}. "
            warningMessage << "This will end up combining all the data together in a single file entity list.
                              Are you sure you want to proceed?"
            wbJobEntity.context['wbErrorMsg'] = warningMessage
          else
            warningsExist = false
          end
        end
      end
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
