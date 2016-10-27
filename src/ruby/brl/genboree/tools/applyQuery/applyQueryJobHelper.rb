require 'json'
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class ApplyQueryJobHelper < WorkbenchJobHelper

    TOOL_ID = 'applyQuery'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "#{@genbConf.toolScriptPrefix}queryCoordinator.rb"
    end

    # To apply a query, we need to properly build the command. The super class will
    # handle executionCallback and properly wrapping it in an TaskWrapper
    def buildCmd()
      # First do validation to make sure we have all the necessary parameters
      if(@workbenchJobObj.settings['targetGroup'].nil? or @workbenchJobObj.settings['targetGroup'].empty? or
         @workbenchJobObj.settings['targetDb'].nil? or @workbenchJobObj.settings['targetDb'].empty? or
         @workbenchJobObj.settings['queryUri'].nil? or @workbenchJobObj.settings['queryUri'].empty? or
         @workbenchJobObj.settings['targetUri'].nil? or @workbenchJobObj.settings['targetUri'].empty? or
         @workbenchJobObj.context['userLogin'].nil? or @workbenchJobObj.context['userLogin'].empty? or
         @workbenchJobObj.context['userEmail'].nil? or @workbenchJobObj.context['userEmail'].empty? or
         @genbConf.dbrcKey.nil? or @genbConf.dbrcKey.empty?)

        raise ArgumentError.new("Required arguments are missing! ")
      end

      opts = {}
      # Note: We need to double URL escape URI things because GetOptLong
      # (in queryCoordinator) will unescape command line params
      targetGroup = Rack::Utils.escape(@workbenchJobObj.settings['targetGroup'])
      targetDb = Rack::Utils.escape(@workbenchJobObj.settings['targetDb'])
      opts['queryURI'] = Rack::Utils.escape(@workbenchJobObj.settings['queryUri'])
      opts['targetURI'] = Rack::Utils.escape(@workbenchJobObj.settings['targetUri'])
      opts['saveGroup'] = targetGroup
      opts['saveDb'] = targetDb
      opts['userLogin'] = @workbenchJobObj.context['userLogin']
      opts['userEmail'] = @workbenchJobObj.context['userEmail']
      opts['dbrcKey'] = @genbConf.dbrcKey
      opts['dataPath'] = Rack::Utils.escape("#{@genbConf.gbDataFileRoot}/grp/#{targetGroup}/db/#{targetDb}/queryResults/")
      debugLog = File.join(@workbenchJobObj.context['scratchDir'], 'queryCoordinator.debug')

      cmdArgs = ['-o', "'#{JSON.generate(opts)}'", '-j', @workbenchJobObj.context['jobId'], '-l', debugLog]
      return "#{self.class.commandName} #{cmdArgs.join(' ')} "
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
