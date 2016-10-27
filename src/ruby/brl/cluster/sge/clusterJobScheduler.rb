#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################

#require 'brl/genboree/genboreeUtil'

require 'brl/genboree/dbUtil'
#require 'brl/util/util'
require 'brl/cluster/clusterJob'
require 'brl/cluster/clusterJobUtils'
require 'brl/cluster/clusterJobRunner'

require 'getoptlong'

module BRL
module Cluster
  # == Overview
  # This ruby scipt serves as a command line tool that can be invoked in order to submit a job for running on the cluster
  # to the scheduler. The details of the job are specified as arguments following appropriate command line flags. The aspects of the job
  # which can be specified are:
  #   The required input files
  #   The list of commands to be run
  #   The list of resources necessary for the job
  #   The output directory where results are to be transferred
  #   Whether the temporary directory used for job execution should be retained
  #   The email to which information about the job execution must be sent
  #
  # 

  class ClusterJobScheduler
    
    def initialize(optsHash)
      @optsHash = optsHash
      setParameters()
    end

    def setParameters()
      @keepDirectory = @optsHash['--keepDir']
      @outputDirectory = @optsHash['--outputDir']      
      @notificationEmail = @optsHash['--email']
      @commandList = @optsHash['--commands']      
      @inputFileList = @optsHash['--inputFiles']      
      @resourceList = @optsHash['--resources']
      @jsonFile = @optsHash['--jsonFile']
      @resourcePathList = @optsHash['--resourcePaths']
      @outputFileList = @optsHash['--outputFileList']
      @jobName = @optsHash['--jobName']
	#	@outputDirectory = URI.Escape.unescape(@optsHash['--outputDir'])
	#	@commandList = URI.Escape.unescape(@optsHash['--commands'])
	#	@inputFileList = URI.Escape.unescape(@optsHash['--inputFiles'])
	#	@resourceList = URI.Escape.unescape(@optsHash['--resources'])
    end

    def work()
      clusterJob = ClusterJob.new
      if(@jobName.nil?)
        clusterJob.jobName = "job-#{Time.now.to_i.to_s}_#{rand(65525)}"
      else
        clusterJob.jobName = @jobName
      end
      
      genbConf = BRL::Genboree::GenboreeConfig.load()
      if(@keepDirectory.nil?) then clusterJob.removeDirectory = "true" else clusterJob.removeDirectory = "false" end
    
      clusterJob.outputDirectory = @outputDirectory
      if(@notificationEmail.nil?)
        if(genbConf.clusterAdminEmail.is_a?(Array)) then
          clusterJob.notificationEmail = genbConf.clusterAdminEmail.join(",")
        else
          clusterJob.notificationEmail = genbConf.clusterAdminEmail
        end

      else
        clusterJob.notificationEmail = @notificationEmail
      end
      
      @commandList.split(/,/).each { |command| clusterJob.commands << command}
      
      unless(@inputFileList.nil?)
        @inputFileList.split(/,/).each { |inputFile| clusterJob.inputFiles << inputFile}
      end
    
      unless(@resourceList.nil?)
        @resourceList.split(/,/).each { |resource| clusterJob.resources << resource}
      end
       
      unless(@jsonFile.nil?)
        jsonFh = File.open(@jsonFile,"r")
        clusterJob.jsonContextString = jsonFh.read
        jsonFh.close
      end
      
      unless(@resourcePathList.nil?)
        @resourcePathList.split(/,/).each { |resourcePath| clusterJob.resourcePaths << resourcePath }
      end
      
      
      unless(@outputFileList.nil?)
        outputListHash = Hash.new
        (outputListHash['srcrexp'], outputListHash['destrexp'], outputListHash['outputDir']) = @outputFileList.split(/,/).map! { |x| CGI.unescape(x) }
        clusterJob.outputFileList << outputListHash
        puts clusterJob.outputFileList.inspect
      end
      
      #ClusterJobUtils.ClusterJobFilledCorrectly(clusterJob)

      clusterJobManager = ClusterJobManager.new(genbConf.schedulerDbrcKey,genbConf.schedulerTable)
      jobId = clusterJobManager.insertJob(clusterJob)
      if(jobId.nil?) then
        puts("Error submitting job to the scheduler")
      else
        puts("Your Job Id is #{jobId}")
      end
    end
    
    def ClusterJobScheduler.processArguments()
      optsArray = [ ['--keepDir',     '-k', GetoptLong::NO_ARGUMENT],       
                  ['--outputDir',    '-o', GetoptLong::REQUIRED_ARGUMENT],
                  ['--email',    '-e', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--commands',    '-c', GetoptLong::REQUIRED_ARGUMENT],
                  ['--inputFiles',  '-i', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--resources',  '-r', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--jsonFile',  '-j', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--resourcePaths',  '-p', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--outputFileList',  '-l', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--jobName', GetoptLong::OPTIONAL_ARGUMENT]
                  ]

      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      if(optsHash.key?('--help')) then
        ClusterJobScheduler.usage()
        @@argumentsOk = false
      end

      unless(progOpts.getMissingOptions().empty?)
        ClusterJobScheduler.usage("USAGE ERROR: some required arguments are missing")
        @@argumentsOk = false
      end
      if(optsHash.empty?) then
        ClusterJobScheduler.usage()
        @@argumentsOk = false
      end
      return optsHash
    end

    def ClusterJobScheduler.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "PROGRAM DESCRIPTION:
          This ruby script is invoked as a command line tool in a programmatic context to submit a job for running on the cluster to the scheduler.
          This script accepts command line arguments and flags that allow full specification of all aspects of the job to be run on the cluster          
            
          COMMAND LINE ARGUMENTS:
            -k or --keepDir         => This flag is optional and does not require arguments. If specified,
                                       the temporary directory used for job execution on the cluster will not be deleted.
                                       By default (flag not specified) the directory will be deleted
            -o or --outputDir       => This flag is required and should be followed by the output directory into which the results of
                                       the job should be copied. This directory should be specified in the rsync format hostname:dirname/
            -e or --email           => This flag is required and should be followed by the email to which notifications about the job should be sent
            -c or --commands        => This flag is required and should be followed by a list of commands to be executed on the cluster
            -i or --inputFiles      => This flag is optional and if used should be followed by a list of input files to be copied over to the temporary
                                       working directory for succesful execution of the commands that constitute the job.
            -r or --resources       => This flag is optional and if present should be follwed by a comma separated list of
                                       cluster resources being requested as name value pairs -- name1=value1, name2 =value2
            -j or --jsonFile        => This optional flag specifies the file containing the json formatted string that specifies any
                                       environment variables or genboree config variables that need to be altered before job execution
            -p or --resourcePaths   => This optional flag is used to specify a resource identifier string for this job which can be used to track resource usage
            -l or --outputFileList  => Output files requiring special handling that need to be moved to a different place can be specified using this optional flag.
                                       The 'rest' of the output files go to the default output dir.
            --jobName               => This optional flag is to be used only in the rare case when the job name needs to be pre-specified. In this case the scheduler will not
                                      auto-generate a job name
            
          USAGE:
          ./clusterJobScheduler.rb -o brl3.brl.bcm.tmc.edu:/usr/local/brl/home/raghuram/ -e raghuram@bcm.edu -c date"
      exit(2);
    end
  end


########################################################################################
# MAIN
########################################################################################

  # Process command line options
  optsHash = ClusterJobScheduler.processArguments()
  clusterJobScheduler = ClusterJobScheduler.new(optsHash)
  clusterJobScheduler.work()


end
end # module BRL ; module Cluster ;
