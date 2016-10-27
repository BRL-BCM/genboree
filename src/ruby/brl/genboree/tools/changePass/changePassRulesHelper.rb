require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/util/emailer'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class ChangePassRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'changePass'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      # No inputs/outputs for this tool.
      # ------------------------------------------------------------------
      # CHECK SETTINGS
      # ------------------------------------------------------------------
      if(sectionsToSatisfy.include?(:settings))
        # Check 1: the old password entered should match what is set
        oldPass = wbJobEntity.settings['oldPass'].strip
        userRecs = @dbu.getUserByUserId(wbJobEntity.context['userId'])
        if(userRecs.first['password'] != oldPass)
          rulesSatisfied = false
          wbJobEntity.context['wbErrorMsg'] = "INVALID_PASSWORD: The old password you entered is not correct."
        else
          # Check 2: The new passwords should be same and at least 6 chars
          newPass = wbJobEntity.settings['newPass'].strip
          newPass2 = wbJobEntity.settings['newPass2'].strip
          if(newPass != newPass2 or newPass.size < 6)
            rulesSatisfied = false
            wbJobEntity.context['wbErrorMsg'] = "INVALID_PASSWORD: Both new passwords must match and have at least 6 characters."
          end
        end
      end
      return rulesSatisfied
    end

    # Override lack of warnings to notify the user that they
    # (1) will be logged out upon job accept and
    # (2) will need to change their password for remote hosts where they have registered this host
    def warningsExist?(wbJobEntity)
      retVal = false
      if(wbJobEntity.context.key?("warningsConfirmed"))
        retVal = false
      else
        # then the user has not confirmed (or seen) this warning yet, display it
        wbJobEntity.context["wbErrorMsg"] = "After changing your password you will be forced "\
          "to log out. You will also need to update your account information at any remote "\
          "Genboree instances where you have registered this host."
        retVal = true
      end
      return retVal
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
