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
  class RunKnifeWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.2"
    COMMAND_LINE_ARGS = {}
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the 'KNIFE (Known and Novel IsoForm Explorer)' tool on a single sample.
                        This tool is intended to be called via the knife wrapper (batch-processing) and NOT by the Genboree Workbench.",
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
        # Genboree specific "context" variables
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        @outputDir = "#{@scratchDir}/outputs"
        `mkdir -p #{@outputDir}`
        @targetUri = @outputs[0]
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
        # Set up format options coming from the UI - "Settings" variables
        @analysisName = @settings['analysisName']
        @isRemoteStorage = true if(@settings['remoteStorageArea'])
        if(@isRemoteStorage)
          @remoteStorageArea = @settings['remoteStorageArea']
        end
        @organism = @settings['organism']
        # Delete items from settings that we don't need
        @settings.delete("jobSpecificSharedScratch")
        # Delete local path to list of job IDs text file
        @settings.delete("filePathToListOfJobIds")
        @settings.delete("piID")
        @settings.delete("platform")
        @settings.delete("primaryJobId")
        @settings.delete("processingPipeline")
        @settings.delete("processingPipelineIdAndVersion")
        @settings.delete("processingPipelineVersion")
        @settings.delete("localJob")
        @settings.delete('remoteStorageArea') if(@settings['remoteStorageArea'] == nil)
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
        # Grab input file and cut off file:// prefix so that we have the location on disk (in cluster shared scratch area)
        inputDir = @inputs[0].clone
        inputDir.slice!("file://")
        @baseNameForInputDir = File.basename(inputDir)
        @outFileForKnife = "#{@scratchDir}/out.log"
        @outFileForWrapper = "#{@scratchDir}/outFileForWrapper.out"
        @errFileForWrapper = "#{@scratchDir}/errFileForWrapper.err"
        # Grab current version of KNIFE
        @toolVersion = @toolConf.getSetting('info', 'version')
         # @failedRun keeps track of whether the sample was successfully processed
        @failedRun = false
        begin
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running runKnife method to process sample #{inputDir}")
          runKnife(inputDir, @outputDir, @outFileForKnife)
        rescue => err
          # If an error occurs, we'll mark the run as failed and set the error message accordingly
          @failedRun = true
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error message occurred while running runKnife method: #{err.message.inspect}")
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Backtrace: #{err.backtrace.join("\n")}")
          @errUserMsg = "An unknown error occurred while processing your KNIFE sample: #{err.message.inspect}."
          @exitCode = 29
        end
        if(@failedRun)
          raise @errUserMsg
        else
          compressOutputs(inputDir, @outputDir, @outFileForWrapper, @errFileForWrapper)
          raise @errUserMsg unless(@exitCode == 0)
          transferOutputs(inputDir, @outputDir, @fullPathResultsZip, @fullPathCoreResultsZip, @outFileForKnife)
          raise @errUserMsg unless(@exitCode == 0)
        end
      # If an error occurs at any point in the above, we'll return an @exitCode of 30 (if exit code hasn't already been set) and give an informative message for the user.
      rescue => err
        @failedRun = true
        @errUserMsg = "ERROR: Running of KNIFE tool failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @exitCode = 30 if(@exitCode == 0)
      end
      return @exitCode
    end

