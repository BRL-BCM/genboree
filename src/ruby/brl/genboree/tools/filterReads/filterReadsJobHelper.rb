require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class FilterReadsJobHelper < WorkbenchJobHelper

    TOOL_ID = 'filterReads'


    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "filterReadsWrapper.rb"
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

    # Casts certain args to the tool to integer
    # Also converts /files url to db if required
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      # Convert files/ to db (if required)
      output = workbenchJobObj.outputs[0]
      workbenchJobObj.outputs[0] = @dbApiHelper.extractPureUri(output)
      # Change the integer type values to int from string so that json file will not have quotes
      maxReadLength = workbenchJobObj.settings['maxReadLength'].to_s
      workbenchJobObj.settings['maxReadLength'] = maxReadLength.empty? ? 6_000_000_000 : maxReadLength.to_i
      minReadLength = workbenchJobObj.settings['minReadLength'].to_s
      workbenchJobObj.settings['minReadLength'] = minReadLength.empty? ? 0 : minReadLength.to_i
      adaptorSeq = workbenchJobObj.settings['adaptorSequences'].to_s
      workbenchJobObj.settings['adaptorSequences'] = adaptorSeq.empty? ? "%" : adaptorSeq
      # Change 'trimHomoPolymer' to boolean true or false
      trimHomoPolymer = workbenchJobObj.settings['trimHomoPolymer']
      if(trimHomoPolymer)
        workbenchJobObj.settings['trimHomoPolymer'] = true
        workbenchJobObj.settings['maxHomoPolymer'] = workbenchJobObj.settings['maxHomoPolymer'].to_i
      else
        workbenchJobObj.settings['trimHomoPolymer'] = false
        workbenchJobObj.settings['maxHomoPolymer'] = 6_000_000_000
      end
      workbenchJobObj.settings['minReadOccurance'] = workbenchJobObj.settings['minReadOccurance'].to_i if(!workbenchJobObj.settings['minReadOccurance'].nil? and !workbenchJobObj.settings['minReadOccurance'].empty?)
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
