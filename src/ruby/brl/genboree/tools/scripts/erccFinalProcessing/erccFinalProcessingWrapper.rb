#!/usr/bin/env ruby
#########################################################
############ ERCC Final Processing Tool                 #
# This wrapper completes various final processing steps #
# involved with ERCC tools.                             #
# Currently, this wrapper does the following:           #
#   1. Sends e-mail out to user with information about  #
#      their overall job (useful for exceRpt and        #
#      RSEQTools batch-processing).                     #
#   2. Uploads tool usage doc to appropriate collection #
#      to help us keep track of ERCC tool usage         # 
# We can add more methods to this wrapper in the future #
# if we need additional generic final-processing steps. #
#########################################################

require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/tools/FTPtoolWrapper'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class ErccFinalProcessingWrapper < BRL::Genboree::Tools::FTPToolWrapper
    VERSION = "1.0.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for completing final processing steps associated with ERCC tools.
                        This tool is intended to be called internally by relevant ERCC tools.",
      :authors      => [ "William Thistlethwaite (thistlew@bcm.edu) and Sai Lakshmi Subramanian (sailakss@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # [+returns+] nil
    def processJobConf()
      begin
        @targetUri = @outputs[0]
        # Getting relevant variables from "context"
        @dbrcKey = @context['apiDbrcKey']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        @analysisName = @settings['analysisName']
        # Grab group and database name from outputs
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
        # Get the tool versions
        toolVersion = @toolConf.getSetting('info', 'version')
        @settings['toolVersion'] = toolVersion
        # Resource path related variables for tool usage doc
        @exRNAInternalKBHost = @genbConf.exRNAInternalKBHost
        @exRNAInternalKBGroup = @genbConf.exRNAInternalKBGroup
        @exRNAInternalKBName = @genbConf.exRNAInternalKBName
        @piCodesColl = @genbConf.exRNAInternalKBPICodesColl
        @erccToolUsageColl = @genbConf.exRNAInternalKBToolUsageColl
        # Resource path related variables for exRNA collections
        @exRNAHost = @settings['exRNAHost']
        @exRNAKbGroup = @settings['exRNAKbGroup']
        @exRNAKb = @settings['exRNAKb']
        @genboreeKbArea = @settings['genboreeKbArea']
        @exRNAKbProject = @settings['exRNAKbProject']
        # ERCC tool usage doc info - more information grabbed below during run() method
        @piID = @settings['piID']
        @shortPiID = @piID[4..9] if(@piID)
        @piName = @settings['piName']
        if(@settings['grantNumber'] == "Non-ERCC Funded Study")
          @grantNumber = @settings['grantNumber']
        else 
          @grantNumber = @settings['grantNumber'].split(" ")[0]
        end
        @platform = @settings['platform']
        @processingPipeline = @settings['processingPipeline']
        @processingPipelineVersion = @settings['processingPipelineVersion']
        @processingPipelineIdAndVersion = @settings['processingPipelineIdAndVersion']
        @anticipatedDataRepo = @settings['anticipatedDataRepo']
        @otherDataRepo = @settings['otherDataRepo']
        @dataRepoSubmissionCategory = @settings['dataRepoSubmissionCategory']
        @dbGaP = @settings['dbGaP']
        # Variables that will be filled out below
        @submitterOrganization = ""
        @piOrganization = ""
        @coPINames = ""
        @rfaTitle = ""
        @rfaTitle = "Non-ERCC Submission" if(@grantNumber == "Non-ERCC Funded Study")
        # FTP-related variables
        @isFTPJob = @settings['isFTPJob']
        if(@isFTPJob)
          @finishedFtpDir = @settings['finishedFtpDir']
          @backupFtpDir = @settings['backupFtpDir']
          @manifestLocation = @settings['manifestLocation']
          @metadataArchiveLocation = @settings['metadataArchiveLocation']
          @dataArchiveLocation = @settings['dataArchiveLocation']
          @finalizedMetadataDir = @settings['finalizedMetadataDir']
          @resultFileDescriptions = JSON.parse(File.read(@genbConf.FTPsmRNAPipelineResultFileDescriptions))
          @readCountCategories = JSON.parse(File.read(@genbConf.FTPsmRNAPipelineReadCountCategories)) 
          @manifestFile = @settings['manifestFile']
          fileData = JSON.parse(File.read(@manifestFile))
          @manifest = fileData["manifest"]
          @outputAreaOnGenboree = @outputs[0]
          @outputHost = URI.parse(@outputAreaOnGenboree).host
          # Create converter and producer for use throughout - we don't need model for any reason so set producer's model to nil
          @converter = BRL::Genboree::KB::Converters::NestedTabbedDocConverter.new()
          @producer = BRL::Genboree::KB::Producers::NestedTabbedDocProducer.new(nil)
          @postProcOutputDir = @settings['postProcOutputDir'] 
          @toolVersionPPR = @settings['toolVersionPPR']
          @uploadReadCountsDocs = @settings['uploadReadCountsDocs']
          @kbBulkUploadJobConfDir = "#{@settings['jobSpecificSharedScratch']}/kbBulkUploadJobConfs"
          `mkdir -p #{@kbBulkUploadJobConfDir}`
          @kbBulkUploadIndex = 0
          @dateOfSubmission = @settings['dateOfSubmission']
        end
        @uploadFullResults = @settings['uploadFullResults']
        @isRemoteStorage = true if(@settings['remoteStorageArea'])
        if(@isRemoteStorage)
          @remoteStorageArea = @settings['remoteStorageArea']
        end
        @subUserId = @settings['subUserId']
        @subUserId = @userId unless(@subUserId)
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error with processJobConf: #{err}")
        @errUserMsg = "ERROR: Could not set up required variables for running job." if(@errUserMsg.nil?)
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Backtrace: #{@errBacktrace}")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # [+returns+] nil
    def run()
      begin
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        user = dbrc.user
        pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        ### GRAB INFO FOR TOOL USAGE DOC ###
        # Grab info about submitter's organization if he/she is non-ERCC (to fill in Tool Usage doc)
        if(@settings['piName'] == "Non-ERCC PI")
          apiCaller = ApiCaller.new(@host, "/REST/v1/usr/#{@userLogin}", user, pass)
          apiCaller.get()
          @submitterOrganization = apiCaller.parseRespBody["data"]["institution"]
          @submitterOrganization = "N/A" if(@submitterOrganization.empty?)
          @piOrganization = "N/A (Submitter organization: #{@submitterOrganization})"
        else
          # Grab PI document to find some additional information for tool usage doc
          apiCaller = ApiCaller.new(@exRNAInternalKBHost, "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}", user, pass)
          apiCaller.get({:grp => @exRNAInternalKBGroup, :kb => @exRNAInternalKBName, :coll => @piCodesColl, :doc => @piID})
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "API RESPONSE: #{apiCaller.respBody.inspect}")
          piDoc = BRL::Genboree::KB::KbDoc.new(apiCaller.parseRespBody["data"])
          @piOrganization = piDoc.getPropVal("ERCC PI Code.Organization")
          unless(@grantNumber == "Non-ERCC Funded Study")
            grantDetails = piDoc.getPropItems("ERCC PI Code.Grant Details")
            grantDetails.each { |currentGrant|
              currentGrant = BRL::Genboree::KB::KbDoc.new(currentGrant)
              currentGrantNumber = currentGrant.getPropVal("Grant Number")
              if(currentGrantNumber == @grantNumber)
                @rfaTitle = currentGrant.getPropVal("Grant Number.RFA")
                @coPINames = currentGrant.getPropVal("Grant Number.Co PI Names") if(currentGrant.getPropVal("Grant Number.Co PI Names"))
              end
            }
          end
        end
        # We will create an API caller to get info about each of our jobs and its status (completed / failed / etc.)
        apiCaller = WrapperApiCaller.new(@host, "/REST/v1/job/{jobId}?detailed=summary", @userId)
        @jobs = {}
        # Traverse all jobIds
        # Grab job IDs and put them in @listOfJobIds - all important job IDs are present in @settings['importantJobIdsDir']
        @listOfJobIds = {}
        importantJobIdsDir = @settings['importantJobIdsDir']
        jobIdFiles = Dir.entries(importantJobIdsDir)
        jobIdFiles.delete(".")
        jobIdFiles.delete("..")
        jobIdFiles.each { |currentFile|
          jobId = JSON.parse(File.read("#{importantJobIdsDir}/#{currentFile}"))
          @listOfJobIds.merge!(jobId)
        }
        @listOfJobIds.each_key { |jobId|
          apiCaller.get( { "jobId" => jobId})
          status = apiCaller.parseRespBody['data']['status']
          @jobs[jobId] = "#{@listOfJobIds[jobId]} - #{status}"
        }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "LIST OF JOBS: #{@jobs.inspect}")
        # @sampleStatus will store info about each status and whether it completed successfully or failed
        @sampleStatus = {} 
        # @successfulSamples will store number of successful samples
        @successfulSamples = 0
        # @failedSamples will store number of failed samples
        @failedSamples = 0
        # Traverse all jobs and set up @sampleStatus for tool usage doc
        @jobs.each_key { |currentJob|
          sampleNameAndStatus = @jobs[currentJob].split(" - ")
          # If job is not an actual sample (PPR job or exogenousSTARMapping job), then skip it
          next if(sampleNameAndStatus[0] == "Process Pipeline Runs Job" or sampleNameAndStatus[0] == "Exogenous STAR Mapping Job")
          # Grab sample name and status for current job
          sampleName = sampleNameAndStatus[0]
          status = sampleNameAndStatus[1]
          if(status == "completed")
            @sampleStatus[sampleName] = "Completed"
            @successfulSamples += 1
          else
            @sampleStatus[sampleName] = "Failed" unless(@sampleStatus[sampleName] == "Completed")
            @failedSamples += 1
          end
        }
        # If we're processing an FTP job, we'll upload metadata and then transfer our original manifest / metadata archive / data archive to the user's finished directory on FTP server.
        if(@isFTPJob)
          # Add all updated metadata files to new zip archive that we will upload to finished area and backup area
          @metadataDirForFtpUpload = "#{@scratchDir}/metadataDirForFtpUpload"
          `mkdir #{@metadataDirForFtpUpload}`
          @finalMetadataArchiveLocation = "#{@metadataDirForFtpUpload}/#{File.basename(@metadataArchiveLocation)}"
          finishAndUploadMetadata()
          raise @errUserMsg unless(@errUserMsg.nil? or @errUserMsg.empty?)
          `cd #{@finalizedMetadataDir} ; cp * #{@metadataDirForFtpUpload}`
          `cd #{@metadataDirForFtpUpload} ; zip #{File.basename(@metadataArchiveLocation)} *`
          # We are transferring updated files to backup area and original files to finished area
          # Note that data has already been transferred to backup area via runExceRpt jobs
          transferFtpFile(@manifestLocation, "#{@finishedFtpDir}#{File.basename(@manifestLocation)}", true)
          transferFtpFile(@manifestFile, @backupFtpDir, false)
          transferFtpFile(@metadataArchiveLocation, "#{@finishedFtpDir}#{File.basename(@metadataArchiveLocation)}", true)
          transferFtpFile(@finalMetadataArchiveLocation, @backupFtpDir, false)
          transferFtpFile(@dataArchiveLocation, "#{@finishedFtpDir}#{File.basename(@dataArchiveLocation)}", true)
        end
        # We won't submit tool usage docs if it's an AUTO job
        submitToolUsageDoc(user, pass) unless(@settings['primaryJobId'][0..4] == "AUTO-")
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of ERCC Final Processing tool failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to run ERCC Final Processing tool." if(@errInternalMsg.nil?)
        @exitCode = 30
      ensure
        # Make sure that we close @ftpHelper.ftpObj (to avoid idle connection to FTP server)
        @ftpHelper.ftpObj.close() rescue nil
        @ftpHelper = nil
        # Let's clean up the job-specific scratch area, since we're done with it (this tool is the last tool in the workflow)
        jobSpecificSharedScratch = @settings['jobSpecificSharedScratch']
        cleanUp([/EXOGENOUS_rRNA\/unaligned.fq.gz/], [], jobSpecificSharedScratch)
      end
      return @exitCode
    end

    # This method is used for FTP-based wrappers (currently, just FTPexceRptPipeline).
    # We edit / fill out metadata documents (Run document, Analysis document, Result Files documents)
    # and then upload those documents to both the user's database and to the exRNA GenboreeKB.
    def finishAndUploadMetadata()
      # Grab current names of collections
      @collections = JSON.parse(File.read(@genbConf.FTPsmRNAPipelineKBCollections))
      @analysisCollection = @collections["Analysis"]
      @biosampleCollection = @collections["Biosample"]
      @donorCollection = @collections["Donor"]
      @experimentCollection = @collections["Experiment"]
      @jobCollection = @collections["Job"]
      @resultFilesCollection = @collections["Result Files"]
      @runCollection = @collections["Run"]
      @studyCollection = @collections["Study"]
      @submissionCollection = @collections["Submission"]
      @readCountsCollection = @collections["Read Counts"]
      # Set up array to hold all metadata files and hash for each document type (by collection)
      @metadataFiles = []
      @analysisMetadataFile = {}
      @biosampleMetadataFiles = {}
      @failedBiosampleMetadataFiles = {}
      @donorMetadataFiles = {}
      @experimentMetadataFiles = {}
      @resultFilesMetadataFiles = {}
      @runMetadataFile = {}
      @studyMetadataFile = {}
      @submissionMetadataFile = {}
      # Set up arrays / strings to hold IDs for each document type (by collection)
      @analysisID = ""
      @biosampleIDs = []
      @failedBiosampleIDs = []
      @donorIDs = []
      @experimentIDs = []
      @readCountsIDs = []
      @resultFilesIDs = []
      @runID = ""
      @studyID = ""
      @submissionID = ""
      # Load metadata docs
      loadMetadataDocs()
      raise @errUserMsg unless(@errUserMsg.nil? or @errUserMsg.empty?)
      # Load input files hash
      @inputFiles = JSON.parse(File.read("#{@settings['jobSpecificSharedScratch']}/inputFilesHash.txt"))
      @sampleDir = "#{@settings['jobSpecificSharedScratch']}/samples"
      allSamples = Dir.entries(@sampleDir)
      allSamples.delete(".")
      allSamples.delete("..")
      allSamples.each { |currentSample|
        next if(File.directory?("#{@sampleDir}/#{currentSample}"))
        sampleHash = JSON.parse(File.read("#{@settings['jobSpecificSharedScratch']}/samples/#{currentSample}"))
        # Let's check to see if we need to correct the key for this hash so that it matches our @inputFiles hash
        unextractedToExtractedMappings = JSON.parse(File.read("#{@settings['jobSpecificSharedScratch']}/samples/unextractedToExtractedMappings/#{currentSample}"))
        if(sampleHash.keys[0] != unextractedToExtractedMappings.keys[0])
          # Update the key for the hash to be the unextracted archive name (as opposed to extracted name) since that will match the original entry in the @inputFiles hash
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Updating key #{sampleHash.keys[0]} to be #{unextractedToExtractedMappings.keys[0]}")
          sampleHash[unextractedToExtractedMappings.keys[0]] = sampleHash.delete(sampleHash.keys[0])
          # Let's 1) delete the job that failed due to memory issues and 2) rename the successful re-run job with the old sample name
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Deleting #{File.basename(unextractedToExtractedMappings.keys[0])} from @sampleStatus")
          @sampleStatus.delete(File.basename(unextractedToExtractedMappings.keys[0]))
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Updating key #{unextractedToExtractedMappings.values[0]} to be #{File.basename(unextractedToExtractedMappings.keys[0])}")
          @sampleStatus[File.basename(unextractedToExtractedMappings.keys[0])] = @sampleStatus.delete(unextractedToExtractedMappings.values[0])
        end
        currentInput = sampleHash.keys[0]
        @inputFiles[currentInput].merge!(sampleHash[currentInput])
      }
      #### REMOVING UNSUCCESSFUL RUNS ####
      # Remove biosamples associated with unsuccessful pipeline runs from @biosampleMetadataFiles and @biosampleIDs
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing unsuccessful biosamples (failed runs) from @biosampleMetadataFiles and @biosampleIDs")
      @inputFiles.each_key { |currentFile|
        if(@sampleStatus[File.basename(currentFile)] == "Failed")
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing #{File.basename(currentFile)}'s biosample because it's associated with a failed sample")
          currentKbDoc = @biosampleMetadataFiles[@inputFiles[currentFile]["biosampleMetadataFileName"]]
          currentBioID = currentKbDoc.getPropVal("Biosample")
          @biosampleIDs.delete(currentBioID)
          @failedBiosampleIDs << currentBioID
          @failedBiosampleMetadataFiles[@inputFiles[currentFile]["biosampleMetadataFileName"]] = @biosampleMetadataFiles[@inputFiles[currentFile]["biosampleMetadataFileName"]].clone()
          File.open(@inputFiles[currentFile]["biosampleMetadataFileName"], 'w') { |file| file.write(@producer.produce(@failedBiosampleMetadataFiles[@inputFiles[currentFile]["biosampleMetadataFileName"]]).join("\n")) }
          `cp #{@inputFiles[currentFile]["biosampleMetadataFileName"]} #{@metadataDirForFtpUpload}/#{@inputFiles[currentFile]["biosampleMetadataFileName"]}`          
          @biosampleMetadataFiles.delete(@inputFiles[currentFile]["biosampleMetadataFileName"])
        end
      }
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully removed unsuccessful biosamples")
      #### GRABBING CONDITIONS ASSOCIATED WITH SUCCESSFUL BIOSAMPLES ####
      @conditions = []
      @biosampleMetadataFiles.each_value { |currentBioDoc|
        @conditions << currentBioDoc.getPropVal("Biosample.Biological Sample Elements.Disease Type") unless(@conditions.include?(currentBioDoc.getPropVal("Biosample.Biological Sample Elements.Disease Type")))
      }
      #### FILLING IN METADATA DOCUMENTS (STAGE 2)
      # RUN: Fill in info for run document (real info now that samples have been processed and unsuccessful samples have been removed)
      @exitCode = fillInRunDoc(@biosampleIDs.count)
      raise @errUserMsg unless(@errUserMsg.nil? or @errUserMsg.empty?)      
      # RUN: Fill in proper file type in run document for each biosample
      #@exitCode = fillInFileTypeForRunDoc()
      #raise @errUserMsg unless(@errUserMsg.nil? or @errUserMsg.empty?)
      # ANALYSIS: Fill in analysis document with preliminary information
      @exitCode = fillInPrelimAnalysisInfo(@successfulSamples)
      raise @errUserMsg unless(@errUserMsg.nil? or @errUserMsg.empty?)
      # ANALYSIS: Fill in analysis document with info from each successful pipeline run
      # Create map from biosample ID to donor ID / result files ID / read counts ID - useful when filling in job doc below
      @biosampleToRelatedIDs = {}
      @inputFiles.each_key { |currentFile|
        unless(@sampleStatus[File.basename(currentFile)] == "Failed")
          @exitCode = fillInAnalysisDoc(@inputFiles[currentFile])
          raise @errUserMsg unless(@errUserMsg.nil? or @errUserMsg.empty?)
        end
      }
      @metadataFiles << @resultFilesMetadataFiles
      # JOB: Add related docs from all collections (run, submission, study, analysis, experiments, biosamples, donors, result files) 
      #      This document needs to be created near the end of our wrapper because:
      #        1) Only successful biosamples should be added to the Job doc (which means that the Job doc should be created AFTER the pipeline runs are finished)
      #        2) The Job doc includes the IDs for our Result Files docs, and these docs are created in the "fillInAnalysisDoc" method (which is run near the end of our wrapper)
      @exitCode = fillInJobDoc()
      raise @errUserMsg unless(@errUserMsg.nil? or @errUserMsg.empty?)
      #### POST-PROCESSING ####
      # ANALYSIS: Fill in analysis document with information from processPipelineRuns
      @exitCode = fillInPostProcessingInfo()
      raise @errUserMsg unless(@errUserMsg.nil? or @errUserMsg.empty?)
      #### UPLOADING METADATA DOCUMENTS ####
      # Delete @finalizedMetadataDir and then create a new version since we're going to be replacing our old docs with the ACTUAL, truly finalized docs
      `rm -rf #{@finalizedMetadataDir}`
      `mkdir #{@finalizedMetadataDir}`
      @metadataFiles.each { |currentDocs|
        @exitCode = uploadMetadataDocs(currentDocs)
        raise @errUserMsg unless(@errUserMsg.nil? or @errUserMsg.empty?)
      }
    end

    # Reads text files and loads metadata files into hashes
    def loadMetadataDocs()
      metadataDirs = Dir.entries(@finalizedMetadataDir)
      metadataDirs.delete(".")
      metadataDirs.delete("..")
      metadataDirs.each { |currentCollection|
        currentMetadataFiles = Dir.entries("#{@finalizedMetadataDir}/#{currentCollection}")
        currentMetadataFiles.delete(".")
        currentMetadataFiles.delete("..")
        currentMetadataFiles.each { |currentMetadataFile|
          currentDoc = BRL::Genboree::KB::KbDoc.new(JSON.parse(File.read("#{@finalizedMetadataDir}/#{currentCollection}/#{currentMetadataFile}")))
          currentID = currentDoc.getRootPropVal()
          if(currentCollection == @analysisCollection)
            @analysisMetadataFile[currentMetadataFile] = currentDoc
            @analysisID = currentID
          elsif(currentCollection == @biosampleCollection)
            @biosampleMetadataFiles[currentMetadataFile] = currentDoc
            @biosampleIDs << currentID
          elsif(currentCollection == @donorCollection)
            @donorMetadataFiles[currentMetadataFile] = currentDoc
            @donorIDs << currentID
          elsif(currentCollection == @experimentCollection)
            @experimentMetadataFiles[currentMetadataFile] = currentDoc
            @experimentIDs << currentID
          elsif(currentCollection == @runCollection)
            @runMetadataFile[currentMetadataFile] = currentDoc
            @runID = currentID
          elsif(currentCollection == @studyCollection)
            @studyMetadataFile[currentMetadataFile] = currentDoc
            @studyID = currentID
          elsif(currentCollection == @submissionCollection)
            @submissionMetadataFile[currentMetadataFile] = currentDoc
            @submissionID = currentID
          end
        }
      }
      @metadataFiles << @analysisMetadataFile
      @metadataFiles << @biosampleMetadataFiles
      @metadataFiles << @donorMetadataFiles
      @metadataFiles << @experimentMetadataFiles
      @metadataFiles << @runMetadataFile
      @metadataFiles << @studyMetadataFile
      @metadataFiles << @submissionMetadataFile
      return
    end

    # Fills in run doc with appropriate info (info about different samples, related studies)  
    # @param [Fixnum] noSamples number of samples we want to set "Run.Type.small RNA-Seq.Raw Data Files" to
    # @return [Fixnum] exit code indicating whether filling in run doc succeeded (0) or failed (29)
    def fillInRunDoc(noSamples)
      begin
        # Grab run doc and study doc
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adding information about biosamples and study to run metadata document")
        runKbDoc = @runMetadataFile.values[0]
        # Set up basic stuff that is always the same for every exceRpt run doc
        runKbDoc.setPropVal("Run.Type", "small RNA-Seq")
        runKbDoc.setPropVal("Run.Type.small RNA-Seq", "")
        # Number of raw data files will be set to number of samples that were successfully processed through pipeline (unsuccessful samples will not be added!)
        runKbDoc.setPropVal("Run.Type.small RNA-Seq.Raw Data Files", noSamples)
        # Clear out user-submitted data files (we only care about successful samples from THIS pipeline run)
        runKbDoc.delPropItems("Run.Type.small RNA-Seq.Raw Data Files")
        errorMessages = ""
        # We will add information about each successful sample as an item
        @biosampleMetadataFiles.each_key { |currentBiosampleName|
          currentBioKbDoc = @biosampleMetadataFiles[currentBiosampleName]
          biosampleID = currentBioKbDoc.getPropVal("Biosample")
          sampleName = currentBioKbDoc.getPropVal("Biosample.Name")
          fileName = ""
          foundSample = false
          @manifest.each { |currentSampleInManifest|
            if(currentSampleInManifest["sampleName"] == sampleName)
              unless(foundSample)
                foundSample = true
                fileName = currentSampleInManifest["dataFileName"]
              else
                errorMessages << "Multiple samples in your manifest file matched the sample name #{sampleName}\nfound under the \"Biosample.Name\" property for #{File.basename(@biosampleMetadataFiles.index(currentBioKbDoc))}.\nSample names must be unique within a given submission!\n\n"
              end
            end
          }
          if(fileName.empty?)
            errorMessages << "Each biosample metadata document you submit must have a value for its \"Biosample.Name\" property,\nand that value must match the \"sampleName\" field for some sample in the manifest file.\nHowever, we could not find a match for #{File.basename(@biosampleMetadataFiles.index(currentBioKbDoc))}.\n\n"
          end
          next unless(errorMessages.empty?)
          # Create a new doc that will be inserted into "Run.Type.small RNA-Seq.Raw Data Files" as an item. We will fill in various bits of information about the sample before we add it.
          currentSampleInRun = BRL::Genboree::KB::KbDoc.new({})
          currentSampleInRun.setPropVal("Biosample ID", biosampleID)
          currentSampleInRun.setPropVal("Biosample ID.File Name", fileName)
          currentSampleInRun.setPropVal("Biosample ID.DocURL", "coll/#{CGI.escape(@biosampleCollection)}/doc/#{biosampleID}")
          @inputFiles.each_key { |currentInput|
            inputFileBiosample = @inputFiles[currentInput]["biosampleMetadataFileName"]
            if(inputFileBiosample == currentBiosampleName)
              currentRawInput = @inputFiles[currentInput]["rawInput"]
              md5 = @inputFiles[currentInput]["md5"]
              currentSampleInRun.setPropVal("Biosample ID.File Name", currentRawInput)
              currentSampleInRun.setPropVal("Biosample ID.MD5 Checksum", md5)
              if(@uploadFullResults)
                currentSampleName = @inputFiles[currentInput]["sampleName"]
                currentCompressedInput = "#{@inputFiles[currentInput]["rawInput"]}.gz"
                currentURL = @outputAreaOnGenboree.clone
                currentURL << "/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@processingPipelineVersion}/#{CGI.escape(@analysisName)}/#{CGI.escape(currentSampleName)}/rawInput/#{CGI.escape(currentCompressedInput)}"
                currentSampleInRun.setPropVal("Biosample ID.File URL", currentURL)
              end
            end
          }
          # The file type below is a dummy value. We cannot fill out this info accurately the first time we run this method because it is run before the data archive is downloaded.
          # We will fill out this info accurately after the data archive is downloaded by using the fillInFileTypeForRunDoc method.
          currentSampleInRun.setPropVal("Biosample ID.Type", "FASTQ")
          # Finally, we add the biosample as an item in the "Run.Type.small RNA-Seq.Raw Data Files" item list
          runKbDoc.addPropItem("Run.Type.small RNA-Seq.Raw Data Files", currentSampleInRun)
        }
        unless(errorMessages.empty?)
          errorMessages.insert(0, "There were some errors when connecting your biosample metadata documents to the manifest file.\nSpecific messages can be found below:\n\n")
          @errUserMsg = errorMessages
          raise @errUserMsg
        end
        # We will add a link to the submitted study document in the "Related Studies" item list (if it's not already there)
        relatedStudy = BRL::Genboree::KB::KbDoc.new({})
        relatedStudy.setPropVal("Related Study", @studyID)
        relatedStudy.setPropVal("Related Study.DocURL", "coll/#{CGI.escape(@studyCollection)}/doc/#{@studyID}")
        runKbDoc.setPropVal("Run.Related Studies", "")
        foundStudy = false
        currentStudies = runKbDoc.getPropItems("Run.Related Studies")
        if(currentStudies)
          currentStudies.each { |currentStudy|
            currentStudy["Related Study"]["value"].insert(4, @shortPiID) unless(currentStudy["Related Study"]["value"][4, @shortPiID.length] == @shortPiID and currentStudy["Related Study"]["value"].length > 4)
            if(currentStudy["Related Study"]["properties"])
              currentStudy["Related Study"]["properties"].store("DocURL", {"value"=>"coll/#{CGI.escape(@studyCollection)}/doc/#{currentStudy["Related Study"]["value"]}"})
            else 
              currentStudy["Related Study"]["properties"] = {"DocURL"=>{"value"=>"coll/#{CGI.escape(@studyCollection)}/doc/#{currentStudy["Related Study"]["value"]}"}}
            end 
            foundStudy = true if(currentStudy["Related Study"]["value"] == @studyID)
          }
        end
        runKbDoc.addPropItem("Run.Related Studies", relatedStudy) unless(foundStudy)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done adding information about biosamples and study to run metadata document")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in biosample / study information for your run metadata document." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 29
      end  
      return @exitCode
    end

    # Fills in the file type for each biosample in the run document
    # This process has to be done AFTER the data archive is downloaded, so that's why it's a separate method
    # CURRENTLY NOT BEING USED!
    # @return [Fixnum] exit code indicating whether filling in file type for run doc succeeded (0) or failed (51)
    def fillInFileTypeForRunDoc()
      begin
        # errorMessages will hold all of the different samples for which we had issues finding the file type
        errorMessages = ""
        # Traverse all biosample KB docs
        @biosampleMetadataFiles.each_value { |currentBioKbDoc|
          # Grab biosample ID as well as sample name
          biosampleID = currentBioKbDoc.getPropVal("Biosample")
          sampleName = currentBioKbDoc.getPropVal("Biosample.Name")
          fileName = ""
          fileType = ""
          # Traverse each sample in our manifest
          @manifest.each { |currentSampleInManifest|
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current sample in manifest: #{currentSampleInManifest.inspect}")
            # If we find a match between the biosample kb doc's sample name and the manifest's sample name, then we proceed
            if(currentSampleInManifest["sampleName"] == sampleName)
              # fileName will hold the data file name associated with that sample in the manifest
              fileName = currentSampleInManifest["dataFileName"]
              # We traverse all the input files and figure out which one has the same name (compressed or uncompressed) as fileName
              # If we find a match, then we look at fileType for that input file to find the sniffed file type
              newName = ""
              md5 = "" 
              @inputFiles.each_key { |currentInputFile|
                # Temporarily (?) not supporting users putting unarchived sample name in manifest file (if sample file came in an archive to begin with)
                if(fileName == @inputFiles[currentInputFile]["originalFileName"])
                  fileType = @inputFiles[currentInputFile]["fileType"]
                  newName = File.basename(currentInputFile)
                  md5 = @inputFiles[currentInputFile]["md5"]
                end 
              }
              # If fileType is still empty, then we failed to find a match and we must raise an error
              if(fileType.empty?)
                errorMessages << "We could not find the file type of the input file #{fileName}.\nAre you sure that you wrote the right name for your sample in the \"dataFileName\" field?\n\n"
                next 
              end
              # We figure out which entry in "Run.Type.small RNA-Seq.Raw Data Files" matches our current file name and then update the file type associated with that entry
              allSamplesInRunDoc = @runMetadataFile.values[0].getPropItems("Run.Type.small RNA-Seq.Raw Data Files")
              allSamplesInRunDoc.each { |currentItem|
                currentItem = BRL::Genboree::KB::KbDoc.new(currentItem)
                if(currentItem.getPropVal("Biosample ID.File Name") == fileName)
                  currentItem.setPropVal("Biosample ID.File Name", newName)
                  if(fileType == "FASTQ")
                    currentItem.setPropVal("Biosample ID.Type", fileType)
                  else
                    currentItem.setPropVal("Biosample ID.Type", "FASTQ-like format")
                    currentItem.setPropVal("Biosample ID.Type.Other", fileType)
                  end
                  currentItem.setPropVal("Biosample ID.MD5 Checksum", md5)
                end
              }
              @runMetadataFile.values[0].setPropItems("Run.Type.small RNA-Seq.Raw Data Files", allSamplesInRunDoc)
            end
          }
        }
        # We raise an error if we found any errors above
        unless(errorMessages.empty?)
          @errUserMsg = errorMessages
          raise @errUserMsg
        end
      rescue => err
        @errUserMsg = "ERROR: There was an issue with finding the file type(s) of your submitted data documents." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 51
      end
      return @exitCode
    end

    # Fills in information for job doc 
    # @return [Fixnum] exit code indicating whether filling in job doc succeeded (0) or failed (40)
    def fillInJobDoc()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adding information about metadata files to job metadata file")
        # Create new job KbDoc that will contain information about different metadata files
        jobDoc = BRL::Genboree::KB::KbDoc.new({})
        # Job doc root prop value is the primary job ID associated with the job (FTPexceRpt job ID, basically)
        jobDoc.setPropVal("Job", @settings['primaryJobId'])
        jobDoc.setPropVal("Job.Status", "Add")
        jobDoc.setPropVal("Job.Original Data Archive Name", File.basename(@dataArchiveLocation))
        jobDoc.setPropVal("Job.Manifest File Name", File.basename(@manifestLocation))
        jobDoc.setPropVal("Job.Manifest File Location", "#{@backupFtpDir}#{File.basename(@manifestLocation)}")
        jobDoc.setPropVal("Job.Metadata Archive Name", File.basename(@finalMetadataArchiveLocation))
        jobDoc.setPropVal("Job.Metadata Archive Location", "#{@backupFtpDir}#{File.basename(@finalMetadataArchiveLocation)}")
        # Save run / submission / study / analysis IDs and docURLs
        jobDoc.setPropVal("Job.Related Run", @runID)
        jobDoc.setPropVal("Job.Related Run.DocURL", "coll/#{CGI.escape(@runCollection)}/doc/#{@runID}")
        jobDoc.setPropVal("Job.Related Submission", @submissionID) 
        jobDoc.setPropVal("Job.Related Submission.DocURL", "coll/#{CGI.escape(@submissionCollection)}/doc/#{@submissionID}")
        jobDoc.setPropVal("Job.Related Study", @studyID) 
        jobDoc.setPropVal("Job.Related Study.DocURL", "coll/#{CGI.escape(@studyCollection)}/doc/#{@studyID}")
        jobDoc.setPropVal("Job.Related Analysis", @analysisID) 
        jobDoc.setPropVal("Job.Related Analysis.DocURL", "coll/#{CGI.escape(@analysisCollection)}/doc/#{@analysisID}")
        # Save experiment IDs and docURLs
        jobDoc.setPropVal("Job.Related Experiments", "")
        @experimentIDs.each { |currentID|
          currentIDDoc = BRL::Genboree::KB::KbDoc.new({})
          currentIDDoc.setPropVal("Related Experiment", currentID)
          currentIDDoc.setPropVal("Related Experiment.DocURL", "coll/#{CGI.escape(@experimentCollection)}/doc/#{currentID}")
          jobDoc.addPropItem("Job.Related Experiments", currentIDDoc)
        }
        biosampleIDToRawFileName = {}
        @biosampleMetadataFiles.each_key { |currentBiosampleName|
          currentBioKbDoc = @biosampleMetadataFiles[currentBiosampleName]
          biosampleID = currentBioKbDoc.getPropVal("Biosample")
          sampleName = currentBioKbDoc.getPropVal("Biosample.Name")
          fileName = ""
          @manifest.each { |currentSampleInManifest|
            if(currentSampleInManifest["sampleName"] == sampleName)
              fileName = currentSampleInManifest["dataFileName"]
              fileName.chomp!(".zip")
              fileName.chomp!(".gz")
              fileName << ".gz"
              biosampleIDToRawFileName[biosampleID] = fileName
            end
          }
        }
        @failedBiosampleMetadataFiles.each_key { |currentBiosampleName|
          currentBioKbDoc = @failedBiosampleMetadataFiles[currentBiosampleName]
          biosampleID = currentBioKbDoc.getPropVal("Biosample")
          sampleName = currentBioKbDoc.getPropVal("Biosample.Name")
          fileName = ""
          @manifest.each { |currentSampleInManifest|
            if(currentSampleInManifest["sampleName"] == sampleName)
              fileName = currentSampleInManifest["dataFileName"]
              fileName.chomp!(".zip")
              fileName.chomp!(".gz")
              fileName << ".gz"
              biosampleIDToRawFileName[biosampleID] = fileName
            end
          }
        }
        # Next, we'll save biosample IDs, as well as docs related to those biosamples (donors / result files / read counts)
        jobDoc.setPropVal("Job.Related Biosamples", 0)
        @biosampleIDs.each { |currentID|
          # Save biosample ID and docURL
          currentIDDoc = BRL::Genboree::KB::KbDoc.new({})
          currentIDDoc.setPropVal("Related Biosample", currentID)
          currentIDDoc.setPropVal("Related Biosample.DocURL", "coll/#{CGI.escape(@biosampleCollection)}/doc/#{currentID}")
          # Save donor ID and docURL
          donorID = @biosampleToRelatedIDs[currentID][0]
          currentIDDoc.setPropVal("Related Biosample.Related Donor", donorID)
          currentIDDoc.setPropVal("Related Biosample.Related Donor.DocURL", "coll/#{CGI.escape(@donorCollection)}/doc/#{donorID}")
          # Save result files ID and docURL
          resultFilesID = @biosampleToRelatedIDs[currentID][1]
          currentIDDoc.setPropVal("Related Biosample.Related Result Files", resultFilesID)
          currentIDDoc.setPropVal("Related Biosample.Related Result Files.DocURL", "coll/#{CGI.escape(@resultFilesCollection)}/doc/#{resultFilesID}")
          # There will most likely be multiple read counts IDs associated with a single biosample (one read counts ID per library type - piRNA, tRNA, etc.)
          # We'll save each of them in the Related Read Counts Docs item list.
          if(@uploadReadCountsDocs)
            readCountsIDs = @biosampleToRelatedIDs[currentID][2]
            currentIDDoc.setPropVal("Related Biosample.Related Read Counts Docs", 0)
            readCountsIDs.each { |currentReadCountsID|
              currentReadCountsIDDoc = BRL::Genboree::KB::KbDoc.new({})
              currentReadCountsIDDoc.setPropVal("Related Read Counts", currentReadCountsID)
              currentReadCountsIDDoc.setPropVal("Related Read Counts.DocURL", "coll/#{CGI.escape(@readCountsCollection)}/doc/#{currentReadCountsID}")
              currentIDDoc.addPropItem("Related Biosample.Related Read Counts Docs", currentReadCountsIDDoc)
            }
          end
          currentIDDoc.setPropVal("Related Biosample.Sample Status", "Succeeded")
          currentIDDoc.setPropVal("Related Biosample.File Name", biosampleIDToRawFileName[currentID])
          currentIDDoc.setPropVal("Related Biosample.File Location", "#{@backupFtpDir}data/#{biosampleIDToRawFileName[currentID]}")
          # Add biosample item with all doc IDs to larger Job doc
          jobDoc.addPropItem("Job.Related Biosamples", currentIDDoc)
        }
        @failedBiosampleMetadataFiles.each_value { |currentBiosampleMetadataFile|
          biosampleID = currentBiosampleMetadataFile.getRootPropVal()
          donorID = currentBiosampleMetadataFile.getPropVal("Biosample.Donor ID")
          currentIDDoc = BRL::Genboree::KB::KbDoc.new({})
          currentIDDoc.setPropVal("Related Biosample", biosampleID)
          currentIDDoc.setPropVal("Related Biosample.Related Donor", donorID)
          currentIDDoc.setPropVal("Related Biosample.Sample Status", "Failed")
          currentIDDoc.setPropVal("Related Biosample.File Name", biosampleIDToRawFileName[biosampleID])
          currentIDDoc.setPropVal("Related Biosample.File Location", "#{@backupFtpDir}data/#{biosampleIDToRawFileName[biosampleID]}")
          # Add biosample item with all doc IDs to larger Job doc
          jobDoc.addPropItem("Job.Related Biosamples", currentIDDoc)
        }
        # After inserting all doc IDs, convert to nested tabbed format and save file
        jobMetadataFileName = "#{@settings['primaryJobId']}.metadata.tsv"
        @jobMetadataFile = {jobMetadataFileName => jobDoc}
        @metadataFiles << @jobMetadataFile
        updatedJobDoc = @producer.produce(jobDoc).join("\n")
        File.open(jobMetadataFileName, 'w') { |file| file.write(updatedJobDoc) }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done adding information about metadata files to job metadata file")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in information for your job metadata document." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 40
      end
      return @exitCode
    end

    # Fills in preliminary info for analysis doc 
    # @param [String] analysisMetadataFileName name of analysis metadata file where information will be put
    # @param [Fixnum] successfulSamples the total number of successful pipeline runs
    # @return [Fixnum] exit code indicating whether filling in preliminary info for analysis doc succeeded (0) or failed (41)
    def fillInPrelimAnalysisInfo(successfulSamples)
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adding preliminary info into #{@analysisMetadataFile.keys[0]}.  Total number of successful samples: #{successfulSamples}")
        # Pull in analysis doc for editing
        analysisKbDoc = @analysisMetadataFile.values[0]
        # Fill out analysis doc with preliminary info (regardless of whether it was auto generated or supplied by user)
        analysisKbDoc.setPropVal("Analysis.Data Analysis Level", "")
        analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type", "Reference Alignment")
        analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment", "")
        analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Alignment Method", "exceRpt smallRNA-seq Pipeline Version #{@processingPipelineVersion}")
        analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Genome Version", @settings['genomeVersion'])
        analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Biosamples", successfulSamples)
        # Add info for atlas statistics
        analysisKbDoc.setPropVal("Analysis.Date of Analysis", @dateOfSubmission)
        analysisKbDoc.setPropVal("Analysis.Conditions Associated with Analysis", @conditions.size)
        @conditions.each { |currentCond|
          condDoc = BRL::Genboree::KB::KbDoc.new({})
          condDoc.setPropVal("Condition", currentCond)
          analysisKbDoc.addPropItem("Analysis.Conditions Associated with Analysis", condDoc)
        }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully added preliminary info into #{@analysisMetadataFile.keys[0]}")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in the preliminary info for your analysis document." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 41
      end       
      return @exitCode
    end

    # Fills in analysis doc with important information gathered from pipeline jobs
    # @param [Hash<String, Hash>] currentInput current input hash (name of file => attributes of that file)
    # @return [Fixnum] exit code indicating whether filling in info for analysis doc succeeded (0) or failed (42)
    def fillInAnalysisDoc(currentInput)
      begin
        # Grab important values to fill in docs below
        biosampleMetadataFileName = currentInput["biosampleMetadataFileName"]
        bioKbDoc = @biosampleMetadataFiles[biosampleMetadataFileName]
        currentBioName = bioKbDoc.getRootPropVal()
        statsFile = currentInput["statsFile"]
        sampleName = currentInput["sampleName"]
        resultsZip = currentInput["resultsZip"]
        coreZip = currentInput["coreZip"]
        exogenousRibosomalTaxoTree = currentInput["exoRibosomalTaxoTree"]
        exogenousGenomicResultsZip = currentInput["exoGenomicArchive"]
        exogenousGenomicTaxoTree = currentInput["exoGenomicTaxoTree"]
        #### FILLING IN ANALYSIS DOC WITH BIOSAMPLE INFO ####
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adding read information from #{biosampleMetadataFileName} into #{@analysisMetadataFile.keys[0]}")
        # Grab important information from our stats file to add to analysis document
        readInStatsFile = File.read(statsFile)
        # These fields should be in every .stats file (regardless of exogenous mapping setting)
        totalReads = readInStatsFile.match(/^input\s+(\d+)$/)[1]
        # Total reads after clipping will either be an integer or NA if no 3' adapter sequence is used - we'll rescue nil if it's NA, and we'll know not to save it in our doc if total reads after clipping is nil
        totalReadsAfterClipping = readInStatsFile.match(/^successfully_clipped\s+(\d+)$/)[1] rescue nil
        failedQualityFilter = readInStatsFile.match(/^failed_quality_filter\s+(\d+)$/)[1]
        failedHomopolymerFilter = readInStatsFile.match(/^failed_homopolymer_filter\s+(\d+)$/)[1]
        # Calibrator will either be an integer or NA if calibrator not used - we'll rescue nil if it's NA, and we'll know not to save it in our doc if calibrator is nil
        calibrator = readInStatsFile.match(/^calibrator\s+(\d+)$/)[1] rescue nil
        uniVecReads = readInStatsFile.match(/^UniVec_contaminants\s+(\d+)$/)[1]
        rRNAReads = readInStatsFile.match(/^rRNA\s+(\d+)$/)[1]
        readsUsedForAlignment = readInStatsFile.match(/^reads_used_for_alignment\s+(\d+)$/)[1]
        genomeReads = readInStatsFile.match(/^genome\s+(\d+)$/)[1]
        miRNAReadsSense = readInStatsFile.match(/^miRNA_sense\s+(\d+)$/)[1]
        miRNAReadsAntisense = readInStatsFile.match(/^miRNA_antisense\s+(\d+)$/)[1]
        miRNAPrecursorReadsSense = readInStatsFile.match(/^miRNAprecursor_sense\s+(\d+)$/)[1]
        miRNAPrecursorReadsAntisense = readInStatsFile.match(/^miRNAprecursor_antisense\s+(\d+)$/)[1]
        tRNAReadsSense = readInStatsFile.match(/^tRNA_sense\s+(\d+)$/)[1]
        tRNAReadsAntisense = readInStatsFile.match(/^tRNA_antisense\s+(\d+)$/)[1]
        piRNAReadsSense = readInStatsFile.match(/^piRNA_sense\s+(\d+)$/)[1]
        piRNAReadsAntisense = readInStatsFile.match(/^piRNA_antisense\s+(\d+)$/)[1]
        gencodeReadsSense = readInStatsFile.match(/^gencode_sense\s+(\d+)$/)[1]
        gencodeReadsAntisense = readInStatsFile.match(/^gencode_antisense\s+(\d+)$/)[1]
        circularRNASense = readInStatsFile.match(/^circularRNA_sense\s+(\d+)$/)[1]
        circularRNAAntisense = readInStatsFile.match(/^circularRNA_antisense\s+(\d+)$/)[1]
        readsNotMappedToGenomeOrLibs = readInStatsFile.match(/^not_mapped_to_genome_or_libs\s+(\d+)$/)[1]
        # If exogenous mapping is miRNA or on, we'll save these fields
        if(@settings['exogenousMapping'] =~ /miRNA/ or @settings['exogenousMapping'] =~ /on/)
          repetitiveElements = readInStatsFile.match(/^repetitiveElements\s+(\d+)$/)[1]
          endogenousGapped = readInStatsFile.match(/^endogenous_gapped\s+(\d+)$/)[1]
          inputToExogenous_miRNA = readInStatsFile.match(/^input_to_exogenous_miRNA\s+(\d+)$/)[1]
          exogenous_miRNA = readInStatsFile.match(/^exogenous_miRNA\s+(\d+)$/)[1]
          inputToExogenous_rRNA = readInStatsFile.match(/^input_to_exogenous_rRNA\s+(\d+)$/)[1]
          exogenous_rRNA = readInStatsFile.match(/^exogenous_rRNA\s+(\d+)$/)[1]
        end
        # If exogenous mapping is on, we'll save these fields
        if(@settings['exogenousMapping'] =~ /on/)
          inputToExogenousGenomes = readInStatsFile.match(/^input_to_exogenous_genomes\s+(\d+)$/)[1]
          exogenousGenomes = readInStatsFile.match(/^exogenous_genomes\s+(\d+)$/)[1]
        end
        # Create subdoc containing information about current biosample
        currentBioInfo = BRL::Genboree::KB::KbDoc.new({})
        currentBioInfo.setPropVal("Biosample ID", currentBioName)
        currentBioInfo.setPropVal("Biosample ID.DocURL", "coll/#{CGI.escape(@biosampleCollection)}/doc/#{currentBioName}")
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages", "")
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Input Reads", totalReads)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.After Clipping", totalReadsAfterClipping) if(totalReadsAfterClipping)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Failed Quality Filter", failedQualityFilter)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Failed Homopolymer Filter", failedHomopolymerFilter)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Calibrator", calibrator) if(calibrator)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.UniVec Contaminants", uniVecReads)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.rRNAs", rRNAReads)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Reads Used for Alignment", readsUsedForAlignment)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Reads Mapped to Reference Genome", genomeReads)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.miRNAs Sense", miRNAReadsSense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.miRNAs Antisense", miRNAReadsAntisense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.miRNAs Precursor Sense", miRNAPrecursorReadsSense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.miRNAs Precursor Antisense", miRNAPrecursorReadsAntisense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.tRNAs Sense", tRNAReadsSense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.tRNAs Antisense", tRNAReadsAntisense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.piRNAs Sense", piRNAReadsSense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.piRNAs Antisense", piRNAReadsAntisense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Gencode Annotations Sense", gencodeReadsSense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Gencode Annotations Antisense", gencodeReadsAntisense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Circular RNAs Sense", circularRNASense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Circular RNAs Antisense", circularRNAAntisense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Reads Not Mapped to Reference Genome or Endogenous Libraries", readsNotMappedToGenomeOrLibs)
        if(@settings['exogenousMapping'] =~ /miRNA/ or @settings['exogenousMapping'] =~ /on/)
          currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Repetitive Elements", repetitiveElements)
          currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Endogenous Gapped", endogenousGapped)
          currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Input to Exogenous miRNAs", inputToExogenous_miRNA)
          currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Exogenous miRNAs", exogenous_miRNA)
          currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Input to Exogenous rRNAs", inputToExogenous_rRNA)
          currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Exogenous rRNAs", exogenous_rRNA)
        end
        if(@settings['exogenousMapping'] =~ /on/)
          currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Input to Exogenous Genomes", inputToExogenousGenomes)
          currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Reads Mapped to Exogenous Genomes", exogenousGenomes)
        end
        # Decompress CORE .tgz (used to grab QC information as well as fill out Result Files doc below)
        exp = BRL::Genboree::Helpers::Expander.new(coreZip)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracting CORE .tgz #{coreZip}")
        exp.extract()
        dataDir = exp.tmpDir
        # Grab QC results file and fill out QC-related properties in currentBioInfo subdoc
        qcResults = File.read("#{dataDir}/#{sampleName}.qcResult")
        currentBioInfo.setPropVal("Biosample ID.QC Metrics", "")
        currentBioInfo.setPropVal("Biosample ID.QC Metrics.Result", qcResults.match(/^QC_result:\s+(\w+)$/)[1])
        currentBioInfo.setPropVal("Biosample ID.QC Metrics.Reference Genome Reads", qcResults.match(/^GenomeReads:\s+(\d+)$/)[1])
        currentBioInfo.setPropVal("Biosample ID.QC Metrics.Transcriptome Reads", qcResults.match(/^TranscriptomeReads:\s+(\d+)$/)[1])
        currentBioInfo.setPropVal("Biosample ID.QC Metrics.Transcriptome Genome Ratio", qcResults.match(/TranscriptomeGenomeRatio:\s+(\d+[,.]\d+|\d$)/)[1])
        # Grab analysis doc for editing
        analysisKbDoc = @analysisMetadataFile.values[0]
        # Add information collected above to doc as item
        analysisKbDoc.addPropItem("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Biosamples", currentBioInfo)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully added read information from #{biosampleMetadataFileName} into #{@analysisMetadataFile.keys[0]}")
        #### ADDING INFO FOR RESULTS FILES INTO RESULT FILES DOC ####
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Creating results files doc for #{biosampleMetadataFileName}")
        resultFilesDoc = BRL::Genboree::KB::KbDoc.new({})
        resultFilesID = grabAutoID("Result Files", @resultFilesCollection)
        raise @errUserMsg unless(@exitCode == 0)
        resultFilesID = resultFilesID.insert(4, @shortPiID)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Result files doc ID: #{resultFilesID}")
        resultFilesDoc.setPropVal("Result Files", resultFilesID)
        resultFilesDoc.setPropVal("Result Files.Status", "Add")
        resultFilesDoc.setPropVal("Result Files.Related Analysis", @analysisID)
        resultFilesDoc.setPropVal("Result Files.Related Analysis.DocURL", "coll/#{CGI.escape(@analysisCollection)}/doc/#{@analysisID}")
        resultFilesDoc.setPropVal("Result Files.Biosample ID", currentBioName)
        resultFilesDoc.setPropVal("Result Files.Biosample ID.DocURL", "coll/#{CGI.escape(@biosampleCollection)}/doc/#{currentBioName}")
        resultFilesDoc.setPropVal("Result Files.Biosample ID.Pipeline Result Files", 0)
        # resultFilePaths will be used to store paths for all files we find in CORE_RESULTS archive 
        resultFilePaths = []
        # Call recursive method to fill out result files for CORE_RESULTS
        currentURL = @outputAreaOnGenboree.clone
        currentURL << "/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@processingPipelineVersion}/#{CGI.escape(@analysisName)}/#{CGI.escape(sampleName)}/CORE_RESULTS"
        fillInResultFilesDoc(dataDir, currentURL, resultFilesDoc, resultFilePaths)
        raise @errUserMsg unless(@exitCode == 0)
        # Add info about result .zip to doc (if @uploadFullResults is true)
        if(@uploadFullResults)
          resultFilesDoc.setPropVal("Result Files.Biosample ID.Results Archive File Name", resultsZip)
          currentURL = @outputAreaOnGenboree.clone
          currentURL << "/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@processingPipelineVersion}/#{CGI.escape(@analysisName)}/#{CGI.escape(sampleName)}/#{CGI.escape(resultsZip)}"
          resultFilesDoc.setPropVal("Result Files.Biosample ID.Results Archive File Name.Genboree URL", currentURL)
          # Add info about exogenous genomic alignments results archive (.tgz) if fullExogenousMapping is on
          if(@settings['exogenousMapping'] =~ /on/)
            resultFilesDoc.setPropVal("Result Files.Biosample ID.Exogenous Genomic Results Archive File Name", exogenousGenomicResultsZip)
            currentURL = @outputAreaOnGenboree.clone
            currentURL << "/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@processingPipelineVersion}/#{CGI.escape(@analysisName)}/#{CGI.escape(sampleName)}/EXOGENOUS_GENOME_OUTPUT/#{CGI.escape(exogenousGenomicResultsZip)}"
            resultFilesDoc.setPropVal("Result Files.Biosample ID.Exogenous Genomic Results Archive File Name.Genboree URL", currentURL)
          end
        end
        # Add info about CORE_RESULTS .tgz to doc
        resultFilesDoc.setPropVal("Result Files.Biosample ID.Core Results Archive File Name", File.basename(coreZip))
        currentURL = @outputAreaOnGenboree.clone
        currentURL << "/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@processingPipelineVersion}/#{CGI.escape(@analysisName)}/#{CGI.escape(sampleName)}/CORE_RESULTS/#{CGI.escape(File.basename(coreZip))}"
        resultFilesDoc.setPropVal("Result Files.Biosample ID.Core Results Archive File Name.Genboree URL", currentURL)
        # Add info about exogenous ribosomal taxonomy tree
        if(@settings['exogenousMapping'] =~ /miRNA/ or @settings['exogenousMapping'] =~ /on/)
          resultFilesDoc.setPropVal("Result Files.Biosample ID.Exogenous rRNA Taxonomy Tree File Name", exogenousRibosomalTaxoTree)
          currentURL = @outputAreaOnGenboree.clone
          currentURL << "/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@processingPipelineVersion}/#{CGI.escape(@analysisName)}/#{CGI.escape(sampleName)}/CORE_RESULTS/#{CGI.escape(sampleName)}/EXOGENOUS_rRNA/#{CGI.escape(exogenousRibosomalTaxoTree)}"
          resultFilesDoc.setPropVal("Result Files.Biosample ID.Exogenous rRNA Taxonomy Tree File Name.Genboree URL", currentURL)
        end
        # Add info about exogenous genomic taxonomy tree
        if(@settings['exogenousMapping'] =~ /on/)
          resultFilesDoc.setPropVal("Result Files.Biosample ID.Exogenous Genomic Taxonomy Tree File Name", exogenousGenomicTaxoTree)
          currentURL = @outputAreaOnGenboree.clone
          currentURL << "/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@processingPipelineVersion}/#{CGI.escape(@analysisName)}/#{CGI.escape(sampleName)}/CORE_RESULTS/#{CGI.escape(sampleName)}/EXOGENOUS_genomes/#{CGI.escape(exogenousGenomicTaxoTree)}"
          resultFilesDoc.setPropVal("Result Files.Biosample ID.Exogenous Genomic Taxonomy Tree File Name.Genboree URL", currentURL)
        end
        # Save results files doc
        resultFilesID = resultFilesDoc.getRootPropVal()
        resultFilesMetadataFileName = "#{resultFilesID}.metadata.tsv"
        resultFilesMetadata = {resultFilesMetadataFileName => resultFilesDoc}
        @resultFilesMetadataFiles.merge!(resultFilesMetadata)
        @resultFilesIDs << resultFilesID
        #### ADDING INFO FOR READ COUNTS INTO READ COUNTS DOCS ####
        currentBiosampleReadCountsIDs = []
        if(@uploadReadCountsDocs)
          fillInReadCountDocs(resultFilePaths, currentBioName, @readCountsIDs, currentBiosampleReadCountsIDs)
          raise @errUserMsg unless(@exitCode == 0)
        end
        # Store association between biosample ID and related IDs (donor / result files / read counts)
        @biosampleToRelatedIDs[currentBioName] = [bioKbDoc.getPropVal("Biosample.Donor ID"), resultFilesID, currentBiosampleReadCountsIDs]
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully created results files doc for #{biosampleMetadataFileName}")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in info for #{sampleName} in your analysis document." if(@errUserMsg.nil? or @errUserMsg.empty?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 42
      end
      return @exitCode
    end

    # Fills out result files entries in a "Result Files" doc for the current sample
    # @param [String] currentPath path to current directory being examined for result files 
    # @param [String] currentURL Genboree path that will point to where result file is located 
    # @param [KbDoc] resultFilesDoc current "Result Files" doc
    # @param [Array] resultFilePaths list of result file paths gathered during recursive search
    # @return [Fixnum] exit code indicating whether filling in result files doc succeeded (0) or failed (57)
    def fillInResultFilesDoc(currentPath, currentURL, resultFilesDoc, resultFilePaths)
      begin
        resultFilePaths << currentPath
        # If current path is a directory, we'll traverse all files in that directory and submit those recursively to this method
        if(File.directory?(currentPath))
          allFiles = Dir.entries(currentPath)
          allFiles.delete(".")
          allFiles.delete("..")
          allFiles.each { |currentFile|
            newPath = "#{currentPath}/#{currentFile}"
            newCurrentURL = "#{currentURL}/#{CGI.escape(currentFile)}"
            fillInResultFilesDoc(newPath, newCurrentURL, resultFilesDoc, resultFilePaths)
          }
        # If current path is a file, we'll place an entry for it in the result files doc
        else
          currentPipelineFile = BRL::Genboree::KB::KbDoc.new({})
          fileID = grabAutoID("Result Files.Biosample ID.Pipeline Result Files.File ID", @resultFilesCollection)
          raise @errUserMsg unless(@exitCode == 0)
          currentPipelineFile.setPropVal("File ID", fileID)
          currentPipelineFile.setPropVal("File ID.File Name", File.basename(currentPath))
          currentPipelineFile.setPropVal("File ID.Genboree URL", currentURL)
          # Grab description for current result file - if no description present, don't fill in "Description" property
          description = nil
          key = ""
          key << "EXOGENOUS_genomes/" if(currentURL.split("/")[-2] == "EXOGENOUS_genomes")
          key << File.basename(currentPath)
          key = "_CORE_RESULTS_v*.tgz" if(currentURL.split("/")[-1].include?("CORE_RESULTS_"))
          key = ".stats" if(currentURL.split("/")[-1].include?(".stats"))
          key = ".qcResult" if(currentURL.split("/")[-1].include?(".qcResult"))
          key = ".log" if(currentURL.split("/")[-1].include?(".log"))
          description = @resultFileDescriptions[key]
          currentPipelineFile.setPropVal("File ID.Description", description) unless(description.nil?)
          # Add current entry to result files doc
          resultFilesDoc.addPropItem("Result Files.Biosample ID.Pipeline Result Files", currentPipelineFile)
        end
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in info for one of your result files documents." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 57
      end
      return @exitCode
    end

    # Method which fills in read count docs associated with a given sample
    # @param [Array] resultFilePaths list of files to consider as read count files
    # @param [Array] readCountsDocs array of different KbDocs that will each contain read count information
    # @param [String] currentBioName current biosample ID
    # @return [Fixnum] exit code indicating whether filling in result files doc succeeded (0) or failed (57)  
    def fillInReadCountDocs(resultFilePaths, currentBioName, readCountsIDs, currentBiosampleReadCountsIDs)
      begin
        # Traverse all result files
        resultFilePaths.each { |currentResultFile|
          # We want to grab part of the full path (currentResultFile) and compare it to the keys in the @readCountCategories hash.
          # If we find it in the hash, that'll tell us what our Library Type should be in our next Read Counts doc.
          currentKey = ""
          # If we're dealing with a file that's exogenous_miRNA (only present if exogenousMapping=miRNA or exogenousMapping=on), then we need to include that in our key.
          if(currentResultFile.split("/")[-2] == "EXOGENOUS_miRNA")
            currentKey = "#{currentResultFile.split("/")[-2]}/#{currentResultFile.split("/")[-1]}"
          else
            currentKey = currentResultFile.split("/")[-1]
          end
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current Result File: #{currentResultFile}")
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current Key: #{currentKey}")
          if(@readCountCategories.include?(currentKey))
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "@readCountCategories[currentKey]: #{@readCountCategories[currentKey]}")
            # Set up current read counts doc (one doc per library type, so basically one doc per .txt file)
            readCountsDoc = BRL::Genboree::KB::KbDoc.new({})
            readCountsID = grabAutoID("Read Counts", @readCountsCollection)
            raise @errUserMsg unless(@exitCode == 0)
            readCountsID = readCountsID.insert(4, @shortPiID)
            readCountsDoc.setPropVal("Read Counts", readCountsID)
            readCountsDoc.setPropVal("Read Counts.Status", "Add")
            readCountsDoc.setPropVal("Read Counts.Biosample ID", currentBioName)
            readCountsDoc.setPropVal("Read Counts.Biosample ID.DocURL", "coll/#{CGI.escape(@biosampleCollection)}/doc/#{currentBioName}")
            readCountsDoc.setPropVal("Read Counts.Library Type", @readCountCategories[currentKey])
            readCountsDoc.setPropVal("Read Counts.Reference Identifiers", 0)
            # Read in current reads doc
            currentReads = File.read(currentResultFile)
            # Traverse each line of current reads doc
            currentReads.each_line { |currentLine|
              # Each doc is tab-delimited, so we can split up each line by tab.
              currentLine = currentLine.split("\t")
              # We want to skip the header lines and any empty lines - they aren't indicated by a # or anything, so we use the header tokens currently used by Rob
              next if(currentLine.empty? or currentLine[0] == "ReferenceID" or currentLine[0] == "GeneSymbol")
              currentReferenceDoc = BRL::Genboree::KB::KbDoc.new({})
              currentReferenceDoc.setPropVal("Reference Name", currentLine[0])
              currentReferenceDoc.setPropVal("Reference Name.Unique Read Count", currentLine[1])
              currentReferenceDoc.setPropVal("Reference Name.Total Read Count", currentLine[2])
              currentReferenceDoc.setPropVal("Reference Name.Multi Mappers Adjusted Read Count", currentLine[3])
              currentReferenceDoc.setPropVal("Reference Name.Multi Mappers Adjusted Barcode Count", currentLine[4]) unless(currentLine[4].to_f == 0.0)
              readCountsDoc.addPropItem("Read Counts.Reference Identifiers", currentReferenceDoc)
            }
            # Create hash for uploading current read counts doc to DB / KB
            readCountsID = readCountsDoc.getRootPropVal()
            readCountsMetadataFileName = "#{readCountsID}.metadata.tsv"
            readCountsMetadata = {readCountsMetadataFileName => readCountsDoc}
            # Save the current readCountsID in relevant arrays
            readCountsIDs << readCountsID
            currentBiosampleReadCountsIDs << readCountsID
            # Upload read counts metadata to DB and KB here (don't want to store ALL the read counts docs at the same time in this wrapper - gets really large!)
            uploadMetadataDocs(readCountsMetadata)
          end
        }
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in info for one of your read count documents." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 58
      end
      return @exitCode  
    end

    # Fills in analysis doc with post-processing file names
    # @return [Fixnum] exit code indicating whether filling in post-processing info for analysis doc succeeded (0) or failed (46)
    def fillInPostProcessingInfo()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adding post-processing information into #{@analysisMetadataFile.keys[0]}")
        # Grab analysis doc for editing
        analysisKbDoc = @analysisMetadataFile.values[0]
        # Add each post-processing file to analysis doc
        analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Post-processing Result Files", "")
        postProcFiles = Dir.entries(@postProcOutputDir)
        postProcFiles.delete(".")
        postProcFiles.delete("..")
        postProcFiles.each { |currentFile|
          currentPostProcFile = BRL::Genboree::KB::KbDoc.new({})
          fileID = grabAutoID("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Post-processing Result Files.File ID", @analysisCollection)
          raise @errUserMsg unless(@exitCode == 0)
          currentPostProcFile.setPropVal("File ID", fileID)
          currentPostProcFile.setPropVal("File ID.File Name", currentFile)
          currentURL = @outputAreaOnGenboree.clone
          currentURL << "/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@processingPipelineVersion}/#{CGI.escape(@analysisName)}/postProcessedResults_v#{@toolVersionPPR}/#{CGI.escape(currentFile)}"
          currentPostProcFile.setPropVal("File ID.Genboree URL", currentURL)
          analysisKbDoc.addPropItem("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Post-processing Result Files", currentPostProcFile)
          # There are certain files that we want to save in special properties in the Analysis collection.
          # Note that some files below will not exist for exogenousMapping=off or exogenousMapping=miRNA (exogenous genome files, for example)
          if(currentFile.include?("DiagnosticPlots.pdf"))
            analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Diagnostic Plots File Name", currentFile)
            analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Diagnostic Plots File Name.Genboree URL", currentURL)
          elsif(currentFile.include?("exceRpt_miRNA_ReadCounts.txt"))
            analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Raw miRNA Read Counts File Name", currentFile)
            analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Raw miRNA Read Counts File Name.Genboree URL", currentURL)
          elsif(currentFile.include?("exogenousGenomes_taxonomyCumulative_ReadCounts.txt"))
            analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Exogenous Genomic Taxonomy Cumulative Read Counts File Name", currentFile)
            analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Exogenous Genomic Taxonomy Cumulative Read Counts File Name.Genboree URL", currentURL)
          elsif(currentFile.include?("exogenousRibosomal_taxonomyCumulative_ReadCounts.txt"))
            analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Exogenous Ribosomal Taxonomy Cumulative Read Counts File Name", currentFile)
            analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Exogenous Ribosomal Taxonomy Cumulative Read Counts File Name.Genboree URL", currentURL)
          end
        }
        pprArchive = "#{CGI.escape(@analysisName)}_exceRpt_postProcessedResults_v#{@toolVersionPPR}.tgz"
        currentURL = @outputAreaOnGenboree.clone
        currentURL << "/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@processingPipelineVersion}/#{CGI.escape(@analysisName)}/postProcessedResults_v#{@toolVersionPPR}/#{CGI.escape(pprArchive)}"  
        analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Post-processing Results Archive File Name", pprArchive)
        analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Post-processing Results Archive File Name.Genboree URL", currentURL)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully added post-processing information into #{@analysisMetadataFile.keys[0]}")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in post-processing info in your analysis document." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 46
      end
      return @exitCode
    end

    # This method will upload docs to user's Genboree database and the appropriate metadata collection
    # @param [Hash<String, Hash>] docs the docs to be uploaded
    # @return [Fixnum] exit code indicating whether metadata upload to db succeeded (0) or failed (52)
    def uploadMetadataDocs(docs)
      begin
        user = pass = host = nil
        if(@dbrcKey)
          dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
          # get super user, pass and hostname
          user = dbrc.user
          pass = dbrc.password
          host = dbrc.driver.split(/:/).last
        else
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @dbrcFile)
          user = suDbDbrc.user
          pass = suDbDbrc.password
          host = suDbDbrc.driver.split(/:/).last
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Now uploading #{docs.keys.inspect} to user's Genboree database")
        # Set up URI
        targetUri = URI.parse(@outputAreaOnGenboree)
        rsrcPath = "#{targetUri.path}/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@processingPipelineVersion}/{analysisName}/metadataFiles/{outputFile}/data?"
        rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
        # Create inputFiles array - it will store the paths on Genboree which we will use for our kbBulkUpload job
        inputFiles = []
        # Write each metadata file to disk and then upload it to user's Genboree database
        docs.each_key { |currentDocName|
          File.open(currentDocName, 'w') { |file| file.write(@producer.produce(docs[currentDocName]).join("\n")) }
          `cp #{currentDocName} #{@finalizedMetadataDir}/#{currentDocName}`
          uploadFile(targetUri.host, rsrcPath, @subUserId, currentDocName, {:analysisName => @analysisName, :outputFile => File.basename(currentDocName)})
          # Add current input path to inputFiles array
          inputPath = "http://#{targetUri.host}"
          inputPath << rsrcPath.gsub("{analysisName}", CGI.escape(@analysisName))
          inputPath.gsub!("{outputFile}", File.basename(currentDocName))
          inputPath.chomp!("/data?")
          inputPath << "?"
          inputFiles << inputPath
        }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done uploading #{docs.keys.inspect} to user's Genboree database")
        # Grab collection associated with current docs
        currentRootProp = docs.values[0].getRootProp()
        coll = @collections[currentRootProp]
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Now submitting a kbBulkUpload job to upload #{docs.keys.inspect} to #{coll}")
        # Set up output path for destination group / KB / collection
        apiCaller = WrapperApiCaller.new(@exRNAHost, rsrcPath, @subUserId)
        groupName = @exRNAKbGroup
        kbName = @exRNAKb
        collName = coll
        outputPath = "http://#{CGI.escape(@exRNAHost)}/REST/v1/grp/#{CGI.escape(groupName)}/kb/#{CGI.escape(kbName)}/coll/#{CGI.escape(collName)}?"
        # Create kbBulkUpload job conf
        kbBulkUploadJobConf = @jobConf.deep_clone()
        kbBulkUploadJobConf['context']['toolIdStr'] = "kbBulkUpload"
        kbBulkUploadJobConf['settings'] = {}
        kbBulkUploadJobConf['settings']['format'] = "tabbed prop nesting"
        kbBulkUploadJobConf['settings']['suppressSuccessEmails'] = true
        kbBulkUploadJobConf['inputs'] = inputFiles
        kbBulkUploadJobConf['outputs'] = [outputPath]
        # Write kbBulkUpload jobConf hash to tool specific jobFile.json
        # @kbBulkUpload is used to create a new jobConf for each kbBulkUpload job
        kbBulkUploadJobFile = "#{@kbBulkUploadJobConfDir}/#{@kbBulkUploadIndex}_kbBulkUploadJobFile.json"
        File.open(kbBulkUploadJobFile,"w") do |kbBulkUploadJob|
          kbBulkUploadJob.write(JSON.pretty_generate(kbBulkUploadJobConf))
        end
        @kbBulkUploadIndex += 1
        # Submit kbBulkUpload job for current docs
        apiCaller = BRL::Genboree::REST::ApiCaller.new(@exRNAHost, "/REST/v1/genboree/tool/kbBulkUpload/job", user, pass)
        apiCaller.put({}, kbBulkUploadJobConf.to_json)
        # Raise error if job cannot be submitted
        unless(apiCaller.succeeded?)
          $stderr.debugPuts(__FILE__, __method__, "KB BULK UPLOAD JOB SUBMISSION FAILURE", apiCaller.respBody.inspect)
          @errUserMsg = "We could not submit your kbBulkUpload job to upload your docs for the #{collName} collection."
          raise @errUserMsg
        else
          $stderr.debugPuts(__FILE__, __method__, "KB BULK UPLOAD JOB SUBMISSION SUCCESS", apiCaller.respBody.inspect)
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully uploaded #{docs.keys.inspect} to #{collName}")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue uploading docs to either\n1) the requested Group / Database or 2) the collection #{coll}." if(@errUserMsg.nil? or @errUserMsg.empty?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 52
      end 
      return @exitCode
    end

    # Upload a given file to Genboree server
    # @param host [String] host that user wants to upload to
    # @param rsrcPath [String] resource path that user wants to upload to
    # @param userId [Fixnum] genboree user id of the user
    # @param inputFile [String] full path of the file on the client machine where data is to be pulled
    # @param templateHash [Hash<Symbol, String>] hash that contains (potential) arguments to fill in URI for API put command
    # @return [nil]
    def uploadFile(host, rsrcPath, userId, input, templateHash)
      # Call FileApiUriHelper's uploadFile method to upload current file
      retVal = @fileApiHelper.uploadFile(host, rsrcPath, userId, input, templateHash)
      # Set error messages if upload fails using @fileApiHelper's uploadFailureStr variable
      unless(retVal)
        @errUserMsg = @fileApiHelper.uploadFailureStr
        @errInternalMsg = @fileApiHelper.uploadFailureStr
        @exitCode = 38
        @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
        raise @err
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "#{input} uploaded successfully to server")
      end
      return
    end

    # Method which grabs an autoID associated with a particular property (within a given collection)
    # @param [String] property path of property that we're checking
    # @param [String] coll name of collection that contains property
    # @return [String] newly generated ID associated with property
    def grabAutoID(property, coll)
      currentID = ""
      begin
        # Auto-generate new ID for doc
        rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/model/prop/{prop}/autoID"
        apiCaller = WrapperApiCaller.new(@exRNAHost, rsrcPath, @subUserId)
        apiCaller.put({:prop => property, :coll => coll, :kb => @exRNAKb, :grp => @exRNAKbGroup})
        # If grabbing the auto ID fails, then we raise an error
        unless(apiCaller.succeeded?)
          @errUserMsg = "ApiCaller failed: call to grab autoID for property #{property} in collection #{coll} failed."
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "ApiCaller failed to grab autoID for property #{property} in collection #{coll}: #{apiCaller.respBody.inspect}")
          raise @errUserMsg
        end
        # Return newly generated ID
        currentID = apiCaller.parseRespBody["data"]["text"]
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There was an issue with grabbing an autoID for #{property} in #{coll}." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 56
      end
      return currentID
    end

    # Method for moving files on FTP server.  fileAlreadyOnFTP will keep track of whether the file is already present on the FTP server.
    # If the file is not already present on the FTP server, we will use @ftpHelper.uploadToFtp to upload the file to the FTP server. 
    # If the file is already present on the FTP server, we will use @ftpHelper.renameOnFtp to simply move the file on the FTP server.
    # @param [String] input the input path of the file that we are uploading / moving
    # @param [String] output the output path of the file that we are uploading / moving
    # @param [boolean] fileAlreadyOnFTP a boolean that keeps track of whether the current transfer is for a file that is already on the FTP server or not
    # @return [nil]
    def transferFtpFile(input, output, fileAlreadyOnFTP)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Moving input file #{input} to appropriate directory #{output} on FTP server")
      # Method used to upload files to FTP (they're not yet present on FTP!)
      unless(fileAlreadyOnFTP)
        retVal = @ftpHelper.uploadToFtp(input, output) rescue nil
        unless(retVal)
          @errUserMsg = "Failed to upload file #{input} to #{output} on FTP server"
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Failed to upload file #{input} to #{output} on FTP server")
          raise @errUserMsg
        end
      # Method used to move files on FTP (they're already present on FTP!)
      else
        # Update timestamp on input before moving it
        touchConfirmation = @ftpHelper.touch(input)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Touch confirmation message for #{input}: #{touchConfirmation}")
        retVal = @ftpHelper.renameOnFtp(input, output) rescue nil
        unless(retVal)
          @errUserMsg = "Failed to move input file #{input} to #{output} on FTP server"
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Failed to move input file #{input} to #{output} on FTP server")
          raise @errUserMsg
        end
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input file #{input} can now be found in directory #{output} on FTP server")
      return  
    end

    # Submits a document to exRNA Internal KB in order to keep track of ERCC tool usage
    # @return [nil]
    def submitToolUsageDoc(user, pass)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Currently uploading tool usage doc")
      # Create KB doc for tool usage and fill it out
      toolUsage = BRL::Genboree::KB::KbDoc.new({})
      toolUsage.setPropVal("ERCC Tool Usage", @settings['primaryJobId'])
      toolUsage.setPropVal("ERCC Tool Usage.Status", "Add")
      toolUsage.setPropVal("ERCC Tool Usage.Job Date", "")
      toolUsage.setPropVal("ERCC Tool Usage.Submitter Login", @userLogin)
      toolUsage.setPropVal("ERCC Tool Usage.PI Name", @piName)
      toolUsage.setPropVal("ERCC Tool Usage.Grant Number", @grantNumber)
      toolUsage.setPropVal("ERCC Tool Usage.RFA Title", @rfaTitle)
      toolUsage.setPropVal("ERCC Tool Usage.Organization of PI", @piOrganization)
      toolUsage.setPropVal("ERCC Tool Usage.Co PI Names", @coPINames) unless(@coPINames.empty?)
      toolUsage.setPropVal("ERCC Tool Usage.Genboree Group Name", @groupName)
      toolUsage.setPropVal("ERCC Tool Usage.Genboree Database Name", @dbName)
      toolUsage.setPropVal("ERCC Tool Usage.Samples Processed Through ERCC Pipeline", 0)
      @sampleStatus.each_key { |currentSample|
        currentInputItem = BRL::Genboree::KB::KbDoc.new({})
        currentInputItem.setPropVal("Sample Name", currentSample)
        currentInputItem.setPropVal("Sample Name.Sample Status", @sampleStatus[currentSample])
        toolUsage.addPropItem("ERCC Tool Usage.Samples Processed Through ERCC Pipeline", currentInputItem)
      }
      toolUsage.setPropVal("ERCC Tool Usage.Number of Successful Samples", @successfulSamples)
      toolUsage.setPropVal("ERCC Tool Usage.Number of Failed Samples", @failedSamples)
      toolUsage.setPropVal("ERCC Tool Usage.Platform", @platform)
      toolUsage.setPropVal("ERCC Tool Usage.Processing Pipeline", @processingPipeline)
      toolUsage.setPropVal("ERCC Tool Usage.Processing Pipeline.Version", @processingPipelineVersion)
      toolUsage.setPropVal("ERCC Tool Usage.Anticipated Data Repository", @anticipatedDataRepo) if(@anticipatedDataRepo)
      toolUsage.setPropVal("ERCC Tool Usage.Anticipated Data Repository.Other Data Repository", @otherDataRepo) if(@anticipatedDataRepo and @otherDataRepo)
      toolUsage.setPropVal("ERCC Tool Usage.Anticipated Data Repository.Submission Category", @dataRepoSubmissionCategory) if(@anticipatedDataRepo and @dataRepoSubmissionCategory)
      toolUsage.setPropVal("ERCC Tool Usage.Anticipated Data Repository.Project Registered by PI with dbGaP?", @dbGaP) if(@anticipatedDataRepo and @dbGaP)
      # Upload doc 
      apiCaller = ApiCaller.new(@exRNAInternalKBHost, "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/docs?", user, pass)
      payload = {"data" => toolUsage}
      apiCaller.put({:grp => @exRNAInternalKBGroup, :kb => @exRNAInternalKBName, :coll => @erccToolUsageColl}, payload.to_json)
      # If doc upload fails, raise error
      unless(apiCaller.parseRespBody["data"]["docs"]["properties"]["invalid"]["items"].empty?)
        @errUserMsg = "ApiCaller failed: call to upload tool usage doc failed."
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "ApiCaller failed to upload tool usage doc: #{apiCaller.respBody.inspect}")
        raise @errUserMsg
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully uploaded tool usage doc")
      end
      return
    end

