#!/usr/bin/env ruby

# Load libraries
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/util/emailer'
require  'brl/util/expander'
require 'brl/genboree/helpers/sniffer'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'json'
require 'brl/genboree/abstract/resources/user'
ENV['DBRC_FILE']
ENV['PATH']
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST


# Main Class
class SampleFileLinker
  NON_SAMPLEFILELINKER_SETTINGS = { 'clusterQueue' => true, "dbuKey" => true }

  # Constructor
  # [+optsHash+] command line args
  def initialize(optsHash)
    @jsonFile = optsHash['--inputFile']
    @fileSampleHash = {}
    @emailMessage = ""
    @userEmail = nil
    @context = nil
    @jobId = nil
    begin
      parseInputFile(@jsonFile)
      linkSamplesWithFiles()
      sendSuccessEmail()
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end
  end

  # Links samples with files
  # [+returns+] nil
  def linkSamplesWithFiles()
    # First, set up a hash with files as keys and an array of samples as values
    genbConfig = BRL::Genboree::GenboreeConfig.load()
    @dbu = BRL::Genboree::DBUtil.new(genbConfig.dbrcKey, nil, nil)
    @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @userId)
    filehelperObj = BRL::Genboree::REST::Helpers::FileApiUriHelper.new()
    sampleHelperObj = BRL::Genboree::REST::Helpers::SampleApiUriHelper.new()
    dbHelperObj = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
    sampleArray = []
    @inputs.each { |input|
      if(input =~ BRL::Genboree::REST::Helpers::FileApiUriHelper::NAME_EXTRACTOR_REGEXP) # Its a file
        # See the 'type' of the file: if it is not text, download and make sure its either sff or sra
        fileUriObj = URI.parse(input)
        apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/type?", @hostAuthMap)
        apiCaller.get()
        fileType = apiCaller.parseRespBody['data']['text']
        if(fileType != 'text')
          fileName = "#{CGI.escape(File.basename(filehelperObj.extractName(input)))}"
          ww = File.open(fileName, 'w')
          apiCaller.setRsrcPath("#{fileUriObj.path}/data?")
          apiCaller.get() { |chunk| ww.print(chunk) }
          ww.close()
          exp = BRL::Util::Expander.new(fileName)
          exp.extract()
          raise "Your file: #{CGI.unescape(fileName)} is a multi-file archive. The tool does not support linking samples to multi-file archives. " if(exp.uncompressedFileList.size > 1)
          sn = BRL::Genboree::Helpers::Sniffer.new(exp.uncompressedFileList[0])
          dataFormat = sn.autoDetect
          if(dataFormat.nil? or (dataFormat != 'sra' and dataFormat != 'sff'))
            `rm -f #{fileName} #{exp.uncompressedFileName}`
            raise "#{CGI.unescape(fileName)} is not sra/sff. Only sra/sff files are allowed to be linked to samples."
          end
          `rm -f #{fileName} #{exp.uncompressedFileName}`
        end
        if(!sampleArray.empty?)
          @fileSampleHash[File.basename(@file)] = sampleArray
        end
        @file = input
        sampleArray = []
      else # Its a sample
        sampleName = sampleHelperObj.extractName(input)
        sampleArray << sampleName
        # Simulate a tabbed file upload
        payload = "#name\tfileLocation\n"
        payload << "#{sampleName}\t#{@file}\n"
        uri = URI.parse(dbHelperObj.extractPureUri(input))
        apiCaller = ApiCaller.new(uri.host, "#{uri.path}/bioSamples?format=tabbed", @hostAuthMap)
        apiCaller.put(payload)
      end
    }
    if(!sampleArray.empty?)
      @fileSampleHash[File.basename(@file)] = sampleArray
    end
    sampleArray = []
  end
  
  def addToolTitle(jsonObj)
    jsonObj['context']['toolTitle'] = @toolConf.getSetting('ui', 'label')
    return jsonObj
  end

  # parses the json input file
  # [+inputFile+] json file
  # [+returns+] nil
  def parseInputFile(inputFile)
    jsonObj = JSON.parse(File.read(inputFile))
    @inputs = jsonObj['inputs']
    dbrcFile = File.expand_path(ENV['DBRC_FILE'])
    @toolIdStr = jsonObj['context']['toolIdStr']
    @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr)
    jsonObj = addToolTitle(jsonObj)
    @dbrcKey = jsonObj['context']['apiDbrcKey']
    @adminEmail = jsonObj['context']['gbAdminEmail']
    @userId = jsonObj['context']['userId']
    @jobId = jsonObj['context']['jobId']
    @context = jsonObj['context']
    @userEmail = jsonObj['context']['userEmail']
    @userLogin = jsonObj['context']['userLogin']
    @dbuKey = jsonObj['settings']['dbuKey']
    dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
    @user = dbrc.user
    @pass = dbrc.password
    @host = dbrc.driver.split(/:/).last
    @scratchDir = jsonObj['context']['scratchDir']
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
    toolTitle = 'Sample - File Linker'

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
  EOS
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
    buff << "\nThe following file(s) and samples(s) has been linked: \n"
    @fileSampleHash.each_key { |file|
      samples = @fileSampleHash[file]
      samples.each { |sample|
        buff << " #{CGI.unescape(file.chomp("?"))}(File) -> #{CGI.unescape(sample)}(Sample) \n"
      }
    }
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
      toolTitle = 'Sample - File Linker'
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

  Description: This tool is intended to be used for linking samples to data file and is to be lanched via the workbench
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

  def self.performSampleFileLinker(optsHash)
    sampleFileLinkerObj = SampleFileLinker.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performSampleFileLinker(optsHash)
