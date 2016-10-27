#!/usr/bin/env ruby

# Loading libraries
require 'pp'
require 'md5'
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/genboree/helpers/sorter'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/genboree/graphics/zoomLevelUpdater'
require 'brl/fileFormats/LFFValidator'

class ImportZoomLevelsForLFF

  BUFFERSIZE = 32000000
  SIZEFORDEFERRING = 200000000

  attr_accessor :file, :groupName, :databaseName, :userName, :dbu, :userId, :refseqId
  attr_accessor :groupId, :ftypeId, :frefHash

  def initialize(optsHash)
    #Making dbUtil Object for database 'genboree'
    @genbConf = BRL::Genboree::GenboreeConfig.load
    @file = optsHash['--inputFile']
    displayErrorMsgAndExit("File: #{@file} not found. Qutting.") if(!File.exists?(optsHash['--inputFile']))
    @getPermission = optsHash['--getPermission'] ? true : false
    @noValidation = optsHash['--noValidation'] ? true : false
    @intermediateFilesBase = "#{File.dirname(@file)}/#{File.basename(@file, File.extname(@file))}"
    dbrcKey = optsHash['--dbrcKey'] ? optsHash['--dbrcKey'] : @genbConf.dbrcKey
    begin
      @dbu = BRL::Genboree::DBUtil.new(dbrcKey, nil, nil)
    rescue => err
      displayErrorMsgAndExit(err)
    end
    # Check whether loginName or loginId provided is valid
    # get one from the other
    userName = optsHash['--userName'].strip
    @noEmail = optsHash['--noEmail'] ? true : false
    if(userName =~ /^\d+$/)
      @userId = userName.to_i
      #Check if user with the provided userId exists
      userCheck = @dbu.getUserByUserId(@userId)
      displayErrorMsgAndExit("User with userId: #{@userId} does not exist") if(userCheck.empty?)
    else
      # userName could be the superUser which we need to allow
      if(userName == @genbConf.gbSuperuserId)
        @userId = userName
      else
        userVal = @dbu.getUserByName(userName)
        displayErrorMsgAndExit("#{userName} does not exist") if(userVal.empty?)
        @userId = userVal.first['userId']
      end
    end
    # Get the user name to include in the email if something goes wrong
    @userName = ''
    @userEmail = nil
    userRec = @dbu.getUserByUserId(@userId)
    if(!userRec.nil? and !userRec.empty?)
      @userName = "#{userRec.first['firstName']} #{userRec.first['lastName']}"
      @userEmail = userRec.first['email']
    end
    # Get databaseName if refseqId provided and check if database belongs to group provided
    databaseName = optsHash['--databaseName']
    databaseName.strip!
    if(databaseName =~ /^\d+$/)
      @refseqId = databaseName.to_i
      # Get database name
      refseqRecord = @dbu.selectDBNameByRefSeqID(@refseqId)
      displayErrorMsgAndExit("Database with refseqId: #{@refseqId} does not exist") if(refseqRecord.nil? or refseqRecord.empty?)
      @databaseName = refseqRecord.first['databaseName']
    else # databaseName command line arg is an actual database name
      # Get refseqid for it
      refseqRecs = @dbu.selectRefseqByDatabaseName(databaseName)
      displayErrorMsgAndExit("User database #{databaseName} does not exist") if(refseqRecs.nil? or refseqRecs.empty?)
      @databaseName = databaseName
      @refseqId = refseqRecs.first['refSeqId']
    end
    refseqRecord = @dbu.selectRefseqByDatabaseName(@databaseName)
    displayErrorMsgAndExit("Database: #{@databaseName} does not have refseqName") if(refseqRecord.nil? or refseqRecord.empty?)
    @refseqName = refseqRecord.first['refseqName']
    # Get group info
    @groupName = optsHash['--groupName']
    @groupName.strip!
    if(@groupName =~ /^\d+$/)
      @groupId = @groupName.to_i
      # Get groupName
      groupRecs = @dbu.selectGroupById(@groupId)
      displayErrorMsgAndExit("Group with groupId: #{@groupId} does not exist") if(groupRecs.nil? or groupRecs.empty?)
      @groupName = groupRecs.first['groupName']
    else # groupName command line arg is an actual group name
      # Get groupId
      groupRecs = @dbu.selectGroupByName(@groupName)
      displayErrorMsgAndExit("Group with group name: #{@groupName} does not exist") if(groupRecs.nil? or groupRecs.empty?)
      @groupId = groupRecs.first['groupId']
    end

    # Check that database is within group
    groupAndRefseqRecs = @dbu.selectGroupRefSeq(@groupId, @refseqId)
    displayErrorMsgAndExit("Group #{@groupName} does not have a user database #{@databaseName}") if(groupAndRefseqRecs.nil? or groupAndRefseqRecs.empty?)
    # set dbUtil object to user database
    @dbu.setNewDataDb(@databaseName)
    @dbu.connectToDataDb()
    @frefHash = {}
    allFrefRecords = @dbu.selectAllRefNames()
    allFrefRecords.each { |record|
      @frefHash[record['refname']] = [record['rlength'].to_i, record['rid'].to_i] if(!@frefHash.has_key?(record['refName']))
    }
    displayErrorMsgAndExit("No entrypoints found in the target database") if(@frefHash.keys.size == 0)
    # defer the application if the file size is too big
    # otherwise use the lock file
    genbConf = ENV['GENB_CONFIG']
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    dbLock = BRL::Genboree::LockFiles::GenericDbLockFile.new(:useImportTool) if(@getPermission)#use the same lock file as the wig importer for now
    expanderObj = BRL::Genboree::Helpers::Expander.new(@file)
    fileSize = 0
    fileType = expanderObj.getFileType()
    # Get size (uncompressed)
    if(fileType == "text")
      fileSize = File.size(@file)
    elsif(fileType == "gzip")
      fileSize = BRL::Util::Gzip.getUncompressedSize(@file).to_i
    else
      fileSize = File.size(@file) * 20
    end
    displayErrorMsgAndExit("Size of file: #{@file.inspect} is 0. Cannot proceed. ") if(fileSize == 0)
    
    # check if the job is to be deferred
    begin
      if(@getPermission)
        sizeForDeferring = genbConfig.deferFileSizeForLFF.to_i
        if(fileSize >= sizeForDeferring)
          hasPermission = false
          loop {
            now = Time.now
            startTime, endTime = BRL::Genboree::GenboreeConfig.getTimePeriod(genbConfig.bigDbOpTimePeriod.join(',')) # use the same deferring times as those of the bigwig jobs
            if(now >= startTime and now <= endTime)
              hasPermission = dbLock.getPermission(false) # Don't block
              if(hasPermission)
                break
              else
                sleepTime = BRL::Genboree::LockFiles::GenericDbLockFile.sleepTimeScaledBySize(fileSize, minSleepTime=30, maxSleepTime=1800, adjFactor=5, addRandomExtra=true)
                $stderr.puts "#{Time.now.to_s}: Sleeping #{sleepTime.inspect} seconds because don't have :useImportTool permission"
                sleep(sleepTime) # wait before trying again
                # Check again if file size for deferring has been changed
                genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
                sizeForDeferring = genbConfig.deferFileSizeForLFF.to_i
                break if(fileSize < sizeForDeferring)
              end
            else
              sleepTime = BRL::Genboree::LockFiles::GenericDbLockFile.sleepTimeScaledBySize(fileSize, minSleepTime=30, maxSleepTime=1800, adjFactor=5, addRandomExtra=true)
              $stderr.puts "#{Time.now.to_s}: Sleeping #{sleepTime.inspect} seconds because not in valid time #{startTime.to_s} - #{endTime.to_s}"
              sleep(sleepTime) # b/c we need to wait until it's 6:20pm...
              # Check again if file size for deferring has been changed
              genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
              sizeForDeferring = genbConfig.deferFileSizeForLFF.to_i
              break if(fileSize < sizeForDeferring)
            end
          }
          if(!hasPermission) # This can only happen if the deferFileSizeForLFF changed while the program was sleeping and the loop was exited
            sleepTime = BRL::Genboree::LockFiles::GenericDbLockFile.sleepTimeScaledBySize(fileSize, minSleepTime=30, maxSleepTime=1800, adjFactor=5, addRandomExtra=true)
            dbLock.getPermission(blocking=true, sleepTime)
          end
        else
          sleepTime = BRL::Genboree::LockFiles::GenericDbLockFile.sleepTimeScaledBySize(fileSize, minSleepTime=30, maxSleepTime=1800, adjFactor=5, addRandomExtra=true)
          dbLock.getPermission(blocking=true, sleepTime)
        end
      end
      compressed = expanderObj.isCompressed?(@file)
      expanderObj.extract(desiredType = 'text')
      fullPathToUncompFile = expanderObj.uncompressedFileName
      $stderr.puts "DEBUG: fullPathToUncompFile: #{fullPathToUncompFile.inspect}"
      raise "Unable to decompress file: #{file}. Unrecognized format?" if(!expanderObj.stderrStr.empty?)
      # Validate the file first
      allOk = true
      unless(@noValidation)
        $stderr.puts "validating...."
        # Write out the 3 column lff file for valid entrypoints
        chrDefFile = "#{@intermediateFilesBase}.chrDefinitions.lff"
        $stderr.puts "    - getting chromosome definitions file to #{chrDefFile.inspect} first."
        ff = File.open(chrDefFile, "w")
        @frefHash.each_key { |chr|
          ff.puts("#{chr}\tchromosome\t#{@frefHash[chr][0]}")
        }
        ff.close
        $stderr.puts "    - done getting chromosome definitions; start validation library call"
        validator = BRL::FileFormats::LFFValidator.new({'--lffFile' => fullPathToUncompFile, '--epFile' => chrDefFile})
        allOk = validator.validateFile() # returns true if no errors found
      end
      unless(allOk)
        errors = ''
        if(validator.haveSomeErrors?() or validator.haveTooManyErrors?())
          ios = StringIO.new(errors)
          validator.printErrors(ios)
        else # WTF???
          errors = "\n\n\n\nFATAL ERROR: Unknown Error in LFFValidator. Cannot upload LFF."
        end
        raise errors
      end
      $stderr.puts "validation done. No errors.." unless(@noValidation)

      # we will have to break the file into many files (each having one track)
      # and then sort each file by chromosome and coordinate, i.e, all the records of a chromosome should be together
      # and the records should also be sorted by the start coordinates
      # computes zoom levels after sorting, one track at a time
      sortAndAddZoomLevels(fullPathToUncompFile)
      # remove the uncompressed version of the file if we expanded the original file
      # compress the original file it was text
      if(!optsHash['--noCompDel'])
        if(compressed)
          system("rm #{fullPathToUncompFile}")
        else
          system("gzip #{fullPathToUncompFile}")
        end
      end
      dbLock.releasePermission() if(@getPermission)
      $stderr.puts "all done"
    rescue Exception => err
      dbLock.releasePermission() if(@getPermission)
      $stderr.puts "ERROR: #{err}\nBacktrace: #{err.backtrace.join("\n")}"
      displayErrorMsgAndExit(err)
    end
  end

  # Displays error message and quits
  # [+msg+]  error message
  # [+returns+] nil
  def displayErrorMsgAndExit(msg)

    # Send email to gbAdminEmail with the error message to alert that the process has failed
    subjectTxt = "Your Genboree upload HAD TOO MANY ERRORS"
    bodyTxt = "Hello #{@userName},\n\n"
    bodyTxt += "There were too many errors uploading your data."
    bodyTxt += "Please fix the following errors before reattempting your upload.\n\n"
    bodyTxt += "Job details:\n"
    bodyTxt += "Group: #{@groupName.inspect}\n"
    bodyTxt += "Database ID: #{@refseqId.inspect}\n"
    bodyTxt += "Database Name: #{@refseqName.inspect}\n"
    bodyTxt += "File Name: #{File.basename(@file)}\n" if(!@file.nil?)
    bodyTxt += "\n\n\n"
    bodyTxt += msg
    $stderr.puts "will send email to: #{@userEmail.inspect}"
    email = BRL::Util::Emailer.new()
    email.setHeaders("do_not_reply@genboree.org", @userEmail, subjectTxt)
    email.setMailFrom("do_not_reply@genboree.org")
    email.addRecipient(@genbConf.gbAdminEmail)
    email.addRecipient(@userEmail)
    email.setBody(bodyTxt)
    email.send() unless(@noEmail)
    $stdout.puts msg
    # The wrapper 'createZoomLevelsForLFF.rb' will see this and will not run the java uploader
    exit(10)
  end

  # breaks lff file into several files (one for each track)
  # sorts each file by chromosome and start coordinates and then computes zoom levels for each track
  # [+file+] lff file
  # [+returns+] nil
  def sortAndAddZoomLevels(file)
    scratchDir = "#{File.dirname(file)}/temp_#{CGI.escape(Time.now.to_f)}"
    system("mkdir -p #{scratchDir}")
    system("sort -t $'\t' -d -k3,4 -k5,5 -k6,6n #{file} > #{scratchDir}/sorted_#{File.basename(file)}") # sort the file by track name, chr and start coordinate
    fileReader = BRL::Util::TextReader.new("#{scratchDir}/sorted_#{File.basename(file)}")
    orphan = nil
    track = nil
    chr = nil
    previousChr = nil
    previousTrack = nil
    start = nil
    span = nil
    zoomObj = ZoomLevelUpdater.new(@dbu)
    while(!fileReader.eof?)
      fileBuff = fileReader.read(BUFFERSIZE)
      fileBuffIO = StringIO.new(fileBuff)
      fileBuffIO.each_line { |line|
        line = orphan + line if(!orphan.nil?)
        orphan = nil
        if(line =~ /\n$/)
          line.strip!
          next if(line.empty? or line.nil? or line =~ /^\s*$/ or line =~ /^#/)
          data = line.split(/\t/)
          trackName = "#{data[2]}:#{data[3]}"
          typeSubType = trackName.split(":")
          chr = data[4]
          start = data[5].to_i
          stop = data[6].to_i
          span = (stop - start) + 1
          score = data[9].to_f
          # check if track exists
          # if it does not create an entry in ftype for the track
          if(previousTrack.nil?)
            val = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(@refseqId, @userId, true, nil)
            $stderr.puts "checking if track: #{trackName} exists in db: #{@refseqName}"
            # Track does not exist or is not accessible to the user
            if(val["#{trackName}"].nil?)
              retVal = @dbu.selectAllByFmethodAndFsource(typeSubType[0], typeSubType[1])
              if(!retVal.empty?)
                 $stderr.puts("This track is not accessible to the user: #{@userId}. Skipping...")
                 next
              # make new track
              else
                $stderr.puts "track: #{trackName} does not exist. Creating..."
                @dbu.insertFtype(typeSubType[0], typeSubType[1], true)
                ftype = @dbu.selectFtypeByTrackName(trackName)
                @ftypeId = ftype.first['ftypeid']
              end
            # track exists
            else
              $stderr.puts "track: #{trackName} exists..."
              # Now make sure that the track is in the ftype list of the user db
              # if not, we will have to make a new ftypeid in the user db
              if(val[trackName]['dbNames'][0]['dbType'] != :'userDb')
                $stderr.puts "Warning: track: #{trackName} does not exist in user db " +
                              "(track with same name exists in template db), Creating track in user db"
                @dbu.insertFtype(typeSubType[0], typeSubType[1], true)
                ftype = @dbu.selectFtypeByTrackName(trackName)
                @ftypeId = ftype.first['ftypeid']
              else
                @ftypeId = val[trackName]['dbNames'][0]['ftypeid'].to_i
              end
            end
            $stderr.puts "adding zoom levels for track: #{trackName}"
            $stderr.puts "computing zoom levels for #{chr}"
            zoomObj.getZoomLevelRecsByRid(@frefHash[chr][1], @frefHash[chr][0], @ftypeId)
            zoomObj.addNewScoreForSpan(score, start, span)
            previousChr = chr
          elsif(trackName != previousTrack)
            zoomObj.writeBackZoomLevelRecords()
            zoomObj.clearZoomData
            $stderr.puts "zoom level records inserted/replaced for track: #{trackName} for #{previousChr}"
            val = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(@refseqId, @userId, true, nil)
            $stderr.puts "checking if track: #{trackName} exists in db: #{@refseqName}"
            # Track does not exist or is not accessible to the user
            if(val["#{trackName}"].nil?)
              retVal = @dbu.selectAllByFmethodAndFsource(typeSubType[0], typeSubType[1])
              if(!retVal.empty?)
                 $stderr.puts("This track is not accessible to the user: #{@userId}. Skipping...")
                 next
              # make new track
              else
                $stderr.puts "track: #{trackName} does not exist. Creating..."
                @dbu.insertFtype(typeSubType[0], typeSubType[1])
                ftype = @dbu.selectFtypeByTrackName(trackName)
                @ftypeId = ftype.first['ftypeid']
              end
            # track exists (make sure it is not a template/shared track)
            else
              $stderr.puts "track: #{trackName} exists..."
              # Now make sure that the track is in the ftype list of the user db
              # if not, we will have to make a new ftypeid in the user db
              if(val[trackName]['dbNames'][0]['dbType'] != :'userDb')
                $stderr.puts "Warning: track: #{trackName} does not exist in user db " +
                              "(track with same name exists in template db), Creating track in user db"
                @dbu.insertFtype(typeSubType[0], typeSubType[1])
                ftype = @dbu.selectFtypeByTrackName(trackName)
                @ftypeId = ftype.first['ftypeid']
              else
                @ftypeId = val[trackName]['dbNames'][0]['ftypeid'].to_i
              end
            end
            zoomObj = ZoomLevelUpdater.new(@dbu)
            zoomObj.getZoomLevelRecsByRid(@frefHash[chr][1], @frefHash[chr][0], @ftypeId)
            $stderr.puts "adding zoom levels for track: #{trackName}"
            $stderr.puts "computing zoom levels for #{chr}"
            zoomObj.addNewScoreForSpan(score, start, span)
            previousChr = chr
          elsif(trackName == previousTrack)
            if(previousChr != chr)
              zoomObj.writeBackZoomLevelRecords()
              zoomObj.clearZoomData
              $stderr.puts "zoom level records inserted/replaced for track: #{trackName} for #{previousChr}"
              zoomObj = ZoomLevelUpdater.new(@dbu)
              zoomObj.getZoomLevelRecsByRid(@frefHash[chr][1], @frefHash[chr][0], @ftypeId)
              $stderr.puts "computing zoom levels for #{chr}"
            end
            zoomObj.addNewScoreForSpan(score, start, span)
            previousChr = chr
          end
          previousTrack = trackName
        else
          orphan = line
        end
      }
    end
    zoomObj.writeBackZoomLevelRecords()
    zoomObj.clearZoomData
    $stderr.puts "zoom level records inserted/replaced for track: #{previousTrack} for #{previousChr}"
    system("rm -rf #{scratchDir}")
  end
end


class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Sameer Paithankar

  Description: This script is for creating/updating zoom level records for lff data. The script manages both inserting new zoom level records (for new tracks)
  and updating zoom level records (for existing tracks)

  Notes:
    -i  --inputFile => full path to the lff file
    -g  --groupName => name or id of the group whose database the data will be uploaded to (required)
    -u  --userName => genboree user name or user id of the person running the program (Note: private tracks may or may not be accessible depending on track access settings) (required)
    -d  --databaseName => full name of the database or refseqid to which the data will be uploaded (required)
    -C  --noCompDel => do not compress/delete (optional)
    -k  --dbrcKey => Optional
    -e  --noEmail
    -p  --getPermission
    -V  --noValidation
    -v  --version => Version of the program
    -h  --help => Display help

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
    methodName="performImportLFF"
    optsArray=[
      ['--inputFile','-i',GetoptLong::REQUIRED_ARGUMENT],
      ['--groupName','-g',GetoptLong::REQUIRED_ARGUMENT],
      ['--userName','-u',GetoptLong::REQUIRED_ARGUMENT],
      ['--databaseName','-d',GetoptLong::REQUIRED_ARGUMENT],
      ['--noCompDel','-C',GetoptLong::OPTIONAL_ARGUMENT],
      ['--dbrcKey','-k',GetoptLong::OPTIONAL_ARGUMENT],
      ['--noEmail','-e',GetoptLong::OPTIONAL_ARGUMENT],
      ['--getPermission','-p',GetoptLong::OPTIONAL_ARGUMENT],
      ['--noValidation','-V',GetoptLong::OPTIONAL_ARGUMENT],
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

  def self.performImportZoomLevelsForLFF(optsHash)
    ImportZoomLevelsForLFF.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performImportZoomLevelsForLFF(optsHash)
