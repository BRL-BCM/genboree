#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'
require 'rinda/tuplespace'
require 'brl/genboree/genboreeUtil'

module BRL; module Genboree; module Pash

# Ruby instantiation of the cluster job submission class
class TupleSpaceJob
  DEBUG=false
  # cluster-specific locations, configurable through the config.properties files
  #@@sgeLogsDirectory      = "/usr/local/brl/data/sge/logs"
  @@sgeScriptSettingsFile = "/usr/local/brl/local/tupleSpace/tsbashrc"
  @@genboreeClusterTmpDir = "/usr/local/brl/data/tupleSpace/tmp"
  @@scratchDirectory      = "/usr/local/brl/data/tupleSpace/scratch"

  #
  attr_accessor :inputFilesNeedCopy, :commandList
  attr_accessor :outputDirectory, :outputIgnoreList
  attr_accessor :sourceHost 
  attr_accessor :outputHost
  attr_accessor :jobResources
  attr_accessor :jobName
  attr_accessor :jobType
  attr_accessor :uniqueJobTicket
  attr_accessor :removeTemporaryFiles
  attr_accessor :notificationEmail

  # set the removeJobDirectory to true, and the remaining attributes to nil
  def initialize()
    @inputFilesNeedCopy = nil
    @commandList = nil
    @outputDirectory = nil
    @outputIgnoreList = nil
    @jobResources = nil
    @removeTemporaryFiles = true
    @jobName = nil
    @notificationEmail = nil
    @scratchDirectory = @@scratchDirectory
    @outputHost = nil
  end

  # AFTER configuration, submits to cluster the current job and waits for completion
  # return 0 for success, non-zero for failure
  def submit()
    genboreeConfig = BRL::Genboree::GenboreeConfig.new()
    genboreeConfig.loadConfigFile()
    tupleSpaceServerPort = genboreeConfig.tupleSpaceServerPort
    tupleSpaceServer = genboreeConfig.tupleSpaceServer
    hostName = genboreeConfig.machineName
    ts = nil
    begin
    ts = DRbObject.new(nil, "druby://#{tupleSpaceServer}:#{tupleSpaceServerPort}")
    rescue => err
      $stderr.puts "caught exception while connecting to tuple space"
      $stderr.puts err.message
      $stderr.puts err.backtrace.inspect
      return 1
    end

    result = 0
    $stderr.puts "START: Genboree cluster job at #{Time.now}" if (DEBUG)
    if (@inputFilesNeedCopy==nil)  then
      $stderr.puts "No input files need to be copied"
    else
      $stderr.puts "The input files that need to be copied  are: #{@inputFilesNeedCopy}" if (DEBUG)
    end
    if (@commandList == nil) then
      $stderr.puts "The commands to be executed must be specified !"
      return 1
    else
      $stderr.puts "The commands to be executed are #{@commandList.join(";")}" if (DEBUG)
    end
    if (@jobName==nil)  then
      $stderr.puts "The job name must be specified !"
      return 1
    else
      $stderr.puts "The jobName is #{@jobName}" if (DEBUG)
    end
    if (@outputDirectory==nil)  then
      $stderr.puts "The output directory must be specified !"
      return 1
    else
      $stderr.puts "The output directory is #{@outputDirectory}" if (DEBUG)
    end

    if (@outputHost==nil)  then
      $stderr.puts "The output host must be specified !"
      return 1
    else
      $stderr.puts "The output host is #{@outputHost}" if (DEBUG)
    end
    if (@sourceHost==nil)  then
      $stderr.puts "The source host must be specified !"
      return 1
    else
      $stderr.puts "The source host is #{@sourceHost}" if (DEBUG)
    end

    if (outputIgnoreList == nil) then
      $stderr.puts "The output ignore list is empty}" if (DEBUG)
    else
      $stderr.puts "The output ignore list is #{@outputIgnoreList.join(" ")}" if (DEBUG)
    end
    if (@removeTemporaryFiles.nil?) then
      @removeTemporaryFiles = "no"
    else
      @removeTemporaryFiles = "yes"
    end
    if (!genboreeConfig.clusterTmpDir.nil?) then
      @@sgeScriptSettingsFile = genboreeConfig.clusterTmpDir
    end
    if (!genboreeConfig.clusterScratchDirectory.nil?) then
      @scratchDirectory = genboreeConfig.clusterScratchDirectory
    else
      @scratchDirectory = @@scratchDirectory
    end
    if (!genboreeConfig.rootRsyncUtility.nil?) then
      @@rootRsyncUtility = genboreeConfig.rootRsyncUtility
    end
    if (@notificationEmail==nil) then
      $stderr.puts "The notification email must be specified !\n"
      return 1
    else
      $stderr.puts "The notification email is #{@notificationEmail}" if (DEBUG)
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

    @decoratedJobName="ts.#{@jobName}.#{uniqueJobTicket}.#{Time.now.to_i}-#{rand(65536)}"
    rubyScriptBaseName = "#{@decoratedJobName}.clusterRubyHarness.rb"
    rubyScriptName = "#{@outputDirectory}/#{rubyScriptBaseName}"

    # generate bashScript; load environment
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
      rubyScriptFile.puts "jobDirectory=\"#{@scratchDirectory}/#{@decoratedJobName}\""
      rubyScriptFile.puts "system(\"mkdir -p \#{jobDirectory}\")"
      rubyScriptFile.puts "Dir.chdir(jobDirectory)"

      #copy input files
      if (@inputFilesNeedCopy !=nil) then
        inputFile=nil
        @inputFilesNeedCopy.each {|inputFile|
          rubyScriptFile.puts("rsyncCommand = \"rsync -avz -e /usr/bin/ssh  #{@sourceHost}:#{inputFile} .\"");
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
        rubyScriptFile.puts "rsyncCommand=\"rsync -avz -e /usr/bin/ssh --exclude-from=#{excludePatternsFileName} ./* #{@outputHost}:#{outputDirectory} 1>&2\""
      else
        rubyScriptFile.puts "rsyncCommand=\"rsync -avz -e /usr/bin/ssh ./* #{@outputHost}:#{outputDirectory} 1>&2 \""
      end
      rubyScriptFile.puts "\$stderr.puts \"rsyncCommand \#{rsyncCommand}\""
      rubyScriptFile.puts "system(rsyncCommand)"


      rubyScriptFile.puts "exit(finalStatus)"
      rubyScriptFile.close
    rescue  SystemCallError
      $stderr.puts "Could not create ruby wrapper #{@bashScriptName}!"
      $stderr.puts $!.message
      $stderr.puts $!.backtrace.inspect
      return 1
    end
    #checks for every command

    submitTuple = ['work', @jobType, @jobName, @uniqueJobTicket, @decoratedJobName, rubyScriptName, @removeTemporaryFiles, @outputDirectory, @notificationEmail, @outputHost, @sourceHost]
    $stderr.puts "about to submit #{submitTuple}" if (DEBUG)
    # submit job info into the TupleSpace
    writeStatus= ts.write(submitTuple)
    $stderr.puts "write status #{writeStatus}" if (DEBUG)

    return result
  end
end

end; end ; end
