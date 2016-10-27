#!/usr/bin/env ruby

require 'brl/genboree/abstract/resources/annotationFile'

# This class is used to get a bed file from the database
# write it to a file on disk

module BRL ; module Genboree ; module Abstract ; module Resources

  class BedFile < AnnotationFile

    # [+dbu+]
    # [+fileName+]
    # [+showTrackHead+]
    # [+options+]
    DEFAULT_SPAN_AGG_FUNCTION = :med
    COLUMN_HEADER_LINE = "#chromosome\tchromStart\tchromEnd\tname\tscore\tstrand\tthickStart\tthickEnd\titemRgb"

    attr_accessor :bucketSum, :bucketCount, :bucketMin, :bucketMax, :bucketSoq
    attr_accessor :coord, :bucket
    def initialize(dbu, fileName=nil, showTrackHead=false, options={})
      super(dbu, fileName)
      @fdataFields = 'fid, rid, fstart, fstop, fscore, fstrand, fphase, gname, displayColor'
      @hdhvType = 'bed'
      # Add the displayColor column for the 9th bed column (itemRgb),
      # however this didn't seem to be implemented, so leaving it out for now.
      # @fdataFields = 'fid, rid, fstart, fstop, fscore, fstrand, fphase, gname, lpad(hex(displayColor),6,0) as displayColor'
      @showTrackHead = showTrackHead
      # Set the @formatOptions instance var called by parent
      @formatOptions = options
      @bucket = []
      @bucketSum = 0.0
      @bucketCount = 0
      @bucketMin = nil
      @bucketMax = nil
      @bucketSoq = 0.0
      # Handle the format specfic options
      # According to UCSC, the score column must be an integer between 0-1000, so by default the score is scaled to be in this range
      @ucscScaleScore = true # default is true
      if(!@formatOptions.nil? and !@formatOptions.empty?)
        @ucscScaleScore = @formatOptions['scaleScores'] == 1 ? true : false
      end
      @bucketEmpty = true
      @prevAnnosStop = nil
      modLastSpan = @formatOptions['modulusLastSpan']
      @modulusLastSpan = if(modLastSpan and !modLastSpan.empty? and modLastSpan =~ /^(?:yes|true)/i) then 1 else 0 end
    end

    # Converts a record from fdata2 to a bed file line.
    # Using bed file definition from here:
    # http://genome.ucsc.edu/FAQ/FAQformat#format1
    #
    # The fdata2 records do not support all the data included in a bed file so
    # some of the optional columns are not included
    #
    #
    # [+rowObj+]    DBI::Row object containing fdata2 record
    # [+returns+]   Bed line string
    def makeLine(rowObj)
      bedLineStr = ""
      fid = rowObj['fid'].to_i
      fscore = rowObj['fscore'].to_f
      fstart = rowObj['fstart'].to_i
      fstop = rowObj['fstop'].to_i
      flength = (fstop - fstart) + 1
      rowObj['gname'].gsub!(" ", "-") if(rowObj['gname'] =~ /\s+/)
      if(!@formatOptions['scoreTrack'].nil? and !@formatOptions['scoreTrack'].empty? and @formatOptions['INTERNAL'])
        if(@blockRecsSize != 0 and @blockIndex < @blockRecsSize)
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
          bedLineStr = "#{@frefNameHash[rowObj['rid']]}\t#{rowObj['fstart'].to_i-1}\t#{rowObj['fstop']}\t#{rowObj['gname']}\t#{@scoreFileHash[rowObj['gname']]}\t#{rowObj['fstrand']}\n"
        else
          bedLineStr = "#{@frefNameHash[rowObj['rid']]}\t#{rowObj['fstart'].to_i-1}\t#{rowObj['fstop']}\t#{rowObj['gname']}\t#{@emptyScoreValue}\t#{rowObj['fstrand']}\n" if(!@emptyScoreValue.nil?)
        end
      else
        score = getScaledScore(rowObj)
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
        bedLineStr = "#{@frefNameHash[rowObj['rid']]}\t#{fstart - 1}\t#{fstop}\t#{rowObj['gname']}\t#{score}\t#{rowObj['fstrand']}"
        thickStart = nil
        thickEnd = nil
        if(@fid2NameAndValueHash.has_key?(fid))
          avpHash = @fid2NameAndValueHash[fid]
          if(!avpHash['thickStart'].empty?)
            thickStart = avpHash['thickStart']
          end
          if(!avpHash['thickEnd'].empty?)
            thickEnd = avpHash['thickEnd']
          end
        end
        if(rowObj['displayColor'])
          displayColor = rowObj['displayColor']
          thickStart = fstart - 1 unless(thickStart)
          thickEnd = fstop unless(thickEnd)
          hexColor = sprintf("%06X", displayColor)
          rgb = hexColor.split('')
          r = (rgb[0].to_i(16) * 16) + rgb[1].to_i(16)
          g = (rgb[2].to_i(16) * 16) + rgb[3].to_i(16)
          b = (rgb[4].to_i(16) * 16) + rgb[5].to_i(16)
          bedLineStr << "\t#{thickStart}\t#{thickEnd}\t#{r},#{g},#{b}"
        else
          if(thickStart)
            bedLineStr << "\t#{thickStart}"
          end
          if(thickEnd)
            bedLineStr << "\t#{thickEnd}"
          end
        end
        bedLineStr << "\n"
      end
      return bedLineStr
    end
    
    def makeAttributeValuePairs(valueString)
      valueString.each { |value|
        thickStart = ""
        thickEnd = ""
        fid = value['fid'].to_i
        if(@attNamesHash[value['attNameId']] == 'thickStart')
          thickStart = value['value']
          if(@fid2NameAndValueHash.key?(fid))
            @fid2NameAndValueHash[fid]['thickStart'] = thickStart
          else
            @fid2NameAndValueHash[fid] = {'thickStart' => thickStart}
          end
        elsif(@attNamesHash[value['attNameId']] == 'thickEnd')
          thickEnd = value['value']
          if(@fid2NameAndValueHash.key?(fid))
            @fid2NameAndValueHash[fid]['thickEnd'] = thickEnd
          else
            @fid2NameAndValueHash[fid] = {'thickEnd' => thickEnd } 
          end
        end
      }
    end

    # Adds lifted scores from a score track to an ROI annotation
    # [+rowObj+] ROI record
    # [+rowCount+] Index for extracting the right aggregates
    # [+returns+] line
    def addLiftedScores(rowObj, rowCount)
      line = ""
      fscore = nil
      fstop = rowObj['fstop'].to_i
      fstart = rowObj['fstart'].to_i
      flength = (fstop - fstart) + 1
      fscore = getScore(rowObj, rowCount)
      fscore = @emptyScoreValue if(!fscore and @emptyScoreValue)
      if(fscore)
        line = "#{@frefNameHash[rowObj['rid']]}\t#{fstart.to_i-1}\t#{fstop}\t" +
                "#{rowObj['gname']}\t#{fscore}\t#{rowObj['fstrand']}\n"
      end
      return line
    end

    def makeTrackHead
      "track name=\"#{@ftypeHash['fmethod']}:#{@ftypeHash['fsource']}\"\n"
    end

    # This method takes a row of fdata2 data and expands it into span=1
    #
    # [+row+]       DBI::Row object containing fdata2 record
    def expandRow(row, span=1)
      chrom = @frefNameHash[row['rid']]
      if(span == 1)
        score = getScaledScore(row['fscore'])
        (row['fstart']..row['fstop']).each { |nn|
          next if(!@start.nil? and nn < start)
          break if(!@stop.nil? and nn > @stop)
          yield "#{@frefNameHash[row['rid']]}\t#{@coord.to_i-1}\t#{@coord}\t#{@frefNameHash[row['rid']]}:#{@coord - 1}-#{@coord}\t#{score}\t+\n"
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
            # Check if scaling is required
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
            # yield the line
            yield "#{@frefNameHash[row['rid']]}\t#{@coord.to_i-1}\t#{@coord + (@dataSpan - 1)}\t#{@frefNameHash[row['rid']]}:#{@coord - 1}-#{@coord + (@dataSpan - 1)}\t#{score}\t+\n"
            # empty the bucket
            @bucket = []
            @bucketSum = 0.0
            @bucketCount = 0
            @bucketMin = nil
            @bucketMax = nil
            @bucketSoq = 0.0
            @coord = nn
            @bucketEmpty = true
          end
          @coord = nn if(@bucketEmpty and @emptyScoreValue.nil?) # We're starting a new bucket
          @bucketEmpty = false
          updateAggs(row['fscore'].to_f)
        }
      end
    end

    # Overridden to set span
    def eachChunkForChromosomeWithSpan(ridRow, start, stop, ftypeId)
      @lastCoord, @prevStart, @coord = nil
      @dataSpan = @formatOptions['desiredSpan'].to_i
      # Ensure that @formatOptions['spanAggFunction'] is set
      @formatOptions['spanAggFunction'] = DEFAULT_SPAN_AGG_FUNCTION if(@formatOptions['spanAggFunction'].nil?)
      @denomForAvgByLength = @formatOptions['desiredSpan'].to_i
    end


    # [+ridRow+]
    # [+start+] requested start coordinate
    # [+stop+] requested stop coordinate
    # [+ftypeId+] ftypeId of the requested track
    # [+returns+] yields chunks of bedGraph records
    def eachChunkFromFdataWithSpan(ridRow, start, stop, ftypeId)
      buffer = ''
      dbRec = @trackObj.getDbRecWithData()
      @dbu.setNewDataDb(dbRec.dbName)
      @numLines = 0
      @start = start.nil? ? 1 : start.to_i
      @stop = stop.nil? ? @frefHash[ridRow['rid']].to_i : stop.to_i
      @stop = @stop < @frefHash[ridRow['rid']].to_i ? @stop : @frefHash[ridRow['rid']].to_i
      @bucketEmpty = true
      # Check if 'emptyScoreValue' parameter is provided for regular downloads
      # If it is provided, we need to fill in the gaps
      if(!@formatOptions['emptyScoreValue'].nil? and !@formatOptions['emptyScoreValue'].empty?)
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
        yieldBedLinesWithEmptyScoreValues(@coord, @dataSpan, @stop, emptyScoreValue, ridRow) { |block| yield block}
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

    def processDataRows(fdataRows, ridRow)
      fdataRows.each { |fdataRow|
        annosStart =  fdataRow['fstart'].to_i  # start coord of the row to be expanded
        if(@emptyScoreValue and @coord < annosStart) # Check if we need to add empty score values
          if(@prevAnnosStop.nil? or @prevAnnosStop < annosStart) # Only add if no overlaps
            yieldBedLinesWithEmptyScoreValues(@coord, @dataSpan, annosStart, @emptyScoreValue, ridRow) { |line|
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

    # makes bed records with provided 'emptyScoreValue'
    # [+start+] requested start coordinate
    # [+span+] requested span
    # [+annosStart+] start coordinate of annotation from fdata2
    # [+emptyScoreValue+]
    # [+ridRow+]
    # [+returns] yields bed lines
    def yieldBedLinesWithEmptyScoreValues(start, span, annosStart, emptyScoreValue, ridRow)
      coordTracker = start + (span - 1)
      score = @bucketEmpty ? emptyScoreValue : calcAggValue(@bucket)
      chrom = @frefNameHash[ridRow['rid']]
      while(coordTracker < annosStart)
        yield "#{@frefNameHash[ridRow['rid']]}\t#{@coord.to_i-1}\t#{coordTracker}\t#{@frefNameHash[ridRow['rid']]}:#{@coord - 1}-#{coordTracker}\t#{score}\t+\n"
        @coord = coordTracker + 1
        coordTracker += span
        score = emptyScoreValue
      end
      if(@modulusLastSpan == 1)
        yield "#{@frefNameHash[ridRow['rid']]}\t#{@coord.to_i-1}\t#{@stop}\t#{@frefNameHash[ridRow['rid']]}:#{@coord - 1}-#{@stop}\t#{score}\t+\n" if(coordTracker >= @stop)
      else
        yield "#{@frefNameHash[ridRow['rid']]}\t#{@coord.to_i-1}\t#{@coord + (@dataSpan - 1)}\t#{@frefNameHash[ridRow['rid']]}:#{@coord - 1}-#{@coord + (@dataSpan - 1)}\t#{score}\t+\n" if(coordTracker >= @stop)
      end
    end

  end

  class Bed3ColFile < AnnotationFile
    COLUMN_HEADER_LINE = "#chromosome\tchromStart\tchromEnd"

    def initialize(dbu, fileName=nil, showTrackHead=false)
      super(dbu, fileName)
      @fdataFields = 'fid, rid, fstart, fstop'
      @showTrackHead = showTrackHead
    end

    # Make a 3 col Bed file line
    def makeLine(rowObj)
      bedLineStr = "#{@frefNameHash[rowObj['rid']]}\t#{rowObj['fstart'].to_i-1}\t#{rowObj['fstop']}\n"
    end

    def makeTrackHead
      "track name=\"#{@ftypeHash['fmethod']}:#{@ftypeHash['fsource']}\"\n"
    end

  end

  class BedGraphFile < AnnotationFile
    DEFAULT_SPAN_AGG_FUNCTION = :med
    COLUMN_HEADER_LINE = "#chromosome\tchromStart\tchromEnd\tscore"

    attr_accessor :bucketSum, :bucketCount, :bucketMin, :bucketMax, :bucketSoq
    attr_accessor :coord, :bucket
    def initialize(dbu, fileName=nil, showTrackHead=false, options={})
      super(dbu, fileName)
      @fdataFields = 'fid, rid, fstart, fstop, fscore, gname'
      @hdhvType = 'bedGraph'
      @bucket = []
      @showTrackHead = showTrackHead
      @formatOptions = options
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

    # [+rowObj+]
    # [+returns+] bedLineStr
    def makeLine(rowObj)
      bedLineStr = ""
      fid = rowObj['fid'].to_i
      fscore = rowObj['fscore'].to_f
      fstart = rowObj['fstart'].to_i
      fstop = rowObj['fstop'].to_i
      flength = (fstop - fstart) + 1
      if(!@formatOptions['scoreTrack'].nil? and !@formatOptions['scoreTrack'].empty? and @formatOptions['INTERNAL'])
        if(@blockRecsSize != 0 and @blockIndex < @blockRecsSize)
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
          bedLineStr = "#{@frefNameHash[rowObj['rid']]}\t#{rowObj['fstart'].to_i-1}\t#{rowObj['fstop']}\t#{@scoreFileHash[rowObj['gname']]}\n"
        else
          bedLineStr = "#{@frefNameHash[rowObj['rid']]}\t#{rowObj['fstart'].to_i-1}\t#{rowObj['fstop']}\t#{@emptyScoreValue}\n" if(!@emptyScoreValue.nil?)
        end
      else
        extendAnnosVal = @formatOptions['extendAnnos'].nil? ? nil : @formatOptions['extendAnnos']
        truncateAnnosVal = @formatOptions['truncateAnnos'].nil? ? nil : @formatOptions['truncateAnnos']
        if(extendAnnosVal and (fstop - fstart) + 1 < extendAnnosVal)
          fstop = fstart + (extendAnnosVal - 1)
        end
        if(truncateAnnosVal and (fstop - fstart) + 1 > truncateAnnosVal)
          fstop = fstart + (truncateAnnosVal - 1)
        end
        bedLineStr = "#{@frefNameHash[rowObj['rid']]}\t#{fstart - 1}\t#{fstop}\t#{fscore}\n"
      end
      return bedLineStr
    end

    # Adds lifted scores from a score track to an ROI annotation
    # [+rowObj+] ROI record
    # [+rowCount+] Index for extracting the right aggregates
    # [+returns+] line
    def addLiftedScores(rowObj, rowCount)
      line = ""
      fscore = nil
      fstop = rowObj['fstop'].to_i
      fstart = rowObj['fstart'].to_i
      flength = (fstop - fstart) + 1
      fscore = getScore(rowObj, rowCount)
      fscore = @emptyScoreValue if(!fscore and @emptyScoreValue)
      if(fscore)
        line << "#{@frefNameHash[rowObj['rid']]}\t#{rowObj['fstart'].to_i-1}\t#{rowObj['fstop']}\t#{fscore}\n"
      end
      return line
    end

    def makeTrackHead
      "track type=bedGraph name=\"#{@ftypeHash['fmethod']}:#{@ftypeHash['fsource']}\"\n"
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
          yield "#{@frefNameHash[row['rid']]}\t#{@coord.to_i-1}\t#{@coord}\t#{tempScore}\n"
        }
      else
        # Add the values to a bucket
        (row['fstart']..row['fstop']).each { |nn|
          next if(!@start.nil? and nn < @start)
          break if(!@stop.nil? and nn > @stop)
          # If the bucket is full or we've moved out of the span, dump the bucket
          if(!@coord.nil? and nn >= @coord + span)
            # perform statistics on bucket
            score = calcAggValue(@bucket)
            # yield the line
            yield "#{@frefNameHash[row['rid']]}\t#{@coord.to_i-1}\t#{@coord + (@dataSpan - 1)}\t#{tempScore}\n"
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
          # Add the score to the bucket
          # Depending on the aggregating function, do the needful
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

    # [+ridRow+]
    # [+start+] requested start coordinate
    # [+stop+] requested stop coordinate
    # [+ftypeId+] ftypeId of the requested track
    # [+returns+] yields chunks of bedGraph records
    def eachChunkFromFdataWithSpan(ridRow, start, stop, ftypeId)
      buffer = ''
      dbRec = @trackObj.getDbRecWithData()
      @dbu.setNewDataDb(dbRec.dbName)
      @numLines = 0
      @start = start.nil? ? 1 : start.to_i
      @stop = stop.nil? ? @frefHash[ridRow['rid']].to_i : stop.to_i
      @stop = @stop < @frefHash[ridRow['rid']].to_i ? @stop : @frefHash[ridRow['rid']].to_i
      @bucketEmpty = true
      # Check if 'emptyScoreValue' parameter is provided for regular downloads
      # If it is provided, we need to fill in the gaps
      #$stderr.puts "@formatOptions['emptyScoreValue']: #{@formatOptions['emptyScoreValue'].inspect}"
      if((!@formatOptions['emptyScoreValue'].nil? and !@formatOptions['emptyScoreValue'].empty? ))
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
        yieldBedGraphLinesWithEmptyScoreValues(@coord, @dataSpan, @stop, emptyScoreValue, ridRow) { |block| yield block}
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

    def processDataRows(fdataRows, ridRow)
      fdataRows.each { |fdataRow|
        annosStart =  fdataRow['fstart'].to_i  # start coord of the row to be expanded
        if(@emptyScoreValue and @coord < annosStart) # Check if we need to add empty score values
          if(@prevAnnosStop.nil? or @prevAnnosStop < annosStart) # Only add if no overlaps
            yieldBedGraphLinesWithEmptyScoreValues(@coord, @dataSpan, annosStart, @emptyScoreValue, ridRow) { |line|
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

    # makes bedGraph records with provided 'emptyScoreValue'
    # [+start+] requested start coordinate
    # [+span+] requested span
    # [+annosStart+] start coordinate of annotation from fdata2
    # [+emptyScoreValue+]
    # [+ridRow+]
    # [+returns] yields bedgraph lines
    def yieldBedGraphLinesWithEmptyScoreValues(start, span, annosStart, emptyScoreValue, ridRow)
      coordTracker = start + (span - 1)
      score = @bucketEmpty ? emptyScoreValue : calcAggValue(@bucket)
      chrom = @frefNameHash[ridRow['rid']]
      while(coordTracker < annosStart)
        yield "#{chrom}\t#{@coord.to_i-1}\t#{coordTracker}\t#{score}\n"
        @coord = coordTracker + 1
        coordTracker += span
        score = emptyScoreValue
      end
      if(@modulusLastSpan == 1)
        yield "#{chrom}\t#{@coord.to_i-1}\t#{@stop}\t#{score}\n" if(coordTracker >= @stop)
      else
        yield "#{chrom}\t#{@coord.to_i-1}\t#{coordTracker}\t#{score}\n" if(coordTracker >= @stop)
      end
    end
    
    

    # Makes AVPs for the current record
    # [+valueString+]
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
