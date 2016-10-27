require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'uri'
require 'brl/util/emailer'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class MessageGroupJobHelper < WorkbenchJobHelper

    TOOL_ID = 'messageGroup'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      messageBody = @workbenchJobObj.settings['messageBody']
      subject = @workbenchJobObj.settings['subject']
      uriObj = URI.parse(@workbenchJobObj.outputs[0])
      groupName = @grpApiHelper.extractName(@workbenchJobObj.outputs[0])
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path}/usrs?detailed=true", @userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      usersInGroup = apiCaller.parseRespBody['data']
      emailer = BRL::Util::Emailer.new(@genbConf.gbSmtpHost)
      # Collect the list of emails to send the message to
      usersInGroup.each { |userRec|
        emailer.addRecipient(userRec['email'])
      }
      emailer.setHeaders(@workbenchJobObj.context['userEmail'], @genbConf.gbAdminEmail, "Genboree: Message To Group: #{subject}")
      emailer.setMailFrom(@workbenchJobObj.context['userEmail'])
      emailBody = "Group: #{groupName}\n\nHost: #{uriObj.host}\n\nMessage:\n"
      emailBody << messageBody
      emailBody << "\n\n*** If you want to reply to this email, please use the following address:\n"
      emailBody << "#{@workbenchJobObj.context['userFirstName']} #{@workbenchJobObj.context['userLastName']} <#{@workbenchJobObj.context['userEmail']}>"
      emailer.setBody(emailBody)
      emailer.send()
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
