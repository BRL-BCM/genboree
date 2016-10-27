#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'json'
require 'brl/util/util'
require 'brl/script/scriptDriver'
require 'brl/genboree/dbUtil'
require 'brl/genboree/prequeue/systems/manager'
require 'brl/genboree/prequeue/job'

module BRL ; module Genboree ; module Prequeue ; module Scripts
  class StatusUpdater < BRL::Script::ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "0.1"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--jobName" =>  [ :REQUIRED_ARGUMENT, "-j", "The unique job name (ticket) in the prequeue tables which you want to update." ],
      "--status"  =>  [ :REQUIRED_ARGUMENT, "-s", "The status to update to. The appropriate time stamp will also be set. Must be one of the official statuses (#{BRL::Genboree::DBUtil::JOB_STATUSES.keys.join(', ')})"]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "Updates the job identified by the unique job name to the provided status. Will also set the appropriate time stamp column for that status.",
      :authors      => [ "Andrew R Jackson (andrewj@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} --jobName=wbJob-someTool-188831596010988.21098 --status=completed",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    #------------------------------------------------------------------
    # CONSTANTS
    #------------------------------------------------------------------
    #------------------------------------------------------------------
    # ACCESSORS
    #------------------------------------------------------------------
    # BRL::Genboree::Prequeue::Job object to submit
    attr_accessor :job
    # Unique name of job in prequeue
    attr_accessor :jobName
    # Symbol indicating the status we want to set the job to
    attr_accessor :status
    # Instance of a BRL::Genboree::Prequeue::Systems::Manager class which can be used to manage the job appropriately
    attr_accessor :manager

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
      # Create Job object and get the Manager
      @job = BRL::Genboree::Prequeue::Job.fromName(@jobName)
      if(@job)
        # Need to load the commands, since Job object won't have retrieved them by default
        @job.loadCommands()
        @manager = @job.manager
        # Update status and associated time stamp
        rowsUpdated = @manager.updateStatus(@job, @status, true)
        unless(rowsUpdated == 1)
          $stderr.puts "WARNING: #{rowsUpdated.inspect} job table rows were updated. This could be because the job already had the #{@status.inspect} status or because of a serious problem."
        end
        # Done with job, force disconnect of DB connection (else server seems to leave it open even after this script ends)
        @job.clear()
      else
        @errUserMsg = "ERROR: No job with unique name (ticket) #{@jobName.inspect} found in the jobs prequeue table. Are you sure you spelled it correctly?"
        @errInternalMsg = @errUserMsg
        @exitCode = 44
        raise @errInternalMsg
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
      @jobName = @status = @job = @manager = nil
      @jobName = @optsHash['--jobName'].strip
      @status = @optsHash['--status'].strip.to_sym
      retVal = true
      return retVal
    end
  end # class StatusUpdater
end ; end ; end ; end # module BRL ; module Genboree ; module Prequeue ; module Scripts

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Genboree::Prequeue::Scripts::StatusUpdater)
end
