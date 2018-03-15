#!/usr/bin/env ruby
#########################################################
######## FTP exceRptPipeline wrapper (4th gen) ##########
## This wrapper begins the FTP version of the 4th      ## 
## generation exceRpt Small RNA-seq Pipeline.          ##
## First, the user's manifest file, metadata archive,  ##
## and data archive are all checked for validity.      ##
## Next, the user's data files are submitted for       ##
## processing through runExceRpt (one job for each     ##
## sample). Then, if full exogenous mapping is enabled,##
## all succesful samples are run through the           ##
## exogenousSTARMapping wrapper. Next, post-processing ##
## is performed on all successful samples through      ##
## processPipelineRuns.                                ##
## Finally, metadata is finalized / uploaded and tool  ## 
## usage doc is uploaded through erccFinalProcessing.  ##
## The user will be emailed throughout the process     ##
## (One email from this wrapper, one email from each   ##
## runExceRpt job, one email from processPipelineRuns, ##
## and one email from erccFinalProcessing).            ##
## Modules used in this pipeline:                      ##
## 1. exceRptPipeline                                  ##
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
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/helpers/sniffer'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/helpers/dataCollectionHelper'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class FTPexceRptPipelineWrapper < BRL::Genboree::Tools::FTPToolWrapper
    VERSION = "4.6.2"
    COMMAND_LINE_ARGS = {}
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running 'FTPexceRptRNAPipeline'.
                        This tool is intended to be called when jobs are submitted by the FTP Pipeline for exceRpt.
                        This wrapper checks the validity of the submitted manifest / metadata archive / data archive
                        and then submits all data samples for processing.",
      :authors      => [ "William Thistlethwaite (thistlew@bcm.edu) and Sai Lakshmi Subramanian (sailakss@bcm.edu)" ],
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
        # Getting relevant variables from "context"
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        # Information about submitter (user)
        # Initially set to be first name / last name / email of FTP job submitter (William, most likely) in case we can't retrieve this info and need to e-mail SOMEONE
        @subUserFirstName = @userFirstName
        @subUserLastName = @userLastName
        @subUserEmail = @userEmail
        # Job file sent by poller will not have an analysis name. Set it here.
        @analysisName = "FTPexceRptPipeline-#{Time.now.strftime('%Y-%m-%d-%H:%M:%S').gsub('-0', '-')}"
        # Set scratch directory variable
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        # Get the current generation of exceRpt (should usually be 4th)
        @exceRptGen = @settings['exceRptGen']
        # Get the tool version
        @toolVersion = @toolConf.getSetting('info', 'version')
        # If we need to run 3rd gen exceRpt for some reason, we'll set that tool version here
        # Unlike the Workbench tool, this will NOT be a standard option for users (we'll choose it ourselves through the initial job conf)
        if(@exceRptGen == "thirdGen")
          @toolVersion = "3.3.0"
        end
        @settings['toolVersion'] = @toolVersion
        # isBatchJob is used to indicate to future tools (runExceRpt, processPipelineRuns) that we're running a batch job
        # This is useful, for example, to let PPR know that inputs have already been downloaded and are local (as opposed to running PPR tool independently)
        @settings['isBatchJob'] = true
        # Settings used for final erccProcessing tool 
        @settings['processingPipeline'] = "exceRpt small RNA-seq"
        @settings['processingPipelineVersion'] = @toolVersion
        @settings['processingPipelineIdAndVersion'] = "exceRptPipeline_v#{@toolVersion}"
        @settings['platform'] = "FTP Submission Pipeline"
        @settings['isFTPJob'] = true
        # Save the job ID for exceRpt so that we can use it in tool usage doc 
        @settings['primaryJobId'] = @jobId
        # This hash will store all job IDs submitted below as part of our batch submission (and will store info about input files as well)
        @listOfJobIds = {}
        # Get location of the shared scratch space in the cluster
        @clusterSharedScratchDir = @genbConf.clusterSharedScratchDir
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "SHARED SCRATCH SPACE: #{@clusterSharedScratchDir}")
        if(@clusterSharedScratchDir.nil? or @clusterSharedScratchDir.empty?) 
          @errUserMsg = "ERROR: Genboree config does not have the shared scratch location information."
          raise @errUserMsg
        end
        # If shared scratch space exists, then create specific directory for this exceRpt job. 
        # This directory will hold various subdirectories:
        #   1. Directory to store post-processing files (both CORE_RESULTS archive inputs (in runsDir) and output files (in @postProcOutputDir))
        #   2. Directory to store metadata (for processing and uploading)
        #   3. Directory to store user-defined custom calibrator/spike-in libraries
        if(File.directory?(@clusterSharedScratchDir))
          # Directory for exceRpt job 
          @jobSpecificSharedScratch = "#{@clusterSharedScratchDir}/#{@jobId}"
          @settings['jobSpecificSharedScratch'] = @jobSpecificSharedScratch
          # Post-processing runs directory and output directory 
          @postProcDir = "#{@jobSpecificSharedScratch}/subJobsScratch/processPipelineRuns"
          @settings['postProcDir'] = @postProcDir
          runsDir = "#{@postProcDir}/runs"
          `mkdir -p #{runsDir}`
          @postProcOutputDir = "#{@postProcDir}/outputFiles"
          `mkdir -p #{@postProcOutputDir}`
          # Directory for metadata processing and uploading
          @metadataDir = "#{@jobSpecificSharedScratch}/metadata"
          `mkdir -p #{@metadataDir}`
          @finalizedMetadataDir = "#{@jobSpecificSharedScratch}/finalizedMetadata"
          `mkdir -p #{@finalizedMetadataDir}`
          @settings['finalizedMetadataDir'] = @finalizedMetadataDir
          # Directory for user defined custom calibrator/spike-in libraries
          # Manifest file will contain info about spike-in use (whether we're using library or not, whether library is local or on Genboree)
          @calibratorDir = "#{@jobSpecificSharedScratch}/calibrator"
          `mkdir -p #{@calibratorDir}`
          # Directory to store mappings between archives and unextracted files - temporary!
          `mkdir -p #{@jobSpecificSharedScratch}/samples/unextractedToExtractedMappings`
          # Create importantJobIdsDir (will store all important job IDs - IDs reported to user in final email, IDs used to determine which samples passed/failed)
          importantJobIdsDir = "#{@jobSpecificSharedScratch}/importantJobIds"
          `mkdir -p #{importantJobIdsDir}`
          @settings['importantJobIdsDir'] = importantJobIdsDir
        else
          @errUserMsg = "ERROR: Shared scratch dir #{@clusterSharedScratchDir} is not available."
          raise @errUserMsg
        end
        # Assign appropriate input locations to variables
        @inputs.each { |inputLocation|
          if(inputLocation =~ /(.+?)\.(?i)manifest(?-i)\.json$/)
            @manifestLocation = inputLocation
            @settings['manifestLocation'] = @manifestLocation
          elsif(inputLocation =~ /(.+?)_(?i)metadata(?-i)(?:\.tar\.gz|\.zip)$/)
            @metadataArchiveLocation = inputLocation
            @settings['metadataArchiveLocation'] = @metadataArchiveLocation
          else
            @dataArchiveLocation = inputLocation
            @settings['dataArchiveLocation'] = @dataArchiveLocation
          end
        }
        # Assign appropriate output locations to variables
        @outputs.unshift("http://{HOST}/REST/v1/grp/{GROUP_NAME}/db/{DB_NAME}")
        @outputs.each { |outputLocation|
          if(outputLocation =~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
            @outputDb = outputLocation
            @outputDb.gsub!(/\{HOST\}/, @settings['outputHost'])
          elsif(outputLocation =~ /\/finished\//)
            @finishedFtpDir = outputLocation
            @settings['finishedFtpDir'] = @finishedFtpDir
          elsif(outputLocation =~ /\/failed\//)
            @failedFtpDir = outputLocation
            @settings['failedFtpDir'] = @failedFtpDir
          end
        }
        # Save path to user's inbox (so we can easily put files back in it in case of job failure)
        @inboxFtpDir = @failedFtpDir.slice(0...@failedFtpDir.index("failed")) << "inbox/"
        @backupFtpDir = @failedFtpDir.gsub("/failed/", "/backup/")
        @settings['backupFtpDir'] = @backupFtpDir
        # Grab PI ID to use later in metadata document names
        @piID = @inboxFtpDir.scan(/exrna-[A-Za-z0-9]+/)[0][6..-1].upcase
        # Grab exRNA-specific host / group / KB associated with submitted job (for metadata submission)
        @exRNAHost = @settings['exRNAHost']
        @exRNAKbGroup = @settings['exRNAKbGroup']
        @exRNAKb = @settings['exRNAKb']
        @exRNAKbProject = @settings['exRNAKbProject']
        @genboreeKbArea = @settings['genboreeKbArea']
        # Set up data collection helper so we can validate docs
        dbu = BRL::Genboree::DBUtil.new("DB:#{@exRNAHost}", nil, nil)
        kbRecs = dbu.selectKbByNameAndGroupName(@exRNAKb, @exRNAKbGroup)
        if(kbRecs.nil?)
          raise BRL::Genboree::GenboreeError.new(:"Not Found", "Could not retrieve KB information for host: #{@exRNAHost}, group:#{@exRNAKbGroup}, and kb:#{@exRNAKb}")
        end
        mdbName = kbRecs.first['databaseName']
        mongoDbrcRec = @suDbDbrc.getRecordByHost(@genbConf.machineName, :nosql)
        @mdb = BRL::Genboree::KB::MongoKbDatabase.new(mdbName, mongoDbrcRec[:driver], { :user => mongoDbrcRec[:user], :pass => mongoDbrcRec[:password] })
        # Grab internal exRNA host / group / KB (for PI / Submitter info)
        @exRNAInternalKBHost = @genbConf.exRNAInternalKBHost
        @exRNAInternalKBGroup = @genbConf.exRNAInternalKBGroup
        @exRNAInternalKBName = @genbConf.exRNAInternalKBName
        # Grab exRNA metadata collection names from config file and set up a variable for each collection name
        @collections = JSON.parse(File.read(@genbConf.FTPsmRNAPipelineKBCollections))
        @analysisCollection = @collections["Analysis"]
        @biosampleCollection = @collections["Biosample"]
        @donorCollection = @collections["Donor"]
        @experimentCollection = @collections["Experiment"]
        @runCollection = @collections["Run"]
        @studyCollection = @collections["Study"]
        @submissionCollection = @collections["Submission"]
        # Grab exRNA internal collection name for ERCC PI docs
        @piCollection = @genbConf.exRNAInternalKBPICodesColl
        # If @debuggingTool is enabled, we will move all files back to /inbox after failed job (for easy repeated testing).
        # Should not be enabled for production.
        @debuggingTool = false
        # Variable to keep track of error messages
        @errUserMsg = nil
        # Variable to keep track of which original input files (manifest / metadata archive / data archive) are working (for reporting to user in error e-mail)
        @workingFiles = []
        # Variable to keep track of which original input files (manifest / metadata archive / data archive) are broken (for reporting to user in error e-mail)
        @brokenFiles = []
        # @failedJobs is a hash that will keep track of which runExceRpt jobs fail - this hash will store the respective error messages for each failed sample.
        @failedJobs = {}
      rescue => err
        @errUserMsg = "ERROR: Could not load initial settings for running the FTP exceRpt pipeline."
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
        # Hash that will contain input file names and associated output files (for uploading and proper clean up)
        # Each inputFile key will be linked to a hash that contains the following values:
        #   :originalFileName => name of original file associated with a given sample / input file (before decompression)
        #   :fileType => file type of sample / input file (FASTQ / SRA), sniffed during the download / check of the data archive
        #   :failedRun => boolean flag telling us whether pipeline job succeeded or failed (false = succeeded, true = failed)
        #   :md5 => md5 string for that particular file (used in filling out Run document)
        #   :biosampleMetadataFileName => name of biosample metadata document associated with input file
        #   :adapterSequence => adapter sequence for a particular sample (if it's given)
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
        # Path to downloaded manifest file
        @manifestFile = nil
        # Create converter and producer for use throughout - we don't need model for any reason so set producer's model to nil
        @converter = BRL::Genboree::KB::Converters::NestedTabbedDocConverter.new()
        @producer = BRL::Genboree::KB::Producers::NestedTabbedDocProducer.new(nil)
        # Set up sniffer
        @sniffer = BRL::Genboree::Helpers::Sniffer.new()
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "BEGIN FTP version of exceRpt small RNA-seq Pipeline (version 4.6.2)")
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
        if(@multiColumnBiosample)
          # Convert multi-column tabbed biosamples into individual biosample files
          @exitCode = convertMultiColumnBiosamples()
        end
        checkError(2)
        # If the user supplied a general donor metadata file above the individual samples, then we need to figure out what to do with that file.
        # That file could either a) be a single doc that applies to all samples that don't have an explicit donor associated with them in the manifest file, or
        #                        b) be a multi-column doc that covers all samples.
        # We will investigate that below.
        if(@foundDonorDoc)
          @multiDonorDoc = false
          @exitCode = checkAndConvertMultiColumnDonors()
        end
        checkError(2)
        # If the user supplied a general experiment metadata file above the individual samples, then we need to figure out what to do with that file.
        # That file could either a) be a single doc that applies to all samples that don't have an explicit experiment associated with them in the manifest file, or
        #                        b) be a multi-column doc that covers all samples.
        # We will investigate that below.
        if(@foundExperimentDoc)
          @multiExperimentDoc = false
          @exitCode = checkAndConvertMultiColumnExperiments()
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
          @errUserMsg = "There were errors in your metadata file(s). Please see the following list and fix all errors before resubmitting:\n"
          @errUserMsg << "\n=================================================================\n"
          @errUserMsg << @metadataErrors.join("\n=================================================================\n")
          @errUserMsg << "\n=================================================================\n"
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
          # Since we're now extracting files in runExceRpt, we can't grab the final file name at this stage.
          # At least for now, if users compress individual FASTQ files, they have to provide the archive names instead.
          #finalFileName = File.basename(currentFile)
          @manifest.each { |currentSample|
            if(currentSample["dataFileName"] == originalFileName)
              @inputFiles[currentFile][:biosampleMetadataFileName] = currentSample["biosampleMetadataFileName"]
              if(currentSample["adapterSequence"])
                @inputFiles[currentFile][:adapterSequence] = currentSample["adapterSequence"]
              end
            end
          }
          # If we can't find a link between the current @inputFiles key and a biosample doc, then we raise an error.
          unless(@inputFiles[currentFile][:biosampleMetadataFileName])
            if(@errUserMsg.nil? or @errUserMsg.empty?)
              @errUserMsg = "We failed to link some of your submitted data files to any of the \"dataFileName\" fields in your manifest file.\nIf you submit a data file, it should be listed in the manifest under\nits compressed name if it is compressed in your data archive.\nA list of problematic files can be found below:\n\n"
              @exitCode = 35
            end
            @errUserMsg << "#{originalFileName}\n"
          end
        }
        checkError(1)
        #### SETTING UP SPIKE-IN LIBRARY ####
        setUpSpikeInLibrary()
        checkError(1)
        #### RUNNING EXCERPT SMALL RNA-SEQ PIPELINE ON SAMPLES ####
        # Create /finished directory for original files (they'll be placed there if at least one sample in submission is processed correctly)
        @ftpHelper.mkdir(@finishedFtpDir)
        @ftpHelper.mkdir(@backupFtpDir)
        @ftpHelper.mkdir("#{@backupFtpDir}/data")
        # Submit runExceRpt jobs
        submitJobs()
        checkError(1)
        # Write updated metadata files to disk
        @metadataFiles.each { |currentDocs|
          currentRootProp = currentDocs.values[0].getRootProp()
          coll = @collections[currentRootProp]
          currentDir = "#{@finalizedMetadataDir}/#{coll}"
          `mkdir -p #{currentDir}`
          currentDocs.each_key { |currentFileName|
            File.open("#{currentDir}/#{File.basename(currentFileName)}", 'w') { |file| file.write(JSON.pretty_generate(currentDocs[currentFileName])) }
          }
        }
        # Write updated manifest to disk
        File.open(@manifestFile, 'w') { |file| file.write(JSON.pretty_generate(@fileData)) }
        # We'll also write our @inputFiles hash to disk so we can use that in erccFinalProcessing
        File.open("#{@jobSpecificSharedScratch}/inputFilesHash.txt", 'w') { |file| file.write(JSON.pretty_generate(@inputFiles)) } 
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE with batch submission of exceRpt Pipeline (version #{@toolVersion}) jobs. END.")
        # DONE FTPexceRptPipeline batch submission
      rescue => err
        # Generic "catch-all" error message for exceRpt small RNA-seq pipeline error
        @errUserMsg = "ERROR: Running of exceRpt small RNA-seq Pipeline failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        # We only want to set the generic @exitCode of 50 if there isn't another @exitCode already set (22 for bad manifest, for example)
        @exitCode = 50 if(@exitCode == 0)
        # Let's clean up the job-specific scratch area, since the job failed
        cleanUp([], [], @jobSpecificSharedScratch)
      ensure
        # Make sure that we close @ftpHelper.ftpObj (to close connection to FTP server) and set it to nil
        @ftpHelper.ftpObj.close() rescue nil
        @ftpHelper = nil
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
        tmpFile = "#{@jobSpecificSharedScratch}/#{fileBaseName.makeSafeStr(:ultra)}"
        retVal = @ftpHelper.downloadFromFtp(manifestLocation, tmpFile)
        # If there's an error downloading the manifest file, report that to the user
        unless(retVal)
          @errUserMsg = "Failed to download manifest file: #{fileBaseName} from FTP server."
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Net::FTP helper failed to download manifest file #{fileBaseName} from FTP server")
          raise @errUserMsg
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file downloaded successfully to #{tmpFile}")
        # Convert to unix format
        convObj = BRL::Util::ConvertText.new(tmpFile, true)
        convObj.convertText()
        # Count number of lines in the input file
        numLines = `wc -l #{tmpFile}`
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of lines in manifest file #{File.basename(tmpFile)}: #{numLines.split(" ")[0]}")
        # Save the manifest file in @manifestFile
        @manifestFile = tmpFile.clone
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "File #{@manifestFile} is a manifest file")
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: The manifest file could not be downloaded properly." if(@errUserMsg.nil?)
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
        tmpFile = "#{@jobSpecificSharedScratch}/#{fileBaseName.makeSafeStr(:ultra)}"
        retVal = @ftpHelper.downloadFromFtp(metadataArchiveLocation, tmpFile)
        # If there's an error downloading the metadata archive, report that to the user
        unless(retVal)
          @errUserMsg = "Failed to download metadata archive: #{fileBaseName} from FTP server."
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Net::FTP helper failed to download metadata archive #{fileBaseName} from FTP server")
          raise @errUserMsg
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Metadata archive downloaded successfully to #{tmpFile}")
        # Extract metadata archive and move contents to metadata directory
        exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracting metadata archive file #{tmpFile}")
        exp.extract()
        # Rename metadata directory to have friendlier name
        `mv #{exp.tmpDir}/* #{@metadataDir}`
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Contents of metadata archive moved to #{@metadataDir}")
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (hopefully won't happen)
        @errUserMsg = "ERROR: The metadata archive could not be downloaded and/or extracted properly." if(@errUserMsg.nil?)
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
        tmpFile = "#{@jobSpecificSharedScratch}/#{fileBaseName.makeSafeStr(:ultra)}"
        retVal = @ftpHelper.downloadFromFtp(@dataArchiveLocation, tmpFile)
        # If there's an error downloading the data archive, report that to the user        
        unless(retVal)
          @errUserMsg = "ApiCaller failed: failed to download data archive #{fileBaseName} from FTP server."
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Net::FTP helper failed to download data archive #{fileBaseName} from FTP server")
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
        @errInputs = {:emptyFiles => [], :badFormat => [], :badArchives => []}
        checkForInputs(tmpFile, true)
        foundError = false
        @errInputs.each_value { |categoryValue| foundError = true unless(categoryValue.empty?) }
        if(foundError)
          @errUserMsg = "We encountered some errors when processing your archives from Genboree.\n"
          @errUserMsg << "Individual error messages are printed below:"
          @errInputs.each_key { |category|
            unless(@errInputs[category].empty?)
              msg = ""
              if(category == :emptyFiles)
                msg = "\n\nAt least some of the files you submitted are empty.\nWe cannot process empty files.\nA list of empty files can be found below:\n"
              elsif(category == :badFormat)
                msg = "\n\nAt least some of the files you submitted were not recognized as FASTQ, SRA, or archive format.\nYour submitted archives should only contain these types of files.\nA list of problematic files can be found below:\n"
              elsif(category == :badArchives)
                msg = "\n\nAt least some of your submitted archives could not be extracted.\nIt is possible that the archives are empty or corrupt.\nPlease check the validity of the archives and try again.\nA list of problematic archives can be found below:\n"
              end
              unless(msg.empty?)
                @errUserMsg << "#{msg}\n#{@errInputs[category].join("\n\n")}"
              end
            end
          }
        end
        raise @errUserMsg unless(@errUserMsg.nil?)
        # Make sure that all data files mentioned in manifest are present in the (unzipped) data archive
        extractedDataFiles = []
        missingManifestDataFiles = []
        @inputFiles.each_key { |currentFileRec| extractedDataFiles << @inputFiles[currentFileRec][:originalFileName] }
        @fileData["manifest"].each { |currentSampleRec|
          currentDataFile = currentSampleRec["dataFileName"]
          missingManifestDataFiles << currentDataFile unless(extractedDataFiles.include?(currentDataFile))
        }
        unless(missingManifestDataFiles.empty?)
          @errUserMsg = "At least some of the data files mentioned in your manifest\ncould not be found in your data archive.\nA list of these files can be seen below:\n\n#{missingManifestDataFiles.join("\n")}"
          raise @errUserMsg
        end
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There was an error downloading / decompressing / checking your data archive." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 34
      end
      return @exitCode
    end

    # Method that is used recursively to check what inputs each submitted file contains
    # @param [String] inputFile file name or folder name currently being checked
    # @param [boolean] continueExtraction boolean that determines whether we're going to extract the current file (only used for those files grabbed from Workbench)
    # @return [nil]
    def checkForInputs(inputFile, continueExtraction=false)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current input file: #{inputFile}")
      # If we have an empty file (not inside of an archive!) then let's check that here.
      # We won't continue to check the file if it's empty at this stage.
      expError = false
      if(File.zero?(inputFile))
        @errInputs[:emptyFiles] << File.basename(inputFile)
      else
        # First, check to see if inputFile is a directory. If it's not, we'll just extract it.
        unless(File.directory?(inputFile))
          if(continueExtraction)
            # Create Expander object on current file and try to extract current file.
            # If Expander has an error while attempting to extract the archive, then we will set expError to be true and save the name of the archive in :badArchives 
            exp = BRL::Util::Expander.new(inputFile)
            begin
              exp.extract()
            rescue => err
              expError = true
              @errInputs[:badArchives] << File.basename(inputFile)
            end
            # If our Expander object didn't error out while extracting the file, we should still check exp.stderrStr to see if any non-fatal errors occurred
            unless(expError)
              expanderErrors = exp.stderrStr
              # If there is any content in stderrStr, then the archive is still bad and we need to report that
              unless(expanderErrors.empty?)
                expError = true
                @errInputs[:badArchives] << File.basename(inputFile)
              end
              unless(expError)
                oldInputFile = inputFile.clone()
                inputFile = exp.uncompressedFileName
                # Delete old archive if there was indeed an archive (it's uncompressed now so we don't need to keep it around)
                `rm -f #{oldInputFile}` unless(exp.compressedFileName == exp.uncompressedFileName)
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uncompressed file name: #{inputFile}")
              end
            end
          end
        end
        unless(expError)
          # Now, we'll check to see if the file is a directory or not - remember, we could have 
          # uncompressed a directory above!
          if(File.directory?(inputFile))
            # If we have a directory, grab all files in that directory and send them all through checkForInputs recursively
            allFiles = Dir.entries(inputFile)
            allFiles.each { |currentFile|
              next if(currentFile == "." or currentFile == ".." or currentFile == "__MACOSX")
              checkForInputs("#{inputFile}/#{currentFile}", false)
            }
          else
            # OK, so we have a file. First, let's make the file name safe 
            fixedInputFile = File.basename(inputFile).makeSafeStr(:ultra)
            # Get full path of input file and replace last part of that path (base name) with fixed file name
            inputFileArr = inputFile.split("/")
            inputFileArr[-1] = fixedInputFile
            fixedInputFile = inputFileArr.join("/")
            # Rename file so that it has fixed file name
            `mv #{Shellwords.escape(inputFile)} #{fixedInputFile}`
            # Check to see if file is empty. We have to do this again because it might have been inside of a (non-empty) archive earlier!
            if(File.zero?(fixedInputFile))
              @errInputs[:emptyFiles] << File.basename(inputFile)
            else
              # Sniff file and see whether it's FASTQ, SRA, FASTA, or one of our supported compression formats
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Sniffing file type of #{fixedInputFile}")
              @sniffer.filePath = fixedInputFile
              fileType = @sniffer.autoDetect()
              if(fileType == "fastq" or fileType == "sra" or fileType == "zip" or fileType == "xz" or fileType == "tar" or fileType == "bz2" or fileType == "7z" or fileType == "gz")
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input file #{fixedInputFile} is in correct format, FASTQ or SRA (or an archived format that we support)")
                @inputFiles[fixedInputFile] = {:originalFileName => File.basename(inputFile), :fileType => "FASTQ", :failedRun => false, :md5 => nil, :errorMsg => ""}
              elsif(fileType == "fa")
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input file #{fixedInputFile} is a spike-in file (FASTA)")
                # Convert to unix format
                convObj = BRL::Util::ConvertText.new(fixedInputFile, true)
                convObj.convertText()
                # Count number of lines in the input file
                numLines = `wc -l #{fixedInputFile}`
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of lines in file #{fixedInputFile} ::: #{numLines.split(" ")[0]}")
                # Set up spike-in file for creation of bowtie2 index by moving it to calibrator directory
                spikeInFileBaseName = File.basename(fixedInputFile)
                @spikeInName = spikeInFileBaseName.makeSafeStr(:ultra)
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Spike-in file is called #{@spikeInName}")
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Moving spike-in file #{fixedInputFile} to calibrator dir #{@calibratorDir}/.")
                `mv #{fixedInputFile} #{@calibratorDir}/.`
                @spikeInFile = "#{@calibratorDir}/#{spikeInFileBaseName}"
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Spike-in file #{@spikeInFile} is available in calibrator dir #{@calibratorDir}/.")
              else
                # Ignore the junk ._ files that Mac archiver puts into archives - we'll assume those are just extraneous files and NOT stop the submission pipeline if we find them
                unless(File.basename(fixedInputFile)[0..1] == "._")
                  @errInputs[:badFormat] << File.basename(inputFile)
                end
              end
            end
          end
        end
      end
      return
    end

    # Download custom oligo/spike-in FASTA file from database, extract zipped file, and sniff this file to make sure it is in FASTA format
    # @param [String] newOligoFile resource path to spike-in file on Genboree
    # @return [Fixnum] exit code indicating whether download of spike-in file was successful (0) or failed (55)
    def downloadSpikeInFile(newOligoFile) 
      begin
        # Check to make sure that spike-in file actually exists 
        unless(@fileApiHelper.exists?(newOligoFile))
          @errUserMsg = "We could not find the spike-in file listed in your manifest file.\nAre you sure that you gave the correct name under \"existingLibraryName\"?\nAre you sure that you uploaded your spike-in file correctly to the \"spikeInLibraries\" folder in your \"Files\" area?" 
          raise @errUserMsg
        end
        # Download spike-in file
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading spike-in file #{newOligoFile}")
        fileBase = @fileApiHelper.extractName(newOligoFile)
        fileBaseName = File.basename(fileBase)
        tmpFile = "#{@jobSpecificSharedScratch}/#{fileBaseName.makeSafeStr(:ultra)}"
        retVal = @fileApiHelper.downloadFile(newOligoFile, @subUserId, tmpFile)
        # If there's an error downloading the spike-in file, report that to the user    
        unless(retVal)
          @errUserMsg = "Failed to download spike-in file #{fileBase} from Genboree.\nIs it possible that you put the wrong file name?\nIf the file name is correct, please contact a DCC admin."
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
        # Check to make sure that archive only contains one file (uncompressed FASTQ / SRA)
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
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of lines in spike-in file #{inputFile}: #{numLines.split(" ")[0]}")
        spikeInFileBasename = File.basename(inputFile)
        # Move spike-in file to calibrator directory and set up @spikeInFile variable
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Moving spike-in file #{inputFile} to calibrator dir #{@calibratorDir}/.")
        `mv #{inputFile} #{@calibratorDir}/.`
        @spikeInFile = "#{@calibratorDir}/#{spikeInFileBasename}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Spike-in file #{@spikeInFile} is available in calibrator dir #{@calibratorDir}/.")
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There was an error downloading your spike-in file." if(@errUserMsg.nil?)
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
        # Convert to unix format
        convObj = BRL::Util::ConvertText.new(manifestFile, true)
        convObj.convertText()
        # Count number of lines in the manifest file
        numLines = `wc -l #{manifestFile}`
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of lines in manifest file #{manifestFile} ::: #{numLines.split(" ")[0]}")
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
        @settings['subUserId'] = @subUserId
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
          errors << "Could not grab userLogin's first name / last name / email."
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
        # Note - group name for results is set in job conf now - user doesn't provide it!
        @groupName = CGI.escape(@settings['outputGroup'])
        @outputDb.gsub!(/\{GROUP_NAME\}/, @groupName)
        # Note - db name for results is set in job conf now - user doesn't provide it!
        @dbName = CGI.escape(@settings['outputDb'])
        @outputDb.gsub!(/\{DB_NAME\}/, @dbName)
        # Grab user-submitted settings (given in manifest) and merge them with default options
        if(!@fileData.key?("settings") or @fileData["settings"].nil? or @fileData["settings"].empty?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file does not have user-submitted settings. We will use default settings for pipeline jobs.")
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Merging user-submitted settings with default options (will override defaults)")
          # We do NOT allow user to edit exogenous mapping setting for FTP pipeline - by default, it will always be on, but if we need to use a different setting,
          # that setting can be updated in the default tool job conf used by the relevant polling area
          @fileData["settings"].delete('exogenousMapping')
          @settings.merge!(@fileData["settings"])
        end
        unless(@settings['remoteStorageArea'])
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Initial job conf (provided by us!) doesn't have remote storage area (remoteStorageArea). We need to add it!")
          errors << "The DCC Admins have not properly set up a remote storage area (virtual FTP area) for your submission. Please contact a DCC admin to fix this issue."  
        end
        #### ANALYSIS DOC ####
        # Check if Analysis metadata doc is available. Otherwise, auto-generate analysis doc for user (we will fill it in after pipeline runs are finished).
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
          analysisMetadataFileName = "#{currentID}.metadata.tsv"
          File.open("#{@metadataDir}/#{analysisMetadataFileName}", 'w') { |file| file.write(updatedAnalysisDoc) }
          @autoGeneratedAnalysisMetadataFileName = analysisMetadataFileName
          # Save new analysis metadata filename to manifest
          @fileData["analysisMetadataFileName"] = analysisMetadataFileName
        end
        #### MULTI-COLUMN BIOSAMPLE DOC ####
        # See if user has included a multi-column tabbed file for his/her biosamples. If so, we will not require biosample names for individual samples.
        @multiColumnBiosample = false
        if(!@fileData.key?("biosampleMetadataFileName") or @fileData["biosampleMetadataFileName"].nil? or @fileData["biosampleMetadataFileName"].empty?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file does not have multi-column tabbed file for biosamples. It is possible that biosample metadata is submitted for each biosample.")
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file has multi-column tabbed file for biosamples. We will set flag for processing multi-column tabbed file.")
          @multiColumnBiosample = true
        end
        #### MAIN/MULTI-COLUMN DONOR DOC ####
        # Check if Donor metadata doc is available. This file could be a multi-column donor file or it could just contain a single general doc. If this file isn't available, then no error (since user could have submitted donor metadata doc for each biosample).
        @foundDonorDoc = false
        if(!@fileData.key?("donorMetadataFileName") or @fileData["donorMetadataFileName"].nil? or @fileData["donorMetadataFileName"].empty?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file does not contain general donor metadata file name. It is possible that donor metadata is submitted for each biosample.")
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file contains general donor metadata file name. This name is used for any samples that do not have a donor metadata file name.")
          # @foundDonorDoc will keep track of whether we found a general donor doc (applies to all samples without specific donor docs)
          @foundDonorDoc = true
        end
        #### MAIN/MULTI-COLUMN EXPERIMENT DOC ####
        # Check if Experiment metadata doc is available. This file could be a multi-column experiment file or it could just contain a single general doc. If this file isn't available, then no error (since user could have submitted experiment metadata doc for each biosample).
        @foundExperimentDoc = false   
        if(!@fileData.key?("experimentMetadataFileName") or @fileData["experimentMetadataFileName"].nil? or @fileData["experimentMetadataFileName"].empty?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file does not contain experiment metadata file name. It is possible that experiment metadata is submitted for each biosample.")
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file contains general experiment metadata file name. This name is used for any samples that do not have an experiment metadata file name.")
          # @foundExperimentDoc will keep track of whether we found a general experiment doc (applies to all samples without specific experiment docs)
          @foundExperimentDoc = true
        end
        #### RUN DOC ####
        # Check if name of Run metadata doc is available. Otherwise, give error (no Run document is not acceptable).
        if(!@fileData.key?("runMetadataFileName") or @fileData["runMetadataFileName"].nil? or @fileData["runMetadataFileName"].empty?)
          errors << "Manifest file does not contain run metadata file name.\nThe \"runMetadataFileName\" field is required.\nPlease put a valid run metadata file name and resubmit your job."
        end
        #### STUDY DOC ####
        # Check if Study metadata doc is available. Otherwise, give error (no Study document is not acceptable).
        if(!@fileData.key?("studyMetadataFileName") or @fileData["studyMetadataFileName"].nil? or @fileData["studyMetadataFileName"].empty?)
          errors << "Manifest file does not contain study metadata file name.\nThe \"studyMetadataFileName\" field is required.\nPlease put a valid study metadata file name and resubmit your job."
        end
        #### SUBMISSION DOC ####
        # Check if Submission metadata doc is available. Otherwise, give error (no Submission document is not acceptable).
        if(!@fileData.key?("submissionMetadataFileName") or @fileData["submissionMetadataFileName"].nil? or @fileData["submissionMetadataFileName"].empty?)
          errors << "Manifest file does not contain submission metadata file name.\nThe \"submissionMetadataFileName\" field is required.\nPlease put a valid submission metadata file name and resubmit your job."
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Data from the manifest file #{manifestFile}: #{@fileData.inspect}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Output database: #{@outputDb}")
        # Grab sample-specific portion of manifest file - this should be proper JSON if entire manifest file was read in correctly earlier
        @manifest = @fileData["manifest"]
        #### CHECKING INDIVIDUAL SAMPLES ####
        count = 0
        sampleErrors = {:sampleName => [], :adapterSeq => [], :biosample => [], :donor => [], :experiment => [], :dataFile => []}
        @manifest.each { |eachSampleHash|
          count += 1
          #### CHECKING SAMPLE NAME ####
          # Check if sample name is provided for sample - if not, we raise an error (it's required!).
          # Note that this sample name must match the "Biosample.Name" field for the associated biosample.
          if(!eachSampleHash.key?("sampleName") or eachSampleHash["sampleName"].nil? or eachSampleHash["sampleName"].empty?)
            sample = "##{count} in your \"manifest\" hash array (no sample name given)"
            sampleErrors[:sampleName] << sample
          else
            sample = eachSampleHash["sampleName"]
          end
          ### CHECKING FOR SAMPLE-SPECIFIC ADAPTER SEQ ####
          # Check if adapter sequence is provided for sample - if not, no issue (is probably handled by settings).
          if(!eachSampleHash.key?("adapterSequence") or eachSampleHash["adapterSequence"].nil? or eachSampleHash["adapterSequence"].empty?)
          else
            # OK, so there's an adapter sequence listed.
            # Now, let's verify that it looks OK. We WILL raise an error if there is something bogus written for a sample's adapter sequence.
            # Note that we'll actually connect input files with their respective adapter sequences later on.
            if(eachSampleHash["adapterSequence"] != "autoDetect" and eachSampleHash["adapterSequence"] != "none" and eachSampleHash["adapterSequence"] !~ /^[ATGCNatgcn]+$/)
              sampleErrors[:adapterSeq] << sample
            end
          end          
          #### CHECKING BIOSAMPLE ASSOCIATED WITH SAMPLE ####
          # Check if biosample metadata file name is provided.
          # If there is no biosample metadata file name provided, then a multi-column tabbed biosample doc must be provided (@multiColumnBiosample must be true). 
          # If not, we raise an error.
          unless(@multiColumnBiosample)
            if(!eachSampleHash.key?("biosampleMetadataFileName") or eachSampleHash["biosampleMetadataFileName"].nil? or eachSampleHash["biosampleMetadataFileName"].empty?)
              sampleErrors[:biosample] << sample
            end
          end
          #### CHECKING DONOR ASSOCIATED WITH SAMPLE ####
          # Check if donor metadata file name is provided.
          # If there is no donor metadata file name provided, then a general donor doc must be provided (generalDonorDoc must be true). 
          # If not, we raise an error.
          if(!eachSampleHash.key?("donorMetadataFileName") or eachSampleHash["donorMetadataFileName"].nil? or eachSampleHash["donorMetadataFileName"].empty?)
            unless(@foundDonorDoc)
              sampleErrors[:donor] << sample
            end
          end            
          #### CHECKING EXPERIMENT ASSOCIATED WITH SAMPLE ####
          # Check if experiment metadata file name is provided.
          # If there is no experiment metadata file name provided, then a general experiment doc must be provided (generalExperimentDoc must be true). 
          # If not, we raise an error.
          if(!eachSampleHash.key?("experimentMetadataFileName") or eachSampleHash["experimentMetadataFileName"].nil? or eachSampleHash["experimentMetadataFileName"].empty?)
            unless(@foundExperimentDoc)
              sampleErrors[:experiment] << sample
            end
          end
          #### CHECKING DATA FILE NAME ASSOCIATED WITH SAMPLE ####
          # Check if data file name is provided - if not, we raise an error (it's required!).
          if(!eachSampleHash.key?("dataFileName") or eachSampleHash["dataFileName"].nil? or eachSampleHash["dataFileName"].empty?)
            sampleErrors[:dataFile] << sample
          end
        }
        foundSampleError = false
        sampleErrors.each_value { |categoryValue| foundSampleError = true unless(categoryValue.empty?) }
        if(foundSampleError)
          sampleErrors.each_key { |category|
            unless(sampleErrors[category].empty?)
              msg = ""
              if(category == :sampleName)
                msg = "Manifest file is missing a \"sampleName\" value\nfor the following samples:"
              elsif(category == :adapterSeq)
                msg = "Manifest file has invalid adapter sequences\nfor the following samples:"
              elsif(category == :biosample)
                msg = "Manifest file is missing a \"biosampleMetadataFileName\" value\n for the following samples:"
              elsif(category == :donor)
                msg = "Manifest file is missing a \"donorMetadataFileName\" value\nfor the following samples (and no general \"donorMetadataFileName\" is given above the list of samples):"
              elsif(category == :experiment)
                msg = "Manifest file is missing an \"experimentMetadataFileName\" value\nfor the following samples (and no general \"experimentMetadataFileName\" is given above the list of samples):"
              elsif(category == :dataFile)
                msg = "Manifest file is missing a \"dataFileName\" value\nfor the following samples:"
              end
              unless(msg.empty?)
                errors << "#{msg}\n\n#{sampleErrors[category].join("\n")}"
              end
            end
          }
        end
        unless(errors.empty?)
          @errUserMsg = "Some errors occurred while traversing your manifest file.\n\n======================LIST OF ISSUES==============================\n"
          @errUserMsg << errors.join("\n=================================================================\n")
          @errUserMsg << "\n================================================================="
          raise @errUserMsg
        end
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: The manifest file does not have all required variables for running the job." if(@errUserMsg.nil?)
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
        # Figure out host / user / pass for API calls
        dbrcKey = @context['apiDbrcKey']
        dbrc = BRL::DB::DBRC.new(@dbrcFile, dbrcKey)
        host = dbrc.driver.split(/:/).last
        user = dbrc.user
        pass = dbrc.password
        errors = []
        # We require analysis name to be given in the manifest file - if it's not given, we raise an error
        unless(@settings['analysisName'])
          errors << "You did not provide a value for the analysisName setting.\nPlease provide an informative analysis name like \"AMILO1-GastCancVsControls-2017-09-12\"\nin your manifest file."
        else
          @analysisName = @settings['analysisName']
        end
        # Check to make sure that adapterSequence setting is valid - default of "autoDetect" (which makes adSeqParameter "guessKnown" for exceRpt)
        @settings['adapterSequence'] = "autoDetect" unless(@settings['adapterSequence'])
        # If adapter sequence is "autoDetect", then the user wants to auto-detect the adapter sequence
        if(@settings['adapterSequence'] == "autoDetect")
          @settings['adSeqParameter'] = 'guessKnown'
        else
           @settings['adSeqParameter'] = @settings['adapterSequence']
        end
        if(@settings['adapterSequence'] != "autoDetect" and @settings['adapterSequence'] != "none" and @settings['adapterSequence'] !~ /^[ATGCNatgcn]+$/)
          errors << "Your value for adapterSequence is invalid.\nYou can write \"autoDetect\" (if you want the pipeline to auto-detect your adapter sequence)\n\"none\" if your input sequences have already had their 3' adapter sequence clipped,\nor you can manually input your adapter sequence (consisting only of ATGCN characters)."
        end
        # Check to make sure that exogenousMapping setting is valid - default of off
        @settings['exogenousMapping'] = "off" unless(@settings['exogenousMapping'])
        if(@settings['exogenousMapping'] != "off" and @settings['exogenousMapping'] != "miRNA" and @settings['exogenousMapping'] != "on")
          errors << "Your value for exogenousMapping is invalid.\nYou can write \"off\" for endogenous-only mapping, \"miRNA\" to map to exogenous miRNAs in miRBase,\nor \"on\" for full exogenous mapping (the genomes of all sequenced species in Ensembl/NCBI)."
        end
        # We will always use 36 GB of Java RAM and 8 threads (current version of exceRpt is more memory intensive than the older versions)
        @settings['javaRam'] = "36G"
        @settings['numThreads'] = 8
        # If exogenous mapping is set to 'on' (full exogenous mapping to all exogenous genomes), then we will set up exogenous mapping options
        if(@settings['exogenousMapping'] =~ /on/)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Changing exogenousMapping setting from 'on' to 'miRNA' so that exceRpt makefile stops before performing full exogenous mapping! We'll do the full exogenous mapping in our exogenousSTARMapping wrapper.")
          @settings['exogenousMapping'] = "miRNA"
          # This is the setting that will actually tell us whether full exogenous mapping is being done (since we changed exogenousMapping from 'on' to 'miRNA')
          @settings['fullExogenousMapping'] = true
          # Full exogenous mapping uses 16 threads and 4 tasks (should we make these settings more dynamic?)
          @settings['numThreadsExo'] = 16
          @settings['numTasksExo'] = 4
          @exogenousNodes = @toolConf.getSetting('settings', 'exogenousNodes').to_i
          @maxSamplesPerExoJob = @toolConf.getSetting('settings', 'maxSamplesPerExoJob').to_i
          @exogenousJobIds = []
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of threads for exogenous mapping: #{@numThreadsExo} ; number of tasks for exogenous mapping: #{@numTasksExo}")
        end
        # The type of conditional job we're submitting at the end of this wrapper is dependent upon whether we're running full exogenous mapping or not
        # If fullExogenousMapping=false (exogenousMapping=off or exogenousMapping=miRNA), then we'll submit a processPipelineRuns job. 
        # Otherwise, if fullExogenousMapping=true (exogenousMapping=on), we'll submit an exogenousSTARMapping job.
        # Also, we'll create a directory in cluster.shared.scratch to store the inputs / outputs from the exogenousSTARMapping job.
        # Note that the exogenousSTARMapping job will submit the processPipelineRuns job (so instead of exceRptPipeline -> processPipelineRuns, we have exceRptPipeline -> exogenousSTARMapping -> processPipelineRuns)
        unless(@settings['fullExogenousMapping'])
          @conditionalJobType = "processPipelineRuns"
        else
          @conditionalJobType = "exogenousSTARMapping"
          @exogenousMappingInputDir = "#{@jobSpecificSharedScratch}/subJobsScratch/exogenousMapping"
          `mkdir -p #{@exogenousMappingInputDir}`
          exogenousTaxoTreeJobIDDir = "#{@jobSpecificSharedScratch}/subJobsScratch/exogenousTaxoTreeIDsDir"
          `mkdir -p #{exogenousTaxoTreeJobIDDir}`
          exogenousRerunDir = "#{@jobSpecificSharedScratch}/exogenousRerunDir"
          @settings['exogenousMappingInputDir'] = @exogenousMappingInputDir
          @settings['exogenousTaxoTreeJobIDDir'] = exogenousTaxoTreeJobIDDir
          @settings['exogenousRerunDir'] = exogenousRerunDir
        end
        # Check to make sure that priorityList setting is valid - default of miRNA > tRNA > piRNA > Gencode > circRNA
        @settings['priorityList'] = "miRNA > tRNA > piRNA > Gencode > circRNA" unless(@settings['priorityList'])
        @settings['priorityList'].gsub!(" > ", ",")
        @settings['priorityList'].gsub!("Gencode", "gencode")
        testingPriorityList = @settings['priorityList'].split(",")
        badPriorityList = false 
        testingPriorityList.each { |currentLibrary| 
          if(currentLibrary != "miRNA" and currentLibrary != "tRNA" and currentLibrary != "piRNA" and currentLibrary != "gencode" and currentLibrary != "circRNA")
            errors << "Your value for priorityList is invalid.\nEach library should be separated with \" > \" and potential libraries include: miRNA, tRNA, piRNA, Gencode, and circRNA."
            badPriorityList = true
            break
          end
        }
        @settings['endogenousLibraryOrder'] = @settings['priorityList'].clone()
        @settings.delete('priorityList')
        # Check to make sure that if exogenous mapping is miRNA or on, we are using all endogenous libraries in priority list
        if((@settings['exogenousMapping'] == "miRNA" or @settings['exogenousMapping'] == "on") and !badPriorityList and testingPriorityList.size < 5)
          errors << "You must include all endogenous libraries in your priority list\nif you choose one of the exogenous mapping options (miRNA or on)."
        end
        # Check to make sure that randomBarcodeLength setting is valid - default of 0
        @settings['randomBarcodeLength'] = 0 unless(@settings['randomBarcodeLength'])
        unless(@settings['randomBarcodeLength'].to_i >= 0)
          errors << "Your value for randomBarcodeLength is invalid.\nYour random barcode length should be an integer that is 0 or greater."          
        end
        # Check to make sure that randomBarcodeLocation setting is valid - default of -5p -3p. Must be -5p -3p, -5p, or -3p.
        @settings['randomBarcodeLocation'] = "-5p -3p" unless(@settings['randomBarcodeLocation'])
        if(@settings['randomBarcodeLocation'] != "-5p -3p" and @settings['randomBarcodeLocation'] != "-5p" and @settings['randomBarcodeLocation'] != "-3p")
          errors << "Your value for randomBarcodeLocation is invalid.\nYour random barcode location should be \"-5p -3p\", \"-5p\", or \"-3p\"."
        end
        # Check to make sure that randomBarcodeStats setting is valid - default of false
        @settings['randomBarcodeStats'] = false unless(@settings['randomBarcodeStats'])
        if(@settings['randomBarcodeStats'] != false and @settings['randomBarcodeStats'] != "false" and @settings['randomBarcodeStats'] != true and @settings['randomBarcodeStats'] != "true")
          errors << "Your value for randomBarcodeStats is invalid.\nThe value of randomBarcodeStats must be true or false."
        end
        # Check to make sure that endogenousMismatch setting is valid - default of 1. Must be 0, 1, 2, or 3.
        @settings['endogenousMismatch'] = 1 unless(@settings['endogenousMismatch'])
        unless((0..3).member?(@settings['endogenousMismatch'].to_i))
          errors << "Your value for endogenousMismatch is invalid.\nYou can choose any integer between 0 and 3 (inclusive)."
        end
        # Check to make sure that exogenousMismatch setting is valid - default of 0. Must be 0 or 1.
        @settings['exogenousMismatch'] = 0 unless(@settings['exogenousMismatch'])
        unless((0..1).member?(@settings['exogenousMismatch'].to_i))
          errors << "Your value for exogenousMismatch is invalid.\nIts value should be either 0 or 1."
        end
        if(@settings['exceRptGen'] == "fourthGen")
          # This value is the minimum base-call quality of reads. Default: 20. Must be 10, 20, 30, or 40.
          @settings['minBaseCallQuality'] = 20 unless (@settings['minBaseCallQuality'])
          if(@settings['minBaseCallQuality'].to_i != 10 and @settings['minBaseCallQuality'].to_i != 20 and @settings['minBaseCallQuality'].to_i != 30 and @settings['minBaseCallQuality'].to_i != 40)
            errors << "Your value for minBaseCallQuality is invalid.\nIts value should be 10, 20, 30, or 40." 
          end
          # This value is the percentage of the read that must meet the minimum base-call quality (found in @settings['minBaseCallQuality']). Default: 80. Must be between 0 and 100 (inclusive).
          @settings['fractionForMinBaseCallQuality'] = 80 unless(@settings['fractionForMinBaseCallQuality'])
          if(@settings['fractionForMinBaseCallQuality'].to_i < 0 and @settings['fractionForMinBaseCallQuality'].to_i > 100)
            errors << "Your value for fractionForMinBaseCallQuality is invalid.\nIts value should be an integer between 0 and 100 (inclusive)." 
          end
          # This value will be the minimum read length we will use after adapter (and random barcode) removal. Minimum of 10. Default: 18.
          @settings['minReadLength'] = 18 unless(@settings['minReadLength'])
          if(@settings['minReadLength'].to_i < 10)
            errors << "Your value for minReadLength is invalid.\nIts value should be and integer and at least 10 (default of 18)." 
          end
          # This value is the minimum fraction of the read that must remain following soft-clipping (in a local alignment). Must be some decimal between 0 and 1 (inclusive).
          @settings['readRemainingAfterSoftClipping'] = 0.9 unless(@settings['readRemainingAfterSoftClipping'])
          if(@settings['readRemainingAfterSoftClipping'].to_f < 0 and @settings['readRemainingAfterSoftClipping'].to_f > 1)
            errors << "Your value for readRemainingAfterSoftClipping is invalid.\nIts value should be some decimal between 0 and 1 (inclusive).\nIt has a default of 0.9." 
          end
          # This option will trim N bases from the 3' end of every read, where N is the value you choose. Default: 0.
          @settings['trimBases3p'] = 0 unless(@settings['trimBases3p'])
          if(@settings['trimBases3p'].to_i < 0)
            errors << "Your value for trimBases3p is invalid.\nIts value should be an integer greater than or equal to 0.\nIt has a default of 0." 
          end
          # This option will trim N bases from the 5' end of every read, where N is the value you choose. Default: 0.
          @settings['trimBases5p'] = 0 unless(@settings['trimBases5p'])
          if(@settings['trimBases5p'].to_i < 0)
            errors << "Your value for trimBases5p is invalid.\nIts value should be an integer greater than or equal to 0.\nIt has a default of 0." 
          end
          # This option will set the minimum number of bases for the 3' adapter sequence to N, where N is the value you choose. Default: 7.
          @settings['minAdapterBases3p'] = 7 unless(@settings['minAdapterBases3p'])
          if(@settings['minAdapterBases3p'].to_i < 3 or @settings['minAdapterBases3p'].to_i > 10)
            errors << "Your value for minAdapterBases3p is invalid.\nIts value should be an integer greater than 2 and less than 11.\nIt has a default of 7." 
          end
          # This setting will allow you to downsample your RNA reads after assigning reads to the various transcriptome libraries. 
          # This may be useful for normalizing very different yields.
          # There is a recommended minimum of 100,000, but any value above 0 is acceptable.
          if(@settings['downsampleRNAReads'] and @settings['downsampleRNAReads'].to_i < 0)
            errors << "Your value for downsampleRNAReads is invalid.\nIts value should be an integer greater than or equal to 0.\nIt has a default of nil (not using the setting)."
          end
        elsif(@settings['exceRptGen'] == "thirdGen")
          # Check to make sure that bowtieSeedLength setting is valid - default of 19
          @settings['bowtieSeedLength'] = 19 unless(@settings['bowtieSeedLength'])
          unless((15..30).member?(@settings['bowtieSeedLength']))
            errors << "Your value for bowtieSeedLength is invalid.\nYou can choose any integer between 15 and 30 (inclusive)."
          end
        end
        # Local execution setting - will always be false for Genboree
        @settings['localExecution'] = false
        # Grab genome version supplied in settings
        @genomeVersion = @settings['genomeVersion']
        # If user supplied a genome version different than hg19 (which is the default), we have to change the output database accordingly
        # This change assumes that the names of our Atlas databases follow a certain format (each Atlas database name is exactly the same other than the name of the genome)
        unless(@genomeVersion == "hg19")
          @outputDb.gsub!("hg19", @genomeVersion)
          @settings['outputDb'].gsub!("hg19", @genomeVersion)
        end
        # Try to parse URI associated with output database - if we can't parse it properly, then we'll add that issue to our errors array
        targetUri = URI.parse(@outputDb) rescue nil
        if(targetUri)
          # Now, we want to grab information about the output database (to check its genome version).
          apiCaller = WrapperApiCaller.new(host, "#{targetUri.path}?", @subUserId)
          apiCaller.get()
          # If we can't grab any info, then we'll add that issue to our errors array
          unless(apiCaller.succeeded?)
            errors << "Could not grab information about output Group (#{@settings['outputGroup']}) and/or output Database (#{@settings['outputDb']}).\nYou may not have access to these resources.\nPlease contact a DCC admin (listed below) in order to be given access."
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "ApiCaller failed for grabbing genome version: #{apiCaller.respBody.inspect}")
          else
            # Now, we've hopefully grabbed info about the database. Let's grab the genome version of the database
            retVal = apiCaller.parseRespBody()
            @genomeVersionOfDb = retVal['data']['version'].decapitalize rescue nil
            # If the genome version of the database is nil or empty, then the user (us, in this case) didn't set up the database correctly, because it has no genome version!
            unless(@genomeVersionOfDb.nil? or @genomeVersionOfDb.empty?)
              # OK, so we've now grabbed some genome version.
               # Grab index base name and genome build associated with this genome version
              gbSmallRNASeqPipelineGenomesInfo = JSON.parse(File.read(@genbConf.gbSmallRNASeqPipelineGenomesInfo))
              indexBaseName = gbSmallRNASeqPipelineGenomesInfo[@genomeVersionOfDb]['indexBaseName']
              @genomeBuild = gbSmallRNASeqPipelineGenomesInfo[@genomeVersionOfDb]['genomeBuild']
              # If indexBaseName is nil, that means we're not currently supporting this genome version for exceRpt.  
              if(indexBaseName.nil?)
                errors << "Your output database on Genboree has genome version #{@genomeVersionOfDb}.\nThis genome version is not currently supported.\nSupported genomes include: #{gbSmallRNASeqPipelineGenomesInfo.keys.join(',')}.\nPlease contact a DCC admin (listed below) for potentially adding support for this genome."
              else
                # Our final check is to make sure that the genome version supplied by user matches the version of the output Database.
                # If no genome version is supplied by user, then we're just checking that hg19 matches the default output Database (it should!).
                unless(@genomeVersion == @genomeVersionOfDb)
                  errors << "The genome version #{@genomeVersion} supplied in your manifest file\ndoes not match the genome version #{@genomeVersionOfDb} of your database.\nPlease make sure that these genome versions match."
                end 
              end
            else
              errors << "Your output database on Genboree has no genome version associated with it. Please make sure that your output database has the same genome version (default of hg19) as your submitted files." if(apiCaller.succeeded?)
            end
          end
        else
          errors << "We were unable to parse the URI associated with your output Database."
        end
        @useLibrary = @settings['useLibrary']
        if(@useLibrary =~ /useExistingLibrary/)
          unless(@settings['existingLibraryName'])
            errors << "You have selected to use an existing spike-in library on Genboree, but you did not supply a spike-in file name.\nThis file name should be supplied under the \"existingLibraryName\" field."
          else
            @spikeInUri = "#{@outputDb}/file/spikeInLibraries/#{@settings['existingLibraryName']}"
            fileBase = @fileApiHelper.extractName(@spikeInUri)
            fileBaseName = File.basename(fileBase)
            @spikeInName = fileBaseName.makeSafeStr(:ultra)
          end
        end
        @settings['genomeVersion'] = @genomeVersion
        @settings['genomeBuild'] = @genomeBuild
        @settings['releaseStatus'] = "releaseNone" unless(@settings['releaseStatus'])
        if(@settings['releaseStatus'] != "releaseAll" and @settings['releaseStatus'] != "releaseControls" and @settings['releaseStatus'] != "releaseNone")
          errors << "Your value for releaseStatus is invalid.\nYou should put \"releaseAll\" (to release all samples to the public),\n\"releaseControls\" (to release only controls to the public),\nor \"releaseNone\" (to release no samples to the public)."
        end
        unless(errors.empty?)
          @errUserMsg = "We encountered some errors while parsing the settings for your job.\nA list is given below:\n\n#{errors.join("\n")}"
          raise @errUserMsg
        end
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There was an issue with configuring the settings for your FTP exceRpt job." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 23
      end
      return @exitCode
    end

    # Initial checks to make sure that some basic requirements are met for metadata files (validation checks will occur in validateMetadataDocs method)
    # @return [Fixnum] exit code that indicates whether error occurred during metadata file check (0 if no error, 25 if error)
    def checkMetadataFiles()
      begin
        # Grab the names of all files in metadata directory
        allMetadataFiles = Dir.entries(@metadataDir)
        # Delete unnecessary entries from list
        allMetadataFiles.delete(".")
        allMetadataFiles.delete("..")
        allMetadataFiles.delete("__MACOSX")
        allMetadataFiles.delete(@autoGeneratedAnalysisMetadataFileName)
        junkMacFiles = []
        allMetadataFiles.each { |currentFile|
          junkMacFiles << currentFile if(currentFile[0..1] == "._")
        }
        junkMacFiles.each { |currentJunkFile|
          allMetadataFiles.delete(currentJunkFile)
        }
        errors = []
        # Handle situation where file list is a single directory (that will then, hopefully, contain all metadata result files)
        allMetadataFiles.each { |inputFile|
          if(File.directory?("#{@metadataDir}/#{inputFile}") and allMetadataFiles.size == 1)
            # Make sure that we move auto-generated analysis doc to the new metadata directory
            `mv #{@metadataDir}/#{@autoGeneratedAnalysisMetadataFileName} #{@metadataDir}/#{inputFile}/` if(File.exist?("#{@metadataDir}/#{@autoGeneratedAnalysisMetadataFileName}"))
            allMetadataFiles = Dir.entries("#{@metadataDir}/#{inputFile}")
            @metadataDir = "#{@metadataDir}/#{inputFile}"
          end
        }
        allMetadataFiles.push(@autoGeneratedAnalysisMetadataFileName).uniq! if(@autoGeneratedAnalysisMetadataFileName)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "list of metadata files: #{allMetadataFiles.inspect}")
        # Check to make sure that metadata archive contains ONLY non-empty .metadata.tsv or .compact.tsv files and no directories!
        metadataErrors = {:directory => [], :zeroFile => [], :incorrectExtension => []}
        allMetadataFiles.each { |currentMetadataFile|
          next if(currentMetadataFile == "." or currentMetadataFile == ".." or currentMetadataFile == "__MACOSX" or currentMetadataFile[0..1] == "._")
          # If file is directory, then we do not need to check for its file extension below (for example, don't want to report error that directory named "Test" doesn't end in .metadata.tsv or .compact.tsv).
          foundDirectory = false 
          if(File.directory?("#{@metadataDir}/#{currentMetadataFile}"))
            metadataErrors[:directory] << currentMetadataFile
            foundDirectory = true
          end
          if(File.zero?("#{@metadataDir}/#{currentMetadataFile}"))
            metadataErrors[:zeroFile] << currentMetadataFile
          end
          unless(foundDirectory)
            unless(currentMetadataFile =~ /.metadata.tsv$/ or currentMetadataFile =~ /.compact.tsv$/)
              metadataErrors[:incorrectExtension] << currentMetadataFile
            end
          end
        }
        foundMetadataError = false
        metadataErrors.each_value { |categoryValue| foundMetadataError = true unless(categoryValue.empty?) }
        if(foundMetadataError)
          metadataErrors.each_key { |category|
            unless(metadataErrors[category].empty?)
              msg = ""
              if(category == :directory)
                msg = "The following extra directories should be deleted\n(and any metadata files inside of them should be placed\ndirectly into the archive - no subdirectories!):"
              elsif(category == :zeroFile)
                msg = "The following files are empty (0 bytes):"
              elsif(category == :incorrectExtension)
                msg = "The following files don't end in the proper extension\n(.compact.tsv or .metadata.tsv):"
              end
              unless(msg.empty?)
                errors << "#{msg}\n\n#{metadataErrors[category].join("\n")}"
              end
            end
          }
        end
        # Next, we'll check that the metadata files mentioned in the manifest file are present
        missingMetadataFiles = []
        if(errors.empty?)
          missingMetadataFiles << @fileData["analysisMetadataFileName"] unless(allMetadataFiles.include?(@fileData["analysisMetadataFileName"]))
          if(@fileData["experimentMetadataFileName"])
            missingMetadataFiles << @fileData["experimentMetadataFileName"] unless(allMetadataFiles.include?(@fileData["experimentMetadataFileName"]))
          end
          missingMetadataFiles << @fileData["runMetadataFileName"] unless(allMetadataFiles.include?(@fileData["runMetadataFileName"]))
          missingMetadataFiles << @fileData["studyMetadataFileName"] unless(allMetadataFiles.include?(@fileData["studyMetadataFileName"]))
          missingMetadataFiles << @fileData["submissionMetadataFileName"] unless(allMetadataFiles.include?(@fileData["submissionMetadataFileName"]))
          if(@fileData["donorMetadataFileName"])
            missingMetadataFiles << @fileData["donorMetadataFileName"] unless(allMetadataFiles.include?(@fileData["donorMetadataFileName"]))
          end
          if(@fileData["biosampleMetadataFileName"])
            missingMetadataFiles << @fileData["biosampleMetadataFileName"] unless(allMetadataFiles.include?(@fileData["biosampleMetadataFileName"]))
          end
          @manifest.each { |eachSampleHash|
            if(eachSampleHash["biosampleMetadataFileName"])
              missingMetadataFiles << eachSampleHash["biosampleMetadataFileName"] unless(allMetadataFiles.include?(eachSampleHash["biosampleMetadataFileName"]))
            end 
            if(eachSampleHash["experimentMetadataFileName"])
              missingMetadataFiles << eachSampleHash["experimentMetadataFileName"] unless(allMetadataFiles.include?(eachSampleHash["experimentMetadataFileName"]))
            end
            if(eachSampleHash["donorMetadataFileName"])
              missingMetadataFiles << eachSampleHash["donorMetadataFileName"] unless(allMetadataFiles.include?(eachSampleHash["donorMetadataFileName"]))
            end
          }
        end
        unless(missingMetadataFiles.empty?)
          errors << "The following metadata files were mentioned in your manifest,\nbut they could not be found in your metadata archive:\n\n#{missingMetadataFiles.join("\n")}"
        end
        # Finally, let's convert each metadata document to unix format
        allMetadataFiles.each { |inputFile|
          # Convert to unix format
          convObj = BRL::Util::ConvertText.new("#{@metadataDir}/#{inputFile}", true)
          convObj.convertText()
          # Count number of lines in the input file
          numLines = `wc -l #{@metadataDir}/#{inputFile}`
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of lines in metadata file #{File.basename(inputFile)}: #{numLines.split(" ")[0]}")
        }
        # We raise an error unless we didn't find any errors above
        unless(errors.empty?)
          @errUserMsg = "There were some errors with your metadata archive. See the following:\n\n#{errors.join("\n\n")}"
          raise @errUserMsg
        end
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There were some errors with checking your metadata files." if(@errUserMsg.nil?)
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
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "BIOSAMPLE LOCATION: #{@metadataDir}/#{@fileData["biosampleMetadataFileName"]}")
        currBiosampleContents = File.read("#{@metadataDir}/#{@fileData["biosampleMetadataFileName"]}")
        currBiosampleContents.gsub!("\r\n", "\n")
        currBiosampleContents.gsub!("\r", "\n")
        convertedBiosamples = @converter.parse(currBiosampleContents, true)
        unless(@converter.errors.empty?)
          @errUserMsg = "There was an error in importing your multi-column biosample doc named #{@fileData["biosampleMetadataFileName"]}.\nAre you sure that you followed the required model for biosample documents?\nDid you forget to add the \"domain\" column to your multi-column tabbed document? Please use the following resources to fix your multi-column tabbed document:\nhttp://genboree.org/genboreeKB/projects/genboreekb-introduction/wiki/Tab_Separated_Value_Formats#Multi-column\nhttp://genboree.org/theCommons/attachments/5028/Biosamples.model.compact.tsv\n\nA list of errors can be found below:\n\n#{@converter.errorSummaryStr}"
          raise @errUserMsg
        end
        # We will now fill out each sample in the manifest with information about its respective biosample
        # docNo will be used to inform the user which document column to look at if they are missing a value for the "-- File Name" property for a particular document. 
        docNo = 0
        # We traverse each biosample, one at a time
        errors = []
        foundIds = []
        multiColumnBiosampleErrors = {:biosampleAlreadyPresent => [], :multiSample => [], :missingNameInManifest => [], :missingNameOrIdInMetadataDoc => [], :duplicateId => []}
        convertedBiosamples.each { |currentBiosample|
          docNo += 1
          # We will create a new KbDoc with the current biosample so we can use KbDoc methods
          currentBiosample = BRL::Genboree::KB::KbDoc.new(currentBiosample)
          # We grab the "Biosample" value from the current biosample
          currentId = currentBiosample.getRootPropVal() rescue nil
          # We grab the "Biosample.Name" value from the current biosample
          currentSampleName = currentBiosample.getPropVal("Biosample.Name") rescue nil
          # foundSample will be used to see whether we've found a matching sample in the manifest for the file grabbed above
          foundSample = false
          # If the current biosample has a "Biosample" value and "Biosample.Name" value, then we proceed, Otherwise, we raise an error.
          if(currentId and !currentId.empty? and currentSampleName and !currentSampleName.empty?)
            if(foundIds.include?(currentId))
              multiColumnBiosampleErrors[:duplicateId] << currentId unless(multiColumnBiosampleErrors[:duplicateId].include?(currentId))
            else
              foundIds << currentId
            end
            # We traverse each sample in the manifest.
            @fileData["manifest"].each { |currentSampleInManifest|
              # If the "sampleName" field for a particular sample matches the name given in the biosample metadata file, then we've found a match
              if(currentSampleInManifest["sampleName"] == currentSampleName)
                # However, you're only allowed to have 1-to-1 match. Thus, if you have the same sample name matching multiple samples, then we raise an error.
                # Otherwise, we proceed.
                unless(foundSample)
                  # It is not permitted for a biosample metadata doc to be linked in both the multi-column file and on a sample-by-sample basis within the manifest file
                  biosampleAlreadyPresent = false
                  if(currentSampleInManifest["biosampleMetadataFileName"])
                    multiColumnBiosampleErrors[:biosampleAlreadyPresent] << currentSampleName unless(multiColumnBiosampleErrors[:biosampleAlreadyPresent].include?(currentSampleName))
                    biosampleAlreadyPresent = true
                    foundSample = true
                  end
                  unless(biosampleAlreadyPresent)
                    # We convert the current biosample into nested tabbed format
                    individualBiosample = @producer.produce(currentBiosample).join("\n")
                    # We give the current biosample a name and then save it as a .tsv file
                    individualBiosampleName = "#{currentId}.metadata.tsv"
                    File.open("#{@metadataDir}/#{individualBiosampleName}", 'w') { |file| file.write(individualBiosample) }
                    # We set the current sample's "biosampleMetadataFileName" field to be this .tsv file - we'll parse the manifest later to load up our metadata files
                    currentSampleInManifest["biosampleMetadataFileName"] = individualBiosampleName
                    # Finally, we set foundSample to be true (since we found a matching sample)
                    foundSample = true
                  end
                else
                  multiColumnBiosampleErrors[:multiSample] << currentSampleName unless(multiColumnBiosampleErrors[:multiSample].include?(currentSampleName))
                end
              end
            }
            # If we didn't find a matching sample for the file name given in the metadata file, we raise an error
            unless(foundSample)
              multiColumnBiosampleErrors[:missingNameInManifest] << currentSampleName unless(multiColumnBiosampleErrors[:missingNameInManifest].include?(currentSampleName))
            end
          else
            multiColumnBiosampleErrors[:missingNameOrIdInMetadataDoc] << docNo
          end
        }
        foundError = false
        multiColumnBiosampleErrors.each_value { |categoryValue| foundError = true unless(categoryValue.empty?) }
        if(foundError)
          multiColumnBiosampleErrors.each_key { |category|
            unless(multiColumnBiosampleErrors[category].empty?)
              msg = ""
              if(category == :biosampleAlreadyPresent)
                msg = "The following sample names\n(collected from your biosample metadata docs)\nmapped to samples in your manifest file\nthat already had a \"biosampleMetadataFileName\" property filled out.\nThis is not allowed - any biosamples in your multi-column file\nshould not be linked in your manifest file.\nIt is also possible that you used the same sample name\nin multiple biosample docs:"
              elsif(category == :multiSample)
                msg = "The following sample names\n(collected from your biosample metadata docs)\nmapped to multiple samples in your manifest file.\nThis is not allowed (we require 1-to-1 correspondence):"
              elsif(category == :missingNameInManifest)
                msg = "The following sample names\n(collected from your biosample metadata docs)\ncould not be found in your manifest file:"
              elsif(category == :missingNameOrIdInMetadataDoc)
                msg = "We could not find a sample name or accession ID\nin at least one of your biosample metadata docs.\nBoth are required for a multi-column biosample.\nThese docs are listed below\n(identified by order of value column):"
              elsif(category == :duplicateId) 
                msg = "The following document IDs\n(collected from your biosample metadata docs)\nwere used multiple times.\nEach document ID can only be used once.\nProblematic IDs can be found below:"
              end
              unless(msg.empty?)
                errors << "#{msg}\n\n#{multiColumnBiosampleErrors[category].join("\n")}"
              end
            end
          }
        end
        unless(errors.empty?)
          @errUserMsg = "There were some errors in parsing your multi-column biosample doc.\nA detailed list of errors can be found below:\n"
          @errUserMsg << "\n=================================================================\n"
          @errUserMsg << errors.join("\n=================================================================\n")
          @errUserMsg << "\n=================================================================\n"
          raise @errUserMsg
        end
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There was an issue with separating your multi-column tabbed biosample file into individual biosample files." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 26
      end
      return @exitCode
    end

    # First, checks whether donor file is a) a single doc that applies to all samples that don't have an explicit donor associated with them in the manifest file, or
    #                                     b) be a multi-column doc that covers multiple samples.
    # Second, depending on whether donor file is a) or b), take measures to set up successful loading of donor docs.
    # @return [Fixnum] exit code indicating whether conversion succeeded (0) or failed (39)
    def checkAndConvertMultiColumnDonors()
      begin
        # Open donors file
        currDonorContents = File.read("#{@metadataDir}/#{@fileData["donorMetadataFileName"]}")
        currDonorContents.gsub!("\r\n", "\n")
        currDonorContents.gsub!("\r", "\n")
        # First, let's assume that the donors file is a single doc (mentioned in a) above). We will attempt to convert that doc into a KB doc
        convertedDonor = @converter.parse(currDonorContents)
        errors = []
        foundIds = []
        multiColumnDonorErrors = {:donorAlreadyPresent => [], :missingDonorIDFromBiosample => [], :failedBiosampleConversion => [], :missingLinkBetweenDonorAndBiosample => [], :missingDonorIDFromDonor => [], :duplicateId => []}
        # If any errors occurred, then we need to figure out what kind of error occurred.
        if(!@converter.errors.empty?)
          # Did the error occur because of the file being multi-column or for another reason?
          # If appropriate error is detected, then we will attempt to convert the file into multiple donor docs.
          # Otherwise, we'll raise the error to the user because it's likely that their doc is messed up.
          @multiDonorDoc = true if(@converter.errorSummaryStr.include?("Duplicate/ambiguous column name \"value\"."))
          if(@multiDonorDoc)
            # In this branch, we assume that the donors file is a multi-column doc that covers multiple samples.
            # We will attempt to convert that file into multiple docs.
            convertedDonors = @converter.parse(currDonorContents, true)
            # If conversion was successful, we proceed - otherwise, we raise an error for user.
            if(@converter.errors.empty?)
              # OK, we now officially have a multi-column donor doc.
              # We will now fill out each sample in the manifest with information about its respective donor
              # docNo will be used to inform the user which document column to look at if they are missing a value for the "Donor" property for a particular document.
              docNo = 0
              convertedDonors.each { |currentDonor|
                docNo += 1
                # Check to see if current donor doc has a donor ID. If it doesn't, then we can't link it to a sample in our manifest.
                currentDonor = BRL::Genboree::KB::KbDoc.new(currentDonor)
                currentDonorID = currentDonor.getPropVal("Donor") rescue nil
                if(currentDonorID and !currentDonorID.empty?)
                  if(foundIds.include?(currentDonorID))
                    multiColumnDonorErrors[:duplicateId] << currentDonorID unless(multiColumnDonorErrors[:duplicateId].include?(currentDonorID))
                  else
                    foundIds << currentDonorID
                  end
                  # OK, now we need to match up the current donor doc with the appropriate sample in the manifest.
                  # Let's traverse all biosample docs and try to find a match!
                  foundSample = false
                  @fileData["manifest"].each { |currentSampleInManifest|
                    # Grab current biosample doc and convert it into KbDoc
                    currBiosampleContents = File.read("#{@metadataDir}/#{currentSampleInManifest["biosampleMetadataFileName"]}")
                    currBiosampleContents.gsub!("\r\n", "\n")
                    currBiosampleContents.gsub!("\r", "\n")
                    currentBiosampleDoc = BRL::Genboree::KB::KbDoc.new(@converter.parse(currBiosampleContents))
                    # If no errors occurred while converting the biosample doc, we proceed
                    if(@converter.errors.empty?)
                      biosampleDonorID = currentBiosampleDoc.getPropVal("Biosample.Donor ID") rescue nil
                      if(!biosampleDonorID.nil? and !biosampleDonorID.empty?)
                        if(currentDonorID == biosampleDonorID)
                          # We set foundSample to be true (since we found a matching sample)
                          foundSample = true
                          unless(currentSampleInManifest["donorMetadataFileName"])
                            # We convert the current biosample into nested tabbed format
                            individualDonor = @producer.produce(currentDonor).join("\n")
                            # We give the current biosample a name and then save it as a .tsv file
                            individualDonorName = "#{currentDonorID}.metadata.tsv"
                            File.open("#{@metadataDir}/#{individualDonorName}", 'w') { |file| file.write(individualDonor) }
                            # We set the current sample's "donorMetadataFileName" field to be this .tsv file - we'll parse the manifest later to load up our metadata files
                            currentSampleInManifest["donorMetadataFileName"] = individualDonorName unless(multiColumnDonorErrors[:duplicateId].include?(currentDonorID))
                          else
                            multiColumnDonorErrors[:donorAlreadyPresent] << "Donor ID: #{currentDonorID}\nBiosample metadata file name: #{currentSampleInManifest["biosampleMetadataFileName"]}\nSample name: #{currentSampleInManifest["sampleName"]}" unless(multiColumnDonorErrors[:duplicateId].include?(currentDonorID))
                          end
                        end
                      else
                        multiColumnDonorErrors[:missingDonorIDFromBiosample] << currentSampleInManifest["biosampleMetadataFileName"] unless(multiColumnDonorErrors[:missingDonorIDFromBiosample].include?(currentSampleInManifest["biosampleMetadataFileName"]))
                      end
                    else
                      multiColumnDonorErrors[:failedBiosampleConversion] << "Biosample metadata file name: #{currentSampleInManifest["biosampleMetadataFileName"]}\nImport errors:\n#{@converter.errorSummaryStr}" unless(multiColumnDonorErrors[:failedBiosampleConversion].include?("Biosample metadata file name:#{currentSampleInManifest["biosampleMetadataFileName"]}\nImport errors:\n#{@converter.errorSummaryStr}"))
                    end
                  }
                  unless(foundSample)
                    multiColumnDonorErrors[:missingLinkBetweenDonorAndBiosample] << currentDonorID unless(multiColumnDonorErrors[:missingLinkBetweenDonorAndBiosample].include?(currentDonorID))
                  end
                else
                  multiColumnDonorErrors[:missingDonorIDFromDonor] << docNo
                end
              }
            else
              @errUserMsg = "There was an error in importing your donor file named #{@fileData["donorMetadataFileName"]}.\nBecause your file included multiple value columns, we are assuming that this donor file contains multiple docs.\nPlease use the following resources to fix your multi-column file:\nhttp://genboree.org/genboreeKB/projects/genboreekb-introduction/wiki/Tab_Separated_Value_Formats#Multi-column\n\nA list of errors can be found below:\n\n#{@converter.errorSummaryStr}"
              raise @errUserMsg            
            end
          else
            @errUserMsg = "There was an error in importing your donor file named #{@fileData["donorMetadataFileName"]}.\nBecause your file didn't include multiple value columns, we are assuming that this donor file is a single doc.\nIf your donor file is supposed to be a multi-column file containing multiple docs,\nplease use the following resources to fix your multi-column file:\nhttp://genboree.org/genboreeKB/projects/genboreekb-introduction/wiki/Tab_Separated_Value_Formats#Multi-column\n\nA list of errors can be found below:\n\n#{@converter.errorSummaryStr}"
            raise @errUserMsg
          end
        else
          # If we reach this branch, it means that our converter didn't report any errors in converting a single tabbed-delimited doc to a KB doc
          # That means we don't need to do anything else here - it'll be handled by the loadMetadataFiles method
        end
        foundError = false
        multiColumnDonorErrors.each_value { |categoryValue| foundError = true unless(categoryValue.empty?) }
        if(foundError)
          multiColumnDonorErrors.each_key { |category|
            unless(multiColumnDonorErrors[category].empty?)
              msg = ""
              if(category == :donorAlreadyPresent)
                msg = "The following donor IDs\n(collected from your multi-column donor doc)\nmatched up with a biosample\nthat already had a donor doc listed in the manifest.\nThis is not allowed - please ensure that you only link\ndonor docs to biosample docs once.\nRelevant donor IDs, biosample file names,\nand sample names are listed below:"
              elsif(category == :missingDonorIDFromBiosample)
                msg = "The following biosample metadata files\nwere missing a donor ID (for \"Biosample.Donor ID\" property).\nThis ID is required for mapping:"
              elsif(category == :failedBiosampleConversion)
                msg = "The following biosample metadata files\ncould not be imported successfully\nfrom nested tabbed format.\nError logs can be seen below as well:"
              elsif(category == :missingLinkBetweenDonorAndBiosample)
                msg = "The following donor IDs could not be matched\nto the \"Biosample.Donor ID\" property\nfor any biosample metadata docs\nmentioned in your manifest file:"
              elsif(category == :missingDonorIDFromDonor)
                msg = "In order to use a multi-column donor file,\neach donor doc must have its own doc ID.\nThe following docs do not have a donor ID\nso they could not be parsed.\nThese docs are listed in order of value column:"
              elsif(category == :duplicateId)
                msg = "The following document IDs\n(collected from your donor metadata docs)\nwere used multiple times.\nEach document ID can only be used once.\nProblematic IDs can be found below:"
              end
              unless(msg.empty?)
                errors << "#{msg}\n\n#{multiColumnDonorErrors[category].join("\n")}"
              end
            end
          }
        end
        unless(errors.empty?)
          @errUserMsg = "There were some errors in parsing your multi-column donor doc.\nA detailed list of errors can be found below:\n"
          @errUserMsg << "\n=================================================================\n"
          @errUserMsg << errors.join("\n=================================================================\n")
          @errUserMsg << "\n=================================================================\n"
          raise @errUserMsg
        end
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There was an issue with checking your general donor file (or converting your multi-column donor file into individual donor files." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 39
      end
      return @exitCode
    end

    # First, checks whether experiment file is a) a single doc that applies to all samples that don't have an explicit experiment associated with them in the manifest file, or
    #                                     b) be a multi-column doc that covers multiple samples.
    # Second, depending on whether experiment file is a) or b), take measures to set up successful loading of experiment docs.
    # @return [Fixnum] exit code indicating whether conversion succeeded (0) or failed (40)
    def checkAndConvertMultiColumnExperiments()
       begin
        # Open experiment file
        currExperimentContents = File.read("#{@metadataDir}/#{@fileData["experimentMetadataFileName"]}")
        currExperimentContents.gsub!("\r\n", "\n")
        currExperimentContents.gsub!("\r", "\n")
        # First, let's assume that the experiment file is a single doc (mentioned in a) above). We will attempt to convert that doc into a KB doc
        convertedExperiment = @converter.parse(currExperimentContents)
        errors = []
        foundIds = []
        multiColumnExperimentErrors = {:experimentAlreadyPresent => [], :missingExperimentIDFromBiosample => [], :failedBiosampleConversion => [], :missingLinkBetweenExperimentAndBiosample => [], :missingExperimentIDFromExperiment => [], :duplicateId => []}
        # If any errors occurred, then we need to figure out what kind of error occurred.
        if(!@converter.errors.empty?)
          # Now, let's figure out if the error occurred because of the file being multi-column or because of another reason.
          @multiExperimentDoc = true if(@converter.errorSummaryStr.include?("Duplicate/ambiguous column name \"value\"."))
          if(@multiExperimentDoc)
            # Now, we assume that the donors file is a multi-column doc that covers all samples.
            # We will attempt to convert that file into multiple docs.
            convertedExperiments = @converter.parse(currExperimentContents, true)
            # If conversion was successful, we proceed - otherwise, we raise an error for user.
            if(@converter.errors.empty?)
              # We will now fill out each sample in the manifest with information about its respective experiment
              # docNo will be used to inform the user which document column to look at if they are missing a value for the "Experiment" property for a particular document.
              docNo = 0
              convertedExperiments.each { |currentExperiment|
                docNo += 1
                # Check to see if current experiment doc has a experiment ID. If it doesn't, then we can't link it to a sample in our manifest.
                currentExperiment = BRL::Genboree::KB::KbDoc.new(currentExperiment)
                currentExperimentID = currentExperiment.getPropVal("Experiment") rescue nil
                if(currentExperimentID and !currentExperimentID.empty?)
                  if(foundIds.include?(currentExperimentID))
                    multiColumnExperimentErrors[:duplicateId] << currentExperimentID unless(multiColumnExperimentErrors[:duplicateId].include?(currentExperimentID))
                  else
                    foundIds << currentExperimentID
                  end
                  # OK, now we need to match up the current experiment doc with the appropriate sample in the manifest.
                  # Let's traverse all biosample docs and try to find a match!
                  foundSample = false
                  @fileData["manifest"].each { |currentSampleInManifest|
                    # Grab current biosample doc and convert it into KbDoc
                    currBiosampleContents = File.read("#{@metadataDir}/#{currentSampleInManifest["biosampleMetadataFileName"]}")
                    currBiosampleContents.gsub!("\r\n", "\n")
                    currBiosampleContents.gsub!("\r", "\n")
                    currentBiosampleDoc = BRL::Genboree::KB::KbDoc.new(@converter.parse(currBiosampleContents))
                    # If no errors occurred while converting the biosample doc, we proceed
                    if(@converter.errors.empty?)
                      experimentIDs = currentBiosampleDoc.getPropItems("Biosample.Related Experiments") rescue nil
                      validItems = []
                      if(experimentIDs)
                        # First, let's remove any bogus empty entries from doc
                        experimentIDs.each { |currentRelExp|
                          validItems << currentRelExp unless(currentRelExp["Related Experiment"]["value"].empty?)
                        }
                        currentBiosampleDoc.setPropItems("Biosample.Related Experiments", validItems)
                        experimentIDs = validItems
                      end
                      if(!experimentIDs.nil? and !experimentIDs.empty?)
                        experimentIDs.each { |currentExperimentRec|
                          currentExperimentRec = BRL::Genboree::KB::KbDoc.new(currentExperimentRec)
                          biosampleExperimentID = currentExperimentRec.getPropVal("Related Experiment")
                          if(currentExperimentID == biosampleExperimentID)
                            # We set foundSample to be true (since we found a matching sample)
                            foundSample = true
                            unless(currentSampleInManifest["experimentMetadataFileName"])
                              # We convert the current experiment into nested tabbed format
                              individualExperiment = @producer.produce(currentExperiment).join("\n")
                              # We give the current experiment a name and then save it as a .tsv file
                              individualExperimentName = "#{currentExperimentID}.metadata.tsv"
                              File.open("#{@metadataDir}/#{individualExperimentName}", 'w') { |file| file.write(individualExperiment) }
                              # We set the current sample's "experimentMetadataFileName" field to be this .tsv file - we'll parse the manifest later to load up our metadata files
                              currentSampleInManifest["experimentMetadataFileName"] = individualExperimentName unless(multiColumnExperimentErrors[:duplicateId].include?(currentExperimentID))
                            else
                              multiColumnExperimentErrors[:experimentAlreadyPresent] << "Experiment ID: #{currentExperimentID}\nBiosample metadata file name: #{currentSampleInManifest["biosampleMetadataFileName"]}\nSample name: #{currentSampleInManifest["sampleName"]}" unless(multiColumnExperimentErrors[:duplicateId].include?(currentExperimentID))
                            end
                          end
                        }
                      else
                        multiColumnExperimentErrors[:missingExperimentIDFromBiosample] << currentSampleInManifest["biosampleMetadataFileName"] unless(multiColumnExperimentErrors[:missingExperimentIDFromBiosample].include?(currentSampleInManifest["biosampleMetadataFileName"]))
                      end
                    else
                      multiColumnExperimentErrors[:failedBiosampleConversion] << "Biosample metadata file name: #{currentSampleInManifest["biosampleMetadataFileName"]}\nImport errors:\n#{@converter.errorSummaryStr}" unless(multiColumnExperimentErrors[:failedBiosampleConversion].include?("Biosample metadata file name:#{currentSampleInManifest["biosampleMetadataFileName"]}\nImport errors:\n#{@converter.errorSummaryStr}"))
                    end
                  }
                  unless(foundSample)
                    multiColumnExperimentErrors[:missingLinkBetweenExperimentAndBiosample] << currentExperimentID unless(multiColumnExperimentErrors[:missingLinkBetweenExperimentAndBiosample].include?(currentExperimentID))
                  end
                else
                  multiColumnExperimentErrors[:missingExperimentIDFromExperiment] << docNo
                end
              }
            else
              @errUserMsg = "There was an error in importing your experiment file named #{@fileData["experimentMetadataFileName"]}.\nBecause your file included multiple value columns, we are assuming that this experiment file contains multiple docs.\nPlease use the following resources to fix your multi-column file:\nhttp://genboree.org/genboreeKB/projects/genboreekb-introduction/wiki/Tab_Separated_Value_Formats#Multi-column\n\nA list of errors can be found below:\n\n#{@converter.errorSummaryStr}"
              raise @errUserMsg
            end
          else
            @errUserMsg = "There was an error in importing your experiment file named #{@fileData["experimentMetadataFileName"]}.\nBecause your file didn't include multiple value columns, we are assuming that this experiment file is a single doc.\nIf your experiment file is supposed to be a multi-column file containing multiple docs,\nplease use the following resources to fix your multi-column file:\nhttp://genboree.org/genboreeKB/projects/genboreekb-introduction/wiki/Tab_Separated_Value_Formats#Multi-column\n\nA list of errors can be found below:\n\n#{@converter.errorSummaryStr}"
            raise @errUserMsg
          end
        else
          # If we reach this branch, it means that our converter didn't report any errors in converting a single tabbed-delimited doc to a KB doc
          # That means we don't need to do anything else here - it'll be handled by the loadMetadataFiles method
        end
        foundError = false
        multiColumnExperimentErrors.each_value { |categoryValue| foundError = true unless(categoryValue.empty?) }
        if(foundError)
          multiColumnExperimentErrors.each_key { |category|
            unless(multiColumnExperimentErrors[category].empty?)
              msg = ""
              if(category == :experimentAlreadyPresent)
                msg = "The following experiment IDs\n(collected from your multi-column experiment doc)\nmatched up with a biosample\nthat already had an experiment doc listed in the manifest.\nThis is not allowed - please ensure that you only link\nexperiment docs to biosample docs once.\nRelevant experiment IDs, biosample file names,\nand sample names are listed below:"
              elsif(category == :missingExperimentIDFromBiosample)
                msg = "The following biosample metadata files\nwere missing one or more experiment IDs\n(in the \"Biosample.Related Experiments\" item list).\nThese IDs are required for mapping.\nIt is also possible that you left some blank values\nfor \"*- Related Experiment\" properties in your doc."
              elsif(category == :failedBiosampleConversion)
                msg = "The following biosample metadata files\ncould not be imported successfully\nfrom nested tabbed format.\nError logs can be seen below as well:"
              elsif(category == :missingLinkBetweenExperimentAndBiosample)
                msg = "The following experiment IDs could not be matched\nto any IDs in the \"Biosample.Related Experiments\" item list\nfor any biosample metadata docs\nmentioned in your manifest file:"
              elsif(category == :missingExperimentIDFromExperiment)
                msg = "In order to use a multi-column experiment file,\neach experiment doc must have its own doc ID.\nThe following docs do not have a experiment ID\nso they could not be parsed.\nThese docs are listed in order of value column:"
              elsif(category == :duplicateId)
                msg = "The following document IDs\n(collected from your experiment metadata docs)\nwere used multiple times.\nEach document ID can only be used once.\nProblematic IDs can be found below:"
              end
              unless(msg.empty?)
                errors << "#{msg}\n\n#{multiColumnExperimentErrors[category].join("\n")}"
              end
            end
          }
        end
        unless(errors.empty?)
          @errUserMsg = "There were some errors in parsing your multi-column experiment doc.\nA detailed list of errors can be found below:\n"
          @errUserMsg << "\n=================================================================\n"
          @errUserMsg << errors.join("\n=================================================================\n")
          @errUserMsg << "\n=================================================================\n"
          raise @errUserMsg
        end
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There was an issue with checking your general experiment file (or converting your multi-column experiment file into individual experiment files." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 40
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

    # Loads metadata files into respective hashes
    # @return [Fixnum] exit code indicating whether metadata loading was successful (0) or failed (27)
    def loadMetadataFiles()
      begin
        # The errors array will keep track of any errors that pop up when loading metadata files / generating IDs for each metadata file
        errors = []
        loadingMetadataErrors = {:failedConversion => [], :missingRootProp => [], :wrongFileName => [], :duplicateId => []}
        #### ANALYSIS DOCUMENT ####
        # Create hash for analysis metadata file: file name => KB doc of file
        currAnalysisContents = File.read("#{@metadataDir}/#{@fileData["analysisMetadataFileName"]}")
        currAnalysisContents.gsub!("\r\n", "\n")
        currAnalysisContents.gsub!("\r", "\n")
        @analysisMetadataFile = {@fileData["analysisMetadataFileName"] => BRL::Genboree::KB::KbDoc.new(@converter.parse(currAnalysisContents))}
        # Report if any errors occurred during conversion of file to KB doc
        unless(@converter.errors.empty?)
          loadingMetadataErrors[:failedConversion] << "Document name: #{@fileData["analysisMetadataFileName"]}\nImport errors:\n\n#{@converter.errorSummaryStr}"
        else
          # Report if root property of document is NOT "Analysis" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Analysis" root property
          unless(@analysisMetadataFile.values[0].getRootProp() == "Analysis")
            loadingMetadataErrors[:missingRootProp] << "#{@fileData["analysisMetadataFileName"]} (missing Analysis root property)"
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
            # If file name doesn't follow required formatting (analysis ID followed by .metadata.tsv), let's rename it for the user in all the necessary contexts
            if("#{@analysisID}.metadata.tsv" != @fileData["analysisMetadataFileName"])
              `mv #{Shellwords.escape("#{@metadataDir}/#{@fileData["analysisMetadataFileName"]}")} #{@metadataDir}/#{@analysisID}.metadata.tsv`
              @analysisMetadataFile["#{@analysisID}.metadata.tsv"] = @analysisMetadataFile.delete(@fileData["analysisMetadataFileName"])
              @fileData["analysisMetadataFileName"] = "#{@analysisID}.metadata.tsv"
              #loadingMetadataErrors[:wrongFileName] << "Document ID: #{@analysisID}\nFile Name: #{@fileData["analysisMetadataFileName"]}"
            end
          end
        end
        #### RUN DOCUMENT ####
        # Create hash for run metadata file
        currRunContents = File.read("#{@metadataDir}/#{@fileData["runMetadataFileName"]}")
        currRunContents.gsub!("\r\n", "\n")
        currRunContents.gsub!("\r", "\n")
        @runMetadataFile = {@fileData["runMetadataFileName"] => BRL::Genboree::KB::KbDoc.new(@converter.parse(currRunContents))}
        # Report if any errors occurred during conversion of file to KB doc
        unless(@converter.errors.empty?)
          loadingMetadataErrors[:failedConversion] << "Document name: #{@fileData["runMetadataFileName"]}\nImport errors:\n\n#{@converter.errorSummaryStr}"
        else
          # Report if root property of document is NOT "Run" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Run" root property
          unless(@runMetadataFile.values[0].getRootProp() == "Run")
            loadingMetadataErrors[:missingRootProp] << "#{@fileData["runMetadataFileName"]} (missing Run root property)"      
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
            if("#{@runID}.metadata.tsv" != @fileData["runMetadataFileName"])
              `mv #{Shellwords.escape("#{@metadataDir}/#{@fileData["runMetadataFileName"]}")} #{@metadataDir}/#{@runID}.metadata.tsv`
              @runMetadataFile["#{@runID}.metadata.tsv"] = @runMetadataFile.delete(@fileData["runMetadataFileName"])
              @fileData["runMetadataFileName"] = "#{@runID}.metadata.tsv"
              #loadingMetadataErrors[:wrongFileName] << "Document ID: #{@runID}\nFile Name: #{@fileData["runMetadataFileName"]}"
            end
          end
        end
        #### STUDY DOCUMENT ####
        # Create hash for study metadata file: file name => KB doc of file 
        currStudyContents = File.read("#{@metadataDir}/#{@fileData["studyMetadataFileName"]}")
        currStudyContents.gsub!("\r\n", "\n")
        currStudyContents.gsub!("\r", "\n")
        @studyMetadataFile = {@fileData["studyMetadataFileName"] => BRL::Genboree::KB::KbDoc.new(@converter.parse(currStudyContents))}
        # Report if any errors occurred during conversion from file to KB doc
        unless(@converter.errors.empty?)
          loadingMetadataErrors[:failedConversion] << "Document name: #{@fileData["studyMetadataFileName"]}\nImport errors:\n\n#{@converter.errorSummaryStr}"
        else
          # Report if root property of document is NOT "Study" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Study" root property
          unless(@studyMetadataFile.values[0].getRootProp() == "Study")
            loadingMetadataErrors[:missingRootProp] << "#{@fileData["studyMetadataFileName"]} (missing Study root property)"  
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
            if("#{@studyID}.metadata.tsv" != @fileData["studyMetadataFileName"])
              `mv #{Shellwords.escape("#{@metadataDir}/#{@fileData["studyMetadataFileName"]}")} #{@metadataDir}/#{@studyID}.metadata.tsv`
              @studyMetadataFile["#{@studyID}.metadata.tsv"] = @studyMetadataFile.delete(@fileData["studyMetadataFileName"])
              @fileData["studyMetadataFileName"] = "#{@studyID}.metadata.tsv"
              #loadingMetadataErrors[:wrongFileName] << "Document ID: #{@studyID}\nFile Name: #{@fileData["studyMetadataFileName"]}"
            end
          end
        end
        #### SUBMISSION DOCUMENT ####
        # Create hash for submission metadata file: file name => KB doc of file
        currSubmissionContents = File.read("#{@metadataDir}/#{@fileData["submissionMetadataFileName"]}")
        currSubmissionContents.gsub!("\r\n", "\n")
        currSubmissionContents.gsub!("\r", "\n")
        @submissionMetadataFile = {@fileData["submissionMetadataFileName"] => BRL::Genboree::KB::KbDoc.new(@converter.parse(currSubmissionContents))}
        # Report if any errors occurred during conversion
        unless(@converter.errors.empty?)
          loadingMetadataErrors[:failedConversion] << "Document name: #{@fileData["submissionMetadataFileName"]}\nImport errors:\n\n#{@converter.errorSummaryStr}"
        else
          # Report if root property of document is NOT "Submission" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Submission" root property
          unless(@submissionMetadataFile.values[0].getRootProp() == "Submission")
            loadingMetadataErrors[:missingRootProp] << "#{@fileData["submissionMetadataFileName"]} (missing Submission root property)"  
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
            if("#{@submissionID}.metadata.tsv" != @fileData["submissionMetadataFileName"])
              `mv #{Shellwords.escape("#{@metadataDir}/#{@fileData["submissionMetadataFileName"]}")} #{@metadataDir}/#{@submissionID}.metadata.tsv`
              @submissionMetadataFile["#{@submissionID}.metadata.tsv"] = @submissionMetadataFile.delete(@fileData["submissionMetadataFileName"])
              @fileData["submissionMetadataFileName"] = "#{@submissionID}.metadata.tsv"
              #loadingMetadataErrors[:wrongFileName] << "Document ID: #{@submissionID}\nFile Name: #{@fileData["submissionMetadataFileName"]}"
            end
          end
        end
        #### DONOR DOCUMENT (GENERAL) ####
        # Add more general donor document (above individual samples) to @donorMetadataFiles and @donorIDs if it exists (ignore if it's a multi-column doc)
        if(@fileData["donorMetadataFileName"] and !@multiDonorDoc)
          currDonorContents = File.read("#{@metadataDir}/#{@fileData["donorMetadataFileName"]}")
          currDonorContents.gsub!("\r\n", "\n")
          currDonorContents.gsub!("\r", "\n")
          currentDonorMetadataFile = {@fileData["donorMetadataFileName"] => BRL::Genboree::KB::KbDoc.new(@converter.parse(currDonorContents))}
          # Report if any errors occurred during conversion
          unless(@converter.errors.empty?)
            loadingMetadataErrors[:failedConversion] << "Document name: #{@fileData["donorMetadataFileName"]}\nImport errors:\n\n#{@converter.errorSummaryStr}"
          else
            # Report if root property of document is NOT "Donor" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Donor" root property          
            unless(currentDonorMetadataFile.values[0].getRootProp() == "Donor")
              loadingMetadataErrors[:missingRootProp] << "#{@fileData["donorMetadataFileName"]} (missing Donor root property)"       
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
              currentDonorID = currentDonorMetadataFile.values[0].getPropVal("Donor")
              @donorIDs << currentDonorID
              if("#{currentDonorID}.metadata.tsv" != @fileData["donorMetadataFileName"])
                `mv #{Shellwords.escape("#{@metadataDir}/#{@fileData["donorMetadataFileName"]}")} #{@metadataDir}/#{currentDonorID}.metadata.tsv`
                currentDonorMetadataFile["#{currentDonorID}.metadata.tsv"] = currentDonorMetadataFile.delete(@fileData["donorMetadataFileName"])
                @fileData["donorMetadataFileName"] = "#{currentDonorID}.metadata.tsv"
                #loadingMetadataErrors[:wrongFileName] << "Document ID: #{currentDonorID}\nFile Name: #{@fileData["donorMetadataFileName"]}"
              end
              @donorMetadataFiles.merge!(currentDonorMetadataFile)
            end
          end
        end
        #### EXPERIMENT DOCUMENT (GENERAL) ####
        # Add more general experiment document (above individual samples) to @experimentMetadataFiles and @experimentIDs if it exists (ignore if it's a multi-column doc)
        if(@fileData["experimentMetadataFileName"] and !@multiExperimentDoc)
          currExperimentContents = File.read("#{@metadataDir}/#{@fileData["experimentMetadataFileName"]}")
          currExperimentContents.gsub!("\r\n", "\n")
          currExperimentContents.gsub!("\r", "\n")
          currentExperimentMetadataFile = {@fileData["experimentMetadataFileName"] => BRL::Genboree::KB::KbDoc.new(@converter.parse(currExperimentContents))}
          # Report if any errors occurred during conversion
          unless(@converter.errors.empty?)
            loadingMetadataErrors[:failedConversion] << "Document name: #{@fileData["experimentMetadataFileName"]}\nImport errors:\n\n#{@converter.errorSummaryStr}"
          else 
            # Report if root property of document is NOT "Experiment" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Experiment" root property
            unless(currentExperimentMetadataFile.values[0].getRootProp() == "Experiment")
              loadingMetadataErrors[:missingRootProp] << "#{@fileData["experimentMetadataFileName"]} (missing Experiment root property)"  
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
              currentExperimentID = currentExperimentMetadataFile.values[0].getPropVal("Experiment")
              @experimentIDs << currentExperimentID
              if("#{currentExperimentID}.metadata.tsv" != @fileData["experimentMetadataFileName"])
                `mv #{Shellwords.escape("#{@metadataDir}/#{@fileData["experimentMetadataFileName"]}")} #{@metadataDir}/#{currentExperimentID}.metadata.tsv`
                currentExperimentMetadataFile["#{currentExperimentID}.metadata.tsv"] = currentExperimentMetadataFile.delete(@fileData["experimentMetadataFileName"])
                @fileData["experimentMetadataFileName"] = "#{currentExperimentID}.metadata.tsv"
                #loadingMetadataErrors[:wrongFileName] << "Document ID: #{currentExperimentID}\nFile Name: #{@fileData["experimentMetadataFileName"]}"
              end
              @experimentMetadataFiles.merge!(currentExperimentMetadataFile)
            end
          end
        end
        # Traverse each sample and load biosample / donor / experiment metadata docs
        oldToNewDonorNames = {}
        oldToNewExperimentNames = {}
        importedDonorNames = []
        importedExperimentNames = []
        @manifest.each { |eachSample|
          #### DONOR DOCUMENT (SAMPLE-SPECIFIC) ####
          if(eachSample["donorMetadataFileName"])
            if(oldToNewDonorNames[eachSample["donorMetadataFileName"]])
              eachSample["donorMetadataFileName"] = oldToNewDonorNames[eachSample["donorMetadataFileName"]]
            end
            unless(importedDonorNames.include?(eachSample["donorMetadataFileName"]))
              currDonorContents = File.read("#{@metadataDir}/#{eachSample["donorMetadataFileName"]}")
              currDonorContents.gsub!("\r\n", "\n")
              currDonorContents.gsub!("\r", "\n")
              currentDonorMetadataFile = {eachSample["donorMetadataFileName"] => BRL::Genboree::KB::KbDoc.new(@converter.parse(currDonorContents))}
              # Report if any errors occurred during conversion
              unless(@converter.errors.empty?)
                loadingMetadataErrors[:failedConversion] << "Document name: #{eachSample["donorMetadataFileName"]}\nImport errors:\n\n#{@converter.errorSummaryStr}"
              else
                # Report if root property of document is NOT "Donor" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Donor" root property          
                unless(currentDonorMetadataFile.values[0].getRootProp() == "Donor")
                  loadingMetadataErrors[:missingRootProp] << "#{eachSample["donorMetadataFileName"]} (missing Donor root property)"  
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
                  currentDonorID = currentDonorMetadataFile.values[0].getPropVal("Donor")
                  unless(@donorIDs.include?(currentDonorID))
                    @donorIDs << currentDonorID
                  end
                  if("#{currentDonorID}.metadata.tsv" != eachSample["donorMetadataFileName"])
                    `mv #{Shellwords.escape("#{@metadataDir}/#{eachSample["donorMetadataFileName"]}")} #{@metadataDir}/#{currentDonorID}.metadata.tsv`
                    currentDonorMetadataFile["#{currentDonorID}.metadata.tsv"] = currentDonorMetadataFile.delete(eachSample["donorMetadataFileName"])
                    oldToNewDonorNames[eachSample["donorMetadataFileName"]] = "#{currentDonorID}.metadata.tsv"
                    eachSample["donorMetadataFileName"] = "#{currentDonorID}.metadata.tsv"
                  end
                  importedDonorNames << "#{currentDonorID}.metadata.tsv"
                  @donorMetadataFiles.merge!(currentDonorMetadataFile)
                end
              end
            end
          end
          #### EXPERIMENT DOCUMENT (SAMPLE-SPECIFIC) ####
          if(eachSample["experimentMetadataFileName"])
            if(oldToNewExperimentNames[eachSample["experimentMetadataFileName"]])
              eachSample["experimentMetadataFileName"] = oldToNewExperimentNames[eachSample["experimentMetadataFileName"]]
            end
            unless(importedExperimentNames.include?(eachSample["experimentMetadataFileName"]))
              currExperimentContents = File.read("#{@metadataDir}/#{eachSample["experimentMetadataFileName"]}")
              currExperimentContents.gsub!("\r\n", "\n")
              currExperimentContents.gsub!("\r", "\n")
              currentExperimentMetadataFile = {eachSample["experimentMetadataFileName"] => BRL::Genboree::KB::KbDoc.new(@converter.parse(currExperimentContents))}
              # Report if any errors occurred during conversion
              unless(@converter.errors.empty?)
                loadingMetadataErrors[:failedConversion] << "Document name: #{eachSample["experimentMetadataFileName"]}\nImport errors:\n\n#{@converter.errorSummaryStr}"
              else
                # Report if root property of document is NOT "Experiment" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Experiment" root property
                unless(currentExperimentMetadataFile.values[0].getRootProp() == "Experiment")
                  loadingMetadataErrors[:missingRootProp] << "#{eachSample["experimentMetadataFileName"]} (missing Experiment root property)"  
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
                  currentExperimentID = currentExperimentMetadataFile.values[0].getPropVal("Experiment")
                  unless(@experimentIDs.include?(currentExperimentID))
                    @experimentIDs << currentExperimentID
                  end
                  if("#{currentExperimentID}.metadata.tsv" != eachSample["experimentMetadataFileName"])
                    `mv #{Shellwords.escape("#{@metadataDir}/#{eachSample["experimentMetadataFileName"]}")} #{@metadataDir}/#{currentExperimentID}.metadata.tsv`
                    currentExperimentMetadataFile["#{currentExperimentID}.metadata.tsv"] = currentExperimentMetadataFile.delete(eachSample["experimentMetadataFileName"])
                    oldToNewExperimentNames[eachSample["experimentMetadataFileName"]] = "#{currentExperimentID}.metadata.tsv"
                    eachSample["experimentMetadataFileName"] = "#{currentExperimentID}.metadata.tsv"
                    # loadingMetadataErrors[:wrongFileName] << "Document ID: #{currentExperimentID}\nFile Name: #{eachSample["experimentMetadataFileName"]}"
                  end
                  importedExperimentNames << "#{currentExperimentID}.metadata.tsv"
                  @experimentMetadataFiles.merge!(currentExperimentMetadataFile)
                end
              end
            end
          end
          #### BIOSAMPLE DOCUMENT ####
          currBiosampleContents = File.read("#{@metadataDir}/#{eachSample["biosampleMetadataFileName"]}")
          currBiosampleContents.gsub!("\r\n", "\n")
          currBiosampleContents.gsub!("\r", "\n")
          currentBiosampleMetadataFile = {eachSample["biosampleMetadataFileName"] => BRL::Genboree::KB::KbDoc.new(@converter.parse(currBiosampleContents))}
          # Report if any errors occurred during conversion
          unless(@converter.errors.empty?)
            loadingMetadataErrors[:failedConversion] << "Document name: #{eachSample["biosampleMetadataFileName"]}\nImport errors:\n\n#{@converter.errorSummaryStr}"
          else
            # Report if root property of document is NOT "Biosample" - we don't want to continue filling out document ID / introducing new issues if document doesn't even have "Biosample" root property
            unless(currentBiosampleMetadataFile.values[0].getRootProp() == "Biosample")
              loadingMetadataErrors[:missingRootProp] << "#{eachSample["biosampleMetadataFileName"]} (missing Biosample root property)"    
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
              currentBiosampleID = currentBiosampleMetadataFile.values[0].getPropVal("Biosample")
              unless(@biosampleIDs.include?(currentBiosampleID))
                @biosampleIDs << currentBiosampleID
              else
                loadingMetadataErrors[:duplicateId] << currentBiosampleID
              end
              if("#{currentBiosampleID}.metadata.tsv" != eachSample["biosampleMetadataFileName"])
                `mv #{Shellwords.escape("#{@metadataDir}/#{eachSample["biosampleMetadataFileName"]}")} #{@metadataDir}/#{currentBiosampleID}.metadata.tsv`
                currentBiosampleMetadataFile["#{currentBiosampleID}.metadata.tsv"] = currentBiosampleMetadataFile.delete(eachSample["biosampleMetadataFileName"])
                eachSample["biosampleMetadataFileName"] = "#{currentBiosampleID}.metadata.tsv"
                # loadingMetadataErrors[:wrongFileName] << "Document ID: #{currentBiosampleID}\nFile Name: #{eachSample["biosampleMetadataFileName"]}"
              end
              @biosampleMetadataFiles.merge!(currentBiosampleMetadataFile)
            end
          end
        }
        foundError = false
        loadingMetadataErrors.each_value { |categoryValue| foundError = true unless(categoryValue.empty?) }
        if(foundError)
          loadingMetadataErrors.each_key { |category|
            unless(loadingMetadataErrors[category].empty?)
              msg = ""
              if(category == :failedConversion)
                msg = "The following metadata files could not be imported successfully\nfrom nested tabbed format. This is not a problem with metadata validation\nbut rather some fundamental issue with the formatting of your doc(s).\nYou can see examples of properly formatted docs here:\n\nhttp://genboree.org/theCommons/projects/exrna-mads/wiki/Prepare_Your_Metadata_Archive#Download-Metadata-Models-Document-Templates-and-Example-Metadata-Documents\n\nError logs can be seen below as well:"
              elsif(category == :missingRootProp)
                msg = "The following metadata files were missing their required root property:"
              elsif(category == :wrongFileName)
                msg = "The names of the following metadata files did not match with their IDs.\nEach metadata file must be named after its ID.\nFor example, if your ID is EXR-AMILO1TEST00-BS,\nyour metadata file should be named EXR-AMILO1TEST00-BS.metadata.tsv.\nIt is possible that your file names no longer match your IDs because we added your required PI code (#{@piId}) to your IDs.\nProblematic files can be found below:"
              elsif(category == :duplicateId)
                msg = "The following document IDs were used more than once.\nThis is not allowed, as each document ID must be unique.\nProblematic IDs can be seen below:"
              end
              unless(msg.empty?)
                errors << "#{msg}\n\n#{loadingMetadataErrors[category].join("\n")}"
              end
            end
          }
        end
        unless(errors.empty?)
          @errUserMsg = "There were some errors with importing your documents.\nSpecific error messages can be found below:\n"
          @errUserMsg << "\n=================================================================\n"
          @errUserMsg << errors.join("\n=================================================================\n")
          @errUserMsg << "\n=================================================================\n"
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
          currentBioKbDoc = @biosampleMetadataFiles[eachSampleHash["biosampleMetadataFileName"]]
          currentExpKbDoc = (@experimentMetadataFiles[eachSampleHash["experimentMetadataFileName"]] ? @experimentMetadataFiles[eachSampleHash["experimentMetadataFileName"]] : @experimentMetadataFiles[@fileData["experimentMetadataFileName"]])
          currentDonorKbDoc = (@donorMetadataFiles[eachSampleHash["donorMetadataFileName"]] ? @donorMetadataFiles[eachSampleHash["donorMetadataFileName"]] : @donorMetadataFiles[@fileData["donorMetadataFileName"]])
          # Create "Related Experiments" item list in biosample doc
          currentBioKbDoc.setPropVal("Biosample.Related Experiments", "")
          # Creating related experiment doc to insert into biosample doc as an item
          addedExpKbDoc = BRL::Genboree::KB::KbDoc.new({})
          addedExpKbDoc.setPropVal("Related Experiment", currentExpKbDoc.getRootPropVal())
          addedExpKbDoc.setPropVal("Related Experiment.DocURL", "coll/#{CGI.escape(@experimentCollection)}/doc/#{currentExpKbDoc.getRootPropVal()}")
          # We will check to see if an experiment doc with the ID grabbed above is already listed in related experiments for this biosample.
          # If it is already listed, then we will not add it again!
          foundExperiment = false
          currentItems = currentBioKbDoc.getPropItems("Biosample.Related Experiments")
          validItems = []
          if(currentItems)
            # First, let's remove any bogus empty entries from doc
            currentItems.each { |currentRelExp|
              validItems << currentRelExp unless(currentRelExp["Related Experiment"]["value"].empty?)
            }
            currentBioKbDoc.setPropItems("Biosample.Related Experiments", validItems)
            currentItems = validItems
            # Now, let's check out the experiment docs already listed
            currentItems.each { |currentRelExp|
              # Add PI prefix to each item if it's not already there (to fix IDs inserted by user)
              currentRelExp["Related Experiment"]["value"].insert(4, @piID) unless(currentRelExp["Related Experiment"]["value"][4, @piID.length] == @piID and currentRelExp["Related Experiment"]["value"].length > 4)
              # Check whether current related experiment has doc URL as subproperty.
              # If we already have other subproperties (not possible currently, but maybe in the future!), then we add it to the list of subproperties.
              # Otherwise, we set it as the only subproperty
              if(currentRelExp["Related Experiment"]["properties"])
                currentRelExp["Related Experiment"]["properties"].store("DocURL", {"value"=>"coll/#{CGI.escape(@experimentCollection)}/doc/#{currentRelExp["Related Experiment"]["value"]}"})
              else 
                currentRelExp["Related Experiment"]["properties"] = {"DocURL"=>{"value"=>"coll/#{CGI.escape(@experimentCollection)}/doc/#{currentRelExp["Related Experiment"]["value"]}"}}
              end 
              # Set foundExperiment to be true if we found a match
              foundExperiment = true if(currentRelExp["Related Experiment"]["value"] == currentExpKbDoc.getRootPropVal())
            }
          end
          # Add related experiment doc to biosample doc
          currentBioKbDoc.addPropItem("Biosample.Related Experiments", addedExpKbDoc) unless(foundExperiment)
          # Placing info about donor into biosample doc
          currentBioKbDoc.setPropVal("Biosample.Donor ID", currentDonorKbDoc.getRootPropVal())
          currentBioKbDoc.setPropVal("Biosample.Donor ID.DocURL", "coll/#{CGI.escape(@donorCollection)}/doc/#{currentDonorKbDoc.getRootPropVal()}")
          # Set "- Status" depending on value of releaseStatus given in manifest (default of releaseNone)
          releaseStatus = @settings['releaseStatus']
          if(releaseStatus == "releaseAll")
            currentBioKbDoc.setPropVal("Biosample.Status", "Release")
          elsif(releaseStatus == "releaseControls")
            sampleType = currentBioKbDoc.getPropVal("Biosample.Biological Sample Elements.Disease Type") rescue nil
            if(sampleType)
              if(sampleType == "Healthy Control")
                currentBioKbDoc.setPropVal("Biosample.Status", "Release")
              else
                currentBioKbDoc.setPropVal("Biosample.Status", "Protect")
              end
            end
          elsif(releaseStatus == "releaseNone")
            currentBioKbDoc.setPropVal("Biosample.Status", "Protect")
          end
        }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done adding experiment and donor information to biosample metadata documents")
      rescue => err 
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in donor / experiment information for your biosample metadata documents." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 28
      end
      return @exitCode
    end
 
    # Fills in run doc with appropriate info (info about different samples, related studies)  
    # @param [Fixnum] noSamples number of samples we want to set "Run.Run.Type.small RNA-Seq.Raw Data Files" to
    # @return [Fixnum] exit code indicating whether filling in run doc succeeded (0) or failed (29)
    def fillInRunDoc(noSamples)
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adding information about biosamples and study to run metadata document")
        runKbDoc = @runMetadataFile.values[0]
        # Set up basic stuff that is always the same for every exceRpt run doc
        runKbDoc.setPropVal("Run.Type", "small RNA-Seq")
        runKbDoc.setPropVal("Run.Type.small RNA-Seq", "")
        # Number of raw data files will be set to number of samples that were successfully processed through pipeline (unsuccessful samples will not be added!)
        runKbDoc.setPropVal("Run.Type.small RNA-Seq.Raw Data Files", noSamples)
        # Clear out user-submitted data files (we only care about successful samples from THIS pipeline run)
        runKbDoc.delPropItems("Run.Type.small RNA-Seq.Raw Data Files")
        errors = []
        runMetadataErrors = {:multiSample => [], :missingNameInManifest => [], :missingNameInBiosample => []}
        foundError = false
        # We will add information about each successful sample as an item
        @biosampleMetadataFiles.each_value { |currentBioKbDoc|
          biosampleID = currentBioKbDoc.getPropVal("Biosample")
          sampleName = currentBioKbDoc.getPropVal("Biosample.Name") rescue nil
          fileName = ""
          if(sampleName and !sampleName.empty?)
            foundSample = false
            @manifest.each { |currentSampleInManifest|
              if(currentSampleInManifest["sampleName"] == sampleName)
                unless(foundSample)
                  foundSample = true
                  fileName = currentSampleInManifest["dataFileName"]
                else
                  runMetadataErrors[:multiSample] << "Sample name: #{sampleName}\nBiosample ID: #{biosampleID}" unless(runMetadataErrors[:multiSample].include?("Sample name: #{sampleName}\nBiosample ID: #{biosampleID}"))
                end
              end
            }
          else
            runMetadataErrors[:missingNameInBiosample] << biosampleID unless(runMetadataErrors[:missingNameInBiosample].include?(biosampleID))
          end
          if(fileName.empty? and (sampleName and !sampleName.empty?))
            runMetadataErrors[:missingNameInManifest] << "Sample name: #{sampleName}\nBiosample ID: #{biosampleID}" unless(runMetadataErrors[:missingNameInManifest].include?("Sample name: #{sampleName}\nBiosample ID: #{biosampleID}"))
          end
          # See if we've come across an error. We'll only check if we haven't found an error yet, though.
          unless(foundError)
            runMetadataErrors.each_value { |categoryValue| foundError = true unless(categoryValue.empty?) }
          end
          # We won't add any additional info to our run doc if we found an error
          next if(foundError)
          # Create a new doc that will be inserted into "Run.Type.small RNA-Seq.Raw Data Files" as an item. We will fill in various bits of information about the sample before we add it.
          currentSampleInRun = BRL::Genboree::KB::KbDoc.new({})
          currentSampleInRun.setPropVal("Biosample ID", biosampleID)
          currentSampleInRun.setPropVal("Biosample ID.File Name", fileName)
          currentSampleInRun.setPropVal("Biosample ID.DocURL", "coll/#{CGI.escape(@biosampleCollection)}/doc/#{biosampleID}")
          # The file type below is a dummy value. We cannot fill out this info accurately the first time we run this method because it is run before the data archive is downloaded.
          # We will fill out this info accurately later in the ERCC Final Processing wrapper by using the fillInFileTypeForRunDoc method.
          currentSampleInRun.setPropVal("Biosample ID.Type", "FASTQ")
          # Finally, we add the biosample as an item in the "Run.Type.small RNA-Seq.Raw Data Files" item list
          runKbDoc.addPropItem("Run.Type.small RNA-Seq.Raw Data Files", currentSampleInRun)
        }
        runMetadataErrors.each_value { |categoryValue| foundError = true unless(categoryValue.empty?) }
        if(foundError)
          runMetadataErrors.each_key { |category|
            unless(runMetadataErrors[category].empty?)
              msg = ""
              if(category == :multiSample)
                msg = "The following sample names (collected from your biosample metadata docs)\nmapped to multiple samples in your manifest file.\nThis is not allowed (we require 1-to-1 correspondence):"
              elsif(category == :missingNameInManifest)
                msg = "The following sample names (collected from your biosample metadata docs)\ncould not be found in your manifest file:"
              elsif(category == :missingNameInBiosample)
                msg = "The following biosample IDs are missing a value for their \"Biosample.Name\" property.\nEach biosample doc must have a value for this property (and it must link\nto a \"sampleName\" field in your manifest file)."
              end
              unless(msg.empty?)
                errors << "#{msg}\n\n#{runMetadataErrors[category].join("\n")}"
              end
            end
          }
        end
        unless(errors.empty?)
          @errUserMsg = "There were some errors with connecting your biosample metadata documents to the manifest file.\nSpecific messages can be found below:\n"
          @errUserMsg << "\n=================================================================\n"
          @errUserMsg << errors.join("\n=================================================================\n")
          @errUserMsg << "\n=================================================================\n"
          raise @errUserMsg
        end
        # We will add a link to the submitted study document in the "Related Studies" item list (if it's not already there)
        relatedStudy = BRL::Genboree::KB::KbDoc.new({})
        relatedStudy.setPropVal("Related Study", @studyID)
        relatedStudy.setPropVal("Related Study.DocURL", "coll/#{CGI.escape(@studyCollection)}/doc/#{@studyID}")
        runKbDoc.setPropVal("Run.Related Studies", "")
        foundStudy = false
        currentStudies = runKbDoc.getPropItems("Run.Related Studies")
        validItems = []
        if(currentStudies)
          # First, let's remove any bogus empty entries from doc
          currentStudies.each { |currentRelStudy|
            validItems << currentRelStudy unless(currentRelStudy["Related Study"]["value"].empty?)
          }
          runKbDoc.setPropItems("Run.Related Studies", validItems)
          currentStudies.each { |currentStudy|
            currentStudy["Related Study"]["value"].insert(4, @piID) unless(currentStudy["Related Study"]["value"][4, @piID.length] == @piID and currentStudy["Related Study"]["value"].length > 4)
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

    # Fills in study doc with info about related submission
    # @return [Fixnum] exit code indicating whether filling in study doc succeeded (0) or failed (30)
    def fillInStudyDoc()
      begin 
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adding information about submission to study metadata file")
        studyKbDoc = @studyMetadataFile.values[0]
        # uploadRawFiles will keep track of whether we're uploading the raw data files for the samples.
        # We upload the raw files if the Study doc has a Study.Aliases.[].Accession.dbName value of SRA or GEO
        studyAliases = studyKbDoc.getPropItems("Study.Aliases")
        if(studyAliases)
          studyAliases.each { |currentAlias|
            currentAlias = BRL::Genboree::KB::KbDoc.new(currentAlias)
            dbName = currentAlias.getPropVal("Accession.dbName")
            if(dbName == "SRA" or dbName == "GEO")
              @settings['uploadRawFiles'] = true
            end
          }
        end
        # We will also upload the raw files if the Study doc has "GEO" or "Other" for the "Study.Anticipated Data Repository" property.
        anticipatedDataRepo = studyKbDoc.getPropVal("Study.Anticipated Data Repository") rescue nil
        @settings['uploadRawFiles'] = true if(anticipatedDataRepo == "GEO" or anticipatedDataRepo == "Other")
        # Set embargo properties
        timeObj = DateTime.now
        endingTimeObj = timeObj >> 12
        timeObj = timeObj.to_time
        endingTimeObj = endingTimeObj.to_time
        currentDate = "#{timeObj.year}-#{timeObj.month}-#{timeObj.day}"
        @settings['dateOfSubmission'] = currentDate
        endingDate = "#{endingTimeObj.year}-#{endingTimeObj.month}-#{endingTimeObj.day}"
        studyKbDoc.setPropVal("Study.Original Submission Date", currentDate)
        studyKbDoc.setPropVal("Study.Embargo End Date", endingDate)
        # We will add a link to the submission doc in the "Related Submissions" item list (if it's not already there)
        studyKbDoc.setPropVal("Study.Related Submissions", "")
        relatedSubmission = BRL::Genboree::KB::KbDoc.new({})
        relatedSubmission.setPropVal("Related Submission", @submissionID)
        relatedSubmission.setPropVal("Related Submission.DocURL", "coll/#{CGI.escape(@submissionCollection)}/doc/#{@submissionID}")
        foundSubmission = false
        currentSubmissions = studyKbDoc.getPropItems("Study.Related Submissions")
        validItems = []
        if(currentSubmissions)
          # First, let's remove any bogus empty entries from doc
          currentSubmissions.each { |currentRelSubmission|
            validItems << currentRelSubmission unless(currentRelSubmission["Related Submission"]["value"].empty?)
          }
          studyKbDoc.setPropItems("Study.Related Submissions", validItems)
          currentSubmissions.each { |currentSubmission|
            currentSubmission["Related Submission"]["value"].insert(4, @piID) unless(currentSubmission["Related Submission"]["value"][4, @piID.length] == @piID and currentSubmission["Related Submission"]["value"].length > 4)
              if(currentSubmission["Related Submission"]["properties"])
                currentSubmission["Related Submission"]["properties"].store("DocURL", {"value"=>"coll/#{CGI.escape(@submissionCollection)}/doc/#{currentSubmission["Related Submission"]["value"]}"})
              else 
                currentSubmission["Related Submission"]["properties"] = {"DocURL"=>{"value"=>"coll/#{CGI.escape(@submissionCollection)}/doc/#{currentSubmission["Related Submission"]["value"]}"}}
              end            
            foundSubmission = true if(currentSubmission["Related Submission"]["value"] == @submissionID)
          }
        end
        studyKbDoc.addPropItem("Study.Related Submissions", relatedSubmission) unless(foundSubmission)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done adding information about submission to study metadata file")
        # Grab info about anticipated data repo - used in tool usage doc
        @settings['dataRepoSubmissionCategory'] = "DCC Submission" # Submission through FTP pipeline is ALWAYS a DCC submission
        if(studyKbDoc.getPropVal("Study.Anticipated Data Repository") rescue nil)
          @settings['anticipatedDataRepo'] = studyKbDoc.getPropVal("Study.Anticipated Data Repository")
          @settings['otherDataRepo'] = studyKbDoc.getPropVal("Study.Anticipated Data Repository.Other Data Repository") rescue nil 
          @settings['dbGaP'] = studyKbDoc.getPropVal("Study.Anticipated Data Repository.Project registered by PI with dbGaP?") rescue nil
        end
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in submission information for your study metadata document." if(@errUserMsg.nil?)
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
        # Figure out host / user / pass for API calls
        dbrcKey = @context['apiDbrcKey']
        dbrc = BRL::DB::DBRC.new(@dbrcFile, dbrcKey)
        host = dbrc.driver.split(/:/).last
        user = dbrc.user
        pass = dbrc.password
        # Grab submission document
        submissionKbDoc = @submissionMetadataFile.values[0]
        # Let's grab user's grant number from doc (for tool usage doc) and also check that it's a valid grant number according to the PI's PI Code doc
        @settings['grantNumber'] = submissionKbDoc.getPropVal("Submission.Funding Source.Grant Details") rescue nil
        unless(@settings['grantNumber'])
          @errUserMsg = "You did not supply a grant number in your Submission document - this is required!\nPlease supply a grant number and resubmit your metadata files."
          raise @errUserMsg
        else
          # Check to see what PI the user is associated with
          submitterPropPath = "ERCC PI Code.Submitters.Submitter ID.Submitter Login"
          apiCaller = ApiCaller.new(@exRNAInternalKBHost, "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/docs?matchProp={matchProp}&matchValues={matchVal}&matchMode=exact&detailed=true", user, pass)
          apiCaller.get({:grp => @exRNAInternalKBGroup, :kb => @exRNAInternalKBName, :coll => @piCollection, :matchProp => submitterPropPath, :matchVal => @subUserLogin})
          unless(apiCaller.succeeded?)
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "API caller resp body for failed call to PI KB: #{apiCaller.respBody}")
            @errUserMsg = "API call failed when trying to grab PI associated with current user.\nPlease try again."
            raise @errUserMsg
          else
            # If we can't find a PI associated with submitter, then we raise an error. We also raise an error if we find more than one PI associated with submitter.
            # If we find only ONE PI associated with submitter, then we proceed.
            if(apiCaller.parseRespBody["data"].size == 0)
              @errUserMsg = "Your user login, #{@subUserLogin},\nis not listed as a valid user under any PI in our database."
              raise @errUserMsg
            elsif(apiCaller.parseRespBody["data"].size > 1)
              @errUserMsg = "Your user login, #{@subUserLogin},\nis listed as a user under multiple PIs in our database."
              raise @errUserMsg
            else
              # grantNumbers will hold all grant numbers associated with current PI (to provide to user in error e-mail if he/she did not put a valid grant number)
              grantNumbers = []
              # We'll store the PI doc in @piDoc so that we can use it later on when filling out our submission doc
              @piDoc = BRL::Genboree::KB::KbDoc.new(apiCaller.parseRespBody["data"][0])
              # PI Name - might as well retrieve it now! We'll use it later in tool usage doc
              @settings['piID'] = @piDoc.getPropVal("ERCC PI Code")
              firstName = @piDoc.getPropVal("ERCC PI Code.PI First Name")
              middleName = @piDoc.getPropVal("ERCC PI Code.PI Middle Name") if(@piDoc.getPropVal("ERCC PI Code.PI Middle Name"))
              lastName = @piDoc.getPropVal("ERCC PI Code.PI Last Name")
              piName = firstName
              piName << " #{middleName}" if(middleName)
              piName << " #{lastName}"
              @settings['piName'] = piName
              foundGrant = false
              # Grab grant numbers (with associated grant tag)
              grantDetails = @piDoc.getPropItems("ERCC PI Code.Grant Details")
              grantDetails.each { |currentGrant|
                currentGrant = BRL::Genboree::KB::KbDoc.new(currentGrant)
                currentGrantNumber = currentGrant.getPropVal("Grant Number")
                grantNumbers << currentGrantNumber
                foundGrant = true if(@settings['grantNumber'] == currentGrantNumber)
              }
              unless(foundGrant or @settings['grantNumber'] == "Non-ERCC Funded Study")
                @errUserMsg = "Your grant number #{@settings['grantNumber']} could not be found in our database.\nHere are the valid grant numbers we found: #{grantNumbers.join(", ")}.\nIf your grant number is not listed and you think we've made a mistake, please contact a DCC admin (listed below)."
                raise @errUserMsg
              end
            end 
          end
        end
        submissionKbDoc.setPropVal("Submission.Principal Investigator", @piDoc.getPropVal("ERCC PI Code"))
        submissionKbDoc.setPropVal("Submission.Principal Investigator.First Name", @piDoc.getPropVal("ERCC PI Code.PI First Name")) if(submissionKbDoc.getPropVal("Submission.Principal Investigator.First Name").nil? or submissionKbDoc.getPropVal("Submission.Principal Investigator.First Name").empty?)
        submissionKbDoc.setPropVal("Submission.Principal Investigator.Last Name", @piDoc.getPropVal("ERCC PI Code.PI Last Name")) if(submissionKbDoc.getPropVal("Submission.Principal Investigator.Last Name").nil? or submissionKbDoc.getPropVal("Submission.Principal Investigator.Last Name").empty?)
        submissionKbDoc.setPropVal("Submission.Principal Investigator.Email", @piDoc.getPropVal("ERCC PI Code.PI Email")) if(submissionKbDoc.getPropVal("Submission.Principal Investigator.Email").nil? or submissionKbDoc.getPropVal("Submission.Principal Investigator.Email").empty?)
        submissionKbDoc.setPropVal("Submission.Organization", @piDoc.getPropVal("ERCC PI Code.Organization")) if(submissionKbDoc.getPropVal("Submission.Organization").nil? or submissionKbDoc.getPropVal("Submission.Organization").empty?)
        # Next, we traverse all submitters associated with that PI in the master list to find our submitter.
        individualSubmitters = @piDoc.getPropItems("ERCC PI Code.Submitters")
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
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done adding information about PI / submitter to submission metadata file")
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with filling in PI / submitter information for your submission metadata document." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 31
      end
      return @exitCode
    end

    # Method that validates a given metadata doc and records errors in @metadataErrors
    # @param [String] currentMetadataFileNames current hash (studies, biosamples, runs, etc.) being checked (doc names => KB docs associated with those doc names)
    # @return [Fixnum] exit code indicating whether process of validation ran successfully (0) or failed (32)
    def validateMetadataDocs(currentMetadataFileNames)
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Validating #{currentMetadataFileNames.keys.inspect}")
        # Flag to tell whether validation error occurred (just for debug statement)
        validationError = false
        # Figure out what collection the documents belong to
        currentRootProp = currentMetadataFileNames.values[0].getRootProp()
        coll = @collections[currentRootProp]
        # Create data collection helper to validate docs
        dch = @mdb.dataCollectionHelper(coll)
        # The docs we're going to validate are already in JSON format in currentMetadataFileNames.values, so we'll just use that as our payload
        payload = currentMetadataFileNames.values
        payload.each { |currentDoc|
          # We need to reset lastValidatorErrors each time so that we don't report duplicate errors for OK docs
          dch.lastValidatorErrors = nil
          # Check whether current doc is valid
          dch.valid?(currentDoc)
          validationErrors = dch.lastValidatorErrors
          # If any docs are invalid, then we will report those errors to the user
          if(validationErrors and !validationErrors.empty?)
            validationError = true
            currentID = currentDoc.getRootPropVal()
            # Figure out which file name has that document ID (we want to report this information to user)
            currentFileName = ""
            currentMetadataFileNames.each_key { |fileName|
              currentFileName = File.basename(fileName) if(currentID == currentMetadataFileNames[fileName].getRootPropVal())
            }
            # Add file name and associated error to @metadataErrors
            @metadataErrors << "#{currentFileName} (#{currentID}):\n\n#{validationErrors}"
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "The doc #{currentFileName} (#{currentID}) has errors")
          end
        }
        unless(validationError)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "the docs submitted to collection #{coll} do not have any errors")
        end
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with validating the following documents: #{currentMetadataFileNames.keys.inspect}." if(@errUserMsg.nil?)
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
        @settings['calib'] = @calib
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
        @errUserMsg = "ERROR: There was an issue with setting up your spike-in library." if(@errUserMsg.nil?)
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
        outFile = "#{@scratchDir}/indexBowtie.out"
        errFile = "#{@scratchDir}/indexBowtie.err"
        # Build Bowtie 2 index
        @oligoBowtie2BaseName = "#{@calibratorDir}/#{CGI.escape(@spikeInName)}"
        command = "bowtie2-build #{spikeInFile} #{@oligoBowtie2BaseName}"
        command << " > #{outFile} 2> #{errFile}"  
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
        exitStatus = system(command)
        # Raise error if Bowtie 2 command is unsuccessful
        unless(exitStatus)
          @errUserMsg = "Bowtie 2 indexing of your spike-in library failed to run."
          raise @errUserMsg
        end
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with creating the Bowtie 2 index of your spike-in file." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 54
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

    # @return [Fixnum] exit code indicating whether submission completely failed or not. Complete failure includes: 1) NO runExceRpt jobs being successfully submitted and/or 2) the processPipelineRuns or job not being successfully submitted
    # Submit runExceRpt worker jobs and exogenousSTARMapping / processPipelineRuns conditional job 
    def submitJobs()
      begin
        # Figure out host / user / pass for submitting jobs
        dbrcKey = @context['apiDbrcKey']
        dbrc = BRL::DB::DBRC.new(@dbrcFile, dbrcKey)
        host = dbrc.driver.split(/:/).last
        user = dbrc.user
        pass = dbrc.password
        # Set @toolId to be runExceRpt (used when submitting precondition jobs)
        @toolId = "runExceRpt"
        # conditionalJob boolean will keep track of whether any conditional job was submitted (at least one runExceRpt job)
        conditionalJob = false
        # Create a reusable ApiCaller instance for launching each runExceRpt job
        apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/genboree/tool/{toolId}/job", user, pass)
        # @preConditionJobs will be used for launching the conditional PPR job - PPR will only launch once all precondition jobs are done
        @preConditionJobs = []
        # Traverse all inputs
        @inputFileNames = []
        # Add file:// prefix to all input file paths for submission as runExceRpt worker jobs
        @inputFiles.each_key { |currentInput|
          @inputFileNames << "file://#{currentInput}"
        }
        # If we're doing full exogenous mapping, let's figure out number of samples we're going to process per node (for exogenousSTARMapping part of pipeline)
        if(@settings['fullExogenousMapping'])
          @samplesPerExoJob = (@inputFileNames.size / @exogenousNodes.to_f).ceil
          if(@samplesPerExoJob > @maxSamplesPerExoJob)
            @samplesPerExoJob = @maxSamplesPerExoJob
          end
          @exoJobIdToRunExceRptConds = {}
          @currentInputNum = 0
        end
        @currentExoIndex = 0
        @inputFileNames.each { |currentInput|
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input file: #{currentInput}")
          @currentExoIndex = (@currentInputNum.to_i / @samplesPerExoJob.to_i).to_i if(@settings['fullExogenousMapping'])
          # Create a job conf for the current input file 
          runExceRptJobObj = createRunExceRptJobConf(currentInput)
          begin
            # Submit job for current input file 
            $stderr.debugPuts(__FILE__, __method__, "runExceRptPipeline job conf for #{currentInput}", JSON.pretty_generate(runExceRptJobObj))
            httpResp = apiCaller.put({ :toolId => @toolId }, runExceRptJobObj.to_json)
            # Check result
            if(apiCaller.succeeded?)
              # We succeeded in launching at least one runExceRptPipeline job, so we set conditionalJob to be true (so that PPR will run below)
              conditionalJob = true
              $stderr.debugPuts(__FILE__, __method__, "Response to submitting runExceRptPipeline job conf for #{currentInput}", JSON.pretty_generate(apiCaller.parseRespBody))
              # We'll grab its job ID and save it in @listOfJobIds
              runExceRptJobId = apiCaller.parseRespBody['data']['text']
              @listOfJobIds[runExceRptJobId] = File.basename(currentInput)
              $stderr.debugPuts(__FILE__, __method__, "Job ID associated with #{currentInput}", runExceRptJobId)
              # We'll make a hash for the condition associated with the current job 
              condition = {
                "type" => "job",
                "expires" => (Time.now + Time::WEEK_SECS * 4).to_s,
                "met" => false,
                "condition"=> {
                  "dependencyJobUrl" => "http://#{host}/REST/v1/job/#{runExceRptJobId}",
                  "acceptableStatuses" =>
                  {
                    "killed"=>true,
                    "failed"=>true,
                    "completed"=>true,
                    "partialSuccess"=>true,
                    "canceled"=>true
                  }
                }
              }
              $stderr.debugPuts(__FILE__, __method__, "Condition connected with runExceRptPipeline job associated with #{currentInput}", condition)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "runExceRpt job accepted with analysis name: #{runExceRptJobObj['settings']['analysisName'].inspect}.\nHTTP Response: #{httpResp.inspect}\nStatus Code: #{apiCaller.apiStatusObj['statusCode'].inspect}\nStatus Message: #{apiCaller.apiStatusObj['msg'].inspect}\n#{'='*80}\n")
              if(@settings['fullExogenousMapping'])
                unless(@exoJobIdToRunExceRptConds[@currentExoIndex])
                 @exoJobIdToRunExceRptConds[@currentExoIndex] = []
                end
                @exoJobIdToRunExceRptConds[@currentExoIndex] << condition
                @currentInputNum += 1
              else
                # We'll add that condition to our @preConditionJobs array
                @preConditionJobs << condition
              end
            else
              $stderr.debugPuts(__FILE__, __method__, "ERROR (but continuing)", "#{@toolId} job submission failed! HTTP Response Object: #{httpResp.class}.\nResponse Payload:\n#{apiCaller.respBody}\n#{'='*80}\n")
              @failedJobs[currentInput] = apiCaller.respBody
            end
          rescue => err
            $stderr.debugPuts(__FILE__, __method__, "ERROR (but continuing)", "Problem with submitting the runExceRpt job #{runExceRptJobObj.inspect}: #{err.message.inspect}.\n#{err.backtrace.join("\n")}")           
            @failedJobs[currentInput] = err.message.inspect
          end
        }
        # If fullExogenousMapping is enabled, then we want to save the list of exogenous jobs in its own file (used for re-running jobs due to memory issues)
        if(@settings['fullExogenousMapping'])
          @exogenousJobIdsHash = {}
          @exogenousJobIds.each { |currentId|
            @exogenousJobIdsHash[currentId] = "Exogenous STAR Mapping Job"
          }
          @settings['filePathToListOfExogenousJobIds'] = "#{@jobSpecificSharedScratch}/listOfExogenousJobIds.txt"
          File.open(@settings['filePathToListOfExogenousJobIds'], 'w') { |file| file.write(JSON.pretty_generate(@exogenousJobIdsHash)) }
        end
        # If any runExceRpt jobs were launched above, we'll run a conditional job below
        if(conditionalJob)
          # If fullExogenousMapping=false, then we'll submit a processPipelineRuns conditional job
          # Otherwise, if fullExogenousMapping=true, we'll submit an exogenousSTARMapping conditional job
          if(@conditionalJobType == "processPipelineRuns")
            # Submit a conditional processPipelineRuns job (will run after all worker runExceRpt jobs finish)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Submitting a conditional processPipelineRuns job (will run after all worker runExceRpt jobs finish)")
            postProcessing(host, user, pass)
          else 
            # Submit a conditional exogenousSTARMapping job (will run after all worker runExceRpt jobs finish)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching an exogenousSTARMapping conditional job on the worker runExceRpt jobs")
            @exoJobIdToRunExceRptConds.each_key { |currentId|
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "currentId: #{currentId}")
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "@exoJobIdToRunExceRptConds[currentId]: #{@exoJobIdToRunExceRptConds[currentId].inspect}")
              exogenousSTARMapping(host, user, pass, currentId, @exoJobIdToRunExceRptConds[currentId])
            }
            exogenousPPRLauncherConds = []
            @exogenousJobIds.each { |currentId|
              condition = {
                "type" => "job",
                "expires" => (Time.now + Time::WEEK_SECS * 4).to_s,
                "met" => false,
                "condition"=> {
                  "dependencyJobUrl" => "http://#{host}/REST/v1/job/#{currentId}",
                  "acceptableStatuses" =>
                  {
                    "killed"=>true,
                    "failed"=>true,
                    "completed"=>true,
                    "partialSuccess"=>true,
                    "canceled"=>true
                  }
                }
              }
              exogenousPPRLauncherConds << condition
            }
            # Submit an exogenousPPRLauncher job (will run after all exogenousSTARMapping jobs finish)
            exogenousPPRLauncher(host, user, pass, exogenousPPRLauncherConds)
          end
        else
          @errUserMsg = "We could not submit runExceRpt jobs for any of your samples.\nPlease see specific error messages below:\n"
          raise @errUserMsg
        end
      rescue => err
        # Generic error message
        @errUserMsg = "ERROR: There was an issue with submitting all of your runExceRpt worker jobs." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 57
      end
      return @exitCode
    end 

      
    # Method to create an exceRpt job conf file given some input file.
    # @param [String] inputFile file path to input file
    # @return [Hash] hash containing the job conf file
    def createRunExceRptJobConf(inputFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Preparing the exceRpt jobConf for #{inputFile}")
      # Reuse the existing jobConf and modify properties as needed 
      runExceRptJobConf = @jobConf.deep_clone()
      # Define input for job conf
      runExceRptJobConf['inputs'] = inputFile
      $stderr.debugPuts(__FILE__, __method__, "INPUT FILES", "Input file: #{inputFile.inspect}")
      # We will keep the same output database
      # Define settings
      runExceRptJobConf['settings']['exoJobId'] = @currentExoIndex if(@settings['fullExogenousMapping'])
      originalInput = inputFile.clone()
      originalInput.slice!("file://")
      runExceRptJobConf['settings']['adSeqParameter'] = @inputFiles[originalInput][:adapterSequence] if(@inputFiles[originalInput][:adapterSequence])
      # Define context
      runExceRptJobConf['context']['toolIdStr'] = @exceRptToolId
      runExceRptJobConf['context']['warningsConfirmed'] = true
      runExceRptJobConf['context']['userLastName'] = @subUserLastName
      runExceRptJobConf['context']['userFirstName'] = @subUserFirstName
      runExceRptJobConf['context']['userEmail'] = @subUserEmail
      runExceRptJobConf['context']['userLogin'] = @subUserLogin
      runExceRptJobConf['context']['userId'] = @subUserId
      return runExceRptJobConf
    end
    
    # Produce a valid job conf for processPipelineRuns tool and then submit PPR job. PPR job will be conditional on all successfully launched runExceRpt jobs finishing (success or failure).
    # @param [String] host host name
    # @param [String] user user name
    # @param [String] pass password
    # @return [nil]
    def postProcessing(host, user, pass)
      # Produce processPipelineRuns job file
      createPPRJobConf()
      # Submit processPipelineRuns job
      submitPPRJob(host, user, pass)
      return
    end
   
    # Method to create processPipelineRuns jobFile.json used in launchPPRJob()
    # @return [nil]
    def createPPRJobConf()
      @pprJobConf = @jobConf.deep_clone()
      @pprJobConf['inputs'] = ["#{@outputDb}/file/dummyFile.tgz"]
      ## Define context
      @pprJobConf['context']['toolIdStr'] = "processPipelineRuns"
      @pprJobConf['context']['userLastName'] = @subUserLastName
      @pprJobConf['context']['userFirstName'] = @subUserFirstName
      @pprJobConf['context']['userEmail'] = @subUserEmail
      @pprJobConf['context']['userLogin'] = @subUserLogin
      @pprJobConf['context']['userId'] = @subUserId
      @pprJobConf['settings']['manifestFile'] = @manifestFile
      @pprJobConf['outputs'].delete_at(1)
      @pprJobConf['outputs'].delete_at(1)
      # We will submit a conditional job. Its preconditions will be the runExceRpt jobs launched above. 
      @pprJobConf['preconditionSet'] =  {
        "willNeverMatch"=> false,
        "numMet"=> 0,
        "someExpired"=> false,
        "count"=> 0,
        "preconditions"=> @preConditionJobs
      }
      # Write jobConf hash to tool specific jobFile.json
      @pprJobFile = "#{@postProcDir}/pprJobFile.json"
      File.open(@pprJobFile,"w") do |pprJob|
        pprJob.write(JSON.pretty_generate(@pprJobConf))
      end
      return
    end

    # Method to submit processPipelineRuns job
    # @param [String] host host name
    # @param [String] user user name 
    # @param [String] pass password
    # @return [nil]
    def submitPPRJob(host, user, pass)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/genboree/tool/processPipelineRuns/job", user, pass)
      apiCaller.put({}, @pprJobConf.to_json)
      unless(apiCaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "PROCESS PIPELINE RUNS JOB SUBMISSION FAILURE", apiCaller.respBody.inspect)
        @errUserMsg = "We could not submit your processPipelineRuns job as a conditional job."
        raise @errUserMsg
      else
        $stderr.debugPuts(__FILE__, __method__, "PROCESS PIPELINE RUNS JOB SUBMISSION SUCCESS", apiCaller.respBody.inspect)
      end
      return
    end

    # Produce a valid job conf for exogenousSTARMapping tool and then submit ESM job. ESM job will be conditional on all successfully launched runExceRpt jobs finishing (success or failure).
    # @param [String] host host name
    # @param [String] user user name
    # @param [String] pass password
    # @param [Array] conditions array of different job conditions required for current exogenousSTARMapping job to launch
    # @return [nil]
    def exogenousSTARMapping(host, user, pass, exoJobId, conditions)
      # Produce exogenousSTARMapping job file
      esmJobConf = createESMJobConf(exoJobId, conditions)
      # Launch exogenousSTARMapping job
      submitESMJob(host, user, pass, esmJobConf)
      return
    end
   
    # Method to create exogenousSTARMapping jobFile.json used in submitESMJob()
    # @settings [Fixnum] exoJobId ID associated with exogenousSTARMapping job (used to divide exogenousSTARMapping jobs on disk)
    # @settings [Array] conditions array of job conditions used as preconditions for current exogenousSTARMapping job
    # @return [JSON] job conf for exogenousSTARMapping tool
    def createESMJobConf(exoJobId, conditions)
      esmJobConf = @jobConf.deep_clone()
      ## Define context
      esmJobConf['context']['toolIdStr'] = "exogenousSTARMapping"
      esmJobConf['context']['userLastName'] = @subUserLastName
      esmJobConf['context']['userFirstName'] = @subUserFirstName
      esmJobConf['context']['userEmail'] = @subUserEmail
      esmJobConf['context']['userLogin'] = @subUserLogin
      esmJobConf['context']['userId'] = @subUserId
      esmJobConf['settings']['manifestFile'] = @manifestFile
      esmJobConf['settings']['exogenousMapping'] = "on"
      esmJobConf['settings']['exoJobId'] = exoJobId
      esmJobConf['outputs'].delete_at(1)
      esmJobConf['outputs'].delete_at(1)
      # We will submit a conditional job. Its preconditions will be the runExceRpt jobs launched above. 
      esmJobConf['preconditionSet'] =  {
        "willNeverMatch"=> false,
        "numMet"=> 0,
        "someExpired"=> false,
        "count"=> 0,
        "preconditions"=> conditions
      }
      # Write jobConf hash to tool specific jobFile.json
      esmJobFile = "#{@exogenousMappingInputDir}/esmJobFile.json"
      File.open(esmJobFile,"w") do |esmJob|
        esmJob.write(JSON.pretty_generate(esmJobConf))
      end
      return esmJobConf
    end
    
    # Method to call exogenousSTARMapping job for successful samples
    # @param [String] host host name
    # @param [String] user user name 
    # @param [String] pass password
    # @param [JSON] esmJobConf job conf for current exogenousSTARMapping job
    # @return [nil]
    def submitESMJob(host, user, pass, esmJobConf)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/genboree/tool/exogenousSTARMapping/job", user, pass)
      apiCaller.put({}, esmJobConf.to_json)
      unless(apiCaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "EXOGENOUS STAR MAPPING JOB SUBMISSION FAILURE", apiCaller.respBody.inspect)
        @errUserMsg = "We could not submit your exogenousSTARMapping job as a conditional job."
        raise @errUserMsg
      else
        $stderr.debugPuts(__FILE__, __method__, "EXOGENOUS STAR MAPPING JOB SUBMISSION SUCCESS", apiCaller.respBody.inspect)
        @exogenousJobIds << apiCaller.parseRespBody['data']['text']
      end
      return
    end

    # Produce a valid job conf for exogenousSTARMapping tool and then submit ESM job. ESM job will be conditional on all successfully launched runExceRpt jobs finishing (success or failure).
    # @param [String] host host name
    # @param [String] user user name
    # @param [String] pass password
    # @param [Array] conditions array of different job conditions required for exogenousPPRLauncher job to launch
    # @return [nil]
    def exogenousPPRLauncher(host, user, pass, conditions)
      # Produce exogenousPPRLauncher job file
      eplJobConf = createEPLJobConf(conditions)
      # Launch exogenousPPRLauncher job
      submitEPLJob(host, user, pass, eplJobConf)
      return
    end
   
    # Method to create exogenousPPRLauncher jobFile.json used in submitEPLJob()
    # @settings [Array] conditions array of job conditions used as preconditions for exogenousPPRLauncher job
    # @return [JSON] job conf for exogenousPPRLauncher tool
    def createEPLJobConf(conditions)
      eplJobConf = @jobConf.deep_clone()
      ## Define context
      eplJobConf['context']['toolIdStr'] = @exogenousPPRLauncherToolId
      eplJobConf['context']['userLastName'] = @subUserLastName
      eplJobConf['context']['userFirstName'] = @subUserFirstName
      eplJobConf['context']['userEmail'] = @subUserEmail
      eplJobConf['context']['userLogin'] = @subUserLogin
      eplJobConf['context']['userId'] = @subUserId
      eplJobConf['settings']['manifestFile'] = @manifestFile
      eplJobConf['settings']['exogenousMapping'] = "on"
      eplJobConf['outputs'].delete_at(1)
      eplJobConf['outputs'].delete_at(1)
      # We will submit a conditional job. Its preconditions will be the runExceRpt jobs launched above. 
      eplJobConf['preconditionSet'] =  {
        "willNeverMatch"=> false,
        "numMet"=> 0,
        "someExpired"=> false,
        "count"=> 0,
        "preconditions"=> conditions
      }
      # Write jobConf hash to tool specific jobFile.json
      eplJobFile = "#{@exogenousMappingInputDir}/eplJobFile.json"
      File.open(eplJobFile,"w") do |eplJob|
        eplJob.write(JSON.pretty_generate(eplJobConf))
      end
      return eplJobConf
    end
    
    # Method to call exogenousPPRLauncher job for successful samples
    # @param [String] host host name
    # @param [String] user user name 
    # @param [String] pass password 
    # @param [JSON] eplJobConf job conf for current exogenousPPRLauncher job
    # @return [nil]
    def submitEPLJob(host, user, pass, eplJobConf)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/genboree/tool/exogenousPPRLauncher/job", user, pass)
      apiCaller.put({}, eplJobConf.to_json)
      unless(apiCaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "EXOGENOUS PPR LAUNCHER JOB SUBMISSION FAILURE", apiCaller.respBody.inspect)
        @errUserMsg = "We could not submit your exogenousPPRLauncher job as a conditional job."
        raise @errUserMsg
      else
        $stderr.debugPuts(__FILE__, __method__, "EXOGENOUS PPR LAUNCHER JOB SUBMISSION SUCCESS", apiCaller.respBody.inspect)
      end
      return
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
          @errUserMsg = "ERROR: We had trouble transferring your files on the FTP server from the /working directory to the /inbox directory."
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

############ END of methods specific to this smRNAPipeline wrapper

    # Success email
    def prepSuccessEmail()
      # Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
      # Remove settings that are unnecessary for user e-mail
      @settings.delete("adSeqParameter")
      @settings.delete("anticipatedDataRepos")
      @settings.delete("exRNAInternalKBGroup")
      @settings.delete("exRNAInternalKBHost")
      @settings.delete("exRNAInternalKBName")
      if(@settings["calib"] == "NULL")
        @settings.delete("calib")
      else 
        @settings["calib"] = File.basename(@settings["calib"])
      end
      @settings.delete("exRNAInternalKBPICodesColl")
      @settings.delete("exRNAInternalKBToolUsageColl")
      @settings.delete("grantNumbers")
      @settings.delete("indexBaseName") unless(@settings['useLibrary'] =~ /uploadNewLibrary/)
      @settings.delete("newSpikeInLibrary") unless(@settings['useLibrary'] =~ /uploadNewLibrary/)
      @settings.delete("existingLibraryName") unless(@settings['useLibrary'] =~ /useExistingLibrary/)
      @settings.delete("jobSpecificSharedScratch")
      @settings.delete("filePathToListOfJobIds")
      @settings.delete("manualAdapter") unless(@settings['adapterSequence'] == "other" and @settings['autoDetectAdapter'] == "no")
      @settings.delete("otherDataRepo") unless(@settings['anticipatedDataRepo'] == "Other")
      @settings.delete("piID")
      @settings.delete("platform")
      @settings.delete("primaryJobId")
      @settings.delete("processingPipeline")
      @settings.delete("processingPipelineIdAndVersion")
      @settings.delete("processingPipelineVersion")
      unless(@settings["randomBarcodesEnabled"])
        @settings.delete("randomBarcodeLength")
        @settings.delete("randomBarcodeLocation")
        @settings.delete("randomBarcodeStats")
      end
      @settings.delete("spinnerField_circRNAOrder")
      @settings.delete("spinnerField_gencodeOrder")
      @settings.delete("spinnerField_miRNAOrder")
      @settings.delete("spinnerField_piRNAOrder")
      @settings.delete("spinnerField_tRNAOrder")
      @settings.delete("subdirs")
      @settings.delete("wbContext")
      @settings.delete("exRNAHost")
      @settings.delete("exRNAKb")
      @settings.delete("exRNAKbGroup")
      @settings.delete("exRNAKbProject")
      @settings.delete("failedFtpDir")
      @settings.delete("backupFtpDir")
      @settings.delete("finalizedMetadataDir")
      @settings.delete("finishedFtpDir")
      @settings.delete("dataArchiveLocation")
      @settings.delete("genomeBuild")
      @settings.delete("genboreeKbArea")
      @settings.delete("javaRam")
      @settings.delete("localExecution")
      @settings.delete("manifestLocation")
      @settings.delete("metadataArchiveLocation")
      @settings.delete("numThreads")
      @settings.delete("outputHost")
      @settings.delete("postProcDir")
      @settings["endogenousLibraryOrder"].gsub!(",", " > ") if(@settings["endogenousLibraryOrder"])
      @settings.delete("subUserId")
      @settings['exogenousMapping'] = "on" if(@settings['fullExogenousMapping'])
      @settings.delete("exogenousMappingInputDir")
      @settings.delete("fullExogenousMapping")
      @settings.delete('exRNAAtlasURL')
      @settings.delete("uploadReadCountsDocs")
      @settings.delete('dbGaP') if(@settings['dbGaP'] == nil)
      @settings.delete('anticipatedDataRepo') if(@settings['anticipatedDataRepo'] == nil)
      @settings.delete('otherDataRepo') if(@settings['otherDataRepo'] == nil)
      @settings.delete('exogenousTaxoTreeJobIDDir')
      @settings.delete('exogenousRerunDir')
      @settings.delete('filePathToListOfExogenousJobIds')
      @settings.delete('importantJobIdsDir')
      # Email object
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@subUserEmail,@jobId)
      emailObject.userFirst      = @subUserFirstName
      emailObject.userLast       = @subUserLastName
      emailObject.analysisName  = @analysisName
      emailObject.inputsText    = nil
      emailObject.outputsText   = nil
      emailObject.settings      = @jobConf['settings']
      emailObject.exitStatusCode = @exitCode
      runExceRptJobIds = @listOfJobIds.keys
      numJobsSubmitted = runExceRptJobIds.length
      additionalInfo = ""
      additionalInfo << "\n==================================================================\n" +
                         "NOTE 1:\n#{(@failedJobs.empty?) ? "All" : "Some"} of your small RNA-seq samples have been submitted\nfor processing through the exceRpt analysis pipeline."
      unless(@settings['suppressRunExceRptEmails'])
        additionalInfo << "\nYou will receive an email when each job finishes\n(3 emails for 3 submitted samples, for example)."
      end
      if(@settings['fullExogenousMapping'])
        additionalInfo << "\n==================================================================\n" +
                          "NOTE 2:\nNext, since you selected full exogenous genomic mapping,\nyour samples will be processed through the Exogenous STAR Mapping tool.\nYou will receive a single email from this tool\nwhen all samples have been processed."
      end
      # Note numbers change depending on whether full exogenous mapping is enabled (since NOTE 2 above only exists if user chooses full exogenous mapping)
      currentNoteNumber = (@settings['fullExogenousMapping'] ? 3 : 2)
      finalNoteNumber = currentNoteNumber + 1
      additionalInfo << "\n==================================================================\n" +
                        "NOTE #{currentNoteNumber}:\nThen, all of your samples will be run through the exceRpt Post-processing tool.\nThis will condense your results into an easy-to-read report.\nYou will receive a single email from this tool\nwhen all samples have been processed." +
                        "\n==================================================================\n" +
                        "NOTE #{finalNoteNumber}:\nFinally, you will receive a single email from the ERCC Final Processing tool.\nThis email will tell you the final status of the jobs above\nand will inform you of any failures."
      if(!@failedJobs.empty?)
        additionalInfo << "\n==================================================================\n" +
                          "Please note that AT LEAST SOME OF YOUR FILES WERE NOT SUCCESSFULLY SUBMITTED!\nYou can find more information below."
      end
      additionalInfo << "\n==================================================================\n" +
                        "Number of jobs successfully submitted for processing: #{numJobsSubmitted}\n\n" +
                        "List of job IDs with respective input files:"
      @listOfJobIds.each_key { |jobId|
        additionalInfo << "\n\nJOB ID: #{jobId}\n" +
                          "Input: #{@listOfJobIds[jobId]}"
      }
      unless(@failedJobs.empty?)
        additionalInfo << "\n==================================================================\n"
        additionalInfo << "We encountered errors when submitting some of your samples. Please see a list of samples and their respective errors below:"
        @failedJobs.each_key { |currentSample|
          additionalInfo << "\n\nCurrent sample: #{currentSample}\n" +
                            "Error message: #{@failedJobs[currentSample]}"
        }
      end
      additionalInfo << "\n==================================================================\n"
      emailObject.additionalInfo = additionalInfo
      if(@suppressEmail)
        return nil
      else
        return emailObject
      end
    end

    # Error email
    def prepErrorEmail()
      # Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
      # Remove settings that are unnecessary for user e-mail
      @settings["adapterSequence"] << " (autoDetect)" if(@settings["adapterSequence"] == "guessKnown")
      @settings.delete("anticipatedDataRepos")
      @settings.delete("exRNAInternalKBGroup")
      @settings.delete("exRNAInternalKBHost")
      @settings.delete("exRNAInternalKBName")
      @settings.delete("exRNAInternalKBPICodesColl")
      @settings.delete("exRNAInternalKBToolUsageColl")
      @settings.delete("grantNumbers")
      @settings.delete("indexBaseName") unless(@settings['useLibrary'] =~ /uploadNewLibrary/)
      @settings.delete("newSpikeInLibrary") unless(@settings['useLibrary'] =~ /uploadNewLibrary/)
      @settings.delete("existingLibraryName") unless(@settings['useLibrary'] =~ /useExistingLibrary/)
      @settings.delete("jobSpecificSharedScratch")
      @settings.delete("manualAdapter") unless(@settings['adapterSequence'] == "other" and @settings['autoDetectAdapter'] == "no")
      @settings.delete("otherDataRepo") unless(@settings['anticipatedDataRepo'] == "Other")
      @settings.delete("piID")
      @settings.delete("platform")
      @settings.delete("primaryJobId")
      @settings.delete("processingPipeline")
      @settings.delete("processingPipelineIdAndVersion")
      @settings.delete("processingPipelineVersion")
      unless(@settings["randomBarcodesEnabled"])
        @settings.delete("randomBarcodeLength")
        @settings.delete("randomBarcodeLocation")
        @settings.delete("randomBarcodeStats")
      end
      @settings.delete("spinnerField_circRNAOrder")
      @settings.delete("spinnerField_gencodeOrder")
      @settings.delete("spinnerField_miRNAOrder")
      @settings.delete("spinnerField_piRNAOrder")
      @settings.delete("spinnerField_tRNAOrder")
      @settings.delete("subdirs")
      @settings.delete("wbContext")
      @settings["endogenousLibraryOrder"].gsub!(",", " > ") if(@settings["endogenousLibraryOrder"])
      @settings.delete("exRNAHost")
      @settings.delete("exRNAKb")
      @settings.delete("exRNAKbGroup")
      @settings.delete("exRNAKbProject")
      @settings.delete("failedFtpDir")
      @settings.delete("backupFtpDir")
      @settings.delete("finalizedMetadataDir")
      @settings.delete("finishedFtpDir")
      @settings.delete("dataArchiveLocation")
      @settings.delete("genomeBuild")
      @settings.delete("genboreeKbArea")
      @settings.delete("javaRam")
      @settings.delete("localExecution")
      @settings.delete("manifestLocation")
      @settings.delete("metadataArchiveLocation")
      @settings.delete("numThreads")
      @settings.delete("outputHost")
      @settings.delete("postProcDir")
      @settings.delete("subUserId")
      @settings['exogenousMapping'] = "on" if(@settings['fullExogenousMapping'])
      @settings.delete("exogenousMappingInputDir")
      @settings.delete('exogenousRerunDir')
      @settings.delete('filePathToListOfExogenousJobIds')
      @settings.delete("fullExogenousMapping")
      # Delete local path to important job IDs dir
      @settings.delete('importantJobIdsDir')
      @settings.delete('exRNAAtlasURL')
      @settings.delete("uploadReadCountsDocs")
      @settings.delete('dbGaP') if(@settings['dbGaP'] == nil)
      @settings.delete('anticipatedDataRepo') if(@settings['anticipatedDataRepo'] == nil)
      @settings.delete('otherDataRepo') if(@settings['otherDataRepo'] == nil)
      @settings.delete('exogenousTaxoTreeJobIDDir')
      # Email object
      emailErrorObject                = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@subUserEmail,@jobId)
      emailErrorObject.userFirst      = @subUserFirstName
      emailErrorObject.userLast       = @subUserLastName
      emailErrorObject.analysisName   = @analysisName
      emailErrorObject.inputsText    = nil
      emailErrorObject.outputsText   = nil
      emailErrorObject.settings       = @jobConf['settings']
      emailErrorObject.errMessage     = @errUserMsg
      emailErrorObject.exitStatusCode = @exitCode
      additionalInfo = ""
      # Print paths to working file(s) for user
      if(@workingFiles)
        unless(@workingFiles.empty?)
          additionalInfo << "======================WORKING FILES==============================\n" 
          additionalInfo << "The files below were not involved in any errors (but were not necessarily checked yet) and were moved back to your inbox.\nThese files include:\n\n"
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
      # Print information about runExceRpt jobs that were not submitted successfully
      if(@failedJobs)
        unless(@failedJobs.empty?)
          additionalInfo << "We encountered errors when submitting your samples. Please see a list of samples and their respective errors below:"
          @failedJobs.each_key { |currentSample|
            additionalInfo << "\n\nCurrent sample: #{currentSample}\n" +
                              "Error message: #{@failedJobs[currentSample]}"
          }
        end
      end
      additionalInfo << "\n==================================================================\n" if(@failedJobs and !@failedJobs.empty?)
      emailErrorObject.additionalInfo = additionalInfo
      emailErrorObject.erccTool = true
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
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::FTPexceRptPipelineWrapper)
end