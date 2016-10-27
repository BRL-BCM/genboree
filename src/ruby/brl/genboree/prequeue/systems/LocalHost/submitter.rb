#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/prequeue/systems/submitter'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/genboree/tools/toolWrapper'

module BRL ; module Genboree ; module Prequeue ; module Systems
  class LocalHostSubmitter < Submitter
    # Batch system-specifc sub-class for submitting to a local 'queue' that runs on the Genboree API web server machine.
    # Implements and/or overrides the methods of the parent Submitter class.
    #------------------------------------------------------------------
    # CLASS INSTANCE VARIABLES
    #------------------------------------------------------------------
    class << self
      # Set up class instance variables ; these are typically also set in the
      # subclasses to specific values (or to use these defaults if appropriate)
      LocalHostSubmitter.genbConf = Submitter.genbConf # Use whatever Submitter class has
      # @deprecated These class instance variables are deprecated.
      LocalHostSubmitter.rsyncCommand = LocalHostSubmitter.genbConf.rootRsyncUtility  # Some remote systems won't support this
      LocalHostSubmitter.jobsDirectory = LocalHostSubmitter.genbConf.prequeueJobsDir
      LocalHostSubmitter.workingDirectoryBase = "#{LocalHostSubmitter.genbConf.prequeueJobsDir}/scratch"
    end
    #------------------------------------------------------------------
    # CONSTANTS
    #------------------------------------------------------------------
    SYSTEM_TYPE = 'LocalHost'
    DEFAULT_WALLTIME = '168:00:00'
    DEFAULT_CONF = {
      'jobsDirectory'             => nil,
      'workingDirectoryBase'      => nil,
      'permissionRequestConf'     => {
        'sleepSecs'      => nil,
        'lockFileDir'    => nil,
        'maxRetries'     => nil,
        'retrySleepSecs' => nil,
        'lockFileName'   => nil,
        'maxOps'         => nil,
        'maxCores'       => nil,
        'maxMemPerJob'   => nil
      },
      'permissionReleaseConfFile' => nil
    }

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
    #         submission to an actual batch system. Should have be prequeued via the
    #         Job#prequeue() method at some point previously.
    def initialize(job, confFile=nil)
      super(job, confFile)
      # Make sure job has the commands info available
      job.loadCommands()
      # Ensure key variables are available
      # * Fall back on old gbConf properties if not set in conf file
      @rsyncCommand = @conf['rsyncCommand'] || self.class.genbConf.rootRsyncUtility
      @jobsDirectory = @conf['jobsDirectory'] || self.class.genbConf.prequeueJobsDir
      @workingDirectoryBase = @conf['workingDirectoryBase'] || "#{self.class.genbConf.prequeueJobsDir}/scratch"
      @workingDir = "#{@workingDirectoryBase}/#{job.name}"
      @jobDir = "#{@jobsDirectory}/#{job.extractJobPrefix()}/#{job.name}"
      # Names of key job files
      @clusterOutputLog = "#{@jobDir}/logs/job.o"
      @clusterErrorLog = "#{@jobDir}/logs/job.e"
      @clusterScript = "#{@jobDir}/scripts/job.pbs"
      @commandsScript = "#{@jobDir}/scripts/job.commands"
      # Resource constraint settings
      # * Fall back on old gbConf properties if not set in conf file
      @maxCores = @conf['maxCores'] || self.class.genbConf.gbMaxCores.to_i
      @maxMem   = @conf['maxMemPerJob'] || (self.class.genbConf.gbMaxMem ? self.class.genbConf.gbMaxMem.to_i : ( 3 * (1024**3)))
      # This file will be handed to a simple release-ops script when the job finishes running
      @permReleaseConfFile = @conf['permissionReleaseConfFile']
    end

    # Submit the job to the appropriate batch system. Implementation highly batch-system
    # specific.
    # [+job+] An instance of BRL::Genboree::Prequeue::Job, filled in appropriate for
    #         submission to an actual batch system. Should have be prequeued via the
    #         Job#prequeue() method at some point previously.
    # [+updateSystemJobId+] [optional; default=true] Boolean indicating whether the
    #                       submitter should record the specific job id the batch system
    #                       assigns upon job submission. This will be stored in the prequeue
    #                       database.
    # [+updateStatus+]      [optional; default=true] Boolean indicating whether the
    #                       submitter should update the status of the job record in the
    #                       prequeue database.
    # [+returns+]           Must return the system specific job id generated by the
    #                       batch system.
    def submit(job, updateSystemJobId=true, updateStatus=true)
      retVal = nil
      # Create final resting place for job files on network storage
      `mkdir -p #{@jobDir}/logs #{@jobDir}/scripts #{@jobDir}/scratch `
      # Extract directives info needed to compose or submit job appropriately
      extractDirectiveInfo(job)
      # Get resource directives, etc. Say, for creating cluster script file.
      ppn = @directives[:ppn] ? @directives[:ppn] : "1"
      ppn = ppn.to_s.split(/\+/).reduce(0) { |sum, ii| sum + ii.to_i }
      mem = @directives[:mem]
      mem = memStrToNumBytes(mem) if(mem)
      pvmem = @directives[:pvmem]
      pvmem = memStrToNumBytes(pvmem) if(pvmem)

      # Number of cores required should not exceed the number of cores available for all local jobs.
      if(ppn.to_i > @maxCores)
        msg = "CANNOT EXECUTE: Number of cores required to run this job: #{ppn.inspect} is more than number of cores available: #{@gbMaxCores}"
        File.open(@clusterErrorLog, 'w') { |ff|
          ff.puts(msg)
        }
        job.updateStatus(:failed)
        raise msg
      else
        # Check max memory allowed for local job does not exceed the amount of memory available for all local jobs.
        if( (pvmem and pvmem > @maxMem) or (mem and mem > @maxMem) )
          msg = "CANNOT EXECUTE: Amount of RAM required to run this job [max(#{mem.to_i}, #{pvmem.to_i})] is more than max RAM allowed for a single local job (#{@maxMem.inspect})"
          File.open(@clusterErrorLog, 'w') { |ff|
            ff.puts(msg)
          }
          job.updateStatus(:failed)
          raise msg
        else
          # Check the job lock file
          dbLock = BRL::Genboree::LockFiles::GenericDbLockFile.new(:custom, @conf['permissionRequestConf'])
          # Get immediate permission to run ppn ops or don't (no retries)
          havePermission = dbLock.getPermission(false, nil, ppn.to_i)
          if(havePermission) # Local 'queue' submit == execute job (no subordinate queuing system; job runs immediately in the background)
            # NOTE: permission for ops will be released as part of wrapper script. See makeCommandsScript()

            # Make commands script (the commands to run in the job)
            makeCommandsScript(job)
            # Make cluster script (the script run by the batch system)
            makeClusterScript(job, ppn)
            # Submit the job (run in background)
            submitCmd = "/bin/bash #{@clusterScript} > #{@clusterOutputLog} 2> #{@clusterErrorLog} &"
            submitCmdOut = `#{submitCmd}`
            exitCodeObj = $?.dup
            unless(exitCodeObj.success?)
              raise "Failed to submit #{SYSTEM_TYPE.inspect} job #{job.name.inspect} using command #{submitCmd.inspect}. Gave exit status #{exitCodeObj.exitstatus.inspect} and following output:\n\n#{submitCmdOut}\n\n"
            else
              # Extract process id from output
              @systemJobId = exitCodeObj.pid.to_s
              if(@systemJobId =~ /\S/)
                # Update status to submitted
                job.updateStatus(:submitted) if(updateStatus)
                # Record @systemJobId in prequeue table for later reference
                job.updateSystemJobId(@systemJobId) if(updateSystemJobId)
                retVal = @systemJobId
              else
                raise "Failed to get a sensible job id string from the #{SYSTEM_TYPE.inspect} batch system submission command. Found #{@systemJobId.inspect}. Are additional options to the submission command or even additional commands needed to get this important identifier from the system?"
              end
            end
          else
            # We'll return an exception instance that has a message, but really this should be an expected possibility and likely can be ignored/skipped.
            retVal = ExecutionPermissionError.new("CANNOT RUN RIGHT NOW: Could not get permission to execute local job. Will leave job status alone, so will try to get permission in the next iteration.")
          end
        end
      end
      return retVal
    end

    # Get an appropriate scratch dir (working dir) for the job to use when it
    # is running. Highly batch system-specific.
    def getScratchDir(job)
      return @workingDir
    end

    # Extract needed info from directive Hash. Much will be batch system-specific
    # and this may be how alternative queues get enough info in them to submit properly.
    # The default implementation extracts nothings (i.e. directives don't matter)
    def extractDirectiveInfo(job)
      retVal = nil
      @directives = {}
      directivesHash = job.batchSystemInfo.getDirectives(job)
      if(directivesHash)
        @directives[:ppn] = (directivesHash['ppn'] || 1)
        @directives[:nodes] = (directivesHash['nodes'] || 1)
        @directives[:walltime] = (directivesHash['walltime'] || DEFAULT_WALLTIME)
        @directives[:mem]       = (directivesHash['mem'] or nil)
        @directives[:pvmem]     = (directivesHash['pvmem'] or nil)
        retVal = @directives
      end
      return retVal
    end

    #------------------------------------------------------------------
    # HELPER METHODS (mainly for internal use)
    #------------------------------------------------------------------
    # Helper method to create the bash file
    def makeClusterScript(job, ppn)
      # Prime status updater command
      statusUpdateBase = "statusUpdater.rb --jobName=#{job.name} --status={status}"
      clusterScriptFile = File.open(@clusterScript, "w+")
      # Add pragmas to cluster script
      #clusterScriptFile.puts "#!/bin/bash -l "
      # Add any job-specific pre-commands
      if(job.preCommands)
        # Because job.loadCommands() has been run (done lazily), this should be an Array:
        job.preCommands.each { |preCommand|
          clusterScriptFile.puts preCommand
        }
      end
      # Add appropriate status updater command
      clusterScriptFile.puts statusUpdateBase.gsub(/\{status\}/, 'running')
      # Add fixed pre-commands to cluster script
      clusterScriptFile.puts "mkdir -p #{@workingDir}"
      clusterScriptFile.puts "cd #{@workingDir}"
      # Add actual comands-runner
      clusterScriptFile.puts "commandsRunner.rb -j #{job.name} -i #{@commandsScript} -e #{job.batchSystemInfo.getAdminEmails(job).join(',')}"
      clusterScriptFile.puts "commandsWrapperExitCode=$?"
      # Add any job-specific post-commands
      if(job.postCommands)
        # Because job.loadCommands() has been run (done lazily), this should be an Array:
        job.postCommands.each { |postCommand|
          clusterScriptFile.puts postCommand
        }
      end
      # Add appropriate status updater command
      clusterScriptFile.puts "if [ $commandsWrapperExitCode -eq #{BRL::Genboree::Tools::ToolWrapper::EXIT_OK} ]; then\n    "
      clusterScriptFile.puts statusUpdateBase.gsub(/\{status\}/, 'completed')
      clusterScriptFile.puts "elif [ $commandsWrapperExitCode -eq #{BRL::Genboree::Tools::ToolWrapper::EXIT_CANCELLED_JOB} ]; then\n    "
      clusterScriptFile.puts statusUpdateBase.gsub(/\{status\}/, 'canceled')
      clusterScriptFile.puts "else\n    "
      clusterScriptFile.puts statusUpdateBase.gsub(/\{status\}/, 'failed')
      clusterScriptFile.puts "fi"
      if(@permReleaseConfFile)
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Release perm command:\n\n  removeLock.rb #{ppn} custom #{@permReleaseConfFile}\n\n")
        clusterScriptFile.puts "removeLock.rb #{ppn} custom #{@permReleaseConfFile}"
      else # old approach, lots of assumptions/blindness and genboree.config.properties assumption
        clusterScriptFile.puts "removeLock.rb #{ppn}  "
      end

      # Add fixed clean up commands at end of postCommands
      # - In case working/scratch dir was somewhere else (big partition) during run, put anything left (hopefully compressed
      #   and cleaned up by the job or postCommands) in with rest of job subdirs.
      clusterScriptFile.puts "mv -f #{@workingDir}/* #{@jobDir}/scratch/ "
      #clusterScriptFile.puts 'qstat -f $PBS_JOBID '
      clusterScriptFile.puts "rm -rf #{@workingDir} "
      clusterScriptFile.close()
      return
    end

    # Helper method to create the ".commands" file used by this Submitter
    # subclass to run job commands in a Torque/Maui job environment.
    def makeCommandsScript(job)
      # Create commands script file
      commandsFile = File.open(@commandsScript, "w+")
      if(job.commands)  # Print out each command in order
        # Because job.loadCommands() has been run (done lazily), this should be an Array:
        job.commands.each { |command|
          commandsFile.puts command
        }
      end
      commandsFile.close()
      return
    end

    # Convert a mem request string like "12GB" or "12Gb" or "12GiB" or "12mb" to
    #   the full number of bytes (i.e. as an integer).
    # @param [String] memStr The mem request string
    # @return [Fixnum] The number of bytes represented by @memStr@
    def memStrToNumBytes(memStr)
      retVal = 0
      if(memStr)
        memStr.strip =~ /^(\d+)(.*)$/
        factor, units = $1.to_i, $2
        if(units)
          if(units =~ /^T/i)
            mult = (1024**4)
          elsif(units =~ /^G/i)
            mult = (1024**3)
          elsif(units =~ /^M/i)
            mult = (1024**2)
          elsif(units =~ /^K/i)
            mult = 1024
          else
            mult = 1 # probably not what you meant
          end
        else
          mult = 1
        end
        retVal = (factor * mult)
      end
      return retVal
    end
  end # class TorqueMauiSubmitter < Submitter
end ; end; end ; end # module BRL ; module Genboree ; module Prequeue ; module Systems
