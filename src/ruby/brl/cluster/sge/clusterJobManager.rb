#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/cluster/dbUtil'
require 'brl/util/textFileUtil'
require 'brl/cluster/clusterJob'
require 'brl/cluster/clusterJobUtils'


module BRL;
module Cluster
   # == Overview
  # This class is used to submit #ClusterJob objects to the ClusterJob Scheduler.
  # This class is responsible for inserting, retrieving and querying the appropriate records corresponding to submitted jobs
  # from the job scheduler table
  # == Notes
  #
  # == Example usage:
  #
  # === E.g. ClusterjobManager Usage to insert a job into the scheduler table
  #
  #   clusterJobManager = ClusterJobManager.new("testDb") #"testDb" is the name of the dbrcKey to use
  #   clusterJobManager.insertJob(clusterJob) # clusterJob is a filled ClusterJob object
  #
  # === E.g. ClusterjobManager Usage to query unsubmitted job records from the scheduler table
  #
  #   clusterJobManager = ClusterJobManager.new("testDb") #"testDb" is the name of the dbrcKey to use
  #   list=clusterJobManager.queryJobsNotSubmitted()
  #
  # === E.g. ClusterjobManager Usage to mark submission time for a job
  #
  #   clusterJobManager = ClusterJobManager.new("testDb") #"testDb" is the name of the dbrcKey to use
  #   clusterJobManager.markJobSubmissionTime(jobId, Time.now)
  
  class ClusterJobManager
    
    # CONSTRUCTOR. Create an object to help with miscellaneous scheduler tasks
    # Creates a member ClusterDbUtil object from the supplied dbrc key
    #
    # [+dbrcKey+]   The key to use from the dbrc file
    # [+jobTable+] The name of the job scheduler table in the current database
    # [+resourceTable+] The name of the resource paths table in the current database
    def initialize(dbrcKey, jobTable)      
      @dbu = ClusterDBUtil.new(dbrcKey, jobTable)      
      @dbu.connectToOtherDb(dbrcKey,true)
    end
      
  
    # Extracts relevant information from the supplied #ClusterJob object and inserts it into
    # the job scheduler table
    # [+clusterJob+]   Filled ClusterJob object that is to be submitted to the scheduler
    # [+returns+]      jobId of the newly created jobRecord if insertion is successful, nil otherwise    
    def insertJob(clusterJob)      
      return @dbu.insertJob(clusterJob)      
    end
    
      
    # Extracts job record corresponding to supplied jobId from the job scheduler table and returns a ClusterJob object
    # [+jobId+]   The jobId assigned to this job at the time of insertion by the scheduler
    # [+returns+] ClusterJob object if jobRecord corresponding to jobId exists
    #             nil, otherwise indicating the retrieval wasn't successful
    def retrieveJob(jobId)
      return @dbu.retrieveJob(jobId)
    end
     
        
    
    # Allows update of attributes related to the cluster job in the scheduler table
    # [+jobId+]         The jobId assigned to this job at the time of insertion by the scheduler
    # [+updateHash+]    Hash containing the fields and values that will be used in SQL SET clause, must have the format: 'fieldName' => 'fieldValue'
    # [+returns+]       number of records so updated. Should be 1 for a successful update  
    def updateClusterJobDetails(jobId,updateHash)
      return @dbu.updateClusterJobDetails(jobId,updateHash)
    end


  # Queries the job scheduler table for jobs that have not yet been submitted to the cluster
  # i.e. status="entered"
  # [+returns+] array of ClusterJob objects corresponding to unsubmitted jobRecords if any exist
  #             nil, otherwise indicating the query wasn't successful
    def queryJobsNotSubmitted()
      return @dbu.queryJobsNotSubmitted()
    end
      
  end
  
end
end # module BRL ; module Cluster ;
