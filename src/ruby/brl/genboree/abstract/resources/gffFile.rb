#!/usr/bin/env ruby

require 'brl/genboree/abstract/resources/annotationFile'

# This class is used to get a bed file from the database
# write it to a file on disk

module BRL ; module Genboree ; module Abstract ; module Resources


  class GffFile < AnnotationFile
    DEFAULT_SPAN_AGG_FUNCTION = :med
    COLUMN_HEADER_LINE = "#chromosome\tsource\ttype\tstart\tend\tscore\tstrand\tphase\tgroup"

    attr_accessor :bucketSum, :bucketCount, :bucketMin, :bucketMax, :bucketSoq
    attr_accessor :coord, :bucket
    def initialize(dbu, fileName=nil, showTrackHead=false, options={})
      super(dbu, fileName)
      @fdataFields = 'fid, rid, fstart, fstop, fscore, fstrand, fphase, gname'
      @hdhvType = 'gff'
      @showTrackHead = showTrackHead
      @formatOptions = options
      @bucket = []
      # Handle the format specfic options
      @ucscScaleScore = false # default is false
      if(!@formatOptions.nil? and !@formatOptions.empty?)
        @ucscScaleScore = @formatOptions['scaleScores'] == 1 ? true : false
      end
      @bucketEmpty = true
      @prevAnnosStop = nil
      @bucketSum = 0.0
      @bucketCount = 0
      @bucketMin = nil
      @bucketMax = nil
      @bucketSoq = 0.0
      modLastSpan = @formatOptions['modulusLastSpan']
      @modulusLastSpan = if(modLastSpan and !modLastSpan.empty? and modLastSpan =~ /^(?:yes|true)/i) then 1 else 0 end
    end

    # Converts a record from fdata2 to a gff file line.
    # Using gff file definition from here:
    # http://genome.ucsc.edu/FAQ/FAQformat#format3
    #
    # [+rowObj+]    DBI::Row object containing fdata2 record
    # [+returns+]   Bed line string
    def makeLine(row)
      gffLineStr = ""
      fid = row['fid'].to_i
      fscore = row['fscore'].to_f
      fstart = row['fstart'].to_i
      fstop = row['fstop'].to_i
      flength = (fstop - fstart) + 1
      phase = row['fphase'].empty? ? '.' : row['fphase']
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
        if(@scoreFileHash.has_key?(row['gname']))
          gffLineStr = "#{@frefNameHash[row['rid']]}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{row['fstart']}\t#{row['fstop']}\t#{@scoreFileHash[row['gname']]}\t#{row['fstrand']}\t#{phase}\t#{row['gname']}\n"
        else
          gffLineStr = "#{@frefNameHash[row['rid']]}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{row['fstart']}\t#{row['fstop']}\t#{@emptyScoreValue}\t" +
                      "#{row['fstrand']}\t#{phase}\t#{row['gname']}\n" if(!@emptyScoreValue.nil?)
        end
      else
        score = getScaledScore(row)
        extendAnnosVal = @formatOptions['extendAnnos'].nil? ? nil : @formatOptions['extendAnnos']
        truncateAnnosVal = @formatOptions['truncateAnnos'].nil? ? nil : @formatOptions['truncateAnnos']
        if(extendAnnosVal and (fstop - fstart) + 1 < extendAnnosVal)
          if(row['fstrand'] == '+')
            fstop = fstart + (extendAnnosVal - 1)
          else
            fstart = fstop - (extendAnnosVal - 1)
          end
        end
        if(truncateAnnosVal and (fstop - fstart) + 1 > truncateAnnosVal)
          if(row['fstrand'] == '+')
            fstop = fstart + (truncateAnnosVal - 1)
          else
            fstart = fstop - (truncateAnnosVal - 1)
          end
        end
        gffLineStr = "#{@frefNameHash[row['rid']]}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{fstart}\t#{fstop}\t#{score}\t#{row['fstrand']}\t#{phase}\t#{row['gname']}\n"
      end
      return gffLineStr
    end

    def makeTrackHead
      "track name=#{@ftypeHash['fmethod']}:#{@ftypeHash['fsource']}\n"
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
        line << "#{@frefNameHash[rowObj['rid']]}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{fstart}\t#{fstop}\t" +
        "#{fscore}\t#{rowObj['fstrand']}\t#{phase}\t#{rowObj['gname']}\n"
      end
      return line
    end

    # This method takes a row of fdata2 data and expands it into span=1
    #
    # [+row+]       DBI::Row object containing fdata2 record
    def expandRow(row, span=1)
      chrom = @frefNameHash[row['rid']]

      if(span == 1)
        score = getScaledScore(row)
        (row['fstart']..row['fstop']).each { |nn|
          next if(!@start.nil? and nn < start)
          break if(!@stop.nil? and nn > @stop)
          yield "#{@frefNameHash[row['rid']]}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{nn}\t#{nn}\t" +
                     "#{score}\t+\t.\t#{@frefNameHash[row['rid']]}:#{nn}-#{nn}\n"
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
            yield "#{@frefNameHash[row['rid']]}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{@coord}\t#{@coord + (@dataSpan - 1)}\t" +
                     "#{score}\t+\t.\t#{@frefNameHash[row['rid']]}:#{@coord}-#{@coord + (@dataSpan - 1)}\n"
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

    # Gets chunks of fdata2 records, expands according to @dataSpan and creates gff lines
    # [+ridRow+]
    # [+start+] requested start coordinate
    # [+stop+] requested stop coordinate
    # [+ftypeId+] ftypeId of the requested track
    # [+returns+] yields chunks of gff records
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
        yieldGffLinesWithEmptyScoreValues(@coord, @dataSpan, @stop, emptyScoreValue, ridRow) { |block| yield block}
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

    # makes gff records with provided 'emptyScoreValue'
    # [+start+] requested start coordinate
    # [+span+] requested span
    # [+annosStart+] start coordinate of annotation from fdata2
    # [+emptyScoreValue+]
    # [+ridRow+]
    # [+returns] yields gff lines
    def yieldGffLinesWithEmptyScoreValues(start, span, annosStart, emptyScoreValue, ridRow)
      coordTracker = start + (span - 1)
      score = @bucketEmpty ? emptyScoreValue : calcAggValue(@bucket)
      chrom = @frefNameHash[ridRow['rid']]
      while(coordTracker < annosStart)
        yield "#{chrom}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{@coord}\t#{coordTracker}\t#{score}\t+\t.\t#{chrom}:#{@coord}-#{coordTracker}\n"
        @coord = coordTracker + 1
        coordTracker += span
        score = emptyScoreValue
      end
      if(@modulusLastSpan == 1)
        yield "#{chrom}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{@coord}\t#{@stop}\t#{score}\t+\t.\t#{chrom}:#{@coord}-#{@stop}\n" if(coordTracker >= @stop)
      else
        yield "#{chrom}\t#{@ftypeHash['fmethod']}\t#{@ftypeHash['fsource']}\t#{@coord}\t#{coordTracker}\t#{score}\t+\t.\t#{chrom}:#{@coord}-#{coordTracker}\n" if(coordTracker >= @stop)
      end
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
            yieldGffLinesWithEmptyScoreValues(@coord, @dataSpan, annosStart, @emptyScoreValue, ridRow) { |line|
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


  end

end ; end ; end ; end