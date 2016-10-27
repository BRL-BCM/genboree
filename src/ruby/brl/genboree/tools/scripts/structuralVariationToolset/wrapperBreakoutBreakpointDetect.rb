#!/usr/bin/env ruby
require 'cgi'
require 'json'
require 'fileutils'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/tools/toolConf'

include BRL::Genboree::REST


class BreakOutBreakPointDetect

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

    @inputType      = jsonObj["settings"]["inputType"]
    @forwardSuffix  = jsonObj["settings"]["forwardSuffix"]
    @reverseSuffix  = jsonObj["settings"]["reverseSuffix"]
    @analysisName   = jsonObj["settings"]["analysisName"]
    @lowerBound     = jsonObj["settings"]["lowerBound"]
    @upperBound     = jsonObj["settings"]["upperBound"]
    @upperBoundFailes = jsonObj["settings"]["upperBoundFailes"]
    @uploadLffFile  = jsonObj["settings"]["uploadLffFile"]
    @circosPlot     = jsonObj["settings"]["circosPlot"]
    @cnvCall        = jsonObj["settings"]["circosPlot"]
    @platFormType   = jsonObj["settings"]["platformType"].upcase!
    if(@platFormType == "SOLID")
      @orientation = "same"
    elsif( @platFormType == "ILLUMINA")
      @orientation = "opposite"
    end


    @chromosomeFile = "/home/coarfa/structVarToolset/hg18.chromosomes"
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
    @type       = "SAM"

  end

  ##Main to call all other functions
  def main()
    begin
      system("mkdir -p #{@scratch}")
      Dir.chdir(@scratch)
      @outputDir = "#{@scratch}/#{@filAnalysisName}"
      system("mkdir -p #{@outputDir}")
      @fwdDir = "#{@outputDir}/fwd"
      @revDir = "#{@outputDir}/rev"
      system("mkdir -p #{@fwdDir}")
      system("mkdir -p #{@revDir}")

      downloadData()
      if( !$?.success? )
        @exitCode = $?.exitstatus
        raise "Some problem occured during download."
      end

      group()
      if( !$?.success? )
        @exitCode = $?.exitstatus
        raise "Some problem occured during classifing fwd mapping files and rev mapping files."
      end

     callTool()
      if( !$?.success? )
        @exitCode = $?.exitstatus
        raise "Some problem occured during runing driverInsertSizeCollect.rb."
      else
        system("rm -rf #{@outputDir}/fwd")
        system("rm -rf #{@outputDir}/rev")
      end

      uploadData()
      if( !$?.success? )
        @exitCode = $?.exitstatus
        raise "Some problem occured during uploading of file."
      end

      if(@uploadLffFile == true)
        uploadLff()
        if( !$?.success? )
          @exitCode = $?.exitstatus
          raise "Some problem occured during uploading lff track."
        end
      end

       ##Reading summary file nad passing it to user in email
       fileSummary = File.open("#{@outputDir}/test.summary")
       @summaryBuffer = ""
       firstLine = true
       fileSummary.each {| line|
         if(firstLine == true)
          @summaryBuffer << line
          firstLine = false
         else
          @summaryBuffer <<"  #{line}"
         end
         }
       fileSummary.close

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
    @localFileLocation = []
    @input.each {|file|
      file  = file.chomp('?')
      saveFile    = File.open("#{@outputDir}/#{File.basename(file)}","w+")
      $stdout.puts "Downloading #{File.basename(file)} file:"
      @db         = @dbhelper.extractName(file)
      @grp        = @grph.extractName(file)
      uri         = URI.parse(file)
      host        = uri.host
      path        = uri.path
      apicaller   = WrapperApiCaller.new(host,"",@userId)
      pathR = "#{path}/data?"
      pathR << "gbKey=#{@dbhelper.extractGbKey(file)}" if(@dbhelper.extractGbKey(file))
      apicaller.setRsrcPath(pathR)
      httpResp  = apicaller.get(){|chunk|
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
      @localFileLocation[ii] = "#{@outputDir}/#{File.basename(file)}"
      ii += 1
      saveFile.close
    }
    rescue => err
      $stderr.puts err.backtrace.join("\n")
      sendFailureEmail(err)
    end
  end

  ##Making groups of forward mapping files and reverse mapping file
  def group()
    ii = 0
    @localFileLocation = []
    @input.each {|file|
      file  = file.chomp('?')
      @localFileLocation[ii] = "#{@outputDir}/#{File.basename(file)}"
      ii += 1
    }
    rev = 0
    fwd = 0
    @fwdFiles = ""
    @revFiles = ""
    jj = 0
    @inputType.each {|type|
      if( type == "Fwd" )
        fwd += 1
        system("mv #{@localFileLocation[jj]} #{@fwdDir}/")
        @fwdFiles << "#{@fwdDir}/#{File.basename(@localFileLocation[jj])},"
      elsif( type == "Rev")
        rev += 1
        system("mv #{@localFileLocation[jj]} #{@revDir}/")
        @revFiles << "#{@revDir}/#{File.basename(@localFileLocation[jj])},"
      else
        err = "un-identified file type"
        return err
      end
      jj += 1
    }

    @fwdFiles.chomp!(',')
    @revFiles.chomp!(',')
    if(rev != fwd or rev == 0)
      err = "Number of fwd mapping file (#{fwd}) is not equal to rev mapping file (#{rev})"
      return err
    end
  end


  ##Identify if the input file is BAM or SAM.
  ##We check this by passing input file file
  ##through our expander class, which can identify
  ##any text or compressed file. BAM file is different
  ##kind of highly compressed format which, expander
  ##class cannot detect.
  def formatType()
    expanderObj = BRL::Genboree::Helpers::Expander.new("#{@localFileLocation[0]}")
    if(compressed = expanderObj.isCompressed?("#{@localFileLocation[0]}"))
    end
  end


  ##Calling main driver tool
  def callTool()
    cmd = "driverBreakoutBreakpointDetect.rb -O #{@orientation} -F \"#{@fwdDir}/*\" -R \"#{@revDir}/*\" -s \"#{@forwardSuffix}\" -S \"#{@reverseSuffix}\""
    cmd << " -N 4 -T #{@type} -o #{@outputDir}/output.svs -b #{@outputDir}/output.svs.lff -B #{@outputDir}/output.xls -X #{@scratch} -E #{@outputDir}/output_2 "
    cmd << " -C #{@outputDir}/test.consistent -J #{@outputDir}/test.inconsistent -A #{@outputDir}/test.summary -i 959 -I 4482 -L #{@chromosomeFile}"
     cmd << " > #{@outputDir}/breakPoint.log 2>#{@outputDir}/breakPoint.error.log"
    $stdout.puts cmd
    system(cmd)
    if(!$?.success?)
      @exitCode = $?.exitstatus
      raise "driverBreakoutBreakpointDetect.rb didn't work"
    end
  end



  ##Upload generated data to specifed database in geboree
  def uploadUsingAPI(studyName,fileName,filePath)
    restPath = @pathOutput
    path     = restPath +"/file/#{CGI.escape("Structural Variation")}/BreakPoints/#{studyName}/#{fileName}/data"
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
    uploadedPath = restPath+"/file/#{CGI.escape("Structural Variation")}/BreakPoints/#{studyName}/#{fileName}"
    @apiRSCRpath = CGI.escape(uploadedPath)
  end

 ##Upload histogram
 def uploadData()
      @apicaller = WrapperApiCaller.new(@hostOutput,"",@userId)
      restPath = @pathOutput
      @success = false
      uploadUsingAPI(@cgiAnalysisName, "breakpoints_#{@cgiAnalysisName}.lff","#{@outputDir}/output.svs.lff")
      uploadUsingAPI(@cgiAnalysisName, "summary_#{@cgiAnalysisName}.txt","#{@outputDir}/test.summary")
      uploadUsingAPI(@cgiAnalysisName, "breakpoints_#{@cgiAnalysisName}.xls","#{@outputDir}/output.xls")
      @success = true
 end

  ##uploading lff file as track
  def uploadLff()

    #path = "/REST/v1/grp/#{CGI.escape(@grpOutput)}/db/#{CGI.escape(@dbOutput)}/annos?userId=#{@userId}"
    #path << "&gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
    #@apicaller.setRsrcPath(path)
    #infile = File.open("#{@outputDir}/output.svs.lff","r")
    #@apicaller.put(infile)
    #if @apicaller.succeeded?
    #  $stdout.puts "successfully uploaded lff file"
    #else
    #  $stdout.puts @apicaller.parseRespBody()
    #  $stderr.puts "API response; statusCode: #{@apicaller.apiStatusObj['statusCode']}, message: #{@apicaller.apiStatusObj['msg']}"
    #  @exitCode = @apicaller.apiStatusObj['statusCode']
    #  raise "#{@apicaller.apiStatusObj['msg']}"
    #end
    # Get the refseqid of the target database
    begin
      outputUri = URI.parse(@output)
      rsrcUri = outputUri.path
      rsrcUri << "?gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
      apiCaller = WrapperApiCaller.new(outputUri.host, rsrcUri, @userId)
      apiCaller.get()
      resp = JSON.parse(apiCaller.respBody)
      uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
      uploadAnnosObj.refSeqId = resp['data']['refSeqId']
      uploadAnnosObj.groupName = @grpOutput
      uploadAnnosObj.userId = @userId
      begin
        uploadAnnosObj.uploadLff(CGI.escape(File.expand_path("#{@outputDir}/output.svs.lff")), false)
      rescue => uploadErr
        raise uploadErr
      end
    rescue => err
      $stderr.puts "Error: #{err}"
      $stderr.puts "Error Backtrace:\n\n#{err.backtrace.join("\n")}"
      raise err
    end
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
         path = restPath +"/file/#{CGI.escape("Structural Variation")}/BreakPoints/#{@cgiAnalysisName}/jobFile.json"
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

Summary report:
  #{@summaryBuffer}

Result File Location in the Genboree Workbench:
    Group : #{@grpOutput}
    DataBase : #{@dbOutput}
    Path to File:
    Files
      * Structural Variation
        * BreakPoints
          * #{@analysisName}

The Genboree Team

Result File URLs (click or paste in browser to access file):
  FILE: breakpoints_#{@cgiAnalysisName}.xls
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


  def BreakOutBreakPointDetect.usage(msg='')
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
  def BreakOutBreakPointDetect.processArguments()
    # We want to add all the prop_keys as potential command line options
    optsArray = [ ['--jsonFile' ,'-j', GetoptLong::REQUIRED_ARGUMENT],
                  ['--help'     ,'-h', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    BreakOutBreakPointDetect.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash

    BreakOutBreakPointDetect.usage if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end
end

begin
optsHash = BreakOutBreakPointDetect.processArguments()
BreakOutBreakPointDetect = BreakOutBreakPointDetect.new(optsHash)
BreakOutBreakPointDetect.main()
    rescue => err
      $stderr.puts "Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
     #BreakOutBreakPointDetect.sendFailureEmail(err.message)
end
