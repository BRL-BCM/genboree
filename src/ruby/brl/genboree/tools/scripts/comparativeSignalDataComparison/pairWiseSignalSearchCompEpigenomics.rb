#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/genboree/rest/apiCaller'
require 'brl/normalize/index_sort'
require 'brl/genboree/helpers/sortByAttribute'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/projectApiUriHelper'

include GSL
include BRL::Genboree::REST


class PairWiseSimilarityWrapper

  def initialize(optsHash)
    @input    = File.expand_path(optsHash['--jsonFile'])
    jsonObj = JSON.parse(File.read(@input))
    @input  = jsonObj["inputs"]
    @output = jsonObj["settings"]['dependentDb'] # Always present (both dependent and independent dbs set in the job helper since we cannot trust the order)
    @altOutput = nil
    @altOutput = jsonObj['settings']['independentDb'] if(jsonObj['outputs'].size == 2) # May or may not be there
    @gbConfFile = jsonObj["context"]["gbConfFile"]
    @apiDBRCkey = jsonObj["context"]["apiDbrcKey"]
    @scratch = jsonObj["context"]["scratchDir"]
    @email = jsonObj["context"]["userEmail"]
    @user_first = jsonObj["context"]["userFirstName"]
    @user_last = jsonObj["context"]["userLastName"]
    @username = jsonObj["context"]["userLogin"]
    
    # set toolTitle and shortToolTitle
    @genbConf = BRL::Genboree::GenboreeConfig.load(ENV['GENB_CONFIG'])
    @toolIdStr = jsonObj['context']'toolIdStr']
    @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr, @genbConf)
    @toolTitle = @toolConf.getSetting('ui', 'label')
    @shortToolTitle = @toolConf.getSetting('ui', 'shortLabel')
    @shortToolTitle = @toolTitle if(@shortToolTitle == "[NOT SET]")

    @gbAdminEmail = jsonObj["context"]["gbAdminEmail"]
    @jobID = jsonObj["context"]["jobId"]
    @userId = jsonObj["context"]["userId"]
    
    @spanAggFunction = jsonObj["settings"]["spanAggFunction"]
    @removeNoDataRegions = jsonObj["settings"]["removeNoDataRegions"]
    @ranknNormalized = jsonObj["settings"]["rankNormalized"]
    @quantileNormalized = jsonObj["settings"]["quantileNormalized"]   
    @runName = jsonObj["settings"]["analysisName"]
    @studyName = jsonObj['settings']['studyName']
    @uploadResults = jsonObj["settings"]["uploadFile"]
    @lffClass = jsonObj["settings"]["lffClass"]
    @lffType = jsonObj["settings"]["lffType"]
    @lffSubType = jsonObj["settings"]["lffSubType"]
    @ROItrack = jsonObj["settings"]["useGenboreeRoiScores"]
    @res = jsonObj["settings"]["resolution"]
    case jsonObj["settings"]["resolution"]
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
    @toolScriptPrefix = jsonObj['context']['toolScriptPrefix']
    @runNameOriginal = @runName
    @runName = CGI.escape(@runName)
    
    @grph = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
    @dbhelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
    @trackhelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@gbConfFile)
    
    ##pulling out upload location specifications
    @output = @output.chomp('?')
    @dbOutput = @dbhelper.extractName(@output)
    @grpOutput = @grph.extractName(@output)
    uriOutput = URI.parse(@output)
    @hostOutput = uriOutput.host
    @pathOutput = uriOutput.path
       
    @uri = @grph.extractPureUri(@output)
    dbrc = BRL::DB::DBRC.new(nil, @apiDBRCkey)
    @pass = dbrc.password
    @user = dbrc.user
    @uri = URI.parse(@input[0])
    @host = @uri.host
    @exitCode= ""   
  end
   
   # Downloads score track with regions from Regions of Interest (ROI) Track.
   # [+returns+] nil
   def work
    system("mkdir -p #{@scratch}")
    Dir.chdir(@scratch)
    @outputDir = "#{@scratch}/signal-search/#{@runName}"
    system("mkdir -p #{@outputDir}")
    withROI()
    sortFiles()
    command = "module load gnuplot/4.4; #{@toolScriptPrefix}pairWiseSignalSearchCompEpigenomicsTool.rb -f 'sorted_depScores.lff,sorted_indepScores.lff' -F Lff "
    command << " -o  #{@scratch}  -a #{@runName} -s #{@scratch} -c #{@removeNoDataRegions} -r #{@resolution} -q #{@quantileNormalized}"
    command << " -l '#{@lffClass}' -L '#{@lffType}' -S '#{@lffSubType}'"
    $stdout.puts command
    system("#{command} > logs")
    if(!$?.success?)
      @exitCode = $?.exitstatus
      raise "CRITICAL ERROR: #{@toolScriptPrefix}pairWiseSignalSearchCompEpigenomicsTool.rb failed."
    end
    regression()
   end
  
  # Sorts downloaded lff files using attribute 'conservedRegionID'
  # [+returns+] nil
  def sortFiles()
    sortByAttObj = BRL::Genboree::Helpers::SortByAttribute.new("#{@outputDir}/depScores.lff", "conservedRegionID")
    sortByAttObj.sortByAtt()
    sortByAttObj = BRL::Genboree::Helpers::SortByAttribute.new("#{@outputDir}/indepScores.lff", "conservedRegionID")
    sortByAttObj.sortByAtt()
  end
  
  # Downloads both sets of scores:
  # Dependent regions of interest with scores lifted from the dependent score track 
  # InDependent regions of interest with scores lifted from the independent score track
  # [+returns+] nil
  def withROI
    # First Download dependent roi track with scores lifted from dependent score track
    dependentROITrack = @input[0]
    dependentScoreTrack = @input[1]
    uri = URI.parse(dependentROITrack)
    host = uri.host
    rcscUri = uri.path.chomp("?")
    @depScoresFile = "#{@outputDir}/depScores.lff"
    writer = File.open(@depScoresFile, "w")
    apiCaller = ApiCaller.new(host, "#{rcscUri}/annos?format=lff&scoreTrack={scrTrack}&spanAggFunction={span}&emptyScoreValue={esValue}", @user, @pass)
    apiCaller.get(
                    :scrTrack => dependentScoreTrack.chomp('?'),
                    :esValue  => "4290772992",
                    :span     => @spanAggFunction
                  ) { |chunk| writer.print(chunk)}
    writer.close()
    # Next download the independent roi track with the scores lifted from the independent score track
    independentROITrack = @input[2]
    independentScoreTrack = @input[3]
    uri = URI.parse(independentROITrack)
    host = uri.host
    rcscUri = uri.path.chomp("?")
    @indepScoresFile = "#{@outputDir}/indepScores.lff"
    writer = File.open(@indepScoresFile, "w")
    apiCaller = ApiCaller.new(host, "#{rcscUri}/annos?format=lff&scoreTrack={scrTrack}&spanAggFunction={span}&emptyScoreValue={esValue}", @user, @pass)
    apiCaller.get(
                    :scrTrack => independentScoreTrack.chomp('?'),
                    :esValue  => "4290772992",
                    :span     => @spanAggFunction
                  ) { |chunk| writer.print(chunk)}
    writer.close()
  end    
    
  
    ##Linear-regression and other statistical calculations
  def regression      
    begin
      ## uploading summary file to specified location
      apicaller =ApiCaller.new(@hostOutput,"",@user,@pass)
      restPath = @pathOutput
      parentDir = CGI.escape("Comparative Epigenomics")
      path = restPath +"/file/#{parentDir}/#{@studyName}/Signal-Comparison/#{@runName}/summary.txt/data"
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
      uploadedPath = restPath+"/file/#{parentDir}/#{@studyName}/Signal-Comparison/#{@runName}/summary.txt"
      @apiRSCRpath = CGI.escape(uploadedPath)
          
          
      ##uploading lff file as a file
      restPath = @pathOutput
      path = restPath +"/file/#{parentDir}/#{@studyName}/Signal-Comparison/#{@runName}/result.lff.gz/data"
      apicaller.setRsrcPath(path)
      infile = File.open("#{@outputDir}/finalUploadSummary.lff.gz","r")
      apicaller.put(infile)
	    if apicaller.succeeded?
        $stdout.puts "successfully uploaded lff file" 
      else
        $stdout.puts apicaller.parseRespBody()
        $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
        @exitCode = apicaller.apiStatusObj['statusCode']
        raise "#{apicaller.apiStatusObj['msg']}"
     end
      uploadedPathLff = restPath+"/file/#{parentDir}/#{@studyName}/Signal-Comparison/#{@runName}/result.lff.gz"
      @apiRSCRpathLff = CGI.escape(uploadedPathLff)        
          
          
      ##uploading lff file as track
      if(@uploadResults == true)
        path = "/REST/v1/grp/#{CGI.escape(@grpOutput)}/db/#{CGI.escape(@dbOutput)}/annos?userId=#{@userId}"
        apicaller.setRsrcPath(path)
        infile = File.open("#{@outputDir}/finalUploadSummary.lff.gz","r")
        apicaller.put({}, infile)
        if apicaller.succeeded?
          $stdout.puts "successfully uploaded track in dependent db" 
        else
          $stdout.puts apicaller.parseRespBody()
          $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
          @exitCode = apicaller.apiStatusObj['statusCode']
          raise "#{apicaller.apiStatusObj['msg']}"
        end
        # If outputs.size == 2, we need to upload the track into the independent db as well.
        if(@altOutput)
          infile.close
          infile = File.open("#{@outputDir}/finalUploadSummary.lff.gz","r")
          uri = URI.parse(@altOutput)
          rcscUri = uri.path.chomp("?")
          apicaller = ApiCaller.new(uri.host, "#{rcscUri}/annos?format=lff&userId=#{@userId}", @user, @pass)
          apicaller.put({}, infile)
          if(apicaller.succeeded?)
            $stdout.puts "successfully uploaded track in independent db" 
          else
            $stdout.puts apicaller.parseRespBody()
            $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
            @exitCode = apicaller.apiStatusObj['statusCode']
            raise "#{apicaller.apiStatusObj['msg']}"
          end
        end
      end
      infile.close
      track = 0
      @bufferResult = ""
      infile = File.open("#{@outputDir}/summary.txt","r")
      while(line = infile.gets)
        @bufferResult << "   #{line}\n"
      end
      infile.close
      num = 0
      body = 
"Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} job has completed successfully.

Job Summary:
   JobID                  : #{@jobID}
   Analysis Name          : #{@runNameOriginal}
    Input Files :
      #{CGI.unescape(File.basename(@input[0]))}
      #{CGI.unescape(File.basename(@input[1]))}"
   if(@input.size ==3)
      body <<"
   ROI track:
      #{CGI.unescape(File.basename(@input[2]))}"
   end
   body <<"
   Settings:
      spanAggFunction     : #{@spanAggFunction}
      removeNoDataRegions : #{@removeNoDataRegions}
      quantileNormalized  : #{@quantileNormalized}
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
	  
      if (@uploadResults==true)
        body <<
"
  **lff file has been added to queue for uploading. You will shortly get a mail of its final status.

"
      end

      body << 
"The Genboree Team

Result File URLs (click or paste in browser to access file):
    FILE: summary.txt
    URL: 
http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpath}/data
    
    FILE: result.lff.gz
    URL: 
http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpathLff}/data


"
       
      subject = "Genboree: Your #{@toolTitle} job is complete "
    rescue => err
      $stderr.puts "Deatils: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      body =  
"Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} job is unsucessfull.

Job Summary:
  JobID : #{@jobID}
   Analysis Name : #{@runNameOriginal}
   Query Track :
      #{CGI.unescape(File.basename(@input[0]))}
   Target Track :
    #{CGI.unescape(File.basename(@input[1]))}
  
      Error Message : #{err.message}
      Exit Status   : #{@exitCode}
Please Contact Genboree team with above information. 
        

The Genboree Team
"
      
      subject = "Genboree: Your #{@toolTitle} job is unsuccessfull "
    end
    if(!@email.nil?)
      sendEmail(subject,body)
    end
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
       Pairwise epigenome comparison tool
    COMMAND LINE ARGUMENTS:
      --file         | -j => Input json file
      --help         | -h => [Optional flag]. Print help info and exit.
  
    usage:
     
    ruby removeAdaptarsWrapper.rb -f jsonFile  
    
      ";
    exit;
  end
      
  # Process Arguements form the command line input
  def PairWiseSimilarityWrapper.processArguements()
    # We want to add all the prop_keys as potential command line options
    optsArray = [ ['--jsonFile' ,'-j', GetoptLong::REQUIRED_ARGUMENT],
                  ['--help'      ,'-h',GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    PairWiseSimilarityWrapper.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash
  
    Coverage if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end 

end

optsHash = PairWiseSimilarityWrapper.processArguements()
performQCUsingFindPeaks = PairWiseSimilarityWrapper.new(optsHash)
performQCUsingFindPeaks.work()
