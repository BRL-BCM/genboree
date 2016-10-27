#!/usr/bin/env ruby
require 'cgi'
require 'json'
require 'fileutils'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/tools/toolConf'

include BRL::Genboree::REST

class SVReport

  ##Intitialization of data
  def initialize(optsHash)
    @inputJson    = File.expand_path(optsHash['--jsonFile'])
    jsonObj       = JSON.parse(File.read(@inputJson))

    @input        = jsonObj["inputs"]
    @outputArray  = jsonObj["outputs"]
    @output       = jsonObj["outputs"][0]

    @gbConfFile   = jsonObj["context"]["gbConfFile"]
    @apiDBRCkey   = jsonObj["context"]["apiDbrcKey"]
    @scratch      = jsonObj["context"]["scratchDir"]
    @email        = jsonObj["context"]["userEmail"]
    @user_first   = jsonObj["context"]["userFirstName"]
    @user_last    = jsonObj["context"]["userLastName"]
    @username     = jsonObj["context"]["userLogin"]

    @toolIdStr = jsonObj['context']['toolIdStr']
    @genbConf = BRL::Genboree::GenboreeConfig.load(ENV['GENB_CONFIG'])
    @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr, @genbConf)
    @toolTitle = @toolConf.getSetting('ui', 'label')

    @gbAdminEmail = jsonObj["context"]["gbAdminEmail"]
    @jobID        = jsonObj["context"]["jobId"]
    @userId       = jsonObj["context"]["userId"]

    @radius         = jsonObj["settings"]["radius"]
    @tgpBreakpoints = jsonObj["settings"]["tgpBreakpoints"]
    @analysisName   = jsonObj["settings"]["analysisName"]
    @uploadLffFile  = jsonObj["settings"]["uploadLff"]

    @fileNameBuffer = []

    @cgiAnalysisName  = CGI.escape(@analysisName)
    @filAnalysisName  = @cgiAnalysisName.gsub(/%[0-9a-f]{2,2}/i, "_")

    @grph       = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
    @dbhelper   = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
    @trackhelper= BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@gbConfFile)

    ##pulling out upload location specifications
    @output     = @output.chomp('?')
    @dbOutput   = @dbhelper.extractName(@output)
    @grpOutput  = @grph.extractName(@output)
    uriOutput   = URI.parse(@output)
    @hostOutput = uriOutput.host
    @pathOutput = uriOutput.path

    @uri        = @grph.extractPureUri(@output)
    dbrc        = BRL::DB::DBRC.new(nil, @apiDBRCkey)
    @pass       = dbrc.password
    @user       = dbrc.user
    @uri        = URI.parse(@input[0])
    @host       = @uri.host
    @exitCode   = ""
    @success    = false
    ##Converting all the BAM files to SAM. Driver is not capable of dealing multi-format files.

    dbVersion()
    puts @genome
    @targetGenomicFile = "/cluster.shared/data/groups/brl/fasta/#{@genome}/#{genome}.wholeGene.lff"
    @tgpFileLocation = "/cluster.shared/data/groups/brl/fasta/#{@genome}/#{@genome}.1000genomes.sv.lff"

  end

  ##Check output dbversion, to look for correct tgp File Location
  def dbVersion()

    uri         = URI.parse(@output)
    host        = uri.host
    path        = uri.path
    apicaller   = WrapperApiCaller.new(host,"",@userId)
    path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
    apicaller.setRsrcPath(path)
    httpResp    = apicaller.get
    temp        = apicaller.parseRespBody()
    @genome     = temp["data"]["version"]
    @genome = "hg18"
  end

  ##Main to call all other functions
  def main()
    begin
      system("mkdir -p #{@scratch}")
      Dir.chdir(@scratch)
      @outputDir = "#{@scratch}/#{@filAnalysisName}"
      system("mkdir -p #{@outputDir}")
      downloadData()
      if( !$?.success? )
        @exitCode = $?.exitstatus
        raise "Some problem occured during download."
      end

     callTool()
      if( !$?.success? )
        @exitCode = $?.exitstatus
        raise "Some problem occured during runing driverInsertSizeCollect.rb."
      end

    compression()

     uploadData()
       if( !$?.success? )
        @exitCode = $?.exitstatus
        raise "Some problem occured during uploading of file."
       end

    sendSuccessEmail()
    rescue => err
      $stderr.puts err.backtrace.join("\n")
      sendFailureEmail(err)
    end
  end

  ##Download all the SAM/BAM files
  def downloadData()
    begin
    ii = 0
    @localFileLocation = ""
    @input.each {|file|
      file  = file.chomp('?')
      saveFile    = File.open("#{@outputDir}/file#{ii}.sv.lff","w+")
      $stdout.puts "Downloading #{File.basename(file)} file:"
      @db         = @dbhelper.extractName(file)
      @grp        = @grph.extractName(file)
      uri         = URI.parse(file)
      host        = uri.host
      path        = uri.path
      path        = path.gsub(/\/files\//,'/file/')
      apicaller   = WrapperApiCaller.new(host,"",@userId)
      pathR       = "#{path}/#{File.basename(file)}.sv.lff/data?"
      pathR << "gbKey=#{@dbhelper.extractGbKey(file)}" if(@dbhelper.extractGbKey(file))
      $stdout.puts pathR
      apicaller.setRsrcPath(pathR)
      httpResp    = apicaller.get(){|chunk|
        saveFile.print chunk
      }

      if apicaller.succeeded?
        $stdout.puts "Successfully downloaded #{file} "
      else
        $stderr.puts apicaller.parseRespBody()
        $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
        @exitCode = apicaller.apiStatusObj['statusCode']
        raise "#{apicaller.apiStatusObj['msg']}"
      end
      @localFileLocation << "#{@outputDir}/file#{ii}.sv.lff,"
      ii += 1
      saveFile.close
    }
    @localFileLocation.chomp!(",")
    rescue => err
      $stderr.puts err.backtrace.join("\n")
      raise "Error"
    end
  end


  ##Calling main driver tool
  def callTool()
    cmd = "driverSVReport.rb -t \"#{@outputDir}/*.sv.lff\" -g #{@targetGenomicFile}  -s #{@scratch} -o #{@outputDir}/#{@filAnalysisName}.report -R #{@radius} "
    if(@tgpBreakpoints == true)
      cmd << " -K #{@tgpFileLocation} "
    end
    cmd <<" > #{@outputDir}/svReport.log 2>#{@outputDir}/svReport.error.log"
    $stdout.puts cmd
    system(cmd)
    if(!$?.success?)
      @exitCode = $?.exitstatus
      raise "driverSVReport.rb didn't work"
    end
  end

  ##zip of output result
   def compression
     Dir.chdir(@outputDir)
     system("zip report.#{@filAnalysisName}.xls.zip `find . -name '*.xls'`")
     Dir.chdir(@scratch)
   end

  ##Upload generated data to specifed database in geboree
  def uploadUsingAPI(studyName,fileName,filePath)
    restPath = @pathOutput
    path     = restPath +"/file/#{CGI.escape("Structural Variation")}/Reports/#{studyName}/#{fileName}/data"
    path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
    @apicaller.setRsrcPath(path)
    infile   = File.open("#{filePath}","r")
    @apicaller.put(infile)
    if @apicaller.succeeded?
      $stdout.puts "Successfully uploaded #{fileName} "
    else
      $stderr.puts @apicaller.parseRespBody()
      $stderr.puts "API response; statusCode: #{@apicaller.apiStatusObj['statusCode']}, message: #{@apicaller.apiStatusObj['msg']}"
      @exitCode = @apicaller.apiStatusObj['statusCode']
      raise "#{@apicaller.apiStatusObj['msg']}"
    end
    uploadedPath = restPath+"/file/#{CGI.escape("Structural Variation")}/Reports/#{studyName}/#{fileName}"
    @apiRSCRpath = CGI.escape(uploadedPath)
  end

 ##Upload histogram
 def uploadData()
      @apicaller = WrapperApiCaller.new(@hostOutput,"",@userId)
      restPath = @pathOutput
      @success = false
      uploadUsingAPI(@cgiAnalysisName, "report.#{@filAnalysisName}.xls.zip","#{@outputDir}/report.#{@filAnalysisName}.xls.zip")
      @success = true
  end

  def sendFailureEmail(errMsg)
    body =
        "
        Hello #{@user_first.capitalize} #{@user_last.capitalize}

        Your #{@toolTitle} job was unsuccessful.

        Job Summary:
        JobID                  : #{@jobID}
        Analysis Name          : #{@analysisName}


        Error Message : #{errMsg}
        Exit Status   : #{@exitCode}
        Please Contact the Genboree team with above information.

        The Genboree Team"

        subject = "Genboree: Your #{@toolTitle} job was unsuccessful"
      if (!@email.nil?) then
        sendEmail(subject,body)
      end

       ##Deleting file from workbech created by UI
         apicaller = WrapperApiCaller.new(@hostOutput,"",@userId)
         restPath = @pathOutput
         path = restPath +"/file/#{CGI.escape("Structural Variation")}/Reports/#{@cgiAnalysisName}/jobFile.json"
         path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
         apicaller.setRsrcPath(path)
         apicaller.delete()
         $stdout.puts apicaller.parseRespBody()
  end


  def sendSuccessEmail
      body =
      "
      Hello #{@user_first.capitalize} #{@user_last.capitalize}

      Your #{@toolTitle} job is complete successfully.

      Job Summary:
      JobID                  : #{@jobID}
      Analysis Name          : #{@analysisName}



      Result File Location in the Genboree Workbench:
      Group : #{@grpOutput}
      DataBase : #{@dbOutput}
      Path to File:
      Files
      * Structural Variation
        * Reports
          *#{@analysisName}


      The Genboree Team


      Result File URLs (click or paste in browser to access file):
      FILE: report.#{@filAnalysisName}.xls.zip
      URL:
      http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpath}/data

            "
      subject = "Genboree: Your #{@toolTitle} job is complete "
      if (!@email.nil?) then sendEmail(subject,body) end
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


  def SVReport.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "

    PROGRAM DESCRIPTION:
    driverInsertSizeCollect wrapper for Cancer workbench
    COMMAND LINE ARGUMENTS:
    --file         | -j => Input json file
    --help         | -h => [Optional flag]. Print help info and exit.

    usage:

    ruby wrapperInsertSizeCollect.rb -f jsonFile
    ";
    exit;
  end #

  # Process Arguments form the command line input
  def SVReport.processArguments()
    # We want to add all the prop_keys as potential command line options
    optsArray = [ ['--jsonFile' ,'-j', GetoptLong::REQUIRED_ARGUMENT],
                  ['--help'     ,'-h', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    SVReport.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash

    SVReport.usage if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end
end

begin
optsHash = SVReport.processArguments()
SVReport = SVReport.new(optsHash)
SVReport.main()
    rescue => err
      $stderr.puts "Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
     #SVReport.sendFailureEmail(err.message)
end
