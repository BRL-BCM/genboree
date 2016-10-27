#!/usr/bin/env ruby
#########################################################
############ RSEQtools Batch Processing pipeline wrapper#
## This wrapper runs the RNA-Seq data analysis pipeline #
## for a batch of samples
## Requires a manifest file to run the RSEQtools pipeline
## in the batch processing mode
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
  class RseqtoolsBatchWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the RSEQtools pipeline in the batch processing mode'.
                        This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "Sai Lakshmi Subramanian (sailakss@bcm.edu)" ],
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

        ## If wrapper is called internally from another tool, 
        ## it is very useful to suppress emails
        @suppressEmail = (@settings["suppressEmail"].to_s.strip =~ /^(?:true|yes)$/i ? true : false)

        # Set up format options coming from the UI
        @analysisName = @settings['analysisName']
        @coverageFactor = @settings['coverageFactor']
        
        @doUploadResults = @settings['doUploadResults']
        @deleteDupTracks = @settings['deleteDupTracks']    
        
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])

        ## Get the tool version from toolConf
        @toolVersion = @toolConf.getSetting('info', 'version')
        @settings['toolVersion'] = @toolVersion
        
        # Get the URI of the manifest file and fill the @inputFiles array with the list of FASTQ files
        @inputFiles = []
        @manifestFileURI = nil
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Inputs: #{@inputs.inspect}")
        @inputs.each { |inputFile|
          inputFile = inputFile.chomp("?")
          if(inputFile =~ /(.+?)\.(?i)manifest(?-i)\.json/)
            @manifestFileURI = inputFile
          else
            @inputFiles << inputFile
          end
        }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "MANIFEST FILE: #{@manifestFileURI}")
        
        # All input sequence file names (before and after expanding the compressed multi-file archive)
        @sequenceFiles = {}
        
        if(@manifestFileURI.empty? or @manifestFileURI.nil?)
          @errUserMsg = "Manifest file is not part of the inputs.\nRSEQtools cannot be run in batch processing mode without a valid manifest file.\n"
          raise @errUserMsg
        end

        @toolId = "rseqtools"

        ## Make sure the genome version is supported by 
        ## current implementation of this pipeline
        @genomeVersion = @settings['genomeVersion']
        @gbRSeqToolsGenomesInfo = JSON.parse(File.read(@genbConf.gbRSeqToolsGenomesInfo))
        @geneAnnoIndexBaseName = @gbRSeqToolsGenomesInfo[@genomeVersion]['indexBaseName']
        
        if(@geneAnnoIndexBaseName.nil?)
          @errUserMsg = "The gene annotations for genome: #{@genomeVersion} could not be found since this genome is not supported currently.\nPlease contact the Genboree Administrator for adding support for this genome. "
          raise @errUserMsg
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "GENOME VERSION: #{@genomeVersion} ==== SUPPORTED GENOMES: #{@gbRSeqToolsGenomesInfo.inspect}")
        
        # Get location of the shared scratch space in the cluster
        @clusterSharedScratchDir = @genbConf.clusterSharedScratchDir
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "SHARED SCRATCH SPACE: #{@clusterSharedScratchDir}")
        
        if(@clusterSharedScratchDir.nil? or @clusterSharedScratchDir.empty?) 
          @errUserMsg = "ERROR: Genboree config does not have the shared scratch location information.\nPlease contact the Genboree Administrator for creating a shared scratch area for temporary storage of input and/or output files and adding it to the Genboree config."
          raise @errUserMsg
        end
        
        if(File.directory?(@clusterSharedScratchDir))
          @jobSpecificSharedScratch = "#{@clusterSharedScratchDir}/#{@jobId}"
          `mkdir -p #{@jobSpecificSharedScratch}`
        else
          @errUserMsg = "ERROR: Shared scratch dir #{@clusterSharedScratchDir} is not available.\nPlease contact the Genboree Administrator for creating a shared scratch area for temporary storage of input and/or output files."
          raise @errUserMsg
        end
        
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
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "BEGIN RSEQtools long RNA-seq Pipeline - Batch processing")

        conditionalJob = false
        @rseqToolsJobs = {}

        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading manifest file from server")
        # Download manifest file @manifestFile
        @exitCode = downloadManifest(@manifestFileURI)
        if(@exitCode == 0)
          # Sanity check manifest file. Make sure manifest file is in correct format with all required info.
          @exitCode = checkManifest(@manifestFile)
          if(@exitCode == 0)
            # Download all input files - Not necessary since the processing tool will handle this
            downloadFiles()
            @inputBaseNames = []
            if(!@sequenceFiles.nil? or !@sequenceFiles.empty?)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input sequencing file: #{@sequenceFiles.inspect}")
              ## Get the file base names of the extracted input sequence files
              ## This is done to avoid issues where manifest has sample file names with the extensions
              ## of the compression formats (like .gz or .zip or .bz2, etc) and the @sequenceFiles array
              ## holds the file path of the extracted file
              #@sequenceFiles.each { |seqFile|
              #  filebase = File.basename(seqFile)
              #  @inputBaseNames << filebase
              #}
              #$stderr.debugPuts(__FILE__, __method__, "STATUS", "Input sequencing file base names: #{@inputBaseNames.inspect}")
              # Link files listed in the manifest with the input files
              linkManifestWithInputFiles()
              # Submit rseqtools jobs using Parallel
              if(!@seqFiles.nil? or !@seqFiles.empty?)
                # Create a reusable ApiCaller instance              
                apiCaller = BRL::Genboree::REST::ApiCaller.new(@host, "/REST/v1/genboree/tool/{toolId}/job", @user, @pass)
                @preConditionJobs = []
  #              @workerJobIds = []
                @seqFiles.each { |inFile|
                  next if(inFile.empty?)
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input file: #{inFile}")
                  rseqToolsJobObj = createRSeqtoolsJobConf(inFile)
                  begin
                    # Submit job
                    $stderr.debugPuts(__FILE__, __method__, "PAYLOAD:", JSON.pretty_generate(rseqToolsJobObj))
                    httpResp = apiCaller.put({ :toolId => @toolId }, rseqToolsJobObj.to_json)
                    
                    # Check result                  
                    if(apiCaller.succeeded?)
                      conditionalJob = true
                      $stderr.debugPuts(__FILE__, __method__, "RESPONSE::\n", JSON.pretty_generate(apiCaller.parseRespBody))
                      rseqToolsJobId = apiCaller.parseRespBody['data']['text']
                      @rseqToolsJobs[rseqToolsJobId] = inFile
                      $stderr.debugPuts(__FILE__, __method__, "JOB ID", rseqToolsJobId )
                      condition = {
                        "type" => "job",
                        "expires" => (Time.now + Time::WEEK_SECS).to_s,
                        "met" => false,
                        "condition"=> {
                          "dependencyJobUrl" =>
                            "http://#{@host}/REST/v1/job/#{rseqToolsJobId}",
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
                      $stderr.debugPuts(__FILE__, __method__, "RSEQTOOLS JOBS:", @rseqToolsJobs.inspect)
                      
                      @preConditionJobs << condition  
                      $stderr.debugPuts(__FILE__, __method__, "PRECONDIITONS:", @preConditionJobs.inspect)
                      $stderr.debugPuts(__FILE__, __method__, "STATUS", "RSeqTools job accepted with analysis name: #{rseqToolsJobObj['settings']['analysisName'].inspect}. \n  HttpResponse: #{httpResp.inspect}\n  statusCode: #{apiCaller.apiStatusObj['statusCode'].inspect}\n  statusMsg: #{apiCaller.apiStatusObj['msg'].inspect}\n#{'='*80}\n")
                    else
                      $stderr.debugPuts(__FILE__, __method__, "ERROR [but continuing]:", "RSeqTools job submission failed for #{@toolId.inspect}! HTTP Response object: #{httpResp.class}. Response payload:\n#{apiCaller.respBody}\n#{'='*80}\n")
                    end
                  rescue => err
                    $stderr.debugPuts(__FILE__, __method__, "ERROR [but continuing]", "Problem with submitting the RSeqTools job #{rseqToolsJobObj.inspect}: #{err.message.inspect}.\n#{err.backtrace.join("\n")}")
                  end
                }              
              end
            else
              @errUserMsg = "ERROR: List of input files is not available. The files listed in the manifest cannot be linked with the raw input files."
              raise @errUserMsg
            end
          end
        end
        
        # Schedule the final email job only if there are worker RSeqtools jobs submitted (at least one)
        if(conditionalJob)
          scheduleFinalEmailJob()
        end
        
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE RSEQtools Long RNAseq Pipeline. END.")
        ## DONE RSEQtools Pipeline
      rescue => err
        #cleanUp("", @jobSpecificSharedScratch)
        @err = err
        @errUserMsg = "ERROR: Running of RSEQtools Long RNA-seq Pipeline failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to run RSEQtools Long RNA-seq Pipeline." if(@errInternalMsg.nil?)
        @exitCode = 30
      end
      return @exitCode
    end

###### *****************************
###### Methods used in this workflow
###### *****************************
    # Download manifest file
    # @param [String] manifestLocation FTP path to manifest file 
    # @return [Fixnum] exit code that indicates whether error occurred during manifest download (0 if no error, 21 if error)
    def downloadManifest(manifestFileURI)
      begin
        # Download manifest file
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading manifest file #{manifestFileURI} ")
        fileBaseName = File.basename(manifestFileURI)
        tmpFile = fileBaseName.makeSafeStr(:ultra)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest base name: #{fileBaseName} and file name on disk: #{tmpFile}")
        retVal = @fileApiHelper.downloadFile(manifestFileURI, @userId, tmpFile)
        # If there's an error downloading the manifest file, report that to the user
        if(!retVal)
          @errUserMsg = "Failed to download file: #{fileBaseName} from the Genboree database. \nPlease contact Genboree administrator for further assistance."
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "ApiCaller failed to download file #{fileBaseName}: #{apiCaller.respBody.inspect}")
          raise @errUserMsg
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Manifest file downloaded successfully to #{tmpFile}")
        # Check to make sure that the file contains the proper file extension (.manifest.json).  If it doesn't, report that error to the user.
        if(tmpFile =~ /.manifest.json$/)
          @manifestFile = tmpFile.clone
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "File #{@manifestFile} has a valid file extension.")
        else
          @errUserMsg = "Manifest file does not seem to have correct file extension.\nDoes your manifest file end in \".manifest.json\"?\nIf not, please rename and resubmit your manifest file!"
          raise @errUserMsg
        end
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: The manifest file could not be downloaded properly.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 21
      end
      return @exitCode
    end
    
    # Sanity check manifest file
    # @param [String] manifestFile path to manifest file
    # @return [Fixnum] exit code that indicates whether error occurred during manifest check (0 if no error, 22 if error)
    def checkManifest(manifestFile)
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking if manifest file #{manifestFile} is correct")
        # Read in manifest file and see whether it's in proper JSON
        @fileData = JSON.parse(File.read(manifestFile)) rescue nil
        # This boolean will keep track of whether manifest file is broken (not proper JSON)
        brokenManifest = false
        # If @fileData isn't valid, then we know that manifest is broken. We will still try to retrieve user's userLogin, though
        unless(@fileData)
          brokenManifest = true
          @errUserMsg = "Manifest file is not in proper JSON format.\nPlease check your manifest file for formatting issues\nor run your manifest file through a JSON validator\nlike JSONLint (www.jsonlint.com) to find errors."
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Data from the manifest file #{manifestFile}: #{@fileData.inspect}")

        # Grab sample-specific portion of manifest file - this should be proper JSON if entire manifest file was read in correctly earlier
        @manifest = @fileData["manifest"]
        #### CHECKING INDIVIDUAL SAMPLES ####
        @manifest.each { |eachSampleHash|
          #### CHECKING DATA FILE NAME ASSOCIATED WITH SAMPLE ####
          # Check if data file name is provided - if not, we raise an error (it's required!).
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Each Sample: #{eachSampleHash.inspect}")
          if(eachSampleHash.key?("dataFileName"))
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Single end sequencing files")
            # If the manifest hash has the key `dataFileName`, then the files are from a single ended sequencing run
            if(!eachSampleHash.key?("dataFileName") or eachSampleHash["dataFileName"].nil? or eachSampleHash["dataFileName"].empty?)
              @errUserMsg = "Manifest file is missing a \"dataFileName\" value for single-end sequencing reads.\nPlease check that each sample has a \"dataFileName\" value if the sequencing type is single-end."
              raise @errUserMsg
            end
          else
            # The files are from a paired-ended sequencing run
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Paired-end sequencing files")
            if(!eachSampleHash.key?("dataFileName1") and !eachSampleHash.key?("dataFileName2"))
              @errUserMsg = "Manifest file is missing the \"dataFileName1\" and \"dataFileName2\" keys for paired-end sequencing reads.\nPlease check that each sample has both \"dataFileName1\" and \"dataFileName2\" keys and\n the values for these keys point to the filenames of paired-end sequencing reads."
              raise @errUserMsg
            elsif((eachSampleHash["dataFileName1"].nil? or eachSampleHash["dataFileName1"].empty?) or (eachSampleHash["dataFileName2"].nil? or eachSampleHash["dataFileName2"].empty?)) 
              @errUserMsg = "Manifest file is missing the \"dataFileName1\" and \"dataFileName2\" values for paired-end sequencing reads.\nPlease check that each sample has values (the filenames) for both \"dataFileName1\" and \"dataFileName2\" keys for paired-end sequencing reads."
              raise @errUserMsg
            end  
          end
        }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "File #{manifestFile} is a valid manifest file.")
 
      rescue => err
        # Generic error message if somehow an error pops up that wasn't handled effectively by the above checks (shouldn't happen)
        @errUserMsg = "ERROR: The manifest file does not have all required variables for running the job.\nPlease contact a Genboree admin for help." if(@errUserMsg.nil?)
        @errInternalMsg = err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", err.message.inspect)
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", errBacktrace)
        @exitCode = 22
      end
      return @exitCode
    end
    
    # Download input files from database, extracts zipped files, sniffs files to make sure they're FASTQ, and sets up hash values for a given input file
    # @return [nil]
    def downloadFiles()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input files using threads #{@inputFiles.inspect}")
      # Ensure all input files are downloaded to the shared scratch space in the cluster
      uriPartition = @fileApiHelper.downloadFilesInThreads(@inputFiles, @userId, @jobSpecificSharedScratch)
      localPaths = uriPartition[:success].values
        
      localPaths.each { |tmpFile|
        originalBaseName = File.basename(tmpFile)
        
        ## Expand the files if it is compressed
        exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracting input file #{tmpFile}")
        exp.extract()
        # Sniffer - To check FASTQ format
        sniffer = BRL::Genboree::Helpers::Sniffer.new()
        inputFile = exp.uncompressedFileName
        uncompressedBaseName = File.basename(inputFile)
        @sequenceFiles[originalBaseName] = { :uncompressedBaseName => uncompressedBaseName, :uncompressedPath => inputFile, :compressedPath => tmpFile }
        # Delete original file if it was compressed (we don't need to keep it)
        `rm -f #{tmpFile}` unless(exp.compressedFileName == inputFile)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "The path of the unzipped input file is: #{inputFile}")
        if(File.zero?(inputFile))
          @errUserMsg = "Input file #{inputFile} is empty.\nPlease upload non-empty file and try again."
          raise @errUserMsg
        end
        tempDir = exp.tmpDir
        
        # Check if the current input file is a single compressed archive of various (compressed) input FASTQ files.
        if(File.directory?(inputFile))
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "It looks like the #{inputFile} is a directory, so the file must have been a compressed archive of all input files.")
          @sequenceFiles = {} # Start making the sequenceFiles hash again for each file in the directory
          @allFiles = Dir.entries(inputFile)
          # Check each file inside this directory
          @allFiles.each{ |inputFileInDir|
            # Skip the junk folder __MACOSX
            next if(inputFileInDir == "." or inputFileInDir == ".." or inputFileInDir =~ /__MACOSX/)
            inputDataFile = "#{tempDir}/#{inputFileInDir}"
            # We do not support multiple subdirs inside the compressed archive. All input FASTQ files should be at the top level.
            if(File.directory?(inputDataFile))
              @errUserMsg = "File #{inputDataFile} is a directory. Data files in an archive should not be inside a sub-directory. Please reupload your archive without any sub-directories."
              raise @errUserMsg
            else
              originalBaseName = File.basename(inputFileInDir)

              ## Expand this data file
              exp = BRL::Genboree::Helpers::Expander.new(inputDataFile)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracting input file #{inputDataFile}")
              exp.extract()
              # Sniffer - To check FASTQ format
              sniffer = BRL::Genboree::Helpers::Sniffer.new()
              dataFile = exp.uncompressedFileName
              uncompressedBaseName = File.basename(dataFile)
              
              # populate the sequenceFiles hash for each file
              @sequenceFiles[originalBaseName] = { :uncompressedBaseName => uncompressedBaseName, :uncompressedPath => dataFile, :compressedPath => inputDataFile }

              # Delete original file if it was compressed (we don't need to keep it)
              `rm -f #{inputDataFile}` unless(inputDataFile == dataFile)  
              # Detect if file is in FASTQ format
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Detecting file type of extracted file #{dataFile} using file sniffer")
              sniffer.filePath = dataFile
              # Reject any file other than FASTQ
              fileType = ""
              fileType = "FASTQ" if(sniffer.detect?('fastq'))
              unless(fileType == "FASTQ")
                @errUserMsg = "File #{dataFile} is not in FASTQ format (acceptable input formats).\nPlease check the file format and try again."
                raise @errUserMsg
              end
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input File #{dataFile} is in correct format, FASTQ")
              # Add input files and its associated data to the hash
              #sequenceFiles << "file://#{dataFile}"
              @sequenceFiles[originalBaseName][:seqFilePath] = "file://#{dataFile}"
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
          # Detect if file is in FASTQ format
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Detecting file type of extracted file #{inputFile} using file sniffer")
          sniffer.filePath = inputFile
          # Reject any file other than FASTQ or SRA
          fileType = ""
          fileType = "FASTQ" if(sniffer.detect?('fastq'))
          unless(fileType == "FASTQ")
            @errUserMsg = "File #{inputFile} is not in FASTQ format (acceptable input format).\nPlease check the file format and try again."
            raise @errUserMsg
          end
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input File #{inputFile} is in correct format, FASTQ")
          # Add input files and its associated data to the hash
          #sequenceFiles << "file://#{inputFile}"
          @sequenceFiles[originalBaseName][:seqFilePath] = "file://#{inputFile}"
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

    # Ensure files in manifest are available in @sequenceFiles - the input files downloaded from the user db,
    # i.e. the actual files or those extracted from an archive    
    def linkManifestWithInputFiles()
      # the seqFiles array of arrays will contain the entire Genboree URL of the input file(s)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Linking the manifest file with the raw input files")
      @seqFiles = []
      
      @originalBaseNames = @sequenceFiles.keys
      
      @manifest.each { |eachSampleHash|
        if(eachSampleHash.key?("dataFileName"))
          fileName = eachSampleHash["dataFileName"]
          
          foundSEInput = @originalBaseNames.grep(/#{fileName}/)
          $stderr.debugPuts(__FILE__, __method__, "STATUS SE FILE", "Single ended input file #{foundSEInput}")
          
          inputSE = []
          if(!foundSEInput.empty? or !foundSEInput.nil?)
            @sequenceFiles.each_key { |inputFile|
              if(inputFile =~ /#{foundSEInput}/)
                inputSE << @sequenceFiles[inputFile][:seqFilePath]
              end              
            }
            if(!inputSE.empty? or !inputSE.nil?)
              @seqFiles << inputSE
            end  
          else
            @errUserMsg = "ERROR: Single-end data file name #{fileName} mentioned in the manifest is not found in the list of inputs to the tool."
            raise @errUserMsg
          end
        else
          fileName1 = eachSampleHash["dataFileName1"]
          fileName2 = eachSampleHash["dataFileName2"]
     
          foundPEInput1 = @originalBaseNames.grep(/#{fileName1}/)
          foundPEInput2 = @originalBaseNames.grep(/#{fileName2}/)
          $stderr.debugPuts(__FILE__, __method__, "STATUS PE FILE 1", "Paired ended input file 1 #{foundPEInput1}")
          $stderr.debugPuts(__FILE__, __method__, "STATUS PE FILE 2", "Paired ended input file 2 #{foundPEInput2}")
          
          inputsPE = []
          if(!foundPEInput1.empty? and !foundPEInput1.nil? and !foundPEInput2.empty? and !foundPEInput2.nil?)
            @sequenceFiles.each_key { |inputFile|
              if(inputFile =~ /#{foundPEInput1}|#{foundPEInput2}/)
                inputsPE << @sequenceFiles[inputFile][:seqFilePath]
              end              
            }
            
            if(!inputsPE.empty? or !inputsPE.nil?)
              @seqFiles << inputsPE
            end  
          else
            @errUserMsg = "ERROR: Paired-end data file names #{fileName1} and #{fileName2} mentioned in the manifest are not found in the list of inputs to the tool."
            raise @errUserMsg
          end
        end
      }
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "List of input sequence files = #{@seqFiles.inspect}")
      return
    end
    
  # Create RSEQtools job Conf file for each sample
  ### Method to create FastQC jobFile.json
    def createRSeqtoolsJobConf(inFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Preparing the RSEqtools jobConf for #{inFile.inspect}")
      # Reuse the existing jobConf and modify properties as needed 
      @RSeqtoolsJobConf = @jobConf.deep_clone()
     
      ## Define inputs
      @RSeqtoolsJobConf['inputs'] = inFile
      
      $stderr.debugPuts(__FILE__, __method__, "INPUT FILES", "Input file(s): #{inFile.inspect}")

      ## Keep the same output database
     
      ## Define context 
      @RSeqtoolsJobConf['context']['toolIdStr'] = @toolId
      @RSeqtoolsJobConf['context']['warningsConfirmed'] = true
      
      ## Define settings
      analysisName = "RSEQtools-#{Time.now.strftime('%Y-%m-%d-%H:%M:%S').gsub('-0', '-')}"
      
      # Extract the file base name from the URI
      # For single end file
      $stderr.debugPuts(__FILE__, __method__, "URI PARSE", "Input file: #{inFile[0]}")
      
      file1 = URI.parse(inFile[0])
      ## If the input path is not a location of a local file, but an actual HTTP URL
      if(!file1.scheme =~ /file/)
        fileBase1 = @fileApiHelper.extractName(inFile[0])        
      else
        fileBase1 = file1.path
      end
      
      fileBaseName1 = File.basename(fileBase1)
      safeFileName1 = fileBaseName1.makeSafeStr(:ultra)
      safeFileName1.gsub!(/[\.|\s]+/, '_')
      
      if(!inFile[1])
        # use the single end file base name as the track name
        lffType = safeFileName1
      else
        # for paired end, construct a track name with the base names of both sequencing files
        file2 = URI.parse(inFile[1])
        ## If the input path is not a location of a local file, but an actual HTTP URL
        if(!file2.scheme =~ /file/)
          fileBase2 = @fileApiHelper.extractName(inFile[1])        
        else
          fileBase2 = file2.path
        end
      
        fileBaseName2 = File.basename(fileBase2)
        safeFileName2 = fileBaseName2.makeSafeStr(:ultra)
        safeFileName2.gsub!(/[\.|\s]+/, '_')
        
        lffType = "#{safeFileName1}_#{safeFileName2}"      
      end      
      
      @RSeqtoolsJobConf['settings']['analysisName'] = analysisName
      @RSeqtoolsJobConf['settings']['lffType'] = lffType
      @RSeqtoolsJobConf['settings']['suppressEmail'] = false
      
      return @RSeqtoolsJobConf
    end
    
    # Schedules a job to send email on completion of each "RSEQtools" job
    def scheduleFinalEmailJob()
      $stderr.debugPuts(__FILE__, __method__, "FINAL EMAIL JOB SUBMISSION METHOD", "Submit final job with preconditions." )

      finalJobConf = @jobConf.deep_clone()
      apiCaller = BRL::Genboree::REST::ApiCaller.new(@host, "/REST/v1/genboree/tool/sendRSEQtoolsEmail/job", @user, @pass)
      toolJobIds = @rseqToolsJobs.keys
      finalJobConf['inputs'] = toolJobIds
      finalJobConf['settings'] = {}
      finalJobConf['settings']['genomeVersion'] = @genomeVersion
      finalJobConf['settings']['analysisName'] = @analysisName
      
      finalJobConf['context']['toolIdStr'] = "sendRSEQtoolsEmail"

      # Upload was accepted as a deferred job due to the size of the file. We will submit a conditional job
      finalJobConf['preconditionSet'] =  {
        "willNeverMatch"=> false,
        "numMet"=> 0,
        "someExpired"=> false,
        "count"=> 0,
        "preconditions"=> @preConditionJobs
      }
      $stderr.debugPuts(__FILE__, __method__, "JOB CONF", finalJobConf.inspect )
      apiCaller.put({}, finalJobConf.to_json)

      if(!apiCaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "FINAL EMAIL JOB SUBMISSION FAILURE", apiCaller.respBody.inspect )
      else
        $stderr.debugPuts(__FILE__, __method__, "FINAL EMAIL JOB ACCEPTED", apiCaller.respBody.inspect )
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
    
############ END of methods specific to this wrapper
    
########### Email 
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
      emailObject.settings      = @jobConf['settings']
      emailObject.exitStatusCode = @exitCode
      
      rseqJobIds = @rseqToolsJobs.keys
      numJobsSubmitted = rseqJobIds.length
      $stderr.debugPuts(__FILE__, __method__, "JOB IDS", "#{rseqJobIds.inspect}")
      additionalInfo = ""
      additionalInfo << "Your long RNA-seq samples have been submitted for processing through the RSEQTools analysis pipeline.\n" +
                        "You will receive an email when each job finishes and also after all samples in the batch have been processed.\n" + 
                        "\n==================================================================\n" +
                        "Number of jobs submitted for processing: #{numJobsSubmitted}\n\n" +
                        "List of job IDs: \n"
      @rseqToolsJobs.each_key { |jobId|
        inFiles = @rseqToolsJobs[jobId]  
        additionalInfo << "JOB ID: #{jobId}\n" +
                          "  Input(s): \n"
        inFiles.each { |fname|
          fname = fname.chomp("?")
          inputFileBase = File.basename(fname)
          additionalInfo << "    #{inputFileBase}\n"
        }
        additionalInfo << " \n"
      }

      #projHost = URI.parse(@projectUri).host
      #emailObject.resultFileLocations = "http://#{projHost}/java-bin/project.jsp?projectName=#{CGI.escape(@prjApiHelper.extractName(@projectUri))}"
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
      if(@suppressEmail)
        return nil
      else
        return emailErrorObject
      end
    end
    
    ## Method to send success e-mail to user
    #def prepSuccessEmail()
    #  # Add number of input files to Job settings
    #  numInputFiles = @inputFiles.length
    #  @settings['numberOfInputFiles'] = numInputFiles
    #  
    #  ## Update jobFile.json with updated contents
    #  toolJobFile = "#{@scratchDir}/jobFile.json"
    #  File.open(toolJobFile,"w") do |jobFile|
    #    jobFile.write(JSON.pretty_generate(@jobConf))
    #  end
    #       
    #  ## Email object
    #  emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
    #  emailObject.userFirst     = @userFirstName
    #  emailObject.userLast      = @userLastName
    #  emailObject.analysisName  = @analysisName
    #  inputsText                = buildSectionEmailSummary(@inputs)
    #  emailObject.inputsText    = inputsText
    #  outputsText               = buildSectionEmailSummary(@outputs)
    #  emailObject.outputsText   = outputsText
    #  emailObject.settings      = @jobConf['settings']
    #  emailObject.exitStatusCode = @exitCode
    #  additionalInfo = ""
    #  additionalInfo << "Your result files are currently being uploaded to your database.\nPlease wait for some time before attempting to download your result files.\n\n" +
    #                    "Result files can be found at this location in the Genboree Workbench:\n" + 
    #                      "|-Group: '#{@groupName}'\n" +
    #                        "|--Database: '#{@dbName}'\n" +
    #                          "|---Files\n" +
    #                            "|----smallRNAseqPipeline_v#{@toolVersion}\n"+
    #                              "|-----#{@analysisName}\n\n"+
    #                    "NOTE 1:\nEach sample you submitted will have its own unique subfolder\nwhere you can find the exceRpt pipeline results for that sample.\n" +
    #                    "NOTE 2:\nThe file that ends in '_results_v#{@toolVersion}' is a large archive\nthat contains all the result files from the exceRpt pipeline.\nWithin that archive, the file 'sRNAbenchOutputDescription.txt' provides\na description of the various output files generated by sRNAbench.\n" +
    #                    "NOTE 3:\nThe file that ends in '_CORE_RESULTS_v#{@toolVersion}' is a much smaller archive\nthat contains the key result files from the exceRpt pipeline.\nThis file can be found in the 'CORE_RESULTS' subfolder\nand has been decompressed in that subfolder for your convenience.\n" +
    #                    "NOTE 4:\nFinally, post-processing results (created by\nthe exceRpt small RNA-seq Post-processing tool)\ncan be found in the 'postProcessedResults_v#{@toolVersion}' subfolder.\n" +
    #                    "==================================================================\n" +
    #                    "Number of files in your submission: #{numInputFiles}\n" +
    #                    "Number of files successfully processed: #{@successfulSamples}\n" +
    #                    "Number of files not successfully processed: #{@failedSamples}\n" +
    #                    "==================================================================\n" +                        
    #                    "List of files in your submission: \n"
    #  @inputFiles.each_key { |inFile|
    #    successStatus = ""
    #    if(@inputFiles[inFile][:failedRun])
    #      successStatus = "FAILED"
    #    else
    #      successStatus = "SUCCEEDED"
    #    end
    #    additionalInfo << " File: #{File.basename(inFile)} - #{successStatus}\n"
    #  }
    #  # Only print unsuccessful samples message if at least one sample was unsuccessful
    #  unless(numInputFiles == @successfulSamples)
    #    additionalInfo << "\n\nAny samples listed below were NOT processed due to an error.\n\n"
    #    # Here, we print all failed runs and corresponding error messages in additionalInfo
    #    @inputFiles.each_key { |inFile|
    #      if(@inputFiles[inFile][:failedRun])
    #        additionalInfo << "#{File.basename(inFile)} failed with the following message:\n"
    #        additionalInfo << "#{@inputFiles[inFile][:errorMsg]}\n"
    #      end
    #    }
    #  end
    #  emailObject.resultFileLocations = nil
    #  emailObject.additionalInfo = additionalInfo
    #  if(@suppressEmail)
    #    return nil
    #  else
    #    return emailObject
    #  end
    #end
    #
    ## Method to send failure e-mail to user
    #def prepErrorEmail()
    #  # Add number of input files to Job settings
    #  numInputFiles = @inputFiles.length
    #  @settings['numberOfInputFiles'] = numInputFiles
    #  ## Update jobFile.json with updated contents
    #  toolJobFile = "#{@scratchDir}/jobFile.json"
    #  File.open(toolJobFile,"w") do |jobFile|
    #    jobFile.write(JSON.pretty_generate(@jobConf))
    #  end
    #  
    #  emailErrorObject                = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
    #  emailErrorObject.userFirst      = @userFirstName
    #  emailErrorObject.userLast       = @userLastName
    #  emailErrorObject.analysisName   = @analysisName
    #  inputsText                      = buildSectionEmailSummary(@inputs)
    #  emailErrorObject.inputsText     = inputsText
    #  outputsText                     = buildSectionEmailSummary(@outputs)
    #  emailErrorObject.outputsText    = outputsText
    #  emailErrorObject.settings       = @jobConf['settings']
    #  emailErrorObject.errMessage     = @errUserMsg
    #  emailErrorObject.exitStatusCode = @exitCode
    #  additionalInfo = ""
    #  additionalInfo << "Group name: #{@groupName}\nDatabase name: #{@dbName}\n" +
    #                    "Number of files in your submission: #{numInputFiles}\n" +
    #                    "List of files in your submission: \n"
    #  @inputFiles.each_key { |inFile|
    #    additionalInfo << " File: #{File.basename(inFile)}\n"
    #  }
    #  additionalInfo << "\n\nBelow, you can find more specific error messages for failed runs.\n" +
    #                    "If you do not see any information below, this means that\nthe Genboree tool failed somewhere other than the actual pipeline itself.\n\n"
    #  # Here, we print all failed runs and corresponding error messages in additionalInfo
    #  @inputFiles.each_key { |inFile|
    #    if(@inputFiles[inFile][:failedRun])
    #      additionalInfo << "#{File.basename(inFile)} failed with the following message:\n"
    #      additionalInfo << "#{@inputFiles[inFile][:errorMsg]}\n"
    #      additionalInfo << "==================================================================\n"
    #    end
    #  }        
    #  emailErrorObject.resultFileLocations = nil
    #  emailErrorObject.additionalInfo = additionalInfo
    #  if(@suppressEmail)
    #    return nil
    #  else
    #    return emailErrorObject
    #  end
    #end
  end
end; end ; end ; end

# If we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::RseqtoolsBatchWrapper)
end
