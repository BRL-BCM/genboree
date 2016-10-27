#!/usr/bin/env ruby

# Note: This version of the wigToBigWigWrapper runs the 'bedGraphToBigWig' program.


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
require 'uri'
require 'json'
ENV['DBRC_FILE']
ENV['PATH']
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

class RunWigToBigWig

  # Constructor
  # [+optsHash+] hash with command line args
  # [+returns+] nil
  def initialize(optsHash)
    @userEmail = nil
    @groupName = optsHash['--groupName']
    @dbName = optsHash['--dbName']
    @trackName = optsHash['--trackName']
    @bigFile = optsHash['--bigwigFile']
    @aKey = optsHash['--apidbrcKey']
    @dKey = optsHash['--dbdbrcKey']
    @userEmail = optsHash['--email']
    @rsrcHost = optsHash['--rsrcHost']
    begin
      runApp()
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end
  end

  # downloads the data and run the wigToBigWig program
  # [+returns+] nil
  def runApp()
    # Get the host, user and pwd from the dbrcKey
    dbrcFile = File.expand_path(ENV['DBRC_FILE'])
    adbrc = BRL::DB::DBRC.new(dbrcFile, @aKey)
    @user = adbrc.user
    @pwd = adbrc.password
    @host = adbrc.driver.split(/:/).last
    timeStamp = Time.now.to_f
    # Now download the track
    $stderr.puts "Downloading wig file for track #{@trackName}"
    rsrcPath = "/REST/v1/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@dbName)}/trk/#{CGI.escape(@trackName)}/annos?format=bedGraph&modulusLastSpan=true" # 'modulusLastSpan=true' ensures we don't run off the end of the chromosome
    apiCaller = ApiCaller.new(@host, rsrcPath, @user, @pwd)
    bedGraphFile = "#{timeStamp}.bedGraph.tmp"
    writer = File.open(bedGraphFile, "w")
    apiCaller.get() { |chunk| writer.print(chunk)}
    writer.close()
    # remove track header
    bedGraphFile2 = "#{timeStamp}.bedGraph"
    system("grep -v 'track' #{bedGraphFile} > #{bedGraphFile2}")
    `rm #{bedGraphFile}`
    bedGraphFile = bedGraphFile2
    $stderr.puts "bedGraph file download complete"
    # Next write out the chr def file
    refFile = "#{timeStamp}.ref"
    refFileWriter = File.open(refFile, "w")
    $stderr.puts "Downloading entrypoints for the bedGraphToBigWig program"
    apiCaller = ApiCaller.new(@host, "/REST/v1/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@dbName)}/eps?", @user, @pwd)
    apiCaller.get()
    apiCaller.parseRespBody['data']['entrypoints'].each { |rec|
      refFileWriter.puts "#{rec['name']}\t#{rec['length']}"
    }
    refFileWriter.close()
    $stderr.puts "entrypoint(ref) file written"
    # Finally run the bedGraphToBigWig program
    @wigToBigWigOut = "#{timeStamp}_wigToBigWig.out"
    @wigToBigWigErr = "#{timeStamp}_wigToBigWig.err"
    wigToBigWigCmd = "bedGraphToBigWig #{bedGraphFile} #{refFile} #{@bigFile} > #{@wigToBigWigOut} 2> #{@wigToBigWigErr}"
    $stderr.puts "cmd to launch: #{wigToBigWigCmd}"
    exitStatus = system(wigToBigWigCmd)
    messBody = makeMessageBody(exitStatus, @bigFile)
    header = nil
    if(exitStatus and File.exists?(@bigFile))
      header = "success"
    else
      header = "failed"
    end
    sendStatusEmail(messBody, header)
    $stderr.puts "All Done"
  end

  # Displays error message and quits
  # [+msg+]  error message
  #  [+returns+] nil
  def displayErrorMsgAndExit(msg)
    $stderr.puts "ERROR from wigToBigWigWrapper.rb:\n #{msg}"
    $stderr.puts "ERROR Backtrace from wigToBigWigWrapper.rb:\n #{msg.backtrace}"
    @emailMessage = "ERROR: #{msg}\nBacktrace: #{msg.backtrace.join("\n")}\n\n"
    sendErrorEmail()
    exit(14)
  end

  def sendStatusEmail(message, header)
    genbConf = ENV['GENB_CONFIG']
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    emailer = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)
    emailer = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)
    if(!@userEmail.nil?)
      emailer.addRecipient(@userEmail)
      emailHeader = "GENBOREE NOTICE: bigWig job status [Success]" if(header == "success")
      emailHeader = "GENBOREE NOTICE: bigWig job status [Failed]" if(header == "failed")
      emailer.setHeaders(genbConfig.gbFromAddress, @userEmail, "#{emailHeader}.\n\n")
      emailer.setMailFrom(genbConfig.gbFromAddress)
      emailer.addHeader("Bcc: #{genbConfig.gbBccAddress}")
      emailer.setBody(message)
      emailer.send()
    end
    # Send email to gbAdminEmail with the error message to alert that the process has failed
    subjectTxt = "Genboree Status Report for #{__FILE__} [Success]" if(header == "success")
    subjectTxt = "Genboree Status Report for #{__FILE__} [Failed]" if(header == "failed")
    bodyTxt = message
    email = BRL::Util::Emailer.new()
    email.setHeaders("do_not_reply@genboree.org", genbConfig.gbAdminEmail, subjectTxt)
    email.setMailFrom("do_not_reply@genboree.org")
    email.addRecipient(genbConfig.gbAdminEmail)
    email.setBody(bodyTxt)
    email.send()
  end

  # Determine if the file creation was successful or not
  # [+exitStatus+] exit status of the wigToBigWig program
  # [+bigFile+] path to the bigWigFile
  # [+returns+] body
  def makeMessageBody(exitStatus, bigFile)
    body = ""
    if(exitStatus and File.exists?(bigFile))
      @hostname = @host
      # Try to get the dbKey, if the database has been unlocked
      dbu = BRL::Genboree::DBUtil.new(@dKey, nil, nil)
      groupRec = dbu.selectGroupByName(@groupName)
      groupId = groupRec.first['groupId'].to_i
      resourcesTableRecs = dbu.selectUnlockedResources(groupId)
      @gbKey = nil
      resourcesTableRecs.size.times { |recCount|
        if(resourcesTableRecs[recCount]['resourceUri'] == "/REST/v1/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@dbName)}")
          @gbKey = resourcesTableRecs[recCount]['unlockKey']
        end
      }
      @gbKey = 'xxxxxxxx' if(@gbKey.nil?)
      # get the db version
      refSeqRec = dbu.selectRefseqByNameAndGroupId(@dbName, groupId)
      @genomeTemplate = refSeqRec.first['refseq_version']
      body = "GENBOREE NOTICE: BigWig file created.\n\n"
      body << "This email is to confirm that your request to create the bigWig file for the following resource is complete\n"
      body << "Group: #{@groupName}\n"
      body << "Database: #{@dbName}\n"
      body << "Track: #{@trackName}\n\n"
      body << "You can retrieve the bigWig file using the API resource URL:\n"
      body << "http://#{@rsrcHost}/REST/#{BRL::REST::Resource::VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/trk/#{Rack::Utils.escape(@trackName)}/bigWig\n\n"
      body << "At the end of the following URL, If the gbKey is 'xxxxxxxx', replace it with the 'real' gbKey after unlocking the database\n"
      body << "http://#{@rsrcHost}/REST/#{BRL::REST::Resource::VER_STR}/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@dbName)}/trk/#{CGI.escape(@trackName)}/bigWig?gbKey=#{CGI.escape(@gbKey)}\n\n"
      body << "To get UCSC's custom track feature, click on the link below:\n"
      body << "http://#{@rsrcHost}/REST/#{BRL::REST::Resource::VER_STR}/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@dbName)}/trk/#{CGI.escape(@trackName)}?gbKey=#{CGI.escape(@gbKey)}&format=ucsc_browser&ucscType=bigWig\n\n"
      if(@genomeTemplate =~ /^\S/)
        body << "If unlocked, use this link to view the track in the UCSC browser.  Be sure to use the correct gbKey.\n"
        customText = "http://#{@rsrcHost}/REST/#{BRL::REST::Resource::VER_STR}/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@dbName)}/trk/#{CGI.escape(@trackName)}?gbKey=#{CGI.escape(@gbKey)}&format=ucsc_browser&ucscType=bigWig&ucscSafe=on"
        body << "http://genome.ucsc.edu/cgi-bin/hgTracks?db=#{@genomeTemplate}&hgct_customText=#{CGI.escape(customText)}\n\n"
        body << "Or view all the bigWig tracks for this database in the UCSC browser.  Be sure to use the correct gbKey.\n"
        customText = "http://#{@rsrcHost}/REST/#{BRL::REST::Resource::VER_STR}/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@dbName)}/trks?gbKey=#{CGI.escape(@gbKey)}&format=ucsc_browser&ucscType=bigWig&ucscSafe=on"
        body << "http://genome.ucsc.edu/cgi-bin/hgTracks?db=#{@genomeTemplate}&hgct_customText=#{CGI.escape(customText)}\n"
      end
    else
      body = "GENBOREE NOTICE: BigWig file NOT created.\n\n"
      body << "There were errors trying to create the bigWig file for the following resource.\n"
      body << "Group: #{@groupName}\n"
      body << "Database: #{@dbName}\n"
      body << "Track: #{@trackName}\n\n"
      body << "\n\nERRORS from UCSC (wigToBigWig):\n"
      errorReader = File.open(@wigToBigWigErr)
      body << "\n\nSTDERR:\n"
      errorReader.each_line { |line|
        body << line
      }
      errorReader.close()
      outReader = File.open(@wigToBigWigOut)
      body << "\n\nSTDOUT:\n"
      outReader.each_line { |line|
        body << line
      }
      outReader.close()
    end
    return body
  end

  # sends email to recipients about the job status
  # [+returns+] no return value
  def sendErrorEmail()
    genbConf = ENV['GENB_CONFIG']
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    emailer = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)
    emailer = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)
    body = "There were errors trying to create the bigWig file for the following resource.\n"
    body << "Group: #{@groupName}\n"
    body << "Database: #{@dbName}\n"
    body << "Track: #{@trackName}\n\n"
    mess = "#{body}#{@emailMessage}"
    if(!@userEmail.nil?)
      emailer.addRecipient(@userEmail)
      emailer.setHeaders(genbConfig.gbFromAddress, @userEmail, "GENBOREE NOTICE: BigWig file NOT created.\n\n")
      emailer.setMailFrom(genbConfig.gbFromAddress)
      emailer.addHeader("Bcc: #{genbConfig.gbBccAddress}")
      emailer.setBody(mess)
      emailer.send()
    end
    # Send email to gbAdminEmail with the error message to alert that the process has failed
    subjectTxt = "Genboree Status Report for #{__FILE__} [Failed]"
    bodyTxt = mess
    email = BRL::Util::Emailer.new()
    email.setHeaders("do_not_reply@genboree.org", genbConfig.gbAdminEmail, subjectTxt)
    email.setMailFrom("do_not_reply@genboree.org")
    email.addRecipient(genbConfig.gbAdminEmail)
    email.setBody(bodyTxt)
    email.send()
  end

