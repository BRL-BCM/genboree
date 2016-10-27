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
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class TophatWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the 'TopHat' tool.
                        This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "Sameer Paithankar(paithank@bcm.edu)" ],
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
        @targetUri = @outputs[0]
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        @dbrcKey = @context['apiDbrcKey']
        @deleteSourceFiles = @settings['deleteSourceFiles']
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @toolScriptPrefix = @context['toolScriptPrefix']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        # Set up format options coming from the UI
        @analysisName = @settings['analysisName']
        @outputBamFile = "#{CGI.escape(@analysisName)}_accepted_hits.bam"
        @doUploadResults = @settings['doUploadResults']
        @refGenome = @settings['refGenome']
        if(@doUploadResults)
          @lffType = @settings['lffType'].strip
          @lffSubType = @settings['lffSubType'].strip
          @trackName = CGI.escape("#{@lffType}:#{@lffSubType}")
          @outputWigFile = "out.wig"
        else
          @lffType = "Read"
          @lffSubType = "Density"
          @trackName = CGI.escape("#{@lffType}:#{@lffSubType}")
          @outputWigFile = "out.wig"
        end
        @coverageSearch = @settings['coverageSearch']
        # Removed from tophat 2.0, will cause tophat crash:
        # @closureSearch = @settings['closureSearch']
        # @butterflySearch = @settings['butterflySearch']
        @minAnchorLength = @settings['minAnchorLength']
        @spliceMisMatches = @settings['spliceMisMatches']
        @minIntronLength = @settings['minIntronLength']
        @maxIntronLength = @settings['maxIntronLength']
        @maxInsertionLength = @settings['maxInsertionLength']
        @maxDeletionLength = @settings['maxDeletionLength']
        @initReadMisMatches = @settings['initialReadMismatches']
        @segmentMisMatches = @settings['segmentMisMatches']
        @segmentLength = @settings['segmentLength']
        @minClosureExon = @settings['minClosureExon']
        @minClosureIntron = @settings['minClosureIntron']
        @maxClosureIntron = @settings['maxClosureIntron']
        @minCoverageIntron = @settings['minCoverageIntron']
        @maxCoverageIntron = @settings['maxCoverageIntron']
        @minSegmentIntron = @settings['minSegmentIntron']
        @maxSegmentIntron = @settings['maxSegmentIntron']
        @autoDetermineMateInnerDist = @settings['autoDetermineMateInnerDist']
        @mateInnerDist = false
        @mateStdev = false
        if(!@autoDetermineMateInnerDist)
          @mateInnerDist = @settings['mateInnerDist']
          @mateStdev = @settings['mateStdev']
        end
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # [+returns+] nil
    def run()
      begin
        # Get data
        fileBase = "#{@format}_upload"
        command = ""
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
        @inputFile1 = @inputFile2 = nil
        # Download the input from the server
        downloadFiles()
        # If auto compute mate inner dist is checked, compute it.
        if(@autoDetermineMateInnerDist)
          autoDetermineMateInnerDist()
        end
        # First make sure that the reference gtf file exists
        if(!File.exists?("#{@genbConf.clusterGTFDir}/#{@refGenome}/refGene.gtf"))
          @errUserMsg = "The reference file: refGene.gtf for genome: #{@refGenome} could not be found since this genome is not supported currently.\nPlease contact the Genboree Administrator for adding support for this genome. "
          raise @errUserMsg
        end
        # Next make sure that the reference bowtie files exist
        if(!File.exists?("#{@genbConf.clusterBowtieDir}/#{@refGenome}"))
          @errUserMsg = "The reference bowtie directory for genome: #{@refGenome} could not be found since this genome is not supported currently.\nPlease contact the Genboree Administrator for adding support for this genome. "
          raise @errUserMsg
        end
        # Run the tool. We use tophat 2 now, via a module load in the .pbs file. The command name is the same: "tophat"
        @outFile = "./tophat.out"
        @errFile = "./tophat.err"
        command = "tophat -p #{@numCores} -o #{@scratchDir} -G #{@genbConf.clusterGTFDir}/#{@refGenome}/refGene.gtf "
        command << " -r #{@mateInnerDist} --mate-std-dev #{@mateStdev} -a #{@minAnchorLength} -m #{@spliceMisMatches} -i #{@minIntronLength} -I #{@maxInsertionLength}"
        command << " --max-insertion-length #{@maxInsertionLength} --max-deletion-length #{@maxDeletionLength}"
        # Removed from tophat 2.0, will cause tophat crash:
        #command << " --butterfly-search " if(@butterflySearch)
        if(@coverageSearch)
          command << " --coverage-search --min-coverage-intron #{@minCoverageIntron} --max-coverage-intron #{@maxCoverageIntron}"
        else
          command << " --no-coverage-search "
        end
        # Removed from tophat 2.0, will cause tophat crash:
        #if(@closureSearch)
        #  command << " --closure-search --min-closure-exon #{@minClosureExon} --min-closure-intron #{@minClosureIntron} --max-closure-intron #{@maxClosureIntron} "
        #else
        #  command << " --no-closure-search "
        #end
        command << " #{ENV['BOWTIE_INDEX_ROOT']}/#{@refGenome}/#{@refGenome} #{@inputFile1} #{@inputFile2} "
        command << " > #{@outFile} 2> #{@errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
        exitStatus = system(command)
        if(!exitStatus)
          @errUserMsg = "tophat failed to run"
          raise "Command: #{command} died. Check ./tophat.out and ./tophat.err for more information."
        end
        # Next convert BAM to bed
        @bedFile = "out.bed"
        command = "convertSamToBed.v20.rb  -B accepted_hits.bam -o #{@bedFile} --addScoreField"
        @outFile = "./convertSamToBed.out"
        @errFile = "./convertSamToBed.err"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
        exitStatus = system(command)
        if(!exitStatus)
          @errUserMsg = "Could not convert bam file to bed."
          raise "Command: #{command} died. Check #{@outFile} and #{@errFile} for more information. "
        end
        # Rename the bam file
        Dir.entries(@scratchDir).each { |file|
          if(file =~ /\.bam/)
            `mv #{file} #{@outputBamFile}`
          end
        }
        # Convert the bed file into wig
        createWig()
        uploadWig() if(@doUploadResults)
        transferFiles()
        # Finally, nuke the 2 files: bam and wig and compress the bed file (since its not copied over to the server)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing accepted_hits.bam and #{@outputWigFile}. Compressing out.bed")
        `rm -f #{@outputBamFile} #{@outputWigFile} #{@inputFile1} #{@inputFile2} t12.sam; gzip out.bed`
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

    def autoDetermineMateInnerDist()
      # First make sure that the reference file exists
      if(!File.exists?("#{@genbConf.clusterBWADir}/#{@refGenome}/refMrna.fa"))
        @errUserMsg = "The reference file: refMrna.fa for genome: #{@refGenome} could not be found since this genome is not supported currently.\nPlease contact the Genboree Administrator for adding support for this genome. "
        raise @errUserMsg
      end
      # Make tmp files for each of the input with the first 1000000 line
      tmpFile1 = "t1.#{File.basename(@inputFile1)}"
      tmpFile2 = "t2.#{File.basename(@inputFile2)}"
      command = "cat #{@inputFile1} | head -1000000 | gzip -c > #{tmpFile1}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running command: #{command}")
      `#{command}`
      command = "cat #{@inputFile2} | head -1000000 | gzip -c > #{tmpFile2}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running command: #{command}")
      `#{command}`
      # Align to mrna Ref
      command = "bwa aln -t 7 #{@genbConf.clusterBWADir}/#{@refGenome}/refMrna.fa #{tmpFile1} > #{@inputFile1}.aln"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running command: #{command}")
      tt = Time.now
      `#{command}`
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Time taken: #{Time.now - tt}")
      command = "bwa aln -t 7 #{@genbConf.clusterBWADir}/#{@refGenome}/refMrna.fa #{tmpFile2} > #{@inputFile2}.aln"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running command: #{command}")
      tt = Time.now
      `#{command}`
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Time taken: #{Time.now - tt}")
      command = "bwa sampe -s #{@genbConf.clusterBWADir}/#{@refGenome}/refMrna.fa #{@inputFile1}.aln #{@inputFile2}.aln #{tmpFile1} #{tmpFile2} > t12.sam 2> bwa.err"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running command: #{command}")
      tt = Time.now
      `#{command}`
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Time taken: #{Time.now - tt}")
      # Parse the stderr for mean
      ff = File.open('bwa.err')
      ff.each_line { |line|
        line.strip!
        next if(line.nil? or line.empty?)
        if(line =~ /inferred external isize/)
          range = line.split(":")[1]
          @mateInnerDist = range.split("+/-")[0].strip
          @mateInnerDist = @mateInnerDist.to_i
          @mateStdev = range.split("+/-")[1].strip
          @mateStdev = @mateStdev.to_i
          break
        end
      }
      ff.close()
      if(!@mateInnerDist)
        #@errUserMsg = File.read('bwa.err')
        @errUserMsg = "FATAL ERROR: bwa failed. Could not compute --mate-inner-dist required to run tophat.\n\n"
        @errUserMsg << "Possible ways to avoid bwa failure:\n"
        @errUserMsg << "* Ensure that the input files: #{File.basename(@inputFile1)}, #{File.basename(@inputFile2)} are fastq.\n"
        @errUserMsg << "* Ensure that the files are complete and not truncated.\n"
        raise 'Could not compute -r (--mate-inner-dist) for tophat using bwa'
      end
      `rm -f #{tmpFile1} #{tmpFile2} #{@inputFile1}.aln #{@inputFile2}.aln `
    end

    def transferFiles()
      # Grab target URI for outputs
      targetUri = URI.parse(@outputs[0])
      # :analysisName => @analysisName
      # Find resource path by tacking onto the end of target URI the particular portion related to these Tophat files
      rsrcPath = "#{targetUri.path}/file/TopHat/{analysisName}/{outputFile}/data?"
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      # outputWigFile
      # :outputFile => @outputWigFile
      # input is @outputWigFile
      uploadFile(targetUri.host, rsrcPath, @userId, @outputWigFile, {:analysisName => @analysisName, :outputFile => @outputWigFile})
      # outputBamFile
      # :outputFile => @outputBamFile
      # input is @outputBamFile
      uploadFile(targetUri.host, rsrcPath, @userId, @outputBamFile, {:analysisName => @analysisName, :outputFile => @outputBamFile})
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
      uploadAnnosObj.trackName = CGI.unescape(@trackName)
      uploadAnnosObj.outputs = @outputs
      begin
        uploadAnnosObj.uploadWig(CGI.escape(File.expand_path(@outputWigFile)), false)
        `gunzip out.wig.gz` # Because the wig importer would have compressed the file
      rescue => uploadErr
        $stderr.puts "Error: #{uploadErr}"
        $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
        @errUserMsg = "FATAL ERROR: Could not upload result wig file to target database."
        if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
          @errUserMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
        end
        raise @errUserMsg
      end
    end

    def createWig()
      # Call the coverage tool that creates a wig file
      @outFile = "./coverage.out"
      @errFile = "./coverage.err"
      command = "coverage.rb -i #{@bedFile} -f bed -o #{@outputWigFile} -t #{@trackName} > #{@outFile} 2> #{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running command: #{command}")
      exitStatus = system(command)
      if(!exitStatus)
        @errUserMsg = "Could not convert bed to wig."
        raise "Command Died: #{command}. Check #{@outFile} and #{@errFile} for more information. "
      end
    end

    def downloadFiles()
      fileCount = 0
      @inputs.each { |input|
        fileBase = @fileApiHelper.extractName(input)
        tmpFile = "#{@scratchDir}/#{CGI.escape(fileBase)}"
        ww = File.open(tmpFile, "w")
        inputUri = URI.parse(input)
        rsrcPath = "#{inputUri.path}/data?"
        rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(input)}" if(@dbApiHelper.extractGbKey(input))
        apiCaller = WrapperApiCaller.new(inputUri.host, rsrcPath, @userId)
        apiCaller.get() { |chunk| ww.print(chunk) }
        ww.close()
        if(!apiCaller.succeeded?)
          @errUserMsg = "Failed to download file: #{fileBase} from server"
          raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
        end
        exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
        exp.extract()
        if(fileCount == 0)
          @inputFile1 = exp.uncompressedFileName
        else
          @inputFile2 = exp.uncompressedFileName
        end
        # Convert to unix format
        convObj = BRL::Util::ConvertText.new(exp.uncompressedFileName, true)
        convObj.convertText()
        fileCount += 1
      }
    end

    def prepSuccessEmail()
      additionalInfo = ""
      additionalInfo << "You can download result files from this location:\n" + 
                          "|-Group: '#{@groupName}'\n" +
                            "|--Database: '#{@dbName}'\n" +
                              "|---Files\n" +
                                "|----TopHat\n"+
                                  "|-----#{@analysisName}\n\n"
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      return successEmailObject
    end


    def prepErrorEmail()
      additionalInfo = @errUserMsg
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      return errorEmailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::TophatWrapper)
end
