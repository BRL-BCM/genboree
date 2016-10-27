require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'

module BRL ; module Genboree ; module Tools
  class CopyTracksRulesHelper < WorkbenchRulesHelper

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      # Input track can not be in the same database as the output database
      outputDbName = BRL::Genboree::Tools::WorkbenchFormHelper.getNameFromURI('db', wbJobEntity.outputs.first)
      wbJobEntity.inputs.each { |inputTrk|
        inputTrkName = BRL::Genboree::Tools::WorkbenchFormHelper.getNameFromURI('trk', inputTrk)
        inputDbName = BRL::Genboree::Tools::WorkbenchFormHelper.getNameFromURI('db', inputTrk)
        if(inputDbName == outputDbName)
          wbJobEntity.context['wbErrorMsg'] = "The input track '#{inputTrkName}' can not be copied to the output database '#{outputDbName}' because it is already in this database."
          rulesSatisfied = false
          break
        end
      }
      return rulesSatisfied
    end

    # [+returns+] boolean
    def warningsExist?(wbJobEntity)
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        retVal = false
      else
        # Determin if there are any warnings for this job
        # Does a track with the same name already exist in the destination database
        outputDbName = BRL::Genboree::Tools::WorkbenchFormHelper.getNameFromURI('db', wbJobEntity.outputs.first)
        wbJobEntity.inputs.each{ |inputTrk|
          inputTrkName = BRL::Genboree::Tools::WorkbenchFormHelper.getNameFromURI('trk', inputTrk)
          # TODO: check for track in database

        }
        # Testing always true
        retVal = true
        wbJobEntity.context['wbErrorMsg'] = "Are you sure you want copy this track?"
      end
      return retVal
    end
  end
end ; end end # module BRL ; module Genboree ; module Tools
