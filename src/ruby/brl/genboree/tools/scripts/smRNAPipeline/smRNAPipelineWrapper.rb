#!/usr/bin/env ruby
#########################################################
############ exceRpt smRNAPipeline wrapper #################
## This wrapper runs the small RNA-Seq data analysis pipeline #
## Modules used in this pipeline:
## 1. smallRNAPipeline
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
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class SmRNAPipelineWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "2.2.8"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running 'smRNAPipeline'.
                        This tool is intended to be called via the Genboree Workbench",
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
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        ## Getting relevant variables from "context"
        @dbrcKey = @context['apiDbrcKey']
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])

        ## Get the tool version from toolConf
        @toolVersion = @toolConf.getSetting('info', 'version')
        @settings['toolVersion'] = @toolVersion

        # Hash that will contain input file names and associated output files (for uploading and proper clean up)
        # each inputFile key will be linked to a hash that contains the following values:
        #   :failedRun => boolean flag telling us whether pipeline job succeeded or failed (false = succeeded, true = failed)
        #   :sampleName => name of sample
        #   :resultsZip => name of zipped archive containing pipeline results
        #   :coreZip => name of zipped archive containing core files from pipeline results
        #   :statsFile => name of stats file containing summary about pipeline results
        #   :errorMsg => error message associated with run
        @inputFiles = {}
        # Directory used for post-processing of successful runs (using the processPipelineRuns tool)
        @postProcDir = "#{@scratchDir}/subJobsScratch/processPipelineRuns"
        @runsDir = "#{@postProcDir}/runs"
        `mkdir -p #{@runsDir}`

        # Set up format options coming from the UI
        @analysisName = @settings['analysisName']

        ## 3' Adapter Sequence Options
        @clippedInput = ""
        @clippedInput = @settings['clippedInput']
        @adapterSequence = @settings['adapterSequence'].to_s

        ## Small RNA Mapping Libraries Options
        @tRNAmapping = @settings['tRNAmapping']
        @piRNAmapping = @settings['piRNAmapping']
        @gencodemapping = @settings['gencodemapping']
        @exogenousMapping = @settings['exogenousMapping']

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

        if(@exogenousMapping =~ /on/)
          # Number of tasks / threads defined for parallel smallRNA-seq jobs to run STAR mapping
          @tRNAmapping = "on"
          @piRNAmapping = "on"
          @gencodemapping = "on"
          @numTasks = 1
          @numThreads = 8
          @javaRam = "10G"
        else
          # Number of tasks / threads defined for parallel smallRNA-seq jobs
          @numTasks = 3
          @numThreads = 4
          @javaRam = "10G"
        end

        @smallRNALibs = "TRNA_MAPPING=#{@tRNAmapping} PIRNA_MAPPING=#{@piRNAmapping} GENCODE_MAPPING=#{@gencodemapping} MAP_EXOGENOUS=#{@exogenousMapping} "
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "small RNA Libs: #{@smallRNALibs}")

        ## Get adapter sequence
        @adSeq = ""
        if(@adapterSequence =~ /^[ATGCNatgcn]+$/)
          @adSeq = "ADAPTER_SEQ=#{@adapterSequence}"
        else
          @adSeq = "ADAPTER_SEQ=NULL"
        end
        if(@clippedInput)
          @adSeq = "ADAPTER_SEQ=NONE"
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adapter Seq: #{@adSeq}")

        ## Mapping advanced options
        @mismatchMirna = @settings['mismatchMirna']
        @mismatchOther = @settings['mismatchOther']

        if(!@mismatchMirna or @mismatchMirna.empty? or @mismatchMirna.nil?)
          @mismatchMirna = 1
        end
        if(!@mismatchOther or @mismatchOther.empty? or @mismatchOther.nil?)
          @mismatchOther = 2
        end

        ## Local execution
        @localExecution = "false"

        ## User defined custom calibrator/spike-in libraries
        ## User uploads a FASTA sequence, generate a bowtie2 index using the "Index Bowtie" tool
        @calibratorDir = "#{@scratchDir}/calibrator"
        `mkdir -p #{@calibratorDir}`

        @useLibrary = @settings['useLibrary']
        if(@useLibrary =~ /uploadNewLibrary/)
          @spikeInName = @settings['indexBaseName']
          @spikeInUri = @settings['newSpikeInLibrary']
          if(@spikeInName.empty? or @spikeInName.nil?)
            fileBase = @fileApiHelper.extractName(@spikeInUri)
            fileBaseName = File.basename(fileBase)
            @spikeInName = fileBaseName.makeSafeStr(:ultra)
          end
        elsif(@useLibrary =~ /useExistingLibrary/)
          @spikeInUri = @settings['libraryList']
          fileBase = @fileApiHelper.extractName(@spikeInUri)
          fileBaseName = File.basename(fileBase)
          @spikeInName = fileBaseName.makeSafeStr(:ultra)
        end

        ## Make sure the genome version is supported by
        ## current implementation of this pipeline
        @genomeVersion = @settings['genomeVersion']
        if(!@genomeVersion.nil?)
          @gbSmallRNASeqPipelineGenomesInfo = JSON.parse(File.read(@genbConf.gbSmallRNASeqPipelineGenomesInfo))
          @indexBaseName = @gbSmallRNASeqPipelineGenomesInfo[@genomeVersion]['indexBaseName']
          @genomeBuild = @gbSmallRNASeqPipelineGenomesInfo[@genomeVersion]['genomeBuild']
          if(@indexBaseName.nil?)
            @errUserMsg = "This genome is not currently supported.\nPlease contact the Genboree Administrator for adding support for this genome."
            raise @errUserMsg
          end
        end
        # @successfulSamples will keep track of how many samples are successfully run through the pipeline
        @successfulSamples = 0
        # @failedSamples will keep track of how many samples failed to be run through the pipeline.
        # This number is only reported if at least one sample succeeded (otherwise, user receives an error e-mail, and all their samples failed!)
        @failedSamples = 0
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job." if(@errUserMsg.nil?)
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # @return [FixNum] @exitCode code corresponding to whether tool run was successful or not (and if not, what error message should be given to user)
    def run()
      begin
        @user = @pass = nil
        if(@dbrcKey)
          dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
          # get super user, pass and hostname
          @user = dbrc.user
          @pass = dbrc.password
        else
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @dbrcFile)
          @user = suDbDbrc.user
          @pass = suDbDbrc.password
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "BEGIN exceRpt small RNA-seq Pipeline")

        # Download the input from the server
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input file from server")
        downloadFiles()

        ## Make bowtie2 indexes of spike-in library
        if(@useLibrary =~ /uploadNewLibrary/ or @useLibrary =~ /useExistingLibrary/)
          ## Download the custom FASTA File from user db, sniff to ensure it is FASTA,
          ## expand if necessary
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading spike-in library file #{@spikeInUri}.")
          downloadSpikeInFile(@spikeInUri)
          ## Make bowtie2 index of this oligo library
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Making Bowtie2 index of spike-in library.")
          makeOligoBowtieIndex(@spikeInFile)
          @calib = "#{@oligoBowtie2BaseName}"
        else
          @calib = "NULL"
        end

        # Run all samples. Jobs will be run in parallel.
        @smRNAMakefile = ENV['SMALLRNA_MAKEFILE']
        Parallel.map(@inputFiles.keys, :in_threads => @numTasks) { |inFile|
          begin
            runSmallRNAseqPipeline(inFile)
          rescue => err
            # If an error occurs, we'll mark the run as failed and set the error message accordingly
            @inputFiles[inFile][:failedRun] = true
            @inputFiles[inFile][:errorMsg] = err.message.inspect
          end
        }
        # Check if there are any samples to be redone with more JAVA RAM
        @redoSamples = []
        @inputFiles.each_key { |currentFile|
          if(@inputFiles[currentFile][:redoThisSample])
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Sample #{currentFile} needs to be done again - with more JAVA RAM.")
            @redoSamples << currentFile
          end
        }
        # If we have samples to redo, then increase JAVA RAM and run one sample at a time
        if(!@redoSamples.empty?)
          # Number of tasks / threads defined for individual smallRNA-seq jobs
          # In such cases, provide more JAVA RAM and run 1 sample at a time
          @javaRam = "30G"
          @numThreads = 12
          @redoSamples.each { |inFile|
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Redoing sample #{inFile} - with 30GB JAVA RAM.")            
            begin
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "runSmallRNAseqPipeline method to run sample #{inFile}")
              runSmallRNAseqPipeline(inFile)
            rescue => err
              # If an error occurs again, we'll mark the run as failed and set the error message accordingly
              @inputFiles[inFile][:failedRun] = true
              @inputFiles[inFile][:errorMsg] = err.message.inspect
            end
          }
        end
        
        # Parallel DONE!
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "small RNA pipeline finished for all samples.")
        # Count number of successful samples processed
        @inputFiles.each_key { |currentFile|
          unless(@inputFiles[currentFile][:failedRun])
            @successfulSamples += 1
          else
            @failedSamples += 1
          end
        }
        # If no runs succeeded, then we raise an error
        if(@successfulSamples == 0)
          @errUserMsg = "All runs failed so post-processing was not done.\nPlease contact the Genboree team to investigate your job."
          raise @errUserMsg
        end
        # Run processPipelineRuns on successful results .zip files
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Run processPipelineRuns on successful results .zip files")
        postProcessing(@inputFiles)
        # Submit tool usage doc to exRNA Internal collection (for tracking purposes). Note that we don't want to submit docs for AUTO jobs!
        unless(@jobId[0, 4] == "AUTO")
          submitToolUsageDoc()
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE smallRNAseq Pipeline. END.")
        ## DONE smRNAPipeline
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of smallRNA-seq Pipeline failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to run smallRNA-seq Pipeline." if(@errInternalMsg.nil?)
        @exitCode = 30
      end
      return @exitCode
    end

