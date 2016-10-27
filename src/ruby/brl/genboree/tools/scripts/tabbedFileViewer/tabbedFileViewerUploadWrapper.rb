#!/usr/bin/env ruby

# Load libraries
require 'json'
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/dbUtil'
require 'brl/genboree/constants'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/helpers/fileUploadUtils'
include BRL::Genboree::Helpers

# Main Class
class TabbedFileViewerUploader
  # Constructor
  # [+optsHash+] command line args
  def initialize(optsHash)
    @jobId = nil
    @context = nil
    @userEmail = nil
    @emailMessage = ""
    @jsonFile = optsHash['--inputFile']
    @genbConf = BRL::Genboree::GenboreeConfig.load(ENV['GENB_CONFIG'])

    begin
      # Read our JSON job file
      parseInputFile(@jsonFile)

      # Create a data file with our data to upload, with new LFF class, type & subtype
      # NOTE: This will essentially create a copy of the data that is in the DB file area,
      #     : into the genboreeUploads area. So if uploads are not cleaned out regularly, 
      #     : redundancy can occurr
      dataFilePath = createTempDataFile(@inputs.first(), @context['inputFormat'])

      # Perform the actual upload
      performUpload(dataFilePath, @context['inputFormat'])
    rescue Exception => err
      # NOTE: The actual upload script will take care of notifying the user of success or failure
      #     : of the upload, so all we need to do is notify the user of an error in this script
      displayErrorMsgAndExit(err)
    end
  end
  
  # parses the json input file
  # [+inputFile+] json file
  # [+returns+] nil
  def parseInputFile(inputFile)
    jsonObj = JSON.parse(File.read(inputFile))
    @inputs = jsonObj['inputs']
    @context = jsonObj['context']
    @userId = jsonObj['context']['userId']
    @jobId = jsonObj['context']['jobId']
    @dbuKey = jsonObj['settings']['dbuKey']
    @adminEmail = jsonObj['context']['gbAdminEmail']
    @userEmail = jsonObj['context']['userEmail']
    @scratchDir = jsonObj['context']['scratchDir']
    @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
  end
 
  def createTempDataFile(fileUri, inputFormat='lff')
    cpCmd = ""
    # Create a directory to store the upload data file - use a temp directory as it will be deleted
    uploadDir = FileUploadUtils.createFinalDir(BRL::Genboree::Constants::UPLOADDIRNAME, "tfvUpload_#{Time.now().to_s.gsub(' ', '_')}_#{rand(100)}", @context['userLogin'])


    # Get our file path from this file URI
    dbu = BRL::Genboree::DBUtil.new(@dbuKey, nil, nil)
    fileApiHelper = BRL::Genboree::REST::Helpers::FileApiUriHelper.new(dbu, @genbConf)
    db = CGI.escape(fileApiHelper.dbApiUriHelper.extractName(@inputs[0]))
    grp = CGI.escape(fileApiHelper.dbApiUriHelper.grpApiUriHelper.extractName(@inputs[0]))
    file = CGI.escape(fileApiHelper.extractName(@inputs[0]))
    filePath = "#{@genbConf.gbDataFileRoot}/grp/#{grp}/db/#{db}/#{file}"

    # Copy the data file
    if(inputFormat == 'lff')
      # If lff format, we need to do a replace of the old class
      oldClass = @context['lffInfo']['oldClass']
      oldType = @context['lffInfo']['oldType']
      oldSubtype = @context['lffInfo']['oldSubtype']
      newClass = @context['specOpts']['extraOptions']['class']
      newType = @context['specOpts']['extraOptions']['type']
      newSubtype = @context['specOpts']['extraOptions']['subtype']
      
      cpCmd = "sed -e 's/^#{oldClass}\t/#{newClass}\t/g' -e 's/\t#{oldType}\t#{oldSubtype}\t/\t#{newType}\t#{newSubtype}\t/g' <#{filePath} > #{File.join(uploadDir, File.basename(filePath))}"
    else
      cpCmd = "cp #{filePath} #{uploadDir} 2>&1"
    end
    output = `#{cpCmd}`
    raise RuntimeError.new("An error occurred while trying to copy the source file to genboree uploads location: #{output}") unless(output.empty?)

    # Return our path so we can delete this temp file later
    return File.join(uploadDir, File.basename(filePath))
  end

  def performUpload(dataFilePath, inputFormat='lff')
    debug = true
    useCluster = (@genbConf.useClusterForGBUpload == "true" || @genbConf.useClusterForGBUpload == "yes")

    # Perform upload - NOTE: Our file is not compressed because the tabbed file viewer read it, so nameOfExtractedFile = dataFilePath
    success = FileUploadUtils.upload(inputFormat, dataFilePath, dataFilePath, @userId, @context['specOpts']['refseqId'], useCluster, @genbConf, @context['specOpts'], debug)
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
  
  # sends error email to recipients about the job status
  # [+returns+] no return value
  def sendErrorEmail()
    @jobId = "Unknown Job Id" if(@jobId.nil?)
    @userEmail = @genbConf.gbAdminEmail if(@userEmail.nil?)
    
    # EMAIL TO USER:
    # appropriate tool title
    if(@context and @context['toolTitle'])
      toolTitle = @context['toolTitle']
    else
      toolTitle = 'Tabbed File Viewer - Annotation Uploader'
    end
    
    # email body
    @emailMessage = "There was an unknown problem." if(@emailMessage.nil? or @emailMessage.empty?)
    prefix = "Unfortunately your #{toolTitle} job has failed. Please contact the Genboree Team (#{@genbConf.gbAdminEmail}) "
    prefix << "with the error details for help with this problem.\n\nERROR DETAILS:\n\n#{@emailMessage}"
    body = buildEmailBodyPrefix(prefix)
    body << "\n\n- The Genboree Team"
    
    # send email with subject and body
    sendEmail(@userEmail, "GENBOREE NOTICE: Your #{toolTitle} job failed", body)
  end
end

# Class for running the script and parsing args
class RunScript
  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="
  
  Author: Michael Smith (BNI)
  
  Description: This tool will process a specified data file and upload the contents as Annotation elements to Genboree, it is to be lanched via the workbench 
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

  def self.uploadAnnotations(optsHash)
    uploadObj = TabbedFileViewerUploader.new(optsHash)
  end
end

optsHash = RunScript.parseArgs()
RunScript.uploadAnnotations(optsHash)