end


# Class for running the script and parsing args
class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Sameer Paithankar

  Description: This tool is a wrapper for running the bedGraphToBigWig program on the cluster
  Note that the input args will not be validated since this tool is launched from the API and the args
  are already validated
  Notes: Intended to be called via the Genboree Workbench
    -g  --groupName                     => group name (required)
    -d  --dbName                        => db name (required)
    -t  --trackName                     => track name (required)
    -b  --bigwigFile                    => name of the output big wig file (required)
    -k  --apidbrcKey                    => api dbrc key of the server (required)
    -K  --dbdbrcKey                     => database dbrckey of the server (required)
    -e  --email                         => email id of the user (optional)
    -R  --rsrcHost                      => host name to use in email (required)
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
      ['--groupName','-g',GetoptLong::REQUIRED_ARGUMENT],
      ['--dbName','-d',GetoptLong::REQUIRED_ARGUMENT],
      ['--trackName','-t',GetoptLong::REQUIRED_ARGUMENT],
      ['--bigwigFile','-b',GetoptLong::REQUIRED_ARGUMENT],
      ['--apidbrcKey','-k',GetoptLong::REQUIRED_ARGUMENT],
      ['--dbdbrcKey','-K',GetoptLong::REQUIRED_ARGUMENT],
      ['--email','-e',GetoptLong::OPTIONAL_ARGUMENT],
      ['--rsrcHost','-R',GetoptLong::REQUIRED_ARGUMENT],
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

  def self.performRunWigToBigWig(optsHash)
    runWigToBigWigObj = RunWigToBigWig.new(optsHash)
  end

end


# Main
optsHash = RunScript.parseArgs()
RunScript.performRunWigToBigWig(optsHash)
