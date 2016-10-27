require 'tempfile'
require 'uri'
require 'json'
require 'open4'
require 'fileutils'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/tools/viewHelper'
require 'brl/genboree/tools/accessHelper'
require 'brl/genboree/tools/toolConfHelper'
require 'brl/cluster/clusterJob'
require 'brl/cluster/clusterJobManager'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/prequeue/job'

include BRL::Genboree::REST

# pre define mixin modules to prevent namespace errors with potential circular dependencies
module BRL; module Genboree; module Tools; module ViewHelper; end; end; end; end
module BRL; module Genboree; module Tools; module AccessHelper; end; end; end; end
module BRL; module Genboree; module Tools; module ToolConfHelper; end; end; end; end

module BRL ; module Genboree ; module Tools
  class WorkbenchJobHelper
    # ------------------------------------------------------------------
    # MIXINS - bring in some generic useful methods used here and elsewhere
    # ------------------------------------------------------------------

    include BRL::Genboree::Tools::ViewHelper
    include BRL::Genboree::Tools::AccessHelper
    include BRL::Genboree::Tools::ToolConfHelper

    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------

    TOOL_ID = "[NOT SET]"
    ENV_VARS_FIX_INFO = {
      'RUBYLIB'           => { :multiPaths => true,   :append => true  },
      'DBRC_FILE'         => { :multiPaths => false,  :append => false },
      'DB_ACCESS_FILE'    => { :multiPaths => false,  :append => false },
      'GENB_CONFIG'       => { :multiPaths => false,  :append => false },
      'LD_LIBRARY_PATH'   => { :multiPaths => true,   :append => true  },
      'PATH'              => { :multiPaths => true,   :append => true  },
      'SITE_JARS'         => { :multiPaths => true,   :append => true  },
      'PERL5LIB'          => { :multiPaths => true,   :append => true  },
      'PYTHONPATH'        => { :multiPaths => true,   :append => true  },
      'DOMAIN_ALIAS_FILE' => { :multiPaths => false,  :append => false },
      'R_LIBS_USER'       => { :multiPaths => true,   :append => true  },
      'SNIFFER_CONF_FILE' => { :multiPaths => false,  :append => false },
    }
    ENV_VARS_TO_FIX = ENV_VARS_FIX_INFO.keys

    # ------------------------------------------------------------------
    # CLASS INSTANCE VARIABLES (not class variables)
    # ------------------------------------------------------------------

    # Set the command that will be run (i.e. the command line).
    # - If multiple commands, can join them using " ; ".
    # - Generally used as-is, but if you MUST, you can override buildCmd() to
    #   build more complex sequences of commands or complicated command line calls.
    #   . In this case, you can put the base or prefix (or a template) command string here.
    # - Must be defined in subclass. DO NOT USE CLASS VARIABLES WITH INHERITANCE.
    #   CAN USE "class level instance variables" HOWEVER. THERE IS ONLY ONE (1)
    #   CLASS VARIABLE, EVEN IF INHERITED (i.e. not separate storage, shared storage...many bugs.)
    class << self
      attr_accessor :commandName
      # {yourClassName}.commandName = '{some bach command string}'
    end

    # ------------------------------------------------------------------
    # ACCESSORS
    # ------------------------------------------------------------------
    attr_accessor :genbConf, :workbenchJobObj, :commandName, :localScratchDir, :useTaskWrapperForLocal
    # @return [BRL::Genboree::Tool::ToolConf] a @ToolConf@ instance for this tool.
    attr_accessor :toolConf
    # Array of conf vars to be included in the context
    attr_accessor :genbConfValues
    attr_accessor :rackEnv
    # A DBRC instance targetting the superuser API-oriented DBRC record for this local Genboree instance
    attr_accessor :superuserApiDbrc
    # A DBRC instance targetting the superuser DB-oriented DBRC record for this local Genboree instance
    attr_accessor :superuserDbDbrc
    # A user-specific Hash of canonical address of hostName => [ login, password, recType] where recType is :internal or :external
    attr_accessor :hostAuthMap
    # Api Helper classes
    attr_accessor :dbApiHelper, :fileApiHelper, :sampleApiHelper, :trkApiHelper, :classApiHelper, :sampleSetApiHelper,
                  :grpApiHelper, :prjApiHelper, :trackEntityListApiHelper, :fileEntityListApiHelper, :sampleEntityListApiHelper

    # ------------------------------------------------------------------
    # INSTANCE METHODS
    # ------------------------------------------------------------------

    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      @genbConf = genbConf || BRL::Genboree::GenboreeConfig.load()
      @toolConf = BRL::Genboree::Tools::ToolConf.new(toolIdStr)
      # Get superuser API and DB dbrcs for this host (will be used to look up any per-user API credential info)
      @superuserApiDbrc = @superuserApiDbrc || BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf)
      @superuserDbDbrc = @superuserDbDbrc || BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @genbConf.dbrcFile, :db)
      # User specifc auth map automatically populated from local Genboree's externalHostAccess table.
      @hostAuthMap = nil
      # An instance of WorkbenchJobEntity containing inputs, outputs, context and settings
      @workbenchJobObj = nil
      @toolIdStr = toolIdStr
      @genbConfValues = ['gbAdminEmail']
      self.class.commandName = nil
      @useTaskWrapperForLocal = false
      @dbu = dbu || BRL::Genboree::DBUtil.new(@superuserDbDbrc.key, nil, nil)
      @jobFileCopyUriPaths = "" # Will be used differently now: used in building the command for fileApiTransfer.rb
      @gbEnvSuffix = @genbConf.gbEnvSuffix || ""
      @clusterSharedRoot = @genbConf.clusterSharedRoot || "/cluster.shared"
    end

    # INTERFACE METHOD. Any commands that need to be added in front of
    # self.class.commandName in order for it to run on the command line. Will be used
    # automatically in buildCmd().
    # - e.g. if you need some "module load ____" commands or something first.
    # - Return a single String
    # - If multiple commands, separate with " ; " as usual for bash. Watch your escaping!!!
    #
    # WARNING: you may want to put your module load/swap commands into the beginning of the
    # .pbs file by overriding preCmds() and NOT by using this method. Here is why:
    # - Some module load/swap commands will set ENV variables, overriding any environment
    #   specific env-fixing that's ocurred beforehand.
    # - e.g. module load jdk/1.6
    # - This will override $SITE_JARS to be the production env. *WRONG* if you are running in _test.
    # - You can fix this by doing any module load/swap early on in the pipeline using pbsInitCmds()
    #   and not putting them as part of the command to run.
    # - Cleaner.
    #
    # WARNING: Be careful when building a command to be executed
    # Any command line option values must be properly escaped!
    #
    # For example: someone submitted a var @settings['foo'] = ';rm -dfr /'
    # and then you build a command without escaping
    # "myCommand.rb -n #{foo}"  =>  myCommand.rb -n ;rm -dfr /
    # The correct way to do this is using CGI.escape()
    # "myCommand.rb -n #{CGI.escape(foo)}"  =>  myCommand.rb -n %3Brm%20-dfr%20%2F
    #
    # [+returns+] String: the command prefix.
    def buildCmdPrefix(useCluster=false)
      cmdPrefix = ''
      return cmdPrefix
    end

    # INTERFACE METHOD. This is where the specific command (or command sequence)
    # to be run is built. Generally don't have to override, but it's here just in case.
    # - Uses the aforementioned self.class.commandName in a standard way.
    # - Uses buildCmdPrefix() to add stuff before the actual tool command.
    #   . e.g. if you need some "module load ____" or something first.
    # - A single String is built. If multiple commands, separate with
    #   " ; " as usual for bash. Watch your escaping!!!
    #
    # WARNING: If overriding (why? can you avoid?), be careful when building a command to be executed.
    # Any command line option values must be properly escaped!
    #
    # For example: someone submitted a var @settings['foo'] = ';rm -dfr /'
    # and then you build a command without escaping
    # "myCommand.rb -n #{foo}"  =>  myCommand.rb -n ;rm -dfr /
    # The correct way to do this is using CGI.escape()
    # "myCommand.rb -n #{CGI.escape(foo)}"  =>  myCommand.rb -n %3Brm%20-dfr%20%2F
    #
    # [+returns+] String: the command
    def buildCmd(useCluster=false)
      cmd = ''
      commandName = self.class.commandName
      raise NoMethodError.new("FATAL INTERNAL ERROR: Must have a non-nil non-blank commandName class instance variable in child class or buildCmd() should be overridden by child class if parent/default executionCallback is used.") if(commandName.nil? or commandName !~ /\S/)
      cmdPrefix = buildCmdPrefix(useCluster)
      cmdPrefix.strip!
      if(!cmdPrefix.empty?)
        if(cmdPrefix !~ /;$/)
          cmdPrefix << ';'
        end
      end
      if(useCluster)
        cmd = "#{cmdPrefix}  #{commandName} -j ./#{@genbConf.gbJobJSONFile}"
      else
        cmd = "#{cmdPrefix}  #{commandName} -j #{@workbenchJobObj.context['scratchDir']}/#{@genbConf.gbJobJSONFile} > #{@workbenchJobObj.context['scratchDir']}/#{commandName}.out 2> #{@workbenchJobObj.context['scratchDir']}/#{commandName}.err"
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
    # Default implementation: Just returns the @toolType@ setting from the tool's
    # @info@ section in its config file.
    # @param [BRL::Genboree::REST::Data::WorkbenchJobEntity] workbenchJobObj The job object, which
    #   can be used to help dynamically determine correct toolType in tools that need to do so.
    # @return [String] the appropriate @toolType@
    def configToolType(workbenchJobObj)
      infoConf = @toolConf.getSetting("info")
      toolType = infoConf['toolType']
      return toolType
    end

    # INTERFACE METHOD. Rarely need to override this, as the implementation here
    # will try to ensure @context['queue']@ is correctly set for @utilityJobs@
    # and for @gbToolJobs@ (queue should be already be present, having come from @default.json@ or from
    # the tool's specific config file if set there).
    #
    # *However*, tools that _dynamically_ determine the queue or whether to run immediately
    # or as a cluster job--say based on inputs--should override this and use what is in @workbenchJobObj@
    # to determine the appropriate queue.
    #
    # (Check that you don't just need to override {#configToolType} though. When the tool
    # just needs to dynamically determine @utilityJob@ vs @gbToolJob@, you should override that
    # method, NOT THIS ONE.
    #
    # Default implementation: Sets the appropriate queue value in workbenchJobObj.context['queue'].
    # Uses the tool config to determine if the job even needs a queue (e.g. utility jobs
    # must have queue 'none'.) Also ensures some queue value is present otherwise; minimally
    # this should be picked up from the default.json tool config file [i.e. if tool didn't
    # need to override this setting], but just in case @@genbConf.gbDefaultPrequeueQueue@
    # is used as a fallback.
    # @param [BRL::Genboree::REST::Data::WorkbenchJobEntity] workbenchJobObj The job object whose
    #   @context['queue']@ needs setting.
    # @return [String] the queue value now in @workbenchJobObj@
    def configQueue(workbenchJobObj)
      toolType = configToolType(workbenchJobObj)
      # If this is a "utilityJob", those are done immediately. There is no queue, no matter what.
      if(toolType == 'utilityJob')
        workbenchJobObj.context['queue'] = 'none'
      # Else this is a regular cluster tool job. Need to set the queue appropriately
      elsif(toolType == 'gbToolJob' or toolType == 'pipelineJob')
        queue = @toolConf.getSetting('cluster', 'queue')
        workbenchJobObj.context['queue'] = ((queue and queue =~ /\S/) ? queue : @genbConf.gbDefaultPrequeueQueue)
      end
      return workbenchJobObj.context['queue']
    end

    # INTERFACE METHOD. Returns a Hash with various special job directives
    # or nil if there are none (basic/simple cluster job). Should NOT OVERRIDE
    # in most cases, unless ppn or nodes, etc, are determined dynamically based
    # on inputs or something. Else, default implementation will build this from
    # the tool's config.
    # @return [Hash] with one or more key-values for @:ppn@, @:nodes@, @:pvmem@
    def directives()
      return @toolConf.buildDirectivesHash()
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
      return []
    end

    # INTERFACE METHOD. Returns an Array of command that should be run AFTER
    # the main tool command(s). They will be run after commandsRunner.rb does the tool's
    # commands, but before any standard and final clean up stuff added by the Submitter subclass.
    #
    # For example, jobs that require the jobFile.json be put into the user's output database
    # would do something like this:
    #
    # def postCommands()
    #   escApiDbFileUrl = <<CODE TO examine @workbenchJobObj.outputs and build target URL for jobFile.json>>
    #   return [
    #     "fileApiTransfer.rb --userId=2 --fileName=./jobFile.json --url=#{escApiDbFileUrl}"
    #   }
    # end
    def postCmds()
      return []
    end

    # INTERFACE METHOD. Returns an Array of any additional exports that need to appear in the
    # cluster .pbs file. They appear just before the call to "commandWrapper.rb". i.e. AFTER
    # the appropriate env location variables have been set.
    # - By default, empty; no extra exports
    #
    # These are added to Job#preCommands after the initCmds and after some standard exports are added to that Array.
    #
    # Example: say you need a classpath with some jars. Then return something like this:
    #
    #  [
    #    "export CLASSPATH=$SITE_JARS/GDASServlet.jar:$SITE_JARS/servlet-api.jar:$SITE_JARS/mysql-connector-java.jar:$SITE_JARS/mail.jar"
    #  ]
    def exports()
      return []
    end

    # @note INTERFACE METHOD. Make an Array of job conf/spec Hashes for any dependent jobs
    #   that should be submitted and which [presumably] depend on this one. The Array
    #   of job confs will be used to submit new jobs.
    # @note The job confs should have a "context" section which should have the
    #   "toolIdStr" set to the type of tool job that will be submitted.
    # It is expected, but not required, that the job confs returned will have a
    # "preconditionSet" section with at least 1 precondition: a dependency on THIS job.
    #
    # @param [BRL::Genboree::Prequeue:Job] dependeeJob upon whom the returned job confs
    #   will (presumably) depend.
    # @return [Array<Hash>,nil] containing the job conf/spec Hashes for the depdendent jobs
    #   or nil if none.
    def makeDependentJobConfs(dependeeJob)
      return nil
    end

    # INTERFACE METHOD. Preprossing method to "clean up" the workbench job object
    # Can be overwritten for a specific tool by the child class, in order
    # to remove "junk" in the workbenchJobObj which should not (for cleanliness)
    # be sent to the tool wrapper or which needs to be replaced with something
    # else more useful or something (e.g. expanding resource collections into
    # lists of individual resources, etc).
    #
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      # if special setting 'multiSelectList' is present, use that to overwrite the inputs
      multiSelectList = workbenchJobObj.settings['multiSelectInputList']
      if(multiSelectList)
        workbenchJobObj.inputs = multiSelectList
        workbenchJobObj.settings.delete('multiSelectInputList')
      end
      return workbenchJobObj
    end

    # @abstract To be implemented by sub-classes for tools that can be run QUICKLY within the web server
    #   process; i.e. not put to cluster (local nor 'proper' cluster), not run as a daemon process, but rather 'live'.
    # @note By default this is not implemented and will communicate back an error.
    # @return [Boolean] indicating if the in-process running of the tool succeeded or not.
    def runInProcess()
      # Add errors to the context so they can be display to user
        @workbenchJobObj.context['wbErrorName'] = :'Internal Server Error'
        @workbenchJobObj.context['wbErrorMsg'] = "NOT IMPLEMENTED. Attempted to run this tool job within the web server process, but this tool does not support that functionality--probably for good reason. This is usually due to a mis-configuration of the tool and what kind of cluster or queue it should run on [if any]."
      return false
    end

    # INTERFACE METHOD. Runs a job on the local server rather than on the cluster.
    # This is the default mechanism, which uses settings & methods here to run
    # the local job appropriately. In some RARE cases you will need special things to
    # be done for local jobs, in which case you can override this method. This default
    # will run the local job AS A DAEMON, and thus will return BEFORE the job is done (probably).
    #
    # NOTE: if you want to REFUSE to run the job locally (more and more common, since
    # tools are doing non-trivial, resource-intense things), simply implement override this
    # method like this to reuse an existing method that will do that for you:
    #
    # def runLocalJob()
    #   return refuseLocalJob()
    # end
    #
    # [+returns+] true if launch succeeds, false otherwise
    def runLocalJob(workbenchJobObj, useTaskWrapper=@useTaskWrapperForLocal)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "BEGIN: runLocalJob for #{self.class} [ Note RAM; Note whether using TaskWrapper or runInProcess() ]")
      job = nil
      begin
        # Local execution using taskWrapper
        @workbenchJobObj = fillServerContext(workbenchJobObj)
        # Create Job object for purpose of tracking, but actual operation will happen now and differently than
        # regular non-taskWrapper jobs.
        # Create a BRL::Genboree::Prequeue::Job object from the @workbenchJobObj
        jobConf = {
          'inputs'    => @workbenchJobObj.inputs.dup(),
          'outputs'   => @workbenchJobObj.outputs.dup(),
          'settings'  => @workbenchJobObj.settings.dup(),
          'context'   => @workbenchJobObj.context.dup()
        }
        jobSystemType = useTaskWrapper ? @genbConf.gbTaskWrapperJobSystemType : @genbConf.gbUtilityJobSystemType
        jobType = useTaskWrapper ? @genbConf.gbTaskWrapperJobType : @genbConf.gbUtilityJobType
        job = BRL::Genboree::Prequeue::Job.newFromJobConf(jobConf, @genbConf.gbTaskWrapperJobHost, jobSystemType, @genbConf.gbTaskWrapperJobQueue, jobType, @userLogin)
        job.submitHost = @genbConf.machineName
        job.setSubmitDate(Time.now())
        job.setExecStartDate(Time.now())
        job.prequeue("wbLocal-#{@toolIdStr}")
        # Now that have Job instance, override/set some key bits of info:
        @workbenchJobObj.context['jobId'] = job.name
        @workbenchJobObj.context['scratchDir'] = generateOutputDir()  # Don't want to get from Job...no Submitter sub-class for these anyway
        success = true
        if(useTaskWrapper)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "    WILL USE: TaskWrapper for local job [ugh, replace with localCluster approach!]")
          @workbenchJobObj = cleanJobObj(@workbenchJobObj)
          # Now do actual operations to get this weird local job running
          createScratchDir()
          cmd = buildCmd()
          # WARNING: Be careful when building a command to be executed.
          # Any command line option values must be properly escaped.
          cmd = WorkbenchJobHelper.wrapCmdForRubyTaskWrapper(cmd, @localScratchDir)
          pid, stdin, stdout, stderr = Open4.popen4(cmd)
          stdin.close
          stderr.each { |line| $stderr.puts line }
          stdout.each { |line| $stderr.puts line }
          stderr.close
          stdout.close
          ignored, errorLevel = Process::waitpid2(pid)
          # returns true if errorLevel is 0
          success = (errorLevel.to_i == 0)
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "    WILL USE: runInProcess() of #{self.class} for local job [better be guaranteed small/fast!]")
          success = runInProcess()
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "    Run 'in process' of #{self.class} was successful? #{success.inspect}")
        end
        # Update Job status (and execEndDate) appropriately
        if(success)
          job.updateStatusForNonQueuedJobs(:completed)
        else
          job.updateStatusForNonQueuedJobs(:failed)
        end
      rescue Exception => err
        success = false
        # Add errors to the context so they can be display to user
        @workbenchJobObj.context['wbErrorName'] = :'Internal Server Error'
        @workbenchJobObj.context['wbErrorMsg'] = "#{err.message}"
        # Log errors
        $stderr.puts "ERROR in method #{__method__} in file #{__FILE__}"
        $stderr.puts "ERROR MESSAGE: #{err.message.inspect}"
        $stderr.puts "ERROR BACKTRACE:\n#{err.backtrace.join("\n")}\n\n"
      ensure
        job.clear() if(job.is_a?(BRL::Genboree::Prequeue::Job))
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "END: runLocalJob for #{self.class}. About to call GC.start() as a brute-force assistance for freeing massive RAM usage by poorly-implemented runInProcess() method of JobHelper subclasses. Big RAM usage in runInProcess() indicates something INAPPROPRIATE for runInProcess() or a sloppy implementation in runInProcess(); need to be _quick_, read only _small_ bits of file, and do O(1) things [not all records etc].")
        GC.start()
      return success
    end

    # INTERFACE METHOD. Standard way to refuse to run a job locally (i.e. no cluster configured for this
    # tool or no cluster available). Very unlikely you want to override this (improve slightly, sure; override no)
    # [+returns+] false
    def refuseLocalJob()
      msg = "ERROR: The #{TOOL_NAME} cluster analysis tool requires a cluster to run."
      $stderr.debugPuts(__FILE__, __method__, "ERROR", msg)
      if(@workbenchJobObj)
        # Add errors to the context so they can be display to user
        @workbenchJobObj.context['wbErrorName'] = :'Internal Server Error'
        @workbenchJobObj.context['wbErrorMsg'] = msg
      end
      return false
    end

    # INTERFACE METHOD. This method loads some useful information to be passed to the job dialog/form.
    # If your job dialog needs extra infomation or preprocessing either add it here
    # if it's generic enough that all jobs could use it, or override this method in
    # the {ToolIdStr}JobHelper sub class.
    #
    # Use with <% WorkbenchFormHelper.addToFormContext({'example' => 'value'}) %>
    # in the dialog rhtml template to pass the value to javascript
    #
    # [+contextHash+] WorkbenchJobEntity
    # [+returns+]     WorkbenchJobEntity
    def fillClientContext(workbenchJobObj)
      @workbenchJobObj = workbenchJobObj
      return @workbenchJobObj
    end

    # INTERFACE METHOD. This method loads some useful information required to be in the context specific to the cluster
    #
    # [+contextHash+] WorkbenchJobEntity
    # [+returns+]     WorkbenchJobEntity
    def fillClusterServerContext(workbenchJobObj)
      @workbenchJobObj = workbenchJobObj
      # Stuff from conf file
      @workbenchJobObj.context['gbConfFile'] = @genbConf.clusterGenbConfFile
      # The dbrcKey that the jobs should use is the gbSuperuserDbrcKey
      @workbenchJobObj.context['apiDbrcKey'] = @superuserApiDbrc.key
      # Cluster jobs shouldn't need a lock file key, but including just in case
      @workbenchJobObj.context['gbLockFileKey'] = @genbConf.workbenchJobLockFileKey
      # Set the toolIdStr, since we don't rely on getting that from user/dev and we have it available:
      @workbenchJobObj.context['toolIdStr'] = @toolIdStr
      return @workbenchJobObj
    end

    # INTERFACE METHOD. This method loads some useful information required to be in the context
    # before the job is launched in a local sub-process (i.e. NOT on the cluster). Rarely needed since most
    # jobs are done on the cluster.
    #
    # [+contextHash+] WorkbenchJobEntity
    # [+returns+]     WorkbenchJobEntity
    def fillServerContext(workbenchJobObj)
      @workbenchJobObj = workbenchJobObj
      # Stuff from conf file
      @workbenchJobObj.context['gbConfFile'] = BRL::Genboree::GenboreeConfig::DEF_CONFIG_FILE
      @genbConf.each { |confVarName|
        @workbenchJobObj.context[confVarName] = @genbConf.send(confVarName)
      }
      @workbenchJobObj.context['apiDbrcKey'] = @superuserApiDbrc.key
      @workbenchJobObj.context['gbLockFileKey'] = @genbConf.workbenchJobLockFileKey
      return @workbenchJobObj
    end

    # ------------------------------------------------------------------
    # PROTECTED METHODS - not candidates for overriding, in general
    # ------------------------------------------------------------------

    # Only used by local jobs (NOT for cluster jobs). Cluster jobs do no copy stuff back to the
    # web server [anymore]. Should be little need to override.
    # The scratch dir consists of the following parts:
    # - base path from config file
    # - username
    # - toolIdStr
    # - jobId
    def generateOutputDir()
      # Something like /usr/local/brl/data/genboree/jobs/timcharnecki/methylationDataComparison/123234231_123423/
      @localScratchDir = "#{@genbConf.gbJobBaseDir}/#{@workbenchJobObj.context['userLogin']}/#{@workbenchJobObj.context['toolIdStr']}/#{@workbenchJobObj.context['jobId']}"
      return @localScratchDir
    end

    def envPathFix(envVar, gbEnvSuffix=@gbEnvSuffix)
      envVar = retVal = envVar.to_s
      # Is there anything to do?
      if(gbEnvSuffix and !gbEnvSuffix.empty?)
        varInfo = ENV_VARS_FIX_INFO[envVar]
        if(varInfo)
          # Is it a variable that can take more than one path and should we append original path value to end of path?
          if(varInfo[:multiPaths] and varInfo[:append])
            retVal = "export #{envVar}=` ruby -e 'print ENV[ARGV.first.strip].gsub(%r{#{@clusterSharedRoot}/local/}, \"#{@clusterSharedRoot}/local#\{ARGV[1].strip\}/\")' #{envVar} #{gbEnvSuffix}`:$#{envVar} "
          else # just replace value
            retVal = "export #{envVar}=` ruby -e 'print ENV[ARGV.first.strip].gsub(%r{#{@clusterSharedRoot}/local/}, \"#{@clusterSharedRoot}/local#\{ARGV[1].strip\}/\")' #{envVar} #{gbEnvSuffix}`"
          end
        end
      end
      return retVal
    end

    # AVOID OVERRIDING executionCallback(). You rarely should override this. If you need to, it is the WRONG SOLUTION.
    # The correct solution is to make WorkbenchJobHelper#executionCallback() more modular
    # so you can provide the components that will be used automatically here.
    #
    # This method defines the default behavior of jobs that are submitted by the workbench
    #
    # This class will take the workbench object containing
    # inputs, outputs, context and settings and perform the following:
    #  - Add server specific info to the context
    #  - Create a scratch dir where the task will be launched.
    #  - Write the workbench object to a json file which is intended to be read by the launched task
    #  - Build a string for a command which takes input option '-j' as json input file
    #  - Wrap a command for the genbTaskWrapper
    #  - and then launch the command
    #
    # This method may be overridden to perform a task that does not need to be run externally
    # or if the command does not require taskWrapper.
    #
    # [+returns+] boolean: true if job has been accepted or completed successfully, else false
    def executionCallback()
      return Proc.new() { |workbenchJobObj|        # Get required server information that the job will need
        success = false
        clusterJobId = nil
        # Get user's host-auth info, for user mentioned in @workbenchJobObj
        @hostAuthMap = initUserInfo(workbenchJobObj)  # Mix-in method actually sets @hostAuthMap and @userLogin variables!
        # Ensure queue correctly set.
        configQueue(workbenchJobObj)
        # Execute on cluster if enabled in the config file and the queue is set to something other than 'none'
        if(!workbenchJobObj.context['queue'].nil? and workbenchJobObj.context['queue'] != 'none' and @genbConf.useClusterForWbJobs == "true")
          # Clean the context of the workbenchJobObj of stuff user/dev should not be provding.
          # - we will fill in the server context here using fillClusterServerContext()
          # - we will only save absolutely required parts in database context record, reconstructing most of context
          #   dynamically when job is retrieved
          jobIdPrefix = 'wbJob'
          if(workbenchJobObj and workbenchJobObj.context)
            # Before cleaning context of crud, extract any needed bits:
            # - jobIdPrefix, if any
            if(workbenchJobObj.context.key?('jobIdPrefix'))
              # Use that jobIdPrefix instead
              jobIdPrefix = workbenchJobObj.context['jobIdPrefix']
            end
            # - queue, if any
            clusterQueue = workbenchJobObj.context['queue']
            # Regardless, Job.cleanContext(context) called in Job#prequeue()
            # will remove jobIdPrefix, queue (and other things) from context so they're not saved in the database records.
            workbenchJobObj.context = BRL::Genboree::Prequeue::Job.cleanContext(workbenchJobObj.context, true)
          end
          # Clean up the job object a bit
          @workbenchJobObj = cleanJobObj(workbenchJobObj)
          fillClusterServerContext(@workbenchJobObj)
          # Create a BRL::Genboree::Prequeue::Job object from the @workbenchJobObj
          jobConfHash = {
            'inputs'    => @workbenchJobObj.inputs.dup(),
            'outputs'   => @workbenchJobObj.outputs.dup(),
            'settings'  => @workbenchJobObj.settings.dup(),
            'context'   => @workbenchJobObj.context.dup()
          }
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@toolConf:\n #{JSON.pretty_generate(@toolConf)}")
          
          prequeueHost = @genbConf.gbDefaultPrequeueHost
          prequeueType = @genbConf.gbDefaultPrequeueType
          # Load up the tool specific conf file to see if it has to be submitted as a 'local' job
          if(@toolConf.conf['cluster'].key?('prequeueType') and @toolConf.conf['cluster']['prequeueType'] == "LocalHost")
            prequeueHost = @genbConf.internalHostnameForCluster
            # Check the setting hash if a host has been provided. This avoids conflicts between taurine/valine
            if(jobConfHash['settings'].key?('gbPrequeueHost'))
              prequeueHost = jobConfHash['settings']['gbPrequeueHost']
            end
            prequeueHost = ( @toolConf.conf['cluster'].key?('prequeueHost') ? @toolConf.conf['cluster']['prequeueHost'] : prequeueHost )
            prequeueType = @toolConf.conf['cluster']['prequeueType']
          end
          
          jobConfHash['preconditionSet'] = @workbenchJobObj.preconditionSet.dup() if(@workbenchJobObj.preconditionSet and !@workbenchJobObj.preconditionSet.empty?)
          job = nil
          begin
            # Catch specific problems processing the job conf payload
            begin
              job = BRL::Genboree::Prequeue::Job.newFromJobConf(jobConfHash, prequeueHost, prequeueType, clusterQueue, @genbConf.gbDefaultPrequeueJobType, @userLogin)
            rescue => err
              success = false
              @workbenchJobObj.context['wbErrorName'] = :'Bad Request' # was ":Internal Server Error"...caused issues, why?
              @workbenchJobObj.context['wbErrorMsg'] = "Cannot process the provided job configuration payload; it has errors. Error Class: #{err.class}. Error Message: #{err.message}"
              raise err # re-raise to handling in outer begin-rescue
            end
            job.submitHost = @genbConf.machineName
              # Set any directives, saving numCores and numNodes for using in standard exports later on.
            directives = self.directives()
            if(directives)
              #directives[:mem] = directives[:pvmem] if(directives.key?(:pvmem) and !directives.key?(:mem))
              job.setDirectives(directives)
              numNodes = (directives[:nodes] || 1)
              numCores = (directives[:ppn] || 1)
            else
              numNodes = numCores = 1
            end
            # Set any preCommands, to prepare job prior to running what is typically the actual job command(s) via commandsRunner.rb
            # - first we add our standard nodes/cores export in case the preCommands need those env vars
            preCommands = [ "export GB_NUM_NODES=#{numNodes}", "export GB_NUM_CORES=#{numCores}" ]
            # - next change the env variables on the cluster depending on which machine (dev/live) the job is coming from
            preConds = []
            if(prequeueType != 'LocalHost')
              ENV_VARS_TO_FIX.each { |var|
                preCommands << envPathFix(var, @gbEnvSuffix)
              }
            else
              preCommands << "export GENB_CONFIG=#{ENV['GENB_CONFIG']}"
            end
            # - now add and special exports that should be added
            preCommands += self.exports()
            # - finally, add the tool-specific preCommands--if any--which will have access to the standard
            #   ENV variables and such already configured above, if needed
            preCommands += self.preCmds()
            # Add preCommands to job object
            job.preCommands = preCommands
            # Set the actual tool job command(s), adding the historical standard chgrp/chmod at the end
            commands = [ self.buildCmd(true) ]
            commands[0] << " --noClean" if(prequeueType == "LocalHost")
            commands << 'chgrp -R nobody *'
            commands << 'chmod -R o-rwx *'
            # Add commands to job object
            job.commands = commands
            # Add any job-specific postCommands for weird clean up or other things the standard stuff won't handle
            job.postCommands = self.postCmds()
            # Queue the new job!
            clusterJobId = job.prequeue("#{jobIdPrefix}-#{@toolIdStr}")
            if(clusterJobId)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "PREQUEUED job #{clusterJobId.inspect}")
              # Are there any dependent jobs to be sumbitted?
              # - i.e. ones that are dependent on THIS job, for which we have a clusterJobId ?
              dependentJobConfs = self.makeDependentJobConfs(job)
              if(dependentJobConfs)
                # If so, submit them via apiCaller
                dependentJobConfs.each_index { |ii|
                  dependentJobConf = dependentJobConfs[ii]
                  depJobToolIdStr = dependentJobConf["context"]["toolIdStr"]
                  if(depJobToolIdStr)
                    $stderr.debugPuts(__FILE__, __method__, "    SUB-STATUS", "Prequeing dependent job ##{ii}. Tool ID: #{depJobToolIdStr.inspect}")
                    # Clean out the now unneeded toolIdStr in context
                    dependentJobConf["context"].delete("toolIdStr")
                    depJobPath = "/REST/v1/genboree/tool/#{depJobToolIdStr}/job?responseFormat=json&connect=no"
                    # - internal API call [probably]
                    apiCaller = BRL::Genboree::REST::ApiCaller.new(@genbConf.machineName, depJobPath, @hostAuthMap)
                    apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
                    httpResp = apiCaller.put({}, dependentJobConf.to_json)
                    depJobPutStatus = apiCaller.succeeded?
                    unless(depJobPutStatus)
                      # Something went wrong. See if we can get the status from the response
                      parseStatus = apiCaller.parseRespBody rescue nil
                      if(parseStatus)
                        # Mirror wbErrorName and wbErrorMsg of subordinate API call here
                        @workbenchJobObj.context['wbErrorName'] = (apiCaller.apiStatusObj["statusCode"] or :'Internal Server Error')
                        @workbenchJobObj.context['wbErrorMsg']  = ("FAILURE: submission of a dependent #{depJobToolIdStr.inspect} job failed: " + (apiCaller.apiStatusObj["msg"] or "(no error message provided)"))
                        # re-raise to handling in outer begin-rescue
                        raise @workbenchJobObj.context['wbErrorMsg']
                      else
                        raise "ERROR: submission of dependent job via API call failed.\n  Dependee job id: #{clusterJobId.inspect}.\n  HTTP Response: #{httpResp.code rescue "N/A"} #{httpResp.message rescue "N/A"} (Class: #{httpResp.class})\n  Dependent Job Conf:\n\n#{JSON.pretty_generate(dependentJobConf)}\n\n"
                      end
                    end
                  else
                    raise "ERROR: missing required 'toolIdStr' field in 'context' section for this this dependent job conf:\n\n#{JSON.pretty_generate(dependentJobConf)}\n\n"
                  end
                }
              end # if(dependentJobConfs)
            end # if(clusterJobId)
            # Make sure our job got scheduled
            if(clusterJobId.nil?)
              success = false
              @workbenchJobObj.context['wbErrorName'] = :'Internal Server Error' # was ":Internal Server Error"...caused issues, why?
              @workbenchJobObj.context['wbErrorMsg'] = "Error submitting job to the cluster scheduler."
              $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error submitting job to the scheduler.")
            else
              # Set the jobId in the @workbenchJobObj ... some follow up code is probably looking for
              # it (e.g. anything that calls getMessage() after this...)
              @workbenchJobObj.context['jobId'] = clusterJobId
              success = true
            end
          rescue => err
            success = false
            if(@workbenchJobObj and @workbenchJobObj.context)
              @workbenchJobObj.context['wbErrorName'] = :'Internal Server Error' unless(@workbenchJobObj.context['wbErrorName'].to_s =~ /\S/)
              @workbenchJobObj.context['wbErrorMsg'] = err.message
            end
            $stderr.puts err
            $stderr.puts err.backtrace.join("\n")
          ensure
            job.clear() if(job.is_a?(BRL::Genboree::Prequeue::Job))
          end
        else # Not using cluster, rather run job locally on submitting server
          success = runLocalJob(workbenchJobObj)
        end
        success
      }
    end

    # This function wraps a command with genbTaskWrapper.rb
    #
    # [+cmd+]       string: The command that will be wrapped
    # [+scratchDir+] string: The dir where log files are created
    # [+returns+]   string: The wrapped command
    def self.wrapCmdForRubyTaskWrapper(cmd, scratchDir)
      raise ArgumentError, "cmd cannot be nil." if(cmd.nil? or cmd.empty? )
      genbTaskWrapperCmd = "genbTaskWrapper.rb -v -c #{CGI.escape(cmd)}" +
                           " -g #{ENV['GENB_CONFIG']}" +
                           " -e #{scratchDir}/genbTaskWrapper.err" +
                           " -o #{scratchDir}/genbTaskWrapper.out" +
                           " &"  # necessary to run in background, since genbTaskWrapper.rb will -detach- itself
      return genbTaskWrapperCmd
    end

    # Create a scratch dir where the task will be launched.
    #
    # Requires that 'scratchDir' is in the context
    # This should be executed after fillServerContext
    #
    # [+returns+] String: dir that was created
    def createScratchDir()
      raise ArgumentError.new("Can't mkdir, context['scratchDir'] must be set") if(@localScratchDir.nil?)
      FileUtils.mkdir_p(@localScratchDir)
      # Ensure dir is group writable
      FileUtils.chmod(0775, @localScratchDir)
    end

    # This method returns the html that contains information about a successfully submitted job
    #
    # It requires certain context variables to be set.
    #
    # [+msgType+]   Symbol: Should be one of :Accepted, :Rejected :Warnings or :Failure
    # [+returns+]   String; Html text
    def getMessage(msgType, wbJobEntity)
      # A String with technical details about the error. Not for users. Backtraces for example. This will just end up in the stderr log.
      # This one may be optional depending on the error (maybe it was a user error or the nature of an input or something) and whether the info is already in the stderr log.
      if(!wbJobEntity.context['wbErrorDetails'].nil?)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error encountered: #{wbJobEntity.context['wbErrorDetails'].inspect}")
      end
      # Try to render the appropriate job message into HTML depending on message type
      # (:Accepted, :Rejected, :Failure, :Warnings)
      uiType = "job#{msgType}"
      toolIdStr = wbJobEntity.context['toolIdStr'] || "{Bug: ToolID Not Available}"
      # Add genbConf and toolIdStr to the evaluate() context so they are available
      # as @genbConf and @toolIdStr in the rhtml
      respHtml = renderDialogContent(toolIdStr, uiType, wbJobEntity.getEvalContext(:genbConf => @genbConf, :toolIdStr => toolIdStr))
      return respHtml
    end

    # @param [Exception] err an error object that will be used to log error details or to 
    #   present error message to the user
    def logAndPrepareError(err)
      defaultMsg = "Unhandled exception. Please contact the administrator at #{@genbConf.send(:gbAdminEmail)}."
      if(err.is_a?(WorkbenchJobError))
        # then error is expected
        @workbenchJobObj.context['wbErrorMsg'] = err.message
        @workbenchJobObj.context['wbErrorName'] = err.code
      else
        # then error is unexpected, log details
        @workbenchJobObj.context['wbErrorMsg'] = defaultMsg
        @workbenchJobObj.context['wbErrorName'] = :"Internal Server Error"
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error message: #{err.message} ; backtrace:\n#{err.backtrace.join("\n")}\n\n")
      end
      return nil
    end
  end

  # Use this error class for controlled error raising in child classes, particular those that 
  #   implement runInProcess()
  class WorkbenchJobError < RuntimeError
    attr_reader :message
    attr_reader :code
    # @param [String] message usual error message
    # @param [Symbol] code HTTP status code name
    def initialize(message, code=:"Internal Server Error")
      super(message)
      @message = message
      @code = code
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
