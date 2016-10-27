#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################


require 'socket'
require 'getoptlong'
require 'cgi'
require 'brl/genboree/dbUtil'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/cluster/clusterJob'
require 'brl/cluster/clusterJobUtils'
require 'brl/cluster/clusterJobRunner'


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

  class UploadWrapper
    
    def initialize(optsHash)
      @optsHash = optsHash
      setParameters()
    end

    def setParameters()      
      @outputDirectory = @optsHash['--outputDir']            
      @commandList = @optsHash['--commands']      
      @inputFileName = @optsHash['--inputFile']
      @parentJobName = @optsHash['--parentJobName']
    end
    

    def work()
      genbConf = BRL::Genboree::GenboreeConfig.load()
      tempDir = "#{genbConf.uploadScratchPath}#{@parentJobName}"
      puts(tempDir)
      FileUtils.mkdir(tempDir)
      FileUtils.mv(@inputFileName,tempDir)
      
      localHostName = Socket.gethostname
      inputFile = "#{localHostName}:#{tempDir}/#{@inputFileName}"
      
      clusterJob = ClusterJob.new
      clusterJob.jobName = "job-#{Time.now.to_i.to_s}_#{rand(65525)}"
      #
      clusterJob.outputDirectory = @outputDirectory
      #
      if(genbConf.clusterAdminEmail.is_a?(Array)) then
          clusterJob.notificationEmail = genbConf.clusterAdminEmail.join(",")
        else
          clusterJob.notificationEmail = genbConf.clusterAdminEmail
        end    
      @commandList.split(/,/).each { |command| clusterJob.commands << command}
      clusterJob.commands << CGI.escape("ssh #{localHostName} rm -rf #{tempDir}")
      clusterJob.inputFiles << inputFile
      clusterJob.resources << "upload=1"
      #
      #unless(@inputFileList.nil?)
      #  @inputFileList.split(/,/).each { |inputFile| clusterJob.inputFiles << inputFile}
      #end
      #
      #unless(@resourceList.nil?)
      #  @resourceList.split(/,/).each { |resource| clusterJob.resources << resource}
      #end
      # 
      #unless(@jsonFile.nil?)
      #  jsonFh = File.open(@jsonFile,"r")
      #  clusterJob.jsonContextString = jsonFh.read
      #  jsonFh.close
      #end
      #
      #unless(@resourcePathList.nil?)
      #  @resourcePathList.split(/,/).each { |resourcePath| clusterJob.resourcePaths << resourcePath }
      #end
      #
      #
      #unless(@outputFileList.nil?)
      #  outputListHash = Hash.new
      #  (outputListHash['srcrexp'], outputListHash['destrexp'], outputListHash['outputDir']) = @outputFileList.split(/,/).map! { |x| CGI.unescape(x) }
      #  clusterJob.outputFileList << outputListHash
      #  puts clusterJob.outputFileList.inspect
      #end
      #
      ##ClusterJobUtils.ClusterJobFilledCorrectly(clusterJob)
      #
      clusterJobManager = ClusterJobManager.new(genbConf.schedulerDbrcKey,genbConf.schedulerTable)
      jobId = clusterJobManager.insertJob(clusterJob)
      if(jobId.nil?) then
        puts("Error submitting job to the scheduler")
      else
        puts("Your Job Id is #{jobId}")
      end
    end
    
    def UploadWrapper.processArguments()
      optsArray = [
                  ['--outputDir',    '-o', GetoptLong::REQUIRED_ARGUMENT],
                  ['--commands',    '-c', GetoptLong::REQUIRED_ARGUMENT],
                  ['--inputFile',  '-i', GetoptLong::REQUIRED_ARGUMENT],
                  ['--parentJobName', '-p', GetoptLong::REQUIRED_ARGUMENT],
                  ['--help', '-h', GetoptLong::OPTIONAL_ARGUMENT]
                  ]

      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      if(optsHash.key?('--help')) then
        UploadWrapper.usage()        
      end

      unless(progOpts.getMissingOptions().empty?)
        UploadWrapper.usage("USAGE ERROR: some required arguments are missing")
        @@argumentsOk = false
      end
      if(optsHash.empty?) then
        UploadWrapper.usage()
        @@argumentsOk = false
      end
      return optsHash
    end

    def UploadWrapper.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "PROGRAM DESCRIPTION:
          This ruby script is invoked as a command line tool in a programmatic context to do the annotation upload for a pre-existing cluster job. Once the relevant infomration
          provided to this script, the parent cluster job can either quit or continue with non-upload-dependent tasks. This script packages the upload command into a new cluster job
          and submits it for execution.
            
          COMMAND LINE ARGUMENTS:            
            -o or --outputDir   => This flag is required and should be followed by the output directory into which the results of the annotation job are copied.
                                   This directory should be specified in the rsync format hostname:dirname/            
            -c or --commands    => This flag is required and should be followed by a list of commands to be executed on the cluster. There can be one or more commands that are CGI escaped and in a
                                   comma separated list
            -p or --parentJobName => This flag is required and should specify the name of the cluster job from which this upload originates. A temporary scratch directory that has the same name as the parent
                                     job is created on the same node as the parent job. The input files are moved there. When the cluster job created by this wrapper finishes, it also deletes this temprorary
                                     directory on the original node.
            -i or --inputFiles  => This flag is required and should specify the local relative location of the input file that is to be uploaded.
          USAGE:
          ./uploadWrapper.rb -o proline.brl.bcm.tmc.edu:/usr/local/brl/local/apache/htdocs/genboreeUploads/ -c CGIESCAPE(java -classpath {classpath-string} org.genboree.upload.AutoUploader -u 1420 -r 1267 -f ./temp.lff -t lff) -i ./temp.lff -p job-1205892655_03253"
      exit(2);
    end
  end


########################################################################################
# MAIN
########################################################################################

  # Process command line options
  optsHash = UploadWrapper.processArguments()
  uploadWrapper = UploadWrapper.new(optsHash)
  uploadWrapper.work()


end
end # module BRL ; module Cluster ;
