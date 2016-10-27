#!/usr/bin/env ruby

require 'brl/genboree/abstract/resources/abstractStreamer'
# Workaround to preven cyclical require errors.
# Define the class before requiring files that might require this class
module BRL ; module Genboree ; module Abstract ; module Resources
#class BRL::Genboree::Abstract::Resources::AnnotationFile
class AnnotationFile < AbstractStreamer
end
end ; end ; end ; end

require 'brl/util/util'
require 'brl/genboree/hdhv'
require 'brl/util/textFileUtil'
require 'ruby-prof'
require 'zlib'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/util/checkSumUtil'
require 'brl/genboree/C/hdhv/getScore'
include Math
# List of fdata2 fields that are required
module BRL ; module Genboree ; module Abstract ; module Resources

  # This class contains common functionality required by different file types
  # used to represent annotation data.
  #
  # It handles both writing the file to disk or streaming the contents
  #
  # This class should be able to handle different requested collections of
  # annotations efficiently, including:
  #  -one or more tracks
  #  -one or more landmarks (one or more chromosomes)
  #     for example: trackA, trackB, trackC => chr1:1-1000,ch2:1-1000
  #
  # set the possible instance variable which determines what will be returned
  # @ftypeId      Int
  # or
  # @trackList    Array of track names
  # and
  # @refSeqId     Int
  #
  # @landmark     String
  # landmark, e.g. 'chr1:1234-5678']
  #
  # The following landmarks are allowed
  # 'chr22' or 'chr22:'   the whole chromosome
  # 'chr22:10000-'        from 10000 to the end
  # 'chr22:-10000'        from beginning to 10000
  # 'chr22:10000-20000'   from 10000 to 20000
  #
  # Potential GOTCHA:
  #   If both @trackList and @ftypeId are set, @trackList takes precedence
  #
  class AnnotationFile < AbstractStreamer

    # Structs:
    AvgStruct = Struct.new(:sum, :count)
    AvgByLengthStruct = Struct.new(:sum)
    MedianStruct = Struct.new(:string, :numRecords) # For high density trks (:string is actually a buffer used on the C side to store gfloat/gdouble values)
    MedianArrStruct = Struct.new(:arr, :numRecords) # For non high density trks (:arr will be used to store numbers directly for each ROI record)
    SumStruct = Struct.new(:sum)
    MaxStruct = Struct.new(:max)
    MinStruct = Struct.new(:min)
    StdevStruct = Struct.new(:sum, :soq, :count)
    CountStruct = Struct.new(:count)
    # BDUtil instance
    attr_accessor :dbu
    # IO object containing the bed data
    attr_accessor :outObj
    # Optional output file, if file should be written to disk use this
    # If this is set, the bedIO object will be a File object instead of a StringIO
    attr_accessor :fileName
    # String that contains the comma separated list of fdata2 columns that are required for the file
    attr_accessor :fdataFields
    # Color lookup table
    attr_accessor :colorHash
    # Hash containing fref names indexed by rid
    attr_accessor :frefNameHash
    # Hash for the length of the chromosomes
    attr_accessor :frefHash
    # Hash containing the fref names
    attr_accessor :ftypeHash
    # Hash containing ftype Attributes, key => value
    attr_accessor :ftypeAttributesHash
    # option to print the track head line in the file
    attr_accessor :showTrackHead
    # User for gff3 to check if 'Name' attribute is already present
    attr_accessor :nameAttrHash
    # option to print the column header (for tab-delim formats mainly)
    attr_accessor :showColumnHeader
    # Set an error here to be checked by the calling method
    attr_accessor :error
    # Set to true in initialize to use this feature
    attr_accessor :hasChrHeaderLine
    # When calling hdhv methods, type (format) is required, 'bed' or 'wiggle'
    attr_accessor :hdhvType
    # for storing the class name for each track
    attr_accessor :className
    # for storing the AVP names
    attr_accessor :attNamesHash
    # for storing the AVP values
    attr_accessor :attValueHash
    # size of the buffer to be collected
    attr_accessor :bufferSize
    # various hashes and arrays for storing name-value pairs and such
    attr_accessor :attIdArray, :fid2NameAndValueHash, :fid2CommentsHash, :fid2SequenceHash, :fidScore, :fidArray
    # track wide min and max values
    attr_accessor :trackWideMinScore, :trackWideMaxScore
    attr_accessor :ftypeCount, :queryFtypeId, :gname
    # array of DBI:rows for blockLevelDataInfo when 'scoreTrack' is passed
    attr_accessor :blockRecs
    # block index: used when getting tracks intersected with score (HD tracks)
    attr_accessor :blockIndex
    # size of blockRecs
    attr_accessor :blockRecsSize
    # replace annos with no scores with:
    attr_accessor :emptyScoreValue
    # hash for storing files from probe/score file
    attr_accessor :scoreFileHash
    # name filter for score lifting
    attr_accessor :nameFilter
    # refSeqId of current user data database (i.e. for the 'roi' or main annotation track)
    attr_accessor :refSeqId
    # trackList array of track name(s) to download
    attr_accessor :trackList
    # denom for avgbylength aggregate function
    attr_accessor :denomForAvgBylength
    # current Adler32 check sum value for the chunks being yielded
    attr_accessor :currAdler32
    # cummulative size of the chunk/payload being yielded
    attr_accessor :totalBytesSent
    # counter for fdata2 records
    attr_accessor :fdata2Index
    # Aggregate Function
    attr_accessor :aggFunction
    # An array of structs to hold aggregate values depending on the requested aggregate function
    attr_accessor :structArray
    # A ruby string which will be used by the C side to fill with a score for an annotation
    attr_accessor :valueString
    # An object of the getScore (inline C) class
    attr_accessor :getScoreObj
    # yield when buffer reaches this size
    MAX_BUFFER_SIZE = 128 * 1024
    FIRST_CHUNK_BUFFER_SIZE = 1024
    FORMATS_WITH_AVPS = {
      'gff3' => nil,
      'gtf' => nil,
      'lff' => nil,
      'bed' => nil,
      'vcf' => nil
    }
    PAUSE_SIZE = 500_000_000
    MEDIAN_LIMIT = 50_000
    PAUSE_LENGTH = 1
    # column header line
    COLUMN_HEADER_LINE = ''


    def initialize(dbu, fileName=nil)
      super()
      unless(self.class.method_defined?(:child_each))
        alias :child_each :each
        alias :each :parent_each
      end
      @dbu, @fileName = dbu, fileName
      @genbConf = BRL::Genboree::GenboreeConfig.load()
      @outObj = (@fileName.nil?) ? StringIO.new : File.new(fileName, 'w')
      @hasChrHeaderLine = false
      @showTrackHead = false
      @showColumnHeader = false
      @colorHash = {}
      @frefNameHash = {}
      @scoreTrackFrefHash = {}
      @yieldBuffSize = FIRST_CHUNK_BUFFER_SIZE
      # Subclasses should redefine this to only specify the fields that are required.
      @fdataFields = '*'
      @hdhvType = ''
      @queryFtypeId = nil
      @gname = nil
      @nameFilter = nil
      # format specific options, handled by subclasses
      @formatOptions = {}
      @attNamesHash = {}
      @attValueHash = {}
      @frefInvertHash = {}
      @attIdArray = []
      @scoreFileHash = {}
      @trackObj = nil
      @frefHash = Hash.new
      @emptyScoreValue = nil
      @refSeqId = nil
      @trackList = nil
      @landmarks = nil
      @timings = Hash.new {|hh,kk| hh[kk] = 0}
      @denomForAvgByLength = 1
      @totalBytesSent = 0
      @currAdler32 = Zlib.adler32()
      @dbuScore = nil
      @dbuROI = nil
      @fdata2Index = 0
      @varInitForGetScoreByAnnos = 0
      @optionsHash = {}
      @aggFunction = nil
      @structArray = []
      @scoreTrkIsHdhv = false
      @hdhvObj = nil
      @createBufferObject = BRL::Genboree::CreateBuffer.new()
      @valueString = @createBufferObject.createBuffer(1, 1024) # More than enough to hold one value for any data type (gfloat, gdouble, guint8)
      @getScoreObj = BRL::Genboree::C::Hdhv::GetScore.new()
      @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
    end

    
    ##############################################################
    ## Enumerable methods (when object is used as response.body)
    ##############################################################

    # Provides the requested file by chunk
    #
    # Implemented so that the file contents can be streamed/buffered.
    def each
      #$stderr.debugPuts(__FILE__, __method__, ">>>>>", "  Entered 'each' to stream annos.")
      t1 = Time.now
      begin
        gcIter = 0
        @funcTime = 0
        yield addChrInfo() if(@formatOptions.key?('addChrInfo'))
        if(!@trackList.nil? and !@refSeqId.nil?) # We were given a list of tracks (rare case)
          @trackList.each { |trackName|
            fmethod, fsource = trackName.split(':')
            @trackObj = BRL::Genboree::Abstract::Resources::Track.new(@dbu, @refSeqId, fmethod.strip, fsource.strip)
            #allDbs = @trackObj.getDbRecsWithData() # Get all dbs for the track
            allDbs = @trackObj.dbRecs
            allDbs.each { |db|
              #$stderr.debugPuts(__FILE__, __method__, ">>>>>", "  Examine this db rec for annos:\n    #{db.inspect}")
              next if(db['ftypeid'].nil?)
              @dbu.setNewDataDb(db['dbName'])
              @ftypeId = db['ftypeid'] # Overwrite @ftypeId so that it matches the current db
              ftypeId = db['ftypeid'].to_i
              makeFtypeHash(ftypeId)
              yieldTrackData(gcIter) { |trkData| yield trkData }
            }
          }
        elsif(!@ftypeId.nil?) # We were given a single track to download (general case)
          # Make @ftypeHash available
          makeFtypeHash(@ftypeId)
          @trackObj = BRL::Genboree::Abstract::Resources::Track.new(@dbu, @refSeqId, @ftypeHash['fmethod'], @ftypeHash['fsource'])
          #allDbs = @trackObj.getDbRecsWithData # get all ds with track
          allDbs = @trackObj.dbRecs
          allDbs.each{ |db|
            #$stderr.debugPuts(__FILE__, __method__, ">>>>>", "  Examine this db rec for annos:\n    #{db.inspect}")
            next if(db['ftypeid'].nil?)
            @dbu.setNewDataDb(db['dbName'])
            @ftypeId = db['ftypeid'] # Overwrite @ftypeId so that it matches the current db
            yieldTrackData(gcIter) { |trkData| yield trkData }
          }
        else
          @error = BRL::Genboree::GenboreeError.new(:'Bad Request', "Must have either ftypeId set or trackList and refSeqId.")
        end
        # Add the adler32 check sum line at the end if required
        if(@formatOptions['addCRC32Line'] == 'true')
          yield BRL::Util::CheckSumUtil.getAdler32Str(@currAdler32)
        end
      rescue Exception => err
        errorBuff = "**************************************************************************\n"
        errorBuff << "FATAL_ERROR: This data file is corrupted and/or incomplete.\n"
        errorBuff << "* This may be due to unacceptably slow Genboree server or\n"
        errorBuff << "* this may be due to an exessively slow network connection between Genboree servers.\n"
        errorBuff << "* Please contact: #{@genbConf.gbAdminEmail.inspect} for more information.\n"
        errorBuff << "*************************************************************************\n"
        errTimeStamp = Time.now()
        yield "#{errorBuff}\nERROR_DETAILS (#{errTimeStamp}):\n#{err}\n"
        $stderr.debugPuts(__FILE__, __method__, "ERROR #{errTimeStamp}", "#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}\n\n@formatOptions:\n#{@formatOptions.inspect}")
      ensure
        $stderr.debugPuts(__FILE__, __method__, ">>>>>", "   DONE download. Sent total of #{@totalBytesSent.inspect} bytes. Doing final GC.")
        GC.start()
      end
      $stderr.debugPuts(__FILE__, __method__, "TIMING", "each() finished, all annos Time to generate data: #{Time.now - t1}secs")
    end
    
    def yieldTrackData(gcIter)
      eachChunkForFtypeId(@ftypeId) { |line|
        @totalBytesSent += line.size
        #$stderr.debugPuts(__FILE__, __method__, ">>>>>", "  Yielding chunk of #{line.size} bytes (yieldBuffSize = #{@yieldBuffSize.inspect}; cummulatively sent: #{@totalBytesSent}) bytes to eventmachine.")     #* Mem before yield: #{BRL::Util::MemoryInfo.getMemUsageStr}"
        yield line
        # Ensure we use MAX_BUFFER_SIZE after the first chunk (first chunk uses FIRST_CHUNK_BUFFER_SIZE)
        @yieldBuffSize = MAX_BUFFER_SIZE
        @currAdler32 = BRL::Util::CheckSumUtil.updateAdler32(line, @currAdler32)
        #$stderr.puts "     Mem after yield: #{BRL::Util::MemoryInfo.getMemUsageStr}"
        newGcIter = (@totalBytesSent / PAUSE_SIZE).floor
        if(newGcIter > gcIter)
          $stderr.debugPuts(__FILE__, __method__, ">>>>>", "   We have sent #{@totalBytesSent.inspect} bytes. Doing GC every #{PAUSE_SIZE} btyes.")
          gcIter = newGcIter
          #sleep(PAUSE_LENGTH)
          GC.start()
          #$stderr.debugPuts(__FILE__, __method__, ">>>>>", "   ...slept for #{PAUSE_LENGTH} secs and completed GC.")
        end
      }
    end
    
    def setUpHelperVars(ftypeId)
      @ftypeId = ftypeId
      setClassName(@ftypeId)
      allFrefRecords = @dbu.selectAllRefNames()
      allFrefRecords.each { |record|
        @frefHash[record['rid'].to_i] = record['rlength'].to_i
        @frefNameHash[record['rid'].to_i] = record['refname']
        @frefInvertHash[record['refname']] = record['rid'].to_i
      }
      @nameFilter = @formatOptions['nameFilter'] if(!@formatOptions['nameFilter'].nil? and !@formatOptions['nameFilter'].empty?)
      @emptyScoreValue = ( !@formatOptions['emptyScoreValue'].nil? and !@formatOptions['emptyScoreValue'].empty? ) ? @formatOptions['emptyScoreValue'] : nil
      @aggFunction = @formatOptions['spanAggFunction']
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@aggFunction: #{@aggFunction.inspect}")
      @emptyScoreValue.strip! if(!@emptyScoreValue.nil?)
      # set up score hash if probe/score file parameter provided
      if(!@formatOptions['scoreFile'].nil? and !@formatOptions['scoreFile'].empty?)
        reader = BRL::Util::TextReader.new(@formatOptions['scoreFile'])
        reader.each_line { |line|
          next if(line.nil? or line.empty? or line =~ /^\s*$/)
          data = line.split(/\s+/)
          @scoreFileHash[data[0]] = data[1]
        }
      end
      @trackWideMinScore = @dbu.selectMinScoreByFtypeId(ftypeId).first['minFscore']
      @trackWideMaxScore = @dbu.selectMaxScoreByFtypeId(ftypeId).first['maxFscore']
      @ftypeCount = @dbu.selectFtypeCountByFtypeid(@ftypeId)
      if(!@ftypeCount.nil? and !@ftypeCount.empty?)
        @ftypeCount = @ftypeCount[0]['numberOfAnnotations'].to_i
      else
        @ftypeCount = 0
      end
      attNames = @dbu.selectAttNameIdAndAttNameByFtypeId(ftypeId)
      attNames.each { |rec|
        @attNamesHash[rec['attNameId'].to_i] = rec['name']
        @attIdArray.push(rec['attNameId'].to_i)
      }
      @isHdhv = @dbu.isHDHV?(@ftypeId)
    end

    Landmark = Struct.new(:ridRow, :start, :stop, :refname) # refname is optional and sometimes left out
    # Provides part of the file, line by line, for the specified track,
    # iterating through the entrypoints.
    # Uses @landmark if it's set.
    #
    # [+ftypeId+]   FtypeId of the track
    def eachChunkForFtypeId(ftypeId)
      # Set the instance variables which may be required by subclasses
      setUpHelperVars(ftypeId)
      raise "This track was not uploaded as VCF and therefore cannot be downloaded as VCF." if(@isHdhv and @hdhvType == 'vcf')
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading track: #{@ftypeHash['fmethod']}:#{@ftypeHash['fsource']} with spanAgg: #{@formatOptions['spanAggFunction'].inspect} [#{File.basename(__FILE__)}:#{__LINE__}] ; scoreTrack if any? #{(!@formatOptions['scoreTrack'].nil? and !@formatOptions['scoreTrack'].empty?) ? @formatOptions['scoreTrack'].inspect : 'no scoreTrack'}")
      ep, start, stop = nil
      allRidRows = []
      makeFtypeAttributesHash(ftypeId)
      # Add the track header if the flag has been set in initialize
      yield makeTrackHead() if(@showTrackHead and self.respond_to?(:makeTrackHead))
      # Add column header line if the flag has been sent in initialize
      yield colHeaderLine() if(@showColumnHeader)
      # parse landmarks
      #  nil - do all chromosome
      #  no start or stop - do the whole chromosome
      #  start or stop - use the binning way
      
      if(@landmark.nil? or @landmark.empty?)
        # get all the entrypoints for the ftype
        roiTrackFtypeId = nil
        if(@isHdhv)
          if(!@formatOptions['ROITrack'].nil? and !@formatOptions['ROITrack'].empty?)
            allRidRows = getRequiredRidsForROI()
          else # No ROI Track provided. Regular download
            if(@emptyScoreValue.nil?)
              allRidRows = @dbu.selectDistinctRidsByFtypeIdForBlockLevelData(ftypeId)
            else
              allRidRows = @dbu.selectAllRefNames()
            end
          end
        else
          if(!@formatOptions['ROITrack'].nil? and !@formatOptions['ROITrack'].empty?)
            allRidRows = getRequiredRidsForROI()
            if(@formatOptions['INTERNAL'])
              @dbuScore = @dbu.dup()
              @dbu = @dbuROI.dup()
              @scoreTrackFtypeId = ftypeId
              ftypeId = @roiTrackFtypeId
              @formatOptions['scoreTrack'] = "#{@ftypeHash['fmethod']}:#{@ftypeHash['fsource']}"
            else
              @formatOptions['scoreTrack'] = "#{@ftypeHash['fmethod']}:#{@ftypeHash['fsource']}"
              @formatOptions['INTERNAL'] = true
              addScoresToROIFromDiffHost(allRidRows, ftypeId) { |chunk| yield chunk }
              allRidRows.clear()
              @formatOptions.delete('INTERNAL')
              @formatOptions.delete('scoreTrack')
              return # We are done at this point. 
            end
          else
            if(!@nameFilter.nil?)
              allRidRows = @dbu.selectDistinctRidsByFtypeIdAndGname(ftypeId, @nameFilter)
            else
              if(@emptyScoreValue.nil?)
                allRidRows = @dbu.selectDistinctRidsByFtypeId(ftypeId)
              else
                allRidRows = @dbu.selectAllRefNames()
              end
            end
            #allRidRows = @nameFilter.nil? ? @dbu.selectDistinctRidsByFtypeId(ftypeId) : @dbu.selectDistinctRidsByFtypeIdAndGname(ftypeId, @nameFilter)
          end
        end
        # The ROI was in the payload. DO NOT loop over rids
        # This is basically a proxied request to make the ROI come from the original host
        if(@formatOptions['hasROIInPayload'])
          # First check if the score track is high density or not
          #trackObj = BRL::Genboree::Abstract::Resources::Track.new(@dbu, @refSeqId, @ftypeHash['fmethod'], @ftypeHash['fsource'])
          if(@dbu.isHDHV?(ftypeId))
            @scoreTrkIsHdhv = true
            @hdhvObj = BRL::Genboree::Hdhv.new(@dbu.dataDbName, ftypeId)
          else
            @formatOptions['scoreTrack'] = "#{@ftypeHash['fmethod']}:#{@ftypeHash['fsource']}"
            @formatOptions['INTERNAL'] = true
          end
          fdata2Recs = []
          roiData = @formatOptions['roiData']
          roiData.each_line { |line|
            fdata2Recs = addToFdataRecs(fdata2Recs, line)
            # Process 500 records at a time
            if(fdata2Recs.size >= 500)
              rowsStart = fdata2Recs[0]['fstart']
              rowsStop = fdata2Recs[-1]['fstop']
              if(@scoreTrkIsHdhv)
                @hdhvObj.getScoreByRidWithROI(fdata2Recs, @formatOptions['payloadROIRID'], @hdhvType, @formatOptions) { |blockData|
                  yield blockData
                } 
              else
                @dbu.eachBlockOfFdataByLandmark(@formatOptions['payloadROIRID'], ftypeId, rowsStart, rowsStop, columns='fstart,fstop,fscore', 0, blockSize=20_000) { |blockRecs| # actually fdata2 recs, trying to simulate same flow when the score track is high density
                  emitRecsWithLiftedScores(blockRecs, fdata2Recs) { |chunk| yield chunk }
                }                  
              end
              fdata2Recs = []
            end
          }
          if(!fdata2Recs.empty?)
            rowsStart = fdata2Recs[0]['fstart']
            rowsStop = fdata2Recs[-1]['fstop']
            if(@scoreTrkIsHdhv)
              @hdhvObj.getScoreByRidWithROI(fdata2Recs, @formatOptions['payloadROIRID'], @hdhvType, @formatOptions) { |blockData|
                yield blockData
              } 
            else
              @dbu.eachBlockOfFdataByLandmark(@formatOptions['payloadROIRID'], ftypeId, rowsStart, rowsStop, columns='fstart,fstop,fscore', 0, blockSize=20_000) { |blockRecs| # actually fdata2 recs, trying to simulate same flow when the score track is high density
                emitRecsWithLiftedScores(blockRecs, fdata2Recs) { |chunk| yield chunk }
              }
            end
            fdata2Recs.clear
          end
          # clean HDHV resources (prevent leaking memory and database connections)
          if(@hdhvObj)
            @hdhvObj.clear() 
          else
            @formatOptions.delete('INTERNAL')
            @formatOptions.delete('scoreTrack')
          end
        else
          allRidRows.each {|ridRow|
            #$stderr.debugPuts(__FILE__, __method__, ">>>>>", "  Now doing this chr record:\n     #{ridRow.inspect}")
            if(@hdhvType == "fixedStep" or @hdhvType == "variableStep")
              eachChunkForChromosome(ridRow, start, stop, ftypeId) { |line| yield line }
            else
              if(@formatOptions['desiredSpan'].nil?)
                eachChunkForChromosome(ridRow, start, stop, ftypeId) { |line| yield line }
              else
                if(@formatOptions['desiredSpan'] < 1)
                  @error = BRL::Genboree::GenboreeError.new(:'Bad Request', 'requested span less than 1')
                else
                  eachChunkForChromosomeWithSpan(ridRow, start, stop, ftypeId) { |line| yield line }
                  eachChunkForChromosome(ridRow, start, stop, ftypeId) { |line| yield line }
                end
              end
            end
            if(@formatOptions['emptyScoreValue'] and !@formatOptions['nameFilter'])
              # Do nothing
            else
              yieldLastChunk(@hdhvType, ridRow) {|line| yield line}
            end
          }
        end
      else
        # landmark could contain multiple chromosomes with different start and stops
        landmarks = @landmark.strip.split(',')
        # Save actual Landmark instances in here:
        @landmarks = []
        landmarks.each { |lm|
          lm =~ /([^: ]+)\s*(?:\:\s*(\d+))?(?:\:?\s*-\s*(\d+))?/
          ep, start, stop = $1, $2, $3
          ridRows = @dbu.selectFrefsByName(ep, true)
          if(!ridRows.nil? and !ridRows.empty?)
            firstRow = ridRows.first
            firstRid = firstRow['rid'].to_i
            firstRefname = @frefNameHash[firstRid]
            lm = Landmark.new(firstRow, start.to_i, stop.to_i, firstRefname)
            # Make adjustments to start & stop etc if needed:
            chromLen = @frefHash[firstRid]
            lm.start = 1 if(lm.start <= 0)
            lm.stop = chromLen if(lm.stop <= 0 or lm.stop > chromLen)
            lm.start, lm.stop = lm.stop, lm.start if(lm.start > lm.stop)
            @landmarks << lm
          else
            @error = BRL::Genboree::GenboreeError.new(:'Bad Request', 'Unknown entrypoint')
          end
        }
        @landmarks.each { |lm|
          if(@hdhvType == "fixedStep" or @hdhvType == "variableStep")
            eachChunkForChromosome(lm.ridRow, lm.start, lm.stop, ftypeId) { |line| yield line }
          else
            if(@formatOptions['desiredSpan'].nil?)
              eachChunkForChromosome(lm.ridRow, lm.start, lm.stop, ftypeId) { |line| yield line }
            else
              if(@formatOptions['desiredSpan'] < 1)
                @error = BRL::Genboree::GenboreeError.new(:'Bad Request', 'requested span less than 1')
              else
                eachChunkForChromosomeWithSpan(lm.ridRow, lm.start, lm.stop, ftypeId) {|line| yield line}
                eachChunkForChromosome(lm.ridRow, lm.start, lm.stop, ftypeId) {|line| yield line}
              end
            end
          end
          if(@formatOptions['emptyScoreValue'] and !@formatOptions['nameFilter'])
            # Do nothing
          else
            yieldLastChunk(@hdhvType, lm.ridRow) {|line| yield line}
          end
        }
      end
      # loop through the entrypoints
      allRidRows.clear if(allRidRows)
    end
    
    def addToFdataRecs(fdata2Recs, line)
      case @hdhvType
      when "lff"
        fdata2Recs << makeLFFHash(line)
      when "bed"
        fdata2Recs << makeBEDHash(line)
      when "bedGraph"
        fdata2Recs << makeBedGraphHash(line)
      when "gff3"
        fdata2Recs << makeGFF3Hash(line)
      when "gff"
        fdata2Recs << makeGFFHash(line)
      when "gtf"
        fdata2Recs << makeGTFHash(line)
      end
      return fdata2Recs
    end
    
    def addScoresToROIFromDiffHost(ridRows, ftypeId)
      fdata2Recs = []
      trackName = @formatOptions['ROITrack'].keys[0]
      apiCaller = @formatOptions['extTrackApiObj'][trackName]
      # We need to make an API call to download the annotations for the track and then feed that to the hdhv method
      # We will collect 500 records of lff at at time and pass that onto the hdhv function.
      extTrkUri = @formatOptions['extTrackURI']
      uri = URI.parse(extTrkUri)
      ridRows.each {|ridRow|
        rsrcPath = @nameFilter.nil? ? "#{uri.path.chomp('?')}/annos?format=#{@formatOptions['repFormat']}&landmark=#{@frefNameHash[ridRow['rid'].to_i]}" : "#{uri.path.chomp('?')}/annos?format=#{@formatOptions['repFormat']}&nameFilter=#{@nameFilter}"
        rsrcPath << "&gbKey=#{@dbApiHelper.extractGbKey(extTrkUri)}" if(@dbApiHelper.extractGbKey(extTrkUri))
        apiCaller.setRsrcPath(rsrcPath)
        orphan = nil
        apiCaller.get() { |chunk|
          chunk.each_line { |line|
            next if(line.nil? or line.empty? or line =~ /^#/ or line =~ /^\s*$/)
            if(!orphan.nil?)
              line = orphan + line
              orphan = nil
            end
            if(line =~ /\n$/) # line is complete
              fdata2Recs = addToFdataRecs(fdata2Recs, line)
              # Process 500 records at a time
              if(fdata2Recs.size >= 500)
                rowsStart = fdata2Recs[0]['fstart']
                rowsStop = fdata2Recs[-1]['fstop']
                @dbu.eachBlockOfFdataByLandmark(ridRow['rid'], ftypeId, rowsStart, rowsStop, columns='fstart,fstop,fscore', 0, blockSize=20_000) { |blockRecs| # actually fdata2 recs, trying to simulate same flow when the score track is high density
                  yield emitRecsWithLiftedScores(blockRecs, fdata2Recs)
                }  
                fdata2Recs.clear
              end
            else # save orphan
              orphan = line
            end
          }
        }
        if(!fdata2Recs.empty?)
          rowsStart = fdata2Recs[0]['fstart']
          rowsStop = fdata2Recs[-1]['fstop']
          @dbu.eachBlockOfFdataByLandmark(ridRow['rid'], ftypeId, rowsStart, rowsStop, columns='fstart,fstop,fscore', 0, blockSize=20_000) { |blockRecs| # actually fdata2 recs, trying to simulate same flow when the score track is high density
            yield emitRecsWithLiftedScores(blockRecs, fdata2Recs)
          }  
          fdata2Recs.clear
        end
      }
    end
    
    def emitRecsWithLiftedScores(blockRecs, fdata2Recs)
      buffer = ''
      initStructArray(fdata2Recs.size)
      iterOverRegionsAndUpdateAggs(blockRecs, fdata2Recs)
      # We will loop over this array of structs and construct our lines
      rowCount = 0
      fdata2Recs.each { |rowObj|
        buffer << constructAnnoLine(rowObj, rowCount)
        if(buffer.size > @yieldBuffSize)
          yield buffer
          buffer = ''
        end
        rowCount += 1
      }
      if(!buffer.empty?)
        yield buffer
      end
      buffer = ''
      # Clean the @structArray as it can take up a lot of memory
      cleanStructArray()
    end
    
    def constructAnnoLine(rowObj, rowCount)
      annoLine = ""
      fscore = getScore(rowObj, rowCount)
      fscore = @emptyScoreValue if(!fscore and @emptyScoreValue)
      chr = rowObj['chr']
      fstart = rowObj['fstart']
      fstop = rowObj['fstop']
      name = rowObj['name']
      strand = rowObj['strand']
      fclass = ""
      type = ""
      subtype = ""
      phase = ""
      case @hdhvType
      when "lff"
        fclass = rowObj['class']
        type = rowObj['type']
        subtype = rowObj['subtype']
        phase = rowObj['phase']
        annoLine << "#{fclass}\t#{name}\t#{type}\t#{subtype}\t#{fstart}\t#{fstop}\t#{strand}\t#{phase}\t#{fscore}"
        annoLine << "\t#{rowObj['qstart']}" if(rowObj['qstart'])
        annoLine << "\t#{rowObj['qstop']}" if(rowObj['qstop'])
        annoLine << "\t#{rowObj['avp']}" if(rowObj['avp'])
        annoLine << "\t#{rowObj['seq']}" if(rowObj['seq'])
        annoLine << "\t#{rowObj['comments']}" if(rowObj['comments'])
        annoLine << "\n"
      when "bed"
        annoLine << "#{chr}\t#{fstart.to_i - 1}\t#{fstop}\t#{name}\t#{fscore}\t#{strand}\n"
      when "bedGraph"
        annoLine << "#{chr}\t#{fstart.to_i - 1}\t#{fstop}\t#{fscore}\n"
      when "gff3"
        annoLine << "#{rowObj['chr']}\t#{rowObj['type']}\t#{rowObj['subtype']}\t#{rowObj['fstart']}\t#{rowObj['fstop']}\t#{fscore}"
        annoLine << "#{rowObj['strand']}\t#{rowObj['phase']}"
        if(!rowObj['avp'].nil? and !rowObj['avp'].empty?)
          annoLine << "\t#{rowObj['avp']}"
        end
        annoLine << "\n"
      when "gff"
        annoLine << "#{rowObj['chr']}\t#{rowObj['type']}\t#{rowObj['subtype']}\t#{rowObj['fstart']}\t#{rowObj['fstop']}\t#{fscore}\t#{rowObj['strand']}\t#{rowObj['phase']}\t#{rowObj['name']}\n"
      when "gtf"
        annoLine << "#{rowObj['chr']}\t#{rowObj['type']}\t#{rowObj['subtype']}\t#{rowObj['fstart']}\t#{rowObj['fstop']}\t#{fscore}\t#{rowObj['strand']}\t#{rowObj['phase']}\t#{rowObj['avp']}\n"
      end
      return annoLine
    end
    
    def getRequiredRidsForROI()
      allRidRows = nil
      if(@formatOptions['INTERNAL'])
        @dbuROI = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil) if(@dbuROI.nil?)
        trackName = @formatOptions['ROITrack'].keys[0]
        roiFmethod, roiFsource = trackName.split(":")
        refSeqIdROITrack = @formatOptions['ROITrack'][trackName]
        trackObj = BRL::Genboree::Abstract::Resources::Track.new(@dbuROI, refSeqIdROITrack, roiFmethod, roiFsource)
        dbRec = trackObj.getDbRecWithData()
        @roiTrackFtypeId = dbRec['ftypeid'].to_i
        @dbuROI.setNewDataDb(dbRec['dbName'])
        allRidRows = @nameFilter.nil? ? @dbuROI.selectDistinctRidsByFtypeId(@roiTrackFtypeId) : @dbuROI.selectDistinctRidsByFtypeIdAndGname(@roiTrackFtypeId, @nameFilter)
      else # Make an API call to get the entrypoints/chromosomes
        trackName = @formatOptions['ROITrack'].keys[0]
        apiCaller = @formatOptions['extTrackApiObj'][trackName]
        extTrkUri = @formatOptions['extTrackURI']
        uri = URI.parse(extTrkUri)
        rsrcPath = @nameFilter.nil? ? "#{uri.path.chomp('?')}/eps?" : "#{uri.path.chomp('?')}/eps?nameFilter=#{@nameFilter}"
        apiCaller.setRsrcPath(rsrcPath)
        apiCaller.get()
        retVal = apiCaller.parseRespBody()['data']['entrypoints']
        retVal.each { |chr|
          allRidRows << {'rid' => @frefInvertHash[chr['name']], 'length' => chr['length']}
        }
      end
      return allRidRows
    end

    def yieldZoomLevels(ridRow, ftypeId)
      zoomLevelRecs = @dbu.selectZoomLevelsByRidAndFtypeid(ridRow['rid'], ftypeId)
      lines = ""
      zoomLevelRecs.each {|zoomRecord|
        lines << "#{zoomRecord['id']}\t#{zoomRecord['level']}\t#{zoomRecord['fstart']}\t#{zoomRecord['fstop']}\t#{zoomRecord['scoreCount']}\t#{zoomRecord['scoreSum']}\t#{zoomRecord['scoreMax']}\t#{zoomRecord['scoreMin']}\t#{zoomRecord['scoreSumOfSquares']}\t#{zoomRecord['negScoreCount']}\t#{zoomRecord['negScoreSum']}\t#{zoomRecord['negScoreSumOfSquares']}\n"
        if(lines.size >= MAX_BUFFER_SIZE)
          yield lines
          lines = ""
        end
      }
      if(!lines.empty?)
        yield lines
      end
    end

    # Provides part of the file, line by line, for the specified track and chromosome
    #
    # Uses Hdhv if the track is 'blockBased'
    #
    # [+ridRow+]    DBI::Row object from fref table
    # [+start+]     Start position of landmark
    # [+stop+]      Stop position of landmark
    # [+ftypeId+]   FtypeId of the track
    def eachChunkForChromosome(ridRow, start, stop, ftypeId)
      buffer = ''
      if(@isHdhv) # For HDHV tracks
        # Only bed or wig formats are allowed for blockBased data
        if(@hdhvType.empty?)
          @error = BRL::Genboree::GenboreeError.new(:'Bad Request', '')
        elsif(@hdhvType == 'zoomLevels')
          yieldZoomLevels(ridRow, ftypeId) { |chunk| yield chunk }
        else
          @hdhvObj = BRL::Genboree::Hdhv.new(@dbu.dataDbName, ftypeId)
          if(!@formatOptions.has_key?("ROITrack")) # No ROI track provided
            start = 1 if(start.nil?)
            stop = @frefHash[ridRow['rid'].to_i] if(stop.nil?)
            tt = Time.now
            begin
              @hdhvObj.getScoreByRid(ridRow['rid'], start, stop, @hdhvType, nil, @formatOptions) { |blockData| # line is actually a chunk of lines
                yield blockData
              }
            rescue => err
              @hdhvObj.binReader.close() if(@hdhvObj.binReader and @hdhvObj.binReader.is_a?(IO) and !@hdhvObj.binReader.closed?)
              raise err # Raise it back to the main exception handling in each()
            end
            @funcTime += Time.now - tt
          else # ROI Track has been provided
            # For a case where both ROI and score track are on the same machine
            if(@formatOptions['INTERNAL'])
              trackName = @formatOptions['ROITrack'].keys[0]
              roiFmethod, roiFsource = trackName.split(":")
              refSeqId = @formatOptions['ROITrack'][trackName]
              trackObj = BRL::Genboree::Abstract::Resources::Track.new(@dbuROI, refSeqId, roiFmethod, roiFsource)
              dbRecs = trackObj.getDbRecsWithData()
              begin
                dbRecs.each { |db|
                  @dbuROI.setNewDataDb(db['dbName'])
                  roiFtypeId = db['ftypeid'].to_i
                  if(@nameFilter.nil?)
                    @dbuROI.eachBlockOfFdataColsByFtypeidAndRid(roiFtypeId, ridRow['rid'], columns='fstart, fstop', BRL::Genboree::DBUtil::FWD_ORDER, 1_000, true) { |fdata2Recs|
                      next if(fdata2Recs.nil? or fdata2Recs.empty?)
                      @hdhvObj.getScoreByRidWithROI(fdata2Recs, ridRow['rid'], @hdhvType, @formatOptions) { |blockData|
                        yield blockData
                      }
                    }
                  else
                    fdata2Recs = @dbuROI.selectFdataCoordByExactGname(roiFtypeId, @nameFilter, 0, true)
                    if(!fdata2Recs.nil? and !fdata2Recs.empty?)
                      @hdhvObj.getScoreByRidWithROI(fdata2Recs, ridRow['rid'], @hdhvType, @formatOptions) { |blockData|
                        yield blockData
                      }
                    end
                  end
                }
                @hdhvObj.closeFileHandles()
              rescue => err
                @hdhvObj.closeFileHandles()
                raise err # Raise it back to the main exception handling in each()
              end
            else # For cases where the ROI and score track are on different machines and the ROI is coming from a different host
              #$stderr.debugPuts(__FILE__, __method__, "STATUS", "ROI coming from a different host...")
              fdata2Recs = []
              trackName = @formatOptions['ROITrack'].keys[0]
              apiCaller = @formatOptions['extTrackApiObj'][trackName]
              # We need to make an API call to download the annotations for the track and then feed that to the hdhv method
              # We will collect 500 records of lff at at time and pass that onto the hdhv function.
              extTrkUri = @formatOptions['extTrackURI']
              uri = URI.parse(extTrkUri)
              rsrcPath = @nameFilter.nil? ? "#{uri.path.chomp('?')}/annos?format=#{@formatOptions['repFormat']}&landmark=#{@frefNameHash[ridRow['rid'].to_i]}" : "#{uri.path.chomp('?')}/annos?format=#{@formatOptions['repFormat']}&nameFilter=#{@nameFilter}"
              rsrcPath << "&gbKey=#{@dbApiHelper.extractGbKey(extTrkUri)}" if(@dbApiHelper.extractGbKey(extTrkUri))
              apiCaller.setRsrcPath(rsrcPath)
              orphan = nil
              apiCaller.get() { |chunk|
                chunk.each_line { |line|
                  next if(line.nil? or line.empty? or line =~ /^#/ or line =~ /^\s*$/)
                  if(!orphan.nil?)
                    line = orphan + line
                    orphan = nil
                  end
                  if(line =~ /\n$/) # line is complete
                    fdata2Recs = addToFdataRecs(fdata2Recs, line)
                    # Process 500 records at a time
                    if(fdata2Recs.size >= 500)
                      @hdhvObj.getScoreByRidWithROI(fdata2Recs, ridRow['rid'], @hdhvType, @formatOptions) { |blockData|
                        yield blockData
                      } 
                      fdata2Recs.clear
                    end
                  else # save orphan
                    orphan = line
                  end
                }
              }
              if(!fdata2Recs.empty?)
                @hdhvObj.getScoreByRidWithROI(fdata2Recs, ridRow['rid'], @hdhvType, @formatOptions) { |blockData|
                  yield blockData
                } 
                fdata2Recs.clear
              end
            end
          end
          # clean HDHV resources (prevent leaking memory and database connections)
          @hdhvObj.clear() if(@hdhvObj)
        end
      else # For regular tracks (fdata2)
        if(@hdhvType == "fixedStep" or @hdhvType == "variableStep") # For wig format
          eachChunkFromFdata(ridRow, start, stop, ftypeId) { |line| yield line }
        else # For non wig format
          if(@formatOptions['desiredSpan'].nil?)
            eachChunkFromFdata(ridRow, start, stop, ftypeId) { |line| yield line }
          else
            if(@formatOptions['desiredSpan'] < 1)
              @error = BRL::Genboree::GenboreeError.new(:'Bad Request', 'requested span less than 1')
            else
              eachChunkFromFdataWithSpan(ridRow, start, stop, ftypeId) { |line| yield line }
            end
          end
        end
      end
    end


    # Provides part of the file getting the annotation data from fdata2,
    # line by line, for the specified track and chromosome.
    #
    # Override this method if the annotation file require specific formatting,
    # See Abstract::Resource::WigFile as an example.
    #
    # [+ridRow+]    DBI::Row object from fref table
    # [+start+]     Start position of landmark
    # [+stop+]      Stop position of landmark
    # [+ftypeId+]   FtypeId of the track
    def eachChunkFromFdata(ridRow, start, stop, ftypeId)
      chunkSize = computeChunkSize()
      # Check if score track is provided
      @scoreTrackFtypeId = @dbName = nil if(@dbuScore.nil?)
      blockRecsSize = 0
      # Set up the hdhv object if score track has been provided and the score track resides on the same machine.
      if(!@formatOptions['scoreTrack'].nil? and !@formatOptions['scoreTrack'].empty? and @formatOptions['INTERNAL'] )
        gc = BRL::Genboree::GenboreeConfig.load
        if(@dbuScore.nil?)
          @dbuScore = BRL::Genboree::DBUtil.new("#{gc.dbrcKey}", nil, nil)
          scoreTrack = @formatOptions['scoreTrack']
          trackName = @formatOptions['scoreTrack'].keys[0]
          scoreFmethod, scoreFsource = trackName.split(":")
          refSeqIdScoreTrack = @formatOptions['scoreTrack'][trackName]
          trackObj = BRL::Genboree::Abstract::Resources::Track.new(@dbuScore, refSeqIdScoreTrack, scoreFmethod, scoreFsource)
          dbRecs = trackObj.dbRecs
          dbRecs.each {|dbRec|
            if(dbRec['dbType'] == :userDb)
              @dbName = dbRec['dbName']    
              @scoreTrackFtypeId = dbRec['ftypeid'].to_i
              break
            end
          }
          @dbuScore.setNewDataDb(@dbName)
          scoreFrefRecords = @dbuScore.selectAllRefNames()
          scoreFrefRecords.each { |record|
            @scoreTrackFrefHash[record['refname']] = record['rid'].to_i
          }
          @scoreTrkIsHdhv = trackObj.isHdhv? ? true : false
        end
        @hdhvObj = ( @scoreTrkIsHdhv ? BRL::Genboree::Hdhv.new(@dbName, @scoreTrackFtypeId) : nil )
      else
        @hdhvObj = nil
      end
      begin
        # If 'nameFilter' parameter present, no need to get chunks of fdata2
        # Get all the records at once (for that 'gname')
        if(!@formatOptions['nameFilter'].nil? and !@formatOptions['nameFilter'].empty?)
          annoDataRows = @dbu.selectFdata2ByRidAndFtypeIdAndGnameOrderedByCoord( ridRow['rid'], ftypeId, @formatOptions['nameFilter'], true )
          if(!annoDataRows.nil? and !annoDataRows.empty?)
            yieldRegions(ridRow, start, stop, ftypeId, annoDataRows) { |regions| yield regions }
          end
        # if nameFilter not present, we must get chunks of fdata2 recs and loop over them
        else
          start, stop = 1, nil if(@landmarks) # walk through whole genome, but return records falling in 1+ landmarks
          @dbu.selectFdataInChunks(ftypeId, ridRow['rid'], @frefHash[ridRow['rid']], @fdataFields, 0, start, stop, chunkSize, true) { |annoDataRows|
            next if(annoDataRows.nil? or annoDataRows.empty?)
            yieldRegions(ridRow, start, stop, ftypeId, annoDataRows) { |regions| yield regions }
          }
        end
        if(@hdhvObj)
          @hdhvObj.closeFileHandles()
          @hdhvObj.closeBuffers()
        end
      rescue => err
        @hdhvObj.closeFileHandles() if(@hdhvObj)
        raise err # Raise it back to the main exception handling block in each()
      end
      # clean HDHV resources (prevent leaking memory and database connections)
      @hdhvObj.clear() if(@hdhvObj)
    end
    
    def yieldRegions(ridRow, start, stop, ftypeId, annoDataRows)
      buffer = ""
      
      initStructArray(annoDataRows.size)
      # First, if we have landmarks, is this current chunk of rows even relevant?
      # - must overlap at least one landmark before we bother looking at each row and doing more work
      # - NOTE: better approach would likely be to loop over landmarks or fragments within large landmarks
      #   but this current is at least compatible with this chromosome-based fragment looping approach. Doesn't seem too slow,
      #   even where there are lots of landmarks (as "select all" chroms in the UI actually does!)

      refname = @frefNameHash[annoDataRows[0]['rid']]
      rowsStart = annoDataRows[0]['fstart'].to_i  # start coord of the chunk
      rowsStop = annoDataRows[-1]['fstop'].to_i   # end coord of the chunk
      if(@landmarks)
        rowsTouchLm = false
        @landmarks.each { |lm|
          if(refname == lm.refname)
            rowsTouchLm = (rowsStart <= lm.stop and lm.start <= rowsStop)
            break if(rowsTouchLm)
          end
        }
        return "" unless(rowsTouchLm) # Skip if we do not have the landmarks touching the current fdata2 chunk
      end
      initHashesAndArrays()
      if(FORMATS_WITH_AVPS.key?(@hdhvType))
        annoDataRows.each { |rowObj|
          fid = rowObj['fid'].to_i
          @fidArray.push(fid)
        }
      end
      # If 'scoreTrack' is provided, we will need to get chunks of blockLevel records for the current fdata2 chunk of records
      # and process one chunk at a time.
      if(!@formatOptions['scoreTrack'].nil? and !@formatOptions['scoreTrack'].empty?)
        if(@formatOptions['INTERNAL']) # Score track is on the same host as the ROI
          @blockRecsFound = false
          if(@scoreTrkIsHdhv) # Score track is high density, get block level data
            @dbuScore.eachBlockOfBlockLevelDataInfoByLandmarkOrderedByCoord(@scoreTrackFrefHash[@frefNameHash[ridRow['rid'].to_i]], @scoreTrackFtypeId, rowsStart, rowsStop, blockSize=1000, true) { |blockRecs|
              iterOverRegionsAndUpdateAggs(blockRecs, annoDataRows)
            }
          else # Score track is NOT a high density track, get fdata2 records
            @dbuScore.eachBlockOfFdataByLandmark(ridRow['rid'], @scoreTrackFtypeId, rowsStart, rowsStop, columns='fstart,fstop,fscore', 0, blockSize=20_000) { |blockRecs| # actually fdata2 recs, trying to simulate same flow when the score track is high density
              iterOverRegionsAndUpdateAggs(blockRecs, annoDataRows)
            }
          end
          # Did we get ANY score data???? If not, we MUST process all the ROI annos in annoDataRows specifically to get missing values (if asked)
          unless(@blockRecsFound)
            setAVPs()
          end
          # We will loop over this array of structs and construct our lines
          rowCount = 0
          annoDataRows.each { |rowObj|
            buffer << addLiftedScores(rowObj, rowCount)
            if(buffer.size > @yieldBuffSize)
              @hdhvObj.closeFileHandles() if(@hdhvObj)
              yield buffer
              buffer = ''
            end
            rowCount += 1
          }
          if(!buffer.empty?)
            yield buffer
          end
          buffer = ''
          # Clean the @structArray as it can take up a lot of memory
          cleanStructArray()
        else # Score Track is on another host
          setAVPs()
          getScoresFromOtherHost(annoDataRows, ridRow) { |lines| yield lines }
        end
      else
        setAVPs()
        yieldLines(annoDataRows) { |lines| yield lines }
      end
    end

    def iterOverRegionsAndUpdateAggs(blockRecs, annoDataRows)
      @fdata2Index = 0 # For each chunk, set the index to 0. This is used for advancing the pointer to the correct fdata2 index while going through several chunks of blockLevel data
      @blockRecs = blockRecs
      castBlockLevelValues() if(@scoreTrkIsHdhv) # This casts all the blockLevelDataInfo values appropriately
      @blockRecsSize = @blockRecs.size
      # Needs to be reset to 0 for each chunk of blockLevel records
      @blockIndex = 0
      @blockRecsFound = true
      setAVPs()
      yieldLines(annoDataRows) { |lines| yield lines } # Will not yield lines. Only updates aggregates for the current chunk of fdata2 recs
    end
    
    def getScoresFromOtherHost(annoDataRows, ridRow)
      buffer = ""
      scoreTrackName = @formatOptions['scoreTrack'].keys[0]
      apiCaller = @formatOptions['extTrackApiObj'][scoreTrackName]
      extTrkUri = @formatOptions['extTrackURI']
      extTrkGbKey = @formatOptions['extTrkGbKey']
      uri = URI.parse(extTrkUri)
      rsrcPath = "#{uri.path.chomp('?')}/annos?format=#{@formatOptions['repFormat'].to_s.downcase}&hasROIInPayload=true&ucscTrackHeader=false&payloadROIRID=#{ridRow['rid']}"
      rsrcPath << "&spanAggFunction=#{@formatOptions['spanAggFunction']}" if(@formatOptions['spanAggFunction'])
      rsrcPath << "&emptyScoreValue=#{@emptyScoreValue}" if(@emptyScoreValue)
      rsrcPath << "&#{extTrkGbKey}" if(!extTrkGbKey.nil? and !extTrkGbKey.empty?)
      rsrcPath << "&addCRC32Line=true" if(@formatOptions['addCRC32Line'] == 'true')
      apiCaller.setRsrcPath(rsrcPath)
      expNumLines = 0
      annoDataRows.each { |row|
        buffer << makeLine(row)
        expNumLines += 1
        if(buffer.size >= @yieldBuffSize)
          connectionAttempt = 0
          adlerFound = false
          chunkBuffer = ""
          if(@formatOptions['addCRC32Line'] == 'true')
            while(!adlerFound and connectionAttempt < apiCaller.maxTimeoutRetry)
              chunkBuffer = ""
              connectionAttempt += 1
              apiCaller.get(nil, buffer) { |chunk|
                chunkBuffer << chunk
              }
              if(chunkBuffer.hasAdler?)
                yield chunkBuffer.stripAdler32
                adlerFound = true
                expNumLines = 0
              else
                sleepTime = (apiCaller.sleepBase * connectionAttempt**2)
                $stderr.debugPuts(__FILE__, __method__, "REATTEMPTING", "A. Failed to download score track from remote host after attempt# #{connectionAttempt} (Max attempt count: #{apiCaller.maxTimeoutRetry}). Will re-attempt after sleeping for #{sleepTime} sec")
                sleep(sleepTime)
              end
            end
            raise ("FINAL Connection Attempt # #{connectionAttempt}\n#{chunkBuffer}") unless(adlerFound) # Something is wrong. Raise the chunk of data received from the remote server. It may contain more info.
          else
            apiCaller.get(nil, buffer) { |chunk|
              yield chunk
            }
          end
          buffer = ''
        end
      }
      if(!buffer.empty?)
        if(@formatOptions['addCRC32Line'] == 'true')
          adlerFound = false
          chunkBuffer = ""
          connectionAttempt = 0
          while(!adlerFound and connectionAttempt < apiCaller.maxTimeoutRetry)
            chunkBuffer = ""
            connectionAttempt += 1
            apiCaller.get(nil, buffer) { |chunk|
              chunkBuffer << chunk
            }
            if(chunkBuffer.hasAdler?)
              yield chunkBuffer.stripAdler32
              adlerFound = true
              expNumLines = 0
            else
              sleepTime = (apiCaller.sleepBase * connectionAttempt**2)
              $stderr.debugPuts(__FILE__, __method__, "REATTEMPTING", "B. Failed to download score track from remote host after attempt# #{connectionAttempt} (Max attempt count: #{apiCaller.maxTimeoutRetry}). Will re-attempt after sleeping for #{sleepTime} sec")
              sleep(sleepTime)
            end
          end
          raise ("FINAL Connection Attempt # #{connectionAttempt}\n#{chunkBuffer}") unless(adlerFound) # Something is wrong. Raise the chunk of data received from the remote server. It may contain more info.
        else
          apiCaller.get(nil, buffer) { |chunk| yield chunk }
        end
        buffer = ''
      end
    end
    
    # Lifts score from a non high density score track for a single record of the regions-of-interest track
    # [blockRecs] fdata2 records (for the score track) for a chunk of fdata2 records (regions-of-interest)
    # [+fstart+] start coordinate of the annotation for the roi track
    # [+fstop+] stop coord of the annotation for the roi track
    # [+optsHash+]
    # [+blockIndex+] global index for fdata2 index for the score track
    # [+blockRecsSize+]
    # [+returns+] array: [blockIndex, score for the annotation or nil (for all NaNs)]
    def getScoreFromNonHDScrTrk(blockRecs, fstart, fstop, optsHash, blockIndex, blockRecsSize)
      fscore = nil
      currBlockRec = blockRecs[blockIndex]
      while(currBlockRec['fstart'] <= fstop and !(fstart <= currBlockRec['fstop'] and fstop >= currBlockRec['fstart']))
        blockIndex += 1
        break if(blockIndex >= blockRecsSize)
        currBlockRec = blockRecs[blockIndex]
      end
      if(blockIndex < blockRecsSize)
        currBlockIndex = blockIndex
        currBlock = blockRecs[currBlockIndex]
        blockStop = currBlock['fstop']
        blockStart = currBlock['fstart']
        blockScore = currBlock['fscore']
        while(fstop >= blockStart and fstart <= blockStop)
          bpStart = ( fstart >= blockStart ? fstart : blockStart)
          bpStop = ( fstop <= blockStop ? fstop : blockStop)
          numRecords = (bpStop - bpStart) + 1 ;   
          updateAggsForNonHDScrTrk(numRecords, blockScore)
          currBlockIndex += 1
          if(currBlockIndex < blockRecsSize)
            currBlock = blockRecs[currBlockIndex]
            blockStop = currBlock['fstop']
            blockStart = currBlock['fstart']
          else
            break
          end
        end # end while
      end
      return blockIndex
    end
    

    # Yield lines once the buffer size hits the max buffer size
    # [+yields+] lines (chunk of fdata2 rows) [May or may not have scores lifted from a score track]
    def yieldLines(annoDataRows)
      buffer = ''
      annoDataRows.each { |row|
        # If landmark, skip rows not falling within a landmark
        if(@landmarks)
          rowInLm = false
          rowRefname = @frefNameHash[row['rid']]
          rowStart = row['fstart'].to_i
          rowStop = row['fstop'].to_i
          @landmarks.each { |lm|
            # TODO: check only start and only stop
            # see about better solution, maybe filling in lm correctly at the beginning?
            if(rowRefname == lm.refname)
              rowInLm = (rowStart <= lm.stop and lm.start <= rowStop)
              break if(rowInLm)
            end
          }
          unless(rowInLm)
            next
          end
        end
        buffer << makeLine(row) # Will not yield lines if score track is present. Instead will update an array with aggregates (for computing final scores). In case of a regular download, will yield lines. Implemented by the child classes
        @fdata2Index += 1
        if(buffer.size > @yieldBuffSize)
          @hdhvObj.closeFileHandles() if(@hdhvObj)
          yield buffer
          buffer = ''
        end
      }
      yield buffer if(buffer.size > 0)
      buffer = ''
    end

    

    ##################################
    ## File (written IO obj) methods
    ##################################

    # [+trackList+] Array of track names
    # [+refSeqId+]  refseq ID of the database containing track
    # [+landmark+]  String containing the entrypoint, start and stop
    # [+returns+]   StringIO or File
    def writeAnnotationsForTrackNames(trackList, refSeqId, landmark=nil)
      setTrackList(trackList, refSeqId, landmark)
      @ftypeId = nil
      each { |line|
        @outObj << line
      }
      return @outObj
    end

    # [+trackName+] String
    # [+refSeqId+]  refseq ID of the database containing track
    # [+landmark+]  String containing the entrypoint, start and stop
    # [+returns+]   StringIO or File
    def writeAnnotationsForTrackName(trackName, refSeqId, landmark=nil)
      writeAnnotationsForTrackNames([trackName], refSeqId, landmark)
    end

    # [+ftypeId+]   FtypeId of the track
    # [+landmark+]  String containing the entrypoint, start and stop
    # [+returns+]   StringIO or File
    def writeAnnotationsForFtypeId(ftypeId, landmark=nil)
      setFtypeId(ftypeId, landmark)
      @trackList = nil
      each { |line|
        @outObj << line
      }
      return @outObj
    end

    def close()
      return @outObj.close
    end


    ###########################
    ## Helpers
    ###########################
    
    # This method sets the fileName instance variable.
    # If the fileName instance variable is set.  THe output will be written to file.
    def setOutputToFile(fileName)
      @fileName = fileName
      @bedIO = File.new(fileName, 'w')
    end

    def getIO
      return @outObj
    end
    
    def updateAggs(tempScore)
      case @formatOptions['spanAggFunction']
      when :med
        @bucket << tempScore
      when :avg
        @bucketSum +=  tempScore
        @bucketCount += 1
      when :max
        if(@bucketMax.nil?)
          @bucketMax = tempScore
        else
          @bucketMax = tempScore > @bucketMax ? tempScore : @bucketMax
        end
      when :min
        if(@bucketMin.nil?)
        else
          @bucketMin = tempScore < @bucketMin ? tempScore : @bucketMin
        end
      when :sum
        @bucketSum += tempScore
      when :count
        @bucketCount += 1
      when :stdev
        @bucketSum += tempScore
        @bucketCount += 1
        @bucketSoq += tempScore * tempScore
      when :avgbylength
        @bucketSum += tempScore
      else
        @error = BRL::Genboree::GenboreeError.new(':Bad Request', 'Unknown Span Aggregate Function')
      end
    end

    def colHeaderLine()
      retVal = ''
      if(@showColumnHeader and self.class::COLUMN_HEADER_LINE)
        retVal = self.class::COLUMN_HEADER_LINE
        retVal << "\n"
        @showColumnHeader = false
      end
      return retVal
    end

    # Set the ftypeId and landmark instance vars.
    # Careful when using this to set ftypeId because you can unintentionally unset landmark
    #
    # [+ftypeId+]   FtypeId of the track
    # [+landmark+]  String containing the entrypoint, start and stop
    def setFtypeId(ftypeId, refSeqId, landmark=nil)
      @ftypeId, @refSeqId, @landmark = ftypeId, refSeqId, landmark
    end

    # A track list also requires refSeqId because the ftypeIds will be
    # retrieved from a Abstract::Resources::Track object which requires refSeqId
    # [+trackList+] Array of track names
    # [+refSeqId+]  refseq ID of the database containing track
    # [+landmark+]  String containing the entrypoint, start and stop
    def setTrackList(trackList, refSeqId, landmark=nil)
      @trackList, @refSeqId, @landmark = trackList, refSeqId, landmark
    end

    def setBufferSize(size)
      @bufferSize = size
    end

    def setClassName(ftypeid)
      classRecord = @dbu.selectAllFtypeClasses(ftypeid)
      @className = classRecord[0]['gclass'] if(!classRecord.nil? and !classRecord.empty?)
    end

    # Subclasses override...mainly for LFF to make [entrypoints] section
    def otherSections(frefNames)
      retVal = ''
      return retVal
    end

    def addChrInfo()
      landmarks = @landmark.strip.split(',')
      chrNames = []
      landmarks.each { |lm|
        lm =~ /([^: ]+)\s*(?:\:\s*(\d+))?(?:\:?\s*-\s*(\d+))?/
        ep, start, stop = $1, $2, $3
        chrNames << ep
      }
      return otherSections(chrNames)
    end

    # Cleans up @structArray after each fdata2 chunk is processed
    # [+returns+] nil
    def cleanStructArray()
      if(!@structArray.nil? and !@structArray.empty?)
        if(@aggFunction != :med)
          @structArray.clear()
        else
          if(@scoreTrkIsHdhv)
            @structArray.each { |struct|
              if(!struct.numRecords.nil?)
                struct.string = ""
              end
            }
          end
        end
      end
    end
    
    # Sets up AVPs for a chunk of fdata2 recs
    # [+returns+] nil
    def setAVPs()
      valueString = ""
      if(FORMATS_WITH_AVPS.key?(@hdhvType) and @attIdArray and !@attIdArray.empty?)
        valueString = @dbu.selectFidsAttNameIdAndAttValueNamesByFidsAndAttNameIds(@fidArray, @attIdArray)
        makeAttributeValuePairs(valueString) if(!valueString.nil? and !valueString.empty?)
      end
    end

    # Casts all blockLevelDataInfo values appropriately
    # The elements will already be a hash if its been yielded as a chunk
    # [+returns+] nil
    def castBlockLevelValues()
      @blockRecs.each_index { |ii|
        blockRec = nil
        if(!@blockRecs[ii].is_a?(Hash))
          blockRec = @blockRecs[ii].to_h
        else
          blockRec = @blockRecs[ii]
        end
        blockRec['id'] = blockRec['id'].to_i
        blockRec['offset'] = blockRec['offset'].to_i
        blockRec['byteLength'] = blockRec['byteLength'].to_i
        blockRec['numRecords'] = blockRec['numRecords'].to_i
        blockRec['fileName'] = blockRec['fileName']
        blockRec['fstart'] = blockRec['fstart'].to_i
        blockRec['fstop'] = blockRec['fstop'].to_i
        blockRec['blockSpan'] = (blockRec['gbBlockBpSpan'] ? blockRec['gbBlockBpSpan'].to_i : @hdhvObj.attributeHash['gbTrackBpSpan'])
        blockRec['blockStep'] = (blockRec['gbBlockBpStep'] ? blockRec['gbBlockBpStep'].to_i : @hdhvObj.attributeHash['gbTrackBpStep'])
        blockRec['blockScale'] = (blockRec['gbBlockScale'] ? blockRec['gbBlockScale'].to_f : @hdhvObj.attributeHash['gbTrackScale'])
        blockRec['blockLowLimit'] = (blockRec['gbBlockLowLimit'] ? blockRec['gbBlockLowLimit'].to_f : @hdhvObj.attributeHash['gbTrackLowLimit'])
        @blockRecs[ii] = blockRec
      }
    end

    # Initializes various hashes and arrays
    # [+returns+] nil
    def initHashesAndArrays()
      @fidArray = []
      @fid2NameAndValueHash = {}
      @fid2CommentsHash = {}
      @fid2SequenceHash = {}
      @fidScore = {}
      @nameAttrHash = {}
    end
    
    # Computes chunk size based on number of records a track has
    # [+returns+] chunkSize
    def computeChunkSize()
      chunkSize = 100_000
      if(@ftypeCount <= 1000)
        chunkSize = 60_000_000
      elsif(@ftypeCount <= 10_000 and @ftypeCount > 1000)
        chunkSize = 40_000_000
      elsif(@ftypeCount <= 100_000 and @ftypeCount > 10_000)
        chunkSize = 20_00_000
      elsif(@ftypeCount <= 1_000_000 and @ftypeCount > 100_000)
        chunkSize = 500_000
      elsif(@ftypeCount <= 2_000_000 and @ftypeCount > 1_000_000)
        chunkSize = 250_000
      else
        chunkSize = chunkSize
      end
      return chunkSize
    end
    
    def updateAggsForNonHDScrTrk(numRecords, blockScore)
      case @aggFunction
      when :avg
        avgStructObj = @structArray[@fdata2Index]
        if(avgStructObj.sum.nil?)
          avgStructObj.sum = (numRecords * blockScore)
          avgStructObj.count = numRecords
        else
          avgStructObj.sum += (numRecords * blockScore)
          avgStructObj.count += numRecords
        end
       when :med
        medStructObj = @structArray[@fdata2Index]
        if(medStructObj.arr.nil?)
          if(numRecords <= MEDIAN_LIMIT)
            medStructObj.arr = Array.new(numRecords, blockScore)
            medStructObj.numRecords = numRecords
          else
            medStructObj.arr = Array.new(50_000, blockScore)
            medStructObj.numRecords = 50_000
          end
        else
          tmpArr = medStructObj.arr
          tmpNumRecs = medStructObj.numRecords
          if(tmpArr.size < MEDIAN_LIMIT)
            numRecords.times { |ii|
              tmpArr << blockScore
              tmpNumRecs += 1
              break if(tmpNumRecs >= MEDIAN_LIMIT)
            }
            medStructObj.numRecords = tmpNumRecs
          end
        end
      when :max
        maxStructObj = @structArray[@fdata2Index]
        if(maxStructObj.max.nil?)
          maxStructObj.max = blockScore
        else
          maxStructObj.max = blockScore if(blockScore > maxStructObj.max)
        end
      when :min
        minStructObj = @structArray[@fdata2Index]
        if(minStructObj.min.nil?)
          minStructObj.min = blockScore
        else
          minStructObj.min = blockScore if(blockScore < minStructObj.min)
        end
      when :stdev
        stdevStructObj = @structArray[@fdata2Index]
        if(stdevStructObj.soq.nil?)
          stdevStructObj.soq = numRecords * (blockScore * blockScore)
          stdevStructObj.sum = (numRecords * blockScore)
          stdevStructObj.count = numRecords
        else
          if(@hdhvObj.stdevStructObj.soq)
            stdevStructObj.soq += numRecords * (blockScore * blockScore)
            stdevStructObj.sum += (numRecords * blockScore)
            stdevStructObj.count += numRecords
          end
        end
      when :avgbylength
        avgByLengthStructObj = @structArray[@fdata2Index]
        if(avgByLengthStructObj.sum.nil?)
          avgByLengthStructObj.sum = (numRecords * blockScore)
        else
          avgByLengthStructObj.sum += (numRecords * blockScore)
        end
      when :count
        countStructObj = @structArray[@fdata2Index]
        if(countStructObj.count.nil?)
          countStructObj.count = numRecords
        else
          countStructObj.count += numRecords
        end
      when :sum
        sumStructObj = @structArray[@fdata2Index]
        if(sumStructObj.sum.nil?)
          sumStructObj.sum = (numRecords * blockScore)
        else
          sumStructObj.sum += (numRecords * blockScore)
        end
      end
    end

    def initStructArray(size)
      @structArray = []
      case @aggFunction
      when :avg
        size.times { |ii|
          @structArray << AvgStruct.new(nil, nil)
        }
      when :avgbylength
        size.times { |ii|
          @structArray << AvgByLengthStruct.new(nil)
        }
      when :stdev
        size.times { |ii|
          @structArray << StdevStruct.new(nil, nil, nil)
        }
      when :max
        size.times { |ii|
          @structArray << MaxStruct.new(nil)
        }
      when :min
        size.times { |ii|
          @structArray << MinStruct.new(nil)
        }
      when :sum
        size.times { |ii|
          @structArray << SumStruct.new(nil)
        }
      when :count
        size.times { |ii|
          @structArray << CountStruct.new(nil)
        }
      when :med
        if(@scoreTrkIsHdhv)
          size.times { |ii|
            @structArray << MedianStruct.new(nil, nil)
          }
        else
          size.times { |ii|
            @structArray << MedianArrStruct.new(nil, nil)
          }
        end
      end
    end

    def updateAggregates()
      case @aggFunction
      when :avg
        avgStructObj = @structArray[@fdata2Index]
        if(avgStructObj.sum.nil?)
          avgStructObj.sum = @hdhvObj.avgStructObj.sum
          avgStructObj.count = @hdhvObj.avgStructObj.count
        else
          if(!@hdhvObj.avgStructObj.sum.nil?)
            avgStructObj.sum += @hdhvObj.avgStructObj.sum
            avgStructObj.count += @hdhvObj.avgStructObj.count
          end
        end
      when :med
        medianStructObj = @structArray[@fdata2Index]
        if(medianStructObj.string.nil?)
          if(!@hdhvObj.medianStructObj.numRecords.nil?)
            medianStructObj.string = @hdhvObj.medianStructObj.string
            medianStructObj.numRecords = @hdhvObj.medianStructObj.numRecords
          end
        else
          if(medianStructObj.string.size <= MEDIAN_LIMIT)
            if(!@hdhvObj.medianStructObj.numRecords.nil?)
              medianStructObj.string << @hdhvObj.medianStructObj.string
              medianStructObj.numRecords += @hdhvObj.medianStructObj.numRecords
            end
          end
        end
      when :max
        maxStructObj = @structArray[@fdata2Index]
        if(maxStructObj.max.nil?)
          maxStructObj.max = @hdhvObj.maxStructObj.max
        else
          maxStructObj.max = @hdhvObj.maxStructObj.max if(@hdhvObj.maxStructObj.max and @hdhvObj.maxStructObj.max > maxStructObj.max)
        end
      when :min
        minStructObj = @structArray[@fdata2Index]
        if(minStructObj.min.nil?)
          minStructObj.min = @hdhvObj.minStructObj.min
        else
          minStructObj.min = @hdhvObj.maxStructObj.min if(@hdhvObj.minStructObj.min and @hdhvObj.minStructObj.min < minStructObj.min)
        end
      when :stdev
        stdevStructObj = @structArray[@fdata2Index]
        if(stdevStructObj.soq.nil?)
          stdevStructObj.soq = @hdhvObj.stdevStructObj.soq
          stdevStructObj.sum = @hdhvObj.stdevStructObj.sum
          stdevStructObj.count = @hdhvObj.stdevStructObj.count
        else
          if(@hdhvObj.stdevStructObj.soq)
            stdevStructObj.soq += @hdhvObj.stdevStructObj.soq * @hdhvObj.stdevStructObj.soq
            stdevStructObj.sum += @hdhvObj.stdevStructObj.sum
            stdevStructObj.count += @hdhvObj.stdevStructObj.count
          end
        end
      when :avgbylength
        avgByLengthStructObj = @structArray[@fdata2Index]
        if(avgByLengthStructObj.sum.nil?)
          avgByLengthStructObj.sum = @hdhvObj.avgByLengthStructObj.sum
        else
          avgByLengthStructObj.sum += @hdhvObj.avgByLengthStructObj.sum if(@hdhvObj.avgByLengthStructObj.sum)
        end
      when :count
        countStructObj = @structArray[@fdata2Index]
        if(countStructObj.count.nil?)
          countStructObj.count = @hdhvObj.countStructObj.count
        else
          countStructObj.count += @hdhvObj.countStructObj.count if(@hdhvObj.countStructObj.count)
        end
      when :sum
        sumStructObj = @structArray[@fdata2Index]
        if(sumStructObj.sum.nil?)
          sumStructObj.sum = @hdhvObj.sumStructObj.sum
        else
          sumStructObj.sum += @hdhvObj.sumStructObj.sum if(@hdhvObj.sumStructObj.sum)
        end
      end
    end

    # Calls C function to get the score for an annotation based on the requested aggregate function
    # [+rowObj+]
    # [+rowCount+] fdata2 index
    # [+returns+] fscore (nil or string with real score)
    def getScore(rowObj, rowCount)
      fscore = nil
      fstop = rowObj['fstop'].to_i
      fstart = rowObj['fstart'].to_i
      flength = (fstop - fstart) + 1
      case @aggFunction
      when :avg
        avgStruct = @structArray[rowCount]
        sum = avgStruct.sum
        count = avgStruct.count
        if(sum and count)
          if(@scoreTrkIsHdhv)
            @getScoreObj.getScore(sum, count, "", 0.0, 0.0, 0.0, @valueString, @hdhvObj.attributeHash['gbTrackDataSpan'], @hdhvObj.aggFunction, 0, @formatOptions['scaleScores'], @hdhvObj.scaleFactor, @hdhvObj.attributeHash['gbTrackDataMin'])
            fscore = @valueString
          else
            fscore = (sum / count)
          end
        end
      when :med
        medianStruct = @structArray[rowCount]
        if(@scoreTrkIsHdhv)
          medianString = medianStruct.string
          numRecords = medianStruct.numRecords
          if(!numRecords.nil?)
            @getScoreObj.getScore(0.0, 0, medianString, 0.0, 0.0, 0.0, @valueString, @hdhvObj.attributeHash['gbTrackDataSpan'], @hdhvObj.aggFunction, numRecords, @formatOptions['scaleScores'], @hdhvObj.scaleFactor, @hdhvObj.attributeHash['gbTrackDataMin'])
            fscore = @valueString
          end
        else
          medArray = medianStruct.arr
          numRecords = medianStruct.numRecords
          fscore = median(medArray) if(numRecords and numRecords > 0)
        end
      when :avgbylength
        avgByLengthStruct = @structArray[rowCount]
        sum = avgByLengthStruct.sum
        if(sum)
          if(@scoreTrkIsHdhv)
            @getScoreObj.getScore(sum, flength, "", 0.0, 0.0, 0.0, @valueString, @hdhvObj.attributeHash['gbTrackDataSpan'], @hdhvObj.aggFunction, 0, @formatOptions['scaleScores'], @hdhvObj.scaleFactor, @hdhvObj.attributeHash['gbTrackDataMin'])
            fscore = @valueString
          else
            fscore = sum / flength
          end
        end
      when :max
        maxStruct = @structArray[rowCount]
        max = maxStruct.max
        if(max)
          if(@scoreTrkIsHdhv)
            @getScoreObj.getScore(0.0, 0, "", max, 0.0, 0.0, @valueString, @hdhvObj.attributeHash['gbTrackDataSpan'], @hdhvObj.aggFunction, 0, @formatOptions['scaleScores'], @hdhvObj.scaleFactor, @hdhvObj.attributeHash['gbTrackDataMin'])
            fscore = @valueString
          else
            fscore = max
          end
        end
      when :min
        minStruct = @structArray[rowCount]
        min = minStruct.min
        if(min)
          if(@scoreTrkIsHdhv)
            @getScoreObj.getScore(0.0, 0, "", 0.0, min, 0.0, @valueString, @hdhvObj.attributeHash['gbTrackDataSpan'], @hdhvObj.aggFunction, 0, @formatOptions['scaleScores'], @hdhvObj.scaleFactor, @hdhvObj.attributeHash['gbTrackDataMin'])
            fscore = @valueString
          else
            score = min
          end 
        end
      when :stdev
        stdevStruct = @structArray[rowCount]
        soq = stdevStruct.soq
        count = stdevStruct.count
        sum = stdevStruct.sum
        if(soq and count and sum)
          if(@scoreTrkIsHdhv)
            @getScoreObj.getScore(sum, count, "", 0.0, 0.0, soq, @valueString, @hdhvObj.attributeHash['gbTrackDataSpan'], @hdhvObj.aggFunction, 0, @formatOptions['scaleScores'], @hdhvObj.scaleFactor, @hdhvObj.attributeHash['gbTrackDataMin'])
            fscore = @valueString
          else
            fscore =  (Math.sqrt((soq / count) - ((sum / count) * (sum / count))))     
          end
        end
      when :count
        countStruct = @structArray[rowCount]
        count = countStruct.count
        if(count)
          fscore = count
        end
      when :sum
        sumStruct = @structArray[rowCount]
        sum = sumStruct.sum
        if(sum)
          if(@scoreTrkIsHdhv)
            @getScoreObj.getScore(sum, 0, "", 0.0, 0.0, 0.0, @valueString, @hdhvObj.attributeHash['gbTrackDataSpan'], @hdhvObj.aggFunction, 0, @formatOptions['scaleScores'], @hdhvObj.scaleFactor, @hdhvObj.attributeHash['gbTrackDataMin'])
            fscore = @valueString
          else
            fscore = sum  
          end
        end
      end
      return fscore
    end

    def yieldLastChunk(fileFormat, ridRow)
      # If there's anything left in @bucket, dump it before doing the next chromosome
      case fileFormat
      when "variableStep"
        if(!@bucketEmpty)
          # perform statistical function on bucket
          score = calcAggValue(@bucket)
          # yield the line which may require a block header
          yield makeChromHeadLine(ridRow['rid'], @dataSpan, @coord) if(needsHeader?)
          yield makeWigLine(@coord, score)
          # empty the bucket
          @bucket = []
        end
      when "fixedStep"
        if(!@bucketEmpty)
          # perform statistical function on bucket
          score = calcAggValue(@bucket)
          # yield the line which may require a block header
          yield makeChromHeadLine(ridRow['rid'], @dataSpan, @coord) if(needsHeader?)
          yield makeWigLine(@coord, score)
          # empty the bucket
          @bucket = []
        end
      when "lff"
        if(!@bucketEmpty)
          stop = @coord + (@dataSpan - 1) < ridRow['rlength'].to_i ? @coord + (@dataSpan - 1) : ridRow['rlength'].to_i
          # perform statistical function on bucket
          score = calcAggValue(@bucket)
          chrom = ridRow['refname']
          yield "#{@className}\t#{chrom}:#{@coord}-#{stop}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{chrom}\t#{@coord}\t#{stop}\t" +
                              "+\t.\t#{score}\n"
          # empty the bucket
          @bucket = []
        end
      when "bed"
        if(!@bucketEmpty)
          stop = @coord + (@dataSpan - 1) < ridRow['rlength'].to_i ? @coord + (@dataSpan - 1) : ridRow['rlength'].to_i
          # perform statistical function on bucket
          score = calcAggValue(@bucket)
          chrom = ridRow['refname']
          if(@ucscScaleScore)
            if(@ftypeId)
              # Only calculate the scaleFactor if it's nil or the track has changed.
              if(@scaleFactor.nil? or @ftypeId != @currFtypeId)
                @currFtypeId = @ftypeId
                dataRange = @trackWideMaxScore - @trackWideMinScore
                # If the values are all the same (dataRange == 0) then the scaled scores will all be 0
                if(dataRange > 0)
                  @scaleFactor = dataRange / 1000
                else
                  @scaleFactor = (@trackWideMaxScore > 0) ? @trackWideMaxScore : 1
                end
              end
              score = ((score - @trackWideMinScore) / @scaleFactor).round
            else
              @error = BRL::Genboree::GenboreeError.new(:'Bad Request', "Must have either ftypId set or trackList and refSeqId.")
            end
          else
            score = score
          end
          yield "#{chrom}\t#{@coord.to_i-1}\t#{@coord + (@dataSpan - 1)}\t#{chrom}:#{@coord - 1}-#{@coord + (@dataSpan - 1)}\t#{score}\t+\n"
          # empty the bucket
          @bucket = []
        end
      when "bedGraph"
        if(!@bucketEmpty)
          stop = @coord + (@dataSpan - 1) < ridRow['rlength'].to_i ? @coord + (@dataSpan - 1) : ridRow['rlength'].to_i
          # perform statistical function on bucket
          score = calcAggValue(@bucket)
          chrom = ridRow['refname']
          yield "#{chrom}\t#{@coord.to_i-1}\t#{@coord + (@dataSpan - 1)}\t#{score}\n"
          # empty the bucket
          @bucket = []
        end
      when "gff3"
        if(!@bucketEmpty)
          stop = @coord + (@dataSpan - 1) < ridRow['rlength'].to_i ? @coord + (@dataSpan - 1) : ridRow['rlength'].to_i
          # perform statistical function on bucket
          score = calcAggValue(@bucket)
          chrom = ridRow['refname']
          if(@ucscScaleScore)
            if(@ftypeId)
              # Only calculate the scaleFactor if it's nil or the track has changed.
              if(@scaleFactor.nil? or @ftypeId != @currFtypeId)
                @currFtypeId = @ftypeId
                dataRange = @trackWideMaxScore - @trackWideMinScore
                # If the values are all the same (dataRange == 0) then the scaled scores will all be 0
                if(dataRange > 0)
                  @scaleFactor = dataRange / 1000
                else
                  @scaleFactor = (@trackWideMaxScore > 0) ? @trackWideMaxScore : 1
                end
              end
              score = ((score - @trackWideMinScore) / @scaleFactor).to_f
            else
              @error = BRL::Genboree::GenboreeError.new(:'Bad Request', "Must have either ftypId set or trackList and refSeqId.")
            end
          else
            score = score
          end
          yield "#{chrom}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{@coord}\t#{@coord + (@dataSpan - 1)}\t" +
                   "#{score}\t+\t.\tName=#{chrom}:#{@coord}-#{@coord + (@dataSpan - 1)}\n"
          # empty the bucket
          @bucket = []
        end
      when "gff"
        if(!@bucketEmpty)
          stop = @coord + (@dataSpan - 1) < ridRow['rlength'].to_i ? @coord + (@dataSpan - 1) : ridRow['rlength'].to_i
          # perform statistical function on bucket
          score = calcAggValue(@bucket)
          chrom = ridRow['refname']
          if(@ucscScaleScore)
            if(@ftypeId)
              # Only calculate the scaleFactor if it's nil or the track has changed.
              if(@scaleFactor.nil? or @ftypeId != @currFtypeId)
                @currFtypeId = @ftypeId
                dataRange = @trackWideMaxScore - @trackWideMinScore
                # If the values are all the same (dataRange == 0) then the scaled scores will all be 0
                if(dataRange > 0)
                  @scaleFactor = dataRange / 1000
                else
                  @scaleFactor = (@trackWideMaxScore > 0) ? @trackWideMaxScore : 1
                end
              end
              score = ((score - @trackWideMinScore) / @scaleFactor).to_f
            else
              @error = BRL::Genboree::GenboreeError.new(:'Bad Request', "Must have either ftypId set or trackList and refSeqId.")
            end
          else
            score = score
          end
          yield "#{chrom}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{@coord}\t#{@coord + (@dataSpan - 1)}\t" +
                   "#{score}\t+\t.\tName=#{chrom}:#{@coord}-#{@coord + (@dataSpan - 1)}\n"
          # empty the bucket
          @bucket = []
        end
      when "gtf"
        if(!@bucketEmpty)
          stop = @coord + (@dataSpan - 1) < ridRow['rlength'].to_i ? @coord + (@dataSpan - 1) : ridRow['rlength'].to_i
          # perform statistical function on bucket
          score = calcAggValue(@bucket)
          chrom = ridRow['refname']
          if(@ucscScaleScore)
            if(@ftypeId)
              # Only calculate the scaleFactor if it's nil or the track has changed.
              if(@scaleFactor.nil? or @ftypeId != @currFtypeId)
                @currFtypeId = @ftypeId
                dataRange = @trackWideMaxScore - @trackWideMinScore
                # If the values are all the same (dataRange == 0) then the scaled scores will all be 0
                if(dataRange > 0)
                  @scaleFactor = dataRange / 1000
                else
                  @scaleFactor = (@trackWideMaxScore > 0) ? @trackWideMaxScore : 1
                end
              end
              score = ((score - @trackWideMinScore) / @scaleFactor).to_f
            else
              @error = BRL::Genboree::GenboreeError.new(:'Bad Request', "Must have either ftypId set or trackList and refSeqId.")
            end
          else
            score = score
          end
          yield "#{chrom}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{@coord}\t#{@coord + (@dataSpan - 1)}\t" +
                   "#{score}\t+\t.\tgene_id \"#{chrom}:#{@coord}-#{@coord + (@dataSpan - 1)}\" transcript_id \"#{chrom}:#{@coord}-#{@coord + (@dataSpan - 1)}\"\n"
          # empty the bucket
          @bucket = []
        end
      else
        @error = BRL::Genboree::GenboreeError.new(':Bad Request', 'Unknown file format')
      end
      @bucketEmpty = true
    end

    def calcAggValue(bucket)
      case @formatOptions['spanAggFunction']
      when :med
        median(bucket)
      when :avg
        average(bucket)
      when :max
        maximum(bucket)
      when :min
        minimum(bucket)
      when :sum
        sum(bucket)
      when :count
        @bucketCount
      when :stdev
        standardDeviation(bucket)
      when :avgbylength
        avgByLength(bucket)
      else
        @error = BRL::Genboree::GenboreeError.new(':Bad Request', 'Unknown Span Aggregate Function')
      end
    end

    def getScaledScore(rowObj)
      score = 1.0
      if(@ucscScaleScore)
        if(@ftypeId)
          # Only calculate the scaleFactor if it's nil or the track has changed.
          if(@scaleFactor.nil? or @ftypeId != @currFtypeId)
            @currFtypeId = @ftypeId
            dataRange = @trackWideMaxScore - @trackWideMinScore
            # If the values are all the same (dataRange == 0) then the scaled scores will all be 0
            if(dataRange > 0)
              @scaleFactor = dataRange / 1000
            else
              @scaleFactor = (@trackWideMaxScore > 0) ? @trackWideMaxScore : 1
            end
          end
          score = ((rowObj['fscore'] - @trackWideMinScore) / @scaleFactor).round
        else
          @error = BRL::Genboree::GenboreeError.new(:'Bad Request', "Must have either ftypId set or trackList and refSeqId.")
        end
      else
        score = rowObj['fscore']
      end
      return score
    end

    def average(bucket)
      return @bucketSum / @bucketCount
    end

    def sum(bucket)
      return @bucketSum
    end

    def median(bucket)
      bucket.sort
      if(bucket.size % 2 == 0)
        median = (bucket[bucket.size / 2 - 1] + bucket[bucket.size / 2]) / 2
      else
        median = bucket[bucket.size/2]
      end
      return median
    end

    def maximum(bucket)
      return @bucketMax
    end

    def minimum(bucket)
      return @bucketMin
    end

    def standardDeviation(bucket)
      return Math.sqrt((@bucketSoq / @bucketCount) - ((@bucketSum / @bucketCount) * (@bucketSum / @bucketCount)))
    end

    def avgByLength(bucket)
      return @bucketSum / @denomForAvgByLength
    end

    # This method should be overridden where a chromosome header line is required.
    # Mainly for wig data
    def makeChromHeadLine(ftypeId, frefRow)
      # Not Implemented
      return false
    end


    # This method should be overridden
    # It defines how an fdata2 record translates into a line in a text file
    #
    # [+rowObj+]  DBI::Row object for fdata2 record
    def makeLine(rowObj)
      annoLine = rowObj.join("\t")
      annoLine += "\n"
    end

    # Converts a line of gff3 record into a hash
    # [+line+] gff3 line
    # [+returns+] gff3 hash
    def makeGFF3Hash(line)
      fields = line.strip.split(/\t/)
      gff3Hash =  {
                    'chr' => fields[0],
                    'type' => fields[1],
                    'subtype' => fields[2],
                    'fstart' => fields[3],
                    'fstop' => fields[4],
                    'score' => fields[5],
                    'strand' => fields[6],
                    'phase' => fields[7],
                    'avp' => fields[8].gsub(/\t$/, "")
                  }
      return gff3Hash
    end

    # Converts a line of gff record into a hash
    # [+line+] gff line
    # [+returns+] gff hash
    def makeGFFHash(line)
      fields = line.strip.split(/\t/)
      gffHash =  {
                    'chr' => fields[0],
                    'type' => fields[1],
                    'subtype' => fields[2],
                    'fstart' => fields[3],
                    'fstop' => fields[4],
                    'score' => fields[5],
                    'strand' => fields[6],
                    'phase' => fields[7],
                    'name' => fields[8]
                  }
      return gffHash
    end

    # Converts a line of gtf record into a hash
    # [+line+] gtf line
    # [+returns+] gtf hash
    def makeGTFHash(line)
      fields = line.strip.split(/\t/)
      gtfHash =  {
                    'chr' => fields[0],
                    'type' => fields[1],
                    'subtype' => fields[2],
                    'fstart' => fields[3],
                    'fstop' => fields[4],
                    'score' => fields[5],
                    'strand' => fields[6],
                    'phase' => fields[7],
                    'avp' => fields[8].gsub(/\t$/, "")
                  }
      return gtfHash
    end

    # Converts a line of BEDGraph record into a hash
    # [+line+] bed graph line
    # [+returns+] bed graph hash
    def makeBedGraphHash(line)
      fields = line.strip.split(/\t/)
      bedHash = {
                  "chr" => fields[0],
                  "fstart" => (fields[1].to_i + 1), # Add 1 to start coordinate since bed format starts from 0
                  'fstop' => fields[2],
                  "score" => fields[4]
                }
      return bedHash
    end

    # Converts a line of BED record into a hash
    # [+line+] bed line
    # [+returns+] bed hash
    def makeBEDHash(line)
      fields = line.strip.split(/\t/)
      bedHash = {
                  "chr" => fields[0],
                  "fstart" => (fields[1].to_i + 1), # Add 1 to start coordinate since bed format starts from 0
                  'fstop' => fields[2],
                  "name" => fields[3],
                  "score" => fields[4],
                  "strand" => fields[5]
                }
      return bedHash
    end

    # Converts a line of LFF record into a hash
    # [+line+] lff line
    # [+returns+] lff hash
    def makeLFFHash(line)
      fields = line.strip.split(/\t/)
      lffHash = {
                  'class' => fields[0],
                  'name' => fields[1],
                  'type' => fields[2],
                  'subtype' => fields[3],
                  'chr' => fields[4],
                  'fstart' => fields[5],
                  'fstop' => fields[6],
                  'strand' => fields[7],
                  'phase' => fields[8],
                  'score' => fields[9]
                }
      if(fields.size > 10)
        fieldCount = 10
        extraFields = fields.size - 10
        extraFields.times { |ii|
          if(fieldCount == 10)
            lffHash['qstart'] = fields[fieldCount]
          elsif(fieldCount == 11)
            lffHash['qstop'] = fields[fieldCount]
          elsif(fieldCount == 12)
            lffHash['avp'] = fields[fieldCount].gsub(/\t$/, "")
          elsif(fieldCount == 13)
            lffHash['seq'] = fields[fieldCount]
          else
            lffHash['comments'] = fields[fieldCount].gsub(/\t$/, "")
          end
          fieldCount += 1
        }
      end
      return lffHash
    end


    # Creates a hash of all entrypoint names indexed by rid found in fref table.
    #
    # [+returns+] Hash or entrypoints
    def makeEntrypointNamesHash()
      @frefNameHash = {}
      frefNameRows = @dbu.selectAllRefNames()
      frefNameRows.map {|row| @frefNameHash[row['rid']] = row['refname']}
      return @frefNameHash
    end

    # Sets the values for fmethod and fsource in the instance var @ftypeHash
    # which might be required in the annotation data file
    def makeFtypeHash(ftypeId)
      # load the fmethod and fsource which may be required
      @ftypeHash = {}
      ftypeRows = @dbu.selectFtypesByIds([ftypeId])
      @ftypeHash['fmethod'] = ftypeRows.first['fmethod']
      @ftypeHash['fsource'] = ftypeRows.first['fsource']
    end

    def makeFtypeAttributesHash(ftypeId)
      @ftypeAttributesHash = {}
      ftypeAttributesRows = @dbu.selectFtypeAttributeNamesAndValuesByFtypeId(ftypeId)
      ftypeAttributesRows.map {|row| @ftypeAttributesHash[row['name']] = row['value']} unless(ftypeAttributesRows.nil?)
      return @ftypeAttributesHash
    end

    # This method is used for building the color column of bed files,
    # It converts a color in RGB hex format to decimal RGB comma seperated format
    # Then it stores the values in the hash @colorHash so that if the color is requested again, it is not computed again.
    #
    # [+hexValue+]  color in RGB Hexadecimal format
    # [+returns+]   color in comma seperated RGB decimal format
    def colorLookup(hexValue)
      if(@colorHash[hexValue].nil?)
        decValue = rgbHexToRgbDec(hexValue)
        @colorHash[hexValue] = decValue
      end
      return @colorHash[hexValue]
    end

    # Convert a RGB hexadecimal color value to RGB comma-separated decimal value
    # example: #00FF00 -> 0,255,0
    #
    # [+hexValue+]  color in RGB Hexadecimal format
    # [+returns+]   color in comma seperated RGB decimal format
    def rgbHexToRgbDec(hexValue)
      # strip the leading '#' off if its there
      hexValue.gsub!(/#/, '')
      hexValue.scan(/../).map{|dd|dd.hex}.join(',')
    end
  end
end ; end ; end ; end