###### *****************************
###### Methods used in this workflow
###### *****************************

    # Download input files from database, extracts zipped files, sniffs files to make sure they're FASTQ or SRA, and sets up hash values for a given input file
    # @return [nil]
    def downloadFiles()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input files using threads #{@inputs.inspect}")

      uriPartition = @fileApiHelper.downloadFilesInThreads(@inputs, @userId, @scratchDir)
      localPaths = uriPartition[:success].values
        
      #@inputs.each { |input|
      #  # Download current input file
      #  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input file #{input}")
      #  fileBase = @fileApiHelper.extractName(input)
      #  fileBaseName = File.basename(fileBase)
      #  tmpFile = fileBaseName.makeSafeStr(:ultra)
      #  retVal = @fileApiHelper.downloadFilesInThreads(input, @userId, @scratchDir)
      #  if(!retVal)
      #    @errUserMsg = "Failed to download file: #{fileBase} from server after many attempts.\nPlease try again later."
      #    raise @errUserMsg
      #  end
      #  $stderr.debugPuts(__FILE__, __method__, "STATUS", "File downloaded successfully to #{tmpFile}")   
      localPaths.each { |tmpFile|
        ## Expand the files if it is compressed
        exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracting input file #{tmpFile}")
        exp.extract()
        # Sniffer - To check FASTQ/SRA format
        sniffer = BRL::Genboree::Helpers::Sniffer.new()
        inputFile = exp.uncompressedFileName
        # Delete original file if it was compressed (we don't need to keep it)
        `rm -f #{tmpFile}` unless(exp.compressedFileName == inputFile)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "The path of the unzipped input file is: #{inputFile}")
        if(File.zero?(inputFile))
          @errUserMsg = "Input file #{inputFile} is empty.\nPlease upload non-empty file and try again."
          raise @errUserMsg
        end
        tempDir = exp.tmpDir
        # Check if the current input file is a single compressed archive of various (compressed) input FASTQ/SRA files.
        if(File.directory?(inputFile))
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "It looks like the #{inputFile} is a directory, so the file must have been a compressed archive of all input files.")
          @allFiles = Dir.entries(inputFile)
          # Check each file inside this directory
          @allFiles.each{ |inputFileInDir|
            # Skip the junk folder __MACOSX
            next if(inputFileInDir == "." or inputFileInDir == ".." or inputFileInDir =~ /__MACOSX/)
            inputDataFile = "#{tempDir}/#{inputFileInDir}"
            # We do not support multiple subdirs inside the compressed archive. All input FASTQ/SRA files should be at the top level.
            if(File.directory?(inputDataFile))
              @errUserMsg = "File #{inputDataFile} is a directory. Data files in an archive should not be inside a sub-directory. Please reupload your archive without any sub-directories."
              raise @errUserMsg
            else            
              ## Expand this data file
              exp = BRL::Genboree::Helpers::Expander.new(inputDataFile)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracting input file #{inputDataFile}")
              exp.extract()
              # Sniffer - To check FASTQ/SRA format
              sniffer = BRL::Genboree::Helpers::Sniffer.new()
              dataFile = exp.uncompressedFileName
              # Delete original file if it was compressed (we don't need to keep it)
              `rm -f #{inputDataFile}` unless(inputDataFile == dataFile)  
              # Detect if file is in FASTQ/SRA format
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Detecting file type of extracted file #{dataFile} using file sniffer")
              sniffer.filePath = dataFile
              # Reject any file other than FASTQ or SRA
              fileType = ""
              fileType = "FASTQ" if(sniffer.detect?('fastq'))
              fileType = "SRA" if(fileType.empty? and sniffer.detect?('sra'))
              unless(fileType == "FASTQ" or fileType == "SRA")
                @errUserMsg = "File #{dataFile} is not in FASTQ/SRA format (acceptable input formats).\nPlease check the file format and try again."
                raise @errUserMsg
              end
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input File #{dataFile} is in correct format, FASTQ or SRA")
              # Add input files and its associated data to the hash
              @inputFiles[dataFile] = {:failedRun => false, :errorMsg => ""}
              # Convert to unix format
              convObj = BRL::Util::ConvertText.new(exp.uncompressedFileName, true)
              convObj.convertText()
              # Count number of lines in the input file
              numLines = `wc -l #{dataFile}`
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of lines in file #{dataFile}: #{numLines}")
            end
          }
        else
          # The current input is a single file, not an archive, so it needs to be handled slightly differently
          # Detect if file is in FASTQ/SRA format
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Detecting file type of extracted file #{inputFile} using file sniffer")
          sniffer.filePath = inputFile
          # Reject any file other than FASTQ or SRA
          fileType = ""
          fileType = "FASTQ" if(sniffer.detect?('fastq'))
          fileType = "SRA" if(fileType.empty? and sniffer.detect?('sra'))
          unless(fileType == "FASTQ" or fileType == "SRA")
            @errUserMsg = "File #{inputFile} is not in FASTQ/SRA format (acceptable input formats).\nPlease check the file format and try again."
            raise @errUserMsg
          end
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input File #{inputFile} is in correct format, FASTQ or SRA")
          # Add input files and its associated data to the hash
          @inputFiles[inputFile] = {:failedRun => false, :errorMsg => ""}
          # Convert to unix format
          convObj = BRL::Util::ConvertText.new(exp.uncompressedFileName, true)
          convObj.convertText() 
          # Count number of lines in the input file
          numLines = `wc -l #{inputFile}`
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of lines in file #{inputFile}: #{numLines}")
        end
      }
      return
    end
    
    # Make bowtie2 index of spike-in file
    # @param [String] spikeInFile path to spike-in file
    # @return [nil]
    def makeOligoBowtieIndex(spikeInFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Using #{spikeInFile} to make bowtie2 index.")
      @outFile = "#{@scratchDir}/indexBowtie.out"
      @errFile = "#{@scratchDir}/indexBowtie.err"
      ## Build Bowtie2 index
      @oligoBowtie2BaseName = "#{@calibratorDir}/#{CGI.escape(@spikeInName)}"
      command = "bowtie2-build #{spikeInFile} #{@oligoBowtie2BaseName} "
      command << " > #{@outFile} 2> #{@errFile}"  
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      if(!exitStatus)
        @errUserMsg = "Bowtie2 indexing of spike-in library failed to run. Please check your spike-in FASTA file. The file should not contain anything other than the spike-in sequences in FASTA format."
        raise "Command: #{command} died. Check #{@outFile} and #{@errFile} for more information."
      end
      return
    end
    
    # Download custom oligo/spike-in FASTA file from database, extracts zipped file, sniff this file to make sure it is in FASTA format'
    # @param [String] newOligoFile URL to spike-in file that we're downloading
    # @return [nil]
    def downloadSpikeInFile(newOligoFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading spike-in file #{newOligoFile}")
      fileBase = @fileApiHelper.extractName(newOligoFile)
      fileBaseName = File.basename(fileBase)
      tmpFile = fileBaseName.makeSafeStr(:ultra)
      retVal = @fileApiHelper.downloadFile(newOligoFile, @userId, tmpFile)
      if(!retVal)
        @errUserMsg = "Failed to download spike-in file: #{fileBase} from server after many attempts.\nPlease try again later."
        raise @errUserMsg
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "File downloaded successfully to #{tmpFile}")   
      # Expand the file if it is compressed
      exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracting spike-in file #{tmpFile}")
      exp.extract()
      # Sniffer - To check FASTQ/SRA format
      sniffer = BRL::Genboree::Helpers::Sniffer.new()
      inputFile = exp.uncompressedFileName
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "The path of the unzipped spike-in file is: #{inputFile}")
      # Check whether file is empty
      if(File.zero?(inputFile))
        @errUserMsg = "Input file #{inputFile} is empty.\nPlease upload non-empty file and try again."
        raise @errUserMsg
      end   
      # Detect if file is in FASTA format
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Detecting file type of extracted spike-in file #{inputFile} using file sniffer")
      sniffer.filePath = inputFile
      unless(sniffer.detect?('ascii') && sniffer.detect?('fa'))
        @errUserMsg = "Spike-in file #{inputFile} is not in FASTA format.\nPlease check the file format.\nNOTE: The spike-in file should be a plain text file and contain only FASTA sequences of the oligos."
        raise @errUserMsg
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Spike-in File #{inputFile} is in correct format")
      # Convert to unix format
      convObj = BRL::Util::ConvertText.new(inputFile, true)
      convObj.convertText() 
      # Count number of lines in the input file
      numLines = `wc -l #{inputFile}`
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of lines in spike-in file #{inputFile}: #{numLines}")
      spikeInFileBasename = File.basename(inputFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Moving spike-in file #{inputFile} to calibrator dir #{@calibratorDir}/.")
      `mv #{inputFile} #{@calibratorDir}/.`
      @spikeInFile = "#{@calibratorDir}/#{spikeInFileBasename}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Spike-in file #{@spikeInFile} is available in calibrator dir #{@calibratorDir}/.")
      return
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
      ## Run smRNA pipeline with outFile and errFile specified below
      outFile = "#{@scratchDir}/#{sample}.out"
      errFile = "#{@scratchDir}/#{sample}.err"
      ## Make command to run smallRNA Pipeline
      command = "make -f #{@smRNAMakefile} INPUT_FILE_PATH=#{inFile} N_THREADS=#{@numThreads} JAVA_RAM=#{@javaRam} MAIN_ORGANISM=#{@genomeBuild} MAIN_ORGANISM_GENOME_ID=#{@genomeVersion} CALIBRATOR_LIBRARY=#{@calib} INPUT_FILE_ID=#{sample} OUTPUT_DIR=#{@scratchDir} #{@smallRNALibs} #{@adSeq} MISMATCH_N_MIRNA=#{@mismatchMirna} MISMATCH_N_OTHER=#{@mismatchOther} LOCAL_EXECUTION=#{@localExecution} >> #{outFile} 2>> #{errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "smallRNA-seq Pipeline command completed for #{inFile} (exit code: #{statusObj.exitstatus})")
      # Check whether there was an error with the smallRNA-seq pipeline run
      foundError = findError(exitStatus, inFile, outFile, errFile)
      if(foundError =~ /redo/)
        @inputFiles[inFile][:redoThisSample] = true
        return
      else
        ## Run make command again with compressCoreResults target to create a tgz archive of core result files
        command = "make compressCoreResults -f #{@smRNAMakefile} INPUT_FILE_PATH=#{inFile} N_THREADS=#{@numThreads} JAVA_RAM=#{@javaRam} MAIN_ORGANISM=#{@genomeBuild} MAIN_ORGANISM_GENOME_ID=#{@genomeVersion} CALIBRATOR_LIBRARY=#{@calib} INPUT_FILE_ID=#{sample} OUTPUT_DIR=#{@scratchDir} #{@smallRNALibs} #{@adSeq} MISMATCH_N_MIRNA=#{@mismatchMirna} MISMATCH_N_OTHER=#{@mismatchOther} LOCAL_EXECUTION=#{@localExecution} >> #{outFile} 2>> #{errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
        exitStatus = system(command)
        statusObj = $?
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "make compressCoreResults command completed for #{inFile} (exit code: #{statusObj.exitstatus})")
        # Compress output (partial results if error occurred in run, full results otherwise)
        compressOutputs(inFile, @inputFiles, foundError, outFile, errFile)
        # Transfer files for this sample to the user db
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Transferring compressed outputs of this sample #{inFile} to the server")
        transferFilesForSample(inFile, @inputFiles)
        return
      end
    end
    
    # Compress output files to be transferred to user db
    # @param [String] inFile path to file name for input file (also used as key in @inputFiles hash for distinguishing runs)
    # @param [Hash<String, Hash<Symbol, Object>] inputFiles hash containing information about input files
    # @param [boolean] foundError boolean that tells us whether an error occurred in the current run 
    # @param [String] outFile path to file where standard output is stored from run
    # @param [String] errFile path to file where error output is stored from run
    # @return [nil]
    def compressOutputs(inFile, inputFiles, foundError, outFile, errFile)
      # Set resultsZip depending on whether an error occurred (partial) or didn't
      unless(foundError)
        resultsZip = "#{inputFiles[inFile][:sampleName]}_#{CGI.escape(@analysisName)}_results_v#{@toolVersion}.zip"
        coreZip = "#{inputFiles[inFile][:sampleName]}_CORE_RESULTS_v#{@toolVersion}.tgz"
      else
        resultsZip = "#{inputFiles[inFile][:sampleName]}_#{CGI.escape(@analysisName)}_partial_results_v#{@toolVersion}.zip"
        coreZip = "#{inputFiles[inFile][:sampleName]}_PARTIAL_CORE_RESULTS_v#{@toolVersion}.tgz"
      end
      # Pipeline will create stats file with name :sampleName.stats
      statsFile = "#{inputFiles[inFile][:sampleName]}.stats"
      # Compress results zip
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Compressing outputs to create #{resultsZip}")
      command = "cd #{@scratchDir}; zip -r #{resultsZip} #{inputFiles[inFile][:sampleName]}.log #{statsFile} #{inputFiles[inFile][:sampleName]}/* >> #{outFile} 2>> #{errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching zip command to compress results file: #{command}")
      exitStatus = system(command)
      unless(exitStatus)
        @errUserMsg = "Could not create the zip archive of results."
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
      if(File.exist?("#{@scratchDir}/#{resultsZip}"))
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE Compressing outputs to create #{resultsZip}")
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Results zip archive #{resultsZip} is not found.")
        @errUserMsg = "Results zip archive #{resultsZip} is not found."
        raise @errUserMsg
      end
      # Push results zip and stats file onto corresponding input file hash
      inputFiles[inFile].merge!({:resultsZip => resultsZip, :coreZip => coreZip, :statsFile => statsFile})
     # Delete uncompressed results (don't need them anymore)
     `rm -rf #{@scratchDir}/#{inputFiles[inFile][:sampleName]}`
      return
    end
    
    # Run processPipelineRuns tool on successful results .zip files
    # @param [Hash<String, Hash<Symbol, Object>] inputFiles hash containing information about input files
    # @return [nil]
    def postProcessing(inputFiles)
      # Produce processPipelineRuns job file
      createPPRJobConf()
      # Call processPipelineRuns wrapper
      callPPRWrapper()
      return
    end
   
    # Method to create processPipelineRuns jobFile.json used in callPPRWrapper()
    # @return [nil]
    def createPPRJobConf()
      @pprJobConf = @jobConf.deep_clone()
      ## Define context 
      @pprJobConf['context']['toolIdStr'] = "processPipelineRuns"
      @pprJobConf['context']['scratchDir'] = @postProcDir
      @pprJobConf['settings']['localJob'] = true
      @pprJobConf['settings']['exceRptToolVersion'] = @toolVersion
      @pprJobConf['settings']['suppressEmail'] = true
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
      return
    end
      
    # Transfer output files to the user database for a particular sample
    # @param [Hash<String, Hash<Symbol, Object>] inputFiles hash containing information about input files
    # @return [nil]    
    def transferFilesForSample(currentFile, inputFiles)
      # Parse target URI for outputs
      targetUri = URI.parse(@outputs[0])
      # Specify  full resource path
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Transferring outputs of this sample #{currentFile} to the user database in server")
      # Traverse every input and upload associated results zip and stats file
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
        uploadFile(targetUri.host, rsrcPath, @userId, "#{@scratchDir}/#{inputFiles[currentFile][:statsFile]}", {:analysisName => @analysisName, :outputFile => "#{inputFiles[currentFile][:statsFile]}"})
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Skipping upload of stats file #{@scratchDir}/#{inputFiles[currentFile][:statsFile]}, since it is incomplete.")
      end        
      # resultsZip
      # :outputFile => each run's resultsZip
      # input is each run's "#{@scratchDir}/#{@resultsZip}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Trying to upload results zip #{@scratchDir}/#{inputFiles[currentFile][:resultsZip]}")        
      uploadFile(targetUri.host, rsrcPath, @userId, "#{@scratchDir}/#{inputFiles[currentFile][:resultsZip]}", {:analysisName => @analysisName, :outputFile => "#{inputFiles[currentFile][:resultsZip]}"})
      # coreZip
      # :outputFile => each run's coreZip
      # input is each run's "#{@scratchDir} /#{coreZip}"
      if(File.exist?("#{@scratchDir}/#{inputFiles[currentFile][:coreZip]}"))
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Trying to upload core zip #{@scratchDir}/#{inputFiles[currentFile][:coreZip]}")
        ## Use extract true to unpack all core result files in the CORE RESULTS folder
        rsrcPath << "extract=true"
        uploadFile(targetUri.host, rsrcPath, @userId, "#{@scratchDir}/#{inputFiles[currentFile][:coreZip]}", {:analysisName => @analysisName, :outputFile => "CORE_RESULTS/#{inputFiles[currentFile][:coreZip]}"})
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Grouped Zip File #{inputFiles[currentFile][:coreZip]} does not exist. Skipping.")
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE transferring outputs of #{sampleName} to the user database in server")
      # Remove uncompressed input file and results zip (we don't need them anymore)
      `rm -f #{currentFile}`
      `rm -f #{@scratchDir}/#{inputFiles[currentFile][:resultsZip]}`
      # Move core .zip to postProcessing directory
      `mv #{@scratchDir}/#{inputFiles[currentFile][:coreZip]} #{@postProcDir}/runs/#{inputFiles[currentFile][:coreZip]}`
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
      # Print error if our upload fails
      if(!retVal)
        # Print error if the reason the upload failed was because we exceeded number of attempts
        if (@fileApiHelper.uploadCheck == 2)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "After many attempts, #{input}\nwas not uploaded successfully to server. Please resubmit your job.")
          @errUserMsg = @errInternalMsg = "After many attempts, #{input}\nwas not uploaded successfully to server. Please resubmit your job."
          @exitCode = 38
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          raise @err
        # Print error if the reason the upload failed was because the target path no longer exists (missing group, database)
        elsif(@fileApiHelper.uploadCheck == 3)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "The target output path could not be found.\nEither group #{@groupName} or database #{@dbName}\nis missing.  Did you rename or delete your group or database?")
          @errUserMsg = @errInternalMsg = "The target output path could not be found.\nEither group #{@groupName} or database #{@dbName}\nis missing.  Did you rename or delete your group or database?"
          @exitCode = 40
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          raise @err     
        # Print error if something REALLY weird happened (how is @uploadCheck a value other than 2 or 3?)
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error uploading #{input}.\n@uploadCheck value is not being set correctly.\nPlease contact Genboree team.")
          @errUserMsg = @errInternalMsg = "Error uploading #{input}.\n@uploadCheck value is not being set correctly.\nPlease contact Genboree team."
          @exitCode = 41
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          raise @err
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "#{input} uploaded successfully to server")
      end
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
        # Check for java out of memory error - if this is the case, then add sample to list of redo this sample with more JAVA RAM
        cmd = "grep -i -e \"java\" -e \"exception\" #{errFile}"
        errorMessages = `#{cmd}`
        if(errorMessages =~ /error=12, Cannot allocate memory/) or (errorMessages =~ /OutOfMemoryError/)
          retVal = "redo"
          return retVal
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
              errorMessages << "\nPOSSIBLE REASON: There were no input reads available for sRNAbench analysis. It is possible that \n1. all reads were removed in the pre-processing stage (or) \n 2. the adapter sequence was not automatically identified by the pipeline, so reads were not clipped. \nAs a result, long reads ended up in the analysis and were rejected by sRNAbench.\n You can try providing the 3\' adapter sequence and redo the analysis. "
            end
          end
          if(errorMessages.strip.empty?)
            retVal = false
          else
            retVal = true
          end
        end
      end
      # Did we find anything?
      if(retVal)
        # Here, we mark the current run as failed and set its error message correspondingly
        @inputFiles[inFile][:failedRun] = true
        @errUserMsg = "smallRNA-seq Pipeline Failed.\nMessage from smallRNA-seq Pipeline:\n\""
        @errUserMsg << (errorMessages || "[No error info available from smallRNA-seq Pipeline]")
        @inputFiles[inFile][:errorMsg] = @errUserMsg
      end
      return retVal
    end

    # Submits a document to exRNA Internal KB in order to keep track of exceRpt tool usage
    # @return [nil]
    def submitToolUsageDoc()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Currently uploading tool usage doc")
      # Create KB doc for tool usage and fill it out
      toolUsage = BRL::Genboree::KB::KbDoc.new({})
      toolUsage.setPropVal("exceRpt Tool Usage", @jobId)
      toolUsage.setPropVal("exceRpt Tool Usage.Status", "Add")
      toolUsage.setPropVal("exceRpt Tool Usage.Job Date", "")
      toolUsage.setPropVal("exceRpt Tool Usage.Submitter Login", @userLogin)
      toolUsage.setPropVal("exceRpt Tool Usage.Genboree Group Name", @groupName)
      toolUsage.setPropVal("exceRpt Tool Usage.Genboree Database Name", @dbName)
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
      toolUsage.setPropVal("exceRpt Tool Usage.Platform", "Genboree Workbench")
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
      return
    end
    
