#!/usr/bin/env ruby

# Loading libraries
require 'pp'
require 'md5'
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'zlib'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/sql/binning'
require 'brl/genboree/hdhv'
require 'brl/genboree/helpers/sorter'
require 'brl/genboree/helpers/expander'
require 'brl/util/emailer'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/genboree/graphics/zoomLevelUpdater'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/helpers/wigValidator'
require 'brl/genboree/rest/wrapperApiCaller'

# Main Wrapper Class
class ImportWig

  # ############################################################################
  # CONSTANTS
  # ############################################################################
  BLOCKSIZE = 4000 # Number of records to insert at a time
  PXHEIGHT = 53 # Set pixel height to 53
  BUFFERSIZE = 32000000 # Read these many bytes from file at a time
  BPSPAN = BPSTEP = 1 # Track wide span and step. This is now always 1 since we are expanding blocks into single base-level scores
  HASNULLRECORDS = 'true' # Keep this true always at least for the time being
  SCALE = LOWLIMIT = 0 # Since now the program only supports 'floatScore' and 'doubleScore' uploads, scale and lowLimit are now constants.
  BLOCKSPAN = BLOCKSTEP = nil # blockStep and blockSpan are always nil now since we are expanding data into single bases.
  VARIABLESTEPRECORDS = "variableStepRecords"
  VARIABLESTEP = "variableStep"
  FIXEDSTEP = "fixedStep"
  SIZEFORDEFERRING = 200000000
  # Special Notes:
  # SCALE AND LOWLIMIT  are used just to update the database. The values will NOT be utilized by either the Genboree Genome Browser nor the library file 'hdhv.rb'.

  # ############################################################################
  # METHODS
  # ############################################################################
  # Initialize and validate command line arguments and other variables
  # [+optsHash+]   Hash with command line arguments
  # [+returns+] nil
  def initialize(optsHash)
    @prgStartTime = Time.now
    #Initializing Instance Variables
    @inputFiles = optsHash["--inputFiles"].split(",")
    @filesToProcess = [] # List of files to process
    if(optsHash['--diff'])
      @difference = optsHash['--diff'].to_i
      displayErrorMsgAndExit("--diff of less than 1 not allowed") if(@difference < 1)
    else
      @difference = 20000
    end
    @currentChr = nil
    @fileMax = nil
    @blockStart = nil
    @offset = nil
    @blockLength = 0
    @start = nil
    @sortedFiles = Hash.new
    @zDeflater = Zlib::Deflate.new()
    @zBuffer = ""
    @extractedDirs = [] # A list of the extracted dirs from the expander class (one per input file)
    @frefHash = {}
    @jobId = nil
    @jobId = optsHash['--jobId']
    @jobId = 'none' unless(@jobId)
    # declare required Hashes
    @processedChr = Hash.new
    @ridHash = Hash.new
    @interSortHash = Hash.new
    @intraSortHash = Hash.new
    @oldPrecision = @blockLowLimit = @blockMax = nil
    @fileFormat = (optsHash['--fileFormat'] ? optsHash['--fileFormat'] : nil)
    @fileFormatFromFile = nil
    @temporaryFileFormat = nil
    @emailMessage = ""
    @email = (optsHash['--email'] ? optsHash['--email'] : nil)
    @attributesPresent = optsHash['--attributesPresent']
    @groupName = optsHash['--groupName']
    @noZoom = (optsHash['--noZoom'] ? 1 : nil)
    @putBinFile = (optsHash['--putBinFile'] ? true : false)
    @skipGz = (optsHash['--skipGz'] ? true : false)
    @host = optsHash['--host']
    displayErrorMsgAndExit("Need --host with --putBinFile") if(@putBinFile and !@host)
    @error = ""
    @errorFile = ""
    @prevCoord = nil
    @min = @max = nil
    @lineCount = 0 #for counting line number for each file
    # Validate some of the command line arguments
    @maxBlockGap = (optsHash['--maxInterBlockGap'] ? optsHash['--maxInterBlockGap'].to_i : 25_000)
    @maxBlockLength = (optsHash['--maxMergedBlockLength'] ? optsHash['--maxMergedBlockLength'].to_i : 1_000_000)
    @maxPrecisionDiff = (optsHash['--maxRelativeChangeInPrecision'] ? optsHash['--maxRelativeChangeInPrecision'].to_f : 0.1)
    @maxLength = optsHash['--maxBlockLength'] ? optsHash['--maxBlockLength'].to_i : 1_000_000
    displayErrorMsgAndExit("maxRelativeChangeInPrecision cannot be greater than 0.80 and less than 0.01") if(@maxPrecisionDiff > 0.80 or @maxPrecisionDiff < 0.01)
    displayErrorMsgAndExit("maxInterBlockGap cannot be less than 100 or greater than 100000000") if(@maxBlockGap < 100 or @maxBlockGap > 100000000)
    displayErrorMsgAndExit("maxMergedBlockLength cannot be less than 100 or greater than 100000000") if(@maxBlockLength < 100 or @maxBlockLength > 100000000)
    displayErrorMsgAndExit("maxBlockLength cannot be less than 200 or greater than 200000000") if(@maxBlockLength < 200 or @maxBlockLength > 200000000)
    @trackHash = Hash.new
    @originalSpan = []
    @checkSpanExist = {}
    if(optsHash['--byte'])
      displayErrorMsgAndExit("--byte of less than 1 or greater than 64 not allowed") if(optsHash['--byte'].to_i < 1 or optsHash['--byte'].to_i > 64)
      @byte = optsHash['--byte'].to_i * 1000000
    else
      @byte = BUFFERSIZE
    end
    @trackName = nil
    if(optsHash['--trackName'])
      displayErrorMsgAndExit("Track name should have a ':'") if(optsHash['--trackName'] !~ /:/)
      @trackName = optsHash['--trackName']
    end
    @recordType = (optsHash['--recordType'] ? optsHash['--recordType'] : 'floatScore')
    if(@recordType == "floatScore")
      @dataSpan = 4
    elsif(@recordType == "doubleScore")
      @dataSpan = 8
    else
      displayErrorMsgAndExit("Incorrect recordType entered. Select one of the record types from the list given in the help section")
    end

    # Get/Set some of the track attributes
    @gbTrackUseLog = (optsHash['--useLog'] ? 'true' : 'false')
    @dataMax = (optsHash['--dataMax'] ? optsHash['--dataMax'].to_i : -10000000) # Give dataMax some Initial value if not provided
    @dataMin = (optsHash['--dataMin'] ? optsHash['--dataMin'].to_i : 10000000) # Give dataMin some Initial value if not provided
    @cBlock = (optsHash['--cBlock'] ? optsHash['--cBlock'].to_i : 1000000)
    @gbTrackWindowingMethod = nil
    @viewLimits = nil
    @visibility = nil
    @color = @altColor = ""
    @lowLimOfCBlock = 0.8 * @cBlock

    # when launching locally
    if(!optsHash['--dbrcKey'])
      #Making dbUtil Object for database 'genboree'
      gc = BRL::Genboree::GenboreeConfig.load
      @dbu = BRL::Genboree::DBUtil.new("#{gc.dbrcKey}", nil, nil)
    # launching on the cluster
    else
      @dbu = BRL::Genboree::DBUtil.new(optsHash['--dbrcKey'], nil, nil)
    end

    # Check if throttling has to be over ridden
    @lockFalse = (optsHash['--importLockFalse'] ? 1 : 0)

    # Check whether loginName or loginId provided is valid
    # get one from the other
    userName = optsHash['--userName'].strip
    if(userName =~ /^\d+$/)
      @userId = userName.to_i
      #Check if user with the provided userId exists
      userCheck = @dbu.getUserByUserId(@userId)
      displayErrorMsgAndExit("User with userId: #{@userId} does not exist") if(userCheck.empty?)
    else
      userVal = @dbu.getUserByName(userName)
      displayErrorMsgAndExit("#{userName} does not exist") if(userVal.empty?)
      @userId = userVal.first['userId']
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
    # Set target directory for binary file
    dirFromFmeta = @dbu.selectValueFmeta('RID_SEQUENCE_DIR')
    if(optsHash['--dir'])
      @dir = optsHash['--dir']
    else
      @dir = dirFromFmeta
    end
    @blockLevelData = Array.new() # Array for storing blockLevelDatainfo inserts
    @dbCount = 0
    $stderr.puts "STATUS: Done contacting DB and getting group/database info."

    # put the rest of the stuff in a begin rescue block
    # This will help us track any unknown/mysterious errors
    # encountered during the upload
    # This part basically covers three things:
    # 1) validation
    # 2) setting track attributes
    # 3) file processing - inserting database records and writing out the binary file
    begin
      if(@lockFalse == 0)
        @genbConf = ENV['GENB_CONFIG']
        @genbConfig = BRL::Genboree::GenboreeConfig.load(@genbConf)
        @dbLock = BRL::Genboree::LockFiles::GenericDbLockFile.new(:useImportTool)
        fileSize = 0
        @inputFiles.each { |file|
          expanderObj = BRL::Genboree::Helpers::Expander.new(file)
          fileType = expanderObj.getFileType()
          # Get size (uncompressed)
          if(fileType == "text")
            fileSize += File.size(file)
          elsif(fileType == "gzip")
            fileSize += BRL::Util::Gzip.getUncompressedSize(file).to_i
          else
            fileSize += File.size(file) * 20
          end
        }
        sizeForDeferring = @genbConfig.deferFileSizeForWIG.to_i
        # check if the job is to be deferred
        if(fileSize >= sizeForDeferring)
          hasPermission = false
          loop {
            now = Time.now
            startTime, endTime = BRL::Genboree::GenboreeConfig.getTimePeriod(@genbConfig.bigDbOpTimePeriod.join(',')) # use the same deferring times as those of the bigwig jobs
            if(now >= startTime and now <= endTime)
              hasPermission = @dbLock.getPermission(false) # Don't block
              if(hasPermission)
                break
              else
                sleepTime = BRL::Genboree::LockFiles::GenericDbLockFile.sleepTimeScaledBySize(fileSize, minSleepTime=30, maxSleepTime=1800, adjFactor=5, addRandomExtra=true)
                $stderr.puts "#{Time.now.to_s}: Sleeping #{sleepTime.inspect} seconds because don't have :useImportTool permission"
                sleep(sleepTime) # wait before trying again
                # Check again if file size for deferring has been changed
                @genbConfig = BRL::Genboree::GenboreeConfig.load(@genbConf)
                sizeForDeferring = @genbConfig.deferFileSizeForWIG.to_i
                break if(fileSize < sizeForDeferring)
              end
            else
              sleepTime = BRL::Genboree::LockFiles::GenericDbLockFile.sleepTimeScaledBySize(fileSize, minSleepTime=30, maxSleepTime=1800, adjFactor=5, addRandomExtra=true)
              $stderr.puts "#{Time.now.to_s}: Sleeping #{sleepTime.inspect} seconds because not in valid time #{startTime.to_s} - #{endTime.to_s}"
              sleep(sleepTime) # b/c we need to wait until it's 6:20pm...
              # Check again if file size for deferring has been changed
              @genbConfig = BRL::Genboree::GenboreeConfig.load(@genbConf)
              sizeForDeferring = @genbConfig.deferFileSizeForWIG.to_i
              break if(fileSize < sizeForDeferring)
            end
          }
          if(!hasPermission) # This can only happen if deferFileSizeForWIG changed while the program was sleeping and the loop exited
            sleepTime = BRL::Genboree::LockFiles::GenericDbLockFile.sleepTimeScaledBySize(fileSize, minSleepTime=30, maxSleepTime=1800, adjFactor=5, addRandomExtra=true)
            @dbLock.getPermission(blocking=true, sleepTime)
          end
        else
          sleepTime = BRL::Genboree::LockFiles::GenericDbLockFile.sleepTimeScaledBySize(fileSize, minSleepTime=30, maxSleepTime=1800, adjFactor=5, addRandomExtra=true)
          @dbLock.getPermission(blocking=true, sleepTime)
        end
      end
      # Get the list of entrypoints (required during validation)
      @allFrefHash = Hash.new
      allFrefRecords = @dbu.selectAllRefNames()
      allFrefRecords.each { |record|
        @allFrefHash[record['refname']] = record['rid'].to_i
        @frefHash[record['refname']] = [record['rlength'].to_i, record['rid'].to_i] if(!@frefHash.has_key?(record['refName']))
      }
      # Check to see if validation is required
      @validate = (optsHash['--noValidation'] ? 0 : 1)
      if(@validate == 0)
        if(optsHash['--fileFormat'].nil? or optsHash['--trackName'].nil?)
          @dbLock.releasePermission if(@lockFalse == 0) # Release lock
          displayErrorMsgAndExit('Both --fileFormat and --trackName need to be provided for skipping validation')
        end
        $stderr.puts "Skipping Validation..."
      else
        # Validate Files, get error list, if any
        $stderr.puts "STATUS: beginning validation"
        validateFiles()
        $stderr.puts "STATUS: finished validation"
      end
      # Override the windowing method setting in the file if provided via the command line
      @gbTrackWindowingMethod = (optsHash['--gbTrackWindowingMethod'] ? optsHash['--gbTrackWindowingMethod'] : @gbTrackWindowingMethod)
      @gbTrackWindowingMethod = 'MAX' if(@gbTrackWindowingMethod.nil?)
      # Throw exception if windowing method is not supported
      if(@gbTrackWindowingMethod != 'MAX' and @gbTrackWindowingMethod != 'MIN' and @gbTrackWindowingMethod != 'AVG')
        @dbLock.releasePermission if(@lockFalse == 0) # Release lock
        displayErrorMsgAndExit("Unsupported windowing method: #{@gbTrackWindowingMethod}")
      end
      # Hash for setting track attributes
      # Note that track attributes will not be set if the track already exists
      @attributeHash =
      {
        "gbTrackBpSpan" => BPSPAN,
        "gbTrackBpStep" => BPSTEP,
        "gbTrackUseLog" => @gbTrackUseLog,
        "gbTrackDataMax" => @dataMax,
        "gbTrackDataMin" => @dataMin,
        "gbTrackWindowingMethod" => @gbTrackWindowingMethod,
        "gbTrackRecordType" => @recordType,
        "gbTrackDataSpan" => @dataSpan,
        "gbTrackHasNullRecords" => HASNULLRECORDS,
        "gbTrackPxHeight" => @pixelHeight,
        "gbTrackUserMax" => @dataMax,
        "gbTrackUserMin" => @dataMin
      }

      # Convert variableStep to fixedstep
      # Store data as is if fileFormat is fixedStep
      if(@fileFormat == "variableStep")
        # If new track, add track attributes, make binary file
        # If old track, track attributes, if provided will not be set
        # If old track, a new binary file will be created
        processTrackSettings()
        # Convert 'variableStep' data to 'fixedStep' by expanding the data by the block span (or track wide span if block span is missing)
        processVariableStep()
        # Set 'gbTrackBpSpan' as 1
        @dbu.insertFtypeAttrValue(1); valId = getAttrValueId(1)
        nameId = getAttrNameId("gbTrackBpSpan")
        @dbu.updateFtype2AttributeForFtypeAndAttrName(@ftypeId, nameId.first['id'], valId.first['id'])
        #set 'gbTrackBpStep' as 1
        nameId = getAttrNameId('gbTrackBpStep')
        @dbu.updateFtype2AttributeForFtypeAndAttrName(@ftypeId, nameId.first['id'], valId.first['id'])
      elsif(@fileFormat == "fixedStep")
        # If new track, add track attributes, make binary file
        # If old track, track attributes if provided will not be set
        # If old track, a new binary file will be created
        processTrackSettings()
        # Store 'fixedStep' as is
        processFixedStep()
      end
      $stderr.puts "STATUS: done processing track settings and the file."
      # Update track wide max and min
      @dbu.insertFtypeAttrValue(@dataMax)
      @dbu.insertFtypeAttrValue(@dataMin)
      # get ids for the values
      dataMinValId = getAttrValueId(@dataMin)
      dataMaxValId = getAttrValueId(@dataMax)
      # get ids for the attr names
      dataMinNameId = getAttrNameId("gbTrackDataMin"); dataMaxNameId = getAttrNameId("gbTrackDataMax")
      @dbu.updateFtype2AttributeForFtypeAndAttrName(@ftypeId, dataMinNameId.first['id'], dataMinValId.first['id'])
      @dbu.updateFtype2AttributeForFtypeAndAttrName(@ftypeId, dataMaxNameId.first['id'], dataMaxValId.first['id'])
      $stderr.puts "STATE: 'gbTrackDataMax' updated to: #{@dataMax}"
      $stderr.puts "STATE: 'gbTrackDataMin' updated to: #{@dataMin}"
      # Update track attributes (from the track header) if its a new track
      if(@appendToTrackBoolean == 0)
        dataMinNameId = getAttrNameId("gbTrackUserMin"); dataMaxNameId = getAttrNameId("gbTrackUserMax")
        if(@viewLimits.nil?)
          @dbu.updateFtype2AttributeForFtypeAndAttrName(@ftypeId, dataMinNameId.first['id'], dataMinValId.first['id'])
          @dbu.updateFtype2AttributeForFtypeAndAttrName(@ftypeId, dataMaxNameId.first['id'], dataMaxValId.first['id'])
          $stderr.puts "STATE: 'gbTrackUserMax' updated to: #{@dataMax}"
          $stderr.puts "STATE: 'gbTrackUserMin' updated to: #{@dataMin}"
        else
          # Use the user max and min from the track header (viewLimits )
          max = @viewLimits[1].to_f
          min = @viewLimits[0].to_f
          @dbu.insertFtypeAttrValue(max)
          @dbu.insertFtypeAttrValue(min)
          # get ids for the values
          dataMinValId = getAttrValueId(min)
          dataMaxValId = getAttrValueId(max)
          @dbu.updateFtype2AttributeForFtypeAndAttrName(@ftypeId, dataMinNameId.first['id'], dataMinValId.first['id'])
          @dbu.updateFtype2AttributeForFtypeAndAttrName(@ftypeId, dataMaxNameId.first['id'], dataMaxValId.first['id'])
          $stderr.puts "STATE: 'gbTrackUserMax' updated to: #{max}"
          $stderr.puts "STATE: 'gbTrackUserMin' updated to: #{min}"
        end
        if(!@altColor.empty?)
          insertAttrNameAndValue('gbTrackNegativeColor', @altColor)
          altColorName_id = getAttrNameId('gbTrackNegativeColor')
          altColorValue_id = getAttrValueId(@altColor)
          insertIntoFtype2AttributeTable(@ftypeId, altColorName_id, altColorValue_id)
        end
        # Update the display to 'Compact'
        displayStyle = nil
        if(!@visibility.nil?)
          if(@visibility == 'full' or @visibility == 2)
            displayStyle = 'Expand'
          elsif(@visibility == 'dense' or @visibility == 1)
            displayStyle = 'Compact'
          elsif(@visibility == 'hide' or @visibility == 0)
            displayStyle = 'Hidden'
          end
        else
          displayStyle = 'Compact'
        end
        rowsAffected = @trackObj.setDisplayForUserId(displayStyle, 0)
        if(rowsAffected == 0)
          $stderr.puts "WARNING: Display could not be set to #{displayStyle} for #{@trackName}"
        else
          $stderr.puts "STATUS: Display updated to #{displayStyle} for #{@trackName}"
        end
        # Add description to track if not nil
        feautureUrlRecs = @dbu.selectFeatureurlByFtypeId(@ftypeId)
        @dbu.insertFeatureurl(@ftypeId, "", "#{@description}", "") if(!@description.nil? and feautureUrlRecs.empty?)
        # Insert 'gbTrackOriginalSpan'
        @dbu.insertFtypeAttrName('gbTrackOriginalSpan')
        # Insert all the original spans from the wiggle file
        @originalSpan.push(1) if(@originalSpan.empty?)
        spanString = @originalSpan.join(",")
        @dbu.insertFtypeAttrValue(spanString)
        # get the attribute name id for 'gbTrackOriginalSpan'
        originalSpanNameId = getAttrNameId('gbTrackOriginalSpan')
        # Add a record into ftype2attributes for each of the spans
        spanId = getAttrValueId(spanString)
        insertIntoFtype2AttributeTable(@ftypeId, originalSpanNameId, spanId)
      # For an old track just update the original spans from the wig file
      else
        # Insert all the original spans from the wiggle file
        @originalSpan.push(1) if(@originalSpan.empty?)
        originalSpanNameId = getAttrNameId('gbTrackOriginalSpan')
        spanString = ""
        spanString = @dbu.selectFtypeAttrValueByFtypeIdAndAttributeNameId(@ftypeId, originalSpanNameId.first['id'])
        if(!spanString.empty?)
          spanString = spanString.first['value']
          spans = spanString.split(",")
          @originalSpan.each { |span|
            seeIfPresent = 0
            spans.each  { |oldSpan|
              seeIfPresent += 1 if(oldSpan.to_i == span)
            }
            spans.push(span) if(seeIfPresent != 0)
          }
          spanString = ""
          spanCount = 0
          spans.each { |span|
            spanString << "#{span}" if(spanCount == 0)
            spanString << ",#{span}" if(spanCount == 1)
            spanCount = 1
          }
          @dbu.insertFtypeAttrValue(spanString)
          spanId = getAttrValueId(spanString)
          @dbu.updateFtype2AttributeForFtypeAndAttrName(@ftypeId, originalSpanNameId.first['id'], spanId.first['id'])
        else
          spanString = @originalSpan.join(",")
          @dbu.insertFtypeAttrValue(spanString)
          # get the attribute name id for 'gbTrackOriginalSpan'
          originalSpanNameId = getAttrNameId('gbTrackOriginalSpan')
          # Add a record into ftype2attributes for each of the spans
          spanId = getAttrValueId(spanString)
          insertIntoFtype2AttributeTable(@ftypeId, originalSpanNameId, spanId)
        end
      end
      @binaryWriter.close()
      @dbLock.releasePermission if(@lockFalse == 0) # Release lock
      $stderr.puts "STATUS: Done processing file, about to clean up...."
      # Remove the temp dirs created by the expander class
      # Will be just one dir for most cases (if uploading via the API/UI)
      @extractedDirs.each { |dir|
        `rm -rf #{dir}`
      }
      # Go through the list of input files and compress them if not already compressed
      @inputFiles.each { |file|
        expanderObj = BRL::Genboree::Helpers::Expander.new(file)
        `gzip -f #{file}` if(!expanderObj.isCompressed?(file)) unless(@skipGz)
      }
      # See if the bin file is to be copied over to the server using the APICaller
      if(@putBinFile)
        rsrcPath = "/REST/v1/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@refseqName)}/file/#{CGI.escape(@outputFile)}/data?fileType=bin"
        hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @userId)
        apiCaller = BRL::Genboree::REST::ApiCaller.new(@host, rsrcPath, hostAuthMap)
        apiCaller.put({}, File.open(@outputFile))
        if(!apiCaller.succeeded?)
          raise "Failed to copy over .bin file: #{@outputFile} to host: #{@host} at rsrcPath: #{rsrcPath}; hostAuthMap: #{hostAuthMap.inspect}.\nAPI Response:\n#{apiCaller.respBody.inspect}"
        else
          $stderr.puts "STATUS: Copied over .bin file using API. Removing from scratch dir..."
          `rm -f #{@outputFile}`
        end
      end
      $stderr.puts "STATUS: All Done...about to send email"
      @emailMessage = "The process of validating and uploading your data was successful.\n  JobId: '#{@jobId}'\n  Track: '#{@trackName}'\n  Class: 'High Density Score Data'\n  Database: '#{@refseqName}'\n  Group: '#{@groupName}'\n\n" +
                      "Began at: #{@prgStartTime}.\nEnding at: #{Time.now}\n\n" +
                      "You can now login to Genboree and visualize your data.\n\n\n" +
                      "The Genboree Team"
      sendEmail('[SUCCESS]') if (!@email.nil?)
    rescue Exception => err
      @dbLock.releasePermission if(@lockFalse == 0) # Release lock
      displayErrorMsgAndExit(err)
    end
  end

  #  Validate all input files
  #  No Arguments and no return value
  #  Makes a list of errors and prints to standard error
  # [+returns+] nil
  def validateFiles()
    @readerArray = Array.new()
    $stderr.puts "STATUS: Validating..."
    ii = 0
    #Check if all files in the filelist exist.
    #Make readers for each of the file after expanding (expansion may or may not be required).
    @inputFiles.each { |file|
      raise ArgumentError, "Unable to read/open the file: #{file}.", caller if(!File.exists?(file))
      expanderObj = BRL::Genboree::Helpers::Expander.new(file)
      compressed = expanderObj.isCompressed?(file)
      expanderObj.extract(desiredType = 'text')
      fullPathToUncompFile = expanderObj.uncompressedFileName
      raise ArgumentError, "Unable to decompress file: #{file}", caller if(!expanderObj.stderrStr.empty?)
      # If the expanded path is a dir (for a multi-file archive), we need to go through that dir and collect all the non compressed files in that dir
      if(File.directory?(fullPathToUncompFile))
        Dir.entries(fullPathToUncompFile).each { |file|
          if(!expanderObj.isCompressed?("#{fullPathToUncompFile}/#{file}")) # Only select the non-compressed files
            @filesToProcess[ii] = "#{fullPathToUncompFile}/#{file}"
            @readerArray[ii] = BRL::Util::TextReader.new("#{fullPathToUncompFile}/#{file}")
            ii += 1
          end
        }
      else
        @filesToProcess[ii] = fullPathToUncompFile
        @readerArray[ii] = BRL::Util::TextReader.new(fullPathToUncompFile)
        ii += 1
      end
      @extractedDirs << expanderObj.tmpDir
    }
    $stderr.puts "    - extraction completed (if needed)"
    # If '--trackName' not present
    if(@trackName.nil?)
      # First non-blank, non-commented line has to be track header for the first file
      @lineCount = 0
      line = readFirstNonBlank(@readerArray[0])
      if(line !~ /^track/)
        @error << "First non-blank, non-commented line of first file not track header for file #{@filesToProcess[0]}"
      else
        # Store AVPS for track
        rr = /([^= \t]+)\s*=\s*(?:(?:([^ \t"']+))|(?:"([^"]+)")|(?:'([^']+)'))/ # regular expression for parsing track header
        line.scan(rr) { |md|
          @trackHash[md[0]] = "#{md[1]}#{md[2]}#{md[3]}" if(!@trackHash.has_key?(md[0]))
        }
      end
      # Check if track name has a ':'
      raise ArgumentError, "Track name from wiggle file does not have a ':'", caller if(@trackHash['name'] !~ /:/)
      
      scanTrackAttributes() # set attributes from track header, if any
      #The next non-blank, non-commented line has to be the block header (for the first file)
      # Set file format from the first block header of the first file if '--fileFormat' missing
      line = readFirstNonBlank(@readerArray[0])
      error = checkBlockHeader(line, @filesToProcess[0], 1)
      @temporaryFileFormat = (@fileFormat.nil? ? @fileFormatFromFile : @fileFormat) if(error.empty?)
      @error = @error.to_s + error if(!error.empty?)
      # Check the remainder of the data (rest of the first file and other files) (file format should not change)
      # Check rest of the file
      # Assume file does not require sorting
      # @interSort is for sorting blocks relative to each other (applies to both variableStep and fixedStep)
      # @intraSort is for sorting records within a block (only applies to variableStep)
      # My intention is to only sort when it is required, not all the time. This will be beneficial if the file
      # already adhears to our standards and save time
      @sortRequired = @interSort = @intraSort = :NO
      error = checkFileFormat(@readerArray[0], @filesToProcess[0])
      @error << error if(!error.empty?)
      if(!@error.empty?)
        raise ArgumentError, "#{@error}", caller
      else
        # Finalizing fileFormat and trackName
        @trackName = (@trackName ? @trackName : @trackHash['name'])
        @fileFormat = (@fileFormat ? @fileFormat : @fileFormatFromFile)
        $stderr.puts "#{@filesToProcess[0]} validated. No errors!"
        $stderr.puts "    - Is sorting required...?"
        if(@sortRequired == :NO)
          $stderr.puts "      . No...Good!"
          @interSortHash[@filesToProcess[0]] = @intraSortHash[@filesToProcess[0]] = :NO
        else
          $stderr.puts "      . Yes...Damn!"
          @interSortHash[@filesToProcess[0]] = @interSort
          @intraSortHash[@filesToProcess[0]] = @intraSort
        end
      end
      #Check the other files, if any
      if(@filesToProcess.size > 1)
        numOfFilesToCheck = @filesToProcess.size - 1
        fileNum = 1
        numOfFilesToCheck.times { |ii|
          # First check if the file starts with a block header
          @lineCount = 0
          tempReader = @readerArray[fileNum]
          line = readFirstNonBlank(tempReader)
          if(line =~ /^fixedStep/ or line =~ /^variableStep/)
            error = checkBlockHeader(line, @filesToProcess[fileNum], 0)
            @error = @error.to_s + error if(!error.empty?)
          else
            line = readFirstNonBlank(tempReader)
            if(line =~ /^fixedStep/ or line =~ /^variableStep/)
              error = checkBlockHeader(line, @filesToProcess[fileNum], 0)
            else
              @error << "#{@filesToProcess[fileNum]} does not start with block header\n" if(line !~ /^fixedStep/ and line !~ /^variableStep/)
            end
          end
          # Assume file does not require sorting
          # @interSort is for sorting blocks relative to each other (applies to both variableStep and fixedStep)
          # @intraSort is for sorting records within a block (only applies to variableStep)
          # My intention is to only sort when it is required, not all the time. This will be beneficial if the file
          # already adhears to our standards and will save computation time
          @sortRequired = @interSort = @intraSort = :NO
          error = checkFileFormat(tempReader, @filesToProcess[fileNum])
          @error << error if(!error.empty?)
          if(!@error.empty?)
            raise ArgumentError, "#{@error}", caller
          else
            $stderr.puts "#{@filesToProcess[fileNum]} validated. No errors!"
            $stderr.puts "       - Is sorting required...?"
            if(@sortRequired == :NO)
              $stderr.puts "        . No...Good!"
              @interSortHash[@filesToProcess[fileNum]] = @intraSortHash[@filesToProcess[fileNum]] = :NO
            else
              $stderr.puts "       . Yes...Damn!"
              @interSortHash[@filesToProcess[fileNum]] = @interSort
              @intraSortHash[@filesToProcess[fileNum]] = @intraSort
            end
          end
          fileNum += 1
        }
      end
    # If '--trackName' is present
    else
      # Check if all files start with a block header and the file format does not change
      # Set file format from the first block header of the first file if '--fileFormat' missing
      @filesToProcess.size.times { |ii|
        # First check if the file starts with a block header
        tempReader = @readerArray[ii]
        @lineCount = 0
        line = readFirstNonBlank(tempReader)
          if(ii == 0)
            # Get track attributes if line is a track header
            if(line =~ /^track/)
              # Store AVPS for track
              rr = /([^= \t]+)\s*=\s*(?:(?:([^ \t"']+))|(?:"([^"]+)")|(?:'([^']+)'))/ # regular expression for parsing track header
              line.scan(rr) { |md|
                @trackHash[md[0]] = "#{md[1]}#{md[2]}#{md[3]}" if(!@trackHash.has_key?(md[0]))
              }
              scanTrackAttributes() # set attributes from track header, if any
            # set some default required track attributes
            else
              @autoScale = 'on'
              @pixelHeight = PXHEIGHT
              @description = nil
            end
          end
        if(line =~ /^fixedStep/ or line =~ /^variableStep/)
          error = checkBlockHeader(line, @filesToProcess[ii], 1) if(ii == 0)
          @temporaryFileFormat = (@fileFormat.nil? ? @fileFormatFromFile : @fileFormat) if(error.empty? and ii == 0)
          error = checkBlockHeader(line, @filesToProcess[ii], 0) if(ii != 0)
          @error = @error.to_s + error if(!error.empty?)
        else
          line = readFirstNonBlank(tempReader)
          if(line =~ /^fixedStep/ or line =~ /^variableStep/)
            error = checkBlockHeader(line, @filesToProcess[ii], 1) if(ii == 0)
            @temporaryFileFormat = (@fileFormat.nil? ? @fileFormatFromFile : @fileFormat) if(error.empty? and ii == 0)
            error = checkBlockHeader(line, @filesToProcess[ii], 0) if(ii != 0)
            @error = @error.to_s + error if(!error.empty?)
          else
            @error << "#{@filesToProcess[ii]} does not start with block header\n"
          end
        end
        # Check rest of the file
        # Assume file does not require sorting
        # @interSort is for sorting blocks relative to each other (applies to both variableStep and fixedStep)
        # @intraSort is for sorting records within a block (only applies to variableStep)
        # My intention is to only sort when it is required, not all the time. This will be beneficial if the file
        # already adhears to our standards and will save computing time
        @sortRequired = @interSort = @intraSort = :NO
        error = checkFileFormat(tempReader, @filesToProcess[ii])
        @error << error if(!error.empty?)
        if(!@error.empty?)
          raise ArgumentError, "#{@error}", caller
        else
          # Finalizing fileFormat and trackName
          if(ii == 0)
            @trackName = (@trackName ? @trackName : @trackHash['name'])
            @fileFormat = (@fileFormat ? @fileFormat : @fileFormatFromFile)
          end
          $stderr.puts "#{@filesToProcess[ii]} validated. No errors!"
          $stderr.puts "    - Is sorting required...?"
          if(@sortRequired == :NO)
            $stderr.puts "      . No...Good!"
            @interSortHash[@filesToProcess[ii]] = @intraSortHash[@filesToProcess[ii]] = :NO
          else
            $stderr.puts "       . Yes...Damn!"
            @interSortHash[@filesToProcess[ii]] = @interSort
            @intraSortHash[@filesToProcess[ii]] = @intraSort
          end
        end
      }
    end
    # Close reader array handler
    @readerArray.each { |reader|
      reader.close
    }
  end

  # Does the track exist?
  # If not, create the track, set default style, color and display settings, set track attributes
  # If it does, make a new binary file. Do not set any new trac attributes
  # [+returns+] nil
  def processTrackSettings()
    # Check if track exists in database:
    $stderr.puts "STATUS: Checking if track exists..."
    val = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(@refseqId, @userId, true, @dbu)
    # For new track or private track
    if(val["#{@trackName}"].nil?)
      fmethodAndFsource = @trackName.split(":")
      fmethod = fmethodAndFsource[0]; fsource = fmethodAndFsource[1]
      retVal = @dbu.selectAllByFmethodAndFsource(fmethod, fsource)
      if(!retVal.empty?)
        raise ArgumentError, "This track is not accessible to the user: #{@userId}", caller
      else
        @appendToTrackBoolean = 0
        $stderr.puts "Track: #{@trackName} does not exist. Creating...."
        typeAndSubtype = @trackName.split(":")
        fmethod = typeAndSubtype[0]; fsource = typeAndSubtype[1]
        # Making Track object
        @trackObj = BRL::Genboree::Abstract::Resources::Track.new(@dbu, @refseqId, fmethod, fsource)

        #Setting style
        displayStyle = (@autoScale == 'on' ? 'Local Score Barchart (big)' : 'Global Score Barchart (big)')
        rowsAffected = @trackObj.setStyleForUserId(displayStyle, 0)
        if(rowsAffected == 0)
          $stderr.puts "WARNING: Style not set for #{@trackName}"
        else
          $stderr.puts "STATUS: style :#{displayStyle} set for #{@trackName}"
        end

        #Setting color
        colorToUse = nil
        if(@color.empty? or @color.nil?)
          colorToUse = "#000000"
        else
          colorToUse = @color
        end
        rowsAffected = @trackObj.setColorForUserId(colorToUse, 0)
        if(rowsAffected == 0)
          $stderr.puts "WARNING: Color not set for #{@trackName}"
        else
          $stderr.puts "STATUS: color #{colorToUse} set for #{@trackName}"
        end

        #Setting display
        rowsAffected = @trackObj.setDisplayForUserId("Hidden", 0)
        if(rowsAffected == 0)
          $stderr.puts "WARNING: Display not set for #{@trackName}"
        else
          $stderr.puts "STATUS: display :Hidden set for #{@trackName}"
        end

        #First get the 'ftypeId' for the track
        ftype = @dbu.selectFtypeByTrackName(@trackName)
        @ftypeId = ftype.first['ftypeid']
        # Inserting record for 'gclass' and 'ftype2gclass'
        insertIntoGclassAndFtype2GClass(@ftypeId)
        ############ Inserting track-wide attribute name and values ######################
        ############ Note: If these names and values are already    ######################
        ############ there, dbUtil will ignore the inserts          ######################


        # Inserting attribute names and values for the track
        @attributeHash.each_key { |key|
          insertAttrNameAndValue(key, @attributeHash[key])
          ftypeAttrName = getAttrNameId(key);
          ftypeAttrValue = getAttrValueId(@attributeHash[key]);
          insertIntoFtype2AttributeTable(@ftypeId, ftypeAttrName, ftypeAttrValue)
        }
        # Make file which will contain the binary data under ridSequences/refseqId/
        system("mkdir -p #{@dir}")
        randName = rand(60000)
        @outputFile = Rack::Utils.escape("#{@trackName}.#{Time.now()}.#{randName}.bin")
        begin
          @binaryWriter = BRL::Util::TextWriter.new("#{@dir}/#{@outputFile}")
        rescue => err
          raise ArgumentError, "Unable to create binary file for track: #{@trackName}\n#{err}", caller
        end
        $stderr.puts "STATUS: binary file created for Track #{@trackName}"
      end
    # If track exists, make a new binary file.
    else
      # Make sure track does not belong to shared/template database
      if(val["#{@trackName}"]["dbNames"].size > 1)
        raise ArgumentError, "This track already belongs to template/shared database. Appending data to this track is not allowed. Please choose another name for this track", caller
      else
        # Get the ftypeId for the track
        ftype = @dbu.selectFtypeByTrackName(@trackName)
        @ftypeId = ftype.first['ftypeid']
        $stderr.puts "STATUS: track exists..."
        # Check if the track is empty
        $stderr.puts "STATUS: Check if track is empty..."
        ftypeCountRec = @dbu.selectFtypeCountByFtypeid(val[@trackName]['ftypeid'])
        noOfAnnos = 0
        if(ftypeCountRec.nil? or ftypeCountRec.empty?)
          noOfAnnos = 0
        else
          noOfAnnos = ftypeCountRec.first[1].to_i
        end
        if(noOfAnnos == 0)
          if(!@attributesPresent)
            $stderr.puts "STATUS: Track is empty. Setting attributes..."
            @appendToTrackBoolean = 0
            # Inserting attribute names and values for the track
            @attributeHash.each_key { |key|
              insertAttrNameAndValue(key, @attributeHash[key])
              ftypeAttrName = getAttrNameId(key);
              ftypeAttrValue = getAttrValueId(@attributeHash[key]);
              insertIntoFtype2AttributeTable(@ftypeId, ftypeAttrName, ftypeAttrValue)
            }
          else
            @appendToTrackBoolean = 1
          end
          # Inserting record for 'gclass' and 'ftype2gclass'
          insertIntoGclassAndFtype2GClass(@ftypeId)
        else
          @appendToTrackBoolean = 1
          $stderr.puts "STATUS: Track not empty..."
          $stderr.puts "STATUS: Getting track attributes from database..."
          # Get record type to check if track is a 'HDHV' track
          attrNameId = getAttrNameId('gbTrackRecordType')
          recordType = @dbu.selectFtypeAttrValueByFtypeIdAndAttrNameId(@ftypeId, attrNameId.first['id'])
          recordType = recordType.to_s
          if(recordType.empty? or recordType.nil?)
            raise ArgumentError, "This track is not a High Density (wiggle) track. Appending this type of data is not allowed", caller
          else
            # Also check if the record types match up
            raise ArgumentError, "--recordType does not match the existing recordType for this track", caller if(recordType != @attributeHash['gbTrackRecordType'])
          end
        end
        # Making Track object
        typeAndSubtype = @trackName.split(":")
        @trackObj = BRL::Genboree::Abstract::Resources::Track.new(@dbu, @refseqId, typeAndSubtype[0], typeAndSubtype[1])
        # set dbUtil object back to user database
        @dbu.setNewDataDb(@databaseName)
        @dbu.connectToDataDb()
        # Create a new binary file
        randName = rand(60000)
        @outputFile = Rack::Utils.escape("#{@trackName}.#{Time.now()}.#{randName}.bin")
        begin
          @binaryWriter = BRL::Util::TextWriter.new("#{@dir}/#{@outputFile}")
        rescue => err
          raise ArgumentError, "Unable to create binary file for track: #{@trackName}\n#{err}", caller
        end
        $stderr.puts "STATUS: new binary file created for Track #{@trackName}"
      end
    end
  end

  # Processes fixedStep wiggle file(s)
  # Checks if sorting is required or not by referring to the hash made
  # during validation.
  # Merges blocks into a single block (if conditions are met)
  # Use zlib to compress the binary stream for each block
  # Writes to Binary file and updates database
  # [+returns+] nil
  def processFixedStep()
    $stderr.puts "STAUTS: Processing fixed step file..."
    @attrHashDb = Hash.new # hash for storing track attributes from database
    # Get all required track wide attributes
    setAttrHashDb() # This method fills up @attrHashDb with the required track attributes and values
    @dataMax = @attrHashDb['gbTrackDataMax'].to_f
    @dataMin = @attrHashDb['gbTrackDataMin'].to_f
    recType = @attrHashDb["gbTrackRecordType"]
    noOfBytesToUse = 0
    if(recType == "floatScore")
      noOfBytesToUse = 4
    elsif(recType == "doubleScore")
      noOfBytesToUse = 8
    end
    # Make all the C objects
    cObj1 = BRL::Genboree::CreateBuffer.new()
    cObjFixed = BRL::Genboree::ReadFixedStep.new()
    @cBuffer = cObj1.createBuffer(noOfBytesToUse, @cBlock)
    @readerArray = Array.new()
    reader = nil
    # Go through each of the input file
    @filesToProcess.each { |file|
      # Check if sorting is required
      if(@interSortHash[file] == :YES)
        sortObj = BRL::Genboree::Helpers::Sorter.new(FIXEDSTEP, file)
        $stderr.puts "    - Sorting file: #{file}..."
        tt = Time.now
        sortObj.sortFile()
        $stderr.puts "    - Sorting completed..."
        $stderr.puts "    - Time taken to sort: #{Time.now - tt}"
        reader = BRL::Util::TextReader.new(sortObj.sortedFileName)
      else
        reader = BRL::Util::TextReader.new(file)
      end
      # Initialize variables used in processing data
      @dataArray = Array.new()
      @blockLineCount = 0
      blockInsert = 0
      bufferCount = 0
      insertCount = 0
      fileLine = 0
      @sizeCheck = 0
      @cBufferFlag = 0
      @cBufferPointer = 0
      percDone = 0
      @byteRead = 0
      @recordCount = 0
      @blockLength = 0
      addMore = 0
      blockGap = 0
      @numScores = 0
      @startCount = 1
      # variables specific for adding zoom level info:
      previousChrZoom = nil
      chrZoom = nil
      startZoom = nil
      spanZoom = nil
      bpCoordZoom = nil
      stepZoom = nil
      startCoordZoom = 0
      doNotAddBlock = 0
      @nullScore = @fileMax + 1
      zoomObj = ZoomLevelUpdater.new(@dbu)
      $stderr.puts "    - Writing Binary data and updating database..."
      # Read parts of the file in memory and then process until the file is completely processed
      while(!reader.eof?)
        buffer = reader.read(@byte)
        @minMaxReader = StringIO.new(buffer)
        bufferCount += 1
        $stderr.puts "~#{@byteRead}MB of file: #{file} processed" if(@byteRead > 0)
        @byteRead = @byteRead + ( @byte / 1000000 )
        orphan = nil if(bufferCount == 1)
        # Read buffer line by line
        @minMaxReader.each_line { |line|
          # Adding orphan line if any
          line = orphan + line if(!orphan.nil?)
          orphan = nil
          if(line =~ /\n$/)
            line.strip!
            next if (line.empty? or line.nil?)
            # Process block header
            if(line =~ /^fixedStep/)
              blockInsert += 1
              # Collect info for zoom level calculation, if needed
              if(@noZoom.nil?)
                blockHeader = line.split(/\s+/)
                spanZoom = nil
                blockHeader.each { |att|
                  attValue = att.split("=")
                  bpCoordZoom = attValue[1].to_i if(attValue[0] == 'start')
                  chrZoom = attValue[1] if(attValue[0] == 'chrom')
                  spanZoom = attValue[1].to_i if(attValue[0] == 'span')
                  stepZoom = attValue[1].to_i if(attValue[0] == 'step')
                  startZoom = attValue[1].to_i if(attValue[0] == 'start')
                }
                startCoordZoom = 0
                if(previousChrZoom.nil?)
                  zoomObj.getZoomLevelRecsByRid(@frefHash[chrZoom][1], @frefHash[chrZoom][0], @ftypeId)
                elsif(previousChrZoom != chrZoom)
                  zoomObj.writeBackZoomLevelRecords()
                  $stderr.puts "zoom levels updated for chr: #{previousChrZoom}"
                  zoomObj.clearZoomData
                  zoomObj = ZoomLevelUpdater.new(@dbu)
                  zoomObj.getZoomLevelRecsByRid(@frefHash[chrZoom][1], @frefHash[chrZoom][0], @ftypeId)
                end
                spanZoom = (spanZoom.nil? ? 1 : spanZoom)
                stepZoom = (stepZoom.nil? ? 1 : stepZoom)
                previousChrZoom = chrZoom
              end
              #Set block attributes
              setBlockValues(line)
              # Set span for the block
              if(@blockHash['span'].nil?)
                @span = @attrHashDb['gbTrackBpSpan']
              else
                @span = @blockHash['span'].to_i
              end
              @step = @blockHash['step'].to_i
              # Add rid info for chrom, if not already there
              @ridHash[@blockHash['chrom']] = @allFrefHash[@blockHash['chrom']] if(!@ridHash.has_key?(@blockHash['chrom']))
              # Set start if not set
              if(@start.nil?)
                @start = @blockHash['start'].to_i
                @currentChr = @chrom = @blockHash['chrom']
              else
                blockGap = (@blockHash['start'].to_i - @stop) - 1
              end
              # Skip this section for first block
              if(blockInsert > 1)
                # end current block and start a new one
                if(@currentChr != @blockHash['chrom'] or blockGap >= @maxBlockGap or @blockLength >= @maxBlockLength)
                  insertCount = makeNewBlock(addMore, noOfBytesToUse, cObjFixed, insertCount, fileFormat = "fixedStep") if(doNotAddBlock == 0)
                  addMore = 0
                  doNotAddBlock = 0
                  @start = @blockHash['start'].to_i
                  @startCount = 1
                # Either the new block needs to be merged if the blockGap is greater or equal to 0
                # or if the blockGap is smaller than 0 the block has the same start coordinate as the block that just ended. In this case start a new block
                elsif(blockGap < @maxBlockGap and @currentChr == @blockHash['chrom'] and @blockLength < @maxBlockLength)
                  # Merge blocks by filling gap with NULLs
                  if(doNotAddBlock == 0)
                    if(blockGap >= 0)
                      blockGap.times {
                        @dataArray << @nullScore
                      }
                      @blockLineCount += blockGap
                      @recordCount += blockGap
                      @blockLength += blockGap
                      @stop = @blockHash['start'].to_i - 1
                    # Make a new block since its not a good idea to merge overlapping blocks
                    else
                      insertCount = makeNewBlock(addMore, noOfBytesToUse, cObjFixed, insertCount, fileFormat = "fixedStep")
                      addMore = 0
                      doNotAddBlock = 0
                      @start = @blockHash['start'].to_i
                      @startCount = 1
                    end
                  else
                    doNotAddBlock = 0
                    @startCount = 1
                    @start = @blockHash['start'].to_i
                    addMore = 0
                  end
                end
              end
            # Process records/score for block
            # Data will be stored with span and step = 1 after being expanded span times
            elsif(line.valid?(:float))
              # Add 0 if required
              if(line =~ /^\./)
                line = "0#{line}"
              elsif(line =~ /\.$/)
                line = "#{line}0"
              end
              # Add info for the zoom level records
              if(@noZoom.nil?)
                if(startCoordZoom == 0)
                  bpCoordZoom = startZoom
                else
                  startZoom += stepZoom
                  bpCoordZoom = startZoom
                end
                zoomObj.addNewScoreForSpan(line.to_f, bpCoordZoom, spanZoom)
                startCoordZoom = 1
              end
              doNotAddBlock = 0
              tempScore = line.to_f
              @span.times {
                @dataArray << tempScore
              }
              @blockLineCount += @span
              @recordCount += @span
              @blockLength += @span
              @numScores += @span
              # Fill with Nans
              if(@step - @span > 0)
                gap = @step - @span
                gap.times {
                  @dataArray << @nullScore
                }
                @blockLineCount += gap
                @recordCount += gap
                @blockLength += gap
              end
              @stop = (@startCount == 1 ? @start + (@step - 1) : @stop + @step)
              # Updating track wide max and min
              @dataMax = tempScore if(tempScore > @dataMax)
              @dataMin = tempScore if(tempScore < @dataMin)
              @startCount = 2
              # Execute the C function if score array size reaches or passes the threshold, print binary values to file
              if(@dataArray.size >= @lowLimOfCBlock and @dataArray.size <= @cBlock)
                buff = cObjFixed.computeFixedStep(@dataArray, noOfBytesToUse, @cBuffer, @nullScore)
                tempBuff = @zDeflater.deflate(buff)
                addMore = addMore + tempBuff.size
                @zBuffer << tempBuff
                @dataArray.clear()
                @blockLineCount = 0
              elsif(@dataArray.size > @cBlock)
                # Make new c Buffer if the size of @dataArray crosses the memory allocated for the C Buffer
                newCBufferObj = BRL::Genboree::CreateBuffer.new()
                @cBuffer = newCBufferObj.createBuffer(noOfBytesToUse, @dataArray.size)
                buff = cObjFixed.computeFixedStep(@dataArray, noOfBytesToUse, @cBuffer, @nullScore)
                tempBuff = @zDeflater.deflate(buff)
                addMore = addMore + tempBuff.size
                @zBuffer << tempBuff
                @dataArray.clear()
                @blockLineCount = 0
              end
              # Write to file if @zBuffer is large enough
              if(@zBuffer.size >= @cBlock)
                @binaryWriter.print(@zBuffer)
                @zBuffer = ""
              end
              # start a new block if block length is greater or equal to @maxLength (--maxBlockLength)
              if(@blockLength >= @maxLength and !@minMaxReader.eof?)
                insertCount = makeNewBlock(addMore, noOfBytesToUse, cObjFixed, insertCount, fileFormat = "fixedStep")
                addMore = 0
                @start = @stop + 1
                doNotAddBlock = 1
                @startCount = 1
              end
            end
          else
            orphan = line
          end
        }
      end
      # write out the zoom level info for the last chromosome
      if(@noZoom.nil?)
        zoomObj.writeBackZoomLevelRecords()
        $stderr.puts "STAUS: zoom levels uploaded for chr: #{previousChrZoom}"
        zoomObj.clearZoomData()
      end
      # Calculate offset for the last record (if required)
      # This is done before calling the C function (if @dataArray not empty) since @preArraySize would change
      if(@offset.nil?)
        @offset = 0
      else
        @offset = @offset + @preArraySize
      end
      # Write to binary file if necessary
      if(!@dataArray.empty?)
        buff = cObjFixed.computeFixedStep(@dataArray, noOfBytesToUse, @cBuffer, @nullScore)
        tempBuff = @zDeflater.deflate(buff, Zlib::FINISH)
        @preArraySize = addMore + tempBuff.size
        @zBuffer << tempBuff
        @binaryWriter.print(@zBuffer)
        @zDeflater.reset()
      else
        tempBuff = @zDeflater.finish()
        @preArraySize = addMore + tempBuff.size
        @zBuffer << tempBuff
        @binaryWriter.print(@zBuffer)
        @zDeflater.reset()
      end
      # Insert any remaning records
      insertCount = updateDatabase(insertCount, flagBoolean = 0) if(!@blockLevelData.empty? or !@blockLevelData.nil?)
      # close reader
      reader.close
    }
    $stderr.puts "STATUS: Done processing fixed step file."
  end

  # Converts variable step data into fixed step format before processing
  # Checks if sorting is required or not by referring to the hash made
  # during validation.
  # Merges blocks into a single block (if conditions are met)
  # Use zlib to compress the binary stream for each block
  # Writes to Binary file and updates database
  # [+returns+] nil
  def processVariableStep()
    $stderr.puts "STATUS: processing variable step file..."
    @attrHashDb = Hash.new # hash for storing track attributes from database
    setAttrHashDb() # This method gets all the required track attributes from the database
    # Getting data for pre calculating multiplier for wiggle formula
    @dataMax = @attrHashDb['gbTrackDataMax'].to_f
    @dataMin = @attrHashDb['gbTrackDataMin'].to_f
    # Getting other variables for wiggle formula
    # These variables are passed to the C function to calculate binary scores
    recType = @attrHashDb["gbTrackRecordType"]
    noOfBytesToUse = 0
    if(recType == "floatScore")
      noOfBytesToUse = 4
    elsif(recType == "doubleScore")
      noOfBytesToUse = 8
    end
    # Allocate memory for storing binary data
    cObj1 = BRL::Genboree::CreateBuffer.new()
    cObjFixed = BRL::Genboree::ReadFixedStep.new()
    @cBuffer = cObj1.createBuffer(noOfBytesToUse, @cBlock)
    reader = nil
    # Go thorugh all wiggle files sequentially
    @filesToProcess.each { |file|
      # Check if sorting is required
      # Also check what kind of sorting is required, if sorting is required
      # No sorting
      if(@interSortHash[file] == :NO and @intraSortHash[file] == :NO)
        reader = BRL::Util::TextReader.new(file)
      # Only sort blocks relative to each other
      elsif(@interSortHash[file] == :YES and @intraSortHash[file] == :NO)
        $stderr.puts "    - Sorting file: #{file}.."
        tt = Time.now
        sortObj = BRL::Genboree::Helpers::Sorter.new(VARIABLESTEP, file)
        sortObj.sortFile()
        $stderr.puts "    - Sorting completed..."
        $stderr.puts "    - Time required for sorting: #{Time.now - tt}"
        reader = BRL::Util::TextReader.new(sortObj.sortedFileName())
      # Sort records within each block and then sort blocks relative to each other
      elsif(@intraSortHash[file] == :YES)
        # First call method that sorts records in each block
        sortObj = BRL::Genboree::Helpers::Sorter.new(VARIABLESTEPRECORDS, file)
        $stderr.puts "    - Sorting records within blocks for file: #{file}..."
        tt = Time.now
        sortObj.sortFile()
        sortedFilePath = sortObj.sortedFileName()
        # Now call method that will take the partially sorted file where only records of each block are sorted
        # and create a fully sorted file where the entire file is sorted
        sortObj = BRL::Genboree::Helpers::Sorter.new(VARIABLESTEP, sortedFilePath)
        $stderr.puts "    - Sorting blocks for file: #{file}..."
        sortObj.sortFile()
        $stderr.puts "    - Sorting completed..."
        $stderr.puts "    - Time required for sorting: #{Time.now - tt}"
        # Remove the partially sorted file
        system("rm -f #{sortedFilePath}")
        reader = BRL::Util::TextReader.new(sortObj.sortedFileName())
      end
      $stderr.puts "    - Writing Binary data and updating database..."
      # Initialize variables
      bufferCount = 0
      insertCount = 0
      fileLine = 0
      @dataArray = Array.new()
      @fileSize = File.size(file)
      blockInsert = 0
      @byteRead = 0
      @cBufferFlag = 0
      @cBufferPointer = 0
      addMore = 0
      blockGap = 0
      @numScores = 0
      # variables specific for adding zoom level info:
      previousChrZoom = nil
      chrZoom = nil
      startZoom = nil
      spanZoom = nil
      bpCoordZoom = nil
      stepZoom = nil
      startCoordZoom = 0
      doNotAddBlock = 0
      @nullScore = @fileMax + 1
      zoomObj = ZoomLevelUpdater.new(@dbu)
      # read till end of file
      while(!reader.eof?)
        # Read in specified buffer
        buffer = reader.read(@byte)
        @minMaxReader = StringIO.new(buffer)
        bufferCount += 1
        $stderr.puts "~#{@byteRead}MB of file: #{file} processed" if(@byteRead > 0)
        @byteRead = @byteRead + ( @byte / 1000000 )
        lineCount = 0
        orphan = nil if(bufferCount == 1)
        coordinate = 0
        @minMaxReader.each_line { |line|
          # Adding orphan line if any
          line = orphan + line if(!orphan.nil?)
          orphan = nil
          # Check if line has a newline character, process if it has
          if(line =~ /\n$/)
            line.strip!
            next if (line.empty? or line.nil?)
            # If block header encountered
            if(line =~ /^variableStep/)
              blockInsert += 1
              # Add info for zoom levels
              if(@noZoom.nil?)
                blockHeader = line.split(/\s+/)
                spanZoom = nil
                blockHeader.each { |att|
                  attValue = att.split("=")
                  chrZoom = attValue[1] if(attValue[0] == 'chrom')
                  spanZoom = attValue[1].to_i if(attValue[0] == 'span')
                }
                startCoordZoom = 0
                if(previousChrZoom.nil?)
                  zoomObj.getZoomLevelRecsByRid(@frefHash[chrZoom][1], @frefHash[chrZoom][0], @ftypeId)
                elsif(previousChrZoom != chrZoom)
                  zoomObj.writeBackZoomLevelRecords()
                  $stderr.puts "zoom levels updated for chr: #{previousChrZoom}"
                  zoomObj.clearZoomData
                  zoomObj = ZoomLevelUpdater.new(@dbu)
                  zoomObj.getZoomLevelRecsByRid(@frefHash[chrZoom][1], @frefHash[chrZoom][0], @ftypeId)
                end
                spanZoom = (spanZoom.nil? ? 1 : spanZoom)
                previousChrZoom = chrZoom
              end
              #Set block attributes
              setBlockValues(line)
              # Add rid info for chrom, if not already there
              @ridHash[@blockHash['chrom']] = @allFrefHash[@blockHash['chrom']] if(!@ridHash.has_key?(@blockHash['chrom']))
              # Set start if not set
              if(@start.nil?)
                @currentChr = @chrom = @blockHash['chrom']
                @startCount = 1
                @blockLineCount = @recordCount = @blockLength = 0
              else
                # Calculate the gap between the last coordinate of the last block
                # and the first coordinate of the current block
                positionInBuffer = @minMaxReader.pos()
                blockGapAndCoordinate = getBlockGapForVariableStep(@minMaxReader, file, bufferCount, nil)
                blockGap = blockGapAndCoordinate[0]
                coordinate = blockGapAndCoordinate[1]
                @minMaxReader.seek(positionInBuffer)
              end
              # Set span for the block
              if(@blockHash['span'].nil?)
                @span = @attrHashDb['gbTrackBpSpan']
              else
                @span = @blockHash['span'].to_i
              end
              # Skip this section for first block
              if(blockInsert > 1)
                # End current block and start new block if any of the conditions for starting a new block are met
                if(@currentChr != @blockHash['chrom'] or blockGap >= @maxBlockGap or @blockLength >= @maxBlockLength)
                  @stop += @span - 1
                  insertCount = makeNewBlock(addMore, noOfBytesToUse, cObjFixed, insertCount, fileFormat = "variableStep") if(doNotAddBlock == 0)
                  addMore = 0
                  @startCount = 1
                  doNotAddBlock = 0
                # Merge blocks by filling gap with NULLs
                elsif(blockGap < @maxBlockGap and @currentChr == @blockHash['chrom'] and @blockLength < @maxBlockLength)
                  # Check if the blockGap is greater or equal to 0
                  # If not start a new block since the new block overlaps with the old block
                  if(doNotAddBlock == 0)
                    if(blockGap >= 0)
                      blockGap.times {
                        @dataArray[@blockLineCount] = @nullScore
                        @blockLineCount += 1
                      }
                      @recordCount += blockGap
                      @blockLength += blockGap
                      @stop = coordinate - @span
                    else
                      @stop += @span - 1
                      insertCount = makeNewBlock(addMore, noOfBytesToUse, cObjFixed, insertCount, fileFormat = "variableStep")
                      @startCount = 1
                      addMore = 0
                      doNotAddBlock = 0
                    end
                  else
                    @startCount = 1
                    addMore = 0
                    doNotAddBlock = 0
                  end
                end
              end
            # Process scores/records for block
            elsif(line =~ /^(?:(\+|\-)?\d+)\s+(?:-|\+)?[0-9]*\.?[0-9]+(e(?:-|\+)?[0-9]+)?$/i)
              data = line.split(/\s+/)
              # Add 0 if required
              if(data[1] =~ /^\./)
                data[1] = "0#{data[1]}"
              elsif(data[1] =~ /\.$/)
                data[1] = "#{data[1]}0"
              end
              doNotAddBlock = 0
              zoomObj.addNewScoreForSpan(data[1].to_f, data[0].to_i, spanZoom) if(@noZoom.nil?) # for zoom level
              tempScore = data[1].to_f
              # For the first record of a new block if block changes with a block header
              if(@startCount == 1)
                @start = data[0].to_i
                # Expand the scores according to the span size
                @span.times {
                  @dataArray[@blockLineCount] = tempScore
                  @blockLineCount += 1
                }
                @recordCount += @span
                @blockLength += @span
                @numScores += @span
                @startCount += 1
              # For the rest of the the file
              else
                @calcStep = data[0].to_i - @stop
                # In case step > span
                if(@calcStep > @span)
                  # End block if step is larger than specified difference (between blocks) and start a new block
                  if(@calcStep >= (@span + @difference))
                    # Add database entry
                    @stop = @stop + (@span - 1)
                    insertCount = makeNewBlock(addMore, noOfBytesToUse, cObjFixed, insertCount, fileFormat = "variableStep")
                    addMore = 0
                    @span.times  {
                      @dataArray << tempScore
                    }
                    @blockLineCount += @span
                    @start = data[0].to_i
                    @recordCount += @span
                    @blockLength += @span
                    @numScores += @span
                  # Fill in gap with null values and expand score according to span size
                  else
                    @filler = @calcStep - @span
                    @filler.times {
                      @dataArray << @nullScore
                    }
                    @blockLineCount += @filler
                    @recordCount += @filler
                    @blockLength += @filler
                    @span.times {
                      @dataArray << tempScore
                    }
                    @blockLineCount += @span
                    @recordCount += @span
                    @blockLength += @span
                    @numScores += @span
                  end
                # For no gaps
                elsif(@calcStep == @span)
                  # Expand the scores according to the span size
                  @span.times {
                    @dataArray << tempScore
                  }
                  @blockLineCount += @span
                  @recordCount += @span
                  @blockLength += @span
                  @numScores += @span
                # if the step is 0. This means thae the previous coordinate is the same as the current one
                # in this case, start a new block since we cannot have a single coordinate with multiple scores
                # in a single block
                elsif(@calcStep == 0)
                  # Add database entry
                  @stop = @stop + (@span - 1)
                  insertCount = makeNewBlock(addMore, noOfBytesToUse, cObjFixed, insertCount, fileFormat = "variableStep")
                  addMore = 0
                  @start = data[0].to_i
                  @span.times  {
                    @dataArray << tempScore
                  }
                  @blockLineCount += @span
                  @recordCount += @span
                  @blockLength += @span
                  @numScores += @span
                end
              end
              @stop = data[0].to_i
              # Updating track wide max and min
              @dataMax = tempScore if(tempScore > @dataMax)
              @dataMin = tempScore if(tempScore < @dataMin)
              # Execute the C function if score array size reaches or passes the threshold, print binary values to file
              if(@dataArray.size >= @lowLimOfCBlock and @dataArray.size <= @cBlock)
                buff = cObjFixed.computeFixedStep(@dataArray, noOfBytesToUse, @cBuffer, @nullScore)
                tempBuff = @zDeflater.deflate(buff)
                addMore = addMore + tempBuff.size
                @zBuffer << tempBuff
                @dataArray.clear()
                @blockLineCount = 0
              elsif(@dataArray.size > @cBlock)
                # Make new c Buffer if the size of @dataArray crosses the memory allocated for the C Buffer
                newCBufferObj = BRL::Genboree::CreateBuffer.new()
                @cBuffer = newCBufferObj.createBuffer(noOfBytesToUse, @dataArray.size)
                buff = cObjFixed.computeFixedStep(@dataArray, noOfBytesToUse, @cBuffer, @nullScore)
                tempBuff = @zDeflater.deflate(buff)
                addMore = addMore + tempBuff.size
                @zBuffer << tempBuff
                @dataArray.clear()
                @blockLineCount = 0
              end
              # Write to file if @zBuffer is large enough
              if(@zBuffer.size >= @cBlock)
                @binaryWriter.print(@zBuffer)
                @zBuffer = ""
              end
               # start a new block if block length is greater or equal to @maxLength (--maxBlockLength)
              if(@blockLength >= @maxLength and !@minMaxReader.eof?)
                # Add database entry
                @stop = @stop + (@span - 1)
                insertCount = makeNewBlock(addMore, noOfBytesToUse, cObjFixed, insertCount, fileFormat = "variableStep")
                @startCount = 1
                addMore = 0
                doNotAddBlock = 1
              end
            end
          else
            orphan = line
          end
        }
      end
      # for zoom levels
      if(@noZoom.nil?)
        zoomObj.writeBackZoomLevelRecords()
        $stderr.puts "STATUS: zoom levels uploaded for chr: #{previousChrZoom}"
        zoomObj.clearZoomData()
      end
      # Calculate offset for the last record (if required)
      # This is done before calling the C function (if @dataArray not empty) since @preArraySize would change
      if(@offset.nil?)
        @offset = 0
      else
        @offset = @offset + @preArraySize
      end
      # Write to binary file if necessary
      if(!@dataArray.empty?)
        buff = cObjFixed.computeFixedStep(@dataArray, noOfBytesToUse, @cBuffer, @nullScore)
        tempBuff = @zDeflater.deflate(buff, Zlib::FINISH)
        @preArraySize = addMore + tempBuff.size
        @zBuffer << tempBuff
        @binaryWriter.print(@zBuffer)
        @zDeflater.reset()
      else
        tempBuff = @zDeflater.finish()
        @preArraySize = addMore + tempBuff.size
        @zBuffer << tempBuff
        @binaryWriter.print(@zBuffer)
        @zDeflater.reset()
      end
      # Insert any remaning records
      @stop = @stop + (@span - 1)
      insertCount = updateDatabase(insertCount, flagBoolean = 0) if(!@blockLevelData.empty? or !@blockLevelData.nil?)
      # close reader
      reader.close
    }
    $stderr.puts "STATUS: Done processing variable step file."
  end

  # ############################################################################
  # HELPER METHODS
  # ############################################################################
  # Displays error message and quits
  # [+message+]  error message
  # [+returns+] nil
  def displayErrorMsgAndExit(message)
    @emailMessage = "The process of validating and uploading your data was unsuccessful.\n  JobId: '#{@jobId.inspect}'\n  Track: '#{@trackName.inspect}'\n  Class: 'High Density Score Data'\n  Database: '#{@refseqName.inspect}'\n  Group: '#{@groupName.inspect}'\n\n" +
                      "Began at: #{@prgStartTime.inspect}.\nEnding at: #{Time.now}\n\n" +
                      "Error: #{message.inspect}.\n\n\n" +
                      "The Genboree Team"
    $stderr.puts "ERROR: #{message}"
    $stdout.puts message
    $stderr.puts "ERROR Backtrace:\n#{message.backtrace.join("\n")}" if(message.is_a?(Exception))
    sendEmail('[FAILED]') if(!@email.nil?)
    exit(14)
  end

  # Insert attribute name and value in the tables ftypeAttrNames and ftypeAttrValues respectively.
  # [+attrName+]  Name of the track atrribute
  # [+attrValue+]  Value of the track atrribute
  #  [+returns+] nil
  def insertAttrNameAndValue(attrName, attrValue)
    @dbu.insertFtypeAttrName(attrName)
    @dbu.insertFtypeAttrValue(attrValue)
  end

  # Get the id of the attribute name provided
  # [+attrName+]  Name of the track atrribute
  # [+returns+]  id of the attribute name
  def getAttrNameId(attrName)
    ftypeAttrName = @dbu.selectFtypeAttrNameByName(attrName)
    return ftypeAttrName
  end

  # Get the id of the attribute value provided
  # [+attrValue+]  Value of the track atrribute
  # [+returns+]  id of the attribute value
  def getAttrValueId(attrValue)
    ftypeAttrValue = @dbu.selectFtypeAttrValueByValue(attrValue)
    return ftypeAttrValue
  end

  # Insert ftypeId, attribute name and value in ftype2attributes table
  # Prints the attribute name and the corresponding value set for the track
  # [+ftypeId+]  ftypeId of the track for which the attribute name and value is going to be set
  # [+ftypeAttrName+]  attribute name id of the attribute name
  # [+ftypeAttrValue+]  attribute value id of the attribute value
  # [+returns+] nil
  def insertIntoFtype2AttributeTable(ftypeId, ftypeAttrName, ftypeAttrValue)
    @dbu.insertFtype2Attribute(ftypeId, ftypeAttrName.first['id'], ftypeAttrValue.first['id'])
    $stderr.puts "'#{ftypeAttrName.first['name']}': #{ftypeAttrValue.first['value']}  set for #{@trackName}"
  end

  # Gets attribute value using ftypeid and attr name id
  # [+attrName_id+]  id of the attribute name for which the value is required
  # [+ftypeId+] ftypeId of the track
  # [+returns+] array or array containing value correspoding to attribute name for the ftypeId
  def getAttrValueFromAttrName_id(attrName_id, ftypeId)
    value = @dbu.selectAttrValueByAttrNameIdAndFtypeId(ftypeId, attrName_id)
    return value
  end

  # reads untill the first non-blank line of the file
  # [+reader+] file reader
  # [+returns+'] the first non blank line from the reader's current position
  def readFirstNonBlank(reader)
    firstNonBlank = nil
    reader.each_line { |line|
      @lineCount += 1
      if(line =~ /\S/ and line !~ /^\s*#/)
        firstNonBlank = line.strip
        break
      end
    }
    return firstNonBlank
  end

  # ends current block and starts new block
  # [+addMore+] binary stream size (used to calculate 'bytelength')
  # [+noOfBytesToUse+] dataSpan: 4 or 8
  # [+cObjFixed+] an object of the C class to 'pack' scores (in hdhv.rb)
  # [+insertCount+] insert batch count
  # [+fileFormat+] fixedStep/variableStep
  # [+returns+] insertCount
  def makeNewBlock(addMore, noOfBytesToUse, cObjFixed, insertCount, fileFormat)
    @chrom = @currentChr
    if(@offset.nil?)
      @offset = 0
    else
      @offset = @offset + @preArraySize
    end
    # Call C function if dataArray not empty
    # If empty, just write the 'stop' bytes for the Z stream to indicate ending of the block
    if(!@dataArray.empty?)
      buff = cObjFixed.computeFixedStep(@dataArray, noOfBytesToUse, @cBuffer, @nullScore)
      # zip using zlib
      tempBuff =  @zDeflater.deflate(buff, Zlib::FINISH)
      @preArraySize = addMore + tempBuff.size
      @zBuffer << tempBuff
      @zDeflater.reset()
    else
      tempBuff = @zDeflater.finish
      @preArraySize = addMore + tempBuff.size
      @zBuffer << tempBuff
      @zDeflater.reset()
    end
    insertCount = updateDatabase(insertCount, flagBoolean = 1) # flagBoolean is used to indicate if its the last insert for the file
    @recordCount = 0
    @blockLength = 0
    @blockLineCount = 0
    @numScores = 0
    @dataArray.clear()
    @currentChr = @chrom = @blockHash['chrom']
    return insertCount
  end

  # validates the block header in the wiggle files
  # Keeps track if all the blocks of a chromosome are together
  # [+line+] line containing the block header
  # [+file+] name of the file containg the line
  # [+blockCount+] block number (used for generating the fileFormat if not provided through the command line)
  # [+returns+] string with errors
  def checkBlockHeader(line, file, blockCount)
    error = ""
    line.strip!
    blockHeader = line.split(/\s+/)
    data = line.split(/\s+/)
    @blockHash = Hash.new
    chrMatch = startMatch = 0
    # Break block header into attribute value pairs
    data.each { |attr|
      avp = attr.split("=")
      if(!@blockHash.has_key?(avp[0]))
        @blockHash[avp[0]] = avp[1]
      end
    }
    # Check if 'chrom' value pair exists in the block header.
    if(!@blockHash["chrom"].nil?)
      # Check if its a genuine chromosome
      raise ArgumentError, "Unrecognized entrypoint/chromosome: #{@blockHash['chrom']} at line #{@lineCount}. Please make sure if the entry point has already been uploaded and/or the format of the block header is in accordance to the UCSC standards.\n", caller if(!@allFrefHash.has_key?(@blockHash['chrom']))
      chrMatch += 1
    end
    # Check for the 'start' value pair in the block header (not present for variableStep)
    # If present, the value should be an integer
    if(!@blockHash['start'].nil?)
      start = @blockHash['start']
      raise ArgumentError, "start value either missing or not an integer value at line #{@lineCount} for file: #{file}", caller if(start !~ /^\d+$/)
      raise ArgumentError, "start value is 0 at line #{@lineCount} for file: #{file}", caller if(start.to_i == 0)
      startMatch +=1
    end
    # Make sure that 'span' and 'step' if present are integer values and non zero
    if(!@blockHash['span'].nil?)
      span = @blockHash['span']
      raise ArgumentError, "span either missing or not an integer value at line #{@lineCount} for file: #{file}", caller if(span !~ /^\d+$/)
      span = span.to_i
      raise ArgumentError, "span value is 0 at line #{@lineCount} for file: #{file}", caller if(span == 0)
      @originalSpan.push(span) if(!@checkSpanExist.has_key?(span))
      @checkSpanExist[span] = nil
    end
    if(!@blockHash['step'].nil?)
      step = @blockHash['step']
      raise ArgumentError, "step either missing or not an integer value at line #{@lineCount} for file: #{file}", caller if(step !~ /^\d+$/)
      raise ArgumentError, "step value is 0 at line #{@lineCount} for file: #{file}", caller if(step.to_i == 0)
    end
    # More checks for block header. Phew!
    # Only allow variable and fixed step block headers
    if(blockHeader[0] == "fixedStep" or blockHeader[0] == "variableStep")
      if(@fileFormat.nil?)
        @fileFormatFromFile = blockHeader[0] if(file == @filesToProcess[0] and blockCount == 1) # For the first block header in the file. This will set the file format for the track if --fileFormat argument is empty
        if(blockCount != 1)
          error << "file format mismatch at line #{@lineCount} for file: #{file}\n" if(@fileFormatFromFile != blockHeader[0])
        end
        if(@fileFormatFromFile == "fixedStep")
          error << "chrom or start value empty at line #{@lineCount} for file: #{file}\n" if(chrMatch == 0 or startMatch == 0)
          error << "step is smaller than span in block at line #{@lineCount} for file: #{file}\n" if((!@blockHash["span"].nil? and !@blockHash["step"].nil?) and (@blockHash["step"].to_i < @blockHash["span"].to_i))
        else
          error << "chrom value empty at line #{@lineCount} for file: #{file}\n" if(chrMatch == 0)
        end
      else
        if(@fileFormat == blockHeader[0])
          if(@fileFormat == "fixedStep")
            error << "chrom or start value empty at line #{@lineCount} for file: #{file}\n" if(chrMatch == 0 or startMatch == 0)
            error << "step is smaller than span in block at line #{@lineCount} for file: #{file}\n" if((!@blockHash["span"].nil? and !@blockHash["step"].nil?) and (@blockHash["step"].to_i < @blockHash["span"].to_i))
          else
            error << "chrom value empty at line #{@lineCount} for file: #{file}\n" if(chrMatch == 0)
          end
        else
          error << "file format mismatch encountered in file: #{file} at line #{@lineCount} \n"
        end
      end
    else
      error << "The block header line for #{file} is either incorrectly formatted or is either of 'bed' (not supported) format at line #{@lineCount}\n"
    end
    # Check if file requires sorting
    # This refers to checking if all the blocks for all the choromosomes are together and not randomly distributed in the wiggle file
    # This part applies to both variable step/fixed step files.
    if(@currentChr.nil?)
      @currentChr = @blockHash['chrom']
    else
      if(@currentChr != @blockHash['chrom'])
        if(@processedChr[file].has_key?(@blockHash['chrom']))
          @sortRequired = @interSort = :YES
          @processedChr[file][@currentChr] = nil
        else
          @processedChr[file][@currentChr] = nil
        end
        @currentChr = @blockHash['chrom']
      end
    end
    # Also check if starts are in increasing order (for fixedStep)
    # It is important that blocks for a chromosome are in increasing order with
    # respect to the coordinates so that we can merge blocks
    if(@blockStart.nil?)
      @blockStart = @blockHash['start'].to_i
      @chrCheck = @currentChr
    else
      if(@chrCheck == @currentChr)
        @sortRequired = @interSort = :YES if(@blockHash['start'].to_i < @blockStart)
        @blockStart = @blockHash['start'].to_i
      else
        @chrCheck = @currentChr
        @blockStart = @blockHash['start'].to_i
      end
    end
    return error
  end

  # Iterates through the file to check for invalid lines
  # If validating 'variableStep' file, also checks if sorting is required
  # Note that for fixed step files, sorting requirement is only checked
  # in the checkBlockHeader() method
  # [+reader+] File reader
  # [+file+] file name
  # [+returns+] string with error list (if found)
  def checkFileFormat(reader, file)
    @checkOrder = orphan =  nil
    errorCount =  0
    chrCheck = @currentChr
    @processedChr[file] = Hash.new
    startCoordOfBlock = nil # variable to check if blocks need to be sorted relative to each other for variableStep data
    while(!reader.eof?)
      buffRead = reader.read(@byte)
      buffReadIO = StringIO.new(buffRead)
      buffReadIO.each_line { |line|
        line = orphan + line if(!orphan.nil?)
        orphan = nil
        if(line =~ /\n$/)
          @lineCount += 1
          line.strip!
          next if (line.empty? or line.nil?)
          # Check for block header lines
          if (line =~ /^variableStep/ or line =~ /^fixedStep/)
            raise ArgumentError, "Block header is not followed by any records/scores at line number: #{@lineCount} in file: #{file}. Possible Empty Block?", caller if(@checkOrder.nil?)
            @errorFile << checkBlockHeader(line, file, 0) # Validate block
            errorCount += 1 if(!@errorFile.empty?)
            @checkOrder = nil
            startCoordCheck = 0
          # Check for bad format
          # Cannot allow just anything to be processed
          # Throw exception if line is not any of:
          # 1) A commented line
          # 2) An empty line
          # 3) Records following a block header (fixed step/ variable step)
          elsif(line !~ /^#/ and line !~ /^\s*$/ and !line.valid?(:float) and line !~ /^(?:(\+|\-)?\d+)\s+(?:-|\+)?[0-9]*\.?[0-9]+(e(?:-|\+)?[0-9]+)?$/i and line !~ /^track/)
            @errorFile << "Bad format at line #{@lineCount}: #{line}\n"
            errorCount += 1
          # Regular expression for a fixed step record
          elsif(line.valid?(:float) and @temporaryFileFormat == 'fixedStep')
            @checkOrder = line
            score = line.to_f
            if(@fileMax.nil?)
              @fileMax = score
            else
              @fileMax = @fileMax >= score ? @fileMax : score
            end
          # Regular expression for a variable step record
          elsif(line =~ /^(?:(\+|\-)?\d+)\s+(?:-|\+)?[0-9]*\.?[0-9]+(e(?:-|\+)?[0-9]+)?$/i and @temporaryFileFormat == 'variableStep')
            data = line.split(/\s+/)
            # Check if records for variable step data are in order.
            # It is unwise to sort just the blocks relative to each other based on the start coordinate of
            # the blocks since the first coordinate may not be the REAL first coordinate of the block
            if(@checkOrder.nil?)
              @checkOrder = data[0].to_i
              # This part checks if the blocks just need to be sorted among themselves
              # If only the first coordinate of a block is smaller than the first coordinate of the previous
              # block and the records in both the blocks are sorted, then we just need to rearrange the blocks similar
              # to sorting fixed step files. Another case where we can get away with only rearranging blocks is if the
              # blocks of a chromosome are not together but the records of ALL blocks are sorted. The arrangement of the
              # chromosomes is check in checkBlockHeader(). The bottome line is that in order for this approach to work,
              # the records in the block MUST be sorted so that we can trust the first coordinate of each block to
              # be the start coordinate of the block
              if(!startCoordOfBlock.nil?)
                # Check if its the same chromosome as before
                if(chrCheck == @currentChr)
                  @sortRequired = @interSort = :YES if(@checkOrder < startCoordOfBlock) # This means that the blocks need to be sorted among themselves
                else
                  chrCheck = @currentChr
                end
              end
              startCoordOfBlock = @checkOrder
            # This part checks if its necessary to sort the records inside a block
            # Knowing what kind of sorting is required/not required will save a lot of time!
            else
              if(data[0].to_i >= @checkOrder)
                @checkOrder = data[0].to_i
              else
                @sortRequired = @intraSort = :YES # This means that the records within blocks need to be sorted
                @checkOrder = data[0].to_i
              end
            end
            score = data[1].to_f
            if(@fileMax.nil?)
              @fileMax = score
            else
              @fileMax = @fileMax >= score ? @fileMax : score
            end
          elsif((line.valid?(:float) and @temporaryFileFormat == 'variableStep') or (line =~ /^(?:(\+|\-)?\d+)\s+(?:-|\+)?[0-9]*\.?[0-9]+(e(?:-|\+)?[0-9]+)?$/i and @temporaryFileFormat == 'fixedStep'))
            raise ArgumentError, "Bad format at line: #{@lineCount}. Incorrect record type: #{line} for file format: #{@temporaryFileFormat} ?", caller
          end
          # If error count threshold is met, stop doing futher validation in the file.
          # and throw exception. Send email if required
          raise ArgumentError, "Too many errors in file : #{File.basename(file)}. Cannot proceed\nError List:\n#{@errorFile}", caller if(errorCount == 20)
        else
          orphan = line
        end
      }
    end
    @processedChr[file][@currentChr] = nil
    return @errorFile
  end

  # Reads block header and stores attributes as an hash
  # [+line+] line containing the block header
  #  [+returns+] nil
  def setBlockValues(line)
    line.strip!
    data = line.split(/\s+/)
    @blockHash = Hash.new{}
    chrMatch = 0; startMatch = 0
    # Checking if block header contains coordinates
    data.each { |attr|
      avp = attr.split("=")
      if(!@blockHash.has_key?(avp[0]))
        @blockHash[avp[0]] = avp[1]
      end
    }
  end

  # Sets the block attributes: span, step, chrom and start (for fixedStep)
  #  [+returns+] nil
  def setSpanAndStepAndChromAndStart()
    if(@blockHash.has_key?("span"))
      @span = @blockHash["span"].to_i
    else
      @span = @attrHashDb["gbTrackBpSpan"]
      @span = @span[0].to_i
    end
    # Setting 'step'
    if(@blockHash.has_key?("step"))
      @step = @blockHash["step"].to_i
    else
      @step = @attrHashDb["gbTrackBpStep"]
      @step = @step[0].to_i
    end
    #Setting Chrom and start
    @chrom = @blockHash["chrom"]
    @start = @blockHash["start"].to_i
    # Add rid info for chrom, if not already there
    if(!@ridHash.has_key?(@chrom))
      fref = @dbu.selectFrefsByName(@chrom, exactMatch=true)
      @ridHash[@chrom] = fref.first['rid']
    end
  end

  # Sets span, chrom from block header (for variableStep)
  # [+returns+]  span of the block
  def setSpanAndChrom()
    blockSpan = nil
    if(@blockHash.has_key?("span"))
      @span = @blockHash["span"].to_i
      blockSpan = @span
    else
      @span = @attrHashDb["gbTrackBpSpan"]
      blockSpan = nil
    end
    #Setting Chrom
    @chrom = @blockHash["chrom"]
    # Add rid info for chrom, if not already there
    if(!@ridHash.has_key?(@chrom))
      fref = @dbu.selectFrefsByName(@chrom, exactMatch=true)
      @ridHash[@chrom] = fref.first['rid']
    end
    return blockSpan
  end

  # Make class 'High Density Score Data' if not present
  # Adds thr track to the class
  # [+ftypeid+] ftypeid of the track
  # [+returns+] nil
  def insertIntoGclassAndFtype2GClass(ftypeid)
    # Make class for High density High Volume data if it does not exist
    @dbu.insertGclassRecord('High Density Score Data')
    # Get gid
    gid = @dbu.selectGclassByGclass('High Density Score Data')
    gid = gid.first['gid']
    # Insert into 'ftype2gclass'
    @dbu.insertFtype2Gclass(ftypeid, gid)
  end

  # Sets hash which contains track attributes recieved from database
  # [+returns+] nil
  def setAttrHashDb()
    @attributeHash.each_key { |key|
      attrName_id = getAttrNameId(key)
      if(!attrName_id.nil? and !attrName_id.empty?)
        value = @dbu.selectFtypeAttrValueByFtypeIdAndAttributeNameId(@ftypeId, attrName_id.first['id'])
        value = value.first['value']
        if(value.valid?(:float))
          if(key == "gbTrackBpSpan" or key == "gbTrackBpStep" or key == "gbTrackDataSpan" or key == "gbTrackPxHeight")
            value = value.to_i
          else
            value = value.to_f
            # Add 0 if required
            if(value =~ /^\./)
              value = "0#{value}"
            elsif(value =~ /\.$/)
              value = "#{value}0"
            end
          end
        else
          value = value
        end
        @attrHashDb[key] = value
      end
    }
  end

  #  Collects records for blockLevelDataInfo table.
  #  The records are inserted in the database 4000 at a time
  #  [+insertCount+]  counter indicating no of inserts
  #  [+flag+]  indicates if its the last chunk of insert
  #  [+returns+] nil
  def updateDatabase(insertCount, flag)
    # For first call of the method, count no of annotations for the track
    if(insertCount == 0)
      ftypeCount = @dbu.selectFtypeCountByFtypeid(@ftypeId)
      numberOfAnnotations = nil
      numberOfAnnotations = ftypeCount[0]['numberOfAnnotations'] if(!ftypeCount.nil? and !ftypeCount.empty?)
      if(!numberOfAnnotations.nil?)
        @annosCount = numberOfAnnotations.to_i + @numScores
      else
        @annosCount = @numScores
        @dbu.insertFtypeCount(@ftypeId, 0) # Initialize ftypeCount with 0
      end
    else
      @annosCount += @numScores
    end
    rid = @ridHash[@chrom]
    binner = BRL::SQL::Binning.new
    fbin = binner.bin(BRL::SQL::MIN_BIN, @start, @stop)
    # Make array of array blockLevelDataInfo inserts
    @blockLevelData[@dbCount] = [@outputFile, @offset, @preArraySize, @recordCount, rid, @ftypeId, @start, @stop, fbin, BLOCKSPAN, BLOCKSTEP, SCALE, LOWLIMIT]
    @dbCount += 1
    # If row count hits 4000, insert in database
    if(@dbCount == BLOCKSIZE)
      @dbu.insertBlockLevelDataInfoRecords(@blockLevelData, BLOCKSIZE)
      @dbu.updateNumberOfAnnotationsByFtypeid(@ftypeId, @annosCount)
      @blockLevelData.clear()
      @dbCount = 0
    end
    # For the last chunk of inserts
    if(flag == 0 and !@blockLevelData.empty?)
      @dbu.insertBlockLevelDataInfoRecords(@blockLevelData, @blockLevelData.size)
      @dbu.updateNumberOfAnnotationsByFtypeid(@ftypeId, @annosCount)
    end
    insertCount += 1;
    return insertCount
  end

  # Calculates the gap between two blocks for variable step data
  # This is the difference between the first coordinate of the current block and the last coordinate of the previous block
  # Note that span is added to the last coordinate of the last block to get the exact number of 'missing' bases between the block
  # blockGap = firstCoordCurrBlock - (lastCoordLastBlock + (span -1))
  # [+reader+] String IO object
  # [+file+] file which is being preocessed
  # [+bufferCount+] No of buffers read from file
  # [+orphan+] line without new line character
  # [+returns+] an array with blockGap and the first coordinate of the current block
  def getBlockGapForVariableStep(reader, file, bufferCount, orphan)
    blockGap = coordinate = nil
    # read till end of file
    while(!reader.eof?)
      buffer = reader.read(@byte)
      buffIO = StringIO.new(buffer)
      buffIO.each_line { |line|
        # Check if line is complete (has newline)
        if(line =~ /\n$/)
          line.strip!
          line = orphan + line if(!orphan.nil?)
          orphan = nil
          if(line =~ /^(?:(\+|\-)?\d+)\s+(?:-|\+)?[0-9]*\.?[0-9]+(e(?:-|\+)?[0-9]+)?$/i)
            data = line.split(/\s+/)
            coordinate = data[0].to_i
            blockGap = coordinate - (@stop + @span)
            break()
          end
        else
          orphan = line
        end
      }
      buffIO.close()
    end
    if(blockGap.nil?)
      newReader =  BRL::Util::TextReader.new(file)
      bufferCount.times {
        newReader.read(@byte)
      }
      orphan = '' if(orphan.nil?)
      blockGapAndcoordinate = getBlockGapForVariableStep(newReader, nil, nil, orphan) if(!newReader.eof?)
      blockGap = blockGapAndcoordinate[0]
      coordinate = blockGapAndcoordinate[1]
      newReader.close()
    end
    return [ blockGap, coordinate ]
  end

  # sends email to recipients about the job status
  # [+returns+] no return value
  def sendEmail(status)
    genbConf = ENV['GENB_CONFIG']
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    emailer = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)
    emailer.addRecipient(@email)
    emailer.addRecipient(genbConfig.gbAdminEmail)
    emailer.setHeaders(genbConfig.gbFromAddress, @email, "GENBOREE NOTICE: WIG upload job status. #{status}")
    emailer.setMailFrom(genbConfig.gbFromAddress)
    emailer.addHeader("Bcc: #{genbConfig.gbBccAddress}")
    @emailMessage = "There was an unknown problem generating the file." if(@emailMessage.empty?)
    emailer.setBody(@emailMessage)
    emailer.send()
  end

  
  # validates color (r, g, b) value in a wiggle file track header and returns hex color value
  # suitable for use with Genboree
  # Also builds up the @color instance variable
  # [+color+] color value in decimal (r, g, b)
  # [+returns+] hex color value
  def generateHexColor(color)
    raise "Incorrect format for rgb" if(color !~ /^\d+,\d+,\d+$/)
    return "##{color.split(/,/).map { |xx| ("%.2X" % xx.to_i) }.join('')}"
  end

  # Scans track header for track attributes
  # [+returns+] nil
  def scanTrackAttributes
    # Get track attributes from track header
    @color = generateHexColor(@trackHash['color']) if(!@trackHash['color'].nil?)
    @altColor = generateHexColor(@trackHash['altColor']) if(!@trackHash['altColor'].nil?)
    @gbTrackWindowingMethod = (@trackHash['windowingFunction'] ? @trackHash['windowingFunction'] : 'MAX')
    # Make sure the value of @gbTrackWindowingMethod makes sense for us
    if(@gbTrackWindowingMethod == 'maximum' or @gbTrackWindowingMethod == 'MAX')
      @gbTrackWindowingMethod = 'MAX'
    elsif(@gbTrackWindowingMethod == 'minimum')
      @gbTrackWindowingMethod = 'MIN'
    elsif(@gbTrackWindowingMethod == 'mean')
      @gbTrackWindowingMethod = 'AVG'
    else
      raise ArgumentError, "Unsupported windowing method type: #{@gbTrackWindowingMethod}", caller
    end
    @visibility = (@trackHash['visibility'] ? @trackHash['visibility'] : nil)
    tempViewLimits = (@trackHash['viewLimits'] ? @trackHash['viewLimits'] : nil)
    if(!tempViewLimits.nil?)
      limits = tempViewLimits.split(":")
      raise ArgumentError, "Track Header has incorrectly formatted 'viewLimits' attribute: #{tempViewLimits}", caller if(limits.size != 2)
      @viewLimits = limits
    else
      @viewLimits = nil
    end
    @description = (@trackHash['description'] ? @trackHash['description'] : nil)
    tempAutoScale = (@trackHash['autoScale'] ? @trackHash['autoScale'] : nil)
    if(!tempAutoScale.nil?)
      raise ArgumentError, "Unsupported autoScale format: #{tempAutoScale}", caller if(tempAutoScale != 'on' and tempAutoScale != 'off')
      @autoScale = tempAutoScale
    else
      @autoScale = 'on'
    end
    heightPixels = (@trackHash['maxHeightPixels'] ? @trackHash['maxHeightPixels'] : nil)
    if(!heightPixels.nil?)
      pixelArray = heightPixels.split(":")
      raise ArgumentError, "Unsupported maxHeightPixels: #{heightPixels}", caller if(pixelArray.size != 3)
      @pixelHeight = pixelArray[0].to_i
    else
      @pixelHeight = PXHEIGHT
    end
  end
end

class RunScript

  VERSION_NUMBER="2.0"
  DEFAULTUSAGEINFO="

  Author: Sameer Paithankar

  Description: This program is for processing wiggle ('fixedStep' and 'variableStep') data. The wiggle file(s) is processed and a binary file is created which
  along with the records in the 'blockLevelDataInfo' table (which are also inserted when the program is run), can be used to recreate the wiggle data. Due to the limitations of the genboree genome browser,
  'variableStep' wiggle data is always stored as 'fixedStep' format.

  Notes:
  => bed format not supported. Supports: fixedStep and variableStep
  => for multiple input files, separate file names by commas without spaces: file1,file2,file3,.....
  => If '--trackName' is not present, the track from the first track header encountered in the first of the input files will be used, this track will be used for ALL the data in ALL the input files

    -i  --inputFiles => comma-separated list of wiggle file paths (required)
    -g  --groupName => name or id of the group whose database the data will be uploaded to (required)
    -u  --userName => genboree user name or user id of the person running the program (Note: private tracks may or may not be accessible depending on track access settings) (required)
    -d  --databaseName => full name of the database or refseqid to which the data will be uploaded (required)
    -t  --trackName =>  argument with the Genboree track name to use for the data to be uploaded (optional but highly recommended)
    -f  --fileFormat  => indicate how the .wig file(s) should be processed (optional. If not present, the program will determine file format from the input file) (optional)
    -o  --useLog =>  If this flag is present, the tool stores a track attribute gbTrackUseLog=true; else it stores gbTrackUseLog=false (optional)
    -m  --dataMax => if present, stores the value of this argument in the track attribute gbTrackDataMax (optional)
                    Note that the program will still calculate 'max' from the wiggle file(s) and update the database accordingly
    -n  --dataMin => if present, stores the value of this argument in the track attribute gbTrackDataMin (optional)
                    Note that the program will still calculate 'min' from the wiggle file(s) and update the database accordingly
    -w  --gbTrackWindowingMethod =>  Possible values are 'AVG', 'MIN', 'MAX'. For storing this value in the track attribute gbTrackWindowingMethod (default: 'MAX')
    -z  --recordType => Indicates one of several fixed binary record types for the data file (default: floatScore)(optional)
                        (Currently supported: 'doubleScore', 'floatScore')
    -b  --byte => no of bytes (in Megs) to process at a time (default: 32 MB)
    -j  --dir => path to dir where the bin file will be stored or read(optional)
    -q  --diff => Used only for variableStep data. Creates a new block if the difference between two successive records is greater than this value (default: 20000)
    -k  --cBlock => number of records to be written to the binary file at a time. (default: 1000000)
    -V  --noValidation => skips validation (--trackName and --fileFormat need to be provided with this flag) (default: performs validation)
                          It is important that the file should already be sorted if validation is to be skipped
    -I  --maxInterBlockGap => maximum gap allowed between blocks. If gap >= maxInterBlockGap, start new block and do not merge (default: 25000)
    -L  --maxMergedBlockLength => merge blocks upto this length. Start new block when length crosses this value (default: 1MBp)
                              Note that the length can be crossed while processing data for one block. If the length is crossed while
                              processing data for a block, the next block will not be merged.
    -P  --maxRelativeChangeInPrecision => merge blocks if precision for a block relative to the previous block is smaller or equal to this value (default: 0.1)
          precisionOfBlock = (blockMax - blockMin) / denom
          merge blocks if absoluteValue(precisionOfBlock - precisionOfPreviousBlock) / precisionOfPreviousBlock <= maxRelativeChangeInPrecision
    -M  --maxBlockLength => maximum length of a single block. (default: 1 MBp) Note that the length can go slightly over 1 MBp if the span for a single record crosses 1 MBp
                            However, the next record in the file will end up as part of the next block in the database
    -E  --email => recepient email address for sending back email when the job is done or an errror log (default: If not provided no email will be sent)
    -F  --importLockFalse => allow any number of import wiggle processes to run
    -Z  --noZoom => flag for not adding zoom level information for the track (default: on)
    -K  --dbrcKey => key from the dbrc file of the server (provide when launching the program on the cluster)
    -A  --attributesPresent => Used only for empty tracks. Will not attempt to set track attributes if flag present.
    -J  --jobId => (optional)
    -B  --putBinFile => Use ApiCaller to copy bin file to server
    -H  --host => name of the host to which the bin file will be copied over
    -G  --skipGz => skip the gzipping of the original uncompressed file
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
    methodName="performImportWig"
    optsArray=[
      ['--inputFiles','-i',GetoptLong::REQUIRED_ARGUMENT],
      ['--groupName','-g',GetoptLong::REQUIRED_ARGUMENT],
      ['--userName','-u',GetoptLong::REQUIRED_ARGUMENT],
      ['--databaseName','-d',GetoptLong::REQUIRED_ARGUMENT],
      ['--trackName','-t',GetoptLong::OPTIONAL_ARGUMENT],
      ['--fileFormat','-f',GetoptLong::OPTIONAL_ARGUMENT],
      ['--useLog','-o',GetoptLong::OPTIONAL_ARGUMENT],
      ['--dataMax','-m',GetoptLong::OPTIONAL_ARGUMENT],
      ['--dataMin','-n',GetoptLong::OPTIONAL_ARGUMENT],
      ['--gbTrackWindowingMethod','-w',GetoptLong::OPTIONAL_ARGUMENT],
      ['--recordType','-z',GetoptLong::OPTIONAL_ARGUMENT],
      ['--byte','-b',GetoptLong::OPTIONAL_ARGUMENT],
      ['--dir','-j',GetoptLong::OPTIONAL_ARGUMENT],
      ['--diff','-q',GetoptLong::OPTIONAL_ARGUMENT],
      ['--cBlock','-k',GetoptLong::OPTIONAL_ARGUMENT],
      ['--noValidation','-V',GetoptLong::OPTIONAL_ARGUMENT],
      ['--maxInterBlockGap','-I',GetoptLong::OPTIONAL_ARGUMENT],
      ['--maxMergedBlockLength','-L',GetoptLong::OPTIONAL_ARGUMENT],
      ['--maxRelativeChangeInPrecision','-P',GetoptLong::OPTIONAL_ARGUMENT],
      ['--maxBlockLength','-M',GetoptLong::OPTIONAL_ARGUMENT],
      ['--email','-E',GetoptLong::OPTIONAL_ARGUMENT],
      ['--importLockFalse','-F',GetoptLong::OPTIONAL_ARGUMENT],
      ['--noZoom','-Z',GetoptLong::OPTIONAL_ARGUMENT],
      ['--dbrcKey','-K',GetoptLong::OPTIONAL_ARGUMENT],
      ['--attributesPresent','-A',GetoptLong::OPTIONAL_ARGUMENT],
      ['--jobId','-J',GetoptLong::OPTIONAL_ARGUMENT],
      ['--putBinFile','-B',GetoptLong::OPTIONAL_ARGUMENT],
      ['--host','-H',GetoptLong::OPTIONAL_ARGUMENT],
      ['--skipGz','-G',GetoptLong::OPTIONAL_ARGUMENT],
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

  def self.performImportWig(optsHash)
    ImportWig.new(optsHash)
  end

end

# Parse Args from the command line
optsHash = RunScript.parseArgs()
# The class method will instantiate and run the main wrapper class
RunScript.performImportWig(optsHash)