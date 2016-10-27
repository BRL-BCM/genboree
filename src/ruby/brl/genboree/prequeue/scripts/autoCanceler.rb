#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'json'
require 'brl/util/util'
require 'brl/script/scriptDriver'
require 'brl/genboree/dbUtil'
require 'brl/genboree/prequeue/manager'

module BRL ; module Genboree ; module Prequeue ; module Scripts
  class AutoCanceler < ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "0.1"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--host"        =>  [ :REQUIRED_ARGUMENT, "-H", "The host domain name where batch system lives." ],
      "--systemType"  =>  [ :REQUIRED_ARGUMENT, "-s", "The type of batch system which lives at host."],
      "--jobType"     =>  [ :REQUIRED_ARGUMENT, "-t", "The type(s) of job to consider canceling. If more than one type, a CSV list." ]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "Finds 'cancelRequested' jobs prequeued for running on the specified type of batch system which lives on specific host. Jobs headed for other types of batch system and/or for systems living on other hosts are ignored. Will attempt to use the system job cancel command if the job is already running on the batch system; so ONLY works on a ystem submit or management host.",
      :authors      => [ "Andrew R Jackson (andrewj@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} --host=brlhead.brl.bcmd.bcm.edu --systemType=TorqueMaui --jobType=gbToolJob",
        "#{File.basename(__FILE__)} -H brlhead.brl.bcmd.bcm.edu -s TorqueMaui -t gbToolJob,pipelineJob",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    #------------------------------------------------------------------
    # CONSTANTS
    #------------------------------------------------------------------
    #------------------------------------------------------------------
    # ACCESSORS
    #------------------------------------------------------------------
    # String containing the host domain name whose batch system jobs we should consider.
    attr_accessor :host
    # String containing the batch system type for which to consider jobs.
    attr_accessor :systemType
    # Array of Strings indicating the type(s) of job to consider for submission.
    attr_accessor :jobTypes

    # ------------------------------------------------------------------
    # IMPLEMENTED INTERFACE METHODS
    # ------------------------------------------------------------------
    # run()
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . @optsHash contains the command-line args, keyed by --longName
    def run()
      # Process args and init and stuff
      validateAndProcessArgs()
      haveLock = lockFile = nil
      # First process args and init and stuff
      validateAndProcessArgs()
      begin
        # Try to get file lock so we don't collide with other related auto-scripts.
        # We'll exit if we can't immediately get the lock (some other related script is running).
        lockFile = File.open(genbConf.prequeueLockFile, "w+")
        fh.flock(File::LOCK_EX | File::LOCK_NB)
        haveLock = true
        @jobTypes.each { |jobType|
          # Identiy 'cancelRequested' jobType jobs headed to batch system type @systemType on @host
          jobNameRows = getJobNameRows(jobType)
          if(jobNameRows)
            jobNameRows.each { |row|
              # Create Job object from job id
              job = BRL::Genboree::Prequeue::Job.getJobByName(row['name'])
              # Get Submitter instance for Job
              manager = job.manager
              begin
                # Submit job, also updating appropriate time stamp and recording systemJobId
                cancelOK = manager.cancelJob(job)
                raise "ERROR: cancelation of job #{job.name} failed." unless(cancelOK)
              rescue => @err
                @errUserMsg = @err.message
                @errInternalMsg = @errUserMsg
                @exitCode = 44
                raise @err
              end
            }
          end
        }
      rescue Errno::EAGAIN => lockErr
        haveLock = false
        $stderr.puts "WARNING: Could not get lock on file #{genbConf.prequeueLockFile.inspect}. Another script probably running." if(@verbose)
      ensure
        if(fh and haveLock)
          lockFile.flock(File::LOCK_UN) rescue $stderr.puts("ERROR: could not release lock on #{genbConf.prequeueLockFile.inspect}!!")
        end
      end
      # Must return a suitable exit code number
      return EXIT_OK
    end

    # ------------------------------------------------------------------
    # SCRIPT-SPECIFIC METHODS
    # ------------------------------------------------------------------
    # - stuff needed to do actual program or drive 3rd party tools, etc
    # - repeatedly-used generic stuff is in library classes of course...
    def validateAndProcessArgs()
      retVal = nil
      # Initialize state
      @host = @systemType = @jobType = nil
      @host = @optsHash['--host'].strip
      @systemType = @optsHash['--systemType'].strip
      @jobTypes = @optsHash['--jobTypes'].strip.split(/,/)
      retVal = true
      return retVal
    end

    def getJobNameRows(jobType)
      # Get DBUtil instance using default dbrcKey etc.
      dbu = BRL::Genboree::Prequeue::Job.getDBUtil()
      statuses = [ 'cancelRequested' ]
      jobNameRows = dbu.selectJobNamesBySystemInfoAndJobType(@host, @systemType, jobType, statuses)
      dbu.clear(true)
      return jobNameRows
    end
  end # class AutoCanceler
end ; end ; end ; end # module BRL ; module Genboree ; module Prequeue ; module Scripts

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Script::AutoCanceler)
end
