#!/usr/bin/env ruby
#########################################################
################# RunExceRpt wrapper ####################
# This wrapper runs the actual makefile for the         #
# exceRpt data analysis pipeline                        #
# Modules used in this pipeline:                        #
# 1. exceRptPipeline                                    #
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
require 'brl/genboree/helpers/sniffer'
require 'parallel'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/tools/FTPtoolWrapper'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class RunExceRptWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "4.6.2"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running 'runExceRpt'. This tool actually runs the exceRpt makefile.
                        This tool is intended to be called via the exceRptPipeline wrapper (batch-processing)",
      :authors      => [ "Sai Lakshmi Subramanian (sailakss@bcm.edu) and William Thistlethwaite (thistlew@bcm.edu)" ],
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
        # @dataDir will store the .fastq file associated with this run
        @dataDir = "#{@scratchDir}/data"
        `mkdir #{@dataDir}`
        # Grab group name and db name
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
        # Set up tool version variables used throughout this tool
        @exceRptGen = @settings['exceRptGen']
        @toolVersion = @settings['toolVersion']
        # Set up sniffer
        @sniffer = BRL::Genboree::Helpers::Sniffer.new()
        # Set up format options coming from the UI
        @analysisName = @settings['analysisName']
        @numThreads = @settings['numThreads']
        @javaRam = @settings['javaRam']
        @genomeBuild = @settings['genomeBuild']
        @genomeVersion = @settings['genomeVersion']
        @calib = @settings['calib']
        @exogenousMapping = @settings['exogenousMapping']
        if(@settings['exogenousmiRNAWithAllReads'] and @exogenousMapping == "miRNA")
          @exogenousMapping = "miRNAAllReads"
        end
        @endogenousLibraryOrder = @settings['endogenousLibraryOrder']
        @adSeqParameter = @settings['adSeqParameter']
        @randomBarcodeLength = @settings['randomBarcodeLength']
        @randomBarcodeLocation = @settings['randomBarcodeLocation']
        @randomBarcodeStats = @settings['randomBarcodeStats']
        @endogenousMismatch = @settings['endogenousMismatch']
        @exogenousMismatch = @settings['exogenousMismatch']
        @bowtieSeedLength = @settings['bowtieSeedLength']
        @minReadLength = @settings['minReadLength']
        @minBaseCallQuality = @settings['minBaseCallQuality']
        @fractionForMinBaseCallQuality = @settings['fractionForMinBaseCallQuality']
        @readRemainingAfterSoftClipping = @settings['readRemainingAfterSoftClipping']
        @trimBases3p = @settings['trimBases3p']
        @trimBases5p = @settings['trimBases5p']
        @minAdapterBases3p = @settings['minAdapterBases3p']
        @downsampleRNAReads = @settings['downsampleRNAReads']
        @localExecution = @settings['localExecution']
        @postProcDir = @settings['postProcDir']
        @isFTPJob = @settings['isFTPJob']
        if(@isFTPJob)
          @md5sum = ""
          @fileType = ""
          @ftpDbrcKey = @genbConf.ftpDbrcKey
          ii = @ftpDbrcKey.index(":")
          ftpHost = @ftpDbrcKey[ii+1..-1]
          ftpKey = @ftpDbrcKey[0...ii].downcase.to_sym
          dbrc = BRL::DB::DBRC.new(@dbrcFile)
          dbrcRec = dbrc.getRecordByHost(ftpHost, ftpKey)
          # Attempt to create @ftpHelper object (using LFTP helper)
          noOfAttempts = 6
          attempt = 1
          while(@ftpHelper.nil? and attempt <= noOfAttempts)
            begin
              @ftpHelper = BRL::Genboree::Pipeline::FTP::Helpers::Lftp.new(dbrcRec[:host], dbrcRec[:user], dbrcRec[:password])
            rescue => err
              $stderr.debugPuts(__FILE__, __method__, "FTP", "Error encountered while opening @ftpHelper on attempt=#{attempt}")
              $stderr.debugPuts(__FILE__, __method__, "FTP", "err.message=#{err.message.inspect}")
              $stderr.debugPuts(__FILE__, __method__, "FTP", "err.backtrace:\n#{err.backtrace.join("\n")}")
              if(attempt == noOfAttempts)
                raise err
              else
                sleepTime = 2 ** (attempt - 1) * 60
                $stderr.debugPuts(__FILE__, __method__, "FTP", "sleeping for #{sleepTime} seconds") unless(sleepTime == 0)
                sleep(sleepTime)
                attempt += 1
              end
            end
          end
        end
        @exogenousMappingInputDir = @settings['exogenousMappingInputDir']
        @isRemoteStorage = true if(@settings['remoteStorageArea'])
        if(@isRemoteStorage)
          @remoteStorageArea = @settings['remoteStorageArea']
        end
        @finishedFtpDir = @settings['finishedFtpDir']
        @subUserId = @settings['subUserId']
        @subUserId = @userId unless(@subUserId)
        @totalOutputFileSize = @settings['totalOutputFileSize']
        @uploadFullResults = @settings['uploadFullResults']
        @useMoreMemory = @settings['useMoreMemory']
        @exoJobId = @settings['exoJobId']
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
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "BEGIN individual run of exceRpt small RNA-seq Pipeline (version #{@toolVersion})")
        # Set up API URI helper for processing inputs currently in email to user
        @apiUriHelper = BRL::Genboree::REST::Helpers::ApiUriHelper.new()
        # Grab location of makefile
        @smRNAMakefile = ENV['SMALLRNA_MAKEFILE']
        # Grab input file and cut off file:// prefix so that we have the location on disk (in cluster shared scratch area)
        inputFile = @inputs[0].clone
        inputFile.slice!("file://")
        @originalInputFile = inputFile.clone()
        # Move file to local scratch area
        `mv #{Shellwords.escape(inputFile)} #{@scratchDir}/#{File.basename(inputFile)}`
        inputFile = "#{@scratchDir}/#{File.basename(inputFile)}"
        # Write the current runExceRpt job ID to file in importantJobIdsDir
        @importantJobIdsDir = @settings['importantJobIdsDir']
        newRunExceRptEntry = {@jobId => File.basename(inputFile)}
        File.open("#{@importantJobIdsDir}/#{@jobId}.txt", 'w') { |file| file.write(JSON.pretty_generate(newRunExceRptEntry)) }
        # @sampleFile will hold the file path to the actual FASTQ / SRA file (once it's been decompressed and converted to UNIX format)
        @sampleFile = ""
        # @errInputs will contain info about any potential errors that might occur 
        @errInputs = {:emptyFiles => [], :badFormat => [], :badArchives => []}
        # Unpack inputFile (if necessary) and convert to unix format
        @inputs = [] # Clear out @inputs - we will populate it with the uncompressed inputs
        preprocessInput(inputFile)
        # @failedRun keeps track of whether the sample was successfully processed
        @failedRun = false
        # @redoThisSample keeps track of whether we want to re-run the sample with more memory
        @redoThisSample = false
        # Run sample through exceRpt pipeline
        begin
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "runExceRpt method to process sample #{@sampleFile}")
          runExceRpt(@sampleFile)
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
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE runExceRpt (version #{@toolVersion}). END.")
        # DONE runExceRpt
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of exceRpt Pipeline (version #{@toolVersion}) failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to run exceRpt Pipeline (version #{@toolVersion})." if(@errInternalMsg.nil?)
        @exitCode = 30 if(@exitCode == 0)
      end
      return @exitCode
    end

###### *****************************
###### Methods used in this workflow
###### *****************************

    # Preprocess our input file - extract file if archive and sniff file to make sure it's FASTQ or SRA
    # @param [String] inputFile path to input file
    # @return [nil]
    def preprocessInput(inputFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Preprocessing input file #{inputFile}")
      # @filePaths will store the collection of file paths gathered from (potential) archive. If there is more than one path, then we raise error, since
      # our input should either be a FASTQ/SRA file or an archive containing a single FASTQ/SRA file!
      @filePaths = []
      # Check our single input file - decompress, check for FASTQ/SRA, convert to UNIX
      checkForInputs(inputFile)
      # If we find no valid files associated with our inputFile, then we definitely want to raise an error
      if(@filePaths.size == 0)
        @errUserMsg = "Your job failed because we were unable to find any valid inputs (FASTQ / SRA).\nPlease make sure that the FASTQ/SRA or archive associated with this job\nis valid and resubmit. More details may be printed below."
      # If we find one valid file, then we're good to go, and we set that path to be @sampleFile
      elsif(@filePaths.size == 1)
        @sampleFile = @filePaths[0]
      # If we find more than one valid file, then the user didn't follow the new requirements that each archive (INSIDE of a given archive on Genboree) contain only a single valid input
      else
        @errUserMsg = "Your job failed because your archive for this job contained more than one file.\nYou may submit more than one sample in a given archive from the Workbench,\nbut any archives inside of that archive should only contain a single sample.\nIf you are submitting via FTP, all individual archives\ninside of your data archive should contain only one sample.\nPlease follow this requirement and resubmit your files.\nMore details may be printed below."
      end
      raise @errUserMsg unless(@errUserMsg.nil? or @errUserMsg.empty?)
      return
    end

    # Method that is used recursively to check what inputs each submitted file contains
    # @param [String] inputFile file name or folder name currently being checked
    # @return [nil]
    def checkForInputs(inputFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current input file: #{inputFile}")
      # If we have an empty file (not inside of an archive!) then let's check that here.
      # We won't continue to check the file if it's empty at this stage.
      expError = false
      if(File.zero?(inputFile))
        @errInputs[inputFile] = "Input file #{File.basename(inputFile)} is empty.\nPlease upload a non-empty file and try again."
      else
        # First, check to see if inputFile is a directory. If it's not, we'll just extract it.
        unless(File.directory?(inputFile))
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
            `rm -f #{oldInputFile}` unless(exp.compressedFileName == exp.uncompressedFileName)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uncompressed file name: #{inputFile}")
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
              checkForInputs("#{inputFile}/#{currentFile}")
            }
          else
            # OK, so we have a file. First, let's make the file name safe 
            fixedInputFile = File.basename(inputFile).makeSafeStr(:ultra)
            # Get full path of input file and replace last part of that path (base name) with fixed file name
            inputFileArr = inputFile.split("/")
            inputFileArr[-1] = fixedInputFile
            fixedInputFile = inputFileArr.join("/")
            # Rename file so that it has fixed file name
            `mv #{Shellwords.escape(inputFile)} #{Shellwords.escape(fixedInputFile)}`
            # Move the file to the data dir
            `mv #{Shellwords.escape(fixedInputFile)} #{@dataDir}/#{File.basename(fixedInputFile)}`
            fixedInputFile = "#{@dataDir}/#{File.basename(fixedInputFile)}"
            # Check to see if file is empty. We have to do this again because it might have been inside of a (non-empty) archive earlier!
            if(File.zero?(fixedInputFile))
              @errInputs[:emptyFiles] << File.basename(inputFile)
            else
              # Sniff file and see whether it's FASTQ or SRA
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Sniffing file type of #{fixedInputFile}")
              @sniffer.filePath = fixedInputFile
              fileType = @sniffer.autoDetect()
              unless(fileType == "fastq" or fileType == "sra")
                @errInputs[:badFormat] << File.basename(inputFile)
              else
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input file #{fixedInputFile} is in correct format, FASTQ or SRA")
                # Compute md5 for FASTQ / SRA file
                if(@isFTPJob)
                  @md5sum = Digest::MD5.file(fixedInputFile).hexdigest
                  if(fileType == "fastq")
                    @fileType = "FASTQ"
                  elsif(fileType == "sra")
                    @fileType = "SRA"
                  end
                end
                # Convert to unix format
                convObj = BRL::Util::ConvertText.new(fixedInputFile, true)
                convObj.convertText()
                # Count number of lines in the input file
                numLines = `wc -l #{fixedInputFile}`
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of lines in file #{fixedInputFile}: #{numLines}")
                @filePaths.push(fixedInputFile)
                @inputs << "file://#{fixedInputFile}"
                # Temporary - save mapping from unextracted archive to extracted FASTQ / SRA file (for use when we re-run files due to memory issues)
                if(@isFTPJob and !@useMoreMemory)
                  @unextractedToExtractedMapping = {}
                  @unextractedToExtractedMapping[@originalInputFile] = File.basename(fixedInputFile)
                end
              end
            end
          end
        end
      end
      return
    end

    # Run exceRpt pipeline on a particular sample
    # @param [String] inFile path to file name for input file 
    # @return [nil]
    def runExceRpt(inFile)
      # Create sample name and save it under @sampleName 
      sampleName = File.basename(inFile)
      sampleName.gsub!(/[\.|\s]+/, '_')
      @sampleName = "sample_#{sampleName}"
      # Write hash to file
      File.open("#{@settings['jobSpecificSharedScratch']}/samples/unextractedToExtractedMappings/#{@sampleName}.txt", 'w') { |file| file.write(JSON.pretty_generate(@unextractedToExtractedMapping)) } if(@isFTPJob and !@useMoreMemory)
      # Variables used for .out / .err files for exceRpt pipeline run
      outFile = "#{@scratchDir}/#{@sampleName}.out"
      errFile = "#{@scratchDir}/#{@sampleName}.err"
      # Run make command to run exceRpt pipeline
      if(@downsampleRNAReads)
        downsampleStr = " DOWNSAMPLE_RNA_READS=#{@downsampleRNAReads}"
      else
        downsampleStr = ""
      end
      if(@exceRptGen == "fourthGen")
        # If our reference genome is hg19 and there exists a directory for local indices (on the node), then we will use those local indices versus the shared indices (to reduce competition and make exceRpt run faster)
        if(@genomeVersion == "hg19" and File.directory?(ENV['EXCERPT_DATABASE_LOCAL']))
          ENV['EXCERPT_DATABASE'] = ENV['EXCERPT_DATABASE_LOCAL']
        end
        command = "make -f #{@smRNAMakefile} INPUT_FILE_PATH=#{inFile} EXCERPT_VERSION=#{@toolVersion} N_THREADS=#{@numThreads} JAVA_RAM=#{@javaRam} MAIN_ORGANISM=#{@genomeBuild} MAIN_ORGANISM_GENOME_ID=#{@genomeVersion} CALIBRATOR_LIBRARY=#{@calib} INPUT_FILE_ID=#{@sampleName} OUTPUT_DIR=#{@scratchDir} MAP_EXOGENOUS=#{@exogenousMapping} ENDOGENOUS_LIB_PRIORITY=#{@endogenousLibraryOrder} TRIM_N_BASES_3p=#{@trimBases3p} TRIM_N_BASES_5p=#{@trimBases5p} MIN_ADAPTER_BASES_3p=#{@minAdapterBases3p} ADAPTER_SEQ=#{@adSeqParameter} RANDOM_BARCODE_LENGTH=#{@randomBarcodeLength} RANDOM_BARCODE_LOCATION=\"#{@randomBarcodeLocation}\" KEEP_RANDOM_BARCODE_STATS=#{@randomBarcodeStats} STAR_outFilterMismatchNmax=#{@endogenousMismatch} MAX_MISMATCHES_EXOGENOUS=#{@exogenousMismatch} MIN_READ_LENGTH=#{@minReadLength} QFILTER_MIN_QUAL=#{@minBaseCallQuality} QFILTER_MIN_READ_FRAC=#{@fractionForMinBaseCallQuality} STAR_outFilterMatchNminOverLread=#{@readRemainingAfterSoftClipping}#{downsampleStr} LOCAL_EXECUTION=#{@localExecution} >> #{outFile} 2>> #{errFile}"
      else
        command = "make -f #{@smRNAMakefile} INPUT_FILE_PATH=#{inFile} EXCERPT_VERSION=#{@toolVersion} N_THREADS=#{@numThreads} JAVA_RAM=#{@javaRam} MAIN_ORGANISM=#{@genomeBuild} MAIN_ORGANISM_GENOME_ID=#{@genomeVersion} CALIBRATOR_LIBRARY=#{@calib} INPUT_FILE_ID=#{@sampleName} OUTPUT_DIR=#{@scratchDir} MAP_EXOGENOUS=#{@exogenousMapping} ENDOGENOUS_LIB_PRIORITY=#{@endogenousLibraryOrder} ADAPTER_SEQ=#{@adSeqParameter} RANDOM_BARCODE_LENGTH=#{@randomBarcodeLength} RANDOM_BARCODE_LOCATION=\"#{@randomBarcodeLocation}\" KEEP_RANDOM_BARCODE_STATS=#{@randomBarcodeStats} BOWTIE1_MAX_MISMATCHES=#{@endogenousMismatch} BOWTIE2_MAX_MISMATCHES=#{@exogenousMismatch} BOWTIE_SEED_LENGTH=#{@bowtieSeedLength} LOCAL_EXECUTION=#{@localExecution} >> #{outFile} 2>> #{errFile}"
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "exceRpt Pipeline command completed for #{inFile} (exit code: #{statusObj.exitstatus})")
      # Check whether there was an error with the exceRpt pipeline run
      foundError = findError(exitStatus, inFile, outFile, errFile)
      if(foundError == "redo" and !@useMoreMemory)
        # If we're uploading full results, we need to keep track of the expected output file size for this sample.
        # We'll save that info in the file name and then delete it when we re-submit.
        if(@uploadFullResults and !@isFTPJob)
          inFileWithOutputSize = "#{File.dirname(inFile)}/#{@totalOutputFileSize}_#{File.basename(inFile)}"
          `mv #{inFile} #{inFileWithOutputSize}`
          inFile = inFileWithOutputSize
        end
        # We'll move the input file to a shared area on the cluster so that we can access it in our PPR or exogenousSTARMapping job
        unless(@settings['fullExogenousMapping'])
          `mv #{inFile} #{@postProcDir}/runs/#{File.basename(inFile)}`
        else
          `mkdir -p #{@exogenousMappingInputDir}/#{@exoJobId}`
          `mv #{inFile} #{@exogenousMappingInputDir}/#{@exoJobId}/#{File.basename(inFile)}`
        end
      else
        # Compress output (partial results if error occurred in run, full results otherwise)
        compressOutputs(inFile, foundError, outFile, errFile)
        # Transfer files for this sample to the user db
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Transferring compressed outputs of this sample #{inFile} to the server")
        transferFilesForSample(inFile)
      end
      return
    end
    
    # Compress output files to be transferred to user db
    # @param [String] inFile path to file name for input file
    # @param [boolean] foundError boolean that tells us whether an error occurred in the current run 
    # @param [String] outFile path to file where standard output is stored from run
    # @param [String] errFile path to file where error output is stored from run
    # @return [nil]
    def compressOutputs(inFile, foundError, outFile, errFile)
      # Pipeline will create stats file with name :sampleName.stats
      statsFile = "#{@sampleName}.stats"
      # Set resultsZip depending on whether an error occurred (partial) or didn't
      resultsZip = ""
      # Set coreZip depending on whether an error occured (nil) or didn't 
      coreZip = "" 
      unless(foundError)
        resultsZip = "#{@sampleName}_#{CGI.escape(@analysisName)}_results_v#{@toolVersion}.zip"
        coreZip = "#{@sampleName}_CORE_RESULTS_v#{@toolVersion}.tgz"
        # Check if core results tgz file is available - if it's not, we'll compress our own core results tgz
        # We'll mark it as PARTIAL since it SHOULD have been created by the pipeline but wasn't - this likely indicates that something went wrong.
        unless(File.exist?("#{@scratchDir}/#{coreZip}"))
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Core Results zip archive #{coreZip} is not found, so making it now.")
          # Update name of CORE_RESULTS archive to include analysis name, and add PARTIAL to the name.
          # Since the pipeline didn't create this file, it's likely that something went wrong and that the CORE_RESULTS archive is incomplete.
          coreZip = "#{@sampleName}_#{CGI.escape(@analysisName)}_PARTIAL_CORE_RESULTS_v#{@toolVersion}.tgz"
          command = "cd #{@scratchDir}/#{@sampleName}/; tar -cvz #{@scratchDir}\/#{coreZip} #{@scratchDir}\/#{statsFile} #{@scratchDir}\/*.log readCounts_* *.readLengths.txt *_fastqc.zip *.counts *.adapterSeq *.qualityEncoding >> #{outFile} 2>> #{errFile}"
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching tar command to compress all key result files: #{command}")
          exitStatus = system(command)
          unless(exitStatus)
            @errUserMsg = "Could not create the zip archive of key result files."
            raise "Command: #{command} died. Check #{errFile} for more information."
          end
          unless(@failedRun)
            @errUserMsg = "The CORE_RESULTS archive generated by the run was not created properly, which indicates that the run had an issue." if(@errUserMsg.nil? or @errUserMsg.empty?)
            @failedRun = true
          end
        else
          # Add analysis name to CORE_RESULTS archive
          newCoreZip = "#{@sampleName}_#{CGI.escape(@analysisName)}_CORE_RESULTS_v#{@toolVersion}.tgz"
          `mv #{@scratchDir}/#{coreZip} #{@scratchDir}/#{newCoreZip}`
          coreZip = newCoreZip
        end
      else
        resultsZip = "#{@sampleName}_#{CGI.escape(@analysisName)}_partial_results_v#{@toolVersion}.zip" 
        coreZip = nil
      end
      # Compress results zip
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Compressing outputs to create #{resultsZip}")
      command = "cd #{@scratchDir}; zip -r #{resultsZip} #{@sampleName}.log #{statsFile} #{@sampleName}/* >> #{outFile} 2>> #{errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching zip command to compress results file: #{command}")
      exitStatus = system(command)
      # Raise error if exit status lets us know that an error occurred
      unless(exitStatus)
        @errUserMsg = "Could not create the zip archive of results."
        raise "Command: #{command} died. Check #{errFile} for more information."
      end
      # If we successfully created results archive, then we're good to go. Otherwise, we raise an error
      if(File.exist?("#{@scratchDir}/#{resultsZip}"))
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE Compressing outputs to create #{resultsZip}")
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Results zip archive #{resultsZip} is not found.")
        @errUserMsg = "The results zip archive #{resultsZip} was not found."
        raise @errUserMsg
      end
      # Save results zip / core zip / stats file in instance variables to make uploading them easier
      @resultsZip = resultsZip
      @coreZip = coreZip
      @statsFile = statsFile
      # If @exogenousMappingInputDir exists (meaning fullExogenousMapping=true), then we need to copy the unaligned.fq.gz file in our results to the cluster shared scratch area so that exogenousSTARMapping
      # can access it for the exogenous genome alignment
      if(@exogenousMappingInputDir and File.exist?("#{@scratchDir}/#{@sampleName}/EXOGENOUS_rRNA/unaligned.fq.gz") and !foundError and !@failedRun)
        `mkdir -p #{@exogenousMappingInputDir}/#{@exoJobId}/#{@sampleName}/EXOGENOUS_rRNA`
        `cp #{@scratchDir}/#{@sampleName}/EXOGENOUS_rRNA/unaligned.fq.gz #{@exogenousMappingInputDir}/#{@exoJobId}/#{@sampleName}/EXOGENOUS_rRNA/unaligned.fq.gz` 
        # We also copy the .stats file to the exogenous mapping dir since we'll add info from the exogenous mapping to the end of it
        `cp #{@scratchDir}/#{@statsFile} #{@exogenousMappingInputDir}/#{@exoJobId}/#{@sampleName}/#{@statsFile}`
        # Let's also copy the CORE_RESULTS archive to the exogenous mapping dir since we want to replace the .stats file in it and add our exogenous summary file
        `cp #{@scratchDir}/#{@coreZip} #{@exogenousMappingInputDir}/#{@exoJobId}/#{@sampleName}/#{@coreZip}` 
      end
      # Compress raw fastq file and upload it to FTP backup area (if we're running an FTP job) - we do this even if the sample failed processing
      if(@isFTPJob)
        command = "cd #{File.dirname(inFile)} ; gzip #{File.basename(inFile)}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching gzip command to compress original input file for backup: #{command}")
        exitStatus = system(command)
        # Raise error if exit status lets us know that an error occurred
        unless(exitStatus)
          @errUserMsg = "Could not create the gzip archive of original FASTQ to upload to FTP backup area."
          raise @errUserMsg
        end
        @compressedInput = "#{inFile}.gz"
        transferFtpFile(@compressedInput, "#{@settings['backupFtpDir']}data", false)
      end
      # If this runExceRpt job is part of an FTPexceRptPipeline job, then we'll need to copy the CORE_RESULTS archive and .stats file over to the cluster shared area
      # The erccFinalProcessing wrapper will use both of them in filling out the contents of metadata documents
      # Also, the erccFinalProcessing wrapper needs the contents of @inputFileHash to associate the current sample with its various related files
      # We'll write it to disk and then read that hash from disk in erccFinalProcessing
      if(@isFTPJob and !foundError and !@failedRun)
        sharedStatsFile = "#{@settings['jobSpecificSharedScratch']}/samples/#{@sampleName}/#{@statsFile}"
        sharedCoreZip = "#{@settings['jobSpecificSharedScratch']}/samples/#{@sampleName}/#{@coreZip}"
        if(@settings['fullExogenousMapping'])
          exoGenomicArchive = "#{@sampleName}_#{CGI.escape(@analysisName)}_ExogenousGenomicAlignments.tgz" if(@uploadFullResults)
          exoGenomicTaxoTree = "ExogenousGenomicAlignments.result.taxaAnnotated.txt"
        end
        if(@exogenousMapping == "miRNA" or @settings['fullExogenousMapping'])
          exoRibosomalTaxoTree = "ExogenousRibosomalAlignments.result.taxaAnnotated.txt"
        end
        `mkdir -p #{@settings['jobSpecificSharedScratch']}/samples/#{@sampleName}`
        `cp #{@scratchDir}/#{@statsFile} #{sharedStatsFile}`
        `cp #{@scratchDir}/#{@coreZip} #{sharedCoreZip}`
        @inputFileHash = {@originalInputFile => {:sampleName => @sampleName, :statsFile => sharedStatsFile, :coreZip => sharedCoreZip, :resultsZip => resultsZip, :md5 => @md5sum, :fileType => @fileType}}
        @inputFileHash[@originalInputFile][:rawInput] = File.basename(inFile)
        if(@settings['fullExogenousMapping'])
          @inputFileHash[@originalInputFile][:exoGenomicArchive] = exoGenomicArchive if(@uploadFullResults)
          @inputFileHash[@originalInputFile][:exoGenomicTaxoTree] = exoGenomicTaxoTree
        end
        if(@exogenousMapping == "miRNA" or @settings['fullExogenousMapping'])
          @inputFileHash[@originalInputFile][:exoRibosomalTaxoTree] = exoRibosomalTaxoTree
        end
        File.open("#{@settings['jobSpecificSharedScratch']}/samples/#{@sampleName}.txt", 'w') { |file| file.write(JSON.pretty_generate(@inputFileHash)) }
      end
      # Delete uncompressed results (don't need them anymore)
      `rm -rf #{@scratchDir}/#{@sampleName}`
      return
    end
          
    # Transfer output files to the user database for a particular sample
    # @param [String] inputFile path to input file
    # @return [nil]    
    def transferFilesForSample(inputFile)
      # Parse target URI for outputs
      targetUri = URI.parse(@outputs[0])
      # Specify full resource path
      unless(@remoteStorageArea)
        rsrcPath = "#{targetUri.path}/file/exceRptPipeline_v#{@toolVersion}/{analysisName}/#{CGI.escape(@sampleName)}/{outputFile}/data?" 
      else
        rsrcPath = "#{targetUri.path}/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@toolVersion}/{analysisName}/#{CGI.escape(@sampleName)}/{outputFile}/data?" 
      end
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      # statsFile
      # :outputFile => each run's statsFile
      # input is the run's "#{@scratchDir}/#{@statsFile}"
      # We check to make sure that .stats file is valid by checking the total number of lines present in the file.
      # If the number of lines matches the expected number, then the .stats file is probably valid and we upload it.
      # If lines are missing, then the .stats file is incomplete and the run failed somehow, EVEN IF IT WASN'T DETECTED BY OUR findError() METHOD!!
      statsFile = File.read("#{@scratchDir}/#{@statsFile}")
      totalLines = statsFile.split("\n").size()
      validStats = true if((@exogenousMapping == "off" and totalLines == 25) or ((@exogenousMapping == "miRNA" or @exogenousMapping == "miRNAAllReads") and totalLines == 31) or (@exogenousMapping == "on" and totalLines == 33))
      if(validStats)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Trying to upload stats file #{@scratchDir}/#{@statsFile}")
        uploadFile(targetUri.host, rsrcPath, @subUserId, "#{@scratchDir}/#{@statsFile}", {:analysisName => @analysisName, :outputFile => @statsFile})
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Skipping upload of stats file #{@scratchDir}/#{@statsFile}, since it is incomplete.")
        unless(@failedRun)
          @errUserMsg = "The .stats file generated by the run was incomplete, which indicates that the run had an issue.\nIt is likely that your FASTQ file is corrupt.\nPlease send contents of .stats file to Genboree admins (emails below)." if(@errUserMsg.nil? or @errUserMsg.empty?)
          @failedRun = true
        end
      end
      # resultsZip
      # :outputFile => each run's resultsZip
      # input is each run's "#{@scratchDir}/#{@resultsZip}"
      if(@uploadFullResults)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Trying to upload results zip #{@scratchDir}/#{@resultsZip}")        
        uploadFile(targetUri.host, rsrcPath, @subUserId, "#{@scratchDir}/#{@resultsZip}", {:analysisName => @analysisName, :outputFile => @resultsZip})
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Not uploading full results zip #{@scratchDir}/#{@resultsZip} because user didn't choose the uploadFullResults option!")             
      end
      # coreZip
      # :outputFile => each run's coreZip
      # input is each run's "#{@scratchDir}/#{coreZip}"
      if(!@coreZip.nil? and !@coreZip.empty? and File.exist?("#{@scratchDir}/#{@coreZip}"))
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Trying to upload CORE RESULTS zip #{@scratchDir}/#{@coreZip}")
        ## Use extract = true to unpack all core result files in the CORE RESULTS folder
        newRsrcPath = rsrcPath.clone()
        newRsrcPath << "extract=true&suppressEmail=true"
        uploadFile(targetUri.host, newRsrcPath, @subUserId, "#{@scratchDir}/#{@coreZip}", {:analysisName => @analysisName, :outputFile => "CORE_RESULTS/#{@coreZip}"})
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "CORE RESULTS zip file #{@coreZip} does not exist. Skipping.")
        unless(@failedRun)
          @errUserMsg = "The CORE_RESULTS archive associated with the run could not be found, which indicates that the run had an issue." if(@errUserMsg.nil? or @errUserMsg.empty?)
          @failedRun = true
        end
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE transferring outputs of #{@sampleName} to the user database in server")
      # Remove uncompressed input file and results zip (we don't need them anymore)
      `rm -f #{inputFile}`
      `rm -f #{@scratchDir}/#{@resultsZip}`
      if(@coreZip)
        # Copy core .tgz to post-processing runs directory (if core .tgz exists)
        `cp #{@scratchDir}/#{@coreZip} #{@postProcDir}/runs/#{@coreZip}` unless(@failedRun)
        # If it's an FTP job, then we can't use extract=true to extract the CORE zip on Genboree.
        # We'll just extract it on disk and then upload the files.
        if(@remoteStorageArea)
          # Decompress CORE .tgz (used to grab QC information as well as fill out Result Files doc below)
          exp = BRL::Genboree::Helpers::Expander.new(@coreZip)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracting CORE .tgz #{@coreZip}")
          exp.extract()
          coreZipDir = exp.tmpDir
          `cp -r #{coreZipDir} #{@scratchDir}/CORE_FILES`
          coreZipDir = "#{@scratchDir}/CORE_FILES"
          # Call recursive method to fill out result files for CORE_RESULTS
          currentRsrcPath = "#{targetUri.path}/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@toolVersion}/{analysisName}/#{CGI.escape(@sampleName)}/CORE_RESULTS" 
          uploadCoreFiles(targetUri.host, coreZipDir, currentRsrcPath)
        end
      end
      # If @isFTPJob and @uploadFullResults are true, then we need to upload the original FASTQ to Genboree
      if(@isFTPJob and @uploadFullResults and @compressedInput and File.exist?(@compressedInput))
        uploadFile(targetUri.host, rsrcPath, @subUserId, @compressedInput, {:analysisName => @analysisName, :outputFile => "rawInput/#{File.basename(@compressedInput)}"})
        `rm -rf #{@compressedInput}`
      end
      # After we're done uploading 
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

    # Uploads all CORE results for a given sample (used for FTP-based submissions, as extract=true is not working currently for virtual FTP)
    # @param [String] currentHost host where we're uploading files
    # @param [String] currentPath path to current directory being examined for CORE files
    # @param [String] currentRsrcPath resource path used with uploadFile method to upload files
    # @return [nil]
    def uploadCoreFiles(currentHost, currentPath, currentRsrcPath)
      # If current path is a directory, we'll traverse all files in that directory and submit those recursively to this method
      if(File.directory?(currentPath))
        allFiles = Dir.entries(currentPath)
        allFiles.delete(".")
        allFiles.delete("..")
        allFiles.each { |currentFile|
          newPath = "#{currentPath}/#{currentFile}"
          newRsrcPath = "#{currentRsrcPath}/#{CGI.escape(currentFile)}"
          uploadCoreFiles(currentHost, newPath, newRsrcPath)
        }
      # If current path is a file, we'll upload it to Genboree
      else
        currentRsrcPath << "/data?"
        currentRsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
        uploadFile(currentHost, currentRsrcPath, @subUserId, currentPath, {:analysisName => @analysisName})
      end
      return
    end

    # Try hard to detect errors
    # - exceRpt Pipeline can exit with 0 status even when it clearly failed.
    # - So we need to aggressively go looking for any errors.
    # @param [boolean] exitStatus indicating if the system() call "succeeded" or not.
    #   system() returns boolean, but if true can't be trusted for smallRNA-seq Pipeline.
    # @param [String] inFile path to file name for input file
    # @param [String] outFile path to file where standard output is stored from run
    # @param [String] errFile path to file where error output is stored from run
    # @return [boolean] indicating if a smallRNA-seq Pipeline error was found or not.
    #   if so, @errUserMsg, @errInternalMsg, @exitCode will be set appropriately
    def findError(exitStatus, inFile, outFile, errFile)
      retVal = false
      errorMessages = nil
      # Check for truncated file error - this means we need to relaunch this job with more memory.
      cmd = "grep -e \"\\[bam_sort_core\\] truncated file. Aborting.\" -e \"^make:\\s\\\*\\\*\\\*\\s\\[.*ExogenousRibosomalAlignments\" #{errFile}"
      errorMessages = `#{cmd}`
      if(!errorMessages.strip.empty? and !@useMoreMemory)
        retVal = "redo"
        errorMessages << "\nBecause this error normally stems from a lack of memory,\nwe are going to reprocess this sample with more memory.\nYou will receive another email when we re-process\nthis sample, letting you know whether the reprocessing was successful."
      else
        ## Capture the make rule where failure occurred
        cmd = "grep -e \"^make:\\s\\\*\\\*\\\*\\s\" -e \"bowtie\" -e \"fastx_clipper\" #{errFile}"
        errorMessages = `#{cmd}`
        if(errorMessages =~ /Failed to read complete record/)
          errorMessages << "ERROR: Your input FASTQ file is incomplete. \nPlease correct your input file and try running the pipeline again.\n"
        end  
        if(errorMessages =~ /^make:\s\*\*\*\s\[(.*)\].*/)
          missingFile = $1
          errorMessages << "\nexceRpt small RNA-seq Pipeline could not find the file #{File.basename(missingFile)}. \nThe pipeline did not proceed further."
          if(missingFile =~ /PlantAndVirus\/mature_sense_nonRed\.grouped/)
            errorMessages << "\nPOSSIBLE REASON: There were no reads to map against plants and virus miRNAs. \nYou can uncheck \"miRNAs in Plants and Viruses\" option under \"small RNA Libraries\" section in the Tool Settings and rerun the pipeline."
          elsif(missingFile =~ /readsNotAssigned\.fa/)
            errorMessages << "\nPOSSIBLE REASON: None of the reads in your sample mapped to the main genome of interest."
          elsif(missingFile =~ /\.clipped\.fastq\.gz/)
            errorMessages << "\nPOSSIBLE REASON: Clipping of 3\' adapter sequence failed. Check your input FASTQ file to ensure the file is complete and correct."
          elsif(missingFile =~ /\.clipped\.noRiboRNA\.fastq\.gz/)
            errorMessages << "\nPOSSIBLE REASON: Mapping to external calibrator libraries or rRNA sequences failed. This could be a potential failure of Bowtie."
          elsif(missingFile =~ /\.clipped\.readLengths\.txt/)
            errorMessages << "\nPOSSIBLE REASON: Calculation of read length distribution of clipped reads failed."
          elsif(missingFile =~ /reads\.fa/)
            errorMessages << "\nPOSSIBLE REASON: There were no input reads available for analysis. It is possible that \n1. all reads were removed in the pre-processing stage (or) \n 2. the adapter sequence was not automatically identified by the pipeline, so reads were not clipped. \nAs a result, long reads ended up in the analysis and were rejected.\n You can try providing the 3\' adapter sequence and redoing the analysis."
          elsif(missingFile =~ /endogenousUnaligned_ungapped_noLibs\.fq/)
            errorMessages << "\nPOSSIBLE REASON: All reads from your input file failed the quality filter stage. Please ensure that\nyour input file has good quality reads."
          elsif(missingFile =~ /ExogenousRibosomalAlignments\.result\.taxaAnnotated\.txt/)
            errorMessages << "\nPOSSIBLE REASON: Your processing failed due to memory issues even after relaunching your job\nwith significantly more memory. Please contact an admin below for further guidance."
          end
        end
        # OK, so we didn't find any errors so far. Let's do a more general check in the .out / .err files just to make sure something weird didn't happen.
        if(errorMessages.strip.empty?)
          cmd = "grep -P \"^ERROR\\s\" #{outFile} #{errFile}"
          errorMessages = `#{cmd}`
          if(errorMessages.strip.empty?)
            retVal = false
          else
            retVal = true
          end
        else
          retVal = true
        end
      end
      # We will always raise an error if exceRpt exited in any unnatural way
      unless(exitStatus)
        retVal = true if(!retVal)
      end
      # Did we find anything?
      if(retVal)
        # Here, we mark the current run as failed and set its error message correspondingly
        @failedRun = true
        @errUserMsg = "exceRpt small RNA-seq Pipeline Failed.\nMessage from exceRpt:\n\n"
        if(errorMessages.nil? or errorMessages.empty?)
          @errUserMsg << "[No error info available from exceRpt]"
        else
          @errUserMsg << errorMessages
        end
      end
      return retVal
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

