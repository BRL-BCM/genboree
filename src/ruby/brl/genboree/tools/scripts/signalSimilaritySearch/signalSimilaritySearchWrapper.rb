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
require 'brl/normalize/index_sort'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/helpers/expander'
include GSL
include BRL::Genboree::REST

class SignalSimilarityWrapper

  attr_accessor :user_first, :user_last, :toolTitle, :exitCode, :apiExitCode, :input, :email
  attr_accessor :jobID, :runNameOriginal, :noCommonRegionsCount

  def initialize(optsHash)
    @input    = File.expand_path(optsHash['--jsonFile'])
    jsonObj 	= JSON.parse(File.read(@input))
    jsonObj = addToolTitle(jsonObj)
    @input  	= jsonObj["inputs"]
    ############################## For testing :##################################
    #tmpInput = []
    #@input.size.times { |ii|
    #  tmpInput[ii] = @input[ii]
    #  break if(ii == 52)
    #}
    #@input = tmpInput
    #@input[0] = "http://valine.brl.bcmd.bcm.edu/REST/v1/grp/Epigenomics%20Roadmap%20Repository/db/Release%204%20Repository/trk/ADMSC%3AH3K27me3%201?"
    #@input[@input.size - 1] = "http://valine.brl.bcmd.bcm.edu/REST/v1/grp/ROI%20Repository/db/ROI%20Repository%20-%20hg19/trk/GeneModel%3AExon?"
    #@input[@input.size - 1] = "http://valine.brl.bcmd.bcm.edu/REST/v1/grp/ROI%20Repository/db/ROI%20Repository%20-%20hg19/trk/GeneModel%3A5%27UTR?"
    ##################################################################################
    @toolIdStr          = jsonObj['context']['toolIdStr']
    @toolConf           = BRL::Genboree::Tools::ToolConf.new(@toolIdStr)
    @output 	= jsonObj["outputs"][0]
    @noCommonRegionsCount = 0
    @gbConfFile 	= jsonObj["context"]["gbConfFile"]
    @apiDBRCkey 	= jsonObj["context"]["apiDbrcKey"]
    @scratch 		= jsonObj["context"]["scratchDir"]
    @email 		= jsonObj["context"]["userEmail"]
    @user_first 	= jsonObj["context"]["userFirstName"]
    @user_last 	= jsonObj["context"]["userLastName"]
    @username 	= jsonObj["context"]["userLogin"]

    @toolIdStr = jsonObj['context']['toolIdStr']
    @genbConf = BRL::Genboree::GenboreeConfig.load(ENV['GENB_CONFIG'])
    @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr, @genbConf)
    @toolTitle = @toolConf.getSetting('ui', 'label')

    @gbAdminEmail 	= jsonObj["context"]["gbAdminEmail"]
    @jobID 		= jsonObj["context"]["jobId"]
    @userId 		= jsonObj["context"]["userId"]
    @prefix	 	= jsonObj["context"]["toolScriptPrefix"]

    @spanAggFunction 	= jsonObj["settings"]["spanAggFunction"]
    @removeNoDataRegions = jsonObj["settings"]["removeNoDataRegions"]
    @ranknNormalized 	= jsonObj["settings"]["rankNormalized"]
    @normalization = jsonObj["settings"]["normalization"]
    @runName 		= jsonObj["settings"]["analysisName"]
    @ROItrack 	= jsonObj["settings"]["useGenboreeRoiScores"]
    #@ROItrack = true
    @res 		= jsonObj["settings"]["resolution"]
    case jsonObj["settings"]["resolution"]
    when "high"
      @resolution = 1000
    when "medium"
      @resolution = 10000
    when "low"
      @resolution = 100000
    else
      @resolution = 10000
    end

    @runNameOriginal 	= @runName
    @runName 		= CGI.escape(@runName)

    @grph 		= BRL::Genboree::REST::Helpers::GroupApiUriHelper.new()
    @dbhelper 	= BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
    @trackhelper 	= BRL::Genboree::REST::Helpers::TrackApiUriHelper.new()

    ##pulling out upload location specifications
    @output 		= @output.chomp('?')
    @dbOutput 	= @dbhelper.extractName(@output)
    @grpOutput 	= @grph.extractName(@output)
    uriOutput 	= URI.parse(@output)
    @hostOutput 	= uriOutput.host
    @pathOutput 	= uriOutput.path

    @uri 	= @grph.extractPureUri(@output)
    dbrc 	= BRL::DB::DBRC.new(nil, @apiDBRCkey)
    @pass 	= dbrc.password
    @user 	= dbrc.user
    @uri 	= URI.parse(@input[0])
    @host 	= @uri.host
    @exitCode	= ""
    @apiExitCode = ""
    @wigCount = 0
    @roiCount = 0
    @downloadTime = 0
    @downloadFile = nil

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
    @filewrite = File.open("#{@outputDir}/summary.txt","w+")
    @filewrite.puts "Track\tCorrelation\tSum of Square of Residual\tIntercept\tSlope\tChiSquare\tRMSEA\tF-Value"
    @filewrite.close
    if(@ROItrack == false)
      wigDownload(@input[0])
      queryTrack = "#{File.basename(@input[0].chomp('?'))}_N#{0}N.gz"
      for i in 1...@input.size
        wigDownload(@input[i])
        targetTrack = "#{File.basename(@input[i].chomp('?'))}_N#{@wigCount - 1}N.gz"
        runTool(queryTrack, targetTrack , "Wig")
        `rm -f #{@downloadFile}`
      end
    else
      @input[@input.size-1] = @input[@input.size-1].chomp('?')
      @dbROI    = @dbhelper.extractName(@input[@input.size-1])
      @grpROI   = @grph.extractName(@input[@input.size-1])
      @trkROI   = @tkOutput = @trackhelper.extractName(@input[@input.size-1])
      withROI(@input[0])
      queryTrack = "#{File.basename(@input[0].chomp('?'))}_N#{0}N.gz"
      for i in 1...@input.size-1
        withROI(@input[i])
        targetTrack = "#{File.basename(@input[i].chomp('?'))}_N#{@roiCount - 1}N.gz"
        runTool(queryTrack, targetTrack , "Lff")
        `rm -f #{@downloadFile}`
      end
    end
    uploads()
    sendSuccessEmail()
    $stderr.debugPuts(__FILE__, __method__, "TIME", "Total Download Time: #{@downloadTime} seconds")
  end


  ## run signalSimilaritySearch tool
  # [+file1+]
  # [+file2+]
  # [+format+]
  # [+returns+] nil
  def runTool(file1, file2 , format)
    command = "#{@prefix}signalSimilaritySearch.rb -f "
    command << " '#{file1},#{file2}' "
    command << "-o  #{@scratch}  -a #{@runName} -s #{@scratch} -F #{format} -c #{@removeNoDataRegions} -r #{@resolution} -q #{@normalization} --deleteFiles >> signalSimilaritySearch.out 2>> signalSimilaritySearch.err"
    $stdout.puts command
    system(command)
    exitObj = $?.dup
    if(!exitObj.success? or exitObj.exitstatus != 0)
      if(exitObj.exitstatus == 118 or exitObj.exitstatus == 119)
        @noCommonRegionsCount += 1
      else
        @exitCode = $?.exitstatus
        raise "The signal search tool has failed to run correctly."
      end
    end
  end


  ## When there is no ROI track, download the score track in wig format
  # [+track+] REST URI for a track
  # [+returns+] nil
  def wigDownload(track)
    #resolution = 1000
    track = track.chomp('?')
    @db  = @dbhelper.extractName(track)
    @grp = @grph.extractName(track)
    @trk  = @trackhelper.extractName(track)
    uri = URI.parse(track)
    host = uri.host
    # Check if a static file is available for the track.
    # If not, do a dynamic download
    tt = Time.now
    @downloadFile = @trackhelper.getDataFileForTrack(track, "fwig", @spanAggFunction, @resolution, "#{@outputDir}/tmp.#{@wigCount}.fwig.bz2", @userId.to_i, nil, "n/a", 5)
    @downloadTime += (Time.now - tt)
    if(@downloadFile)
      @buff = ''
      saveFile = File.open("#{@outputDir}/#{File.basename(track)}_N#{@wigCount}N","w+")
      saveFile2 = File.open("#{@outputDir}/#{File.basename(track)}_N#{@wigCount}N.wig","w+")
      # The static files are bzipped. We need to expand it
      expander = BRL::Genboree::Helpers::Expander.new(@downloadFile)
      expander.extract()
      bzipReader = BRL::Util::TextReader.new(expander.uncompressedFileName)
      bzipReader.each_line  { |line|
        saveFile2.write line
        unless(line =~ /track/ or line =~ /fixedStep/)
          score = line.strip
          saveFile.write("#{@lffClass}\t\t\t\t\t\t\t\t\t#{score}\n") # Transform into lff to protect legacy code
        end
      }
      saveFile.close
      saveFile2.close
      bzipReader.close()
      `rm -rf #{expander.tmpDir}`
    else
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not download file for track: #{track.inspect}")
      raise "Could not download file for track: #{track.inspect}"
    end
    Dir.chdir(@outputDir)
    ## Zipping files
    system("gzip  #{File.basename(track)}_N#{@wigCount}N")
    Dir.chdir(@scratch)
    @wigCount += 1
  end


  ## When there is a ROI track
  # [+track+] REST URI for a track
  # [+returns+] nil
  def withROI(track)
    track = track.chomp('?')
    uri = URI.parse(track)
    host = uri.host
    # Check if a static file is available for the track.
    # If not, do a dynamic download
    tt = Time.now
    @downloadFile = @trackhelper.getDataFileForTrack(track, "bedGraph", @spanAggFunction, @input.last, "#{@outputDir}/tmp.#{@roiCount}.bedGraph.bz2", @userId.to_i, nil, "n/a", 5)
    @downloadTime += (Time.now - tt)
    if(@downloadFile)
      @buff = ''
      skipFirst = 1
      # The static files are bzipped. We need to expand it
      expander = BRL::Genboree::Helpers::Expander.new(@downloadFile)
      expander.extract()
      bzipReader = BRL::Util::TextReader.new(expander.uncompressedFileName)
      saveFile = File.open("#{@outputDir}/#{File.basename(track)}_N#{@roiCount}N","w+")
      bzipReader.each_line { |line|
        if(skipFirst > 1)
          line.strip!
          fields = line.split(/\t/)
          saveFile.write("#{@lffClass}\t#{File.basename(track)}\t\t\t#{fields[0]}\t#{fields[1]}\t#{fields[2]}\t+\t0\t#{fields[3]}\n")
        end
        skipFirst += 1
      }
      bzipReader.close()
      saveFile.close()
      `rm -rf #{expander.tmpDir}`
    else
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not download file for track: #{track.inspect}")
      raise "Could not download file for track: #{track.inspect}"
    end
    Dir.chdir(@outputDir)
    system("gzip  #{File.basename(track)}_N#{@roiCount}N")
    Dir.chdir(@scratch)
    @roiCount += 1
  end

    ##upload summary
  def uploads
    ## uploading summary file to specified location
    apicaller = WrapperApiCaller.new(@hostOutput, "", @userId)
    restPath = @pathOutput
    path = restPath +"/file/#{CGI.escape('Signal Search')}/#{@runName}/summary.txt/data"
    path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
    apicaller.setRsrcPath(path)
    infile = File.open("#{@outputDir}/summary.txt","r")
    apicaller.put(infile)
    if apicaller.succeeded?
      $stdout.puts "successfully uploaded summary.txt"
    else
      apicaller.parseRespBody()
      $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
      @exitCode = apicaller.apiStatusObj['statusCode']
      raise "#{apicaller.apiStatusObj['msg']}"
    end
    uploadedPath = restPath+"/file/#{CGI.escape('Signal Search')}/#{@runName}/summary.txt"
    @apiRSCRpath = CGI.escape(uploadedPath)
    infile.close
    track = 0
    @bufferResult = ""
    infile = File.open("#{@outputDir}/summary.txt","r")
    while(line = infile.gets)
      if(track ==10)
         break
      end
      columns = line.split(/\t/)
      @bufferResult << "   #{columns[0]}\t#{columns[1]}\n"
      track += 1
    end
    infile.close
  end


   def sendSuccessEmail()
      num = 0
      body =
