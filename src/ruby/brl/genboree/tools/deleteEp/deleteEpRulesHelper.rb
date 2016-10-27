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
  class DeleteEpRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'deleteEp'

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
      # ------------------------------------------------------------------
      # CHECK SETTINGS
      # ------------------------------------------------------------------
      if(sectionsToSatisfy.include?(:settings))
        # Check 1 :settings together with info from :outputs :
        unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
          raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
        end

        ## Select at least one entrypoint 
        selectedEp = false
        settings = wbJobEntity.settings
        baseWidget = settings['baseWidget']
        settings.keys.each{ |key|
          if(key =~ /#{baseWidget}/)
            selectedEp = true
            break
          end
        }
        unless(selectedEp)
          errorMsg = "INVALID SELECTION: You should select at least one entrypoint to delete."
          wbJobEntity.context['wbErrorMsg'] = errorMsg
          rulesSatisfied = false
        else
          rulesSatisfied = true
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
        warningsExist = true
        wbJobEntity.context['wbErrorMsg'] = "This will permanently delete the selected entrypoints/chromosomes."
      end
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
