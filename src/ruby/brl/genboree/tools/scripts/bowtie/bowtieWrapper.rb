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
require "brl/genboree/helpers/sniffer"
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class BowtieWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the 'Bowtie' tool.
                        This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "Sai Lakshmi Subramanian(sailakss@bcm.edu)" ],
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
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "#####BEGIN Bowtie job ###################")
        
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        
        ## Genboree specific "context" variables
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

        ## Make subJobsScratch dir for use by internal tool wrappers
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Making subJobsScratch directory for running internal tool wrappers")
        @subJobsScratch = "#{@scratchDir}/subJobsScratch"
        `mkdir -p #{@subJobsScratch}`
        
        ## Check if output is written locally in a directory or copied to Genboree db
        @outputLocally = (@outputs[0] =~ /^\// ? true : false )
        
        @outputWigFile = "out.wig"
        @outputWigFileGz = "out.wig.gz"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Settings Hash: #{@settings.inspect}")
        @doUploadResults = @settings['doUploadResults']
        @deleteDupTracks = @settings['deleteDupTracks']

        if(@outputLocally)
          @resultsDir = File.expand_path(@outputs[0])
          @groupName = "Internal Bowtie"
          @dbName = "Internal Bowtie"          
          @indexOutputs = @settings['indexOutputs']           
        else
          @targetUri = @outputs[0]
          if(@doUploadResults)
            @lffType = @settings['lffType'].strip
            @lffSubType = @settings['lffSubType'].strip
            @className = @settings['trackClassName'].strip
            @className = CGI.escape("#{@className}")
            @trackName = CGI.escape("#{@lffType}:#{@lffSubType}")
          else
            @lffType = "Read"
            @lffSubType = "Density"
            @className = CGI.escape("User Data")
            @trackName = CGI.escape("#{@lffType}:#{@lffSubType}")
          end
          @groupName = @grpApiHelper.extractName(@outputs[0])
          @dbName = @dbApiHelper.extractName(@outputs[0])
        end
        
        ## Set up format options coming from the UI - "Settings" variables
        @analysisName = @settings['analysisName']
        @genomeVersion = @settings['genomeVersion']
        
        ## Index Options
        @useIndex = @settings['useIndex']
        if(@useIndex =~ /makeNewIndex/)
          @indexBaseName = @settings['indexBaseName']
          @epList = @settings['epList']
        elsif(@useIndex =~ /useExistingIndex/) 
          @indexFileName = @settings['indexList']            
        end

        ## Alignment Options
        @alignmentType = @settings['alignmentType']
        @presetOption = @settings['presetOption']
        if(@alignmentType =~ /endToEnd/)
          @alignmentType = "end-to-end"
          if(@presetOption =~ /veryFast/)
            @presetOption = "very-fast"
          elsif(@presetOption =~ /verySensitive/)
            @presetOption = "very-sensitive"
          end
        elsif(@alignmentType =~ /local/)
          if(@presetOption =~ /veryFast/)
            @presetOption = "very-fast-local"
          elsif(@presetOption =~ /fast/)
            @presetOption = "fast-local"
          elsif(@presetOption =~ /sensitive/)
            @presetOption = "sensitive-local"
          elsif(@presetOption =~ /verySensitive/)
            @presetOption = "very-sensitive-local"
          end
        end
        @disallowGapsWithin = @settings['disallowGapsWithin']
        @strandDirection = @settings['strandDirection']
        
        ## Input Reads Options
        @skipNReads = @settings['skipNReads']
        @alignFirstNReads = @settings['alignFirstNReads']
        @trimNBasesAt5prime = @settings['trimNBasesAt5prime']
        @trimNBasesAt3prime = @settings['trimNBasesAt3prime']
        
        ## Output Files
        @outputSamFile = "#{CGI.escape(@analysisName)}_aligned.sam"
        @outputBamFile = "#{CGI.escape(@analysisName)}_aligned.bam"
        @outputBaiFile = "#{CGI.escape(@analysisName)}_aligned.bai"
        @outputMetricsFile = "#{CGI.escape(@analysisName)}_metrics.txt"
       
        ## Reporting Options
        @unalignedReadsFile = @settings['unalignedReadsFile']
        if(@unalignedReadsFile)
          @unalignedReadsFile = "#{CGI.escape(@analysisName)}_unaligned.fastq"
        end
        @reportAlnsPerRead = @settings['reportAlnsPerRead']
        @noUnalignedSamRecord = @settings['noUnalignedSamRecord']

        ## If wrapper is called internally from another tool, 
        ## it is very useful to suppress emails
        @suppressEmail = (@settings["suppressEmail"].to_s.strip =~ /^(?:true|yes)$/i ? true : false)
        
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
        @inputFile1 = @inputFile2 = nil
        @outFile = @errFile = ""
        @outFile = "#{@scratchDir}/bowtie.out"
        @errFile = "#{@scratchDir}/bowtie.err"
  
        # Download the input from the server
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input files from the server")        
        downloadFiles()
        
        # Create bowtie2 index for reference sequence uploaded by user
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Create Bowtie2 index for reference sequences uploaded by the user")        
        if(@useIndex =~ /makeNewIndex/)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Create Job conf file for createIndex Job")   
          createIndexBowtieJobConf()
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Run index bowtie wrapper")   
          foundErrorInIndexing = callIndexBowtieWrapper()
        
          if(foundErrorInIndexing)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Errors while making the bowtie2 index!")   
            raise @errUserMsg
          else
            ## Set index base name for use in bowtie2 command
            @bt2indexBaseName = "#{@indexBowtieScratchDir}/#{CGI.escape(@indexBaseName)}"
          end
        elsif(@useIndex =~ /useExistingIndex/)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Using Existing Index - Getting index from the database")   
          getIndexFromDb()
        end
                
        # Run the tool. We use bowtie 2.1, via a module load in the .pbs file.
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Run Bowtie 2 job to map reads to the genome")   
        foundErrorInBowtie = runBowtie()

        unless(foundErrorInBowtie)
          # Convert SAM to BAM using Samtools
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Converting SAM to BAM using samtools")   
          sam2bam()

          # Create BAM Index - .bai file
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Create BAM Index - .bai file")   
          makeBai()
          
          # Convert BAM to bed using BEDTools
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Convert BAM to bed using BEDTools")   
          bam2bed()

          # Rename the sam & bam files
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Rename the sam & bam files")   
          renameFiles()
          
          # Upload tracks and clean up
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Upload tracks and clean up")   
          uploadTrack()
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "#####END of Bowtie job ###################")
        end # unless(foundErrorInBowtie)

      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of bowtie2 failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to run bowtie2." if(@errInternalMsg.nil?)
        @exitCode = 30
      ensure 
        cleanUpAfterError()
      end
      return @exitCode
    end

