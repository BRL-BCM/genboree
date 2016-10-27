require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/dbUtil'

module BRL ; module Genboree ; module Tools
  class SamplesImporterJobHelper < WorkbenchJobHelper

    TOOL_ID = 'samplesImporter'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "samplesImporter.rb"
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
    def buildCmd(useCluster=false)
      cmd = ''
      commandName = self.class.commandName
      raise NoMethodError.new("FATAL INTERNAL ERROR: Must have a commandName class instance variable in child class or buildCmd() should be overridden by child class if parent/default executionCallback is used.") if(commandName.nil?)
      if(useCluster)
        cmd = "#{commandName} -j ./#{@genbConf.gbJobJSONFile} "
      else
        cmd = "#{commandName} -j #{@workbenchJobObj.context['scratchDir']}/#{@genbConf.gbJobJSONFile} > #{@workbenchJobObj.context['scratchDir']}/#{commandName}.out 2> #{@workbenchJobObj.context['scratchDir']}/#{commandName}.err"
      end
      return cmd
    end

    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
