#!/usr/bin/env ruby
require 'brl/genboree/abstract/resources/annotationFile'

module BRL ; module Genboree ; module Abstract ; module Resources

class LffFile < AnnotationFile
  # [+dbu+]
  # [+fileName+]
  # [+showTrackHead+]
  # [+options+]

  COLUMN_HEADER_LINE = "#class\tname\ttype\tsubtype\tchromosome\tstart\tstop\tstrand\tphase\tscore\tqStart\tqStop\tattributes\tsequence\tcomments"
  DEFAULT_SPAN = 20
  DEFAULT_SPAN_AGG_FUNCTION = :med

  attr_accessor :bucketSum, :bucketCount, :bucketMin, :bucketMax, :bucketSoq
  attr_accessor :coord, :bucket
  def initialize(dbu, fileName=nil, showTrackHead=false, options={})
    super(dbu, fileName)
    @fdataFields = 'fid, rid, fstart, fstop, fscore, fstrand, fphase, gname, ftarget_start, ftarget_stop'
    @hdhvType = 'lff'
    @showTrackHead = showTrackHead
    @formatOptions = options
    @bucket = [] # Used for scoring scores when computing statistical functions for different spans
    @bucketSum = 0.0
    @bucketCount = 0
    @bucketMin = nil
    @bucketMax = nil
    @bucketSoq = 0.0
    @bucketEmpty = true
    @prevAnnosStop = nil
    modLastSpan = @formatOptions['modulusLastSpan']
    @modulusLastSpan = if(modLastSpan and !modLastSpan.empty? and modLastSpan =~ /^(?:yes|true)/i) then 1 else 0 end
  end

  def otherSections(frefNames)
    retVal = nil
    if(frefNames and !frefNames.empty?)
      frefs = @dbu.selectFrefsByNames(frefNames)
      if(frefs)
        retVal = "[entrypoints]\n"
        frefs.each { |frefRec|
          retVal << "#{frefRec['refname']}\tChromosome\t#{frefRec['rlength']}\n"
        }
        retVal << "\n[annotations]\n"
      end
    end
    return retVal
  end

  # Converts a record from fdata2 to a lff file line.
  #
  # [+rowObj+]    DBI::Row object containing fdata2 record
  # [+returns+]   lff line string
  def makeLine(rowObj)
    lffLineStr = ""
    fid = rowObj['fid'].to_i
    fscore = rowObj['fscore'].to_f
    fstart = rowObj['fstart'].to_i
    fstop = rowObj['fstop'].to_i
    flength = (fstop - fstart) + 1
    if(!@formatOptions['scoreTrack'].nil? and !@formatOptions['scoreTrack'].empty? and @formatOptions['INTERNAL'])
      if(@blockRecsSize != 0 and @blockIndex < @blockRecsSize)
        # TODO: this is slow, even for just a few fdata2s whose scores should be in 1 or perhaps 2 blocks
        if(@scoreTrkIsHdhv)
          @blockIndex = @hdhvObj.getScoreByAnnos(@blockRecs, fstart, fstop, @formatOptions, @blockIndex, @blockRecsSize)
          updateAggregates()
        else
          @blockIndex = getScoreFromNonHDScrTrk(@blockRecs, fstart, fstop, @formatOptions, @blockIndex, @blockRecsSize)
        end
      else
        # Do nothing
      end
    elsif(!@formatOptions['scoreFile'].nil? and !@formatOptions['scoreFile'].empty?)
      if(@scoreFileHash.has_key?(rowObj['gname']))
        fscore = @scoreFileHash[rowObj['gname']]
        phaseStr = (rowObj['fphase'].empty? ? '.' : rowObj['fphase'])
        lffLineStr = "#{@className}\t#{rowObj['gname']}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{@frefNameHash[rowObj['rid']]}\t" +
                     "#{fstart}\t#{fstop}\t#{rowObj['fstrand']}\t#{phaseStr}\t#{fscore}"
        if(@fid2NameAndValueHash.has_key?(fid))
          lffLineStr = addAVPs(rowObj, lffLineStr, fid)
        else
          lffLineStr << "\n"
        end
      else
        if(!@emptyScoreValue.nil?)
          phaseStr = (rowObj['fphase'].empty? ? '.' : rowObj['fphase'])
          lffLineStr = "#{@className}\t#{rowObj['gname']}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{@frefNameHash[rowObj['rid']]}\t" +
                       "#{fstart}\t#{fstop}\t#{rowObj['fstrand']}\t#{phaseStr}\t#{@emptyScoreValue}"
          if(@fid2NameAndValueHash.has_key?(fid))
            lffLineStr = addAVPs(rowObj, lffLineStr, fid)
          else
            lffLineStr << "\n"
          end
        end
      end
    else
      extendAnnosVal = @formatOptions['extendAnnos'].nil? ? nil : @formatOptions['extendAnnos']
      truncateAnnosVal = @formatOptions['truncateAnnos'].nil? ? nil : @formatOptions['truncateAnnos']
      if(extendAnnosVal and (fstop - fstart) + 1 < extendAnnosVal)
        if(rowObj['fstrand'] == '+')
          fstop = fstart + (extendAnnosVal - 1)
        else
          fstart = fstop - (extendAnnosVal - 1)
        end
      end
      if(truncateAnnosVal and (fstop - fstart) + 1 > truncateAnnosVal)
        if(rowObj['fstrand'] == '+')
          fstop = fstart + (truncateAnnosVal - 1)
        else
          fstart = fstop - (truncateAnnosVal - 1)
        end
      end
      phaseStr = (rowObj['fphase'].empty? ? '.' : rowObj['fphase'])
      lffLineStr = "#{@className}\t#{rowObj['gname']}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{@frefNameHash[rowObj['rid']]}\t" +
                   "#{fstart}\t#{fstop}\t#{rowObj['fstrand']}\t#{phaseStr}\t#{fscore}"
      if(@fid2NameAndValueHash.has_key?(fid))
        lffLineStr = addAVPs(rowObj, lffLineStr, fid)
      else
        lffLineStr << "\n"
      end
    end
    return lffLineStr
  end

  # Adds lifted scores from a score track to an ROI annotation
  # [+rowObj+] ROI record
  # [+rowCount+] Index for extracting the right aggregates
  # [+returns+] line
  def addLiftedScores(rowObj, rowCount)
    line = ""
    fscore = nil
    fid = rowObj['fid'].to_i
    fstop = rowObj['fstop'].to_i
    fstart = rowObj['fstart'].to_i
    flength = (fstop - fstart) + 1
    phase = (rowObj['fphase'].empty? ? '0' : rowObj['fphase'])
    fscore = getScore(rowObj, rowCount)
    fscore = @emptyScoreValue if(!fscore and @emptyScoreValue)
    if(fscore)
      phase = (rowObj['fphase'].empty? ? '.' : rowObj['fphase'])
      line = "#{@className}\t#{rowObj['gname']}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{@frefNameHash[rowObj['rid']]}\t" +
                   "#{fstart}\t#{fstop}\t#{rowObj['fstrand']}\t#{phase}\t#{fscore}"
      if(@fid2NameAndValueHash.has_key?(fid))
        line = addAVPs(rowObj, line, fid)
      else
        line << "\n"
      end
    end
    return line
  end

  # makes an lff line from a row object from the zoomLevels table
  # [+rowObj+] DBI:row object
  # [+zoomLevelsFunction+] 'AVG' or 'MIN' or 'MAX'
  # [+returns+] lffLineStr
  def makeLineFromZoomLevels(rowObj, zoomLevelsFunction)
    score = 0
    fstart = rowObj['fstart']
    fstop = rowObj['fstop']
    chr = @frefNameHash[rowObj['rid']]
    case zoomLevelsFunction
    when 'AVG'
      score = (rowObj['scoreSum'].to_f + rowObj['negScoreSum'].to_f) / (rowObj['scoreCount'].to_i + rowObj['negScoreCount'].to_i)
    when 'MAX'
      score = rowObj['scoreMax'].to_f
    when 'MIN'
      score = rowObj['scoreMin'].to_f
    end
    lffLineStr = "#{@className}\t#{chr}:#{fstart}-#{fstop}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t" +
               "#{chr}\t#{fstart}\t#{fstop}\t+\t.\t#{score}"
    return lffLineStr
  end

  # add AVPs to the string (if present)
  # [+rowObj+]
  def addAVPs(rowObj, lffLineStr, fid)
    qstart = rowObj['ftarget_start'].nil? ? "." : "#{rowObj['ftarget_start']}"
    qstop = rowObj['ftarget_stop'].nil? ? "." : "#{rowObj['ftarget_stop']}"
    lffLineStr << "\t#{qstart}\t#{qstop}\t#{@fid2NameAndValueHash[fid]}\t"
    if(!@fid2CommentsHash.has_key?(fid) and !@fid2SequenceHash.has_key?(fid))
      lffLineStr << "\n"
    elsif(@fid2CommentsHash.has_key?(fid) and !@fid2SequenceHash.has_key?(fid))
      lffLineStr << ".\t#{@fid2CommentsHash[fid]}\n"
    elsif(!@fid2CommentsHash.has_key?(fid) and @fid2SequenceHash.has_key?(fid))
      lffLineStr << "#{@fid2SequenceHash[fid]}\n"
    elsif(@fid2CommentsHash.has_key?(fid) and @fid2CommentsHash.has_key?(fid))
      lffLineStr << "#{@fid2SequenceHash[fid]}\t#{@fid2CommentsHash[fid]}\n"
    end
    return lffLineStr
  end


  # This method takes a row of fdata2 data and expands it into span=1
  #
  # [+row+]       DBI::Row object containing fdata2 record
  def expandRow(row, span=1)
    chrom = @frefNameHash[row['rid']]
    tempScore = row['fscore'].to_f
    if(span == 1)
      (row['fstart']..row['fstop']).each { |nn|
        next if(!@start.nil? and nn < start)
        break if(!@stop.nil? and nn > @stop)
        yield "#{@className}\t#{chrom}:#{nn}-#{nn}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{chrom}\t#{nn}\t#{nn}\t" +
                          "+\t.\t#{tempScore}\n"
      }
    else
      # Add the values to a bucket
      (row['fstart']..row['fstop']).each { |nn|
        next if(!@start.nil? and nn < @start)
        break if(!@stop.nil? and nn > @stop)
        # If the bucket is full or we've moved out of the span, dump the bucket
        if(!@coord.nil? and nn >= @coord + span)
          # perform statistical function on bucket
          score = calcAggValue(@bucket)
          # yield the line
          yield "#{@className}\t#{chrom}:#{@coord}-#{@coord + (span - 1)}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{chrom}\t#{@coord}\t#{@coord + (span - 1)}\t" +
                          "+\t.\t#{tempScore}\n"
          # empty the bucket
          @bucket = []
          @bucketSum = 0.0
          @bucketCount = 0
          @bucketMin = nil
          @bucketMax = nil
          @bucketSoq = 0.0
          @bucketEmpty = true
          @coord = nn
        end
        @coord = nn if(@bucketEmpty and @emptyScoreValue.nil?) # We're starting a new bucket
        @bucketEmpty = false
        tempScore = row['fscore'].to_f
        updateAggs(tempScore)
      }
    end
  end

  # Overridden to set span
  def eachChunkForChromosomeWithSpan(ridRow, start, stop, ftypeId)
    @lastCoord, @prevStart, @coord = nil
    @dataSpan = @formatOptions['desiredSpan'].to_i
    # Ensure that @formatOptions['spanAggFunction'] is set
    #$stderr.puts "in here"
    @formatOptions['spanAggFunction'] = DEFAULT_SPAN_AGG_FUNCTION if(@formatOptions['spanAggFunction'].nil?)
    @denomForAvgByLength = @formatOptions['desiredSpan'].to_i
  end

  # Gets chunks of fdata2 records, expands according to @dataSpan and creates wig lines
  # [+ridRow+]
  # [+start+] requested start coordinate
  # [+stop+] requested stop coordinate
  # [+ftypeId+] ftypeId of the requested track
  # [+returns+] yields chunks of wig records
  def eachChunkFromFdataWithSpan(ridRow, start, stop, ftypeId)
    buffer = ''
    dbRec = @trackObj.getDbRecWithData()
    @dbu.setNewDataDb(dbRec.dbName)
    @numLines = 0
    @bucketEmpty = true
    @start = start.nil? ? 1 : start.to_i
    @stop = stop.nil? ? @frefHash[ridRow['rid']].to_i : stop.to_i
    @stop = @stop < @frefHash[ridRow['rid']].to_i ? @stop : @frefHash[ridRow['rid']].to_i
    # Check if 'emptyScoreValue' parameter is provided for regular downloads
    # If it is provided, we need to fill in the gaps
    if((!@formatOptions['emptyScoreValue'].nil? and !@formatOptions['emptyScoreValue'].empty?))
      @emptyScoreValue = @formatOptions['emptyScoreValue']
      @coord = @start # @coord will track the start coord of bucket/window throughout the download
    else
      @emptyScoreValue = nil
    end
    noRecsFound = true
    @dbu.eachBlockOfFdataByLandmark(ridRow['rid'], ftypeId, @start, @stop, @fdataFields) { |annoDataRows|
      noRecsFound = false
      processDataRows(annoDataRows, ridRow) { |line|
        buffer << line
        if(buffer.size > MAX_BUFFER_SIZE)
          yield buffer
          buffer = ''
        end
      }
      yield buffer if(buffer.size > 0)
    }
    endCoordForLastRec = @coord + (@dataSpan - 1) if(!@emptyScoreValue.nil?)
    # Add trailing emptyScoreValues if required
    if(@emptyScoreValue and endCoordForLastRec < @stop)
      yieldLffLinesWithEmptyScoreValues(@coord, @dataSpan, @stop, emptyScoreValue, ridRow) { |block| yield block}
    elsif(@emptyScoreValue and noRecsFound and @stop < endCoordForLastRec)
      chrom = @frefNameHash[ridRow['rid']]
      if(@modulusLastSpan == 1)
        yield "#{chrom}\t#{@coord.to_i-1}\t#{@stop}\t#{@emptyScoreValue}\n" 
      else
        yield "#{chrom}\t#{@coord.to_i-1}\t#{endCoordForLastRec}\t#{@emptyScoreValue}\n"
      end
    else
      # No-op
    end
    @prevAnnosStop = nil
  end

  # Loops over all fdata2 recs for the current set of fdata2 recs
  # [+fdataRows+] a chunk of fdata2 recs in sorted order
  # [+ridRow+] row with rid(chr) info
  # [+returns+] yields chunks of lff records
  def processDataRows(fdataRows, ridRow)
    fdataRows.each { |fdataRow|
      annosStart =  fdataRow['fstart'].to_i  # start coord of the row to be expanded
      if(@emptyScoreValue and @coord < annosStart) # Check if we need to add empty score values
        if(@prevAnnosStop.nil? or @prevAnnosStop < annosStart) # Only add if no overlaps
          yieldLffLinesWithEmptyScoreValues(@coord, @dataSpan, annosStart, @emptyScoreValue, ridRow) { |line|
            yield line
          }
          @lastCoord = annosStart - 1
        else 
          updateAggs(fdataRow['fscore'].to_f)
          next if(fdataRow['fstop'] == @prevAnnosStop)
          fdataRow['fstart'] = @prevAnnosStop + 1
        end
      end
      # Expand the row
      expandRow(fdataRow, @dataSpan) { |line|
        yield line
      }
      @prevAnnosStop = fdataRow['fstop'].to_i
    }
  end

  # makes lff records with provided 'emptyScoreValue'
  # [+start+] requested start coordinate
  # [+span+] requested span
  # [+annosStart+] start coordinate of annotation from fdata2
  # [+emptyScoreValue+]
  # [+ridRow+]
  # [+returns] yields lff lines
  def yieldLffLinesWithEmptyScoreValues(start, span, annosStart, emptyScoreValue, ridRow)
    coordTracker = start + (span - 1)
    score = @bucketEmpty ? emptyScoreValue : calcAggValue(@bucket)
    chrom = @frefNameHash[ridRow['rid']]
    while(coordTracker < annosStart)
      yield "#{@className}\t#{chrom}:#{@coord}-#{coordTracker}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{chrom}\t#{@coord}\t#{coordTracker}\t" +
                          "+\t.\t#{score}\n"
      @coord = coordTracker + 1
      coordTracker += span
      score = emptyScoreValue
    end
    if(@modulusLastSpan == 1)
      yield "#{@className}\t#{chrom}:#{@coord}-#{@stop}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{chrom}\t#{@coord}\t#{@stop}\t" +
                          "+\t.\t#{score}\n" if(coordTracker >= @stop)
    else
      yield "#{@className}\t#{chrom}:#{@coord}-#{coordTracker}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{chrom}\t#{@coord}\t#{coordTracker}\t" +
                          "+\t.\t#{score}\n" if(coordTracker >= @stop)
    end
  end

  def makeAttributeValuePairs(valueString)
    valueString.each { |value|
      key = value['fid'].to_i
      if(@fid2NameAndValueHash.has_key?(key))
        @fid2NameAndValueHash[key] = @fid2NameAndValueHash[key] + "#{@attNamesHash[value['attNameId']]}=#{value['value']}; "
      else
        @fid2NameAndValueHash[key] = "#{@attNamesHash[value['attNameId']]}=#{value['value']}; "
      end
    }
    comments = @dbu.selectFidWithCommentsByFtypeIdAndFids(@ftypeId, @fidArray)
    if(!comments.nil? and !comments.empty?)
      comments.each { |comment|
        @fid2CommentsHash[comment['fid'].to_i] = comment['text']
      }
    end
    sequences = @dbu.selectFidWithSequenceByFtypeIdAndFids(@ftypeId, @fidArray)
    if(!sequences.nil? and !sequences.empty?)
      sequences.each { |seq|
        @fid2SequenceHash[seq['fid'].to_i] = seq['text']
      }
    end
  end
end

end ; end ; end ; end
