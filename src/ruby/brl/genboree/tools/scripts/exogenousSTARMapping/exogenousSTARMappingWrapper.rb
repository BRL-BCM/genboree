#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/processUtil'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/helpers/sniffer'
require 'parallel'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class ExogenousSTARMappingWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "4.6.2"
    COMMAND_LINE_ARGS = {}
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the 'STAR exogenous mapping' tool.
                        This tool is intended to be called via exceRptPipeline ",
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
        # Set up API URI helper for processing inputs correctly in email to user
        @apiUriHelper = BRL::Genboree::REST::Helpers::ApiUriHelper.new()
        # Genboree specific "context" variables
        @dbrcKey = @context['apiDbrcKey']
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
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?) 
        # .out / .err files to log output from our STAR mapping
        @outFile = "#{@scratchDir}/exogenousSTARMapping.out"
        @errFile = "#{@scratchDir}/exogenousSTARMapping.err"
        # Add exogenousSTARMapping job ID to list of job IDs to display in final processing email
        importantJobIdsDir = @settings['importantJobIdsDir']
        newExoEntry = {@jobId => "Exogenous STAR Mapping Job"}
        File.open("#{importantJobIdsDir}/#{@jobId}.txt", 'w') { |file| file.write(JSON.pretty_generate(newExoEntry)) }
        # Grab job IDs and put them in @listOfJobIds
        @listOfJobIds = {}
        jobIdFiles = Dir.entries(importantJobIdsDir)
        jobIdFiles.delete(".")
        jobIdFiles.delete("..")
        jobIdFiles.each { |currentFile|
          jobId = JSON.parse(File.read("#{importantJobIdsDir}/#{currentFile}"))
          @listOfJobIds.merge!(jobId)
        }
        # Grab group name and database name
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
        # Set up variables coming from @settings
        @analysisName = @settings['analysisName']
        # @numThreads and @numTasks are used during the mapping process - they are set in the jobConf submitted via exceRptPipeline
        @numThreads = @settings['numThreadsExo']
        @numTasks = @settings['numTasksExo']
        # @indexDir is the local path to the STAR indices on a given high-capacity node (path is saved in STAR's module conf)
        @indexDir = ENV['STAR_GENOMES_DIR_FOR_EXCERPT']
        # @inputDir is where we can find the input files associated with our different samples (one input file per sample)
        # IMPORTANT NOTE: inputs are stored in cluster.shared.scratch area, but OUTPUTS will be stored in node's local scratch area
        @inputDir = "#{@settings['exogenousMappingInputDir']}/#{@settings['exoJobId']}"
        # @paramsForSTAR contains various parameters used during the STAR mapping process (path is saved in STAR's module conf)
        @paramsForSTAR = ENV['STAR_PARAMETERS_FOR_EXCERPT']
        # Grab exogenous input files to display in email
        @inputs = []
        @listOfJobIds.each_key { |currentJob|
          if(currentJob.include?("runExceRpt"))
            @inputs << "file:///#{@listOfJobIds[currentJob]}" unless(@inputs.include?("file:///#{@listOfJobIds[currentJob]}"))
          end
        }
        # Get the tool version of exogenousSTARMapping from toolConf
        @toolVersion = @toolConf.getSetting('info', 'version')
        @settings['toolVersion'] = @toolVersion
        # STAR Mapping params
        # This is some setting for STAR mapping that is fixed by the makefile at 0.3.
        # TODO: Make this setting more dynamic (put it in tool .conf file, maybe?)
        @STAR_outFilterMismatchNoverLmax = 0.3
        @starExogenousParams = "--outSAMtype BAM Unsorted --outSAMattributes Standard --alignEndsType EndToEnd --outFilterMatchNmin #{@settings['minReadLength']} --outFilterMatchNminOverLread 1.0 --outFilterMismatchNmax #{@settings['exogenousMismatch']} --outFilterMismatchNoverLmax #{@STAR_outFilterMismatchNoverLmax}"
        # Grab exogenous claves
        # If, for some reason, @settings['exogenousClaves'] wasn't set, then we will just set it to be the default value (and map to everything)
        if(@settings['exogenousClaves'])
          @exogenousClaves = @settings['exogenousClaves']
        else
          @exogenousClaves = ["Bacteria", "FPV", "Metazoa", "Plants", "Vertebrates"] unless(@exogenousClaves)
        end
        # Post-processing directory
        @postProcDir = @settings['postProcDir']
        # FTP-related variables
        @isFTPJob = @settings['isFTPJob']
        @finishedFtpDir = @settings['finishedFtpDir'] if(@settings['isFTPJob'])
        @isRemoteStorage = true if(@settings['virtualFTPArea'] or @settings['remoteStorageArea'])
        if(@isRemoteStorage)
          if(@settings['virtualFTPArea'])
            @remoteStorageArea = @settings['virtualFTPArea']
          else
            @remoteStorageArea = @settings['remoteStorageArea']
          end
        end
        @subUserId = @settings['subUserId']
        @subUserId = @userId unless(@subUserId)
        # Tool ID for individual worker job runs - exogenousSTARMapping launches exogenousTaxoTree jobs
        @exogenousTaxoTreeToolId = "exogenousTaxoTree"
        # Create exogenous taxonomy tree dir (for that part of the exogenous mapping process)
        # We create each taxonomy tree in its own exogenousTaxoTree job, thus parallelizing the processing of samples (as opposed to serially going through each sample in this wrapper)
        `mkdir -p #{@settings['jobSpecificSharedScratch']}/exogenousTaxoTrees`
        # We'll save our list of exogenousTaxoTree job IDs on disk as a text file - we'll use that list for our exogenousPPRLauncher job
        @listOfExogenousTaxoTreeJobIds = {}
        @exogenousTaxoTreeJobIDDir = @settings['exogenousTaxoTreeJobIDDir']
        # @preConditionJobs will be used in the conditions for our processPipelineRuns job
        @preConditionJobs = []
        # @failedJobs is a hash that will keep track of which files are NOT submitted properly to exogenousTaxoTree
        # This hash will store the respective error messages for each failed sample
        @failedJobs = {}
        # Save info about viruses (Genbank ID -> Species Name) in @virusIDToSpeciesHash
        toolConfExogenousTaxoTree = BRL::Genboree::Tools::ToolConf.new('exogenousTaxoTree', @genbConf)
        @virusIDToSpeciesTable = File.read(toolConfExogenousTaxoTree.getSetting('settings', 'virusIDToSpeciesTable'))
        @virusIDToSpeciesHash = {}
        @virusIDToSpeciesTable.each_line { |currentLine|
          virusID = currentLine.split("\t")[0]
          species = currentLine.split("\t")[1]
          @virusIDToSpeciesHash[virusID] = species
        }
        potentialRerunFiles = Dir.entries(@inputDir) rescue nil
        unless(potentialRerunFiles)
          @errUserMsg = "There are no valid inputs.\nMost likely, a batch exceRpt pipeline job was run, but there were no successful result files generated."
          raise @errUserMsg
        end
        potentialRerunFiles.delete(".") 
        potentialRerunFiles.delete("..")
        sniffer = BRL::Genboree::Helpers::Sniffer.new()
        @rerunFiles = []
        potentialRerunFiles.each { |currentFile|
          fullPath = "#{@inputDir}/#{currentFile}"
          sniffer.filePath = fullPath
          if(sniffer.detect?("fastq") or sniffer.detect?("sra"))
            @rerunFiles << "file://#{fullPath}"
          end
        }
        # We will re-launch runExceRpt jobs for samples that failed (using more memory), and we will launch a new conditional exogenousSTARMapping job with those job IDs included.
        unless(@rerunFiles.empty?)
          # preconditionJobsForRerunningJob will hold all of the job IDs that need to finish in order for this tool (exogenousSTARMapping) to re-run.
          preconditionJobsForRerunningJob = []
          @runExceRptToolId = "runExceRpt"
          @esmToolId = @toolConf.getSetting('info', 'idStr')
          @failedRerunJobs = {}
          conditionalJob = false
          # Create a reusable ApiCaller instance for launching each runExceRpt job
          apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/genboree/tool/{toolId}/job", user, pass)
          # Now, we will submit a job for each of the files that needs to be re-run.
          # We will also add a condition for each job into our preconditionJobsForRerunningJob array. Note that met will be set to false for these conditions (since the jobs haven't run yet!)
          @rerunFiles.each { |currentInput|
            runExceRptJobObj = createRunExceRptJobConf(currentInput)
            begin
              # Submit job for current input file 
              $stderr.debugPuts(__FILE__, __method__, "runExceRpt job conf for #{currentInput}", JSON.pretty_generate(runExceRptJobObj))
              httpResp = apiCaller.put({ :toolId => @runExceRptToolId }, runExceRptJobObj.to_json)
              # Check result
              if(apiCaller.succeeded?)
                # We succeeded in launching at least one runExceRpt job, so we set conditionalJob to be true (so that PPR will run below)
                conditionalJob = true
                $stderr.debugPuts(__FILE__, __method__, "Response to submitting runExceRpt job conf for #{currentInput}", JSON.pretty_generate(apiCaller.parseRespBody))
                # We'll grab its job ID
                runExceRptJobId = apiCaller.parseRespBody['data']['text']
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
                # We'll add that condition to our preconditionJobsForRerunningJob array
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Condition connected with runExceRpt job associated with #{runExceRptJobObj['inputs']}: #{condition.inspect}")
                preconditionJobsForRerunningJob << condition
              else
                $stderr.debugPuts(__FILE__, __method__, "ERROR (BUT CONTINUING)", "#{@runExceRptToolId} job submission failed! HTTP Response Object: #{httpResp.class}.\nResponse Payload:\n#{apiCaller.respBody}\n#{'='*80}\n")
                @failedRerunJobs[File.basename(runExceRptJobObj['inputs'])] = apiCaller.respBody
              end
            rescue => err
              $stderr.debugPuts(__FILE__, __method__, "ERROR (BUT CONTINUING)", "Error raised while submitting the runExceRpt job #{runExceRptJobObj.inspect}: #{err.message.inspect}.\n#{err.backtrace.join("\n")}")
              @failedRerunJobs[File.basename(runExceRptJobObj['inputs'])] = err.message.inspect
            end
          }
          # If a worker job was successfully launched, then we will launch our exogenousSTARMapping job again.
          if(conditionalJob)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Submitting a conditional exogenousSTARMapping job for all samples that need to be rerun (will run after all worker runExceRpt jobs finish)")
            exogenousSTARMapping(host, user, pass, preconditionJobsForRerunningJob)
          end
          # Now that we've re-launched our worker runExceRpt jobs and our PPR job, we will cancel this job by raising an error with exit code 15 (reserved for cancellation)
          @errUserMsg = "At least some of your samples failed processing through exceRpt,\nlikely due to insufficient memory.\nWe will re-run those failed samples with more memory.\nAfter those samples are re-run, we will run this job again.\n"
          @rerunFiles.map! { |currentInput| File.basename(currentInput) }
          @errUserMsg << "The samples that failed processing are the following:\n\n#{@rerunFiles.join("\n")}"
          @exitCode = 15
          raise @errUserMsg
        end
        # Do we have any input files? If not, let's raise an error
        numberOfInputs = Dir["#{@inputDir}/sample_*"].length
        if(numberOfInputs == 0)
          @errUserMsg = "There are no valid inputs.\nMost likely, a batch exceRpt pipeline job was run, but there were no successful result files generated."
          raise @errUserMsg
        end
      # If we have any errors above, we will return an @exitCode of 22 (unless we're rerunning samples) and give an informative message for the user.
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error with processJobConf: #{err}")
        @errUserMsg = "ERROR: Could not set up required variables for running job." if(@errUserMsg.nil?)
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Backtrace: #{@errBacktrace}")
        @exitCode = 22 if(@exitCode == 0)
      end
      return @exitCode
    end

    # Runs the script
    # [+returns+] nil
    def run()
      begin
        # Get data
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
        # Grab list of all STAR indices
        allSTARindices = Dir.entries(@indexDir)
        # Grab list of all input files that will be processed (each input file will have its own directory) and print number of input files
        allInputFiles = Dir["#{@inputDir}/sample_*"]
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of input files: #{allInputFiles.length}")
        # Because we can't process every sample at the same time safely, we'll cut the samples into chunks of 50
        allInputFiles = allInputFiles.each_slice(50).to_a
        allInputFiles.each { |currentChunkOfInputFiles|
          # Grab number of input files that will be processed in chunk
          numInputFilesInChunk = currentChunkOfInputFiles.length
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Number of input files in current chunk: #{numInputFilesInChunk}")
          # Traverse each STAR index, one at a time
          allSTARindices.each { |starIndexDir|
            # Skip "." and ".." (not real index directories)
            next if(starIndexDir == "." or starIndexDir == "..")
            next if(starIndexDir.include?("BACTERIA") and !@exogenousClaves.include?("Bacteria"))
            next if(starIndexDir.include?("FUNGI_PROTIST_VIRUS") and !@exogenousClaves.include?("FPV"))
            next if(starIndexDir.include?("METAZOA") and !@exogenousClaves.include?("Metazoa"))
            next if(starIndexDir.include?("PLANTS") and !@exogenousClaves.include?("Plants"))
            next if(starIndexDir.include?("VERTEBRATE") and !@exogenousClaves.include?("Vertebrates"))
            # Grab full directory path for current STAR index
            fullIndexDirPath = "#{@indexDir}/#{starIndexDir}"
            # As a safety precaution, let's make doubly sure that we're looking at a STAR index dir.
            # All STAR index dirs begin with STAR_GENOME_, followed by some description of the genome (BACTERIA1, VERTEBRATE2, etc.).
            # Thus, if our path is indeed a directory, and also begins with STAR_GENOME_, then we can proceed.
            # We'll also save the identifier for that genome (BACTERIA1, VERTEBRATE2, etc.) in indexID.
            # Otherwise, if the criteria aren't met, we'll proceed to the next file / directory.
            if(File.directory?(fullIndexDirPath) and starIndexDir =~ /STAR_GENOME_(.*)/)
              indexID = $1
            else
              next
            end
            # We add an underscore because it makes the generated files have easier to read names (BACTERIA8_Aligned.out.bam versus BACTERIA8Aligned.out.bam)
            indexID = "#{indexID}_"
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "INDEX ID is #{indexID} and INDEX DIR: #{fullIndexDirPath}")
            # We keep track of which file we're on in order to accurately report pids for parent / child processes
            fileCount = 1
            # Traverse all input file directories in current chunk (remember that there is one input file per directory)
            currentChunkOfInputFiles.each { |inputFileDir|
              # All sample directories should be prefaced with "sample_" - otherwise, we'll ignore the current entry
              if(File.directory?("#{inputFileDir}") and inputFileDir =~ /^.*\/(sample_.*)$/)
                # We grab the name of the directory and save it in sampleID
                sampleID = $1
                # Each sample will have its own output directory for the STAR mapping
                @outputDir = "#{@scratchDir}/#{sampleID}/EXOGENOUS_genomes"
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "INPUT DIR: #{inputFileDir}\nOUTPUT DIR: #{@outputDir}")
                # Create output dir for current sample
                `mkdir -p #{@outputDir}`
                # @inputFile will store the path to the actual file that will be used as input for STAR mapping
                # This file should have been put into place by the sample's runExceRpt job
                @inputFile = "#{inputFileDir}/EXOGENOUS_rRNA/unaligned.fq.gz"
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "INPUT FILE: #{@inputFile}")
                # Now, we'll check to see if that input file is actually present. If it's not, we'll raise an error (how did this happen?)
                if(File.exists?(@inputFile))
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "File Count : #{fileCount}; Input File: #{@inputFile} exists!!")
                  # Set MALLOC_CHECK_ env variable to 0 so the glibc double free corruption warnings are silently ignored from STAR command
                  ENV['MALLOC_CHECK_'] = "0"
                  # Below, we see the actual STAR command.
                  # IMPORTANT: The option LoadAndKeep will load the genome index and keep the index in memory for future runs
                  command = "STAR --genomeLoad LoadAndKeep --runThreadN #{@numThreads} --outFileNamePrefix #{@outputDir}/#{indexID} --genomeDir #{fullIndexDirPath} --readFilesIn #{@inputFile} --parametersFiles #{@paramsForSTAR} #{@starExogenousParams} 1>>#{@outFile} 2>>#{@errFile}"
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "\n********\n********\nLaunching STAR command: #{command}\n********\n********\n")
                  # We will launch our command using POpen4.
                  # POpen4 allows us to run the command, get the associated pid, and do any other necessary checks while the command is runnning
                  exitStatus = POpen4::popen4(command) { |stdout, stderr, stdin, pid|
                    $stderr.debugPuts(__FILE__, __method__, "STATUS", "PID of parent process: #{pid}\n******\n")
                    # Grab child pid via processUtil
                    childPid = BRL::Util::ProcessUtil.childPidByPpid(pid)
                    $stderr.debugPuts(__FILE__, __method__, "STATUS", "child Pid is: #{childPid.inspect}")
                    # Sleep for a second to allow IPCS to update
                    sleep(1)
                    # If fileCount is 1, then the current child pid is associated with loading the current index into memory (should stay the same with all samples for the current index)
                    # Otherwise, if fileCount is greater than 1, the index was loaded by a previous (child) process!
                    if(fileCount == 1)
                      @indexLoadPid = childPid[0]
                      ipcInfoForPid = BRL::Util::ProcessUtil.ipcShmsByPid(@indexLoadPid)
                      # Traverse each line of IPC info output and write shared memory IDs to file (first token on each line)
                      ipcInfoForPid.each_line { |currentLine|
                        File.open("#{@scratchDir}/listOfShmids.log", 'a') { |file| file.write("#{currentLine.split("\s")[0]}\n") }
                      }
                    end
                    $stderr.debugPuts(__FILE__, __method__, "STATUS", "PID of child STAR process that loaded the genome index #{indexID}: #{@indexLoadPid}")
                    # Check whether @indexLoadPid matches with ipcs output
                    unless(BRL::Util::ProcessUtil.ipcShmsByPid(@indexLoadPid).empty?)
                      ipcsOutput = BRL::Util::ProcessUtil.ipcShmsByPid(@indexLoadPid)
                      $stderr.debugPuts(__FILE__, __method__, "STATUS", "PID of the first STAR process that loaded the genome index #{indexID}: #{@indexLoadPid} matches with ipcs output:\n#{ipcsOutput}")
                    else
                      $stderr.debugPuts(__FILE__, __method__, "STATUS", "PID of the first STAR process that loaded the genome index #{indexID}: #{@indexLoadPid} does not match with ipcs output. Please check!")
                    end
                  }
                  # The STAR mapping command has finished for the current sample / index
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "exceRpt Exogenous STAR Mapping tool command completed with exit code: #{exitStatus}")
                  # Check to see whether command finished successfully
                  foundErrorInExogenousSTARMapping = findError(exitStatus)
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error occurred? : #{foundErrorInExogenousSTARMapping}")
                  unless(foundErrorInExogenousSTARMapping)
                    # Delete all files other than .bam files associated with current index ID (we don't need them for anything else)
                    outputFiles = Dir.entries(@outputDir)
                    outputFiles.delete(".")
                    outputFiles.delete("..")
                    outputFiles.each { |currentFile|
                      `rm -rf #{@outputDir}/#{currentFile}` unless(currentFile =~ /.bam$/)
                    }
                    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current contents of output directory: #{Dir.entries(@outputDir)}")                  
                    # We'll increment fileCount as well, since we're moving onto the next sample
                    fileCount += 1
                  else
                    @exitCode = 31
                    raise @errUserMsg
                  end
                  # If fileCount is larger than numInputFilesInChunk, that means that we've processed all of our samples for the current index
                  # We can now remove the current index from memory by launching a different STAR command
                  if(fileCount > numInputFilesInChunk)
                    # Below, we see the STAR command referenced above.
                    # IMPORTANT: The option Remove for the --genomeLoad parameter will remove the current index from memory
                    command = "STAR --genomeLoad Remove --runThreadN #{@numThreads} --outFileNamePrefix #{@outputDir}/REMOVE_#{indexID} --genomeDir #{fullIndexDirPath} --readFilesIn #{@inputFile} #{@starExogenousParams} 1>>#{@outFile} 2>>#{@errFile}"         
                    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching Remove loaded index command: #{command}")
                    # Launch the STAR command using POpen4
                    exitStatus = POpen4::popen4(command) { |stdout, stderr, stdin, pid|
                      # Check if the index was removed completely from memory
                      # Keep polling if the indexLoadPid is still in use - i.e. ipcs -p output will have the original shared process id
                      # We are looking for the shared memory to be free - i.e. the index is completely removed from memory, and the original
                      # process that loaded the index will no longer appear in ipcs output so ipcs output should be empty
                      unless(BRL::Util::ProcessUtil.ipcShmsByPid(@indexLoadPid).empty?)
                        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Waiting for genome to be completely removed from memory and all shared segments are released.\nChecking ipcs output for original STAR pid #{@indexLoadPid}.\n IPCS Output: #{BRL::Util::ProcessUtil.ipcShmsByPid(@indexLoadPid)}")
                        sleep(1)
                      end
                    }
                    $stderr.debugPuts(__FILE__, __method__, "STATUS", "STAR command completed with exit code: #{exitStatus}")
                    # Check to see whether STAR command (which removed index from memory) had any errors
                    foundErrorInExogenousSTARMapping = findError(exitStatus)
                    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error occurred? : #{foundErrorInExogenousSTARMapping}")
                    unless(foundErrorInExogenousSTARMapping)
                      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully removed genome index completely from memory: #{indexID}")
                      # Delete the REMOVE_ files generated by the above command
                      outputFiles = Dir.entries(@outputDir)
                      outputFiles.delete(".")
                      outputFiles.delete("..")
                      outputFiles.each { |currentFile|
                        `rm -rf #{@outputDir}/#{currentFile}` if(currentFile =~ /REMOVE_/)
                      }
                      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current contents of output directory: #{Dir.entries(@outputDir)}")       
                    else
                      @exitCode = 32
                      raise @errUserMsg
                    end
                    # Sleep for 2 seconds just to make sure that previous commands are completely out of memory
                    sleep(2)
                  end
                else
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "INPUT FILE: #{@inputFile} does not exist!")
                  @errUserMsg = "We wanted to use #{@inputFile} as input for exogenous genomic alignment, but it didn't exist."
                  @exitCode = 33
                  raise @errUserMsg
                end
              end
            }
          }
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current contents of output directory: #{Dir.entries(@outputDir)}") rescue nil      
          # At this point, we've traversed every index and have completed all of the STAR alignments for exogenous genomes.
          # Our final step is to combine and produce alignment summaries for each category of genome (bacteria, vertebrate, etc.) for each sample in our chunk.
          # We will be traversing every input file directory (each directory corresponding to a sample)
          currentChunkOfInputFiles.each { |inputFileDir|
            # If the current entry is a directory and its name contains the "sample_" prefix, then we know that we're looking at an actual sample directory.
            if(File.directory?(inputFileDir) and inputFileDir =~ /^.*\/(sample_.*)$/)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "START: Combining the results of all exogenous GENOMES for input sample: #{inputFileDir}")
              # Grab sampleID from above regular expression
              sampleID = $1
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Working with input sample #{sampleID}")
              # Grab full path of original input file (used for STAR mapping) - we will insert read count info for exogenous genomes into .stats file held inside of this archive
              @inputFile = "#{inputFileDir}/EXOGENOUS_rRNA/unaligned.fq.gz"
              # Grab full path of output directory (used by STAR mapping) - we need to read the output files in order to generate our alignment summaries
              @outputDir = "#{@scratchDir}/#{sampleID}/EXOGENOUS_genomes"
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current contents of output directory: #{Dir.entries(@outputDir)}")
              # BACTERIA
              if(@exogenousClaves.include?("Bacteria"))
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Combine alignments from Bacteria for sample #{sampleID}")
                # Grab list of all bacteria-related .bam files
                allBacteria = Dir["#{@outputDir}/BACTERIA*.bam"]
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current contents of output directory: #{Dir.entries(@outputDir)}")
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current bacteria BAM files: #{allBacteria}")
                # Use the parallel gem to convert bacteria .bam files to .sam files
                Parallel.map(allBacteria, :in_threads => @numTasks) { |alignmentBam|
                  tmpSamSummaryFile = alignmentBam.clone().gsub(/bam/,"sam.summary.tmp")
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Working with file #{alignmentBam}; Writing to output file #{tmpSamSummaryFile}")
                  `samtools view -@ #{@numThreads} #{alignmentBam} | cut -d $'\t' -f 1,3,4,6,10 | uniq | perl -ne '$_ =~ /^(\\S+)\\s([^\\$]+)\\$\\S+\\$[^:]+:[^:]+:([^:]+)\\S+\\s+(.+)/ ; print "$1\tBacteria\t$2\t$3\t$4\n" ' | sort -k1,1 >> #{tmpSamSummaryFile}`
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Command completed with exit code: #{$?.exitstatus}")
                }
                # We can go ahead and delete all the bacteria .bam files since we're done with them
                allBacteria.each { |currentBamFile|
                  `rm -f #{currentBamFile}`
                }
                # Sort all bacteria .sam files by time and then combine them into one summary file)
                `sort -m #{@outputDir}/BACTERIA*.sam.summary.tmp > #{@outputDir}/Bacteria_Aligned.out.sam.summary`
                # We can go ahead and delete all the bacteria .sam.summary.tmp files since we're done with them
                allBacteria = Dir["#{@outputDir}/BACTERIA*.sam.summary.tmp"]
                allBacteria.each { |currentTmpFile|
                  `rm -f #{currentTmpFile}`
                }
              end
              # PLANTS
              if(@exogenousClaves.include?("Plants"))
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Combine alignments from Plants for sample #{sampleID}")
                # Grab list of all plant-related .bam files 
                allPlants = Dir["#{@outputDir}/PLANTS*.bam"]
                # Use the parallel gem to convert plant .bam files to .sam files
                Parallel.map(allPlants, :in_threads => @numTasks) { |alignmentBam|
                  tmpSamSummaryFile = alignmentBam.clone().gsub(/bam/,"sam.summary.tmp")
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Working with file #{alignmentBam}")
                  `samtools view -@ #{@numThreads} #{alignmentBam} | cut -d $'\t' -f 1,3,4,6,10 | uniq | perl -ne '$_ =~ /^(\\S+)\\s([^:]+):([^:]+):([^:]+)\\s+(.+)/ ; print "$1\t$2\t$3\t$4\t$5\n" ' | sort -k1,1 >> #{tmpSamSummaryFile}`
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Command completed with exit code: #{$?.exitstatus}")
                }
                # We can go ahead and delete all the plant .bam files since we're done with them
                allPlants.each { |currentBamFile|
                  `rm -f #{currentBamFile}`
                }
                # Sort all plant .sam files by time and then combine them into one summary file
                `sort -m #{@outputDir}/PLANTS*.sam.summary.tmp > #{@outputDir}/Plants_Aligned.out.sam.summary`
                # We can go ahead and delete all the plant .sam.summary.tmp files since we're done with them
                allPlants = Dir["#{@outputDir}/PLANTS*.sam.summary.tmp"]
                allPlants.each { |currentTmpFile|
                  `rm -f #{currentTmpFile}`
                }
              end
              # FUNGI / PROTISTS / VIRUSES
              if(@exogenousClaves.include?("FPV"))
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Combine alignments from Fungi, Protists, Viruses for sample #{sampleID}")
                # Grab list of all fungus/protist/virus .bam files
                allFPV = Dir["#{@outputDir}/FUNGI_PROTIST_VIRUS*.bam"]
                # Use the parallel gem to convert fungus/protist/virus .bam files to .sam files - only one of each kind of file, so don't need to create a summary file
                Parallel.map(allFPV, :in_threads => @numTasks) { |alignmentBam|
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Working with file #{alignmentBam}")
                  `samtools view -@ #{@numThreads} #{alignmentBam} | grep "Virus:" | cut -d $'\t' -f 1,3,4,6,10 | uniq | perl -ne '$_ =~ /^(\\S+)\\s+([^:]+):\\S+\\|([^\\|]+)\\|\\S+\\|([^\\|]+)\\|\\s+(.+)/ ; print "$1\t$2\t$3\t$4\t$5\n" ' | sort -k1,1 >> #{@outputDir}/Virus_Aligned.out.sam.summary`
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Command completed with exit code: #{$?.exitstatus}")
                  `samtools view -@ #{@numThreads} #{alignmentBam} | grep "Fungi:" | cut -d $'\t' -f 1,3,4,6,10 | uniq | perl -ne '$_ =~ /^(\\S+)\\s([^:]+):([^:]+):([^:]+)\\s+(.+)/ ; print "$1\t$2\t$3\t$4\t$5\n" ' | sort -k1,1 >> #{@outputDir}/Fungi_Aligned.out.sam.summary`
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Command completed with exit code: #{$?.exitstatus}")
                  `samtools view -@ #{@numThreads} #{alignmentBam} | grep "Protist:" | cut -d $'\t' -f 1,3,4,6,10 | uniq | perl -ne '$_ =~ /^(\\S+)\\s([^:]+):([^:]+):([^:]+)\\s+(.+)/ ; print "$1\t$2\t$3\t$4\t$5\n" ' | sort -k1,1 >> #{@outputDir}/Protist_Aligned.out.sam.summary`
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Command completed with exit code: #{$?.exitstatus}")
                }
                # We can go ahead and delete all the FPV .bam files since we're done with them
                allFPV.each { |currentBamFile|
                  `rm -f #{currentBamFile}`
                }
                # There's currently a bug in our virus indices (or in how exceRpt handles them?), so we need to add species names manually.
                virusInputs = File.open("#{@outputDir}/Virus_Aligned.out.sam.summary", 'r')
                outputFile = File.open("#{@outputDir}/Virus_Aligned.out.sam.summary.FIXED", 'w')
                virusInputs.each_line { |currentLine|
                  currentLineSplit = currentLine.split("\t")
                  virusID = currentLineSplit[2]
                  species = @virusIDToSpeciesHash[virusID]
                  unless(species.nil?)
                    currentLineSplit[2] = species.chomp()
                  else
                    currentLineSplit[2] = "#{virusID} (not used in taxonomy tree because GenBank ID is deprecated or associated with removed record)"
                  end
                  currentLine = currentLineSplit.join("\t")
                  outputFile.write(currentLine)
                }
                virusInputs.close()
                outputFile.close()
                `mv #{@outputDir}/Virus_Aligned.out.sam.summary.FIXED #{@outputDir}/Virus_Aligned.out.sam.summary`
              end
              # VERTEBRATES
              if(@exogenousClaves.include?("Vertebrates"))
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Combine alignments from Vertebrates for sample #{sampleID}")
                # Grab list of all vertebrate .bam files
                allVertebrates = Dir["#{@outputDir}/VERTEBRATE*.bam"]
                # Use the parallel gem to convert vertebrate .bam files to .sam files
                Parallel.map(allVertebrates, :in_threads => @numTasks) { |alignmentBam|
                  tmpSamSummaryFile = alignmentBam.clone().gsub(/bam/,"sam.summary.tmp")
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Working with file #{alignmentBam}")
                  `samtools view -@ #{@numThreads} #{alignmentBam} | cut -d $'\t' -f 1,3,4,6,10 | uniq | perl -ne '$_ =~ /^(\\S+)\\s([^:]+):([^:]+):([^:]+)\\s+(.+)/ ; print "$1\t$2\t$3\t$4\t$5\n" ' | sort -k1,1 >> #{tmpSamSummaryFile}`
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Command completed with exit code: #{$?.exitstatus}")
                }
                # We can go ahead and delete all the vertebrate .bam files since we're done with them
                allVertebrates.each { |currentBamFile|
                  `rm -f #{currentBamFile}`
                }
                # Sort all vertebrate .sam files by time and then combine them into one summary file
                `sort -m #{@outputDir}/VERTEBRATE*.sam.summary.tmp > #{@outputDir}/Vertebrate_Aligned.out.sam.summary`
                # We can go ahead and delete all the vertebrate .sam.summary.tmp files since we're done with them
                allVertebrates = Dir["#{@outputDir}/VERTEBRATE*.sam.summary.tmp"]
                allVertebrates.each { |currentTmpFile|
                  `rm -f #{currentTmpFile}`
                }
              end
              # METAZOA
              if(@exogenousClaves.include?("Metazoa"))
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Combine alignments from Metazoa for sample #{sampleID}")
                # Grab list of all metazoa .bam files
                allMetazoa = Dir["#{@outputDir}/METAZOA*.bam"]
                # Use the parallel gem to convert metazoa .bam files to .sam files
                Parallel.map(allMetazoa, :in_threads => @numTasks) { |alignmentBam|
                  tmpSamSummaryFile = alignmentBam.clone().gsub(/bam/,"sam.summary.tmp")
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Working with file #{alignmentBam}")
                  `samtools view -@ #{@numThreads} #{alignmentBam} | cut -d $'\t' -f 1,3,4,6,10 | uniq | perl -ne '$_ =~ /^(\\S+)\\s([^:]+):([^:]+):([^:]+)\\s+(.+)/ ; print "$1\t$2\t$3\t$4\t$5\n" ' | sort -k1,1 >> #{tmpSamSummaryFile}`
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Command completed with exit code: #{$?.exitstatus}")
                }
                # We can go ahead and delete all the metazoa .bam files since we're done with them
                allMetazoa.each { |currentBamFile|
                  `rm -f #{currentBamFile}`
                }
                # Sort all metazoa .sam files by time and then combine them into one summary file
                `sort -m #{@outputDir}/METAZOA*.sam.summary.tmp > #{@outputDir}/Metazoa_Aligned.out.sam.summary`
                # We can go ahead and delete all the metazoa .sam.summary.tmp files since we're done with them
                allMetazoa = Dir["#{@outputDir}/METAZOA*.sam.summary.tmp"]
                allMetazoa.each { |currentTmpFile|
                  `rm -f #{currentTmpFile}`
                }
              end
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Collate and sort all summaries to produce a single exogenous alignment result file for sample #{sampleID}")
              sortString = ""
              sortString << " #{@outputDir}/Bacteria_Aligned.out.sam.summary" if(File.exist?("#{@outputDir}/Bacteria_Aligned.out.sam.summary"))
              sortString << " #{@outputDir}/Plants_Aligned.out.sam.summary" if(File.exist?("#{@outputDir}/Plants_Aligned.out.sam.summary"))
              sortString << " #{@outputDir}/Virus_Aligned.out.sam.summary" if(File.exist?("#{@outputDir}/Virus_Aligned.out.sam.summary"))
              sortString << " #{@outputDir}/Fungi_Aligned.out.sam.summary" if(File.exist?("#{@outputDir}/Fungi_Aligned.out.sam.summary"))
              sortString << " #{@outputDir}/Protist_Aligned.out.sam.summary" if(File.exist?("#{@outputDir}/Protist_Aligned.out.sam.summary"))
              sortString << " #{@outputDir}/Vertebrate_Aligned.out.sam.summary" if(File.exist?("#{@outputDir}/Vertebrate_Aligned.out.sam.summary"))
              sortString << " #{@outputDir}/Metazoa_Aligned.out.sam.summary" if(File.exist?("#{@outputDir}/Metazoa_Aligned.out.sam.summary"))
              `sort -m#{sortString} > #{@outputDir}/ExogenousGenomicAlignments.txt`
              # Delete all individual summaries (we don't need them anymore since we have the overall summary)
              allSummaries = Dir["#{@outputDir}/*.sam.summary"]
              allSummaries.each { |currentSummary|
                  `rm -f #{currentSummary}`
              }
              remainingFiles = `ls -art #{@outputDir}`
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Finished combining the results of all exogenous GENOMES for input #{sampleID}")
              # Now, we're going to write the exogenous alignment read counts to the sample's .stats file
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Write to stats file for sample #{sampleID}")
              # Write read count for "input_to_exogenous_genomes" field in .stats file
              `gunzip -c #{@inputFile} | wc -l | awk '{print "input_to_exogenous_genomes\t"$1/4}' >> #{@inputDir}/#{sampleID}/#{sampleID}.stats`
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Count reads mapped to exogenous genomes for sample #{sampleID}")
              # Write read count for "exogenous_genomes" field in .stats file
              `cat #{@outputDir}/ExogenousGenomicAlignments.txt | cut -d $'\t' -f 1 | uniq | wc -l | awk '{print "exogenous_genomes\t"$1}' >> #{@inputDir}/#{sampleID}/#{sampleID}.stats`
              # Rename ExogenousGenomicAlignments.txt to have sample ID and analysis name in it
              `cd #{@outputDir} ; mv ExogenousGenomicAlignments.txt #{sampleID}_#{CGI.escape(@analysisName)}_ExogenousGenomicAlignments.txt`
              # Compress renamed ExogenousGenomicAlignments.txt so we can upload it (if user chose to upload full results) - it can be gigantic so we want to do this as soon as possible!
              `cd #{@outputDir} ; tar -zcvf #{sampleID}_#{CGI.escape(@analysisName)}_ExogenousGenomicAlignments.tgz #{sampleID}_#{CGI.escape(@analysisName)}_ExogenousGenomicAlignments.txt` if(@settings['uploadFullResults'] or @settings['uploadExogenousAlignments'])
              # Move uncompressed renamed ExogenousGenomicAlignments.txt to shared cluster area (for processing through exogenous taxonomy tree wrapper)
              exogenousTaxoTreeInput = "#{@settings['jobSpecificSharedScratch']}/exogenousTaxoTrees/#{sampleID}_#{CGI.escape(@analysisName)}_ExogenousGenomicAlignments.txt"
              `mv #{@outputDir}/#{sampleID}_#{CGI.escape(@analysisName)}_ExogenousGenomicAlignments.txt #{exogenousTaxoTreeInput}`
              # Fix .stats file so that lines are in correct order and so timestamp is correct
              statsFile = File.open("#{@inputDir}/#{sampleID}/#{sampleID}.stats", 'r')
              newStatsFile = ""
              statsFile.each_line { |currentLine|
                newStatsFile << currentLine unless(currentLine.include?("#END OF STATS"))
              }
              statsFile.close()
              finalLine = "#END OF STATS from the exceRpt smallRNA-seq pipeline. Run completed at #{`/bin/date "+%Y-%m-%d--%H:%M:%S"`}"
              newStatsFile << finalLine
              # Write new stats file to same path as above
              File.open("#{@inputDir}/#{sampleID}/#{sampleID}.stats", "w") { |file| file.write(newStatsFile) }
              # Let's update our CORE_RESULTS archive with the new .stats file
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Adding updated files to CORE_RESULTS archive for #{sampleID}")
              # Grab path of CORE_RESULTS archive
              coreResultsArchive = Dir["#{@inputDir}/#{sampleID}/*_CORE_RESULTS*.tgz"][0]
              # Create temporary directory where CORE_RESULTS archive will be unzipped
              tempCoreResultsDir = "#{@inputDir}/#{sampleID}/TEMP_CORE_RESULTS_DIR"
              `mkdir #{tempCoreResultsDir}`
              # Unzip CORE_RESULTS archive to temp dir
              `tar -zxvf #{Shellwords.escape(coreResultsArchive)} -C #{tempCoreResultsDir}`
              # Copy .stats file to temp dir
              `cp #{@inputDir}/#{sampleID}/#{sampleID}.stats #{tempCoreResultsDir}/#{sampleID}.stats`
              # Delete old copy of CORE_RESULTS archive
              `rm -f #{coreResultsArchive}`
              # Re-zip the (new) contents of the CORE_RESULTS archive in the same place as the previous version
              `cd #{tempCoreResultsDir} ; tar -zcvf #{coreResultsArchive} *`
              # Delete the unzipped CORE_RESULTS directory (we're done compressing it again)
              `rm -rf #{tempCoreResultsDir}`
              # If @settings['isFTPJob'] is true, then we'll need to overwrite the .stats file and CORE_RESULTS archive in the shared location used by erccFinalProcessing as well
              if(@settings['isFTPJob'])
                sharedStatsFile = "#{@settings['jobSpecificSharedScratch']}/samples/#{sampleID}/#{sampleID}.stats"
                `cp #{@inputDir}/#{sampleID}/#{sampleID}.stats #{sharedStatsFile}`
              end
              # Now, since the .stats file and CORE_RESULTS archive are updated, let's upload them to Genboree. 
              # We'll upload the .stats file to the sample's base directory, and we'll upload the .stats file and CORE_RESULTS archive to the CORE_RESULTS subfolder.
              # These files will replace the old (exogenousMapping="miRNA") versions in the user's database.
              # Stats file to base sample dir
              transferFile(sampleID, "#{@inputDir}/#{sampleID}/#{sampleID}.stats", "")
              # Stats file to CORE_RESULTS subdir
              transferFile(sampleID, "#{@inputDir}/#{sampleID}/#{sampleID}.stats", "/CORE_RESULTS")
              # CORE_RESULTS archive to CORE_RESULTS subdir
              transferFile(sampleID, coreResultsArchive, "/CORE_RESULTS")
              # Collated single exogenous alignment result file
              transferFile(sampleID, "#{@outputDir}/#{sampleID}_#{CGI.escape(@analysisName)}_ExogenousGenomicAlignments.tgz", "/EXOGENOUS_GENOME_OUTPUT") if(@settings['uploadFullResults'] or @settings['uploadExogenousAlignments'])
              # Now that we're totally done with the exogenous run for the current sample, let's clean up the sample's directory to make space for other runs
              cleanUp([/_CORE_RESULTS_/], [], inputFileDir)
              # Finally, we'll submit the exogenousTaxoTree job to process this job's taxonomy tree
              exogenousTaxoTreeJobObj = createExogenousTaxoTreeJobConf(exogenousTaxoTreeInput, coreResultsArchive, sampleID)
              begin
                # Submit job for current input file
                $stderr.debugPuts(__FILE__, __method__, "exogenousTaxoTree job conf for #{exogenousTaxoTreeInput}", JSON.pretty_generate(exogenousTaxoTreeJobObj))
                # Create an ApiCaller instance for launching the exogenousTaxoTree job
                apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/genboree/tool/{toolId}/job", user, pass)
                httpResp = apiCaller.put({ :toolId => @exogenousTaxoTreeToolId }, exogenousTaxoTreeJobObj.to_json)
                # Check result
                if(apiCaller.succeeded?)
                  $stderr.debugPuts(__FILE__, __method__, "Response to submitting exogenousTaxoTree job conf for #{exogenousTaxoTreeInput}", JSON.pretty_generate(apiCaller.parseRespBody))
                  # We'll grab its job ID and save it in @listOfExogenousTaxoTreeJobIds
                  exogenousTaxoTreeJobId = apiCaller.parseRespBody['data']['text']
                  @listOfExogenousTaxoTreeJobIds[exogenousTaxoTreeJobId] = File.basename(exogenousTaxoTreeInput)
                  $stderr.debugPuts(__FILE__, __method__, "Job ID associated with #{exogenousTaxoTreeInput}", exogenousTaxoTreeJobId)
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "exogenousTaxoTree job accepted with analysis name: #{exogenousTaxoTreeJobObj['settings']['analysisName'].inspect}.\nHTTP Response: #{httpResp.inspect}\nStatus Code: #{apiCaller.apiStatusObj['statusCode'].inspect}\nStatus Message: #{apiCaller.apiStatusObj['msg'].inspect}\n#{'='*80}\n")
                else
                  $stderr.debugPuts(__FILE__, __method__, "ERROR (but continuing)", "#{@exogenousTaxoTreeToolId} job submission failed! HTTP Response Object: #{httpResp.class}.\nResponse Payload:\n#{apiCaller.respBody}\n#{'='*80}\n")
                  @failedJobs[exogenousTaxoTreeInput] = apiCaller.respBody
                end
              rescue => err
                $stderr.debugPuts(__FILE__, __method__, "ERROR (but continuing)", "Problem with submitting the exogenousTaxoTree job #{exogenousTaxoTreeJobObj.inspect}: #{err.message.inspect}.\n#{err.backtrace.join("\n")}")
                @failedJobs[exogenousTaxoTreeInput] = err.message.inspect
              end
              # Make sure that files are being properly cleaned up
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Remaining files in output dir: #{remainingFiles}.")
            else
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "INPUT DIR #{inputFileDir} is not a directory.")
            end
          }
        }
        # Let's save our exogenous taxonomy tree job IDs to a file
        listOfExogenousTaxoTreeJobIdsOnly = @listOfExogenousTaxoTreeJobIds.keys
        File.open("#{@exogenousTaxoTreeJobIDDir}/#{@jobId}.txt", 'w') { |file| file.write(listOfExogenousTaxoTreeJobIdsOnly.join("\n")) }
      # If an error occurs at any point in the above, we'll return an @exitCode of 30 (if exit code hasn't already been set) and give an informative message for the user.
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of STAR exogenous mapping tool failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to run STAR exogenous mapping tool." if(@errInternalMsg.nil?)
        @exitCode = 30 if(@exitCode == 0)
      end
      return @exitCode
    end

