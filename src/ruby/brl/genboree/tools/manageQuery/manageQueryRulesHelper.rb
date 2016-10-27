require 'brl/genboree/tools/workbenchRulesHelper'

module BRL ; module Genboree ; module Tools

  class ManageQueryRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'manageQuery'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # CODE FOR TESTING
      # Rather than change the rules for applyQuery, we use this custom loader to

      # NO, NO, NO. CHange rules file. Do not hide validly loaded rules with secret changes in code.

      return super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      #return true
    end
  end
end; end; end