####################################
#### Methods used in this wrapper
####################################

    ## Download input files from database
    def downloadFiles()
      fileCount = 0
      @inputs.each { |input|
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input file #{input}")
        inputUri = URI.parse(input)
        if(inputUri.scheme =~ /file/)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input File #{input} is already available in the local shared scratch space.")
          tmpFile = inputUri.path
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Path of local input file #{tmpFile}")
        else       
          fileBase = @fileApiHelper.extractName(input)
          fileBaseName = File.basename(fileBase)
          tmpFile = fileBaseName.makeSafeStr(:ultra)
          retVal = @fileApiHelper.downloadFile(input, @userId, tmpFile)
          if(!retVal)
            @errUserMsg = "Failed to download file: #{fileBase} from server"
            raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "File downloaded successfully to #{tmpFile}")
          end
        end

        ## Extract the file if it is compressed
        exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
        exp.extract()

        # Sniffer - To check FASTQ format
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Detecting Fastq file type using sniffer")
        sniffer = BRL::Genboree::Helpers::Sniffer.new()
        inputFileFastq1 = true 
        if(fileCount == 0)
          @inputFile1 = exp.uncompressedFileName
          if(File.zero?(@inputFile1))
            @errUserMsg = "Input file is empty. Please upload non-empty file and try again."
            raise @errUserMsg
          end
          #Detect if file is in FASTQ format
          sniffer.filePath = @inputFile1
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Sniffing file #{@inputFile1}")
          unless(sniffer.detect?("fastq"))
            inputFileFastq1 = false
            @errUserMsg = "Input file is not in FASTQ format. Please check the file format."
            raise @errUserMsg
          end
        else
          @inputFile2 = exp.uncompressedFileName
          if(File.size(@inputFile2) == 0)
            @errUserMsg = "Input file is empty. Please upload non-empty file and try again."
            raise @errUserMsg
          end
          #Detect if file is in FASTQ format
          sniffer.filePath = @inputFile2
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Sniffing file #{@inputFile2}")
          unless(sniffer.detect?("fastq"))
            if(inputFileFastq1 =~ /true/)
              @errUserMsg = "Input file 2 is not in FASTQ format. Please check the file format."
            else
              @errUserMsg = "Paired-end input files are not in FASTQ format. Please check the file format."
            end
            raise @errUserMsg
          end
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done Sniffing file type")
        # Convert to unix format
        convObj = BRL::Util::ConvertText.new(exp.uncompressedFileName, true)
        convObj.convertText()
        fileCount += 1
      }
      return
    end


    ## Make indexBowtie jobFile.json
    def createIndexBowtieJobConf()
      @indexBowtieJobConf = @jobConf.deep_clone()

      ## Define inputs
      ## This tool does not need any inputs, since it downloads entrypoints from db
      @indexBowtieJobConf['inputs'] = [ ]
      
      ## Define inputs, outputs
      ## Writes output to same user db
      ## If bowtie is run as an internal job, we need to be able to provide a proper
      ## user db as output for indexBowtie tool
      if(@outputLocally)
        @indexBowtieJobConf['outputs'] = [ @indexOutputs ]
      end
      
      ## Define settings
      @indexBowtieJobConf['settings']['epList'] = @epList
      @indexBowtieJobConf['settings']['indexBaseName'] = @indexBaseName
      @indexBowtieJobConf['settings']['suppressEmail'] = "true"

      ## Define context
      @indexBowtieJobConf['context']['toolIdStr'] = "indexBowtie"
      
      @indexBowtieScratchDir = "#{@subJobsScratch}/indexBowtieOutput"
      @indexBowtieJobConf['context']['scratchDir'] = @indexBowtieScratchDir
    
      ## Create job specific scratch and results directories
      `mkdir -p #{@indexBowtieScratchDir}`
    
      ## Write jobConf hash to tool specific jobFile.json
      @indexBowtieJobFile = "#{@indexBowtieScratchDir}/indexBowtieJobFile.json"
      File.open(@indexBowtieJobFile,"w") do |indexBowtieJob|
        indexBowtieJob.write(JSON.pretty_generate(@indexBowtieJobConf))
      end
      return      
    end
 
    ## Make bowtie 2 index for user specified reference sequences
    def callIndexBowtieWrapper()  
      @errFileFromIndexBowtie = "#{@indexBowtieScratchDir}/indexBowtie.err"
      @outFileFromIndexBowtie = "#{@indexBowtieScratchDir}/indexBowtie.out"

      ## Build Bowtie2 index
      command = "cd #{@indexBowtieScratchDir}; indexBowtieWrapper.rb -C -j #{@indexBowtieJobFile} >> #{@outFileFromIndexBowtie} 2>> #{@errFileFromIndexBowtie}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Bowtie Indexing wrapper command completed with exit code: #{statusObj.exitstatus}")
      foundError = findError(exitStatus)
      return foundError
    end

    ## Get Bowtie2 index from db
    def getIndexFromDb()
      @bowtie2indexName = File.basename(@indexFileName)
      @bowtie2index = @bowtie2indexName.makeSafeStr(:ultra)
      @indexFile = "#{@scratchDir}/#{@bowtie2index}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Writing index from db to file: #{@indexFile}")
      retVal = @fileApiHelper.downloadFile(@indexFileName, @userId, @indexFile)
      if(!retVal)
        @errUserMsg = "Failed to download bowtie2 index file from db. \n Please try again after sometime.\n"
        raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Index file downloaded successfully to #{@indexFile}")
      end
      
      ## Unzip bowtie2 index using expander
      if(File.exists?(@indexFile) && @indexFile =~ /tar.gz/)
        exp = BRL::Genboree::Helpers::Expander.new(@indexFile)
        exp.extract()
      else
        @errUserMsg = "File #{@indexFile} does not exist.\n"   
        raise @errUserMsg
      end  
      ## Check if index is available and get bowtie 2 index basename
      @indexDir = exp.tmpDir
      Dir.glob("#{@indexDir}/*.bt2") do |@indFile|
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "File name = #{@indFile}")
        ## Look for index files. Bowtie 2 indexfiles end with .1.bt2, .2.bt2, .3.bt2 and so on
        if(@indFile =~ /^(.*)\.3\.bt2$/) ## Checking if indexfile with .3.bt2 extension is available, get index basename
          @bt2indexBaseName = $1
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Index file basename is #{@bt2indexBaseName}")
        end    
      end  
      unless(@bt2indexBaseName)  
        ## Bowtie 2 Index is not found
        @errUserMsg = "Bowtie 2 index files are not found. Cannot proceed further without a valid Bowtie2 index.\n"
        @exitCode = 34
        raise @errUserMsg
      end    
      return
    end

    ## Run Bowtie2.1
    def runBowtie()
      @alignedSam = "aligned.sam"
      
      command = "bowtie2 -p #{@numCores} -x #{@bt2indexBaseName} "
      unless(@inputFile1 and @inputFile2)
        command << " -U #{@inputFile1} "
      else
        command << " -1 #{@inputFile1} -2 #{@inputFile2} " 
      end
      command << " -S #{@scratchDir}/#{@alignedSam} "
      command << " --#{@alignmentType} --#{@presetOption} "
      ## Add options to command if values are provided by user
      if(!@skipNReads.nil? and @skipNReads.to_i > 0)
        command << " -s #{@skipNReads} "
      end
      if(!@trimNBasesAt5prime.nil? and @trimNBasesAt5prime.to_i > 0)
        command << " -5 #{@trimNBasesAt5prime} "
      end
      if(!@trimNBasesAt3prime.nil? and @trimNBasesAt3prime.to_i > 0)
        command << " -3 #{@trimNBasesAt3prime} "
      end
      if(!@disallowGapsWithin.nil? and @disallowGapsWithin.to_i > 0)
        command << " --gbar #{@disallowGapsWithin} "
      end
      if(!@alignFirstNReads.nil? and @alignFirstNReads.to_i > 0)
        command << " -u #{@alignFirstNReads} "
      end
      if(@strandDirection !~ /both/)
        command << " --#{@strandDirection} "
      end
      if(!@unalignedReadsFile.nil?)
        command << " --un #{@scratchDir}/#{@unalignedReadsFile} "
      end
      if(@noUnalignedSamRecord)
        command << " --no-unal "
      end
      if(!@reportAlnsPerRead.nil? and @reportAlnsPerRead.to_i > 0)
        command << " -k #{@reportAlnsPerRead} "
      end
      command << " --met-file #{@scratchDir}/#{@outputMetricsFile} "
      command << " > #{@outFile} 2> #{@errFile}"

      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Bowtie command completed with exit code: #{statusObj.exitstatus}")
      foundError = findError(exitStatus)
      return foundError
    end

    ## Convert SAM to sorted BAM file
    def sam2bam()
      @bamFile = "sorted.bam"
      @bamFilePrefix = "sorted"
      @sam2bamErrFile = "#{@scratchDir}/sam2bam.err"
      command = "samtools view -h -S #{@scratchDir}/#{@alignedSam} -b | samtools sort - #{@scratchDir}/#{@bamFilePrefix} 2>> #{@sam2bamErrFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      if(statusObj.exitstatus != 0 and File.size("#{@sam2bamErrFile}") > 0) # FAILED: sam2bam. Check stderr from this command.
        @errUserMsg = "Could not convert sam file to bam file using samtools,\nwhich exited with code #{statusObj.exitstatus}. Error message from samtools: \n\n"
        errorReader = File.open("#{@sam2bamErrFile}")
        errorReader.each_line { |line|
          @errUserMsg << "    #{line}"
        }
        errorReader.close()
        @errUserMsg.chomp!
        @errUserMsg << "    \"\n\n"
        @exitCode = 31
        raise 
      end
      return @exitCode
    end

    ## Make BAI file - index of BAM file        
    def makeBai()    
      @baiFile = "out.bai"
      @makeBaiErrFile = "#{@scratchDir}/makeBai.err"
      command = "samtools index #{@scratchDir}/#{@bamFile} #{@scratchDir}/#{@baiFile} 2>> #{@makeBaiErrFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      if(statusObj.exitstatus != 0 and File.size("#{@makeBaiErrFile}") > 0) # FAILED: makeBai. Check stderr from this command.
        @errUserMsg = "Could not generate index for bam file using samtools,\nwhich exited with code #{statusObj.exitstatus}. Error message from samtools: \n\n"
        errorReader = File.open("#{@makeBaiErrFile}")
        errorReader.each_line { |line|
          @errUserMsg << "    #{line}"
        }
        errorReader.close()
        @errUserMsg.chomp!
        @errUserMsg << "    \"\n\n"
        @exitCode = 32
        raise 
      end
      return @exitCode
    end

    ## Convert BAM to bed using BEDTools
    def bam2bed()
      @bedFile = "out.bed"
      @bam2bedErrFile = "#{@scratchDir}/bam2bed.err"
      command = "bedtools bamtobed -i #{@scratchDir}/#{@bamFile} > #{@scratchDir}/#{@bedFile} 2>> #{@bam2bedErrFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      if(statusObj.exitstatus != 0 and File.size("#{@bam2bedErrFile}") > 0) # FAILED: bam2bed. Check stderr from this command.
        @errUserMsg = "Could not convert bam file to bed using bedtools,\nwhich exited with code #{statusObj.exitstatus}. Error message from bedtools: \n\n"
        errorReader = File.open("#{@bam2bedErrFile}")
        errorReader.each_line { |line|
          @errUserMsg << "    #{line}"
        }
        errorReader.close()
        @errUserMsg.chomp!
        @errUserMsg << "    \"\n\n"
        @exitCode = 33
        raise 
      end
      return @exitCode
    end

    ## Rename files
    def renameFiles()
      Dir.entries(@scratchDir).each { |file|
        if(file =~ /\.sam/)
          `mv #{file} #{@scratchDir}/#{@outputSamFile}`
        end
        if(file =~ /\.bam/)
          `mv #{file} #{@scratchDir}/#{@outputBamFile}`
        end
        if(file =~ /\.bai/)
          `mv #{file} #{@scratchDir}/#{@outputBaiFile}`
        end
      }
      return
    end

    ## Upload signal tracks to user db
    def uploadTrack()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading signal tracks to user db")
      if(@outputLocally)
        # Delete the input files, wig file and compress the bed file 
        `rm -f #{@inputFile1} #{@inputFile2} #{@indexFile}; gzip #{@scratchDir}/out.bed`
        # Move all result files to the final results directory
        system("mv #{@scratchDir}/#{@outputSamFile} #{@scratchDir}/#{@outputBamFile} #{@scratchDir}/#{@outputBaiFile} #{@resultsDir}/")
        `touch #{@scratchDir}/internalBowtieJob.txt`
      else
        # Upload output signal track in wig format and mapped splice junction reads in gff format to user db
        # If the user has opted to delete existing tracks with matching names, we need to delete them from the target database before proceeding with the upload
        if(@deleteDupTracks)
          outputUri = URI.parse(@outputs[0])
          rsrcPath = outputUri.path
          apiCaller = WrapperApiCaller.new(outputUri.host, "#{rsrcPath}/trk/#{@trackName}", @userId)
          apiCaller.get()
          if(apiCaller.succeeded?) # Track exists, delete it
            apiCaller.delete()
            if(!apiCaller.succeeded?)
              $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to delete pre-existing track:#{@trackName.inspect} (during a re-attempt)\nAPI Response:\n#{apiCaller.respBody.inspect}")
              raise "Error: Could not delete pre-existing track: #{@trackName.inspect} (during a re-attempt) from target database."
            else
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Pre-existing track: #{@trackName.inspect} deleted.")
            end
          end
        end # if(@deleteDupTracks)
        
        # Convert the bed file into wig
        createWig()
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading wig files to the server")
        if(@doUploadResults)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Calling uploadWig method")
          uploadWig()
          #$stderr.debugPuts(__FILE__, __method__, "STATUS", "Calling createBigFilesJobConf method to prepare bigFiles jobConf file")
          #createBigFilesJobConf()
          #$stderr.debugPuts(__FILE__, __method__, "STATUS", "Calling callBigFilesWrapper method to run bigFiles wrapper")
          #callBigFilesWrapper()
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Transfer files to the output database")
        transferFiles()

        ## Clean up input files, index files, etc
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Tool clean up to remove unwanted files")
        toolCleanUp() 
      end # if(@outputLocally)
      return
    end

    ## Transfer outputs to user database
    def transferFiles()
      # Find target URI for user's database
      targetUri = URI.parse(@outputs[0])
      # Find resource path by tacking onto the end of target URI the particular portion related to these Bowtie files
      rsrcPath = "#{targetUri.path}/file/Bowtie/{analysisName}/{outputFile}/data?"
      # We also need to add our gbKey for access (if it exists)
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      # outputSamFile
      uploadFile(targetUri.host, rsrcPath, @userId, "#{@scratchDir}/#{@outputSamFile}", {:analysisName => @analysisName, :outputFile => CGI.unescape(@outputSamFile)})
      # outputBamFile
      uploadFile(targetUri.host, rsrcPath, @userId, "#{@scratchDir}/#{@outputBamFile}", {:analysisName => @analysisName, :outputFile => CGI.unescape(@outputBamFile)})
      # outputBaiFile
      uploadFile(targetUri.host, rsrcPath, @userId, "#{@scratchDir}/#{@outputBaiFile}", {:analysisName => @analysisName, :outputFile => CGI.unescape(@outputBaiFile)})
      # outputMetricsFile
      uploadFile(targetUri.host, rsrcPath, @userId, "#{@scratchDir}/#{@outputMetricsFile}", {:analysisName => @analysisName, :outputFile => CGI.unescape(@outputMetricsFile)})
      # unalignedReadsFile
      unless(File.exists?("#{@scratchDir}/#{@unalignedReadsFile}") and (File.size("#{@scratchDir}/#{@unalignedReadsFile}") > 0))
        uploadFile(targetUri.host, rsrcPath, @userId, "#{@scratchDir}/#{@unalignedReadsFile}", {:analysisName => @analysisName, :outputFile => CGI.unescape(@unalignedReadsFile)})
      end
      return
    end
    
    ## Upload a given file to Genboree server
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
   
    ## Clean Up
    # @todo toolWrapper defines a generic clean up now, is this one still needed?
    def toolCleanUp()
      # Delete the input files, index files, wig file and compress the bed file (since its not copied over to the server)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing input files, index files, wig file and compressing #{@scratchDir}/out.bed")
      `rm -f #{@scratchDir}/#{@outputWigFile} #{@inputFile1} #{@inputFile2} #{@indexFile} #{@indexDir}/*.bt2 #{@indexBowtieScratchDir}/*.bt2 ; gzip #{@scratchDir}/out.bed`
      return
    end   

    ## Clean Up in case of errors
    def cleanUpAfterError()
      # If there are any errors, then remove the index files 
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing index files")
      `rm -f #{@indexFile} #{@indexDir}/*.bt2 #{@indexBowtieScratchDir}/*.bt2`
      return
    end
  
    ## Call the coverage tool that creates a wig file
    def createWig()
      command = "coverage.rb -i #{@scratchDir}/#{@bedFile} -f bed -o #{@scratchDir}/#{@outputWigFile} -t #{@trackName} >> #{@outFile} 2>> #{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running command: #{command}")
      exitStatus = system(command)
      if(!exitStatus)
        @errUserMsg = "Could not convert bed to wig.\n"
        raise "Command Died: #{command}. Check #{@outFile} and #{@errFile} for more information. "
      end
      return
    end

