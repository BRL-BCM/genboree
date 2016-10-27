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

include BRL::Genboree::REST
# Write sub-class of BRL::Genboree::Tools::ToolWrapper
module BRL ; module Genboree; module Tools
  class WrapperEpigenomicSlice < ToolWrapper

    VERSION = "1.0"

    DESC_AND_EXAMPLES = {
      :description => "Wrapper to run EpigenomicSlice tool, which generates matrix",
      :authors      => [ "Arpit Tandon" ],
      :examples => [
        "#{File.basename(__FILE__)} --jsonFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    ## To ensure AlL THE TRACKS in entitylist EXIST and are ACCESSIBLE by the user
    def tracksAccessible?(tracksArray)
      exitStatus = 0
      begin
        tracksArray.each{|track|
          uri = URI.parse(track)
          host= uri.host
          path = uri.path
          path << "?gbKey=#{@dbApiHelper.extractGbKey(track)}" if(@dbApiHelper.extractGbKey(track))
          api = WrapperApiCaller.new(host,"#{path}",@userId)
          api.get
          if(!api.succeeded?)
            exitStatus = 120
            $stderr.debugPuts(__FILE__, __method__, "#{File.basename(path)}", api.parseRespBody().inspect)
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

    # run()
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . optsHash contains the command-line args, keyed by --longName
    def run()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running Driver .....")
        exitStatus = EXIT_OK
        @errMsg = ""
        system("mkdir -p #{@scratch}/matrix")
        system("mkdir -p #{@scratch}/trksDownload")
        system("mkdir -p #{@scratch}/logs")
        if(File.exists?("#{@scratch}/matrix") and File.exists?("#{@scratch}/trksDownload") and  File.exists?("#{@scratch}/logs")) then
          exitStatus = tracksAccessible?(@inputs)
          if(exitStatus != EXIT_OK) then
            @errMsg = "Some of the tracks are either removed or not accessible by user"
            $stderr.debugPuts(__FILE__, __method__, "ERROR",@errMsg)
            exitStatus = 120
          else
            exitStatus = buildMatrix(@roiTrack,@inputs,"matrix.xls")
            if(exitStatus != EXIT_OK) then
              @errMsg = "Matrix couldn't be built"
              $stderr.debugPuts(__FILE__, __method__, "ERROR",@errMsg)
              exitStatus = 113
            else
              $stderr.debugPuts(__FILE__, __method__, "Done","Matrix is created")
              if(!compressFiles())
                @errMsg = "Compression failed"
                $stderr.debugPuts(__FILE__, __method__, "ERROR", @errMsg)
                exitStatus = 116
              else
                $stderr.debugPuts(__FILE__, __method__, "Done", "Compression")
                exitStatus = uploadData()
                if(exitStatus != EXIT_OK) then
                  @errMsg = "Upload failed"
                  $stderr.debugPuts(__FILE__, __method__, "Status", @errMsg)
                  exitStatus = 119
                else
                  exitStatus=EXIT_OK
                end
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
        $stderr.debugPuts(__FILE__, __method__, "Status", "Wrapper completed with #{exitStatus}")
        return exitStatus
      end
    end

    def checkInvalid(naCount,numTracks,naProportion)
      return((naCount > 0 and naProportion == 0) or (naCount == numTracks and naProportion == 100) or (naCount!=0 and naCount*100.0/numTracks >= naProportion))
    end


    def compressFiles
      Dir.chdir("#{@scratch}/matrix")
      system("zip matrix.xls.zip matrix.xls")
      Dir.chdir(@scratch)
      return $?.success?
    end

    def buildMatrix(roiTrack,trackList,matrixFileName)
      begin
        roiUri = URI.parse(roiTrack)
        trackList.each{|track|
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "downloading track=#{track.inspect}")
          trackName = @trkApiHelper.extractName(track)
          outFilePath = "#{@scratch}/trksDownload/#{CGI.escape(trackName)}"
          #def getDataFileForTrack(uri, format, aggFunction, regions, outputFilePath, userId, hostAuthMap=nil, emptyScoreValue=nil, noOfAttempts=10, uriParams=nil, regionsParams=nil)
          regionsParams = {"ucscScaling"=>"false"}
          # download track
          respFilePath = @trkApiHelper.getDataFileForTrack(track, "bed", "avg", roiTrack, outFilePath, @userId, hostAuthMap=nil, 
                                                           emptyScoreValue="NA", noOfAttempts=10, uriParams=nil, regionsParams)
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
          annoName = nil
          coordinates = nil
          scoreBuff = nil
          naCount = 0
          fileHandles.each{|fh|
            sl=fh.readline().chomp.split(/\t/)
            if(sl[4] == "NA") then
              naCount += 1
              sl[4] = @replaceNAValue
            end
            if(scoreBuff.nil?) then scoreBuff = StringIO.new end
            if(coordinates.nil?) then
              coordinates = "#{sl[0]}_#{sl[1]}_#{sl[2]}"
              label = "#{coordinates}.#{sl[3]}"
              annoName = sl[3]
              scoreBuff << annoName
            end
            scoreBuff << "\t#{sl[4]}"
          }
          
          invalidScore = (@removeNoData and checkInvalid(naCount,numTracks,@naProportion))
          # Check for non repeated coords only if removeRoiDuplicates is true
          if(!invalidScore and !(@removeRoiDuplicates and coordsHash.has_key?(coordinates))) then
            validLine = true
            coordsHash[coordinates] = true
            numCoords += 1
          end
          
          if(validLine) then
            matrixFile.print scoreBuff.string
            matrixFile.print "\n"
            labelFile.puts label
          else
            puts "skipped #{scoreBuff.string}"
          end
        end
        exitStatus = EXIT_OK
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
    # . Upload files. should be a interface method. Will put it in parent class soon
    def uploadUsingAPI(jobName,fileName,filePath)
      @exitCode = 0
      restPath = @outPath
      path = restPath +"/file/EpigenomeSlice/#{CGI.escape(jobName)}/#{fileName}/data"
      path << "?gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      @apicaller.setRsrcPath(path)
      infile = File.open("#{filePath}","r")
      @apicaller.put(infile)
      if @apicaller.succeeded?
        $stderr.debugPuts(__FILE__, __method__, "Upload file", "#{fileName} done")
        @exitCode = 0
      else
        @errMsg = "Failed to upload the file #{fileName}"
        $stderr.debugPuts(__FILE__, __method__, "Upload Failure", @apicaller.parseRespBody())
        @exitCode = @apicaller.apiStatusObj['statusCode']
      end
      return @exitCode
    end

    def uploadData
      exitStatus = 0
      @apicaller = WrapperApiCaller.new(@outHost,"",@userId)
      restPath = @outPath
      uploadUsingAPI(@analysis,"matrix.xls.zip","#{@scratch}/matrix/matrix.xls.zip")
      uploadUsingAPI(@analysis,"roiLabels.txt","#{@scratch}/matrix/roiLabels.txt")
      uploadUsingAPI(@analysis,"jobFile.json","#{@scratch}/jobFile.json")
      system("rm -rf #{@scratch}/trksDownload")
      system("rm #{@scratch}/matrix/matrix.xls")
      attrNames = ["JobToolId","CreatedByJobName"]
      attrVals = [@toolId,"http://#{@submitHost}/REST/v1/job/#{@jobId}"]
      setFileAttrs(restPath +"/file/EpigenomeSlice/#{CGI.escape(@analysis)}/matrix.xls.zip",attrNames,attrVals)
      setFileAttrs(restPath +"/file/EpigenomeSlice/#{CGI.escape(@analysis)}",attrNames,attrVals)
      if($?.exitstatus != 0)
        exitStatus = 118
      end
      return exitStatus
    end

    # Used to store job specific info. as attrs on uploaded files
    def setFileAttrs(fileRsrcPath,attrNames, attrValues)
      apiCaller = WrapperApiCaller.new(@outHost,"",@userId)
      rsrcPath = "#{fileRsrcPath}/attribute/{attribute}/value"
      rsrcPath << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
      apiCaller.setRsrcPath(rsrcPath)
      attrNames.each_index{|ii|
        payload = { "data" => { "text" => attrValues[ii]}}
        apiCaller.put({:attribute => attrNames[ii]},payload.to_json)
        if(!apiCaller.succeeded?) then
          errMsg = "Unable to set #{attrNames[ii]} attribute of #{fileRsrcPath}\n#{apiCaller.respBody}"
          $stderr.debugPuts(__FILE__, __method__, "Failure setting attributes", errMsg)
          raise errMsg
        end
      }
    end

    # . Prepare successmail
    def prepSuccessEmail
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @firstName
      emailObject.userLast      = @lastName
      emailObject.analysisName  = @analysis
      inputsText                = buildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @jobConf['settings']
      emailObject.exitStatusCode = @exitCode
      emailObject.resultFileLocations = "http://#{@outHost}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{CGI.escape("#{@outPath}/file/EpigenomeSlice/#{CGI.escape(@analysis)}/matrix.xls.zip/data")}"
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
      @roiTrack     = @jobConf['settings']['roiTrack']
      @span         = @jobConf['settings']['spanAggFunction']
      @analysis     = @jobConf['settings']['analysisName']
      @removeNoData = @jobConf['settings']['removeNoDataRegions'] ? true : false
      @replaceNAValue = @jobConf['settings']['replaceNAValue']
      @removeRoiDuplicates = @jobConf['settings']['removeRoiDuplicates'] ? true : false
      @gbConfig     = @jobConf['context']['gbConfFile']
      @userEmail    = @jobConf['context']['userEmail']
      @adminEmail   = @jobConf['context']['gbAdminEmail']
      @firstName    = @jobConf['context']['userFirstName']
      @lastName     = @jobConf['context']['userLastName']
      @scratch      = @jobConf['context']['scratchDir']
      @apiDBRCkey   = @jobConf["context"]["apiDbrcKey"]
      @jobId        = @jobConf["context"]["jobId"]
      @userId       = @jobConf["context"]["userId"]
      @toolId       = @jobConf["context"]["toolIdStr"]
      @submitHost   = @jobConf["context"]["submitHost"]
      naGroup = @jobConf['settings']['naGroup']
      if(naGroup == "custom") then
        @naProportion = @jobConf['settings']['naPercentage'].to_f
      elsif(naGroup == "0" or naGroup == "100")
        @naProportion = naGroup.to_f
      else
        raise "Invalid value for naGroup: #{naGroup}"
      end
      
      @analysisNameEsc = CGI.escape(@analysis)

      ##Retreiving group and database information from the input trkSet
      @grph 	    = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfig)
      @dbhelper     = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfig)
      dbrc 	    = BRL::DB::DBRC.new(nil, @apiDBRCkey)
      @pass 	    = dbrc.password
      @user 	    = dbrc.user

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
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::WrapperEpigenomicSlice)
end
