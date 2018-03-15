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
  class ErccPCAWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = {}
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the 'erccPCA' tool.
                        This tool is intended to be called via the exRNA Atlas",
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
        @processingPipeline = "Dimensionality Reduction Plot"
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
        @remoteStorageArea = @settings['remoteStorageArea']
        # Set up other options
        @localJob = @settings['localJob']
        @postProcDir = "#{@scratchDir}/postProcDir"
        `mkdir -p #{@postProcDir}`
        # Make directories where we'll create dependencies for PCA tool
        @makeDependenciesDir = "#{@scratchDir}/makeDependencies"
        `mkdir -p #{@makeDependenciesDir}`
        `mkdir -p #{@makeDependenciesDir}/miRNA`
        `mkdir -p #{@makeDependenciesDir}/piRNA`
        `mkdir -p #{@makeDependenciesDir}/QC_Results`
        `mkdir -p #{@makeDependenciesDir}/smallRNAQuants`
        `mkdir -p #{@makeDependenciesDir}/tRNA`
        `mkdir -p #{@makeDependenciesDir}/Dependencies`
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
        # @inputFiles will store all input files 
        @inputFiles = []
        # @sniffer will be used to check whether input files are ASCII
        @sniffer = BRL::Genboree::Helpers::Sniffer.new()
        # Download the inputs from the server (if not a job run locally)
        unless(@localJob)
          downloadFiles()
        end
        raise @errUserMsg unless(@exitCode == 0)
        # Grab paths for all CORE_RESULTS archives
        coreResultsArchives = Dir["#{@postProcDir}/*.tgz"]
        analyses = []
        # Traverse each CORE_RESULTS archive path
        coreResultsArchives.each { |currentCoreResults|
          currentCoreResultsBase = File.basename(currentCoreResults)
          # Grab analysis name from name of CORE_RESULTS archive
          indexOne = currentCoreResultsBase.index("_fastq")
          if(indexOne)
            sampleName = currentCoreResultsBase[0..indexOne+5]
            analysisName = currentCoreResultsBase[indexOne+7..-1]
            analysisName.slice!("_CORE_RESULTS_v4.6.2.tgz")
          else
            indexOne = currentCoreResultsBase.index("_fq")
            sampleName = currentCoreResultsBase[0..indexOne+2]
            analysisName = currentCoreResultsBase[indexOne+4..-1]
            analysisName.slice!("_CORE_RESULTS_v4.6.2.tgz")
          end
          unless(File.directory?("#{@postProcDir}/#{analysisName}"))
            `mkdir #{@postProcDir}/#{analysisName}`
            `mkdir #{@postProcDir}/#{analysisName}/runs`
            `mkdir #{@postProcDir}/#{analysisName}/output`            
          end
          `mv #{currentCoreResults} #{@postProcDir}/#{analysisName}/runs`
          analyses << analysisName unless(analyses.include?(analysisName))
        }
        analyses.each { |currentAnalysisName|
          errorOccurred = postProcessing(currentAnalysisName)
          raise @errUserMsg if(errorOccurred)
        }
        # Now we need to move the relevant files generated by PPR to their own directory for the PCA tool to process
        analyses.each { |currentAnalysisName|
          `mv #{@postProcDir}/#{currentAnalysisName}/outputFiles/#{currentAnalysisName}_exceRpt_miRNA_ReadsPerMillion.txt #{@makeDependenciesDir}/miRNA/`
          `mv #{@postProcDir}/#{currentAnalysisName}/outputFiles/#{currentAnalysisName}_exceRpt_piRNA_ReadsPerMillion.txt #{@makeDependenciesDir}/piRNA/`
          `mv #{@postProcDir}/#{currentAnalysisName}/outputFiles/#{currentAnalysisName}_exceRpt_QCresults.txt #{@makeDependenciesDir}/QC_Results/`
          `mv #{@postProcDir}/#{currentAnalysisName}/outputFiles/#{currentAnalysisName}_exceRpt_smallRNAQuants_ReadsPerMillion.RData #{@makeDependenciesDir}/smallRNAQuants/`
          `mv #{@postProcDir}/#{currentAnalysisName}/outputFiles/#{currentAnalysisName}_exceRpt_tRNA_ReadsPerMillion.txt #{@makeDependenciesDir}/tRNA/`        
        }
        @failedRun = false
        generateDependenciesForPCA(@makeDependenciesDir)
        # If the tool finished successfully, we'll upload the tool's output files
        unless(@failedRun)
          # Upload all relevant files
          transferFiles(@analysisName, @toolVersion, "#{@makeDependenciesDir}/Dependencies")
        else
          @errUserMsg = "Your PCA run failed." if(@errUserMsg.nil? or @errUserMsg.empty?)
          @exitCode = 26
          raise @errUserMsg
        end
      # If an error occurs at any point in the above, we'll return an @exitCode of 30 (if exit code hasn't already been set) and give an informative message for the user.
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of PCA tool failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @exitCode = 30 if(@exitCode == 0)
      ensure
        #submitToolUsageDoc(user, pass) unless(@jobId[0..4] == "AUTO-")
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
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "File DOES match the CORE_RESULTS regular expression. Moving #{tmpFile} to #{@postProcDir}/#{File.basename(tmpFile)}")
            `mv #{tmpFile} #{@postProcDir}/#{tmpFile}`
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
       
    # Generate PCA/tSNE dependency files for tool
    # @param [String] makeDependenciesDir file path to directory containing files necessary to generate dependencies
    # @return [nil]
    def generateDependenciesForPCA(makeDependenciesDir)
      # Create command for actually launching the shell script that will run the tool
      makeDependenciesScript = File.basename(ENV['CREATE_ERCC_PCA_DEPENDENCIES_R'])
      `cp #{ENV['CREATE_ERCC_PCA_DEPENDENCIES_R']} #{makeDependenciesDir}`
      `cp #{ENV['MAKE_ERCC_PCA_DEPENDENCIES_RMD']} #{makeDependenciesDir}`
      `cp #{ENV['ERCC_PCA_BACKGROUND_METADATA']} #{makeDependenciesDir}`
      `cp #{ENV['ERCC_PCA_BACKGROUND_METADATA']} #{makeDependenciesDir}/Dependencies`
      command = "module unload R ; module load R/3.4-devel ; cd #{makeDependenciesDir} ; R CMD BATCH #{makeDependenciesScript}"
      # Launch command
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Exit status: #{exitStatus}")
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Tool run to generate dependencies completed with exit code: #{statusObj.exitstatus}")
      findError(exitStatus, makeDependenciesDir)
      return
    end

    # Transfer output files to user database
    # @param [String] analysisName analysis name used in file path
    # @param [String] toolVersion current version of erccPCA tool in Workbench (NOT version of R package)
    # @param [String] outputDir path to current output directory
    # @return [FixNum] exitCode to indicate whether method succeeded or failed
    def transferFiles(analysisName, toolVersion, outputDir)
      # Find target URI for user's database
      targetUri = URI.parse(@outputs[0])
      # Set resource path
      if(@remoteStorageArea)
        rsrcPath = "#{targetUri.path}/file/#{CGI.escape(@remoteStorageArea)}/ERCC_DimensReduc_v#{toolVersion}/{analysisName}/{outputFile}/data?"
      else 
        rsrcPath = "#{targetUri.path}/file/ERCC_DimensReduc_v#{toolVersion}/{analysisName}/{outputFile}/data?"
      end
      # We also need to add our gbKey for access (if it exists)
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      # Upload all output files
      allOutputFiles = Dir.entries(outputDir)
      allOutputFiles.delete(".")
      allOutputFiles.delete("..")
      allOutputFiles.each { |outputFile|
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
    # @param [String] makeDependenciesDir directory that stores the files that create the dependencies for the plotting tool
    # @return [boolean] indicating if a erccPCA error was found or not.
    def findError(exitStatus, makeDependenciesDir)
      retVal = true
      errorMessages = []
      makeDependenciesOutput = "#{makeDependenciesDir}/Make_Dependencies.md"
      # Check the obvious things first. Outright failure or putting error messages on stderr:
      if(exitStatus)
        # So far, so good. Look for ERROR lines in STDOUT / STDERR.
        cmd = "grep -i \"ERROR\" #{makeDependenciesOutput} | grep -v \"Backtrace\""
        errorMessage = `#{cmd}`.strip
        if(errorMessage.empty?)
          retVal = false
        else
          errorMessages << errorMessage
        end
      else
        # OK, so none of our checks found anything, but there's still an error. 
        # Let's just look for ERROR lines in STDOUT / STDERR and at least report those!
        if(errorMessages.empty?)
          cmd = "grep -i \"ERROR\" #{makeDependenciesOutput} | grep -v \"Backtrace\""
          errorMessage = `#{cmd}`.strip
          errorMessages << errorMessage unless(errorMessage.empty?)
        end
      end
      # Did we find anything? Or, erccPCA failed (bad exit status) and we'll still report an error occurred, even if we didn't find anything
      if(retVal)
        # Here, we mark the current run as failed and set its error message correspondingly
        @failedRun = true
        @errUserMsg = "Generation of dependencies for Dimensionality Reduction Plotting tool failed.\nReason(s) for failure:\n\n"
        errorMessages = nil if(errorMessages.empty?)
        @errUserMsg << (errorMessages.join("\n\n") || "[No error info available from Dimensionality Reduction Plotting tool]\n")
        @errUserMsg << "\nThis tool is currently in beta status and may not work with every combination of samples.\nIf you receive an error email after launching your job,\nplease use the Contact Us button at the top of the Atlas\nto report your error."
      end
      return retVal
    end

   ########## METHODS RELATED TO PPR ##########

    # Run processPipelineRuns tool on CORE_RESULTS archive files
    # @param [String] analysisName analysis name (used for naming files and for knowing where to look for CORE_RESULTS archives to process)
    # @return [nil]
    def postProcessing(analysisName)
      # Produce processPipelineRuns job file
      pprJobFile = createPPRJobConf(analysisName)
      # Call processPipelineRuns wrapper
      callPPRWrapper(analysisName, pprJobFile)
      return
    end
   
    # Method to create processPipelineRuns jobFile.json used in callPPRWrapper()
    # @param [String] analysisName analysis name (used for naming files and for knowing where to look for CORE_RESULTS archives to process)
    # @return [nil]
    def createPPRJobConf(analysisName)
      pprJobConf = @jobConf.deep_clone()
      ## Define context 
      pprJobConf['context']['toolIdStr'] = "processPipelineRuns"
      pprJobConf['context']['scratchDir'] = "#{@postProcDir}/#{analysisName}"
      pprJobConf['settings']['localJob'] = true
      pprJobConf['settings']['suppressEmail'] = true
      pprJobConf['settings']['pcaJob'] = true
      pprJobConf['settings']['analysisName'] = analysisName
      ## Write jobConf hash to tool specific jobFile.json
      pprJobFile = "#{@postProcDir}/#{analysisName}/pprJobFile.json"
      File.open(pprJobFile,"w") do |pprJob|
        pprJob.write(JSON.pretty_generate(pprJobConf))
      end
      return pprJobFile
    end
    
    # Method to call processPipelineRuns wrapper on successful samples
    # @param [String] analysisName analysis name (used for naming files and for knowing where to look for CORE_RESULTS archives to process)
    # @param [String] pprJobFile path to file containing job conf for PPR job
    # @return [nil]
    def callPPRWrapper(analysisName, pprJobFile)
      # Create out and err files for processPipelineRuns wrapper, then call wrapper
      outFileFromPPR = "#{@postProcDir}/#{analysisName}/processPipelineRunsFromPCA.out"
      errFileFromPPR = "#{@postProcDir}/#{analysisName}/processPipelineRunsFromPCA.err"
      command = "cd #{@postProcDir}/#{analysisName}; processPipelineRunsWrapper.rb -C -j #{pprJobFile} >> #{outFileFromPPR} 2>> #{errFileFromPPR}"
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
            errorMessages = "It looks like none of your submitted CORE_RESULTS archives were valid inputs\nfor the post-processing tool (used to generate your miRNA read counts file).\nPlease try re-running exceRpt on those samples, or contact a DCC admin (#{@genbConf.gbDccAdminEmails.join(", ")}) for assistance.\n"
          end
        end
        # Print error message in error log for debugging purposes
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error messages: #{errorMessages}")
      end
      # Did we find anything?
      if(retVal)
        @errUserMsg = "exceRpt small RNA-seq Post-processing tool failed. Message from exceRpt small RNA-seq Post-processing tool:\n\n"
        @errUserMsg << (errorMessages || "[No error info available from exceRpt small RNA-seq Post-processing tool]\n")
        @errUserMsg << "\n\nThis tool is currently in beta status and may not work with every combination of samples.\nIf you receive an error email after launching your job,\nplease use the Contact Us button at the top of the Atlas\nto report your error." if(@settings['atlasVersion'] == "v4")
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
                            "|-----ERCC_DimensReduc_v#{@toolVersion}\n" +
                              "|------#{@analysisName}\n\n"
      else 
        additionalInfo << "|----ERCC_DimensReduc_v#{@toolVersion}\n" +
                            "|-----#{@analysisName}\n\n" 
      end
      additionalInfo << "NOTE 1:\nWe are in the process of integrating support\nfor visualizing your results.\nIn the mean time, feel free to download\nthe visualization tool from the following URL:\n\n"
      additionalInfo << "https://github.com/jamesdiao/ERCC-Plotting-Tool\n\n"
      additionalInfo << "To visualize your results, install the tool by following the README\n"
      additionalInfo << "and then drag all of your result files into the \"Dependencies\" folder.\n"
      additionalInfo << "You may overwrite the pre-existing files."
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
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::ErccPCAWrapper)
end