############ END of methods specific to this smRNAPipeline wrapper
    
########### Email 

    # Method to send success e-mail to user
    def prepSuccessEmail()
      # Add number of input files to Job settings
      numInputFiles = @inputFiles.length
      @settings['numberOfInputFiles'] = numInputFiles
      
      ## Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
           
      ## Email object
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @userFirstName
      emailObject.userLast      = @userLastName
      emailObject.analysisName  = @analysisName
      inputsText                = buildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @jobConf['settings']
      emailObject.exitStatusCode = @exitCode
      additionalInfo = ""
      additionalInfo << "Your result files are currently being uploaded to your database.\nPlease wait for some time before attempting to download your result files.\n\n" +
                        "Result files can be found at this location in the Genboree Workbench:\n" + 
                          "|-Group: '#{@groupName}'\n" +
                            "|--Database: '#{@dbName}'\n" +
                              "|---Files\n" +
                                "|----smallRNAseqPipeline_v#{@toolVersion}\n"+
                                  "|-----#{@analysisName}\n\n"+
                        "NOTE 1:\nEach sample you submitted will have its own unique subfolder\nwhere you can find the exceRpt pipeline results for that sample.\n" +
                        "NOTE 2:\nThe file that ends in '_results_v#{@toolVersion}' is a large archive\nthat contains all the result files from the exceRpt pipeline.\nWithin that archive, the file 'sRNAbenchOutputDescription.txt' provides\na description of the various output files generated by sRNAbench.\n" +
                        "NOTE 3:\nThe file that ends in '_CORE_RESULTS_v#{@toolVersion}' is a much smaller archive\nthat contains the key result files from the exceRpt pipeline.\nThis file can be found in the 'CORE_RESULTS' subfolder\nand has been decompressed in that subfolder for your convenience.\n" +
                        "NOTE 4:\nFinally, post-processing results (created by\nthe exceRpt small RNA-seq Post-processing tool)\ncan be found in the 'postProcessedResults_v#{@toolVersion}' subfolder.\n" +
                        "==================================================================\n" +
                        "Number of files in your submission: #{numInputFiles}\n" +
                        "Number of files successfully processed: #{@successfulSamples}\n" +
                        "Number of files not successfully processed: #{@failedSamples}\n" +
                        "==================================================================\n" +                        
                        "List of files in your submission: \n"
      @inputFiles.each_key { |inFile|
        successStatus = ""
        if(@inputFiles[inFile][:failedRun])
          successStatus = "FAILED"
        else
          successStatus = "SUCCEEDED"
        end
        additionalInfo << " File: #{File.basename(inFile)} - #{successStatus}\n"
      }
      # Only print unsuccessful samples message if at least one sample was unsuccessful
      unless(numInputFiles == @successfulSamples)
        additionalInfo << "\n\nAny samples listed below were NOT processed due to an error.\n\n"
        # Here, we print all failed runs and corresponding error messages in additionalInfo
        @inputFiles.each_key { |inFile|
          if(@inputFiles[inFile][:failedRun])
            additionalInfo << "#{File.basename(inFile)} failed with the following message:\n"
            additionalInfo << "#{@inputFiles[inFile][:errorMsg]}\n"
          end
        }
      end
      emailObject.resultFileLocations = nil
      emailObject.additionalInfo = additionalInfo
      if(@suppressEmail)
        return nil
      else
        return emailObject
      end
    end
    
    # Method to send failure e-mail to user
    def prepErrorEmail()
      # Add number of input files to Job settings
      numInputFiles = @inputFiles.length
      @settings['numberOfInputFiles'] = numInputFiles
      ## Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
      
      emailErrorObject                = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailErrorObject.userFirst      = @userFirstName
      emailErrorObject.userLast       = @userLastName
      emailErrorObject.analysisName   = @analysisName
      inputsText                      = buildSectionEmailSummary(@inputs)
      emailErrorObject.inputsText     = inputsText
      outputsText                     = buildSectionEmailSummary(@outputs)
      emailErrorObject.outputsText    = outputsText
      emailErrorObject.settings       = @jobConf['settings']
      emailErrorObject.errMessage     = @errUserMsg
      emailErrorObject.exitStatusCode = @exitCode
      additionalInfo = ""
      additionalInfo << "Group name: #{@groupName}\nDatabase name: #{@dbName}\n" +
                        "Number of files in your submission: #{numInputFiles}\n" +
                        "List of files in your submission: \n"
      @inputFiles.each_key { |inFile|
        additionalInfo << " File: #{File.basename(inFile)}\n"
      }
      additionalInfo << "\n\nBelow, you can find more specific error messages for failed runs.\n" +
                        "If you do not see any information below, this means that\nthe Genboree tool failed somewhere other than the actual pipeline itself.\n\n"
      # Here, we print all failed runs and corresponding error messages in additionalInfo
      @inputFiles.each_key { |inFile|
        if(@inputFiles[inFile][:failedRun])
          additionalInfo << "#{File.basename(inFile)} failed with the following message:\n"
          additionalInfo << "#{@inputFiles[inFile][:errorMsg]}\n"
          additionalInfo << "==================================================================\n"
        end
      }        
      emailErrorObject.resultFileLocations = nil
      emailErrorObject.additionalInfo = additionalInfo
      if(@suppressEmail)
        return nil
      else
        return emailErrorObject
      end
    end
  end
end; end ; end ; end

# If we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::SmRNAPipelineWrapper)
end
