#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'json'
require 'daemons'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/prequeue/systems/manager'
require 'brl/genboree/prequeue/job'
require 'brl/genboree/prequeue/systems/localHost'

module BRL ; module Genboree ; module Prequeue ; module Scripts
  class JobsSubmitter

    EXIT_OK = 0 # wywalic
    
    #------------------------------------------------------------------
    # CONSTANTS
    #------------------------------------------------------------------
    SUBMISSION_PAUSE_LEN = (1 * 60)
    SUBMISSION_PAUSE_JOBS = 250
    # Struct with the local db userId number and the user's hostAuthMap for contacting any remote resources mentioned.
    JobUserInfo = Struct.new(:userId, :hostAuthMap)

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
      @startTime = Time.now()
      jobsSubmittedCount = 0
      # First process args and init and stuff
      @host = 'localhost'
      @systemType = 'LocalHost'
      @jobTypes = 'gbToolJob'
      @verbose = true
      batchSys = BRL::Genboree::Prequeue::Systems::LocalHost.new()
      begin
        @err = nil
        @exitCode = EXIT_OK
        @genbConf = BRL::Genboree::GenboreeConfig.load
        # Get DBUtil instance using default dbrcKey etc.
        @dbu = BRL::Genboree::Prequeue::Job.getDBUtil()
        @jobTypes.each { |jobType|
          @prevTime = Time.now()
          # Identiy 'entered', 'submitted' and 'running' jobType jobs headed to batch system type @systemType on @host
          jobNameRows = getJobNameRows(jobType)
          jobs = []
          jobNameRows.each { |row|
            # Create Job object from job id
            job = BRL::Genboree::Prequeue::Job.fromName(row['name'], @dbu)
            if(job.status == :entered)
              # Get user info for this job's user
              userInfo = getJobUserInfo(job)
              # Check preconditions for this job
              preconditionsMet = checkPreconditions(job, userInfo)
              if((preconditionsMet == :none) or (preconditionsMet == :met))
                job.loadCommands()
                jobs.push(job)
              else
                if(preconditionsMet == :expired)
                  $stderr.puts "STATUS (#{getTimeDelta(true)}): Preconditions not all met before their expiration periods. Job #{job.name} will NEVER run."
                else
                  $stderr.puts "STATUS (#{getTimeDelta(true)}): Preconditions not all met for job #{job.name}"
                end
                rowsUpdated = job.dbu.updateJobStatusByJobName(job.name, :failed)
                job.updateExecEndDate()
              end
            else
              jobs.push(job)
            end
          }
          # control flows to batch system, updated statuses are returned
          newStatuses, newSystemJobIds = batchSys.synchronizeJobsStatuses(jobs)
          # save new statuses to DB
          jobs.each_with_index() { |job, index|
            newStatus = newStatuses[index]
            newSystemJobId = newSystemJobIds[index]
            if(newStatus != job.status)
              rowsUpdated = job.dbu.updateJobStatusByJobName(job.name, newStatus)
              case newStatus
              when :submitted
                job.dbu.updateJobSubmitDateByJobName(job.name, Time.now())
              when :running
                job.dbu.updateJobExecStartDateByJobName(job.name, Time.now())
              when :completed, :failed
                job.dbu.updateJobExecEndDateByJobName(job.name, Time.now())
              end
            end
            if(newSystemJobId != job.batchSystemInfo.systemJobId)
              job.dbu.updateSystemInfoSystemJobIdByJobName(job.name, newSystemJobId)
            end
          }
          $stderr.puts('-'*50)
        }
      ensure
        if(@dbu)
          @dbu.clear(true) rescue nil
        end
      end
      # Must return a suitable exit code number
      return @exitCode
    end

    # ------------------------------------------------------------------
    # SCRIPT-SPECIFIC METHODS
    # - stuff needed to do actual program or drive 3rd party tools, etc
    # - repeatedly-used generic stuff is in library classes of course...
    # ------------------------------------------------------------------

    # @param [String] jobType get job name records for jobs which are candidates to be submitted
    #   on this host's batch sytem.
    # @return [Array<Hash>] the result set rows
    def getJobNameRows(jobType)
      statuses = [ 'entered', 'submitted', 'running' ]
      jobNameRows = @dbu.selectJobNamesBySystemInfoAndJobType(@host, @systemType, jobType, statuses)
      return jobNameRows
    end

    # Check a specific job's preconditions (if any) are met. If not all met
    # previously, evaluate the conditions now.
    # @param [BRL::Genboree::Prequeue::Job] job which to evaluate preconditions of
    # @param [JobUserInfo] userInfo struct with key info about the user whose job this is
    # @return [Symbol] indicating if all the preconditions are :none, :met, :notMet, :expired
    def checkPreconditions(job, userInfo)
      retVal = :notMet
      precondSet = job.preconditionSet
      # If no preconditionSet for jobs, it's good to go
      if(!precondSet.is_a?(PreconditionSet) or precondSet.count() <= 0)
        $stderr.puts "STATUS (#{getTimeDelta(true)}): #{job.name} has no preconditions. CAN BE SUBMITTED."
        retVal = :none
      else
        $stderr.puts "STATUS (#{getTimeDelta(true)}): #{job.name} has #{precondSet.count()} preconditions. Check status of preconditions:"
        if(precondSet.allMet?)
          $stderr.puts "  - (#{getTimeDelta(true)}) They have ALL been previously met. CAN BE SUBMITTED."
          retVal = :met
        else
          $stderr.puts "  - They have NOT ALL been previously met. Number met prior to now: #{precondSet.numMet.inspect} (#{getTimeDelta(true)})"
          if(precondSet.someExpired)
            $stderr.puts "  - At least 1 of the preconditions has expired prior to now. WILL NEVER BE SUBMITTED. (#{getTimeDelta(true)}) "
            retVal = :expired
          else
            $stderr.puts "  - None of the preconditions have expired prior to now. Update the status of preconditions:"
            # Assess all preconditions via PreconditionSet#update(), which will call evaluate
            #  each heretofore unmet condition to see if it is now met or not.
            # - this method automatically checks to see if need to init the Precondition objects within the PreconditionSet
            allMet = precondSet.update()
            retVal = (allMet ? :met : :notMet)
            $stderr.puts "    . Updated the status of the preconditions. All met NOW? #{retVal.inspect}. (#{getTimeDelta(true)})"
            # In case update() changed the state of some of the preconditions do a store/update as needed:
            numRowsUpdated = precondSet.store(@dbu)
            $stderr.puts "    . Also stored precondition status change [if any!] back into database. (#{getTimeDelta(true)})\n      Num rows updated (0 == no precondition status change): #{numRowsUpdated.inspect}"
            $stderr.puts "    . CAN BE SUBMITTED" if(retVal == :met)
          end
        end
      end
      return retVal
    end

    # Get key info about user who owns a job. Mainly local db userId and a hostAuthMap.
    # @param [BRL::Genboree::Prequeue::Job] job which to evaluate preconditions of
    # @return [JobUserInfo] job struct with key info about the user whose job this is
    def getJobUserInfo(job)
      # Get host auth map for user in job
      userRows = @dbu.getUserByName(job.user)
      userId = userRows.first['userId']
      hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, userId)
      return JobUserInfo.new(userId, hostAuthMap)
    end

    def getTimeDelta(asStr=false)
      currTime = Time.now()
      @prevTime = @startTime unless(@prevTime)
      retVal = (currTime - @prevTime)
      @prevTime = currTime
      return (asStr ? ("#{"%.3f" % retVal} secs") : retVal)
    end
  end # class JobsSubmitter
end ; end ; end ; end # module BRL ; module Genboree ; module Prequeue ; module Scripts


########################################################################
# MAIN - Provided in the scripts that implement deamon
########################################################################
# IF we are running this file (and not using it as a library), run it:
#if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))

  options = {
    :dir_mode   => :normal,
    :dir        => "/usr/local/brl/local/var",
    :multiple   => false,
    :ontop      => false,
    :mode       => :load,
    :backtrace  => true,
    :log_output => true
  }
  
  puts 'Start...'
  
  Daemons.run_proc("genboreeJobsSubmitter", options) do
    js = BRL::Genboree::Prequeue::Scripts::JobsSubmitter.new();
    loop do
      js.run()
      sleep(2)
    end
  end 
  
  puts 'Finish...'
  

  