## Upload wig files as tracks in output target database
    def uploadWig()
      # Get the refseqid of the target database
      outputUri = URI.parse(@outputs[0])
      rsrcPath = outputUri.path
      rsrcPath << "?gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      apiCaller = WrapperApiCaller.new(outputUri.host, rsrcPath, @userId)
      apiCaller.get()
      resp = JSON.parse(apiCaller.respBody)
      uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
      uploadAnnosObj.refSeqId = resp['data']['refSeqId']
      uploadAnnosObj.groupName = @groupName
      uploadAnnosObj.userId = @userId
      uploadAnnosObj.jobId = @jobId
      uploadAnnosObj.className = CGI.unescape(@className)
      uploadAnnosObj.trackName = CGI.unescape(@trackName)
      uploadAnnosObj.outputs = @outputs
      begin
        uploadAnnosObj.uploadWig(CGI.escape(File.expand_path("#{@scratchDir}/#{@outputWigFile}")), false)
        if(File.exists?("#{@scratchDir}/#{@outputWigFileGz}"))
          `gunzip #{@scratchDir}/#{@outputWigFileGz}` # Because the wig importer would have compressed the file
        end        
      rescue => uploadErr
        $stderr.puts "Error: #{uploadErr}"
        $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
        @errUserMsg = "FATAL ERROR: Could not upload result wig file to target database.\n"
        if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
          @errUserMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
        end
        raise @errUserMsg
      end
      ## Create and upload bigwig
      begin
        uploadAnnosObj.wigToBigWig(CGI.escape(File.expand_path("#{@scratchDir}/#{@outputWigFile}")))        
      rescue => uploadErr
        $stderr.puts "Error: #{uploadErr}"
        $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
        @errUserMsg = "FATAL ERROR: Could not convert wig file to bigWig file and upload to the server.\n"
        if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
          @errUserMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
        end
        raise @errUserMsg
      end
      return
    end

