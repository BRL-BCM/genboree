require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class TabularTrackViewerRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'tabularTrackViewer'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        rulesSatisfied = false
        inputs = wbJobEntity.inputs
        allDbsOk = true
        allTrksOk = true
        userId = wbJobEntity.context['userId']
        previousDb = nil
        # Check1: All tracks must come from the same db
        inputs.each { |input|
          if(!previousDb.nil?)
            if(@dbApiHelper.extractPureUri(input) != previousDb)
              allDbsOk = false
              break
            end
          end
          if(@trkApiHelper.isHdhv?(input, @hostAuthMap))
            allTrksOk = false
            break
          end
          previousDb = @dbApiHelper.extractPureUri(input)
        }
        unless(allDbsOk)
          wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: All tracks MUST come from the same database. "
        else
          unless(allTrksOk)
            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Tabular view cannot be created for high density score tracks."
          else
            rulesSatisfied = true
          end
        end
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings)) # No Settings to verify for now

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
