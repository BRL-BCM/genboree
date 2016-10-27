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
require 'brl/genboree/rest/helpers/trackApiUriHelper'
include GSL
include BRL::Genboree::REST


class SignalSimilarityWrapper

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
    @toolScriptPrefix = jsonObj['context']['toolScriptPrefix']
    
    @spanAggFunction = jsonObj["settings"]["spanAggFunction"]
    @removeNoDataRegions = jsonObj["settings"]["removeNoDataRegions"]
    @ranknNormalized = jsonObj["settings"]["rankNormalized"]
    @quantileNormalized = jsonObj["settings"]["quantileNormalized"]   
    @runName = jsonObj["settings"]["analysisName"]
    @ROItrack = jsonObj["settings"]["useGenboreeRoiScores"]
    @res = jsonObj["settings"]["resolution"]
    @studyName = jsonObj['settings']['studyName']
    
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
    command = "#{@toolScriptPrefix}signalSimilarityCompEpigenomicsSearch.rb -f '#{@depSortedFile}.zip"
    @indepScoresFiles.each { |indepScoreFile|
      command << ",sorted_#{File.basename(indepScoreFile)}.zip"
    }
    command << "'"
    command << " -o  #{@scratch}  -a #{@runName} -s #{@scratch} -F Lff -c #{@removeNoDataRegions} -r #{@resolution} -q #{@quantileNormalized}"
    $stdout.puts command
    system("#{command} > logs")
    if(!$?.success?)
      @exitCode = $?.exitstatus
      raise "#{@toolScriptPrefix}signalSimilarityCompEpigenomicsSearch.rb Failed."
    end
    regression()
  end
   
  # Sorts downloaded lff files using attribute 'conservedRegionID'
  # [+returns+] nil
  def sortFiles()
    sortByAttObj = BRL::Genboree::Helpers::SortByAttribute.new("#{@outputDir}/depScores.lff", "conservedRegionID")
    sortByAttObj.sortByAtt()
    @depSortedFile = File.basename(sortByAttObj.sortedFile)
    Dir.chdir(@outputDir)
    system("zip -m #{@depSortedFile}.zip #{@depSortedFile}")
    Dir.chdir(@scratch)
    @indepScoresFiles.each { |indepScoreFile|
      sortByAttObj = BRL::Genboree::Helpers::SortByAttribute.new("#{indepScoreFile}", "conservedRegionID")
      sortByAttObj.sortByAtt()
      sortedFile = File.basename(sortByAttObj.sortedFile)
      Dir.chdir(@outputDir)
      system("zip -m #{sortedFile}.zip #{sortedFile}")
      Dir.chdir(@scratch)
    }
  end 
  

  # Downloads both sets of scores:
  # Dependent regions of interest with scores lifted from the dependent score track 
  # InDependent regions of interest with scores lifted from the independent score track(s)
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
    # Next download the independent roi track with the scores lifted from the independent score track(s)
    independentROITrack = @input[2]
    @indepScoresFiles = []
    uri = URI.parse(independentROITrack)
    host = uri.host
    rcscUri = uri.path.chomp("?")
    fileCount = 0
    @trkApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new()
    for ii in 3..@input.size - 1
      independentScoreTrack = @input[ii]
      @indepScoresFiles.push("#{@outputDir}/#{CGI.escape(@trkApiHelper.extractName(@input[ii]))}_#{fileCount}.lff")
      writer = File.open(@indepScoresFiles[fileCount], "w")
      apiCaller = ApiCaller.new(host, "#{rcscUri}/annos?format=lff&scoreTrack={scrTrack}&spanAggFunction={span}&emptyScoreValue={esValue}", @user, @pass)
      apiCaller.get(
                      :scrTrack => independentScoreTrack.chomp('?'),
                      :esValue  => "4290772992",
                      :span     => @spanAggFunction
                    ) { |chunk| writer.print(chunk)}
      writer.close()
      fileCount += 1
    end
  end    
    
    ##Linear-regression and other statistical calculations
   def regression            
      begin  
	 ## uploading summary file to specified location
         apicaller =ApiCaller.new(@hostOutput,"",@user,@pass)
         restPath = @pathOutput
         path = restPath +"/file/#{CGI.escape('Comparative Epigenomics')}/#{@studyName}/Signal-Search/#{@runName}/summary.txt/data"
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
         uploadedPath = restPath+"/file/#{CGI.escape('Comparative Epigenomics')}/#{@studyName}/Signal-Search/#{@runName}/summary.txt"
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
         num = 0
               body =
"
Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} job is completed successfully.

Job Summary:
   JobID                                       : #{@jobID}
   Analysis Name                               : #{@runNameOriginal}
   Query Regions-of-interest Track             : #{@trkApiHelper.extractName(@input[0])}
   Query Score Track                           : #{@trkApiHelper.extractName(@input[1])}
   Target Regions-of-interest Track            : #{@trkApiHelper.extractName(@input[2])}
   Target Score Tracks                         :"
   num = @input.size-3
  body<<" #{num}"
   
    body <<"
    
Settings:
   SpanAggFunction        : #{@spanAggFunction}
   RemoveNoDataRegions    : #{@removeNoDataRegions}
   QuantileNormalized     : #{@quantileNormalized}
   Resolution             : #{@res}"
    
    body <<"
    
Top Results:
#{@bufferResult}"
      
if(@input.size>11)
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
          

      subject = "Genboree: Your #{@toolTitle} job is complete "
              
           rescue => err
         $stderr.puts "Deatils: #{err.message}"
         $stderr.puts err.backtrace.join("\n")
         
          body =
"
Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} job is unsucessfull.

Job Summary:
  JobID : #{@jobID}
   Analysis Name : #{@runNameOriginal}
   Query Track :
      #{CGI.unescape(File.basename(@input[0]))}
   
  
      Error Message : #{err.message}
      Exit Status   : #{@exitCode}
Please Contact Genboree team with above information. 
        

The Genboree Team"

      subject = "Genboree: Your #{@toolTitle} job is unsuccessfull "
        end
        
         if (!@email.nil?) then
             sendEmail(subject,body)
         end
         ##Removing left over stuff
   system('find . -name *.zip -exec rm {} \;')
   system('find . -name *N0N -exec rm {} \;')
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
                        ['--help'      ,'-h',GetoptLong::NO_ARGUMENT]
                      ]
          progOpts = GetoptLong.new(*optsArray)
          SignalSimilarityWrapper.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
          optsHash = progOpts.to_hash
        
          Coverage if(optsHash.empty? or optsHash.key?('--help'));
          return optsHash
      end 

end

optsHash = SignalSimilarityWrapper.processArguements()
performQCUsingFindPeaks = SignalSimilarityWrapper.new(optsHash)
performQCUsingFindPeaks.work()
