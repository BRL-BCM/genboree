#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'json'
require 'brl/util/util'
require 'brl/script/scriptDriver'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/prequeue/systems/manager'
require 'brl/genboree/prequeue/job'

module BRL ; module Genboree ; module Prequeue ; module Scripts
  class AutoSubmitter < BRL::Script::ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = '0.1'
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      '--host'       =>  [:REQUIRED_ARGUMENT, '-H', 'The host domain name where batch system lives.'],
      '--systemType' =>  [:REQUIRED_ARGUMENT, '-s', 'The type of batch system which lives at host.'],
      '--jobType'    =>  [:REQUIRED_ARGUMENT, '-t', 'The type(s) of job to consider submitting. If more than one type, a CSV list.'],
      '--confFile'   =>  [:OPTIONAL_ARGUMENT, '-c', 'Path to prequeue-specific JSON conf file. Necessary to use tuning params and recommended instead of using genboree.config.properties for older params.']
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "Finds 'entered' jobs prequeued for running on the specified type of batch system which lives on specific host. Jobs headed for other types of batch system and/or for systems living on other hosts are ignored.",
      :authors      => [ "Andrew R Jackson (andrewj@bcm.edu)" ],
      :authors      => [ "Andrew R Jackson (andrewj@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} --host=brlhead.brl.bcmd.bcm.edu --systemType=TorqueMaui --jobType=gbToolJob",
        "#{File.basename(__FILE__)} -H brlhead.brl.bcmd.bcm.edu -s TorqueMaui -t gbToolJob,pipelineJob -c /usr/local/brl/local/conf/prequeue.conf.json",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    #------------------------------------------------------------------
    # CONSTANTS
    #------------------------------------------------------------------
    WINDOW_TOO_BIG = 300
    PAUSE_TOO_SMALL = 1
    PAUSE_TOO_BIG = 58
    DEFAULT_CONF = {
      'lockFile'           => nil,
      'iteratedSubmission' => { 'on' => false, 'pause' => 5, 'window' => 295, 'maxNum' => 59, 'maxFailedLocks' => 10 },
      'submission'         => { 'pauseLen' => (1 * 30), 'pauseJobs' => 250, 'confFile' => nil }
    }
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
    # Conf file path
    attr_accessor :confFile
    # Conf file contents
    attr_accessor :conf

    # ------------------------------------------------------------------
    # IMPLEMENTED INTERFACE METHODS
    # ------------------------------------------------------------------
    # run()
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . @optsHash contains the command-line args, keyed by --longName
    def run()
      @myPid = $$
      @startTime = Time.now()
      jobsSubmittedCount = 0
      haveLock = fh = nil
      # First process args and init and stuff
      validateAndProcessArgs()
      begin
        @err = nil
        @exitCode = EXIT_OK
        # Try to get file lock so we don't collide with other related auto-scripts.
        # We'll exit if we can't immediately get the lock (some other related script is running).
        # NOTE (changed to iterative approach): Since this submitter is run via cron and only wakes up once/min, lock contention is
        #   unlikely unless submission is taking a very very long time for some reason. To decrease
        #   the amount of "dead time" between cron runs that submit jobs to the batch processing system
        #   --especially in the face of quite fast local jobs (some file moves tend to be just a few sec)
        #   PLUS very fast processing of the prequeue (low job entry rate and/or very fast submission speed)
        #   --rather than get this lock & submit some jobs just once change to do up to X times per run,
        #   pausing N secs between and do this ONLY while nowTime < (@startTime + 55sec). We'll stop/quit
        #   iteration if we fail to get the lock, since we've run into another auto-submitter process
        #   that's doing the same thing. NOTE: because *local* submission 'queue' jobs are going to
        #   execute right away (available resources allowing), iteration also allows for more local jobs
        #   to be retired per submission cycle; this has no effect on actual batch submission job execution
        #   rates, only on rate of queuing.
        iterNum = 0
        failedLockAttempts = 0
        while(  (iterNum < @conf['iteratedSubmission']['maxNum']) and
                (Time.now() < (@startTime + @conf['iteratedSubmission']['window'])))
          $stderr.debugPuts(__FILE__, __method__, "#{@myPid} STATUS", "BEGIN: Iteration #{iterNum+1} / max #{@conf['iteratedSubmission']['maxNum']}") if(@verbose)
          # Pause between submission iterations
          sleep(@conf['iteratedSubmission']['pause']) unless(iterNum == 0)
          # Lock file to prevent collision with other submitters (rarely, one run next minute by cron)
          begin
            fh = File.open(@prequeueLockFile, 'w+')
            fh.flock(File::LOCK_EX | File::LOCK_NB) # raises Errno::EAGAIN if can't get lock immediately
            haveLock = true
            failedLockAttempts = 0
          rescue Errno::EAGAIN => lockErr
            haveLock = false
            failedLockAttempts += 1
            if(failedLockAttempts < @conf['iteratedSubmission']['maxFailedLocks'])
              $stderr.puts "#{@myPid} WARNING: Could not get lock on file #{@genbConf.prequeueLockFile.inspect}. Another script probably running. Will try again next iteration." if(@verbose)
            else # Too many failed lock attempts in a row ; too much lock contention.
              raise lockErr # Re-raise this no-lock error to break out of iteration while-loop for a specific reason
            end
          end

          if(haveLock)
            @jobTypes.each { |jobType|
              @prevTime = Time.now()
              # Identify 'entered' jobType jobs headed to batch system type @systemType on @host
              jobNameRows = getJobNameRows(jobType)
              $stderr.puts "\n#{@myPid} STATUS (#{getTimeDelta(true)}): Iteration #{iterNum+1}. Found #{jobNameRows.size} #{jobType.inspect} type candidate jobs in database." if(jobNameRows.size > 0 or @verbose)
              if(jobNameRows and !jobNameRows.empty?)
                jobNameRows.each { |row|
                  $stderr.puts('-'*50) if(@verbose)
                  begin
                    # Create Job object from job id
                    job = BRL::Genboree::Prequeue::Job.fromName(row['name'], @dbu)
                    # Get user info for this job's user
                    userInfo = getJobUserInfo(job)
                    # Check preconditions for this job
                    preconditionsMet = checkPreconditions(job, userInfo)
                    if((preconditionsMet == :none) or (preconditionsMet == :met))
                      subStart = Time.now
                      # Get Submitter instance for Job
                      #submitter = job.submitter
                      submitterClass = BRL::Genboree::Prequeue::BatchSystemInfo.submitters[@systemType]
                      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Submitter Class: #{submitterClass.inspect}")
                      submitter = submitterClass.new(job, @conf['submission']['confFile'])
                      # Submit job to the batch job processing system, also updating appropriate time stamp and recording systemJobId.
                      # * Note that the batch job processing system is likely not to run the job right away (unless it's a local job
                      #   that obtains permission to run, in which case it's going to be running in the background).
                      systemJobId = submitter.submit(job)
                      if(systemJobId and systemJobId =~ /\S/)
                        $stderr.puts "#{@myPid} STATUS (#{"%.3f" % (Time.now - subStart)} secs): Job #{systemJobId.inspect} submitted."
                        # Check if we should pause the submission of jobs for a bit.
                        jobsSubmittedCount += 1
                        if(jobsSubmittedCount > 1 and (jobsSubmittedCount % @conf['submission']['pauseJobs'] == 0))
                          $stderr.puts "#{@myPid} STATUS (#{getTimeDelta(true)}): submitted #{jobsSubmittedCount} / #{jobNameRows.size} jobs. Pausing for #{@conf['submission']['pauseLen']} seconds."
                          sleep(@conf['submission']['pauseLen'])
                        end
                      elsif(systemJobId.is_a?(BRL::Genboree::Prequeue::Systems::ExecutionPermissionError))
                        # Expected possibility...job execution could not happen right now (relevant for LocalHost type jobs)
                        $stderr.puts "#{@myPid} STATUS (#{getTimeDelta(true)}): #{systemJobId.message}" if(@verbose)
                      else
                        raise "ERROR: submission failed in submit() but wasn't noticed in that method??"
                      end

                    elsif(preconditionsMet == :expired)
                      $stderr.puts "#{@myPid} STATUS (#{getTimeDelta(true)}): Preconditions not all met before their expiration periods. Job #{job.name} will NEVER run. Updating job with 'depsExpired' status."
                      @dbu.updateJobStatusByJobName(job.name, :depsExpired)
                    else
                      $stderr.puts "#{@myPid} STATUS (#{getTimeDelta(true)}): Preconditions not all met for job #{job.name}. Updating job with 'wait4deps' status"
                      @dbu.updateJobStatusByJobName(job.name, :wait4deps)
                    end
                  rescue Exception => @err
                    $stderr.debugPuts(__FILE__, __method__, "\nERROR SUBMITTING JOB", "Could not submit job. Job name row: #{row.inspect}. Will continue looking at more jobs and re-raise this when done. (See 'DEFERRED EXCEPTION' below. Only last deferred job error will be reported below.)\n\n")
                    @errUserMsg = "DEFERRED EXCEPTION => #{@err.message}\nJob Row:  #{row.inspect}\nJob object:  #{job.inspect}"
                    @errInternalMsg = @errUserMsg
                    @exitCode = 44
                  ensure
                    if(job and job.is_a?(BRL::Genboree::Prequeue::Job))
                      # Done with job, but leave @dbu connection stuff alone; @dbu being reused for all jobs.
                      job.clear(false) rescue false
                    end
                  end
                }
                $stderr.puts('-'*50) if(@verbose)
              end
            }
          end

          # Regardless of whether this iteration proceeded or collided:
          iterNum += 1
        end
        # Log record unless there were no jobs found
        unless(jobsSubmittedCount <= 0)
          $stderr.puts "#{'-'*50}"
          $stderr.debugPuts(__FILE__, __method__, "#{@myPid} STATUS (#{"%.3f" % (Time.now-@startTime)} secs)", "DONE: submitted #{jobsSubmittedCount} #{@jobTypes.inspect} type jobs over #{iterNum} / max #{@conf['iteratedSubmission']['maxNum']} job-scanning iterations during a max #{@conf['iteratedSubmission']['window'].inspect} sec window.")
          $stderr.puts "#{'-'*50}"
        end
        $stderr.puts "#{'='*20} #{@myPid} ALL DONE #{'='*20}"
      rescue Errno::EAGAIN => lockErr
        haveLock = false
        $stderr.puts "#{@myPid} WARNING: Could not get lock on file #{@genbConf.prequeueLockFile.inspect} #{@conf['iteratedSubmission']['maxFailedLocks'].inspect} times in a row. Will abandon this run." if(@verbose)
        $stderr.puts "#{'='*20} #{@myPid} TOO MUCH LOCK CONTENTION. PROBABLY ANOTHER RUN HAS STARTED UP. WON'T CONTINUE. #{'='*20}"
      rescue Exception => err
        # May have lock still; ensure block should see it cleared, especially if we set haveLock
        haveLock = true
        $stderr.debugPuts(__FILE__, __method__, "#{@myPid} ERROR", "Unexpected error.\n  Error Class: #{err.class}\n  Error Message: #{err.message}\n  Error Trace:\n\n#{err.backtrace.join("\n")}")
      ensure
        if(@dbu)
          @dbu.clear(true) rescue nil
        end
        if(fh and haveLock) # Aggressively try to release lock (esp if Exception raised of some kind)
          fh.flock(File::LOCK_UN) rescue $stderr.puts("#{@myPid} ERROR: could not release lock on #{genbConf.prequeueLockFile.inspect}!! (possibly didn't have it due to unexpected exception)")
        end
        # Did we get an error for some jobs?
        unless(@exitCode == EXIT_OK)
          # Re-raise the @err that was saved within the job-loop above. We didn't re-raise before because then no subsequent jobs would be submitted!
          raise @err
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

    # @note Almost all ScriptDriver subclasses should have this method and call it from
    #   their run() implementation. A place to go through command line options and extract
    #   needed settings and state.
    # @return [Boolean] Indicating setup using command line options was sucessful or not.
    def validateAndProcessArgs()
      retVal = nil
      # Initialize state
      @host = @systemType = @jobType = nil
      @genbConf = BRL::Genboree::GenboreeConfig.load
      # Parse args
      @host = @optsHash['--host'].strip
      @systemType = @optsHash['--systemType'].strip
      @jobTypes = @optsHash['--jobType'].strip.split(/,/)
      @verbose = @optsHash.key?('--verbose')
      @confFile = @optsHash['--confFile'].to_s.strip
      # Load and inspect key items of conf file [if present]
      if(@confFile.empty?)
        @conf = self.class::DEFAULT_CONF.deep_clone
      else
        raise ArgumentError, "ERROR: The conf file #{@confFile.inspect} provided is not readable." unless(File.readable?(@confFile))
        conf = JSON.parse(File.read(@confFile))
        @conf = self.class::DEFAULT_CONF.merge(conf)
      end
      @prequeueLockFile = @conf['lockFile'] || @genbConf.prequeueLockFile
      # If not doing iterated submissions, arrange for "single iteration"
      # Make sure iteration settings make sense, issue warnings if bad and raise error if dangerous
      if(@conf['iteratedSubmission']['on'])
        # Allow some amount of overlapping autoSubmitters to reduce delay-before-move latency.
        # if(@conf['iteratedSubmission']['window'] >= WINDOW_TOO_BIG)
        #   raise ArgumentError, "ERROR: Your iteration window size of #{@conf['iteratedSubmission']['window'].inspect} is too big, given that the auto-submitter is likely launched 1/minute by cron. You are almost guaranteeing lock file contention for no reason. Iteration and this setting is for arranging more rapid submission WITHIN cron's 1 minute resolution."
        # end
        if(@conf['iteratedSubmission']['pause'] <= PAUSE_TOO_SMALL or @conf['iteratedSubmission']['pause'] >= PAUSE_TOO_BIG)
          raise ArgumentError, "ERROR: Your pause between iterations of #{@conf['iteratedSubmission']['pause'].inspect} is too #{@conf['iteratedSubmission']['pause'] <= PAUSE_TOO_SMALL ? 'small' : 'big'} to make sense, given that the auto-submitter runs in cron at max rate of once/minute."
        elsif((@conf['iteratedSubmission']['pause'] * @conf['iteratedSubmission']['maxNum']) > @conf['iteratedSubmission']['window'])
          $stderr.puts "#{'*'*40}\n#{@myPid} WARNING: Your pause of #{@conf['iteratedSubmission']['pause'].inspect} between iterations together with your maximum number of iterations of #{@conf['iteratedSubmission']['maxNum'].inspect} are too big; the total pausing alone is bigger than your window size of #{@conf['iteratedSubmission']['window'].inspect} secs, so they don't make much sense. Are you sure you understand these settings?\n#{'*'*40}\n"
        end
      else # If not doing iterated submissions, arrange for "single iteration"
        @conf['iteratedSubmission']['maxNum'] = 1
      end
      # Get DBUtil instance using default dbrcKey etc.
      @dbu = BRL::Genboree::Prequeue::Job.getDBUtil()
      retVal = true
      return retVal
    end

    # @param [String] jobType get job name records for jobs which are candidates to be submitted
    #   on this host's batch sytem.
    # @return [Array<Hash>] the result set rows
    def getJobNameRows(jobType)
      statuses = [ 'entered', 'wait4deps' ]
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
        $stderr.puts "#{@myPid} STATUS (#{getTimeDelta(true)}): #{job.name} has no preconditions. CAN BE SUBMITTED." if(@verbose)
        retVal = :none
      else
        $stderr.puts "#{@myPid} STATUS (#{getTimeDelta(true)}): #{job.name} has #{precondSet.count()} preconditions. Check status of preconditions:"
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
  end # class AutoSubmitter
end ; end ; end ; end # module BRL ; module Genboree ; module Prequeue ; module Scripts

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Genboree::Prequeue::Scripts::AutoSubmitter)
end
