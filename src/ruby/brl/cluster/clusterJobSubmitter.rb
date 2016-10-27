#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################
require 'cgi'
require 'rubygems'
require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'
require 'brl/cluster/clusterJob'
require 'brl/cluster/clusterJobUtils'

module BRL;
  module Cluster
    # == Overview
    # This class is intended to be used to sumbit a filled ClusterJob object to run a job on a cluster.
    # This class is primarily tasked with creating the context and environment necessary for the job
    # to run. This includes creating working directories, moving input files over, creating script files for submission to the cluster,
    # copying back output files and notifying the user as appropriate.
    # == Example usage:
    #
    # === E.g. Simple ClusterJob object submission

    #   require 'ClusterJob'
    #   clusterJobSubmitter = ClusterJobSubmitter.new
    #   clusterJobSubmitter.submitJob(clusterJob)
    class ClusterJobSubmitter
      # GenboreeConfig object used to extract additional environment settings
      @@genbConf = BRL::Genboree::GenboreeConfig.load()
      # Location to store cluster logs (output and error files)
      @@clusterLogsDirectory = @@genbConf.clusterLogsDirectory
      # Location to store cluster logs (output and error files)
      @@clusterScriptsDirectory = @@genbConf.clusterScriptsDirectory
      # Location to store copy of cluster jobFile.json files (for job tracking)
      @@clusterJobFilesDirectory = @@genbConf.clusterJobFilesDirectory
      # Path to rsync utility used to copy files
      @@rootRsyncUtility = @@genbConf.rootRsyncUtility
      # Path to parent directory of the job directory
      @@workingDirectoryBase = @@genbConf.workingDirectoryBase
      @@statusUpdater = "clusterJobStatusUpdater.rb"


      # CONSTRUCTOR. Creates an object to submit jobs to the cluster
      # Initializes member variables to appropriate states
      def initialize()
        # The output directory to copy output files back to
        @outputDirectory = nil
        # The 'current directory' for the job on the cluster
        @workingDirectory = nil
        # The name of the bash script to execute as a cluster job
        @bashScriptName = nil
        # The output file for the job
        @scriptOutputFile = nil
        # The error file for the job
        @scriptErrorFile = nil
      end


      # Creates the appropriate bash script for submission of the job to the cluster from the supplied
      # ClusterJob object
      # [+clusterJob+] Filled ClusterJob object from which a bash script file is generated
      # [+returns+]    0 if the bash script was successfully created
      #                nil otherwise
      def CreateBashScript(clusterJob)
        retVal = nil
        begin
          # Set up requested context/environment variables
          contextHash = nil
          genbConfRewrite = nil
          envVarRewrite = nil
          pbsDirectives = {}
          if(clusterJob.jsonContextString =~ /\S/)
            contextHash = JSON.parse(clusterJob.jsonContextString)
            if(contextHash.key?("genbConfig"))
              genbConfRewrite = true
            end
            if(contextHash.key?("env"))
              envVarRewrite = true
            end
            if(contextHash.key?("pbsDirectives") and contextHash['pbsDirectives'].is_a?(Hash))
              pbsDirectives = contextHash['pbsDirectives']
            end
          end

          indentLevel = 0
          indentStr = "  "
          bashScriptFilePath = "#{@@clusterScriptsDirectory}/#{@bashScriptName}.pbs"
          bashScriptFile = File.new("#{@@clusterScriptsDirectory}/#{@bashScriptName}.pbs", "w+")
          bashScriptFile.chmod(0755)

          bashScriptFile.sync = true
          pbsCommands = clusterJob.pbsCommands
          commandsFilePath = "#{@@clusterScriptsDirectory}/#{@bashScriptName}.commands"
          commandsFile = File.new(commandsFilePath, "w+")
          commandsFile.chmod(0755)

          bashScriptFile.puts "#!/bin/bash -l"
          #
          pbsCores = (pbsDirectives['cores'] || "-l nodes=1:ppn=1")
          pbsWalltime = (pbsDirectives['walltime'] || "-l walltime=168:00:00")
          bashScriptFile.puts "#PBS #{pbsCores}"
          bashScriptFile.puts "#PBS #{pbsWalltime}"
          @scriptOutputFile = "#{@@clusterLogsDirectory}/#{clusterJob.jobName}.o"
          @scriptErrorFile = "#{@@clusterLogsDirectory}/#{clusterJob.jobName}.e"
          bashScriptFile.puts "#PBS -o #{@scriptOutputFile}"
          bashScriptFile.puts "#PBS -e #{@scriptErrorFile}"
          bashScriptFile.puts "#PBS -q #{clusterJob.queueName}"
          statusUpdaterString="#{@@statusUpdater} -j #{clusterJob.id} -u \'running\' -c \$PBS_JOBID -h \"\`hostname\`\" -d #{@@genbConf.schedulerDbrcKey} -n #{@@genbConf.schedulerTable} -b \"\`date\`\""
          statusUpdaterString << " -p #{CGI.escape(pbsCommands)}" if(!pbsCommands.nil? and !pbsCommands.empty?)
          bashScriptFile.puts statusUpdaterString

          bashScriptFile.puts "mkdir #{@workingDirectory}"
          bashScriptFile.puts "cd #{@workingDirectory}"

          # Copy requested input files into working directory
          clusterJob.inputFiles.each { |inputFile|
            bashScriptFile.puts "echo '----------------------------------' "
            # rsync used to use -rltgoDvz but many of those seem inappropriate (goD) and/or are failing (t); also remove -e for ssh (default anyway)
            bashScriptFile.puts "#{@@rootRsyncUtility} -rlvz #{inputFile} . 2>&1 "
            if(inputFile =~ /jobFile\.json/)
              jobFileName = File.basename(inputFile)
              bashScriptFile.puts "#{@@rootRsyncUtility} -rlvz #{jobFileName} #{@@clusterJobFilesDirectory}/#{clusterJob.jobName}.#{jobFileName} 2>&1 "
            end
            bashScriptFile.puts "echo '----------------------------------' "
          }

          oldValuesHash = Hash.new

          unless(genbConfRewrite.nil?)
            commandsFile.puts "genbConfigRewriter.rb -j #{CGI.escape(clusterJob.jsonContextString)}"
            oldValuesHash["GENB_CONFIG"] = ENV["GENB_CONFIG"]
            commandsFile.puts "export GENB_CONFIG=./genboree.config"
          end
          unless(envVarRewrite.nil?)
            contextHash["env"].each_key { |key|
              oldValuesHash[key] = ENV[key]
              commandsFile.puts "export #{key}=#{contextHash["env"][key]}"
            }
          end


          # Print out each command in order into bash script file
          clusterJob.commands.each { |command|
            unescCmd = CGI.unescape(command)
            #unescCmd.gsub!(/"/, '\\\"')
            #commandsFile.puts "/bin/bash -l -c \" #{CGI.unescape(unescCmd)} \" "
            #commandsFile.puts "/bin/bash -l -c \" #{unescCmd} \" "
            commandsFile.puts unescCmd
          }

          unless (genbConfRewrite.nil?)
            commandsFile.puts "rm ./genboree.config"
          end

          # Copy contents of working directory to output directory
          if(!clusterJob.outputFileList.empty?)
            commandsFile.puts "fileMover.rb -d . -s #{CGI.escape(JSON.generate(clusterJob.outputFileList))}"
          end

          # Add any special cleanup commands:
          if(clusterJob.cleanUpCommands and clusterJob.cleanUpCommands.is_a?(Array))
            clusterJob.cleanUpCommands.each { |cmd|
              commandsFile.puts cmd
            }
          end
          commandsFile.close

          oldValuesHash.each_key{|key| commandsFile.puts "export #{key}=#{oldValuesHash[key]}"}
          # Delete working directory if so requested
          # Add the additional pbs commands if required (For changing env vars if launching from dev machine)


          if(!pbsCommands.nil?)
            if(!pbsCommands.empty?)
              pbsCommands.strip!
              cmds = JSON.parse(pbsCommands)
              cmds.each { |pbsCmd|
                bashScriptFile.puts(CGI.unescape(pbsCmd))
              }
            end
          end
          # Now arrange for actual commands to be run via wrapper
          bashScriptFile.puts "commandWrapper.rb -i #{@@clusterScriptsDirectory}/#{@bashScriptName}.commands -e #{clusterJob.notificationEmail} -j #{clusterJob.jobName}"
          bashScriptFile.puts "execCode=$?"
          if(@outputDirectory and  !clusterJob.outputDirectory.empty?)
            # rsync used to use -rltgoDvz but many of those seem inappropriate (goD) and/or are failing (t); also remove -e for ssh (default anyway)
            bashScriptFile.puts "#{@@rootRsyncUtility} -rlvz  #{@workingDirectory}/ #{@outputDirectory}"
          end
          # Assess final job status to notify user with error messages if any.
          # Also call status updater script to update status information in scheduler table
          bashScriptFile.puts "if [ $execCode -eq 0 ]; then"
          statusUpdaterString = "#{@@statusUpdater} -j #{clusterJob.id} -u \'completed\' -d #{@@genbConf.schedulerDbrcKey} -n #{@@genbConf.schedulerTable} -e \"\`date\`\""
          statusUpdaterString << " -p #{CGI.escape(pbsCommands)}" if(!pbsCommands.nil? and !pbsCommands.empty?)
          bashScriptFile.puts "\t#{statusUpdaterString}"
          bashScriptFile.puts "else"
          statusUpdaterString="#{@@statusUpdater} -j #{clusterJob.id} -u \'failed\' -d #{@@genbConf.schedulerDbrcKey} -n #{@@genbConf.schedulerTable} -e \"`date\`\""
          statusUpdaterString << " -p #{CGI.escape(pbsCommands)}" if(!pbsCommands.nil? and !pbsCommands.empty?)
          bashScriptFile.puts "\t#{statusUpdaterString}"
          bashScriptFile.puts "fi"
          if(clusterJob.removeDirectory != "false" and clusterJob.removeDirectory != false)
            bashScriptFile.puts "rm -rf #{@workingDirectory}"
          else
            bashScriptFile.puts "mv #{@workingDirectory} #{@@genbConf.retainDirectoryBase}/"
          end
          # Dump some resource usage info etc as last thing.
          bashScriptFile.puts "qstat -f $PBS_JOBID "
          # Done with bash script
          bashScriptFile.close()
          retVal = 0
        rescue Exception => err1
          begin
            ClusterJobUtils.logClusterError("ERROR: couldn't prep job submission scripts.\n  Err Message: #{err1.message}\nBacktrace:\n#{err1.backtrace.join("\n")}")
          rescue => err2
          end
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Couldn't prep job submission scripts.\n  Err Message: #{err1.message}\nBacktrace:\n#{err1.backtrace.join("\n")}")
          retVal = nil
        end
        return retVal
      end

      # Checks if the supplied #ClusterJob object is valid
      # If yes creates a bash script to submit job to the cluster
      # If bashscript was created successfully, submits bashscript to the cluster
      # [+clusterJob+] Filled ClusterJob object from which a bash script file is to be generated
      # [+returns+]    0 if job was submitted successfully,
      #                nil otherwise
      def submitJob(clusterJob)
        retVal = nil
        # Check if Clusterjob object is valid
        if(ClusterJobUtils.clusterJobFilledCorrectly(clusterJob)) then
          # Keep track of output directory, working directory and bash script name
          @outputDirectory = clusterJob.outputDirectory
          @workingDirectory="#{@@workingDirectoryBase}/#{clusterJob.jobName}/"
          # Generate bash script
           @bashScriptName = "#{clusterJob.jobName}"
          if(!CreateBashScript(clusterJob).nil?)
            system("qsub #{@@clusterScriptsDirectory}/#{@bashScriptName}.pbs")
            if( @@genbConf.deleteClusterJobScripts == "true" or @@genbConf.deleteClusterJobScripts == "yes" ) then
              system("rm #{@@clusterScriptsDirectory}/#{@bashScriptName}.pbs")
              system("rm #{@@clusterScriptsDirectory}/#{@bashScriptName}.commands")
            end
            retVal = 0
          else
            retVal = nil
          end
        else
          retVal = nil
        end
        return retVal
      end
    end
  end ; end  # module BRL ; module Cluster ;
