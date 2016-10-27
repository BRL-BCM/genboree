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
  class ProcessPipelineRunsJobHelper < WorkbenchJobHelper

    TOOL_ID = 'processPipelineRuns'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "processPipelineRunsWrapper.rb"
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
      # Batch job - we'll use exceRptGen to figure out whether we want to use 3rd or 4th gen module
      if(@workbenchJobObj.settings["exceRptGen"])
        if(@workbenchJobObj.settings["exceRptGen"] == "fourthGen")
          currentModule = "exceRptPipeline/4_prod"
        elsif(@workbenchJobObj.settings["exceRptGen"] == "thirdGen")
          currentModule = "exceRptPipeline/3_prod_alt"
        end
      else
        # Stand-alone job - we'll use inputsVersion (set in RulesHelper) to figure out whether we want to use 3rd or 4th gen module
        if(@workbenchJobObj.settings["inputsVersion"][0].chr == "4")
          currentModule = "exceRptPipeline/4_prod"
        elsif(@workbenchJobObj.settings["inputsVersion"][0].chr == "3")
          currentModule = "exceRptPipeline/3_prod_alt"
        end
      end
      return ["module load #{currentModule}"]
    end

   def postCmds()
      return ["fileApiTransfer.rb #{@userId} ./jobFile.json #{CGI.escape(@jobFileCopyUriPaths)}"]
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
      uri = URI.parse(output)
      # Get the tool version from toolConf
      @toolVersion = @toolConf.getSetting('info', 'version')
      workbenchJobObj.settings['toolVersion'] = @toolVersion
      # The option of "None Selected" from Workbench for remote storage is not a real option.
      workbenchJobObj.settings['remoteStorageArea'] = nil if(workbenchJobObj.settings['remoteStorageArea'] == "None Selected")
      # isRemoteStorage will be true if we have a value for remoteStorageArea (any dummy value like "None Selected" will be eliminated in exceRptPipeline stage)
      isRemoteStorage = true if(workbenchJobObj.settings['remoteStorageArea'])
      # Figure out the value associated with our remote storage area if isRemoteStorage is true
      remoteStorageArea = nil
      if(isRemoteStorage)
        remoteStorageArea = workbenchJobObj.settings['remoteStorageArea']
      end
      # Grab tool version of exceRpt
      toolConfExceRpt = BRL::Genboree::Tools::ToolConf.new('exceRptPipeline', @genbConf)
      toolVersionExceRpt = toolConfExceRpt.getSetting('info', 'version')
      standAloneThirdGenJob = (workbenchJobObj.settings["inputsVersion"][0].chr == "3") rescue nil
      if(workbenchJobObj.settings["exceRptGen"] == "thirdGen" or standAloneThirdGenJob)
        @toolVersion = "3.1.0"
        toolVersionExceRpt = "3.3.0"
      end
      # If we're launching this tool as part of a batch job (as part of the exceRptPipeline / runExceRpt / processPipelineRuns / erccFinalProcessing workflow),
      # then we'll upload to the exceRptPipeline tool area.
      if(workbenchJobObj.settings["isBatchJob"])
        if(remoteStorageArea)
            @jobFileCopyUriPaths = "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/#{CGI.escape(remoteStorageArea)}/exceRptPipeline_v#{toolVersionExceRpt}/#{CGI.escape(analysisName)}/postProcessedResults_v#{@toolVersion}/jobFile.json/data?"
          else
            @jobFileCopyUriPaths = "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/exceRptPipeline_v#{toolVersionExceRpt}/#{CGI.escape(analysisName)}/postProcessedResults_v#{@toolVersion}/jobFile.json/data?"
          end
      else
        # Otherwise, we'll upload the results to the regular postProcessedResults area.
        if(remoteStorageArea)
          @jobFileCopyUriPaths = "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/#{CGI.escape(remoteStorageArea)}/postProcessedResults_v#{@toolVersion}/#{CGI.escape(analysisName)}/jobFile.json/data?"
        else
          @jobFileCopyUriPaths = "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/postProcessedResults_v#{@toolVersion}/#{CGI.escape(analysisName)}/jobFile.json/data?"          
        end
      end
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
