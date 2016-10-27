#!/usr/bin/env ruby

# Loading libraries
require 'rubygems'
require 'open4'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/helpers/expander'
require 'brl/util/emailer'
# This script combines the two processes for uploading an LFF file and runs them serially.
# First the ruby script createZoomLevelsForLFF the java util LFF uploader, AutoUploder.

module BRL ; module Genboree

  class CreateZoomLevelAndUplodLFF

  def initialize(optsHash)

    @lffFile = optsHash['--inputFile']
    @noCompress = optsHash['--noCompDel']
    # Use inputFile as base name for err and out files, but strip off extension if any.
    @taskErrOutFilesBase = "#{File.dirname(@lffFile)}/#{File.basename(@lffFile, File.extname(@lffFile))}"

    # These can either be names or ids
    groupName = optsHash['--groupName']
    userName = optsHash['--userName']
    databaseName = optsHash['--databaseName']

    #Making dbUtil Object for database 'genboree'
    @genbConf = BRL::Genboree::GenboreeConfig.load
    @dbrcKey = optsHash['--dbrcKey'] ? optsHash['--dbrcKey'] : @genbConf.dbrcKey
    # ARJ: Hack to get around bug in how DBUtil is instantiated and that databaseid from command line is not refseqid or a databaseName
    @dbu = BRL::Genboree::DBUtil.new("#{@dbrcKey}", nil, nil)


    if(userName =~ /^[\-]?\d+$/)
      @userId = userName.to_i
    else
      userVal = @dbu.getUserByName(userName)
      raise ArgumentError.new("#{userName} does not exist") if(userVal.empty?)
      @userId = userVal.first['userId']
    end

    userRec = @dbu.getUserByUserId(@userId)
    if(!userRec.nil? and !userRec.empty?)
      @userName = "#{userRec.first['firstName']} #{userRec.first['lastName']}"
    end

    if(groupName =~ /^\d+$/)
      @groupId = groupName.to_i
      groupRecs = @dbu.selectGroupById(@groupId)
      raise ArgumentError.new("Group with groupId: #{@groupId} does not exist") if(groupRecs.nil? or groupRecs.empty?)
      @groupName = groupRecs.first['groupName']
    else # groupName command line arg is an actual group name
      # Get groupId
      groupRecs = @dbu.selectGroupByName(groupName)
      raise ArgumentError.new("Group with group name: #{groupName} does not exist") if(groupRecs.nil? or groupRecs.empty?)
      @groupId = groupRecs.first['groupId']
    end

    if(databaseName =~ /^\d+$/)
      @refseqId = databaseName.to_i
      refseqRecord = @dbu.selectDBNameByRefSeqID(@refseqId)
      raise ArgumentError.new("Database with refseqId: #{@refseqId} does not exist") if(refseqRecord.nil? or refseqRecord.empty?)
      @databaseName = refseqRecord.first['databaseName']
    else # databaseName command line arg is an actual database name
      # Get refseqid for it
      refseqRecs = @dbu.selectRefseqByDatabaseName(databaseName)
      raise ArgumentError.new("User database #{databaseName} does not exist") if(refseqRecs.nil? or refseqRecs.empty?)
      @databaseName = databaseName
      @refseqId = refseqRecs.first['refSeqId']
    end

    refseqRecord = @dbu.selectRefseqByDatabaseName(@databaseName)
    raise ArgumentError.new("Database: #{@databaseName} does not have refseqName") if(refseqRecord.nil? or refseqRecord.empty?)
    @refseqName = refseqRecord.first['refseqName']

    @userEmail = optsHash['--userEmail'] ? optsHash['--userEmail'] : false
    @onCluster = optsHash['--onCluster'] ? true : false
  end

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Description: This script is for importing LFF data.  It executes both the ruby script createZoomLevelsForLFF
               and the java utility AutoUploader serially.  First running createZoomLevelsForLFF then on success AutoUploader.

  Options:
    -i  --inputFile     Full path to the lff file
    -g  --groupName     Name or id of the group whose database the data will be uploaded to (required)
    -u  --userName      Genboree user name or user id of the person running the program (required)
    -d  --databaseName  Full name of the database or refseqid to which the data will be uploaded (required)
    -C  --noCompDel     Do not compress/delete (optional)
    -S  --sendEmail     Send email (optional)
    -v  --version       Version of the program
    -h  --help          Display help

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

  def self.processArguments()
    methodName="createZoomLevelsAndUploadLFF"
    optsArray=[
      ['--inputFile','-i',GetoptLong::REQUIRED_ARGUMENT],
      ['--groupName','-g',GetoptLong::REQUIRED_ARGUMENT],
      ['--userName','-u',GetoptLong::REQUIRED_ARGUMENT],
      ['--databaseName','-d',GetoptLong::REQUIRED_ARGUMENT],
      ['--noCompDel','-C',GetoptLong::OPTIONAL_ARGUMENT],
      ['--dbrcKey', '-K',GetoptLong::OPTIONAL_ARGUMENT],
      ['--userEmail', '-E',GetoptLong::OPTIONAL_ARGUMENT],
      ['--onCluster', '-c',GetoptLong::OPTIONAL_ARGUMENT],
      ['--version','-v',GetoptLong::NO_ARGUMENT],
      ['--help','-h',GetoptLong::NO_ARGUMENT]
    ]
    begin
      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
    rescue Exception => err
      printUsage("USAGE ERROR: #{err.message}.\n\n")
    end
    if(optsHash.key?('--help'))
      printUsage()
    elsif(optsHash.key?('--version'))
      printVersion()
    end
    printUsage("USAGE ERROR: Some required arguments are missing.\n\n") unless(progOpts.getMissingOptions().empty?)
    return optsHash
  end


  def run()
    expanderObj = BRL::Genboree::Helpers::Expander.new(@lffFile)
    expanderObj.forcedOutputFileName = "#{@taskErrOutFilesBase}.inflatedData"
    expanderObj.extract(desiredType = 'text')
    fullPathToUncompFile = expanderObj.uncompressedFileName
    @zoomCmdOutFile = "#{@taskErrOutFilesBase}.createZoomLevelsForLFF.out"
    @zoomCmdErrFile = "#{@taskErrOutFilesBase}.createZoomLevelsForLFF.err"

    zoomCmd = "createZoomLevelsForLFF.rb -i #{CGI.escape(fullPathToUncompFile)} -d #{@refseqId} -g #{@groupId} -u #{@userId} -C -k #{@dbrcKey} > #{@zoomCmdOutFile} 2> #{@zoomCmdErrFile} "
    $stderr.puts "Attempting to run Zoom Level Script:\n#{zoomCmd}"
    # Need to ensure that this returns proper codes on exit.  Only proceed if success
    pid, stdin, stdout, stderr = Open4.popen4(zoomCmd)
    stdin.close
    stderr.each { |line| $stderr.puts line }
    stdout.each { |line| $stderr.puts line }
    stderr.close
    stdout.close
    ignored, errorLevel = Process::waitpid2(pid)
    zoomCmdSuccess = (errorLevel.to_i == 0)
    $stderr.puts "zoomCmdSuccess: #{zoomCmdSuccess.inspect}"
    if(zoomCmdSuccess)
      @uploadCmdOutFile = "#{@taskErrOutFilesBase}.autoUploader.out"
      @uploadCmdErrFile = "#{@taskErrOutFilesBase}.autoUploader.err"
      @uploadCmd = ""
      @uploadCmd << "module load jdk/1.5; " if(@onCluster)
      javaPgm = @onCluster ? "org.genboree.upload.AutoUploaderCluster" : "org.genboree.upload.AutoUploader"
      @uploadCmd << "java -classpath $CLASSPATH -Xmx1800M #{javaPgm} -t lff -u #{@userId} -r #{@refseqId} -f #{fullPathToUncompFile} -b"
      # Don't have auto uploader java do compression when run by this driver.
      # - instead, this script will compress more safely, based on consistent file naming.
      @uploadCmd += " > #{@uploadCmdOutFile} 2> #{@uploadCmdErrFile} "
      $stderr.puts "Attempting to run the java uploader:\n#{@uploadCmd}"
      `#{@uploadCmd}`
      lffCmdSuccess = $?.dup()
      $stderr.puts "... done running java uploader"
      # Send email if required
      if(@userEmail)
        if(lffCmdSuccess.exitstatus == 0)
          msg = "Hello #{@userName},\n\n"
          msg += "#{File.read(@uploadCmdOutFile)}" if(File.exists?(@uploadCmdOutFile))
          msg << "\n\nYou can now login to Genboree and visualize your data.\n\n"
          msg << "Thank you for using Genboree.\n\nThe Genboree team."
          email = BRL::Util::Emailer.new()
          email.setHeaders("do_not_reply@genboree.org", @userEmail, "LFF API Upload [SUCCESS]")
          email.setMailFrom("do_not_reply@genboree.org")
          email.addRecipient(@genbConf.gbAdminEmail)
          email.addRecipient(@userEmail)
          email.setBody(msg)
          email.send()
        else
          msg = "Hello #{@userName},\n\n"
          msg += "There were errors uploading your data.\n\n"
          msg += "Job details:\n"
          msg += "Group: #{@groupName.inspect}\n"
          msg += "Database ID: #{@refseqId.inspect}\n"
          msg += "Database Name: #{@refseqName.inspect}\n"
          errorMsg = ""
          errorMsg << "#{File.read(@uploadCmdOutFile)}" if(File.exists?(@uploadCmdOutFile))
          # Try to read the err file if out is empty
          if(errorMsg.empty?)
            errorMsg << File.read(@uploadCmdErrFile) if(File.exists?(@uploadCmdErrFile))
          end
          msg += "\n\nError message from upload tool:\n#{errorMsg}\n\n"
          msg += "Please contact #{@genbConf.gbAdminEmail} with the above information.\n\nThe Genboree team."
          email = BRL::Util::Emailer.new()
          email.setHeaders("do_not_reply@genboree.org", @userEmail, "LFF API Upload [FAILED]")
          email.setMailFrom("do_not_reply@genboree.org")
          email.addRecipient(@genbConf.gbAdminEmail)
          email.addRecipient(@userEmail)
          email.setBody(msg)
          email.send()
        end
      end
    end

    # Compress intermediate files if asked.
    unless(@noCompress)
      gzipCmd = "gzip -9 #{@taskErrOutFilesBase}* "
      $stderr.puts "About to gzip intermediate files via this command:\n    #{gzipCmd.inspect}"
      $stderr.flush # including output of this script...must be LAST output to stderr!
      `#{gzipCmd}`
    end


  end

end
end ; end

# --------------------------------------------------------------------------
# MAIN (command line execution begins here)
# --------------------------------------------------------------------------
begin
  # process args
  optsHash = BRL::Genboree::CreateZoomLevelAndUplodLFF.processArguments()
  # instantiate
  cmdObj = BRL::Genboree::CreateZoomLevelAndUplodLFF.new(optsHash)
  # call
  cmdObj.run
  exitVal = BRL::Genboree::OK
rescue => err
	errTitle =  "(#{$$}) #{Time.now()} CreateZoomLevelAndUplodLFF - FATAL ERROR: Exception listed below.\n"
	errstr   =  "   The error message was: '#{err.message}'.\n"
	errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
	$stderr.puts errTitle + errstr
	exitVal = BRL::Genboree::FATAL
end

exit(exitVal)
