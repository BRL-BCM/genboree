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
  class CopyUsersJobHelper < WorkbenchJobHelper

    TOOL_ID = 'copyUsers'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      settings = @workbenchJobObj.settings
      baseWidget = settings['baseWidget']
      begin
        groupId = @dbu.selectGroupByName(@grpApiHelper.extractName(@workbenchJobObj.outputs[0])).first['groupId']
        usersInGroup = @dbu.getUsersWithRolesByGroupId(groupId, orderBy='')
        userHash = {}
        usersInGroup.each { |userRec|
          userHash[userRec['userId'].to_i] = userRec['userGroupAccess']
        }
        # Match the settings ending with 'checkToCopy' and 'targetRole' based on userId and copy those users over with the selected role
        # If user exists in the target db, do an update if role is different than what is already set.
        settings.each_key { |key|
          if(key =~ /checkToCopy$/)
            if(settings[key] and settings[key] == 'on')
              userId = key.split("|")[1]
              role = settings["userRecsList|#{userId}|targetRole"]
              if(userHash.key?(userId.to_i))
                if(role != userHash[userId])
                  @dbu.updateAccessByUserIdAndGroupId(userId, groupId, role)
                end
              else
                #$stderr.puts("userId: #{userId.inspect}; role: #{role.inspect}")
                rowsChanged = @dbu.insertMultiUsersIntoGroupById([userId], groupId, role)
              end
            end
          end
        }
      rescue => err
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = "INTERNAL SERVER ERROR: #{err.message}"
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
