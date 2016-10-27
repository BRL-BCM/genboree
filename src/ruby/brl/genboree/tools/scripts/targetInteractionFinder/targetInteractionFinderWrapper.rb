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
require 'fileutils'
include BRL::Genboree::REST


module BRL; module Genboree; module Tools; module Scripts
  class TargetInteractionFinderWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = {}
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the 'Target Interaction Finder' tool.
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
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        # Genboree specific "context" variables
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
        user = dbrc.user
        pass = dbrc.password
        host = dbrc.driver.split(/:/).last
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        @targetUri = @outputs[0]
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
        @toolVersion = @toolConf.getSetting('info', 'version')
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
        @processingPipeline = "Target Interaction Finder"
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
        @localJob = nil
        @localJob = @settings['localJob'] if(@settings['localJob'])
        # Set up format options coming from the UI - "Settings" variables
        @analysisName = @settings['analysisName']
        @remoteStorageArea = @settings['remoteStorageArea']
        # Make directory where we'll place output files
        @subjobsDir = "#{@scratchDir}/subjobs"
        `mkdir -p #{@subjobsDir}`
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
        @settings.delete("piID")
        @settings.delete("remoteStorageArea") if(@settings["remoteStorageArea"] == nil)
      # If we have any errors above, we will return an @exitCode of 22 and give an informative message for the user.
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. \n"
        @errInternalMsg = "ERROR: Could not set up required variables for running job. \nCheck your jobFile.json to make sure all variables are defined."
        @err = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # [+returns+] nil
    def run()
      begin
        # Get data
        user = pass = nil
        @outFile = @errFile = ""
        if(@dbrcKey)
          dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
          # get super user, pass and hostname
          user = dbrc.user
          pass = dbrc.password
        else
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @dbrcFile)
          user = suDbDbrc.user
          pass = suDbDbrc.password
        end
        @outFile = "#{@scratchDir}/targetInteractionFinder.out"
        @errFile = "#{@scratchDir}/targetInteractionFinder.err"
        # @inputFiles will hold the names of all of our input files
        @inputFiles = []
        # @outputDirs will keep track of the output dir associated with each input file 
        @outputDirs = {}
        # @fileCounts will solve the problem of downloading 2+ files of the same name (mature_sense.grouped and mature_sense.grouped, for example)
        # If we encounter the same file name while going through our downloaded files, we will add 2, 3, etc. to the end depending on how many we've already seen
        @fileCounts = {}
        # @failedRuns will keep track of which input files failed to be processed correctly
        @failedRuns = []
        # @successfulRuns will keep track of which input files were processed correctly
        @successfulRuns = []
        # @sniffer will be used to check whether input files are ASCII
        @sniffer = BRL::Genboree::Helpers::Sniffer.new()
        # Download the input from the server (if not a job run locally)
        unless(@localJob)
          downloadFiles()
        end
        @foundErrorInTargetInteractionFinder = false
        @inputFiles.each { |currentInput|
          # We'll convert the file to be targetInteractionFinder compatible if it's in exceRpt format
          contents = File.read(currentInput)
          newContents = ""
          contents.each_line { |currentLine|
            currentLineTabbed = currentLine.split("\t")
            if(currentLineTabbed[0].include?(":"))
              newContents << "#{currentLineTabbed[0].split(":")[0]}\n"
            else
              newContents << currentLine
            end
          }
          File.open(currentInput, 'w') { |file| file.write(newContents) }
          # Run the tool
          @foundErrorInTargetInteractionFinder = runTargetInteractionFinder(currentInput)
          # If the tool finished successfully, we'll upload the tool's output files
          unless(@foundErrorInTargetInteractionFinder)
            failedRun = false
            allOutputFiles = Dir.entries(@outputDirs[currentInput])
            # Add @analysisName as a prefix to all output files
            prefix = "#{CGI.escape(@analysisName)}"
            allOutputFiles.each { |outputFile|
              next if(outputFile == "." or outputFile == "..")
              newName = "#{prefix}_#{File.basename(currentInput)}_#{outputFile}"
              FileUtils.mv("#{@outputDirs[currentInput]}/#{outputFile}", "#{@outputDirs[currentInput]}/#{newName}")
            }
            # Upload all relevant files
            transferFiles(File.basename(currentInput), @toolVersion, @outputDirs[currentInput]) unless(failedRun)
            @successfulRuns.push(File.basename(currentInput))
          else
            @failedRuns.push(File.basename(currentInput))
          end
        }
        if(@failedRuns.size == @inputFiles.size)
          @errUserMsg = "None of your files generated results.\nThis is most likely because they are not in the proper format.\nPlease make sure that each submitted file has a column of miRNA identifiers\n(this column must be the first column in the file!)."
          @exitCode = 26
        end
      # If an error occurs at any point in the above, we'll return an @exitCode of 30 (if exit code hasn't already been set) and give an informative message for the user.
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of Target Interaction Finder tool failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to run Target Interaction Finder tool." if(@errInternalMsg.nil?)
        @exitCode = 30 if(@exitCode == 0)
      ensure
        submitToolUsageDoc(user, pass) unless(@jobId[0..4] == "AUTO-")  
      end
      return @exitCode
    end