## Method to create bigwig job conf file
    def createBigFilesJobConf()
      @bigFilesJobConf = @jobConf.deep_clone()

      @outputUri = URI.parse(@outputs[0])
      @outputUri.path = "#{@outputUri.path}/trk/#{@trackName}"
      @wigTrack = @outputUri.to_s

      ## Define inputs
      @bigFilesJobConf['inputs'] = [@wigTrack]

      ## Define settings 
      @bigFilesJobConf['settings']['type'] = "bigwig"
      @bigFilesJobConf['settings']['suppressEmail'] = "true"

      ## Define context
      @bigFilesJobConf['context']['toolIdStr'] = "bigFiles"
      
      @bigFilesScratchDir = "#{@subJobsScratch}/bigFiles"
      @bigFilesJobConf['context']['scratchDir'] = @bigFilesScratchDir
      
      ## Create job specific scratch and results directories
      `mkdir -p #{@bigFilesScratchDir}`
      

      ## Define outputs
      @bigFilesJobConf['outputs'] = [ ]
      
      ## Write jobConf hash to tool specific jobFile.json 
      @bigFilesJobFile = "#{@bigFilesScratchDir}/bigFilesJobFile.json"
      File.open(@bigFilesJobFile,"w") do |bigFilesJob|
        bigFilesJob.write(JSON.pretty_generate(@bigFilesJobConf))
      end
      return
    end

