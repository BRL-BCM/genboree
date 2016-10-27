#!/usr/bin/env ruby
require 'cgi'
require 'json'
require 'pathname'
require 'brl/util/util'
require 'brl/genboree/rest/wrapperApiCaller'
# Require toolWrapper.rb
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/trackEntityListApiUriHelper'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
include BRL::Genboree::REST
#load '/cluster.shared/local_test/lib/ruby/site_ruby/1.8/brl/genboree/rest/helpers/apiUriHelper.rb'
# Write sub-class of BRL::Genboree::Tools::ToolWrapper
module BRL ; module Genboree; module Tools
  class WrapperLimmaSignalComparison < ToolWrapper

    VERSION = "1.0"

    DESC_AND_EXAMPLES = {
      :description => "Wrapper to run tool, which runs limma on epigenome data",
      :authors      => [ "Arpit Tandon" ],
      :examples => [
        "#{File.basename(__FILE__)} --jsonFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    # run()
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . optsHash contains the command-line args, keyed by --longName
    def run()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running Driver .....")
        exitStatus = EXIT_OK
        @errMsg = ""
        apiUriHelper = BRL::Genboree::REST::Helpers::ApiUriHelper.new()
        @entityLists = []
        roiTrack = nil
        @inputs.each{|input|
          inpType = apiUriHelper.extractType(input)
          if(inpType == "entityList") then
            @entityLists << input
          elsif(inpType == "trk") then
            @roiTrack = input
          end
        }
        
        @matrixSizeErrorMsg = <<-END
        ERROR: Final Data Matrix is too small.
        
        The final input to the Limma package is a matrix with your tracks as columns and different ROI regions as the rows. Each cell contains the score of a track (column) for the ROI region (row).
        Only the ROI regions that meet your 'NA' handling criteria (if any) are included in this matrix. There must be at least #{@minMatrixRows} ROI regions (rows) in the final matrix. Your matrix has an insufficient number of rows.
        
        You can fix this by:
        1. Using a different ROI track. Your current ROI track may have too few regions to begin with.
        2. Consider relaxing your \"NA\" handling criteria. In the tool's Help Dialog, please refer to the section dealing with this (Tool-Specific Settings > No Data Regions (Advanced)) and the addendum.
        END
        @numSets = @entityLists.length
        @allTracks = []
        system("mkdir -p #{@scratch}/matrix")
        system("mkdir -p #{@scratch}/trksDownload")
        system("mkdir -p #{@scratch}/logs")
        if(File.exists?("#{@scratch}/matrix") and File.exists?("#{@scratch}/trksDownload") and  File.exists?("#{@scratch}/logs")) then
          exitStatus = buildHashofVectorEntity()
          if(exitStatus != EXIT_OK) then
            if(@errMsg.nil? or @errMsg.empty?) then @errMsg = "Some of the tracks are either removed or not accessible by user" end
            $stderr.debugPuts(__FILE__, __method__, "ERROR",@errMsg)
            exitStatus = 120
          else
            if(checkMatrixSize(@roiTrack,@allTracks.length,@matrixSizeLimit)) then
              exitStatus = buildMatrix(@roiTrack,@allTracks,"matrix.txt")
              if(exitStatus != EXIT_OK) then
                if(exitStatus == 120) then
                  @errMsg = @matrixSizeErrorMsg
                else
                  @errMsg = "Matrix couldn't be built"
                end
                $stderr.debugPuts(__FILE__, __method__, "ERROR",@errMsg)
                exitStatus = 113
              else
                $stderr.debugPuts(__FILE__, __method__, "Done","Matrix is created")
                buildMetadata()
                $stderr.debugPuts(__FILE__, __method__, "Done","Metadata file created")
                exitStatus = runLimma()
                if(exitStatus != EXIT_OK) then
                  @errMsg = "Limma tool didn't run successfully.\nError messages from Limma follow:\n\n"
                  @errMsg += "\"\n#{File.read("#{@scratch}/logs/limma.error.log")}\n\""
                  $stderr.debugPuts(__FILE__, __method__, "ERROR", @errMsg)
                  exitStatus = 114
                else
                  if(@uploadTrack) then makeLFFResults end
                  compressRawOutput()
                  uploadStatus = uploadResults()
                  if (uploadStatus!=EXIT_OK) then
                    @errMsg = "Result data upload failed"
                    $stderr.debugPuts(__FILE__, __method__, "ERROR", @errMsg)
                    exitStatus = 118
                  else
                    exitStatus=EXIT_OK
                  end
                end
              end
            else
              $stderr.debugPuts(__FILE__, __method__, "Error", "Matrix size exceeds maximum limit")
              exitStatus = 120
            end
          end
        else
          @errMsg = "Dir generation failed"
          $stderr.debugPuts(__FILE__, __method__, "Status", @errMsg)
          exitStatus = 119
        end
      rescue => err
        @errMsg = err.message
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 121
      ensure
        @exitCode = exitStatus
        return exitStatus
      end
    end


    ##Download entityList
    ##And verify all the tracks are accessible
    def buildHashofVectorEntity()
      exitCode = 0
      begin
        @trkSetHashes = []
        @setNames = []

        @entityLists.each{|trackSet|
          uri = URI.parse(trackSet)
          tmpPath = "#{uri.path.chomp('?')}/data?"
          tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(trackSet)}" if(@dbApiHelper.extractGbKey(trackSet))
          @apiCaller.setHost(uri.host)
          @apiCaller.setRsrcPath(tmpPath)
          @apiCaller.get()
          if @apiCaller.succeeded?
            $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "TrackSet #{trackSet} downloaded successfully")
          else
            $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool- ERROR", @apiCaller.respBody.inspect)
            exitCode = @apiCaller.apiStatusObj['statusCode']
            raise "Error downloading trackSet #{trackSet}"
          end
          @apiCaller.parseRespBody
          # Limma has issues with several chars in variable names. So only retain letters and numbers
          setName = @trackListHelper.extractName(trackSet).gsub(/[:|\s|_]/,".")
          # Limma has issues with variable name starting with a number
          @setNames << setName.gsub(/\W/,"").gsub(/^\d/,"X")
          tempHash = {}
          @apiCaller.apiDataObj.each { |obj|
            tempHash[obj['url']] = setName
          }
          if(tempHash.keys.length < @minNumTracks)
            @errMsg = "Unable to use track entity list #{@trackListHelper.extractName(trackSet)}.\nEach track entity list must contain a minimum of 2 tracks for this limma tool to run successfully."
            raise @errMsg
          else
            @trkSetHashes << tempHash
          end
        }

        @trkSetHashes.each{|trkSetHash|
          @allTracks += trkSetHash.keys
        }
        ## Checking if THE TRACKS in entitylist EXIST and are ACCESSIBLE by the user
        exitStatus = tracksAccessible?(@allTracks) ? EXIT_OK : 120
      rescue=> err
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 120
      end
      return exitStatus
    end

    def checkMatrixSize(roiTrack,numSamples,limit)
      roiUri = URI.parse(roiTrack)
      rsrcPath = "#{roiUri.path}/annos/count?"
      rsrcPath << "&gbKey=#{@dbApiHelper.extractGbKey(roiTrack)}" if(@dbApiHelper.extractGbKey(roiTrack))
      @apiCaller.setHost(roiUri.host)
      @apiCaller.setRsrcPath(rsrcPath)
      @apiCaller.get()
      if(@apiCaller.succeeded?) then
        @apiCaller.parseRespBody()
        roiCount = @apiCaller.apiDataObj["count"].to_i
        if(roiCount < @minMatrixRows) then
          @errMsg = @matrixSizeErrorMsg
        else
          matrixSize =  roiCount* numSamples
          if(matrixSize > @maxMatrixEntries) then
            @errMsg = "Unfortunately, the size of your data set is too large to analyze with LIMMA."+
            "\n- Your ROI track has #{roiCount.commify} annotations."+
            "\n- You have #{numSamples.commify} samples (tracks)."+
            "\nThis is a total of #{matrixSize.commify} datapoints."+
            "\nDue to memory constraints, we cannot accept LIMMA analysis jobs with more than #{@maxMatrixEntries.commify} total data points."
            return false
          else
            return true
          end
        end
      else
        errMsg = "Error determining roi track annotation count\nROI Track:#{roiTrack.inspect}"
        $stderr.debugPuts(__FILE__, __method__, "Error", errMsg)
        $stderr.debugPuts(__FILE__, __method__, "Error ", @apiCaller.respBody.inspect)
        raise errMsg
      end
    end


    def buildMatrix(roiTrack,trackList,matrixFileName)
      begin
        # download tracks
        trackList.each{|track|
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "downloading track=#{track.inspect}")
          trackName = @trkApiHelper.extractName(track)
          outFilePath = "#{@scratch}/trksDownload/#{CGI.escape(trackName)}"
          respFilePath = @trkApiHelper.getDataFileForTrack(track, "bed", "avg", roiTrack, outFilePath, @userId, hostAuthMap=nil, 
                                                           emptyScoreValue="NA", noOfAttempts=10, uriParams=nil, regionsParams=nil)
          unless(respFilePath)
            # then the file was not downloaded successfully
            errMsg = "Error downloading track #{trackName}"
            $stderr.debugPuts(__FILE__, __method__, "Build Matrix - Error ", errMsg)
            raise errMsg
          end
        }

        fileHandles = []
        coordsHash = Hash.new(0)
        matrixFile = File.open("#{@scratch}/matrix/#{matrixFileName}","w")
        trackList.each{|track|
          trackName = @trkApiHelper.extractName(track)
          fileHandles << File.open("#{@scratch}/trksDownload/#{CGI.escape(trackName)}","r")
          matrixFile.print("\t#{trackName.gsub(/[:| ]/,'.')}")
        }
        matrixFile.print("\n")
        numTracks = fileHandles.length
        coordsHash = {}
        numCoords = 0
        labelFile = File.open("#{@scratch}/matrix/roiLabels.txt","w")
        fileHandles.each{|fh| fh.readline()}
        while(!fileHandles[0].eof?)
          validLine = false
          invalidScore = false
          label = nil
          coordinates = nil
          scoreBuff = nil
          naCount = 0
          fileHandles.each{|fh|
            sl=fh.readline().chomp.split(/\t/)
            if(sl[4]== "NA") then
              naCount += 1
              sl[4] = @replaceNAValue
            end
            if(scoreBuff.nil?) then scoreBuff = StringIO.new end
            if(coordinates.nil?) then
              coordinates = "#{sl[0]}_#{sl[1]}_#{sl[2]}"
              label = "#{coordinates}.#{sl[3]}"
              scoreBuff << label
            end
            scoreBuff << "\t#{sl[4]}"
            
          }
          invalidScore = (@removeNoData and checkInvalid(naCount,numTracks,@naProportion))
          if(!invalidScore and !coordsHash.has_key?(coordinates)) then
            validLine = true
            coordsHash[coordinates] = true
            numCoords += 1
          end
          if(validLine) then
            matrixFile.print scoreBuff.string
            matrixFile.print "\n"
            labelFile.puts label
          end
        end
        if(numCoords >= @minMatrixRows) then
          exitStatus = EXIT_OK
        else
          exitStatus = 120
        end
      rescue => err
        exitStatus = 113
        @errMsg = err.message
        $stderr.puts err.message
        $stderr.puts err.backtrace.join("\n")
      ensure
        fileHandles.each{|fh| fh.close()}
        labelFile.close
        matrixFile.close
        return exitStatus
      end
    end

    ## To ensure AlL THE TRACKS in entitylist EXIST and are ACCESSIBLE by the user
    def tracksAccessible?(tracksArray)
      exitStatus = 0
      begin
        tracksArray.each{|track|
          uri = URI.parse(track)
          host= uri.host
          path = uri.path
          path << "?gbKey=#{@dbApiHelper.extractGbKey(track)}" if(@dbApiHelper.extractGbKey(track))
          @apiCaller.setHost(host)
          @apiCaller.setRsrcPath(path)

          @apiCaller.get
          if(!@apiCaller.succeeded?)
            exitStatus = 120
            $stderr.debugPuts(__FILE__, __method__, "#{File.basename(path)}", @apiCaller.respBody.inspect)
            raise "Error checking accessibility of track #{track}"
            break
          else
            $stderr.debugPuts(__FILE__, __method__, "Track Access", "#{File.basename(path)} is accessible")
          end
        }
      rescue=> err
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 120
      end
      return exitStatus
    end

    def checkInvalid(naCount,numTracks,naProportion)
      return((naCount > 0 and naProportion == 0) or (naCount == numTracks and naProportion == 100) or (naCount!=0 and naCount*100.0/numTracks >= naProportion))
    end

    def buildMetadata()
      classArray = [1]
      (1 .. @numSets -1).each{|ii| classArray << 0}
      fileWrite = File.open("#{@scratch}/matrix/metadata.txt", "w+")
      fileWrite.write "\t#{@setNames.join("\t")}"
      fileWrite.puts
      @trkSetHashes.each{|trkSetHash|
        trkSetHash.each_key{|k|
          kk = @trkApiHelper.extractName(k).gsub(/[:| ]/,'.')
          fileWrite.write "#{kk}\t#{classArray[0 .. @numSets-1].join("\t")}\n"
        }
        classArray.insert(0,0)
      }
      fileWrite.close
    end
    # . Upload files. should be a interface method. Will put it in parent class soon
    def uploadUsingAPI(jobName,fileName,filePath)
      @apiCaller.setHost(@outHost)
      @exitCode = EXIT_OK
      restPath = @outPath
      path = restPath +"/file/Epigenome_Limma/#{CGI.escape(jobName)}/#{fileName}/data"
      encodedOut = @outputs[0]
      path << "?gbKey=#{@dbApiHelper.extractGbKey(encodedOut)}" if(@dbApiHelper.extractGbKey(encodedOut))
      @apiCaller.setRsrcPath(path)
      infile = File.open("#{filePath}","r")
      @apiCaller.put(infile)
      if @apiCaller.succeeded?
        $stderr.debugPuts(__FILE__, __method__, "Upload file", "#{fileName} done")
        @exitCode = EXIT_OK
      else
        @errMsg = "Failed to upload the file #{fileName}"
        $stderr.debugPuts(__FILE__, __method__, "Upload Failure", @apiCaller.respBody.inspect)
        @exitCode = @apiCaller.apiStatusObj['statusCode']
      end
      return @exitCode
    end

    def uploadResults()
      exitStatus = EXIT_OK
      begin
        exitCode = uploadUsingAPI(@analysis,"raw.results.zip","#{@scratch}/matrix/raw.results.zip")
        if(exitCode != EXIT_OK)
          exitStatus = 118
        end
      rescue => err
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 118
      end
      return exitStatus
    end

    def runLimma
      begin
        setString = StringIO.new
        normalizeString = nil
        contrastString = nil
        if(@normalize == "Quantile") then
          normalizeString = "dataMatrixNormalize <- normalize.quantiles(dataMatrix, copy=TRUE)"
        elsif(@normalize == "Percentage")
          normalizeString = "dataMatrix[is.na(dataMatrix)]<-0\ncolSums <- apply(dataMatrix,2,sum)\n"+
          "dataMatrixNormalize <- t(apply(dataMatrix,1,function(x) (x/colSums)*#{@multiplier}))"
        else
          normalizeString = "dataMatrixNormalize <- dataMatrix"
        end

        if(@numSets > 2)
          (0 .. @numSets-2).each{|ii|
            (ii+1 .. @numSets-1).each{|jj|
              setString << " #{@setNames[ii]} - #{@setNames[jj]},"
            }
          }
          contrastString = "makeContrasts(#{setString.string} levels=design)"
        else
          contrastString = "makeContrasts(#{@setNames[0]}Vs#{@setNames[1]} = #{@setNames[0]} - #{@setNames[1]}, levels=design)"
        end
        limmaFileName = "limma.R"
        limmaFile = File.open("#{@scratch}/#{limmaFileName}","w")
        limmaFile.print <<-END
        library(preprocessCore)
        library(limma)
        pathPrefix <- \"#{@scratch}/matrix\"
        dataMatrix <- read.table(paste(pathPrefix,\"/\",\"matrix.txt\",sep=\"\"),check.names=FALSE,header=TRUE,row.names=1)
        design <- read.table(paste(pathPrefix,\"/\",\"metadata.txt\",sep=\"\"))
        dataMatrix <- as.matrix(dataMatrix[,row.names(design)])
        #{normalizeString}
        rownames(dataMatrixNormalize) <- rownames(dataMatrix)
        colnames(dataMatrixNormalize) <- colnames(dataMatrix)
        write.table(dataMatrixNormalize,file=paste(pathPrefix,\"/\",\"normalizedMatrix.txt\",sep=\"\"),quote=FALSE,sep='\\t')
        cont.matrix <- #{contrastString}
        fit <- lmFit(dataMatrixNormalize, design)
        fit2 <- contrasts.fit(fit, cont.matrix)
        fit2 <- eBayes(fit2)
        topResults <- toptable(fit2, adjust.method = \"#{@adjustMethod}\",number="inf")
        row.names(topResults) <- row.names(dataMatrixNormalize)[as.integer(row.names(topResults))]
        write.table(topResults,file=paste(pathPrefix,\"/\",\"topTableNoFilter.txt\",sep=\"\"),col.names=NA,quote=FALSE,sep='\\t')
        topResults<-topResults[which(abs(topResults[,2]) > abs(#{@minFoldCh})),]
        topResults <- topResults[which((topResults[,"P.Value"] < #{@minPval}) & (topResults[,"adj.P.Val"] < #{@minAdjPval})),]
        write.table(topResults,file=paste(pathPrefix,\"/\",\"topTable.txt\",sep=\"\"),quote=FALSE,col.names=NA,sep='\\t')
        results <- decideTests(fit2, method=\"#{@testMethod}\", adjust.method=\"#{@adjustMethod}\", p.value=#{@minAdjPval}, lfc=#{@minFoldCh})
        write.table(results,file=paste(pathPrefix,\"/\",\"decideTests.txt\",sep=\"\"),col.names=NA,quote=FALSE,sep='\\t')
        write.table(summary(results),file=paste(pathPrefix,\"/\",\"decideTestsClassification.txt\",sep=\"\"),quote=FALSE,col.names=NA,sep='\\t')
        END
        limmaFile.close
        system("Rscript --vanilla #{limmaFileName} >#{@scratch}/logs/limma.log 2>#{@scratch}/logs/limma.error.log")
        exitStatus = ($?.success?) ? EXIT_OK : 114
      rescue=> err
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 114
      end
      $stderr.debugPuts(__FILE__, __method__, "Status", "Limma tool completed with #{exitStatus}")
      return exitStatus
    end

    def makeLFFResults
      ifh = File.open("#{@scratch}/matrix/topTable.txt","r")
      ifh.readline
      defScore = 0
      defStrand = '+'
      lffFileName = "topTable.lff"
      recordCount = 0
      topTableEmpty = true
      @additionalInfo = ""
      ofh = File.open("#{@scratch}/matrix/#{lffFileName}","w")
      ifh.each_line{|line|
        sl = line.chomp.split(/\t/)
        locName = sl[0]
        (loc,name) = sl[0].split(/\./)
        (chr,start,stop) = loc.split(/_/)
        ofh.puts "#{@trackClass}\t#{name}\t#{@trackType}\t#{@trackSubType}\t#{chr}\t#{start.to_i+1}\t#{stop}\t#{defStrand}\t.\t#{defScore}"
        topTableEmpty = false
        recordCount += 1
      }
      ofh.close
      if(!topTableEmpty)
        outputUri = URI.parse(@output)
        rsrcPath = outputUri.path
        rsrcPath << "?gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
        @apiCaller.setRsrcPath(rsrcPath)
        @apiCaller.setHost(outputUri.host)
        @apiCaller.get()
        if (@apiCaller.succeeded?) then
          refSeqId = JSON.parse(@apiCaller.respBody)['data']['refSeqId']
          uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
          uploadAnnosObj.refSeqId = refSeqId
          uploadAnnosObj.groupName = @grpOutput
          uploadAnnosObj.userId = @userId
          uploadAnnosObj.outputs = [@output]
          begin
            uploadAnnosObj.uploadLff(CGI.escape(File.expand_path("#{@scratch}/matrix/#{lffFileName}")), false)
            @additionalInfo += "#{recordCount} records remain after filtering. Track #{@trackType}:#{@trackSubType} created in class #{@trackClass}"
          rescue => uploadErr
            $stderr.puts "Error: #{uploadErr}"
            $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
            errMsg = "FATAL ERROR: Could not upload result lff file to target database."
            if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
              errMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
            end
            raise errMsg
          end
        else
          $stderr.debugPuts(__FILE__, __method__, "Track Upload - ERROR", @apiCaller.respBody.inspect)
          errMsg = "Could not obtain refSeqId for #{@output}"
          raise errMsg
        end
      else
        @additionalInfo += "\nNo records remain after filtering. No result track uploaded."
      end
    end

    ##run Limma tool
    def runLimmaOld()
      exitStatus = 0
      $stderr.debugPuts(__FILE__, __method__, "Running", "Running Limma")
      begin
        cmd = "run_limma.rb "
        cmd << " -i #{@scratch}/matrix/matrix.txt -m #{@scratch}/matrix/metadata.txt -o #{@scratch}/matrix -s #{@sortby} -p #{@minPval} -a #{@minAdjPVal} -f #{@minFoldCh}"
        cmd << " -e #{@minAveExp} -b #{@minBval} -T #{@testMethod} -A #{@adjustMethod} -x #{@multiplier} -t #{@printTaxa} -n #{@normalize} -c 'class'"
        cmd << " >#{@scratch}/logs/limma.log 2>#{@scratch}/logs/limma.error.log"

        $stderr.debugPuts(__FILE__, __method__, "Limma tool command ", cmd)
        system(cmd)
        if(!$?.success?)
          exitStatus = 114
        else
          $stderr.debugPuts(__FILE__, __method__, "Done", "Limma Tool")
        end
      rescue=> err
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 114
      end
      $stderr.debugPuts(__FILE__, __method__, "Status", "Limma tool completed with #{exitStatus}")
      return exitStatus
    end

    ## generic archive of output directory, regardless whether LIMMA succeeded or not
    def compressRawOutput()
      Dir.chdir("#{@scratch}/matrix")
      system("zip raw.results.zip  * -x *.xlsx -x matrix.txt -x metadata.txt")
      system("rm -rf #{@scratch}/trksDownload")
      Dir.chdir(@scratch)
    end

    # . Prepare successmail
    def prepSuccessEmail
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @firstName
      emailObject.userLast      = @lastName
      emailObject.analysisName  = @analysis
      inputsText                = buildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      emailObject.additionalInfo = @additionalInfo
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @jobConf['settings']
      emailObject.exitStatusCode = @exitCode
      emailObject.resultFileLocations = "http://#{@outHost}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{CGI.escape("#{@outPath}/file/Epigenome_Limma/#{CGI.escape(@analysis)}/raw.results.zip/data")}"

      return emailObject
    end

    # . Prepare Failure mail
    def prepErrorEmail
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @firstName
      emailObject.userLast      = @lastName
      emailObject.analysisName  = @analysis
      inputsText                = buildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @jobConf['settings']
      emailObject.errMessage    = @errMsg
      emailObject.exitStatusCode = @exitCode
      return emailObject
    end

    # ------------------------------------------------------------------
    # SCRIPT-SPECIFIC METHODS
    # ------------------------------------------------------------------
    # - stuff needed to do actual program or drive 3rd party tools, etc
    # - repeatedly-used generic stuff is in library classes of course...

    def processJobConf()
      begin
        @inputs       = @jobConf['inputs']
        @outputs      = @jobConf['outputs']
        apiUriHelper = BRL::Genboree::REST::Helpers::ApiUriHelper.new()
        if(apiUriHelper.extractType(@outputs[0]) != "db" ) then
          @outputs.reverse!
        end
        @normalize    = @jobConf['settings']['normalize']
        @analysis     = @jobConf['settings']['analysisName']
        @sortby       = @jobConf["settings"]["sortBy"]
        @minPval      = @jobConf["settings"]["minPval"]
        @minAdjPval   = @jobConf["settings"]["minAdjPval"]
        @minFoldCh    = @jobConf["settings"]["minFoldChange"]
        # @minBval      = @jobConf["settings"]["minBval"]
        @testMethod   = @jobConf["settings"]["testMethod"]
        @adjustMethod = @jobConf["settings"]["adjustMethod"]
        @spanAggFunction = @jobConf["settings"]["spanAggFunction"]
        @multiplier   = @jobConf["settings"]["multiplier"]
        if(@multiplier.nil? or @multiplier.to_f <= 0) then @multiplier = 1 end
        @gbConfig     = @jobConf['context']['gbConfFile']
        @userEmail    = @jobConf['context']['userEmail']
        @adminEmail   = @jobConf['context']['gbAdminEmail']
        @firstName    = @jobConf['context']['userFirstName']
        @lastName     = @jobConf['context']['userLastName']
        @scratch      = @jobConf['context']['scratchDir']
        @apiDBRCkey   = @jobConf["context"]["apiDbrcKey"]
        @jobId        = @jobConf["context"]["jobId"]
        @userId       = @jobConf["context"]["userId"]
        @removeNoData = @jobConf['settings']['removeNoDataRegions'] ? true : false
        naGroup = @jobConf['settings']['naGroup']
        if(naGroup == "custom") then
          @naProportion = @jobConf['settings']['naPercentage'].to_f
        elsif(naGroup == "0" or naGroup == "100")
          @naProportion = naGroup.to_f
        else
          raise "Invalid value for naGroup: #{naGroup}"
        end
        @uploadTrack = @jobConf['settings']['uploadTrack'] ? true : false
        if(@uploadTrack) then
          @trackClass = @jobConf['settings']['trackClass']
          @trackType = @jobConf['settings']['lffType']
          @trackSubType = @jobConf['settings']['lffSubType']
        end
        @replaceNAValue = @jobConf['settings']['replaceNAValue']
        @trackListHelper = BRL::Genboree::REST::Helpers::TrackEntityListApiUriHelper.new()
        @analysisNameEsc = CGI.escape(@analysis)
        dbrc 	    = BRL::DB::DBRC.new(nil, @apiDBRCkey)
        @pass 	    = dbrc.password
        @user 	    = dbrc.user
        @grph 	    = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfig)
        @grpOutput  = @grph.extractName(@outputs[0])
        @apiCaller = WrapperApiCaller.new("","",@userId)
        # Minimum number of non NA rows in matrix
        @minMatrixRows = 100
        @maxMatrixEntries = 250_000_000
        # Minimum number of tracks per tracklist
        @minNumTracks = 2
        ## Output database information to upload the heatmap in file area
        @output = @outputs[0]
        uri         = URI.parse(@output)
        @outHost    = uri.host
        @outPath    = uri.path
        return EXIT_OK
      rescue => err
        @errMsg = err.message
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 121
        return exitStatus
      end
    end
  end
end ; end; end; # module BRL ; module Script

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
puts __FILE__
if($0 and File.exist?($0) )
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::WrapperLimmaSignalComparison)
end
