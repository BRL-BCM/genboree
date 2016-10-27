#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'
require 'drmaa'

module BRL; module GenboreeCluster

# Ruby instantiation of the cluster job submission class
class GenboreeClusterJob
  
  # class data
  @@sgeLogsDirectory      = "/usr/local/brl/data/sge/logs" 
  @@sgeScriptSettingsFile = "/usr/local/brl/local/sge/brl/common/.sgebashrc"
  @@rootRsyncUtility      = "/usr/local/brl/local/bin/rrsync"
  @@genboreeClusterTmpDir = "/usr/local/brl/data/sge/tmp"
  @@scratchDirectory      = "/usr/local/brl/data/sge/scratch"
  # 
  attr_accessor :inputFilesNeedCopy, :commandList
  attr_accessor :outputDirectory, :outputIgnoreList
  attr_accessor :jobResources, :removeJobDirectory
  attr_accessor :scratchDirectory
  attr_accessor :jobName
  attr_accessor :jobResources
  
  
  # set the removeJobDirectory to true, and the remaining attributes to nil
  def initialize()
    @inputFilesNeedCopy = nil
    @commandList = nil
    @outputDirectory = nil
    @outputIgnoreList = nil
    @jobResources = nil
    @removeJobDirectory = true
    @jobName = nil
    @scratchDirectory = @@scratchDirectory
  end

  # AFTER configuration, submits to cluster the current job and waits for completion  
  # return 0 for success, non-zero for failure
  def submitAndWaitForCompletion()
    result = 0
    $stderr.puts "START: Genboree cluster job at #{Time.now}"
    if (@inputFilesNeedCopy==nil)  then
      $stderr.puts "No input files need to be copied"
    else
      $stderr.puts "The input files that need to be copied  are: #{@inputFilesNeedCopy}"
    end
    if (@commandList == nil) then
      $stderr.puts "The commands to be executed must be specified !"
      return 1
    else
      $stderr.puts "The commands to be executed are #{@commandList.join(";")}"
    end
    if (@jobName==nil)  then
      $stderr.puts "The job name must be specified !"
      return 1
    else
      $stderr.puts "The jobName is #{@jobName}"
    end
    if (@outputDirectory==nil)  then
      $stderr.puts "The output directory must be specified !"
      return 1
    else
      $stderr.puts "The output directory is #{@outputDirectory}"
    end
    if (outputIgnoreList == nil) then
      $stderr.puts "The output ignore list is empty}"
    else 
      $stderr.puts "The output ignore list is #{@outputIgnoreList.join(" ")}"
    end
    if (@scratchDirectory==nil)  then
      $stderr.puts "The scratch directory must be specified !"
      return 1
    else
      $stderr.puts "The scratch directory is #{@@scratchDirectory}"
    end
    
    begin
      session = DRMAA::Session.new()
    rescue DRMAA::DRMAAException
      $stderr.puts $!.message
      $stderr.puts $!.backtrace.inspect
      session.finalize()
      retry
    end  
    
    begin
      version = DRMAA.version
      drm = DRMAA.drm_system
      impl = DRMAA.drmaa_implementation
      contact = DRMAA.contact
      $stderr.puts "DRMAA #{drm} v #{version} impl #{impl} contact #{contact}"
      jobTemplate = DRMAA::JobTemplate.new()
    rescue DRMAA::DRMAAException
      $stderr.puts $!.message
      $stderr.puts $!.backtrace.inspect
    end
    
    
    # set-up job parameters: stdout, stderr, working directory, command, arguments
    if (File.exist?(@outputDirectory)) then
      if (!File.directory?(@outputDirectory)) then
        $stderr.puts "The output directory already exists and it is not a directory !"
        return 1
      end
    else
      # create the output directory
      begin
        Dir.mkdir(@outputDirectory, 0775)
      rescue SystemCallError
        $stderr.puts "Could not create the output directory #{@outputDirectory}!"
        $sterr.puts $!.message
        $stderr.puts $!.backtrace.inspect
        return 1
      end
    end

    @decoratedJobName="sge.#{@jobName}.#{Time.now.to_i}-#{rand(65536)}"
    # todo: create two methods to fill out the bash & ruby scripts
    bashScriptBaseName = "#{@decoratedJobName}.clusterWrapper.sh"
    bashScriptName = "#{@outputDirectory}/#{bashScriptBaseName}"
    rubyScriptBaseName = "#{@decoratedJobName}.clusterRubyHarness.rb"
    rubyScriptName = "#{@outputDirectory}/#{rubyScriptBaseName}"
    
    # generate bashScript; load environment
    begin
      if (File.exists?(bashScriptName)) then
        $stderr.puts "#{bashScriptName} already exists"
        return 1
      end
      bashScriptFile = File.new(bashScriptName, "w", 0775)
      # TODO: check for bash initialization script presence
      bashScriptFile.puts "#!/bin/bash"
      bashScriptFile.puts "\#\$ -o #{@@sgeLogsDirectory}/"
      bashScriptFile.puts "\#\$ -e #{@@sgeLogsDirectory}/"
      bashScriptFile.puts "source #{@@sgeScriptSettingsFile}"
      if (@jobResources != nil) then
        k = nil
        @jobResources.each_key {|k|
          bashScriptFile.puts "\#\$ -l #{k}=#{@jobResources[k]}"
        }
      end
      
      hostName = "#{`hostname`.strip}"
      # mkdir /scratch directory
      bashScriptFile.puts "export GENBOREE_DIR=#{@@scratchDirectory}/#{@decoratedJobName}.${JOB_ID}"
      bashScriptFile.puts "echo \"Making job directory ${GENBOREE_DIR}\" 1>&2"
      bashScriptFile.puts "mkdir -p ${GENBOREE_DIR}  1>&2"
      bashScriptFile.puts "cd ${GENBOREE_DIR}"
      bashScriptFile.puts "#{@@rootRsyncUtility} #{hostName}:#{rubyScriptName} .  1>&2"
      bashScriptFile.puts "chmod +x #{rubyScriptBaseName}"
      bashScriptFile.puts "./#{rubyScriptBaseName}"
      bashScriptFile.close()
      
    rescue SystemCallError
      $stderr.puts "Could not create bash wrapper #{@bashScriptName}!"
      $sterr.puts $!.message
      $stderr.puts $!.backtrace.inspect
      return 1
    end
    # generate ruby harness
    
    # TODO
    # * check error conditions
    # * accept an array of commands
    # * retrieve output data into output directory
    begin
      if (File.exists?(rubyScriptName)) then
        $stderr.puts "#{rubyScriptName} already exists"
        return 1
      end
      rubyScriptFile = File.new(rubyScriptName, "w", 0775)
      rubyScriptFile.puts "#!/usr/bin/env ruby"
      rubyScriptFile.puts "require \'brl/util/textFileUtil.rb\'"
      # get jobid and create /scratch directory
      rubyScriptFile.puts "$stderr.puts \"executing job  \#{ENV[\"JOB_ID\"]} on host \#{ENV[\"HOSTNAME\"]}\""
      rubyScriptFile.puts "jobDirectory=\"#{@@scratchDirectory}/#{@decoratedJobName}.\#{ENV[\"JOB_ID\"]}\""
    
      #copy input files
      if (@inputFilesNeedCopy !=nil) then
        inputFile=nil
        @inputFilesNeedCopy.each {|inputFile|
          rubyScriptFile.puts("rsyncCommand = \"#{@@rootRsyncUtility} #{hostName}:#{inputFile} .\"");
          rubyScriptFile.puts "system(rsyncCommand)"
        }
      end
      
      # run command list
      #rubyScriptFile.puts "command=\"#{command}\"";
      #rubyScriptFile.puts "$stderr.puts \"executing command \#{command}\""
      #rubyScriptFile.puts "system(command)"
      
      rubyScriptFile.puts "commandList=[]"
      commandList.each { |command|
        rubyScriptFile.puts "commandList.push \"#{command}\""
      }
      rubyScriptFile.puts "finalStatus=0"
      rubyScriptFile.puts "commandList.each { |cmmd|"
      rubyScriptFile.puts "status = system(cmmd)"
      rubyScriptFile.puts "if (status) then"
      rubyScriptFile.puts "  $stderr.puts \"command \\\"\#{cmmd}\\\" suceeded\""
      rubyScriptFile.puts "else"
      rubyScriptFile.puts "  finalStatus=$?.exitstatus"
      rubyScriptFile.puts "  $stderr.puts \"command \#{cmmd} failed with exitStatus=\#\{finalStatus\}\""
      rubyScriptFile.puts "  break"
      rubyScriptFile.puts "end"
      rubyScriptFile.puts "}"
      
      #rsync the results back
      if (outputIgnoreList != nil) then
      # generate exclude file based on the outputIgnoreList
        excludePatternsFileName = "sge_#{@decoratedJobName}.rsyncExcludeFiles"
        rubyScriptFile.puts "excludePatternsWriter=BRL::Util::TextWriter.new(\"#{excludePatternsFileName}\")"
        outputIgnorePattern = nil
        outputIgnoreList.each { |outputIgnorePattern|
          rubyScriptFile.puts "excludePatternsWriter.puts \"#{outputIgnorePattern}\""
        }
        rubyScriptFile.puts "excludePatternsWriter.close"
        rubyScriptFile.puts "rsyncCommand=\"#{@@rootRsyncUtility} --exclude-from=#{excludePatternsFileName} ./* #{`hostname`.strip}:#{outputDirectory} 1>&2\""
      else
        rubyScriptFile.puts "rsyncCommand=\"#{@@rootRsyncUtility} ./* #{`hostname`.strip}:#{outputDirectory} 1>&2 \""
      end
      rubyScriptFile.puts "\$stderr.puts \"rsyncCommand \#{rsyncCommand}\""
      rubyScriptFile.puts "system(rsyncCommand)"
      
      # create cache file
      
      rubyScriptFile.puts "tmpDirCache=\"#{@@genboreeClusterTmpDir}/genboreeClusterComputingCache.\#{ENV[\"JOB_NAME\"]}.\#{ENV[\"JOB_ID\"]}\""
      rubyScriptFile.puts "$stderr.puts \"Creating clean-up cache file \#{tmpDirCache}\""
      rubyScriptFile.puts "cacheFile = File.new(tmpDirCache,\"w\",0775)"
      rubyScriptFile.puts "cacheFile.puts \"outputDirectory__GenboreeCluster=#{outputDirectory}\""
      rubyScriptFile.puts "cacheFile.puts \"destinationHost__GenboreeCluster=#{`hostname`.strip}\""
      rubyScriptFile.puts "cacheFile.puts \"jobDirectory__GenboreeCluster=\#{jobDirectory}\""
      rubyScriptFile.puts "cacheFile.puts \"bashScript__GenboreeCluster=#{bashScriptBaseName}\"" 
      if (@removeJobDirectory) then
        rubyScriptFile.puts "cacheFile.puts \"removeTemporaryFiles__GenboreeCluster=yes\""
      else
        rubyScriptFile.puts "cacheFile.puts \"removeTemporaryFiles__GenboreeCluster=no\""
      end
      rubyScriptFile.puts "cacheFile.close"
      rubyScriptFile.puts "exit(finalStatus)" 
      rubyScriptFile.close
    rescue  SystemCallError
      $stderr.puts "Could not create ruby wrapper #{@bashScriptName}!"
      $stderr.puts $!.message
      $stderr.puts $!.backtrace.inspect
      return 1
    end
    #checks for every command

    # copy bashWrapper
    system("cp -f #{bashScriptName} #{@@genboreeClusterTmpDir}/")
    begin
      jobTemplate.command = "#{@@genboreeClusterTmpDir}/#{bashScriptBaseName}"
      jobTemplate.stdout = ":#{@@sgeLogsDirectory}/"
      jobTemplate.stderr = ":#{@@sgeLogsDirectory}/"
      jobTemplate.arg = []
      jobTemplate.name = @decoratedJobName
      $stderr.puts "jobTemplate: #{jobTemplate}"
      jobid = session.run(jobTemplate) 
      $stderr.puts "executing job: #{jobid}"
      info = session.wait(jobid)
      #  print job exit info
      if (info.wifaborted?()) then
        $stderr.puts "The job #{jobid} was aborted"
        result = 1
      elsif (info.wifexited?()) then
        $stderr.puts "The job #{jobid} exited with status #{info.wexitstatus}"
        result = info.wexitstatus 
      elsif (info.wifsignaled?()) then
        $stderr.puts "The job #{jobid} finished due to signal #{info.wtermsig}"
        result = 1 
      else
        $stderr.puts "The job #{jobid} finished with unclear conditions"
        result = 1
      end
      resourceUsage = info.rusage
      k=nil
      resourceUsage.each_key { |k|
        puts "#{k}=#{resourceUsage[k]}"
      }
      $stderr.puts "STOP: Genboree cluster job at #{Time.now}"
      session.finalize(0)
    rescue DRMAA::DRMAAException
      $stderr.puts $!.message
      $stderr.puts $!.backtrace.inspect
      result = 1
    end
    
    return result
  end
 
end

end ; end
