#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'gsl'
require 'pathname'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/stats/stats'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class RegressionWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the regression based Signal Data Comparison tools.
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
        @uploadResults = @settings["uploadFile"]
        @lffClass = @settings["lffClass"]
        @lffType = @settings["lffType"]
        @lffSubType = @settings["lffSubType"]
        @roiTrack = @settings["roiTrack"]
        @res = @settings["resolution"]
        @xTrk = @settings['xAxisTrk']
        @yTrk = @settings['yAxisTrk']
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
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading X and Y axes tracks...")
        downloadTracks()
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done downloading X and Y axes tracks...")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Creating common regions files for X and Y axes tracks...")
        createCommonRegionsFiles()
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done creating common regions files for X and Y axes tracks. Found #{@commonRegions.inspect} common regions.")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Computing Regression and writing out summary.txt and result.lff...")
        performRegression()
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Regression computed successfully. Transferring files to target database...")
        transferFiles()
        if(@uploadResults)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Files transferred successfully. Uploading result.lff as track...")
          uploadTrack()
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "All Done!")
      rescue => err
        @err = err
        @errUserMsg = err.message
        @exitCode = 30
      end
      return @exitCode
    end

    # Transfers 'summary.txt' and 'result.lff.gz' to target database
    # [+returns+] nil
    def transferFiles()
      uriObj = URI.parse(@outputs[0])
      rsrcPath = "#{uriObj.path}/file/Signal%20Comparison/#{@runName}"
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{rsrcPath}/summary.txt/data?", @userId)
      apiCaller.put({}, File.open('summary.txt'))
      if(!apiCaller.succeeded?)
        raise "Could not transfer summary.txt to target database.\n\n#{apiCaller.respBody}"
      end
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{rsrcPath}/result.lff.zip/data?", @userId)
      apiCaller.put({}, File.open('result.lff.zip'))
      if(!apiCaller.succeeded?)
        raise "Could not transfer result.lff.zip to target database.\n\n#{apiCaller.respBody}"
      end
    end

    # Uploads result.lff.gz as track
    # [+returns+] nil
    def uploadTrack()
      uriObj = URI.parse(@outputs[0])
      apiCaller = WrapperApiCaller.new(uriObj.host, uriObj.path, @userId)
      apiCaller.get()
      if(apiCaller.succeeded?)
        apiCaller.parseRespBody()
        # This doesn't appear to be Genboree Network compatible.
        # - i.e. is it api-based upload or direct MySQL insert work?
        # - should we do it one way if local and another if remote (for flexibility and efficiency)
        uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
        uploadAnnosObj.refSeqId = apiCaller.apiDataObj['refSeqId']
        uploadAnnosObj.groupName = @groupName
        uploadAnnosObj.userId = @userId
        uploadAnnosObj.jobId = @jobId
        # expand the lff we're going to upload as annos:
        exp = BRL::Genboree::Helpers::Expander.new("result.lff.zip")
        exp.extract()
        # do upload of annos
        begin
          uploadAnnosObj.uploadLff(CGI.escape(File.expand_path(exp.uncompressedFileName)), false)
          # remove expanded lff file just uploaded
          `rm -f #{exp.uncompressedFileName}`
        rescue => uploadErr
          errMsg = "Could not upload track to target database."
          if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
            errMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
          end
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{errMsg}\nException: #{uploadErr}\nBacktrace:\n#{uploadErr.backtrace.join("\n")}\n\n")
          raise errMsg
        end
      end
    end

    # Reads data from x.common and y.common into GSL vectors and computes linear regression
    # Writes out summary.txt and the final summary lff file for uploading/transferring
    # [+returns+] nil
    def performRegression()
      xVec = GSL::Vector.alloc(@commonRegions)
      yVec = GSL::Vector.alloc(@commonRegions)
      xPrimeReader = File.open('x.common')
      yPrimeReader = File.open('y.common')
      @commonRegions.times { |ii|
        xVec[ii] = xPrimeReader.readline.to_f
        yVec[ii] = yPrimeReader.readline.to_f
      }
      xPrimeReader.close
      yPrimeReader.close
      # Perform normalizations
      if(@normalization == 'quant')
        xVecNorm, yVecNorm = BRL::Stats::quantileNormalize(xVec, yVec)
        xVec, yVec = xVecNorm, yVecNorm # replace non-norm vectors, freeing memory; calc on xVec & yVec
      elsif(@normalization == 'gauss')
        xVecNorm, yVecNorm = BRL::Stats::quantileNormalize(xVec, yVec)
        xVec, yVec = xVecNorm, yVecNorm # replace non-norm vectors, freeing memory; calc on xVec & yVec
      end

      # Pearson's Correlation:
      correlation = GSL::Stats::correlation(xVec, yVec)

      # Linear Regression. Returns info-enhanced BRL class
      regressionObj = BRL::Stats::linearRegress(xVec, yVec)

      # Summary report
      summaryStr = <<-EOS
        #{'='*70}
        Tracks Compared:
            - X                         => #{@trkApiHelper.extractName(@xTrk)}
            - Y                         => #{@trkApiHelper.extractName(@yTrk)}
        Basis of Comparison:
            - #{@roiTrack ? "ROI track  => #{@roiTrackName.inspect}" : "Fixed window: #{@resolution}bp" }
        Settings:
            - Remove Data-Less Regions  => #{@filter.inspect}
            - Normalization Method      => #{@normalization.inspect}
        #{'-'*40}
        Linear Regression Line (Y = a + bX):
            - Equation                           => Y = #{"%0.6g" % regressionObj.yIntercept} + #{"%0.6g" % regressionObj.slope} * X
            - Intercept                          => #{"%0.6g" % regressionObj.yIntercept}
            - Slope                              => #{"%0.6g" % regressionObj.slope}
        Regression Metrics and Statistics:
            - Correlation (Pearson)              => #{"%0.6g" % correlation}
            - Total Sum of Squares               => #{"%0.4e" % regressionObj.sumSqTotal}
              . Sum of squares of regression          -> #{"%0.4e" % regressionObj.sumSqRegression}
              . Sum of squares of residuals           -> #{"%0.4e" % regressionObj.sumSqResiduals}
            - Degrees of Freedom                 => #{regressionObj.df}
            - R-Square (coeff. of determination) => #{"%0.6g" % regressionObj.rSq}
            - Chi-Square Statistic               => #{"%0.6g" % regressionObj.sumSqResiduals}
            - Root Mean Square Error (RMSEA)     => #{"%0.6g" % regressionObj.rmsea}
            - F-Test (Goodness of Fit):
              . F-statistic = #{"%0.6g" % regressionObj.fStatistic}
              . p-value     = #{"%0.4e" % regressionObj.fStatisticPvalue}
            - t-Test on Constant Term (test a=0):
              . t-statistic = #{"%0.6g" % regressionObj.yInterceptTStatistic}
              . p-value     = #{"%0.4e" % regressionObj.yInterceptPvalue}
            - t-Test on Slope (test b=0):
              . t-statistic = #{"%0.6g" % regressionObj.slopeTStatistic}
              . p-value     = #{"%0.4e" % regressionObj.slopePvalue}
            - Variance-Covariance Matrix         => [ #{regressionObj.covarianceMatrix.map{|xx| "%0.6e" % xx}.join(", ")} ]
      EOS
      summaryStr.gsub!(/^ {4,4}/, '')
      summaryWriter = File.open('summary.txt', 'w')
      summaryWriter.puts summaryStr
      summaryWriter.close
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "    - Calcuated regression and related metrics & statistics. Wrote regression summary file.")
      # Write out LFF file containing each ROI region X & Y have in common
      # and add various point-specific scores such as:
      # - Predicted Y value
      # - Observed Y value (may be normalized)
      # - Residual
      # - z-Test to see if residual at point Xi,Yi comes from the population of residuals whose mean is ~0 (regression minimizes mean residual sum)
      #   . includes z-score
      #   . includes p-value
      #   . includes -10 * log of p-value (so bigger == more of an outlier residual, off the regression line...i.e. bigger==interesting point)
      #
      # Get predicted Y values GSL::Vector using our linear model and the original X vector
      predictedYVector = regressionObj.calculatePredictedYs(xVec)
      # Get residuals GSL::Vector using our linear model and the original X and Y vectors
      # (provide optional predictedYVector to save time since we need those values anyway for a different reason)
      residualsVector = regressionObj.calculateResiduals(xVec, yVec, predictedYVector)
      # Get z-Scores and p-Values for each residual r_i, testing if r_i belongs to the population where mean r = 0
      # (actually we use the real mean r from residualsVector.mean, which should be CLOSE to 0 since that's the point of the regression in theory.)
      # - this comes back as 2 GSL::Vectors stored in a Hash keyed by: :zScoresVector and :pValuesVector (2-tailed test)
      residualsZScoresHash = regressionObj.calculateResidualZscoresAndPvalues(residualsVector)
      zScoresVector = residualsZScoresHash[:zScoresVector]
      pValuesVector = residualsZScoresHash[:pValuesVector]
      # Read through the common regions BED file and convert to LFF with augmented info
      # - this file is supposed to be in the SAME ORDER as the scores in the vectors
      # - an index (line number) in this file will MATCH and index in the vector
      filteredReader = File.open('filteredCommonRegions.bed')
      lffWriter = File.open('result.lff', 'w+')
      filteredReader.each_line { |line|
        # Line number in file matched index in vectors (no header, no blanks, etc)
        ii = (filteredReader.lineno - 1)
        columns = line.strip.split(/\t/)
        zScore = zScoresVector[ii]
        pValue = pValuesVector[ii]
        predictedY = predictedYVector[ii]
        residual = residualsVector[ii]
        logPvalue = ((pValue <= 0.0 or pValue.to_s == "NaN") ? (0.0/0.0) : (-10.0 * Math.log10(pValue)) )
        # Write augmented LFF line
        lffWriter.puts  "#{@lffClass}\t#{columns[3]}\t#{@lffType}\t#{@lffSubType}\t#{columns[0]}\t#{columns[1]}\t#{columns[2]}\t#{columns[5]}\t.\t#{pValue.to_s == "NaN" ? -1.0 : pValue}\t.\t.\tyIntercept=#{"%0.6g" % regressionObj.yIntercept}; slope=#{"%0.6g" % regressionObj.slope}; predictedY=#{"%0.6g" % predictedY}; observedY=#{"%0.6g" % yVec[ii]}; residual=#{"%0.6g" % residual}; zScore=#{"%0.6g" % zScore}; pValue=#{"%0.6g" % pValue}; 10log10Pvalue=#{"%0.6g" % logPvalue}; "
      }
      filteredReader.close
      lffWriter.close
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "    - Calcuated predicted-y, residual, and residual z-test results for all #{@commonRegions} data points. Wrote compute info for each common region to LFF file.")
      # Compress the LFF file
      `zip -9 result.lff.zip result.lff`
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "    - Zipped LFF with common region info.")
    end

    # Goes through the original downloaded files and creates new files with only common regions depending on filter value
    # [+returns+] nil
    def createCommonRegionsFiles()
      xReader = File.open(@xFile)
      yReader = File.open(@yFile)
      origXReader = File.open(@origXFile)
      xcommonFile = "x.common"
      ycommonFile = "y.common"
      xPrimeWriter = File.open(xcommonFile, 'w')
      yPrimeWriter = File.open(ycommonFile, 'w')
      @filteredRegionsFile = "filteredCommonRegions.bed"
      filteredWriter = File.open(@filteredRegionsFile, 'w')
      # Skip the track headers
      xReader.readline()
      yReader.readline()
      origXReader.readline()
      @commonRegions = 0
      (@xLines - 1).times { |ii|
        xScore = xReader.readline()
        yScore = yReader.readline()
        filteredLine = origXReader.readline()
        if(@filter)
          if(xScore != "n/a\n" and yScore != "n/a\n")
            xPrimeWriter.print(xScore)
            yPrimeWriter.print(yScore)
            filteredWriter.print(filteredLine)
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
          filteredWriter.print(filteredLine)
          @commonRegions += 1
        end
      }
      xPrimeWriter.close()
      yPrimeWriter.close()
      filteredWriter.close()
      xReader.close()
      yReader.close()
      origXReader.close()
      raise "No Common regions found between #{xAxisTrk} and #{yAxisTrk}. Cannot compute correlation." if(@commonRegions == 0)
    end

    def roundOf(a)
      a = a.to_s
      if(a =~/\d+/)
        a=a.to_f
        roundOfValue = (a*10**6).round.to_f/(10.0**6)
      else
        roundOfValue = "NaN"
      end
      return roundOfValue
    end

    # Downloads X-axis and Y-axis tracks in bedgraph format
    # [+returns+] nil
    def downloadTracks()
      regions = @roiTrack ? @roiTrack : @resolution
      # First download the X-axis track
      xAxisTrk = CGI.escape(@trkApiHelper.extractName(@xTrk))
      @xFile = "#{xAxisTrk}.#{Time.now.to_f}.bed"
      @origXFile = @xFile.dup() # This will be used to create the 'filteredCommonRegions.bed' (containing coordinates of the common regions between the X-axis and Y-axis tracks) file which is used to generate the final summary lff file
      retVal = @trkApiHelper.getDataFileForTrack(@xTrk, 'bed', @spanAggFunction, regions, @xFile, @userId, nil, 'n/a', 10)
      unless(retVal)
        raise "Error: Could not download trk: #{xAxisTrk}"
      end
      exp = BRL::Util::Expander.new(@xFile)
      exp.extract()
      @xFile = exp.uncompressedFileName
      # Next download the Y-axis track
      yAxisTrk = CGI.escape(@trkApiHelper.extractName(@yTrk))
      @yFile = "#{yAxisTrk}.#{Time.now.to_f}.bed"
      origYFile = @yFile.dup()
      retVal = @trkApiHelper.getDataFileForTrack(@yTrk, 'bed', @spanAggFunction, regions, @yFile, @userId, nil, 'n/a', 10)
      unless(retVal)
        raise "Error: Could not download trk: #{yAxisTrk}"
      end
      exp = BRL::Util::Expander.new(@yFile)
      exp.extract()
      @yFile = exp.uncompressedFileName
      # The number of lines MUST be equal
      xLines = `wc -l #{@xFile}`.to_i
      yLines = `wc -l #{@yFile}`.to_i
      raise "Error: Number of lines in downloaded file for tracks: #{xAxisTrk} and #{yAxisTrk} not equal." if(xLines != yLines)
      `cut -f5 #{@xFile} > #{@xFile}.scores`
      `cut -f5 #{@yFile} > #{@yFile}.scores`
      @xFile = "#{@xFile}.scores"
      @yFile = "#{@yFile}.scores"
      @xLines = xLines
      # Nuke the original Y-axis track file, we don't need it anymore. We will still keep around the original x axis file for the reason mentioned above.
      `rm -f #{origYFile}`
    end

    def prepSuccessEmail()
      summaryURI = "http://#{URI.parse(@outputs[0]).host}/REST/v1/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@dbName)}/file/Signal%20Comparison/#{@runName}/summary.txt/data?"
      lffURI = "http://#{URI.parse(@outputs[0]).host}/REST/v1/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@dbName)}/file/Signal%20Comparison/#{@runName}/result.lff.zip/data?"
      additionalInfo = " Job Summary:
  JobID                 : #{@jobId}
  Analysis Name         : #{@runNameOriginal}
  Input Tracks :
    - X                 : #{@trkApiHelper.extractName(@xTrk)}
    - Y                 : #{@trkApiHelper.extractName(@yTrk)}
  Basis of Comparison:
    - #{@roiTrack ? "ROI track         : #{@roiTrackName.inspect}" : "Fixed window: #{@resolution}bp" }"
      additionalInfo << "
  Settings:
    spanAggFunction     : #{@spanAggFunction}
    removeNoDataRegions : #{@removeNoDataRegions}
    normalization       : #{@normalization}
    resolution          : #{@res}

Result File Location in the Genboree Workbench:
(Direct links to files are at the end of this email)
  Group    : #{@groupName}
  DataBase : #{@dbName}
  Path to File:
      Files
      * Signal Comparison
       * #{@runNameOriginal}
         * summary.txt

Result File URLs (click or paste in browser to access file):
    FILE: summary.txt
    URL:
http://#{URI.parse(@outputs[0]).host}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{CGI.escape(summaryURI)}

    FILE: result.lff.zip
    URL:
http://#{URI.parse(@outputs[0]).host}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{CGI.escape(lffURI)}

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
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::RegressionWrapper)
end