"
Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} job completed successfully.

Job Summary:
   JobID                  : #{@jobID}
   Analysis Name          : #{@runNameOriginal}
   Query File             : #{CGI.unescape(File.basename(@input[0]))}
   Target Files           :"
  if(@ROItrack == true)
   num = @input.size-2
  else
    num = @input.size-1
  end
  body<<" #{num}"
  if(@ROItrack == true)
      body <<"
   ROITrack               : #{CGI.unescape(File.basename(@input[@input.size-1]))}"
    else
      body <<"
   ROITrack               : No ROI Track"
    end

    body <<"

Settings:
   SpanAggFunction        : #{@spanAggFunction}
   RemoveNoDataRegions    : #{@removeNoDataRegions}
   Normalization     : #{@normalization}
   Resolution             : #{@res}\n\n"
  if(@noCommonRegionsCount > 0)
    if(@noCommonRegionsCount == (@input.size - 1))
      body << "Unfortunately, NONE of the target tracks have regions that overlap your query track. No valid data can be obtained.\n\nThe Genboree Team"
    else
      body << "NOTE: some of the target tracks have no regions in common with your query track."
    end
  end

  if(@noCommonRegionsCount != (@input.size - 1))
    body <<"

Top Results:
#{@bufferResult}"

    if(@input.size > 11)
      body<<"

Complete summary report can be downloaded from the link given in the end of the mail.
   "
    end


      body <<"

Result File Location in the Genboree Workbench:
(Direct links to files are at the end of this email)
   Group : #{@grpOutput}
   DataBase : #{@dbOutput}
   Path to File:
      Files
      * Signal Search
       * #{@runNameOriginal}
         * summary.txt

The Genboree Team

Result File URLs (click or paste in browser to access file):
    FILE: summary.txt
    URL:
http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpath}/data "
  end

      subject = "Genboree: Your #{@toolTitle} job is complete "


       if (!@email.nil?) then
             sendEmail(@email,subject,body)
       end
       ##Removing left over stuff
       system('find . -name *.gz -exec rm {} \;')
       system('find . -name *_N* -exec rm {} \;')
   end


   def self.sendFailureEmail(err,workObj)
      user_first = (workObj ? workObj.user_first : "n/a")
      user_last = (workObj ? workObj.user_last : "n/a")
      toolTitle = (workObj ? workObj.toolTitle : "n/a")
      input = (workObj ? workObj.input : "n/a")
      exitCode = (workObj ? workObj.exitCode : "n/a")
      apiExitCode = (workObj ? workObj.apiExitCode : "n/a")
      email = (workObj ? workObj.email : "n/a")
      jobID = (workObj ? workObj.jobID : "n/a")
      runNameOriginal = (workObj ? workObj.runNameOriginal : "n/a")
      body =
"
Hello #{user_first.capitalize} #{user_last.capitalize}

Your #{toolTitle} job is unsuccessful.

Job Summary:
  JobID : #{jobID}
   Analysis Name : #{runNameOriginal}
   Query Track :
      #{CGI.unescape(File.basename(input[0]))}


      Error Message : #{err.message}
      Exit Status   : #{exitCode}
"
   if(apiExitCode != "")
      body <<"      Api Exit Status   : #{apiExitCode}
"	 end
      body <<"

Please Contact Genboree team with above information.


The Genboree Team"

      subject = "Genboree: Your #{toolTitle} job is unsuccessful "

    if(!email.nil?)
       self.sendEmail(email,subject,body)
    end
  end

  ##Email
  def sendEmail(emailTo, subjectTxt, bodyTxt)
     self.class.sendEmail(emailTo, subjectTxt,bodyTxt )
  end

  def self.sendEmail(emailTo, subjectTxt,bodyTxt )

    genbConf = ENV['GENB_CONFIG']
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    email = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)
    $stdout.puts "email #{emailTo}"
    email = BRL::Util::Emailer.new()
    email.setHeaders("genboree_admin@genboree.org", emailTo, subjectTxt)
    email.setMailFrom('genboree_admin@genboree.org')
    email.addRecipient(emailTo)
    email.addRecipient("genboree_admin@genboree.org")
    email.addHeader("Bcc: #{emailTo}")
    email.setBody(bodyTxt)
    email.send()
  end


   def SignalSimilarityWrapper.usage(msg='')
          unless(msg.empty?)
            puts "\n#{msg}\n"
          end
          puts "

        PROGRAM DESCRIPTION:
           Pairwise epigenome comparison tool
        COMMAND LINE ARGUMENTS:
          --file         | -j => Input json file
          --help         | -h => [Optional flag]. Print help info and exit.

       usage:

      ruby removeAdaptarsWrapper.rb -f jsonFile

        ";
            exit;
        end #

      # Process Arguements form the command line input
      def SignalSimilarityWrapper.processArguements()
        # We want to add all the prop_keys as potential command line options
          optsArray = [ ['--jsonFile' ,'-j', GetoptLong::REQUIRED_ARGUMENT],
                        ['--help'     ,'-h', GetoptLong::NO_ARGUMENT]
                      ]
          progOpts = GetoptLong.new(*optsArray)
          SignalSimilarityWrapper.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
          optsHash = progOpts.to_hash

          Coverage if(optsHash.empty? or optsHash.key?('--help'));
          return optsHash
      end

end
tt = Time.now
optsHash = performQCUsingFindPeaks = nil
wrapperExitCode = 0
begin
   optsHash = SignalSimilarityWrapper.processArguements()
   performQCUsingFindPeaks = SignalSimilarityWrapper.new(optsHash)
   performQCUsingFindPeaks.work()
   #SignalSimilarityWrapper.sendSuccessEmail(performQCUsingFindPeaks)
   wrapperExitCode = 0
rescue Exception => err
   SignalSimilarityWrapper.sendFailureEmail(err,performQCUsingFindPeaks)
   $stderr.puts "ERROR: #{err}\n\nERROR Stacktrace: #{err.backtrace.join("\n")}"
   wrapperExitCode = 14
end
$stderr.debugPuts(__FILE__, __method__, "TIME (TOTAL)", "#{Time.now - tt} seconds")
exit(wrapperExitCode)
