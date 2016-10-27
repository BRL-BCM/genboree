#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'fileutils'
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
require 'brl/genboree/kb/kbDoc'
include BRL::Genboree::REST


module BRL; module Genboree; module Tools; module Scripts
  class DESeq2Wrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = {}
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the 'DESeq2' tool.
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
        # Set up dbrc-related variables - also done below in run() method, since we need user / pass again and we don't want to save authentication info in instance variables
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        dbrcKey = @context['apiDbrcKey']
        user = pass = dbrc = nil
        if(dbrcKey)
          dbrc = BRL::DB::DBRC.new(dbrcFile, dbrcKey)
          # get super user, pass and hostname
          user = dbrc.user
          pass = dbrc.password
          host = dbrc.driver.split(/:/).last
        else
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, dbrcFile)
          user = suDbDbrc.user
          pass = suDbDbrc.password
          host = suDbDbrc.driver.split(/:/).last
        end
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
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
        @processingPipeline = "DESeq2"
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
        # Set up format options coming from the UI - "Settings" variables
        @analysisName = @settings['analysisName']
        @firstFactorLevel = @settings['factorLevel1']
        @secondFactorLevel = @settings['factorLevel2']
        @factorName = @settings['factorName1']
        @remoteStorageArea = @settings['remoteStorageArea']
        # Set up other options
        @localJob = @settings['localJob']
        @runPostProcessingTool = @settings['runPostProcessingTool']
        # If we're going to be running PPR, then we'll need to create directories for those files (base dir, input dir, and output dir)
        if(@runPostProcessingTool) 
          @postProcDir = "#{@scratchDir}/postProcDir" 
          @inputDirForPostProc = "#{@postProcDir}/runs"
          @outputDirForPostProc = "#{@postProcDir}/outputFiles"
          `mkdir -p #{@inputDirForPostProc}`
          `mkdir -p #{@outputDirForPostProc}`
        end
        # Make directory where we'll place output files for DESeq2
        @outputDir = "#{@scratchDir}/outputDir"
        `mkdir -p #{@outputDir}`
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
        @settings.delete("factorLevelsForSampleDescriptors")
        @settings.delete("readCountsFileName")
        @settings.delete("sampleDescriptors")
        @settings.delete("sampleDescriptorsFileName")
        @settings.delete("piID")
        @settings.delete("remoteStorageArea") if(@settings["remoteStorageArea"] == nil)
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
        # Set up dbrc-related variables
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        dbrcKey = @context['apiDbrcKey']
        user = pass = dbrc = nil
        if(dbrcKey)
          dbrc = BRL::DB::DBRC.new(dbrcFile, dbrcKey)
          # get super user, pass and hostname
          user = dbrc.user
          pass = dbrc.password
        else
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, dbrcFile)
          user = suDbDbrc.user
          pass = suDbDbrc.password
        end
        targetUri = URI.parse(@outputs[0])
        @outputHost = targetUri.host
        # Set up variables for .out / .err files used for DESeq2 tool run
        @outFile = "#{@scratchDir}/DESeq2.out"
        @errFile = "#{@scratchDir}/DESeq2.err"
        # @inputFiles will store all input files 
        @inputFiles = []
        # @readCountsFile will track the name of the file containing miRNA read counts / sample names
        @readCountsFile = ""
        # @factorsFile will track the name of the file containing sample names / factor names
        @factorsFile = ""
        # @sniffer will be used to check whether input files are ASCII
        @sniffer = BRL::Genboree::Helpers::Sniffer.new()
        # Download the inputs from the server (if not a job run locally)
        unless(@localJob)
          downloadFiles()
        end
        raise @errUserMsg unless(@exitCode == 0)
        # Now, we need to run the post-processing tool (PPR) on the CORE_RESULTS archives if they were submitted
        if(@runPostProcessingTool)
          errorOccurred = postProcessing()
          raise @errUserMsg if(errorOccurred)
          # Rename file because DESeq2 script seems to be auto-escaping file name
          newNameForReadCountsFile = "#{@outputDirForPostProc}/DESeq2_exceRpt_miRNA_ReadCounts.txt"
          `mv #{@outputDirForPostProc}/#{CGI.escape(@analysisName)}_exceRpt_miRNA_ReadCounts.txt #{newNameForReadCountsFile}`
          @inputFiles << newNameForReadCountsFile
          # Convert file to UNIX format
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Converting #{newNameForReadCountsFile} to Unix")
          convObj = BRL::Util::ConvertText.new(newNameForReadCountsFile, true)
          convObj.convertText()
        end
        # Check that inputs are in correct format and set up @readCountsFile / @factorsFile variables
        preprocessInputs(@inputFiles)
        raise @errUserMsg unless(@exitCode == 0)
        @failedRun = false
        runDESeq2(@readCountsFile, @factorsFile, @outputDir, @factorName, @firstFactorLevel, @secondFactorLevel, @outFile, @errFile)
        # If the tool finished successfully, we'll upload the tool's output files
        unless(@failedRun)
          allOutputFiles = Dir.entries(@outputDir)
          # Add @analysisName as a prefix to all output files
          prefix = CGI.escape(@analysisName)
          allOutputFiles.each { |outputFile|
            next if(outputFile == "." or outputFile == "..")
            newName = "#{prefix}_#{outputFile}"
            FileUtils.mv("#{@outputDir}/#{outputFile}", "#{@outputDir}/#{newName}")
          }
          # Upload all relevant files
          transferFiles(@analysisName, @toolVersion, @outputDir)
        else
          @errUserMsg = "Your DESeq2 run failed." if(@errUserMsg.nil? or @errUserMsg.empty?)
          @exitCode = 26
          raise @errUserMsg
        end
      # If an error occurs at any point in the above, we'll return an @exitCode of 30 (if exit code hasn't already been set) and give an informative message for the user.
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of DESeq2 tool failed (#{err.message.inspect})." if(@errUserMsg.nil?)
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
          # Download current input file
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input file #{input}")
          fileBase = @fileApiHelper.extractName(input)
          fileBaseName = File.basename(fileBase)
          tmpFile = fileBaseName.makeSafeStr(:ultra)
          retVal = @fileApiHelper.downloadFile(input, @userId, tmpFile)
          # If we are unable to download our file successfully, we will set an error message for the user.
          unless(retVal)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Failed to download file: #{fileBase} from server.")
            @errUserMsg = "Failed to download file: #{fileBase} from server"
            raise @errUserMsg
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "File downloaded successfully to #{tmpFile}")
          end
          # @errInputArray will hold file names of files that aren't proper inputs (wrong format, for example) associated with current input
          @errInputArray = []
          # If the file is a CORE_RESULTS archive, then we'll move it to a special directory for processing. Otherwise, we'll do our normal checks on that file.
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "File's base name is: #{File.basename(tmpFile)}.")
          if(File.basename(tmpFile) =~ /_CORE_RESULTS_v(\d\.\d\.\d)(?:.tgz)/)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "File DOES match the CORE_RESULTS regular expression. Moving #{tmpFile} to #{@inputDirForPostProc}/#{File.basename(tmpFile)}")
            `mv #{tmpFile} #{@inputDirForPostProc}/#{File.basename(tmpFile)}`
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "File does NOT match the CORE_RESULTS regular expression.")
            checkForInputs(tmpFile)
          end
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
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error (backtrace below): #{err.message.inspect}")
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
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Converting #{fixedInputFile} to Unix")
          convObj = BRL::Util::ConvertText.new(fixedInputFile, true)
          convObj.convertText()
          # Finally, push file onto @inputFiles array
          @inputFiles.push(fixedInputFile)
        end
      end
    end

    # Method which will make sure that both input files (miRNA reads and factor levels) are in correct format.
    # We also figure out which file contains the miRNA reads and which file contains the factor levels (programmatically, as opposed to asking the user or something).
    # This is currently ALSO done in the RulesHelper, but we might remove that (or at least put a cap on the size of files that it checks) since we don't want to block the web server.
    # @param [Array] inputFiles array containing both input files 
    # @return [Fixnum] exit code telling us whether pre-processing succeeded (0) or failed (24)
    def preprocessInputs(inputFiles)
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Pre-processing #{inputFiles.inspect}")
        # Grab file paths for both files
        firstFile = inputFiles[0]
        secondFile = inputFiles[1]
        # Read first file into firstFile variable and split by newline
        firstFile = File.read(firstFile).split("\n")
        # Let's remove all blank lines
        firstFile =  firstFile.select { |currentToken| currentToken =~ /^[^\r\n]/ }
        # Split up file into individual tab-delimited elements on lines
        firstFile.map! { |currentToken| currentToken.split("\t") }
        # Read second file into secondFile variable and split by newline
        secondFile = File.read(secondFile).split("\n")
        # Remove blank lines
        secondFile = secondFile.select { |currentToken| currentToken =~ /^[^\r\n]/ }
        # Split up file into individual tab-delimited elements on lines
        secondFile.map! { |currentToken| currentToken.split("\t") }
        # Grab column headers for each file
        firstFileColumnHeaders = firstFile[0]
        secondFileColumnHeaders = secondFile[0]
        # Grab row headers for each file
        firstFileRowHeaders = []
        secondFileRowHeaders = []
        firstFile.each { |currentLine|
          firstFileRowHeaders << currentLine[0]
        }
        secondFile.each { |currentLine|
          secondFileRowHeaders << currentLine[0]
        }
        # Let's delete the first element from each of these since it's blank or a header comment and doesn't correspond to an actual row / column name
        firstFileRowHeaders.shift()
        secondFileRowHeaders.shift()
        firstFileColumnHeaders.shift()
        secondFileColumnHeaders.shift()
        # Our main check is that the column headers for the read counts file must be the same as the row headers for the factor levels file.
        if(firstFileColumnHeaders.sort == secondFileRowHeaders.sort)
          @readCountsFile = inputFiles[0]
          @factorsFile = inputFiles[1]
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "First file (#{@readCountsFile}) column headers match second file (#{@factorsFile}) row headers, so files are compatible.")
        elsif(secondFileColumnHeaders.sort == firstFileRowHeaders.sort)    
          @readCountsFile = inputFiles[1]
          @factorsFile = inputFiles[0]
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "First file (#{@factorsFile}) row headers match second file (#{@readCountsFile}) column headers, so files are compatible.")
        else
          @errUserMsg = "Your two input files are not in the correct format. The column headers in your file containing read counts\nmust match the row headers in your file containing sample descriptors.\nAlso, your documents should not contain any header lines (lines that begin with #).\nThe one exception to this rule is the first line of your file\n(which contains the column names).\nPlease contact a Genboree admin (sailakss@bcm.edu) for further help."
          raise @errUserMsg
        end
        # Let's also check to make sure that the factor name / factor levels given by the user actually exist in the factors file
        # First, we'll figure out which file contents / column headers are associated with the factor file
        factorsFileContents = ""
        factorsColumnHeaders = ""
        if(@factorsFile == inputFiles[1])
          factorsFileContents = secondFile
          factorsColumnHeaders = secondFileColumnHeaders
        else 
          factorsFileContents = firstFile
          factorsColumnHeaders = firstFileColumnHeaders
        end
        # Now, we'll check to make sure that the @factorName is present in the column headers for the factor file
        unless(factorsColumnHeaders.include?(@factorName))
          @errUserMsg = "Your factor name, #{@factorName}, is not valid.\nPlease make sure that your factor name is present in your factors file (#{File.basename(@factorsFile)})."
          raise @errUserMsg
        else 
          # OK, so the factor name is there. Next, let's figure out if the two factor levels given are present for that factor name
          # Grab index of the factor name, then run through file contents for factor file and see whether factor levels are present for that index (column)
          indexOfFactorName = factorsColumnHeaders.index(@factorName) + 1
          firstFactorPresent = false
          secondFactorPresent = false
          factorsFileContents.each { |currentLine|
            if(currentLine[indexOfFactorName] == @firstFactorLevel)
              firstFactorPresent = true
            elsif(currentLine[indexOfFactorName] == @secondFactorLevel)
              secondFactorPresent = true 
            end
          }
          # Set error message according to which factor levels are present - if both are present, then everything is OK
          if(!firstFactorPresent and secondFactorPresent)
            @errUserMsg = "One of your factor levels, #{@firstFactorLevel}, is missing for your factor name #{@factorName}.\n"
          elsif(firstFactorPresent and !secondFactorPresent)
            @errUserMsg = "One of your factor levels, #{@secondFactorLevel}, is missing for your factor name #{@factorName}.\n"
          elsif(!firstFactorPresent and !secondFactorPresent)
            @errUserMsg = "Both of your factor levels, #{@firstFactorLevel} and #{@secondFactorLevel}, are missing for your factor name #{@factorName}.\n"
          end
          if(@errUserMsg)
            @errUserMsg << "Please make sure that all factor levels are present under the factor name given."
            raise @errUserMsg
          end
        end
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (hopefully won't happen)
        @errUserMsg = "ERROR: Your two input files are not in the correct format.\nThe column headers in your file containing read counts must match\nthe row headers in your file containing sample descriptors.\nAlso, your documents should not contain any header lines (lines that begin with #).\nThe one exception to this rule is the first line of your file\n(which contains the column names).\nPlease contact a Genboree admin (sailakss@bcm.edu) for further help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", @errBacktrace)
        @exitCode = 24
      end 
      return @exitCode  
    end 
       
    # Run DESeq2
    # @param [String] readCountsFile file path to miRNA read counts / sample names file 
    # @param [String] factorsFile file path to sample names / factor levels file
    # @param [String] outputDir file path to output directory
    # @param [String] factorName name of factor (biofluid, disease, etc.) under which both factor levels fall
    # @param [String] firstFactorLevel name of first factor level (case-sensitive!)
    # @param [String] secondFactorLevel name of second factor level (case-sensitive!)
    # @param [String] outFile file path to .out file associated with tool run
    # @param [String] errFile file path to .err file associated with tool run
    # @return [nil]
    def runDESeq2(readCountsFile, factorsFile, outputDir, factorName, firstFactorLevel, secondFactorLevel, outFile, errFile)
      # Do some necessary R-related updates to text provided by user so that DESeq2 script works properly
      factorName.gsub!(" ", ".")
      # Create command for actually launching the shell script that will run the tool
      command = "module unload R ; module load R/3.1 ; computeFoldChange.rb -i #{readCountsFile} -s #{factorsFile} -o #{outputDir} -f \"#{factorName}\" -d \"#{firstFactorLevel}\" -t \"#{secondFactorLevel}\" >> #{outFile} 2>> #{errFile}"
      # Launch command
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Exit status: #{exitStatus}")
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "DESeq2 tool command completed with exit code: #{statusObj.exitstatus}")
      findError(exitStatus)
      return
    end

    # Transfer output files to user database
    # @param [String] analysisName analysis name used in file path
    # @param [String] toolVersion current version of DESeq2 tool in Workbench (NOT version of R package)
    # @param [String] outputDir path to current output directory
    # @return [FixNum] exitCode to indicate whether method succeeded or failed
    def transferFiles(analysisName, toolVersion, outputDir)
      # Find target URI for user's database
      targetUri = URI.parse(@outputs[0])
      # Set resource path
      if(@remoteStorageArea)
        rsrcPath = "#{targetUri.path}/file/#{CGI.escape(@remoteStorageArea)}/DESeq2_v#{toolVersion}/{analysisName}/{outputFile}/data?"
      else 
        rsrcPath = "#{targetUri.path}/file/DESeq2_v#{toolVersion}/{analysisName}/{outputFile}/data?"
      end
      # We also need to add our gbKey for access (if it exists)
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      # Upload all output files
      allOutputFiles = Dir.entries(outputDir)
      allOutputFiles.each { |outputFile|
        next if(outputFile == "." or outputFile == "..")
        uploadFile(targetUri.host, rsrcPath, @userId, "#{outputDir}/#{outputFile}", { :analysisName => analysisName, :outputFile => outputFile })
      }
      @successfulRun = true
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

    # Method to detect errors
    # @param [boolean] exitStatus indicating if the system() call "succeeded" or not.
    # @return [boolean] indicating if a DESeq2 error was found or not.
    def findError(exitStatus)
      retVal = true
      errorMessages = []
      # Check the obvious things first. Outright failure or putting error messages on stderr:
      if(exitStatus)
        # So far, so good. Look for ERROR lines in STDOUT / STDERR.
        cmd = "grep -i \"ERROR\" #{@outFile} #{@errFile} | grep -v \"Backtrace\""
        errorMessage = `#{cmd}`.strip
        if(errorMessage.empty?)
          retVal = false
        else
          errorMessages << errorMessage
        end
      else
        # OK, our tool failed. We will now check to see if any common errors came up.
        # CHECK #1: Error related to incorrect factor levels (user had a typo in one of his/her factor levels)
        cmd = "grep -i \"contrasts can be applied only to factors with 2 or more levels\" #{@errFile}"
        errorMessagesForCmd = `#{cmd}`
        cmd2 = "grep -i \"'ref' must be an existing level\" #{@errFile}"
        errorMessagesForCmd2 = `#{cmd2}`
        unless(errorMessagesForCmd.strip().empty?() and errorMessagesForCmd2.strip().empty?())
          errorMessages << "Likely reason: One or both of your two factor levels, #{@firstFactorLevel} and #{@secondFactorLevel},\ncould not be found under your factor name #{@factorName}.\nAre you sure that the #{@factorName} column contains both of these factor levels?"
        end
        # Proceed with CHECK #2: Error related to incorrect factor levels - user had a typo in BOTH of his/her factor levels
        cmd = "grep -i \"all samples have 0 counts for all genes\" #{@errFile}"
        errorMessagesForCmd = `#{cmd}`
        unless(errorMessagesForCmd.strip().empty?())
        errorMessages << "Likely reason: Your factor name, #{@factorName}, is not valid.\nPlease make sure that your factor name is present in your factors file (#{File.basename(@factorsFile)})."
        end
        # Proceed with CHECK #3: Error that occurs if user included a sample that has no read counts for any listed miRNAs (0 value for every row in at least one of the columns)
        cmd = "grep -i \"every gene contains at least one zero, cannot compute log geometric means\" #{@errFile}"
        errorMessagesForCmd = `#{cmd}`
        unless(errorMessagesForCmd.strip().empty?())
          errorMessages << "Likely reason: At least one of your samples has a 0 count for each listed miRNA in your read counts file.\nPlease remove the columns corresponding to samples that don't have any detected miRNAs and then resubmit your files."
        end
        # Proceed with CHECK #4: Error that occurs if user has duplicate row names in read counts file (maybe both files). For example, one user's submission failed because she had multiple blank row names.
        cmd = "grep -i \"duplicate 'row.names' are not allowed\" #{@errFile}"
        errorMessagesForCmd = `#{cmd}`
        unless(errorMessagesForCmd.strip().empty?())
          errorMessages << "Likely reason: Your read counts file or factors file (or both) has duplicate row names.\nFor example, does your read counts doc have multiple blank entries for miRNA identifiers?\nPlease edit or remove any duplicates and resubmit your files."
        end
        # OK, so none of our checks found anything, but there's still an error. 
        # Let's just look for ERROR lines in STDOUT / STDERR and at least report those!
        if(errorMessages.empty?)
          cmd = "grep -i \"ERROR\" #{@outFile} #{@errFile} | grep -v \"Backtrace\""
          errorMessage = `#{cmd}`.strip
          errorMessages << errorMessage unless(errorMessage.empty?)
        end
      end
      # Did we find anything? Or, DESeq2 failed (bad exit status) and we'll still report an error occurred, even if we didn't find anything
      if(retVal)
        # Here, we mark the current run as failed and set its error message correspondingly
        @failedRun = true
        @errUserMsg = "DESeq2 run failed.\nReason(s) for failure:\n\n"
        errorMessages = nil if(errorMessages.empty?)
        @errUserMsg << (errorMessages.join("\n\n") || "[No error info available from DESeq2 tool]\n")
        @errUserMsg << "\nThis tool is currently in beta status and may not work with every combination of samples.\nIf you receive an error email after launching your job,\nplease use the Contact Us button at the top of the Atlas\nto report your error." if(@settings['atlasVersion'] == "v4")
      end
      return retVal
    end

   ########## METHODS RELATED TO PPR ##########

    # Run processPipelineRuns tool on CORE_RESULTS archive files
    # @return [nil]
    def postProcessing()
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
      @pprJobConf['settings']['suppressEmail'] = true
      @pprJobConf['settings']['DESeq2Job'] = true
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
      outFileFromPPR = "#{@scratchDir}/processPipelineRunsFromDESeq2.out"
      errFileFromPPR = "#{@scratchDir}/processPipelineRunsFromDESeq2.err"
      command = "cd #{@postProcDir}; processPipelineRunsWrapper.rb -C -j #{@pprJobFile} >> #{outFileFromPPR} 2>> #{errFileFromPPR}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "processPipelineRuns wrapper command completed with exit code: #{statusObj.exitstatus}")
      errorOccurred = findErrorForPPR(exitStatus, outFileFromPPR, errFileFromPPR)
      return errorOccurred 
    end

    # Method to detect errors from PPR log files
    # @param [boolean] exitStatus indicating if the system() call "succeeded" or not.
    # @param [String] outFileFromPPR Path to .out file generated by PPR
    # @param [String] errFileFromPPR Path to .err file generated by PPR 
    # @return [boolean] indicating if a processPipelineRuns error was found or not.
    #   if so, @errUserMsg, @errInternalMsg, @exitCode will be set appropriately
    def findErrorForPPR(exitStatus, outFileFromPPR, errFileFromPPR)
      retVal = true
      errorMessages = nil
      # Check the obvious things first. Outright failure or putting error messages on stderr:
      if(exitStatus)
        # So far, so good. Look for ERROR lines in STDOUT / STDERR.
        cmd = "grep -i \"ERROR\" #{outFileFromPPR} #{errFileFromPPR} | grep -v \"Backtrace\""
        errorMessages = `#{cmd}`
        if(errorMessages.strip.empty?)
          retVal = false
        end
      else
        # OK, our PPR tool failed. We will now check to see if any common errors came up.
        # CHECK #1: Error related to samples with same name 
        cmd = "grep -i \"Error in data.frame(value, row.names = rn, check.names = FALSE, check.rows = FALSE)\" #{@errFile}"
        errorMessagesForCmd = `#{cmd}`
        unless(errorMessagesForCmd.strip().empty?())
          errorMessages = "It looks like one or more of your samples have the same names.\nPlease check your inputs and ensure samples do not have the same name.\n"
        end
        # CHECK #2: Error related to inputs not being valid 
        unless(errorMessages)
          cmd = "grep -i \"NumberOfCompatibleSamples > 0 is not TRUE\" #{@errFile}"
          errorMessagesForCmd = `#{cmd}`
          unless(errorMessagesForCmd.strip().empty?())
            errorMessages = "It looks like none of your submitted CORE_RESULTS archives were valid inputs\nfor the post-processing tool (used to generate your miRNA read counts file).\nPlease try re-running exceRpt on those samples, or contact a Genboree admin (sailakss@bcm.edu) for assistance.\n"
          end
        end
        # Print error message in error log for debugging purposes
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error messages: #{errorMessages}")
      end
      # Did we find anything?
      if(retVal)
        @errUserMsg = "exceRpt small RNA-seq Post-processing tool failed. Message from exceRpt small RNA-seq Post-processing tool:\n\n"
        @errUserMsg << (errorMessages || "[No error info available from exceRpt small RNA-seq Post-processing tool]\n")
        @errUserMsg << "\nThis tool is currently in beta status and may not work with every combination of samples.\nIf you receive an error email after launching your job,\nplease use the Contact Us button at the top of the Atlas\nto report your error." if(@settings['atlasVersion'] == "v4")
        @errInternalMsg = @errUserMsg
        @exitCode = 29
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
      toolUsage.setPropVal("ERCC Tool Usage.Samples Processed Through ERCC Pipeline", 1)
      runItem = BRL::Genboree::KB::KbDoc.new({})
      runItem.setPropVal("Sample Name", "#{CGI.escape(@analysisName)}_#{File.basename(@readCountsFile)}")
      sampleStatus = ""
      successfulSamples = 0
      failedSamples = 0
      if(@successfulRun)
        sampleStatus = "Completed"
        successfulSamples += 1
      else 
        sampleStatus = "Failed"
        failedSamples += 1
      end
      runItem.setPropVal("Sample Name.Sample Status", sampleStatus)
      toolUsage.addPropItem("ERCC Tool Usage.Samples Processed Through ERCC Pipeline", runItem)
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
      @settings = @jobConf['settings']
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
      additionalInfo << "Your result files can be found on the Genboree Workbench.\n"
      additionalInfo << "The Genboree Workbench is a repository of bioinformatics tools\n"
      additionalInfo << "that will store your result files for you.\n"
      additionalInfo << "You can find the Genboree Workbench here:\nhttp://#{@outputHost}/java-bin/workbench.jsp\n"
      additionalInfo << "Once you're on the Workbench, follow the ASCII drawing below\nto find your result files.\n" +
                          "|-Group: '#{@groupName}'\n" +
                            "|--Database: '#{@dbName}'\n" +
                              "|---Files\n" 
      if(@remoteStorageArea)
        additionalInfo << "|----#{@remoteStorageArea}\n" + 
                            "|-----DESeq2_v#{@toolVersion}\n" +
                              "|------#{@analysisName}\n\n"
      else 
        additionalInfo << "|----DESeq2_v#{@toolVersion}\n" +
                            "|-----#{@analysisName}\n\n" 
      end 
      additionalInfo << "NOTE 1:\nThe file that ends in '_foldChange.txt' contains the results from your DESeq2 analysis.\n" +
                        "NOTE 2:\nThe file that ends in 'diffExp.R' is the R script that was used to generate your results.\n" +
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
      @settings = @jobConf['settings']
      emailErrorObject                = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailErrorObject.userFirst      = @userFirstName
      emailErrorObject.userLast       = @userLastName
      emailErrorObject.analysisName   = @analysisName
      inputsText                      = buildSectionEmailSummary(@inputs)
      emailErrorObject.inputsText     = inputsText
      outputsText                     = buildSectionEmailSummary(@outputs)
      emailErrorObject.outputsText    = outputsText
      emailErrorObject.settings       = @settings
      emailErrorObject.errMessage     = @errUserMsg
      emailErrorObject.exitStatusCode = @exitCode
      emailErrorObject.erccTool        = true
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
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::DESeq2Wrapper)
end
