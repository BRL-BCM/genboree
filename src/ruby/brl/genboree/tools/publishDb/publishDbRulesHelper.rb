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
  class PublishDbRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'publishDb'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        if(!canonicalAddressesMatch?(URI.parse(wbJobEntity.outputs[0]).host, [@genbConf.machineName, @genbConf.machineNameAlias]))
          wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: This tool cannot be used across multiple hosts."
          rulesSatisfied = false
        else
          permission = testUserPermissions(wbJobEntity.outputs, 'o')
          unless(permission)
            rulesSatisfied = false
            wbJobEntity.context['wbErrorMsg'] = "NO PERMISSION: You need administrator level access to publish databases."
          else
            # ------------------------------------------------------------------
            # CHECK SETTINGS
            # ------------------------------------------------------------------
            if(sectionsToSatisfy.include?(:settings))
              # Check :settings together with info from :outputs :
              unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
                raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
              end
            end
          end
        end
      end

      # Clean up helpers, which cache many things
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      return rulesSatisfied
    end

    # It's a good idea to catch any potential errors now instead of relying on the job to do validation because,
    # the job may get queued and the user wouldn't be notified  for an unnecessarily long time that they have something minor wrong with their inputs.
    #
    # [+returns+] boolean
    def warningsExist?(wbJobEntity)
      warningsExist = true
      inputs = wbJobEntity.inputs
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else
        warningsExist = false
      end
      @sampleSetApiHelper.clear() if(!@sampleSetApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools