require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class DeleteGroupRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'deleteGroup'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        # Check 1: does user have access to the file
        userId = wbJobEntity.context['userId']
        access = true
        if(!testUserPermissions(inputs[0], 'o'))
          access = false
        end
        unless(access)
          wbJobEntity.context['wbErrorMsg'] = "ACCESS_DENIED: You need admin level access to delete groups."
        else # OK: user can write to input database
          rulesSatisfied = true
        end
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
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
      else
        warningMsg = "The following group is going to be PERMANENTLY deleted with all of its contents:"
        warningMsg << "<ul>"
        warningMsg << "<li>#{@grpApiHelper.extractName(inputs[0])}</li>"
        warningMsg << "</ul>"
        wbJobEntity.context['wbErrorMsg'] = warningMsg
        wbJobEntity.context['wbErrorMsgHasHtml'] = true
      end
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools