#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/genboree/prequeue/systems/batchSystem'

module BRL ; module Genboree ; module Prequeue ; module Systems
  class LocalHost < BatchSystem
    #------------------------------------------------------------------
    # CLASS INSTANCE VARIABLES
    #------------------------------------------------------------------
    class << self
      # Set up class instance variables ; these are typically also set in the
      # subclasses to specific values (or to use these defaults if appropriate)
      LocalHost.genbConf = BRL::Genboree::GenboreeConfig.load()
      LocalHost.jobsDirectory = LocalHost.genbConf.prequeueJobsDir
      LocalHost.workingDirectoryBase = LocalHost.genbConf.workingDirectoryBase
    end
    #------------------------------------------------------------------
    # INSTANCE METHODS
    #------------------------------------------------------------------
    # Initializer. Sub-classes should make sure to call super(job) in their
    # implementations of initialize(job) [if any] in case some generic operations
    # are added.
    # [+job+] An instance of BRL::Genboree::Prequeue::Job, filled in appropriate for
    #         submission to an actual batch system. Should have be prequeued via the
    #         Job#prequeue() method at some point previously.
    def initialize()
      @availableCores  = LocalHost.genbConf.gbMaxCores.to_i
      @availableMemory = LocalHost.genbConf.gbMaxMem.to_i
    end

    # Synchronizes the jobs statuses with the appropriate batch system. 
    # Submits jobs when possible and refreshes their statuses.
    # It doesn't update data in the database. It doesn't change status in the job object.
    # Implementation highly batch-system specific.
    # [+jobs+] An array of BRL::Genboree::Prequeue::Job, filled in appropriate for
    #         submission to an actual batch system. Should have be prequeued via the
    #         Job#prequeue() method at some point previously.
    # [+returns+] An array of refreshed jobs statuses.
    def synchronizeJobsStatuses(jobs)
      freeCores  = @availableCores
      freeMemory = @availableMemory
      newStatuses = Array(jobs.length())
      newSystemJobIds = Array(jobs.length())
      # go through all jobs, check statuses of running one and calculate free cores and memory
      jobs.each_with_index{ |job, index|
        status = job.status()
        systemJobId = job.batchSystemInfo.systemJobId
        if(status == :running)
          begin
            pid, exitCode = Process.waitpid2(systemJobId.to_i(), Process::WNOHANG)
            if(pid != nil)
              status = (exitCode == 0) ? (:completed) : (:failed)
            else 
              ppn, mem = getResourcesRequirements(job)
              freeCores  -= ppn
              freeMemory -= mem
            end
          rescue Exception => e
            status = :failed
            $stderr.puts("Exception caught in #{__FILE__} at line #{__LINE__}, message: #{e.message}, backtrace: #{e.backtrace.to_s()}")
          end
        end
        newStatuses[index] = status
        newSystemJobIds[index] = systemJobId
      }
      # go through all jobs and try to submit them if there is enough resources
      jobs.each_with_index{ |job, index|
        status = job.status()
        if(status == :entered)
          begin
            ppn, mem = getResourcesRequirements(job)
            if(ppn <= freeCores and mem <= freeMemory)
              workingDir = "#{self.class.workingDirectoryBase}/#{job.name}"
              jobDir = "#{self.class.jobsDirectory}/#{job.extractJobPrefix()}/#{job.name}"
              # Create final resting place for job files
              `mkdir -p #{jobDir}/logs #{jobDir}/scripts #{jobDir}/scratch `
              # Generate scripts
              generateBashScripts(outDir="#{jobDir}/scripts", job, workingDir, jobDir)
              # Generate file with list of nodes
              fileWithNodes = "#{jobDir}/scripts/nodelist"
              outFile = File.open(fileWithNodes, 'w')
              for iter in 1..ppn
                outFile.puts('localhost')
              end
              outFile.close()
              # Create child process
              pid = fork()
              if(pid == nil)
                # this is executed in the child process only  
                clusterOutputLog = "#{jobDir}/logs/job.o"
                clusterErrorLog = "#{jobDir}/logs/job.e"
                clusterScript = "#{jobDir}/scripts/job.cluster"
                $stdout.reopen("#{clusterOutputLog}", 'w')
                $stderr.reopen("#{clusterErrorLog}", 'w')
                exec("/bin/bash -l -c 'export PBS_NODEFILE=#{fileWithNodes}; source #{clusterScript}'")
                # end of child process
              end
              # Parent process
              newSystemJobIds[index] = pid.to_s()
              status = :running
              freeCores  -= ppn
              freeMemory -= mem            
            elsif(ppn > @availableCores)
              raise "Number of cores required to run this job: #{ppn} is more than number of cores available: #{@availableCores}"
            elsif(mem > @availableMemory)
              raise "Amount of RAM required to run this job (#{mem}) is more than max RAM allowed (#{@availableMemory})"
            end
          rescue Exception => e
            status = :failed
            $stderr.puts("Exception caught in #{__FILE__} at line #{__LINE__}, message: #{e.message}, backtrace: #{e.backtrace.to_s()}")
          end
          newStatuses[index] = status
        end
      }
      return newStatuses, newSystemJobIds
    end

        
    # helpers
    # returns cores, memory in MB
    def getResourcesRequirements(job)
      nodes    = 1
      ppn      = 1
      walltime = 99999 # DEFAULT_WALLTIME
      mem      = '128M'
      pmem     = '128M'
      vmem     = '128M'
      pvmem    = '128M'
      directivesHash = job.batchSystemInfo.getDirectives(job)
      if(directivesHash)
        nodes    = directivesHash['nodes'   ] if directivesHash['nodes'   ]
        ppn      = directivesHash['ppn'     ] if directivesHash['ppn'     ]
        walltime = directivesHash['walltime'] if directivesHash['walltime']
        mem      = directivesHash['mem'     ] if directivesHash['mem'     ]
        pmem     = directivesHash['pmem'    ] if directivesHash['pmem'    ]
        vmem     = directivesHash['vmem'    ] if directivesHash['vmem'    ]
        pvmem    = directivesHash['pvmem'   ] if directivesHash['pvmem'   ]
      end
      nodes = nodes.to_i
      ppn   = ppn.to_s.split(/\+/).reduce(0) { |sum, ii| sum + ii.to_i }
      mem   = [memStrToNumBytes(mem.to_s()  ) / (1024*1024), 1].min()
      pmem  = [memStrToNumBytes(pmem.to_s() ) / (1024*1024), 1].min()
      vmem  = [memStrToNumBytes(vmem.to_s() ) / (1024*1024), 1].min()
      pvmem = [memStrToNumBytes(pvmem.to_s()) / (1024*1024), 1].min()
      return (ppn*nodes), [mem, pmem*ppn*nodes, vmem, pvmem*ppn*nodes].max()
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
    
  end
end ; end ; end ; end # module BRL ; module Genboree ; module Prequeue ; module Systems
  