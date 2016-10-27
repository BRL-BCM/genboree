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
    @@sgeLogsDirectory = @@genbConf.sgeLogsDirectory
    # Location to store cluster logs (output and error files)
    @@sgeScriptsDirectory = @@genbConf.sgeScriptsDirectory
    # Path to rsync utility used to copy files
    @@rootRsyncUtility = @@genbConf.rootRsyncUtility
    # Path to parent directory of the job directory
    @@workingDirectoryBase = @@genbConf.workingDirectoryBase
    # bashrc file to source for environment variables
    @@bashrc = @@genbConf.bashrcPath
    # Finisher script to call after execution is complete
    @@statusUpdater = @@genbConf.statusUpdaterPath
  
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
      
      if (File.exists?("#{@@sgeScriptsDirectory}/#{@bashScriptName}")) then
        $stderr.puts "#{@@sgeScriptsDirectory}/#{@bashScriptName} already exists"
        retVal = nil
      else
        
        indentLevel = 0
        indentStr = "  "        
        bashScriptFile = File.new("#{@@sgeScriptsDirectory}/#{@bashScriptName}", "w", 0775)
        bashScriptFile.puts "#!/usr/bin/env bash"
        bashScriptFile.puts "source #{@@bashrc}"        
        @scriptOutputFile = "#{@@sgeLogsDirectory}/#{clusterJob.jobName}.out"
        @scriptErrorFile = "#{@@sgeLogsDirectory}/#{clusterJob.jobName}.error"
        
        # Specify bash shell and output and error log files        
        bashScriptFile.puts "\#\$ -S /bin/sh"
        bashScriptFile.puts "\#\$ -o #{@scriptOutputFile}"
        bashScriptFile.puts "\#\$ -e #{@scriptErrorFile}"
        
        # Resource requests
        clusterJob.resources.each{|resource| bashScriptFile.puts "\#\$ -l #{resource}"}
        
        
        # Keep track of error msgs and failures if any        
        bashScriptFile.puts "errmsg=\"\""
        bashScriptFile.puts "failure=0"
        
        statusUpdaterString="#{@@statusUpdater} -j #{clusterJob.id} -u \'running\' -c \$JOB_ID -h $HOSTNAME -d #{@@genbConf.schedulerDbrcKey} -n #{@@genbConf.schedulerTable} -b \"\`date\`\""
        bashScriptFile.puts("#{indentStr*indentLevel}"+statusUpdaterString)      
        bashScriptFile.puts("#{indentStr*indentLevel}echo \""+statusUpdaterString+"\"")
        
        # Create working directory        
        bashScriptFile.puts "echo \"Making working directory #{@workingDirectory}\" "              
        bashScriptFile.puts "#{indentStr*indentLevel}mkdir #{@workingDirectory}"        
        bashScriptFile.puts "#{indentStr*indentLevel}if [ $? -eq 0 ]; then"
        
        # Switch to working directory        
        indentLevel += 1            
        bashScriptFile.puts "#{indentStr*indentLevel}cd #{@workingDirectory}"      
        bashScriptFile.puts "#{indentStr*indentLevel}if [ $? -eq 0 ]; then"        
        indentLevel += 1

        oldValuesHash = Hash.new
        contextHash = nil
        genbConfRewrite = nil
        envVarRewrite = nil

        # Set up requested context/environment variables
        if(clusterJob.jsonContextString=~/\S/)          
          contextHash = JSON.parse(clusterJob.jsonContextString)
          if(contextHash.has_key?("genbConfig"))
            genbConfRewrite = true
          end
          if(contextHash.has_key?("env"))
          envVarRewrite = true 
          end
        end
        
          unless (genbConfRewrite.nil?)
            bashScriptFile.puts "#{indentStr*indentLevel}genbConfigRewriter.rb -j #{CGI.escape(clusterJob.jsonContextString)}"
            bashScriptFile.puts "#{indentStr*indentLevel}if [ $? -eq 0 ]; then"        
            indentLevel += 1
            oldValuesHash["GENB_CONFIG"] = ENV["GENB_CONFIG"]
            bashScriptFile.puts "#{indentStr*indentLevel}export GENB_CONFIG=./genboree.config"
          end
          unless (envVarRewrite.nil?)
            contextHash["env"].each_key{|key|
              oldValuesHash[key] = ENV[key]
              bashScriptFile.puts "#{indentStr*indentLevel}export #{key}=#{contextHash["env"][key]}"}
          end        
        
        # Copy requested input files into working directory        
        clusterJob.inputFiles.each { |inputFile|
          bashScriptFile.puts "#{indentStr*indentLevel}#{@@rootRsyncUtility} -avz -e /usr/bin/ssh #{inputFile} ."        
          bashScriptFile.puts "#{indentStr*indentLevel}if [ $? -eq 0 ]; then"
          indentLevel += 1
        }
              
        # Print out each command in order into bash script file        
        clusterJob.commands.each { |command|          
          bashScriptFile.puts "#{indentStr*indentLevel}#{CGI.unescape(command)}"          
          bashScriptFile.puts "#{indentStr*indentLevel}if [ $? -eq 0 ]; then"
          indentLevel += 1
        }

        unless (genbConfRewrite.nil?)
            bashScriptFile.puts "#{indentStr*indentLevel}rm ./genboree.config"
        end

        # Copy contents of working directory to output directory
        if(!clusterJob.outputFileList.empty?)          
          bashScriptFile.puts "#{indentStr*indentLevel}fileMover.rb -d . -s #{CGI.escape(JSON.generate(clusterJob.outputFileList))}"
        end
        
        bashScriptFile.puts "#{indentStr*indentLevel}if [ `ls -a|wc -l` -ne 2 ]; then"
        indentLevel += 1
        bashScriptFile.puts "#{indentStr*indentLevel}#{@@rootRsyncUtility} -avz -e /usr/bin/ssh * #{@outputDirectory}"
        indentLevel -= 1 
        bashScriptFile.puts "#{indentStr*indentLevel}fi"
        bashScriptFile.puts "#{indentStr*indentLevel}if [ $? -eq 0 ]; then"
        indentLevel += 1        
        bashScriptFile.puts "#{indentStr*indentLevel}errmsg=\"\""        
        oldValuesHash.each_key{|key| bashScriptFile.puts "#{indentStr*indentLevel}export #{key}=#{oldValuesHash[key]}"}
          
          
        
        indentLevel -= 1
        bashScriptFile.puts "#{indentStr*indentLevel}else"      
        indentLevel += 1
        bashScriptFile.puts "#{indentStr*indentLevel}errmsg=\"Could not copy output files to #{@outputDirectory}\" "      
        bashScriptFile.puts "#{indentStr*indentLevel}failure=1"      
        indentLevel -= 1      
        bashScriptFile.puts "#{indentStr*indentLevel}fi"
          
        # Finish up if else ladder for error checking in bash script file        
        clusterJob.commands.reverse.each { |command|
          indentLevel -= 1        
          bashScriptFile.puts "#{indentStr*indentLevel}else"                
          indentLevel += 1        
          bashScriptFile.puts "#{indentStr*indentLevel}errmsg=\"Command #{CGI.unescape(command)} did not execute successfully\" "        
          bashScriptFile.puts "#{indentStr*indentLevel}failure=1"      
          indentLevel -= 1        
          bashScriptFile.puts "#{indentStr*indentLevel}fi"
        }
        
        clusterJob.inputFiles.reverse.each { |inputFile|
          indentLevel -= 1
          bashScriptFile.puts "#{indentStr*indentLevel}else"                
          indentLevel += 1
          bashScriptFile.puts "#{indentStr*indentLevel}errmsg=\"Could not copy over input file #{inputFile}\" "
          bashScriptFile.puts "#{indentStr*indentLevel}failure=1"      
          indentLevel -= 1        
          bashScriptFile.puts "#{indentStr*indentLevel}fi"
        }
        
        unless (genbConfRewrite.nil?)
          indentLevel -= 1
          bashScriptFile.puts "#{indentStr*indentLevel}else"      
          indentLevel += 1
          bashScriptFile.puts "#{indentStr*indentLevel}errmsg=\"Could not perform requested GENB_CONFIG changes\" "
          bashScriptFile.puts "#{indentStr*indentLevel}failure=1"      
          indentLevel -= 1
          bashScriptFile.puts "#{indentStr*indentLevel}fi"
        end
        
        indentLevel -= 1
        bashScriptFile.puts "#{indentStr*indentLevel}else"      
        indentLevel += 1
        bashScriptFile.puts "#{indentStr*indentLevel}errmsg=\"Could not change working directory to #{@workingDirectory}\" "
        bashScriptFile.puts "#{indentStr*indentLevel}failure=1"      
        indentLevel -= 1
        bashScriptFile.puts "#{indentStr*indentLevel}fi"
        
        indentLevel -= 1
        bashScriptFile.puts "#{indentStr*indentLevel}else"      
        indentLevel += 1
        bashScriptFile.puts "#{indentStr*indentLevel}errmsg=\"Could not create working directory #{@workingDirectory}\" "      
        bashScriptFile.puts "#{indentStr*indentLevel}failure=1"      
        indentLevel -= 1 
        bashScriptFile.puts "#{indentStr*indentLevel}fi"
        
        # Delete working directory if so requested
        if(clusterJob.removeDirectory!="false") then
          bashScriptFile.puts "#{indentStr*indentLevel}echo \"Deleting working directory #{@workingDirectory}\" "
          bashScriptFile.puts "#{indentStr*indentLevel}rm -rf #{@workingDirectory}"
        end
          
        # Assess final job status to notify user with error messages if any.
        # Also call status updater script to update status information in scheduler table
        bashScriptFile.puts "#{indentStr*indentLevel}if [ $failure -eq 0 ]; then"
        indentLevel += 1      
        bashScriptFile.puts "#{indentStr*indentLevel}echo \"ClusterJob #{clusterJob.jobName} executed successfully\""
        msgBody = "\"The output produced by the job was:\\n\\n"
        msgBody += "`cat #{@scriptOutputFile}`\""        
        bashScriptFile.puts "#{indentStr*indentLevel}echo -e #{msgBody} |mail -s \"ClusterJob #{clusterJob.jobName} executed successfully\" #{clusterJob.notificationEmail} "            
        statusUpdaterString = "#{@@statusUpdater} -j #{clusterJob.id} -u \'completed\' -d #{@@genbConf.schedulerDbrcKey} -n #{@@genbConf.schedulerTable} -e \"\`date\`\""
        bashScriptFile.puts("#{indentStr*indentLevel}"+statusUpdaterString)      
        bashScriptFile.puts("#{indentStr*indentLevel}echo \""+statusUpdaterString+"\"")
        indentLevel -= 1
        bashScriptFile.puts "#{indentStr*indentLevel}else"      
        indentLevel += 1
        bashScriptFile.puts "#{indentStr*indentLevel}echo \"Job execution was unsuccessful: $errmsg\""
        msgBody = "\"ClusterJob execution was unsuccessful: $errmsg\\n\\n"
        msgBody += "The output produced by the job was:\\n\\n"
        msgBody += "`cat #{@scriptOutputFile}`\\n\\n"
        msgBody += "The error log of the job was:\\n\\n"
        msgBody += "`cat #{@scriptErrorFile}`\""
        bashScriptFile.puts "#{indentStr*indentLevel}echo -e #{msgBody} | mail -s \"ClusterJob #{clusterJob.jobName} failed\" #{clusterJob.notificationEmail} "
        statusUpdaterString="#{@@statusUpdater} -j #{clusterJob.id} -u \'failed\' -d #{@@genbConf.schedulerDbrcKey} -n #{@@genbConf.schedulerTable} -e \"`date\`\""
        bashScriptFile.puts("#{indentStr*indentLevel}"+statusUpdaterString)      
        bashScriptFile.puts("#{indentStr*indentLevel}echo \""+statusUpdaterString+"\"")        
        indentLevel -= 1        
        bashScriptFile.puts "#{indentStr*indentLevel}fi"
        bashScriptFile.puts "#{indentStr*indentLevel}echo \"JobId = $JOB_ID\""
        bashScriptFile.puts "#{indentStr*indentLevel}echo \"JobName = $JOB_NAME\""
        bashScriptFile.puts "#{indentStr*indentLevel}echo \"Hostname = $HOSTNAME\""
        bashScriptFile.puts "#{indentStr*indentLevel}echo \"SchedulerId = #{clusterJob.id}\""
        #To allow mail to finish successfully
        bashScriptFile.puts "sleep 3"
        bashScriptFile.close()
        retVal = 0
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
        @bashScriptName = "#{clusterJob.jobName}.clusterWrapper.sh"              
        # Generate bash script        
        if(!CreateBashScript(clusterJob).nil?) then
          system("qsub #{@@sgeScriptsDirectory}/#{@bashScriptName}")          
          if( @@genbConf.deleteClusterJobScripts == "true" or @@genbConf.deleteClusterJobScripts == "yes" ) then
            system("rm #{@@sgeScriptsDirectory}/#{@bashScriptName}")            
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
