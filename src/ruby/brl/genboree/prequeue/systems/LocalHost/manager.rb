#!/usr/bin/env ruby
$VERBOSE = nil


# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/util/util'
require 'brl/genboree/prequeue/systems/manager'

module BRL ; module Genboree ; module Prequeue ; module Systems
    # Abstract parent class of batch system-specific manager subclasses.
    # Defines interface methods and inheritablegeneric methods [if any]
  class LocalHostManager < Manager
    #------------------------------------------------------------------
    # CLASS INSTANCE VARIABLES
    #------------------------------------------------------------------
    class << self
      # Set up class instance variables ; these are typically also set in the
      # subclasses to specific values (or to use these defaults if appropriate)
      LocalHostManager.genbConf = Manager.genbConf # Use whatever Submitter class has
    end
    #------------------------------------------------------------------
    # CONSTANTS
    #------------------------------------------------------------------
    SYSTEM_TYPE = 'LocalHost'
    #------------------------------------------------------------------
    # ACCESSORS
    #------------------------------------------------------------------
    #------------------------------------------------------------------
    # INSTANCE METHODS
    #------------------------------------------------------------------
    # Initializer. Sub-classes should make sure to call super(job) in their
    # implementations of initialize(job) [if any] in case some generic operations
    # are added.
    # [+job+] An instance of BRL::Genboree::Prequeue::Job, filled in appropriate for
    #         submission to an actual batch system.
    def initialize(job)
      super(job)
    end

    # Interface method to cancel a job. Implementation is highly batch system-specific.
    # How to handle jobs that are already submitted to the system or even already
    # running is very batch system specific.
    # Implementation must handle jobs that are 'entered' but not submitted, 'submitted'
    # but not yet running, as well as jobs that have finished (successfully or not).
    # [+job+] An instance of BRL::Genboree::Prequeue::Job, already prequeued via the
    #         Job#prequeue() method at some point previously.
    # [+supressWarnings+] [optional; default=false] Boolean indicating whether to warn
    #                     about attempts to cancel jobs in certain states. For example
    #                     trying to cancel an already 'canceled' or even finished
    #                     ('completed', 'failed', 'killed') jobs.
    # [+updateStatus+]    [optional; default=true] Boolean indicating whether to
    #                     set the status to 'canceled'. Probably should be true so
    #                     there's a record of the cancelation and so it doesn't try to
    #                     cancel the job again.
    def cancelJob(job, supressWarnings=false, updateStatus=true)
      retVal = nil
      # The job must be either prequeued ('entered'), queued ('submitted'), or actually running
      if(job.status == 'entered') # Then no command to run, just update status in record
        self.setStatus('canceled', updateTimeStamp)
      elsif(job.status == 'submitted' or job.status == 'running' or job.status == 'cancelRequested')  # Then must cancel via batch system command
        # THIS WILL FAIL ON MACHINES WHICH ARE NOT SUBMIT/MANAGEMENT HOSTS FOR THE BATCH SYSTEM!
        # (In which case you are using the wrong method; perhaps you mean to do an setStatus('cancelRequested') so
        # an entered job will be canceled at earliest opportunity?)
        # Must have the system's job id available
        if(job.batchSystemInfo and job.batchSystemInfo.systemJobId and !job.batchSystemInfo.systemJobId.empty?)
          # Attempt to cancel via qdel
          cancelCmd = "kill -9 #{job.batchSystemInfo.systemJobId} 2>&1 "
          cancelCmdOut = `#{cancelCmd}`
          exitCodeObj = $?.dup
          unless(exitCodeObj.success?)
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to cancel #{SYSTEM_TYPE.inspect} job #{job.name.inspect} using command #{cancelCmd.inspect}. Gave exit status #{exitCodeObj.exitstatus.inspect} and following output:\n\n#{cancelCmdOut}\n\n")
          else
            self.setStatus('canceled', updateTimeStamp)
            retVal = true
          end
        end
      else
        unless(supressWarnings)
          $stderr.puts "WARNING: cannot cancel job #{job.name.inspect} because it is not queued or running. (Its status is #{job.status.inspect}. Perhaps already canceled or the job has finished."
        end
      end
      return retVal
    end

    #------------------------------------------------------------------
    # HELPER METHODS (mainly for internal use)
    #------------------------------------------------------------------
  end # class TorqueMauiManager < Manager
end ; end ; end ; end # module BRL ; module Genboree ; module Prequeue ; module Systems
