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
require 'brl/cluster/clusterJobUtils'


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

      # ############################################################################
      # CONSTANTS
      # ############################################################################
      INSERT_CLUSTERJOB_SQL = 'insert into clusterJobs (name, queue, status, entryDate, submitDate, execStartDate, execEndDate, commands, cleanUpCommands, inputFiles, outputDirectory, removeDirectory, email, contextString, outputFileList, pbsCommands) values(?, ?, default, default, default, default, default, ?, ?, ?, ?, ?, ?, ?, ?, ?)'

      def insertClusterJob(clusterJob)
        retVal = nil
        begin
          commandsText = clusterJob.commands.join(",")
          cleanUpCommandsText = clusterJob.cleanUpCommands.join(',')
          inputFilesText = clusterJob.inputFiles.join(",")
          connectToOtherDb()
          stmt = @otherDbh.prepare(INSERT_CLUSTERJOB_SQL)
          if(clusterJob.removeDirectory == true)
            clusterJob.removeDirectory = "true"
          elsif(clusterJob.removeDirectory == false)
            clusterJob.removeDirectory = "false"
          end
          stmt.execute(clusterJob.jobName, clusterJob.queueName, commandsText, cleanUpCommandsText, inputFilesText, clusterJob.outputDirectory.to_s, clusterJob.removeDirectory, clusterJob.notificationEmail, clusterJob.jsonContextString, clusterJob.outputFileList, clusterJob.pbsCommands)
          retVal = stmt.rows
        rescue => @err
          BRL::Genboree::DBUtil.logDbError("ERROR: ClusterDBUtil#insertClusterJob(): ", @err, INSERT_CLUSTERJOB_SQL)
        ensure
          stmt.finish() unless(stmt.nil?)
        end
        return retVal
      end

      def insertJob(clusterJob)
        retVal = nil
        if(ClusterJobUtils.clusterJobFilledCorrectly(clusterJob).nil?) then
          retVal = nil
        else
          numRecords = insertClusterJob(clusterJob)
          if(numRecords!=1) then
            retVal = nil
          else
            errMsg = "ERROR: ClusterDBUtil#insertJob"
            jobRecords = selectByFieldAndValue(:otherDB, @jobTable, "name", clusterJob.jobName, errMsg)
            clusterJobId = jobRecords[0]["id"]
            retVal = clusterJobId
            clusterJob.resourcePaths.each{|resourcePath|
              resourceData = []
              resourceData << clusterJobId
              resourceData << resourcePath
              errMsg = "ERROR: ClusterDBUtil#insertJob:ResourcesTable #{@resourceTable} "
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
        errMsg = "ERROR: ClusterDBUtil#retrieveJob: "
        jobRecords = selectByFieldAndValue(:otherDB, @jobTable, "id", jobId, errMsg)
        if(jobRecords.empty? or jobRecords.nil?) then
          retVal = nil
        else
          retVal = createClusterJob(jobRecords[0])
          if(ClusterJobUtils.clusterJobFilledCorrectly(retVal).nil?) then
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
        errMsg = "ERROR: ClusterJobManager#queryJobsNotSubmitted: "
        unsubmittedJobs = selectByFieldAndValue(:otherDB, @jobTable, "status", "entered", errMsg)
        clusterJobs = []
        if(unsubmittedJobs.empty? || unsubmittedJobs.nil?) then
          return retVal
        else
          unsubmittedJobs.each{|jobRecord|
            begin
            clusterJobs << createClusterJob(jobRecord)
            rescue Exception => err1
              ClusterJobUtils.logClusterError("Error extracting job  #{jobRecord["name"]} from queue\nMessage: #{err1.message}\n:Backtrace:\n#{err1.backtrace.join("\n")}")
            end

            }
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
        errMsg = "ERROR: ClusterDBUtil#updateClusterJobDetails: "
        return updateByFieldAndValue(:otherDB, @jobTable, updateHash, "id", jobId, errMsg)
      end

      # Creates and returns a #ClusterJob object corresponding to the supplied jobRecord from the ClusterJobs scheduler table
      # [+jobRecord+] object representing a record extracted from the job scheduler table
      # [+returns+]   ClusterJob object corresponding to supplied record

      def createClusterJob(jobRecord)
        clusterJob = ClusterJob.new
        clusterJob.id = jobRecord["id"]
        clusterJob.jobName = jobRecord["name"]
        clusterJob.queueName = (jobRecord["queue"] || 'general')
        clusterJob.entryDate = jobRecord["entryDate"]
        clusterJob.submitDate = jobRecord["submitDate"]
        clusterJob.clusterJobId = jobRecord["clusterJobId"]
        clusterJob.jobStatus = jobRecord["status"]
        clusterJob.removeDirectory = jobRecord["removeDirectory"]
        clusterJob.outputDirectory = jobRecord["outputDirectory"]
        clusterJob.notificationEmail = jobRecord["email"]
        clusterJob.pbsCommands = jobRecord['pbsCommands'] if(jobRecord['pbsCommands'])
        jobRecord["commands"].split(/,/).each{ |command| clusterJob.commands << command }
        jobRecord['cleanUpCommands'].split(/,/).each{ |command| clusterJob.cleanUpCommands << command } unless(jobRecord['cleanUpCommands'].nil? or jobRecord['cleanUpCommands'].empty?)
        jobRecord["inputFiles"].split(/,/).each{ |inputFile| clusterJob.inputFiles << inputFile }
        clusterJob.jsonContextString = jobRecord["contextString"]
        clusterJob.outputFileList = JSON.parse(jobRecord["outputFileList"]) unless jobRecord["outputFileList"].nil?
        errMsg = "ERROR: ClusterDBUtil#createClusterJob: "
        resourcePaths = selectByFieldAndValue(:otherDB, @resourceTable, "clusterJob_id", clusterJob.id, errMsg)
        resourcePaths.each{|resourcePath| clusterJob.resourcePaths << resourcePath["resourceIdentifier"]}
        return clusterJob
      end
    end

  end
end  # module BRL ; module Cluster ;