####################################
#### Methods used in this wrapper
####################################

    # Run KNIFE
    # @param [String] inputDir path to sub job dir that contains current inputs files
    # @param [String] outputDir path to output directory where output files will be created
    # @param [String] outFile path to .out file that will be used for printing out / err messages for KNIFE tool
    # @return [Boolean] boolean that tells us whether error occurred while running KNIFE
    def runKnife(inputDir, outputDir, outFile)
      # If our organism is NOT human (hg19), then we need to supply the name of the organism to the end of our mode parameter (which normally just consists of "phred64")
      organismParameter = ""
      unless(@organism == "human")
        organismParameter = "phred64_#{@organism}"
      else
        organismParameter = "phred64"
      end
      # Create command for actually launching the shell script that will run the tool
      command = "sh completeRun.sh #{inputDir} complete #{outputDir} #{File.basename(inputDir)} 8 #{organismParameter} circReads 40 > #{outFile} 2>&1"
      # Launch command
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      # Check exit status of tool
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Exit status: #{exitStatus}")
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "KNIFE tool command completed with exit code: #{statusObj.exitstatus}")
      # Check for errors from tool run
      findError(exitStatus)
      return
    end

    # Method to detect errors
    # @param [boolean] exitStatus indicating if the system() call "succeeded" or not.
    # @return [boolean] indicating if a KNIFE error was found or not.
    def findError(exitStatus)
      retVal = true
      errorMessages = nil
      # Check the obvious things first. Outright failure or putting error messages on stderr:
      if(exitStatus)
        # So far, so good. Let's do some checks to further verify that we didn't get any errors
        # Check #1: Did any reads align?
        cmd = "grep -iP \"0.00%\s+overall\s+alignment\s+rate\" #{@outFileForKnife}"
        cmd2 = "grep -iP \"Runtime\s+error\s+(func=(main),\s+adr=9):\s+Divide\s+by\s+zero\" #{@outFileForKnife}"
        errorMessagesForCmd = `#{cmd}`
        errorMessagesForCmd2 = `#{cmd2}`
        if(!errorMessagesForCmd.strip().empty?() and !errorMessagesForCmd2.strip().empty?())
          errorMessages = "None of your sample reads aligned to circular RNA, so further processing could not be performed."
        end
        # Proceed with check #2 if we passed check #1
        unless(errorMessages)
          # Check #2: Are file quality scores in phred64?
          cmd = "grep -iP \"but\s+expected\s+64-based\s+Phred\s+qual.\" #{@outFileForKnife}"
          errorMessagesForCmd = `#{cmd}`
          unless(errorMessagesForCmd.strip().empty?())
            errorMessages = "We could not process your sample because its quality scores were not encoded in phred64."
          end
        end
        # If we pass both checks above, then we'll check for any error messages at all
        unless(errorMessages)
          # Check for ERROR lines and ignore certain lines that are always there (even if job succeeds)
          cmd = "grep -i \"ERROR\" #{@outFileForKnife} | grep -v \"Backtrace\" | grep -vP \"classification\s+errors\" | grep -vP \"Estimate\s+Std.\s+Error\""
          errorMessages = `#{cmd}`
          # If we don't find any error lines, then we assume that the job was successful
          if(errorMessages.strip().empty?())
            retVal = false
          end
        end
      end
      # Did we find anything? Or, KNIFE failed (bad exit status) and we'll still report an error occurred, even if we didn't find anything
      if(retVal)
        # Here, we mark the current run as failed and set its error message correspondingly
        @failedRun = true
        @errUserMsg = "KNIFE run failed.\nReason(s) for failure:\n\n"
        errorMessages = nil if(errorMessages.empty?)
        @errUserMsg << (errorMessages || "[No error info available from KNIFE tool]")
      end
      return retVal
    end

    # Compress output files to be transferred to user db
    # @param [String] inputDir path to sub job dir that contains inputs for current KNIFE run
    # @param [String] outputDir path to results dir that contains outputs for current KNIFE run
    # @param [String] outFile path to .out file used for current run of the runKnife wrapper
    # @param [String] errFile path to .err file used for current run of the runKnife wrapper
    # @return [nil]
    def compressOutputs(inputDir, outputDir, outFile, errFile)
      begin
        # First, we will compress ALL of the results (including full alignments) in results archive
        resultsZip = "#{File.basename(inputDir)}_results_v#{@toolVersion}.zip"
        @fullPathResultsZip = "#{@scratchDir}/#{resultsZip}"
        # Then, we will compress all of the results (minus full alignments) in the CORE_RESULTS archive
        coreResultsZip = "#{File.basename(inputDir)}_CORE_RESULTS_v#{@toolVersion}.zip"
        @fullPathCoreResultsZip = "#{@scratchDir}/#{coreResultsZip}"
        # Compress full results zip
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Compressing all outputs to create #{resultsZip}")
        command = "cd #{@scratchDir}; zip -r #{resultsZip} out.log outputs/#{File.basename(inputDir)}/* > #{outFile} 2> #{errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching zip command to compress full results archive: #{command}")
        exitStatus = system(command)
        # Raise error if exit status lets us know that an error occurred
        unless(exitStatus)
          @errUserMsg = "We could not create the zip archive of full results for this run."
          raise "Command: #{command} died. Check #{errFile} for more information."
        end
        # If we successfully created results archive, then we're good to go. Otherwise, we raise an error
        if(File.exist?(@fullPathResultsZip))
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE Compressing outputs to create full results archive #{resultsZip}")
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Full results archive #{resultsZip} is not found.")
          @errUserMsg = "We could not find your full results archive #{resultsZip} for this run."
          raise @errUserMsg
        end
        # Next, we will delete the "orig" directory which contains all of the full alignment files 
        `rm -rf #{outputDir}/#{File.basename(inputDir)}/orig`
        # Now, we can compress the CORE RESULTS zip (everything from before EXCEPT for the "orig" directory)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Compressing core outputs to create #{coreResultsZip}")
        command = "cd #{@scratchDir}; zip -r #{coreResultsZip} out.log outputs/#{File.basename(inputDir)}/* > #{outFile} 2> #{errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching zip command to compress core results archive: #{command}")
        exitStatus = system(command)
        # Raise error if exit status lets us know that an error occurred
        unless(exitStatus)
          @errUserMsg = "We could not create the zip archive of core results for this run."
          raise "Command: #{command} died. Check #{errFile} for more information."
        end
        # If we successfully created the core results archive, then we're good to go. Otherwise, we raise an error
        if(File.exist?(@fullPathCoreResultsZip))
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE Compressing outputs to create core results archive #{coreResultsZip}")
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Core results archive #{coreResultsZip} is not found.")
          @errUserMsg = "We could not find your core results archive #{coreResultsZip} for this run."
          raise @errUserMsg
        end
        # We can go ahead and delete the raw inputs dir and raw outputs dir since we're done with both of them (we processed inputs and we compressed outputs)
        `rm -rf #{inputDir}`
        `rm -rf #{outputDir}`
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There was an error compressing your results from KNIFE." if(@errUserMsg.nil?)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 28
      end
      return
    end

    # Transfer output files to user database
    # @param [String] inputDir path to sub job dir that contains inputs for current KNIFE run
    # @param [String] outputDir path to results dir that contains outputs for current KNIFE run
    # @param [String] resultsZip full path to results zip for current KNIFE run
    # @param [String] outFile full path to out.log file used for KNIFE logging output  
    # @return [Fixnum] exitCode to indicate whether method succeeded or failed
    def transferOutputs(inputDir, outputDir, resultsZip, coreResultsZip, outFile)
      begin
        # Find target URI for user's database
        targetUri = URI.parse(@outputs[0])
        # Set resource path
        rsrcPath = ""
        unless(@remoteStorageArea)
          rsrcPath = "#{targetUri.path}/file/KNIFE_v#{@toolVersion}/{analysisName}/{subJobDir}/{outputFile}/data?"
        else
          rsrcPath = "#{targetUri.path}/file/#{CGI.escape(@remoteStorageArea)}/KNIFE_v#{@toolVersion}/{analysisName}/{subJobDir}/{outputFile}/data?"
        end
        # We also need to add our gbKey for access (if it exists)
        rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
        # Upload results .zip
        uploadFile(targetUri.host, rsrcPath, @userId, resultsZip, {:analysisName => @analysisName, :subJobDir => File.basename(inputDir), :outputFile => File.basename(resultsZip)})
        # Upload CORE RESULTS .zip
        uploadFile(targetUri.host, rsrcPath, @userId, coreResultsZip, {:analysisName => @analysisName, :subJobDir => File.basename(inputDir), :outputFile => File.basename(coreResultsZip)})
        # Upload out.log
        uploadFile(targetUri.host, rsrcPath, @userId, outFile, {:analysisName => @analysisName, :subJobDir => File.basename(inputDir), :outputFile => File.basename(outFile)})
      rescue => err
        # Generic error message if an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: There was an error uploading the results from your KNIFE run." if(@errUserMsg.nil?)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 27
      end
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
   
