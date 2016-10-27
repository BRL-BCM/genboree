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
   
    
     def extractSampleIds()
      exitCode = 0
      begin
        dbNames = {}
        
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
          @apiCaller.apiDataObj.each { |obj|
            trkUrl = obj['url']
            @allTracks << trkUrl
            dbName = "#{@dbApiHelper.extractPureUri(trkUrl)}?#{@dbApiHelper.extractQuery(trkUrl)}"
            dbNames[dbName] = [] unless(dbNames.has_key?(dbName))
            dbNames[dbName] << trkUrl
          }
        }
        
        @inputTracks.each{|track|
          @allTracks << track
            dbName = "#{@dbApiHelper.extractPureUri(track)}?#{@dbApiHelper.extractQuery(track)}"
            dbNames[dbName] = [] unless(dbNames.has_key?(dbName))
            dbNames[dbName] << track
          }
        
        
        if(@allTracks.length < @minNumTracks)
            @errMsg = "Not enough samples.\nThis limma tool needs a minimum of #{@minNumTracks} samples to run successfully."
            raise @errMsg
        end
        
        dbNames.keys.each{|dbu|
          @apiCaller.setHost(@dbApiHelper.extractHost(dbu))
          @apiCaller.setRsrcPath("#{@dbApiHelper.extractPath(dbu)}/trks/attributes/map?#{@dbApiHelper.extractQuery(dbu)}&attributeList={attrList}&minNumAttributes=0")
          @apiCaller.get({:attrList => @sampleIdAtt})
          if @apiCaller.succeeded?
            @apiCaller.parseRespBody()
            dbNames[dbu].each{|track|
              trkName = @trkApiHelper.extractName(track)
              if(@apiCaller.apiDataObj[trkName]) then
                sampleId = @apiCaller.apiDataObj[trkName][@sampleIdAtt]
                if(sampleId.nil? or sampleId.empty?)
                  @errMsg = "Could not find a valid sampleId for track #{track} under attribute #{@sampleIdAtt}"
                  $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool - ERROR", "track:#{track} sampleId:#{sampleId}")
                  raise @errMsg
                else
                  if(@sampleIds.member?(sampleId))
                    @errMsg = "Multiple tracks are associated with sample #{sampleId}. Each sample must be linked to only 1 track"
                    raise @errMsg
                  else
                    sampleId = File::makeSafePath(sampleId,:ultra)
                    @trackSampleMap[track] = sampleId
                    @sampleIds << sampleId
                  end
                end
              else
                @errMsg = "Could not retrieve attribute #{@sampleIdAtt} for track #{track}"
                raise @errMsg
              end
              }
          else
            $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool - ERROR", @apiCaller.respBody.inspect)
            raise "Error getting attributes from database: #{dbu}"
          end
          }
        
        ## Checking if THE TRACKS in entitylist EXIST and are ACCESSIBLE by the user
        if(tracksAccessible?(@allTracks)) then
          exitStatus = EXIT_OK
        else
          @errMsg = "Some of the tracks are either removed or not accessible by user"
          raise @errMsg
        end
      rescue=> err
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 120
      end
      return exitStatus
    end
    
    
    def extractSampleAttributes
      begin
      @apiCaller.setHost(@dbApiHelper.extractHost(@dbSample))
      @apiCaller.setRsrcPath("#{@dbApiHelper.extractPath(@dbSample)}/samples?#{@dbApiHelper.extractQuery(@dbSample)}&format=tabbed")
      ofh = File.open("#{@scratch}/sampleInfo.txt","w")
      @apiCaller.get(){|chunk| ofh.print chunk}
      ofh.close
      if(@apiCaller.succeeded?)
          $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "Sample Info retrieved successfully")
      else
          $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool- ERROR", @apiCaller.respBody.inspect)
          raise "Error retrieving sample info from #{@dbSample}"
      end
      ifh = File.open("#{@scratch}/sampleInfo.txt","r")
      headers = ifh.readline().chomp.split(/\t/)
      attrPos = {}
      @attributes.each{|attr|
        ap = headers.find_index(attr)
        if(ap.nil?) then
          @errMsg = "Attribute #{attr} does not exist for samples in #{@dbSample}"
          raise @errMsg
        else
          attrPos[attr] = ap
        end
        }
      @sampleIds.each{|ss| @sampleAttrs[ss] = {}}
      ifh.each_line{|line|
        sl = line.chomp.split(/\t/)
        if(@sampleIds.member?(sl[0])) then
          @attributes.each{|attr|
          attrVal = sl[attrPos[attr]]
          if(attrVal.nil? or attrVal.empty?) then
            @errMsg = "Sample #{sl[0]} does not have attribute #{attr} set"
            raise @errMsg
          else
           @sampleAttrs[sl[0]][attr] = attrVal
          end
          }
        end
        }
      ifh.close()
      exitStatus = EXIT_OK
       rescue=> err
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 120
      end
      return exitStatus
    end
    
    
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
        @inputTracks = []
        @allTracks = []
        @trackSampleMap = {}
        @sampleIds = []

        @inputs.each{|input|
          inpType = apiUriHelper.extractType(input)
          if(inpType == "entityList") then
            @entityLists << input
          elsif(inpType == "trk") then
            @inputTracks << input
          elsif(inpType == "db") then
            @dbSample = input
          end
        }

        system("mkdir -p #{@scratch}/matrix")
        system("mkdir -p #{@scratch}/trksDownload")
        system("mkdir -p #{@scratch}/logs")
        if(File.exists?("#{@scratch}/matrix") and File.exists?("#{@scratch}/trksDownload") and  File.exists?("#{@scratch}/logs")) then
          exitStatus = extractSampleIds()
          if(exitStatus != EXIT_OK) then
            $stderr.debugPuts(__FILE__, __method__, "ERROR",@errMsg)
            exitStatus = 120
          else
            @sampleAttrs = {}
            exitStatus = extractSampleAttributes()
            if(exitStatus != EXIT_OK) then
              $stderr.debugPuts(__FILE__, __method__, "ERROR",@errMsg)
              exitStatus = 120
            else
              if(checkMatrixSize(@roiTrack,@allTracks.length,@matrixSizeLimit)) then
                exitStatus = buildMatrix(@roiTrack,@allTracks,"matrix.txt",@trackSampleMap)
                if(exitStatus != EXIT_OK) then
                  if(exitStatus == 120) then
                    @errMsg = "The Matrix could not be created because there were too few rows with non NA scores"
                  else
                    @errMsg = "Matrix couldn't be built"
                  end
                  $stderr.debugPuts(__FILE__, __method__, "ERROR",@errMsg)
                  exitStatus = 113
                else
                  $stderr.debugPuts(__FILE__, __method__, "Done","Matrix is created")
                  @attrNames = []
                  @attrMap = {}
                  @attrValues = {}
                  buildMetadataFile()
                  $stderr.debugPuts(__FILE__, __method__, "Done","Metadata file created")
                  exitStatus = runLimma()
                  if(exitStatus != EXIT_OK) then
                    @errMsg = "Limma tool didn't run successfully"
                    $stderr.debugPuts(__FILE__, __method__, "ERROR", @errMsg)
                    exitStatus = 114
                  else
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
      else
        errMsg = "Error determining roi track annotation count\nROI Track:#{roiTrack.inspect}"
        $stderr.debugPuts(__FILE__, __method__, "Error", errMsg)
        $stderr.debugPuts(__FILE__, __method__, "Error ", @apiCaller.respBody.inspect)
        raise errMsg
      end
    end


    def buildMatrix(roiTrack, trackList, matrixFileName, sampleMap)
      begin
        fileHandles = []
        matrixFile = File.open("#{@scratch}/matrix/#{matrixFileName}","w")
        labelFile = File.open("#{@scratch}/matrix/roiLabels.txt","w")
        trackList.each{|track|
          trackName = @trkApiHelper.extractName(track)

          outFilePath = "#{@scratch}/trksDownload/#{CGI.escape(trackName)}"
          respFilePath = @trkApiHelper.getDataFileForTrack(track, "bed", @spanAggFunction, roiTrack, outFilePath, @userId, hostAuthMap=nil, 
                                                           emptyScoreValue="NA", noOfAttempts=10, uriParams=nil, regionsParams=nil)
          unless(respFilePath)
            errMsg = "Error downloading track #{trackName}"
            $stderr.debugPuts(__FILE__, __method__, "Build Matrix - Error ", errMsg)
            raise errMsg
          end
        }
        
        coordsHash = Hash.new(0)
        
        trackList.each{|track|
          trackName = @trkApiHelper.extractName(track)
          fileHandles << File.open("#{@scratch}/trksDownload/#{CGI.escape(trackName)}","r")
          matrixFile.print("\t#{@trackSampleMap[track].gsub(/[:| ]/,'.')}")
        }
        matrixFile.print("\n")
        numTracks = fileHandles.length
        coordsHash = {}
        numCoords = 0

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
        if(numCoords > @minMatrixRows) then
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
    
    def checkInvalid(naCount,numTracks,naProportion)
      return((naCount > 0 and naProportion == 0) or (naCount == numTracks and naProportion == 100) or (naCount!=0 and naCount*100.0/numTracks >= naProportion))
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
    
    
    
    def buildMetadataFile()
      fileWrite = File.open("#{@scratch}/matrix/metadata.txt", "w+")
      @attributes.each{|attr|
        attrNew = File::makeSafePath(attr,:ultra)
        @attrNames << attrNew
        @attrMap[attr] = attrNew
        @attrValues[attr] = Hash.new(0)
      }
      fileWrite.print "\t#{@attrNames.join("\t")}\n"
      @sampleIds.each{|ss|
        fileWrite.print ss
        @attributes.each{|attr|
          attrVal = @sampleAttrs[ss][attr]
          fileWrite.print "\t#{attrVal}"
          @attrValues[attr]["X#{attrVal}"] += 1
        }
        fileWrite.print("\n")
      }
      fileWrite.close
      @attrValues.each_key{|aa|
        if(@attrValues[aa].keys.length < 2) then
          @errMsg = "Unable to use attribute #{aa}.\nEach metadata attribute must have atleast two distinct values for this limma tool to run successfully."
          raise @errMsg
        end
        @attrValues[aa].each_key{|vv|
          if(@attrValues[aa][vv] < 2) then
            @errMsg = "Unable to use attribute #{aa}.\nEach attribute value must have atleast two samples associated with it for this limma tool to run successfully."
            raise @errMsg
          end
        }
      }
    end
    
  def createDesignFiles
    dfh = []
    @attrNames.each{|attr|
      fh = File.open("#{@scratch}/matrix/#{attr}Design.txt","w")
      fh.puts "sample\tTarget"
      dfh << fh
      }
    mfh = File.open("#{@scratch}/matrix/metadata.txt")
    mfh.readline
    mfh.each_line{|line|
      sl=line.chomp.split(/\t/)
      (1 .. sl.length-1).each{|ss|
        dfh[ss-1].puts "#{sl[0]}\tX#{sl[ss]}"
        }
      }
    mfh.close
    dfh.each{|dd| dd.close}
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
    createDesignFiles()
    errorState = false
    @attributes.each{|attr|
      vals = @attrValues[attr].keys
      numSets = vals.length
      setString = StringIO.new
      normalizeString = nil
      if(@normalize == "Quantile") then
          normalizeString = "dataMatrixNormalize <- normalize.quantiles(dataMatrix, copy=TRUE)"
        elsif(@normalize == "Percentage")
          normalizeString = "dataMatrix[is.na(dataMatrix)]<-0\ncolSums <- apply(dataMatrix,2,sum)\n"+
          "dataMatrixNormalize <- t(apply(dataMatrix,1,function(x) (x/colSums)*#{@multiplier}))"
        else
          normalizeString = "dataMatrixNormalize <- dataMatrix"
        end
      contrastString = nil
      filterString = nil
      if(numSets > 2) then
        (0 .. numSets-2).each{|ii|
          (ii+1 .. numSets-1).each{|jj|
            setString << " #{vals[ii]} - #{vals[jj]},"
          }
        }
        contrastString = "makeContrasts(#{setString.string} levels=design)"
      else
        contrastString = "makeContrasts(#{vals[0]}Vs#{vals[1]}=#{vals[0]}-#{vals[1]}, levels=design)"
      end
      valString = vals.map{|vv| "\"#{vv}\""}.join(",")
      limmaFileName = "#{@attrMap[attr]}.R"
      limmaFile = File.open("#{@scratch}/#{limmaFileName}","w")
      limmaFile.print <<-END
      library(preprocessCore)
      library(limma)
      pathPrefix <- \"#{@scratch}/matrix\"
      dataMatrix <- read.table(paste(pathPrefix,\"/\",\"matrix.txt\",sep=\"\"),check.names=FALSE,header=TRUE,row.names=1)     
      dataMatrix <- as.matrix(dataMatrix)
      #{normalizeString}
      rownames(dataMatrixNormalize) <- rownames(dataMatrix)
      colnames(dataMatrixNormalize) <- colnames(dataMatrix)
      write.table(dataMatrixNormalize,file=paste(pathPrefix,\"/\",\"normalizedMatrix.txt\",sep=\"\"),quote=FALSE,sep='\\t')
      targets <- readTargets(file=paste(pathPrefix,\"/\",\"#{@attrMap[attr]}Design.txt\",sep=\"\"))
      f <- factor(targets$Target, levels = c(#{valString}))
      design <- model.matrix(~0 + f)
      colnames(design) <- c(#{valString})
      cont.matrix <- #{contrastString}
      fit <- lmFit(dataMatrixNormalize, design)
      fit2 <- contrasts.fit(fit, cont.matrix)
      fit2 <- eBayes(fit2)
      topResults <- toptable(fit2, adjust.method = \"#{@adjustMethod}\",number="inf")
      row.names(topResults) <- row.names(dataMatrixNormalize)[as.integer(row.names(topResults))]
      write.table(topResults,file=paste(pathPrefix,\"/\",\"#{@attrMap[attr]}_topTableNoFilter.txt\",sep=\"\"),col.names=NA,quote=FALSE,sep='\\t')
      topResults <- topResults[which((topResults[,"P.Value"] < #{@minPval}) & (topResults[,"adj.P.Val"] < #{@minAdjPval})),]
      write.table(topResults,file=paste(pathPrefix,\"/\",\"#{@attrMap[attr]}_topTable.txt\",sep=\"\"),quote=FALSE,col.names=NA,sep='\\t')
      results <- decideTests(fit2, method=\"#{@testMethod}\", adjust.method=\"#{@adjustMethod}\", p.value=#{@minAdjPval}, lfc=#{@minFoldCh})
      write.table(results,file=paste(pathPrefix,\"/\",\"#{@attrMap[attr]}_decideTests.txt\",sep=\"\"),col.names=NA,quote=FALSE,sep='\\t')
      write.table(summary(results),file=paste(pathPrefix,\"/\",\"#{@attrMap[attr]}_decideTestsClassification.txt\",sep=\"\"),quote=FALSE,col.names=NA,sep='\\t')
      END
        limmaFile.close
        $stderr.debugPuts(__FILE__, __method__, "Status", "Running Limma for attribute #{@attrMap[attr]}")
        system("Rscript --vanilla #{@scratch}/#{limmaFileName}")
        exitStatus = ($?.success?) ? EXIT_OK : 113
        if(exitStatus != EXIT_OK) then errorState = true end
        $stderr.debugPuts(__FILE__, __method__, "Status", "Limma tool completed with #{exitStatus} for attribute #{@attrMap[attr]}")
      }
    if(errorState) then return 113 else return EXIT_OK end
    end
    
    ## generic archive of output directory, regardless whether LIMMA succeeded or not
    def compressRawOutput()
      Dir.chdir("#{@scratch}/matrix")
      system("zip raw.results.zip  * -x *atrix.txt -x metadata.txt -x *Design.txt -x *NoFilter.txt -x *.R")
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
      @inputs       = @jobConf['inputs']
      @outputs      = @jobConf['outputs']
      apiUriHelper = BRL::Genboree::REST::Helpers::ApiUriHelper.new()
      if(apiUriHelper.extractType(@outputs[0]) != "db" ) then
        @outputs.reverse!
      end
      @roiTrack = @jobConf['settings']['roiTrack']
      @sampleIdAtt  = @jobConf["settings"]["sampleIdAttribute"]
      @attributes   = @jobConf["settings"]["attributesForLimma"]
      @normalize    = @jobConf['settings']['normalize']
      @analysis     = @jobConf['settings']['analysisName']
    # @sortby       = @jobConf["settings"]["sortBy"]
      @minPval      = @jobConf["settings"]["minPval"]
      @minAdjPval   = @jobConf["settings"]["minAdjPval"]
      @minFoldCh    = @jobConf["settings"]["minFoldChange"]
    #  @minBval      = @jobConf["settings"]["minBval"]
      @testMethod   = @jobConf["settings"]["testMethod"]
      @adjustMethod = @jobConf["settings"]["adjustMethod"]
      @multiplier   = @jobConf["settings"]["multiplier"]
      @spanAggFunction = @jobConf["settings"]["spanAggFunction"]
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
      uri         = URI.parse(@outputs[0])
      @outHost    = uri.host
      @outPath    = uri.path

      return EXIT_OK
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