############ END of methods specific to this runExceRpt wrapper
    
########### Email 

    # Method to send success e-mail to user
    def prepSuccessEmail()
      # Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
      # Transfer jobFile.json to user's Database (can't do this via JobHelper because we don't know the full resource path until we run this wrapper)
      uploadJobFile(toolJobFile)
      # Email object
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @userFirstName
      emailObject.userLast      = @userLastName
      emailObject.analysisName  = @analysisName
      inputsText                = customBuildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      outputsText               = buildSectionEmailSummary(@outputs[0])
      emailObject.outputsText   = outputsText
      emailObject.settings      = @settings
      emailObject.exitStatusCode = @exitCode
      additionalInfo = ""
      additionalInfo << "Your result files are currently being uploaded to your database.\nPlease wait for some time before attempting to download your result files.\n\n" +
                        "Result files for this sample can be found at this location in the Genboree Workbench:\n" + 
                          "|-Group: '#{@groupName}'\n" +
                            "|--Database: '#{@dbName}'\n" +
                              "|---Files\n" 
      if(@remoteStorageArea)
        additionalInfo << "|----#{@remoteStorageArea}\n" + 
                            "|-----exceRptPipeline_v#{@toolVersion}\n" +
                              "|------#{@analysisName}\n"+
                                "|-------#{@sampleName}\n"
      else 
        additionalInfo << "|----exceRptPipeline_v#{@toolVersion}\n" +
                            "|-----#{@analysisName}\n" +
                              "|------#{@sampleName}\n"
      end 
      additionalInfo << "\n==================================================================\n" +
                        "NOTE 1:\nIf you selected to upload full alignment files,\nthe file that ends in '_results_v#{@toolVersion}' is a large archive\nthat contains all result files from the exceRpt pipeline\nthrough the exogenous miRNA + rRNA stage." +
                        "\n==================================================================\n" +
                        "NOTE 2:\nThe file that ends in '_CORE_RESULTS_v#{@toolVersion}' is a much smaller archive\nthat contains the key result files from the exceRpt pipeline.\nThis file can be found in the 'CORE_RESULTS' subfolder\nand has been decompressed in that subfolder for your convenience." +
                        "\n==================================================================\n" +
                        "NOTE 3:\nThe file that ends in '.stats' contains a summary list of read counts mapped to various libraries." +
                        "\n==================================================================\n" +
                        "NOTE 4:\nQC metrics for your sample can be found in the sample's .qcResult file.\nTo learn more about our QC metrics, view the following:\nhttp://exrna.org/resources/data/data-quality-control-standards/"
      if(@settings['fullExogenousMapping'])
        additionalInfo <<  "\n==================================================================\n" +
                           "NOTE 5:\nWhen all of your samples have been processed, we will run the Exogenous STAR Mapping tool\nto finish the exogenous genomic alignments for your samples.\nTHIS MEANS THAT THE RESULT FILES FROM THIS JOB\nONLY INCLUDE ENDOGENOUS ALIGNMENTS + ALIGNMENTS TO EXOGENOUS miRNAs AND rRNAs!\nWhen your Exogenous STAR Mapping job finishes, you will have access to the full exogenous genomic alignments,\nand your .stats file and CORE_RESULTS archive will be updated with the exogenous genome alignment information."
      end
      emailObject.resultFileLocations = nil
      foundError = false
      @errInputs.each_value { |categoryValue| foundError = true unless(categoryValue.empty?) }
      if(foundError)
        additionalInfo << "\n==================================================================\n"
        additionalInfo << "We encountered some errors when processing your input for this job.\n\n"
        additionalInfo << "Individual error messages are printed below:"
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
              additionalInfo << "#{msg}\n#{@errInputs[category].join("\n")}"
            end
          end
        }
      end
      additionalInfo << "\n==================================================================\n"
      emailObject.additionalInfo = additionalInfo
      # Remove settings that are unnecessary for user e-mail
      cleanUpSettingsForEmail()
      # If user checked the checkbox to suppress runExceRpt emails, then we won't send them an email for each individual sample successfully processed.
      # We'll still send them emails for samples that fail, though (you can't suppress those via UI!).
      @suppressEmail = true if(@settings['suppressRunExceRptEmails'])
      if(@suppressEmail)
        return nil
      else
        return emailObject
      end
    end
    
    # Method to send failure e-mail to user
    def prepErrorEmail()
      # Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
      # Transfer jobFile.json to user's Database (can't do this via JobHelper because we don't know the full resource path until we run this wrapper)
      # If the job fails before @sampleName is successfully grabbed, then we shouldn't try to upload the job file (as the resource path depends upon this variable)
      uploadJobFile(toolJobFile) if(@sampleName)
      # Email object  
      emailErrorObject                = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailErrorObject.userFirst      = @userFirstName
      emailErrorObject.userLast       = @userLastName
      emailErrorObject.analysisName   = @analysisName
      inputsText                      = customBuildSectionEmailSummary(@inputs)
      emailErrorObject.inputsText     = inputsText
      outputsText                     = buildSectionEmailSummary(@outputs[0])
      emailErrorObject.outputsText    = outputsText
      emailErrorObject.settings       = @settings
      emailErrorObject.errMessage     = @errUserMsg
      emailErrorObject.exitStatusCode = @exitCode
      emailErrorObject.erccTool = true
      additionalInfo = ""
      if(@errInputs)
        foundError = false
        @errInputs.each_value { |categoryValue| foundError = true unless(categoryValue.empty?) }
        if(foundError)
          additionalInfo << "We encountered some errors when processing your input for this job.\n\n"
          additionalInfo << "Individual error messages are printed below:"
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
                additionalInfo << "#{msg}\n#{@errInputs[category].join("\n")}"
              end
            end
          }
        end
      end
      emailErrorObject.additionalInfo = additionalInfo unless(additionalInfo.empty?)
      # Remove settings that are unnecessary for user e-mail
      cleanUpSettingsForEmail()
      if(@suppressEmail)
        return nil
      else
        return emailErrorObject
      end
    end
  
    # This method uploads the jobFile.json file to the appropriate location in the user's Database.
    # We have to use this method (as opposed to relying on JobHelper and its postCmds() method)
    # because we don't know the full resource path at the time the JobHelper runs.
    # @param [String] toolJobFile path to jobFile.json on disk
    # @return [nil]
    def uploadJobFile(toolJobFile)
      targetUri = URI.parse(@outputs[0])
      # Specify full resource path
      unless(@remoteStorageArea)
        rsrcPath = "#{targetUri.path}/file/exceRptPipeline_v#{@toolVersion}/{analysisName}/#{CGI.escape(@sampleName)}/{outputFile}/data?" 
      else
        rsrcPath = "#{targetUri.path}/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@toolVersion}/{analysisName}/#{CGI.escape(@sampleName)}/{outputFile}/data?" 
      end
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      uploadFile(targetUri.host, rsrcPath, @subUserId, toolJobFile, {:analysisName => @analysisName, :outputFile => File.basename(toolJobFile)})
      return
    end

    # When we send our success or failure email, there are certain settings that we don't want to send the user (because they're not helpful, redundant, etc.).
    # @return [nil]  
    def cleanUpSettingsForEmail()
      @settings.delete("adSeqParameter")
      @settings.delete("calib")
      @settings.delete("genomeBuild")
      @settings.delete("javaRam")
      @settings.delete("localExecution")
      @settings.delete("numThreads")
      @settings.delete("postProcDir")
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
      if(@settings['adapterSequence'] == "manual")
        @settings['adapterSequence'] << " (#{@adSeqParameter})"
      end
      @settings.delete("piID")
      @settings.delete("platform")
      @settings.delete("processingPipeline")
      @settings.delete("processingPipelineIdAndVersion")
      @settings.delete("processingPipelineVersion")
      @settings.delete("subdirs")
      @settings.delete("wbContext")
      unless(@settings["randomBarcodesEnabled"])
        @settings.delete("randomBarcodeLength")
        @settings.delete("randomBarcodeLocation")
        @settings.delete("randomBarcodeStats")
      end
      # Fix up endogenous library order so that it's easier to read
      if(@settings['endogenousLibraryOrder'])
        @settings['endogenousLibraryOrder'].gsub!("gencode", "Gencode")
        @settings['endogenousLibraryOrder'].gsub!(",", " > ")
      end
      # Delete misc. settings associated with endogenous library ordering
      @settings.delete('priorityList')
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
      @settings["endogenousLibraryOrder"].gsub!(",", " > ") if(@settings["endogenousLibraryOrder"])
      @settings.delete("subUserId")
      @settings.delete("uploadRawFiles")
      @settings.delete("remoteStorageArea") if(@settings["remoteStorageArea"] == nil)
      @settings.delete('totalOutputFileSize')
      # Delete local path to post-processing input dir
      @settings.delete('postProcDir')
      @settings.delete('exogenousMappingInputDir')
      # Delete information about number of threads / tasks for exogenous mapping (used in exogenousSTARMapping wrapper)
      @settings.delete('numThreadsExo')
      @settings.delete('numTasksExo')
      @settings.delete('numberField_fractionForMinBaseCallQuality')
      @settings.delete('numberField_minReadLength')
      @settings.delete('numberField_readRemainingAfterSoftClipping')
      @settings.delete('numberField_trimBases5p')
      @settings.delete('numberField_trimBases3p')
      @settings.delete('numberField_minAdapterBases3p')
      @settings.delete('numberField_downsampleRNAReads')
      @settings.delete('numberField_bowtieSeedLength')
      @settings.delete('minBaseCallQuality') if(@settings['exceRptGen'] == 'thirdGen') # We can delete minimum base-call quality if user submitted 3rd gen exceRpt job
      @settings['exogenousMapping'] = "on" if(@settings['fullExogenousMapping'])
      @settings.delete('exRNAAtlasURL')
      @settings.delete('importantJobIdsDir')
      @settings.delete('postProcOutputDir')
      @settings.delete('manifestFile')
      @settings.delete('releaseStatus')
      @settings.delete('exogenousClaves')
      @settings.delete("uploadReadCountsDocs")
      @settings.delete("exoJobId")
      @settings.delete("exogenousTaxoTreeJobIDDir")
      @settings.delete('exogenousRerunDir')
      @settings.delete('filePathToListOfExogenousJobIds')
      @settings.delete("backupFtpDir")
      @settings.delete('databaseGenomeVersion')
      @outputs.delete_at(1)
      @outputs.delete_at(1)
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
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::RunExceRptWrapper)
end
