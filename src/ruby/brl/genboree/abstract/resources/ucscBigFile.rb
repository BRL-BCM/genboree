#!/usr/bin/env ruby

require 'rubygems'
require 'cgi'
require 'fileutils'
require 'rack'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/rest/resource'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/abstractStreamer'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/abstract/resources/bedFile'
require 'brl/genboree/abstract/resources/unlockedGroupResource'
require 'brl/genboree/lockFiles/genericDbLockFile'

module BRL ; module Genboree ; module Abstract ; module Resources

  # Used to pass the big* file to the response body
  # @todo rename this, its not UCSC specific and actually it is just used
  # to stream file data
  class UCSCBigFileHandler < AbstractStreamer
    # Chosen for the current Thin buffer of 20MB
    CHUNK_SIZE = 4 * 1024 * 1024
    MAX_SEND_UCSC = 8 * 1024 * 1024

    def initialize(filePath, reqLength=nil, reqOffset=nil)
      super()
      unless(self.class.method_defined?(:child_each))
        alias :child_each :each
        alias :each :parent_each
      end
      @isRangeReq = (!reqLength.nil? or !reqOffset.nil?)
      @filePath = filePath
      @fileSize = File.size(@filePath)
      @reqLength = (reqLength.nil?) ? File.size(@filePath) : reqLength
      @reqOffset = reqOffset.to_i # This will be 0 if nil
    end

    # Serve the file in reasonable chunks
    def each()
      offset = @reqOffset
      length = min(@reqLength, CHUNK_SIZE)
      bytesSent = 0
      iiLogger = 1
      while bytesSent < @reqLength
        yield IO.read(@filePath, length, offset)
        bytesSent += length
        offset += CHUNK_SIZE
        length = min(@reqLength - bytesSent, CHUNK_SIZE)
        # Debugging info
        if(bytesSent > iiLogger * 4_000_000)
          # $stderr.puts "BIGWIG: ...#{@logId} Read #{bytesSent.commify} bytes..."
          iiLogger += 1
        end
        # Assuming UCSC never consumes more than 8M (?) per request, stop sending data earlier than their request indicates.
        break if(@isRangeReq and bytesSent >= MAX_SEND_UCSC)
      end
    end

    # because it's not in Math
    def min(a, b)
      a < b ? a : b
    end
  end

  class UCSCBigFile

    def initialize(dbu, groupId, refSeqId, trackName)
      groupRows = dbu.selectGroupById(groupId)
      @groupName = groupRows.first['groupName'] if(!groupRows.nil? and !groupRows.empty?)
      refSeqRows = dbu.selectRefseqById(refSeqId)
      dbu.setNewDataDb(refSeqRows.first['databaseName'])
      trkRecs = dbu.selectFtypeByTrackName(trackName)
      @ftypeid = trkRecs.first['ftypeid'] if(!trkRecs.nil? and !trkRecs.empty?)
      @dbName = refSeqRows.first['refseqName'] if(!refSeqRows.nil? and !refSeqRows.empty?)
      @trackName = trackName
      @groupId, @refSeqId = groupId, refSeqId
    end

    def fileExists?()
      fileNameFull = getFilePath()
      return File.exists?(fileNameFull)
    end

    def getTimestamp()
      time = nil
      fileNameFull = getFilePath()
      if(File.exists?(fileNameFull))
        time = File.mtime(fileNameFull).strftime("%Y/%m/%d %H:%M %Z")
      end
      return time
    end

    def hasPendingJob()
      path = getDirPath()
      filePath = "#{path}/#{getJobMarkerFileName()}"
      return File.exists?(filePath)
    end

    def getDirPath()
      genbConf = BRL::Genboree::GenboreeConfig.load()
      # Escape the names because they will be used for the file directory path
      # and in the command to create the bigwig file
      groupNameEsc = Rack::Utils.escape(@groupName)
      dbNameEsc = Rack::Utils.escape(@dbName)
      trackNameEsc = Rack::Utils.escape(@trackName)
      # Get path to file from the conf file
      path = "#{genbConf.gbAnnoDataFilesDir}grp/#{@groupId}/db/#{@refSeqId}/trk/#{@ftypeid}"
    end

    def getFilePath()
      path = getDirPath()
      filePath = "#{path}/#{getFileName()}"
      return filePath
    end

    def getFileName()
      # unimplemented. Implemented by sub-classes
    end

    def deleteDir()
      annoFilePath = getDirPath()
      if(File.exists?(annoFilePath))
        FileUtils.rm_rf(annoFilePath)
      end
    end
    
    # Make use of initialized file information to determine range even for "terminal n" byte range
    #   requests
    # @param [String] rangeStr value of http range header
    # @return [Hash] object storing
    #   :length [nil, Fixnum] a length value that can be used with Ruby IO
    #   :offset [nil, Fixnum] an offset value that can be used with Ruby IO
    #   :rangeHeader [String] a response header based on the rangeStr request header
    def self.parseRange(rangeStr, filepath)
      retVal = {}

      # initialize byte range to entire file
      start = 0
      fileSize = File.size(filepath)
      stop = fileSize - 1

      if(rangeStr.nil?)
        # not really a range request then..
        offset = length = nil
      else
        # parse the range string
        rangePattern = /(\d+)?-(\d+)?/
        matchData = rangePattern.match(rangeStr)
        if(matchData.nil?)
          # could not parse string as range request
          offset = length = nil
        elsif(matchData[1].nil? and matchData[2].nil?)
          # you gave me a dash? not a range request..
          offset = length = nil
        elsif(!matchData[1].nil? and matchData[2].nil?)
          start = matchData[1].to_i
          length = nil
          offset = start
        elsif(matchData[1].nil? and !matchData[2].nil?)
          nn = matchData[2].to_i
          if(nn < fileSize)
            # then byte range is ok
            offset = fileSize - nn
            length = nn
            start = offset
          else
            # then byte range is in excess of file size, give whole file
            offset = length = nil
          end
        else
          # neither is nil, a proper range
          start = matchData[1].to_i
          stop = matchData[2].to_i
          length = stop - start + 1
          offset = start
        end
      end
      retVal[:length] = length
      retVal[:offset] = offset
      retVal[:rangeHeader] = "bytes #{start}-#{stop} / #{fileSize}"
      return retVal
    end

    # @todo doesnt support entire set of options as specified by the syntax
    #   in http://tools.ietf.org/html/rfc7233#section-3.1
    # @todo left this function intact bc UCSC has been known to break RFC,
    #   merge with more compliant range request above, parseRange, if UCSC not
    #   misusing "terminal n" byte range requests
    def self.parseRangeRequest(rangeStr)
      if(rangeStr.nil?)
          offset = length = nil
      else
        if(rangeStr =~ /(\d+)-(\d+)?/)
          offset = $~[1].to_i
          length = $~[2].to_i - offset + 1 if(!$~[2].nil?)
        end
      end
      return [length, offset]
    end

    def self.makeDirPath(genbConf, groupName, dbName, trackName)
      # Escape the names because they will be used for the file directory path
      # and in the command to create the bigbed file
      groupNameEsc = Rack::Utils.escape(groupName)
      dbNameEsc = Rack::Utils.escape(dbName)
      trackNameEsc = Rack::Utils.escape(trackName)
      # Get path to file from the conf file
      path = "#{genbConf.gbAnnoDataFilesDir}grp/#{groupNameEsc}/db/#{dbNameEsc}/trk/#{trackNameEsc}"
    end


  end

  class BigWigFile < UCSCBigFile
    def getJobMarkerFileName()
      'bigWig.jobSubmitted'
    end

    def getFileName()
      genbConf = BRL::Genboree::GenboreeConfig.load()
      genbConf.gbTrackAnnoBigWigFile
    end
  end

  class BigBedFile < UCSCBigFile
    def getJobMarkerFileName()
      'bigBed.jobSubmitted'
    end

    def getFileName()
      genbConf = BRL::Genboree::GenboreeConfig.load()
      genbConf.gbTrackAnnoBigBedFile
    end
  end




  # Parent class that defines common functionality for the genbBigBedFile and genbBigWigFile command line utilities
  class UCSCBigFileConverter

    # DbUtil instance
    attr_accessor :dbu

    # Unique identifier representing the job, used for logging/archiving
    attr_accessor :taskId

    # File contains the annotations
    attr_accessor :txtFileName

    # Final product big* file generated by this processs
    attr_accessor :bigFileName

    # Buffer where all stdout should be captured
    attr_accessor :outBuffer

    # Buffer where all stderr should be captured
    attr_accessor :errBuffer

    # Name of the cammnd: bedToBigBed or wigToBigWig
    attr_accessor :converterName

    # Return status of the converter procesees
    attr_accessor :converterStatus

    # File contains the stdout of the converter process
    attr_accessor :converterOutFileName

    # File contains the stderr of the converter process
    attr_accessor :converterErrFileName

    # File required by converter which contains the sizes of each chromosome
    attr_accessor :chrSizesFileName

    # File contains the body text of the email that was sent
    attr_accessor :msgFileName

    # File that contains the stdout and stderr of the entire process
    attr_accessor :logFileName

    # File used at flag to indicate that a job has been submitted and isn't complete
    attr_accessor :jobSubmittedFlagFileName

    # bigBed or bigWig
    attr_accessor :fileType

    attr_accessor :gbKey
    attr_accessor :ftypeAttributesHash


    def initialize(optsHash)
      # Set stderr and stdout to be captured by buffers
      @outBuffer = StringIO.new
      @tmpStdOut = $stdout
      #$stdout = @outBuffer
      @errBuffer = StringIO.new
      @tmpStdErr = $stderr
      #$stderr = @errBuffer

      # Initialize instance variables defined by command line options
      @optsHash = optsHash
      @genbConf = optsHash['--genbConf'] || ENV['GENB_CONFIG']
      @dbrcKey = optsHash['--dbrcKey']
      @taskId = optsHash['--taskId']
      @hostname = optsHash['--hostname']
      @emailToAddress = @optsHash['--email']
      @noLock = @optsHash['noLock']

      @genbConfig = @dbu = nil
      @genbConfig = GenboreeConfig.load(@genbConf)
      @dbrcKey ||= @genbConfig.dbrcKey
      # At this point we don't know it yet so create dbu with no data db
      @dbu = BRL::Genboree::DBUtil.new(@dbrcKey, nil, @genbConfig.dbrcFile)
    end

    def clean()
      @genbConfig.clear() if(@genbConfig)
      @dbu.clear()        if(@dbu)
      @dbu.clearCaches()  if(@dbu)
    end

    # By default, when the command finishes, two files that were used to create
    # the big* file will remain, the text file and the chromosome sizes file.
    # Command line option available to handle these are
    # -z Archive the files, also archives stdout and stderr if they exist
    # -x Delete the files
    def cleanSourceFiles
     # The jobSubmitted flag file must also be deleted to indicate that the job is complete
     FileUtils.rm(@jobSubmittedFlagFileName) if(File.exists?(@jobSubmittedFlagFileName))
      if(@optsHash['--archiveSrc'])
        zipFileName = @optsHash['--archiveSrc']
        # zip text file, chr.sizes, stdout, stderr
        archiveCmd = "tar --remove-files -czf #{zipFileName}"
        filesToTar = [@chrSizesFileName, @txtFileName, @converterErrFileName, @converterOutFileName, @msgFileName, @logFileName]
        filesToTar.each { |fileToTar|
          archiveCmd += " #{fileToTar}" if(File.exists?(fileToTar))
        }
        system(archiveCmd)
      elsif(@optsHash['--deleteSrc'])
        # delete text file and chr.sizes
        FileUtils.rm(@txtFileName)
        FileUtils.rm(@chrSizesFileName)
      end
    end

    def initTrackObj()
      # Create the big* from group, database and track names
      if(!@optsHash['--genboreeGroup'].nil? and !@optsHash['--genboreeDatabase'].nil? and !@optsHash['--track'].nil?) # groupName, databaseName and trackName
        @groupName = @optsHash['--genboreeGroup']
        @refSeqName = @optsHash['--genboreeDatabase']
        @trackName = @optsHash['--track']
        @gbKey = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.getHighestKeyForTrackByName(@dbu, @groupName, @refSeqName, @trackName)    # Set this for email template
        @outBuffer.puts Time.now.to_s + "  Getting Annotations for group: #{@groupName} database: #{@refSeqName} and track #{@trackName} (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
        groupRows = @dbu.selectGroupByName(@groupName)
        if(!groupRows.nil? and !groupRows.empty?)
          groupId = groupRows.first['groupId']
          refSeqRows = @dbu.selectRefseqByNameAndGroupId(@refSeqName, groupId)
          if(!refSeqRows.nil? and !refSeqRows.empty?)
            @refSeqId = refSeqRows.first['refSeqId']
            @genomeTemplate = refSeqRows.first['refseq_version']  # Set this for email template
            method, source = Rack::Utils.unescape(@trackName).split(':')
            @trackObj = BRL::Genboree::Abstract::Resources::Track.new(@dbu, @refSeqId, method, source)
            if(!@trackObj.exists?)
              @errBuffer << "ERROR: Track could not be found"
            end
          else
            @errBuffer << "ERROR: Database could not be found"
          end
        else
          @errBuffer << "ERROR: Group could not be found"
        end
      else
        self.usage("Can't get annotations, you must specify genboreeGroup, genboreeDatabase and track")
      end
      return @trackObj
    end

    # Uses the getAnnoFileObj method defined in the subclass
    #
    # Requires @trackName and @refSeqId
    # [+returns+]   IO object
    def getIOFromGroupDatabaseTrack()
      ioObj = nil
      if(@trackObj.exists?)
        # Now set the data db for dbu to the db that contains the fdata2 records for the track
        dbRec = @trackObj.getDbRecWithData()
        @dbu.setNewDataDb(dbRec.dbName)
        @ftypeId = dbRec.ftypeid
        makeFtypeAttributesHash(dbRec.ftypeid)
        # use the AnnotationFile class to generate the text file data
        annoFileObj = getAnnoFileObj() # Defined in sub classes
        $stderr.puts "STATUS: about to writeAnnotationsForTrackName()"
        ioObj = annoFileObj.writeAnnotationsForTrackName(@trackName, @refSeqId)
        $stderr.puts "STATUS: done writeAnnotationsForTrackName()"
        annoFileObj.close()
      else
        @errBuffer << "ERROR: Track could not be found"
      end
      $stderr.puts "STATUS: done getIOFromGroupDatabaseTrack()"
      return ioObj
    end

    # What about the case where many large jobs are submitted.
    # All are deferred to after hours
    # After hourse, all jobs get through but are queued and processed 1 at a time.
    # and hog resources until all are complete which could be well into the next day
    #
    # We can't put the defer method after getting the largeMemJob lock because
    # jobs would be wasted in sleep mode.
    #
    # It would be better if the defer test was executed before
    #
    #
    def run()
      begin
        # PHASE 1: get estimate of job size. Need to get and release DB connections to user database for this.
        # Use GenericDBLockFile to lock :userGenbDb
        unless(@noLock)
          @jobLock = BRL::Genboree::LockFiles::GenericDbLockFile.new(:userGenbDb)
          @jobLock.getPermission()
        end
        initTrackObj()
        # First check the estimated 'size' of the job.  If it's 'huge' we will defer it to run later
        # An estimate of the 'size' of the job would probably be based on the size of the file.
        # this depends on whether the records will be expanded or not.
        #
        @trackRecCount = @trackObj.getAnnotationCount()
        sleepTime = BRL::Genboree::LockFiles::GenericDbLockFile.sleepTimeScaledBySize(@trackRecCount, @genbConfig.largeMemJobMinSleepTime.to_i, @genbConfig.largeMemJobMaxSleepTime.to_i, 7, true)
        # Done with database release permission
        @jobLock.releasePermission unless(@noLock) # Release lock
        # Must now release DB connections we established, because we may be sleeping a while before being allowed to run.
        @trackObj.clear()
        @dbu.clear()
        @dbu.clearCaches() # This is necessary to also clear out the connection pool
        $stderr.puts "STATUS: got anno count (@trackRecCount). Check if can run."

        if(@trackRecCount > @genbConfig.largeRecordsForLargeMemJobOps.to_i)
          $stderr.puts "STATUS: too big for right now. Need to try later."
          # This track is too big to run now. Check occasionally if we're allowed.
          loop {
            now = Time.now
            startTime, endTime = GenboreeConfig.getTimePeriod(@genbConfig.largeMemJobOpsTimePeriod.join(','))
            if(now >= startTime and now <= endTime)
              # This task can be very memory intensive so restrict the number of jobs that can run
              unless(@noLock)
                @jobLock = BRL::Genboree::LockFiles::GenericDbLockFile.new(:largeMemJob)
                hasPermission = @jobLock.getPermission(false) # Don't block
              end
              if(@noLock or hasPermission)
                $stderr.puts "STATUS: big op allowed to run now."
                # PHASE 2. Can run.
                # First, we need to connect back to DB and get track info again.
                @dbu = BRL::Genboree::DBUtil.new(@dbrcKey, nil, @genbConfig.dbrcFile)
                initTrackObj()
                $stderr.puts "STATUS: big op reestablished db and track object."
                # Now ready to get info and launch job
                ioObj = getIOFromGroupDatabaseTrack()
                $stderr.puts "STATUS: big op got file object about  to launch command"
                launchCmd(ioObj)
                @jobLock.releasePermission unless(@noLock) # All done, release lock
                $stderr.puts "STATUS: big op done command and released permission"
                break
              else
                $stdout.puts "#{Time.now.to_s}: Sleeping #{sleepTime.inspect} seconds because don't have :largeMemJob permission"
                sleep(sleepTime) # wait before trying again
              end
            else
              $stdout.puts "#{Time.now.to_s}: Sleeping #{sleepTime.inspect} seconds because not in valid time #{startTime.to_s} - #{endTime.to_s}"
              sleep(sleepTime) # b/c we need to wait until it's 6:20pm...
            end
          }
        else
          $stderr.puts "STATUS: small enough to run now"
          # This task is small enough so we can run it now, but still need to get the largeMemJob lock
          unless(@noLock)
            @jobLock = BRL::Genboree::LockFiles::GenericDbLockFile.new(:largeMemJob)
            @jobLock.getPermission() # blocking until receives permission
          end
          $stderr.puts "STATUS: got permission to do a large mem job."
          # PHASE 2. Can run.
          # First, we need to connect back to DB and get track info again.
          @dbu = BRL::Genboree::DBUtil.new(@dbrcKey, nil, @genbConfig.dbrcFile)
          initTrackObj()
          # Now ready to get info and launch job
          ioObj = getIOFromGroupDatabaseTrack()
          $stderr.puts "STATUS: db connections and track object reestablished. Launching."
          launchCmd(ioObj)
          @jobLock.releasePermission unless(@noLock) # Release lock
          $stderr.puts "STATUS: command run and permission released."
        end
      rescue => err
        @jobLock.releasePermission unless(@noLock) # Release lock
        $stderr.puts "ERROR in run(): #{err.message}"
        $stderr.puts err.backtrace
      end
    end

    # This method handles the steps of creating the big* file.
    #  - Create the text file
    #  - Convert the text file to big*
    def launchCmd(ioObj)
      # The annotations should be written to the text file, now convert.
      if(ioObj.is_a?(File) and ioObj.closed?)
        @outBuffer.puts Time.now.to_s + "  Annotations written. (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
        $stderr.puts "STATUS: launching ... about to get chr sizes file"
        makeChromosomeSizesFile()
        $stderr.puts "STATUS: launching ... got chr sizes file"
        # execute the converter.
        @outBuffer.puts Time.now.to_s + "  Launching converter #{converterName} (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
        convertCmd = "#{@converterName} #{@txtFileName} #{@chrSizesFileName} #{@bigFileName}.tmp > #{@converterOutFileName} 2> #{@converterErrFileName}"
        $stderr.puts "STATUS: launching ... about to run this converter command\n   #{convertCmd.inspect}"
        # Using system so that we can capture the exit status
        @converterStatus = system(convertCmd)
        $stderr.puts "STATUS: launching ... command done running"
        if(@converterStatus and File.exists?(@bigFileName + '.tmp'))
          File.open(@converterOutFileName, 'r') { |file| file.each { |line| @outBuffer << line } }
          # if @converterStatus is good, put any stderr to stdout because the UCSC commands print info to stderr even if the command is successful
          File.open(@converterErrFileName, 'r') { |file| file.each { |line| @outBuffer << line } }
          FileUtils.mv(@bigFileName + '.tmp', @bigFileName)
        else
          File.open(@converterOutFileName, 'r') { |file| file.each { |line| @outBuffer << line } }
          File.open(@converterErrFileName, 'r') { |file| file.each { |line| @errBuffer << line } }
          @errBuffer.puts Time.now.to_s + "  There was an error converting the file, command '#{convertCmd}'"
        end
        @outBuffer.puts Time.now.to_s + "  Done converting, cleaning up (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
      else
        @errBuffer.puts "ERROR: There was a problem retrieving annotations. (#{ioObj.class})"
      end
    end


    def writeToLog()
      # Generate the message/log text and write it to a file that will be archived
      @messageBody = makeMessageBody()
      File.open(@msgFileName, 'w') { |file|
        file.write(@messageBody)
      }
      File.open(@logFileName, 'w') { |log|
        log.puts("STDOUT:")
        log.write(@outBuffer.string)
        log.puts("STDERR:")
        log.write(@errBuffer.string)
      }
      # Done capturing stderr, return it, so that errors go back to stderr
      $stderr = @tmpStdErr
      $stdout = @tmpStdOut
    end


    # The converter requires a tab delimited text file that contains the chromosomes and their sizes
    # We can generate this from the database.
    def makeChromosomeSizesFile

      # There exists some data that contains annotations that go past the end of the chromosome
      # This is not allowed by the UCSC big* converters and causes an error.

      chrSizesFileObj = File.new(@chrSizesFileName, 'w')
      chrRows = getFrefRows()
      chrRows.each { |chrRow|
        # Compare to the max fstop for the rid could be from fdata2 or blockLevelDataInfo
        chrSize = chrRow['rlength']
        if(@ftypeAttributesHash['gbTrackRecordType'].nil?)
          maxFstopRows = @dbu.selectMaxFstopFromFdataForRidAndFtypeId(chrRow['rid'], @ftypeId)
        else
          maxFstopRows = @dbu.selectMaxFstopFromBlockLevelDataForRidAndFtypeId(chrRow['rid'], @ftypeId)
        end
        if(!maxFstopRows.nil? and !maxFstopRows.empty?)
          chrSize = maxFstopRows.first['maxFstop'] if(maxFstopRows.first['maxFstop'].to_i > chrSize)
        end
        chrSizesFileObj.puts("#{chrRow['refname']}\t#{chrSize}\n")
      }
      chrSizesFileObj.close
    end

    def makeFtypeAttributesHash(ftypeId)
      @ftypeAttributesHash = {}
      ftypeAttributesRows = @dbu.selectFtypeAttributeNamesAndValuesByFtypeId(ftypeId)
      ftypeAttributesRows.map {|row| @ftypeAttributesHash[row['name']] = row['value']}
      return @ftypeAttributesHash
    end


    # Get the fref (entrypoint info) rows for a particular user database.
    #
    # * Assumes availability of: @dbu
    #
    # [+returns+] +Array+ of +fref+ table rows for the database.
    def getFrefRows()
      # Get entrypoints in the user database
      frefRows = @dbu.selectAllRefNames()
      frefRows.sort! {|aa,bb| aa['refname'].downcase <=> bb['refname'].downcase } unless(frefRows.nil?)
      return frefRows
    end

    def sendFinishEmail()
      if(@emailToAddress)
        require 'brl/util/emailer' # This require is here because it can cause conflicts outside of this class
        emailer = BRL::Util::Emailer.new(@genbConfig.gbSmtpHost)
        emailer.addRecipient(@emailToAddress)
        emailer.setHeaders(@genbConfig.gbFromAddress, @emailToAddress, "GENBOREE NOTICE: #{@fileType} job status.")
        emailer.setMailFrom(@genbConfig.gbFromAddress)
        emailer.addHeader("Bcc: #{@genbConfig.gbBccAddress}")
        body = (@messageBody.nil?) ? 'There was an unknown problem generating the file.' : @messageBody
        emailer.setBody(body)
        emailer.send()
      end
    end

    def finish()
      # Finish the job should always write the message to a file and email the message if that option was set.
      writeToLog()
      sendFinishEmail()
      cleanSourceFiles()
      clean
    end
  end



end ; end ; end ; end
