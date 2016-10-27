require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class CoverageJobHelper < WorkbenchJobHelper

    TOOL_ID = 'coverage'


    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "coverageWrapper.rb"
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

    # INTERFACE METHOD. Returns an Array of any additional exports that need to appear in the
    # cluster .pbs file. They appear just before the call to "commandWrapper.rb". i.e. AFTER
    # the appropriate env location variables have been set.
    # - By default, empty; no extra exports
    def exports()
      return [
        "export CLASSPATH=$SITE_JARS/GDASServlet.jar:$SITE_JARS/servlet-api.jar:$SITE_JARS/mysql-connector-java.jar:$SITE_JARS/mail.jar"
      ]
    end

    # Cleans the workbench job object
    # Can be overwritten for a specific tool by the child class
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      # Need to make sure to invert the meaning of the "noStrandForSorting" checkbox
      # - right now if CHECKED it means the USER is ENABLING the strand separation feature (easier for users to understand)
      # - but in the json this setting means DISABLE the default separation feature
      # - so need to invert this by:
      #   - if setting is present, then box is checked (value will be "on" or something and user DOES want to separate)
      #     . delete setting
      #   - if setting is missing, then box is not checked (user DOES NOT want to separate)
      #     . add noStrandForSorting=on
      settings = workbenchJobObj.settings
      if(settings.key?('noStrandForSorting'))
        settings.delete('noStrandForSorting')
      else # missing
        settings['noStrandForSorting'] = 'on'
      end
      return workbenchJobObj
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
