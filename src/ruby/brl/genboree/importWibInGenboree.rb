#!/usr/bin/env ruby


# Loading libraries and require classes
require 'rack'
require 'cgi'
require 'getoptlong'
require 'md5'
require 'zlib'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/db/dbrc'
require 'pp'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/genboreeUtil'
require 'brl/sql/binning'
require 'brl/genboree/graphics/zoomLevelUpdater'

# Main class with all methods. This class initializes all required variables
# and objects, validates the wig (txt) file, moves the wib file to the right
# location and inserts records into 'blockLevelDataInfo'
class ImportWib

  attr_accessor :wigReader, :wibReader, :track, :group, :database, :user, :byte, :dbu
  attr_accessor :groupId, :groupName, :dir, :useLog, :windowingMethod, :dataType, :wibFile
  attr_accessor :attributeHash, :dataMax, :dataMin, :dbCount, :blockData, :outputFile, :ridHash
  attr_accessor :annosCount, :zipWriter, :zDeflater, :zipOffset, :binName, :compressedWibData
  attr_accessor :numRecords, :sizeOfCompressedWibData, :appendToTrackBoolean, :originalSpan
  attr_accessor :noZoom, :frefHash, :allFrefHash
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  # Some of these constants are used to set the track wide attributes for each track.
  BLOCKSIZE = 4000 # Number of records to insert at a time
  INITDATAMAX = -10000000 # Initial value for data max (this value is replaced by scores from the file)
  INITDATAMIN = 10000000 # Initial value for data min (this value is replaced by scores from the file)
  DATASPAN = 1 # No of bytes per record
  PXHEIGHT = 53 # Set pixel height to 53
  BPSPAN = 1 # block wide span fixed to 1
  BPSTEP = 1 # block wide step fixed to 1
  DENOMINATOR = 127 # denominator for wiggle formula
  GBFORMULA = 'wiggle' # type of formula
  # ############################################################################
  # METHODS
  # ############################################################################
  # CONSTRUCTOR. Checks if wig and wib files exist. Also checks if database
  # provided belongs to group provided. Creates dbUtil object.
  #[+optsHash+] hash with command line arguments
  # [+returns+] no return value
  def initialize(optsHash)
    @group = optsHash['--group']
    @database = optsHash['--database']
    displayErrorMsgAndExit("--byte cannot be larger than 64 or smaller than 1") if(!optsHash['--byte'].nil? and (optsHash['--byte'].to_i < 1 or optsHash['--byte'].to_i > 64))
    @byte = (optsHash['--byte'] ? optsHash['--byte'].to_i * 1000000 : 32000000)
    @useLog = (optsHash['--gbTrackUseLog'] ? true : false)
    @windowingMethod = (optsHash['--gbTrackWindowingMethod'] ? optsHash['--gbTrackWindowingMethod'] : 'MAX')
    @dataType = (optsHash['--gbTrackDataType'] ? optsHash['--gbTrackDataType'] : 'blockBased')
    @noZoom = (optsHash['--noZoom'] ? 1 : nil)
    # Check if 'wig' and 'wib' files exist
    @wigReader = Hash.new
    @wibReader = Hash.new
    @frefHash = Hash.new
    @allFrefHash = Hash.new
    @zDeflater = Zlib::Deflate.new()
    @compressedWibData = ""
    @numRecords = @sizeOfCompressedWibData = nil
    @originalSpan = Hash.new
    wigFiles = nil
    wibFiles = nil
    wigFiles = optsHash['--wig'].split(",")
    wigFiles.size.times { |ii|
      begin
        @wigReader[wigFiles[ii]] = BRL::Util::TextReader.new(wigFiles[ii])
      rescue => err
        $stderr.puts "ERROR: file #{wigFiles[ii]} missing."
        exit(14)
      end
    }
    wibFiles = optsHash['--wib'].split(",")
    wibFiles.size.times { |ii|
      if(!File.exist?(wibFiles[ii]))
        displayErrorMsgAndExit("'#{wibFiles[ii]}' does not exist.")
      else
        @wibReader[wibFiles[ii]] = BRL::Util::TextReader.new(wibFiles[ii])
      end
    }
    # Validate track name
    if(optsHash['--track'] !~ /:/)
      displayErrorMsgAndExit("Track name does not have ':'")
    else
      @track = optsHash['--track']
    end
    # Making dbUtil object for the local database
    gc = BRL::Genboree::GenboreeConfig.load
    @dbu= BRL::Genboree::DBUtil.new("#{gc.dbrcKey}", nil, nil)

    # Check whether loginName or loginId provided is valid
    # get one from the other
    userName = optsHash['--user'].strip
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
    databaseName = optsHash['--database']
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

    # Get group info
    @group.strip!
    if(@group =~ /^\d+$/)
      @groupId = @group.to_i
      # Get groupName
      groupRecs = @dbu.selectGroupById(@groupId)
      displayErrorMsgAndExit("Group with groupId: #{@groupId} does not exist") if(groupRecs.nil? or groupRecs.empty?)
      @groupName = groupRecs.first['groupName']
    else # groupName command line arg is an actual group name
      # Get groupId
      @groupName = @group
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
    allFrefRecords = @dbu.selectAllRefNames()
    allFrefRecords.each { |record|
      @allFrefHash[record['refname']] = record['rid'].to_i
      @frefHash[record['refname']] = [record['rlength'].to_i, record['rid'].to_i] if(!@frefHash.has_key?(record['refName']))
    }
    dirFromFmeta = @dbu.selectValueFmeta('RID_SEQUENCE_DIR')
    if(optsHash['--dir'])
      @dir = optsHash['--dir']
    else
      @dir = dirFromFmeta
    end

    # Validate wig files if '--noValidation' not provided
    if(optsHash['--noValidation'].nil?)
      error = validateWig()
      if(!error.empty?)
        $stderr.puts "Error: Following errors were found:"
        $stderr.puts error
        exit(14)
      else
        $stdout.puts "Validation done. No errors!"
      end
    else
      $stdout.puts "Skipping Validation"
    end

    # Set track attributes, move wib file(s)
    processWig()
    #Read text file(s) corresponding to wib files. Insert records into 'blockLevelDataInfo'
    readWig()
    #update track wide dataMax and dataMin
    #Insert new values for min and max
    @dbu.insertFtypeAttrValue(@dataMax); @dbu.insertFtypeAttrValue(@dataMin)

    # get ids for the values
    dataMinValId = getAttrValueId(@dataMin); dataMaxValId = getAttrValueId(@dataMax)

    # get ids for the attr names
    dataMinNameId = getAttrNameId("gbTrackDataMin"); dataMaxNameId = getAttrNameId("gbTrackDataMax")
    @dbu.updateFtype2AttributeForFtypeAndAttrName(@ftypeId, dataMinNameId.first['id'], dataMinValId.first['id'])
    @dbu.updateFtype2AttributeForFtypeAndAttrName(@ftypeId, dataMaxNameId.first['id'], dataMaxValId.first['id'])
    if(@appendToTrackBoolean == 0)
      userMinNameId = getAttrNameId("gbTrackUserMin"); userMaxNameId = getAttrNameId("gbTrackUserMax")
      @dbu.updateFtype2AttributeForFtypeAndAttrName(@ftypeId, userMinNameId.first['id'], dataMinValId.first['id'])
      @dbu.updateFtype2AttributeForFtypeAndAttrName(@ftypeId, userMaxNameId.first['id'], dataMaxValId.first['id'])
      # Add original span
      # Insert 'gbTrackOriginalSpan'
      @dbu.insertFtypeAttrName('gbTrackOriginalSpan')
      # Insert all the original spans from the wiggle file
      @originalSpan[1] = nil if(@originalSpan.empty?)
      spanString = @originalSpan.keys.join(",")
      @dbu.insertFtypeAttrValue(spanString)
      # get the attribute name id for 'gbTrackOriginalSpan'
      originalSpanNameId = getAttrNameId('gbTrackOriginalSpan')
      # Add a record into ftype2attributes for each of the spans
      spanId = getAttrValueId(spanString)
      insertIntoFtype2AttributeTable(@ftypeId, originalSpanNameId, spanId)
    else
      # Insert all the original spans from the wiggle file
      @originalSpan[1] = nil if(@originalSpan.empty?)
      originalSpanNameId = getAttrNameId('gbTrackOriginalSpan')
      spanString = ""
      spanString = @dbu.selectFtypeAttrValueByFtypeIdAndAttributeNameId(@ftypeId, originalSpanNameId.first['id'])
      if(!spanString.empty?)
        spanString = spanString.first['value']
        spans = spanString.split(",")
        @originalSpan.each_key { |span|
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
        spanString = @originalSpan.keys.join(",")
        @dbu.insertFtypeAttrValue(spanString)
        # get the attribute name id for 'gbTrackOriginalSpan'
        originalSpanNameId = getAttrNameId('gbTrackOriginalSpan')
        # Add a record into ftype2attributes for each of the spans
        spanId = getAttrValueId(spanString)
        insertIntoFtype2AttributeTable(@ftypeId, originalSpanNameId, spanId)
      end
    end
    @zipWriter.close # Close file writer
    # Move original wib files (after gzipping) to the right directory
    system("mkdir -p #{@dir}")
    @wibReader.each_key { |wibFile|
      $stdout.puts "gzipping #{wibFile}"
      system("gzip #{wibFile}")
      system("mv #{wibFile}.gz #{@dir}")
      $stdout.puts "#{wibFile}.gz moved to #{@dir}"
    }
    $stdout.puts "All done"
  end

  # Performs validation of the txt file. If number of errors crosses a threshold,
  # the application exits and prints the errors encountered. If the number of errors is
  # less than the threshold, the complete file is validated and a list of all the
  # errors is printed after validation
  # [+returns+] error list
  def validateWig()
    error = ""
    errorTotal = ""
    errorLineCount = 0
    @wigReader.each_key { |file|
      $stdout.puts "Validating #{file}...."
      lineCount = 0
      orphan = nil
      while(!@wigReader[file].eof?)
        buffer = @wigReader[file].read(@byte)
        bufferIO = StringIO.new(buffer)
        bufferIO.each_line { |line|
          lineCount += 1
          line = orphan + line if(!orphan.nil?)
          orphan = nil
          if(line =~ /\n$/)
            line.strip!
            next if(line =~ /^#/ or line =~ /^\s*$/ or line.nil? or line.empty?)
            data = line.split(/\t/)
            # Check second column (chr)
            if(!@allFrefHash.has_key?(data[1]))
              error << "Unrecognized entrypoint/chromosome: #{data[1]} for file: #{file} at line #{lineCount}. Please make sure if the entry point has already been uploaded.\n"
            end

            # check third and fourth column (start and stop)
            if(data[2] !~ /^\d+$/)
              error << "3rd column of Line : #{lineCount} of #{file} has incorrect format. Expecting start coordinate. Got #{data[2]}\n"
            end
            if(data[3] !~ /^\d+$/)
              error << "4th column of Line : #{lineCount} of #{file} has incorrect format. Expecting stop coordinate. Got #{data[3]}\n"
            end

            # Checking sixth seventh and eight column (span, count and offset)
            if(data[5] !~ /^\d+$/)
              error << "6th column of Line : #{lineCount} of #{file} has incorrect format. Expecting span. Got #{data[5]}\n"
            else
              @originalSpan[data[5].to_i] = nil if(!@originalSpan.has_key?(data[5].to_i))
            end
            if(data[6] !~ /^\d+$/)
              error << "7th column of Line : #{lineCount} of #{file} has incorrect format. Expecting count. Got #{data[6]}\n"
            end
            if(data[7] !~ /^\d+$/)
              error << "8th column of Line : #{lineCount} of #{file} has incorrect format. Expecting offset. Got #{data[7]}\n"
            end

            # Checking tenth and eleventh columns (lowLimit and dataRange)
            if(data[9] !~ /^(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?$/i)
              error << "10th column of Line : #{lineCount} of #{file} has incorrect format. Expecting lowLimit. Got #{data[9]}\n"
            end
            if(data[10] !~ /^(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?$/i)
              error << "11th column of Line : #{lineCount} of #{file} has incorrect format. Expecting dataRange. Got #{data[10]}\n"
            end
            if(!error.empty?)
              errorLineCount += 1
              errorTotal << error
            end
            error = ""
            if(errorLineCount == 20)
              $stderr.puts "Error: Too many errors found in file(s). Unable to proceed"
              $stderr.puts errorTotal
              exit(14)
            end
          else
            orphan = line
          end
        }
      end
    }
    return errorTotal
  end

  # Checks if track exists. creates if it doesn't and sets track wide attributes.
  # If track does exist, no attributes are set
  # The wib file is moved to either the default dir (given in the fmeta table) or
  # user specified dir
  # [+returns+] no return value
  def processWig()
    # Check if track exists in database:
    $stdout.puts "Checking if track exists..."
    val = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(@refseqId, @userId, true, nil)

    # For new track or private track
    if(val["#{@track}"].nil?)
      fmethodAndFsource = @track.split(":")
      fmethod = fmethodAndFsource[0]; fsource = fmethodAndFsource[1]
      retVal = @dbu.selectAllByFmethodAndFsource(fmethod, fsource)
      if(!retVal.empty?)
        $stderr.puts "Private track. Permission denied"
        exit(14)
      else
        # Creating track and adding attribute settings for the track
        $stdout.puts "Track: #{@track} does not exist. Creating...."
        typeAndSubtype = @track.split(":")
        fmethod = typeAndSubtype[0]; fsource = typeAndSubtype[1]

        # Making Track object
        trackObj = BRL::Genboree::Abstract::Resources::Track.new(@dbu, @refseqId, fmethod, fsource)

        #Setting style
        rowsAffected = trackObj.setStyleForUserId("Global Score Barchart (big)", 0)
        if(rowsAffected == 0)
          $stderr.puts "Warning: Style not set for #{@track}"
        else
          $stdout.puts "style :Global Score Barchart (big) set for #{@track}"
        end

        #Setting color
        rowsAffected = trackObj.setColorForUserId("#996600", 0)
        if(rowsAffected == 0)
          $stderr.puts "Warning: Color not set for #{@track}"
        else
          $stdout.puts "color :#996600 set for #{@track}"
        end

        #Setting display
        rowsAffected = trackObj.setDisplayForUserId("Compact", 0)
        if(rowsAffected == 0)
          $stderr.puts "Warning: Display not set for #{@track}"
        else
          $stdout.puts "display :Compact set for #{@track}"
        end

        ############ Inserting track-wide attribute name and values ######################
        ############ Note: If these names and values are already    ######################
        ############ there, dbUtil will ignore the inserts          ######################

        #First get the 'ftypeId' for the track
        ftype = @dbu.selectFtypeByTrackName(@track)
        @ftypeId = ftype.first['ftypeid']

        #Hash for iterating over track attributes
        @attributeHash =
        {
          "gbTrackBpSpan" => BPSPAN,
          "gbTrackBpStep" => BPSTEP,
          "gbTrackDenominator" => DENOMINATOR,
          "gbTrackUseLog" => @UseLog,
          "gbTrackDataMax" => INITDATAMAX,
          "gbTrackDataMin" => INITDATAMIN,
          "gbTrackPxHeight" => PXHEIGHT,
          "gbTrackUserMax" => INITDATAMAX,
          "gbTrackUserMin" => INITDATAMIN,
          "gbTrackHasNullRecords" => "true",
          "gbTrackWindowingMethod" => @windowingMethod,
          "gbTrackDataType" => @dataType,
          "gbTrackRecordType" => 'int8Score',
          "gbTrackDataSpan" => DATASPAN,
          "gbTrackFormula" => GBFORMULA
        }

        # Inserting attribute names and values for the track
        @attributeHash.each_key { |key|
          if(!@attributeHash[key].nil?)
            @attributeHash[key] = nil if(key == "gbTrackFormula" and (@recordType == "floatScore" or @recordType == "doubleScore"))
            insertAttrNameAndValue(key, @attributeHash[key])
            ftypeAttrName = getAttrNameId(key);
            ftypeAttrValue = getAttrValueId(@attributeHash[key]);
            insertIntoFtype2AttributeTable(@ftypeId, ftypeAttrName, ftypeAttrValue)
          end
        }

        # Inserting record for 'gclass' and 'ftype2gclass'
        insertIntoGclassAndFtype2GClass(@ftypeId)
        @dataMax = INITDATAMAX
        @dataMin = INITDATAMIN
        # Make new bin file for the track
        system("mkdir -p #{@dir}")
        @binName = Rack::Utils.escape("#{@track}.#{Time.now}.#{rand()}.bin")
        @zipWriter = BRL::Util::TextWriter.new("#{@dir}/#{@binName}")
        @zipOffset = 0
        @appendToTrackBoolean = 0
      end
    # If track exists, do not set attributes, just move wib file
    else
      $stdout.puts "track attributes (if provided) will not be set since track already exists"
      #First get the 'ftypeId' for the track
      ftype = @dbu.selectFtypeByTrackName(@track)
      @ftypeId = ftype.first['ftypeid']
      # Get existing 'gbTrackDataMax' and 'gbTrackDataMin' from database
      maxId = getAttrNameId('gbTrackDataMax')
      value = @dbu.selectFtypeAttrValueByFtypeIdAndAttributeNameId(@ftypeId, maxId.first['id'])
      @dataMax = value.first['value'].to_f
      minId = getAttrNameId('gbTrackDataMin')
      value = @dbu.selectFtypeAttrValueByFtypeIdAndAttributeNameId(@ftypeId, minId.first['id'])
      @dataMin = value.first['value'].to_f
      dirFromFmeta = @dbu.selectValueFmeta('RID_SEQUENCE_DIR')
      @binName = @dbu.selectBlockLevelDataExistsForFtypeId(@ftypeId)
      @appendToTrackBoolean = 1
      # The existing binary file would be useless if the user selected the 'delete annotatons prior to upload'
      # Make new binary file in that case
      if(@binName.empty? or @binName.nil?)
        @binName = Rack::Utils.escape("#{@track}.#{Time.now}.#{rand()}.bin")
        @zipWriter = BRL::Util::TextWriter.new("#{@dir}/#{@binName}")
      else
        @zipWriter = BRL::Util::TextWriter.new("#{@dir}/#{@binName}", "a")
        @zipOffset = @zipWriter.pos()
      end
    end
  end

  # Reads the txt file(s) and makes an array of arrays required for insertion into
  # 'blockLevelDataInfo'. Inserts 4000 records at a time. Reading of the txt file is
  # done in memory to promote optimization
  #[+returns+] no return value
  def readWig()
    @ridHash = Hash.new
    @dbCount = 0
    @blockData = Array.new()
    # variables specific for adding zoom level info:
    previousChrZoom = nil
    chrZoom = nil
    startZoom = nil
    spanZoom = nil
    bpCoordZoom = nil
    stepZoom = nil
    startCoordZoom = 0
    zoomObj = ZoomLevelUpdater.new(@dbu)
    binner = BRL::SQL::Binning.new
    @wigReader.each_key { |wigFile|
      @wigReader[wigFile].rewind()
      lineCount = 0
      byteRead = 0
      orphan = nil
      #Read in chunks
      while(!@wigReader[wigFile].eof?)
        buffer = @wigReader[wigFile].read(@byte)
        $stdout.puts "#{byteRead}MB of file: #{wigFile} processed" if(byteRead > 0)
        byteRead = byteRead + (@byte / 1000000)
        buffIO = StringIO.new(buffer)
        buffIO.each_line { |line|
          line = orphan + line if(!orphan.nil?)
          orphan = nil
          if(line =~ /\n$/)
            line.strip!
            next if(line =~ /^#/ or line =~ /^\s*$/ or line.nil? or line.empty?)
            lineCount += 1
            # Check if track has already has annos/data
            if(lineCount == 1)
              numberOfAnnotations = nil
              ftypeCount = @dbu.selectFtypeCountByFtypeid(@ftypeId)
              numberOfAnnotations = ftypeCount[0]['numberOfAnnotations'] if(!ftypeCount.nil? and !ftypeCount.empty?)
              if(!numberOfAnnotations.nil?) # Initialize ftypeCount with 0
                @annosCount = numberOfAnnotations.to_i
              else
                @annosCount = 0
                @dbu.insertFtypeCount(@ftypeId, 0) # Initialize with 0
              end
            end
            data = line.split(/\t/)
            # Parse required fields
            chrom = data[1].to_s
            start = data[2].to_i + 1 # Add 1 to start since UCSC stuff is 0 relative and closed set (the last base is not included in the set)
            stop = data[3].to_i
            fbin = binner.bin(BRL::SQL::MIN_BIN, start, stop)
            span = data[5].to_i
            scale = data[10].to_f
            lowLimit = data[9].to_f
            fileReader = @wibReader[File.basename(data[8])]
            @numRecords = data[6].to_i * span
            numScores = 0
            # seek to the file offset, expand span times and then compress (span may be greater than 1)
            fileReader.seek(data[7].to_i)
            wibData = fileReader.read(data[6].to_i)
            if(@noZoom.nil?)
              if(previousChrZoom.nil?)
                zoomObj.getZoomLevelRecsByRid(@frefHash[chrom][1], @frefHash[chrom][0], @ftypeId)
                realScores = wibData.unpack("C*")
                bpCoordZoom = start
                realScores.each { |value|
                  if(value < 128)
                    zoomObj.addNewScoreForSpan((lowLimit + scale * (value.to_f / 127.0)), bpCoordZoom, span)
                    numScores += span
                  end
                  bpCoordZoom += span
                }
              else
                # write out zoom level info for the chromosome if we have a new chromosome
                if(previousChrZoom != chrom)
                  zoomObj.writeBackZoomLevelRecords()
                  zoomObj.clearZoomData()
                  $stdout.puts "zoom level updated for #{previousChrZoom}"
                  zoomObj = zoomLevelUpdater.new(@dbu)
                  zoomObj.getZoomLevelRecsByRid(@frefHash[chrom][1], @frefHash[chrom][0], @ftypeId)
                  realScores = wibData.unpack("C*")
                  bpCoordZoom = start
                  realScores.each { |value|
                    if(value < 128)
                      zoomObj.addNewScoreForSpan((lowLimit + scale * (value.to_f / 127.0)), bpCoordZoom, span)
                      numScores += span
                    end
                    bpCoordZoom += span
                  }
                # For old chr, just update the zoom level recs hash
                else
                  realScores = wibData.unpack("C*")
                  bpCoordZoom = start
                  realScores.each { |value|
                    if(value < 128)
                      zoomObj.addNewScoreForSpan((lowLimit + scale * (value.to_f / 127.0)), bpCoordZoom, span)
                      numScores += span
                    end
                    bpCoordZoom += span
                  }
                end
              end
              previousChrZoom = chrom
            else
              realScores = wibData.unpack("C*")
              realScores.each { |value|
                numScores += span if(value < 128)
              }
            end
            expandedTempWibData = ""
            wibData.each { |value|
              span.times {
                expandedTempWibData << value
              }
            }
            # Add zoom level info if required

            tempWibData = @zDeflater.deflate(expandedTempWibData, Zlib::FINISH)
            @zDeflater.reset()
            @compressedWibData << tempWibData
            @sizeOfCompressedWibData = tempWibData.size
            max = lowLimit + scale
            @dataMax = max if(max > @dataMax)
            @dataMin = lowLimit if(lowLimit < @dataMin)
            @blockData[@dbCount] = [@binName, @zipOffset, @sizeOfCompressedWibData, @numRecords, @allFrefHash[chrom], @ftypeId, start, stop, fbin, nil, nil, scale, lowLimit]
            @dbCount += 1
            @zipOffset = @zipOffset + @sizeOfCompressedWibData
            @annosCount += numScores
            if(@dbCount == BLOCKSIZE)
              @dbu.insertBlockLevelDataInfoRecords(@blockData, BLOCKSIZE)
              # Check for errors
              displayErrorMsgAndExit(@dbu.err) if(!@dbu.err.nil?)
              @blockData.clear()
              @dbCount = 0
            end
            if(@compressedWibData.size >= 5000000)
              @zipWriter.print(@compressedWibData)
              @compressedWibData = ""
            end
          else
            orphan = line
          end
        }
      end
      zoomObj.writeBackZoomLevelRecords()
      zoomObj.clearZoomData()
      $stdout.puts "zoom level updated for #{previousChrZoom}"
      # Insert remaining block level records
      if(!@blockData.empty?)
        @dbu.insertBlockLevelDataInfoRecords(@blockData, @blockData.size)
        if(!@dbu.err.nil?)
          $stderr.puts @dbu.err
          exit(14)
        end
      end
      @dbu.updateNumberOfAnnotationsByFtypeid(@ftypeId, @annosCount)
      # Write to file if necessary
      @zipWriter.print(@compressedWibData) if(!@compressedWibData.empty?)
      @compressedWibData = ""
      @blockData.clear()
      @dbCount = 0
    }
  end

  # ############################################################################
  # GENERIC METHODS
  # ############################################################################
  # Displays error message and quits
  # [+msg+]  error message
  def displayErrorMsgAndExit(msg)
    $stderr.puts msg
    exit(14)
  end

  # Insert attribute name and value in the tables ftypeAttrNames and ftypeAttrValues respectively.
  # [+attrName+]  Name of the track atrribute
  # [+attrValue+]  Value of the track atrribute
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
  def insertIntoFtype2AttributeTable(ftypeId, ftypeAttrName, ftypeAttrValue)
    @dbu.insertFtype2Attribute(ftypeId, ftypeAttrName.first['id'], ftypeAttrValue.first['id'])
    $stdout.puts "'#{ftypeAttrName.first['name']}': #{ftypeAttrValue.first['value']}  set for #{@track}"
  end

  # Gets attribute value using ftypeid and attr name id
  # [+attrName_id+]  id of the attribute name for which the value is required
  # [+ftypeId+] ftypeId of the track
  # [+returns+] array or array containing value correspoding to attribute name for the ftypeId
  def getAttrValueFromAttrName_id(attrName_id, ftypeId)
    value = @dbu.selectFtypeAttrValueByFtypeIdAndAttrNameId(ftypeId, attrName_id)
    return value
  end

  # Make class '06. HDHV_data' if not present
  # Adds thr track to the class
  #  [+ftypeid+] ftypeid of the track which is to be added to the HDHV class
  def insertIntoGclassAndFtype2GClass(ftypeid)
    # Make class for High density High Volume data if it does not exist
    @dbu.insertGclassRecord('High Density Score Data')
    # Get gid
    gid = @dbu.selectGclassByGclass('High Density Score Data')
    gid = gid.first['gid']
    # Insert into 'ftype2gclass'
    @dbu.insertFtype2Gclass(ftypeid, gid)
  end

end

# Class for processing command line arguments
class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Sameer Paithankar

  Description: This program is for uploading wig and wib data in genboree.
  The program takes in two types of files: txt(wig) file(s) and wib file(s).
  Each record in the wig file has a corresponding set of bytes in the wib file which is 'seeked' using the
  offset information available in the wig file. Currently, the byte score is then converted into the original
  score using the 'wiggle' formula explained in the UCSC wiggle wiki page.
  Each record is then uploaded in the blockLevelDataInfo table of the database specified.

  Important: The wib file(s) is moved to: /usr/local/brl/data/genboree/ridSequences/(reseqId_of_database)/ if no --dir is specified
              The .wib file should not be zipped when providing to the script.

  Arguments:

    -f  --txt => txt file(s) to be processed (required). If mulitple files, list should be comma seperated without spaces(-f file1.txt,file2.txt,file3.txt)
    -w  --wib => wib file(s) to be processed (required). If mulitple files, list should be comma seperated without spaces(-w file1.wib,file2.wib,file3.wib)
    -t  --track => name of the track (required)
    -g  --group => group name to which the database belongs (required)
    -d  --database => name of the database (required) (refseqId or full name)
    -u  --user => genboree loginid or login name (required)
    -i  --dir => directory where the wib file(s) and the bin file will be moved (default /usr/local/brl/data/genboree/ridSequences/(reseqId_of_database)/)
              Note that in case track exists, the program will try to find the bin file in this dir to append data. In case the user selected 'remove annotations
              prior to uploading new annotations' the old bin file will be null and void and a new bin file will be created in this directory.
    -m  --gbTrackWindowingMethod => 'AVG', 'MAX' or 'MIN' (default: 'MAX')
    -l  --gbTrackUseLog => used to know if we need to use logarithmic scale during the drawing
    -y  --gbTrackDataType => 'genomeBased' or 'blockBased' (default: 'blockBased')
    -b  --byte => no of Mbs to process at a time from the wib file (default: ~ 32 MB)
    -V  --noValidation => skip validation. (only recommended if file is from very reliable source!)
    -Z  --noZoom => do not add zoom level info for the track. (default settings will add zoom level records for the track)
    -v  --version => Version of the program
    -h  --help => Display help

    Usage:  importWibInGenboree.rb -f phastConsQuick.txt -w phastCons44wayPlacental.wib -t phastCons:test -g 'EDACC - Test New Features' -d 1095 -u 7
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
    methodName="performImportWib"
    optsArray=[
      ['--wig','-f',GetoptLong::REQUIRED_ARGUMENT],
      ['--wib','-w',GetoptLong::REQUIRED_ARGUMENT],
      ['--track','-t',GetoptLong::REQUIRED_ARGUMENT],
      ['--group','-g',GetoptLong::REQUIRED_ARGUMENT],
      ['--database','-d',GetoptLong::REQUIRED_ARGUMENT],
      ['--user','-u',GetoptLong::REQUIRED_ARGUMENT],
      ['--dir','-i',GetoptLong::OPTIONAL_ARGUMENT],
      ['--gbTrackWindowingMethod','-m',GetoptLong::OPTIONAL_ARGUMENT],
      ['--gbTrackUseLog','-l',GetoptLong::OPTIONAL_ARGUMENT],
      ['--gbTrackDataType','-y',GetoptLong::OPTIONAL_ARGUMENT],
      ['--byte','-b',GetoptLong::OPTIONAL_ARGUMENT],
      ['--noValidation','-V',GetoptLong::OPTIONAL_ARGUMENT],
      ['--noZoom','-Z',GetoptLong::OPTIONAL_ARGUMENT],
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

  def self.performImportWib(optsHash)
    ImportWib.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performImportWib(optsHash)
