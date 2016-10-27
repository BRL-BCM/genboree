#!/usr/bin/env ruby

# Load libraries
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/genboreeUtil'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/genboree/genboreeDBHelper'
require 'brl/util/emailer'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/util/samTools'
require 'brl/util/vcfParser'
require 'uri'
require 'json'
ENV['DBRC_FILE']
ENV['PATH']
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

# Driver Class
class DriveAtlasSnp2Genotyper
  NON_ATLASSNP2GENOTYPER_SETTINGS = { 'clusterQueue' => true }
  MAX_OUT_BUFFER = 1024 * 1024 * 4

  # Constructor
  # [+optsHash+] command line args
  # [+returns+] nil
  def initialize(optsHash)
    @jsonFile = optsHash['--inputFile']
    @emailMessage = ""
    @userEmail = nil
    @context = nil
    @jobId = nil
    @origFileBaseName = nil
    begin
      # Parse the input json file
      @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
      parseInputFile(@jsonFile)
      # Run genotyper.rb program
      runAtlasSnp2Genotyper()
      # Prepares lff file:
      prepLff()
      # Transfer .vcf. and .lff files to target
      transferFiles()
      # Uploads lff file as track in Genboree (if required)
      uploadLff() if(@uploadSNPTrack)
      # Send Email to User with success notification
      sendSuccessEmail()
    rescue Exception => err
      # Also sends out Failure email to user
      displayErrorMsgAndExit(err)
    end
  end

  # Downloads inputs file and runs the Atlas-SNP2-Genotyper program
  # [+returns+] nil
  def runAtlasSnp2Genotyper()
    filehelperObj = BRL::Genboree::REST::Helpers::FileApiUriHelper.new()
    dbHelperObj = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
    # Download the snp file
    uri = URI.parse(@input)
    rcscUri = uri.path.chomp("?")
    rcscUri << "?gbKey=#{@dbApiHelper.extractGbKey(@input)}" if(@dbApiHelper.extractGbKey(@input))
    @inputFileName = nil
    # If input not file, must be folder containing .snp file
    if(@input !~ BRL::Genboree::REST::Helpers::FileApiUriHelper::NAME_EXTRACTOR_REGEXP)
      apiCaller = WrapperApiCaller.new(uri.host, rcscUri, @userId)
      apiCaller.get()
      if(!apiCaller.succeeded?)
        @emailMessage = "Failed to get contents of folder: #{rcscUri.inspect} from host: #{uri.host.inspect}."
        raise "Failed to download resource: #{rcscUri.inspect} from host: #{uri.host.inspect}.\nApiCaller response:\n#{apiCaller.respBody.inspect}"
      end
      resp = apiCaller.parseRespBody['data']
      resp.each { |file|
        filePath =   file['label']
        if(File.basename(filePath) =~ /\.snp\.zip$/)
          @input = file['refs'][BRL::Genboree::REST::Data::DatabaseFileEntity::REFS_KEY]
          uri = URI.parse(@input)
          rcscUri = uri.path.chomp("?")
          break
        end
      }
    end
    rcscUri << "/data?"
    rcscUri << "gbKey=#{@dbApiHelper.extractGbKey(@input)}" if(@dbApiHelper.extractGbKey(@input))
    @inputFileName = CGI.escape(File.basename(filehelperObj.extractName(@input)))
    fileWriter = File.open(@inputFileName, "w")
    apiCaller = WrapperApiCaller.new(uri.host, rcscUri, @userId)
    $stderr.puts "Downloading .snp file from resource: #{rcscUri.inspect}, host: #{uri.host.inspect}"
    writeBuff = ''
    apiCaller.get() { |chunk|
      writeBuff << chunk
      if(writeBuff.size >= MAX_OUT_BUFFER)
        fileWriter.print(writeBuff)
        writeBuff = ''
      end
    }
    if(!apiCaller.succeeded?)
      @emailMessage = "Failed to download resource: #{rcscUri.inspect} from host: #{uri.host.inspect}. File missing?"
      raise "Failed to download resource: #{rcscUri.inspect} from host: #{uri.host.inspect}.\nApiCaller response:\n#{apiCaller.respBody.inspect}"
    end
    if(!writeBuff.empty?)
      fileWriter.print(writeBuff)
      writeBuff = ''
    end
    fileWriter.close()
    # We need to expand and convert the downloaded file to unix format before launching the genotyper
    preppedFile = prepSnpFile(@inputFileName)
    # Run Atlas-SNP2.rb
    @inputFileName.gsub!(/\.snp(?:\.[^\.]+)?/i, "")
    cmd = "module load atlastools; genotyper.rb #{preppedFile} #{CGI.escape(@sampleName)} #{@postProbCutOff} #{@minCov} > #{@scratchDir}/#{@inputFileName}.genotype.vcf 2> #{@scratchDir}/genotyper.stderr"
    $stderr.puts "Launching Command: #{cmd.inspect}"
    exitStatus = system(cmd)
    statusObj = $?.dup()
    if(!exitStatus)
      stderrStream = File.read("#{@scratchDir}/genotyper.stderr")
      @emailMessage = "Failed to run: genotyper.rb.\n Stderr:\n#{stderrStream}\n"
      raise "genotyper.rb failed with status: #{statusObj.inspect}.\nCommand: #{cmd.inspect}"
    end
  end


  # Preps downloaded .snp file:
  # expands it and converts it to unix format
  # [+snpFile+]
  # [+returns+] preppedFile
  def prepSnpFile(snpFile)
    $stderr.puts "Prepping .snp file..."
    # Uncompress the file if its zipped
    expanderObj = BRL::Genboree::Helpers::Expander.new(snpFile)
    expanderObj.extract(desiredType = 'text')
    fullPathToUncompFile = expanderObj.uncompressedFileName
    # Convert to unix format:
    convertObj = BRL::Util::ConvertText.new(fullPathToUncompFile)
    convertObj.convertText(:all2unix)
    preppedFile = convertObj.convertedFileName
    return preppedFile
  end

  # Transfer output files to target
  # [+returns+] nil
  def transferFiles()
    uri = URI.parse(@output)
    host = uri.host
    rcscUri = uri.path
    rcscUri = rcscUri.chomp("?")
    rcscUri << "/file/#{CGI.escape("Atlas2 Suite Results")}/#{CGI.escape(@studyName)}/Atlas-SNP2-Genotyper/#{CGI.escape(@jobName)}/"
    # Transfer files:
    files = [@vcfFile, @lffFile]
    # gzip the files
    compressedFiles = []
    files.each { |file|
      cmd = "zip #{file}.zip #{file}"
      exitStatus = system(cmd)
      exitObj = $?.dup()
      if(!exitStatus)
        @emailMessage = "Could not compress file: #{file.inspect}"
        raise "gzip cmd failed.\nExit Status: #{exitObj.inspect}\nCommand: #{cmd.inspect}"
      end
      compressedFiles.push("#{file}.zip") if(File.exists?("#{file}.zip"))
    }
    compressedFiles.each { |file|
      fileUri = rcscUri.dup()
      fileUri << "#{File.basename(file)}/data?"
      fileUri << "gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
      apiCaller = WrapperApiCaller.new(host, fileUri, @userId)
      $stderr.puts "Transferring file: #{File.basename(file)}"
      apiCaller.put({}, File.open(file))
      if(!apiCaller.succeeded?)
        @emailMessage = "Failed to transfer file: #{File.basename(file)} to target."
        raise "Failed to transfer file: #{File.basename(file)} to target.\nDetails: \n#{apiCaller.respBody.inspect}"
      end
    }
  end


  # Uploads Lff File as a track
  # [+returns+] nil
  def uploadLff()
    @uploadFailed = false
    uri = URI.parse(@output)
    host = uri.host
    rcscUri = uri.path.chomp("?")
    # First create the empty track
    rcscUri << "/trk/#{@trackName}?"
    rcscUri << "gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
    apiCaller = WrapperApiCaller.new(host, rcscUri, @userId)
    apiCaller.put()
    if(apiCaller.succeeded?) # OK, set the default display
      payload = { "data" => { "text" => "Expand with Names" } }
      rcscUri.chomp!("?")
      rcscUri << "/defaultDisplay?"
      apiCaller = WrapperApiCaller.new(host, rcscUri, @userId)
      apiCaller.put(payload.to_json)
      $stderr.puts "Setting the default display for track: #{@trackName} failed (rcscUri: #{rcscUri.inspect}): #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
      # Set the default color
      rcscUri.gsub!("/defaultDisplay?", "/defaultColor?")
      apiCaller = WrapperApiCaller.new(host, rcscUri, @userId)
      payload = { "data" => { "text" => "#0000ff" } }
      apiCaller.put(payload.to_json)
      $stderr.puts "Setting the default color for track: #{@trackName} failed (rcscUri: #{rcscUri.inspect}): #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
    else # Failed
      $stderr.puts "Creating the empty track: #{@trackName} failed (Track already exists?) (rcscUri: #{rcscUri.inspect}): #{apiCaller.respBody.inspect}"
    end
    rcscUri = uri.path.chomp("?")
    rcscUri << "/annos?format=lff&userId=#{@userId}"
    rcscUri << "&gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
    apiCaller = WrapperApiCaller.new(host, rcscUri, @userId)
    $stderr.puts "Uploading file: #{File.basename("#{@lffFile}.zip")}"
    apiCaller.put({}, File.open("#{@lffFile}.zip"))
    if(!apiCaller.succeeded?)
      $stderr.puts "Could not upload LFF File: #{@lffFile}.\nDetails:\n#{apiCaller.respBody.inspect}"
      @uploadFailed = true
    end
  end

  # Creates an lff file from the .vcf file generated by genotyper.rb program
  # [+returns+] nil
  def prepLff()
    $stderr.puts "Preparing LFF File..."
    @vcfFile = "#{@inputFileName}.genotype.vcf"
    vcfReader = File.open(@vcfFile)
    @lffFile = "#{@inputFileName}.genotype.lff"
    lffWriter = File.open(@lffFile, "w")
    buff = ''

    vcfObj = nil
    vcfReader.each_line { |line|
      if(line =~ /^#(?!#)/) # Column Header
        # Init vcfParser
        vcfObj = BRL::Util::VcfParser.new(line, nil)
        break
      end
    }

    # Go through the vcf file and create a lff record for each record in the file
    vcfReader.each_line { |line|
      line.strip!
      next if(line.nil? or line =~ /^#/ or line =~ /^\s*$/ or line.empty?)
      vcfObj.parseLine(line)
      buff << vcfObj.makeLFF("Atlas Tool Suite", @lffType, @lffSubType)
      if(buff.size >= MAX_OUT_BUFFER)
        lffWriter.print(buff)
        buff = ''
      end
      vcfObj.deleteNonCoreKeys
    }
    if(!buff.empty?)
      lffWriter.print(buff)
      buff = ''
    end
    # Close all file handlers
    vcfReader.close()
    lffWriter.close()
  end

  def addToolTitle(jsonObj)
    jsonObj['context']['toolTitle'] = @toolConf.getSetting('ui', 'label')
    return jsonObj
  end



  # parses the json input file and sets up required instance variables
  # [+inputFile+] json file
  # [+returns+] nil
  def parseInputFile(inputFile)
    jsonObj = JSON.parse(File.read(inputFile))
    jsonObj = addToolTitle(jsonObj)
    # Get Input/Output
    @input = jsonObj['inputs'][0]
    @output = jsonObj['outputs'][0]
    dbrcFile = File.expand_path(ENV['DBRC_FILE'])
    # Get Context Info:
    @toolIdStr = jsonObj['context']['toolIdStr']
    @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr)
    @dbrcKey = jsonObj['context']['apiDbrcKey']
    @adminEmail = jsonObj['context']['gbAdminEmail']
    @userId = jsonObj['context']['userId']
    @jobId = jsonObj['context']['jobId']
    @context = jsonObj['context']
    @userEmail = jsonObj['context']['userEmail']
    @userLogin = jsonObj['context']['userLogin']
    @scratchDir = jsonObj['context']['scratchDir']
    # Get Settings options
    @studyName = jsonObj['settings']['studyName']
    @jobName = jsonObj['settings']['jobName']
    @uploadSNPTrack = jsonObj['settings']['uploadSNPTrack']
    @platformType = jsonObj['settings']['platformType']
    @eCovPriori = jsonObj['settings']['eCoveragePriori']
    @lCovPriori = jsonObj['settings']['lCoveragePriori']
    @maxPercSubBases = jsonObj['settings']['maxPercSubBases']
    @maxPercIndelBases = jsonObj['settings']['maxPercIndelBases']
    @maxAlignPileup = jsonObj['settings']['maxAlignPileup']
    @postProbCutOff = jsonObj['settings']['postProbCutOff']
    @minCov = jsonObj['settings']['minCov']
    @insertionSize = jsonObj['settings']['insertionSize']
    @sampleName = jsonObj['settings']['sampleName']
    @fastaDir = jsonObj['settings']['fastaDir']
    @refGenome = jsonObj['settings']['refGenome']
    @lffType = jsonObj['settings']['lffType']
    @lffSubType = jsonObj['settings']['lffSubType']
    @trackName = CGI.escape("#{@lffType}:#{@lffSubType}") if(@uploadSNPTrack)
    @lffType = CGI.escape(@sampleName) unless(@lffType)
    @lffSubType = 'GenoTypes' unless(@lffSubType)
    # Get User, pass and host info:
    dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
    @user = dbrc.user
    @pass = dbrc.password
    @host = dbrc.driver.split(/:/).last
    @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
  end

  # Displays error message and quits
  # [+msg+]  error message
  #  [+returns+] nil
  def displayErrorMsgAndExit(msg)
    $stderr.puts "ERROR:\n #{msg}"
    $stderr.puts "ERROR Backtrace:\n #{msg.backtrace.join("\n")}"
    @emailMessage = msg.to_s if(@emailMessage.nil? or @emailMessage.empty?)
    sendErrorEmail()
    exit(14)
  end

  def buildEmailBodyPrefix(msg)
    # defaults if things very very wrong (no json file even)
    userFirstName = 'User'
    userLastName = ''
    toolTitle = 'Atlas-SNP2-Genotyper'

    # use appropriate info from json file if available
    if(@context and @context.is_a?(Hash))
      userFirstName = @context['userFirstName'] if(@context['userFirstName'])
      userLastName = @context['userLastName'] if(@context['userLastName'])
      toolTiitle = @context['toolTitle'] if(@context['toolTitle'])
    end
    buff = ''
    buff << "\nHello #{userFirstName} #{userLastName},\n\n#{msg}\n\nJOB SUMMARY:\n"
    buff << <<-EOS
      JobID          : #{@jobId}
      Job Name       : #{@jobName}
      Study Name     : #{@studyName}

            Advanced Settings:
      Posterior Probablity Cutoff                  : #{@postProbCutOff}
      Min Coverage For High Confidence SNP calls   : #{@minCov}
      Sample Name                                  : #{@sampleName}

    EOS
    if(@uploadSNPTrack)
      buff << <<-EOS
        SNP Track Name    : #{@lffType}:#{@lffSubType}
      EOS
    end
    return buff
  end

  def sendEmail(emailTo, subject, body)
    self.class.sendEmail(emailTo, subject, body)
  end

  def self.sendEmail(emailTo, subject, body)
    genbConf = ENV['GENB_CONFIG']
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    emailer = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)

    # Email to user
    if(!emailTo.nil?)
      emailer.addRecipient(emailTo)
      emailer.addRecipient(genbConfig.gbAdminEmail)
      emailer.setHeaders(genbConfig.gbFromAddress, emailTo, subject)
      emailer.setMailFrom(genbConfig.gbFromAddress)
      emailer.addHeader("Bcc: #{genbConfig.gbBccAddress}")
      body ||= "There was an unknown problem."
      emailer.setBody(body)
      emailer.send()
    end
  end

  def sendSuccessEmail()
    # Build message body
    buff = buildEmailBodyPrefix("Your #{@context['toolTitle']} job has completed successfully.")
    if(@uploadSNPTrack)
      if(@uploadFailed)
        buff << "\nHowever, we did encounter a problem uploading the LFF file as a track in Genboree. Please contact the Genboree Administrator for additional details."
      else
        buff << "\nYou should shortly recieve an email once the LFF file has finished uploading."
      end
    end
    buff << "\n\nThe Genboree Team"
    sendEmail(@userEmail, "GENBOREE NOTICE: Your #{@context['toolTitle']} completed", buff)
    $stderr.puts "STATUS: All Done"
  end

  # sends error email to recipients about the job status
  # [+returns+] no return value
  def sendErrorEmail()
    genbConf = ENV['GENB_CONFIG']
    @jobId = "Unknown Job Id" if(@jobId.nil?)
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    @userEmail = genbConfig.gbAdminEmail if(@userEmail.nil?)

    # EMAIL TO USER:
    # appropriate tool title
    if(@context and @context['toolTitle'])
      toolTitle = @context['toolTitle']
    else
      toolTitle = 'Atlas-SNP2-Genotyper'
    end

    # email body
    @emailMessage = "There was an unknown problem." if(@emailMessage.nil? or @emailMessage.empty?)
    body = buildEmailBodyPrefix("Unfortunately your #{toolTitle} job has failed. Please contact the Genboree Team (#{genbConfig.gbAdminEmail}) with the error details for help with this problem.\n\nERROR DETAILS:\n\n#{@emailMessage}")
    body << "\n\n- The Genboree Team"

    # send email with subject and body
    sendEmail(@userEmail, "GENBOREE NOTICE: Your #{toolTitle} job failed", body)
  end

