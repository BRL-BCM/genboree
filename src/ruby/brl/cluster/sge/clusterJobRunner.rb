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
    end

    # Retrieves unsubmitted jobs from the scheduler and submits them to the cluster
    # [+fileHandle+] File to write messages to since this is expected to run in a 'cron' context. STDOUT by default
    # [+returns+] number of jobs that were successfully submitted to the cluster
    def work(fileHandle = $stdout)      
      jobsNotSubmitted = @clusterJobManager.queryJobsNotSubmitted()      
      jobCount = 0;
      if (jobsNotSubmitted.nil?) then
#        fileHandle.puts "#{Time.now.to_s} No jobs found"
      else
        jobsNotSubmitted.each do |clusterJob|          
          if(@clusterJobSubmitter.submitJob(clusterJob).nil?) then
            fileHandle.puts "#{Time.now.to_s} Error submitting job #{clusterJob.jobName} to cluster"
          else
            @clusterJobManager.updateClusterJobDetails(clusterJob.id,{"status"=>"submitted","sgeSubmissionDate"=>Time.now} )
            fileHandle.puts "#{Time.now.to_s} Submitted job #{clusterJob.jobName} to cluster"
            jobCount += 1
          end
        end
      end
      if(jobCount > 1) then fileHandle.puts "#{Time.now.to_s} #{jobCount} jobs submitted successfully" end
      return jobCount  
    end
  end
  
end
end # module BRL ; module Cluster ;
