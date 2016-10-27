#!/usr/bin/env ruby
=begin

Author: Andrew R. Jackson <andrewj@bcm.tmc.edu>
Date  : July 17, 2004
=end

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'getoptlong'            # for GetoptLong class (command line option parse)
require 'stringio'              # String-as-I/O class
require 'net/smtp'
require 'brl/util/util'          # for to_hash extension of GetoptLong class
require 'brl/util/propTable'    # for PropTable class
require 'brl/util/textFileUtil' # For TextReader/Writer classes
require 'brl/genboree/genboreeUtil' # For validation functions
require 'brl/fileFormats/LFFValidator' # For validation functions

$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

module BRL; module Genboree

class RemoteUploadError < StandardError ; end

class GenboreeImporter
  include BRL::Genboree # mixin util functions
  attr_accessor :jobTicket, :databaseID, :databaseName, :lffErrorList, :msgList, :genboreeUserID

  SCP_EXE = 'scp -p '
  SSH_EXE = 'ssh -t -n -t ' # multiple -t intentional
  GZIP_EXE = '/usr/bin/gzip '
  UPLOAD_CMD_BASE = '/usr/local/brl/local/jdk/bin/java -classpath ' +
                    '/usr/local/brl/local/apache/htdocs/common/lib/servlet-api.jar:' +
                    '/usr/local/brl/local/apache/htdocs/common/lib/mysql-connector-java.jar:' +
                    '/usr/local/brl/local/apache/htdocs/common/lib/activation.jar:' +
                    '/usr/local/brl/local/apache/htdocs/common/lib/mail.jar:' +
                    '/usr/local/brl/local/apache/java-bin/WEB-INF/lib/GDASServlet.jar ' +
                    ' -Xmx1000M ' +
                    ' org.genboree.upload.AutoUploader '
  UPLOAD_CMD_STATIC_OPTS =  ' -v -s '            # turn off validation (done locally), suppress emails


  def initialize(genboreeServer, genboreeUploadUser, genboreeUploadDir)
    @server, @genboreeUploadUser, @genboreeUploadDir = genboreeServer.strip, genboreeUploadUser.strip, genboreeUploadDir.strip
    @databaseID, @genboreeUserID = nil
    @genboreeUploadDir += '/' unless(@genboreeUploadDir =~ /\/$/)
    @lffErrorList = []
    @msgList = []
  end

  def clearErrors()
    @lffErrorList.clear() unless(@lffErrorList.nil?)
    @msgList.clear() unless(@msgList.nil?)
    return
  end

  def processFile(inputFile, deleteExistingAnnos=false, fileType='lff', extraArgs='lff')
    unless(FileTest.exists?(inputFile))
      @lffErrorList << "ERROR: File #{inputFile} does not exist. Moving on."
      return false
    end

    # FIRST, validate the data file
    @msgList << "#{Time.now()} STATUS: about to validate #{inputFile}..."
    begin
      $stderr.puts "      . Progress: "
      if(fileType == 'lff')
        valid = self.validateLFFFile(inputFile)
        @msgList << "#{Time.now()} STATUS: done validating LFF file: #{inputFile}."
        $stderr.puts "        -- valid..." if(valid == OK)
      else
        valid = OK
        @msgList << "#{Time.now()} STATUS: not validating file, it is not LFF: #{inputFile}."
      end
      if(valid == OK)
        # SECOND, put the file on the remote machine
        @msgList << "#{Time.now()} STATUS: About to scp the file to remote machine..."
        exitCode = scpFile(inputFile)
        @msgList << "#{Time.now()} STATUS: scp attempt finished with exit code '#{exitCode}'"
        if(exitCode == 0)
          $stderr.puts "        -- scp'd..."
          # THIRD, remotely call upload program
          @msgList << "#{Time.now()} STATUS: About to ssh execute upload command..."
          exitCode = remoteUploadFile(inputFile, deleteExistingAnnos, fileType, extraArgs)
          @msgList << "#{Time.now()} STATUS: ssh execute finished with exit code '#{exitCode}'"
          unless(exitCode == 0)
            @lffErrorList << "ERROR: remote upload command FAILED"
          end
          $stderr.puts "        -- remote uploaded"
        else
          @lffErrorList << "ERROR: file transfer failed for some reason ('#{exitCode}' != 0)"
        end
      elsif(valid == FAILED or valid == OK_WITH_ERRORS)
        stringIO = StringIO.new()
        @validator.printErrors(stringIO)
        @lffErrorList <<  "ERROR: Your LFF file '#{File.basename(inputFile)}' cannot be uploaded because it has errors!\n" +
                          "       Errors are not allowed in auto-uploaded files.\n\n" +
                          "       Here are samples of your mistakes:\n" +
                          stringIO.string() +
                          "\n"
      else # WTF?
        @lffErrorList <<  "ERROR: An unknown error was encountered while validating your LFF file '#{File.basename(inputFile)}'." +
                          "       The auto-upload was cancelled. Please contact genboree_admin@genboree.org about this problem. " +
                          "\n\n"
      end
    rescue => err
      @lffErrorList << ("ERROR: problem encountered while auto-uploading data.\n" +
                        "       Error details:  =>  '#{err.message}'\n" +
                        (err.kind_of?(RemoteUploadError) ? '' : ("      Local Backtrace:\n\n      " + err.backtrace.join("\n      "))) +
                        "\n")
    end
    return true
  end

  def validateLFFFile(inputFile)
    fullValidation = false
    validationOpts = {  '--lffFile' => inputFile,
                        '--checkType' => 'full',
                     }
    @validator = BRL::FileFormats::LFFValidator.new(validationOpts)
    allOk = @validator.validateFile()
    if(allOk)
      return OK
    else
      if(@validator.haveSomeErrors?())
        return OK_WITH_ERRORS
       elsif(@validator.haveTooManyErrors?())
         return FAILED
       else # WTF???
         return FATAL
       end
    end
  end

  def scpFile(inputFile)
    scpCmd = SCP_EXE + " #{inputFile} #{@genboreeUploadUser}@#{@server}:#{@genboreeUploadDir} 2>&1 "
    @msgList << "SCP COMMAND: '#{scpCmd}'"
    scpOut = `#{scpCmd}`
    exitCode = $?
    @msgList << "SCP OUTPUT:\n      '#{scpOut.strip}'\n"
    return exitCode
  end

  def remoteUploadFile(inputFile, deleteExistingAnnos=false, fileType='lff', extraArgs='')
    remoteFile = @genboreeUploadDir + File.basename(inputFile)
    uploadOption = (deleteExistingAnnos ? (UPLOAD_CMD_STATIC_OPTS + ' -o ') : UPLOAD_CMD_STATIC_OPTS)
    remoteUploadCmd = UPLOAD_CMD_BASE + " #{uploadOption} -r #{@databaseID} -u #{@genboreeUserID} -f #{remoteFile} #{extraArgs} 2>&1 | tee  2> #{remoteFile}.err "
    #remoteUploadCmd = UPLOAD_CMD_BASE + " #{uploadOption} -r #{@databaseID} -f #{remoteFile} -t #{fileType} #{extraArgs} 2>&1 "
    remoteCdCmd = "source /usr/local/brl/home/genbadmin/.bashrc ; echo $PATH ; cd #{@genboreeUploadDir}"
    remoteCmd = "#{remoteCdCmd} ; #{remoteUploadCmd} "
    sshCmd = SSH_EXE + " #{@genboreeUploadUser}@#{@server} \"#{remoteCmd} ; echo EXIT CODE: $?\""
    $stderr.puts "        -- #{sshCmd}"
    @msgList << "SSH COMMAND: '#{sshCmd}'"
    @sshOut = `#{sshCmd}`
    exitCode = $?
    @msgList << "SSH LOCAL EXIT CODE: #{exitCode} (exited? #{exitCode.exited?} status: #{exitCode.exitstatus}) "
    @msgList << "SSH OUTPUT:\n      '#{@sshOut}'"
    exitCode = extractExitCode(@sshOut)
    $stderr.puts "         -- ssh'd with $?.exitstatus=#{$?.exitstatus} and remote exit code of #{exitCode}"
    @msgList << "SSH REMOTE EXIT CODE: #{exitCode}"
    if(exitCode.nil? or (exitCode != 0))
      raise(RemoteUploadError, "ERROR: Remote upload command issued an ERROR.\n" +
            "       Exit code was '#{exitCode.inspect}'.\n" +
            "       Details:\n#{@sshOut.inspect}\n")
    end
    return exitCode
  end

  def extractExitCode(cmdOut)
    if(cmdOut =~ /EXIT CODE:\s*(\S+)/)
      return $1.to_i
    else
      return nil
    end
  end

