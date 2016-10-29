require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'uri'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/tools/workbenchJobHelper'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class DESeq2JobHelper < WorkbenchJobHelper

    TOOL_ID = 'DESeq2'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "DESeq2Wrapper.rb"
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
        cmd = "#{commandName} -j ./#{@genbConf.gbJobJSONFile}"
      else
        msg = "ERROR: The #{TOOL_NAME} cluster analysis tool requires a cluster to run."
        $stderr.puts msg
        @workbenchJobObj = workbenchJobObj
        # Add errors to the context so they can be displayed to user
        @workbenchJobObj.context['wbErrorName'] = :'Internal Server Error'
        @workbenchJobObj.context['wbErrorMsg'] = msg
        success = false
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

    # INTERFACE METHOD. Returns an Array of commands that should be run very early in
    # the tool pipeline. These will be executed directly from the pbs file.
    # - They will run after the scratch dir is made and the job file sync'd over.
    # - Therefore suitable for global module load/swap commands that may set/change
    #   key env-variables (which will then need fixing)
    #
    # These are added to Job#preCommands at/near the top.
    #
    # Example, say you need to swap in a new jdk and thus want the $SITE_JARS updated
    # correctly depending on the environment. Return this:
    #
    #   [
    #     "module swap jdk/1.6"
    #   ]
    def preCmds()
      currentModule = ""
      # If we're launching this job from the exRNA Atlas, we'll use the atlasVersion variable
      # to figure out whether we want to use the 3rd or 4th gen module.
      # If we aren't launching the job from the atlas, we'll just use the 4th gen module.
      if(@workbenchJobObj.settings["atlasVersion"])
        if(@workbenchJobObj.settings["atlasVersion"] == "v4")
          currentModule = "exceRptPipeline/4_prod"
        elsif(@workbenchJobObj.settings["atlasVersion"] == "v3")
          currentModule = "exceRptPipeline/3_prod_alt"
        end
      else
        currentModule = "exceRptPipeline/4_prod"
      end
      return [
        "module load gcc/4.9.2",
        "module load #{currentModule}"
      ]
    end

   def postCmds()
      return ["fileApiTransfer.rb #{@userId} ./jobFile.json #{CGI.escape(@jobFileCopyUriPaths)}"]
    end

    # INTERFACE METHOD. Returns a Hash with various special job directives
    # or nil if there are none (basic/simple cluster job). In this tool,
    # ppn, nodes, mem, vmem, etc, are determined dynamically based
    # on user selected option. If user selects exogenous mapping to both miRNA and genomes, 
    # which uses STAR mapping, then set mem/vmem to 100GB. Else, set mem/vmem to 124GB
    # @return [Hash] with one or more key-values for @:ppn@, @:nodes@, @:pvmem@
    def directives()
      directives = super()
      runPostProcessingTool = workbenchJobObj.settings['runPostProcessingTool']
      if(runPostProcessingTool)
        directives[:mem] = "60gb"
        directives[:vmem] = "60gb"
        directives[:ppn] = 1
        $stderr.puts "runPostProcessingTool: #{runPostProcessingTool} ==> New Directives: #{directives.inspect}"
      end
      return directives
    end

    # We override the configQueue method so that we can submit exogenous mapping jobs to a different queue (gbLowParallel) from other jobs (gbMultiCore)
    # We do this in order to keep a solid limit on how many exogenous mapping jobs can run at a given time (4, currently) so that they don't overrun all
    # of our available high capacity nodes.
    def configQueue(workbenchJobObj)
      super(workbenchJobObj)
      runPostProcessingTool = workbenchJobObj.settings['runPostProcessingTool']
      if(runPostProcessingTool)
        workbenchJobObj.context['queue'] = "gbRamHeavy"
      end
      return workbenchJobObj.context['queue']
    end

   # Casts certain args to the tool to integer
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj) 
      super(workbenchJobObj)
      output = workbenchJobObj.outputs[0]
      workbenchJobObj.outputs[0] = @dbApiHelper.extractPureUri(output)
      settings = workbenchJobObj.settings
      group = @grpApiHelper.extractName(output)
      db = @dbApiHelper.extractName(output)
      analysisName = settings['analysisName']
      @toolVersion = @toolConf.getSetting('info', 'version')
      workbenchJobObj.settings['toolVersion'] = @toolVersion
      uri = URI.parse(output)
      # Set path for jobFile.json on the basis of whether we have a remote storage area being used or not
      workbenchJobObj.settings['remoteStorageArea'] = nil if(workbenchJobObj.settings['remoteStorageArea'] == "None Selected")
      remoteStorageArea = workbenchJobObj.settings['remoteStorageArea']
      unless(remoteStorageArea)
        @jobFileCopyUriPaths << "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/DESeq2_v#{@toolVersion}/#{CGI.escape(analysisName)}/jobFile.json/data?"
      else
        @jobFileCopyUriPaths << "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/#{remoteStorageArea}/DESeq2_v#{@toolVersion}/#{CGI.escape(analysisName)}/jobFile.json/data?"
      end
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools