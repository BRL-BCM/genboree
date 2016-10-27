#!/usr/bin/env ruby
########################################################
############ KNIFE batch wrapper #######################
# This wrapper is the first step in processing KNIFE   #
# inputs. This wrapper loads all settings and then     #
# launches individual KNIFE jobs for either 1 input    #
# fastq (single-end) or 2 input fastqs (paired-end).   #
# Samples are run through runKnife tool. After all     #
# samples are processed, ERCC Final Processing (tool   #
# usage doc / email tool) is launched.                 #
# Modules used in this pipeline:                       #
# 1. KNIFE/1.2                                         #
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
require 'fileutils'
include BRL::Genboree::REST


module BRL; module Genboree; module Tools; module Scripts
  class KnifeWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.2"
    COMMAND_LINE_ARGS = {}
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the 'KNIFE (Known and Novel IsoForm Explorer)' tool in batch-processing mode.
                        This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "William Thistlethwaite (thistlew@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # [+returns+] nil
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
        # Get the tool version
        @toolVersion = @toolConf.getSetting('info', 'version')
        # isBatchJob is used to indicate to future tools (runKnife, processPipelineRuns) that we're running a batch job
        # This is useful, for example, to let PPR know that inputs have already been downloaded and are local (as opposed to running PPR tool independently)
        @settings['isBatchJob'] = true
        # isLocalJob is used to indicate whether we need to download inputs or if they're already present locally
        @localJob = @settings['isLocalJob']
        # alreadyExtracted is used to indicate whether inputs are already extracted / sniffed / converted or not
        # This option should only be used with isLocalJob
        @filesAlreadyExtracted = @settings['filesAlreadyExtracted'] if(@localJob)
        # Settings used for final erccProcessing tool 
        @settings['processingPipeline'] = "KNIFE"
        @settings['processingPipelineVersion'] = @toolVersion
        @settings['processingPipelineIdAndVersion'] = "KNIFE_v#{@toolVersion}"
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
        # Save the job ID for KNIFE so that we can use it in tool usage doc 
        @settings['primaryJobId'] = @jobId
        # This hash will store all job IDs submitted below as part of our batch submission (and will store info about input files as well)
        @listOfJobIds = {}
        # Array containing input file names
        @inputFiles = []
        # Get location of the shared scratch space in the cluster
        @clusterSharedScratchDir = @genbConf.clusterSharedScratchDir
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "SHARED SCRATCH SPACE: #{@clusterSharedScratchDir}")
        if(@clusterSharedScratchDir.nil? or @clusterSharedScratchDir.empty?) 
          @errUserMsg = "ERROR: Genboree config does not have the shared scratch location information."
          raise @errUserMsg
        end
        # If shared scratch space exists, then create specific directory for this KNIFE job.
        if(File.directory?(@clusterSharedScratchDir))
          @jobSpecificSharedScratch = "#{@clusterSharedScratchDir}/#{@jobId}"
          @settings['jobSpecificSharedScratch'] = @jobSpecificSharedScratch
          # Also create sub-directories for individual KNIFE runs (each sample run through runKnife tool)
          @knifeJobsDir = "#{@jobSpecificSharedScratch}/knifeJobs"
          `mkdir -p #{@knifeJobsDir}`
        else
          @errUserMsg = "ERROR: Shared scratch dir #{@clusterSharedScratchDir} is not available."
          raise @errUserMsg
        end
        # Set up format options coming from the UI - "Settings" variables
        @analysisName = @settings['analysisName']
        genomeVersion = @settings['genomeVersion']
        if(genomeVersion == "hg19")
          @settings['organism'] = "human"
        elsif(genomeVersion == "mm10")
          @settings['organism'] = "mouse"
        elsif(genomeVersion == "rn5")
          @settings['organism'] = "rat"
        elsif(genomeVersion == "dm3")
          @settings['organism'] = "fly"
        else
          @errUserMsg = "The genome version #{genomeVersion} is not supported by KNIFE."
          raise @errUserMsg
        end
        # Delete unnecessary items from @settings
        @settings.delete("anticipatedDataRepos")
        @settings.delete("exRNAInternalKBGroup")
        @settings.delete("exRNAInternalKBHost")
        @settings.delete("exRNAInternalKBName")
        @settings.delete("exRNAInternalKBPICodesColl")
        @settings.delete("exRNAInternalKBToolUsageColl")
        @settings.delete("grantNumbers")
        @settings.delete("otherDataRepo") unless(@settings['anticipatedDataRepo'] == "Other")
        @settings.delete("remoteStorageAreas")
      # If we have any errors above, we will return an @exitCode of 22 and give an informative message for the user.
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error with processJobConf: #{err.message.inspect}")
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
        # Get data
        @user = @pass = nil
        if(@dbrcKey)
          dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
          @user = dbrc.user
          @pass = dbrc.password
          @host = dbrc.driver.split(/:/).last
        else
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @dbrcFile)
          @user = suDbDbrc.user
          @pass = suDbDbrc.password
          @host = suDbDbrc.driver.split(/:/).last
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "BEGIN KNIFE (version #{@toolVersion}) batch processing")
        # Grab current version of KNIFE
        @toolVersion = @toolConf.getSetting('info', 'version')
        # @inputFiles will hold the names of all of our input files
        @inputFiles = []
        # @errInputHash will hold file names of files that aren't proper inputs (wrong format, for example) and link those file names to the errors that came up while checking them
        @errInputHash = {}
        @failedSubmissions = {}
        # @fileCounts will solve the problem of downloading 2+ files of the same name (SRR9234.fastq and SRR9234.fastq, for example)
        # If we encounter the same file name while going through our downloaded files, we will add 2, 3, etc. to the end depending on how many we've already seen
        @fileCounts = {}
        # @sniffer will be used to check whether input files are FASTQ
        @sniffer = BRL::Genboree::Helpers::Sniffer.new()
        # Unless we're running KNIFE locally, we'll download our input files and check to make sure that they're FASTQ
        unless(@localJob)
          downloadAndCheckInputs()
        end
        raise @errUserMsg unless(@exitCode == 0)
        # Depending on how the user submitted his/her files, they could be all over the place in different directories.
        # Let's move all the files to organized subdirectories so that we can easily submit our KNIFE jobs
        createKnifeSubjobDirectories(@inputFiles)
        raise @errUserMsg unless(@exitCode == 0)
        # @runKnifeJobSubmissionFailures will keep track of which runKnife jobs are not submitted properly (to report to user)
        @runKnifeJobSubmissionFailures = {}
        # Set @runKnifeToolId to be runKnife (used when submitting precondition jobs)
        @runKnifeToolId = "runKnife"
        # conditionalJob boolean will keep track of whether any worker job was submitted (at least one runKnife job) - if so, we'll launch our erccFinalProcessing conditional job
        conditionalJob = false
        # Create a reusable ApiCaller instance for launching each runKnife job
        apiCaller = BRL::Genboree::REST::ApiCaller.new(@host, "/REST/v1/genboree/tool/{toolId}/job", @user, @pass)
        # @preConditionJobs will be used in the conditions for our erccFinalProcessing job
        @preConditionJobs = []
        # Grab all sub-job directories for different submissions to runKnife - each directory will be an input for a runKnife worker job
        subJobDirectories = Dir.entries(@knifeJobsDir)
        subJobDirectories.delete(".")
        subJobDirectories.delete("..")
        subJobDirectories.each { |currentSubJob|
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current sub-directory: #{currentSubJob}")
          # Create a job conf for the current input file
          currentSubJob = "file://#{@knifeJobsDir}/#{currentSubJob}"
          runKnifeJobObj = createRunKnifeJobConf(currentSubJob)
          begin
            # Submit job for current input file 
            $stderr.debugPuts(__FILE__, __method__, "runKnifePipeline job conf for #{currentSubJob}", JSON.pretty_generate(runKnifeJobObj))
            httpResp = apiCaller.put({ :toolId => @runKnifeToolId }, runKnifeJobObj.to_json)
            # Check result
            if(apiCaller.succeeded?)
              # We succeeded in launching at least one runKnife job, so we set conditionalJob to be true (so that erccFinalProcessing will run below)
              conditionalJob = true
              $stderr.debugPuts(__FILE__, __method__, "Response to submitting runKnife job conf for #{currentSubJob}", JSON.pretty_generate(apiCaller.parseRespBody))
              # We'll grab its job ID and save it in @listOfJobIds
              runKnifeJobId = apiCaller.parseRespBody['data']['text']
              @listOfJobIds[runKnifeJobId] = File.basename(currentSubJob)
              $stderr.debugPuts(__FILE__, __method__, "Job ID associated with #{currentSubJob}", runKnifeJobId)
              # We'll make a hash for the condition associated with the current job 
              condition = {
                "type" => "job",
                "expires" => (Time.now + Time::WEEK_SECS * 4).to_s,
                "met" => false,
                "condition"=> {
                  "dependencyJobUrl" => "http://#{@host}/REST/v1/job/#{runKnifeJobId}",
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
              # We'll add that condition to our @preConditionJobs array
              $stderr.debugPuts(__FILE__, __method__, "Condition connected with runKnife job associated with #{currentSubJob}", condition)
              @preConditionJobs << condition
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "runKnife job accepted with analysis name: #{runKnifeJobObj['settings']['analysisName'].inspect}.\nHTTP Response: #{httpResp.inspect}\nStatus Code: #{apiCaller.apiStatusObj['statusCode'].inspect}\nStatus Message: #{apiCaller.apiStatusObj['msg'].inspect}\n#{'='*80}\n")
            else
              $stderr.debugPuts(__FILE__, __method__, "ERROR (but continuing)", "#{@runKnifeToolId} job submission failed! HTTP Response Object: #{httpResp.class}.\nResponse Payload:\n#{apiCaller.respBody}\n#{'='*80}\n")
              @failedSubmissions[currentSubJob] = apiCaller.respBody
            end
          rescue => err
            $stderr.debugPuts(__FILE__, __method__, "ERROR (but continuing)", "Problem with submitting the runKnife job #{runKnifeJobObj.inspect}: #{err.message.inspect}.\n#{err.backtrace.join("\n")}")
            @failedSubmissions[currentSubJob] = err.message.inspect
          end
        }
        # Write @listOfJobIds to a text file, saving path to text file in @settings
        @settings['filePathToListOfJobIds'] = "#{@jobSpecificSharedScratch}/listOfJobIds.txt"
        File.open(@settings['filePathToListOfJobIds'], 'w') { |file| file.write(JSON.pretty_generate(@listOfJobIds)) }
        # If any runKnife jobs were launched above, we'll run erccFinalProcessing tool as a conditional job
        if(conditionalJob)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Run erccFinalProcessing as conditional job")
          erccFinalProcessing()
        else
          @errUserMsg = "None of your samples could be submitted. Please see specific error messages below."
          raise @errUserMsg
        end 
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE with batch submission of KNIFE (version #{@toolVersion}) jobs. END.") 
        # DONE KNIFE batch submission
      # If an error occurs at any point in the above, we'll return an @exitCode of 30 (if exit code hasn't already been set) and give an informative message for the user.
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of KNIFE batch submission tool failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @exitCode = 30 if(@exitCode == 0)
      end
      return @exitCode
    end

####################################
#### Methods used in this wrapper
####################################

    # Download input files from database
    # @return [FixNum] exit code to indicate whether download was successful
    def downloadAndCheckInputs()
      begin
        # We will download our inputs using the thread-based method in fileApiUriHelper
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input files using threads #{@inputs.inspect}")
        # If job is not local, then we need to download our inputs. Otherwise, our inputs will be the local file paths.
        unless(@localJob)
          uriPartition = @fileApiHelper.downloadFilesInThreads(@inputs, @userId, @jobSpecificSharedScratch)
          localPaths = uriPartition[:success].values
        else
          localPaths = @inputs
        end
        localPaths.each { |inputFile|
          # Check all inputs inside of current input (could be .zip with multiple files inside) - we check recursively
          checkInputs(inputFile)
        }
        # If @errInputHash isn't empty (some files were erroneous), then we raise an error for user and let them know which files were erroneous.
        unless(@errInputHash.empty?)
          @errUserMsg = "Errors occurred when decompressing / checking your input files. The following errors were found:\n\n"
          @errInputHash.each_key { |currentKey|
            @errUserMsg << "#{File.basename(currentKey)}: #{@errInputHash[currentKey]}\n"
          }
          raise @errUserMsg
        end
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (hopefully won't happen)
        @errUserMsg = "ERROR: Could not download / decompress / check your files correctly." if(@errUserMsg.nil?)
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", @errBacktrace)
        @exitCode = 23
      end
      return @exitCode
    end

    # Method that is used recursively to check what inputs each submitted file contains
    # @param [String] inputFile file name or folder name currently being checked
    # @return [FixNum] exitCode to indicate whether method failed or succeeded
    def checkInputs(inputFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current input file: #{inputFile}")
      # First, check to see if inputFile is a directory. If it's not, we'll just extract it.
      unless(File.directory?(inputFile))
        exp = BRL::Util::Expander.new(inputFile)
        exp.extract()
        # If inputFile was an archive, we're going to delete it (since we've extracted it)
        `rm -f #{inputFile}` unless(exp.compressedFileName == exp.uncompressedFileName)
        # Set inputFile to be the new, unextracted file name
        inputFile = exp.uncompressedFileName
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uncompressed file name: #{inputFile}")
      end
      # Now, we'll check to see if the file is a directory or not - remember, we could have 
      # uncompressed a directory above!
      if(File.directory?(inputFile))
        # If we have a directory, grab all files in that directory and send them all through checkInputs recursively
        allFiles = Dir.entries(inputFile)
        allFiles.each { |currentFile|
          next if(currentFile == "." or currentFile == "..")
          checkInputs("#{inputFile}/#{currentFile}")
        }
      else
        # OK, so we have a file. First, let's make the file name safe 
        fixedInputFile = File.basename(inputFile).makeSafeStr(:ultra)
        # Grab a count of file name (we want to handle having multiple files with same name)
        currentCount = (@fileCounts[fixedInputFile] ? (@fileCounts[fixedInputFile] + 1) : 1)
        # Update count for current file name 
        @fileCounts[fixedInputFile] = currentCount
        # If current count is greater than 1, then we need to add that number to the beginning of our file name
        # in order to handle multiple files with same name 
        if(currentCount > 1)
          fixedInputFile = "#{currentCount}_#{fixedInputFile}"
        end
        # Get full path of input file and replace last part of that path (base name) with fixed file name
        inputFileArr = inputFile.split("/")
        inputFileArr[-1] = fixedInputFile
        fixedInputFile = inputFileArr.join("/")
        # Rename file so that it has fixed file name
        `mv #{Shellwords.escape(inputFile)} #{fixedInputFile}`
        # Sniff file and see whether it's ASCII
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Sniffing #{fixedInputFile}")
        @sniffer.filePath = fixedInputFile
        # We only want ASCII so we reject the file if it's not ASCII
        # ?? Should we accept other ASCII-based formats ??
        unless(@sniffer.detect?('fastq'))
          @errInputHash[inputFile] = "#{inputFile} is not in FASTQ format."
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Sniffing successful for #{fixedInputFile}")
          # Convert ASCII file to Unix format
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Converting #{fixedInputFile} to UNIX")
          convObj = BRL::Util::ConvertText.new(fixedInputFile, true)
          convObj.convertText()
          # If input file name contains "unaligned", we need to remove that token since it is reserved for the KNIFE tool
          if(File.basename(fixedInputFile).include?("unaligned"))
            newFile = fixedInputFile.split("/")
            newFile[-1].slice!("unaligned")
            newFile = newFile.join("/")
            `mv #{fixedInputFile} #{newFile}`
            fixedInputFile = newFile
          end
          # Finally, push file onto @inputFiles array
          @inputFiles.push(fixedInputFile)
        end
      end
    end
    
    # Method which creates individual KNIFE subdirectories for each submitted single-end FASTQ file (or pair of paired-end FASTQ files)
    # @param [Array] inputFiles array which contains full paths of input files
    # @return [Fixnum] exit code which tells us whether job failed (24) or succeeded (0)
    def createKnifeSubjobDirectories(inputFiles)
      begin
        # Traverse all input files
        inputFiles.each { |currentFile|
          # Create sub job directory for current KNIFE job
          currentSubDirectory = File.basename(currentFile).chomp(".fq").chomp(".fastq").chomp("_R1").chomp("_R2").chomp("_1").chomp("_2")
          fullSubJobDirectory = "#{@knifeJobsDir}/#{currentSubDirectory}"
          `mkdir #{fullSubJobDirectory}`
          # Move current input to its sub job directory and save new path to current input in newCurrentFile
          `mv #{currentFile} #{fullSubJobDirectory}/#{File.basename(currentFile)}`
          newCurrentFile = "#{fullSubJobDirectory}/#{File.basename(currentFile)}"
          # If our current file ends in one of the paired-end suffixes (_1 / _2 or _R1 / _R2), then it is most likely a paired-end read and we need to find its partner.
          if(File.basename(newCurrentFile) =~ /_R?(1|2)\.(fq|fastq)$/)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current file #{File.basename(currentFile)} has a name which most likely identifies it as a paired-end read")
            # Grab prefix from current file (must match the other associated paired-end read)
            baseName = File.basename(newCurrentFile)
            prefix = baseName[0...baseName.index(/_R?(1|2)\.(fq|fastq)$/)]
            firstSuffix = baseName[baseName.index(/_R?(1|2)\.(fq|fastq)$/)..-1]
            # foundOtherRead boolean will keep track of whether we've found the associated paired-end read
            foundOtherRead = false
            # Set the regular expression for the associated paired-end read (_2 if current paired-end read is _1, _1 if current paired-end read is _2, etc.)
            otherReadRegExp = nil
            if(newCurrentFile =~ /_R?1\.(fq|fastq)$/)
              otherReadRegExp = /#{prefix}_R?2\.(fq|fastq)$/
            else
              otherReadRegExp = /#{prefix}_R?1\.(fq|fastq)$/
            end
            # Look through all input files and check for the associated paired-end read
            inputFiles.each { |currentFile2|
              # If we find a matching file (associated paired-end read), then we proceed
              if(File.basename(currentFile2) =~ otherReadRegExp)
                # We log an error if we find two or more associated paired-end read files with the current paired-end read file)
                unless(foundOtherRead)
                  # It's possible that the regular expression above matched two files that don't actually have completely complementary suffixes.
                  # Example: test_1.fq and test_R2.fastq (1 versus R2 and .fq versus .fastq).
                  # We could raise an error and make the user fix this problem, but let's just try to fix it for them.
                  # We grabbed the first suffix above (_1.fq, maybe), and we grab the second suffix below (_R2.fastq, maybe).
                  # We clone currentFile2 as secondFile because we want to delete currentFile2 from our inputFiles array after we're finished with it,
                  # and we might alter currentFile2 by editing its suffix
                  secondFile = currentFile2.clone()
                  baseName2 = File.basename(currentFile2)
                  secondSuffix = baseName2[baseName2.index(/_R?(1|2)\.(fq|fastq)$/)..-1]
                  # newSuffix will store a complementary suffix to the first suffix (_2.fq if first suffix is _1.fq, for example)
                  newSuffix = ""
                  if(firstSuffix.include?("1"))
                    newSuffix = firstSuffix.gsub("1", "2")
                  else
                    newSuffix = firstSuffix.gsub("2", "1")
                  end
                  # Now, if the second suffix doesn't match this new suffix (it should!), then we will fix the file name so that it does match properly
                  unless(secondSuffix == newSuffix)
                    newBaseName2 = "#{prefix}#{newSuffix}"
                    newFullPath2 = "#{File.dirname(currentFile2)}/#{newBaseName2}"
                    `mv #{currentFile2} #{newFullPath2}`
                    # We'll also save the new full path to the second file (in secondFile) and the new, corrected suffix in secondSuffix 
                    secondFile = newFullPath2
                    secondSuffix = newSuffix
                  end
                  # Now, we'll move the second paired-end file to the same directory as the first paired-end file (so they're together)
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Found #{File.basename(secondFile)} which is the other paired-end read for #{File.basename(currentFile)}")
                  `mv #{secondFile} #{fullSubJobDirectory}/#{File.basename(secondFile)}`
                  # Let's go ahead and rename the job directory, too, so it's clear that it's a paired-end submission
                  newSubJobDirectory = "#{fullSubJobDirectory}#{firstSuffix.chomp(".fq").chomp(".fastq")}_and#{secondSuffix.chomp(".fq").chomp(".fastq")}"
                  `mv #{fullSubJobDirectory} #{newSubJobDirectory}`
                  # We delete the other associated paired-end entry from inputFiles after we find it. This should be OK since we're never going to be deleting the current element
                  inputFiles.delete(currentFile2)
                  # Since we found a matching read, we set foundOtherRead to be true.
                  foundOtherRead = true
                else
                  @errInputHash[currentFile] = "File #{File.basename(currentFile)} has a name which identifies it as a paired-end read, but we found multiple other associated reads.\nPlease make sure that any paired-end read only has one other paired-end read associated with it."
                end
              end
            }
            # If we don't find an associated paired-end read for our current read, then we are most likely dealing with a single-end read submission
            unless(foundOtherRead)
              # If the paired-end read suffix indicates that the read is the SECOND read, then we raise an error because it should have an accompanying FIRST paired-end read.
              # Otherwise, if the paired-end read suffix indicates that the read is the FIRST read, then we assume that it's a single-end submission.
              if(firstSuffix.include?("2"))
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "File #{File.basename(currentFile)} has a name which identifies it as the SECOND read in a set of paired-end reads.\nHowever, we couldn't find the FIRST read (_1 / _R1) associated with this second read.")
                @errInputHash[currentFile] = "File #{File.basename(currentFile)} has a name which identifies it as the SECOND read in a set of paired-end reads.\nHowever, we couldn't find the FIRST read (_1 / _R1) associated with this second read."
              else
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Could not find an associated paired-end read for current file #{File.basename(currentFile)}. It is possible that it is a single-end read, so we won't raise an error here. If we're wrong, KNIFE will hopefully complain!")
                # Rename sub-job directory to include _1 / _R1
                newSubJobDirectory = "#{fullSubJobDirectory}#{firstSuffix.chomp(".fq").chomp(".fastq")}"
                `mv #{fullSubJobDirectory} #{newSubJobDirectory}`
              end
            end
          else
            # If current file does NOT have one of the paired-end suffixes, we just assume that it's a single-end read
            # However, we also need to update its name so that it matches the convention expected by KNIFE (file name ending in _1 or _R1).
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current file #{File.basename(currentFile)} has no paired-end suffix, so we're going to assume it's single-end. We need to add _R1 to the end of the file name because it's KNIFE's convention.")
            newFile = newCurrentFile.split("/")
            indexOfFileExtension = newFile[-1].index(/\.(fq|fastq)/)
            newFile[-1].insert(indexOfFileExtension, "_R1")
            newFile = newFile.join("/")
            `mv #{newCurrentFile} #{newFile}`
            # Now, let's rename the sub-job directory to indicate that this is a single-end read
            newSubJobDirectory = "#{fullSubJobDirectory}_R1"
            `mv #{fullSubJobDirectory} #{newSubJobDirectory}`
          end
        }
        # If @errInputHash isn't empty (some files were erroneous), then we raise an error for user and let them know which files were erroneous.
        unless(@errInputHash.empty?)
          @errUserMsg = "Errors occurred when organizing your input files.\nThe following errors were found:\n\n"
          @errInputHash.each_key { |currentKey|
            @errUserMsg << "#{File.basename(currentKey)}: #{@errInputHash[currentKey]}\n"
          }
          raise @errUserMsg
        end        
      rescue => err
        # Generic error message if an error pops up that wasn't handled effectively by the above checks (hopefully won't happen)
        @errUserMsg = "ERROR: Could not create subdirectories for individual KNIFE jobs." if(@errUserMsg.nil?)
        @errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", @errBacktrace)
        @exitCode = 24
      end
      return @exitCode
    end

    # Method to create a KNIFE job conf file given the path to some sub-job dir.
    # @param [String] currentSubJobDir file path to current sub-job dir
    # @return [Hash] hash containing the job conf file
    def createRunKnifeJobConf(currentSubJobDir)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Preparing the exceRpt jobConf for #{currentSubJobDir}")
      # Reuse the existing jobConf and modify properties as needed 
      runKnifeJobConf = @jobConf.deep_clone()
      # Define input for job conf
      runKnifeJobConf['inputs'] = currentSubJobDir
      # We will keep the same output database
      # Define context
      runKnifeJobConf['context']['toolIdStr'] = @runKnifeToolId
      runKnifeJobConf['context']['warningsConfirmed'] = true
      return runKnifeJobConf
    end
   
    # Submit an erccFinalProcessing job (to run after all KNIFE jobs finish)
    # @return [nil]
    def erccFinalProcessing()
      # Produce erccFinalProcessing job file
      createERCCFinalProcessingJobConf()
      # Launch erccFinalProcessing job
      launchERCCFinalProcessingJob()
      return
    end
   
    # Method to create erccFinalProcessing job conf used in launchERCCFinalProcessingJob()
    # @return [nil]
    def createERCCFinalProcessingJobConf()
      @erccJobConf = @jobConf.deep_clone()
      # Define context
      @erccJobConf['context']['toolIdStr'] = "erccFinalProcessing"
      @erccJobConf['preconditionSet'] =  {
        "willNeverMatch"=> false,
        "numMet"=> 0,
        "someExpired"=> false,
        "count"=> 0,
        "preconditions"=> @preConditionJobs
      }
      return
    end
    
    # Method to call erccFinalProcessing job
    # @return [nil]
    def launchERCCFinalProcessingJob()
      apiCaller = BRL::Genboree::REST::ApiCaller.new(@host, "/REST/v1/genboree/tool/erccFinalProcessing/job", @user, @pass)
      apiCaller.put({}, @erccJobConf.to_json)
      unless(apiCaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "ERCC JOB SUBMISSION FAILURE", apiCaller.respBody.inspect)
        $stderr.debugPuts(__FILE__, __method__, "ERCC JOB SUBMISSION FAILURE", @erccJobConf.inspect)
      else
        $stderr.debugPuts(__FILE__, __method__, "ERCC JOB SUBMISSION SUCCESS", apiCaller.respBody.inspect)
      end
      return
    end

###################################################################################
    def prepSuccessEmail()
      @settings = @jobConf['settings']
      # Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
      @settings.delete("jobSpecificSharedScratch")
      # Delete local path to list of job IDs text file
      @settings.delete("filePathToListOfJobIds")
      @settings.delete("piID")
      @settings.delete("platform")
      @settings.delete("primaryJobId")
      @settings.delete("processingPipeline")
      @settings.delete("processingPipelineIdAndVersion")
      @settings.delete("processingPipelineVersion")
      @settings.delete('remoteStorageArea') if(@settings['remoteStorageArea'] == nil)
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @userFirstName
      emailObject.userLast      = @userLastName
      emailObject.analysisName  = @analysisName
      inputsText                = buildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @settings
      emailObject.exitStatusCode = @exitCode
      runKnifeJobIds = @listOfJobIds.keys
      numJobsSubmitted = runKnifeJobIds.length
      additionalInfo = ""
      additionalInfo << "Your samples have been submitted for processing through KNIFE.\n" +
                        "You will receive an email when each job finishes and also after all samples in the batch have been processed.\n" + 
                        "\n==================================================================\n" +
                        "Number of jobs successfully submitted for processing: #{numJobsSubmitted}\n\n" +
                        "List of job IDs with respective input files: \n"
      @listOfJobIds.each_key { |jobId|
        additionalInfo << "JOB ID: #{jobId}\n" +
                          "Input: #{@listOfJobIds[jobId]}\n\n"
      }
      unless(@failedSubmissions.empty?)
        additionalInfo << "We encountered errors when submitting some of your samples. Please see a list of samples and their respective errors below:\n\n"
        @failedSubmissions.each_key { |currentSample|
          additionalInfo << "Current sample: #{currentSample}\n" +
                            "Error message: #{@failedSubmissions[currentSample]}\n\n"
        }
      end
      emailObject.additionalInfo = additionalInfo
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
      @settings.delete("jobSpecificSharedScratch")
      # Delete local path to list of job IDs text file
      @settings.delete("filePathToListOfJobIds")
      @settings.delete("piID")
      @settings.delete("platform")
      @settings.delete("primaryJobId")
      @settings.delete("processingPipeline")
      @settings.delete("processingPipelineIdAndVersion")
      @settings.delete("processingPipelineVersion")
      @settings.delete('remoteStorageArea') if(@settings['remoteStorageArea'] == nil)
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
      if(@failedSubmissions)
        unless(@failedSubmissions.empty?)
          additionalInfo << "We encountered errors when submitting your samples. Please see a list of samples and their respective errors below:\n\n"
          @failedSubmissions.each_key { |currentSample|
            additionalInfo << "Current sample: #{currentSample}\n" +
                              "Error message: #{@failedSubmissions[currentSample]}\n\n"
          }
        end
      end
      emailErrorObject.additionalInfo = additionalInfo unless(additionalInfo.empty?)
      emailErrorObject.erccTool = true
      if(@suppressEmail)
        return nil
      else
        return emailErrorObject
      end
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::KnifeWrapper)
end
