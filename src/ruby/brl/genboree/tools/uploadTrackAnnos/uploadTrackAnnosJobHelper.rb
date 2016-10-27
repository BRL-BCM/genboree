require 'uri'
require 'json'
require 'brl/util/util'
require "brl/db/dbrc"
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/helpers/fileApiUriHelper'

module BRL ; module Genboree ; module Tools
  class UploadTrackAnnosJobHelper < WorkbenchJobHelper

    TOOL_ID = 'uploadTrackAnnos'



    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "uploadTrackAnnosWrapper.rb"
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
      return [
        "module load jksrc"
      ]
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

    # INTERFACE METHOD. Returns an Array of any additional exports that need to appear in the
    # cluster .pbs file. They appear just before the call to "commandWrapper.rb". i.e. AFTER
    # the appropriate env location variables have been set.
    # - By default, empty; no extra exports
    def exports()
      return [
        "export CLASSPATH=$SITE_JARS/GDASServlet.jar:$SITE_JARS/servlet-api.jar:$SITE_JARS/mysql-connector-java.jar:$SITE_JARS/mail.jar"
      ]
    end

    # @param [Object] workbenchJobObj
    # @return [Object] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      super(workbenchJobObj)
      settings    = workbenchJobObj.settings
      inputFormat = settings['inputFormat']
      trkClass    = settings['trackClassName']
      if(!trkClass or trkClass.strip.empty?) # then need to set trackClassName appropriately
        # Determine default class for format, if any
        # - how & whether we use this default depends on what the user provided and the format
        # - but get default first
        defClassName = Abstraction::Track.getDefaultClass(inputFormat)
        settings['trackClassName'] = defClassName
      end
      return workbenchJobObj
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
      #
      #retVal = []
      #depJobConf1 = DEPENDENT_JOB_TEMPLATE.deep_clone()
      ## Get dynamic bits:
      #expires = (Time.now + (2*Time::WEEK_SECS)).to_s
      #dependeeJobUrl = "http://#{@genbConf.machineName}/REST/v1/job/#{dependeeJob.name}"
      ## Carefully get target database from "outputs" of dependeeJob
      ## - Does it have the expected number of outputs??
      #if(dependeeJob.outputs.size == 1)
      #  # - Can we get a put db uri from it?
      #  pureDbUri = @dbApiHelper.extractPureUri(dependeeJob.outputs.first)
      #  if(pureDbUri)
      #    # - Use extracted db in "outputs" of this conditional job
      #    depJobConf1["outputs"] << pureDbUri
      #  else
      #    raise "ERROR: ERROR: Dependee job #{dependeeJob.name} (type: #{dependeeJob.toolId}) doesn't have exactly 1 database URI in it. It has some other kind of URI which we cannot even derive a database URI from. dependeeJob.outputs:\n\n#{dependeeJob.outputs.inspect}\n\n "
      #  end
      #else
      #  raise "ERROR: Dependee job #{dependeeJob.name} (type: #{dependeeJob.toolId}) doesn't have exactly 1 output. Expecting just the target database in the 'outputs' array. Did a dev change the tool without thinking about the dependent jobs?) dependeeJob.outputs:\n\n#{dependeeJob.outputs.inspect}\n\n"
      #end
      #
      ## Fill template:
      #precond1 = depJobConf1["preconditionSet"]["preconditions"].first
      #precond1["expires"] = expires
      #precond1["condition"]["dependencyJobUrl"] = dependeeJobUrl
      ## Add to set of dependent job confs to return
      #retVal << depJobConf1
      #
      #return retVal
    end

    # ------------------------------------------------------------------
    # INTERNAL CONSTANTS
    # ------------------------------------------------------------------

    # @todo Remove this, it was for development only.

    #DEPENDENT_JOB_TEMPLATE =
    #{
    #  "inputs"   =>  [ ],                     # STAYS EMPTY
    #  "outputs"  =>  [ ],                     # ADD: target database
    #  "settings" =>  { },                     # STAYS EMPTY
    #  "context"  =>
    #  {
    #    "toolIdStr"      => "cleanAnnoAvpMap",
    #    "queue"          => "gbApiHeavy",
    #    "jobIdPrefix"    => "DEV"
    #  },
    #  "preconditionSet"  =>
    #  {
    #    "willNeverMatch" =>  false,
    #    "someExpired"    =>  false,
    #    "count"          =>  0,
    #    "numMet"         =>  0,
    #    "preconditions"  =>
    #    [
    #      {
    #        "met"        =>  false,
    #        "type"       =>  "job",
    #        "expires"    =>  nil,             # FILL (2 weeks from now)
    #        "condition"  =>
    #        {
    #          "dependencyJobUrl"    =>  nil,  # FILL: the upload job
    #          "acceptableStatuses"  =>
    #          {
    #            "completed"       =>  true,
    #            "failed"          =>  true,
    #            "partialSuccess"  =>  true,
    #            "canceled"        =>  true,
    #            "killed"          =>  true
    #          }
    #        }
    #      }
    #    ]
    #  }
    #}
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
