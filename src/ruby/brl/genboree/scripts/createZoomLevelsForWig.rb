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
require 'brl/genboree/helpers/wigValidator'
require 'brl/genboree/graphics/zoomLevelUpdater'

# class for importing zoom level records for wig tracks
class ImportZoomLevels
  ####################
  # Constants
  BUFFERSIZE = 32000000
  DEFAULTSPAN = 1
  #####################
  #Variables
  #####################
  attr_accessor :inputFile, :groupName, :userName, :databaseName, :trackName
  attr_accessor :dbu, :userId, :refseqId, :refseqName, :groupId, :reader, :frefHash
  #####################
  # Methods
  #####################
  def initialize(optsHash)
    @inputFile = optsHash["--inputFile"]
    $stderr.puts "File does not exist" if(!File.exists?(@inputFile))
    @trackName = nil
    if(optsHash['--trackName'])
      displayErrorMsgAndExit("Track name should have a ':'") if(optsHash['--trackName'] !~ /:/)
      @trackName = optsHash['--trackName']
    end

    #Making dbUtil Object for database 'genboree'
    gc = BRL::Genboree::GenboreeConfig.load
    @dbu = BRL::Genboree::DBUtil.new("#{gc.dbrcKey}", nil, nil)

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
    # collect all rid info from user db
    @frefHash = Hash.new
    allFrefRecords = @dbu.selectAllRefNames()
    allFrefRecords.each { |record|
      @frefHash[record['refname']] = [record['rlength'].to_i, record['rid'].to_i] if(!@frefHash.has_key?(record['refName']))
    }
    # Expand the file if required
    expanderObj = BRL::Genboree::Helpers::Expander.new(@inputFile)
    expanderObj.extract(desiredType = 'text')
    displayErrorMsgAndExit("Unable to decompress file: #{@inputFile}") if(!expanderObj.stderrStr.empty?)
    fileStatus = (File.basename(expanderObj.uncompressedFileName) == File.basename(@inputFile) ? :compress : :remove)
    @inputFile = expanderObj.uncompressedFileName

    # Validate the wig file first
    validator = WigValidator.new(@inputFile, @dbu)
    $stdout.puts "validating.."
    begin
      validator.validateWig()
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end
    errors = validator.giveErrorList
    fileFormat = validator.fileFormat
    displayErrorMsgAndExit(errors) if(!errors.empty?)
    $stdout.puts "validation done. No errors"
    # sort file file if required
    if(validator.isSortReq? == :YES)
      # launch the appropriate sorter depending on what kind of sorting is required
      if(validator.fileFormat == "fixedStep")
        sortObj = Sorter.new(fileType = "fixedStep", pathToFile = @inputFile)
        $stdout.puts "sorting file: #{@inputFile}"
        sortObj.sortFile
        @reader = BRL::Util::TextReader.new(sortObj.sortedFileName)
      elsif(validator.fileFormat == "variableStep")
        if(validator.interSort == :YES and validator.intraSort != :YES)
          sortObj = Sorter.new(fileType = "variableStep", pathToFile = @inputFile)
          $stdout.puts "sorting file: #{@inputFile}"
          sortObj.sortFile()
          @reader = BRL::Util::TextReader.new(sortObj.sortedFileName)
        elsif(validator.intraSort == :YES)
          sortObj = Sorter.new(fileType = "variableStepRecords", pathToFile = @inputFile)
          sortObj.sortFile()
          newSortObj = Sorter.new(fileType = "variableStep", pathToFile = sortObj.sortedFileName)
          newSortObj.sortFile()
          @reader = BRL::Util::TextReader.new(newSortObj.sortedFileName)
        end
      end
    else
      @reader = BRL::Util::TextReader.new(@inputFile)
    end
    $stdout.puts "starting computing of zoom levels..."
    # Process the file now and create/update zoom level records
    if(fileFormat == "fixedStep")
      createZoomLevelRecordsForFixedStep()
    elsif(fileFormat == "variableStep")
      createZoomLevelRecordsForVariableStep()
    else
      $stderr.puts "Unknown format"
      exit()
    end
    if(fileStatus == :compress)
      $stdout.puts "compressing file: #{@inputFile}"
      system("gzip #{@inputFile}")
    elsif(fileStatus == :remove)
      $stdout.puts "removing file: #{@inputFile}"
      system("rm #{@inputFile}")
    end
    $stdout.puts "All done"
  end

  # Goes through a fixed step wig file and creates/updates zoomLevels table for that track
  # [+returns+] nil
  def createZoomLevelRecordsForFixedStep()
    # First get ftypeid for the track
    ftypeid = nil
    ftype = @dbu.selectFtypeByTrackName(@trackName)
    if(ftype.empty? or ftype.nil?)
      methodSource = @trackName.split(":")
      @dbu.insertFtype(methodSource[0], methodSource[1])
      ftype = @dbu.selectFtypeByTrackName(@trackName)
      ftypeId = ftype.first['ftypeid']
    else
      ftypeId = ftype.first['ftypeid']
    end
    orphan = nil
    bpCoord = nil
    chr = nil
    previousChr = nil
    span = nil
    step = nil
    start = nil
    startCoord = 0 # flag for keeping track if its the first recordof the block
    zoomObj = ZoomLevelUpdater.new(@dbu)
    while(!@reader.eof?)
      fileBuffer = @reader.read(BUFFERSIZE)
      buffIO = StringIO.new(fileBuffer)
      buffIO.each_line { |line|
        line = orphan + line if(!orphan.nil?)
        orphan = nil
        if(line =~ /\n$/)
          line.strip!
          if(line =~ /^fixedStep/)
            # parse the block header for the chromosome, span and start values
            blockHeader = line.split(/\s+/)
            span = nil
            blockHeader.each { |att|
              attValue = att.split("=")
              bpCoord = attValue[1].to_i if(attValue[0] == 'start')
              chr = attValue[1] if(attValue[0] == 'chrom')
              span = attValue[1].to_i if(attValue[0] == 'span')
              step = attValue[1].to_i if(attValue[0] == 'step')
              start = attValue[1].to_i if(attValue[0] == 'start')
            }
            startCoord = 0
            if(previousChr.nil?)
              zoomObj.getZoomLevelRecsByRid(@frefHash[chr][1], @frefHash[chr][0], ftypeId)
            elsif(previousChr != chr)
              zoomObj.writeBackZoomLevelRecords()
              $stdout.puts "zoom levels updated for chr: #{previousChr}"
              zoomObj.clearZoomData
              zoomObj = ZoomLevelUpdater.new(@dbu)
              zoomObj.getZoomLevelRecsByRid(@frefHash[chr][1], @frefHash[chr][0], ftypeId)
            end
            span = (span.nil? ? DEFAULTSPAN : span)
            step = (step.nil? ? DEFAULTSPAN : step)
            previousChr = chr
          elsif(line =~ /^(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?$/i)
            # Add 0 if required
            if(line =~ /^\./)
              line = "0#{line}"
            elsif(line =~ /\.$/)
              line = "#{line}0"
            end
            score = line.to_f
            if(startCoord == 0)
              bpCoord = start
            else
              start += step
              bpCoord = start
            end
            zoomObj.addNewScoreForSpan(score, bpCoord, span)
            #span.times {
            #  zoomObj.addNewScore(score, bpCoord)
            #  bpCoord += 1
            #}
            startCoord = 1
          end
        else
          orphan = line
        end
      }
    end
    zoomObj.writeBackZoomLevelRecords()
    $stdout.puts "zoom levels uploaded for chr: #{previousChr}"
    zoomObj.clearZoomData()
  end

  def createZoomLevelRecordsForVariableStep()
    # First get ftypeid for the track
    ftypeid = nil
    ftype = @dbu.selectFtypeByTrackName(@trackName)
    if(ftype.empty? or ftype.nil?)
      methodSource = @trackName.split(":")
      @dbu.insertFtype(methodSource[0], methodSource[1])
      ftype = @dbu.selectFtypeByTrackName(@trackName)
      ftypeId = ftype.first['ftypeid']
    else
      ftypeId = ftype.first['ftypeid']
    end
    orphan = nil
    bpCoord = nil
    chr = nil
    previousChr = nil
    span = nil
    zoomObj = ZoomLevelUpdater.new(@dbu)
    while(!@reader.eof?)
      fileBuffer = @reader.read(BUFFERSIZE)
      buffIO = StringIO.new(fileBuffer)
      buffIO.each_line { |line|
        line = orphan + line if(!orphan.nil?)
        orphan = nil
        if(line =~ /\n$/)
          line.strip!
          if(line =~ /^variableStep/)
            # parse the block header for the chromosome, span and start values
            blockHeader = line.split(/\s+/)
            span = nil
            blockHeader.each { |att|
              attValue = att.split("=")
              chr = attValue[1] if(attValue[0] == 'chrom')
              span = attValue[1].to_i if(attValue[0] == 'span')
            }
            if(previousChr.nil?)
              zoomObj.getZoomLevelRecsByRid(@frefHash[chr][1], @frefHash[chr][0], ftypeId)
            elsif(previousChr != chr)
              zoomObj.writeBackZoomLevelRecords()
              zoomObj.clearZoomData()
              zoomObj = ZoomLevelUpdater.new(@dbu)
              zoomObj.getZoomLevelRecsByRid(@frefHash[chr][1], @frefHash[chr][0], ftypeId)
            end
            span = (span.nil? ? DEFAULTSPAN : span)
            previousChr = chr
          elsif(line =~ /^(?:(\+|\-)?\d+)\s+(?:(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?)$/i)
            data = line.split(/\s+/)
            # Add 0 if required
            if(data[1] =~ /^\./)
              data[1] = "0#{data[1]}"
            elsif(data[1] =~ /\.$/)
              data[1] = "#{data[1]}0"
            end
            score = data[1].to_f
            bpCoord = data[0].to_i
            zoomObj.addNewScoreForSpan(score, bpCoord, span)
            #span.times {
            #  zoomObj.addNewScore(score, bpCoord)
            #  bpCoord += 1
            #}
          end
        else
          orphan = line
        end
      }
    end
    zoomObj.writeBackZoomLevelRecords()
    $stdout.puts "zoom levels uploaded for chr: #{previousChr}"
    zoomObj.clearZoomData()
  end

  # ############################################################################
  # GENERIC METHODS
  # ############################################################################
  # Displays error message and quits
  # [+msg+]  error message
  #  [+returns+] nil
  def displayErrorMsgAndExit(msg)
    msg = "FATAL ERROR:\n" + msg.to_s
    $stderr.puts msg
    exit(14)
  end


end



class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Sameer Paithankar

  Description: This script is for creating zoom level records for wiggle (fixedStep and variableStep) data. The script manages both inserting new zoom level records (for new tracks)
  and updating zoom level records (for existing tracks)

  Notes:
  => bed format not supported. Supports: fixedStep and variableStep

    -i  --inputFiles => full path to the wig file
    -g  --groupName => name or id of the group whose database the data will be uploaded to (required)
    -u  --userName => genboree user name or user id of the person running the program (Note: private tracks may or may not be accessible depending on track access settings) (required)
    -d  --databaseName => full name of the database or refseqid to which the data will be uploaded (required)
    -t  --trackName =>  argument with the Genboree track name to use for the data to be uploaded
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
      ['--inputFile','-i',GetoptLong::REQUIRED_ARGUMENT],
      ['--groupName','-g',GetoptLong::REQUIRED_ARGUMENT],
      ['--userName','-u',GetoptLong::REQUIRED_ARGUMENT],
      ['--databaseName','-d',GetoptLong::REQUIRED_ARGUMENT],
      ['--trackName','-t',GetoptLong::REQUIRED_ARGUMENT],
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

  def self.performImportZoomLevels(optsHash)
    ImportZoomLevels.new(optsHash)
  end

end

require 'ruby-prof'

optsHash = RunScript.parseArgs()

#RubyProf.start
RunScript.performImportZoomLevels(optsHash)
#result = RubyProf.stop
#RubyProf::GraphPrinter.new(result).print(STDOUT, 0)
