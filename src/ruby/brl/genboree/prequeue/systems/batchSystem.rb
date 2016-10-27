#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'

module BRL ; module Genboree ; module Prequeue ; module Systems
  class BatchSystem
    # Abstract parent class of batch system-specific BatchSystem subclasses.
    # Defines interface methods and inheritable generic methods [if any]
    #------------------------------------------------------------------
    # CLASS INSTANCE VARIABLES
    #------------------------------------------------------------------
    class << self
      # Set up class instance variables ; these are typically also set in the
      # sub-classes to specific values (or to use these defaults if appropriate)
      attr_accessor :genbConf, :rsyncCommand, :jobsDirectory, :workingDirectoryBase
      Submitter.genbConf = BRL::Genboree::GenboreeConfig.load()
      Submitter.rsyncCommand = nil
      Submitter.jobsDirectory = nil
      Submitter.workingDirectoryBase = nil
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
    #         submission to an actual batch system. Should have be prequeued via the
    #         Job#prequeue() method at some point previously.
    def initialize()
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
      raise "Interface Method '#{__method__}()' Not Implemented!"
    end

    #------------------------------------------------------------------
    # HELPER METHODS (mainly for internal use)
    #------------------------------------------------------------------
    # Helper method to create job.commands and job.cluster files in the given directory.
    def generateBashScripts(outDir, job, workingDir, jobDir, clusterScriptHeader='')
      # Names of key job files
      commandsScript = "#{jobDir}/scripts/job.commands"
      outCommandScript = "#{outDir}/job.commands"
      outClusterScript = "#{outDir}/job.cluster"
      clusterScriptFile = File.open(outClusterScript, "w+")
      clusterScriptFile.puts "#!/bin/bash"
      clusterScriptFile.puts "set -e"
      clusterScriptFile.puts "#{clusterScriptHeader}"
      # Add any job-specific pre-commands
      if(job.preCommands)
        # Because job.loadCommands() has been run (done lazily), this should be an Array:
        job.preCommands.each { |preCommand|
          next if (preCommand =~ /^chown/ or preCommand =~ /^chgrp/)
          clusterScriptFile.puts preCommand  
        }
      end
      # Add fixed pre-commands to cluster script
      clusterScriptFile.puts "umask 022"
      clusterScriptFile.puts "mkdir -p #{workingDir}"
      clusterScriptFile.puts "set +e"
      clusterScriptFile.puts "cd #{workingDir}"
      clusterScriptFile.puts "commandsRunner.rb -j #{job.name} -i #{commandsScript} -e #{job.batchSystemInfo.getAdminEmails(job).join(',')}"
      clusterScriptFile.puts "exitCode=$?"
      # Add any job-specific post-commands
      if(job.postCommands)
        # Because job.loadCommands() has been run (done lazily), this should be an Array:
        job.postCommands.each { |postCommand|
          next if (postCommand =~ /^chown/ or postCommand =~ /^chgrp/)
          clusterScriptFile.puts postCommand
          if (postCommand !~ /^module/)
            clusterScriptFile.puts "if [ $? -ne 0 ]; then\n"
            clusterScriptFile.puts "  exitCode=1"
            clusterScriptFile.puts "fi"
          end
        }
      end
      # Add fixed clean up commands at end of postCommands
      clusterScriptFile.puts "mv -f #{workingDir}/* #{jobDir}/scratch/ "
      clusterScriptFile.puts "if [ $? -ne 0 ]; then\n"
      clusterScriptFile.puts "  exitCode=1"
      clusterScriptFile.puts "fi"
      clusterScriptFile.puts "rm -rf #{workingDir} "
      clusterScriptFile.puts "if [ $? -ne 0 ]; then\n"
      clusterScriptFile.puts "  exitCode=1"
      clusterScriptFile.puts "fi"
      clusterScriptFile.puts "exit $exitCode"
      clusterScriptFile.close()
      # Create commands script file
      commandsFile = File.open(outCommandScript, "w+")
      if(job.commands)  # Print out each command in order
        # Because job.loadCommands() has been run (done lazily), this should be an Array:
        job.commands.each { |command|
          next if (command =~ /^chown/ or command =~ /^chgrp/)
          commandsFile.puts(command)
        }
      end
      commandsFile.close()
    end

  end # class Submitter
end ; end ; end ; end # module BRL ; module Genboree ; module Prequeue ; module Systems
