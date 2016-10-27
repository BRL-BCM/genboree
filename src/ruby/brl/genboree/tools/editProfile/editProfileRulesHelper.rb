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
  class EditProfileRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'editProfile'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      # No inputs/outputs for this tool.
      # ------------------------------------------------------------------
      # CHECK SETTINGS
      # ------------------------------------------------------------------
      if(sectionsToSatisfy.include?(:settings))
        # Check :settings together with info from :outputs :
        if(!BRL::Util::Emailer.validateEmail(wbJobEntity.settings['email']))
          wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The email address is not valid. Please provide a valid email address"
          rulesSatisfied = false
        else
          # Login should not be already taken
          login = wbJobEntity.settings['login'].strip
          if(login != wbJobEntity.context['userLogin'])
            userRecs = @dbu.getUserByName(login)
            if(!userRecs.nil? and !userRecs.empty?)
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The user name: #{login} is already taken. "
              rulesSatisfied = false
            end
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