## Method to call bigFiles tool wrapper to make bigwig file for the uploaded wig track
## This makes visualization easier for the user
    def callBigFilesWrapper()
      @errFileFromBigFiles = "#{@bigFilesScratchDir}/bedGraphToBigWig.err"
      command = "cd #{@bigFilesScratchDir}; bigFilesWrapper.rb -C -j #{@bigFilesJobFile} >> #{@outFile} 2>> #{@errFileFromBigFiles}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "BigFiles wrapper command completed with exit code: #{statusObj.exitstatus}")
      if(statusObj.exitstatus != 0 and File.size("#{@errFileFromBigFiles}") > 0) # FAILED: bigFiles. Check stderr from this wrapper.
        @errUserMsg = "Could not convert bedGraph to bigWig.\nBigFiles Wrapper failed with exitCode. #{statusObj.exitstatus}. \n\n"
        errorReader = File.open("#{@errFileFromBigFiles}")
        errorReader.each_line { |line|
          next if(line =~ /RuntimeError/ or line =~ /Backtrace/ or line =~ /Wrapper\.rb/)
          @errUserMsg << "    #{line}"
        }
        errorReader.close()
        @errUserMsg.chomp!
        @errUserMsg << "    \"\n\n"
        @exitCode = 42
        raise 
      end
      return @exitCode
    end

