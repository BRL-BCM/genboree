#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
module BRL ; module Genboree ; module Prequeue ; module Systems
  class Manager
    # Abstract parent class of batch system-specific manager subclasses.
    # Defines interface methods and inheritablegeneric methods [if any]
    #------------------------------------------------------------------
    # CLASS INSTANCE VARIABLES
    #------------------------------------------------------------------
    class << self
      # Set up class instance variables ; these are typically also set in the
      # subclasses to specific values (or to use these defaults if appropriate)
      attr_accessor :genbConf
      Manager.genbConf = BRL::Genboree::GenboreeConfig.load()
    end
    #------------------------------------------------------------------
    # CONSTANTS
    #------------------------------------------------------------------
    SYSTEM_TYPE = '[NOT SET]'
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
      raise "Interface Method '#{__method__}()' Not Implemented!"
    end

    # Generic method which will update the status of job in the database.
    # Typically requires no batch system-specific overrides and this
    # implementation should be fine.
    def updateStatus(job, status, updateTimeStamp=true)
      rowsUpdated = job.dbu.updateJobStatusByJobName(job.name, status)
      if(updateTimeStamp) # then also update appropriate time-stamp column for key statuses
        case status
          when :entered, 'entered'
            updateEntryDate(job)
          when :submitted, 'submitted'
            updateSubmitDate(job)
          when :running, 'running'
            updateExecStartDate(job)
          when :completed, :failed, :partialSucess, :canceled, :killed, 'completed', 'failed', 'partialSucess', 'canceled', 'killed'
            updateExecEndDate(job)
        end
      end
      return rowsUpdated
    end

    # Generic method which will update the unqiue job id provided by a batch system
    # upon submission of the job.
    # Typically requires no batch system-specific overrides and this
    # implementation should be fine.
    def updateSystemJobId(job, systemJobId)
      rowsUpdated = job.dbu.updateSystemInfoSystemJobIdByJobName(job.name, systemJobId)
      return rowsUpdated
    end

    # Generic method which will update the entry date time for job in the database.
    # Typically requires no batch system-specific overrides and this
    # implementation should be fine.
    def updateEntryDate(job, time=Time.now())
      rowsUpdated = job.dbu.updateJobEntryDateByJobName(job.name, time)
      return rowsUpdated
    end

    # Generic method which will update the submit date time for job in the database.
    # Typically requires no batch system-specific overrides and this
    # implementation should be fine.
    def updateSubmitDate(job, time=Time.now())
      rowsUpdated = job.dbu.updateJobSubmitDateByJobName(job.name, time)
      return rowsUpdated
    end

    # Generic method which will update the execution start date time for job in the database.
    # Typically requires no batch system-specific overrides and this
    # implementation should be fine.
    def updateExecStartDate(job, time=Time.now())
      rowsUpdated = job.dbu.updateJobExecStartDateByJobName(job.name, time)
      return rowsUpdated
    end

    # Generic method which will update the execution end date time for job in the database.
    # Typically requires no batch system-specific overrides and this
    # implementation should be fine.
    def updateExecEndDate(job, time=Time.now())
      rowsUpdated = job.dbu.updateJobExecEndDateByJobName(job.name, time)
      return rowsUpdated
    end

    #------------------------------------------------------------------
    # HELPER METHODS (mainly for internal use)
    #------------------------------------------------------------------
  end # class Manager
end ; end ; end ; end # module BRL ; module Genboree ; module Prequeue ; module Systems