end


# Class for running the script and parsing args
class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Sameer Paithankar

  Description: This tool is intended to used for running the Atlas-SNP2 Genotyper program from BCM-HGSC via the Genboree Workbench
    -j  --inputFile                     => input file in json format
    -v  --version                       => Version of the program
    -h  --help                          => Display help

  "
  def self.printUsage(additionalInfo=nil)
    puts DEFAULTUSAGEINFO
    puts additionalInfo unless(additionalInfo.nil?)
    if(additionalInfo.nil?)
      exit(0)
    else
      exit(15)
    end
  end

  def self.printVersion()
    puts VERSION_NUMBER
    exit(0)
  end

  def self.parseArgs()
    optsArray=[
      ['--inputFile','-j',GetoptLong::REQUIRED_ARGUMENT],
      ['--version','-v',GetoptLong::NO_ARGUMENT],
      ['--help','-h',GetoptLong::NO_ARGUMENT]
    ]
    progOpts=GetoptLong.new(*optsArray)
    optsHash=progOpts.to_hash
    if(optsHash.key?('--help'))
      printUsage()
    elsif(optsHash.key?('--version'))
      printVersion()
    end
    printUsage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    return optsHash
  end

  def self.performDriveAtlasSnp2Genotyper(optsHash)
    driveAtlasSnp2GenotyperObj = DriveAtlasSnp2Genotyper.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performDriveAtlasSnp2Genotyper(optsHash)
