#!/usr/bin/env ruby

# Load libraries
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/util/emailer'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/util/samTools'
require 'uri'
require 'json'
ENV['DBRC_FILE']
ENV['PATH']
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

# Driver Class
class DriveROILifter
  NON_ROILIFTER_SETTINGS = { 'clusterQueue' => true }
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
    begin
      # Parse the input json file
      parseInputFile(@jsonFile)
      # Run roiLifter program
      runROILifter()
      # process lff files before uploading
      mungeLffFiles()
      # Transfer output files to targets
      transferFiles()
      # Uploads lff file as track in Genboree to both target dbs
      uploadLff() 
      # Send Email to User with success notification
      sendSuccessEmail()
    rescue Exception => err
      # Also sends out Failure email to user
      displayErrorMsgAndExit(err)
    end
  end

  # Downloads input track and runs roiLifter tool
  # [+returns+] nil
  def runROILifter()
    @trkApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new()
    # First download the ROI track
    uri = URI.parse(@input)
    host = uri.host
    rcscUri = "#{uri.path.chomp("?")}/annos?format=lff"
    fileName = "#{CGI.escape(@trkApiHelper.extractName(@input))}.lff"
    writer = File.open(fileName, "w")
    apiCaller = ApiCaller.new(host, rcscUri, @user, @pass)
    outBuffer = ''
    $stderr.puts "Downloading track: #{@input.inspect}"
    apiCaller.get() { |chunk|
      outBuffer << chunk
      if(outBuffer.size >= MAX_OUT_BUFFER)
        writer.print(outBuffer)
        outBuffer = ''
      end
    }
    if(!outBuffer.empty?)
      writer.print(outBuffer)
      outBuffer = ''
    end
    writer.close()
    if(!apiCaller.succeeded?)
      @emailMessage = "CRITICAL ERROR:\nDownloading track: #{@lffType}:#{@lffSubType} failed."
      raise apiCaller.respBody.inspect
    end
    # Run the tool
    stderrFile = "comparative_epigenomics_lifter.stderr"
    stdoutFile = "comparative_epigenomics_lifter.stdout"
    cmd = "module load jksrc; comparative_epigenomics_lifter.pl --srcLff=#{fileName} --srcVer=#{@srcVer} --destVer=#{@destVer} --lffType=#{@lffType} --lffSubtype=#{@lffSubType} --minRatio=#{@ratioFilter} "
    cmd << " --multiple=1" if(@multiple)
    cmd << " >#{stdoutFile} 2> #{stderrFile}"
    $stderr.puts "Launching command: #{cmd.inspect}"
    exitStatus = system(cmd)
    if(!exitStatus)
      exitstatusObj = $?.dup()
      @emailMessage = "CRITICAL ERROR while running comparative_epigenomics_lifter.pl.\n\nstderr:#{File.read(stderrFile)}\nstdout:#{File.read(stdoutFile)}"
      raise "Cmd: #{cmd.inspect} failed.\n Exitstatus: #{exitstatusObj.inspect}"
    end
    @srcFile = CGI.escape("#{@lffType}:#{@lffSubType}.#{@srcVer}.out.lff")
    @destFile = CGI.escape("#{@lffType}:#{@lffSubType}.#{@destVer}.out.lff")
  end
  
  # Processes output lff files so that if many records from src matches one rec in the dest,
  # the redundancy in the target lff file is removed by adding special chars to the names
  # and finally making the names in the src lff file match the *changed* names in the target file
  # [+returns+] nil
  def mungeLffFiles()
    # First sort the target lff file by landmark:
    cmd = "sort -t $'\t' -k 6,6 -k 7,7 -k 8,8 -k 3,3 #{@destFile} > tmp_sorted_#{@destFile}"
    exitStatus = system(cmd)
    exitObj = $?.dup()
    if(!exitStatus)
      @emailMessage = "Sorting Target Lff File by Landmark Failed."
      raise "Sort cmd Failed:\nCmd: #{cmd.inspect}\nexitStatus: #{exitObj.inspect}"
    end
    
    # Next go through the sorted lff file and modify names if redundant record
    reader = File.open("tmp_sorted_#{@destFile}")
    writer = File.open("sorted_#{@destFile}", "w")
    prevLandmark = nil
    dupCount = 1
    reader.each_line { |line|
      line.strip!
      next if(line.nil? or line.empty? or line =~ /^#/ or line =~ /^\s*$/)
      fields = line.split(/\t/)
      name = fields[2]
      chr = fields[5]
      startCoord = fields[6]
      endCoord = fields[7]
      currLandmark = "#{name}_#{chr}_#{startCoord}_#{endCoord}"
      if(!prevLandmark.nil?)
        if(prevLandmark == currLandmark)
          dupCount += 1
          fields[2] = "#{fields[2]}-#{dupCount}"
        else
          dupCount = 1
        end
      end
      lffLine = ""
      fields.each { |field|
        lffLine << "#{field}\t"  
      }
      writer.puts(lffLine)
      prevLandmark = "#{name}_#{chr}_#{startCoord}_#{endCoord}"
    }
    writer.close()
    reader.close()
    
    # Next, sort both the target and src lff files by the first column (conservedRegionID)
    cmd = "sort -t $'\t' -k1 sorted_#{@destFile} > sorted_id_#{@destFile}"
    exitStatus = system(cmd)
    exitObj = $?.dup()
    if(!exitStatus)
      @emailMessage = "Sorting Target Lff File by 'conservedRegionId' Failed."
      raise "Sort cmd Failed:\nCmd: #{cmd.inspect}\nexitStatus: #{exitObj.inspect}"
    end
    cmd = "sort -t $'\t' -k1 #{@srcFile} > sorted_id_#{@srcFile}"
    exitStatus = system(cmd)
    exitObj = $?.dup()
    if(!exitStatus)
      @emailMessage = "Sorting Src Lff File by 'conservedRegionId' Failed."
      raise "Sort cmd Failed:\nCmd: #{cmd.inspect}\nexitStatus: #{exitObj.inspect}"
    end
    
    # Before writing out the final lff file to upload, make sure both file have the same number of lines
    wcSrc = `wc sorted_id_#{@srcFile}`
    srcRes = wcSrc.split(/\s+/)
    srcLines = srcRes[1].to_i
    wcTarget = `wc sorted_id_#{@destFile}`
    targetRes = wcTarget.split(/\s+/)
    targetLines = targetRes[1].to_i
    raise "No of lines in src and target lff files not equal." if(targetLines != srcLines)
    # Finally, change the names in the src lff file to match those in the target lff file
    srcReader = File.open("sorted_id_#{@srcFile}")
    targetReader = File.open("sorted_id_#{@destFile}")
    srcWriter = File.open(@srcFile, "w")
    targetWriter = File.open(@destFile, "w")
    targetReader.each_line { |tline|
      tline.strip!
      sline = srcReader.readline
      sline.strip!
      tfields = tline.split(/\t/)
      sfields = sline.split(/\t/)
      sfields[2] = tfields[2] # Overwrite the names in source lff file with the names from the target lff file
      targetLff = ""
      tfields.size.times { |ii|
        next if(ii == 0) # skip the first column (conservedRegionID)
        targetLff << "#{tfields[ii]}\t"
      }
      targetWriter.puts(targetLff)
      srcLff = ""
      sfields.size.times { |ii|
        next if(ii == 0) # skip the first column (conservedRegionID)
        srcLff << "#{sfields[ii]}\t"  
      }
      srcWriter.puts(srcLff)
    }
    srcReader.close()
    targetReader.close()
    srcWriter.close()
    targetWriter.close()
    system("rm sorted_id_#{@srcFile} sorted_id_#{@destFile} tmp_sorted_#{@destFile}") # Remove unwanted files
  end
  
  # Transfer output files to target dbs
  # [+returns+] nil
  def transferFiles()
    # Transfer src lff to src db
    $stderr.puts "Transferring files..."
    uri = URI.parse(@srcDb)
    rcscUri = "#{uri.path.chomp("?")}/file/Comparative%20Epigenomics/#{CGI.escape(@studyName)}/ROI-Lifter/#{CGI.escape(@jobName)}/#{@srcFile}/data?"
    apiCaller = ApiCaller.new(uri.host, rcscUri, @user, @pass)
    apiCaller.put({}, File.open(@srcFile))
    if(!apiCaller.succeeded?)
      @emailMessage = "Failed to transfer file: #{@srcFile.inspect} "
      raise apiCaller.respBody.inspect
    end
    # Upload target lff to dest db
    uri = URI.parse(@destDb)
    rcscUri = "#{uri.path.chomp("?")}/file/Comparative%20Epigenomics/#{CGI.escape(@studyName)}/ROI-Lifter/#{CGI.escape(@jobName)}/#{@destFile}/data?"
    apiCaller = ApiCaller.new(uri.host, rcscUri, @user, @pass)
    apiCaller.put({}, File.open(@destFile))
    if(!apiCaller.succeeded?)
      @emailMessage = "Failed to transfer file: #{@destFile.inspect}"
      raise apiCaller.respBody.inspect
    end
  end

  
  # Uploads Lff File as a track to both target dbs
  # [+returns+] nil
  def uploadLff()
    # Upload src track to src db
    $stderr.puts "Uploading tracks..."
    uri = URI.parse(@srcDb)
    rcscUri = "#{uri.path.chomp("?")}/annos?format=lff&userId=#{@userId}"
    apiCaller = ApiCaller.new(uri.host, rcscUri, @user, @pass)
    apiCaller.put({}, File.open(@srcFile))
    if(!apiCaller.succeeded?)
      @emailMessage = "Failed to upload #{@srcFile} as track"
      raise apiCaller.respBody.inspect
    end
    # Upload dest trk to dest db
    uri = URI.parse(@destDb)
    rcscUri = "#{uri.path.chomp("?")}/annos?format=lff&userId=#{@userId}"
    apiCaller = ApiCaller.new(uri.host, rcscUri, @user, @pass)
    apiCaller.put({}, File.open(@destFile))
    if(!apiCaller.succeeded?)
      @emailMessage = "Failed to upload #{@destFile} as track"
      raise apiCaller.respBody.inspect
    end
  end
  
 
  
  # parses the json input file and sets up required instance variables
  # [+inputFile+] json file
  # [+returns+] nil
  def parseInputFile(inputFile)
    jsonObj = JSON.parse(File.read(inputFile))
    # Get Input/Output
    @input = jsonObj['inputs'][0]
    @outputs = jsonObj['outputs']
    dbrcFile = File.expand_path(ENV['DBRC_FILE'])
    # Get Context Info:
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
    @ratioFilter = jsonObj['settings']['ratioFilter']
    @lffType = jsonObj['settings']['lffType']
    @lffSubType = jsonObj['settings']['lffSubType']
    @srcVer = jsonObj['settings']['srcVer']
    @destVer = jsonObj['settings']['destVer']
    @srcDb = jsonObj['settings']['srcDb']
    @destDb = jsonObj['settings']['destDb']
    @multiple = jsonObj['settings']['multiple']
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
    toolTitle = 'ROI-Lifter'

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
      Ratio Filter   : #{@ratioFilter}
      Track Name     : #{@lffType}:#{@lffSubType}
      
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
    buff << "\nYou should shortly recieve an email once the LFF files have finished uploading." 
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
      toolTitle = 'ROI-Lifter'
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

  Description: This wrapper is intended to used for running the ROI-Lifter tool via the Genboree Workbench
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

  def self.performDriveROILifter(optsHash)
    driveROILifterObj = DriveROILifter.new(optsHash) # Constructor will run required programs, transfer and upload files and send out success/failure emails
  end

end

optsHash = RunScript.parseArgs()
RunScript.performDriveROILifter(optsHash)
