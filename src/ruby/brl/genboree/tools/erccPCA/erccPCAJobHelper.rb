require 'brl/genboree/tools/workbenchJobHelper'

module BRL; module Genboree; module Tools
  class ErccPCAJobHelper < WorkbenchJobHelper
    TOOL_ID = "erccPCA"

    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "erccPCAWrapper.rb"
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
      currentModule = "exceRptPipeline/4_prod"
      return [
        "module load #{currentModule}"
      ]
    end

    # Transfer jobFile.json to user's Database
    def postCmds()
      return ["fileApiTransfer.rb #{@userId} ./jobFile.json #{CGI.escape(@jobFileCopyUriPaths)}"]
    end

    # Casts certain args to the tool to integer
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj) 
      input = workbenchJobObj.inputs
      output = workbenchJobObj.outputs[0]
      workbenchJobObj.outputs[0] = @dbApiHelper.extractPureUri(output)
      group = @grpApiHelper.extractName(output)
      db = @dbApiHelper.extractName(output)
      analysisName = workbenchJobObj.settings['analysisName']
      # isRemoteStorage will be true if we have a value for remoteStorageArea (any dummy value like "None Selected" will be eliminated in exceRptPipeline stage)
      isRemoteStorage = true if(workbenchJobObj.settings['remoteStorageArea'])
      # Figure out the value associated with our remote storage area if isRemoteStorage is true
      remoteStorageArea = nil
      if(isRemoteStorage)
        remoteStorageArea = workbenchJobObj.settings['remoteStorageArea']
      end
      uri = URI.parse(output)
      # Get the tool version of runExceRpt from toolConf
      @toolVersion = @toolConf.getSetting('info', 'version')
      workbenchJobObj.settings['toolVersion'] = @toolVersion
      # Set path for jobFile.json (depending on we're uploading to remote storage area)
      # Currently disabled!
      #if(remoteStorageArea)
      #  @jobFileCopyUriPaths << "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/#{CGI.escape(remoteStorageArea)}/exceRptPipeline_v#{@toolVersion}/#{CGI.escape(analysisName)}/#{sampleForRsrcPath}/jobFile.json/data?"
      #else
      #  @jobFileCopyUriPaths << "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/exceRptPipeline_v#{@toolVersion}/#{CGI.escape(analysisName)}/#{sampleForRsrcPath}/jobFile.json/data?"
      #end
      return workbenchJobObj
    end
  end

end; end; end
