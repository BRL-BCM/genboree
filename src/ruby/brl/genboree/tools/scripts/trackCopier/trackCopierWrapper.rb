#!/usr/bin/env ruby

# Loading libraries
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
require 'brl/genboree/rest/helpers/classApiUriHelper'
require 'uri'
require 'json'
ENV['DBRC_FILE']
ENV['PATH']
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

# Main wrapper class
class TrackCopierWrapper

  # Constructor
  # [+optsHash+] hash with command line args
  # [+returns+] nil
  def initialize(optsHash)
    @jsonFile = optsHash['--inputFile']
    begin
      parseInputFile(@jsonFile)
      runTrackCopier()
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end
  end

  # Runs trackCopier.rb
  # [+returns+] nil
  def runTrackCopier()
    # First collect all tracks in an array:
    dbHelperObj = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
    classHelperObj = BRL::Genboree::REST::Helpers::ClassApiUriHelper.new()
    @inputsList = []
    @inputUri.each { |inputUri|
      if(inputUri =~ BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP)
        @inputsList.push(inputUri)
      else # Must be a class
        aliasUri = inputUri
        className = classHelperObj.extractName(aliasUri)
        dbUri = dbHelperObj.extractPureUri(aliasUri)
        uri = URI.parse(dbUri)
        rcscUri = uri.path.chomp("?")
        rcscUri << "/trks?detailed=true&class=#{CGI.escape(className)}"
        rcscUri << "&gbKey=#{dbHelperObj.extractGbKey(inputUri)}" if(dbHelperObj.extractGbKey(inputUri))
        # Get all tracks for this class
        apiCaller = WrapperApiCaller.new(uri.host, rcscUri, @userId)
        apiCaller.get()
        if(!apiCaller.succeeded?)
          raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
        end
        retVal = apiCaller.parseRespBody()
        tracks = retVal['data']
        tracks.each { |track|
          rsrcUri = "#{dbUri.chomp("?")}/trk/#{CGI.escape(track['name'])}?"
          rsrcUri << "gbKey=#{dbHelperObj.extractGbKey(inputUri)}" if(dbHelperObj.extractGbKey(inputUri))
          @inputsList.push(rsrcUri)
        }
      end
    }

    # Make the input file that 'trackCopier.rb' needs
    propFile = "#{@scratchDir}/#{Time.now.to_f}_prop.txt"
    propWriter = File.open(propFile, "w")
    propWriter.puts("inputTracks=#{@inputsList.join(",")}")
    propWriter.puts("outputDatabase=#{@outUri}")
    propWriter.close()
    # Next run the tool
    errFile = "#{@scratchDir}/#{Time.now.to_f}.err"
    outFile = "#{@scratchDir}/#{Time.now.to_f}.out"
    cmd = ""
    if(!@deleteSourceTracks)
      cmd = "trackCopier.rb -i #{propFile} -k #{@dbrcKey} -u #{@userId} -s #{@scratchDir} -l #{@userLogin} -j #{@jobId} > #{outFile} 2> #{errFile}"
    else
      cmd = "trackCopier.rb -i #{propFile} -k #{@dbrcKey} -u #{@userId} -d -s #{@scratchDir} -l #{@userLogin} -j #{@jobId} > #{outFile} 2> #{errFile}"
    end
    $stderr.puts "cmd to run: #{cmd}"
    exitStatus = system(cmd)
    # Check if the sub script ran successfully
    if(!exitStatus)
      # Sub script failed
      # read the stderr and send an error report via email
      @jobId = "Unknown Job Id" if(!@jobId)
      @emailMessage = "Stderr for the job (jobId: #{@jobId}):\n\n"
      @emailMessage << File.read(outFile)
      raise @emailMessage
    end
    sendSuccessEmail()
  end

  # parses the json input file
  # [+inputFile+] json file
  # [+returns+] nil
  def parseInputFile(inputFile)
    jsonObj = JSON.parse(File.read(inputFile))
    @inputUri = jsonObj['inputs']
    @outUri = jsonObj['outputs'][0]
    dbrcFile = File.expand_path(ENV['DBRC_FILE'])
    @dbrcKey = jsonObj['context']['apiDbrcKey']
    @deleteSourceTracks = jsonObj['settings']['deleteSourceTracks']
    @adminEmail = jsonObj['context']['gbAdminEmail']
    @userId = jsonObj['context']['userId']
    @jobId = jsonObj['context']['jobId']
    @userEmail = jsonObj['context']['userEmail']
    @userLogin = jsonObj['context']['userLogin']
    @toolPrefix = jsonObj['context']['toolScriptPrefix']
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
    $stderr.puts "ERROR:\n #{msg}\n"
    $stderr.puts "ERROR Backtrace:\n #{msg.backtrace.join("\n")}"
    if(!@emailMessage)
      @emailMessage = "ERROR:\n #{msg}\n"
      @emailMessage << "ERROR Backtrace:\n #{msg.backtrace.join("\n")}"
    end
    sendErrorEmail()
    exit(1)
  end

  def sendSuccessEmail()
    genbConf = ENV['GENB_CONFIG']
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    emailer = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)
    emailer = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)
    @jobId = "Unknown Job Id" if(!@jobId)
    @adminEmail = genbConfig.gbAdminEmail if(!@adminEmail)
    emailer.addRecipient(@userEmail)
    emailer.addRecipient(@adminEmail)
    emailer.setHeaders(genbConfig.gbFromAddress, @userEmail, "GENBOREE NOTICE: Track Copier Job completed successfully.")
    emailer.setMailFrom(genbConfig.gbFromAddress)
    @emailMessage = "Dear #{@userLogin},\nyour Track Copier Job (JobId: #{@jobId}) has completed successfully.\n"
    @emailMessage << "The following tracks have been "
    @emailMessage << ( @deleteSourceTracks ? "moved:\n\n" : "copied:\n\n")
    trkHelperObj = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new()
    @inputsList.each { |trk|
      @emailMessage << "  #{trkHelperObj.lffType(trk)}:#{trkHelperObj.lffSubtype(trk)}\n\n"
    }
    @emailMessage << "Thank you for using the Genboree Workbench,\n\nThe Genboree Team."
    emailer.setBody(@emailMessage)
    emailer.send()
  end

  # Sends an email containing the error report
  # [+returns+] nil
  def sendErrorEmail()
    genbConf = ENV['GENB_CONFIG']
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    emailer = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)
    emailer = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)
    @jobId = "Unknown Job Id" if(!@jobId)
    @adminEmail = genbConfig.gbAdminEmail if(!@adminEmail)
    if(!@userEmail.nil?)
      emailer.addRecipient(@userEmail)
      emailer.addRecipient(@adminEmail)
      emailer.setHeaders(genbConfig.gbFromAddress, @userEmail, "GENBOREE NOTICE: Problem with Track Copier Job [Failed]")
      emailer.setMailFrom(genbConfig.gbFromAddress)
      @emailMessage = "There was an unknown problem." if(@emailMessage.empty?)
      emailer.setBody("Dear #{@userLogin},\n Unfortunately your Job with id: #{@jobId} has failed. Please contact the Genboree Team.\n\nError Details: #{@emailMessage}")
      emailer.send()
    end
    # Send email to gbAdminEmail with the error message to alert that the process has failed
    subjectTxt = "Genboree Status Report for #{__FILE__} for jobId: #{@jobId} [Failed]"
    email = BRL::Util::Emailer.new()
    email.setHeaders("do_not_reply@genboree.org", @adminEmail, subjectTxt)
    email.setMailFrom("do_not_reply@genboree.org")
    email.addRecipient(@adminEmail)
    email.setBody(@emailMessage)
    email.send()
  end

end

# Class for running the script and parsing args
class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Sameer Paithankar

  Description: This tool is a wrapper for the track copier tool . Intended to be run via the workbench
  Notes: Intended to be called via the Genboree Workbench
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

  def self.performTrackCopierWrapper(optsHash)
    trackCopierWrapperObj = TrackCopierWrapper.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performTrackCopierWrapper(optsHash)