####################################
#### Methods used in this wrapper
####################################

    # Download input files from database
    # @return [FixNum] exit code to indicate whether download was successful
    def downloadFiles()
      begin
        # We traverse all inputs
        @inputs.each { |input|
          # Below, we figure out what file name we should give our new file
          # First, we create a "safe" string based on the base file name of our input file 
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input file #{input}")
          fileBase = @fileApiHelper.extractName(input)
          fileBaseName = File.basename(fileBase)
          tmpFile = fileBaseName.makeSafeStr(:ultra)
          # Then, if our input is coming from an exceRpt pipeline job, we go ahead and put the analysis name of the exceRpt job into the file name
          # This is to differentiate between different exceRpt jobs, since the file name doesn't inherently have the analysis name in it
          # (It's just readCounts_miRNAmature_sense.txt or something)
          # NOTE: Using an entire read count file from exceRpt for this tool is a bad idea, as there are too many identifiers present
          # This tool is for more targeted analysis (fewer miRNA identifiers)
          if(input.include?("exceRptPipeline_v"))
            tmpFile = "#{File.dirname(tmpFile)}/#{input.split("/")[-2]}_#{File.basename(tmpFile)}"           
          end
          # It could still be the case that we have another file, on disk already, with the same name as the one we just found above
          # Since we don't want to overwrite our old file, we need to add some prefix (currentIndex) to our file name so that we know it's unique
          # We'll keep trying different index numbers (incremented one at a time) until we find a file name that doesn't already exist
          currentIndex = @inputs.index(input) + 1
          while(File.exists?(tmpFile))
            tmpFile = "#{File.dirname(tmpFile)}/#{currentIndex}_#{File.basename(tmpFile)}"
            currentIndex += 1
          end
          retVal = @fileApiHelper.downloadFile(input, @userId, tmpFile)
          # If we are unable to download our file successfully, we will set an error message for the user.
          if(!retVal)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Failed to download file: #{fileBase} from server.")
            @errUserMsg = "Failed to download file: #{fileBase} from server"
            raise @errUserMsg
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "File downloaded successfully to #{tmpFile}")
          end
          # @errInputArray will hold file names of files that aren't proper inputs (wrong format, for example) associated with current input
          @errInputArray = []
          # Check all inputs inside of current input (could be .zip with multiple files inside) - we check recursively
          checkForInputs(tmpFile)
          # If @errInputArray isn't empty (some files were erroneous), then we raise an error for user and let them know which files were erroneous.
          unless(@errInputArray.empty?)
            @errUserMsg = "Errors occurred when decompressing / checking your input file #{tmpFile}. The following errors were found:\n\n#{@errInputArray.join("\n")}"
            raise @errUserMsg
          end
        }
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
    def checkForInputs(inputFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current input file: #{inputFile}")
      # First, check to see if inputFile is a directory. If it's not, we'll just extract it.
      unless(File.directory?(inputFile))
        exp = BRL::Util::Expander.new(inputFile)
        exp.extract()
        inputFile = exp.uncompressedFileName
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uncompressed file name: #{inputFile}")
      end
      # Now, we'll check to see if the file is a directory or not - remember, we could have 
      # uncompressed a directory above!
      if(File.directory?(inputFile))
        # If we have a directory, grab all files in that directory and send them all through checkForInputs recursively
        allFiles = Dir.entries(inputFile)
        allFiles.each { |currentFile|
          next if(currentFile == "." or currentFile == "..")
          checkForInputs("#{inputFile}/#{currentFile}")
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
        unless(@sniffer.detect?('ascii'))
          @errInputArray.push("#{File.basename(fixedInputFile)} is not in ASCII format.")
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Sniffing successful for #{fixedInputFile}")
          # Convert ASCII file to Unix format
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Converting #{fixedInputFile} to UNIX")
          convObj = BRL::Util::ConvertText.new(fixedInputFile, true)
          convObj.convertText()
          # Finally, push file onto @inputFiles array
          @inputFiles.push(fixedInputFile)
        end
      end
    end
       
    # Run Target Interaction Finder
    # @param [String] inputFile path to current input file being processed through Target Interaction Finder
    # @return [String] information about any errors found while running Target Interaction Finder
    def runTargetInteractionFinder(inputFile)
      inputFileBaseName = File.basename(inputFile)
      currentSubjobDir = "#{@subjobsDir}/#{inputFileBaseName}"
      `mkdir -p #{currentSubjobDir}`
      `mv #{inputFile} #{currentSubjobDir}/`
      currentOutputDir = "#{currentSubjobDir}/output"
      `mkdir -p #{currentOutputDir}`
      @outputDirs[inputFile] = currentOutputDir
      inputFile = "#{currentSubjobDir}/#{inputFileBaseName}"
      # Commands for actually launching the Python script that will run the tool
      command = "ln -s #{ENV['SOURCE_XGMML']}/*.xgmml #{currentSubjobDir}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      command = "python #{ENV['TARGETPREDICTIONFINDER']} #{inputFile} -s #{currentSubjobDir}/ -o #{currentOutputDir}/ 1>#{@outFile} 2>#{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      # Check to see if the run had any errors
      exitStatus = system(command)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Exit status: #{exitStatus}")
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Target Interaction Finder tool command completed with exit code: #{statusObj.exitstatus}")
      foundError = findError(exitStatus)
      return foundError
    end

    # Transfer output files to user database
    # @param [String] subjobName name of subjob (results will be placed into directory for subjob)
    # @param [String] outputDir path to current output directory
    # @return [FixNum] exitCode to indicate whether method succeeded or failed
    def transferFiles(subjobName, toolVersion, outputDir)
      # Find target URI for user's database
      targetUri = URI.parse(@outputs[0])
      # Set resource path
      if(@remoteStorageArea)
        rsrcPath = "#{targetUri.path}/file/#{CGI.escape(@remoteStorageArea)}/targetInteractionFinder_v#{toolVersion}/{analysisName}/{subjobName}/{outputFile}/data?"
      else 
        rsrcPath = "#{targetUri.path}/file/targetInteractionFinder_v#{toolVersion}/{analysisName}/{subjobName}/{outputFile}/data?"
      end
      # We also need to add our gbKey for access (if it exists)
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      # Upload all output files
      allOutputFiles = Dir.entries(outputDir)
      allOutputFiles.each { |outputFile|
        next if(outputFile == "." or outputFile == "..")
        uploadFile(targetUri.host, rsrcPath, @userId, "#{outputDir}/#{outputFile}", {:analysisName => @analysisName, :subjobName => subjobName, :outputFile => outputFile})
      }
    end

    ## Upload a given file to Genboree server
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
    end
   
    # Method to detect errors
    # @param [boolean] exitStatus indicating if the system() call "succeeded" or not.
    # @return [boolean] indicating if a targetInteractionFinder error was found or not.
    #   if so, @errUserMsg, @errInternalMsg, @exitCode will be set appropriately
    def findError(exitStatus)
      retVal = true
      errorMessages = nil
      # Check the obvious things first. Outright failure or putting error messages on stderr:
      if(exitStatus)
        # So far, so good. Look for ERROR lines on stdout.
        cmd = "grep -i \"ERROR\" #{@outFile} #{@errFile} | grep -v \"Backtrace\""
        errorMessages = `#{cmd}`
        if(errorMessages.strip.empty?)
          retVal = false
        end
      end
      return retVal
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
      toolUsage.setPropVal("ERCC Tool Usage.Samples Processed Through ERCC Pipeline", (@successfulRuns.size + @failedRuns.size))
      @successfulRuns.each { |currentSample|
        runItem = BRL::Genboree::KB::KbDoc.new({})
        runItem.setPropVal("Sample Name", currentSample)
        runItem.setPropVal("Sample Name.Sample Status", "Completed")
        toolUsage.addPropItem("ERCC Tool Usage.Samples Processed Through ERCC Pipeline", runItem)
      }
      @failedRuns.each { |currentSample|
        runItem = BRL::Genboree::KB::KbDoc.new({})
        runItem.setPropVal("Sample Name", currentSample)
        runItem.setPropVal("Sample Name.Sample Status", "Failed")
        toolUsage.addPropItem("ERCC Tool Usage.Samples Processed Through ERCC Pipeline", runItem)
      }
      toolUsage.setPropVal("ERCC Tool Usage.Number of Successful Samples", @successfulRuns.size)
      toolUsage.setPropVal("ERCC Tool Usage.Number of Failed Samples", @failedRuns.size)
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
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Payload is: #{payload.to_json.inspect}")
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
      @settings = @jobConf['settings']
      
      if(@useIndex =~ /useExistingIndex/)
        indexList = @settings['indexList']
        indexName = File.basename(indexList)

        files = @fileApiHelper.extractName(indexList)
        fileString = files.gsub(/\//, " >> ")
        @settings.delete('indexList')
      end
       
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
      additionalInfo = ""
      additionalInfo << "You can download result files from this location:\n" + 
                          "|-Group: '#{@groupName}'\n" +
                            "|--Database: '#{@dbName}'\n" +
                              "|---Files\n" +
                                "|----TargetInteractionFinder_v#{@toolVersion}\n"+
                                  "|-----#{@analysisName}\n\n"
      if(@failedRuns.size > 0)
        additionalInfo << "At least one of your submitted files did not generate any results.\n" +
                          "This is most likely because they are not in the proper format.\n" +
                          "Please make sure that each submitted file has a column of miRNA identifiers\n" +
                          "(the column must be the first column in the file!).\n\n" +
                          "You can see a list of failed files below:\n\n" 
        @failedRuns.each { |currentFailedRun|
          additionalInfo << "#{currentFailedRun}\n"
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

    def prepErrorEmail()
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
      emailErrorObject.erccTool       = true
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
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::TargetInteractionFinderWrapper)
end