############ END of methods specific to this RSEQtools wrapper

    def prepSuccessEmail()
      # Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
      # Email object
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @userFirstName
      emailObject.userLast      = @userLastName
      emailObject.analysisName  = @analysisName
      emailObject.inputsText    = nil
      emailObject.outputsText   = nil
      emailObject.settings      = @jobConf['settings']
      emailObject.exitStatusCode = @exitCode
      gbDccAdminEmails = ""
      if(@genbConf.gbDccAdminEmails.class == Array)
        gbDccAdminEmails = @genbConf.gbDccAdminEmails.join(", ")
      else
        gbDccAdminEmails = @genbConf.gbDccAdminEmails
      end
      additionalInfo = ""
      additionalInfo << "All the samples from the #{@processingPipeline} batch submission have been processed and the results were uploaded to your Genboree Database.\n" +
                        "You can download result files from this location:\n" + 
                          "|-Group: '#{@groupName}'\n" +
                            "|--Database: '#{@dbName}'\n" +
                              "|---Files\n"
      if(@isFTPJob)
        additionalInfo << "|----#{@remoteStorageArea}\n" + 
                            "|-----#{@processingPipelineIdAndVersion}\n" +
                              "|------#{@analysisName}\n\n"
      else 
        additionalInfo << "|----#{@processingPipelineIdAndVersion}\n" +
                            "|-----#{@analysisName}\n\n"
      end
      additionalInfo << "==================================================================\n"
      additionalInfo << "The status of your #{@processingPipeline} jobs is summarized below:\n"                    
      # Traverse all jobIds and print info about each of them
      @jobs.each_key { |jobId|
        additionalInfo << "Job ID: #{jobId} - #{@jobs[jobId]}\n"
      }
      additionalInfo << "==================================================================\n"
      additionalInfo << "\nIf there are any jobs with \'failed\' status in the list above,\nplease look at the email from the job to identify the cause of failure.\n\n"
      if(@isFTPJob)
        additionalInfo << "======================ACCESSING RESULTS ON ATLAS=================\n" +
                        "NOTE 1:\nYou can view your results on the private, ERCC-only Atlas at the following location:\n#{@settings['exRNAAtlasURL']}\nPlease give us some time to expose your data on the Atlas.\n" +
                        "NOTE 2:\nIf you would like to deposit your results in the public Atlas (available to all users),\ncontact a DCC admin (#{gbDccAdminEmails})\n" +
                        "======================ACCESSING RESULTS USING FTP CLIENT=========\n" +
                        "NOTE 1:\nIn order to access your results via FTP client,\nyou will need to contact a DCC admin (#{gbDccAdminEmails})\n" +
                        "======================NOTES ON RESULT FILES======================\n" +
                        "NOTE 1:\nEach sample you submitted will have its own unique subfolder\nwhere you can find the exceRpt pipeline results for that sample.\n" +
                        "NOTE 2:\nIf you chose to upload full results,\nthe file that ends in '_results_v#{@processingPipelineVersion}' is a large archive\nthat contains all the result files from the exceRpt pipeline.\n" +
                        "NOTE 3:\nThe file that ends in '_CORE_RESULTS_v#{@processingPipelineVersion}' is a much smaller archive\nthat contains the key result files from the exceRpt pipeline.\nThis file can be found in the 'CORE_RESULTS' subfolder\nand has been decompressed in that subfolder for your convenience.\n" +
                        "NOTE 4:\nFinally, any exogenous genome output for a given sample\ncan be found in its EXOGENOUS_GENOME_OUTPUT subfolder.\nThe taxonomy tree taxaAnnotated.txt file will also be\nin your CORE_RESULTS archive.\n" +
                        "NOTE 4:\nTo learn more about your output, visit the Data Analysis page here:\nhttp://genboree.org/theCommons/projects/exrna-tools-may2014/wiki/ExRNA_Data_Analysis\n" +
                        "======================NOTES ON POST-PROCESSED RESULTS============\n" +
                        "NOTE 1:\nPost-processed results (created by\nthe exceRpt small RNA-seq Post-processing tool)\ncan be found in the 'postProcessedResults_v#{@toolVersionPPR}' subfolder.\n" +
                        "NOTE 2:\nTo learn more about your output, visit the exRNA Wiki Tutorial here:\nhttp://genboree.org/theCommons/projects/exrna-tools-may2014/wiki/Small%20RNA-seq%20Pipeline#Post-processing-of-Samples\n" +
                        "======================NOTES ON ORIGINAL SUBMISSION===============\n" +
                        "NOTE 1:\nYour original submission (manifest file / metadata archive / data archive)\ncan be found on the FTP server in the following directory: #{@finishedFtpDir}\nYou cannot access these files via the Workbench.\n" +
                        "======================NOTES ON METADATA FILES====================\n" +
                        "NOTE 1:\nYou can find the IDs of your metadata documents in your Job document\non the exRNA GenboreeKB UI. Your Job document has the following ID:\n    #{@settings['primaryJobId']}" + 
                               "\nTo view your Job document on the exRNA GenboreeKB UI, use the following link:\nhttp://#{@exRNAHost}/#{@genboreeKbArea}/genboree_kbs?project_id=#{@exRNAKbProject}&coll=#{@jobCollection}&doc=#{@settings['primaryJobId']}&docVersion=\nIt will take a moment for your documents to be uploaded.\n" +
                        "NOTE 2:\nYou must be a member of the \"Extracellular RNA Atlas - Consortium v2\" project\non GenboreeKB in order to view your Job document." +
                               "\nPlease contact a DCC admin (#{gbDccAdminEmails})\nif you are having difficulty viewing your Job document.\n" +
                        "NOTE 3:\nIf you need help navigating the exRNA GenboreeKB UI,\nview the following Wiki page for guidance:\nhttp://genboree.org/theCommons/projects/exrna-mads/wiki/GenboreeKB%20exRNA%20Metadata%20Tracking%20System%20-%20Navigating%20the%20Metadata%20UI\n"
      end
      emailObject.additionalInfo = additionalInfo
      # Remove settings that are unnecessary for user e-mail
      cleanUpSettingsForEmail()
      return emailObject
    end

    def prepErrorEmail()
      # Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
      # Email object
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @userFirstName
      emailObject.userLast      = @userLastName
      emailObject.analysisName  = @analysisName
      emailObject.inputsText    = nil
      emailObject.outputsText   = nil
      emailObject.settings      = @jobConf['settings']
      emailObject.errMessage    = @errUserMsg
      emailObject.exitStatusCode = @exitCode
      emailObject.erccTool = true
      # Remove settings that are unnecessary for user e-mail
      cleanUpSettingsForEmail()
      return emailObject
    end

    # When we send our success or failure email, there are certain settings that we don't want to send the user (because they're not helpful, redundant, etc.).
    # @return [nil]  
    def cleanUpSettingsForEmail()
      @settings.delete("indexBaseName") unless(@settings['useLibrary'] =~ /uploadNewLibrary/)
      unless(@settings['useLibrary'] =~ /uploadNewLibrary/)
        @settings.delete('newSpikeInLibrary') 
      else
        @settings['newSpikeInLibrary'].gsub!("gbmainprod1.brl.bcmd.bcm.edu", "genboree.org")
      end
      @settings.delete("existingLibraryName") unless(@settings['useLibrary'] =~ /useExistingLibrary/)
      @settings.delete("jobSpecificSharedScratch")
      @settings.delete("autoDetectAdapter") unless(@settings['adapterSequence'] == "other")
      @settings.delete("manualAdapter") unless(@settings['adapterSequence'] == "other" and @settings['autoDetectAdapter'] == "no")
      @settings.delete("otherDataRepo") unless(@settings['anticipatedDataRepo'] == "Other")
      @settings.delete("piID")
      @settings.delete("platform")
      @settings.delete("processingPipeline")
      @settings.delete("processingPipelineIdAndVersion")
      @settings.delete("processingPipelineVersion")
      @settings.delete("wbContext")
      @settings.delete("subdirs")
      unless(@settings["randomBarcodesEnabled"])
        @settings.delete("randomBarcodeLength")
        @settings.delete("randomBarcodeLocation")
        @settings.delete("randomBarcodeStats")
      end
      @settings.delete("subjobDir")
      @settings.delete("priorityList")
      if(@settings['endogenousLibraryOrder'])
        @settings['endogenousLibraryOrder'].gsub!("gencode", "Gencode")
        @settings['endogenousLibraryOrder'].gsub!(",", " > ")
      end
      @settings.delete("adSeqParameter")
      @settings.delete("adapterSequence")
      @settings.delete("anticipatedDataRepo")
      @settings.delete("bowtieSeedLength")
      @settings.delete("calib")
      @settings.delete("exRNAHost")
      @settings.delete("exRNAKb")
      @settings.delete("exRNAKbGroup")
      @settings.delete("exRNAKbProject")
      @settings.delete("failedFtpDir")
      @settings.delete("finalizedMetadataDir")
      @settings.delete("finishedFtpDir")
      @settings.delete("dataArchiveLocation")
      @settings.delete("genboreeKbArea")
      @settings.delete("manifestLocation")
      @settings.delete("metadataArchiveLocation")
      @settings.delete("outputHost")
      @settings.delete("anticipatedDataRepo")
      @settings.delete("dataRepoSubmissionCategory")
      @settings.delete("dbGaP")
      @settings.delete("grantNumber")
      @settings.delete("piName")
      @settings.delete("javaRam")
      @settings.delete("localExecution")
      @settings.delete("numThreads")
      @settings.delete("postProcOutputDir")
      @settings.delete("useLibrary")
      @settings.delete("endogenousLibraryOrder")
      @settings.delete("endogenousMismatch")
      @settings.delete("exogenousMapping")
      @settings.delete("exogenousMismatch")
      @settings.delete("genomeBuild")
      @settings.delete("manifestFile")
      @settings.delete("postProcDir")
      @settings.delete("uploadRawFiles")
      @settings.delete("remoteStorageArea") if(@settings["remoteStorageArea"] == nil)
      # Delete local path to post-processing input dir
      @settings.delete('postProcDir')
      # Delete local path to list of job IDs text file
      @settings.delete('importantJobIdsDir')
      @settings.delete('filePathToListOfExogenousTaxoTreeJobIds')
      @settings.delete('exogenousMappingInputDir')
      # Delete information about number of threads / tasks for exogenous mapping (used in exogenousSTARMapping wrapper)
      @settings.delete('numThreadsExo')
      @settings.delete('numTasksExo')
      @settings.delete("subUserId")
      @settings.delete('numberField_fractionForMinBaseCallQuality')
      @settings.delete('numberField_minReadLength')
      @settings.delete('numberField_readRemainingAfterSoftClipping')
      @settings.delete('numberField_trimBases5p')
      @settings.delete('numberField_trimBases3p')
      @settings.delete('numberField_minAdapterBases3p')
      @settings.delete('numberField_downsampleRNAReads')
      @settings.delete('numberField_bowtieSeedLength')
      @settings.delete('minBaseCallQuality') if(@settings['exceRptGen'] == 'thirdGen') # We can delete minimum base-call quality if user submitted 3rd gen exceRpt job
      @settings.delete('totalOutputFileSize')
      @settings.delete('exRNAAtlasURL')
      @settings.delete('listOfExogenousTaxoTreeJobIds')
      @settings.delete('exogenousTaxoTreeJobIDDir')
      @settings.delete('exogenousRerunDir')
      @settings.delete('filePathToListOfExogenousJobIds')
      @settings.delete('exogenousClaves')
      @settings.delete('backupFtpDir')
      @settings.delete('databaseGenomeVersion')
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::ErccFinalProcessingWrapper)
end
