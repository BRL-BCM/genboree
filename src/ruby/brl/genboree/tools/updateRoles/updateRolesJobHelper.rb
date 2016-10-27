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
  class UpdateRolesJobHelper < WorkbenchJobHelper

    TOOL_ID = 'updateRoles'

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
        # Loop pver settings and extract settings that start with the baseWidget
        settings.each_key { |key|
          if(key =~ /^#{baseWidget}/)
            userId = key.split("|")[1]
            access = settings[key]
            if(access == 'x') # Remove user from group
              @dbu.deleteUserFromGroup(userId, groupId)
            else # Update role
              @dbu.updateAccessByUserIdAndGroupId(userId, groupId, access)
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
