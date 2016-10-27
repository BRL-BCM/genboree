require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class BigBedFilesJobHelper < WorkbenchJobHelper

    TOOL_ID = 'bigBedFiles'



    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "bigFilesWrapper.rb"
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
      workbenchJobObj = super(workbenchJobObj)
      settings = workbenchJobObj.settings
      newInputList = []
      baseWidget = settings['baseWidget']
      settings.each_key { |key|
        if(key =~ /^#{baseWidget}/)
          if(settings[key])
            newInputList << key.split("|")[1]
          end
        end
      }
      # Create the dirs where the big* files will be rsynced.
      inputs = newInputList
      workbenchJobObj.inputs = inputs
      settings = { 'type' => 'bigbed' }
      workbenchJobObj.settings = settings
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

      # @todo Remove this, was for development only

      # Get recursion level of dependeeJob
      #recursionLevel = (dependeeJob.context["recursionLevel"] or 0)
      #if(recursionLevel < 2)
      #  retVal = []
      #  depJobConf1 = DEPENDENT_JOB_TEMPLATE.deep_clone()
      #  # Get dynamic bits:
      #  toolIdStr = dependeeJob.toolId
      #  expires = (Time.now + Time::WEEK_SECS).to_s
      #  dependeeJobUrl = "http://#{@genbConf.machineName}/REST/v1/job/#{dependeeJob.name}"
      #  recursionLevel += 1
      #  # Fill template:
      #  depJobConf1["context"]["toolIdStr"] = toolIdStr
      #  depJobConf1["context"]["recursionLevel"] = recursionLevel
      #  precond1 = depJobConf1["preconditionSet"]["preconditions"].first
      #  precond1["expires"] = expires
      #  precond1["condition"]["dependencyJobUrl"] = dependeeJobUrl
      #  # [ "MAKE WORK": regenerate the SAME bigBed file AGAIN ]
      #  depJobConf1["inputs"]   = dependeeJob.inputs
      #  depJobConf1["outputs"]  = dependeeJob.outputs
      #  depJobConf1["settings"] = dependeeJob.settings
      #  # Add to set of dependent job confs to return
      #  retVal << depJobConf1
      #else
      #  retVal = nil
      #end
      #
      #return retVal
    end

    # ------------------------------------------------------------------
    # INTERNAL CONSTANTS
    # ------------------------------------------------------------------

    DEPENDENT_JOB_TEMPLATE =
    {
      "inputs"   =>  [ ],                     # DUPLICATED
      "outputs"  =>  [ ],                     # DUPLICATED
      "settings" =>  { },                     # DUPLICATED
      "context"  =>
      {
        "toolIdStr"      => nil,              # FILL
        "queue"          => "gb",
        "jobIdPrefix"      => "DEV",
        "recursionLevel" => nil               # FILL
      },
      "preconditionSet"  =>
      {
        "willNeverMatch" =>  false,
        "someExpired"    =>  false,
        "count"          =>  0,
        "numMet"         =>  0,
        "preconditions"  =>
        [
          {
            "met"        =>  false,
            "type"       =>  "job",
            "expires"    =>  nil,             # FILL
            "condition"  =>
            {
              "dependencyJobUrl"    =>  nil,  # FILL
              "acceptableStatuses"  =>
              {
                "completed"       =>  true,
                "failed"          =>  true,
                "partialSuccess"  =>  true,
                "canceled"        =>  true,
                "killed"          =>  true
              }
            }
          }
        ]
      }
    }

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
