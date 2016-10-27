#!/usr/bin/env ruby
#########################################################
############ FTP smRNAPipeline pipeline wrapper #################
## This wrapper runs the small RNA-Seq data analysis pipeline,
# data is downloaded from the FTP site and results are copied
# to both FTP finished area as well as to the Genboree Workbench
## This wrapper runs the small RNA-Seq data analysis pipeline #
## Modules used in this pipeline:
## 1. smallRNAPipeline
#########################################################

require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/util/emailer'
require 'brl/genboree/tools/FTPtoolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/helpers/sniffer'
require 'brl/genboree/abstract/resources/user'
require 'parallel'
require 'brl/genboree/kb/kbDoc'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class FTPSmRNAPipelineWrapper < BRL::Genboree::Tools::FTPToolWrapper
    VERSION = "2.2.8"
    COMMAND_LINE_ARGS = {}
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running 'FTPsmRNAPipeline'.
                        This tool is intended to be called when jobs are submitted by the FTP Pipeline",
      :authors      => [ "Sai Lakshmi Subramanian (sailakss@bcm.edu) and William Thistlethwaite (thistlew@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    # ------------------------------------------------------------------
    # INTERFACE METHODS
    # ------------------------------------------------------------------
    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # [+returns+] nil
    def processJobConf()
      begin
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        ## Getting relevant variables from "context"
        @dbrcKey = @context['apiDbrcKey']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        # Information about submitter (user)
        # Initially set to be first name / last name / email of FTP job submitter (William, most likely) in case we can't retrieve this info and need to e-mail SOMEONE
        @subUserFirstName = @userFirstName
        @subUserLastName = @userLastName
        @subUserEmail = @userEmail
        # Job file sent by poller will not have an analysis name. Set it here.
        @analysisName = "FTPsmallRNA-seqPipeline-#{Time.now.strftime('%Y-%m-%d-%H:%M:%S').gsub('-0', '-')}"
        # Grab dbrc info
        # Grab dbrc info
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        # Set scratch directory variable
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        # Create directory for metadata processing and uploading
        @metadataDir = "#{@scratchDir}/metadata"
        `mkdir -p #{@metadataDir}`
        # Create directory for user defined custom calibrator/spike-in libraries
        # Manifest file will contain info about spike-in use (whether we're using library or not, whether library is local or on Genboree)
        @calibratorDir = "#{@scratchDir}/calibrator"
        `mkdir -p #{@calibratorDir}`
        # Create directory used for post-processing of successful runs (using the processPipelineRuns tool)
        @postProcDir = "#{@scratchDir}/subJobsScratch/processPipelineRuns"
        @runsDir = "#{@postProcDir}/runs"
        `mkdir -p #{@runsDir}`
        # Create directory used for holding post-processing results created by processPipelineRuns tool
        @postProcOutputDir = "#{@postProcDir}/outputFiles"
        # Create directory used for running kbBulkUpload jobs on local metadata .tsv files - not currently used
        @kbBulkUploadScratchDir = "#{@scratchDir}/subJobsScratch/kbBulkUpload"
        `mkdir -p #{@kbBulkUploadScratchDir}`
        # Point to the smallRNA pipeline "makefile" location 
        # NOTE: To run the pipeline, you have to run the make command on this makefile
        @smRNAMakefile = ENV['SMALLRNA_MAKEFILE']
        # Assign appropriate input locations to variables
        @inputs.each { |inputLocation|
          if(inputLocation =~ /(.+?)\.(?i)manifest(?-i)\.json$/)
            @manifestLocation = inputLocation
          elsif(inputLocation =~ /(.+?)_(?i)metadata(?-i)(?:\.tar\.gz|\.zip)$/)
            @metadataArchiveLocation = inputLocation
          else
            @dataArchiveLocation = inputLocation
          end
        }
        # Assign appropriate output locations to variables
        @outputs.each { |outputLocation|
          if(outputLocation =~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
            @outputDb = outputLocation
            @outputDb.gsub!(/\{HOST\}/, @settings['outputHost'])
          elsif(outputLocation =~ /\/finished\//)
            @finishedFtpDir = outputLocation
          elsif(outputLocation =~ /\/failed\//)
            @failedFtpDir = outputLocation
          end
        }
        # Save path to user's inbox (so we can easily put files back in it in case of job failure)
        @inboxFtpDir = @failedFtpDir.slice(0...@failedFtpDir.index("failed")) << "inbox/"
        # Grab PI ID to use later in metadata document names
        @piID = @inboxFtpDir.scan(/exrna-[A-Za-z0-9]+/)[0][6..-1].upcase
        # Grab exRNA-specific host / group / KB associated with submitted job (for metadata submission)
        @exRNAHost = @settings['exRNAHost']
        @exRNAKbGroup = @settings['exRNAKbGroup']
        @exRNAKb = @settings['exRNAKb']
        @exRNAKbProject = @settings['exRNAKbProject']
        @genboreeKbArea = @settings['genboreeKbArea']
        # Grab collection names from config file and set up a variable for each collection name
        @collections = JSON.parse(File.read(@genbConf.FTPsmRNAPipelineKBCollections))
        @analysisCollection = @collections["Analysis"]
        @biosampleCollection = @collections["Biosample"]
        @donorCollection = @collections["Donor"]
        @experimentCollection = @collections["Experiment"]
        @jobCollection = @collections["Job"]
        @piCollection = @collections["ERCC PI"]
        @resultFilesCollection = @collections["Result Files"]
        @runCollection = @collections["Run"]
        @studyCollection = @collections["Study"]
        @submissionCollection = @collections["Submission"]
        @resultFileDescriptions = JSON.parse(File.read(@genbConf.FTPsmRNAPipelineResultFileDescriptions))
        # Define number of tasks to run in parallel - overridden in updateSettings() method
        @numTasks = @settings['numTasks'].to_i
        # Define number of threads for each task - overridden in updateSettings() method
        @numThreads = @settings['numThreads'].to_i
        # Local execution
        @localExecution = "false"
        # Get the tool version (of FTP Pipeline) from toolConf
        @toolVersion = @toolConf.getSetting('info', 'version')
        @settings['toolVersion'] = @toolVersion
        # Get the tool version of processPipelineRuns from another instance of toolConf
        @toolConfPPR = BRL::Genboree::Tools::ToolConf.new('processPipelineRuns', @genbConf)
        @toolVersionPPR = @toolConfPPR.getSetting('info', 'version')
        @settings['toolVersionPPR'] = @toolVersionPPR
        # If enabled, will move all files back to /inbox after failed job (for easy repeated testing).
        # Should not be enabled for production.
        @debuggingTool = false
        # Variable to keep track of error messages
        @errUserMsg = nil
        # Variable to keep track of which files are working (for reporting to user in error e-mail)
        @workingFiles = []
        # Variable to keep track of which files are broken (for reporting to user in error e-mail)
        @brokenFiles = []
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job."
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 20
      end
      return @exitCode
    end

    # Runs the script
    # [+returns+] nil
    def run()
      begin
        #### PRELIMINARY SETUP ####
        command = ""
        # dbrc-related
        @user = @pass = nil
        if(@dbrcKey)
          dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
          @user = dbrc.user
          @pass = dbrc.password
        else
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @dbrcFile)
          @user = suDbDbrc.user
          @pass = suDbDbrc.password
        end
        # Define .out and .err files for output
        @outFile = @errFile = ""
        @outFile = "#{@scratchDir}/FTPsmRNAPipeline.out"
        @errFile = "#{@scratchDir}/FTPsmRNAPipeline.err"
        # Hash that will contain input file names and associated output files (for uploading and proper clean up)
        # Each inputFile key will be linked to a hash that contains the following values:
        #   :originalFileName => name of original file associated with a given sample / input file (before decompression)
        #   :fileType => file type of sample / input file (FASTQ / SRA), sniffed during the download / check of the data archive
        #   :failedRun => boolean flag telling us whether pipeline job succeeded or failed (false = succeeded, true = failed)
        #   :md5 => md5 string for that particular file (used in filling out Run document)
        #   :sampleName => name of sample
        #   :resultsZip => name of zipped archive containing pipeline results
        #   :statsFile => name of stats file containing summary about pipeline results
        #   :errorMsg => error message associated with run
        #   :coreZip => name of zipped archive containing all CORE file results
        #   :biosampleMetadataFileName => name of biosample metadata document associated with input file
        @inputFiles = {}
        # Array that holds all metadata files. This array is used for easy iterative validation and upload of all metadata documents.
        @metadataFiles = []
        # Set up variables to hold IDs associated with documents (by collection).
        # Some collections will only have one associated document (Analyses, Runs, Studies, Submissions) - we store these single IDs in strings.
        # Some collections have (potentially) multiple associated documents (Biosamples, Donors, Experiments, Results) - we store these IDs in an array of strings.
        @analysisID = ""
        @biosampleIDs = []
        @donorIDs = []
        @experimentIDs = []
        @resultFilesIDs = []
        @runID = ""
        @studyID = ""
        @submissionID = ""
        # Set up hashes to hold document names and associated KbDoc objects (containing contents of documents)
        # Hash keys will be document names and hash values will be those documents in KbDoc format 
        @analysisMetadataFile = {}
        @biosampleMetadataFiles = {}
        @donorMetadataFiles = {}
        @experimentMetadataFiles = {}
        @resultFilesMetadataFiles = {}
        @runMetadataFile = {}
        @studyMetadataFile = {}
        @submissionMetadataFile = {}
        # Array that holds errors found in metadata files - used during metadata validation stage
        @metadataErrors = []
        # Hash that holds a read-in copy of the submitted manifest file
        @manifestFile = nil
        # Array that contains names of all skipped files (metadata files in data archive, for example)
        # We will not raise an error if we find these files - instead, we'll just let the user know that he/she made a mistake in including them
        @skippedFiles = []
        # Variable to keep track of number of successful samples
        @successfulSamples = 0
        # Variable to keep track of number of failed samples
        @failedSamples = 0
        # Create converter and producer for use throughout - we don't need model for any reason so set producer's model to nil
        @converter = BRL::Genboree::KB::Converters::NestedTabbedDocConverter.new()
        @producer = BRL::Genboree::KB::Producers::NestedTabbedDocProducer.new(nil)
        # Create validator for checking metadata documents
        @validator = BRL::Genboree::KB::Validators::DocValidator.new()
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "BEGIN exceRpt small RNA-seq Pipeline")
        #### DOWNLOADING AND CHECKING MANIFEST FILE ####
        # There are three different possibilities when dealing with an incomplete submission.
        # 1. The manifest file is not present. In this case, we have to send an e-mail to the admin (since we do not have the user's information) and will move any existing files from /working to /inbox
        # 2. The manifest file is present but broken. In this case, we can try to send an e-mail to the user, but will send an e-mail to the admin if we can't access the user's info. We will move any existing files that are NOT the manifest file from /working to /inbox
        # 3. The manifest file is present and working. In this case, we will send an e-mail to the user and move any existing files from /working to /inbox.
        # We will first check to see if the manifest file exists.
        unless(@manifestLocation)
          @errUserMsg = "This e-mail is to alert you that you have an incomplete submission that has been sitting in your inbox for more than 2 days.\nPlease complete your submission by uploading the following files to your inbox:"
          @errUserMsg += "\nManifest file"
          @errUserMsg += "\nMetadata archive" unless(@metadataArchiveLocation)
          @errUserMsg += "\nData archive" unless(@dataArchiveLocation)
          @exitCode = 53
        end
        # checkError method is used to see whether error occurred in above method. If error did occur, then we transfer some subset of original submitted FTP files 
        # according to code given and raise an error
        checkError(4)
        # Download manifest file and set it to @manifestFile
        @exitCode = downloadManifest(@manifestLocation)
        checkError(1)
        # Sanity check manifest file. Make sure manifest file is in correct format with all required info.
        @exitCode = checkManifest(@manifestFile)
        checkError(1)
        # Update settings associated with job by looking at user-submitted settings in manifest
        @exitCode = updateSettings()
        checkError(1)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "File #{@manifestFile} is a valid manifest file with all required information")
        #### DOWNLOADING AND CHECKING METADATA ARCHIVE ####
        # Before we proceed, let's see if user's submission is incomplete (missing metadata archive or data archive)
        unless(@metadataArchiveLocation and @dataArchiveLocation)
          @errUserMsg = "This e-mail is to alert you that you have an incomplete submission that has been sitting in your inbox for more than 2 days.\nPlease complete your submission by uploading the following files to your inbox:"
          @errUserMsg += "\nMetadata archive" unless(@metadataArchiveLocation)
          @errUserMsg += "\nData archive" unless(@dataArchiveLocation)
          @exitCode = 53
        end
        checkError(4)
        # Download metadata archive
        downloadMetadataArchive(@metadataArchiveLocation)
        checkError(2)
        # Sanity check metadata files to check some basic things (no directories, no empty files, files in right format, all metadata files in manifest are present)
        @exitCode = checkMetadataFiles()
        checkError(2)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Metadata archive is valid")
        # If the user supplied a multi-column tabbed biosamples file, we will split that file up into individual biosample files (one for each sample)
        if(@multiColumn)
          # Convert multi-column tabbed biosamples into individual biosample files
          @exitCode = convertMultiColumnBiosamples()
        end
        checkError(2)
        # Load all metadata files into their KbDoc format for easier editing (won't have to open and close files repeatedly!)
        # Also generates IDs for documents lacking them
        @exitCode = loadMetadataFiles()
        checkError(2)
        #### FILLING IN METADATA DOCS (STAGE 1) ####
        # BIOSAMPLE: Fill in each biosample doc with related experiment, related donor, and potentially other pooled biosamples (?)
        @exitCode = fillInBiosampleDocs()
        checkError(2)
        # RUN: Fill in run doc with info about samples / related studies. This will be done again after the pipeline is done processing (so that only successful samples are kept).
        # We do it here just so the validator doesn't complain.
        @exitCode = fillInRunDoc(@biosampleIDs.count)
        checkError(2)
        # STUDY: Fill in study doc with info about related submission
        @exitCode = fillInStudyDoc()
        checkError(2)
        # SUBMISSION: Fill in submission doc with info about PI / submitter
        @exitCode = fillInSubmissionDoc()
        checkError(2)
        # Check to make sure that each metadata doc is valid using PUT calls and save=false - if not, we will raise an error and let user know
        @metadataFiles.each { |currentSetOfMetadataDocs|
          validateMetadataDocs(currentSetOfMetadataDocs)
          checkError(2)
        }
        # If there are any metadata errors, user will need to re-submit with fixed metadata files
        unless(@metadataErrors.empty?)
          @errUserMsg = "There were errors in your metadata file(s). Please see the following list and fix all errors before resubmitting:\n\n#{@metadataErrors.join("\n\n")}\n"
          @exitCode = 33
        end
        checkError(2)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Metadata files are valid")
        #### DOWNLOADING AND CHECKING DATA ARCHIVE ####
        # Download and check data archive
        @exitCode = downloadAndCheckDataArchive()
        checkError(3)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Data files are valid")
        # Link each @inputFiles key to its biosample metadata doc - used when filling in analysis document
        @inputFiles.each_key { |currentFile|
          # User should have put either the compressed file name or uncompressed file name for his/her "dataFileName" field for a given sample.
          originalFileName = @inputFiles[currentFile][:originalFileName]
          finalFileName = File.basename(currentFile)
          @manifest.each { |currentSample|
            if(currentSample["dataFileName"] == originalFileName or currentSample["dataFileName"] == finalFileName)
              @inputFiles[currentFile][:biosampleMetadataFileName] = "#{@metadataDir}/#{currentSample["biosampleMetadataFileName"]}"
            end
          }
          # If we can't find a link between the current @inputFiles key and a biosample doc, then we raise an error.
          unless(@inputFiles[currentFile][:biosampleMetadataFileName])
            if(@errUserMsg.empty?)
              @errUserMsg = "We failed to link some of your submitted data files to any of the \"dataFileName\" fields in your manifest file.\nIf you submit a data file, it should be listed in the manifest under either\nits compressed name or uncompressed name. A list of problematic files can be found below:\n\n"
              @exitCode = 35
            end
            @errUserMsg << "#{finalFileName} (with compressed name #{originalFileName})\n"
          end
        }
        checkError(1)
        #### SETTING UP SPIKE-IN LIBRARY ####
        setUpSpikeInLibrary()
        checkError(1)
        #### RUNNING EXCERPT SMALL RNA-SEQ PIPELINE ON SAMPLES ####
        # Create /finished directory for result files
        @ftpHelper.mkdir(@finishedFtpDir)
        # Run all samples given in the manifest file. Jobs will be run in parallel.
        Parallel.map(@inputFiles.keys, :in_threads => @numTasks) { |inFile|
          begin 
            runSmallRNAseqPipeline(inFile)
          rescue => err
            # If an error occurs, we'll mark the run as failed and set the error message accordingly
            @inputFiles[inFile][:failedRun] = true
            @inputFiles[inFile][:errorMsg] = err.message.inspect
          end
        }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "exceRpt small RNA-seq pipeline finished for all samples.")
        #### REMOVING UNSUCCESSFUL RUNS ####
        # Remove biosamples associated with unsuccessful pipeline runs from @biosampleMetadataFileNames and @biosampleIDs
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing unsuccessful biosamples (failed runs) from @metadataFiles and @biosampleIDs")
        @inputFiles.each_key { |currentFile|
          if(@inputFiles[currentFile][:failedRun])
            currentKbDoc = @biosampleMetadataFiles[@inputFiles[currentFile][:biosampleMetadataFileName]]
            currentBioID = currentKbDoc.getPropVal("Biosample")
            @biosampleIDs.delete(currentBioID)
          end
        }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully removed unsuccessful biosamples")
        # Find total number of successful / failed samples (to fill in analysis doc and to report in email / internal tool usage doc)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Finding total number of successful / failed samples")
        @inputFiles.each_key { |currentFile|
          unless(@inputFiles[currentFile][:failedRun])
            @successfulSamples += 1
          else
            @failedSamples += 1
          end
        }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of successful samples is: #{@successfulSamples}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of failed samples is: #{@failedSamples}")
        # If there are no successful samples, we'll raise an error
        if(@successfulSamples == 0)
          @errUserMsg = "None of your samples was successfully processed through the exceRpt small RNA-seq pipeline.\nPlease see the messages below to get a better idea of why your samples failed."
          @exitCode = 39
        end
        checkError(3)
        #### FILLING IN METADATA DOCUMENTS (STAGE 2)
        # RUN: Fill in info for run document (real info now that samples have been processed and unsuccessful samples have been removed)
        @exitCode = fillInRunDoc(@biosampleIDs.count)
        checkError(2)
        # RUN: Fill in proper file type in run document for each biosample
        @exitCode = fillInFileTypeForRunDoc()
        checkError(1)
        # ANALYSIS: Fill in analysis document with preliminary information
        @exitCode = fillInPrelimAnalysisInfo(@successfulSamples)
        checkError(2)
        # ANALYSIS: Fill in analysis document with info from each successful pipeline run
        # Create map from biosample ID to donor ID and result files ID - useful when filling in job doc below
        @biosampleToDonorAndResultFiles = {}
        @inputFiles.each_key { |currentFile|
          unless(@inputFiles[currentFile][:failedRun])
            @exitCode = fillInAnalysisDoc(@inputFiles[currentFile])
            checkError(2)
          end
        }
        @metadataFiles << @resultFilesMetadataFiles
        # JOB: Add related docs from all collections (run, submission, study, analysis, experiments, biosamples, donors, result files) 
        #      This document needs to be created near the end of our wrapper because:
        #        1) Only successful biosamples should be added to the Job doc (which means that the Job doc should be created AFTER the pipeline runs are finished)
        #        2) The Job doc includes the IDs for our Result Files docs, and these docs are created in the "fillInAnalysisDoc" method (which is run near the end of our wrapper)
        @exitCode = fillInJobDoc()
        checkError(2)
        #### UPLOADING METADATA DOCUMENTS ####
        @metadataFiles.each { |currentDocs|
          uploadMetadataToDb(currentDocs)
          checkError(2)
        }
        @metadataFiles.each { |currentDocs|
          uploadMetadataDocs(currentDocs)
          checkError(2)
        }
        #### POST-PROCESSING ####
        # Run processPipelineRuns on successful results .zip files
        postProcessing(@inputFiles)
        checkError(1)
        # ANALYSIS: Fill in analysis document with information from processPipelineRuns
        fillInPostProcessingInfo()
        checkError(2)
        # Since we edited the analysis doc, we need to re-upload it to the KB 
        uploadMetadataDocs(@analysisMetadataFile)
        checkError(2)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE with post-processing.")
        # Call method to upload tool usage doc
        submitToolUsageDoc()
        checkError(2)
        #### TRANSFERRING ORIGINAL FILES TO "FINISHED" FOLDER ####
        begin
          transferFtpFile(@manifestLocation, "#{@finishedFtpDir}#{File.basename(@manifestLocation)}", true)
          transferFtpFile(@metadataArchiveLocation, "#{@finishedFtpDir}#{File.basename(@metadataArchiveLocation)}", true)
          transferFtpFile(@dataArchiveLocation, "#{@finishedFtpDir}#{File.basename(@dataArchiveLocation)}", true)
        rescue => err
            @errUserMsg = "There was an error moving your original submitted files to your /finished directory on the FTP server.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
            @exitCode = 49
            raise @errUserMsg
        end
        #### DONE ####
      rescue => err
        # Generic "catch-all" error message for exceRpt small RNA-seq pipeline error
        @errUserMsg = "ERROR: Running of exceRpt small RNA-seq Pipeline failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        # We only want to set the generic @exitCode of 50 if there isn't another @exitCode already set (22 for bad manifest, for example)
        @exitCode = 50 if(@exitCode == 0)
      end
      return @exitCode
    end

