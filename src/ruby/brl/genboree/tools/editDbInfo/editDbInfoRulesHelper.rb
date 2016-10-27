require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class EditDbInfoRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'editDbInfo'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      inputs = wbJobEntity.inputs
      outputs = wbJobEntity.outputs
      output = outputs[0]
      # ------------------------------------------------------------------
      # Check Inputs/Outputs
      # ------------------------------------------------------------------
      userId = wbJobEntity.context['userId']
      permission = testUserPermissions(wbJobEntity.outputs, 'o')
      unless(permission)
        rulesSatisfied = false
        wbJobEntity.context['wbErrorMsg'] = "NO PERMISSION: You need administrator level access to edit database information."
      else
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end
          rulesSatisfied = false
          # Check 1: The name being used to rename should not already exist
          newName = wbJobEntity.settings['newName'].strip
          if(newName != @dbApiHelper.extractName(output)) # Only check if name was changed to something new
            targetUri = URI.parse(@grpApiHelper.extractPureUri(output))
            targetHost = targetUri.host
            targetRsrcPath = targetUri.path
            apiCaller = ApiCaller.new(targetHost, "#{targetRsrcPath}/db/#{CGI.escape(newName)}?", @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            if(apiCaller.succeeded?)
              wbJobEntity.context['wbErrorMsg'] = "A database with the name: '#{newName}' already exists in the target group. "
            else
              rulesSatisfied = true
            end
          else
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
        warningMsg = ""
        version = wbJobEntity.settings['version']
        currVersion = wbJobEntity.settings['currVersion']
        if(version != currVersion)
          warningMsg = "You are changing the genome version of the database. This might cause tools that rely on genome versions to fail. "
        end
        if(!warningMsg.empty?)
          wbJobEntity.context['wbErrorMsg'] = warningMsg
        else
          warningsExist = false
        end
      end
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
