#!/usr/bin/env ruby

require 'fileutils'
require 'brl/genboree/abstract/resources/annotationFile'

# This class is used to get a bed file from the database
# write it to a file on disk

module BRL ; module Genboree ; module Abstract ; module Resources
  class WigFile < AnnotationFile

    # MAX_BLOCK_LINES defines the max number of lines that will be printed before
    # another block header is printed (for variableStep data)
    MAX_BLOCK_LINES = 10_000
    DEFAULT_SPAN = 20
    DEFAULT_SPAN_AGG_FUNCTION = :med
    attr_accessor :bucketSum, :bucketCount, :bucketMin, :bucketMax, :bucketSoq, :bucket
    def initialize(dbu, fileName=nil, showTrackHead=false, options={})
      super(dbu, fileName)
      # Only specify the fields (fdata2 columns) that are required to construct this file.  Additional fields will slow the process.
      @fdataFields = 'fid, rid, fstart, fstop, fscore, ftypeid'
      @hdhvType = 'variableStep'
      @showTrackHead = showTrackHead
      @formatOptions = options
      @bucket = [] # Used for scoring scores when computing statistical functions for different spans
      @bucketSum = 0.0
      @bucketCount = 0
      @bucketMin = nil
      @bucketMax = nil
      @bucketSoq = 0.0
      modLastSpan = @formatOptions['modulusLastSpan']
      if(modLastSpan and !modLastSpan.empty? and modLastSpan =~ /^(?:yes|true)/i)
        @modulusLastSpan = 1
      elsif(modLastSpan and !modLastSpan.empty? and modLastSpan =~ /^ucscStyle/i)
        @modulusLastSpan = 2
      else
        @modulusLastSpan = 0
      end
      @prevAnnosStop = nil
      @bucketEmpty = true
    end

    # The span that will be used is determined here.
    #
    #
    #
    # Ensure that @formatOptions['desiredSpan'] is set because that is required by the hdhv.rb code
    #
    def determineSpan(ftypeId)
      if(!@isHdhv)
        # Until span is done for fdata2 overwrite @formatOptions['determineSpan']
        # check for constant span in the data first because if it is constant we can use that to generate the file more efficiently
        spanRows = @dbu.selectDataSpanByFtypeId(ftypeId, 2)
        if(spanRows.count == 1)
          @hasConstantSpan =  true
          @constantSpan = spanRows.first['span'] + 1 # Add 1 because start and stop are included in the annotation
        else # If the span aren't constant, then we have to expand all the data to span = 1
          @hasConstantSpan = false
        end
      end

      # Ensure that @formatOptions['desiredSpan'] is set because that is required by the hdhv.rb code
      if(@formatOptions['desiredSpan'].nil?)
        if(!@ftypeAttributesHash['gbTrackOriginalSpan'].nil?)
          # Use the first value from gbTrackOriginalSpan
          spanList = @ftypeAttributesHash['gbTrackOriginalSpan']
          spanArr = spanList.split(',')
          @formatOptions['desiredSpan'] = spanArr.first.to_i
          @formatOptions['endSpan'] = spanArr.last.to_i
        else
          # If the track is from fdata2 and there is a constantSpan, use it
          # otherwise use the default value that is defined in conf, 20
          @formatOptions['desiredSpan'] = (!@isHdhv and @hasConstantSpan) ? @constantSpan : DEFAULT_SPAN
        end
      #else formatOptions['desiredSpan'] is already set, use it
      end

      # Ensure that @formatOptions['spanAggFunction'] is set
      if(@formatOptions['spanAggFunction'].nil?)
        @formatOptions['spanAggFunction'] = DEFAULT_SPAN_AGG_FUNCTION
      end

      # This page uses the instance var @dataSpan so set it from the options
      @dataSpan = @formatOptions['desiredSpan']
      @denomForAvgByLength = @formatOptions['desiredSpan']
    end

    # Overridden to set span
    def eachChunkForChromosome(ridRow, start, stop, ftypeId)
      @lastCoord, @prevStart, @coord = nil
      determineSpan(ftypeId)
      super(ridRow, start, stop, ftypeId)
    end

    # Gets chunks of fdata2 records, expands according to @dataSpan and creates wig lines
    # [+ridRow+]
    # [+start+] requested start coordinate
    # [+stop+] requested stop coordinate
    # [+ftypeId+] ftypeId of the requested track
    # [+returns+] yields chunks of wig records
    def eachChunkFromFdata(ridRow, start, stop, ftypeId)
      buffer = ''
      dbRec = @trackObj.getDbRecWithData()
      @dbu.setNewDataDb(dbRec.dbName)
      @numLines = 0
      @start = start.nil? ? 1 : start.to_i
      @stop = stop.nil? ? @frefHash[ridRow['rid']].to_i : stop.to_i
      @stop = @stop < @frefHash[ridRow['rid']].to_i ? @stop : @frefHash[ridRow['rid']].to_i
      if(@modulusLastSpan == 2)
        @stop -= 1
        @modulusLastSpan = 1
      end
      @bucketEmpty = true
      # Check if 'emptyScoreValue' parameter is provided for regular downloads
      # If it is provided, we need to fill in the gaps
      if((!@formatOptions['emptyScoreValue'].nil? and !@formatOptions['emptyScoreValue'].empty?))
        @emptyScoreValue = @formatOptions['emptyScoreValue']
        @coord = @start # @coord will track the start coord of bucket/window throughout the download
        if(@hdhvType == "fixedStep")
          buffer << "fixedStep chrom=#{@frefNameHash[ridRow['rid']]} start=#{@coord} span=#{@dataSpan} step=#{@dataSpan}\n"
        else
          buffer << "variableStep chrom=#{@frefNameHash[ridRow['rid']]} span=#{@dataSpan}\n"
          @prevStart = @coord
        end
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
      if(@emptyScoreValue)
        if(endCoordForLastRec < @stop)
          yieldWigLinesWithEmptyScoreValues(@coord, @dataSpan, @stop, @emptyScoreValue, ridRow) { |block| yield block}
        elsif(endCoordForLastRec >= @stop)
          unless(@bucketEmpty) # Its possible that the last record ended at the desired end coordinate
            score = calcAggValue(@bucket)
            if(@hdhvType == 'fixedStep')
              yield "#{score}\n"
            else
              yield "#{@coord} #{score}\n"
            end
            @bucket = []
            @bucketEmpty = true
          else
            if(noRecsFound)
              if(@hdhvType == 'fixedStep')
                yield "#{score}\n"
              else
                yield "#{@coord} #{score}\n"
              end
            end
          end
        else
          # No-op
        end
      end
      @prevAnnosStop = nil
    end

    # Loops over all fdata2 recs for the current set of fdata2 recs
    # [+fdataRows+] a chunk of fdata2 recs in sorted order
    # [+ridRow+] row with rid(chr) info
    # [+returns+] yields chunks of wig records
    def processDataRows(fdataRows, ridRow)
      fdataRows.each { |fdataRow|
        annosStart =  fdataRow['fstart'].to_i  # start coord of the row to be expanded
        if(@emptyScoreValue and annosStart > (@coord + (@dataSpan - 1))) # Check if we need to add empty score values
          if(@prevAnnosStop.nil? or @prevAnnosStop < annosStart) # Only add if no overlaps
            yieldWigLinesWithEmptyScoreValues(@coord, @dataSpan, annosStart, @emptyScoreValue, ridRow) { |line|
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

    # [+returns+] track header for wig records
    def makeTrackHead
      return "track name=\"#{@ftypeHash['fmethod']}:#{@ftypeHash['fsource']}\" type=wiggle_0\n"
    end

  end

  class FWigFile < WigFile

    def initialize(dbu, fileName=nil, showTrackHead=false, options={})
      super(dbu, fileName, showTrackHead, options)
      @hdhvType = 'fixedStep'
    end

    def makeWigLine(coord, score)
      # wig data is just in the ftype records
      return "#{score}\n"
    end


    def makeChromHeadLine(rid, span, start)
      return "fixedStep chrom=#{@frefNameHash[rid]} start=#{start} step=#{span} span=#{span}\n"
    end

    # Fixed Wig format needs a block header at the start of a chromosome or when the
    # coordinate of the next annotation is not consecutive
    def needsHeader?
      return (@prevStart != @coord - @dataSpan)
    end

    # makes 'fixedStep' records with provided 'emptyScoreValue'
    # [+start+] requested start coordinate
    # [+span+] requested span
    # [+annosStart+] start coordinate of annotation from fdata2
    # [+emptyScoreValue+]
    # [+ridRow+]
    # [+returns] yields fixedStep wig lines
    def yieldWigLinesWithEmptyScoreValues(start, span, annosStart, emptyScoreValue, ridRow)
      buffer = ''
      coordTracker = start + (span - 1)
      score = @bucketEmpty ? emptyScoreValue : calcAggValue(@bucket)
      while(coordTracker < annosStart)
        buffer = "#{score}\n"
        @coord = coordTracker + 1
        coordTracker += span
        score = emptyScoreValue
        yield buffer
      end

      if(@modulusLastSpan == 1)
        if(coordTracker >= @stop)
          yield makeChromHeadLine(ridRow['rid'], @stop - (@coord - 1), @coord) if(coordTracker > @stop)
          yield "#{score}\n"
        end
      else
        yield "#{score}\n" if(coordTracker >= @stop)
      end
    end

    # This method takes a row of fdata2 data and expands it into span=1 wig data (1 score / base)
    #
    #
    # [+row+]       DBI::Row object containing fdata2 record
    def expandRow(row, span=1)
      tempScore = row['fscore'].to_f
      if(span == 1)
        # print a new header line unless the coordinates are consecutive
        (row['fstart']..row['fstop']).each { |nn|
          next if(!@start.nil? and nn < @start)
          break if(!@stop.nil? and nn > @stop)
          yield makeChromHeadLine(row['rid'], span, nn) if(@lastCoord != nn - 1)
          yield "#{tempScore}\n"
          @lastCoord = nn
        }
      else
        # Add the values to a bucket
        (row['fstart']..row['fstop']).each { |nn|
          next if(!@start.nil? and nn < @start)
          break if(!@stop.nil? and nn > @stop)
          # If the bucket is full or we've moved out of the span, dump the bucket
          if(!@coord.nil? and nn >= @coord + span)
            yield makeChromHeadLine(row['rid'], span, @coord) if(needsHeader?)
            # perform statistical function on bucket
            score = calcAggValue(@bucket)
            # yield the line
            yield "#{score}\n"
            # empty the bucket
            @bucket = []
            @prevStart = @coord
            @bucketSum = 0.0
            @bucketCount = 0
            @bucketMin = nil
            @bucketMax = nil
            @bucketSoq = 0.0
            @bucketEmpty = true
            @coord = nn
            # Check if we need a 'special' block header at the end
            if(@modulusLastSpan == 1)
              # If we are going beyond the requested length,
              if(@coord + (span - 1) > @stop)
                yield makeChromHeadLine(row['rid'], @stop - (@coord - 1), @coord)
              end
            end
          end
          @coord = nn if(@bucketEmpty and @emptyScoreValue.nil?) # We're starting a new bucket
          @bucketEmpty = false

          # Depending on the aggregating function, do the needful
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
              @bucketMin = tempScore
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
        }
      end
    end
  end

  class VWigFile < WigFile

    def initialize(dbu, fileName=nil, showTrackHead=false, options={})
      super(dbu, fileName, showTrackHead, options)
      @hdhvType = 'variableStep'
    end

    def makeWigLine(coord, score)
      return "#{coord} #{score}\n"
    end

    def makeChromHeadLine(rid, span, start)
      # Note that we have printed a header for this chromosome by setting @prevStart
      @prevStart = start
      return "variableStep chrom=#{@frefNameHash[rid]} span=#{span}\n"
    end

    def needsHeader?
      return @prevStart.nil?
    end

    # makes 'variableStep' records with provided 'emptyScoreValue'
    # [+start+] requested start coordinate
    # [+span+] requested span
    # [+annosStart+] start coordinate of annotation from fdata2
    # [+emptyScoreValue+]
    # [+ridRow+]
    # [+returns] yields variableStep wig lines
    def yieldWigLinesWithEmptyScoreValues(start, span, annosStart, emptyScoreValue, ridRow)
      coordTracker = start + (span - 1)
      score = @bucketEmpty ? emptyScoreValue : calcAggValue(@bucket)
      while(coordTracker < annosStart)
        yield "#{@coord} #{score}\n"
        @coord = coordTracker + 1
        coordTracker += span
        score = emptyScoreValue
      end
      if(@modulusLastSpan == 1)
        if(coordTracker >= @stop)
          yield makeChromHeadLine(ridRow['rid'], @stop - (@coord - 1), @coord) if(coordTracker > @stop)
          yield "#{@coord} #{score}\n"
        end
      else
        yield "#{@coord} #{score}\n" if(coordTracker >= @stop)
      end
    end

    # This method takes a row of fdata2 data and expands it into span=1 wig data (1 score / base)
    #
    # This is for variableStep format which is the default if variable or fixed is not defined
    #
    # [+row+]       DBI::Row object containing fdata2 record
    def expandRow(row, span=1)
      tempScore = row['fscore'].to_f
      if(span == 1)
        yield "variableStep chrom=#{@frefNameHash[row['rid']]} span=1\n"
        (row['fstart']..row['fstop']).each { |nn|
          next if(!@start.nil? and nn < @start)
          break if(!@stop.nil? and nn > @stop)
          yield "#{nn} #{tempScore}\n"
        }
      else
        # Add the values to a bucket
        (row['fstart']..row['fstop']).each { |nn|
          next if(!@start.nil? and nn < @start)
          break if(!@stop.nil? and nn > @stop)
          # If the bucket is full or we've moved out of the span, dump the bucket
          if(!@coord.nil? and nn >= @coord + span)
            yield makeChromHeadLine(row['rid'], span, @coord) if(needsHeader?)
            # perform statistical function on bucket
            score = calcAggValue(@bucket)
            # yield the line
            yield "#{@coord} #{score}\n"
            # empty the bucket
            @bucket = []
            @bucketSum = 0.0
            @bucketCount = 0
            @bucketMin = nil
            @bucketMax = nil
            @bucketSoq = 0.0
            @bucketEmpty = true
            @coord = nn
            # Check if we need a 'special' block header at the end
            if(@modulusLastSpan == 1)
              # If we are going beyond the requested length,
              if(@coord + (span - 1) > @stop)
                yield makeChromHeadLine(row['rid'], @stop - (@coord - 1), @coord)
              end
            end
          end
          @coord = nn if(@bucketEmpty and @emptyScoreValue.nil?) # We're starting a new bucket
          @bucketEmpty = false

          # Add the score to the bucket
          # Depending on the aggregating function, do the needful
          case @formatOptions['spanAggFunction']
          when :med
            @bucket.push(tempScore)
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
        }
      end
    end

  end




end ; end ; end ; end