###### *****************************
###### HELPER METHODS - Methods used in this workflow
###### *****************************
    
    # Download manifest file
    # @param [String] manifestLocation FTP path to manifest file 
    # @return [Fixnum] exit code that indicates whether error occurred during manifest download (0 if no error, 21 if error)
    def downloadManifest(manifestLocation)
      begin
        # Download manifest file
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input file #{manifestLocation} (manifest file)")
        fileBaseName = File.basename(manifestLocation)
        tmpFile = fileBaseName.makeSafeStr(:ultra)
        retVal = @ftpHelper.downloadFromFtp(manifestLocation, tmpFile)
        # If there's an error downloading the manifest file, report that to the user
        unless(retVal)
          @errUserMsg = "Failed to download file: #{fileBaseName} from FTP server. Looks like the file does not exist on the FTP server.\nPlease contact Genboree administrator for further assistance."
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "ApiCaller failed to download file #{fileBaseName}: #{apiCaller.respBody.inspect}")
          raise @errUserMsg
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file downloaded successfully to #{tmpFile}")
        # Save the manifest file in @manifestFile
        @manifestFile = tmpFile.clone
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "File #{@manifestFile} is a manifest file")
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: The manifest file could not be downloaded properly.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 21
      end
      return @exitCode
    end

    # Download and extract metadata archive
    # @param [String] metadataArchiveLocation FTP path to metadata archive
    # @return [Fixnum] exit code that indicates whether error occurred during metadata download / decompression (0 if no error, 24 if error)
    def downloadMetadataArchive(metadataArchiveLocation)
      begin
        # Download metadata archive 
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input file #{metadataArchiveLocation} (metadata archive)")
        fileBaseName = File.basename(metadataArchiveLocation)
        tmpFile = fileBaseName.makeSafeStr(:ultra)
        retVal = @ftpHelper.downloadFromFtp(metadataArchiveLocation, tmpFile)
        # If there's an error downloading the metadata archive, report that to the user
        unless(retVal)
          @errUserMsg = "Failed to download file: #{fileBaseName} from FTP server. Looks like the file does not exist on the FTP server.\nPlease contact the Genboree administrator for further assistance."
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "ApiCaller failed to download file #{fileBaseName}: #{apiCaller.respBody.inspect}")
          raise @errUserMsg
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Metadata archive downloaded successfully to #{tmpFile}")
        # Extract metadata archive and move contents to metadata directory
        exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracting metadata archive file #{tmpFile}")
        exp.extract()
        `mv #{exp.tmpDir}/* #{@metadataDir}`
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Contents of metadata archive moved to #{@metadataDir}")
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (hopefully won't happen)
        @errUserMsg = "ERROR: The metadata archive could not be downloaded and/or extracted properly.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 24
      end
      return @exitCode
    end

    # Download and decompress data archive (containing individual samples) and check files to make sure that everything is OK
    # @return [Fixnum] exit code that tells us whether error occurred during data download / decompression / checking (0 if no error, 34 if error)
    def downloadAndCheckDataArchive()
      begin
        # Download data archive
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input file #{@dataArchiveLocation}")
        fileBaseName = File.basename(@dataArchiveLocation)
        tmpFile = fileBaseName.makeSafeStr(:ultra)
        retVal = @ftpHelper.downloadFromFtp(@dataArchiveLocation, tmpFile)
        # If there's an error downloading the data archive, report that to the user        
        unless(retVal)
          @errUserMsg = "ApiCaller failed: failed to download file #{fileBaseName} from FTP server.\nLooks like the file does not exist on the FTP server.\nPlease contact Genboree administrator for further assistance."
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "ApiCaller failed to download file #{fileBaseName} from FTP server: #{apiCaller.respBody.inspect}")
          raise @errUserMsg
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "File downloaded successfully to #{tmpFile}")
        # Compute the MD5 digest of the input archive and compare it to the value given in the manifest file
        # If MD5 digest doesn't match, report error to user
        md5_digest = Digest::MD5.file(tmpFile).hexdigest
        if(@md5Checksum.eql?(md5_digest))
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "MD5 checksum provided by user #{@md5Checksum} matches with computed digest #{md5_digest}.")
        else
          @errUserMsg = "MD5 checksum provided by user #{@md5Checksum} does not match with the computed checksum #{md5_digest}.\nPlease double check the MD5 checksum provided in your manifest file\nand/or try to reupload your data archive."
          raise @errUserMsg
        end
        # Extract the file since it's compressed
        exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracting input file #{tmpFile}")
        exp.extract()
        # Delete data archive - we're done with it!
        `rm -f #{tmpFile}`
        # Save path to data directory and grab all files in data directory
        dataDir = exp.tmpDir
        allFiles = Dir.entries(dataDir)
        # Remove bogus entries from file list
        allFiles.delete(".")
        allFiles.delete("..")
        allFiles.delete("__MACOSX")
        # Handle situation where file list is a single directory (that will then, hopefully, contain all data result files)
        allFiles.each { |inputFile|
          if(File.directory?("#{dataDir}/#{inputFile}") and allFiles.size == 1)
            allFiles = Dir.entries("#{dataDir}/#{inputFile}")
            dataDir = "#{dataDir}/#{inputFile}"
          end
        }
        # Traverse each input file and make sure that they follow certain rules (no extra directories and no empty files)
        # Note that manifest.json / .tsv files do not raise an error - we just delete them and add them to @skippedFiles for reporting later.
        dataArchiveErrors = {:emptyFiles => [], :skippedFiles => [], :directories => []}
        allFiles.each { |inputFile|
          next if(inputFile == "." or inputFile == ".." or inputFile == "__MACOSX")
          inputDataFile = "#{dataDir}/#{inputFile}"
          if(File.zero?(inputDataFile))
            dataArchiveErrors[:emptyFiles] << inputFile
          elsif(inputFile =~ /.tsv$/ or inputFile =~ /.manifest.json$/)
            @skippedFiles << inputFile
            File.delete(inputDataFile)
          elsif(File.directory?(inputDataFile))
            dataArchiveErrors[:directories] << inputFile
          end
        }
        # Save errors from traversing input files above
        dataArchiveErrors.each_key { |category|
          unless(dataArchiveErrors[category].empty?)
            msg = ""
            if(category == :emptyFiles)
              msg = "Some of the files in your data archive are empty.\nWe do not accept empty input files.\nPlease remove these files or make sure that they have content.\nA list of these files can be found below:\n\n"
            elsif(category == :directories)
              msg = "You have included extra sub-directories inside of your data archive.\nAll files in your data archive should be located immediately inside of the archive (no sub-directories).\nA list of these directories can be found below:\n\n"
            end
            if(@errUserMsg.nil?)
              @errUserMsg = msg
            else
              @errUserMsg << "\n\n#{msg}"
            end
            @errUserMsg << dataArchiveErrors[category].join("\n")
          end
        }
        # If we found any issues above, we'll report those to the user (BEFORE beginning to expand individual files!)
        raise @errUserMsg unless(@errUserMsg.nil?)
        # Traverse each input file, check its format, and save information about it
        dataFileErrors = {:emptyFiles => [], :multipleSpikeInFiles => [], :badFormat => [], :extraFiles => [], :misc => []}
        @compressedDataNameToUncompressedDataName = {}
        allFiles.each { |inputFile|
          next if(inputFile == "." or inputFile == ".." or inputFile == "__MACOSX")
          inputDataFile = "#{dataDir}/#{inputFile}"
          begin
            # Expand file
            exp = BRL::Genboree::Helpers::Expander.new(inputDataFile)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracting original (compressed?) input file #{inputDataFile}")
            begin
              exp.extract()
            rescue => err
              # If uncompressed file is empty (given by exp.errorLevel == 30), then we add it to dataFileErrors[:emptyFiles] and move onto our next file.
              # Otherwise, the error is something else, so we'll re-raise the error and add it to dataFileErrors[:misc]. 
              if(exp.errorLevel == 30)
                msg = "Archive #{inputFile} with empty file #{File.basename(exp.uncompressedFileName)}"
                dataFileErrors[:emptyFiles] << msg
                next
              else
                raise err
              end
            end 
            # Delete __MACOSX directory if it exists
            `rm -rf #{exp.tmpDir}/__MACOSX` if(File.exist?("#{exp.tmpDir}/__MACOSX"))
            allExtractedFiles = Dir.entries(exp.tmpDir) rescue nil # If this fails, it means that exp.tmpDir wasn't created because the original file was uncompressed!
            # Check to make sure that archive only contains one file (uncompressed FASTQ / SRA) - if it contains other files (excluding __MACOSX directory),
            # then we add the archive name to our :extraFiles array in our dataFileErrors hash
            if(allExtractedFiles)
              allExtractedFiles.delete(".")
              allExtractedFiles.delete("..")
              if(allExtractedFiles.size != 1)
                dataFileErrors[:extraFiles] << inputFile
                next
              end
            end
            dataFile = exp.uncompressedFileName
            # Sniffer - To check FASTQ/SRA/FASTA format
            sniffer = BRL::Genboree::Helpers::Sniffer.new()
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Detecting file type of extracted file #{dataFile} using file sniffer")
            sniffer.filePath = dataFile
            # Grab file type (FASTQ / SRA / FASTA)
            fileType = ""
            if(sniffer.detect?('fastq'))
              fileType = "FASTQ"
            elsif(sniffer.detect?('sra'))
              fileType = "SRA"
            elsif(sniffer.detect?('fa'))
              fileType = "FASTA"
            end
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "File type of #{dataFile} is #{fileType}")
            unless(fileType == "FASTQ" || fileType == "SRA" || fileType == "FASTA")
              dataFileErrors[:badFormat] << "Archive #{inputFile} containing wrong format file #{File.basename(dataFile)}"
            else 
              # If file type is FASTQ or SRA, it's a data file
              if(fileType == "FASTQ" || fileType == "SRA")
                # Compute md5 for FASTQ / SRA file
                md5_digest = Digest::MD5.file(exp.uncompressedFileName).hexdigest
                # Convert to unix format
                convObj = BRL::Util::ConvertText.new(exp.uncompressedFileName, true)
                convObj.convertText()
                # Count number of lines in the input file
                numLines = `wc -l #{dataFile}`
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of lines in file #{dataFile} ::: #{numLines}")
                # Add data file to our @inputFiles array
                @inputFiles[dataFile] = {:originalFileName => inputFile, :fileType => fileType, :failedRun => false, :md5 => md5_digest, :errorMsg => ""}
                # If file was originally compressed, then delete the compressed version (since we have the uncompressed version)
                `rm -f #{inputDataFile}` unless(inputDataFile == dataFile)
              # If file type is FASTA, it's a spike-in file
              elsif(fileType == "FASTA")
                # Convert to unix format
                convObj = BRL::Util::ConvertText.new(exp.uncompressedFileName, true)
                convObj.convertText()
                # Count number of lines in the input file
                numLines = `wc -l #{dataFile}`
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of lines in file #{dataFile} ::: #{numLines}")
                # Set up spike-in file for creation of bowtie2 index by moving it to calibrator directory
                spikeInFileBaseName = File.basename(dataFile)
                @spikeInName = spikeInFileBaseName.makeSafeStr(:ultra)
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Spike-in file is called #{@spikeInName}")
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Moving spike-in file #{dataFile} to calibrator dir #{@calibratorDir}/.")
                `mv #{dataFile} #{@calibratorDir}/.`
                @spikeInFile = "#{@calibratorDir}/#{spikeInFileBaseName}"
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Spike-in file #{@spikeInFile} is available in calibrator dir #{@calibratorDir}/.")
                # Check to make sure that the user only included a single FASTA file - we don't allow multiple spike-in libraries!
                dataFileErrors[:multipleSpikeInFiles] << spikeInFileBaseName
              end
            end
          rescue => err
            dataFileErrors[:misc] << inputFile
            $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
            errBacktrace = err.backtrace.join("\n")
            $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
          end
        }
        # Save errors from extracting / processing each data file above
        dataFileErrors.each_key { |category|
          unless(dataFileErrors[category].empty?)
            msg = ""
            if(category == :emptyFiles)
              msg = "At least some of the uncompressed files in your data archive are empty.\nWe cannot process empty files. Please resubmit your data archive with no empty files.\nA list of empty uncompressed files can be found below:\n\n"
            elsif(category == :multipleSpikeInFiles and dataFileErrors[category].size > 1)
              msg = "You submitted multiple spike-in files in your data archive.\nWe only allow one spike-in (fasta) file in a given submission.\nPlease resubmit your data archive with only one spike-in file.\nA list of your submitted spike-in files can be found below:\n\n"
            elsif(category == :badFormat)
              msg = "At least some of the uncompressed files in your data archive were not recognized as fastq, sra, or fasta format.\nThe data archive should only contain these types of files.\nPlease resubmit your data archive with only fasta / sra / fastq files.\nA list of problematic files can be found below:\n\n"
            elsif(category == :extraFiles)
              msg = "At least some of your submitted archives contained multiple files / folders.\nEach archive should only contain a single file (uncompressed FASTQ / SRA file).\nA list of problematic archives can be found below:\n\n"
            elsif(category == :misc)
              msg = "At least some of the files in your data archive failed processing.\nPlease contact a Genboree admin for help understanding why your files failed.\nA list of problematic files can be found below:\n\n"
            end
            unless(msg.empty?)
              if(@errUserMsg.nil?)
                @errUserMsg = msg
              else
                @errUserMsg << "\n\n#{msg}"
              end
              @errUserMsg << dataFileErrors[category].join("\n")
            end
          end
        }
        raise @errUserMsg unless(@errUserMsg.nil?)
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There was an error downloading / decompressing / checking your data archive.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 34
      end
      return @exitCode
    end

    # Download custom oligo/spike-in FASTA file from database, extract zipped file, and sniff this file to make sure it is in FASTA format
    # @param [String] newOligoFile resource path to spike-in file on Genboree
    # @return [Fixnum] exit code indicating whether download of spike-in file was successful (0) or failed (55)
    def downloadSpikeInFile(newOligoFile) 
      begin
        # Check to make sure that spike-in file actually exists 
        unless(@fileApiHelper.exists?(newOligoFile))
          @errUserMsg = "We could not find the spike-in file listed in your manifest file.\nAre you sure that you gave the correct name under \"existingLibraryName\"?\nAre you sure that you uploaded your spike-in file correctly to the \"spikeInLibraries\" folder in your \"Files\" area?\nIf the above solutions do not address your issue, please contact a Genboree admin." 
          raise @errUserMsg
        end
        # Download spike-in file
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading spike-in file #{newOligoFile}")
        fileBase = @fileApiHelper.extractName(newOligoFile)
        fileBaseName = File.basename(fileBase)
        tmpFile = fileBaseName.makeSafeStr(:ultra)
        retVal = @fileApiHelper.downloadFile(newOligoFile, @subUserId, tmpFile)
        # If there's an error downloading the spike-in file, report that to the user    
        unless(retVal)
          @errUserMsg = "Failed to download spike-in file: #{fileBase} from server after many attempts.\nIs it possible that you put the wrong file name?\nPlease try again later."
          raise @errUserMsg
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "File downloaded successfully to #{tmpFile}")   
        # Expand the file if it is compressed
        exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracting spike-in file #{tmpFile}")
        exp.extract()
        # Delete __MACOSX directory if it exists 
        `rm -rf #{exp.tmpDir}/__MACOSX` if(File.exist?("#{exp.tmpDir}/__MACOSX"))
        allExtractedFiles = Dir.entries(exp.tmpDir) rescue nil # If this fails, it means that exp.tmpDir wasn't created because the original file was uncompressed!
        # Check to make sure that archive only contains one file (uncompressed FASTQ / SRA) - if it contains other files (excluding __MACOSX directory),
        # then we add the archive name to our :extraFiles array in our dataFileErrors hash
        if(allExtractedFiles) 
          allExtractedFiles.delete(".")
          allExtractedFiles.delete("..")
          if(allExtractedFiles.size != 1)
            @errUserMsg = "Your spike-in file archive #{fileBaseName} contains multiple files.\nPlease delete any extra files that are in the archive and then resubmit your job."
            raise @errUserMsg
          end
        end
        # Sniffer - To check FASTA format
        sniffer = BRL::Genboree::Helpers::Sniffer.new()
        inputFile = exp.uncompressedFileName
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "The path of the unzipped spike-in file is: #{inputFile}")
        # Check whether file is empty
        if(File.zero?(inputFile))
          @errUserMsg = "Your spike-in file #{inputFile} is empty.\nPlease upload a non-empty file and try again."
          raise @errUserMsg
        end   
        # Detect if file is in FASTA format
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Detecting file type of extracted spike-in file #{inputFile} using file sniffer")
        sniffer.filePath = inputFile
        unless(sniffer.detect?('fa'))
          @errUserMsg = "Your spike-in file #{inputFile} is not in FASTA format.\nPlease check the file format."
          raise @errUserMsg
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Spike-in file #{inputFile} is in correct format")
        # Convert to unix format
        convObj = BRL::Util::ConvertText.new(inputFile, true)
        convObj.convertText() 
        # Count number of lines in the input file
        numLines = `wc -l #{inputFile}`
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of lines in spike-in file #{inputFile}: #{numLines}")
        spikeInFileBasename = File.basename(inputFile)
        # Move spike-in file to calibrator directory and set up @spikeInFile variable
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Moving spike-in file #{inputFile} to calibrator dir #{@calibratorDir}/.")
        `mv #{inputFile} #{@calibratorDir}/.`
        @spikeInFile = "#{@calibratorDir}/#{spikeInFileBasename}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Spike-in file #{@spikeInFile} is available in calibrator dir #{@calibratorDir}/.")
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There was an error downloading your spike-in file.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 55
      end
      return @exitCode
    end

    # Sanity check manifest file
    # @param [String] manifestFile path to manifest file
    # @return [Fixnum] exit code that indicates whether error occurred during manifest check (0 if no error, 22 if error)
    def checkManifest(manifestFile)
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking if manifest file #{manifestFile} is correct")
        # Read in manifest file and see whether it's in proper JSON
        @fileData = JSON.parse(File.read(manifestFile)) rescue nil
        # errors array will keep track of all errors that occur as we check our manifest file
        errors = []
        # This boolean will keep track of whether manifest file is broken (not proper JSON)
        brokenManifest = false
        # If @fileData isn't valid, then we know that manifest is broken. We will still try to retrieve user's userLogin, though
        unless(@fileData)
          brokenManifest = true
          errors << "Manifest file is not in proper JSON format.\nPlease check your manifest file for formatting issues\nor run your manifest file through a JSON validator\nlike JSONLint (www.jsonlint.com) to find errors."
        end
        # If manifest is broken, we will try to grep the broken manifest file for user's login
        if(brokenManifest) 
          # Do a search to try to find userLogin
          findUserLogin = `grep userLogin #{manifestFile}`
          # If we found something, let's try to grab the user login
          unless(findUserLogin.empty?)
            # Scan for words in line, then set @subUserLogin to be a word that matches a Genboree login (token that is not "userLogin" and between 5-40 characters)
            tokens = findUserLogin.scan(/\w+/)
            tokens.each { |currentToken|
              @subUserLogin = currentToken if(currentToken != "userLogin" and currentToken.length >= 5 and currentToken.length <= 40)
            }
          end
          # If we still couldn't find the userLogin, then we raise an error.
          unless(@subUserLogin)
            errors << "We were unable to locate your userLogin so we can't e-mail you.\nPlease correct your manifest file / make sure that you put your correct userLogin in!"
          end
        # If manifest is NOT broken, then let's try to grab the userLogin normally
        else
          # If no value is given or "userLogin" is missing, then we raise an error
          if(!@fileData.key?("userLogin") or @fileData["userLogin"].nil? or @fileData["userLogin"].empty?)
            errors << "Manifest file does not contain user login.\nThe \"userLogin\" field is required.\nPlease put your user login name for Genboree\nand resubmit your job."
          else
            @subUserLogin = @fileData["userLogin"]
          end
        end
        # If we haven't yet found @subUserLogin, then raise an error containing any issues found above
        unless(@subUserLogin)
          @errUserMsg = "There were some issues with finding your user login in your manifest file. More specific error messages can be found below:\n\n"
          @errUserMsg << errors.join("\n")
          raise @errUserMsg
        end 
        # If we now have @subUserLogin, then we hopefully managed to find user login (either directly from working manifest or from searching broken manifest)
        # Check if the user login is a valid Genboree user name 
        @dbu = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil, nil)
        @subUserId = Abstraction::User.getUserIdForLogin(@dbu, @subUserLogin)
        @subUserId = @subUserId.to_i if(@subUserId)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "@subUserId is: #{@subUserId}")
        host = @settings['outputHost']
        # If it's not a valid user login, then let admin know and raise error
        if(@subUserId.nil?)
          error = "User #{@subUserLogin} is not a valid user for host #{host}."
          error << "\nSince your manifest is broken, we tried to retrieve the correct user login (value of \"userLogin\" field),\nbut it is possible that we failed to do so correctly." if(brokenManifest)
          errors << error 
          @errUserMsg = "There were some issues with your manifest file. More specific error messages can be found below:\n\n"
          @errUserMsg << errors.join("\n")
          raise @errUserMsg
        end
        # Get first name, last name, email for that subUserLogin (important for sending out error e-mail to user)
        # If we can't retrieve this info, then let admin know and raise error
        rsrcPath = "/REST/v1/usr/#{@subUserLogin}"
        apiCaller = WrapperApiCaller.new(host, rsrcPath, @subUserId)
        apiCaller.get()
        unless(apiCaller.succeeded?)
          errors << "Could not grab userLogin's first name / last name / email.\nPlease contact a Genboree admin for help."
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "ApiCaller failed for grabbing first name / last name / email: #{apiCaller.respBody.inspect}")
          @errUserMsg = "There were some issues with your manifest file. More specific error messages can be found below:\n\n"
          @errUserMsg << errors.join("\n")
          raise @errUserMsg
        end
        retVal = apiCaller.parseRespBody()
        @subUserFirstName = retVal['data']['firstName']
        @subUserLastName = retVal['data']['lastName']
        @subUserEmail = retVal['data']['email']
        # Even if we managed to find user's info, if the manifest is broken, the user should fix that before we proceed with their submission.
        # Thus, we'll raise an error message to let them know
        if(brokenManifest)
          @errUserMsg = "There were some issues with the structure of your manifest file.\nMore detailed error messages can be found below:\n\n"
          @errUserMsg << errors.join("\n")
          raise @errUserMsg
        end
        # Check study name - if no value given, raise error (it's required)
        if(!@fileData.key?("studyName") or @fileData["studyName"].nil? or @fileData["studyName"].empty?)
          errors << "Manifest file does not contain study name.\nThe \"studyName\" field is required.\nPlease put a name for your study and resubmit your job."
        else
          @studyName = @fileData["studyName"]
        end
        # Check for md5 checksum provided by user (error if none given) - we will make sure that it matches with computed digest after we download the data archive
        if(!@fileData.key?("md5CheckSum") or @fileData["md5CheckSum"].nil? or @fileData["md5CheckSum"].empty?)
          errors << "Manifest file does not contain MD5 checksum.\nThe \"md5CheckSum\" field is required.\nPlease compute the MD5 checksum of your archive and resubmit your job."
        else
          @md5Checksum = @fileData['md5CheckSum']
        end
        # Check for group name provided by user - if no value given, raise error (it's required)
        if(!@fileData.key?("group") or @fileData["group"].nil? or @fileData["group"].empty?)
          errors << "Manifest file does not contain Genboree group.\nThe \"group\" field is required.\nPlease put a valid group name for Genboree and resubmit your job."
        else
          @groupName = CGI.escape(@fileData["group"])
          @outputDb.gsub!(/\{GROUP_NAME\}/, @groupName)
        end
        # Check for database name provided by user - if no value given, raise error (it's required)
        if(!@fileData.key?("db") or @fileData["db"].nil? or @fileData["db"].empty?)
          errors << "Manifest file does not contain Genboree database.\nThe \"db\" field is required.\nPlease put a valid database name for Genboree and resubmit your job."
        else
          @dbName = CGI.escape(@fileData["db"])
          @outputDb.gsub!(/\{DB_NAME\}/, @dbName)
        end
        # Grab user-submitted settings (given in manifest) and merge them with default options
        if(!@fileData.key?("settings") or @fileData["settings"].nil? or @fileData["settings"].empty?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file does not have user-submitted settings. We will use default settings for pipeline jobs.")
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Merging user-submitted settings with default options (will override defaults)")
          @settings.merge!(@fileData["settings"])
        end
        # Grab genome version associated with output database (this will be compared against genome version submitted by user in settings, which is a default of hg19)
        targetUri = URI.parse(@outputDb) rescue nil 
        if(targetUri)
          apiCaller = WrapperApiCaller.new(host, "#{targetUri.path}?", @subUserId)
          apiCaller.get()
          unless(apiCaller.succeeded?)
            errors << "Could not grab genome version associated with output database.\nAre you sure that the group / database you listed in your manifest file exist already in the Genboree Workbench?\nAre you also sure that you didn't make a typo in the group / database name?\nIf your problem is not solved by the above fixes, please contact a Genboree admin."
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "ApiCaller failed for grabbing genome version: #{apiCaller.respBody.inspect}")
          end
          retVal = apiCaller.parseRespBody()
          @genomeVersionOfDb = retVal['data']['version'].decapitalize rescue nil
          # Grab index base name and genome build associated with genome version grabbed above
          unless(@genomeVersionOfDb.nil? or @genomeVersionOfDb.empty?)
            gbSmallRNASeqPipelineGenomesInfo = JSON.parse(File.read(@genbConf.gbSmallRNASeqPipelineGenomesInfo))
            indexBaseName = gbSmallRNASeqPipelineGenomesInfo[@genomeVersionOfDb]['indexBaseName']
            genomeBuild = gbSmallRNASeqPipelineGenomesInfo[@genomeVersionOfDb]['genomeBuild']  
            if(indexBaseName.nil?)
              errors << "Your output database on Genboree has genome version #{@genomeVersionOfDb}.\nThis genome version is not currently supported.\nSupported genomes include: #{gbSmallRNASeqPipelineGenomesInfo.keys.join(',')}.\nPlease contact the Genboree Administrator for potentially adding support for this genome."
            end
          else
            errors << "Your output database on Genboree has no genome version associated with it. Please make sure that your output database has the same genome version (default of hg19) as your submitted files." if(apiCaller.succeeded?)
          end
        end
        #### ANALYSIS DOC ####
        # Check if Analysis metadata doc is available - if it is, add it to @metadataFiles.  Otherwise, auto-generate analysis doc for user (we will fill it in after pipeline runs are finished).
        if(!@fileData.key?("analysisMetadataFileName") or @fileData["analysisMetadataFileName"].nil? or @fileData["analysisMetadataFileName"].empty?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file does not contain analysis metadata file name. Creating analysis metadata document.")
          # Create new analysisDoc that contains most basic, required information, and then save it as compact tabbed file
          analysisDoc = BRL::Genboree::KB::KbDoc.new({})
          # Auto-generate new ID
          currentID = grabAutoID("Analysis", @analysisCollection)
          raise @errUserMsg unless(@exitCode == 0)
          currentID.insert(4, @piID)
          # Set up basic attributes of analysis document
          analysisDoc.setPropVal("Analysis", currentID)
          analysisDoc.setPropVal("Analysis.Status", "Add")
          # Save doc with filename "autoGeneratedAnalysisDoc.compact.metadata.tsv"
          updatedAnalysisDoc = @producer.produce(analysisDoc).join("\n")
          analysisMetadataFileName = "autoGeneratedAnalysisDoc.compact.metadata.tsv"
          File.open("#{@metadataDir}/#{analysisMetadataFileName}", 'w') { |file| file.write(updatedAnalysisDoc) }
          # Save new analysis metadata filename to manifest
          @fileData["analysisMetadataFileName"] = analysisMetadataFileName
        end
        #### MULTI-COLUMN BIOSAMPLE DOC ####
        # See if user has included a multi-column tabbed file for his/her biosamples. If so, we will not require biosample names for individual samples.
        # In fact, they're not allowed at all since the multi-column tabbed file must contain all biosamples if it exists.
        if(!@fileData.key?("biosampleMetadataFileName") or @fileData["biosampleMetadataFileName"].nil? or @fileData["biosampleMetadataFileName"].empty?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file does not have multi-column tabbed file for biosamples. It is possible that biosample metadata is submitted for each biosample.")
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file has multi-column tabbed file for biosamples. We will set flag for processing multi-column tabbed file.")
          # @multiColumn will keep track of whether multi-column file was found
          @multiColumn = true
        end
        #### MAIN DONOR DOC ####
        # Check if Donor metadata doc is available - if it is, add it to @metadataFiles.  Otherwise, keep going (since user could have submitted donor metadata doc for each biosample).
        foundDonorDoc = false
        if(!@fileData.key?("donorMetadataFileName") or @fileData["donorMetadataFileName"].nil? or @fileData["donorMetadataFileName"].empty?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file does not contain general donor metadata file name. It is possible that donor metadata is submitted for each biosample.")
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file contains general donor metadata file name. This name is used for any samples that do not have a donor metadata file name.")
          # foundDonorDoc will keep track of whether we found a general donor doc (applies to all samples without specific donor docs)
          foundDonorDoc = true
        end
        #### MAIN EXPERIMENT DOC ####
        # Check if Experiment metadata doc is available - if it is, add it to @metadataFiles.  Otherwise, keep going (since user could have submitted Experiment metadata doc for each biosample).
        foundExperimentDoc = false   
        if(!@fileData.key?("experimentMetadataFileName") or @fileData["experimentMetadataFileName"].nil? or @fileData["experimentMetadataFileName"].empty?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file does not contain experiment metadata file name. It is possible that experiment metadata is submitted for each biosample.")
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file contains general experiment metadata file name. This name is used for any samples that do not have an experiment metadata file name.")
          # foundExperimentDoc will keep track of whether we found a general experiment doc (applies to all samples without specific experiment docs)
          foundExperimentDoc = true
        end
        #### RUN DOC ####
        # Check if name of Run metadata doc is available - if it is, add it to @metadataFiles.  Otherwise, give error (no Run document is not acceptable).
        if(!@fileData.key?("runMetadataFileName") or @fileData["runMetadataFileName"].nil? or @fileData["runMetadataFileName"].empty?)
          errors << "Manifest file does not contain run metadata file name.\nThe \"runMetadataFileName\" field is required.\nPlease put a valid run metadata file name and resubmit your job."
        end
        #### STUDY DOC ####
        # Check if Study metadata doc is available - if it is, add it to @metadataFiles.  Otherwise, give error (no Study document is not acceptable).
        if(!@fileData.key?("studyMetadataFileName") or @fileData["studyMetadataFileName"].nil? or @fileData["studyMetadataFileName"].empty?)
          errors << "Manifest file does not contain study metadata file name.\nThe \"studyMetadataFileName\" field is required.\nPlease put a valid study metadata file name and resubmit your job."
        end
        #### SUBMISSION DOC ####
        # Check if Submission metadata doc is available - if it is, add it to @metadataFiles.  Otherwise, give error (no Submission document is not acceptable).
        if(!@fileData.key?("submissionMetadataFileName") or @fileData["submissionMetadataFileName"].nil? or @fileData["submissionMetadataFileName"].empty?)
          errors << "Manifest file does not contain submission metadata file name.\nThe \"submissionMetadataFileName\" field is required.\nPlease put a valid submission metadata file name and resubmit your job."
        end
        #### GENOME MAPPING DOC ####
        # This is currently commented out because we're not filling out this information yet!
=begin
        # Add Genome Mappings doc (will not be created by user)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file does not have genome mapping metadata filename. Creating genome mapping metadata document.")
        # Create new genomeMappingsDoc that contains most basic, required information, and then save it as compact tabbed file
        genomeMappingsDoc = BRL::Genboree::KB::KbDoc.new({})
        # Auto-generate new ID
        rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/model/prop/{prop}/autoID"
        apiCaller = WrapperApiCaller.new(@exRNAHost, rsrcPath, @subUserId)
        apiCaller.get({:prop => "Genome Mappings", :coll => "Genome Mappings", :kb => @exRNAKb, :grp => @exRNAKbGroup})
        # Set up basic attributes of genome mapping document
        genomeMappingsDoc.setPropVal("Genome Mappings", apiCaller.parseRespBody["data"]["text"])
        genomeMappingsDoc.setPropVal("Genome Mappings.Status", "Add")
        # Save doc with filename "genomeMappings.compact.metadata.tsv"
        updatedGenomeMappingsDoc = @producer.produce(genomeMappingsDoc).join("\n")
        @genomeMappingsMetadataFileName = "genomeMappingsDoc.compact.metadata.tsv"
        File.open("#{@metadataDir}/#{@genomeMappingsMetadataFileName}", 'w') { |file| file.write(updatedGenomeMappingsDoc) }
        # Save new genome mappings metadata filename to manifest
        @fileData["genomeMappingsMetadataFileName"] = "genomeMappingsDoc.compact.metadata.tsv"
        @metadataFiles << @genomeMappingsMetadataFileName
=end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Data from the manifest file #{manifestFile}: #{@fileData.inspect}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Output database: #{@outputDb}")
        # Grab sample-specific portion of manifest file - this should be proper JSON if entire manifest file was read in correctly earlier
        @manifest = @fileData["manifest"]
        #### CHECKING INDIVIDUAL SAMPLES ####
        count = 0
        @manifest.each { |eachSampleHash|
          count += 1
          #### CHECKING SAMPLE NAME ####
          # Check if sample name is provided for sample - if not, we raise an error (it's required!).
          # Note that this sample name must match the "Biosample.Name" field for the associated biosample.
          if(!eachSampleHash.key?("sampleName") or eachSampleHash["sampleName"].nil? or eachSampleHash["sampleName"].empty?)
            errors << "Manifest file is missing a \"sampleName\" value for sample ##{count} in your \"manifest\" hash array.\nPlease check that each sample has a \"sampleName\" value."
          else
            sample = eachSampleHash["sampleName"]
          end
          sample = "##{count} in your \"manifest\" hash array" unless(sample)
          #### CHECKING BIOSAMPLE ASSOCIATED WITH SAMPLE ####
          # Check if biosample metadata file name is provided.
          # If there is no biosample metadata file name provided, then a multi-column tabbed biosample doc must be provided (@multiColumn must be true). 
          # If not, we raise an error.
          unless(@multiColumn)
            if(!eachSampleHash.key?("biosampleMetadataFileName") or eachSampleHash["biosampleMetadataFileName"].nil? or eachSampleHash["biosampleMetadataFileName"].empty?)
              errors << "Manifest file is missing a \"biosampleMetadataFileName\" value for sample #{sample}.\nPlease check that each sample has a \"biosampleMetadataFileName\" value."
            end
          end
          # If @multiColumn is true AND a biosample metadata file name is provided, we also raise an error (you can't have both).
          if(@multiColumn and eachSampleHash.key?("biosampleMetadataFileName"))
            errors << "You have included a multi-column biosample metadata file,\nbut you have also included a value for an individual sample's \"biosampleMetadataFileName\".\nThe multi-column file must supply all biosample metadata.\nPlease delete all individual sample \"biosampleMetadataFileName\" fields and try again."
          end
          #### CHECKING DONOR ASSOCIATED WITH SAMPLE ####
          # Check if donor metadata file name is provided.
          # If there is no donor metadata file name provided, then a general donor doc must be provided (generalDonorDoc must be true). 
          # If not, we raise an error.
          if(!eachSampleHash.key?("donorMetadataFileName") or eachSampleHash["donorMetadataFileName"].nil? or eachSampleHash["donorMetadataFileName"].empty?)
            unless(foundDonorDoc)
              errors << "Manifest file is missing a \"donorMetadataFileName\" value for sample #{sample}.\nBecause you did not supply a more general \"donorMetadataFileName\" value that can apply to all samples,\nyour manifest file is invalid."
            end
          end            
          #### CHECKING EXPERIMENT ASSOCIATED WITH SAMPLE ####
          # Check if experiment metadata file name is provided.
          # If there is no experiment metadata file name provided, then a general experiment doc must be provided (generalExperimentDoc must be true). 
          # If not, we raise an error.
          if(!eachSampleHash.key?("experimentMetadataFileName") or eachSampleHash["experimentMetadataFileName"].nil? or eachSampleHash["experimentMetadataFileName"].empty?)
            unless(foundExperimentDoc)
              errors << "Manifest file is missing a \"experimentMetadataFileName\" value for sample #{sample}.\nBecause you did not supply a more general \"experimentMetadataFileName\" value that can apply to all samples,\nyour manifest file is invalid."
            end
          end
          #### CHECKING DATA FILE NAME ASSOCIATED WITH SAMPLE ####
          # Check if data file name is provided - if not, we raise an error (it's required!).
          if(!eachSampleHash.key?("dataFileName") or eachSampleHash["dataFileName"].nil? or eachSampleHash["dataFileName"].empty?)
            errors << "Manifest file is missing a \"dataFileName\" value for sample #{sample}.\nPlease check that each sample has a \"dataFileName\" value."
          end
        }
        unless(errors.empty?)
          @errUserMsg = "Some errors occurred while traversing your manifest file.\n\n======================LIST OF ISSUES==============================\n"
          @errUserMsg << errors.join("\n=================================================================\n")
          @errUserMsg << "\n================================================================="
          raise @errUserMsg
        end
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: The manifest file does not have all required variables for running the job.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        unless(@metadataArchiveLocation and @dataArchiveLocation)
          @errUserMsg << "\nIn addition, you have an incomplete submission that has been sitting in your inbox for more than 2 days.\nPlease complete your submission by uploading the following files to your inbox:"
          @errUserMsg << "\nMetadata archive" unless(@metadataArchiveLocation)
          @errUserMsg << "\nData archive" unless(@dataArchiveLocation)
        end
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 22
      end
      return @exitCode
    end

    # Update settings associated with job (given in manifest file) 
    # @return [Fixnum] exit code indicating whether updating settings was successful (0 if it was, 23 if not)
    def updateSettings()
      begin
        # Set up spike-in options
        @analysisName = @settings['analysisName'] if(@settings['analysisName'])
        @useLibrary = @settings['useLibrary']
        if(@useLibrary =~ /useExistingLibrary/)
          unless(@settings['existingLibraryName'])
            @errUserMsg = "You have selected to use an existing spike-in library on Genboree, but you did not supply a spike-in file name.\nThis file name should be supplied under the \"existingLibraryName\" field."
            raise @errUserMsg
          end
          @spikeInUri = "#{@outputDb}/file/spikeInLibraries/#{@settings['existingLibraryName']}"
          fileBase = @fileApiHelper.extractName(@spikeInUri)
          fileBaseName = File.basename(fileBase)
          @spikeInName = fileBaseName.makeSafeStr(:ultra)
        end
        # Set up other options
        # 3' adapter sequence options 
        @clippedInput = ""
        @clippedInput = @settings['clippedInput']
        @adapterSequence = @settings['adapterSequence'].to_s
        # Small RNA mapping libraries options
        @tRNAmapping = @settings['tRNAmapping']
        @piRNAmapping = @settings['piRNAmapping']
        @gencodemapping = @settings['gencodemapping']
        @exogenousMapping = @settings['exogenousMapping']
        # If no information is supplied, assume the mapping is off
        if(!@tRNAmapping or @tRNAmapping.empty? or @tRNAmapping.nil?)
          @tRNAmapping = "off"
        end  
        if(!@piRNAmapping or @piRNAmapping.empty? or @piRNAmapping.nil?)
          @piRNAmapping = "off"
        end  
        if(!@gencodemapping or @gencodemapping.empty? or @gencodemapping.nil?)
          @gencodemapping = "off"
        end  
        if(!@exogenousMapping or @exogenousMapping.empty? or @exogenousMapping.nil?)
          @exogenousMapping = "off"
        end
        # There are certain requirements if exogenous mapping is on (must map to tRNA, piRNA, gencode). We also change the @numTasks and @numThreads for exogenous mapping.
        if(@exogenousMapping =~ /on/)
          # Number of tasks / threads defined for parallel exceRpt small RNA-seq pipeline jobs to run STAR mapping
          @tRNAmapping = "on"
          @piRNAmapping = "on"
          @gencodemapping = "on"
          @numTasks = 1
          @numThreads = 8
          @javaRam = "20G"
        else
          # Number of tasks / threads defined for parallel exceRpt small RNA-seq pipeline jobs
          @numTasks = 3
          @numThreads = 4
          @javaRam = "20G"
        end
        # We'll save all of the different libraries in @smallRNALibs to easily pass those options to our command that calls the exceRpt small RNA-seq pipeline
        @smallRNALibs = "TRNA_MAPPING=#{@tRNAmapping} PIRNA_MAPPING=#{@piRNAmapping} GENCODE_MAPPING=#{@gencodemapping} MAP_EXOGENOUS=#{@exogenousMapping} " 
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "exceRpt small RNA-seq pipeline Libs: #{@smallRNALibs}")
        # Get adapter sequence
        @adSeq = ""
        if(@adapterSequence =~ /^[ATGCNatgcn]+$/)
          @adSeq = "ADAPTER_SEQ=#{@adapterSequence}"
        else
          @adSeq = "ADAPTER_SEQ=NULL"
        end
        if(@clippedInput)
          @adSeq = "ADAPTER_SEQ=NONE"
        end
        # Advanced mapping options
        @mismatchMirna = @settings['mismatchMirna']
        @mismatchOther = @settings['mismatchOther']
        if(!@mismatchMirna or @mismatchMirna.empty? or @mismatchMirna.nil?)
          @mismatchMirna = 1
        end
        if(!@mismatchOther or @mismatchOther.empty? or @mismatchOther.nil?)
          @mismatchOther = 2
        end
        # Local execution
        @localExecution = "false"
        # Make sure the genome version given in the manifest (default of hg19) is supported by current implementation of this pipeline
        @genomeVersion = @settings['genomeVersion']
        unless(@genomeVersion.nil? or @genomeVersion.empty?)
          gbSmallRNASeqPipelineGenomesInfo = JSON.parse(File.read(@genbConf.gbSmallRNASeqPipelineGenomesInfo))
          indexBaseName = gbSmallRNASeqPipelineGenomesInfo[@genomeVersion]['indexBaseName']
          # @genomeBuild will be used below when making system call to run exceRpt small RNA-seq pipeline
          @genomeBuild = gbSmallRNASeqPipelineGenomesInfo[@genomeVersion]['genomeBuild']
          if(indexBaseName.nil?)
            @errUserMsg = "The genome version #{@genomeVersion} supplied in your manifest file is not currently supported.\nSupported genomes include: #{gbSmallRNASeqPipelineGenomesInfo.keys.join(',')}.\nPlease contact the Genboree admin for adding support for this genome."
            raise @errUserMsg
          end
          # If genome version given in manifest does not match the genome version associated with the output database, we raise an error
          unless(@genomeVersion == @genomeVersionOfDb)
            @errUserMsg = "The genome version #{@genomeVersion} supplied in your manifest file\ndoes not match the genome version #{@genomeVersionOfDb} of your database.\nPlease make sure that these genome versions match."
            raise @errUserMsg
          end 
        else
          @errUserMsg = "Your submitted genomeVersion is empty or nil, which means you wrote something like\n\"genomeVersion\": \"\"\nin your manifest file. Please make sure that you supply the correct genome version for your files.\nIf you are using hg19, you do not have to include \"genomeVersion\" in your manifest settings."
        end
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There was an issue with configuring the settings for your pipeline runs.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 23
      end
      return @exitCode
    end

    # Initial checks to make sure that some basic requirements are met for metadata files (validation checks will occur during upload of metadata docs to KB)
    # @return [Fixnum] exit code that indicates whether error occurred during metadata file check (0 if no error, 25 if error)
    def checkMetadataFiles()
      begin
        # Grab the names of all files in metadata directory
        allMetadataFiles = Dir.entries(@metadataDir)
        # Delete unnecessary entries from list
        allMetadataFiles.delete(".")
        allMetadataFiles.delete("..")
        allMetadataFiles.delete("__MACOSX")
        autoGeneratedAnalysisDoc = "autoGeneratedAnalysisDoc.compact.metadata.tsv"
        allMetadataFiles.delete(autoGeneratedAnalysisDoc)
        errors = []
        # Handle situation where file list is a single directory (that will then, hopefully, contain all metadata result files)
        allMetadataFiles.each { |inputFile|
          if(File.directory?("#{@metadataDir}/#{inputFile}") and allMetadataFiles.size == 1)
            # Make sure that we move auto-generated analysis doc to the new metadata directory
            `mv #{@metadataDir}/#{autoGeneratedAnalysisDoc} #{@metadataDir}/#{inputFile}/` if(File.exist?("#{@metadataDir}/#{autoGeneratedAnalysisDoc}"))
            allMetadataFiles = Dir.entries("#{@metadataDir}/#{inputFile}")
            @metadataDir = "#{@metadataDir}/#{inputFile}"
          end
        }
        allMetadataFiles.push(autoGeneratedAnalysisDoc).uniq!
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "list of metadata files: #{allMetadataFiles.inspect}")
        # Check to make sure that metadata archive contains ONLY non-empty .metadata.tsv or .compact.tsv files and no directories!
        allMetadataFiles.each { |currentMetadataFile|
          next if(currentMetadataFile == "." or currentMetadataFile == ".." or currentMetadataFile == "__MACOSX")
          # If file is directory, then we do not need to check for its file extension below (for example, don't want to report error that directory named "Test" doesn't end in .metadata.tsv or .compact.tsv).
          foundDirectory = false 
          if(File.directory?("#{@metadataDir}/#{currentMetadataFile}"))
            errors << "File #{currentMetadataFile} is a directory.\nMetadata files in an archive should not be inside a sub-directory.\nPlease re-upload your archive without any sub-directories."
            foundDirectory = true
          end
          if(File.zero?("#{@metadataDir}/#{currentMetadataFile}"))
            errors << "File #{currentMetadataFile} is empty.\nPlease make sure that all submitted files are non-empty and submit your job again."
          end
          unless(currentMetadataFile =~ /.metadata.tsv$/ or currentMetadataFile =~ /.compact.tsv$/)
            errors << "File #{currentMetadataFile} was found inside metadata archive but does not end in .metadata.tsv or .compact.tsv.\nPlease ensure that all of your files end in .metadata.tsv or .compact.tsv and are metadata files." unless(foundDirectory)
          end
        }
        # Next, we'll check that the metadata files mentioned in the manifest file are present
        if(errors.empty?)
          errors << "Analysis metadata file #{@fileData["analysisMetadataFileName"]} could not be found in your metadata archive, but is mentioned in your manifest." unless(allMetadataFiles.include?(@fileData["analysisMetadataFileName"]))
          if(@fileData["experimentMetadataFileName"])
            errors << "Experiment metadata file #{@fileData["experimentMetadataFileName"]} could not be found in your metadata archive, but is mentioned in your manifest." unless(allMetadataFiles.include?(@fileData["experimentMetadataFileName"]))
          end
          errors << "Run metadata file #{@fileData["runMetadataFileName"]} could not be found in your metadata archive, but is mentioned in your manifest." unless(allMetadataFiles.include?(@fileData["runMetadataFileName"]))
          errors << "Study metadata file #{@fileData["studyMetadataFileName"]} could not be found in your metadata archive, but is mentioned in your manifest." unless(allMetadataFiles.include?(@fileData["studyMetadataFileName"]))
          errors << "Submission metadata file #{@fileData["submissionMetadataFileName"]} could not be found in your metadata archive, but is mentioned in your manifest." unless(allMetadataFiles.include?(@fileData["submissionMetadataFileName"]))
          if(@fileData["DonorMetadataFileName"])
            errors << "Donor metadata file #{@fileData["donorMetadataFileName"]} could not be found in your metadata archive, but is mentioned in your manifest." unless(allMetadataFiles.include?(@fileData["donorMetadataFileName"]))
          end
          if(@fileData["biosampleMetadataFileName"])
            errors << "Biosample multi-column metadata file #{@fileData["biosampleMetadataFileName"]} could not be found in your metadata archive, but is mentioned in your manifest." unless(allMetadataFiles.include?(@fileData["biosampleMetadataFileName"]))
          end
          @manifest.each { |eachSampleHash|
            if(eachSampleHash["biosampleMetadataFileName"])
              errors << "Biosample metadata file #{eachSampleHash["biosampleMetadataFileName"]} could not be found in your metadata archive, but is mentioned in your manifest." unless(allMetadataFiles.include?(eachSampleHash["biosampleMetadataFileName"]))
            end 
            if(eachSampleHash["experimentMetadataFileName"])
              errors << "Experiment metadata file #{eachSampleHash["experimentMetadataFileName"]} could not be found in your metadata archive, but is mentioned in your manifest." unless(allMetadataFiles.include?(eachSampleHash["experimentMetadataFileName"]))
            end
            if(eachSampleHash["donorMetadataFileName"])
              errors << "Donor metadata file #{eachSampleHash["donorMetadataFileName"]} could not be found in your metadata archive, but is mentioned in your manifest." unless(allMetadataFiles.include?(eachSampleHash["donorMetadataFileName"]))
            end
          }
        end
        # We raise an error unless we didn't find any errors above
        unless(errors.empty?)
          @errUserMsg = "There were some errors with your metadata archive. See the following:\n\n#{errors.join("\n\n")}"
          raise @errUserMsg
        end
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There were some errors with checking your metadata files.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 25
      end
      return @exitCode
    end

    # Converts multi-column biosample file into individual biosample files
    # @return [Fixnum] exit code indicating whether conversion succeeded (0) or failed (26)
    def convertMultiColumnBiosamples()
      begin
        # Use converter to parse and convert multi-column tabbed file into an array of single biosamples
        biosamplesFile = File.open("#{@metadataDir}/#{@fileData["biosampleMetadataFileName"]}", 'r')
        convertedBiosamples = @converter.parse(biosamplesFile, true)
        unless(@converter.errors.empty?)
          @errUserMsg = "There was an error in importing your multi-column biosample doc named #{@fileData["biosampleMetadataFileName"]}.\nAre you sure that you followed the required model for biosample documents?\nDid you forget to add the \"domain\" column to your multi-column tabbed document? Please use the following resources to fix your multi-column tabbed document:\nhttp://genboree.org/genboreeKB/projects/genboreekb-introduction/wiki/Tab_Separated_Value_Formats#Multi-column\nhttp://genboree.org/theCommons/attachments/5028/Biosamples.model.compact.tsv\n\nA list of errors can be found below:\n\n#{@converter.errorSummaryStr}"
          raise @errUserMsg
        end
        # We will now fill out each sample in the manifest with information about its respective biosample
        # docNo will be used to inform the user which document column to look at if they are missing a value for the "-- File Name" property for a particular document. 
        docNo = 0
        # We traverse each biosample, one at a time
        errors = []
        convertedBiosamples.each { |currentBiosample|
          docNo += 1
          # We will create a new KbDoc with the current biosample so we can use KbDoc methods
          currentBiosample = BRL::Genboree::KB::KbDoc.new(currentBiosample)
          # We grab the "Biosample.Name" value from the current biosample
          currentSampleName = currentBiosample.getPropVal("Biosample.Name") rescue nil
          # foundSample will be used to see whether we've found a matching sample in the manifest for the file grabbed above
          foundSample = false
          # If the current biosample has a "Biosample.Name" value, then we proceed, Otherwise, we raise an error.
          if(currentSampleName)
            # We traverse each sample in the manifest.
            @fileData["manifest"].each { |currentSampleInManifest|
              # If the "sampleName" field for a particular sample matches the name given in the biosample metadata file, then we've found a match
              if(currentSampleInManifest["sampleName"] == currentSampleName)
                # However, you're only allowed to have 1-to-1 match. Thus, if you have the same sample name matching multiple samples, then we raise an error.
                # Otherwise, we proceed.
                unless(foundSample)
                  # We convert the current biosample into nested tabbed format
                  individualBiosample = @producer.produce(currentBiosample).join("\n")
                  # We give the current biosample a name and then save it as a .tsv file
                  individualBiosampleName = "biosample_#{currentSampleName}.metadata.tsv"
                  File.open("#{@metadataDir}/#{individualBiosampleName}", 'w') { |file| file.write(individualBiosample) }
                  # We set the current sample's "biosampleMetadataFileName" field to be this .tsv file and then add it to our array of metadata files
                  currentSampleInManifest["biosampleMetadataFileName"] = individualBiosampleName
                  # Finally, we set foundSample to be true (since we found a matching sample)
                  foundSample = true
                else
                  errors << "The sample name given in your biosample metadata document (#{currentFile})\nmapped to multiple samples in your manifest file.\nThis is not allowed - please ensure a 1-to-1 correspondence\nbetween your biosample metadata document and a sample in your manifest file."
                end
              end
            }
            # If we didn't find a matching sample for the file name given in the metadata file, we raise an error
            unless(foundSample)
              errors << "The sample name given in your biosample metadata document (#{currentSampleName})\nunder \"Biosample.Name\" could not be found in your manifest file."
            end
          else
            errors << "We could not find a sample name in at least one of your biosample metadata documents\nThis document is, in order of value column, number #{docNo}.\nPlease ensure that you have correctly filled out the field \"- Name\"."
          end
        } 
        unless(errors.empty?)
          @errUserMsg = "There were some errors in parsing your multi-column biosample doc.\nA detailed list of errors can be found below:\n\n"
          @errUserMsg << errors.join("\n")
          raise @errUserMsg
        end
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There was an issue with separating your multi-column tabbed biosample file into individual biosample files.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 26
      end
      return @exitCode
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
          @errUserMsg = "ApiCaller failed: call to grab autoID for property #{property} in collection #{coll} failed.\nPlease contact a Genboree admin for help."
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "ApiCaller failed to grab autoID for property #{property} in collection #{coll}: #{apiCaller.respBody.inspect}")
          raise @errUserMsg
        end
        # Return newly generated ID
        currentID = apiCaller.parseRespBody["data"]["text"]
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There was an issue with grabbing an autoID for #{property} in #{coll}.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 56
      end
      return currentID
    end

    # Loads metadata files into respective hashes
    # @return [Fixnum] exit code indicating whether metadata loading was successful (0) or failed (27)
    def loadMetadataFiles()
      begin
        # The errors array will keep track of any errors that pop up when loading metadata files / generating IDs for each metadata file
        errors = [] 
        #### ANALYSIS DOCUMENT ####
        # Create hash for analysis metadata file: file name => KB doc of file 
        @analysisMetadataFile = {"#{@metadataDir}/#{@fileData["analysisMetadataFileName"]}" => BRL::Genboree::KB::KbDoc.new(@converter.parse(File.open("#{@metadataDir}/#{@fileData["analysisMetadataFileName"]}", 'r')))}
        # Report if any errors occurred during conversion of file to KB doc
        unless(@converter.errors.empty?)
          errors << "There was an error in importing your analysis doc named #{@fileData["analysisMetadataFileName"]}.\nAre you sure that you followed the required model for analysis documents?\nPlease double check using the template found here:\nhttp://genboree.org/theCommons/attachments/5039/Analyses.template.tsv\nA list of errors can be found below:\n\n#{@converter.errorSummaryStr}"
        else
          # Report if root property of document is NOT "Analysis" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Analysis" root property
          unless(@analysisMetadataFile.values[0].getRootProp() == "Analysis")
            errors << "Your analysis document named #{@fileData["analysisMetadataFileName"]} does not have the required root property of Analysis.\nPlease make sure that your analysis document contains this root property, and then resubmit your files."
          else
            currentID = @analysisMetadataFile.values[0].getRootPropVal()
            # If user didn't supply an ID for analysis doc, generate one. We will also insert the PI's ID into the doc ID (after EXR-).
            if(currentID.nil? or currentID.empty?)
              currentID = grabAutoID("Analysis", @analysisCollection)
              raise @errUserMsg unless(@exitCode == 0)
              currentID.insert(4, @piID)
              @analysisMetadataFile.values[0].setPropVal("Analysis", currentID)
            else
              # User supplied ID for analysis doc - add PI's ID to doc ID if doc ID doesn't already contain it
              unless(currentID[4, @piID.length] == @piID and currentID.length >= 4)
                currentID.insert(4, @piID)
                @analysisMetadataFile.values[0].setPropVal("Analysis", currentID)
              end
            end
            # Save final ID in @analysisID
            @analysisID = @analysisMetadataFile.values[0].getPropVal("Analysis")
          end
        end
        #### RUN DOCUMENT ####
        # Create hash for run metadata file
        @runMetadataFile = {"#{@metadataDir}/#{@fileData["runMetadataFileName"]}" => BRL::Genboree::KB::KbDoc.new(@converter.parse(File.open("#{@metadataDir}/#{@fileData["runMetadataFileName"]}", 'r')))}
        # Report if any errors occurred during conversion of file to KB doc
        unless(@converter.errors.empty?)
          errors << "There was an error in importing your run doc named #{@fileData["runMetadataFileName"]}.\nAre you sure that you followed the required model for run documents?\nPlease double check using the template found here:\nhttp://genboree.org/theCommons/attachments/5041/Runs.template.tsv\nA list of errors can be found below:\n\n#{@converter.errorSummaryStr}"
        else
          # Report if root property of document is NOT "Run" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Run" root property
          unless(@runMetadataFile.values[0].getRootProp() == "Run")
            errors << "Your run document named #{@fileData["runMetadataFileName"]} does not have the required root property of Run.\nPlease make sure that your run document contains this root property, and then resubmit your files."        
          else
            currentID = @runMetadataFile.values[0].getRootPropVal()
            # If user didn't supply an ID for run doc, generate one. We will also insert the PI's ID into the doc ID (after EXR-).
            if(currentID.nil? or currentID.empty?)
              currentID = grabAutoID("Run", @runCollection)
              raise @errUserMsg unless(@exitCode == 0)
              currentID.insert(4, @piID)
              @runMetadataFile.values[0].setPropVal("Run", currentID)
            else
              # User supplied ID for analysis doc - add PI's ID to doc ID if doc ID doesn't already contain it
              unless(currentID[4, @piID.length] == @piID and currentID.length > 4)
                currentID.insert(4, @piID)
                @runMetadataFile.values[0].setPropVal("Run", currentID)
              end
            end
            # Save final ID in @runID
            @runID = @runMetadataFile.values[0].getPropVal("Run")
          end
        end
        #### STUDY DOCUMENT ####
        # Create hash for study metadata file: file name => KB doc of file 
        @studyMetadataFile = {"#{@metadataDir}/#{@fileData["studyMetadataFileName"]}" => BRL::Genboree::KB::KbDoc.new(@converter.parse(File.open("#{@metadataDir}/#{@fileData["studyMetadataFileName"]}", 'r')))}
        # Report if any errors occurred during conversion from file to KB doc
        unless(@converter.errors.empty?)
          errors << "There was an error in importing your study doc named #{@fileData["studyMetadataFileName"]}.\nAre you sure that you followed the required model for study documents?\nPlease double check using the template found here:\nhttp://genboree.org/theCommons/attachments/5037/Studies.template.tsv\nA list of errors can be found below:\n\n#{@converter.errorSummaryStr}"
        else
          # Report if root property of document is NOT "Study" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Study" root property
          unless(@studyMetadataFile.values[0].getRootProp() == "Study")
            errors << "Your study document named #{@fileData["studyMetadataFileName"]} does not have the required root property of Study.\nPlease make sure that your study document contains this root property, and then resubmit your files."        
          else
            currentID = @studyMetadataFile.values[0].getRootPropVal()
            # If user didn't supply an ID for study doc, generate one. We will also insert the PI's ID into the doc ID (after EXR-).
            if(currentID.nil? or currentID.empty?)
              currentID = grabAutoID("Study", @studyCollection)
              raise @errUserMsg unless(@exitCode == 0)
              currentID.insert(4, @piID)
              @studyMetadataFile.values[0].setPropVal("Study", currentID)
            else
              # User supplied ID for study doc - add PI's ID to doc ID if doc ID doesn't already contain it
              unless(currentID[4, @piID.length] == @piID and currentID.length > 4)
                currentID.insert(4, @piID)
                @studyMetadataFile.values[0].setPropVal("Study", currentID)
              end
            end
            # Save final ID in @studyID
            @studyID = @studyMetadataFile.values[0].getPropVal("Study")
          end
        end
        #### SUBMISSION DOCUMENT ####
        # Create hash for submission metadata file: file name => KB doc of file 
        @submissionMetadataFile = {"#{@metadataDir}/#{@fileData["submissionMetadataFileName"]}" => BRL::Genboree::KB::KbDoc.new(@converter.parse(File.open("#{@metadataDir}/#{@fileData["submissionMetadataFileName"]}", 'r')))}
        # Report if any errors occurred during conversion
        unless(@converter.errors.empty?)
          errors << "There was an error in importing your submission doc named #{@fileData["submissionMetadataFileName"]}.\nAre you sure that you followed the required model for submission documents?\nPlease double check using the template found here:\nhttp://genboree.org/theCommons/attachments/5040/Submissions.template.tsv\nA list of errors can be found below:\n\n#{@converter.errorSummaryStr}"
        else
          # Report if root property of document is NOT "Submission" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Submission" root property
          unless(@submissionMetadataFile.values[0].getRootProp() == "Submission")
            errors << "Your submission document named #{@fileData["submissionMetadataFileName"]} does not have the required root property of Submission.\nPlease make sure that your submission document contains this root property, and then resubmit your files."        
          else
            currentID = @submissionMetadataFile.values[0].getRootPropVal()
            # If user didn't supply an ID for submission doc, generate one. We will also insert the PI's ID into the doc ID (after EXR-).
            if(currentID.nil? or currentID.empty?)
              currentID = grabAutoID("Submission", @submissionCollection)
              raise @errUserMsg unless(@exitCode == 0)
              currentID.insert(4, @piID)
              @submissionMetadataFile.values[0].setPropVal("Submission", currentID)
            else
              # User supplied ID for submission doc - add PI's ID to doc ID if doc ID doesn't already contain it
              unless(currentID[4, @piID.length] == @piID and currentID.length > 4)
                currentID.insert(4, @piID)
                @submissionMetadataFile.values[0].setPropVal("Submission", currentID)
              end
            end
            # Save final ID in @submissionID
            @submissionID = @submissionMetadataFile.values[0].getPropVal("Submission")
          end
        end
        #### DONOR DOCUMENT (GENERAL) ####
        # Add more general donor document (above individual samples) to @donorMetadataFiles and @donorIDs if it exists
        if(@fileData["donorMetadataFileName"])
          currentDonorMetadataFile = {"#{@metadataDir}/#{@fileData["donorMetadataFileName"]}" => BRL::Genboree::KB::KbDoc.new(@converter.parse(File.open("#{@metadataDir}/#{@fileData["donorMetadataFileName"]}", 'r')))}
          # Report if any errors occurred during conversion
          unless(@converter.errors.empty?)
            errors << "There was an error in importing your donor doc named #{@fileData["donorMetadataFileName"]}.\nAre you sure that you followed the required model for donor documents?\nPlease double check using the template found here:\nhttp://genboree.org/theCommons/attachments/5036/Donors.template.tsv\nA list of errors can be found below:\n\n#{@converter.errorSummaryStr}"
          else
            # Report if root property of document is NOT "Donor" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Donor" root property          
            unless(currentDonorMetadataFile.values[0].getRootProp() == "Donor")
              errors << "Your donor document named #{@fileData["donorMetadataFileName"]} does not have the required root property of Donor.\nPlease make sure that your donor document contains this root property, and then resubmit your files."        
            else
              currentID = currentDonorMetadataFile.values[0].getRootPropVal()
              # If user didn't supply an ID for donor doc, generate one. We will also insert the PI's ID into the doc ID (after EXR-).
              if(currentID.nil? or currentID.empty?)
                currentID = grabAutoID("Donor", @donorCollection)
                raise @errUserMsg unless(@exitCode == 0)
                currentID.insert(4, @piID)
                currentDonorMetadataFile.values[0].setPropVal("Donor", currentID)
              else
                # User supplied ID for donor doc - add PI's ID to doc ID if doc ID doesn't already contain it
                unless(currentID[4, @piID.length] == @piID and currentID.length > 4)
                  currentID.insert(4, @piID)
                  currentDonorMetadataFile.values[0].setPropVal("Donor", currentID)
                end
              end
              @donorMetadataFiles.merge!(currentDonorMetadataFile)
              currentDonorID = currentDonorMetadataFile.values[0].getPropVal("Donor")
              @donorIDs << currentDonorID
            end
          end
        end
        #### EXPERIMENT DOCUMENT (GENERAL) ####
        # Add more general experiment document (above individual samples) to @experimentMetadataFiles and @experimentIDs if it exists
        if(@fileData["experimentMetadataFileName"])
          currentExperimentMetadataFile = {"#{@metadataDir}/#{@fileData["experimentMetadataFileName"]}" => BRL::Genboree::KB::KbDoc.new(@converter.parse(File.open("#{@metadataDir}/#{@fileData["experimentMetadataFileName"]}", 'r')))}
          # Report if any errors occurred during conversion
          unless(@converter.errors.empty?)
            errors << "There was an error in importing your experiment doc named #{@fileData["experimentMetadataFileName"]}.\nAre you sure that you followed the required model for experiment documents?\nPlease double check using the template found here:\nhttp://genboree.org/theCommons/attachments/5043/Experiments.template.tsv\nA list of errors can be found below:\n\n#{@converter.errorSummaryStr}"
          else 
            # Report if root property of document is NOT "Experiment" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Experiment" root property
            unless(currentExperimentMetadataFile.values[0].getRootProp() == "Experiment")
              errors << "Your experiment document named #{@fileData["experimentMetadataFileName"]} does not have the required root property of Experiment.\nPlease make sure that your experiment document contains this root property, and then resubmit your files.\n"        
            else
              currentID = currentExperimentMetadataFile.values[0].getRootPropVal()
              # If user didn't supply an ID for experiment doc, generate one. We will also insert the PI's ID into the doc ID (after EXR-).
              if(currentID.nil? or currentID.empty?)
                currentID = grabAutoID("Experiment", @experimentCollection)
                raise @errUserMsg unless(@exitCode == 0)
                currentID.insert(4, @piID)
                currentExperimentMetadataFile.values[0].setPropVal("Experiment", currentID)
              else
                # User supplied ID for experiment doc - add PI's ID to doc ID if doc ID doesn't already contain it
                unless(currentID[4, @piID.length] == @piID and currentID.length > 4)
                  currentID.insert(4, @piID)
                  currentExperimentMetadataFile.values[0].setPropVal("Experiment", currentID)
                end
              end
              @experimentMetadataFiles.merge!(currentExperimentMetadataFile)
              currentExperimentID = currentExperimentMetadataFile.values[0].getPropVal("Experiment")
              @experimentIDs << currentExperimentID
            end
          end
        end
        # Traverse each sample and load biosample / donor / experiment metadata docs
        @manifest.each { |eachSample|
          #### DONOR DOCUMENT (SAMPLE-SPECIFIC) ####
          if(eachSample["donorMetadataFileName"])
            currentDonorMetadataFile = {"#{@metadataDir}/#{eachSample["donorMetadataFileName"]}" => BRL::Genboree::KB::KbDoc.new(@converter.parse(File.open("#{@metadataDir}/#{eachSample["donorMetadataFileName"]}", 'r')))}
            # Report if any errors occurred during conversion
            unless(@converter.errors.empty?)
              errors << "There was an error in importing your donor doc named #{eachSample["donorMetadataFileName"]}.\nAre you sure that you followed the required model for donor documents?\nPlease double check using the template found here:\nhttp://genboree.org/theCommons/attachments/5036/Donors.template.tsv\nA list of errors can be found below:\n\n#{@converter.errorSummaryStr}"
            else
              # Report if root property of document is NOT "Donor" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Donor" root property          
              unless(currentDonorMetadataFile.values[0].getRootProp() == "Donor")
                errors << "Your donor document named #{eachSample["donorMetadataFileName"]} does not have the required root property of Donor.\nPlease make sure that your donor document contains this root property, and then resubmit your files.\n"        
              else
                currentID = currentDonorMetadataFile.values[0].getRootPropVal()
                # If user didn't supply an ID for donor doc, generate one. We will also insert the PI's ID into the doc ID (after EXR-).
                if(currentID.nil? or currentID.empty?)
                  currentID = grabAutoID("Donor", @donorCollection)
                  raise @errUserMsg unless(@exitCode == 0)
                  currentID.insert(4, @piID)
                  currentDonorMetadataFile.values[0].setPropVal("Donor", currentID)
                else
                  # User supplied ID for donor doc - add PI's ID to doc ID if doc ID doesn't already contain it
                  unless(currentID[4, @piID.length] == @piID and currentID.length > 4)
                    currentID.insert(4, @piID)
                    currentDonorMetadataFile.values[0].setPropVal("Donor", currentID)
                  end
                end
                @donorMetadataFiles.merge!(currentDonorMetadataFile)
                currentDonorID = currentDonorMetadataFile.values[0].getPropVal("Donor")
                @donorIDs << currentDonorID
              end
            end
          end
          #### EXPERIMENT DOCUMENT (SAMPLE-SPECIFIC) ####
          if(eachSample["experimentMetadataFileName"])
            currentExperimentMetadataFile = {"#{@metadataDir}/#{eachSample["experimentMetadataFileName"]}" => BRL::Genboree::KB::KbDoc.new(@converter.parse(File.open("#{@metadataDir}/#{eachSample["experimentMetadataFileName"]}", 'r')))}
            # Report if any errors occurred during conversion
            unless(@converter.errors.empty?)
              errors << "There was an error in importing your experiment doc named #{eachSample["experimentMetadataFileName"]}.\nAre you sure that you followed the required model for experiment documents?\nPlease double check using the template found here:\nhttp://genboree.org/theCommons/attachments/5043/Experiments.template.tsv\nA list of errors can be found below:\n\n#{@converter.errorSummaryStr}"
            else
              # Report if root property of document is NOT "Experiment" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Experiment" root property
              unless(currentExperimentMetadataFile.values[0].getRootProp() == "Experiment")
                errors << "Your experiment document named #{eachSample["experimentMetadataFileName"]} does not have the required root property of Experiment.\nPlease make sure that your experiment document contains this root property, and then resubmit your files.\n"        
              else
                currentID = currentExperimentMetadataFile.values[0].getRootPropVal()
                # If user didn't supply an ID for experiment doc, generate one. We will also insert the PI's ID into the doc ID (after EXR-).
                if(currentID.nil? or currentID.empty?)
                  currentID = grabAutoID("Experiment", @experimentCollection)
                  raise @errUserMsg unless(@exitCode == 0)
                  currentID.insert(4, @piID)
                  currentExperimentMetadataFile.values[0].setPropVal("Experiment", currentID)
                else
                  # User supplied ID for experiment doc - add PI's ID to doc ID if doc ID doesn't already contain it
                  unless(currentID[4, @piID.length] == @piID and currentID.length > 4)
                    currentID.insert(4, @piID)
                    currentExperimentMetadataFile.values[0].setPropVal("Experiment", currentID)
                  end
                end
                @experimentMetadataFiles.merge!(currentExperimentMetadataFile)
                currentExperimentID = currentExperimentMetadataFile.values[0].getPropVal("Experiment")
                @experimentIDs << currentExperimentID
              end
            end
          end
          #### BIOSAMPLE DOCUMENT ####
          currentBiosampleMetadataFile = {"#{@metadataDir}/#{eachSample["biosampleMetadataFileName"]}" => BRL::Genboree::KB::KbDoc.new(@converter.parse(File.open("#{@metadataDir}/#{eachSample["biosampleMetadataFileName"]}", 'r')))}
          # Report if any errors occurred during conversion
          unless(@converter.errors.empty?)
            errors << "There was an error in importing your biosample doc named #{eachSample["biosampleMetadataFileName"]}.\nAre you sure that you followed the required model for biosample documents?\nPlease double check using the template found here:\nhttp://genboree.org/theCommons/attachments/5035/Biosamples.template.tsv\nA list of errors can be found below:\n\n#{@converter.errorSummaryStr}"
          else
            # Report if root property of document is NOT "Biosample" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Biosample" root property
            unless(currentBiosampleMetadataFile.values[0].getRootProp() == "Biosample")
              errors << "Your biosample document named #{eachSample["biosampleMetadataFileName"]} does not have the required root property of Biosample.\nPlease make sure that your biosample document contains this root property, and then resubmit your files.\n"        
            else
              currentID = currentBiosampleMetadataFile.values[0].getRootPropVal()
              # If user didn't supply an ID for biosample doc, generate one. We will also insert the PI's ID into the doc ID (after EXR-).
              if(currentID.nil? or currentID.empty?)
                currentID = grabAutoID("Biosample", @biosampleCollection)
                raise @errUserMsg unless(@exitCode == 0)
                currentID.insert(4, @piID)
                currentBiosampleMetadataFile.values[0].setPropVal("Biosample", currentID)
              else
                # User supplied ID for biosample doc - add PI's ID to doc ID if doc ID doesn't already contain it
                unless(currentID[4, @piID.length] == @piID and currentID.length > 4)
                  currentID.insert(4, @piID)
                  currentBiosampleMetadataFile.values[0].setPropVal("Biosample", currentID)
                end
              end
              @biosampleMetadataFiles.merge!(currentBiosampleMetadataFile)
              currentBiosampleID = currentBiosampleMetadataFile.values[0].getPropVal("Biosample")
              @biosampleIDs << currentBiosampleID
            end
          end
        }
        unless(errors.empty?)
          @errUserMsg = "There were some errors with importing your documents.\nSpecific error messages can be found below:\n\n#{errors.join("\n")}"
          raise @errUserMsg
        end
        # Add all metadata documents to @metadataFiles
        @metadataFiles << @analysisMetadataFile
        @metadataFiles << @runMetadataFile
        @metadataFiles << @studyMetadataFile
        @metadataFiles << @submissionMetadataFile
        @metadataFiles << @donorMetadataFiles
        @metadataFiles << @experimentMetadataFiles
        @metadataFiles << @biosampleMetadataFiles
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with loading your metadata files.\nAre you sure that all of your files are in compact nested tabbed format?\nPlease make sure that each of your metadata files contains a #property column and value column.\nExamine the templates on the exRNA Wiki\n(http://genboree.org/theCommons/projects/exrna-mads/wiki/exRNA%20Metadata%20Standards)\nfor examples of proper nested compact tabbed format." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 27
      end
      return @exitCode
    end

    # Fills in donor / experiment info for each biosample
    # @return [Fixnum] exit code indicating whether filling in biosample docs succeeded (0) or failed (28)
    def fillInBiosampleDocs()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adding experiment and donor information to biosample metadata documents")
        @manifest.each { |eachSampleHash|
          # Grab current biosample, experiment, and donor kb docs
          currentBioKbDoc = @biosampleMetadataFiles["#{@metadataDir}/#{eachSampleHash["biosampleMetadataFileName"]}"]
          currentExpKbDoc = (@experimentMetadataFiles["#{@metadataDir}/#{eachSampleHash["experimentMetadataFileName"]}"] ? @experimentMetadataFiles["#{@metadataDir}/#{eachSampleHash["experimentMetadataFileName"]}"] : @experimentMetadataFiles["#{@metadataDir}/#{@fileData["experimentMetadataFileName"]}"])
          currentDonorKbDoc = (@donorMetadataFiles["#{@metadataDir}/#{eachSampleHash["donorMetadataFileName"]}"] ? @donorMetadataFiles["#{@metadataDir}/#{eachSampleHash["donorMetadataFileName"]}"] : @donorMetadataFiles["#{@metadataDir}/#{@fileData["donorMetadataFileName"]}"])
          # Create "Related Experiments" item list in biosample doc
          currentBioKbDoc.setPropVal("Biosample.Related Experiments", "")
          # Creating related experiment doc to insert into biosample doc as an item
          addedExpKbDoc = BRL::Genboree::KB::KbDoc.new({})
          addedExpKbDoc.setPropVal("Related Experiment", currentExpKbDoc.getRootPropVal())
          addedExpKbDoc.setPropVal("Related Experiment.DocURL", "coll/#{@experimentCollection}/doc/#{currentExpKbDoc.getRootPropVal()}")
          # We will check to see if an experiment doc with the ID grabbed above is already listed in related experiments for this biosample.
          # If it is already listed, then we will not add it again!
          foundExperiment = false
          currentItems = currentBioKbDoc.getPropItems("Biosample.Related Experiments")
          if(currentItems)
            currentItems.each { |currentRelExp|
              # Add PI prefix to each item if it's not already there (to fix IDs inserted by user)
              currentRelExp["Related Experiment"]["value"].insert(4, @piID) unless(currentRelExp["Related Experiment"]["value"][4, @piID.length] == @piID and currentRelExp["Related Experiment"]["value"].length > 4)
              # Check whether current related experiment has doc URL as subproperty.
              # If we already have other subproperties (not possible currently, but maybe in the future!), then we add it to the list of subproperties.
              # Otherwise, we set it as the only subproperty
              if(currentRelExp["Related Experiment"]["properties"])
                currentRelExp["Related Experiment"]["properties"].store("DocURL", {"value"=>"coll/#{@experimentCollection}/doc/#{currentRelExp["Related Experiment"]["value"]}"})
              else 
                currentRelExp["Related Experiment"]["properties"] = {"DocURL"=>{"value"=>"coll/#{@experimentCollection}/doc/#{currentRelExp["Related Experiment"]["value"]}"}}
              end 
              # Set foundExperiment to be true if we found a match
              foundExperiment = true if(currentRelExp["Related Experiment"]["value"] == currentExpKbDoc.getRootPropVal())
            }
          end
          # Add related experiment doc to biosample doc
          currentBioKbDoc.addPropItem("Biosample.Related Experiments", addedExpKbDoc) unless(foundExperiment)
          # Placing info about donor into biosample doc
          currentBioKbDoc.setPropVal("Biosample.Donor ID", currentDonorKbDoc.getRootPropVal())
          currentBioKbDoc.setPropVal("Biosample.Donor ID.DocURL", "coll/#{@donorCollection}/doc/#{currentDonorKbDoc.getRootPropVal()}")
        }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done adding experiment and donor information to biosample metadata documents")
      rescue => err 
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in donor / experiment information for your biosample metadata documents.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 28
      end
      return @exitCode
    end
 
    # Fills in run doc with appropriate info (info about different samples, related studies)  
    # @param [Fixnum] noSamples number of samples we want to set "Run.Raw Data Files" to-1
    # @return [Fixnum] exit code indicating whether filling in run doc succeeded (0) or failed (29)
    def fillInRunDoc(noSamples)
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adding information about biosamples and study to run metadata document")
        runKbDoc = @runMetadataFile.values[0]
        # Number of raw data files will be set to number of samples that were successfully processed through pipeline (unsuccessful samples will not be added!)
        runKbDoc.setPropVal("Run.Raw Data Files", noSamples)
        # Clear out user-submitted data files (we only care about successful samples from THIS pipeline run)
        runKbDoc.delPropItems("Run.Raw Data Files")
        errorMessages = ""
        # We will add information about each successful sample as an item
        @biosampleMetadataFiles.each_value { |currentBioKbDoc|
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
          # Create a new doc that will be inserted into "Run.Raw Data Files" as an item. We will fill in various bits of information about the sample before we add it.
          currentSampleInRun = BRL::Genboree::KB::KbDoc.new({})
          fileID = grabAutoID("Run.Raw Data Files.File ID", @runCollection)
          raise @errUserMsg unless(@exitCode == 0)
          currentSampleInRun.setPropVal("File ID", fileID)
          currentSampleInRun.setPropVal("File ID.File Name", fileName)
          currentSampleInRun.setPropVal("File ID.Biosample ID", biosampleID)
          currentSampleInRun.setPropVal("File ID.DocURL", "coll/#{@biosampleCollection}/doc/#{biosampleID}")
          # The file type below is a dummy value. We cannot fill out this info accurately the first time we run this method because it is run before the data archive is downloaded.
          # We will fill out this info accurately after the data archive is downloaded by using the fillInFileTypeForRunDoc method.
          currentSampleInRun.setPropVal("File ID.Type", "FASTQ")
          # Finally, we add the biosample as an item in the "Run.Raw Data Files" item list
          runKbDoc.addPropItem("Run.Raw Data Files", currentSampleInRun)
        }
        unless(errorMessages.empty?)
          errorMessages.insert(0, "There were some errors when connecting your biosample metadata documents to the manifest file.\nSpecific messages can be found below:\n\n")
          @errUserMsg = errorMessages
          raise @errUserMsg
        end
        # We will add a link to the submitted study document in the "Related Studies" item list (if it's not already there)
        relatedStudy = BRL::Genboree::KB::KbDoc.new({})
        relatedStudy.setPropVal("Related Study", @studyID)
        relatedStudy.setPropVal("Related Study.DocURL", "coll/#{@studyCollection}/doc/#{@studyID}")
        runKbDoc.setPropVal("Run.Related Studies", "")
        foundStudy = false
        currentStudies = runKbDoc.getPropItems("Run.Related Studies")
        if(currentStudies)
          currentStudies.each { |currentStudy|
            currentStudy["Related Study"]["value"].insert(4, @piID) unless(currentStudy["Related Study"]["value"][4, @piID.length] == @piID and currentStudy["Related Study"]["value"].length > 4)
            if(currentStudy["Related Study"]["properties"])
              currentStudy["Related Study"]["properties"].store("DocURL", {"value"=>"coll/#{@studyCollection}/doc/#{currentStudy["Related Study"]["value"]}"})
            else 
              currentStudy["Related Study"]["properties"] = {"DocURL"=>{"value"=>"coll/#{@studyCollection}/doc/#{currentStudy["Related Study"]["value"]}"}}
            end 
            foundStudy = true if(currentStudy["Related Study"]["value"] == @studyID)
          }
        end
        runKbDoc.addPropItem("Run.Related Studies", relatedStudy) unless(foundStudy)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done adding information about biosamples and study to run metadata document")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in biosample / study information for your run metadata document.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
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
            # If we find a match between the biosample kb doc's sample name and the manifest's sample name, then we proceed
            if(currentSampleInManifest["sampleName"] == sampleName)
              # fileName will hold the data file name associated with that sample in the manifest
              fileName = currentSampleInManifest["dataFileName"]
              # We traverse all the input files and figure out which one has the same name (compressed or uncompressed) as fileName
              # If we find a match, then we look at :fileType for that input file to find the sniffed file type
              newName = ""
              md5 = "" 
              @inputFiles.each_key { |currentInputFile|
                if(fileName == File.basename(currentInputFile) or fileName == @inputFiles[currentInputFile][:originalFileName])
                  fileType = @inputFiles[currentInputFile][:fileType]
                  newName = File.basename(currentInputFile)
                  md5 = @inputFiles[currentInputFile][:md5]
                end 
              }
              # If fileType is still empty, then we failed to find a match and we must raise an error
              if(fileType.empty?)
                errorMessages << "We could not find the file type of the input file #{fileName}.\nAre you sure that you wrote the right name for your sample in the \"dataFileName\" field?\n\n"
                next 
              end
              # We figure out which entry in "Run.Raw Data Files" matches our current file name and then update the file type associated with that entry
              allSamplesInRunDoc = @runMetadataFile.values[0].getPropItems("Run.Raw Data Files")
              allSamplesInRunDoc.each { |currentItem|
                currentItem = BRL::Genboree::KB::KbDoc.new(currentItem)
                if(currentItem.getPropVal("File ID.File Name") == fileName)
                  currentItem.setPropVal("File ID.File Name", newName)
                  if(fileType == "FASTQ")
                    currentItem.setPropVal("File ID.Type", fileType)
                  else
                    currentItem.setPropVal("File ID.Type", "FASTQ-like format")
                    currentItem.setPropVal("File ID.Type.Other", fileType)
                  end
                  currentItem.setPropVal("File ID.MD5 Checksum", md5)
                end
              }
              @runMetadataFile.values[0].setPropItems("Run.Raw Data Files", allSamplesInRunDoc)
            end
          }
        }
        # We raise an error if we found any errors above
        unless(errorMessages.empty?)
          @errUserMsg = errorMessages
          raise @errUserMsg
        end
      rescue => err
        @errUserMsg = "ERROR: There was an issue with finding the file type(s) of your submitted data documents.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 51
      end
      return @exitCode
    end 

    # Fills in study doc with info about related submission
    # @return [Fixnum] exit code indicating whether filling in study doc succeeded (0) or failed (30)
    def fillInStudyDoc()
      begin 
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adding information about submission to study metadata file")
        studyKbDoc = @studyMetadataFile.values[0]
        # We will add a link to the submission doc in the "Related Submissions" item list (if it's not already there)
        studyKbDoc.setPropVal("Study.Related Submissions", "")
        relatedSubmission = BRL::Genboree::KB::KbDoc.new({})
        relatedSubmission.setPropVal("Related Submission", @submissionID)
        relatedSubmission.setPropVal("Related Submission.DocURL", "coll/#{@submissionCollection}/doc/#{@submissionID}")
        foundSubmission = false
        currentSubmissions = studyKbDoc.getPropItems("Study.Related Submissions")
        if(currentSubmissions)
          currentSubmissions.each { |currentSubmission|
            currentSubmission["Related Submission"]["value"].insert(4, @piID) unless(currentSubmission["Related Submission"]["value"][4, @piID.length] == @piID and currentSubmission["Related Submission"]["value"].length > 4)
              if(currentSubmission["Related Submission"]["properties"])
                currentSubmission["Related Submission"]["properties"].store("DocURL", {"value"=>"coll/#{@submissionCollection}/doc/#{currentSubmission["Related Submission"]["value"]}"})
              else 
                currentSubmission["Related Submission"]["properties"] = {"DocURL"=>{"value"=>"coll/#{@submissionCollection}/doc/#{currentSubmission["Related Submission"]["value"]}"}}
              end            
            foundSubmission = true if(currentSubmission["Related Submission"]["value"] == @submissionID)
          }
        end
        studyKbDoc.addPropItem("Study.Related Submissions", relatedSubmission) unless(foundSubmission)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done adding information about submission to study metadata file")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in submission information for your study metadata document.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 30
      end
      return @exitCode
    end

    # Fills in submission doc with info about PI / submitter
    # @return [Fixnum] exit code indicating whether filling in submission doc succeeded (0) or failed (31)
    def fillInSubmissionDoc()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adding information about PI / submitter to submission metadata file")
        # Grab submission document
        submissionKbDoc = @submissionMetadataFile.values[0]
        # Grab master list of PIs / submitters from exRNA KB
        rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}"
        apiCaller = WrapperApiCaller.new(@exRNAHost, rsrcPath, @subUserId)
        groupName = @exRNAKbGroup
        kbName = @exRNAKb
        collName = @piCollection
        docName = "EXR-MASTERLIST-PI"
        apiCaller.get({:doc => docName, :coll => collName, :kb => kbName, :grp => groupName})
        masterList = BRL::Genboree::KB::KbDoc.new(apiCaller.parseRespBody["data"])
        # Traverse individual PIs in the master list until we find the PI associated with our submission (as dictated by the PI ID in the FTP directory name)
        individualPIs = masterList.getPropItems("ERCC PI.List of ERCC PIs")
        individualPIs.each { |currentPI|
          currentPI = BRL::Genboree::KB::KbDoc.new(currentPI)
          currentPICode = currentPI.getPropVal("PI Code")
          # If we find the PI in the master list that matches our current PI, then we fill in our Submission document with information about that PI.
          if(currentPICode == "EXR-#{@piID}-PI")
            submissionKbDoc.setPropVal("Submission.Principal Investigator", currentPICode)
            submissionKbDoc.setPropVal("Submission.Principal Investigator.First Name", currentPI.getPropVal("PI Code.PI First Name")) if(submissionKbDoc.getPropVal("Submission.Principal Investigator.First Name").nil? or submissionKbDoc.getPropVal("Submission.Principal Investigator.First Name").empty?)
            submissionKbDoc.setPropVal("Submission.Principal Investigator.Last Name", currentPI.getPropVal("PI Code.PI Last Name")) if(submissionKbDoc.getPropVal("Submission.Principal Investigator.Last Name").nil? or submissionKbDoc.getPropVal("Submission.Principal Investigator.Last Name").empty?)
            submissionKbDoc.setPropVal("Submission.Principal Investigator.Email", currentPI.getPropVal("PI Code.PI Email")) if(submissionKbDoc.getPropVal("Submission.Principal Investigator.Email").nil? or submissionKbDoc.getPropVal("Submission.Principal Investigator.Email").empty?)
            submissionKbDoc.setPropVal("Submission.Organization", currentPI.getPropVal("PI Code.Organization")) if(submissionKbDoc.getPropVal("Submission.Organization").nil? or submissionKbDoc.getPropVal("Submission.Organization").empty?)
            # Next, we traverse all submitters associated with that PI in the master list to find our submitter.
            individualSubmitters = currentPI.getPropItems("PI Code.Submitters")
            individualSubmitters.each { |currentSubmitter|
              currentSubmitter = BRL::Genboree::KB::KbDoc.new(currentSubmitter)
              submitterLogin = currentSubmitter.getPropVal("Submitter ID.Submitter Login")
              # If we find the submitter in the master list that matches our current submitter (login name is used), then we fill in our Submission document with information about that submitter.
              if(submitterLogin == @subUserLogin)
                submissionKbDoc.setPropVal("Submission.Submitter", currentSubmitter.getPropVal("Submitter ID"))
                submissionKbDoc.setPropVal("Submission.Submitter.First Name", currentSubmitter.getPropVal("Submitter ID.Submitter Login.First Name")) if(submissionKbDoc.getPropVal("Submission.Submitter.First Name").nil? or submissionKbDoc.getPropVal("Submission.Submitter.First Name").empty?)
                submissionKbDoc.setPropVal("Submission.Submitter.Last Name", currentSubmitter.getPropVal("Submitter ID.Submitter Login.Last Name")) if(submissionKbDoc.getPropVal("Submission.Submitter.Last Name").nil? or submissionKbDoc.getPropVal("Submission.Submitter.Last Name").empty?)
                submissionKbDoc.setPropVal("Submission.Submitter.Email", currentSubmitter.getPropVal("Submitter ID.Submitter Login.Email")) if(submissionKbDoc.getPropVal("Submission.Submitter.Email").nil? or submissionKbDoc.getPropVal("Submission.Submitter.Email").empty?)
              end
            }  
          end
        } 
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done adding information about PI / submitter to submission metadata file")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in PI / submitter information for your submission metadata document.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 31
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
        # Set up all related documents for job doc (run, submission, study, analysis, experiments, and biosamples)
        jobDoc.setPropVal("Job", @jobId)
        jobDoc.setPropVal("Job.Status", "Add")
        jobDoc.setPropVal("Job.Related Run", @runID)
        jobDoc.setPropVal("Job.Related Run.DocURL", "coll/#{@runCollection}/doc/#{@runID}")
        jobDoc.setPropVal("Job.Related Submission", @submissionID) 
        jobDoc.setPropVal("Job.Related Submission.DocURL", "coll/#{@submissionCollection}/doc/#{@submissionID}")
        jobDoc.setPropVal("Job.Related Study", @studyID) 
        jobDoc.setPropVal("Job.Related Study.DocURL", "coll/#{@studyCollection}/doc/#{@studyID}")
        jobDoc.setPropVal("Job.Related Analysis", @analysisID) 
        jobDoc.setPropVal("Job.Related Analysis.DocURL", "coll/#{@analysisCollection}/doc/#{@analysisID}")
        jobDoc.setPropVal("Job.Related Experiments", "")
        @experimentIDs.each { |currentID|
          currentIDDoc = BRL::Genboree::KB::KbDoc.new({})
          currentIDDoc.setPropVal("Related Experiment", currentID)
          currentIDDoc.setPropVal("Related Experiment.DocURL", "coll/#{@experimentCollection}/doc/#{currentID}")
          jobDoc.addPropItem("Job.Related Experiments", currentIDDoc)
        }
        jobDoc.setPropVal("Job.Related Biosamples", "")
        @biosampleIDs.each { |currentID|
          currentIDDoc = BRL::Genboree::KB::KbDoc.new({})
          currentIDDoc.setPropVal("Related Biosample", currentID)
          currentIDDoc.setPropVal("Related Biosample.DocURL", "coll/#{@biosampleCollection}/doc/#{currentID}")
          donorID = @biosampleToDonorAndResultFiles[currentID][0]
          currentIDDoc.setPropVal("Related Biosample.Related Donor", donorID)
          currentIDDoc.setPropVal("Related Biosample.Related Donor.DocURL", "coll/#{@donorCollection}/doc/#{donorID}")
          resultFilesID = @biosampleToDonorAndResultFiles[currentID][1]
          currentIDDoc.setPropVal("Related Biosample.Related Result Files", resultFilesID)
          currentIDDoc.setPropVal("Related Biosample.Related Result Files.DocURL", "coll/#{CGI.escape(@resultFilesCollection)}/doc/#{resultFilesID}")
          jobDoc.addPropItem("Job.Related Biosamples", currentIDDoc)
        }
        # After inserting all related docs, convert to nested tabbed format and save file
        jobMetadataFileName = "autoGeneratedJobDoc.metadata.tsv"
        @jobMetadataFile = {jobMetadataFileName => jobDoc}
        @metadataFiles << @jobMetadataFile
        updatedJobDoc = @producer.produce(jobDoc).join("\n")
        File.open("#{@metadataDir}/#{jobMetadataFileName}", 'w') { |file| file.write(updatedJobDoc) }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done adding information about metadata files to job metadata file")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in information for your job metadata document.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 40
      end
      return @exitCode
    end

    # Method that validates a given metadata doc and records errors in @metadataErrors
    # @param [String] currentMetadataFileNames current hash (studies, biosamples, runs, etc.) being checked (doc names => KB docs associated with those doc names)
    # @return [Fixnum] exit code indicating whether process of validation ran successfully (0) or failed (32)
    def validateMetadataDocs(currentMetadataFileNames)
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Validating #{currentMetadataFileNames.keys.inspect}")
        # Figure out what collection the documents belong to
        currentRootProp = currentMetadataFileNames.values[0].getRootProp
        coll = @collections[currentRootProp]
        # Set up the API to validate the docs
        rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/docs?detailed=true&save=false"
        apiCaller = WrapperApiCaller.new(@exRNAHost, rsrcPath, @subUserId)
        # Divide payload into sets of 10 docs so that normal put calls work - will not need to use this once we are using kbBulkUpload
        payload = currentMetadataFileNames.values
        payload = payload.each_slice(10).to_a
        payload.each { |currentPayload|
          apiCaller.put({:coll => coll, :kb => @exRNAKb, :grp => @exRNAKbGroup}, currentPayload.to_json)
          # If any docs are invalid, then we will report those errors to the user
          unless(apiCaller.parseRespBody["data"]["docs"]["properties"]["invalid"]["items"].empty?)
            # Grab each invalid doc
            apiCaller.parseRespBody["data"]["docs"]["properties"]["invalid"]["items"].each { |currentItem|
              # Grab the document ID (root property value) associated with current doc 
              currentID = currentItem["id"]["properties"]["doc"]["properties"][currentRootProp]["value"]
              # Figure out which file name has that document ID (we want to report this information to user)
              currentFileName = ""
              currentMetadataFileNames.each_key { |currentDoc|
                currentFileName = File.basename(currentDoc) if(currentID == currentMetadataFileNames[currentDoc].getRootPropVal())
              }
              # Grab error associated with current doc 
              docError = apiCaller.parseRespBody["data"]["docs"]["properties"]["invalid"]["items"][0]["id"]["properties"]["msg"]["value"]
              # Add file name and associated error to @metadataErrors
              @metadataErrors << "#{currentFileName}: #{docError}"
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "The doc #{currentFileName} has errors")
            }
          end
        }
        if(@metadataErrors.empty?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "the docs submitted to collection #{coll} do not have any errors")
        end
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with validating the following documents: #{currentMetadataFileNames.keys.inspect}.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 32
      end      
      return @exitCode
    end

    # Set up spike-in library (either given in data archive or set as value of "existingLibraryName"
    # @return [Fixnum] exit code indicating whether validator ran successfully (0) or failed (37)
    def setUpSpikeInLibrary() 
      begin
        # If @useLibrary is set to uploadNewLibrary or useExistingLibrary, then the user wants to use a spike-in library
        if(@useLibrary =~ /uploadNewLibrary/ or @useLibrary =~ /useExistingLibrary/)
          # If we're using a pre-existing library, then we need to download the FASTA file from the user database before we make
          # our Bowtie 2 indexes.  Otherwise, if we're uploading a new library, that means that the FASTA file was provided in the
          # data archive (so we don't need to download the FASTA file separately).
          if(@useLibrary =~ /useExistingLibrary/)
            if(@spikeInFile)
              @errUserMsg = "You included a FASTA file in your data archive, but you also set \"useLibrary\" to be \"useExistingLibrary\",\nindicating that you want to download a spike-in file from your Genboree database.\nYou should either delete the spike-in file from your data archive (recompute your MD5!) or set \"useLibrary\" to be \"uploadNewLibrary\"."
              raise @errUserMsg
            end
            # Download the custom FASTA file from user database, sniff to ensure it is FASTA, and expand if necessary
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading spike-in library file #{@spikeInUri}.")
            downloadSpikeInFile(@spikeInUri)
            raise @errUserMsg unless(@exitCode == 0)
          end
          # If we don't have a value for @spikeInFile at this point, it means that we don't have a spike-in file (and we should).
          # Thus, we raise an error.
          unless(@spikeInFile)
            @errUserMsg = "There was an error grabbing your spike-in file.\nIt is likely that you set \"useLibrary\" to have the value \"uploadNewLibrary\"\nbut didn't include a FASTA file in your submission.\nPlease delete the \"useLibrary\" field or set it to \"noOligo\"."
            raise @errUserMsg
          end
          # Make Bowtie 2 index of this oligo library
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Making Bowtie 2 index of spike-in library.")
          makeOligoBowtieIndex(@spikeInFile)
          raise @errUserMsg unless(@exitCode == 0)
          @calib = @oligoBowtie2BaseName
        # If user didn't set @useLibrary to uploadNewLibrary or useExistingLibrary, but still included a spike-in file (FASTA) in their data archive, then we raise an error - this isn't allowed
        elsif(@spikeInFile)
          @errUserMsg = "You included a FASTA file in your data archive but did not indicate in your manifest that you wanted to use\na spike-in sequence. Please set \"useLibrary\" to be \"uploadNewLibrary\" if you want to include a spike-in sequence in your data archive."
          raise @errUserMsg
        # If the user specified no spike-in library ("noOligo"), we will set @calib to be NULL.
        else 
          @calib = "NULL"
        end
        # Upload new spike-in library to Genboree Workbench (if user submitted it)
        if(@useLibrary =~ /uploadNewLibrary/)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading spike-in file #{@spikeInFile}")
          # Parse target URI for outputs
          targetUri = URI.parse(@outputDb)
          rsrcPath = "#{targetUri.path}/file/spikeInLibraries/{outputFile}/data?"
          rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
          uploadFile(targetUri.host, rsrcPath, @subUserId, @spikeInFile, {:outputFile => File.basename(@spikeInFile)})
        end
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with setting up your spike-in library.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 37
      end
    end

    # Make Bowtie 2 index of spike-in file
    # @param [String] spikeInFile file path to spike-in file
    # @return [Fixnum] exit code indicating whether Bowtie 2 index creation was successful (0) or failed (54)
    def makeOligoBowtieIndex(spikeInFile)
      begin 
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Using #{spikeInFile} to make bowtie2 index.")
        @outFile = "#{@scratchDir}/indexBowtie.out"
        @errFile = "#{@scratchDir}/indexBowtie.err"
        # Build Bowtie 2 index
        @oligoBowtie2BaseName = "#{@calibratorDir}/#{CGI.escape(@spikeInName)}"
        command = "bowtie2-build #{spikeInFile} #{@oligoBowtie2BaseName}"
        command << " > #{@outFile} 2> #{@errFile}"  
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
        exitStatus = system(command)
        # Raise error if Bowtie 2 command is unsuccessful
        unless(exitStatus)
          @errUserMsg = "Bowtie 2 indexing of your spike-in library failed to run.\nPlease contact a Genboree admin for help."
          raise @errUserMsg
        end
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with creating the Bowtie 2 index of your spike-in file.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 54
      end
      return @exitCode
    end

    # Run smallRNA-seq pipeline on a particular sample
    # @param [String] inFile path to file name for input file (also used as key in @inputFiles hash for distinguishing runs)
    # @return [nil]
    def runSmallRNAseqPipeline(inFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Calling small RNA pipeline method for #{inFile} using Parallel.map")
      # Results dir is same as sample name (created by the pipeline itself)
      sampleName = File.basename(inFile)
      sampleName.gsub!(/[\.|\s]+/, '_')
      sample = "sample_#{sampleName}"
      # Add sample name to hash associated with input file
      @inputFiles[inFile].merge!({:sampleName => sample})
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "SAMPLENAME: #{sampleName}")
      # Run smRNA pipeline with outFile and errFile specified below
      outFile = "#{@scratchDir}/#{sample}.out"
      errFile = "#{@scratchDir}/#{sample}.err"
      # Make command to run smallRNA Pipeline
      command = "make -f #{@smRNAMakefile} INPUT_FILE_PATH=#{inFile} N_THREADS=#{@numThreads} JAVA_RAM=#{@javaRam} MAIN_ORGANISM=#{@genomeBuild} MAIN_ORGANISM_GENOME_ID=#{@genomeVersion} CALIBRATOR_LIBRARY=#{@calib} INPUT_FILE_ID=#{sample} OUTPUT_DIR=#{@scratchDir} #{@smallRNALibs} #{@adSeq} MISMATCH_N_MIRNA=#{@mismatchMirna} MISMATCH_N_OTHER=#{@mismatchOther} LOCAL_EXECUTION=#{@localExecution} >> #{outFile} 2>> #{errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "smallRNA-seq Pipeline command completed for #{inFile} (exit code: #{statusObj.exitstatus})")
      # Check whether there was an error with the smallRNA-seq pipeline run
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking for errors")
      foundError = findError(exitStatus, inFile, outFile, errFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done checking for errors")
      # Run make command again with compressCoreResults target to create a tgz archive of core result files
      command = "make compressCoreResults -f #{@smRNAMakefile} INPUT_FILE_PATH=#{inFile} N_THREADS=#{@numThreads} JAVA_RAM=#{@javaRam} MAIN_ORGANISM=#{@genomeBuild} MAIN_ORGANISM_GENOME_ID=#{@genomeVersion} CALIBRATOR_LIBRARY=#{@calib} INPUT_FILE_ID=#{sample} OUTPUT_DIR=#{@scratchDir} #{@smallRNALibs} #{@adSeq} MISMATCH_N_MIRNA=#{@mismatchMirna} MISMATCH_N_OTHER=#{@mismatchOther} LOCAL_EXECUTION=#{@localExecution} >> #{outFile} 2>> #{errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "make compressCoreResults command completed for #{inFile} (exit code: #{statusObj.exitstatus})")
      # Compress output (partial results if error occurred in run, full results otherwise)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Compressing outputs")
      compressOutputs(inFile, @inputFiles, foundError, outFile, errFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done compressing outputs")
      # Transfer files for this sample to the user db
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Transferring compressed outputs of the sample #{inFile} to Genboree workbench / FTP server")
      transferFilesForSample(inFile, @inputFiles)
      return
    end

    # Try hard to detect errors
    # - smallRNA-seq Pipeline can exit with 0 status even when it clearly failed.
    # - So we need to aggressively go looking for any errors.
    # @param [boolean] exitStatus indicating if the system() call "succeeded" or not.
    #   system() returns boolean, but if true can't be trusted for smallRNA-seq Pipeline.
    # @param [String] inFile path to file name for input file (also used as key in @inputFiles hash for distinguishing runs)
    # @param [String] outFile path to file where standard output is stored from run
    # @param [String] errFile path to file where error output is stored from run
    # @return [boolean] indicating if a smallRNA-seq Pipeline error was found or not.
    #   if so, @errUserMsg, @errInternalMsg, @exitCode will be set appropriately
    def findError(exitStatus, inFile, outFile, errFile)
      retVal = false
      errorMessages = nil
      # Check the obvious things first. Outright failure or putting error messages on stderr:
      if(exitStatus)
      #if(exitStatus and File.size("#{errFile}") <= 0)
        # So far, so good. Look for ERROR lines on stdout and stderr.
        cmd = "grep -P \"^ERROR\\s\" #{outFile} #{errFile}"
        errorMessages = `#{cmd}`
        if(errorMessages.strip.empty?)
          retVal = false
        else
          retVal = true
        end
      else
        ## Capture the make rule where failure occurred
        cmd = "grep -e \"^make:\\s\\\*\\\*\\\*\\s\" -e \"bowtie\" -e \"fastx_clipper\" #{errFile}"
        errorMessages = `#{cmd}`
        if(errorMessages =~ /Failed to read complete record/)
          errorMessages << "ERROR: Your input FASTQ file is incomplete. \nPlease correct your input file and try running the pipeline again.\n"
        end  
        if(errorMessages =~ /^make:\s\*\*\*\s\[(.*)\].*/)
          missingFile = $1
          errorMessages << "\nsmallRNA-seq Pipeline could not find the file #{missingFile}. \nThe pipeline did not proceed further."
          if(missingFile =~ /PlantAndVirus\/mature_sense_nonRed\.grouped/)
            errorMessages << "\nPOSSIBLE REASON: There were no reads to map against plants and virus miRNAs. \nYou can uncheck \"miRNAs in Plants and Viruses\" option under \"small RNA Libraries\" section in the Tool Settings and rerun the pipeline."
          elsif(missingFile =~ /readsNotAssigned\.fa/)
            errorMessages << "\nPOSSIBLE REASON: None of the reads in your sample mapped to the main genome of interest."
          elsif(missingFile =~ /\.clipped\.fastq\.gz/)
            errorMessages << "\nPOSSIBLE REASON: Clipping of 3\' adapter sequence failed. Check your input FastQ file to ensure the file is complete and correct."
          elsif(missingFile =~ /\.clipped\.noRiboRNA\.fastq\.gz/)
            errorMessages << "\nPOSSIBLE REASON: Mapping to external calibrator libraries or rRNA sequences failed. This could be potential failure of Bowtie. Please contact Genboree admin for more assistance."
          elsif(missingFile =~ /\.clipped\.readLengths\.txt/)
            errorMessages << "\nPOSSIBLE REASON: Calculation of read length distribution of clipped reads failed. Please contact Genboree admin for more assistance."
          elsif(missingFile =~ /reads\.fa/)
            errorMessages << "\nPOSSIBLE REASON: There were no input reads available for sRNAbench analysis. It is possible that \n1. all reads were removed in the pre-processing stage (or) \n2. the adapter sequence was not automatically identified by the pipeline, so reads were not clipped. \nAs a result, long reads ended up in the analysis and were rejected by sRNAbench.\nYou can try providing the 3\' adapter sequence and redo the analysis. "
          end
        end
        if(errorMessages.strip.empty?)
          retVal = false
        else
          retVal = true
        end
      end
      # Did we find anything?
      if(retVal)
        # Here, we mark the current run as failed and set its error message correspondingly
        @inputFiles[inFile][:failedRun] = true
        @errUserMsg = "exceRpt Small RNA-seq Pipeline Failed.\nMessage from exceRpt Small RNA-seq Pipeline:\n\""
        @errUserMsg << (errorMessages || "[No error info available from exceRpt Small RNA-seq Pipeline]")
        @inputFiles[inFile][:errorMsg] = @errUserMsg
      end
      return retVal
    end
    
    # Compress output files to be transferred to user db
    # @param [String] inFile path to file name for input file (also used as key in @inputFiles hash for distinguishing runs)
    # @param [Hash<String, Hash<Symbol, Object>] inputFiles hash containing information about input files
    # @param [boolean] foundError boolean that tells us whether an error occurred in the current run 
    # @param [String] outFile path to file where standard output is stored from run
    # @param [String] errFile path to file where error output is stored from run
    # @return [nil]
    def compressOutputs(inFile, inputFiles, foundError, outFile, errFile)
      # Set names of resultsZip and coreZip depending on whether an error occurred (partial) or didn't
      unless(foundError)
        resultsZip = "#{inputFiles[inFile][:sampleName]}_#{CGI.escape(@analysisName)}_results_v#{@toolVersion}.zip"
        coreZip = "#{inputFiles[inFile][:sampleName]}_CORE_RESULTS_v#{@toolVersion}.tgz"
      else
        resultsZip = "#{inputFiles[inFile][:sampleName]}_#{CGI.escape(@analysisName)}_partial_results_v#{@toolVersion}.zip"
        coreZip = "#{inputFiles[inFile][:sampleName]}_#{CGI.escape(@analysisName)}_PARTIAL_CORE_RESULTS_v#{@toolVersion}.zip"
      end
      # Pipeline will create stats file with name :sampleName.stats
      statsFile = "#{inputFiles[inFile][:sampleName]}.stats"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current stats file is #{statsFile}")
      # Compress files to create results zip
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Compressing outputs to create #{resultsZip}")
      command = "cd #{@scratchDir}; zip -r #{resultsZip} #{inputFiles[inFile][:sampleName]}.log #{statsFile} #{inputFiles[inFile][:sampleName]}/* >> #{outFile} 2>> #{errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching zip command to compress results file: #{command}")
      exitStatus = system(command)
      # If compression fails, raise error
      unless(exitStatus)
        @errUserMsg = "Could not create the zip archive of results.\nPlease contact a Genboree admin for help."
        raise "Command: #{command} died. Check #{errFile} for more information."
      end
      # Check if core results tgz file is available, else compress core results tgz
      if(File.exist?("#{@scratchDir}/#{inputFiles[inFile][:sampleName]}_CORE_RESULTS_v#{@toolVersion}.tgz"))
        # Rename CORE_RESULTS zip to include analysis name
        newCoreZip = "#{inputFiles[inFile][:sampleName]}_#{CGI.escape(@analysisName)}_CORE_RESULTS_v#{@toolVersion}.tgz"
        `mv #{@scratchDir}/#{coreZip} #{@scratchDir}/#{newCoreZip}`
        coreZip = newCoreZip
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Compressed file of core results exists #{coreZip}")
      else
        coreZip.gsub!(inputFiles[inFile][:sampleName], "#{inputFiles[inFile][:sampleName]}_#{CGI.escape(@analysisName)}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Core Results zip archive #{coreZip} is not found, so making it now.")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Compressing \.grouped files to create #{coreZip}")
        command = "cd #{@scratchDir}/#{inputFiles[inFile][:sampleName]}/; tar -cvz \"#{@scratchDir}\/#{coreZip}\" \"#{@scratchDir}\/#{statsFile}\" \"*.grouped\" \"stat\/*\" \"*.sorted.txt\" \".result.txt\" \"*.counts\" \"*.adapterSeq\" \"*.qualityEncoding\" \"*.readLengths.txt\" >> #{outFile} 2>> #{errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching tar command to compress all \.grouped files: #{command}")
        exitStatus = system(command)
        if(!exitStatus)
          @errUserMsg = "Could not create the zip archive of \.grouped files."
          raise "Command: #{command} died. Check #{errFile} for more information."
        end
      end
      # If the results zip doesn't exist after compression, then we raise an error
      if(File.exist?("#{@scratchDir}/#{resultsZip}") )
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE Compressing outputs to create #{resultsZip}")
      else
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Results zip archive #{resultsZip} is not found")
        @errUserMsg = "Results zip archive #{resultsZip} is not found.\nPlease contact a Genboree admin for help."
        raise @errUserMsg
      end
      # Merge info about results zip, grouped zip, and stats file into corresponding input file hash
      inputFiles[inFile].merge!({:resultsZip => resultsZip, :coreZip => coreZip, :statsFile => statsFile})
     # Delete uncompressed results (don't need them anymore)
     `rm -rf #{@scratchDir}/#{inputFiles[inFile][:sampleName]}`
      return
    end

    # Run processPipelineRuns tool on successful results .zip files
    # @param [Hash<String, Hash<Symbol, Object>] inputFiles hash containing information about input files
    # @return [Fixnum] exit code indicating whether post-processing tool succeeded (0) or failed (45)
    def postProcessing(inputFiles)
      begin
        # Create processPipelineRuns job file
        createPPRJobConf()
        # Call processPipelineRuns wrapper
        callPPRWrapper()
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with the post-processing portion of your submission.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 45
      end
      return @exitCode
    end
   
    # Method to create processPipelineRuns jobFile.json used in callPPRWrapper()
    # @return [nil]
    def createPPRJobConf()
      @pprJobConf = @jobConf.deep_clone()
      ## Define context
      @pprJobConf['context']['toolIdStr'] = "processPipelineRuns"
      @pprJobConf['context']['scratchDir'] = @postProcDir
      @pprJobConf['context']['userId'] = @subUserId
      @pprJobConf['context']['userFirstName'] = @subUserFirstName
      @pprJobConf['context']['userLastName'] = @subUserLastName
      @pprJobConf['context']['userEmail'] = @subUserEmail
      @pprJobConf['context']['userLogin'] = @subUserLogin
      @pprJobConf['settings']['localJob'] = true
      @pprJobConf['settings']['suppressEmail'] = true
      @pprJobConf['settings']['exceRptToolVersion'] = @toolVersion
      @pprJobConf['settings']['analysisName'] = @analysisName
      @pprJobConf['outputs'].clear
      @pprJobConf['outputs'].push(@outputDb)
      ## Write jobConf hash to tool specific jobFile.json
      @pprJobFile = "#{@postProcDir}/pprJobFile.json"
      File.open(@pprJobFile,"w") do |pprJob|
        pprJob.write(JSON.pretty_generate(@pprJobConf))
      end
      return
    end
    
    # Method to call processPipelineRuns wrapper on successful samples
    # @return [nil]
    def callPPRWrapper()
      # Create out and err files for processPipelineRuns wrapper, then call wrapper
      outFileFromPPR = "#{@postProcDir}/processPipelineRunsFromSmallRNASeq.out"
      errFileFromPPR = "#{@postProcDir}/processPipelineRunsFromSmallRNASeq.err"
      command = "cd #{@postProcDir}; processPipelineRunsWrapper.rb -C -j #{@pprJobFile} >> #{outFileFromPPR} 2>> #{errFileFromPPR}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "processPipelineRuns wrapper command completed with exit code: #{statusObj.exitstatus}")
      # Create FTP directory where results from post-processing tool will go
      outputDir = "#{@finishedFtpDir}postProcessedResults/"
      @ftpHelper.mkdir(outputDir)
      # Upload all post-processing files to FTP directory
      postProcFiles = Dir.entries(@postProcOutputDir)
      postProcFiles.each { |currentFile|
        next if(currentFile == "." or currentFile == "..")
        transferFtpFile("#{@postProcOutputDir}/#{currentFile}", "#{outputDir}", false)
      }
      return
    end
      
    # Transfer output files to the user database for a particular sample
    # @param [String] currentFile the current input file being uploaded
    # @param [Hash<String, Hash<Symbol, Object>] inputFiles hash containing information about input files
    # @return [nil]
    def transferFilesForSample(currentFile, inputFiles)
      # Parse target URI for outputs
      targetUri = URI.parse(@outputDb)
      # Specify full resource path
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Transferring outputs for #{currentFile} to the user database in server")
      sampleName = inputFiles[currentFile][:sampleName]
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current Sample name: #{sampleName}")
      rsrcPath = "#{targetUri.path}/file/smallRNAseqPipeline_v#{@toolVersion}/{analysisName}/#{sampleName}/{outputFile}/data?"
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      # statsFile
      # :outputFile => each run's statsFile
      # input is each run's "#{@scratchDir}/#{@statsFile}"
      # Upload this file only if it has stats info - Last line in this file always begins with "#END OF STATS"
      cmd = "grep -P \"#END OF STATS\" #{@scratchDir}/#{inputFiles[currentFile][:statsFile]}"
      grepResult = `#{cmd}`
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Grep for end of stats file: #{grepResult}")
      if(grepResult =~ /#END OF STATS/)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Trying to upload stats file #{@scratchDir}/#{inputFiles[currentFile][:statsFile]}")
        uploadFile(targetUri.host, rsrcPath, @subUserId, "#{@scratchDir}/#{inputFiles[currentFile][:statsFile]}", {:analysisName => @analysisName, :outputFile => inputFiles[currentFile][:statsFile]})
        @ftpHelper.mkdir("#{@finishedFtpDir}#{inputFiles[currentFile][:sampleName]}/")
        transferFtpFile("#{@scratchDir}/#{inputFiles[currentFile][:statsFile]}", "#{@finishedFtpDir}#{inputFiles[currentFile][:sampleName]}", false)
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Skipping upload of stats file #{@scratchDir}/#{inputFiles[currentFile][:statsFile]}, since it is incomplete.")
      end        
      # resultsZip
      # :outputFile => each run's resultsZip
      # input is each run's "#{@scratchDir}/#{@resultsZip}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Trying to upload results zip #{@scratchDir}/#{inputFiles[currentFile][:resultsZip]}")        
      uploadFile(targetUri.host, rsrcPath, @subUserId, "#{@scratchDir}/#{inputFiles[currentFile][:resultsZip]}", {:analysisName => @analysisName, :outputFile => inputFiles[currentFile][:resultsZip]})
      @ftpHelper.mkdir("#{@finishedFtpDir}#{inputFiles[currentFile][:sampleName]}/")
      transferFtpFile("#{@scratchDir}/#{inputFiles[currentFile][:resultsZip]}", "#{@finishedFtpDir}#{inputFiles[currentFile][:sampleName]}", false)
      # coreZip
      # :outputFile => each run's coreZip
      # input is each run's "#{@scratchDir}/{SAMPLE_RESULTS_DIR}/#{coreZip}"
      if(File.exist?("#{@scratchDir}/#{inputFiles[currentFile][:coreZip]}"))
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Trying to upload CORE_RESULTS archive #{@scratchDir}/#{inputFiles[currentFile][:coreZip]}")
        # Use extract=true to unpack all core result files in the CORE_RESULTS folder
        rsrcPath << "extract=true"
        uploadFile(targetUri.host, rsrcPath, @subUserId, "#{@scratchDir}/#{inputFiles[currentFile][:coreZip]}", {:analysisName => @analysisName, :outputFile => "CORE_RESULTS/#{inputFiles[currentFile][:coreZip]}"})          
        transferFtpFile("#{@scratchDir}/#{inputFiles[currentFile][:coreZip]}", "#{@finishedFtpDir}#{inputFiles[currentFile][:sampleName]}", false)
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "CORE_RESULTS zip file #{inputFiles[currentFile][:coreZip]} does not exist. Skipping.")
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE transferring outputs of #{sampleName} to the user database in server")
      # Remove uncompressed input and results zip (we don't need them anymore)
      `rm -f #{currentFile}`
      `rm -f #{@scratchDir}/#{inputFiles[currentFile][:resultsZip]}`
      # Copy CORE_RESULTS .zip for post-processing
      `cp #{@scratchDir}/#{inputFiles[currentFile][:coreZip]} #{@postProcDir}/runs/#{inputFiles[currentFile][:coreZip]}`
      return
    end

    # This method will upload docs to user's Genboree database
    # @param [Hash<String, Hash>] docs the docs to be uploaded
    # @return [Fixnum] exit code indicating whether metadata upload to db succeeded (0) or failed (52)
    def uploadMetadataToDb(docs)
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Now uploading #{docs.keys.inspect} to user's Genboree database")
        # Set up URI
        targetUri = URI.parse(@outputDb)
        rsrcPath = "#{targetUri.path}/file/smallRNAseqPipeline_v#{@toolVersion}/{analysisName}/metadataFiles/{outputFile}/data?"
        rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
        # Write each metadata file to disk and then upload it to user's Genboree database
        docs.each_key { |currentDocName|
          File.open(currentDocName, 'w') { |file| file.write(@producer.produce(docs[currentDocName]).join("\n")) }
          uploadFile(targetUri.host, rsrcPath, @subUserId, currentDocName, {:analysisName => @analysisName, :outputFile => File.basename(currentDocName)})
        }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done uploading #{docs.keys.inspect} to user's Genboree database")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue uploading docs to collection #{coll}.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 52
      end 
      return @exitCode    
    end

    # This method will upload docs to the appropriate collection
    # @param [Hash<String, Hash>] docs the docs to be uploaded
    # @return [Fixnum] exit code indicating whether metadata upload to kb succeeded (0) or failed (43)
    def uploadMetadataDocs(docs)
      begin
        # Grab collection associated with current docs
        currentRootProp = docs.values[0].getRootProp()
        coll = @collections[currentRootProp]
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Now uploading #{docs.keys.inspect} to #{coll}")
        # Set up resource path for upload
        rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/docs"
        apiCaller = WrapperApiCaller.new(@exRNAHost, rsrcPath, @subUserId)
        groupName = @exRNAKbGroup
        kbName = @exRNAKb
        collName = coll
        # Set up payload - we divide payload into chunks of 10 documents (just for now until we update kbBulkUpload so that we can use it with local files)
        payload = docs.values
        payload = payload.each_slice(10).to_a
        payload.each { |currentPayload|
          apiCaller.put({:coll => collName, :kb => kbName, :grp => groupName}, currentPayload.to_json)
          # If doc upload fails, raise error
          unless(apiCaller.parseRespBody["data"]["docs"]["properties"]["invalid"]["items"].empty?)
            @errUserMsg = "ApiCaller failed: call to upload #{docs.keys.inspect} to collection #{coll} failed."
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "ApiCaller failed to upload #{docs.keys.inspect} to collection #{coll}: #{apiCaller.respBody.inspect}")
            raise @errUserMsg
          end
        }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully uploaded #{docs.keys.inspect} to #{coll}")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue uploading docs to collection #{coll}.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 43
      end 
      return @exitCode
    end

    #### BULK UPLOAD-BASED UPLOAD - NOT CURRENTLY IN USE
    # This method will upload docs to the appropriate collection
    # @param [Hash<String, Hash>] docs the docs to be uploaded
    # @return [Fixnum] exit code indicating whether metadata upload succeeded (0) or failed (43)
    #def uploadMetadataDocs(docs)
     # begin
      #  coll = ""
       # if(docs.class == String)
       #   coll = @collections[docs.values[0].getRootProp()]
       # else
       #   coll = @collections[docs[0].values[0].getRootProp()]
       # end
       # $stderr.debugPuts(__FILE__, __method__, "STATUS", "Now uploading #{docs.keys.inspect} to #{coll}")
       # # Save docs from KbDoc format to .tsv format
       # docs.each_key { currentDocName|
       #   File.open(currentDocName, 'w') { |file| file.write(@producer.produce(docs[currentDocName]).join("\n")) }
       # }
        # Create KbBulkUpload job conf file
       # createKbBulkUploadJobConf(docs, coll)
       # callKbBulkUploadWrapper(coll)
       # $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully uploaded #{docs.keys.inspect} to #{coll}")
     # rescue => err
     #   # Generic error message
     #   @errUserMsg = "ERROR: There was an issue uploading docs to collection #{coll}.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
     #   @errInternalMsg = err
     #   $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
     #   errBacktrace = err.backtrace.join("\n")
     #   $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
     #   @exitCode = 43
    #  end 
    #  return @exitCode
   # end

    # Method to create kbBulkUpload jobFile.json used in callKbBulkUpload()
    # Not currently used
    # @param [Hash<String, Hash>] currentMetadataFiles docs to be uploaded
    # @param [String] coll the collection to whcih the docs will be uploaded
    # @return [nil]
    #def createKbBulkUploadJobConf(docs, coll)
    #  @KbBulkUpload = @jobConf.deep_clone()
      ## Define inputs, outputs, context and settings
    #  @kbBulkUploadConf['inputs'] = [docs.keys]
    #  @kbBulkUploadConf['outputs'] = ["http://#{CGI.escape(@exRNAHost)}/REST/v1/grp/#{CGI.escape(@exRNAKbGroup)}/kb/#{CGI.escape(@exRNAKb)}/coll/#{CGI.escape(coll)}?"]
      ## All internal tool wrappers will have a scratch dir under subJobsScratch/ dir,
      ## named after the tool "idStr" as defined in the tool conf json
    #  @kbBulkUploadConf['context']['toolIdStr'] = "kbBulkUpload"
    #  @kbBulkUploadConf['context']['scratchDir'] = @kbBulkUploadScratchDir
    #  @kbBulkUploadConf['settings']['localJob'] = true
    #  @kbBulkUploadConf['settings']['suppressEmail'] = true
      ## Write jobConf hash to tool specific jobFile.json
    #  @kbBulkUploadJobFile = "#{@kbBulkUploadScratchDir}/kbBulkUploadJobFile.json"
    #  File.open(@kbBulkUploadJobFile,"w") do |kbBulkUpload|
    #    kbBulkUpload.write(JSON.pretty_generate(@kbBulkUploadConf))
    #  end
    #  return
   # end
    
    # Method to call kbBulkUpload wrapper on successful samples
    # Not currently used
    # @return [nil]
    #def callKbBulkUploadWrapper(coll)
    #  outFileFromKbBulkUpload = "#{@kbBulkUploadScratchDir}/kbBulkUpload.out"
    #  errFileFromKbBulkUpload = "#{@kbBulkUploadScratchDir}/kbBulkUpload.err"
    #  command = "cd #{@kbBulkUploadScratchDir}; kbBulkUpload.rb -C -j #{@kbBulkUploadJobFile} > #{outFileFromKbBulkUpload} 2> #{errFileFromKbBulkUpload}"
    #  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
    #  system(command)
    #  statusObj = $?
    #  $stderr.debugPuts(__FILE__, __method__, "STATUS", "kbBulkUpload wrapper command completed with exit code: #{statusObj.exitstatus}")
    #  if(statusObj.exitstatus != 0 and File.size(errFileFromKbBulkUpload) > 0) # FAILED: kbBulkUpload. Check stderr from this command.
    #    @errUserMsg = "Could not upload documents for collection #{coll}.\nkbBulkUplaod wrapper exited with code #{statusObj.exitstatus}.\nError message from kbBulkUpload wrapper:\n\n"
    #    errorReader = File.open("#{errFileFromKbBulkUpload}")
    #    errorReader.each_line { |line|
    #      next if(line =~ /STATUS:/ or line =~ /^\[/)
    #      break if(line =~ /^Backtrace:/)
    #      @errUserMsg << "    #{line}"
    #    }
    #    errorReader.close()
    #    @errUserMsg.chomp!
    #    @errUserMsg << "------\n"
    #    raise @errUserMsg
    #  end
    #  return
    #end    
    
    # Upload a given file to Genboree server
    # @param host [String] host that user wants to upload to
    # @param rsrcPath [String] resource path that user wants to upload to
    # @param userId [Fixnum] Genboree user id of the user
    # @param inputFile [String] full path of the file on the client machine where data is to be pulled
    # @param templateHash [Hash<Symbol, String>] hash that contains (potential) arguments to fill in URI for API put command
    # @return [nil]
    def uploadFile(host, rsrcPath, userId, input, templateHash)
      # Call FileApiUriHelper's uploadFile method to upload current file
      retVal = @fileApiHelper.uploadFile(host, rsrcPath, userId, input, templateHash)
      # Print error if our upload fails
      unless(retVal)
        # Print error if the reason the upload failed was because we exceeded number of attempts
        if(@fileApiHelper.uploadCheck == 2)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "After many attempts, #{input}\nwas not uploaded successfully to server. Please resubmit your job.")
          @errUserMsg = @errInternalMsg = "After many attempts, #{input}\nwas not uploaded successfully to server. Please resubmit your job."
          raise @errUserMsg
        # Print error if the reason the upload failed was because the target path no longer exists (missing group, database)
        elsif(@fileApiHelper.uploadCheck == 3)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "The target output path could not be found.\nEither group #{@groupName} or database #{@dbName}\nis missing.  Did you rename or delete your group or database?")
          @errUserMsg = @errInternalMsg = "The target output path could not be found.\nEither group #{@groupName} or database #{@dbName}\nis missing.  Did you rename or delete your group or database?"
          raise @errUserMsg
        # Print error if something REALLY weird happened (how is @uploadCheck a value other than 2 or 3?)
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error uploading #{input}.\n@uploadCheck value is not being set correctly.\nPlease contact a Genboree admin for help.")
          @errUserMsg = @errInternalMsg = "Error uploading #{input}.\n@uploadCheck value is not being set correctly.\nPlease contact a Genboree admin for help."
          raise @errUserMsg
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "#{input} uploaded successfully to server")
      end
      return
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
        analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Alignment Method", "exceRpt smallRNA-seq Pipeline Version #{@toolVersion}")
        analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Genome Version", @settings['genomeVersion'])
        analysisKbDoc.setPropVal("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Biosamples", successfulSamples)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully added preliminary info into #{@analysisMetadataFile.keys[0]}")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in the preliminary info for your analysis document.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
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
        biosampleMetadataFileName = currentInput[:biosampleMetadataFileName]
        bioKbDoc = @biosampleMetadataFiles[biosampleMetadataFileName]
        currentBioName = bioKbDoc.getRootPropVal()
        statsFile = currentInput[:statsFile]
        sampleName = currentInput[:sampleName]
        resultsZip = currentInput[:resultsZip]
        coreZip = currentInput[:coreZip]
        #### FILLING IN ANALYSIS DOC WITH BIOSAMPLE INFO ####
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adding read information from #{biosampleMetadataFileName} into #{@analysisMetadataFile.keys[0]}")
        # Grab important information from our stats file to add to analysis document
        readInStatsFile = File.read(statsFile)
        totalReads = readInStatsFile.match(/^input\s+(\d+)$/)[1]
        totalReadsAfterClipping = readInStatsFile.match(/^successfully_clipped\s+(\d+)$/)[1]
        failedQualityFilter = readInStatsFile.match(/^failed_quality_filter\s+(\d+)$/)[1]
        failedHomopolymerFilter = readInStatsFile.match(/^failed_homopolymer_filter\s+(\d+)$/)[1]
        calibrator = readInStatsFile.match(/^calibrator\s+(\d+)$/)[1] rescue nil
        uniVecReads = readInStatsFile.match(/^UniVec_contaminants\s+(\d+)$/)[1]
        rRNAReads = readInStatsFile.match(/^rRNA\s+(\d+)$/)[1]
        readsUsedForAlignment = readInStatsFile.match(/^reads_used_for_alignment\s+(\d+)$/)[1]
        genomeReads = readInStatsFile.match(/^genome\s+(\d+)$/)[1]
        miRNAReads_Sense = readInStatsFile.match(/^miRNA_sense\s+(\d+)$/)[1]
        miRNAReads_Antisense = readInStatsFile.match(/^miRNA_antisense\s+(\d+)$/)[1]
        tRNAReads_Sense = readInStatsFile.match(/^tRNA_sense\s+(\d+)$/)[1]
        tRNAReads_Antisense = readInStatsFile.match(/^tRNA_antisense\s+(\d+)$/)[1]
        piRNAReads_Sense = readInStatsFile.match(/^piRNA_sense\s+(\d+)$/)[1]
        piRNAReads_Antisense = readInStatsFile.match(/^piRNA_antisense\s+(\d+)$/)[1]
        gencodeReads_Sense = readInStatsFile.match(/^gencode_sense\s+(\d+)$/)[1]
        gencodeReads_Antisense = readInStatsFile.match(/^gencode_antisense\s+(\d+)$/)[1]
        inputToRepetitiveElementAlignment = readInStatsFile.match(/^input_to_repetitiveElement_alignment\s+(\d+)$/)[1]
        repetitiveElements = readInStatsFile.match(/^repetitiveElements\s+(\d+)$/)[1]
        circularRNA_Sense = readInStatsFile.match(/^circularRNA_sense\s+(\d+)$/)[1]
        circularRNA_Antisense = readInStatsFile.match(/^circularRNA_antisense\s+(\d+)$/)[1]
        input_To_Exogenous_miRNA = readInStatsFile.match(/^input_to_miRNA_exogenous\s+(\d+)$/)[1]
        miRNA_exogenousReads_Sense = readInStatsFile.match(/^miRNA_exogenous_sense\s+(\d+)$/)[1]
        if(@exogenousMapping =~ /on/)
          readsForExogenousGenomes = readInStatsFile.match(/^input_to_exogenous_genomes\s+(\d+)$/)[1]
          exogenousGenomes = readInStatsFile.match(/^exogenous_genomes\s+(\d+)$/)[1]
        end
        # Create subdoc containing information about current biosample
        currentBioInfo = BRL::Genboree::KB::KbDoc.new({})
        currentBioInfo.setPropVal("Biosample ID", currentBioName)
        currentBioInfo.setPropVal("Biosample ID.DocURL", "coll/#{@biosampleCollection}/doc/#{currentBioName}")
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages", "")
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Input Reads", totalReads)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.After Clipping", totalReadsAfterClipping)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Failed Quality Filter", failedQualityFilter)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Failed Homopolymer Filter", failedHomopolymerFilter)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Calibrator", calibrator) if(calibrator)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.UniVec Contaminants", uniVecReads)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.rRNAs", rRNAReads)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Reads Used for Alignment", readsUsedForAlignment)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Genome", genomeReads)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.miRNAs Sense", miRNAReads_Sense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.miRNAs Antisense", miRNAReads_Antisense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.piRNAs Sense", piRNAReads_Sense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.piRNAs Antisense", piRNAReads_Antisense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.tRNAs Sense", tRNAReads_Sense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.tRNAs Antisense", tRNAReads_Antisense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Gencode Annotations Sense", gencodeReads_Sense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Gencode Annotations Antisense", gencodeReads_Antisense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Input to Repetitive Element Alignment", inputToRepetitiveElementAlignment)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Repetitive Elements", repetitiveElements)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Circular RNAs Sense", circularRNA_Sense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Circular RNAs Antisense", circularRNA_Antisense)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Reads Used for Exogenous Alignments", input_To_Exogenous_miRNA)
        currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Exogenous miRNAs", miRNA_exogenousReads_Sense)
        if(@exogenousMapping =~ /on/)
          currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Reads Used for Exogenous Genome Alignments", readsForExogenousGenomes)
          currentBioInfo.setPropVal("Biosample ID.Read Counts at Various Stages.Exogenous Genomes", exogenousGenomes)
        end
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
        resultFilesID = resultFilesID.insert(4, @piID)
        resultFilesDoc.setPropVal("Result Files", resultFilesID)
        resultFilesDoc.setPropVal("Result Files.Status", "Add")
        resultFilesDoc.setPropVal("Result Files.Related Analysis", @analysisID)
        resultFilesDoc.setPropVal("Result Files.Biosample ID", currentBioName)
        resultFilesDoc.setPropVal("Result Files.Biosample ID.Pipeline Result Files", 0)
        # Decompress CORE .tgz for placing file names into KB doc
        exp = BRL::Genboree::Helpers::Expander.new(coreZip)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracting CORE .tgz #{coreZip}")
        exp.extract()
        extractedFile = exp.uncompressedFileName
        dataDir = exp.tmpDir
        # Copy CORE .tgz to dataDir (so we can put it in Pipeline Result Files item list)
        `cp #{coreZip} #{dataDir}/`
        # Call recursive method to fill out result files for CORE_RESULTS
        currentURL = @outputDb.clone
        currentURL << "/file/smallRNAseqPipeline_v#{@toolVersion}/#{CGI.escape(@analysisName)}/#{CGI.escape(sampleName)}/CORE_RESULTS"
        fillInResultFilesDoc(dataDir, currentURL, resultFilesDoc)
        raise @errUserMsg unless(@exitCode == 0)
        # Add info about result .zip to doc
        resultFilesDoc.setPropVal("Result Files.Biosample ID.Results Archive File Name", resultsZip)
        currentURL = @outputDb.clone
        currentURL << "/file/smallRNAseqPipeline_v#{@toolVersion}/#{CGI.escape(@analysisName)}/#{CGI.escape(sampleName)}/#{CGI.escape(resultsZip)}"
        resultFilesDoc.setPropVal("Result Files.Biosample ID.Results Archive File Name.Genboree URL", currentURL)
        # Save results files doc
        resultFilesID = resultFilesDoc.getRootPropVal()
        resultFilesMetadataFileName = "#{resultFilesID}.metadata.tsv"
        resultFilesMetadata = {resultFilesMetadataFileName => resultFilesDoc}
        @resultFilesMetadataFiles.merge!(resultFilesMetadata)
        @resultFilesIDs << resultFilesID
        # Store association between biosample ID and donor ID / result files ID (used in Job doc)
        @biosampleToDonorAndResultFiles[currentBioName] = [bioKbDoc.getPropVal("Biosample.Donor ID"), resultFilesID]
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully created results files doc for #{biosampleMetadataFileName}")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in info for #{sampleName} in your analysis document.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
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
    # @return [Fixnum] exit code indicating whether filling in result files doc succeeded (0) or failed (57)
    def fillInResultFilesDoc(currentPath, currentURL, resultFilesDoc)
      begin
        # If current path is a directory, we'll traverse all files in that directory and submit those recursively to this method
        if(File.directory?(currentPath))
          allFiles = Dir.entries(currentPath)
          allFiles.delete(".")
          allFiles.delete("..")
          allFiles.each { |currentFile|
            newPath = "#{currentPath}/#{currentFile}"
            newCurrentURL = "#{currentURL}/#{CGI.escape(currentFile)}"
            fillInResultFilesDoc(newPath, newCurrentURL, resultFilesDoc)
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
          key << "EXOGENOUS_miRNA/" if(currentURL.split("/")[-2] == "EXOGENOUS_miRNA")
          key << "noGenome/" if(currentURL.split("/")[-2] == "noGenome")
          key << File.basename(currentPath)
          key = "_CORE_RESULTS_v*.zip" if(currentURL.split("/")[-1].include?("CORE_RESULTS_"))
          key = ".stats" if(currentURL.split("/")[-1].include?(".stats"))
          description = @resultFileDescriptions[key]
          currentPipelineFile.setPropVal("File ID.Description", description) unless(description.nil?)
          # Add current entry to result files doc
          resultFilesDoc.addPropItem("Result Files.Biosample ID.Pipeline Result Files", currentPipelineFile)
        end
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in info for one of your result files documents.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 57
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
        postProcFiles.each { |currentFile|
          next if(currentFile == "." or currentFile == "..")
          currentPostProcFile = BRL::Genboree::KB::KbDoc.new({})
          fileID = grabAutoID("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Post-processing Result Files.File ID", @analysisCollection)
          raise @errUserMsg unless(@exitCode == 0)   
          currentPostProcFile.setPropVal("File ID", fileID)
          currentPostProcFile.setPropVal("File ID.File Name", currentFile)
          currentURL = @outputDb.clone
          currentURL << "/file/smallRNAseqPipeline_v#{@toolVersion}/#{CGI.escape(@analysisName)}/postProcessedResults_v#{@toolVersionPPR}/#{CGI.escape(currentFile)}"
          currentPostProcFile.setPropVal("File ID.Genboree URL", currentURL)
          analysisKbDoc.addPropItem("Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Post-processing Result Files", currentPostProcFile)
        }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully added post-processing information into #{@analysisMetadataFile.keys[0]}")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in post-processing info in your analysis document.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 46
      end
      return @exitCode
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

    # Method for moving files on FTP server if error occurs. This method just provides a shortcut for deciding to move manifest / metadata zip / data zip in case of error.
    # @param [Fixnum] code number that indicates which files to move (manifest, metadata archive, data archive)
    # @return [Fixnum] exit code indicating whether transferring FTP files succeeded (0) or failed (48)
    def transferFtpFilesIfError(code) 
      begin
        # We set code to be 4 (so that all existing files are transferred back to inbox) if @debuggingTool is true
        code = 4 if(@debuggingTool)
        # Used when manifest file has errors
        if(code==1)
          transferFtpFile(@metadataArchiveLocation, "#{@inboxFtpDir}#{File.basename(@metadataArchiveLocation)}", true) if(@metadataArchiveLocation)
          transferFtpFile(@dataArchiveLocation, "#{@inboxFtpDir}#{File.basename(@dataArchiveLocation)}", true) if(@dataArchiveLocation)
          @workingFiles.push(@metadataArchiveLocation.gsub(/\/working\/.+\//, "/inbox/"))
          @workingFiles.push(@dataArchiveLocation.gsub(/\/working\/.+\//, "/inbox/"))
          @brokenFiles.push(@manifestLocation)
        # Used when metadata archive has errors
        elsif(code==2)
          transferFtpFile(@manifestLocation, "#{@inboxFtpDir}#{File.basename(@manifestLocation)}", true) if(@manifestLocation)
          transferFtpFile(@dataArchiveLocation, "#{@inboxFtpDir}#{File.basename(@dataArchiveLocation)}", true) if(@dataArchiveLocation)
          @workingFiles.push(@manifestLocation.gsub(/\/working\/.+\//, "/inbox/"))
          @workingFiles.push(@dataArchiveLocation.gsub(/\/working\/.+\//, "/inbox/"))
          @brokenFiles.push(@metadataArchiveLocation)
        # Used when data archive has errors
        elsif(code==3)
          transferFtpFile(@manifestLocation, "#{@inboxFtpDir}#{File.basename(@manifestLocation)}", true) if(@manifestLocation)
          transferFtpFile(@metadataArchiveLocation, "#{@inboxFtpDir}#{File.basename(@metadataArchiveLocation)}", true) if(@metadataArchiveLocation)
          @workingFiles.push(@manifestLocation.gsub(/\/working\/.+\//, "/inbox/"))
          @workingFiles.push(@metadataArchiveLocation.gsub(/\/working\/.+\//, "/inbox/"))
          @brokenFiles.push(@dataArchiveLocation)
        # Used when failure jobs are submitted (some files are missing) or for debugging purposes
        elsif(code==4)
          if(@manifestLocation)
            transferFtpFile(@manifestLocation, "#{@inboxFtpDir}#{File.basename(@manifestLocation)}", true)
            @workingFiles.push(@manifestLocation)
          else
            @brokenFiles.push("MANIFEST FILE (NOT SUBMITTED)")
          end
          if(@metadataArchiveLocation)
            transferFtpFile(@metadataArchiveLocation, "#{@inboxFtpDir}#{File.basename(@metadataArchiveLocation)}", true)
            @workingFiles.push(@metadataArchiveLocation)
          else
            @brokenFiles.push("METADATA ARCHIVE (NOT SUBMITTED)")
          end
          if(@dataArchiveLocation)
            transferFtpFile(@dataArchiveLocation, "#{@inboxFtpDir}#{File.basename(@dataArchiveLocation)}", true)
            @workingFiles.push(@dataArchiveLocation)
          else
            @brokenFiles.push("DATA ARCHIVE (NOT SUBMITTED)")
          end 
        end
      rescue => err
        # Generic error message
        if(@errUserMsg.nil?)
          @errUserMsg = "ERROR: We had trouble transferring your files on the FTP server from the /working directory to the /inbox directory.\nPlease contact a Genboree admin for help."
          @exitCode = 48
        else
          @errUserMsg << "\n\nAlso, we had trouble transferring your files on the FTP server from the /working directory to the /inbox directory." if(@errUserMsg.nil?)
        end
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)    
      end
      return @exitCode
    end

    # Method that checks whether an error occurred. If an error has occurred, then it transfers appropriate files on FTP and informs user.
    # @param [Fixnum] codeForFtpTransfer this code is used in the transferFtpFilesIfError method to figure out which files we should transfer back to the user's inbox
    # @return [nil]
    def checkError(codeForFtpTransfer)
      unless(@exitCode == 0)
        transferFtpFilesIfError(codeForFtpTransfer)
        raise @errUserMsg
      end
    end

    # Submits a document to exRNA Internal KB in order to keep track of exceRpt tool usage
    # @return [Fixnum] exit code indicating whether uploading tool usage doc succeeded (0) or failed (58)
    def submitToolUsageDoc()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading tool usage doc")
        # Create KB doc for tool usage and fill it out
        toolUsage = BRL::Genboree::KB::KbDoc.new({})
        toolUsage.setPropVal("exceRpt Tool Usage", @jobId)
        toolUsage.setPropVal("exceRpt Tool Usage.Status", "Add")
        toolUsage.setPropVal("exceRpt Tool Usage.Job Date", "")
        toolUsage.setPropVal("exceRpt Tool Usage.Submitter Login", @subUserLogin)
        toolUsage.setPropVal("exceRpt Tool Usage.Genboree Group Name", CGI.unescape(@groupName))
        toolUsage.setPropVal("exceRpt Tool Usage.Genboree Database Name", CGI.unescape(@dbName))
        toolUsage.setPropVal("exceRpt Tool Usage.Samples Processed Through exceRpt", 0)
        @inputFiles.each_key { |inFile|
          currentInputItem = BRL::Genboree::KB::KbDoc.new({})
          currentInputItem.setPropVal("Sample Name", File.basename(inFile))
          successStatus = ""
          if(@inputFiles[inFile][:failedRun])
            successStatus = "Failed"
          else
            successStatus = "Completed"
          end
          currentInputItem.setPropVal("Sample Name.Sample Status", successStatus)
          toolUsage.addPropItem("exceRpt Tool Usage.Samples Processed Through exceRpt", currentInputItem)
        } 
        toolUsage.setPropVal("exceRpt Tool Usage.Number of Successful Samples", @successfulSamples)
        toolUsage.setPropVal("exceRpt Tool Usage.Number of Failed Samples", @failedSamples)
        toolUsage.setPropVal("exceRpt Tool Usage.Platform", "FTP Submission Pipeline")
        # Set up resource path for upload
        kbHost = @genbConf.kbExRNAToolUsageHost
        rsrcPath = @genbConf.kbExRNAToolUsageCollection
        apiCaller = ApiCaller.new(kbHost, rsrcPath, @user, @pass)
        payload = {"data" => toolUsage}
        apiCaller.put(payload.to_json)
        # If doc upload fails, raise error
        unless(apiCaller.parseRespBody["data"]["docs"]["properties"]["invalid"]["items"].empty?)
          @errUserMsg = "ApiCaller failed: call to upload tool usage doc failed."
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "ApiCaller failed to upload tool usage doc: #{apiCaller.respBody.inspect}")
          raise @errUserMsg
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully uploaded tool usage doc")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with submitting a tool usage document.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 58
      end
      return @exitCode
    end

############ END of methods specific to this smRNAPipeline wrapper

    # ------------------------------------------------------------------
    # INTERFACE METHODS - Send Email in case of success or failure
    # ------------------------------------------------------------------
    ## Send an email summary of all samples that were processed in parallel
    ## some samples may have failed, some may have been a success 
    ## or all were successful or all failed
    def prepSuccessEmail()
      # Add number of data files to Job settings
      numDataFiles = @inputFiles.length
      @settings['numberOfDataFiles'] = numDataFiles
      @groupName = @grpApiHelper.extractName(@outputDb)
      @dbName = @dbApiHelper.extractName(@outputDb)
      @detailedMessage = ""
      @detailedMessage << "-------------------------------------------------\n" +
                          "Detailed summary of the jobs:\n" + 
                          "-------------------------------------------------\n"
       
      emailObject                     = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@subUserEmail,@jobId)
      emailObject.userFirst           = @subUserFirstName
      emailObject.userLast            = @subUserLastName
      emailObject.resultFileLocations = nil
      emailObject.inputsText = nil
      emailObject.outputsText = nil
      emailObject.analysisName        = @analysisName
      additionalInfo = "" 
      additionalInfo << "You can download result files from the following directory\n"
      additionalInfo << "on the FTP server: #{@finishedFtpDir}\n"
      additionalInfo << "You can also find result files on Genboree at the following location:\n" +
                          "|-Group: '#{@groupName}'\n" +
                            "|--Database: '#{@dbName}'\n" +
                              "|---Files\n" +
                                "|----smallRNAseqPipeline_v#{@toolVersion}\n" +
                                  "|-----#{@analysisName}\n\n" +
                        "======================SUMMARY OF DATA PROCESSING=================\n" +
                        "Number of files in your submission: #{numDataFiles}\n" +
                        "Number of files successfully processed: #{@successfulSamples}\n" +
                        "Number of files not successfully processed: #{@failedSamples}\n" +
                        "======================LIST OF DATA FILES=========================\n" +    
                        "List of data files in your submission:\n"
                        @inputFiles.each_key { |inFile|
                          successStatus = ""
                          if(@inputFiles[inFile][:failedRun])
                            successStatus = "FAILED"
                          else
                            successStatus = "SUCCEEDED"
                          end
                          additionalInfo << " File: #{File.basename(inFile)} - #{successStatus}\n"
                        }
                        additionalInfo << "======================NOTES ON RESULT FILES======================\n" +
                        "NOTE 1:\nEach sample you submitted will have its own unique subfolder\nwhere you can find the exceRpt pipeline results for that sample.\n" +
                        "NOTE 2:\nThe file that ends in '_results_v#{@toolVersion}' is a large archive\nthat contains all the result files from the exceRpt pipeline.\nWithin that archive, the file 'sRNAbenchOutputDescription.txt' provides\na description of the various output files generated by sRNAbench.\n" +
                        "NOTE 3:\nThe file that ends in '_CORE_RESULTS_v#{@toolVersion}' is a much smaller archive\nthat contains the key result files from the exceRpt pipeline.\nThis file can be found in the 'CORE_RESULTS' subfolder\nand has been decompressed in that subfolder for your convenience.\n" +
                        "======================NOTES ON POST-PROCESSED RESULTS============\n" +
                        "NOTE 1:\nPost-processed results (created by\nthe exceRpt small RNA-seq Post-processing tool)\ncan be found in the 'postProcessedResults_v#{@toolVersionPPR}' subfolder.\n" +
                        "======================NOTES ON METADATA FILES====================\n" +
                        "NOTE 1:\nYou can find the IDs of your metadata documents in your Job document\non the exRNA GenboreeKB UI. Your Job document has the following ID:\n    #{@jobId}" + 
                               "\nTo view your Job document on the exRNA GenboreeKB UI, use the following link:\nhttp://#{@exRNAHost}/#{@genboreeKbArea}/genboree_kbs?project_id=#{@exRNAKbProject}&coll=Jobs&doc=#{@jobId}&docVersion=\n" +
                        "NOTE 2:\nYou must be a member of the \"exRNA Metadata Standards\" group\non GenboreeKB in order to view your Job document." +
                               "\nPlease contact Sai Lakshmi Subramanian (sailakss@bcm.edu)\nor William Thistlethwaite (thistlew@bcm.edu)\nif you are having difficulty viewing your Job document.\n" +
                        "NOTE 3:\nIf you need help navigating the exRNA GenboreeKB UI,\nview the following Wiki page for guidance:\nhttp://genboree.org/theCommons/projects/exrna-mads/wiki/Metadata%20Submission%20using%20GenboreeKB%20UI\n"
      if(@successfulSamples < @inputFiles.keys.size)
        additionalInfo << "======================INFO ON FAILED FILES=======================\n" +
                          "\nAny samples listed below were NOT processed fully due to an error.\n" +
                          "If the job did not succeed for a sample, you will find a results archive with the tag \"PARTIAL\".\n" +
                          "This PARTIAL results archive will contain the intermediate outputs from the pipeline\n" +
                          "that were generated up until the pipeline failed.\n\n"
        # Here, we print all failed runs and corresponding error messages in additionalInfo
        @inputFiles.each_key { |inFile|
          if(@inputFiles[inFile][:failedRun])
            additionalInfo << "#{File.basename(inFile)} failed with the following message:\n"
            additionalInfo << "#{@inputFiles[inFile][:errorMsg]}\n\n"
          end
        }
      end
      # Print files that were skipped in data archive (if there are any)
      unless(@skippedFiles.empty?)
        additionalInfo << "======================SKIPPED FILES==============================\n"
        additionalInfo << "\nThe following files were not needed in your data archive and were skipped:\n"
        @skippedFiles.each { |skippedFile|
          additionalInfo << "#{skippedFile}\n"
        }
      end
      additionalInfo << "================================================================="
      emailObject.additionalInfo = additionalInfo
      if(@suppressEmail)
        return nil
      else
        return emailObject
      end
    end

    ## Send an error email when the job failed
    def prepErrorEmail() 
      @subUserEmail = "thistlew@bcm.edu" unless(@subUserEmail)
      @subUserFirstName = "William" unless(@subUserFirstName)
      @subUserLastName = "Thistlethwaite" unless(@subUserLastName)
      emailErrorObject                = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@subUserEmail,@jobId)
      emailErrorObject.userFirst      = @subUserFirstName
      emailErrorObject.userLast       = @subUserLastName
      emailErrorObject.analysisName   = @analysisName
      emailErrorObject.inputsText = nil
      emailErrorObject.outputsText = nil
      emailErrorObject.settings       = @settings
      emailErrorObject.errMessage     = @errUserMsg
      emailErrorObject.exitStatusCode = @exitCode
      additionalInfo = ""
      # Print paths to working file(s) for user
      if(@workingFiles)
        unless(@workingFiles.empty?)
          additionalInfo << "======================WORKING FILES==============================\n" 
          additionalInfo << "The files below were not involved in any errors and were moved back to your inbox.\nThese files include:\n\n"
          additionalInfo << @workingFiles.join("\n")
        end
      end
      # Print paths to broken file(s) for user
      if(@brokenFiles)
        unless(@brokenFiles.empty?)
          additionalInfo << "\n======================BROKEN FILES===============================\n" 
          additionalInfo << "The files below were involved in at least one error and were not moved back to your inbox.\nIf you wish to retrieve these files (to edit / resubmit / etc.), they are located here:\n\n" 
          additionalInfo << @brokenFiles.join("\n")
        end
      end
      # Print files that were skipped in data archive
      if(@skippedFiles)
        unless(@skippedFiles.empty?)
          additionalInfo << "\n======================SKIPPED FILES===============================\n"
          additionalInfo << "\n\nThe following files were not needed in your data archive and were skipped:\n"
          additionalInfo << @skippedFiles.join("\n")
        end
      end
      additionalInfo << "\n================================================================="
      emailErrorObject.additionalInfo = additionalInfo
      if(@suppressEmail)
        return nil
      else
        return emailErrorObject
      end
    end
  end
end; end ; end ; end

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::FTPSmRNAPipelineWrapper)
end