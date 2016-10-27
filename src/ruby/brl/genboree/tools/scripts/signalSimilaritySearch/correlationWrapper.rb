#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'gsl'
require 'pathname'
require 'brl/util/util'
require 'brl/stats/linearRegression'
require 'brl/stats/stats'
require 'brl/util/emailer'
require 'brl/normalize/index_sort'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/parallelTrackDownload'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class CorrelationWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the correlation based Signal Similarity Search tools.
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
        # Set up options coming from the UI
        @spanAggFunction = @settings["spanAggFunction"]
        @filter = @settings["removeNoDataRegions"]
        @normalization = @settings["normalization"]
        @runName = @settings["analysisName"]
        @roiTrack = @settings["roiTrack"]
        @res = @settings["resolution"]
        @scoreTracks = @settings['scoreTracks']
        @queryTrack = @settings['queryTrack']
        case @res
        when "high"
          @resolution = 1000
        when "medium"
          @resolution = 10000
        when "low"
          @resolution = 100000
        else
          @resolution = @settings["resolution"].to_i
        end
        @runNameOriginal = @runName
        @runName = @runName.makeSafeStr()
        # Set up group and db name
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
        @roiTrackName = @trkApiHelper.extractName(@roiTrack)
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
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading Query track...")
        downloadQueryTrack()
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done downloading Query track. Starting to compute correlation...")
        computeCorr()
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Correlation computed successfully. Transferring files to target database...")
        transferFiles()
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "All Done!")
      rescue => err
        @err = err
        @errUserMsg = err.message
        @exitCode = 30
      end
      return @exitCode
    end

    # Transfers 'summary.txt' to target database
    # [+returns+] nil
    def transferFiles()
      uriObj = URI.parse(@outputs[0])
      rsrcPath = "#{uriObj.path}/file/Signal%20Search/#{@runName}"
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{rsrcPath}/summary.txt/data?", @userId)
      apiCaller.put({}, File.open('summary.txt'))
      if(!apiCaller.succeeded?)
        raise "Could not transfer summary.txt to target database.\n\n#{apiCaller.respBody}"
      end
    end
  
    # Loops over all target tracks and computes correlation with the query track.
    # Treat the query track as 'X' and each of the target tracks as 'Y'
    # Downloads tracks in batches of 3 using concurrent threads.
    # [+returns+] nil
    def computeCorr()
      @qTrkName = @trkApiHelper.extractName(@queryTrack)
      @targetTracksSize = 0
      regions = @roiTrack ? @roiTrack : @resolution
      summaryWriter = File.open('summary.txt', 'w')
      summaryWriter.puts("Track\tCorrelation\tSum of Square of Residual\tIntercept\tSlope\tChiSquare\tRMSEA\tF-Value")
      xLines = `module load gnucoreutils/8; wc -l #{@xFile}`.to_i
      bucket = 0
      uriFileHash = {}
      ptd = BRL::Genboree::Helpers::ParallelTrackDownload.new(uriFileHash, @userId)
      ptd.regions = regions
      ptd.emptyScoreValue = 'n/a'
      ptd.spanAggFunction = @spanAggFunction
      @scoreTracks.each { |targetTrk|
        next if(targetTrk.chomp("?") == @queryTrack.chomp("?"))
        if(@roiTrack)
          next if(targetTrk.chomp("?") == @roiTrack.chomp("?"))
        end
        @targetTracksSize += 1
        tTrk = CGI.escape(@trkApiHelper.extractName(targetTrk))
        if(bucket < 3) # We will download 3 tracks at a time
          bucket += 1
          uriFileHash[targetTrk] = "#{tTrk}.#{Time.now.to_f}.bedGraph" 
          next
        end
        #@trkApiHelper.getDataFilesForTracksWithThreads(uriFileHash, 'bedGraph', @spanAggFunction, regions, @userId, nil, 'n/a')  
        ptd.downloadTracksUsingThreads(uriFileHash)
        writeSummary(summaryWriter, uriFileHash, xLines)
        bucket = 1
        uriFileHash.clear()
        uriFileHash[targetTrk] = "#{tTrk}.#{Time.now.to_f}.bedGraph"  
      }
      if(!uriFileHash.empty?)
        #@trkApiHelper.getDataFilesForTracksWithThreads(uriFileHash, 'bedGraph', @spanAggFunction, regions, @userId, nil, 'n/a')
        ptd.downloadTracksUsingThreads(uriFileHash)
        writeSummary(summaryWriter, uriFileHash, xLines)
      end
      uriFileHash.clear()
      `rm -f #{@xFile} #{@origQFile}`
      summaryWriter.close()
    end
  
    # Writes out summary statistics for query vs target
    # [+summaryWriter+] file handler for summary.txt
    # [+uriFileHash+] A hash mapping track uris to their files
    # [+xLines+] Number of lines in the query file
    # [+returns+] nil
    def writeSummary(summaryWriter, uriFileHash, xLines)
      uriFileHash.each_key { |trkUri|
        tFile = uriFileHash[trkUri]
        @yFile = "#{tFile}.scores"
        `module load gnucoreutils/8; cut -f4 #{tFile} > #{@yFile}`
        `rm -f #{tFile}`
        @tTrkName = @trkApiHelper.extractName(trkUri)
        # The number of lines MUST be equal
        yLines = `module load gnucoreutils/8; wc -l #{@yFile}`.to_i
        raise "Error: Number of lines in downloaded file for tracks: #{@qTrkName} and #{@tTrkName} not equal." if(xLines != yLines)
        createCommonRegionsFiles(xLines)
        xVec = GSL::Vector.alloc(@commonRegions)
        yVec = GSL::Vector.alloc(@commonRegions)
        xPrimeReader = File.open('x.common')
        yPrimeReader = File.open('y.common')
        @commonRegions.times { |ii|
          xVec[ii] = xPrimeReader.readline.to_f
          yVec[ii] = yPrimeReader.readline.to_f
        }
        # Perform normalizations
        if(@normalization == 'quant')
          xVecNorm, yVecNorm = BRL::Stats::quantileNormalize(xVec, yVec)
          xVec, yVec = xVecNorm, yVecNorm # replace non-norm vectors, freeing memory; calc on xVec & yVec
        elsif(@normalization == 'gauss')
          xVecNorm, yVecNorm = BRL::Stats::quantileNormalize(xVec, yVec)
          xVec, yVec = xVecNorm, yVecNorm # replace non-norm vectors, freeing memory; calc on xVec & yVec
        end
        cor = GSL::Stats::correlation(xVec, yVec)
        lr = BRL::Stats::linearRegress(xVec, yVec)
        summaryWriter.print("#{@tTrkName}\t")
        summaryWriter.printf("%6f\t","#{cor}")
        summaryWriter.printf("%6f\t","#{lr.sumSqResiduals}")
        summaryWriter.printf("%6f\t","#{lr.yIntercept}")
        summaryWriter.printf("%6f\t","#{lr.slope}")
        summaryWriter.printf("%6f\t","#{lr.sumSqResiduals}")
        summaryWriter.printf("%6f\t","#{lr.rmsea}")
        if(lr.fStatistic.to_s != "Infinity")
          summaryWriter.printf("%6f\t","#{lr.fStatistic}")
        else
          summaryWriter.printf("Infinity\t")
        end
        summaryWriter.print("\n")
        `rm -f #{@yFile} x.common y.common`
      }
    end

    # Goes through the original downloaded files and creates new files with only common regions depending on filter value
    # [+xLines+] No of lines in the query scores file
    # [+returns+] nil
    def createCommonRegionsFiles(xLines)
      xReader = File.open(@xFile)
      yReader = File.open(@yFile)
      xcommonFile = "x.common"
      ycommonFile = "y.common"
      xPrimeWriter = File.open(xcommonFile, 'w')
      yPrimeWriter = File.open(ycommonFile, 'w')
      # Skip the track headers
      xReader.readline()
      yReader.readline()
      @commonRegions = 0
      (xLines - 1).times { |ii|
        xScore = xReader.readline()
        yScore = yReader.readline()
        if(@filter)
          if(xScore != "n/a\n" and yScore != "n/a\n")
            xPrimeWriter.print(xScore)
            yPrimeWriter.print(yScore)
            @commonRegions += 1
          end
        else
          if(xScore == "n/a\n")
            xPrimeWriter.puts('0.0')
          else
            xPrimeWriter.print(xScore)
          end
          if(yScore == "n/a\n")
            yPrimeWriter.puts('0.0')
          else
            yPrimeWriter.print(yScore)
          end
          @commonRegions += 1
        end
      }
      xPrimeWriter.close()
      yPrimeWriter.close()
      xReader.close()
      yReader.close()
      raise "No Common regions found between #{@qTrkName} and #{@tTrkName}. Cannot compute correlation." if(@commonRegions == 0)
    end
    
    
    # Downloads target track based on the given track URI
    # [+trkURI+] full track URI
    # [+returns+] path to the scores only file for the downloaded track. 
    def downloadTargetTrack(trkUri)
      regions = @roiTrack ? @roiTrack : @resolution
      # First download the X-axis track
      tTrk = CGI.escape(@trkApiHelper.extractName(trkUri))
      tFile = "#{tTrk}.#{Time.now.to_f}.bedGraph"
      retVal = @trkApiHelper.getDataFileForTrack(trkUri, 'bedGraph', @spanAggFunction, regions, tFile, @userId, nil, 'n/a', 10)
      unless(retVal)
        raise "Error: Could not download trk: #{tTrk}"
      end
      exp = BRL::Util::Expander.new(tFile)
      exp.extract()
      tFile = exp.uncompressedFileName
      `module load gnucoreutils/8; cut -f4 #{tFile} > #{tFile}.scores`
      `rm -f #{tFile}`
      return "#{tFile}.scores"
    end
    
    # Downloads Query track in bedgraph format and creates the scores-only file
    # [+returns+] nil
    def downloadQueryTrack()
      regions = @roiTrack ? @roiTrack : @resolution
      # First download the X-axis track
      qTrk = CGI.escape(@trkApiHelper.extractName(@queryTrack))
      qFile = "#{qTrk}.#{Time.now.to_f}.bedGraph"
      @origQFile = qFile.dup()
      retVal = @trkApiHelper.getDataFileForTrack(@queryTrack, 'bedGraph', @spanAggFunction, regions, qFile, @userId, nil, 'n/a', 10)
      unless(retVal)
        raise "Error: Could not download trk: #{qTrk}"
      end
      exp = BRL::Util::Expander.new(qFile)
      exp.extract()
      qFile = exp.uncompressedFileName
      `module load gnucoreutils/8; cut -f4 #{qFile} > #{qFile}.scores`
      `rm -f #{qFile}`
      @xFile = "#{qFile}.scores"
    end

    def prepSuccessEmail()
      summaryURI = "http://#{URI.parse(@outputs[0]).host}/REST/v1/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@dbName)}/file/Signal%20Search/#{@runName}/summary.txt/data?"
      additionalInfo = " Job Summary:
  JobID                  : #{@jobId}
  Analysis Name          : #{@runNameOriginal}
  Query Track :
    #{@trkApiHelper.extractName(@queryTrack)}"
      if(@roiTrack)
        additionalInfo << "
  ROI track:
    #{@trkApiHelper.extractName(@roiTrack)}"
      end
      additionalInfo << "
  Target Tracks:
    #{@targetTracksSize}"
      additionalInfo << "
  Settings:
    spanAggFunction     : #{@spanAggFunction}
    removeNoDataRegions : #{@removeNoDataRegions}
    normalization  : #{@normalization}
    resolution          : #{@res}

Result File Location in the Genboree Workbench:
(Direct links to files are at the end of this email)
  Group : #{@groupName}
  DataBase : #{@dbName}
  Path to File:
      Files
      * Signal Search
       * #{@runName}
         * summary.txt
         
Result File URLs (click or paste in browser to access file):
    FILE: summary.txt
    URL:
http://#{URI.parse(@outputs[0]).host}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{CGI.escape(summaryURI)}

         "
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      return successEmailObject
    end


    def prepErrorEmail()
      additionalInfo = "     Error:\n#{@errUserMsg}"
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      return errorEmailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::CorrelationWrapper)
end
