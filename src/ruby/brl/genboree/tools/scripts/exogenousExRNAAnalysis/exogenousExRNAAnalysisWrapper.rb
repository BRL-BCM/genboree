#!/usr/bin/env ruby
########################################################
############ exogenousExRNAAnalysis wrapper ############
# This wrapper performs different exogenous exRNA      #
# analysis related tasks.                              #
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
  class ExogenousExRNAAnalysisWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "4.6.2"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running 'exogenousExRNAAnalysis'. 
                        This tool performs different exogenous exRNA analysis related tasks.",
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
        # Make special directory inside of scratch dir that will store species-specific data
        `mkdir #{@scratchDir}/parseSpecies`
        # Grab group name and db name
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
        # Set up tool version variables used throughout this tool
        @toolVersion = @settings['toolVersion']
        # Set up settings
        @speciesDir = @toolConf.getSetting('settings', 'speciesDir')
        @doNotCapture = @toolConf.getSetting('settings', 'doNotCapture')
        @sampleID = @settings['sampleID']
        @localJob = @settings['localJob']
        @biosampleID = @settings['biosampleID']
        @experimentID = @settings['experimentID']
        # Resource path related variables for exRNA collections
        @exRNAHost = @settings['exRNAHost']
        @exRNAKbGroup = @settings['exRNAKbGroup']
        @exRNAKb = @settings['exRNAKb']
        @exRNABiosamplesColl = @settings['exRNABiosamplesColl']
        @exRNAExperimentsColl = @settings['exRNAExperimentsColl']
        @sniffer = BRL::Genboree::Helpers::Sniffer.new()
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
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "BEGIN individual run of exogenous exRNA Analysis (version #{@toolVersion})")
        # Set up API URI helper for processing inputs currently in email to user
        @apiUriHelper = BRL::Genboree::REST::Helpers::ApiUriHelper.new()
        # Grab input file and cut off file:// prefix so that we have the location on disk (in cluster shared scratch area)
        @inputFiles = []
        @inputFile = ""
        downloadFiles(@inputs, true)
        # If there is only one extracted file (as expected), then we're good to go and we save the path to that file in @inputFile
        if(@inputFiles.size == 1)
          @inputFile = @inputFiles[0]
        else
          if(@inputFiles.size == 0)
            @errUserMsg = "We were unable to find a valid .txt input containing your exogenous alignments.\nMore information can be found below if available."
          else
            @errUserMsg = "You submitted too many files for processing. This wrapper currently accepts ONE file as input (exogenous read alignments file)."
          end
        end
        # Raise an error if we came across one during our downloading / extracting of archive
        raise @errUserMsg unless(@errUserMsg.nil?)
        @inputFile.slice!("file://")
        # Grab relevant metadata from biosample doc associated with sample
        rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}"
        apiCaller = WrapperApiCaller.new(@exRNAHost, rsrcPath, @userId)
        apiCaller.get({:grp => @exRNAKbGroup, :kb => @exRNAKb, :coll => @exRNABiosamplesColl, :doc => @biosampleID})
        biosampleDoc = BRL::Genboree::KB::KbDoc.new(apiCaller.parseRespBody["data"])
        biofluidName = biosampleDoc.getPropVal("Biosample.Biological Sample Elements.Biological Fluid.Biofluid Name")
        exRNASource = biosampleDoc.getPropVal("Biosample.Molecular Sample Elements.exRNA Source")
        anatomicalLocation = biosampleDoc.getPropVal("Biosample.Biological Sample Elements.Anatomical Location")
        diseaseType = biosampleDoc.getPropVal("Biosample.Biological Sample Elements.Disease Type")
        apiCaller.get({:grp => @exRNAKbGroup, :kb => @exRNAKb, :coll => @exRNAExperimentsColl, :doc => @experimentID})
        experimentDoc = BRL::Genboree::KB::KbDoc.new(apiCaller.parseRespBody["data"])
        rnaIsolationKit = experimentDoc.getPropVal("Experiment.exRNA Sample Preparation Protocol.RNA Isolation Method.RNA Isolation Kit")
        # Parse input file for species
        begin
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "parseExogenousReadsForSpecies method to process sample #{@inputFile}")
          parseExogenousReadsForSpecies(@inputFile, @speciesDir, @doNotCapture, biofluidName, exRNASource, anatomicalLocation, diseaseType, rnaIsolationKit)
        rescue => err
          # If an error occurs, we'll mark the run as failed and set the error message accordingly
          @failedRun = true
          @errUserMsg = err.message.inspect
          @errBacktrace = err.backtrace.join("\n")
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error message: #{@errUserMsg}")
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Backtrace: #{@errBacktrace}")
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE exogenousExRNAAnalysis (version #{@toolVersion}). END.")
        # DONE exogenousExRNAAnalysis
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of Exogenous ExRNA Analysis (version #{@toolVersion}) failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to run Exogenous ExRNA Analysis (version #{@toolVersion})." if(@errInternalMsg.nil?)
        @exitCode = 30 if(@exitCode == 0)
      end
      return @exitCode
    end

###### *****************************
###### Methods used in this workflow
###### *****************************

    # Download input files from database. Perform initial extraction (of multi-file archives) if requested
    # @return [nil]
    def downloadFiles(inputs, extractFiles)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input files using threads #{inputs.inspect}")
      # If job is not local, then we need to download our inputs. Otherwise, our inputs will be the local file paths.
      unless(@localJob)
        uriPartition = @fileApiHelper.downloadFilesInThreads(inputs, @userId, @scratchDir)
        localPaths = uriPartition[:success].values
      else
        localPaths = inputs
      end
      if(extractFiles)
        # We will traverse all of the downloaded files, one at a time.
        localPaths.each { |tmpFile|
          checkForInputs(tmpFile, tmpFile, true)
        }
      end
      return
    end

    # Method that is used recursively to check what inputs each submitted file contains
    # @param [String] inputFile file name or folder name currently being checked
    # @param [boolean] continueExtraction boolean that determines whether we're going to extract the current file (only used for those files grabbed from Workbench)
    # @param [String] originalSource the original source file (archive, most likely) that the current file was originally part of. This info is used for error reporting.
    # @return [nil]
    def checkForInputs(inputFile, originalSource, continueExtraction=false)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current input file: #{inputFile}")
      # If we have an empty file (not inside of an archive!) then let's check that here.
      # We won't continue to check the file if it's empty at this stage.
      expError = false
      if(File.zero?(inputFile))
        @errInputs[:emptyFiles] << "#{File.basename(inputFile)}\n(with original source archive #{File.basename(originalSource)})"
      else
        # First, check to see if inputFile is a directory. If it's not, we'll just extract it.
        unless(File.directory?(inputFile))
          if(continueExtraction)
            exp = BRL::Util::Expander.new(inputFile)
            begin
              exp.extract()
            rescue => err
              expError = true
              @errInputs[:badArchives] << File.basename(inputFile)     
            end
            unless(expError)
              oldInputFile = inputFile.clone()
              inputFile = exp.uncompressedFileName
              # Delete old archive if there was indeed an archive (it's uncompressed now so we don't need to keep it around)
              `rm -f #{oldInputFile}` unless(exp.compressedFileName == oldInputFile)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uncompressed file name: #{inputFile}")
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
              checkForInputs("#{inputFile}/#{currentFile}", originalSource, false)
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
              @errInputs[:emptyFiles] << "#{File.basename(inputFile)}\n(with original source archive #{File.basename(originalSource)})"     
            else
              # Sniff file and see whether it's ASCII
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Sniffing file type of #{fixedInputFile}")
              @sniffer.filePath = fixedInputFile
              fileType = @sniffer.autoDetect()
              unless(fileType == "ascii")
                @errInputs[:badFormat] << "#{File.basename(inputFile)}\n(with original source archive #{File.basename(originalSource)})"
              else
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input file #{fixedInputFile} is in correct format (ASCII)")
                @inputFiles.push("file://#{fixedInputFile}")
              end
            end
          end
        end
      end
      return
    end

    # Parse exogenous reads for species (for a particular sample)
    # @param [String] inFile path to file name for input file
    # @param [String] outputDir path to output dir
    # @param [Array] doNotCapture array containing kingdoms that we're not going to store information about (Bacteria, Fungi, etc.)
    # @param [String] biofluidName name of biofluid
    # @param [String] exRNASource type of exRNA source
    # @param [String] anatomicalLocation name of anatomical location
    # @param [String] diseaseType name of disease type
    # @param [String] rnaIsolationKit name of RNA isolation kit
    # @return [nil]
    def parseExogenousReadsForSpecies(inFile, outputDir, doNotCapture, biofluidName, exRNASource, anatomicalLocation, diseaseType, rnaIsolationKit)
      # Open exogenous read alignments file and start parsing it
      inFileHandle = File.open(inFile, 'r')
      inFileHandle.each_line { |currentRead|
        # Move onto the next line if the kingdom is in the @doNotCapture group (examples: Bacteria, Fungi, etc.)
        kingdomName = currentRead.split("\t")[1]
        next if(doNotCapture.include?(kingdomName))
        speciesName = currentRead.split("\t")[2]
        # Add sample ID to the beginning of the line and add metadata fields to end of line
        currentRead = "#{@sampleID}\t#{currentRead.chomp!}\t#{biofluidName}\t#{exRNASource}\t#{anatomicalLocation}\t#{diseaseType}\t#{rnaIsolationKit}\n"
        # Make species-specific directory if it doesn't already exist 
        `mkdir -p #{@scratchDir}/parseSpecies/#{kingdomName}/#{speciesName}`
        # Write current line (read) to sample-specific file inside species-specific directory
        File.open("#{@scratchDir}/parseSpecies/#{kingdomName}/#{speciesName}/#{@sampleID}.txt", 'a') { |file| file.write(currentRead) }
      }
      inFileHandle.close()
      # Copy all file contents created above to the shared cluster area
      allKingdoms = Dir.entries("#{@scratchDir}/parseSpecies") ; nil
      allKingdoms.delete(".")
      allKingdoms.delete("..")
      allKingdoms.each { |currentKingdom|
        `rsync -a #{@scratchDir}/parseSpecies/#{currentKingdom} #{@speciesDir}`
      }
      return
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
      @settings.delete("indexBaseName")
      @settings.delete("newSpikeInLibrary")
      @settings.delete("existingLibraryName")
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
      @settings.delete('coreResultsArchive')
      @settings.delete('exogenousTaxoTreeJobIDDir')
      @settings.delete('filePathToListOfJobIds')
      @settings.delete('wbContext')
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
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::ExogenousExRNAAnalysisWrapper)
end
