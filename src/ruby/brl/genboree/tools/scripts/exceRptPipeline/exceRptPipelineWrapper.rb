#!/usr/bin/env ruby
#########################################################
############ exceRpt batch wrapper ######################
# This wrapper is the first step in processing exceRpt #
# inputs. This wrapper loads all settings and then     #
# launches individual exceRpt jobs for each input file #
# (through runExceRpt). Next, processPipelineRuns is   #
# launched as a conditional job (when all runExceRpt   #
# jobs finish). Finally, tool usage doc / email tool   #
# is launched.                                         #
# Modules used in this pipeline:                       #
# 1. exceRptPipeline                                   #
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
  class ExceRptPipelineWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "4.6.2"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running 'exceRptPipeline' in batch-processing mode.
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
        # Getting relevant variables from "context"
        @dbrcKey = @context['apiDbrcKey']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        # Get the tool version from settings - note that this is set up by the JobHelper's cleanJobObj method!
        @toolVersion = @settings['toolVersion']
        # isBatchJob is used to indicate to future tools (runExceRpt, processPipelineRuns) that we're running a batch job
        # This is useful, for example, to let PPR know that inputs have already been downloaded and are local (as opposed to running PPR tool independently)
        @settings['isBatchJob'] = true
        # isLocalJob is used to indicate whether we need to download inputs or if they're already present locally
        @localJob = @settings['isLocalJob']
        # alreadyExtracted is used to indicate whether inputs are already extracted / sniffed / converted or not
        # This option should only be used with isLocalJob
        @filesAlreadyExtracted = @settings['filesAlreadyExtracted'] if(@localJob)
        # Settings used for final erccProcessing tool (mostly for tool usage doc)
        @settings['processingPipeline'] = "exceRpt small RNA-seq"
        @settings['processingPipelineVersion'] = @toolVersion
        @settings['processingPipelineIdAndVersion'] = "exceRptPipeline_v#{@toolVersion}"
        @settings['platform'] = "Genboree Workbench"
        # Set up anticipated data repository options
        # Cut off first two chars if anticipated data repo is 0_None - 0_ was added only for UI reasons 
        @settings['anticipatedDataRepo'] = @settings['anticipatedDataRepo'][2..-1] if(@settings['anticipatedDataRepo'] == "0_None")
        # If anticipatedDataRepo is "None", then we make sure that other data repo is nil, data repo submission is not for DCC, and dbGaP is not applicable (not sure about this last part)
        if(@settings['anticipatedDataRepo'] == "None")
          @settings['otherDataRepo'] = nil
          @settings['dataRepoSubmissionCategory'] = "Samples Not Meant for Submission to DCC"
          @settings['dbGaP'] = "Not Applicable"
        else
          # We make dbGaP option not applicable if the anticipated repo doesn't include dbGaP
          @settings['dbGaP'] = "Not Applicable" if(@settings['anticipatedDataRepo'] != "dbGaP" and @settings['anticipatedDataRepo'] != "Both GEO & dbGaP")
          # We make other data repo nil if anticipated data repo is not "Other"
          @settings['otherDataRepo'] = nil if(@settings['anticipatedDataRepo'] != "Other")
        end
        # Cut off first two chars if grant number is primary, as that means it has a prefix of 0_ (added only for UI reasons)
        @settings['grantNumber'] = @settings['grantNumber'][2..-1] if(@settings['grantNumber'].include?("Primary"))
        # Save the job ID for exceRpt so that we can use it in tool usage doc 
        @settings['primaryJobId'] = @jobId
        # This hash will store all job IDs submitted below as part of our batch submission (and will store info about input files as well)
        @listOfJobIds = {}
        # Array containing input file names
        @inputFiles = []
        # Hash which will map input file names to the predicted amount of space their outputs will take up (used in exceRpt RulesHelper to detect whether user is going over max amount of storage)
        @predictedOutputFileSizes = {}
        # Get location of the shared scratch space in the cluster
        @clusterSharedScratchDir = @genbConf.clusterSharedScratchDir
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "SHARED SCRATCH SPACE: #{@clusterSharedScratchDir}")
        if(@clusterSharedScratchDir.nil? or @clusterSharedScratchDir.empty?)
          @errUserMsg = "ERROR: Genboree config does not have the shared scratch location information."
          raise @errUserMsg
        end
        # If shared scratch space exists, then create specific directory for this exceRpt job. Also, create post-processing directory (and its runs directory for holding CORE_RESULTS archives from individual runs).
        if(File.directory?(@clusterSharedScratchDir))
          @jobSpecificSharedScratch = "#{@clusterSharedScratchDir}/#{@jobId}"
          @settings['jobSpecificSharedScratch'] = @jobSpecificSharedScratch
          @postProcDir = "#{@jobSpecificSharedScratch}/subJobsScratch/processPipelineRuns"
          @settings['postProcDir'] = @postProcDir
          runsDir = "#{@postProcDir}/runs"
          `mkdir -p #{runsDir}`
          # Create and save in settings importantJobIdsDir (will store all important job IDs - IDs reported to user in final email, IDs used to determine which samples passed/failed)
          importantJobIdsDir = "#{@jobSpecificSharedScratch}/importantJobIds"
          `mkdir -p #{importantJobIdsDir}`
          @settings['importantJobIdsDir'] = importantJobIdsDir
        else
          @errUserMsg = "ERROR: Shared scratch dir #{@clusterSharedScratchDir} is not available."
          raise @errUserMsg
        end
        # Below, we'll configure settings coming from the UI
        # Analysis name (used to identify files associated with this particular tool run)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Analysis name: #{@settings['analysisName']}")
        # 3' adapter sequence options
        # Grab adapter sequence from UI - cut off first two chars (those are just used for organizing options in the UI)
        @settings['adapterSequence'] = @settings['adapterSequence'][2..-1]
        # If adapter sequence is "autoDetect", then the user wants to auto-detect the adapter sequence
        if(@settings['adapterSequence'] == "autoDetect")
          @settings['adSeqParameter'] = 'guessKnown'
        # If adapter sequence is '"manual", then the user put in his/her own, manual adapter sequence
        elsif(@settings['adapterSequence'] == "manual")
          @settings['adSeqParameter'] = @settings['manualAdapter']
        # Otherwise, the user just selected one of the pre-decided adapter sequences, so we'll just use @settings['adapterSequence'] as our adapter sequence
        else
           # If user didn't choose other, then he/she chose an adapter sequence from the list of options in the UI.
           # That means we can just set adSeqParameter to be that value (adapterSequence)
           @settings['adSeqParameter'] = @settings['adapterSequence']
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adapter sequence parameter: #{@settings['adSeqParameter']}")
        # Random barcode options
        # If user did not check the "Random Barcodes Enabled" checkbox, then we will set the random barcode parameters such that random barcodes are not used
        unless(@settings['randomBarcodesEnabled'])
          @settings['randomBarcodeLength'] = 0
          @settings['randomBarcodeLocation'] = "-5p -3p"
          @settings['randomBarcodeStats'] = false
        end
        # Because randomBarcodeStats is a checkbox, its value will be "on" by default if it's checked, and null if it's not checked
        # We want to convert that "on"/null to true/false for the exceRpt makefile
        @settings['randomBarcodeStats'] = @settings['randomBarcodeStats'] ? true : false
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Random barcode parameters: Length: #{@settings['randomBarcodeLength']}, Location: #{@settings['randomBarcodeLocation']}, Stats Enabled: #{@settings['randomBarcodeStats']}")
        # Exogenous mapping options - cut off first two chars (those are just used for organizing options in the UI)
        @settings['exogenousMapping'] = @settings['exogenousMapping'][2..-1]
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Exogenous mapping setting: #{@settings['exogenousMapping']}")
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
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of threads for exogenous mapping: #{@settings['numThreadsExo']} ; number of tasks for exogenous mapping: #{@settings['numTasksExo']} ; number of exogenous genome mapping nodes: #{@exogenousNodes} ; max number of samples per exogenous genome mapping node: #{@maxSamplesPerExoJob}")
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of threads: #{@settings['numThreads']}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Java RAM: #{@settings['javaRam']}")
        # The type of conditional job we're submitting at the end of this wrapper is dependent upon whether we're running full exogenous mapping or not
        # If exogenousMapping=off or exogenousMapping=miRNA, then we'll submit a processPipelineRuns job. Otherwise, if exogenousMapping=on, we'll submit an exogenousSTARMapping job.
        # Also, if exogenousMapping=on, we'll create a directory in cluster.shared.scratch to store the inputs / outputs from the exogenousSTARMapping job.
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
        # Order of alignment for endogenous libraries
        # We need to convert format from the easier-to-read format in the UI to the format that exceRpt expects
        @settings['endogenousLibraryOrder'] = @settings['priorityList']
        @settings['endogenousLibraryOrder'].gsub!("Gencode", "gencode")
        @settings['endogenousLibraryOrder'].gsub!(" > ", ",")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Endogenous Library Order Settings: #{@settings['endogenousLibraryOrder']}")
        # Number of permitted endogenous mismatches - default is 1
        if(!@settings['endogenousMismatch'] or @settings['endogenousMismatch'].empty? or @settings['endogenousMismatch'].nil?)
          @settings['endogenousMismatch'] = 1
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Permitted number of endogenous mismatches: #{@settings['endogenousMismatch']}")
        # Number of permitted exogenous mismatches - default is 0
        if(!@settings['exogenousMismatch'] or @settings['exogenousMismatch'].empty? or @settings['exogenousMismatch'].nil?)
          @settings['exogenousMismatch'] = 0
        end
        if(@settings['fullExogenousMapping'])
          # This setting will keep track of which claves we map to (if user chooses to map to exogenous genomes)
          @settings['exogenousClaves'] = ["Bacteria", "FPV", "Metazoa", "Plants", "Vertebrates"]
          # We will delete entries from this default if user unchecked the associated checkbox in the Workbench UI
          @settings['exogenousClaves'].delete("Bacteria") unless(@settings['mapToBacteria'])
          @settings['exogenousClaves'].delete("FPV") unless(@settings['mapToFPV'])
          @settings['exogenousClaves'].delete("Metazoa") unless(@settings['mapToMetazoa'])
          @settings['exogenousClaves'].delete("Plants") unless(@settings['mapToPlants'])
          @settings['exogenousClaves'].delete("Vertebrates") unless(@settings['mapToVertebrates'])
        else
          @settings.delete('mapToBacteria')
          @settings.delete('mapToFPV')
          @settings.delete('mapToMetazoa')
          @settings.delete('mapToPlants')
          @settings.delete('mapToVertebrates')
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Permitted number of exogenous mismatches: #{@settings['exogenousMismatch']}")
        # There are certain settings that only apply to 4th gen. exceRpt, and certain settings that only apply to 3rd gen. exceRpt.
        if(@settings['exceRptGen'] == "fourthGen")
          # This value is the minimum base-call quality of reads. Default: 20.
          if(!@settings['minBaseCallQuality'] or @settings['minBaseCallQuality'].empty? or @settings['minBaseCallQuality'].nil?)
            @settings['minBaseCallQuality'] = 20
          end
          # This value is the percentage of the read that must meet the minimum base-call quality (found in @settings['minBaseCallQuality']). Default: 80.
          @settings['fractionForMinBaseCallQuality'] = @settings['numberField_fractionForMinBaseCallQuality']
          if(!@settings['fractionForMinBaseCallQuality'] or @settings['fractionForMinBaseCallQuality'].empty? or @settings['fractionForMinBaseCallQuality'].nil?)
            @settings['fractionForMinBaseCallQuality'] = 80
          end
          # This value will be the minimum read length we will use after adapter (and random barcode) removal. Default: 18.
          @settings['minReadLength'] = @settings['numberField_minReadLength']
          if(!@settings['minReadLength'] or @settings['minReadLength'].empty? or @settings['minReadLength'].nil?)
            @settings['minReadLength'] = 18
          end
          # This value is the minimum fraction of the read that must remain following soft-clipping (in a local alignment).
          @settings['readRemainingAfterSoftClipping'] = @settings['numberField_readRemainingAfterSoftClipping']
          if(!@settings['readRemainingAfterSoftClipping'] or @settings['readRemainingAfterSoftClipping'].empty? or @settings['readRemainingAfterSoftClipping'].nil?)
            @settings['readRemainingAfterSoftClipping'] = 0.9
          end
          # This option will trim N bases from the 3' end of every read, where N is the value you choose. Default: 0.
          @settings['trimBases3p'] = @settings['numberField_trimBases3p']
          if(!@settings['trimBases3p'] or @settings['trimBases3p'].empty? or @settings['trimBases3p'].nil?)
            @settings['trimBases3p'] = 0
          end
          # This option will trim N bases from the 5' end of every read, where N is the value you choose. Default: 0.
          @settings['trimBases5p'] = @settings['numberField_trimBases5p']
          if(!@settings['trimBases5p'] or @settings['trimBases5p'].empty? or @settings['trimBases5p'].nil?)
            @settings['trimBases5p'] = 0
          end
          @settings['minAdapterBases3p'] = @settings['numberField_minAdapterBases3p']
          if(!@settings['minAdapterBases3p'] or @settings['minAdapterBases3p'].empty? or @settings['minAdapterBases3p'].nil?)
            @settings['minAdapterBases3p'] = 7
          end
          # This setting will allow you to downsample your RNA reads after assigning reads to the various transcriptome libraries. 
          # This may be useful for normalizing very different yields.
          if(@settings['downsampleRNAReadsEnabled'])
            # You will downsample to this number of RNA reads after assigning reads to the various transcriptome libraries. 
            # There is a recommended minimum of 100,000, but any value above 0 is acceptable.
            @settings['downsampleRNAReads'] = @settings['numberField_downsampleRNAReads']
            if(!@settings['downsampleRNAReads'] or @settings['downsampleRNAReads'].empty? or @settings['downsampleRNAReads'].nil?)
              @settings['downsampleRNAReads'] = 100000
            end
          else
            @settings.delete('numberField_downsampleRNAReads')
          end
        else
          # Bowtie seed length (only used in 3rd gen. exceRpt)
          # Rename setting to remove numberField_ prefix
          @settings['bowtieSeedLength'] = @settings['numberField_bowtieSeedLength']
          if(!@settings['bowtieSeedLength'] or @settings['bowtieSeedLength'].empty? or @settings['bowtieSeedLength'].nil?)
            @settings['bowtieSeedLength'] = 19
          end
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Bowtie seed length: #{@settings['bowtieSeedLength']}")
        end
        # localExecution - exceRpt parameter which is used to specify paths for different variables the pipeline uses. Will always be false for Genboree.
        @settings['localExecution'] = "false"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Local execution: #{@settings['localExecution']}")
        # Tool ID for individual worker job runs - exceRptPipeline launches runExceRpt jobs
        @runExceRptToolId = "runExceRpt"
        @processPipelineRunsToolId = "processPipelineRuns"
        @exogenousSTARMappingToolId = "exogenousSTARMapping"
        @exogenousPPRLauncherToolId = "exogenousPPRLauncher"
        # User defined custom calibrator/spike-in libraries
        # User gives us a FASTA sequence, and then we'll generate a bowtie2 index using the "Index Bowtie" tool
        # Below, we define settings that will allow us to launch the Index Bowtie tool
        @calibratorDir = "#{@jobSpecificSharedScratch}/calibrator"
        `mkdir -p #{@calibratorDir}`
        if(@settings['useLibrary'] =~ /uploadNewLibrary/)
          @spikeInName = @settings['indexBaseName']
          @spikeInUri = @settings['newSpikeInLibrary']
          if(@spikeInName.empty? or @spikeInName.nil?)
            fileBase = @fileApiHelper.extractName(@spikeInUri)
            fileBaseName = File.basename(fileBase)
            @spikeInName = fileBaseName.makeSafeStr(:ultra)
          end
        elsif(@settings['useLibrary'] =~ /useExistingLibrary/)
          @spikeInUri = @settings['existingLibraryName']
          fileBase = @fileApiHelper.extractName(@spikeInUri)
          fileBaseName = File.basename(fileBase)
          @spikeInName = fileBaseName.makeSafeStr(:ultra)
        end
        # Make sure the genome version is supported by current implementation of the exceRpt pipeline
        unless(@settings['genomeVersion'].nil?)
          gbSmallRNASeqPipelineGenomesInfo = JSON.parse(File.read(@genbConf.gbSmallRNASeqPipelineGenomesInfo))
          indexBaseName = gbSmallRNASeqPipelineGenomesInfo[@settings['genomeVersion']]['indexBaseName']
          if(indexBaseName.nil?)
            @errUserMsg = "Your genome version #{@settings['genomeVersion']} is not currently supported by exceRpt."
            raise @errUserMsg
          else
            # @genomeBuild is used in runExceRpt job confs, so we save it as an instance variable
            @settings['genomeBuild'] = gbSmallRNASeqPipelineGenomesInfo[@settings['genomeVersion']]['genomeBuild']
          end
        end
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
        # Grab user, pass, and host for use throughout wrapper
        user = pass = host = nil
        if(@dbrcKey)
          dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
          user = dbrc.user
          pass = dbrc.password
          host = dbrc.driver.split(/:/).last
        else
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @dbrcFile)
          user = suDbDbrc.user
          pass = suDbDbrc.password
          host = suDbDbrc.driver.split(/:/).last
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "BEGIN exceRpt small RNA-seq Pipeline (version #{@toolVersion}) batch processing")
        # @sniffer will be used to make sure that files are either FASTQ or SRA
        @sniffer = BRL::Genboree::Helpers::Sniffer.new()
        # @errInputs will have: keys equal to file names and values equal to any errors associated with those file names
        @errInputs = {:emptyFiles => [], :badFormat => [], :badArchives => []}
        # @failedJobs is a hash that will keep track of which files are NOT submitted properly to runExceRpt
        # This hash will store the respective error messages for each failed sample
        @failedJobs = {}
        # Download the inputs from the server
        # @TODO: move each individual download to its own respective job? 
        # NOTICE: @filesAlreadyExtracted OPTION NOT WORKING PROPERLY FOR NOW! DO NOT USE!
        unless(@filesAlreadyExtracted)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input files from server")
          downloadFiles()
        else
          @inputFiles = @inputs.clone()
        end
        # If we didn't find any valid files, then we'll print errors below.
        if(@inputFiles.empty?)
          @errUserMsg = "We were unable to find any valid files\n(FASTQ/SRA files or archives) in your inputs\nfrom the Genboree Workbench.\nMore information can be found below if available."
        end
        # Raise an error if we came across one during our downloading / extracting of archives above
        raise @errUserMsg unless(@errUserMsg.nil?)
        # Make bowtie2 indexes of spike-in library
        if(@settings['useLibrary'] =~ /uploadNewLibrary/ or @settings['useLibrary'] =~ /useExistingLibrary/)
          # Download the custom FASTA file from user db, expand if necessary, and then sniff to ensure it is FASTA
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading spike-in library file #{@spikeInUri}.")
          downloadSpikeInFile(@spikeInUri)
          # Make bowtie2 index of this oligo library
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Making Bowtie2 index of spike-in library.")
          makeOligoBowtieIndex(@spikeInFile)
          @settings['calib'] = @oligoBowtie2BaseName
        else
          @settings['calib'] = "NULL"
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Location of calibrator is: #{@settings['calib']}")
        # Set @toolId to be runExceRpt (used when submitting worker jobs)
        @toolId = "runExceRpt"
        # conditionalJob boolean will keep track of whether any worker job was submitted (at least one runExceRpt job)
        conditionalJob = false
        # Create a reusable ApiCaller instance for launching each runExceRpt job
        apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/genboree/tool/{toolId}/job", user, pass)
        # @preConditionJobs will be used in the conditions for our processPipelineRuns job
        @preConditionJobs = []
        # If we're doing full exogenous mapping, let's figure out number of samples we're going to process per node (for exogenousSTARMapping part of pipeline)
        if(@settings['fullExogenousMapping'])
          @samplesPerExoJob = (@inputFiles.size / @exogenousNodes.to_f).ceil
          if(@samplesPerExoJob > @maxSamplesPerExoJob)
            @samplesPerExoJob = @maxSamplesPerExoJob
          end
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Samples processed per exogenous job: #{@samplesPerExoJob} (with fewer potentially samples processed for final job)")
          @exoJobIdToRunExceRptConds = {}
          @currentInputNum = 0
        end
        # Traverse all inputs
        @currentExoIndex = 0
        @inputFiles.each { |currentInput|
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input file: #{currentInput}")
          @currentExoIndex = (@currentInputNum.to_i / @samplesPerExoJob.to_i).to_i if(@settings['fullExogenousMapping'])
          # Create a job conf for the current input file 
          runExceRptJobObj = createRunExceRptJobConf(currentInput)
          begin
            # Submit job for current input file 
            $stderr.debugPuts(__FILE__, __method__, "runExceRpt job conf for #{currentInput}", JSON.pretty_generate(runExceRptJobObj))
            httpResp = apiCaller.put({ :toolId => @toolId }, runExceRptJobObj.to_json)
            # Check result
            if(apiCaller.succeeded?)
              # We succeeded in launching at least one runExceRpt job, so we set conditionalJob to be true (so that PPR will run below)
              conditionalJob = true
              $stderr.debugPuts(__FILE__, __method__, "Response to submitting runExceRpt job conf for #{currentInput}", JSON.pretty_generate(apiCaller.parseRespBody))
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "runExceRpt job accepted with analysis name: #{runExceRptJobObj['settings']['analysisName'].inspect}.\nHTTP Response: #{httpResp.inspect}\nStatus Code: #{apiCaller.apiStatusObj['statusCode'].inspect}\nStatus Message: #{apiCaller.apiStatusObj['msg'].inspect}\n\n")              
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
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Condition connected with runExceRpt job associated with #{currentInput}: #{condition.inspect}")
              if(@settings['fullExogenousMapping'])
                unless(@exoJobIdToRunExceRptConds[@currentExoIndex])
                 @exoJobIdToRunExceRptConds[@currentExoIndex] = []
                end
                @exoJobIdToRunExceRptConds[@currentExoIndex] << condition
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Condition #{condition.inspect} has been added to index #{@currentExoIndex} for @exoJobIdToRunExceRptConds")
                @currentInputNum += 1
              else
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
        # If any runExceRpt jobs were launched above, we'll launch a conditional job based on those jobs 
        if(conditionalJob)
          # If fullExogenousMapping=false, then we'll submit a processPipelineRuns conditional job
          # Otherwise, if fullExogenousMapping=true, we'll submit an exogenousSTARMapping conditional job
          if(@conditionalJobType == @processPipelineRunsToolId)
            # Submit a conditional processPipelineRuns job (will run after all worker runExceRpt jobs finish)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Submitting a conditional processPipelineRuns job (will run after all worker runExceRpt jobs finish)")
            postProcessing(host, user, pass)
          else 
            # Submit some number of conditional exogenousSTARMapping job (will run after all worker runExceRpt jobs finish)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching exogenousSTARMapping conditional jobs on the worker runExceRpt jobs")
            @exoJobIdToRunExceRptConds.each_key { |currentId|
              exogenousSTARMapping(host, user, pass, currentId, @exoJobIdToRunExceRptConds[currentId])
            }
            # We will also submit an exogenousPPRLauncher job.
            # It will be launched after all exogenousSTARMapping jobs finish.
            # The exogenousPPRLauncher job submits a PPR job to be launched after all exogenousTaxoTree jobs connected with the exogenousSTARMapping jobs finish.
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
          @errUserMsg = "None of your samples could be submitted.\nMore information will be provided below if available."
          raise @errUserMsg
        end 
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE with batch submission of exceRpt Pipeline (version #{@toolVersion}) jobs. END.") 
        # DONE exceRptPipeline batch submission
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of exceRpt Pipeline (version #{@toolVersion}) batch submission failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to run exceRpt Pipeline (version #{@toolVersion}) batch submission." if(@errInternalMsg.nil?)
        @exitCode = 30
        # Let's clean up the job-specific scratch area, since the job failed
        cleanUp([], [], @jobSpecificSharedScratch)
      end
      return @exitCode
    end

###### *****************************
###### Methods used in this workflow
###### *****************************

    # Download input files from database. Perform initial extraction (of multi-file archives) and set up file size predictions for inputs.
    # @return [nil]
    def downloadFiles()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input files using threads #{@inputs.inspect}")
      # If job is not local, then we need to download our inputs. Otherwise, our inputs will be the local file paths.
      unless(@localJob)
        uriPartition = @fileApiHelper.downloadFilesInThreads(@inputs, @userId, @jobSpecificSharedScratch)
        localPaths = uriPartition[:success].values
      else
        localPaths = @inputs
      end
      # We will traverse all of the downloaded files, one at a time.
      # We will only extract the top layer of files (the files coming directly from the Workbench).
      # We will then submit each of those files as an input for a runExceRpt job.
      # This will speed up our initial processing stage considerably.
      localPaths.each { |tmpFile|
        checkForInputs(tmpFile, tmpFile, true)
      }
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
              # Sniff file and see whether it's FASTQ, SRA, or one of our supported compression formats
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Sniffing file type of #{fixedInputFile}")
              @sniffer.filePath = fixedInputFile
              fileType = @sniffer.autoDetect()
              unless(fileType == "fastq" or fileType == "sra" or fileType == "zip" or fileType == "xz" or fileType == "tar" or fileType == "bz2" or fileType == "7z" or fileType == "gz")
                @errInputs[:badFormat] << "#{File.basename(inputFile)}\n(with original source archive #{File.basename(originalSource)})"
              else
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input file #{fixedInputFile} is in correct format, FASTQ or SRA (or an archived format that we support)")
                if(@settings['uploadFullResults'] or (@settings['uploadExogenousAlignments'] and @settings['fullExogenousMapping']))
                  dataFileSize = File.size(fixedInputFile)
                  $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Size of #{fixedInputFile} is #{dataFileSize}")
                  if(@settings['uploadFullResults'])
                    if(@settings['exogenousMapping'] == "off")
                      if(fileType == "fastq" or fileType == "sra")
                        dataFileSize *= @toolConf.getSetting('settings', 'uncompressedMultiplierExoOff').to_f
                      else
                        dataFileSize *= @toolConf.getSetting('settings', 'compressedMultiplierExoOff').to_f
                      end
                    elsif(@settings['exogenousMapping'] == "miRNA")
                      if(fileType == "fastq" or fileType == "sra")
                        dataFileSize *= @toolConf.getSetting('settings', 'uncompressedMultiplierExoMiRNA').to_f
                      else
                        dataFileSize *= @toolConf.getSetting('settings', 'compressedMultiplierExoMiRNA').to_f                
                      end
                    elsif(@settings['fullExogenousMapping'])
                      if(fileType == "fastq" or fileType == "sra")
                        dataFileSize *= @toolConf.getSetting('settings', 'uncompressedMultiplierExoOn').to_f
                      else
                        dataFileSize *= @toolConf.getSetting('settings', 'compressedMultiplierExoOn').to_f
                      end
                    end
                  elsif(@settings['uploadExogenousAlignments'] and @settings['fullExogenousMapping'])
                    if(fileType == "fastq" or fileType == "sra")
                      dataFileSize *= @toolConf.getSetting('settings', 'uncompressedMultiplierExoOnExoOnly').to_f
                    else
                      dataFileSize *= @toolConf.getSetting('settings', 'compressedMultiplierExoOnExoOnly').to_f   
                    end                    
                  end
                  dataFileSize = dataFileSize.round
                  @predictedOutputFileSizes["file://#{fixedInputFile}"] = dataFileSize
                end
                @inputFiles.push("file://#{fixedInputFile}")
              end
            end
          end
        end
      end
      return
    end
    
    # Make bowtie2 index of spike-in file
    # @param [String] spikeInFile path to spike-in file
    # @return [nil]
    def makeOligoBowtieIndex(spikeInFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Using #{spikeInFile} to make bowtie2 index.")
      @outFile = "#{@scratchDir}/indexBowtie.out"
      @errFile = "#{@scratchDir}/indexBowtie.err"
      # Build Bowtie2 index
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
      fileType = sniffer.autoDetect()
      unless(fileType == "fa" and sniffer.detect?('ascii'))
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
    
    # Method to create an exceRpt job conf file given some input file.
    # @param [String] inputFile file path to input file
    # @return [Hash] hash containing the job conf file
    def createRunExceRptJobConf(inputFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Preparing the exceRpt jobConf for #{inputFile}")
      # Reuse the existing jobConf and modify properties as needed
      runExceRptJobConf = @jobConf.deep_clone()
      # Define input for job conf
      runExceRptJobConf['inputs'] = inputFile
      # We will keep the same output database
      # Define context
      runExceRptJobConf['context']['toolIdStr'] = @runExceRptToolId
      runExceRptJobConf['context']['warningsConfirmed'] = true
      # Define settings
      if(@settings['uploadFullResults'] or (@settings['uploadExogenousAlignments'] and @settings['fullExogenousMapping']))
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Total output file size will be #{@predictedOutputFileSizes[inputFile]}")
        runExceRptJobConf['settings']['totalOutputFileSize'] = @predictedOutputFileSizes[inputFile]
      end
      runExceRptJobConf['settings']['exoJobId'] = @currentExoIndex if(@settings['fullExogenousMapping'])
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
   
    # Method to create processPipelineRuns jobFile.json used in submitPPRJob()
    # @return [nil]
    def createPPRJobConf()
      @pprJobConf = @jobConf.deep_clone()
      ## Define context
      @pprJobConf['context']['toolIdStr'] = @processPipelineRunsToolId
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
      esmJobConf['context']['toolIdStr'] = @exogenousSTARMappingToolId
      ## Define settings
      esmJobConf['settings']['exogenousMapping'] = "on"
      esmJobConf['settings']['exoJobId'] = exoJobId
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
      ## Define settings
      eplJobConf['settings']['exogenousMapping'] = "on"
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

############ END of methods specific to this exceRptPipeline wrapper
    
########### Email 
 
    # Success email
    def prepSuccessEmail()
      # Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
      # Remove settings that are unnecessary for user e-mail
      cleanUpSettingsForEmail()
      # Email object
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @userFirstName
      emailObject.userLast      = @userLastName
      emailObject.analysisName  = @settings['analysisName']
      inputsText                = buildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @jobConf['settings']
      emailObject.exitStatusCode = @exitCode
      runExceRptJobIds = @listOfJobIds.keys
      numJobsSubmitted = runExceRptJobIds.length  
      foundError = false
      @errInputs.each_value { |categoryValue| foundError = true unless(categoryValue.empty?) }
      additionalInfo = ""
      additionalInfo << "\n==================================================================\n" +
                         "NOTE 1:\n#{(@failedJobs.empty? and !foundError) ? "All" : "Some"} of your small RNA-seq samples have been submitted\nfor processing through the exceRpt analysis pipeline."
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
      if(!@failedJobs.empty? or foundError)
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
        additionalInfo << "We encountered errors when submitting some of your samples.\nPlease see a list of samples and their respective errors below:"
        @failedJobs.each_key { |currentSample|
          additionalInfo << "\n\nCurrent sample: #{File.basename(currentSample)}\n" +
                            "Error message: #{@failedJobs[currentSample]}"
        }
      end
      if(foundError)
        additionalInfo << "\n==================================================================\n"
        additionalInfo << "We #{@failedJobs.empty? ? "" : "also "}encountered some errors when processing your archives from Genboree.\n\n"
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
              additionalInfo << "#{msg}\n#{@errInputs[category].join("\n\n")}"
            end
          end
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
      cleanUpSettingsForEmail()
      # Email object
      emailErrorObject                = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailErrorObject.userFirst      = @userFirstName
      emailErrorObject.userLast       = @userLastName
      emailErrorObject.analysisName   = @settings['analysisName']
      inputsText                      = buildSectionEmailSummary(@inputs)
      emailErrorObject.inputsText     = inputsText
      outputsText                     = buildSectionEmailSummary(@outputs)
      emailErrorObject.outputsText    = outputsText
      emailErrorObject.settings       = @jobConf['settings']
      emailErrorObject.errMessage     = @errUserMsg
      emailErrorObject.exitStatusCode = @exitCode
      additionalInfo = ""
      if(@failedJobs)
        unless(@failedJobs.empty?)
          additionalInfo << "\n==================================================================\n"
          additionalInfo << "We encountered errors when processing or submitting your samples.\nPlease see a list of samples and their respective errors below:"
          @failedJobs.each_key { |currentSample|
            additionalInfo << "\n\nCurrent sample: #{File.basename(currentSample)}\n" +
                              "Error message: #{@failedJobs[currentSample]}"
          }
        end
      end
      foundError = false
      if(@errInputs)
        @errInputs.each_value { |categoryValue| foundError = true unless(categoryValue.empty?) }
        if(foundError)
          additionalInfo << "\n==================================================================\n"
          additionalInfo << "We #{@failedJobs.empty? ? "" : "also "}encountered some errors when processing your archives from Genboree.\n"
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
                additionalInfo << "#{msg}\n#{@errInputs[category].join("\n\n")}"
              end
            end
          }
        end
      end
      additionalInfo << "\n==================================================================\n" if((@failedJobs and !@failedJobs.empty?) or foundError)
      emailErrorObject.additionalInfo = additionalInfo unless(additionalInfo.empty?)
      emailErrorObject.erccTool = true
      if(@suppressEmail)
        return nil
      else
        return emailErrorObject
      end
    end

    # When we send our success or failure email, there are certain settings that we don't want to send the user (because they're not helpful, redundant, etc.).
    # @return [nil]  
    def cleanUpSettingsForEmail()
      # Delete settings related to adapter sequence depending on options chosen by user 
      @settings.delete('autoDetectAdapter') unless(@settings['adapterSequence'] == 'other')
      @settings.delete('manualAdapter') unless(@settings['adapterSequence'] == 'other' and @settings['autoDetectAdapter'] == 'no')
      @settings.delete('otherDataRepo') unless(@settings['anticipatedDataRepo'] == 'Other')
      if(@settings['adapterSequence'] == "manual")
        @settings['adapterSequence'] << " (#{@settings['adSeqParameter']})"
      end
      @settings.delete('adSeqParameter')
      # Delete misc. settings associated with endogenous library ordering
      @settings.delete('priorityList')
      # Delete misc. settings associated with calibrator, depending on which options the user has chosen
      @settings.delete('indexBaseName') unless(@settings['useLibrary'] =~ /uploadNewLibrary/)
      unless(@settings['useLibrary'] =~ /uploadNewLibrary/)
        @settings.delete('newSpikeInLibrary') 
      else
        @settings['newSpikeInLibrary'].gsub!("gbmainprod1.brl.bcmd.bcm.edu", "genboree.org")
      end
      @settings.delete('existingLibraryName') unless(@settings['useLibrary'] =~ /useExistingLibrary/)
      # Delete misc. advanced settings
      @settings.delete('remoteStorageArea') if(@settings['remoteStorageArea'] == nil)
      @settings.delete('numberField_fractionForMinBaseCallQuality')
      @settings.delete('numberField_minReadLength')
      @settings.delete('numberField_readRemainingAfterSoftClipping')
      @settings.delete('numberField_trimBases5p')
      @settings.delete('numberField_trimBases3p')
      @settings.delete('numberField_minAdapterBases3p')
      @settings.delete('numberField_downsampleRNAReads')
      @settings.delete('numberField_bowtieSeedLength')
      @settings.delete('minBaseCallQuality') if(@settings['exceRptGen'] == 'thirdGen') # We can delete minimum base-call quality if user submitted 3rd gen exceRpt job
      # Delete job-specific directory associated with exceRptPipeline job (users don't need to know our local path)
      @settings.delete('jobSpecificSharedScratch') 
      # Delete PI ID (users don't need to know this)
      @settings.delete('piID')
      # Delete Java RAM setting
      @settings.delete('javaRam')
      # Delete tool usage doc-related info
      @settings.delete('platform')
      @settings.delete('primaryJobId')
      @settings.delete('processingPipeline')
      @settings.delete('processingPipelineIdAndVersion')
      @settings.delete('processingPipelineVersion')
      # Delete random barcode-related values if user isn't using random barcodes
      unless(@settings['randomBarcodesEnabled'])
        @settings.delete('randomBarcodeLength')
        @settings.delete('randomBarcodeLocation')
        @settings.delete('randomBarcodeStats')
      end
      # Delete local path to post-processing input dir
      @settings.delete('postProcDir')
      # Delete local path to exogenous mapping inputs (only present if fullExogenousMapping=true)
      @settings.delete('exogenousMappingInputDir')
      # Delete local path to important job IDs dir
      @settings.delete('importantJobIdsDir')
      # Delete information about number of threads / tasks for exogenous mapping (used in exogenousSTARMapping wrapper)
      @settings.delete('numThreadsExo')
      @settings.delete('numTasksExo')
      # Fix up endogenous library order so that it's easier to read
      if(@settings['endogenousLibraryOrder'])
        @settings['endogenousLibraryOrder'].gsub!("gencode", "Gencode")
        @settings['endogenousLibraryOrder'].gsub!(",", " > ")
      end
      @settings.delete('totalOutputFileSize')
      @settings['exogenousMapping'] = "on" if(@settings['fullExogenousMapping'])
      @settings.delete('calib')
      @settings.delete('genomeBuild')
      @settings.delete('localExecution')
      @settings.delete('numThreads')
      @settings.delete('exogenousTaxoTreeJobIDDir')
      @settings.delete('exogenousRerunDir')
      @settings.delete('filePathToListOfExogenousJobIds')
      @settings.delete('exogenousClaves')
      @settings.delete('databaseGenomeVersion')
    end
  end

end; end ; end ; end

# If we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::ExceRptPipelineWrapper)
end
