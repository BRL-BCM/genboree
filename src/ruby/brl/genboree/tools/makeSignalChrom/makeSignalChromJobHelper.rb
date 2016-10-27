require 'uri'
require 'json'
require 'brl/util/util'
require "brl/db/dbrc"
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/helpers/fileApiUriHelper'

module BRL ; module Genboree ; module Tools
  class MakeSignalChromJobHelper < WorkbenchJobHelper

    TOOL_ID = 'makeSignalChrom'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "makeSignalChromWrapper.rb"
    end

    def preCmds()
      return [ "module load makeSignalChrom/1.2",
               "module load ChromHMM/1.1" 
             ]
    end
    def postCmds()
      return ["fileApiTransfer.rb #{@userId} ./jobFile.json #{CGI.escape(@jobFileCopyUriPaths)}"]
    end
    # This is where the command is defined
    #
    # WARNING: Be careful when building a command to be executed.
    # Any command line option values must be properly escaped.
    #
    # For example: someone submitted a var @settings['foo'] = ';rm -dfr /'
    # and then you build a command without escaping
    # "myCommand.rb -n #{foo}"  =>  myCommand.rb -n ;rm -dfr /
    # The correct way to do this is using CGI.escape()
    # "myCommand.rb -n #{CGI.escape(foo)}"  =>  myCommand.rb -n %3Brm%20-dfr%20%2F
    #
    # [+returns+] string: the command
    def buildCmd(useCluster=true)
      cmd = ''
      commandName = self.class.commandName
      $stderr.puts "commandName: #{commandName.inspect}"
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
      end
      return cmd
    end

    # Casts certain args to the tool to integer
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      output = workbenchJobObj.outputs[0]
      workbenchJobObj.outputs[0] = @dbApiHelper.extractPureUri(output)
      group = @grpApiHelper.extractName(output)
      db = @dbApiHelper.extractName(output)
      uri = URI.parse(output)
      analysisName = workbenchJobObj.settings['analysisName']
      @jobFileCopyUriPaths << "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/FindERChromHMM%20-%20Results/#{CGI.escape(analysisName)}/jobFile.json/data?"
      
      #Delete unwanted settings
      settings = workbenchJobObj.settings
      settings.delete('multiSelectInputList')
      settings.delete('toggleMultiSelectListButton')
      settings.delete('gridFields')
      settings.delete('gridRecs')
      settings.delete('gridRowUriMap')
      settings.delete('sampleRowUriMap')
      settings.delete('sampleEditHash')
      settings.delete('sampleAttributeRemoveHash')
      settings.delete('btnType') 
      settings.delete('selectedtrks')    
      #$stderr.debugPuts(__FILE__, __method__, "workbenchJobObj:", "#{workbenchJobObj.inspect}")
 
      return workbenchJobObj
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
