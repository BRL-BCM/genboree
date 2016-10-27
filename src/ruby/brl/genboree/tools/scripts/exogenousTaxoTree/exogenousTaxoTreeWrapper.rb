#!/usr/bin/env ruby
########################################################
############ exogenousTaxoTree wrapper #################
# This wrapper generates the exogenous taxonomy tree   #
# using the output from exogenousSTARMapping for       #
# a single sample.                                     #
# Modules used in this pipeline:                       #
# 1. exceRptPipeline                                   #
########################################################

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
require 'brl/genboree/helpers/sniffer'
require 'parallel'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/tools/FTPtoolWrapper'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class ExogenousTaxoTreeWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "4.6.2"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running 'exogenousTaxoTree'. 
                        This tool generates the exogenous taxonomy tree for a sample using the output from exogenousSTARMapping.
                        This tool is intended to be called via the exceRptPipeline wrapper (batch-processing)",
      :authors      => [ "William Thistlethwaite (thistlew@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # @return [FixNum] @exitCode code corresponding to whether tool run was successful or not (and if not, what error message should be given to user)
    def processJobConf()
      begin
        # Getting relevant variables from "context"
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        # Grab group name and db name
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
        # Set up tool version variables used throughout this tool
        @toolVersion = @settings['toolVersion']
        # Set up format options coming from the UI
        @analysisName = @settings['analysisName']
        @javaRam = @settings['javaRam']
        @postProcDir = @settings['postProcDir']
        @isFTPJob = @settings['isFTPJob'] 
        @remoteStorageArea = @settings['remoteStorageArea'] if(@settings['remoteStorageArea'])
        @subUserId = @settings['subUserId']
        @subUserId = @userId unless(@subUserId)
        @coreResultsArchive = @settings['coreResultsArchive']
        @sampleID = @settings['sampleID']
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
    # @return [FixNum] @exitCode code corresponding to whether tool run was successful or not (and if not, what error message should be given to user)
    def run()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "BEGIN individual run of exogenous taxonomy tree generation (version #{@toolVersion})")
        # Set up API URI helper for processing inputs currently in email to user
        @apiUriHelper = BRL::Genboree::REST::Helpers::ApiUriHelper.new()
        # Grab location of makefile
        @smRNAMakefile = ENV['SMALLRNA_MAKEFILE']
        # Grab input file and cut off file:// prefix so that we have the location on disk (in cluster shared scratch area)
        @inputFile = @inputs[0].clone
        @inputFile.slice!("file://")
        # Move file to local scratch area
        `mv #{@inputFile} #{@scratchDir}/#{File.basename(@inputFile)}`
        @inputFile = "#{@scratchDir}/#{File.basename(@inputFile)}"
        # @failedRun keeps track of whether the sample was successfully processed
        @failedRun = false
        # Run sample through exogenous taxonomy tree program
        begin
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "exogenousTaxoTree method to process sample #{@inputFile}")
          exogenousTaxoTree(@inputFile)
        rescue => err
          # If an error occurs, we'll mark the run as failed and set the error message accordingly
          @failedRun = true
          @errUserMsg = err.message.inspect
          @errBacktrace = err.backtrace.join("\n")
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error message: #{@errUserMsg}")
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Backtrace: #{@errBacktrace}")
        end
        # If run failed for some reason, then we raise our error
        if(@failedRun)
          raise @errUserMsg
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE exogenousTaxoTree (version #{@toolVersion}). END.")
        # DONE exogenousTaxoTree
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of Exogenous Taxonomy Tree Generation (version #{@toolVersion}) failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to run Exogenous Taxonomy Tree Generation (version #{@toolVersion})." if(@errInternalMsg.nil?)
        @exitCode = 30 if(@exitCode == 0)
      end
      return @exitCode
    end

###### *****************************
###### Methods used in this workflow
###### *****************************

    # Run exogenousTaxoTree on a particular sample
    # @param [String] inFile path to file name for input file 
    # @return [nil]
    def exogenousTaxoTree(inFile)
      # Create sample name and save it under @sampleName 
      sampleName = File.basename(inFile)
      sampleName.gsub!(/[\.|\s]+/, '_')
      @sampleName = "sample_#{sampleName}"
      # Variables used for .out / .err files for exogenousTaxoTree run
      errFile = "#{@scratchDir}/#{@sampleName}.err"
      # Create Java command to run exogenous taxonomy tree program
      command = "#{ENV['JAVA_EXE']} -Xmx#{@settings['javaRam']} -jar #{ENV['EXCERPT_TOOLS_EXE']} ProcessExogenousAlignments -taxonomyPath #{ENV['EXCERPT_DATABASE']}/NCBI_taxonomy_taxdump -min 0.001 -frac 0.95 -batchSize 500000 -minReads 3 -alignments #{inFile} > #{@scratchDir}/ExogenousGenomicAlignments.result.taxaAnnotated.txt 2>> #{errFile}"
      # Launching Java command
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "exogenousTaxoTree command completed for #{inFile} (exit code: #{statusObj.exitstatus})")
      # Check whether there was an error with the exceRpt pipeline run
      foundError = findError(exitStatus, inFile, errFile)
      unless(foundError)
        # Create temporary directory where CORE_RESULTS archive will be unzipped
        tempCoreResultsDir = "#{@scratchDir}/TEMP_CORE_RESULTS_DIR"
        `mkdir -p #{tempCoreResultsDir}`
        # Unzip CORE_RESULTS archive to temp dir
        `tar -zxvf #{Shellwords.escape(@coreResultsArchive)} -C #{tempCoreResultsDir}`
        # Copy taxonomy tree file to the proper directory inside of archive
        `mkdir -p #{tempCoreResultsDir}/#{@sampleID}/EXOGENOUS_genomes`
        `cp -r #{@scratchDir}/ExogenousGenomicAlignments.result.taxaAnnotated.txt #{tempCoreResultsDir}/#{@sampleID}/EXOGENOUS_genomes/ExogenousGenomicAlignments.result.taxaAnnotated.txt`
        # Delete old copy of CORE_RESULTS archive
        `rm -f #{@coreResultsArchive}`
        # Re-zip the (new) contents of the CORE_RESULTS archive in the same place as the previous version
        `cd #{tempCoreResultsDir} ; tar -zcvf #{@coreResultsArchive} *`
        # Delete the unzipped CORE_RESULTS directory (we're done compressing it again)
        `rm -rf #{tempCoreResultsDir}`
        # Let's also move our CORE_RESULTS archive to the post-processing area, since we've updated it
        `cp #{@coreResultsArchive} #{@postProcDir}/runs/#{File.basename(@coreResultsArchive)}`
        # If we're running an FTP job, we need to copy the CORE_RESULTS archive to the shared area (so that erccFinalProcessing can use it for parsing reads and other FTP exceRpt tasks).
        if(@isFTPJob)
          sharedCoreArchive = "#{@settings['jobSpecificSharedScratch']}/samples/#{@sampleID}/#{File.basename(@coreResultsArchive)}"
          `cp #{@coreResultsArchive} #{sharedCoreArchive}`
        end
        # Transfer CORE_RESULTS archive and taxonomy tree file for this sample to the user db
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Transferring CORE_RESULTS archive and taxonomy tree file for this sample #{inFile} to the server")
        transferFiles(@coreResultsArchive, "#{@scratchDir}/ExogenousGenomicAlignments.result.taxaAnnotated.txt")
      end
      return
    end
          
    # Transfer output files to the user database for a particular sample
    # @param [String] coreResultsArchive path to core results archive
    # @param [String] taxaTree path to taxonomy tree file
    # @return [nil]
    def transferFiles(coreResultsArchive, taxaTree)
      # Parse target URI for outputs
      targetUri = URI.parse(@outputs[0])
      # Specify full resource path
      unless(@remoteStorageArea)
        rsrcPath = "#{targetUri.path}/file/exceRptPipeline_v#{@toolVersion}/{analysisName}/#{CGI.escape(@sampleID)}/{outputFile}/data?" 
      else
        rsrcPath = "#{targetUri.path}/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@toolVersion}/{analysisName}/#{CGI.escape(@sampleID)}/{outputFile}/data?" 
      end
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      # CORE_RESULTS archive to CORE_RESULTS subdir
      uploadFile(targetUri.host, rsrcPath, @subUserId, coreResultsArchive, {:analysisName => @analysisName, :outputFile => "CORE_RESULTS/#{File.basename(coreResultsArchive)}"})
      # Exogenous taxa file to EXOGENOUS_GENOMES subdir
      uploadFile(targetUri.host, rsrcPath, @subUserId, taxaTree, {:analysisName => @analysisName, :outputFile => "EXOGENOUS_GENOME_OUTPUT/#{File.basename(taxaTree)}"})
      # Exogenous taxa file to CORE_RESULTS subdir/sampleID/EXOGENOUS_genomes
      uploadFile(targetUri.host, rsrcPath, @subUserId, taxaTree, {:analysisName => @analysisName, :outputFile => "CORE_RESULTS/#{@sampleID}/EXOGENOUS_genomes/#{File.basename(taxaTree)}"})
      return
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

    # Try hard to detect errors
    # - exceRpt Pipeline can exit with 0 status even when it clearly failed.
    # - So we need to aggressively go looking for any errors.
    # @param [boolean] exitStatus indicating if the system() call "succeeded" or not.
    #   system() returns boolean, but if true can't be trusted for smallRNA-seq Pipeline.
    # @param [String] inFile path to file name for input file
    # @param [String] errFile path to file where error output is stored from run
    # @return [boolean] indicating if a smallRNA-seq Pipeline error was found or not.
    #   if so, @errUserMsg, @errInternalMsg, @exitCode will be set appropriately
    def findError(exitStatus, inFile, errFile)
      retVal = false
      errorMessages = nil
      # Check the obvious things first. Outright failure or putting error messages on stderr:
      cmd = "grep -P \"^ERROR\\s\" #{errFile}"
      errorMessages = `#{cmd}`
      if(errorMessages.strip.empty?)
        retVal = false
      else
        retVal = true
      end
      # Did we find anything?
      if(retVal or !exitStatus)
        # Here, we mark the current run as failed and set its error message correspondingly
        @failedRun = true
        @errUserMsg = "Exogenous Taxonomy Tree job failed.\nMessage from exceRpt:\n\""
        @errUserMsg << (errorMessages || "[No error info available from exceRpt]")
      end
      return retVal
    end

############ END of methods specific to this runExceRpt wrapper
    
########### Email 

    # Method to send success e-mail to user
    def prepSuccessEmail()
      # Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
      return nil
    end
    
    # Method to send failure e-mail to user
    def prepErrorEmail()
      # Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
      # Email object
      emailErrorObject                = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailErrorObject.userFirst      = @userFirstName
      emailErrorObject.userLast       = @userLastName
      emailErrorObject.analysisName   = @analysisName
      inputsText                      = customBuildSectionEmailSummary(@inputs)
      emailErrorObject.inputsText     = inputsText
      outputsText                     = buildSectionEmailSummary(@outputs[0])
      emailErrorObject.outputsText    = outputsText
      emailErrorObject.settings       = @jobConf['settings']
      emailErrorObject.errMessage     = @errUserMsg
      emailErrorObject.exitStatusCode = @exitCode
      emailErrorObject.erccTool = true
      # Remove settings that are unnecessary for user e-mail
      cleanUpSettingsForEmail()
      if(@suppressEmail)
        return nil
      else
        return emailErrorObject
      end
    end

    # When we send our success or failure email, there are certain settings that we don't want to send the user (because they're not helpful, redundant, etc.).
    # @return [nil]  
    def cleanUpSettingsForEmail()
      if(@settings['endogenousLibraryOrder'])
        @settings['endogenousLibraryOrder'].gsub!("gencode", "Gencode")
        @settings['endogenousLibraryOrder'].gsub!(",", " > ")
      end
      @settings.delete("indexBaseName") unless(@settings['useLibrary'] =~ /uploadNewLibrary/)
      @settings.delete("newSpikeInLibrary") unless(@settings['useLibrary'] =~ /uploadNewLibrary/)
      @settings.delete("existingLibraryName") unless(@settings['useLibrary'] =~ /useExistingLibrary/)
      @settings.delete("jobSpecificSharedScratch")
      @settings.delete("listOfJobIds")
      @settings.delete("autoDetectAdapter") unless(@settings['adapterSequence'] == "other")
      @settings.delete("manualAdapter") unless(@settings['adapterSequence'] == "other" and @settings['autoDetectAdapter'] == "no")
      @settings.delete("otherDataRepo") unless(@settings['anticipatedDataRepo'] == "Other")
      @settings.delete("piID")
      @settings.delete("platform")
      @settings.delete("processingPipeline")
      @settings.delete("processingPipelineIdAndVersion")
      @settings.delete("processingPipelineVersion")
      unless(@settings["randomBarcodesEnabled"])
        @settings.delete("randomBarcodeLength")
        @settings.delete("randomBarcodeLocation")
        @settings.delete("randomBarcodeStats")
      end
      @settings.delete("subjobDir")
      @settings.delete("toolVersionPPR")
      @settings["priorityList"].gsub!(",", " > ") if(@settings["priorityList"])
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
      @settings.delete("endogenousMismatch")
      @settings.delete("exogenousMapping")
      @settings.delete("exogenousMismatch")
      @settings.delete("genomeBuild")
      @settings.delete("manifestFile")
      @settings.delete("postProcDir")
      @settings.delete("subUserId")
      @settings.delete("uploadRawFiles")
      @settings.delete("remoteStorageArea") if(@settings["remoteStorageArea"] == nil)
      # Delete local path to post-processing input dir
      @settings.delete('postProcDir')
      @settings.delete('exogenousMappingInputDir')
      # Delete information about number of threads / tasks for exogenous mapping (used in exogenousSTARMapping wrapper)
      @settings.delete('numThreadsExo')
      @settings.delete('numTasksExo') 
      @settings.delete("toggleMultiSelectListButton")
      @settings.delete('numberField_fractionForMinBaseCallQuality')
      @settings.delete('numberField_minReadLength')
      @settings.delete('numberField_readRemainingAfterSoftClipping')
      @settings.delete('numberField_trimBases5p')
      @settings.delete('numberField_trimBases3p')
      @settings.delete('numberField_minAdapterBases3p')
      @settings.delete('numberField_downsampleRNAReads')
      @settings.delete('numberField_bowtieSeedLength')
      @settings.delete('minBaseCallQuality') if(@settings['exceRptGen'] == 'thirdGen') # We can delete minimum base-call quality if user submitted 3rd gen exceRpt job
      @settings.delete('exRNAAtlasURL')
      @settings.delete("uploadReadCountsDocs")
      @settings.delete('listOfExogenousTaxoTreeJobIds')
    end

    def customBuildSectionEmailSummary(section)
      sectionHash = {}
      countDisplay = 1
      ##Only display 10 input items as max
      section.each { |file|
        uriObj = URI.parse(file)
        scheme = uriObj.scheme
        if(scheme =~ /file/)
          type = scheme
          baseName = File.basename(uriObj.path)
        else
          type = @apiUriHelper.extractType(file)
          baseName = File.basename(@apiUriHelper.extractName(file))
        end
        sectionHash["#{countDisplay}. #{type.capitalize}"] = baseName
        # We want to display only 9 files and keep record if there are more than
        # 9,
        # which would be shown by "...."
        if(countDisplay == 9 and section.size > 9)
          sectionHash["99"] = "....."
          break
        end
        countDisplay += 1
      }
      return sectionHash
    end

  end
end; end ; end ; end

# If we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::ExogenousTaxoTreeWrapper)
end
