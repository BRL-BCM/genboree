require 'json'
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require "brl/genboree/tools/workbenchJobHelper"
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/abstract/resources/databaseFiles"
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class ProcessFileJobHelper < WorkbenchJobHelper

    TOOL_ID = 'processFile'


    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "postProcessFiles.rb"
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

    def runInProcess()
      # All the work is done by the js side
      return true
    end

    def cleanJobObj(workbenchJobObj)
      if(workbenchJobObj.settings['unpack'] and workbenchJobObj.settings['unpack'] == 'on')
        workbenchJobObj.settings['unpack'] = true
      end
      if(workbenchJobObj.settings['convToUnix'] and workbenchJobObj.settings['convToUnix'] == 'on')
        workbenchJobObj.settings['convToUnix'] = true
      end
      # Normalize all inputs to files
      newInputs = []
      workbenchJobObj.inputs.each {|input|
        if(input !~  /\/files\/entityList\//)
          newInputs << input
        else
          uriObj = URI.parse(input)
          apiCaller = ApiCaller.new(uriObj.host, uriObj.path, @hostAuthMap)
          apiCaller.get()
          resp = apiCaller.parseRespBody()['data']
          resp.each {|fileUri|
            newInputs << fileUri['url']
          }
        end
      }
      workbenchJobObj.inputs = newInputs
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