# Method to detect errors
# @param [boolean] exitStatus indicating if the system() call "succeeded" or not.
#   system() returns boolean, but if true can't be trusted for Bowtie 2.
# @return [boolean] indicating if a Bowtie 2 error was found or not.
#   if so, @errUserMsg, @errInternalMsg, @exitCode will be set appropriately
    def findError(exitStatus)
      retVal = false
      errorMessages = nil
      # Check the obvious things first. Outright failure or putting error messages on stderr:
      if(!exitStatus)
        # So far, so good. Look for ERROR lines on stdout.
        cmd = "grep -i \"ERROR\" #{@outFile} #{@errFile} | grep -v \"Backtrace\""
        errorMessages = `#{cmd}`

        ## Check errFile and outFile from indexBowtie tool
        if(@outFileFromIndexBowtie and File.exist?(@outFileFromIndexBowtie) and File.size("#{@outFileFromIndexBowtie}") > 0)
          cmd = "grep -h \"ERROR:\" #{@outFileFromIndexBowtie} "
          errorMessages << `#{cmd}`
        elsif(@errFileFromIndexBowtie and File.exist?(@errFileFromIndexBowtie) and File.size("#{@errFileFromIndexBowtie}") > 0)
          cmd = "grep -i \"ERROR\" #{@errFileFromIndexBowtie}"
          errorMessages << `#{cmd}`
        end

        ## Case when user uploads 2 FASTQ files that are not paired end, bowtie provides an error message
        ## Convert that error message into an informative message to user
        if(errorMessages =~ /fewer reads in file specified with/)
          errorMessages = "The input files are not paired-end, one file has fewer reads than the other.\n If you upload 2 input files, please make sure they are paired-end FASTQ files with same number of reads.\n"
        end

        if(errorMessages =~ /Failed to download file completely after attempt number/)
          errorMessages = "The input file or Bowtie index file could not be downlaoded from the server, this could be due to a network problem. Please try again after sometime or contact Genboree admin.\n"
        end
      else
        cmd = "grep -i \"ERROR\" #{@errFile} #{@errFileFromIndexBowtie}" 
        errorMessages = `#{cmd}`
      end  
      if(errorMessages.strip.empty?)
        retVal = false
      else
        retVal = true
      end

      # Did we find anything?
      if(retVal)
        @errUserMsg = "Bowtie2 Failed. Message from Bowtie2:\n\""
        @errUserMsg << (errorMessages || "[No error info available from Bowtie 2]")
        @errUserMsg << "    \"\n\n"
        @errInternalMsg = @errUserMsg
        @exitCode = 30
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
                                "|----Bowtie\n"+
                                  "|-----#{@analysisName}\n\n"
      if(!files.nil?) 
        additionalInfo << "  The index file '#{indexName}' used in this analysis \n " + 
                          "  can be found at: \n" +
                          "  Files >> #{fileString} \n\n  " +
                          "  Coverage track of mapped reads can be found under \"Tracks\" in your database.\n" +
                          "  These tracks can be readily viewed in the UCSC Genome Broswer using the \"View Tracks in UCSC Genome Browser\" \n" +
                          "  tool under \"Visualization\" menu in the toolbar. \n"
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
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::BowtieWrapper)
end

