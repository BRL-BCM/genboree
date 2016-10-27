#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/expander'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class MacsWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the 'MACS' tool.
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
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @toolScriptPrefix = @context['toolScriptPrefix']

        @dbu = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil, nil)
        @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @userId)

        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        # Set up format options coming from the UI
        @analysisName = @settings['analysisName']
        @resultsName = CGI.escape(@settings['resultsName'])
        @doUploadResults = @settings['doUploadResults']
        @refGenome = @settings['refGenome']
        @format = @settings['format']
        @macsVersion = @settings['macsVersion']
        if(@doUploadResults)
          @lffType = @settings['lffType'].strip
          @lffSubType = @settings['lffSubType'].strip
          @trackName = CGI.escape("#{@lffType}:#{@lffSubType}")
          @outputLffFile = "#{@trackName}.lff"
        else
          @lffType = "ChIP-Seq"
          @lffSubType = "tags"
          @trackName = CGI.escape("#{@lffType}:#{@lffSubType}")
          @outputLffFile = "#{@trackName}.lff"
        end
        @pValue = @settings['pValue']
        @mFold = @settings['mFold'].strip
        @noLambda = @settings['noLambda']
        if(!@noLambda)
          @slocal = @settings['slocal']
          @llocal = @settings['llocal']
        end
        @offAuto = @settings['offAuto']
        @noModel = @settings['noModel']
        if(@noModel)
          @ssize = @settings['ssize']
        end
        @typeHash = {}
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
        @fileList = [
                          "#{@resultsName}_model.r",
                          "#{@resultsName}_negative_peaks.xls",
                          "#{@resultsName}_peaks.bed",
                          "#{@resultsName}_peaks.xls",
                          "#{@resultsName}_summits.bed",
                          @outputLffFile
                    ]
        @geneIntersectInfo = ""
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
        downloadFiles()

        # Run MACS
        @outFile = "./macs.out"
        @errFile = "./macs.err"
        command = "module load MACS/#{@macsVersion}; macs"
        command << "2 callpeak " if(@macsVersion == '2')
        @typeHash.each_key { |key|
          if(@typeHash[key] == "treatment")
            command << " -t #{key} "
          else
            command << " -c #{key} "
          end
        }
        command << " -n #{@resultsName} -p #{@pValue} "
        if(@macsVersion == '2')
          command << " -m #{@mFold} "
        else
          command << "-m #{@mFold.gsub(' ', ',')} "
        end
        if(@noLambda)
          command << " --nolambda "
        else
          command << " --slocal=#{@slocal} --llocal=#{@llocal} "
        end
        if(@offAuto)
          command << " --off-auto "
        end
        if(@noModel)
          command << "--nomodel --shiftsize=#{@ssize} "
        end
        command << " > #{@outFile} 2> #{@errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
        exitStatus = system(command)
        if(!exitStatus)
          @exitCode = 25
          @macsErrPath = @errFile.dup()
          uriObj = URI.parse(@outputs[0]) # a database URL
          errName = [@jobId, File.basename(@macsErrPath)].join("-")
          @macsErrUrl = "http://#{uriObj.host}#{uriObj.path}/file/MACS/#{CGI.escape(@analysisName)}/#{CGI.escape(errName)}"
          @errInternalMsg = @errUserMsg = "MACS failed to run."
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          raise @err
        end

        # Next create a lff file from the {@resultsName}.xls file
        @outFile = "./convertMACS2PeaksToLff.out"
        @errFile = "./convertMACS2PeaksToLff.err"
        convertScript = "convertMACS2PeaksToLffScript.rb"
        command = "#{convertScript} --inputFile=#{CGI.escape(@resultsName)}_peaks.xls --outputFile=#{CGI.escape(@outputLffFile)} --track=#{@trackName} --class=MACS --avp=#{CGI.escape("resultsName=#{@resultsName}")}"
        command << " > #{@outFile} 2> #{@errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
        exitStatus = system(command)
        if(!exitStatus)
          @exitCode = 26
          @errInternalMsg = @errUserMsg = "Could not convert xls to lff."
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          raise @err
        end

        @transferFileList = []
        performGenicIntersections()
        uploadLff() if(@doUploadResults)
        # Zip all files except the {@resultsName}.xls file
        @fileList.each { |file|
          if(File.exists?(file))
            if(file != "#{@resultsName}_peaks.xls")
              `zip #{file}.zip #{file}`
              @transferFileList.push("#{file}.zip")
            else
              @transferFileList.push(file)
            end
          end
        }

        transferFiles()
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing files: #{@inputFile1}, #{@inputFile2} and #{@outputLffFile}")
        `rm -f #{@inputFile1} #{@inputFile2} #{@outputLffFile}`
      rescue => err
        if(@exitCode == EXIT_OK)
          @err = err
          @errInternalMsg = @errUserMsg = "An unrecognized error occurred while running MACS"
          @exitCode = 30
        end
      end
      return @exitCode
    end

    def uploadLff()
      # Get the refseqid of the target database
      outputUri = URI.parse(@outputs[0])
      rsrcUri = outputUri.path
      rsrcUri << "?gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      apiCaller = WrapperApiCaller.new(outputUri.host, rsrcUri, @userId)
      apiCaller.get()
      if(apiCaller.succeeded?)
        resp = JSON.parse(apiCaller.respBody)
        uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
        uploadAnnosObj.refSeqId = resp['data']['refSeqId']
        uploadAnnosObj.groupName = @groupName
        uploadAnnosObj.userId = @userId
        begin
          uploadAnnosObj.uploadLff(CGI.escape(File.expand_path(@outputLffFile)), false)
        rescue => uploadErr
          @exitCode = 27
          @errUserMsg = "Could not upload result lff file to target database."
          if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
            @errUserMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
          end
          @errInternalMsg = @errUserMsg
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          # propagate error to run()
          raise @err
        end
      else
        @exitCode = 28
        @errInternalMsg = @errUserMsg = "FATAL ERROR: Could not get info about target database from Genboree host. Can't upload annotations to target database."
        @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
        raise @err
      end
    end

    def downloadFiles()
      fileCount = 0
      @inputs.each { |input|
        fileBase = @fileApiHelper.extractName(input)
        tmpFile = "file_#{fileCount}_#{CGI.escape(fileBase)}"
        respFilePath = @fileApiHelper.downloadFile(input, @userId, tmpFile)
        unless(respFilePath)
          @exitCode = 29
          @errInternalMsg = @errUserMsg = "Failed to download file: #{fileBase} from server"
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          raise @err
        end
        extract = true
        if(@inputs.size == 1)
          if(@format == 'bam')
            extract = false
          end
        else
          if(@settings["fileOptsRecs|0|format_#{input}"])
            extract = false if(@settings["fileOptsRecs|0|format_#{input}"] == 'bam')
          elsif(@settings["fileOptsRecs|1|format_#{input}"])
            extract = false if(@settings["fileOptsRecs|1|format_#{input}"] == 'bam')
          else
            # No-op
          end
        end
        if(extract)
          exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
          exp.extract()
          if(exp.uncompressedFileList and !exp.uncompressedFileList.empty?)
            if(fileCount == 0)
              @inputFile1 = exp.uncompressedFileList.first
                @settings.each_key { |setting|
                if(setting =~ /tc_#{input}/)
                  @typeHash[@inputFile1] = @settings[setting]
                end
              }
            else
              @inputFile2 = exp.uncompressedFileList.first
              @settings.each_key { |setting|
                if(setting =~ /tc_#{input}/)
                  @typeHash[@inputFile2] = @settings[setting]
                end
              }
            end
          end
        else
          if(fileCount == 0)
            @inputFile1 = tmpFile
            @settings.each_key { |setting|
              if(setting =~ /tc_#{input}/)
                @typeHash[@inputFile1] = @settings[setting]
              end
            }
          else
            @inputFile2 = tmpFile
            @settings.each_key { |setting|
              if(setting =~ /tc_#{input}/)
                @typeHash[@inputFile2] = @settings[setting]
              end
            }
          end
        end
        fileCount += 1
      }
    end

    def countOvlpPeaks(file1,file2)
      peakCount = `module load BEDTools/2.14;intersectBed -u -a #{file1} -b #{file2}|wc -l`
      return peakCount.chomp
    end

    def writeNonOvlpPeaks(file1,file2, fileName)
      `module load BEDTools/2.14;intersectBed -v -a #{file1} -b #{file2} > #{fileName}`
    end

    def makeTSSRangeFromBed(ifileName, ofileName, range=3000)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "in range")
      ifh=File.open(ifileName, "r")
      ofh=File.open(ofileName, "w")
      ifh.each_line{|line|
        line.chomp!
        if(line =~ /^#/) then
          ofh.puts line
        else
          sl = line.split(/\t/)
          sl[1] = [sl[2].to_i - range,1].max
          sl[2] = [sl[2].to_i + range,@chrHash[sl[0]]].min
          ofh.puts sl.join("\t")
        end
        }
      ofh.close
      ifh.close
    end

    def downloadTrackAsBed(host, dbPath, track, fileName)
      retVal = nil
      begin
        # assume scheme is http
        scheme = "http"
        uri = "#{scheme}://#{host}#{dbPath}/trk/#{CGI.escape(track)}"
        uriParams = {"ucscTrackHeader" => "false"}
        respFilePath = @trkApiHelper.getDataFileForTrack(uri, "bed", "rawdata", nil, fileName, @userId, hostAuthMap=nil,
                                                         emptyScoreValue=nil, noOfAttempts=10, uriParams, regionsParams=nil)
        unless(respFilePath)
          @exitCode = 23
          @errInternalMsg = @errUserMsg = "Failed to download track #{track} on #{host} from #{dbPath}"
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          raise @err
        else
          # make sure the downloaded file is uncompressed first
          if(@trkApiHelper.staticFile)
            expObj = BRL::Util::Expander.new(respFilePath)
            success = expObj.extract()
            if(success)
              retVal = expObj.uncompressedFileName
            else
              retVal = nil
            end
          else
            retVal = respFilePath
          end
        end
      rescue => err
        if(@exitCode == EXIT_OK)
          @err = err
          @errInternalMsg = @errUserMsg = "ERROR: Could not download track as bed. "
          @exitCode = 24
        end
        # propagate error up to run()
        raise @err
      end
    end

    def performGenicIntersections
      begin
        roiDBTemplate = "http://genboree.org/REST/v1/grp/ROI%20Repository/db/ROI%20Repository%20-%20{VER}"
        roiDBURI = roiDBTemplate.gsub(/\{VER\}/,@refGenome)
        roiDBHost = @dbApiHelper.extractHost(roiDBURI)
        roiDBPath = @dbApiHelper.extractPath(roiDBURI)
        @chrHash = {}
        apiCaller = WrapperApiCaller.new(roiDBHost, roiDBPath, @userId)
        apiCaller.get()
        if(apiCaller.succeeded?) then
          apiCaller2 = WrapperApiCaller.new(roiDBHost, "#{roiDBPath}/eps", @userId)
          apiCaller2.get
          if(apiCaller2.succeeded?) then
            apiCaller2.parseRespBody()
            apiCaller2.apiDataObj["entrypoints"].each{|ii| @chrHash[ii["name"]] = ii["length"].to_i}
          else
            @exitCode = 31
            @errInternalMsg = @errUserMsg = "Unable to download entry points for #{@refGenome} from db #{@dbApiHelper.extractName(roiDBURI)} on #{roiDBHost} at #{roiDBPath}"
            @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
            raise @err
          end
          macsBedFilePath = File.join(@scratchDir, "#{@resultsName}_peaks.bed")
          macsPeakCount = `wc -l #{macsBedFilePath} | cut -f 1 -d " "`.chomp
          macsPeakCount = macsPeakCount.chomp.to_i
          # Assume if GeneModel:TSS exists, all other GeneModel tracks also exist
          apiCaller3 = WrapperApiCaller.new(roiDBHost, "#{roiDBPath}/trk/#{CGI.escape("GeneModel:TSS")}?detailed=false&connect=no", @userId)
          apiCaller3.get()
          if(apiCaller3.succeeded?) then
            # calculate tss peak count
            tssBedFilePath = File.join(@scratchDir, "#{@resultsName}_tss.bed")
            tssBedFilePath = downloadTrackAsBed(roiDBHost, roiDBPath, "GeneModel:TSS", tssBedFilePath)
            tssRangeFilePath = File.join(@scratchDir, "#{@resultsName}_tss_range.bed")
            makeTSSRangeFromBed(tssBedFilePath, tssRangeFilePath)
            nonTssFilePath = File.join(@scratchDir, "#{@resultsName}_nontss.bed")
            tssPeakCount = countOvlpPeaks(macsBedFilePath, tssRangeFilePath)
            writeNonOvlpPeaks(macsBedFilePath, tssRangeFilePath, nonTssFilePath)
  
            # calculate exon peak count
            exonFilePath = File.join(@scratchDir, "#{@resultsName}_exon.bed")
            exonFilePath = downloadTrackAsBed(roiDBHost, roiDBPath, "GeneModel:Exon", exonFilePath)
            nonExonFilePath = File.join(@scratchDir, "#{@resultsName}_nonexon.bed")
            exonPeakCount = countOvlpPeaks(nonTssFilePath, exonFilePath)
            writeNonOvlpPeaks(nonTssFilePath, exonFilePath, nonExonFilePath)

            # calculate intron peak count
            intronFilePath = File.join(@scratchDir, "#{@resultsName}_intron.bed")
            intronFilePath = downloadTrackAsBed(roiDBHost, roiDBPath, "GeneModel:Intron", intronFilePath)
            intronPeakCount = countOvlpPeaks(nonExonFilePath, intronFilePath)

            # calculate integenic peak count
            intergenicFilePath = File.join(@scratchDir, "#{@resultsName}_intergenic.bed")
            writeNonOvlpPeaks(nonExonFilePath, intronFilePath, intergenicFilePath)
            intergenicPeakCount = `wc -l #{intergenicFilePath} | cut -f 1 -d " "`.chomp

            msgBuffer = StringIO.new
            msgBuffer << "MACS called #{macsPeakCount} peaks. The breakdown of the peaks with respect to the gene model follows:\n"
            msgBuffer << "Gene TSS +- 3K Peaks\t#{tssPeakCount}\t#{((tssPeakCount.to_f/macsPeakCount)*10000).to_i/100.0}%\n"
            msgBuffer << "Gene Exon Peaks\t#{exonPeakCount}\t#{((exonPeakCount.to_f/macsPeakCount)*10000).to_i/100.0}%\n"
            msgBuffer << "Gene Intron Peaks\t#{intronPeakCount}\t#{((intronPeakCount.to_f/macsPeakCount)*10000).to_i/100.0}%\n"
            msgBuffer << "Intergenic Peaks\t#{intergenicPeakCount}\t#{((intergenicPeakCount.to_f/macsPeakCount)*10000).to_i/100.0}%\n"
            @geneIntersectInfo = msgBuffer.string
            sfh = File.open("summary.txt","w")
            sfh.puts(@geneIntersectInfo)
            sfh.close
            @transferFileList << "summary.txt"
            $stderr.debugPuts(__FILE__, __method__, "STATUS", @geneIntersectInfo)
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "#{apiCaller3.rsrcPath} failed")
          @geneIntersectInfo = "Database #{@dbApiHelper.extractName(roiDBURI)} on #{roiDBHost} at does not contain a GeneModel:TSS track. Skipping genic intersections"
          end
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "#{apiCaller.rsrcPath} failed")
          @geneIntersectInfo = "Database #{@dbApiHelper.extractName(roiDBURI)} does not exist on #{roiDBHost} at #{@dbApiHelper.extractPath(roiDBURI)}. Skipping genic intersections"
        end
        @exitCode = 0
      rescue => err
        if(@exitCode == EXIT_OK)
          @err = err
          @errInternalMsg = @errUserMsg = "ERROR: Could not perform genic intersections. "
          @exitCode = 22
        end
        # propogate error up to run()
      end
      return @exitCode
    end

    def transferFiles()
      targetUri = URI.parse(@outputs[0])
      @transferFileList.each { |file|
        rsrcUri = nil
        if(file == "#{@resultsName}_peaks.xls" or file =~ /\.lff/)
          rsrcUri = "#{targetUri.path}/file/MACS/#{CGI.escape(@analysisName)}/#{file}/data?"
        else
          rsrcUri = "#{targetUri.path}/file/MACS/#{CGI.escape(@analysisName)}/raw/#{file}/data?"
        end
        rsrcUri << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
        apiCaller = WrapperApiCaller.new(targetUri.host, rsrcUri, @userId)
        apiCaller.put({}, File.open(file))
      }
    end


    def prepSuccessEmail()
      additionalInfo = ""
      additionalInfo << "  Database: '#{@dbName}'\n  Group: '#{@groupName}'\n\n" +
                        "You can download result files from the '#{@analysisName}' folder under the 'MACS' directory.\n"
      additionalInfo << "\n\n\n"
      additionalInfo << @geneIntersectInfo
      additionalInfo << "\n"
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return successEmailObject
    end


    def prepErrorEmail()
      additionalInfo = ""
      if(@exitCode == 25)
        # then the error is from the "macs" command failing
        additionalInfo = reportToolError(@macsErrPath, @macsErrUrl)
      else
        additionalInfo = "  Error message from MACS:\n#{@errUserMsg}"
      end
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      errorEmailObject.exitStatusCode = @exitCode.to_s
      return errorEmailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::MacsWrapper)
end