end #GenboreeImporter

end ; end # module BRL; module Genboree

class ScriptingImporter
  SMTP_SERVER = 'smtp.bcm.tmc.edu'
  MAIL_FROM = 'andrewj@bcm.edu'
  FILE_NAME_IDX, DELETE_DB_IDX = 0,1

  # Required properties
  GLOBAL_PROP_KEYS =   %w{
                          topLevelDir
                          validUsers
                          globalLogDir
                          globalLogFile
                          wipeDBDir
                          addToDBDir
                          doneDir
                          workingDir
                          logDir
                          userPropFile
                          uploadFileExtension
                          logEverything
                          genboreeServer
                          genboreeUploadUser
                          genboreeUploadDir
                        };
  LOCAL_PROP_KEYS = %w{
                        databaseName
                        databaseID
                        emailAddresses
                        userUids
                        genboreeUserID
                      } ;

  def initialize()
    @progArgs = self.processArguments()
    self.processGlobalPropTable()
    # Try for a lock--if can't get one immediately, then another autoUpload is running and will take care of everything
    unless(getLock())
      exit(0) # exit immediately, another autoUpload is running on this InBox area
    end
    # open the log file for append
    @logFile = File.open(@globalLogFile, 'a+')
    @logFile.sync = true
    # Make a Genboree importer
    @genboreeImporter = BRL::Genboree::GenboreeImporter.new(@genboreeServer, @genboreeUploadUser, @genboreeUploadDir)
    @hadErrors = false
  end

  def getLock()
    flockResult = -1
    begin
      flockResult = @lockFile.flock( File::LOCK_EX | File::LOCK_NB)
    rescue Errno::EAGAIN => err
      # This is ok, the resourse is in use, so flockResult stays -1
    end
    $stderr.puts "  => Lock file in use." unless(flockResult > -1)
    return (flockResult > -1)
  end

  def cleanup()
    @logFile.close()
  end

  # Estimate size of upload file...use similar approach as BigDBOpsLockFile#estimateNumLFFRecsInFile()
  # - this method intentionally estimates around 10 small but non-trivial AVPs per annotation
  # - generally this method OVER estimates the number of records when there are decent/lots AVPs
  #   and UNDER estimates the number of records when there are no AVPs. This is good.
  def estimateNumLFFRecsInFile(filePath)
    retVal = (File.exist?(filePath) ? File.size(filePath) : 0)
    return (retVal < 150 ? 1 : (retVal / 150))
  end

  # Determine if current time falls within configured period
  def nowWithinTimePeriod?(timePeriodStr)
    # Parse the time period string
    timePeriodStr.strip =~ /^(\d+)\s*:\s*(\d+)\s*,\s*(\d+)$/
    hour, minute, secLength = $1.to_i, $2.to_i, ($3.to_i * 60)
    # Get a time array to work with
    currTime = Time.now
    currTimeArray = currTime.to_a
    # Setup the time period start using the array
    currTimeArray[2] = hour
    currTimeArray[1] = minute
    timePeriodStart = Time.local(*currTimeArray)
    # Get the time period end
    timePeriodEnd = timePeriodStart + secLength
    # Get time period as a range
    timePeriod = timePeriodStart .. timePeriodEnd
    # Is current time included in the range?
    return timePeriod.include?(currTime)
  end

  def uploadNewData()
    # For each user in the list
    @validUsers.each { |user|
      begin # Don't let one failure ruin other project uploads
        @userDir = "#{@topLevelDir}/#{user}" # Find their directory
        next unless(File::exist?(@userDir))
        @userWipeDBDir = "#{@userDir}/#{@wipeDBDir}" # Make their wipeDBDir
        Dir.safeMkdir(@userWipeDBDir)
        @userAddToDBDir = "#{@userDir}/#{@addToDBDir}" # Make their addToDBDir
        Dir.safeMkdir(@userAddToDBDir)
        @userWorkDir = "#{@userDir}/#{@workingDir}" # Make their workingDir
        Dir.safeMkdir(@userWorkDir)
        @userDoneDir = "#{@userDir}/#{@doneDir}" # Make their doneDir
        Dir.safeMkdir(@userDoneDir)
        @userLogDir = "#{@userDir}/#{@logDir}" # Make their logDir
        Dir.safeMkdir(@userLogDir)
        # Skip them if they don't have a properties file or if not owned by owner of this process (andrewj, presumably)
        localPropFile = "#{@userDir}/#{@userPropFile}"
        next unless(FileTest.exist?(localPropFile))
        lpfStat = File::stat(localPropFile)
        unless(lpfStat.uid == Process.uid)
          puts "\nWARNING: #{localPropFile} is not owned by uid #{Process.uid}. Not processing this."
          next
        end
        unless(lpfStat.mode == 33200 or lpfStat.mode == 33184)
          puts "\nWARNING: #{localPropFile} is not rw-r----- . Not processing this."
          next
        end
        # Load their properties file
        self.processLocalPropFile(localPropFile)
        # Set the database name for importing for this user
        @genboreeImporter.databaseName = @databaseName
        @genboreeImporter.databaseID = @databaseID
        @genboreeImporter.genboreeUserID = @genboreeUserID
        @logWriter = nil
        # Look for new files
        newFiles = self.getNewFileList()
        $stderr.puts "    - Processing '#{user}'" unless(newFiles.empty?)
        # For each new file
        newFiles.each { |newFileRecord|
          $stderr.puts "      . Examining file '#{File.basename(newFileRecord[FILE_NAME_IDX])}'"
          # Get record number estimate for file
          estNumRecs = estimateNumLFFRecsInFile(newFileRecord[FILE_NAME_IDX])
          $stderr.puts "      . Estimated num records in file: #{estNumRecs}"
          # Unless the file is quite small, we need to upload only within the configured time period,
          # otherwise skip.
          if(estNumRecs >= @smallNumRecs)
            $stderr.puts "      . Too many records to run during day (max is #{@smallNumRecs})...are we in the configured time period?"
            if(nowWithinTimePeriod?(@timePeriodStr))
              $stderr.puts "        => YES (process file now)"
            else
              $stderr.puts "        => NO (skip this file)"
              next
            end
          else
            $stderr.puts "      . Small number of records, can run now regardless of time."
          end
          @hadErrors = false
          @userLogFileName = nil
          @logWriter = nil
          @genboreeImporter.clearErrors()
          fileName, deleteCurrentContent = newFileRecord[FILE_NAME_IDX], newFileRecord[DELETE_DB_IDX]
          # create a ticket number
          jobTicket = self.makeJobTicket()
          fileToProcess = "#{jobTicket}.#{File::basename(fileName)}"
          @userLogFileName = "#{@userLogDir}/#{fileToProcess}.log.gz"
          @logWriter = BRL::Util::TextWriter.new(@userLogFileName, 'w+', true)
          @logWriter.puts(('-'*60) + "\n#{Time.now()} UPLOAD SCRIPT: #{__FILE__}")
          @logWriter.write("#{Time.now()} JOB TICKET: #{jobTicket}\n    USER: #{user}\n    PROCESSING FILE: '#{fileName}'\n\n")
          # Move the file to the workingDir
          newFileName = "#{@userWorkDir}/#{fileToProcess}"
          `mv #{fileName} #{newFileName}`
          if(@logEverything) then @logWriter.write("#{Time.now()} DONE: moved file to working directory\n") ; end
          # Upload it
          @genboreeImporter.processFile(newFileName, deleteCurrentContent, @fileType, @extraUploadParams)
          # Record messages and status info
          self.logMessages()
          if(@logEverything) then @logWriter.write("#{Time.now()} DONE: tried to upload file data and recorded status. Were there errors?\n\n") ; end
          # Dump errors to log file
          self.logUploadErrors()
          # Move the file to the doneDir
          doneFileName = "#{@userDoneDir}/#{fileToProcess}"
          `mv #{newFileName}  #{doneFileName}`
          # Zip the file
          `gzip #{doneFileName}` unless(doneFileName =~ /\.gz$/ or doneFileName =~ /\.bz$/ or doneFileName =~ /\.bz2$/)
          if(@logEverything) then @logWriter.write("#{Time.now()} DONE: moved file to finished directory and gzipped it\n") ; end
          # Send a Finish email if it looks like error
          if(@hadErrors)
            self.sendFinishEmail(user, fileName, jobTicket)
            if(@logEverything) then @logWriter.write("#{Time.now()} DONE: sent finished-job email\nALL DONE\n\n") ; end
          end
          @logWriter.close() unless(@logWriter.nil?)
        }
      rescue => err
        $stderr.puts "      . ERROR! #{err.message}\n      " + err.backtrace.join("\n")
      ensure
        begin
          self.clearState()
        end
      end
    }
  end

  def processGlobalPropTable()
    @globalPropTable = BRL::Util::PropTable.new(File.open(@progArgs['--propFile']))
    # Verify the proptable contains what we need
    @globalPropTable.verify(GLOBAL_PROP_KEYS)
    # Get the key properties in proper form
    @topLevelDir = @globalPropTable['topLevelDir']
    @validUsers = @globalPropTable['validUsers']
    @globalLogDir = "#{@topLevelDir}/#{@globalPropTable['globalLogDir']}"
    @globalLogFile = "#{@globalLogDir}/#{@globalPropTable['globalLogFile']}"
    @wipeDBDir = @globalPropTable['wipeDBDir']
    @addToDBDir = @globalPropTable['addToDBDir']
    @doneDir = @globalPropTable['doneDir']
    @workingDir = @globalPropTable['workingDir']
    @logDir = @globalPropTable['logDir']
    @userPropFile = @globalPropTable['userPropFile']
    @uploadFileExt = @globalPropTable['uploadFileExtension']
    @logEverything = (@globalPropTable['logEverything'].downcase == 'true') ? true : false
    @genboreeServer = @globalPropTable['genboreeServer']
    @genboreeUploadUser = @globalPropTable['genboreeUploadUser']
    @genboreeUploadDir = @globalPropTable['genboreeUploadDir']
    @lockFileName = @topLevelDir + (@topLevelDir=~/\/$/ ? '' : '/') + 'lock.file'
    @lockFile = File.open(@lockFileName, "w+")
    @timePeriodStr = @globalPropTable['uploadTimePeriod']
    $stderr.puts "@timePeriodStr => #{@timePeriodStr.inspect}"
		@smallNumRecs = @globalPropTable['smallNumRecs'].to_i
  end

  def processLocalPropFile(localPropFile)
    @localPropTable = BRL::Util::PropTable.new(File.open(localPropFile))
    # Verify the proptable contains what we need
    @localPropTable.verify(LOCAL_PROP_KEYS)
    @databaseName = @localPropTable['databaseName']
    @databaseID = @localPropTable['databaseID']
    @emailToList = @localPropTable['emailAddresses']
    @userUids = @localPropTable['userUids']
    @genboreeUserID = @localPropTable['genboreeUserID']
    unless(@userUids.kind_of?(Array))
      @userUids = [ @userUids.to_i ]
    else
      @userUids.map! {|uid| uid.to_i }
    end
    # genboreeEmailUserIDs are OPTIONAL! Not needed for anything right nwo.
    @genboreeEmailUserIDs = @localPropTable.key?('genboreeEmailUserIDs') ? @localPropTable['genboreeEmailUserIDs'] : nil
    unless(@genboreeEmailUserIDs.kind_of?(Array) or @genboreeEmailUserIDs.nil?)
      @genboreeEmailUserIDs = [ @genboreeEmailUserIDs.to_i ]
    else
      unless(@genboreeEmailUserIDs.nil?)
        @genboreeEmailUserIDs.map! {|uid| uid.to_i }
      end
    end
    @fileType = @localPropTable.key?('fileType') ? @localPropTable['fileType'] : 'lff'
    @extraUploadParams = @localPropTable.key?('extraUploadParams') ? @localPropTable['extraUploadParams'] : ""
  end

  def logUploadErrors()
    @logWriter.write("ERRORS Encountered in LFF file during upload:\n\n")
    unless(@genboreeImporter.lffErrorList.empty?)
      @genboreeImporter.lffErrorList.each_with_index { |errorMsg, ii|
        @logWriter.write("  #{ii}:  #{errorMsg}\n")
      }
      @hadErrors = true
    else # no errors
      @logWriter.write("  NONE\n")
    end
    return
  end

  def logMessages()
    @logWriter.write("\n")
    @genboreeImporter.msgList.each { |msg|
      @logWriter.write("   IMPORTER => #{msg}\n")
    }
    @logWriter.write("\n")
    return
  end

  def clearState()
    @lffErrorList = []
    @localPropTable = nil
    @databaseName = nil
    @emailToList = nil
  end

  def makeJobTicket()
    pid = Process.pid
    time = Time::now.to_i
    return "#{time}-#{pid}"
  end

  def getNewFileList()
    fileRecords = []
    # Do the wipeDBFirst files
    fileRecords += getFileRecords(@userWipeDBDir, true)
    # Do the addToDB files
    fileRecords += getFileRecords(@userAddToDBDir, false)
    return fileRecords
  end

  def getFileRecords(patternPrefix, tagValue)
    newFileRecords = []
    filePattern = "#{patternPrefix}/*"
    newFiles = Dir::glob(filePattern)
    # Keep only the one belonging to this user. ~safety measure
    newFiles.delete_if { |fileName|
      fileStat = File::stat(fileName)
      !(@userUids.include?(fileStat.uid))
    }
    newFiles.each { |newFile|
      newFileRecords << [ newFile, tagValue ]
    }
    return newFileRecords
  end

  # -------------------------------------------------------------
  # Email methods
  # -------------------------------------------------------------
  def sendStartEmail(user, fileName, jobTicket)
    body = "Date: #{Time.now()}\nFrom: Andrew R. Jackson <andrewj@bcm.tmc.edu>\nTo: <undisclosed>\nSubject: GENBOREE NOTICE: Start of upload job (#{jobTicket})\n\n"
    body << "Started this auto-upload:\n    User: #{user}\n    New LFF File: #{File::basename(fileName)}\n    Job Ticket: #{jobTicket}\n    Date-stamp: #{Time::now().to_s}\n\n"
    self.sendEmail(body)
  end

  def sendFinishEmail(user, fileName, jobTicket)
    body = "Date: #{Time.now()}\nFrom: Andrew R. Jackson <andrewj@bcm.tmc.edu>\nTo: <undisclosed>\nSubject: GENBOREE NOTICE: Auto-upload failed (#{jobTicket})\n\n"
    body << "This auto-upload had problems:\n    User: #{user}\n    New LFF File: #{File::basename(fileName)}\n    Job Ticket: #{jobTicket}\n    Date-stamp: #{Time::now().to_s}\n\n"
    body << "The following ERRORs occured when processing your file:\n\n"
    unless(@genboreeImporter.lffErrorList.empty?)
      @genboreeImporter.lffErrorList.each_with_index { |errorMsg, ii|
        body << "  #{ii}:  #{errorMsg}\n\n"
      }
      body << "\n"
    else # no errors
      body << "  NONE (congratulations)\n\n"
    end
    self.sendEmail(body)
  end

  def sendEmail(body)
    smtp = Net::SMTP.new(SMTP_SERVER, 25)
    smtp.start()
    smtp.sendmail(body, MAIL_FROM, @emailToList)
    smtp.finish()
  end

  def processArguments
    progOpts =
      GetoptLong.new(
        ['--propFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
        ['--help', '-h', GetoptLong::NO_ARGUMENT]
      )

    @progArgs = progOpts.to_hash
    ScriptingImporter.usage() if(@progArgs.empty? or @progArgs.key?('--help'))
    return @progArgs
  end

  def ScriptingImporter.usage()
    puts "\n\nUSAGE: lffScriptingImporter.rb -p global.properties\n\n"
    exit(1)
  end
end # module LFFScriptingImporter

# ##############################################################################
# MAIN
# ##############################################################################
# Initialize the importer
importer = ScriptingImporter.new()

# Process all new files for each user
importer.uploadNewData()

# Clean up
importer.cleanup()

exit(0)
