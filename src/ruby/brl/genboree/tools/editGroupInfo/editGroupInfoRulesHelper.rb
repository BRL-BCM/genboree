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
  class EditGroupInfoRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'editGroupInfo'

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
      if(!testUserPermissions(wbJobEntity.outputs, 'o')) # Need admin level access
        rulesSatisfied = false
        wbJobEntity.context['wbErrorMsg'] = "ACCESS_DENIED: You need administrator level access to edit group info."
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
          if(newName != @grpApiHelper.extractName(output)) # Only check if name was changed to something new
            targetUri = URI.parse(@grpApiHelper.extractPureUri(output))
            targetHost = targetUri.host
            targetRsrcPath = targetUri.path
            apiCaller = ApiCaller.new(targetHost, "/REST/v1/grp/#{CGI.escape(newName)}?", @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            if(apiCaller.succeeded?)
              wbJobEntity.context['wbErrorMsg'] = "A group with the name: '#{newName}' already exists at host: #{targetHost}. "
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
      else # No warnings for now
        warningsExist = false
      end
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
