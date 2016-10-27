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


module BRL;
module Cluster
  
  # == Overview
  # This class contains useful functions for d/b manipulations specific to the BRL Cluster system
  # This class provides facilities for inserting, retrieving and querying the appropriate records corresponding to submitted jobs
  # == Example usage:
  #
  #   @dbu = BRL::Cluster::ClusterDBUtil.new('testDb', nil, genbConfig.dbrcFile)
  #   @dbu.connectToOtherDb('testDb',true)
  #
  #
  #
  class ClusterDBUtil < BRL::Genboree::DBUtil
    # CONSTRUCTOR. Create an object to help with database tasks
    # Subclass of Genboree::DBUtil
    # Initializes self and superclass
    # [+dbrcKey+]   The key to use from the dbrc file
    # [+jobTable+] The name of the job scheduler table in the current database
    # [+resourceTable+] The name of the resource paths table in the current database
    def initialize(dbrcKey, jobTable, resourceTable="resourceIdentifiers")
      genbConfig = BRL::Genboree::GenboreeConfig.load()
      @jobTable = jobTable
      @resourceTable = resourceTable
      super(dbrcKey, nil, genbConfig.dbrcFile)
    end
    
    # Extracts relevant information from the supplied #ClusterJob object and inserts it into
    # the job scheduler table.
    # This initializes job status to "entered" and entryDate to Time.Now
    # [+clusterJob+] ClusterJob object to be inserted into the scheduler table
    # [+returns+] jobId of the newly created jobRecord if insertion is successful, nil otherwise    
    def insertJob(clusterJob)
      retVal = nil
      if(ClusterJobUtils.clusterJobFilledCorrectly(clusterJob).nil?) then
        retVal = nil
      else      
        inputFilesText = clusterJob.inputFiles.join(",")
        resourcesText = clusterJob.resources.join(",")
        commandsText = clusterJob.commands.join(",")
        
        insertData = []        
        insertData << clusterJob.jobName        
        insertData << Time.now        
        insertData << nil        
        insertData << nil        
        insertData << "entered"        
        insertData << inputFilesText
        insertData << clusterJob.outputDirectory
        insertData << resourcesText
        insertData << clusterJob.removeDirectory
        insertData << clusterJob.notificationEmail
        insertData << commandsText
        insertData << nil
        insertData << nil
        insertData << nil
        insertData << clusterJob.jsonContextString
        insertData << JSON.generate(clusterJob.outputFileList)        
        errMsg = "ERROR: ClusterJobManager.insertJob: "      
        numRecords = insertRecords(:otherDB, @jobTable, insertData, true, 1, 16, false, errMsg)
        if(numRecords!=1) then
          retVal = nil
        else
          jobRecords = selectByFieldAndValue(:otherDB, @jobTable, "name", clusterJob.jobName, errMsg)
          clusterJobId = jobRecords[0]["id"]
          retVal = clusterJobId
          clusterJob.resourcePaths.each{|resourcePath|
          resourceData = []
          resourceData << clusterJobId
          resourceData << resourcePath
          errMsg = "ERROR: ClusterJobManager.insertJob:ResourcesTable #{@resourceTable} "      
          numRecords = insertRecords(:otherDB, @resourceTable, resourceData, false, 1, 2, false, errMsg)
          }
        end
      end
      return retVal
    end
      
    # Extracts job record corresponding to supplied jobId from the ClusterJobs table and returns a ClusterJob object
    # [+jobId+]   The jobId assigned to a job at the time of insertion by the scheduler
    # [+returns+] ClusterJob object if jobRecord corresponding to jobId exists
    #             nil, otherwise indicating the retrieval wasn't successful
    def retrieveJob(jobId)
      retVal = nil
      errMsg = "ERROR: ClusterJobManager.retrieveJob: "
      jobRecords = selectByFieldAndValue(:otherDB, @jobTable, "id", jobId, errMsg)
      if(jobRecords.empty? or jobRecords.nil?) then
        retVal = nil
      else        
        retVal = createClusterJob(jobRecords[0])
        if(ClusterJobUtils.clusterJobFilledCorrectly(clusterJob).nil?) then
          retVal=nil
        end
        
      end
      return retVal
    end
     

    
    # Queries the job scheduler table for job that have not yet been submitted to the cluster
    # i.e. status="entered"
    # [+returns+] array of clusterJob objects corresponding to unsubmitted jobRecords if any exist
    #             nil, otherwise indicating the query wasn't successful
    def queryJobsNotSubmitted()
      retVal = nil      
      errMsg = "ERROR: ClusterJobManager.queryJobsNotSubmitted: "
      unsubmittedJobs = selectByFieldAndValue(:otherDB, @jobTable, "status", "entered", errMsg)
      clusterJobs = []
      if(unsubmittedJobs.empty? || unsubmittedJobs.nil?) then
        return retVal
      else
        unsubmittedJobs.each{|jobRecord| clusterJobs << createClusterJob(jobRecord)}
        retVal = clusterJobs
      end
      return retVal
    end
    
    # Fills in the final job status, the cluster job Id and the cluster host in the appropriate record in
    # the scheduler table
    # [+jobId+]         The jobId assigned to this job at the time of insertion by the scheduler
    # [+updateHash+]    Hash containing the fields and values that will be used in SQL SET clause, must have the format: 'fieldName' => 'fieldValue'    
    # [+returns+]       number of records so updated. Should be 1 for a successful update
    
    def updateClusterJobDetails(jobId, updateHash)
      errMsg = "ERROR: ClusterJobManager.markJobSubmissionTime: "      
      return updateByFieldAndValue(:otherDB, @jobTable, updateHash, "id", jobId, errMsg)
    end
    
    # Creates and returns a #ClusterJob object corresponding to the supplied jobRecord from the ClusterJobs scheduler table
    # [+jobRecord+] object representing a record extracted from the job scheduler table
    # [+returns+]   ClusterJob object corresponding to supplied record
    
    def createClusterJob(jobRecord)
      clusterJob = ClusterJob.new
      clusterJob.id = jobRecord["id"]
      clusterJob.jobName = jobRecord["name"]
      clusterJob.entryDate = jobRecord["entryDate"]      
      clusterJob.submissionDate = jobRecord["sgeSubmissionDate"]
      clusterJob.clusterJobId = jobRecord["sgeJobId"]      
      clusterJob.jobStatus = jobRecord["status"]
      clusterJob.removeDirectory = jobRecord["removeDirectory"]
      clusterJob.outputDirectory = jobRecord["outputDirectory"]      
      clusterJob.notificationEmail = jobRecord["email"]
      jobRecord["commands"].split(/,/).each{ |command| clusterJob.commands << command }
      jobRecord["resources"].split(/,/).each{ |resource| clusterJob.resources << resource }
      jobRecord["inputFiles"].split(/,/).each{ |inputFile| clusterJob.inputFiles << inputFile }
      clusterJob.jsonContextString = jobRecord["contextString"]      
      clusterJob.outputFileList=JSON.parse(jobRecord["outputFileList"])
      errMsg = "ERROR: ClusterJobManager.createClusterJob: " 
      resourcePaths = selectByFieldAndValue(:otherDB, @resourceTable, "clusterJob_id", clusterJob.id, errMsg)
      resourcePaths.each{|resourcePath| clusterJob.resourcePaths << resourcePath["resourceIdentifier"]}      
      return clusterJob      
    end
  end
  
end
end  # module BRL ; module Cluster ;
