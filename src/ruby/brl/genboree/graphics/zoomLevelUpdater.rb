#!/usr/bin/env ruby

ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
require 'ruby-prof'
require 'brl/util/util'
require 'brl/sql/binning'
require 'stringio'
require 'brl/C/CFunctionWrapper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/wrapperApiCaller'

# This class implements zoom level creation and updating. You stream new
# base-scores through it and it will update existing zoom records or create
# new zoom records if there are no zoom records currently covering the base-score.
#
# Basic use of this class is:
# 1. instantiate
# 2. reuse instance, doing 1 chr at a time:
#   a. clearZoomData() - clear out data from previous chr
#   b. getZoomLevelRecsByRid(rid, ftypeId) - populate internal zoomLeveles Hash
#   c. addNewScore() - call for EACH new base-score datum in file
#   d. writeBackZoomLevelRecords() - batching & minimal write back to MySQL of changed & new zoomLevels records
# 3. cleanup() - clean up when ALL done
class ZoomLevelUpdater
  include BRL::C

  ZL_SPANS = { :loRes => 100_000, :hiRes => 10_000 }  # for dynamic
  ZL_SPAN_LO = ZL_SPANS[:loRes] # for speed
  ZL_SPAN_HI = ZL_SPANS[:hiRes] # for speed
  LO_RES = 5
  HI_RES = 4
  NEW_FLAG, MODIFIED_FLAG, UNMODIFIED_FLAG = 0, 1, 2
  BATCH_SIZE = 8_000
  REMOTE_BATCH_SIZE = 20_000
  attr_accessor :newId, :zoomLevelRecsHash, :rid, :ridLen, :ftypeId, :userId
  attr_accessor :dbu, :arrayToInsert, :arrayToUpdate, :useApi, :trackUri, :chrom

  # Constructor
  # [+dbuObj+] A dbUtil object
  # [+returns+] nil
  def initialize(dbuObj, useApi=false)
    @newId = -1
    # This is a Hash of Hashes
    # The 1st Hash key the zoomLevels records by the zoom level
    # and the 2nd level of Hashes key the zoomLevels by their start coord
    # - for any given bp coordinate we can quickly find the appropriate zoomLevel coord through Math
    @zoomLevelRecsHash = { :hiRes => {}, :loRes => {} }
    # To reduce Hash#[]() calls by 50%:
    @hiResZoomLevelRecsHash = @zoomLevelRecsHash[:hiRes]
    @loResZoomLevelRecsHash = @zoomLevelRecsHash[:loRes]
    @dbu = dbuObj
    @useApi = useApi
    @arrayToInsert = []
    @arrayToUpdate = []
  end

  # Use this to reuse the object for another chromosome's zoomLevels records:
  def clearZoomData()
    @zoomLevelRecsHash.clear()
    @zoomLevelRecsHash = { :hiRes => {}, :loRes => {} }
    # To reduce Hash#[]() calls by 50%:
    @hiResZoomLevelRecsHash = @zoomLevelRecsHash[:hiRes]
    @loResZoomLevelRecsHash = @zoomLevelRecsHash[:loRes]
  end

  def numZoomRecs()
    return ( (@zoomLevelRecsHash.key?(:loRes) ? @zoomLevelRecsHash[:loRes].size : 0) + ((@zoomLevelRecsHash.key?(:hiRes) ? @zoomLevelRecsHash[:hiRes].size : 0)) )
  end

  # Get existing zoomLevels data from MySQL for current chr. Only partial record data is needed.
  # - here the data is fake
  # - ridLen is particularly important so new zoom levels can properly stop at end of chr
  def getZoomLevelRecsByRid(rid, ridLen, ftypeId)
    @rid, @ridLen = rid, ridLen
    @ftypeId = ftypeId
    # Get all zoom level records by chr and track
    zoomLevelRecs = []
    unless(@useApi)
      zoomLevelRecs = @dbu.selectZoomLevelsByRidAndFtypeid(@rid, @ftypeId)
    else
      uriObj = URI.parse(@trackUri)
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path}/annos?format=zoomLevels&landmark=#{@chrom}", @userId)
      apiCaller.get() { |lines|
        lines.each_line { |line|
          fields = line.strip.split(/\t/)
          zoomLevelRecs << {'id' => fields[0], 'level' => fields[1], 'fstart' => fields[2], 'fstop' => fields[3], 'scoreCount' => fields[4], 'scoreSum' => fields[5],
          'scoreMax' => fields[6], 'scoreMin' => fields[7], 'scoreSumOfSquares' => fields[8], 'negScoreCount' => fields[9],
          'negScoreSum' => fields[10], 'negScoreSumOfSquares' => fields[11]
          } 
        }
      }
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "zoomLevelRecs.size: #{zoomLevelRecs.size}")
    end
    
    # Go through the result set and fill up the cache hash
    zoomLevelRecs.each { |zoomRecord|
      # Low Resolution
      if(zoomRecord['level'] == LO_RES)
        @loResZoomLevelRecsHash[zoomRecord['fstart']] = [zoomRecord['id'], LO_RES, zoomRecord['fstart'].to_i, zoomRecord['fstop'].to_i,
                                                         zoomRecord['scoreCount'].to_i, zoomRecord['scoreSum'].to_f, zoomRecord['scoreMax'].to_f,
                                                         zoomRecord['scoreMin'].to_f, zoomRecord['scoreSumofSquares'].to_f, zoomRecord['negScoreCount'].to_i,
                                                         zoomRecord['negScoreSum'].to_f, zoomRecord['negScoreSumOfSquares'].to_f, UNMODIFIED_FLAG]
      # High Resolution
      elsif(zoomRecord['level'] == HI_RES)
        @hiResZoomLevelRecsHash[zoomRecord['fstart']] = [zoomRecord['id'], HI_RES, zoomRecord['fstart'].to_i, zoomRecord['fstop'].to_i, zoomRecord['scoreCount'].to_i,
                                                         zoomRecord['scoreSum'].to_f, zoomRecord['scoreMax'].to_f, zoomRecord['scoreMin'].to_f, zoomRecord['scoreSumofSquares'].to_f,
                                                         zoomRecord['negScoreCount'].to_i, zoomRecord['negScoreSum'].to_f, zoomRecord['negScoreSumOfSquares'].to_f, UNMODIFIED_FLAG]
      end
    }
    # Clear the original result set
    zoomLevelRecs.clear()
    return
  end

  # Add a new base-score (from file say) to appropriate zoom levels.
  # - update existing zoom levels
  # - create missing zoom levels if no existing zoom regions cover the new base-score
  # We need to find the existing zoomLevels records, if any, covering the
  # base for each score. We do that by calculating the start base of the appropriate
  # zoomLevel record and then looking for it in the Hash.
  #
  # Once we find the existing records, we create any that are missing and update any that
  # already exist with the new score info.
  # - Spending some effort timing this process will pay off since its done
  #   for each new score.
  # * NOTE: for any given score, there should be at most 1 record per zoom level
  # * For each zoom level record found, update it.
  # * For each missing zoom level records, insert a new one.
  #
  # [+score+] MUST be a non-nil Ruby Float object (.to_f highly recommended)
  def addNewScore(score, bpCoord)
    saw10k, saw100k = false, false # flags to tell which zoomLevel records we've seen...we don't know which will come first, 10k or 100k
    loResZoomRec = hiResZoomRec = nil
    # Find zoom records this base-score
    start100k = self.zoomLevelStartFromBp(ZL_SPAN_LO, bpCoord)
    start10k = self.zoomLevelStartFromBp(ZL_SPAN_HI, bpCoord)
    loResZoomRec = @loResZoomLevelRecsHash[start100k]
    hiResZoomRec = @hiResZoomLevelRecsHash[start10k]
    if(loResZoomRec.nil? and hiResZoomRec.nil?) # then no existing zoom level records covering this base. Add them.
      # Need to make a NEW ZL_SPAN_LO zoomLevels record and a 10_000 zoomLevels record
      # 100k:
      self.makeZoomLevelRec(score, bpCoord, :loRes)
      # 10k:
      self.makeZoomLevelRec(score, bpCoord, :hiRes)
    else # either 1 [lo res] or 2 [hi and lo res] existing zoom level records cover this base
      if(loResZoomRec) # We have at least the low res record
        # UPDATE lo res record
        self.updateZoomLevelRec(loResZoomRec, score, bpCoord)
        # Do we have the hi res record?
        if(hiResZoomRec) # yes
          # UPDATE hi res record
          self.updateZoomLevelRec(hiResZoomRec, score, bpCoord)
        else # no
          # CREATE hi res record
          self.makeZoomLevelRec(score, bpCoord, :hiRes)
        end
      else # ERROR: got only a hi res record (not possible!)
        raise "ERROR: got only a hi res record for base-score of [#{score.inspect} @ #{bpCoord.inspect}]"
      end
    end
    return
  end

  def addNewScoreForSpan(score, bpStart, span=1)
    if(span <= 1)
      addNewScore(score, bpStart)
    else
      loResZoomRec = hiResZoomRec = nil
      # Calc span-score stop
      bpStop = self.calcCoordStop(bpStart, span)
      #-------------------
      # LOW RES zoom level -- duplicated in HIGH RES section to avoid tests and parameterized hash-accesses a bit
      #-------------------
      # What zoom level record does this span-score begin in?
      spanZlStart = self.zoomLevelStartFromBp(ZL_SPAN_LO, bpStart)
      # What zoom level record does this span-score end in? (hopefully same one, but could cross >1 adjacent zoom level records)
      spanLastZlStart = self.zoomLevelStartFromBp(ZL_SPAN_LO, bpStop)
      # Does whole span fit in zoom level?
      if(spanZlStart == spanLastZlStart) # Yes, so we don't need to break up the span-score. Process it as a whole
        zoomRec = @loResZoomLevelRecsHash[spanZlStart]
        if(zoomRec.nil?) # then no existing zoom level record. Add it.
          self.makeZoomLevelRecUsingSpan(score, bpStart, span, :loRes)
        else # we have an existing zoom level record. Update it.
          self.updateZoomLevelRecUsingSpan(zoomRec, score, bpStart, span)
        end
      else # No, the span-score doesn't fit in a single zoom level. Need to break span apart. Don't assume just breaking into 2 piece is sufficient (e.g. what if span = 1_000_000)
        # Where does the entire span-score end?
        spanScoreStop = self.calcCoordStop(bpStart, span)
        partialScoreStart = bpStart
        # While the current span-score doesn't fit in a single zoom level rec, add portions of the span-score
        while(spanZlStart <= spanLastZlStart)
          # Current portion of span-score stops where current zoom level record stops or where whole span-score stops (whichever is smaller)
          partialScoreStop = self.calcCoordStop(spanZlStart, 100_000)
          partialScoreStop = spanScoreStop if(spanScoreStop < partialScoreStop)
          # Size of current portion of span-score
          partialScoreSpan = self.calcSpanSize(partialScoreStart, partialScoreStop)
          # Get current zoom level record
          zoomRec = @loResZoomLevelRecsHash[spanZlStart]
          # If got one, update; if not, create new ... but all using data for PORTION of span-score
          if(zoomRec.nil?) # then no existing zoom level record. Add it.
            self.makeZoomLevelRecUsingSpan(score, partialScoreStart, partialScoreSpan, :loRes)
          else # we have an existing zoom level record. Update it.
            self.updateZoomLevelRecUsingSpan(zoomRec, score, partialScoreStart, partialScoreSpan)
          end
          # Next portion to process will start at very next bp
          partialScoreStart = self.calcIncrementFixnum(partialScoreStop, 1)
          # Next zoom level record's start bp:
          spanZlStart = self.zoomLevelStartFromBp(ZL_SPAN_LO, partialScoreStart)
          break if(partialScoreStart > bpStop)
        end
      end
      #-------------------
      # HIGH RES zoom level -- duplicated in LOW RES section to avoid tests and parameterized hash-accesses a bit
      #-------------------
      # What zoom level record does this span-score begin in?
      spanZlStart = self.zoomLevelStartFromBp(ZL_SPAN_HI, bpStart)
      # What zoom level record does this span-score end it? (hopefully same one, but could cross >1 adjacent zoom level records)
      spanLastZlStart = self.zoomLevelStartFromBp(ZL_SPAN_HI, bpStop)
      # Does whole span fit in zoom level?
      if(spanZlStart == spanLastZlStart) # Yes, so we don't need to break up the span. Treat as a whole.
        zoomRec = @hiResZoomLevelRecsHash[spanZlStart]
        if(zoomRec.nil?) # then no existing zoom level record. Add it.
          self.makeZoomLevelRecUsingSpan(score, bpStart, span, :hiRes)
        else # we have an existing zoom level record. Update it.
          # UPDATE record
          self.updateZoomLevelRecUsingSpan(zoomRec, score, bpStart, span)
        end
      else # No, it doesn't. Need to break span apart. Don't assume just breaking into 2 piece is sufficient (e.g. what if span = 1_000_000)
        # Where does the entire span-score end?
        spanScoreStop = self.calcCoordStop(bpStart, span)
        partialScoreStart = bpStart
        # While the current span-score doesn't fit in a single zoom level rec, add portions of the span-score
        while(spanZlStart <= spanLastZlStart)
          # Current portion of span-score stops where current zoom level record stops or where whole span-score stops (whichever is smaller)
          partialScoreStop = self.calcCoordStop(spanZlStart, 10_000)
          partialScoreStop = spanScoreStop if(spanScoreStop < partialScoreStop)
          # Size of current portion of span-score
          partialScoreSpan = self.calcSpanSize(partialScoreStart, partialScoreStop)
          # Get current zoom level record
          zoomRec = @hiResZoomLevelRecsHash[spanZlStart]
          # If got one, update; if not, create new ... but all using data for PORTION of span-score
          if(zoomRec.nil?) # then no existing zoom level record. Add it.
            self.makeZoomLevelRecUsingSpan(score, partialScoreStart, partialScoreSpan, :hiRes)
          else # we have an existing zoom level record. Update it.
            self.updateZoomLevelRecUsingSpan(zoomRec, score, partialScoreStart, partialScoreSpan)
          end
          # Next portion to process will start at very next bp
          partialScoreStart = self.calcIncrementFixnum(partialScoreStop, 1)
          # Next zoom level record's start bp:
          spanZlStart = self.zoomLevelStartFromBp(ZL_SPAN_HI, partialScoreStart)
          break if(partialScoreStart > bpStop)
        end
      end
    end
    return
  end

  # Write updated & new zoom level data to MySQL
  # - do NOT do wasteful work; don't involve records marked as UNMODIFIED_FLAG
  # - DO fix all the -ve "id" NEW_FLAG zoom level records to have nil "id" so MySQL gives them appropriate ids
  # - DO INSERT or UPDATE ~4000 records in a single batch SQL
  # - MODIFIED_FLAG == UPDATE, NEW_FLAG = INSERT
  def writeBackZoomLevelRecords()
    # TODO
    insertCount = 0
    updateCount = 0
    mysqlStreamInsert = ""
    mysqlStreamUpdate = ""
    dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
    trkApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new()
    apiCaller = nil
    trackName = nil
    if(@useApi)
      uriObj = URI.parse(dbApiHelper.extractPureUri(@trackUri)) 
      trackName = trkApiHelper.extractName(@trackUri)
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path}/annos?format=gbTabbedDbRecs&annosFormat=wig&annosType=zoomLevels&trackName=#{CGI.escape(trackName)}", @userId)
    end
    binner = BRL::SQL::Binning.new
    @zoomLevelRecsHash.each_key { |res|
      @zoomLevelRecsHash[res].each_key { |zStart|
        tempArray = @zoomLevelRecsHash[res][zStart]
        # New Records. Do Insert
        if(tempArray[12] == NEW_FLAG)
          unless(@useApi)
            @arrayToInsert[insertCount] = [tempArray[1], @ftypeId, @rid, binner.bin(BRL::SQL::MIN_BIN, tempArray[2], tempArray[3]), tempArray[2], tempArray[3], tempArray[4], tempArray[5], tempArray[6], tempArray[7], tempArray[8], tempArray[9], tempArray[10], tempArray[11]]
          else
            mysqlStreamInsert << "NULL\t#{tempArray[1]}\t#{@ftypeId}\t#{@rid}\t#{binner.bin(BRL::SQL::MIN_BIN, tempArray[2], tempArray[3])}\t#{tempArray[2]}\t#{tempArray[3]}\t#{tempArray[4]}\t#{tempArray[5]}\t#{tempArray[6]}\t#{tempArray[7]}\t#{tempArray[8]}\t#{tempArray[9]}\t#{tempArray[10]}\t#{tempArray[11]}\n"
          end
          insertCount += 1
          if(insertCount == BATCH_SIZE)
            unless(@useApi)
              @dbu.insertZoomLevelRecords(@arrayToInsert, BATCH_SIZE)
              @arrayToInsert.clear()
            else
              $stderr.debugPuts(__FILE__, __method__, "TIME", "[zoom levels] before put (insert): #{Time.now}")
              apiCaller.put(mysqlStreamInsert)
              $stderr.debugPuts(__FILE__, __method__, "TIME", "[zoom levels] after put (insert): #{Time.now}")
              mysqlStreamInsert = ""
            end
            insertCount = 0
          end
        # Modified Records. Do Replace
        elsif(tempArray[12] == MODIFIED_FLAG)
          unless(@useApi)
            @arrayToUpdate[updateCount] = [tempArray[0], tempArray[1], @ftypeId, @rid, binner.bin(BRL::SQL::MIN_BIN, tempArray[2], tempArray[3]), tempArray[2], tempArray[3], tempArray[4], tempArray[5], tempArray[6], tempArray[7], tempArray[8], tempArray[9], tempArray[10], tempArray[11]]
          else
            mysqlStreamUpdate << "#{tempArray[0]}\t#{tempArray[1]}\t#{@ftypeId}\t#{@rid}\t#{binner.bin(BRL::SQL::MIN_BIN, tempArray[2], tempArray[3])}\t#{tempArray[2]}\t#{tempArray[3]}\t#{tempArray[4]}\t#{tempArray[5]}\t#{tempArray[6]}\t#{tempArray[7]}\t#{tempArray[8]}\t#{tempArray[9]}\t#{tempArray[10]}\t#{tempArray[11]}\n"
          end
          updateCount += 1
          if(updateCount == BATCH_SIZE)
            unless(@useApi)
              @dbu.replaceZoomLevelRecords(@arrayToUpdate, BATCH_SIZE)
              @arrayToUpdate.clear()
            else
              $stderr.debugPuts(__FILE__, __method__, "TIME", "[zoom levels] before put (replace): #{Time.now}")
              apiCaller.put(mysqlStreamUpdate)
              $stderr.debugPuts(__FILE__, __method__, "TIME", "[zoom levels] after put (replace): #{Time.now}")
              mysqlStreamUpdate = ""
            end
            updateCount = 0
          end
        end
      }
    }
    # Insert any remaining 'insertable' records
    if(!@arrayToInsert.empty?)
      @dbu.insertZoomLevelRecords(@arrayToInsert, @arrayToInsert.size)
      @arrayToInsert.clear()
      insertCount = 0
    end
    if(!mysqlStreamInsert.empty?)
      #$stderr.debugPuts(__FILE__, __method__, "TIME", "[zoom levels] before put (insert): #{Time.now}")
      apiCaller.put(mysqlStreamInsert)
      #$stderr.debugPuts(__FILE__, __method__, "TIME", "[zoom levels] after put (insert): #{Time.now}")
      mysqlStreamInsert = ""
    end
    
    # Replace any remaining 'replacable' records
    if(!@arrayToUpdate.empty?)
      @dbu.replaceZoomLevelRecords(@arrayToUpdate, @arrayToUpdate.size)
      @arrayToUpdate.clear()
      updateCount = 0
    end
    if(!mysqlStreamUpdate.empty?)
      #$stderr.debugPuts(__FILE__, __method__, "TIME", "[zoom levels] before put (replace): #{Time.now}")
      apiCaller.put(mysqlStreamUpdate)
      #$stderr.debugPuts(__FILE__, __method__, "TIME", "[zoom levels] after put (replace): #{Time.now}")
      mysqlStreamUpdate = ""
    end
    
  end

  # Clean up at end of all processing is a good practice
  def cleanup()
    @zoomLevelRecsHash.clear()
  end

  #------------------------------------------------------------------
  # INTERNAL HELPER METHODS
  #------------------------------------------------------------------
  # Update in-memory zoomLevels record's data
  def updateZoomLevelRec(zoomLevelRec, score, bpCoord)
    # If new this batch, leave as new, else mark pre-existing zoom level as modified
    self.updateZoomLevelRecData(zoomLevelRec, score)
    return zoomLevelRec
  end

  # Create a NEW zoomLevel and insert it into data structures
  def makeZoomLevelRec(score, bpCoord, zlType)
    zlSpan = ZL_SPANS[zlType]
    # Calc start of zoom region covering bpCoord.
    zlStart = self.zoomLevelStartFromBp(zlSpan, bpCoord)
    zlStop = self.zoomLevelStopFromStart(zlSpan, zlStart)
    zlStop = @ridLen if(zlStop > @ridLen)
    newZoomRec = nil
    # Flag is NEW_FLAG, so we can easily do an SQL "INSERT" for this vs "UPDATE" for existing ones when put back to MySQL
    if(score >= 0.0)
      newZoomRec = [ nil, Math.log10(zlSpan).to_i, zlStart, zlStop, 1, score, score, score, score * score, 0, 0.0, 0.0, NEW_FLAG ]
    elsif(score < 0.0)
      newZoomRec = [ nil, Math.log10(zlSpan).to_i, zlStart, zlStop, 0, 0.0, score, score, 0.0, 1, score, score * score, NEW_FLAG ]
    end
    # Add to Hash of full records
    @zoomLevelRecsHash[zlType][zlStart] = newZoomRec
    return newZoomRec
  end

  # Create a NEW zoomLevel using score across a span and insert it into data structures
  def makeZoomLevelRecUsingSpan(score, bpCoord, scrSpan, zlType)
    zlSpan = ZL_SPANS[zlType]
    # Calc start of zoom region covering bpCoord.
    zlStart = self.zoomLevelStartFromBp(zlSpan, bpCoord)
    zlStop = self.zoomLevelStopFromStart(zlSpan, zlStart)
    zlStop = @ridLen if(zlStop > @ridLen)
    newZoomRec = nil
    # Flag is NEW_FLAG, so we can easily do an SQL "INSERT" for this vs "UPDATE" for existing ones when put back to MySQL
    if(score >= 0.0)
      newZoomRec = [ nil, Math.log10(zlSpan).to_i, zlStart, zlStop, scrSpan, scrSpan*score, score, score, score * score * scrSpan, 0, 0.0, 0.0, NEW_FLAG ]
    elsif(score < 0.0)
      newZoomRec = [ nil, Math.log10(zlSpan).to_i, zlStart, zlStop, 0, 0.0, score, score, 0.0, scrSpan, scrSpan*score, score * score * scrSpan, NEW_FLAG ]
    end
    # Add to Hash of full records
    if(zlType == :loRes)
      @loResZoomLevelRecsHash[zlStart] = newZoomRec
    else # high res
      @hiResZoomLevelRecsHash[zlStart] = newZoomRec
    end
    return newZoomRec
  end

    # Update in-memory zoomLevels record's data
  def updateZoomLevelRecUsingSpan(zoomLevelRec, score, bpCoord, span)
    self.updateZoomLevelRecDataUsingSpan(zoomLevelRec, score, span.to_i)
    return zoomLevelRec
  end

  #------------------------------------------------------------------
  # INTERNAL C HELPER FUNCTIONS
  #------------------------------------------------------------------
  # idx 2 data: 4 -> count, 5 -> sum, 6 -> max, 7 -> min, 8 -> sosq
  UPDATE_ZOOM_LEVEL_REC_DATA = <<-EOC
    VALUE updateZoomLevelRecData(VALUE zoomLevelRecAry, VALUE score)
    {
      double scr = RFLOAT(score)->value;
      /* count */
      /* update the appropriate columns (+ve/-ve) */
      if(scr >= 0.0)
      {
        long count = FIX2LONG(rb_ary_entry(zoomLevelRecAry, 4)) + 1 ;
        rb_ary_store(zoomLevelRecAry, 4, LONG2FIX(count)) ;  
      }
      else //if(scr < 0.0)
      {
        long count = FIX2LONG(rb_ary_entry(zoomLevelRecAry, 9)) + 1 ;
        rb_ary_store(zoomLevelRecAry, 9, LONG2FIX(count)) ; 
      }
      /* sum */
      VALUE zlSumElem = rb_ary_entry(zoomLevelRecAry, 5) ;
      VALUE zlSumElemNeg = rb_ary_entry(zoomLevelRecAry, 10) ;
      if(scr >= 0.0)
      {
        double sum = (RFLOAT(zlSumElem)->value + RFLOAT(score)->value) ;
        rb_ary_store(zoomLevelRecAry, 5, rb_float_new(sum)) ;  
      }
      else //if(scr < 0.0)
      {
        double sum = (RFLOAT(zlSumElemNeg)->value + RFLOAT(score)->value) ;
        rb_ary_store(zoomLevelRecAry, 10, rb_float_new(sum)) ; 
      }
      /* max */
      VALUE zlMaxElem = rb_ary_entry(zoomLevelRecAry, 6) ;
      if(RFLOAT(score)->value > RFLOAT(zlMaxElem)->value)
      {
        rb_ary_store(zoomLevelRecAry, 6, score) ;
      }
      /* min */
      VALUE zlMinElem = rb_ary_entry(zoomLevelRecAry, 7) ;
      if(RFLOAT(score)->value < RFLOAT(zlMinElem)->value)
      {
        rb_ary_store(zoomLevelRecAry, 7, score) ;
      }
      /* sosq - online formula tracking sum(Xi^2) - for use in sosq = sum(xi^2) - 2*mean*sum + count*mean^2 = sum((Xi - mean)^2) */
      VALUE zlSosqElem = rb_ary_entry(zoomLevelRecAry, 8) ;
      VALUE zlSosqElemNeg = rb_ary_entry(zoomLevelRecAry, 11) ;
      if(scr >= 0.0)
      {
        double oldSosq = RFLOAT(zlSosqElem)->value ;
        double newSq = RFLOAT(score)->value * RFLOAT(score)->value ;
        rb_ary_store(zoomLevelRecAry, 8, rb_float_new(oldSosq + newSq)) ;  
      }
      else //if(scr < 0.0)
      {
        double oldSosq = RFLOAT(zlSosqElemNeg)->value ;
        double newSq = scr * scr ;
        rb_ary_store(zoomLevelRecAry, 11, rb_float_new(oldSosq + newSq)) ;  
      }
      
      /* flag */
      VALUE zlFlagElem = rb_ary_entry(zoomLevelRecAry, 12) ;
      long flag = FIX2LONG(zlFlagElem) ;
      if(flag == 2L) /* new stays new, modified stays modified, but unmodified->modified */
      {
        rb_ary_store(zoomLevelRecAry, 12, LONG2FIX(1)) ;
      }
      /* done */
      return Qnil ;
    }
  EOC

  # idx 2 data: 4 -> count, 5 -> sum, 6 -> max, 7 -> min, 8 -> sosq
  UPDATE_ZOOM_LEVEL_REC_DATA_USING_SPAN = <<-EOC
    VALUE updateZoomLevelRecDataUsingSpan(VALUE zoomLevelRecAry, VALUE score, VALUE span)
    {
      long span_l = FIX2LONG(span) ;
      double scr = RFLOAT(score)->value;
      /* count */
      if(scr >= 0.0)
      {
        long count = FIX2LONG(rb_ary_entry(zoomLevelRecAry, 4)) + span_l ;
        rb_ary_store(zoomLevelRecAry, 4, LONG2FIX(count)) ;  
      }
      else //if(scr < 0.0)
      {
        long count = FIX2LONG(rb_ary_entry(zoomLevelRecAry, 9)) + span_l ;
        rb_ary_store(zoomLevelRecAry, 9, LONG2FIX(count)) ;
      }
      
      /* sum */
      VALUE zlSumElem = rb_ary_entry(zoomLevelRecAry, 5) ;
      VALUE zlSumElemNeg = rb_ary_entry(zoomLevelRecAry, 10) ;
      if(scr >= 0.0)
      {
        double sum = (RFLOAT(zlSumElem)->value + (RFLOAT(score)->value * span_l)) ;
        rb_ary_store(zoomLevelRecAry, 5, rb_float_new(sum)) ;  
      }
      else //if(scr < 0.0)
      {
        double sum = (RFLOAT(zlSumElemNeg)->value + (RFLOAT(score)->value * span_l)) ;
        rb_ary_store(zoomLevelRecAry, 10, rb_float_new(sum)) ;
      }
      /* max */
      VALUE zlMaxElem = rb_ary_entry(zoomLevelRecAry, 6) ;
      if(RFLOAT(score)->value > RFLOAT(zlMaxElem)->value)
      {
        rb_ary_store(zoomLevelRecAry, 6, score) ;
      }
      /* min */
      VALUE zlMinElem = rb_ary_entry(zoomLevelRecAry, 7) ;
      if(RFLOAT(score)->value < RFLOAT(zlMinElem)->value)
      {
        rb_ary_store(zoomLevelRecAry, 7, score) ;
      }
      /* sosq - online formula tracking sum(Xi^2) - for use in sosq = sum(xi^2) - 2*mean*sum + count*mean^2 = sum((Xi - mean)^2) */
      VALUE zlSosqElem = rb_ary_entry(zoomLevelRecAry, 8) ;
      VALUE zlSosqElemNeg = rb_ary_entry(zoomLevelRecAry, 11) ;
      if(scr >= 0.0)
      {
        double oldSosq = RFLOAT(zlSosqElem)->value ;
        double newSq = RFLOAT(score)->value * RFLOAT(score)->value * span_l ;
        rb_ary_store(zoomLevelRecAry, 8, rb_float_new(oldSosq + newSq)) ;  
      }
      else //if(scr < 0.0)
      {
        double oldSosq = RFLOAT(zlSosqElemNeg)->value ;
        double newSq = scr * scr * span_l ;
        rb_ary_store(zoomLevelRecAry, 11, rb_float_new(oldSosq + newSq)) ;  
      }
      /* flag - 0 is NEW_FLAG, 1 is MODIFIED_FLAG, 2 is UNMODIFIED_FLAG */
      VALUE zlFlagElem = rb_ary_entry(zoomLevelRecAry, 12) ;
      long flag = FIX2LONG(zlFlagElem) ;
      if(flag == 2L) /* new stays new, modified stays modified, but unmodified->modified */
      {
        rb_ary_store(zoomLevelRecAry, 12, LONG2FIX(1)) ;
      }
      /* done */
      return Qnil ;
    }
  EOC

  # For: # (ZL_SPAN_LO * ((bpCoord - (bpCoord % ZL_SPAN_LO == 0 ? 1 : 0)) / ZL_SPAN_LO) + 1)
  # For: # (ZL_SPAN_HI * ((bpCoord - (bpCoord % ZL_SPAN_HI == 0 ? 1 : 0)) / ZL_SPAN_HI) + 1)
  # For: # (zlSpan * ((bpCoord - (bpCoord % zlSpan == 0 ? 1 : 0)) / zlSpan) + 1)
  ZOOM_LEVEL_START_FROM_BP = <<-EOC
    VALUE zoomLevelStartFromBp(VALUE zlSpan, VALUE bpCoord)
    {
      long zlSpan_l = FIX2LONG(zlSpan) ;
      long bpCoord_l = FIX2LONG(bpCoord) ;
      long zlStart = (zlSpan_l * ((bpCoord_l - (bpCoord_l % zlSpan_l == 0 ? 1 : 0)) / zlSpan_l) + 1) ;
      return LONG2FIX(zlStart) ;
    }
  EOC

  ZOOM_LEVEL_STOP_FROM_START = <<-EOC
    VALUE zoomLevelStopFromStart(VALUE zlSpan, VALUE zlStart)
    {
      long zlSpan_l = FIX2LONG(zlSpan) ;
      long zlStart_l = FIX2LONG(zlStart) ;
      long zlStop = (zlStart_l + zlSpan_l - 1) ;
      return LONG2FIX(zlStop) ;
    }
  EOC

  CALC_COORD_STOP = <<-EOC
    VALUE calcCoordStop(VALUE bpCoord, VALUE span)
    {
      long stop = (FIX2LONG(bpCoord) + FIX2LONG(span) - 1) ;
      return LONG2FIX(stop) ;
    }
  EOC

  CALC_SPAN_SIZE = <<-EOC
    VALUE calcSpanSize(VALUE bpStart, VALUE bpStop)
    {
      long stop = (FIX2LONG(bpStop) - FIX2LONG(bpStart) + 1) ;
      return LONG2FIX(stop) ;
    }
  EOC

  CALC_INCREMENT_FIXNUM = <<-EOC
    VALUE calcIncrementFixnum(VALUE num, VALUE incBy)
    {
      long newNum = (FIX2LONG(num) + FIX2LONG(incBy)) ;
      return LONG2FIX(newNum) ;
    }
  EOC

  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base, :math))
    builder.c(CALC_COORD_STOP)
    builder.c(CALC_SPAN_SIZE)
    builder.c(CALC_INCREMENT_FIXNUM)
    builder.c(ZOOM_LEVEL_STOP_FROM_START)
    builder.c(ZOOM_LEVEL_START_FROM_BP)
    builder.c(UPDATE_ZOOM_LEVEL_REC_DATA)
    builder.c(UPDATE_ZOOM_LEVEL_REC_DATA_USING_SPAN)
  }
end
