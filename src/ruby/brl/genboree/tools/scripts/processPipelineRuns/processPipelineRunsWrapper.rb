#!/usr/bin/env ruby
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
require 'brl/genboree/tools/FTPtoolWrapper'
require 'fileutils'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class ProcessPipelineRunsWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "4.6.3"
    COMMAND_LINE_ARGS = {}
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the 'exceRpt small RNA-seq Post-processing' tool.
                        This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "William Thistlethwaite (thistlew@bcm.edu)" ],
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
        # Set up API URI helper for processing inputs currently in email to user
        @apiUriHelper = BRL::Genboree::REST::Helpers::ApiUriHelper.new()
        # Genboree specific "context" variables
        @dbrcKey = @context['apiDbrcKey']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        @scratchDir = @context['scratchDir']
        @originalScratchDir = @scratchDir.clone()
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        # Set up user / pass / host
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
        targetUri = URI.parse(@outputs[0])
        @outputHost = targetUri.host
        # Grab group name and database name
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
        # @batchJob is used to differentiate stand-alone PPR jobs from jobs that are part of the exceRptPipeline batch / runExceRpt series of jobs
        @batchJob = @settings['isBatchJob']
        @DESeq2Job = @settings['DESeq2Job']
        if(@batchJob)
          # If this is a batch job, then we save the @exceRptToolVersion (used in e-mail to user) and set the @scratchDir to be the special location in the cluster shared scratch area
          @scratchDir = @settings['postProcDir']
          # Add processPipelineRuns job ID to list of job IDs to display in final processing email
          @listOfJobIds = JSON.parse(File.read(@settings['filePathToListOfJobIds']))
          @listOfJobIds[@jobId] = "Process Pipeline Runs Job"
          File.open(@settings['filePathToListOfJobIds'], 'w') { |file| file.write(JSON.pretty_generate(@listOfJobIds)) }
        # We only want to set up tool usage doc options if job is not run as a subjob of DESeq2 (tool usage doc will be submitted as part of the DESeq2 job, so not necessary here)
        elsif(!@DESeq2Job)
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
          # Now, we'll set up our variables for the tool usage doc
          @exRNAInternalKBHost = @genbConf.exRNAInternalKBHost
          @exRNAInternalKBGroup = @genbConf.exRNAInternalKBGroup
          @exRNAInternalKBName = @genbConf.exRNAInternalKBName
          @piCodesColl = @genbConf.exRNAInternalKBPICodesColl
          @erccToolUsageColl = @genbConf.exRNAInternalKBToolUsageColl
          @piName = @settings['piName']
          if(@settings['grantNumber'] == "Non-ERCC Funded Study")
            @grantNumber = @settings['grantNumber']
          else 
            @grantNumber = @settings['grantNumber'].split(" ")[0]
          end
          @piID = @settings['piID']
          @platform = "Genboree Workbench"
          @processingPipeline = "exceRpt Small RNA-seq (Post-processing Only)"
          @anticipatedDataRepo = @settings['anticipatedDataRepo']
          @otherDataRepo = @settings['otherDataRepo']
          @dataRepoSubmissionCategory = @settings['dataRepoSubmissionCategory']
          @dbGaP = @settings['dbGaP']
          @submitterOrganization = ""
          @piOrganization = ""
          @coPINames = ""
          @rfaTitle = ""
          if(@piName == "Non-ERCC PI")
            apiCaller = ApiCaller.new(host, "/REST/v1/usr/#{@userLogin}", user, pass)
            apiCaller.get()
            @submitterOrganization = apiCaller.parseRespBody["data"]["institution"]
            @submitterOrganization = "N/A" if(@submitterOrganization.empty?)
            @piOrganization = "N/A (Submitter organization: #{@submitterOrganization})"
            @rfaTitle = "Non-ERCC Submission"
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
            else
              @rfaTitle = "Non-ERCC Submission"
            end
          end
        end
        @localJob = @settings['localJob']
        # fileCount will be used to create subdirectories for each individual run within our parent directory
        @fileCount = 0
        # Set up format options coming from the UI - "Settings" variables
        @analysisName = @settings['analysisName']
        # Make directory where we'll place unzipped runs for processing
        @runsDir = "#{@scratchDir}/runs"
        `mkdir -p #{@runsDir}` unless(@batchJob) # Don't need to make dir if batchJob is true (already made it earlier)
        # Make directory where we'll place output files
        @outputDir = "#{@scratchDir}/outputFiles"
        @settings['postProcOutputDir'] = @outputDir
        `mkdir -p #{@outputDir}`
        # Set up inputs array if job is batch job or local job
        if(@batchJob or @localJob)
          # Grab all files that are present in the runs directory.
          # These files will either be .tgz files (CORE_RESULTS archives) or FASTQ/SRA files.
          # If all files are the former, then we can run this job.
          # If any files are the latter, we need to re-run runExceRpt jobs on the FASTQ/SRA files and cancel this job.
          runsDirFiles = Dir.entries(@runsDir)
          runsDirFiles.delete(".") 
          runsDirFiles.delete("..")
          sniffer = BRL::Genboree::Helpers::Sniffer.new()
          # @inputs will store valid input paths, while @rerunFiles will store file paths that need to be re-run through exceRpt 
          @rerunFiles = []
          @inputs = []
          runsDirFiles.each { |currentFile|
            fullPath = "#{@runsDir}/#{currentFile}"
            sniffer.filePath = fullPath
            if(sniffer.detect?("fastq") or sniffer.detect?("sra"))
              @rerunFiles << "file://#{fullPath}"
            else
              @inputs << "file://#{fullPath}"
            end
          }
          # We will re-launch runExceRpt jobs for samples that failed (using more memory), and we will launch a new conditional processPipelineRuns job with those job IDs included.
          unless(@rerunFiles.empty?)
            # preconditionJobs will hold all of the job IDs that need to finish in order for this tool (processPipelineRuns) to re-run.
            # Many of these jobs will already be finished (because they ran earlier successfully)
            preconditionJobs = []
            @runExceRptToolId = "runExceRpt"
            @pprToolId = @toolConf.getSetting('info', 'idStr')
            @failedRerunJobs = {}
            conditionalJob = false
            # Create a reusable ApiCaller instance for launching each runExceRpt job
            apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/genboree/tool/{toolId}/job", user, pass)
            # Traverse all of the jobs that already finished and add a condition hash for each to our preconditionJobs array.
            # Note that met has been set to be true for all of these jobs (they won't be re-run)
            @listOfJobIds.each_key { |jobId|
              condition = {
                "type" => "job",
               "expires" => (Time.now + Time::WEEK_SECS * 4).to_s,
                "met" => true,
                "condition"=> {
                  "dependencyJobUrl" => "http://#{host}/REST/v1/job/#{jobId}",
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
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Condition connected with runExceRpt job #{jobId} (sample name: #{@listOfJobIds[jobId]}): #{condition.inspect}")
              preconditionJobs << condition
            }
            # Now, we will submit a job for each of the files that needs to be re-run.
            # We will also add a condition for each job into our preconditionJobs array. Note that met will be set to false for these conditions (since the jobs haven't run yet!)
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
                  # We'll grab its job ID and save it in @listOfJobIds
                  runExceRptJobId = apiCaller.parseRespBody['data']['text']
                  @listOfJobIds[runExceRptJobId] = File.basename(runExceRptJobObj['inputs'])
                  File.open(@settings['filePathToListOfJobIds'], 'w') { |file| file.write(JSON.pretty_generate(@listOfJobIds)) }
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
                  # We'll add that condition to our preconditionJobs array
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Condition connected with runExceRpt job associated with #{runExceRptJobObj['inputs']}: #{condition.inspect}")
                  preconditionJobs << condition
                else
                  $stderr.debugPuts(__FILE__, __method__, "ERROR (BUT CONTINUING)", "#{@runExceRptToolId} job submission failed! HTTP Response Object: #{httpResp.class}.\nResponse Payload:\n#{apiCaller.respBody}\n#{'='*80}\n")
                  @failedRerunJobs[File.basename(runExceRptJobObj['inputs'])] = apiCaller.respBody
                end
              rescue => err
                $stderr.debugPuts(__FILE__, __method__, "ERROR (BUT CONTINUING)", "Error raised while submitting the runExceRpt job #{runExceRptJobObj.inspect}: #{err.message.inspect}.\n#{err.backtrace.join("\n")}")
                @failedRerunJobs[File.basename(runExceRptJobObj['inputs'])] = err.message.inspect
              end
            }
            # If a worker job was successfully launched, then we will launch our PPR job again.
            if(conditionalJob)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Submitting a conditional processPipelineRuns job for all samples that need to be rerun (will run after all worker runExceRpt jobs finish)")
              postProcessing(host, user, pass, preconditionJobs)
            end
            # Now that we've re-launched our worker runExceRpt jobs and our PPR job, we will cancel this job by raising an error with exit code 15 (reserved for cancellation)
            @errUserMsg = "At least some of your samples failed processing through exceRpt,\nlikely due to insufficient memory.\nWe will re-run those failed samples with more memory.\nAfter those samples are re-run, we will run this job again.\n"
            @rerunFiles.map! { |currentInput| File.basename(currentInput) }
            @errUserMsg << "The samples that failed processing are the following:\n\n#{@rerunFiles.join("\n")}"
            @exitCode = 15
            raise @errUserMsg
          end
        end
        # Get the tool version from toolConf
        @toolVersion = @toolConf.getSetting('info', 'version')
        @settings['toolVersion'] = @toolVersion
        # We set toolVersionPPR for the erccfinalProcessing tool
        @settings['toolVersionPPR'] = @toolVersion
        # Get the tool version of exceRpt
        if(@inputs.nil? or @inputs.empty?)
          @errUserMsg = "There are no valid inputs.\nMost likely, a batch exceRpt pipeline job was run, but there were no successful result files generated."
          raise @errUserMsg
        end
        @resultsVersion = @inputs[0].match((/v(\d\.\d\.\d)(?:.zip|.tgz)/))[1]
        @settings['exceRptResultsVersion'] = @resultsVersion
        toolConfExceRptPipeline = BRL::Genboree::Tools::ToolConf.new('exceRptPipeline', @genbConf)
        @mostRecentVersion = toolConfExceRptPipeline.getSetting('info', 'version')
        # If input version number starts with 3 (third gen), then @mostRecentVersion will be set to 3.3.0 (the latest version of 3rd gen exceRpt)
        # We'll also update the tool version for PPR to be 3.1.0, since we'll be using 3rd gen PPR to process the samples
        if(@resultsVersion[0].chr == "3")
          @mostRecentVersion = "3.3.0"
          @toolVersion = "3.1.0"
          @settings['toolVersion'] = "3.1.0"
          @settings['toolVersionPPR'] = "3.1.0"
        end
        # FTP-related variables (along with remote storage area, which can come from the Workbench)
        @isFTPJob = @settings['isFTPJob']
        @finishedFtpDir = @settings['finishedFtpDir'] if(@settings['isFTPJob'])
        @isRemoteStorage = true if(@settings['remoteStorageArea'])
        if(@isRemoteStorage)
          @remoteStorageArea = @settings['remoteStorageArea']
        end
        @subUserId = @settings['subUserId']
        @subUserId = @userId unless(@subUserId)
      # If we have any errors above, we will return an @exitCode of 22 and give an informative message for the user.
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
        @outFile = @errFile = ""
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
        @outFile = "#{@scratchDir}/processPipelineRuns.out"
        @errFile = "#{@scratchDir}/processPipelineRuns.err"
        # Download the input from the server (if not a job run locally from smallRNA-seq pipeline)
        unless(@batchJob or @localJob)
          downloadFiles()
        end
        # Run the tool
        foundErrorInProcessPipelineRuns = runProcessPipelineRuns()
        # If the tool finished successfully, we'll upload the tool's output files
        unless(foundErrorInProcessPipelineRuns)
          allOutputFiles = Dir.entries(@outputDir)
          # Add @analysisName as a prefix to all output files
          prefix = "#{CGI.escape(@analysisName)}_"
          allOutputFiles.each { |outputFile|
            next if(outputFile == "." or outputFile == "..")
            newName = "#{prefix}#{outputFile}"
            FileUtils.mv("#{@outputDir}/#{outputFile}", "#{@outputDir}/#{newName}")
          }
          # Compress all files in a .tgz
          pprArchive = "#{prefix}postProcessedResults_v#{@toolVersion}.tgz"
          `cd #{@outputDir} ; tar -zcvf #{pprArchive} *`
          # Upload all relevant files
          transferFiles()
          @successfulRun = true
        end # unless(foundErrorInProcessPipelineRuns)
      # If an error occurs at any point in the above, we'll return an @exitCode of 30 (if exit code hasn't already been set) and give an informative message for the user.
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of exceRpt small RNA-seq Post-processing tool failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to run exceRpt small RNA-seq Post-processing tool." if(@errInternalMsg.nil?)
        @exitCode = 30 if(@exitCode == 0)
      ensure
        # If we're running a batch job, then we'll reset our scratch dir to be the original scratch dir (not the one on cluster.shared.scratch) to avoid an error.
        # We'll also submit our ERCC Final Processing job.
        if(@batchJob)
          @scratchDir = @originalScratchDir
          erccFinalProcessing(user, pass, host)
        else
          # Otherwise, if this is not a batch job, we'll just upload the tool usage doc (unless we're running an AUTO job or this job is a subjob of the DESeq2 job).
          submitToolUsageDoc(user, pass) unless(@jobId[0..4] == "AUTO-" or @DESeq2Job)
        end
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
      runExceRptJobConf['settings']['javaRam'] = "50G"
      # If @settings['uploadFullResults'] is true, then we'll grab the estimated file size from the file name of the input file
      if(@settings['uploadFullResults'])
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

    # Produce a valid job conf for processPipelineRuns tool and then submit PPR job. PPR job will be conditional on all successfully launched runExceRpt jobs finishing (success or failure).
    # @param [String] host host name
    # @param [String] user user name
    # @param [String] pass password
    # @return [nil]
    def postProcessing(host, user, pass, preconditionJobs)
      # Produce processPipelineRuns job file
      pprJobConf = createPPRJobConf(preconditionJobs)
      # Submit processPipelineRuns job
      submitPPRJob(host, user, pass, pprJobConf)
      return
    end
   
    # Method to create processPipelineRuns jobFile.json used in submitPPRJob()
    # @return [nil]
    def createPPRJobConf(preconditionJobs)
      pprJobConf = @jobConf.deep_clone()
      ## Define context
      pprJobConf['context']['toolIdStr'] = @pprToolId
      # We will submit a conditional job. Its preconditions will be the runExceRpt jobs launched above. 
      pprJobConf['preconditionSet'] =  {
        "willNeverMatch"=> false,
        "numMet"=> 0,
        "someExpired"=> false,
        "count"=> 0,
        "preconditions"=> preconditionJobs
      }
      # Write jobConf hash to tool specific jobFile.json
      pprJobFile = "#{@settings['postProcDir']}/pprJobFile.json"
      File.open(pprJobFile,"w") do |pprJob|
        pprJob.write(JSON.pretty_generate(pprJobConf))
      end
      return pprJobConf
    end
    
    # Method to submit processPipelineRuns job
    # @param [String] host host name
    # @param [String] user user name
    # @param [String] pass password
    # @param [Hash] pprJobConf job conf for PPR job
    # @return [nil]
    def submitPPRJob(host, user, pass, pprJobConf)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/genboree/tool/processPipelineRuns/job", user, pass)
      apiCaller.put({}, pprJobConf.to_json)
      unless(apiCaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "PROCESS PIPELINE RUNS JOB SUBMISSION FAILURE", apiCaller.respBody.inspect)
        @errUserMsg = "We could not submit your processPipelineRuns job as a conditional job."
        raise @errUserMsg
      else
        $stderr.debugPuts(__FILE__, __method__, "PROCESS PIPELINE RUNS JOB SUBMISSION SUCCESS", apiCaller.respBody.inspect)
      end
      return
    end

    # Download input files from database - these will be the different exceRpt small RNA-seq pipeline runs (compressed in .zip or .tgz).
    # Note that the runs will be unzipped into directories like "0", "1", "2", etc. within the parent directory created
    # for the runs.
    # @return [nil]
    def downloadFiles()
      # Array to hold different files that were not archives at all (not zip or gz)
      notArchives = []
      # Array to hold different files that were not valid exceRpt smallRNA-seq pipeline archives
      badArchives = []
      # We traverse all inputs
      @inputs.each { |input|
        # Download current input .zip / .tgz file
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input file #{input}")
        fileBase = @fileApiHelper.extractName(input)
        fileBaseName = File.basename(fileBase)
        tmpFile = fileBaseName.makeSafeStr(:ultra)
        retVal = @fileApiHelper.downloadFile(input, @userId, tmpFile)
        # If we are unable to download our file successfully, we will set an error message for the user.
        unless(retVal)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Failed to download file: #{fileBase} from server.")
          @errUserMsg = @errInternalMsg = "Failed to download file: #{fileBase} from server"
          @exitCode = 37
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          raise @err 
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "File downloaded successfully to #{tmpFile}")
        end
        # Sniffer - To check ZIP / GZ format
        sniffer = BRL::Genboree::Helpers::Sniffer.new()
        sniffer.filePath = tmpFile
        # Grab file type (ZIP / GZ)
        fileType = ""
        fileType = "ZIP" if(sniffer.detect?('zip'))
        fileType = "GZ" if(fileType == "" and sniffer.detect?('gz'))
        # If file is ZIP or GZ, then we proceed
        if(fileType == "ZIP" or fileType == "GZ")
          # Unzip the archive we just downloaded
          exp = BRL::Util::Expander.new(tmpFile)
          exp.extract()
          correctArchive = false
          # If uncompressed archive is properly handled by expander (for example, .RData is technically gzip but is not handled by expander), then we proceed.
          if(File.directory?(exp.uncompressedFileName))
            # Move unzipped files (held within the directory exp.uncompressedFileName) to relevant directory within the "runs" parent folder.
            # Relevant directory will be something like "0", "1", etc.
            currentRun = "#{@runsDir}/#{@fileCount}"
            `mv #{exp.uncompressedFileName} #{currentRun}`
            # Delete old .zip / .tgz file since we uncompressed it
            `rm -f #{tmpFile}`
            # Increment @fileCount for next directory
            @fileCount += 1
            # Check to make sure that archive file contains correct contents.  We will check for a .stats file in the base directory - if there isn't one, then the user submitted the wrong file!
            Dir.entries(currentRun).each { |file|
              if(file =~ /\.stats$/)  
                correctArchive = true
              end
            }
          end
          # If the user didn't submit a .zip / .tgz file generated from a recent version of the exceRpt small RNA-seq pipeline, we'll raise an error.
          unless(correctArchive)
            badArchives << fileBaseName
          end
        else
          notArchives << fileBaseName
        end
      }
      unless(notArchives.empty? and badArchives.empty?)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Some inputs are bad. List of non-archives: #{notArchives.inspect}. List of bad archives: #{badArchives.inspect}")
        @errUserMsg = @errInternalMsg = "Some of your submitted files were not valid exceRpt small RNA-seq pipeline output.\nEach file should be either the larger results.zip or smaller CORE_RESULTS.tgz\nassociated with an exceRpt pipeline run. If you submitted an archive\ngenerated by the exceRpt small RNA-seq pipeline but you ran the job several months ago,\nplease re-run the job with the newest version of the exceRpt small RNA-seq pipeline."   
        unless(notArchives.empty?)
          @errUserMsg << "\n\nList of non-archives:\n#{notArchives.join("\n")}"
        end
        unless(badArchives.empty?)
          @errUserMsg << "\n\nList of bad archives:\n#{badArchives.join("\n")}"
        end
        @exitCode = 39
        @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
        raise @err
      end
      return
    end

    # Run the processPipelineRuns.R script on our inputs
    # @return [boolean] exit status that tells us whether job succeeded (true) or failed (false)
    def runProcessPipelineRuns()
      # Command for actually launching the R script that will do the pipeline run processing
      command = "Rscript #{ENV['PROCESS_PIPELINE_R']} #{@runsDir} #{@outputDir} 1>#{@outFile} 2>#{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Path of processPipelineRuns.R: #{ENV['PROCESS_PIPELINE_R']}")
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      # Check to see if the run had any errors
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "exceRpt small RNA-seq Post-processing tool command completed with exit code: #{statusObj.exitstatus}")
      foundError = findError(exitStatus)
      if(@batchJob or @localJob)
        `mv #{@outFile} #{@originalScratchDir}/`
        `mv #{@errFile} #{@originalScratchDir}/`
      end
      return foundError
    end

    # Transfer output files to user database
    # @return [nil]
    def transferFiles()
      # Find target URI for user's database
      targetUri = URI.parse(@outputs[0])
      # Set resource path
      rsrcPath = ""
      # If job is batch job, then we'll upload results to the exceRptPipeline tool area
      if(@batchJob)
        if(@isRemoteStorage)
          rsrcPath = "#{targetUri.path}/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@mostRecentVersion}/{analysisName}/postProcessedResults_v#{@toolVersion}/{outputFile}/data?"
        else
          rsrcPath = "#{targetUri.path}/file/exceRptPipeline_v#{@mostRecentVersion}/{analysisName}/postProcessedResults_v#{@toolVersion}/{outputFile}/data?"
        end
      else
        # Otherwise, we'll upload to normal post-processing area
        if(@isRemoteStorage)
          rsrcPath = "#{targetUri.path}/file/#{CGI.escape(@remoteStorageArea)}/postProcessedResults_v#{@toolVersion}/{analysisName}/{outputFile}/data?"
        else 
          rsrcPath = "#{targetUri.path}/file/postProcessedResults_v#{@toolVersion}/{analysisName}/{outputFile}/data?" 
        end
      end
      # We also need to add our gbKey for access (if it exists)
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      # Upload all output files
      allOutputFiles = Dir.entries(@outputDir)
      allOutputFiles.each { |outputFile|
        next if(outputFile == "." or outputFile == "..")
        uploadFile(targetUri.host, rsrcPath, @subUserId, "#{@outputDir}/#{outputFile}", {:analysisName => @analysisName, :outputFile => outputFile})
      }
      return
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
    # @return [boolean] indicating if a processPipelineRuns error was found or not.
    #   if so, @errUserMsg, @errInternalMsg, @exitCode will be set appropriately
    def findError(exitStatus)
      retVal = false
      errorMessages = nil
      # If exitStatus is false, then we most likely had some errors.
      unless(exitStatus)
        # We will look for errors in our @outFile and @errFile. If we find some, we will set retVal to be true.
        cmd = "grep -i \"ERROR\" #{@outFile} #{@errFile} | grep -v \"Backtrace\""
        errorMessages = `#{cmd}`
        if(errorMessages.strip.empty?)
          retVal = false
        else
          retVal = true
          if(errorMessages =~ /Error in data\.frame\(value, row\.names = rn, check\.names = FALSE/)
            errorMessages << "\nPOSSIBLE REASON: It looks like one or more of your samples have the same names.\nPlease check your inputs and ensure samples do not have the same name.\n"
          elsif(errorMessages =~ /NumberOfCompatibleSamples > 0 is not TRUE/)
            errorMessages << "\nPOSSIBLE REASON: It looks like none of your submitted samples were valid inputs for the post-processing tool.\nIf you submitted an exceRpt Pipeline job, it is likely that none of your samples were successfully processed.\nPlease consult the error messages provided in each sample's respective email.\n"
          end
          # Print error message in error log for debugging purposes
          $stderr.debugPuts(__FILE__, __method__, "STATUS", errorMessages)
        end
      end
      # Did we find anything?
      if(retVal)
        @errUserMsg = "exceRpt small RNA-seq Post-processing tool failed. Message from exceRpt small RNA-seq Post-processing tool:\n\n"
        @errUserMsg << (errorMessages || "[No error info available from exceRpt small RNA-seq Post-processing tool]")
        @errInternalMsg = @errUserMsg
        @exitCode = 30
      end
      return retVal
    end

    # Run erccFinalProcessing tool if this is part of the exceRpt pipeline
    # @param [String] user user name
    # @param [String] pass password
    # @param [String] host host name
    # @return [nil]
    def erccFinalProcessing(user, pass, host)
      # Produce erccFinalProcessing job file
      createERCCFinalProcessingJobConf(host)
      # Launch erccFinalProcessing job
      launchERCCFinalProcessingJob(user, pass, host)
      return
    end
   
    # Method to create erccFinalProcessing job conf used in launchERCCFinalProcessingJob()
    # @param [String] host host name
    # @return [nil]
    def createERCCFinalProcessingJobConf(host)
      @erccJobConf = @jobConf.deep_clone()
      # Define context
      @erccJobConf['context']['toolIdStr'] = "erccFinalProcessing"
      # We will submit a conditional job.
      # We first set up a precondition for the job.
      preconditionJobs = []
      condition = {
        "type" => "job",
        "expires" => (Time.now + Time::WEEK_SECS * 4).to_s,
        "met" => false,
        "condition"=> {
          "dependencyJobUrl" => "http://#{host}/REST/v1/job/#{@jobId}",
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
      preconditionJobs << condition
      @erccJobConf['preconditionSet'] =  {
        "willNeverMatch"=> false,
        "numMet"=> 0,
        "someExpired"=> false,
        "count"=> 0,
        "preconditions"=> preconditionJobs
      }
      return
    end
    
    # Method to call erccFinalProcessing job
    # @param [String] user user name
    # @param [String] pass password
    # @param [String] host host name
    # @return [nil]
    def launchERCCFinalProcessingJob(user, pass, host)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/genboree/tool/erccFinalProcessing/job", user, pass)
      apiCaller.put({}, @erccJobConf.to_json)
      unless(apiCaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "ERCC JOB SUBMISSION FAILURE", apiCaller.respBody.inspect)
        $stderr.debugPuts(__FILE__, __method__, "ERCC JOB SUBMISSION FAILURE", @erccJobConf.inspect)
      else
        $stderr.debugPuts(__FILE__, __method__, "ERCC JOB SUBMISSION SUCCESS", apiCaller.respBody.inspect)
      end
      return
    end

    ########## METHODS RELATED TO TOOL USAGE DOC ##########   
 
    # Submits a document to exRNA Internal KB in order to keep track of ERCC tool usage
    # @return [nil]
    def submitToolUsageDoc(user, pass)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Currently uploading tool usage doc")
      # Create KB doc for tool usage and fill it out
      toolUsage = BRL::Genboree::KB::KbDoc.new({})
      toolUsage.setPropVal("ERCC Tool Usage", @jobId)
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
      toolUsage.setPropVal("ERCC Tool Usage.Samples Processed Through ERCC Pipeline", @inputs.size)
      successfulSamples = 0
      failedSamples = 0
      @inputs.each { |currentInput|
        runItem = BRL::Genboree::KB::KbDoc.new({})
        runItem.setPropVal("Sample Name", File.basename(currentInput).chomp("?"))
        sampleStatus = ""
        if(@successfulRun)
          sampleStatus = "Completed"
          successfulSamples += 1
        else 
          sampleStatus = "Failed"
          failedSamples += 1
        end
        runItem.setPropVal("Sample Name.Sample Status", sampleStatus)
        toolUsage.addPropItem("ERCC Tool Usage.Samples Processed Through ERCC Pipeline", runItem)
      }
      toolUsage.setPropVal("ERCC Tool Usage.Number of Successful Samples", successfulSamples)
      toolUsage.setPropVal("ERCC Tool Usage.Number of Failed Samples", failedSamples)
      toolUsage.setPropVal("ERCC Tool Usage.Platform", @platform)
      toolUsage.setPropVal("ERCC Tool Usage.Processing Pipeline", @processingPipeline)
      toolUsage.setPropVal("ERCC Tool Usage.Processing Pipeline.Version", @toolVersion)
      toolUsage.setPropVal("ERCC Tool Usage.Anticipated Data Repository", @anticipatedDataRepo)
      toolUsage.setPropVal("ERCC Tool Usage.Anticipated Data Repository.Other Data Repository", @otherDataRepo) if(@otherDataRepo)
      toolUsage.setPropVal("ERCC Tool Usage.Anticipated Data Repository.Submission Category", @dataRepoSubmissionCategory)
      toolUsage.setPropVal("ERCC Tool Usage.Anticipated Data Repository.Project Registered by PI with dbGaP?", @dbGaP)
      # Upload doc
      apiCaller = ApiCaller.new(@exRNAInternalKBHost, "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/docs?", user, pass)
      payload = {"data" => toolUsage}
      apiCaller.put({:grp => @exRNAInternalKBGroup, :kb => @exRNAInternalKBName, :coll => @erccToolUsageColl}, payload.to_json)
      # If doc upload fails, raise error
      unless(apiCaller.succeeded? and apiCaller.parseRespBody["data"]["docs"]["properties"]["invalid"]["items"].empty?)
        @errUserMsg = "ApiCaller failed: call to upload tool usage doc failed."
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "ApiCaller failed to upload tool usage doc: #{apiCaller.respBody.inspect}")
        raise @errUserMsg
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully uploaded tool usage doc")
      end
      return
    end

###################################################################################

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
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @settings
      emailObject.exitStatusCode = @exitCode
      additionalInfo = ""
      # Path always begins with Group name, then Database name, then Files
      additionalInfo << "Your result files can be found on the Genboree Workbench.\n"
      additionalInfo << "The Genboree Workbench is a repository of bioinformatics tools\n"
      additionalInfo << "that will store your result files for you.\n"
      additionalInfo << "You can find the Genboree Workbench here:\nhttp://#{@outputHost}/java-bin/workbench.jsp\n"
      additionalInfo << "Once you're on the Workbench, follow the ASCII drawing below\nto find your result files.\n" +
                          "|-Group: '#{@groupName}'\n" +
                            "|--Database: '#{@dbName}'\n" +
                              "|---Files\n"
      # If this is a batch job, then we're uploading to exceRptPipeline tool area.
      if(@batchJob)
        # We'll also add the remote storage area into the path if the user is uploading to one.
        if(@remoteStorageArea)
          additionalInfo <<       "|----#{@remoteStorageArea}\n" + 
                                    "|-----exceRptPipeline_v#{@toolVersion}\n" +
                                      "|------#{@analysisName}\n" +
                                        "|-------postProcessedResults_v#{@toolVersion}\n\n"
        else
          additionalInfo <<       "|----exceRptPipeline_v#{@mostRecentVersion}\n" +
                                    "|-----#{@analysisName}\n" +
                                      "|------postProcessedResults_v#{@toolVersion}\n\n"
        end
      # If this is not a batch job, then we're uploading to the regular post-processing tool area.
      else
        if(@remoteStorageArea)
          additionalInfo <<       "|----#{@remoteStorageArea}\n" +
                                    "|-----postProcessedResults_v#{@toolVersion}\n" +
                                      "|------#{@analysisName}\n\n"
        else  
          additionalInfo <<       "|----postProcessedResults_v#{@toolVersion}\n" +
                                    "|-----#{@analysisName}\n\n"
        end
      end
      emailObject.resultFileLocations = nil
      # Print info about jobs that we couldn't relaunch
      if(@failedRerunJobs)
        unless(@failedRerunJobs.empty?)
          additionalInfo << "\n==================================================================\n"
          additionalInfo << "We encountered errors when resubmitting some of your samples.\nPlease see a list of samples and their respective errors below:"
          @failedRerunJobs.each_key { |currentSample|
            additionalInfo << "\n\nCurrent sample: #{currentSample}\n" +
                              "Error message: #{@failedRerunJobs[currentSample]}"
          }
        end
      end
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
      outputsText                     = buildSectionEmailSummary(@outputs)
      emailErrorObject.outputsText    = outputsText
      emailErrorObject.settings       = @jobConf['settings']
      emailErrorObject.errMessage     = @errUserMsg
      emailErrorObject.exitStatusCode = @exitCode
      emailErrorObject.erccTool = true
      additionalInfo = ""
      unless(@settings['isBatchJob'])
        unless(@mostRecentVersion.nil? or @mostRecentVersion.empty?)
          if(@resultsVersion and @resultsVersion != @mostRecentVersion)
            additionalInfo = "The most recent version of 4th generation exceRpt is v#{@mostRecentVersion}, while your submitted files are v#{@resultsVersion}.\nThis version incompatibility could be the source of your error.\nPlease try re-running your original samples with the latest version of exceRpt.\n"
          end 
          emailErrorObject.additionalInfo = additionalInfo unless(additionalInfo.empty?)
        end
      end 
      additionalInfo << "In addition, the tool may have failed because your result files\n had very few (or no) reads mapped to endogenous libraries.\nYou can check out the .stats file associated with each run\nto see whether this might be the problem." unless(@exitCode == 15)
      # Print info about jobs that we couldn't relaunch
      if(@failedRerunJobs)
        unless(@failedRerunJobs.empty?)
          additionalInfo << "\n==================================================================\n"
          additionalInfo << "We encountered errors when resubmitting some of your samples.\nPlease see a list of samples and their respective errors below:"
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
      @settings.delete("wbContext")
      @settings.delete("subdirs")
      unless(@settings["randomBarcodesEnabled"])
        @settings.delete("randomBarcodeLength")
        @settings.delete("randomBarcodeLocation")
        @settings.delete("randomBarcodeStats")
      end
      @settings.delete("toolVersionPPR")
      @settings["priorityList"].gsub!(",", " > ") if(@settings["priorityList"])
      @settings.delete("adSeqParameter")
      @settings.delete("adapterSequence")
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
      @settings.delete("piName")
      @settings.delete("javaRam")
      @settings.delete("localExecution")
      @settings.delete("numThreads")
      @settings.delete("postProcOutputDir")
      @settings.delete("useLibrary")
      @settings.delete("endogenousMismatch")
      @settings.delete("exogenousMismatch")
      @settings.delete("genomeBuild")
      @settings.delete("manifestFile")
      @settings.delete("postProcDir")
      @settings.delete("subUserId")
      @settings.delete("uploadRawFiles")
      @settings.delete("remoteStorageArea") if(@settings["remoteStorageArea"] == nil)
      @settings.delete('exogenousMappingInputDir')
      @settings.delete("anticipatedDataRepos")
      @settings.delete("grantNumbers")
      @settings.delete("remoteStorageAreas")
      @settings.delete("inputsVersion")
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
      @settings.delete('totalOutputFileSize')
      @settings.delete('exRNAAtlasURL')
      @settings.delete("uploadReadCountsDocs")
      @settings.delete('listOfExogenousTaxoTreeJobIds')
      # Delete local path to list of job IDs text file
      @settings.delete('filePathToListOfJobIds')
      @settings.delete('filePathToListOfExogenousTaxoTreeJobIds')
      @settings.delete('exogenousTaxoTreeJobIDDir')
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
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::ProcessPipelineRunsWrapper)
end
