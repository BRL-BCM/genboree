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
  class BwaWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the 'BWA' tool - a mapper for low divergent sequences.\n  This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "Neethu Shah (neethus@bcm.edu)" ],
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
        @numCores = ENV['GB_NUM_CORES']
        @dbrcKey = @context['apiDbrcKey']
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        ## Genboree specific "context" variables
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        @toolIdStr = @context['toolIdStr']        
        ## Check if output is written locally in a directory or copied to Genboree db
        @outputLocally = (@outputs.first =~ /^\// ? true : false )
        
        @outputWigFile = "#{@scratchDir}/out.wig"
        
        @doUploadResults = @settings['doUploadResults']
        if(@outputLocally)
          @resultsDir = File.expand_path(@outputs.first)
          @groupName = "Internal Bwa"
          @dbName = "Internal Bwa"
        else
          @targetUri = @outputs.first
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
          @groupName = @grpApiHelper.extractName(@outputs.first)
          @dbName = @dbApiHelper.extractName(@outputs.first)
        end
        
        ## Set up format options coming from the UI - "Settings" variables
        @analysisName = @settings['analysisName']
        @genomeVersion = @settings['genomeVersion']
 
        ## Index Options
        @useIndex = @settings['useIndex']
        if(@useIndex =~ /makeNewIndex/)
          @indexBaseName = @settings['indexBaseName']
          @epList = @settings['epList']

          ## Make subJobsScratch dir for use by internal tool wrappers
          @subJobsScratch = "#{@scratchDir}/subJobsScratch"
          `mkdir -p #{@subJobsScratch}`

        elsif(@useIndex =~ /useExistingIndex/)
          @indexFileName = @settings['indexList']
        end
        
        ## BWA Specific Options
        @presetOption = @settings['presetOption']
        
        ## Options common to BWA-MEM, BWA-Bactrack and BWA-SW
        ## Default settings vary
        @matchPenalty = @settings['matchPenalty']
        @gapOpen = @settings['gapOpen']
        @gapExtension = @settings['gapExtension']
        
        # Common BWA-MEM and BWA-SW, default setting varies
        @bandWidth = @settings['bandWidth']
        @matchScore = @settings['matchScore']
	
        ## BWA-MEM specific options
        @minSeedLength = @settings['minSeedLength']
        @xDropoff = @settings['xDropoff']
        @interleavedFileOption = @settings['interleavedFileOption']
        @outAlignment = @settings['outAlignment']
        @outAll = @settings['outAll']        
        
        ## BWA-Backtrack specific options
        @editDistance = @settings['editDistance']
        @numGapOpens = @settings['numGapOpens']
        @disDeletion = @settings['disDeletion']
        @disIndel = @settings['disIndel']
        @maxEditSeed = @settings['maxEditSeed']
        @maxNumAlignments = @settings['maxNumAlignments']
        
        ## Output Files
        @outputSamFile = "#{@scratchDir}/#{CGI.escape(@analysisName)}_aligned.sam"
        @outputBamFile = "#{@scratchDir}/#{CGI.escape(@analysisName)}_aligned.bam"
        @outputBaiFile = "#{@scratchDir}/#{CGI.escape(@analysisName)}_aligned.bai"
        
        ## If wrapper is called internally from another tool, 
        ## it is very useful to suppress emails
        @suppressEmail = (@settings["suppressEmail"].to_s.strip =~ /^(?:true|yes)$/i ? true : false)
        
        
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = "ERROR: Could not set up required variables for running job. Check your jobFile.json to make sure all variables are defined."
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
        @outFile = @errFile = ""
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
        
        # BWA Index File Operations

        if(@useIndex =~ /makeNewIndex/)
          createIndexBwaJobConf()
          callIndexBwaWrapper()
        elsif(@useIndex =~ /useExistingIndex/)
          getIndexFromDb()
          ## Unzip bwa index
          if(File.exists?(@indexFile) && @indexFile =~ /tar.gz/)
            exp = BRL::Genboree::Helpers::Expander.new(@indexFile)
            exp.extract()
          end
          @indexFiles = Dir["#{exp.tmpDir}/*.bwt"]
          @genomeIndexBase = @indexFiles[0].split('.').first
          if(!File.exists?("#{@genomeIndexBase}.sa"))
            @errUserMsg = "File #{@genomeIndexBase}.sa is not found. Cannot proceed further without a valid BWA index.\n"
            raise @errUserMsg
          end
        end
        
        # Download the input from the server
        downloadFiles()
        # Run BWA 0.7
        runBWA()        
        # Convert SAM to BAM using Samtools
        sam2bam()
        # Create BAM Index - .bai file
        makeBai()
        # Convert BAM to bed using BEDTools
        bam2bed()
        # Rename the sam & bam files
        Dir.entries(@scratchDir).each { |file|
          if(file =~ /\.sam/)
            `mv #{@scratchDir}/#{file} #{@outputSamFile}`
          end
          if(file =~ /\.bam/)
            `mv #{@scratchDir}/#{file} #{@outputBamFile}`
          end
          if(file =~ /\.bai/)
            `mv #{@scratchDir}/#{file} #{@outputBaiFile}`
          end
        }         
        if(@outputLocally)
          `rm -f #{@inputFile1} #{@inputFile2}; gzip #{@scratchDir}/out.bed`
          system("mv #{@scratchDir}/* #{@resultsDir}")
          `touch #{@scratchDir}/internalBwaJob.txt`
        else
          # Convert the bed file into wig
          createWig()
          # Uploads the coverage tracks as bigwig/bigbed files
          if(@doUploadResults)
            uploadWig()
          end
	    
          transferFiles()
          # Finally, nuke the  files: wig and compress the bed file (since its not copied over to the server)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing #{@outputWigFile}. Compressing out.bed")
          `rm -f #{@outputWigFile} #{@outputSamFile} #{@outputBamFile} #{@outputBaiFile} #{@inputFile1} #{@inputFile2}; rm -f #{@scratchDir}/out.bed *.gz`; 
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing index files #{@genomeIndexBase} .......")
          `rm -f #{@genomeIndexBase}*`
        end
      rescue => err
        @err = err
        # Try to read the out file first:
        outStream = ""
        outStream << File.read(@outFile) if(File.exists?(@outFile))
        # If out file is not there or empty, read the err file
        if(!outStream.empty?)
          errStream = ""
          errStream = File.read(@errFile) if(File.exists?(@errFile))
          @errUserMsg = errStream if(!errStream.empty?)
        end
        @exitCode = 30
      end
      return @exitCode
    end

    #### BWA specifc methods

   def createIndexBwaJobConf()
      @indexBwaJobConf = @jobConf.deep_clone()

      ## Define inputs
      ## This tool does not need any inputs, since it downloads entrypoints from db
      @indexBwaJobConf['inputs'] = [ ]

      ## Define inputs, outputs
      ## Writes output to same user db
      if(@outputLocally)
        @indexBwaJobConf['outputs'] = [ @indexOutputs ]
      end

      ## Define settings
      @indexBwaJobConf['settings']['epList'] = @epList
      @indexBwaJobConf['settings']['indexBaseName'] = @indexBaseName
      @indexBwaJobConf['settings']['suppressEmail'] = "true"

      ## Define context
      @indexBwaJobConf['context']['toolIdStr'] = "indexBwa"

      @indexBwaScratchDir = "#{@subJobsScratch}/indexBwaOutput"
      @indexBwaJobConf['context']['scratchDir'] = @indexBwaScratchDir

      ## Create job specific scratch and results directories
      `mkdir -p #{@indexBwaScratchDir}`

      ## Write jobConf hash to tool specific jobFile.json
      @indexBwaJobFile = "#{@indexBwaScratchDir}/indexBwaJobFile.json"
      File.open(@indexBwaJobFile,"w") do |indexBwaJob|
        indexBwaJob.write(JSON.pretty_generate(@indexBwaJobConf))
      end
    end

     ## Make bwa index for user specified reference sequences
    def callIndexBwaWrapper()
      @errFile = "#{@indexBwaScratchDir}/bwaIndex.err"

      ## Build Bwa index
      command = "indexBwaWrapper.rb -j #{@indexBwaJobFile} 2> #{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      if(!exitStatus)
        @errUserMsg = "BWA indexing failed to run."
        raise "Command: #{command} died. Check #{@errFile} for more information."
      end
      ## Set index base name for use in bwa index command
      @genomeIndexBase = "#{@indexBwaScratchDir}/#{CGI.escape(@indexBaseName)}"
    end


    ## Get BWA Index Files from the database
    def getIndexFromDb()
      @bwaindex = File.basename(@indexFileName)
      @indexFile = "#{@scratchDir}/#{@bwaindex}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Writing index from db to file: #{@indexFile}")
      retVal = @fileApiHelper.downloadFile(@indexFileName, @userId, @indexFile)
      if(!retVal)
        @errUserMsg = "Failed to get BWA index file from db"
        raise "File Download FAILED!! for the indexfile , #{@indexFileName}"
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Index file downloaded successfully to #{@indexFile}")
    end


    ## Download input files from database
    def downloadFiles()
      inputFileFastq = Array.new()
      @inputFile1 = @inputFile2 = nil
      fileCount = 0
      @inputs.each { |input|
        fileBase = @fileApiHelper.extractName(input)
        fileBaseName = File.basename(fileBase)
        tmp = fileBaseName.makeSafeStr(:ultra)
        tmpFile = "#{@scratchDir}/#{CGI.escape(tmp)}"
        retVal = @fileApiHelper.downloadFile(input, @userId, tmpFile)
        if(!retVal)
          @errUserMsg = "Failed to download file: #{fileBase} from server"
          raise "Failed to download the file, #{fileBase}."
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "File downloaded successfully to #{tmpFile}")
        exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
        exp.extract()
        # Sniffer - To check FASTQ format
        sniffer = BRL::Genboree::Helpers::Sniffer.new()
        inputFileFastq[fileCount] = true 
      if(fileCount == 0)
        @inputFile1 = exp.uncompressedFileName
        sniffer.filePath = @inputFile1
	      unless(sniffer.detect?("fastq"))
          inputFileFastq[fileCount] = false
          @errUserMsg = "Input file is not in FASTQ format. Please check the file format."
          raise @errUserMsg
        end
      else
        @inputFile2 = exp.uncompressedFileName
        sniffer.filePath = @inputFile2
        unless(sniffer.detect?("fastq"))
          inputFileFastq[fileCount] = false
          if(inputFileFastq[0] == true)
            @errUserMsg = "Input file 2 is not in FASTQ format. Please check the file format."
          else
            @errUserMsg = "Paired-end input files are not in FASTQ format. Please check the file format."
          end
          raise @errUserMsg
        end
      end
        # Convert to unix format
        convObj = BRL::Util::ConvertText.new(exp.uncompressedFileName, true)
        convObj.convertText()
        fileCount += 1
      }
    end
    
    ## Run the tool. Uses bwa 0.7, via a module load in the .pbs file.
    def runBWA()
      @errFile = "#{@scratchDir}/bwa.err"
      @alignedSam = "#{@scratchDir}/aligned.sam"
      # BWA commands when the alignment option is "BWA-mem"
      if(@presetOption =~ /mem/)
        if(@outAll)
          @outAll = '-a'
        else
          @outAll = ""
        end
        command = "bwa #{@presetOption} -t #{@numCores} -k #{@minSeedLength} -w #{@bandWidth} -d #{@xDropoff} -A #{@matchScore} -B #{@matchPenalty} -O #{@gapOpen} -E #{@gapExtension} -T #{@outAlignment} #{@outAll} #{@genomeIndexBase}"
        unless(@inputFile1 and @inputFile2)
          if(@interleavedFileOption)
            command << " -p #{@inputFile1}"
          else
            command << " #{@inputFile1}"
          end
        else
          command << " #{@inputFile1} #{@inputFile2}"
        end
        command << " > #{@alignedSam} 2> #{@errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
        exitStatus = system(command)
      end
      # BWA commands when the alignment option is BWA-Backtrack
      if(@presetOption =~ /aln/)
        @saCoordinate1= "#{@scratchDir}/1.sai"
        @saCoordinate2= "#{@scratchDir}/2.sai"
        command = "bwa #{@presetOption} -t #{@numCores} -n #{@maxEditSeed} -o #{@numGapOpens} -d #{@disDeletion} -i #{@disIndel} -k #{@editDistance} -M #{@matchPenalty} -O #{@gapOpen} -E #{@gapExtension} #{@genomeIndexBase}"
        unless(@inputFile1 and @inputFile2)
          command << " #{@inputFile1} > #{@saCoordinate1} 2> #{@errFile}"
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
          exitStatus = system(command)
          command = "bwa samse -n #{@maxNumAlignments} #{@genomeIndexBase} #{@saCoordinate1} #{@inputFile1} > #{@alignedSam} 2> #{@errFile}"
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
          exitStatus = system(command)
	  system("rm #{@saCoordinate1}")
        else
          command = "bwa #{@presetOption} -t #{@numCores} -n #{@maxEditSeed} -o #{@numGapOpens} -d #{@disDeletion} -i #{@disIndel} -k #{@editDistance} -M #{@matchPenalty} -O #{@gapOpen} -E #{@gapExtension} #{@genomeIndexBase} #{@inputFile1} > #{@saCoordinate1} 2> #{@errFile}"
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
          exitStatus = system(command)
          command = "bwa #{@presetOption} -t #{@numCores} -n #{@maxEditSeed} -o #{@numGapOpens} -d #{@disDeletion} -i #{@disIndel} -k #{@editDistance} -M #{@matchPenalty} -O #{@gapOpen} -E #{@gapExtension} #{@genomeIndexBase} #{@inputFile2} > #{@saCoordinate2} 2> #{@errFile}"
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
          exitStatus = system(command)
          command = "bwa sampe -n #{@maxNumAlignments} #{@genomeIndexBase} #{@saCoordinate1} #{@saCoordinate2} #{@inputFile1} #{@inputFile2} >#{@alignedSam} 2> #{@errFile}"
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
          exitStatus = system(command)
	  system("rm #{@saCoordinate1} #{@saCoordinate2}")
        end
      end
      # BWA commands when the alignment option is BWA-SW
      if(@presetOption =~ /bwasw/)
	command = "bwa #{@presetOption} -t #{@numCores} -a #{@matchScore} -b #{@matchPenalty} -q #{@gapOpen} -r #{@gapExtension} -w #{@bandWidth} #{@genomeIndexBase}"
	unless(@inputFile1 and @inputFile2)
	  command << " #{@inputFile1} > #{@alignedSam} 2> #{@errFile}"
        else
	  command << " #{@inputFile1} #{@inputFile2} > #{@alignedSam} 2> #{@errFile}"
        end
	$stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
	exitStatus = system(command)		
      end
      if(!exitStatus)
        @errUserMsg = "BWA failed to run"
        raise "Command: #{command} died. Check #{@errFile} for more information."
      end
    end
    
    # Converts sam to bam. Require samtools which is loaded as module via the .pbs file.
    def sam2bam()
      @alignedSam = "#{@scratchDir}/aligned.sam"
      @alignedBam = "#{@scratchDir}/aligned.bam"
      @bamFile = "#{@scratchDir}/sorted.bam"
      @bamFilePrefix = "#{@scratchDir}/sorted"
      @errFile = "#{@scratchDir}/samtoolsSamToBam.err"
      #command = "samtools view -h -S #{@alignedSam} -b | samtools sort -n - #{@bamFilePrefix} 2> #{@errFile}"
      command = "samtools view -h -S -b #{@alignedSam} > #{@alignedBam} 2> #{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching sam to bam command: #{command}")
      exitStatus = system(command)
      if(!exitStatus)
        @errUserMsg = "Could not convert sam file to bam file."
        raise "Command: #{command} died. Check #{@errFile} for more information. "
      end
      command = "samtools sort #{@alignedBam} #{@bamFilePrefix} 2>>#{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching sorting command: #{command}")
      exitStatus = system(command)
      if(!exitStatus)
        @errUserMsg = "Could not convert sam file to bam file."
        raise "Command: #{command} died. Check #{@errFile} for more information.."
      end
    end

    ## Make BAI file - index of BAM file        
    def makeBai()    
      @baiFile = "#{@scratchDir}/out.bai"
      @errFile = "#{@scratchDir}/createBaiForBam.err"
      command = "samtools index #{@bamFile} #{@baiFile} 2> #{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      if(!exitStatus)
        @errUserMsg = "Could not generate index for bam file."
        raise "Command: #{command} died. Check #{@errFile} for more information. "
      end
    end

    ## Convert BAM to bed using BEDTools
    def bam2bed()
      @bedFile = "#{@scratchDir}/out.bed"
      @errFile = "#{@scratchDir}/bedtools.err"
      command = "bedtools bamtobed -i #{@bamFile} > #{@bedFile} 2> #{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      if(!exitStatus)
        @errUserMsg = "Could not convert bam file to bed."
        raise "Command: #{command} died. Check #{@errFile} for more information. "
      end
    end

    ## Transfer outputs to user database
    def transferFiles()
      # Parse output URI 
      targetUri = URI.parse(@outputs[0])
      # Find resource path by tacking onto the end of target URI the particular portion related to these Bowtie files 
      # :analysisName => @analysisName
      # :outputFile => File.basename(@outputSamFile)
      # :outputFile => File.basename(@outputBamFile)
      # :outputFile => File.basename(@outputBaiFile)
      rsrcPath = "#{targetUri.path}/file/BWA/{analysisName}/{outputFile}/data?"
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      # outputSamFile
      uploadFile(targetUri.host, rsrcPath, @userId, @outputSamFile, {:analysisName => @analysisName, :outputFile => File.basename(@outputSamFile)})
      # outputBamFile
      uploadFile(targetUri.host, rsrcPath, @userId, @outputBamFile, {:analysisName => @analysisName, :outputFile => File.basename(@outputBamFile)})
      # outputBaiFile
      uploadFile(targetUri.host, rsrcPath, @userId, @outputBaiFile, {:analysisName => @analysisName, :outputFile => File.basename(@outputBaiFile)})
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
        
    ## Call the coverage tool that creates a wig file
    def createWig()
      @outFile = "#{@scratchDir}/coverage.out"
      @errFile = "#{@scratchDir}/coverage.err"
      command = "coverage.rb -i #{@bedFile} -f bed -o #{@outputWigFile} -t #{@trackName} > #{@outFile} 2> #{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running command: #{command}")
      exitStatus = system(command)
      if(!exitStatus)
        @errUserMsg = "Could not convert bed to wig."
        raise "Command Died: #{command}. Check #{@outFile} and #{@errFile} for more information. "
      end
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
        uploadAnnosObj.uploadWig(CGI.escape(File.expand_path(@outputWigFile)), false)
        exp = BRL::Genboree::Helpers::Expander.new('out.wig.gz')
        exp.extract() 
        #`gunzip out.wig.gz` # Because the wig importer would have compressed the file
      rescue => uploadErr
        $stderr.puts "Error: #{uploadErr}"
        $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
        @errUserMsg = "FATAL ERROR: Could not upload result wig file to target database."
        if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
          @errUserMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
        end
        raise @errUserMsg
      end
      
      begin
        uploadAnnosObj.wigToBigWig(CGI.escape(File.expand_path("#{@outputWigFile}")))
      rescue => uploadErr
        $stderr.puts "Error: #{uploadErr}"
        $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
        @errUserMsg = "FATAL ERROR: Could not convert wig file to bigWig file and upload to the server.\n"
        if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
          @errUserMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
        end
        raise @errUserMsg
      end

    end
    
    
    #### End of BWA specific methods  
    
    def prepSuccessEmail()

      unless(@inputFile1 and @inputFile2)
	      inputInfo = {
	                    "File" => File.basename(@fileApiHelper.extractName(@inputs.first)),
                    }
      else
        inputInfo = {
	                    "File1" => File.basename(@fileApiHelper.extractName(@inputs.first)),
                      "File2" => File.basename(@fileApiHelper.extractName(@inputs.last))
                    }
      end
      if(@useIndex =~ /useExistingIndex/)
        indexList = @settings['indexList']
        indexName = File.basename(indexList)

        files = @fileApiHelper.extractName(indexList)
        fileString = files.gsub(/\//, " >> ")
        @settings.delete('indexList')
      end

      additionalInfo = ""
      additionalInfo << "You can download result files from this location:\n" + 
                          "|-Group: '#{@groupName}'\n" +
                            "|--Database: '#{@dbName}'\n" +
                              "|---Files\n" +
                                "|----BWA\n"+
                                  "|-----#{@analysisName}\n\n"
      if(!files.nil?)
        additionalInfo << "  The index file '#{indexName}' used in this analysis \n " +
                          "  can be found at: \n" +
                          "  Files >> #{fileString} \n\n  "
      end

      resultFileLocation = <<-EOS
      Host: #{@dbApiHelper.extractHost(@outputs.first)}
        Grp: #{@grpApiHelper.extractName(@outputs.first)}
          Db: #{@dbApiHelper.extractName(@outputs.first)}
            Files Area:
              * BWA/
                * #{@settings['analysisName']}/
                  * #{CGI.unescape(File.basename(@outputBaiFile))}
                  * #{CGI.unescape(File.basename(@outputBamFile))}
                  * #{CGI.unescape(File.basename(@outputSamFile))}
     
      EOS
      if(@presetOption =~ /mem/)
	settingsToEmail = ["presetOption", "gapOpen", "gapExtension", "bandWidth", "matchScore", "minSeedLength", "xDropoff", "interleavedFileOption", "outAlignment", "outAll", "doUploadResults"]
      elsif(@presetOption =~ /aln/)
	settingsToEmail = ["presetOption", "matchPenalty", "gapOpen", "gapExtension", "editDistance", "numGapOpens", "disDeletion", "disIndel", "maxEditSeed", "maxNumAlignments","doUploadResults"]
      else
	settingsToEmail = ["presetOption", "matchPenalty", "gapOpen", "gapExtension", "bandWidth", "matchScore", "doUploadResults"]	
      end
      settings = {}
      settingsToEmail.each { |kk|
        settings[kk] = @settings[kk]
      }
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, 
                           @analysisName, inputInfo, outputsText="n/a", settings, additionalInfo, resultFileLocation, resultFileURLs=nil, @shortToolTitle)
      if(@suppressEmail)
        successEmailObject = nil
      end
      return successEmailObject
    end

    def prepErrorEmail()
      additionalInfo = @errUserMsg
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", 
                         inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      if(@suppressEmail)
        errorEmailObject = nil
      end
      return errorEmailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::BwaWrapper)
end