####################################
#### Methods used in this wrapper
####################################

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
      # Define settings - we flag that we're using more memory (so that we request 94 GB mem/vmem for our job), and we also set Java RAM to be higher (50 GB instead of 30 GB)
      runExceRptJobConf['settings']['useMoreMemory'] = true
      runExceRptJobConf['settings']['javaRam'] = "64G"
      runExceRptJobConf['settings']['exogenousMapping'] = "miRNA"
      # If @settings['uploadFullResults'] is true, then we'll grab the estimated file size from the file name of the input file
      if(@settings['uploadFullResults'] and !@isFTPJob)
        basename = File.basename(inputFile)
        basename = basename.split("_")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Total output file size is predicted to be #{basename[0]}")
        runExceRptJobConf['settings']['totalOutputFileSize'] = basename[0]
        basename.shift()
        newBasename = basename.join("_")
        # Update file so that its file name doesn't have file size token
        oldInputFile = inputFile.clone()
        oldInputFile.slice!("file://")
        newInputFile = "#{File.dirname(oldInputFile)}/#{newBasename}"
        `mv #{oldInputFile} #{newInputFile}`
        # Update inputs array in job conf to point to new file name (without file size token)
        newInputFile = "file://#{newInputFile}"
        runExceRptJobConf['inputs'] = newInputFile
        @rerunFiles.map! { |currentInput| currentInput = newInputFile if(currentInput == inputFile) }
      end
      return runExceRptJobConf
    end

    # Produce a valid job conf for exogenousSTARMapping tool and then submit ESM job. ESM job will be conditional on all successfully launched runExceRpt jobs finishing (success or failure).
    # @param [String] host host name
    # @param [String] user user name
    # @param [String] pass password
    # @param [Hash] preconditionJobsForRerunningJob list of precondition jobs (for re-running exogenousSTARMapping job)
    # @return [nil]
    def exogenousSTARMapping(host, user, pass, preconditionJobsForRerunningJob)
      # Produce exogenousSTARMapping job file
      createESMJobConf(preconditionJobsForRerunningJob)
      # Launch exogenousSTARMapping job
      submitESMJob(host, user, pass)
      return
    end
   
    # Method to create exogenousSTARMapping jobFile.json used in submitESMJob()
    # @return [nil]
    def createESMJobConf(preconditionJobsForRerunningJob)
      @esmJobConf = @jobConf.deep_clone()
      ## Define context
      @esmJobConf['context']['toolIdStr'] = @exogenousSTARMappingToolId
      @esmJobConf['settings']['exogenousMapping'] = "on"
      # We will submit a conditional job. Its preconditions will be the runExceRpt jobs launched above. 
      @esmJobConf['preconditionSet'] =  {
        "willNeverMatch"=> false,
        "numMet"=> 0,
        "someExpired"=> false,
        "count"=> 0,
        "preconditions"=> preconditionJobsForRerunningJob
      }
      # Write jobConf hash to tool specific jobFile.json
      @esmJobFile = "#{@inputDir}/esmJobFile.json"
      File.open(@esmJobFile,"w") do |esmJob|
        esmJob.write(JSON.pretty_generate(@esmJobConf))
      end
      return
    end
    
    # Method to call exogenousSTARMapping job for successful samples
    # @param [String] host host name
    # @param [String] user user name 
    # @param [String] pass password
    # @return [nil]
    def submitESMJob(host, user, pass)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/genboree/tool/exogenousSTARMapping/job", user, pass)
      apiCaller.put({}, @esmJobConf.to_json)
      unless(apiCaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "EXOGENOUS STAR MAPPING JOB SUBMISSION FAILURE", apiCaller.respBody.inspect)
        @errUserMsg = "We could not submit your exogenousSTARMapping job as a conditional job."
        raise @errUserMsg
      else
        $stderr.debugPuts(__FILE__, __method__, "EXOGENOUS STAR MAPPING JOB SUBMISSION SUCCESS", apiCaller.respBody.inspect)
        apiCaller.parseRespBody()
        # Grab job ID for new exogenousSTARMapping job
        newJobId = apiCaller.apiDataObj["text"]
        # Write file containing this job ID to specific folder in shared job area (used by exogenousPPRLauncher to relaunch itself)
        `mkdir -p #{@settings['exogenousRerunDir']}`
        File.open("#{@settings['exogenousRerunDir']}/#{newJobId}.txt", 'w') { |file| file.write(newJobId) }
      end
      return
    end

    # Transfer output files related to a given index to user database
    # @param [String] sampleID ID for current sample
    # @param [String] outputFile local file path for file being uploaded
    # @param [String] pathPrefix prefix (after sample name) to where file will be uploaded
    # @return [FixNum] exitCode to indicate whether method succeeded or failed
    def transferFile(sampleID, outputFile, pathPrefix)
      # Find target URI for user's database
      targetUri = URI.parse(@outputs[0])
      # Set resource path
      if(@remoteStorageArea)
        rsrcPath = "#{targetUri.path}/file/{remoteStorageArea}/exceRptPipeline_v#{@toolVersion}/{analysisName}/{sampleID}#{pathPrefix}/{outputFile}/data?"
      else
        rsrcPath = "#{targetUri.path}/file/exceRptPipeline_v#{@toolVersion}/{analysisName}/{sampleID}#{pathPrefix}/{outputFile}/data?"
      end
      # We also need to add our gbKey for access (if it exists)
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      # Upload file 
      uploadFile(targetUri.host, rsrcPath, @subUserId, outputFile, { :analysisName => @analysisName, :outputFile => File.basename(outputFile), :remoteStorageArea => @remoteStorageArea, :sampleID => sampleID })
    end

    # Upload a given file to Genboree server
    # @param [String] host the host where we're uploading the file 
    # @param [String] rsrcPath the resource path for where we're uploading the file
    # @param [FixNum] userId the ID associated with the user's account
    # @param [String] input the local path to the file that's being uploaded
    # @param [Hash<Symbol, String>] templateHash hash containing information for the rsrcPath
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

    # Method to detect errors
    # @param [boolean] exitStatus indicating if the system() call "succeeded" or not.
    # @return [boolean] indicating if an exogenousSTARMapping error was found or not.
    def findError(exitStatus)
      retVal = true
      errorMessages = nil
      # Check the obvious things first. Outright failure or putting error messages on stderr:
      cmd = "grep -i \"ERROR\" #{@outFile} #{@errFile} | grep -v \"Backtrace\""
      errorMessages = `#{cmd}`
      # If exitStatus is true (run succeeded according to that metric) and we didn't find any errors in the log files, then we'll set retVal to be false, indicating the run was successful.
      if(exitStatus and errorMessages.strip.empty?)
        retVal = false
      end
      # If retVal is still true, then something went wrong, and we need to raise an error and report any pertinent info to the user.
      if(retVal)
        @errUserMsg = "Exogenous STAR Mapping run failed.\nReason(s) for failure:\n\n"
        errorMessages = nil if(errorMessages.nil? or errorMessages.empty?)
        @errUserMsg << (errorMessages || "[No error info available from Exogenous STAR Mapping tool]")
      end
      return retVal
    end

    # Method to create an exogenousTaxoTree job conf file given some input file.
    # @param [String] inputFile file path to input file
    # @param [String] coreResultsArchive file path to core results archive
    # @param [String] sampleID sample ID
    # @return [Hash] hash containing the job conf file
    def createExogenousTaxoTreeJobConf(inputFile, coreResultsArchive, sampleID)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Preparing the exogenousTaxoTree jobConf for #{inputFile}")
      # Reuse the existing jobConf and modify properties as needed
      exogenousTaxoTreeJobConf = @jobConf.deep_clone()
      # Define input for job conf
      exogenousTaxoTreeJobConf['inputs'] = "file://#{inputFile}"
      # We will keep the same output database
      # Define context
      exogenousTaxoTreeJobConf['context']['toolIdStr'] = @exogenousTaxoTreeToolId
      exogenousTaxoTreeJobConf['context']['warningsConfirmed'] = true
      # define settings
      exogenousTaxoTreeJobConf['settings']['javaRam'] = "64G"
      exogenousTaxoTreeJobConf['settings']['coreResultsArchive'] = coreResultsArchive
      exogenousTaxoTreeJobConf['settings']['sampleID'] = sampleID
      return exogenousTaxoTreeJobConf
    end

