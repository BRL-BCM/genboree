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
  class AddNewUserJobHelper < WorkbenchJobHelper

    TOOL_ID = 'addNewUser'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      fName = @workbenchJobObj.settings['fName']
      lName = @workbenchJobObj.settings['lName']
      email = @workbenchJobObj.settings['email']
      institution = @workbenchJobObj.settings['institution']
      role = @workbenchJobObj.settings['role']
      targetGrp = @grpApiHelper.extractName(@workbenchJobObj.outputs[0])
      warningsSelectRadioBtn = @workbenchJobObj.settings['warningsSelectRadioBtn']
      login = nil
      begin
        # Nothing matched (or the user was not satisfied with the list of current users). Enter a record into 'genboreeuser', create user's default group and add user to requested group
        if(warningsSelectRadioBtn.nil? or warningsSelectRadioBtn.empty? or warningsSelectRadioBtn == 'none')
          iter = 0
          userEntered = false
          while(!userEntered)
            if(iter == 0)
              login = email.split("@")[0]
            elsif(iter == 1)
              login = "#{fName}_#{lName}"
            else
              login = "#{email.split("@")[0]}_#{iter}"
            end
            # See if the login exists
            userRecs = @dbu.getUserByName(login)
            # No such login exists. We can use this
            if(userRecs.nil? or userRecs.empty?)
              # Insert user record
              @dbu.insertUserRec(login, String.generateUniqueString().xorDigest(), fName, lName, institution, email, phone='')
              userEntered = true
            end
            iter += 1
          end
          # Make user's default group
          baseGroup = "#{login}_group"
          groupIter = 0
          groupEntered = false
          groupId = nil
          while(!groupEntered)
            groupName = ( groupIter == 0 ? baseGroup : "#{baseGroup}_#{groupIter}" )
            groupRecs = @dbu.selectGroupByName(groupName)
            if(groupRecs.nil? or groupRecs.empty?)
              @dbu.insertGroup(groupName, groupDescription='')
              groupRecs = @dbu.selectGroupByName(groupName)
              groupId = groupRecs.first['groupId']
              groupEntered = true
            end
            groupIter += 1
          end
          # Link user to default group
          userId = @dbu.getUserByName(login).first['userId']
          @dbu.insertUserIntoGroupById(userId, groupId, 'o')
          # Add user to requested group
          grpRecs = @dbu.selectGroupByName(targetGrp)
          @dbu.insertUserIntoGroupById(userId, grpRecs.first['groupId'], role)
          # Send email to newly registered user:
          emailer = BRL::Util::Emailer.new(@genbConf.gbSmtpHost)
          emailer.addRecipient(@genbConf.gbAdminEmail)
          emailer.addRecipient(email)
          emailer.setHeaders(@genbConf.gbAdminEmail, email, "Genboree: New Genboree registration for #{fName} #{lName}")
          emailer.setMailFrom(@genbConf.gbAdminEmail)
          emailBody = "\nDear #{fName} #{lName},\n"
          emailBody << "You have been added to the Genboree group '#{grpRecs.first['groupName']}'\n"
          emailBody << "at http://#{URI.parse(@workbenchJobObj.outputs[0]).host} by #{@workbenchJobObj.context['userFirstName']} #{@workbenchJobObj.context['userLastName']}.\n\n"
          emailBody << "Your Genboree login name which was\n"
          emailBody << "added to the group is '#{login}'.\n\n"
          emailBody << "If you do not know your password, please use the\n"
          emailBody << "'Forgot your password?' feature to obtain it.\n\n"
          emailBody << "Once logged into http://#{URI.parse(@workbenchJobObj.outputs[0]).host}, you can change\n"
          emailBody << "your password by clicking \"My Profile\" -> \"Change Password\".\n\n"
          emailBody << "Regards,\nThe Genboree team\n"
          emailer.setBody(emailBody)
          emailer.send()
        else # The user selected a current user to be added to the group
          login = warningsSelectRadioBtn.dup()
          userId = @dbu.getUserByName(login).first['userId']
          # Add user to requested group
          grpRecs = @dbu.selectGroupByName(targetGrp)
          @dbu.insertUserIntoGroupById(userId, grpRecs.first['groupId'], role)
        end
        @workbenchJobObj.context['wbStatusMsg'] = "The user: '#{login}' has been added to the group."
      rescue => err
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = "INTERNAL_SERVER_ERROR: #{err.message}"
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
