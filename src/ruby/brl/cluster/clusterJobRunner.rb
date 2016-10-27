#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/util/textFileUtil'
require 'brl/cluster/clusterJob'
require 'brl/cluster/clusterJobManager'
require 'brl/cluster/clusterJobSubmitter'
require 'brl/cluster/clusterJobUtils'

module BRL;
module Cluster
   # == Overview
  # This class is used to submit jobs to the cluster grid engine. It checks periodically for unsubmitted jobs in the job scheduler table
  # and retrieves and submits them
  #
  # == Example usage:
  #
  # === E.g. ClusterjobRunner Usage
  #   clusterJobRunner = ClusterJobRunner.new
  #   clusterJobRunner.work()
  #
  #
  class ClusterJobRunner
    # CONSTRUCTOR. Create an object to submit jobs to the cluster
    # Creates member ClusterJobManager and ClusterJobSubmitter objects
    # [+dbrcKey+]   The key to use from the dbrc file
    # [+tableName+] The name of the job scheduler table in the current database
    def initialize(dbrcKey, tableName)
      @clusterJobManager = ClusterJobManager.new(dbrcKey,tableName)
      @clusterJobSubmitter = ClusterJobSubmitter.new
      @genbConf = BRL::Genboree::GenboreeConfig.load()
    end

    # Retrieves unsubmitted jobs from the scheduler and submits them to the cluster
    # [+fileHandle+] File to write messages to since this is expected to run in a 'cron' context. STDOUT by default
    # [+returns+] number of jobs that were successfully submitted to the cluster
    def work()
      # Pause and sleep afte N jobs:
      clusterMaxBatchSubmitSize = (@genbConf.clusterMaxBatchSubmitSize or 500).to_i
      clusterBatchSubmitPauseLength = (@genbConf.clusterBatchSubmitPauseLength or 180).to_i
      # Get unsubmitted jobs and submit them.
      jobsNotSubmitted = @clusterJobManager.queryJobsNotSubmitted()
      ClusterJobUtils.logClusterError("STATUS: Found #{jobsNotSubmitted ? jobsNotSubmitted.size : 0} jobs that need submitting. (Will submit a maximum of #{clusterMaxBatchSubmitSize.inspect} at a time.)")
      jobCount = totalSucceeded = totalFailed = 0
      unless(jobsNotSubmitted.nil?)
        jobsNotSubmitted.each { |clusterJob|
          begin
            if(@clusterJobSubmitter.submitJob(clusterJob).nil?)
              ClusterJobUtils.logClusterError("ERROR: failed to submit job #{clusterJob.jobName} to cluster.")
              totalFailed += 1
            else
              @clusterJobManager.updateClusterJobDetails(clusterJob.id, { "status" => "submitted", "submitDate" => Time.now })
              ClusterJobUtils.logClusterError("STATUS: Successfully submitted job #{clusterJob.jobName} to cluster.")
              jobCount += 1
              totalSucceeded += 1
            end
          rescue Exception => err1
            ClusterJobUtils.logClusterError("ERROR: exception raised while submitting job #{clusterJob.jobName} to cluster\nMessage: #{err1.message}\nBacktrace: #{err1.backtrace.join("\n")}")
              totalFailed += 1
          end
          # Have we submitted the maximum for this run?
          if(clusterMaxBatchSubmitSize > 0 and jobCount >= clusterMaxBatchSubmitSize)
            ClusterJobUtils.logClusterError("STATUS: submitted the maximum number jobs allowed per run (#{jobCount}). Will now pause for #{clusterBatchSubmitPauseLength.inspect}, hanging onto the lock, to ameliorate spamming of the cluster.")
            sleep(clusterBatchSubmitPauseLength)
            # Reset jobCount so we can continue for another batch of jobs.
            jobCount = 0
          end
        }
      end
      if(totalSucceeded > 1 or totalFailed > 1)
        ClusterJobUtils.logClusterError("STATUS: Done submitting jobs. #{totalSucceeded} job submissions succeeded, #{totalFailed} job submissions failed.")
      end
      return jobCount
    end
  end

end
end # module BRL ; module Cluster ;
