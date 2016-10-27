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
  class UploadDbFileJobHelper < WorkbenchJobHelper

    TOOL_ID = 'uploadDbFile'

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

    # INTERFACE METHOD. Rarely need to override this implementation.
    #
    # *However*, tools that _dynamically_ determine the @toolType@ based on
    # user settings and/or number/type of inputs should override this
    # method. In such cases, overriding this method is sufficient and overriding
    # {#configQueue} is _not needed_.
    #
    # This implementation overrides the default and determines @toolType@ using some fields in the
    # @settings@ section
    # @param [BRL::Genboree::REST::Data::WorkbenchJobEntity] workbenchJobObj The job object, which
    #   can be used to help dynamically determine correct toolType in tools that need to do so.
    # @return [String] the appropriate @toolType@
    def configToolType(workbenchJobObj)
      toolType = "utilityJob"
      if(workbenchJobObj.settings)
        doUnpack  = workbenchJobObj.settings['unpack']
        doConvert = workbenchJobObj.settings['convToUnix']
        if(doUnpack or doConvert)
          toolType = 'gbToolJob'
        end
      end
      return toolType
    end

    def runInProcess()
      # add a description if it is set
      description = @workbenchJobObj.settings['description']
      if(description)
        input = @workbenchJobObj.inputs[0]
        uri = URI(input)
        rsrcPath = "#{uri.path}/description?"
        apiCaller = ApiCaller.new(uri.host, rsrcPath, @hostAuthMap)
        apiCaller.put(JSON({'data' => {'text' => description}}))
      end
      # rest of work is done by the js side (AJAX is used to transfer the file over to the target folder)
      return true
    end

    def cleanJobObj(workbenchJobObj)
      if(workbenchJobObj.settings['unpack'] and workbenchJobObj.settings['unpack'] == 'on')
        workbenchJobObj.settings['unpack'] = true
      end
      if(workbenchJobObj.settings['convToUnix'] and workbenchJobObj.settings['convToUnix'] == 'on')
        workbenchJobObj.settings['convToUnix'] = true
      end
      # Remove outputs from configuration
      workbenchJobObj.outputs = []
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