###################################################################################

    # Method to send success e-mail to user
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
      inputsText                = customBuildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      outputsText               = buildSectionEmailSummary(@outputs[0])
      emailObject.outputsText   = outputsText
      emailObject.settings      = @settings
      emailObject.exitStatusCode = @exitCode
      additionalInfo = ""
      additionalInfo << "Your result files are currently being uploaded to your database.\nPlease wait for some time before attempting to download your result files.\n\n" +
                        "Result files have been uploaded for each processed sample under this location in the Genboree Workbench:\n" + 
                          "|-Group: '#{@groupName}'\n" +
                            "|--Database: '#{@dbName}'\n" +
                              "|---Files\n" 
      if(@remoteStorageArea)
        additionalInfo << "|----#{@remoteStorageArea}\n" + 
                            "|-----exceRptPipeline_v#{@toolVersion}\n" +
                              "|------#{@analysisName}\n"+
                                "|-------[Individual Sample Directory]\n" +
                                  "|--------EXOGENOUS_GENOME_OUTPUT\n"
      else 
        additionalInfo << "|----exceRptPipeline_v#{@toolVersion}\n" +
                            "|-----#{@analysisName}\n" +
                              "|------[Individual Sample Directory]\n" +
                                "|-------EXOGENOUS_GENOME_OUTPUT\n"
      end
      additionalInfo << "\n==================================================================\n" +
                        "NOTE 1:\nEach sample's .stats file and CORE_RESULTS archive\nhave been updated with information from the exogenous alignments." +
                        "\n==================================================================\n" +
                        "NOTE 2:\nWe have launched some background jobs\nto generate taxonomy trees for your exogenous reads.\nThese jobs will also update each sample's CORE_RESULTS archive." +
                        "\n==================================================================\n" +
                        "NOTE 3:\nWhen these background jobs finish,\nthe exceRpt post-processing tool will be run on your samples\nto condense information from your samples into an easy-to-read report." +
                        "\n==================================================================\n"
      # Print info about jobs that we couldn't relaunch
      if(@failedRerunJobs)
        unless(@failedRerunJobs.empty?)
          additionalInfo << "\n==================================================================\n"
          additionalInfo << "We encountered errors when submitting some of your samples.\nPlease see a list of samples and their respective errors below:"
          @failedRerunJobs.each_key { |currentSample|
            additionalInfo << "\n\nCurrent sample: #{currentSample}\n" +
                              "Error message: #{@failedRerunJobs[currentSample]}"
          }
        end
      end
      emailObject.resultFileLocations = nil
      emailObject.additionalInfo = additionalInfo
      # Remove settings that are unnecessary for user e-mail
      cleanUpSettingsForEmail()
      if(@suppressEmail)
        return nil
      else
        return emailObject
      end
    end

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
      # Print info about jobs that we couldn't relaunch
      additionalInfo = ""
      if(@failedRerunJobs)
        unless(@failedRerunJobs.empty?)
          additionalInfo << "\n==================================================================\n"
          additionalInfo << "We encountered errors when submitting some of your samples.\nPlease see a list of samples and their respective errors below:"
          @failedRerunJobs.each_key { |currentSample|
            additionalInfo << "\n\nCurrent sample: #{currentSample}\n" +
                              "Error message: #{@failedRerunJobs[currentSample]}"
          }
        end
      end
      emailErrorObject.additionalInfo = additionalInfo
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
      # Delete local path to list of job IDs text file
      @settings.delete('filePathToListOfExogenousTaxoTreeJobIds')
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
      @settings.delete('totalOutputFileSize')
      @settings.delete('listOfExogenousTaxoTreeJobIds')
      @settings.delete('wbContext')
      @settings.delete('exogenousTaxoTreeJobIDDir')
      @settings.delete('exogenousRerunDir')
      @settings.delete('filePathToListOfExogenousJobIds')
      @settings.delete('exoJobId')
      @settings.delete('exogenousClaves')
      @settings.delete('backupFtpDir')
      @settings.delete('importantJobIdsDir')
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
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::ExogenousSTARMappingWrapper)
end
