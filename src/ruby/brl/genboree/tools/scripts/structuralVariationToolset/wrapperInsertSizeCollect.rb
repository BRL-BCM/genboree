#!/usr/bin/env ruby
require 'cgi'
require 'json'
require 'fileutils'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/normalize/expanderAdvanced'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/tools/toolConf'

include BRL::Genboree::REST


class InsertSizeCollect

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
    @platFormType   = jsonObj["settings"]["platformType"].upcase!
    if( @platFormType == "SOLID" )
      @orientation = "same"
    elsif( @platFormType == "ILLUMINA" )
      @orientation = "opposite"
    end

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

       ##Reading summary file nad passing it to user in email
       fileSummary = File.open("#{@scratch}/InsertSizeSummary.txt")
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

  ##Converting all the BAM files(if present) into SAM files.
  ##Tools run only on one kinaa file BAM/SAM.
  ##We are running it on SAM files.
  def convertBAMtoSAM(file)
    system("samtools view -h -o #{File.basename(file)} #{file}")
  end

  ##looking for BAM files.
  def checkForBAM()
    @input.each {|file|
      expander = ExpandAdvanced(file)
      type = expander.recursivelyCheck()
      if (type == "BAM")
        fileName = expander.finalFilename()
        convertBAMtoSAM(fileName)
      elsif( type == "unknown")
        raise "File format is unidentified"
      end
      }
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
      raise "Error"
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
  ## NEED TO BE DONE
  def formatType()
    expanderObj = BRL::Genboree::Helpers::Expander.new("#{@localFileLocation[0]}")
    if(compressed = expanderObj.isCompressed?("#{@localFileLocation[0]}"))
    end
  end


  ##Calling main driver tool
  def callTool()
    cmd = "driverInsertSizeCollect.rb -O #{@orientation} -F \"#{@fwdDir}/*\" -R \"#{@revDir}/*\" -s \"#{@forwardSuffix}\" -S \"#{@reverseSuffix}\""
    cmd << " -N 2 -A InsertSizeSummary.txt -T #{@type} -o #{@outputDir}/Histogram.xls -X #{@scratch} "
    cmd << " > #{@outputDir}/insertSize.log 2>#{@outputDir}/InsertSize.error.log"
    $stdout.puts cmd
    system(cmd)
    if(!$?.success?)
      @exitCode = $?.exitstatus
      raise "driverInsertSizeCollect.rb didn't work"
    end
  end


  ##Upload generated data to specifed database in geboree
  def uploadUsingAPI(studyName,fileName,filePath)
    restPath = @pathOutput
    path     = restPath +"/file/#{CGI.escape("Structural Variation")}/InsertSizes/#{studyName}/#{fileName}/data"
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
    uploadedPath = restPath+"/file/#{CGI.escape("Structural Variation")}/InsertSizes/#{studyName}/#{fileName}"
    @apiRSCRpath = CGI.escape(uploadedPath)
  end

 ##Upload histogram
 def uploadData()
      @apicaller = WrapperApiCaller.new(@hostOutput,"",@userId)
      restPath = @pathOutput
      @success = false
      uploadUsingAPI(@cgiAnalysisName, "Summary_#{@cgiAnalysisName}.txt","#{@scratch}/InsertSizeSummary.txt")
      uploadUsingAPI(@cgiAnalysisName, "Histogram_#{@cgiAnalysisName}.xls","#{@outputDir}/Histogram.xls")
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
         path = restPath +"/file/#{CGI.escape("Structural Variation")}/InsertSizes/#{@cgiAnalysisName}/jobFile.json"
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
      * InsertSizes
        *#{@analysisName}

The Genboree Team

Result File URLs (click or paste in browser to access file):
  FILE: Histogram.xls
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


  def InsertSizeCollect.usage(msg='')
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
  def InsertSizeCollect.processArguments()
    # We want to add all the prop_keys as potential command line options
    optsArray = [ ['--jsonFile' ,'-j', GetoptLong::REQUIRED_ARGUMENT],
                  ['--help'     ,'-h', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    InsertSizeCollect.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash

    InsertSizeCollect.usage if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end
end

begin
optsHash = InsertSizeCollect.processArguments()
InsertSizeCollect = InsertSizeCollect.new(optsHash)
InsertSizeCollect.main()
    rescue => err
      $stderr.puts "Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
     #InsertSizeCollect.sendFailureEmail(err.message)
end
