require 'uri'
require 'brl/genboree/tools/workbenchRulesHelper'

module BRL ; module Genboree ; module Tools

  class CreateBAIRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        userId = wbJobEntity.context['userId']
        inputs = wbJobEntity.inputs
        if(!@dbApiHelper.allAccessibleByUser?(inputs, userId, CAN_WRITE_CODES))
          # FAILED: doesn't have write access to source database
          wbJobEntity.context['wbErrorMsg'] =
          {
            :msg => "Access Denied: You don't have permission to write to all the source databases.",
            :type => :writeableDbs,
            :info => @dbApiHelper.accessibleDatabasesHash(inputs, userId, CAN_WRITE_CODES)
          }
          rulesSatisfied = false          
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
      else # No warnings for now
        warningsExist = false
      end
      return warningsExist
    end

  end
end; end; end
