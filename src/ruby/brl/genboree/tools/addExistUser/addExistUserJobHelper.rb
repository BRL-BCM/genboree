require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'uri'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class AddExistUserJobHelper < WorkbenchJobHelper

    TOOL_ID = 'addExistUser'


    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      userToAdd = @workbenchJobObj.settings['userId']
      groupId = @workbenchJobObj.settings['groupId']
      role = @workbenchJobObj.settings['role']
      warningsSelectRadioBtn = @workbenchJobObj.settings['warningsSelectRadioBtn']
      if(!warningsSelectRadioBtn.nil? and !warningsSelectRadioBtn.empty?)
        login = warningsSelectRadioBtn.dup()
        userToAdd = @dbu.getUserByName(login).first['userId']
      end
      rowsChanged = @dbu.insertMultiUsersIntoGroupById([userToAdd], groupId, role)
      login = @dbu.getUserByUserId(userToAdd).first['name']
      if(rowsChanged.nil? or rowsChanged < 1)
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = "INTERNAL_SERVER_ERROR: Could not add user: #{userToAdd} to group: #{groupId} with role: #{role}"
      else
        @workbenchJobObj.context['wbStatusMsg'] = "The user: '#{login}' has been added to the group."
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
