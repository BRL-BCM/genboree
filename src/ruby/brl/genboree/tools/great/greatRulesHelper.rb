require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class GreatRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        dbUri = nil
        if(outputs.size == 1)
          dbUri = outputs[0]
        else
          outputs.each { |output|
            if(@dbApiHelper.extractName(output))
              dbUri = output
              break
            end
          }
        end
        permission = testUserPermissions([dbUri], 'o')
        unless(permission)
          rulesSatisfied = false
          wbJobEntity.context['wbErrorMsg'] = "NO PERMISSION: You need administrator level access to the target database since the tool involves unlocking file resources for GREAT to access."
        else
          unless(checkDbVersions(inputs + [dbUri], skipNonDbUris=true))
            # FAILED: No, some versions didn't match
            wbJobEntity.context['wbErrorMsg'] =
            {
              :msg => 'Some tracks are from a different genome assembly version than other tracks, or from the output database.',
              :type => :versions,
              :info =>
              {
                :inputs =>  @trkApiHelper.dbVersionsHash(inputs),
                :outputs => @dbApiHelper.dbVersionsHash(outputs)
              }
            }
            rulesSatisfied = false
          end
        end
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings) and rulesSatisfied)
          
          
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
        warningsExist = false # No warnings for now
      end
      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