###################################################################################
    def prepSuccessEmail()
      @settings = @jobConf['settings']
       
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
      additionalInfo << "Your result files are currently being uploaded to your database.\nPlease wait for some time before attempting to download your result files.\n\n" +
                        "Result files for this sample can be found at the following location in the Genboree Workbench:\n" + 
                          "|-Group: '#{@groupName}'\n" +
                            "|--Database: '#{@dbName}'\n" +
                              "|---Files\n" 
      if(@remoteStorageArea)
        additionalInfo << "|----#{@remoteStorageArea}\n" + 
                            "|-----KNIFE_v#{@toolVersion}\n" +
                              "|------#{@analysisName}\n"+
                                "|-------#{@baseNameForInputDir}\n\n"
      else 
        additionalInfo << "|----exceRptPipeline_v#{@toolVersion}\n" +
                            "|-----#{@analysisName}\n" +
                              "|------#{@baseNameForInputDir}\n\n"
      end 
      additionalInfo << "NOTE 1:\nThe file that ends in '_results_v#{@toolVersion}' is an archive\nthat contains all the result files from KNIFE.\n" +
                        "NOTE 2:\nThe file that ends in '_CORE_RESULTS_v#{@toolVersion}' is an archive\nthat contains all core result files from KNIFE\n(everything but full alignment files).\n" +
                        "NOTE 3:\nThe file named 'out.log' contains all of the logging information from the KNIFE tool run.\n" +
                        "\n==================================================================\n"
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
      inputsText                      = customBuildSectionEmailSummary(@inputs)
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

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::RunKnifeWrapper)
end
