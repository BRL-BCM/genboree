#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################

require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'


module BRL;
module Cluster
  # == Overview
  # This class is intended as an encapsulator for a request to run a job on a cluster.
  # A filled ClusterJob object is expected to contain all necessary information to create, submit and
  # monitor a request for job execution on a cluster.
  # == Notes
  #
  # == Example usage:
  #
  # === E.g. Simple ClusterJob object creation
  #    require 'ClusterJob'
  #
  #    clusterJob = ClusterJob.new
  #    clusterJob.jobName = "job-#{Time.now.to_f-rand(100_000_000)}"
  #    clusterJob.removeDirectory = false
  #    clusterJob.outputDirectory = "brl3.brl.bcm.tmc.edu:/usr/local/brl/home/raghuram/"
  #    clusterJob.notificationEmail = "raghuram@bcm.edu"
  #    clusterJob.commands << "cat blah1 >blah1brl2"
  #    clusterJob.commands << "cat blah2 >blah2brl2"
  #    clusterJob.commands << "date >datebrl2"
  #    clusterJob.inputFiles << "brl3.brl.bcm.tmc.edu:/usr/local/brl/home/raghuram/blah1"
  #    clusterJob.inputFiles << "brl2.brl.bcm.tmc.edu:/usr/local/brl/home/raghuram/blah2"
  #    a=Array.new
  #    a[0]=Hash.new
  #    a[0]['srcrexp']=\"output\\/(\\d+)\\.out\"  (We are trying to specify something like ./output/1234.out Note the escaped forward and back slashes)
  #    a[0]['destrexp']=\"results/\\1/outputs\"  (We are trying to specify output/1234/1234.out Note the back reference \1. Since this is a string, no escaped forward slashes)
  #    a[0]['outputDir']=\"a:b/\"
  #    clusterJob.outputFileList=JSON.generate(a)

  class ClusterJob

    # The id assigned to this job by the job scheduler
    attr_accessor :id
    # The name of this job. This is usually randomly generated and reasonably unique. The name is intended to help idenitfy this job on the cluster as well.
    attr_accessor :jobName
    # The cluster queue to which the job needs to be submitted
    attr_accessor :queueName
    # The time at which this job was submitted to the scheduler
    attr_accessor :entryDate
    # The time at which this job was submitted by the scheduler to the cluster
    attr_accessor :submitDate
    # The id assigned to this job by the cluster
    attr_accessor :clusterJobId
    # The status of this job wrt the scheduler. Current possible statuses are Entered, Submitted, Completed and Failure. This is to contain a member of the class #JobStatus
    attr_accessor :jobStatus
    # A flag to indicate if the temporary directory created on the remote execution host of the cluster should be retained
    attr_accessor :removeDirectory
    # The output directory where job results are to be placed. Since output dirs must follow rsync naming conventions, this must be an object of the class #RsyncFileName
    attr_accessor :outputDirectory
    # The listing of output files to be handled differently via regexps encoded in JSON
    attr_accessor :outputFileList
    # The email address to which any job status updates must be sent
    attr_accessor :notificationEmail
    # The list of commands to be executed on the cluster. These are executed in the order in which they are filled into the array.
    attr_accessor :commands

    # The list of input files that this job #command requires in order to execute successfully. This is an array of #RsyncFileName objects. Each input file must follow the rsync naming convention
    attr_accessor :inputFiles
    # The json formatted string that specifies any environment variables or genboree config variables that need to be altered before job execution
    attr_accessor :jsonContextString
    # The list of resources likely to be used by this job during execution
    attr_accessor :resourcePaths
    # Array of commands to do special cleanup & delete.
    # - mainly to delete files that don't need to be copied to web server or cluster scratch
    # - run after any special file moving operations, right before job ends
    attr_accessor :cleanUpCommands
    # additional commands to add to the pbs script
    attr_accessor :pbsCommands

    # CONSTRUCTOR.  Create a ClusterJob object
    # Initializes the #resources and #inputFiles arrays
    # [+returns+]   Instance of +ClusterJob+
    def initialize(jobName = nil, outputDirectory = nil, queueName='general', notificationEmail = nil, removeDirectory = true)
      @jobName = jobName
      @queueName = queueName
      @outputDirectory = outputDirectory
      @notificationEmail = notificationEmail
      @removeDirectory = removeDirectory
      @inputFiles = []
      @commands = []
      @cleanUpCommands = []
      @outputFileList = "[]"
      @resourcePaths = []
      @pbsCommands = []
    end
  end
end
end # module BRL ; module Cluster ;
