#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/util/emailer'
require 'gsl'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/normalize/index_sort'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/util/checkSumUtil'
require 'brl/genboree/helpers/expander'
include GSL
include BRL::Genboree::REST

class PairWiseSimilarityWrapper
  def initialize(optsHash)
    @jsonFile    = File.expand_path(optsHash['--jsonFile'])
    jsonObj = JSON.parse(File.read(@jsonFile))
    jsonObj = addToolTitle(jsonObj)
    @input  = jsonObj["inputs"]
    @output = jsonObj["outputs"][0]
    @toolIdStr = jsonObj['context']['toolIdStr']
    @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr)
    @gbConfFile = jsonObj["context"]["gbConfFile"]
    @apiDBRCkey = jsonObj["context"]["apiDbrcKey"]
    @scratch = jsonObj["context"]["scratchDir"]
    @email = jsonObj["context"]["userEmail"]
    @user_first = jsonObj["context"]["userFirstName"]
    @user_last = jsonObj["context"]["userLastName"]
    @username = jsonObj["context"]["userLogin"]

    @toolIdStr = jsonObj['context']['toolIdStr']
    @genbConf = BRL::Genboree::GenboreeConfig.load(ENV['GENB_CONFIG'])
    @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr, @genbConf)
    @toolTitle = @toolConf.getSetting('ui', 'label')

    @gbAdminEmail = jsonObj["context"]["gbAdminEmail"]
    @jobID = jsonObj["context"]["jobId"]
    @userId = jsonObj["context"]["userId"]
    @spanAggFunction = jsonObj["settings"]["spanAggFunction"]
    @removeNoDataRegions = jsonObj["settings"]["removeNoDataRegions"]
    @ranknNormalized = jsonObj["settings"]["rankNormalized"]
    @normalization = jsonObj["settings"]["normalization"]
    @runName = jsonObj["settings"]["analysisName"]
    @uploadResults = jsonObj["settings"]["uploadFile"]
    @lffClass = jsonObj["settings"]["lffClass"]
    @lffType = jsonObj["settings"]["lffType"]
    @lffSubType = jsonObj["settings"]["lffSubType"]
    @ROItrack = jsonObj["settings"]["useGenboreeRoiScores"]
    @res = jsonObj["settings"]["resolution"]
    case @res
    when "high"
      @resolution = 1000
    when "medium"
      @resolution = 10000
    when "low"
      @resolution = 100000
    else
      @resolution = jsonObj["settings"]["resolution"].to_i
      @res = jsonObj["settings"]["resolution"].to_i
    end
    @runNameOriginal = @runName
    @runName = @runName.makeSafeStr()
    @grph = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new()
    @dbhelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
    @trackhelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new()
    ##pulling out upload location specifications
    @output = @output.chomp('?')
    @dbOutput = @dbhelper.extractName(@output)
    @grpOutput = @grph.extractName(@output)
    uriOutput = URI.parse(@output)
    @hostOutput = uriOutput.host
    @pathOutput = uriOutput.path
    @uri = @grph.extractPureUri(@output)
    genbConfig = BRL::Genboree::GenboreeConfig.load()
    dbrcFile = File.expand_path(ENV['DBRC_FILE'])
    @uri = URI.parse(@input[0])
    @host = @uri.host
    @aggFuncDir = nil
    if(@spanAggFunction == 'avgByLength')
      @aggFuncDir = "By%20AvgByLength"
    elsif(@spanAggFunction == 'med')
      @aggFuncDir = "By%20Median"
    else
      @aggFuncDir = "By%20#{@spanAggFunction.capitalize}"
    end
    @exitCode= ""
    @wigCount = @roiCount = 0
    # Collect the downloaded data file names and the "LFF" versions made for each file
    @downloadedLFFDataFiles = []
    @downloadedDataFiles = []
  end
  
  def addToolTitle(jsonObj)
    jsonObj['context']['toolTitle'] = @toolConf.getSetting('ui', 'label')
    return jsonObj
  end

  ##Main to call either wigdownload or withROI
  def work
    system("mkdir -p #{@scratch}")
    Dir.chdir(@scratch)
    @outputDir = "#{@scratch}/signal-search/#{@runName}"
    system("mkdir -p #{@outputDir}")
    if(@input.size == 2)
      @haveROI = false
      @dataInputs = @input
      wigDownload()
    else # Also have an ROI (currently the last input must be the ROI)
      @haveROI = true
      @roiInput = @input.pop
      @dataInputs = @input
      # Get ROI-related info
      @roiInput.chomp!('?')
      @dbROI    = @dbhelper.extractName(@roiInput)
      @grpROI   = @grph.extractName(@roiInput)
      @trkROI   = @tkOutput = @trackhelper.extractName(@roiInput)
      # Download w.r.t. ROI
      withROI()
    end
    # Build command
    # - base command:
    command = "module load gnuplot/4.4; pairWiseSignalSearchTool.rb "
    # Add -f arg to command
    command << " -f '#{@downloadedLFFDataFiles.join(",")}' "
    if(@haveROI)
      ##WAS: (but unused in downstream script after all?)
      #niceBasename = File.makeSafePath(@trkROI, :ultra)
      ## Add ROI file plus weird naming suffix downstream tools seem to expect:
      #command << " #{niceBasename}_N#{@input.lastIndex}N"
      command << " -R #{CGI.escape(@trkROI)} "
    end
    # Rest or command args:
    format = (@haveROI ? "Lff" : "Wig")
    command << " -o  #{@scratch}  -a #{CGI.escape(@runName)} -s #{@scratch} -F #{format} -c #{@removeNoDataRegions} -r #{@resolution} -q #{@normalization}"
    command << " -l #{CGI.escape(@lffClass)} -L #{CGI.escape(@lffType)} -S #{CGI.escape(@lffSubType)} > pairWiseSignalSearchTool.log "
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command:\n    #{command.inspect}...")
    system(command)
    if(!$?.success?)
      @exitCode = $?.exitstatus
      raise "pairWiseSignalSearch.rb failed (exit code: #{@exitCode.inspect})"
    end
    regression()
  end

  # For downloading 'wig' files (static/dynamic) if no Regions of Interest (ROI) track present.
  # The data is downloaded as 'windows' of base pairs selected by the user
  # The method first checks if a static wig file is present for the score track on the server and downloads it if available.
  # If static file absent, a dynamic download of the score track is done. The presence of the adler32 checksum is used to verify
  # the completeness of the dynamically downloaded data. If absent, 2 more attempts are made to download the data
  # [+returns+] nil
  def wigDownload()
    @dataInputs.each_index { |ii|
      dataInput = @dataInputs[ii]
      # Get some info about the trk resource:
      host = @trackhelper.extractHost(dataInput)
      @db  = @dbhelper.extractName(dataInput)
      @grp = @grph.extractName(dataInput)
      @trk  = @trackhelper.extractName(dataInput)
      # Set up the track download:
      @buff = ''
      @startPoint = @endPoint = 0
      @chr = {}
      # Do APIs call on behalf of the user
      apicaller = WrapperApiCaller.new(host, "", @userId)
      # Downloading offset file to get the length of each chromosome
      chrHash = {}
      restPath1 = "/REST/v1/grp/{grp}/db/{db}/eps"
      # - Tack on gKey to db/eps request if we have one (~public resource or something)
      gbKey = @dbhelper.extractGbKey(dataInput)
      if(gbKey)
        restPath1 << "?gbKey=#{gbKey}"
      end
      # - do actual eps request
      apicaller.setRsrcPath(restPath1)
      apicaller.get({ :grp => @grp, :db  => @db })
      # - some sort of checking (there was none), although this should really inherit from ToolWrapper and use proper state variables for handling errors
      unless(apicaller.succeeded?)
        msg = "Failed to obtain chromosomes information from database #{@db.inspect} in group #{@grp.inspect}."
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{msg} ApiCaller response:\n\n#{apicaller.respBody.inspect}\n\n")
        raise msg
      end
      # - parse response to get at chromsome info
      eps = apicaller.parseRespBody()
      apicaller.apiDataObj['entrypoints'].each { |epsObj|
        chrHash[epsObj['name']] = epsObj['length']
      }
      @downloadFile = @trackhelper.getDataFileForTrack(dataInput, "fwig", @spanAggFunction, @resolution, "#{@outputDir}/tmp.#{@wigCount}.fwig.bz2", @userId.to_i, nil, "n/a", 5)
      if(@downloadFile)
        chrom = nil
        # Now weird naming suffix downstream tools seem to expect. Let's do it nice and safe:
        uriObj = URI.parse(dataInput)
        unescBasename = CGI.unescape(File.basename(uriObj.path))
        niceBasename = File.makeSafePath(unescBasename, :ultra)
        niceBasenameWithSuffix = "#{niceBasename}_N#{@wigCount}N"
        niceBasenameWithSuffixWig = "#{niceBasenameWithSuffix}.wig"
        @downloadedLFFDataFiles << niceBasenameWithSuffix
        @downloadedDataFiles    << niceBasenameWithSuffixWig
        lffFile = File.open("#{@outputDir}/#{niceBasenameWithSuffix}", "w+")
        wigFile = File.open("#{@outputDir}/#{niceBasenameWithSuffixWig}", "w+")
        # The static files are bzipped. We need to expand it if we got a static file.
        expander = BRL::Genboree::Helpers::Expander.new(@downloadFile)
        expander.extract()
        # Process file lines
        dataFile = File.open(expander.uncompressedFileName)
        dataFile.each_line { |line|
          line.strip!
          wigFile.puts line
          if(line =~ /fixedStep/) # a block header...go get chrom info and init @startPoint
            # Very poor parse of block header avps (not robust in face of extra spaces and such):
            blockHeader = line.split(/\s/)
            blockHeader.each { |avps|
              avpPair = avps.split(/=/)
              avpPair.map!{|xx| xx.strip }
              if(avpPair[0].strip == "chrom")
                chrom = avpPair[1].strip
              end
            }
            unless(@chr.has_key?(chrom))
              @chr[chrom] = true
              @startPoint = 1
            end
          end
          # non-block or track lines contain data and we need to update @endPoint as we see data
          # - we don't disover span/step from file because we asked for a certain @resolution in the request
          # - this seems vulnerable to last-block-on-chromosome which are shorter than @resolution...
          unless(line =~ /track/ or line =~ /fixedStep/)
            score = line # fixed step only has score
            @endPoint = @startPoint + ( @resolution - 1 ) # location is inclusive of start and end
            if(@endPoint > chrHash[chrom])
              @endPoint = chrHash[chrom]
            end
            lffFile.puts("#{@lffClass}\t#{chrom}:#{@startPoint}-#{@endPoint}\t#{@lffType}\t#{@lffSubType}\t#{chrom}\t#{@startPoint}\t#{@endPoint}\t+\t0\t#{score}")
            @startPoint = @endPoint + 1
          end
        }
        lffFile.close
        wigFile.close
        dataFile.close
      else
        msg = "Failed to download annotations fwig data for track: #{dataInput.inspect}."
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{msg} (output file = #{@downloadFile.inspect})")
        raise msg
      end
      @wigCount += 1
    }
  end

  # Lifts scores from a score track based on regions coming from the Regions of Interest (ROI) track
  # Download all files as bedGraph (static and dynamic)
  # For dynamic downloads (if static file absent), if checksum absent try downloading it 2 more times before generating error
  # [+returns+] nil
  def withROI()
    @dataInputs.each_index { |ii|
      dataInput = @dataInputs[ii]
      @type = "bedGraph"
      @downloadFile = @trackhelper.getDataFileForTrack(dataInput, @type, @spanAggFunction, @roiInput, "#{@outputDir}/tmp.#{@roiCount}.bedGraph.bz2", @userId.to_i, nil, "n/a", 5)
      if(@downloadFile)
        # The static files are bzipped. We need to expand it
        expander = BRL::Genboree::Helpers::Expander.new(@downloadFile)
        expander.extract()
        # Now weird naming suffix downstream tools seem to expect. Let's do it nice and safe:
        uriObj = URI.parse(dataInput)
        unescBasename = CGI.unescape(File.basename(uriObj.path))
        niceBasename = File.makeSafePath(unescBasename, :ultra)
        niceBasenameWithSuffix = "#{niceBasename}_N#{@roiCount}N"
        @downloadedLFFDataFiles << niceBasenameWithSuffix
        lffFile = File.open("#{@outputDir}/#{niceBasenameWithSuffix}", "w+")
        # Process file lines
        dataFile = File.open(expander.uncompressedFileName)
        # - skip header line
        dataFile.readline
        # - go through rest of bedGraph lines
        dataFile.each_line { |line|
          line.strip!
          fields = line.split(/\t/)
          lffFile.puts("#{@lffClass}\t#{niceBasename}\t#{@lffType}\t#{@lffSubType}\t#{fields[0]}\t#{fields[1]}\t#{fields[2]}\t+\t0\t#{fields[3]}")
        }
        dataFile.close()
        lffFile.close()
      else
        msg = "Failed to download annotations bedGraph data for track: #{dataInput.inspect}."
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{msg} (#{@downloadFile.inspect})")
        raise msg
      end
      @roiCount += 1
    }
  end

  ##Linear-regression and other statistical calculations
  def regression
    localErr = nil
    begin
      ## uploading summary file to specified location
      apicaller = WrapperApiCaller.new(@hostOutput, "", @userId)
      restPath = @pathOutput
      path = restPath + "/file/{resultsFolder}/{runName}/summary.txt/data"
      apicaller.setRsrcPath(path)
      infile = File.open("#{@outputDir}/summary.txt")
      apicaller.put({ :resultsFolder => 'Signal Comparison', :runName => @runName }, infile)
      infile.close unless(infile.closed?)
      if(apicaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully uploaded summary.txt to results folder.")
      else # error, try to get info
        msg = "Failed to upload summary.txt to results folder."
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{msg} ApiCaller response:\n\n#{apicaller.respBody.inspect}\n\n")
        @exitCode = 47
      end
      # Save rsrc path for later (in email stuff below it seems)
      @apiRSCRpath = apicaller.fillApiUriTemplate({ :resultsFolder => 'Signal Comparison', :runName => @runName })

      ##uploading lff file as a RAW FILE
	    restPath = @pathOutput
	    path = restPath + "/file/{resultsFolder}/{runName}/result.lff.gz/data"
      apicaller.setRsrcPath(path)
	    infile = File.open("#{@outputDir}/finalUploadSummary.lff.gz")
	    apicaller.put({ :resultsFolder => 'Signal Comparison', :runName => @runName }, infile)
	    if(apicaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully uploaded result.lff to results folder.")
	    else # error, try to get info
        msg = "Failed to upload summary.txt to results folder."
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{msg} ApiCaller response:\n\n#{apicaller.respBody.inspect}\n\n")
        @exitCode = 48
	    end
	    infile.close unless(infile.closed?)
      # Save rsrc path for later (in email stuff below it seems)
      @apiRSCRpathLff = apicaller.fillApiUriTemplate({ :resultsFolder => 'Signal Comparison', :runName => @runName })

      ##uploading lff file as ANNO TACK
      if(@uploadResults == true)
        # Get info about target database from database resource itself:
        path = "/REST/v1/grp/{grp}/db/{db}"
        apicaller.setRsrcPath(path)
        apicaller.get({ :grp => @grpOutput, :db => @dbOutput })
        if(apicaller.succeeded?)
          apicaller.parseRespBody()
          # This doesn't appear to be Genboree Network compatible.
          # - i.e. is it api-based upload or direct MySQL insert work?
          # - should we do it one way if local and another if remote (for flexibility and efficiency)
          uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
          uploadAnnosObj.refSeqId = apicaller.apiDataObj['refSeqId']
          uploadAnnosObj.groupName = @grpOutput
          uploadAnnosObj.userId = @userId
          uploadAnnosObj.jobId = @jobID
          # expand the lff we're going to upload as annos:
          exp = BRL::Genboree::Helpers::Expander.new("#{@outputDir}/finalUploadSummary.lff.gz")
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

      ##compose email from summary.txt
      track = 0
      @bufferResult = ""
      infile = File.open("#{@outputDir}/summary.txt")
      infile.each { |line|
        @bufferResult << "   #{line}\n"
      }
      infile.close
      num = track = 0
      body =
"
Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} job has completed successfully.

Job Summary:
  JobID                  : #{@jobID}
  Analysis Name          : #{@runNameOriginal}
  Input Tracks :
    #{CGI.unescape(File.basename(URI.parse(@dataInputs[0]).path))}
    #{CGI.unescape(File.basename(URI.parse(@dataInputs[1]).path))}"
      if(@haveROI)
        body << "
  ROI track:
    #{CGI.unescape(File.basename(URI.parse(@roiInput).path))}"
      end
      body << "
  Settings:
    spanAggFunction     : #{@spanAggFunction}
    removeNoDataRegions : #{@removeNoDataRegions}
    normalization  : #{@normalization}
    resolution          : #{@res}

Result File Location in the Genboree Workbench:
(Direct links to files are at the end of this email)
  Group : #{@grpOutput}
  DataBase : #{@dbOutput}
  Path to File:
      Files
      * Signal Comparison
       * #{@runNameOriginal}
         * summary.txt

"

      if(@uploadResults==true)
        body << "\n** The LFF file has been added to queue for uploading. You will shortly get a mail of its final status\n\n."
      end
      body << "
The Genboree Team


Result File URLs (click or paste in browser to access file):
    FILE: summary.txt
    URL:
http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{CGI.escape(@apiRSCRpath)}

    FILE: result.lff.gz
    URL:
http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{CGI.escape(@apiRSCRpathLff)}


"
      subject = "Genboree: Your #{@toolTitle} job is complete "
    rescue => err # something went wrong in uploading; send error email
      localErr = err
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "Message: #{err.message}\nBacktrace:\n#{err.backtrace.join("\n")}\n\n")
      body =
"
Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} job was unsuccessful.

Job Summary:
  JobID                  : #{@jobID}
  Analysis Name          : #{@runNameOriginal}
  Input Tracks :
    #{CGI.unescape(File.basename(URI.parse(@dataInputs[0]).path))}
    #{CGI.unescape(File.basename(URI.parse(@dataInputs[1]).path))}"
      if(@haveROI)
        body << "
  ROI track:
    #{CGI.unescape(File.basename(URI.parse(@roiInput).path))}"
      end
      body << "
  Settings:
    spanAggFunction     : #{@spanAggFunction}
    removeNoDataRegions : #{@removeNoDataRegions}
    normalization  : #{@normalization}
    resolution          : #{@res}

  Error Message : #{err.message}
  Exit Code     : #{@exitCode}

Please Contact Genboree team with the above information.


The Genboree Team"

      subject = "Genboree: Your #{@toolTitle} job is unsuccessfull "
    end
    # Now send error or success email
    if(!@email.nil?)
      sendEmail(subject,body)
    end
    # Re-raise any error rescued so this script will exit with correct status and job status is updated...
    # - really this is stupid and should be a ToolWrapper
    raise localErr if (localErr)
  end

  ##Email
  def sendEmail(subjectTxt, bodyTxt)
    email = BRL::Util::Emailer.new()
    email.setHeaders("genboree_admin@genboree.org", @email, subjectTxt)
    email.setMailFrom('genboree_admin@genboree.org')
    email.addRecipient(@email)
    email.addRecipient("genboree_admin@genboree.org")
    email.setBody(bodyTxt)
    email.send()
  end

  def PairWiseSimilarityWrapper.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "

    PROGRAM DESCRIPTION:
      Pairwise track score comparison tool

    COMMAND LINE ARGUMENTS:
      --jsonFile     | -j => Input json file
      --help         | -h => [Optional flag]. Print help info and exit.

    USAGE:
      ruby removeAdaptarsWrapper.rb -f jsonFile

"
      exit
  end

    # Process Arguements form the command line input
    def PairWiseSimilarityWrapper.processArguements()
      # We want to add all the prop_keys as potential command line options
      optsArray = [
                    ['--jsonFile', '-j', GetoptLong::REQUIRED_ARGUMENT],
                    ['--help',     '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      PairWiseSimilarityWrapper.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
      PairWiseSimilarityWrapper.usage if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end
end

# ------------------------------------------------------------------
# MAIN - this should be a ToolWrapper subclass!!!!!
# ------------------------------------------------------------------
optsHash = PairWiseSimilarityWrapper.processArguements()
pairWiseSimilarityWrapper = PairWiseSimilarityWrapper.new(optsHash)
pairWiseSimilarityWrapper.work()
