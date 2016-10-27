require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'uri'
require 'brl/util/emailer'
require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class RequestFeatureJobHelper < WorkbenchJobHelper

    TOOL_ID = 'requestFeature'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      emailFrom = @workbenchJobObj.settings['userEmail'] ? @workbenchJobObj.settings['userEmail'] : @workbenchJobObj.context['userEmail']
      emailer = BRL::Util::Emailer.new(@genbConf.gbSmtpHost)
      emailer.addRecipient(@genbConf.gbAdminEmail)
      # Add all Bccs
      bccList = @genbConf.requestFeatureBccAddress
      if(bccList.is_a?(Array))
        bccList.each { |email|
          emailer.addRecipient(email)
        }
      else
        emailer.addRecipient(bccList)
      end
      emailer.setHeaders(emailFrom, @genbConf.gbAdminEmail, "Genboree: Feature Request")
      emailer.setMailFrom(emailFrom)
      emailBody = "\nUSER:  #{@workbenchJobObj.context['userFirstName']} #{@workbenchJobObj.context['userLastName']}\n"
      emailBody << "EMAIL:  #{emailFrom}\n\n"
      emailBody << "USER MESSAGE:\n\n#{@workbenchJobObj.settings['requestText']}\n"
      emailer.setBody(emailBody)
      # Try to validate the email first before sending
      if(!BRL::Util::Emailer.validateEmail(emailFrom))
        @workbenchJobObj.context['wbErrorMsg'] = "INVALID_EMAIL: The email you entered does not seem to be a valid email id. Please enter another valid email id. "
        success = false
      else
        emailer.send()
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
