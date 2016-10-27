require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require "brl/genboree/tools/workbenchJobHelper"
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/abstract/resources/databaseFiles"

module BRL ; module Genboree ; module Tools
  class FtpFileProcessorJobHelper < WorkbenchJobHelper

    TOOL_ID = 'ftpFileProcessor'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "ftpFileProcessor.rb"
    end

    def buildCmd(useCluster=true)
      cmd = ''
      commandName = self.class.commandName
      raise NoMethodError.new("FATAL INTERNAL ERROR: Must have a commandName class instance variable in child class or buildCmd() should be overridden by child class if parent/default executionCallback is used.") if(commandName.nil?)
      if(useCluster)
        cmd = "#{commandName} -j ./#{@genbConf.gbJobJSONFile} "
      else
        msg = "ERROR: The #{TOOL_NAME} cluster analysis tool requires a cluster to run."
        $stderr.puts msg
        @workbenchJobObj = workbenchJobObj
        # Add errors to the context so they can be display to user
        @workbenchJobObj.context['wbErrorName'] = :'Internal Server Error'
        @workbenchJobObj.context['wbErrorMsg'] = msg
        success = false
      end
      return cmd
    end

    def cleanJobObj(workbenchJobObj)
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
