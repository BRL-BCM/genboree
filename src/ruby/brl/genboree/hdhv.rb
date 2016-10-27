#!/usr/bin/env ruby

# Load require libraries
# Note: The dir set for INLINEDIR should not be group and world writable
require 'rack'
require 'cgi'
require 'getoptlong'
require 'zlib'
require 'md5'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/db/dbrc'
require 'pp'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/genboreeUtil'
require 'brl/sql/binning'
require 'brl/C/CFunctionWrapper'
require 'brl/genboree/C/hdhv/yieldLastChunkForNonWig'
require 'brl/genboree/C/hdhv/yieldLastChunkForWig'
require 'brl/genboree/C/hdhv/intersectHdhv'
require 'brl/genboree/C/hdhv/yieldIntersectHdhv'
require 'brl/genboree/C/hdhv/getNonWig'
require 'brl/genboree/C/hdhv/getWiggle'
require 'brl/genboree/C/hdhv/expandZlibBlocks'
require 'brl/genboree/C/hdhv/computeCollapsedScores.rb'
require 'brl/genboree/C/hdhv/printCollapsedScores.rb'
require 'brl/genboree/C/hdhv/testBinScores'
require 'brl/genboree/C/hdhv/testSegFault'

ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
ENV['DBRC_FILE']
ENV['PATH']

module BRL #:nodoc:
module Genboree #:nodoc:
# Module for getting back hdhv data in wig and non wig formats
# The methods in the module is accessed by the hdhv object.
module ReadHDHV
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  BLOCKSIZE = 20000 # Number of records to process at a time
  BUFFERSIZE = 16_000_000
  MAX_OUT_BUFFER = 128_000
  MEDIAN_LIMIT = 50_000 # Allocate memory for 50_000 records. Only the first 50_000 records will be used to compute the median
  # Default format specific optional hash
  OPTIONSHASH = {
    "scaleScores" => 1, # set default to 1
    "desiredSpan" => 1, # set default to 1
    "spanForLFF" => 0, # this just means do not produce spanned output
    "spanAggFunction" => :med, # one of: :med, :avg, :max, :min, :sum, :stdev, :count
    "posScoresOnly" => 0, # only get +ve scores
    "negScoresOnly" => 0, # only get -ve scores
    "endSpan" => 1,
    "modulusLastSpan" => 0
  }
  SPAN_AGG_FUNCTIONS = {
    :med => 1,
    :avg => 2,
    :max => 3,
    :min => 4,
    :sum => 5,
    :stdev => 6,
    :count => 7,
    :avgbylength => 8
  }
  # ############################################################################
  # METHODS
  # ############################################################################
  # Returns score for an annotation (called by annotationFile.rb for each fdata2 record)
  # [blockRecs] blockLevelDataInfo records for a chunk for fdata2 records
  # [+fstart+] start coordinate of the annotation
  # [+fstop+] stop coord of the annotation
  # [+optsHash+]
  # [+blockIndex+] global index for block level records
  # [+blockRecsSize+]
  # [+returns+] array: [blockIndex, score for the annotation or nil (for all NaNs)]
  def getScoreByAnnos(blockRecs, fstart, fstop, optsHash, blockIndex, blockRecsSize)
    t1 = Time.now
    fscore = nil
    bufferSize = BUFFERSIZE
    @blockRecsSize = blockRecsSize
    if(@varInitForGetScoreByAnnos == 0)
      if(!optsHash.nil? and !optsHash.empty?)
        @optionsHash['scaleScores'] = optsHash['scaleScores']
        @optionsHash['spanAggFunction'] = optsHash['spanAggFunction'] if(optsHash.key?('spanAggFunction'))
        # Check if only +ve or only -ve scores are to be retrieved
        # First make sure that both are not true
        posScores = optsHash['posScoresOnly'] if(optsHash.has_key?('posScoresOnly'))
        negScores = optsHash['negScoresOnly'] if(optsHash.has_key?('negScoresOnly'))
        @posScores = if(posScores and !posScores.empty? and posScores =~ /^(?:yes|true)/i) then 1 else 0 end
        @negScores = if(negScores and !negScores.empty? and negScores =~ /^(?:yes|true)/i) then 1 else 0 end
        @posScores = @negScores = 0 if(@posScores == 1 and @negScores == 1)
        @optionsHash['posScoresOnly'] = @posScores
        @optionsHash['negScoresOnly'] = @negScores
      end
      # Convert the spanAggFunction value from Symbol to an int (as needed by C function)
      @spanAggFunction = @optionsHash['spanAggFunction']
      @optionsHash['spanAggFunction'] = SPAN_AGG_FUNCTIONS[@optionsHash['spanAggFunction']]
      @aggFunction = @optionsHash['spanAggFunction']
      @spanSum = 0.0
      @spanCount = 0
      @spanMin = @attributeHash['gbTrackDataMax']
      @spanMax = @attributeHash['gbTrackDataMin']
      @spanSoq = 0.0
      # Apart for the median array, pack the other values into one array
      # This makes it easy to pass these values to the C functions
      @globalArray = [0, 0, 0, 0, @spanSum, @spanCount, @spanMax, @spanMin, @spanSoq, @spanMax, @spanMin, 0]
      @tempBlockHash = {}
      @trackContHash = {}
      @currExpandBufferId = nil
      @prevExpandBufferId = nil
      @varInitForGetScoreByAnnos = 1
    end
    if(@spanAggFunction == :med)
      @spanMedianArray = @createBufferObject.createBuffer(@attributeHash['gbTrackDataSpan'], MEDIAN_LIMIT)
    else
      @spanMedianArray = ""
    end
    currBlockRec = blockRecs[blockIndex]
    while(currBlockRec['fstart'] <= fstop and !(fstart <= currBlockRec['fstop'] and fstop >= currBlockRec['fstart']))
      blockIndex += 1
      break if(blockIndex >= @blockRecsSize)
      currBlockRec = blockRecs[blockIndex]
    end
    if(blockIndex < @blockRecsSize)
      currBlockIndex = blockIndex
      currBlock = blockRecs[currBlockIndex]
      stop = currBlock['fstop']
      start = currBlock['fstart']
      while(fstop >= start and fstart <= stop)
        blockSpan = currBlock['blockSpan']
        blockStep = currBlock['blockStep']
        blockScale = currBlock['blockScale']
        blockLowLimit = currBlock['blockLowLimit']
        offset = currBlock['offset']
        fileName = currBlock['fileName']
        sizeOfBlock = currBlock['byteLength']
        numRecords = currBlock['numRecords']
        dataSpan = @attributeHash['gbTrackDataSpan']
        # New file
        if(!@fileHash.has_key?(fileName))
          binReader = nil
          if(File.exists?("#{@dir}/#{fileName}"))
            binReader = File.open("#{@dir}/#{fileName}")
          else
            raise "FATAL ERROR: bin file: #{fileName} does not exist."
            currBlockIndex += 1
            if(currBlockIndex < @blockRecsSize)
              currBlock = blockRecs[currBlockIndex]
              stop = currBlock['fstop']
              start = currBlock['fstart']
              next
            else
              break
            end
          end
          startOffsetFromFile = offset
          offsetInBuffer = 0
          binReader.seek(offset)
          byteRead = 0
          # If entire block is present in the buffer
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "ready to read zip file (init took #{Time.now - t1})")
          t1 = Time.now
          if(sizeOfBlock <= bufferSize)
            @binScores = binReader.read(bufferSize)
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "A read zip file  in #{Time.now - t1})")
            byteRead = byteRead + bufferSize
          # read in entire block.
          else
            @binScores = binReader.read(sizeOfBlock)
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "B read zip file in #{Time.now - t1})")
            byteRead = byteRead + sizeOfBlock
          end
          expandedBlockSize = numRecords * dataSpan
          if(expandedBlockSize > @expandBufferSize)
            #$stderr.puts "DEBUG: expanding the buffer to #{expandedBufferSize.inspect} from #{@expandBufferSize.inspect}"
            @setBufferSizeObj.setBufferSize(@expandBuffer, @expandBufferSize) # Reset to original size to avoid memory leak
            @expandBuffer = nil
            @setBufferSizeObj.setBufferSize(@prevExpandBuffer, @prevExpandBufferSize) # Reset to original size to avoid memory leak
            @prevExpandBuffer = nil
            @expandBuffer = @createBufferObject.createBuffer(dataSpan, numRecords)
            @prevExpandBuffer = @createBufferObject.createBuffer(dataSpan, numRecords)
            @expandBufferSize = expandedBlockSize
            @prevExpandBufferSize = expandedBlockSize
          end
          t1 = Time.now
          expRet = @expandBlockObject.expandBlock(@binScores, @expandBuffer, dataSpan, numRecords, sizeOfBlock, 0)
          raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
          @currExpandBufferId = currBlock['id']
          @prevExpandBufferId = currBlock['id']
          @intersectObject.intersectTracks(@expandBuffer, @globalArray, @spanMedianArray, fstart, fstop, start, stop,
                                           dataSpan, @optionsHash['spanAggFunction'], [@attributeHash['gbTrackDenominator'], blockScale, blockLowLimit], MEDIAN_LIMIT)
          @trackContHash[fileName] = [startOffsetFromFile, offsetInBuffer, byteRead, offset]
          @fileHash[fileName] = binReader
        # File contents already in memory
        else
          # File Handler may have been closed after yielding chunk (to avoid pooling up of file handles)
          if(@fileHash[fileName].closed?)
            @fileHash[fileName] = File.open("#{@dir}/#{fileName}")
          end
          # Check if the block is in buffer
          startOffsetFromFile = @trackContHash[fileName][0]
          offsetInBuffer = @trackContHash[fileName][1]
          byteRead = @trackContHash[fileName][2]
          prevOffsetInFile = @trackContHash[fileName][3]
          if(prevOffsetInFile > offset)
            binReader = @fileHash[fileName]
            binReader.seek(offset)
            startOffsetFromFile = offset
            offsetInBuffer = 0
            byteRead = 0
            # If entire block is present in the buffer
            if(sizeOfBlock <= bufferSize)
              @binScores = binReader.read(bufferSize)
              byteRead = byteRead + bufferSize
            # read in entire block.
            else
              @binScores = binReader.read(sizeOfBlock)
              byteRead = byteRead + sizeOfBlock
            end
            expandedBlockSize = numRecords * dataSpan
            if(expandedBlockSize > @expandBufferSize)
              @setBufferSizeObj.setBufferSize(@expandBuffer, @expandBufferSize) # Reset to original size to avoid memory leak
              @expandBuffer = nil
              @setBufferSizeObj.setBufferSize(@prevExpandBuffer, @prevExpandBufferSize) # Reset to original size to avoid memory leak
              @prevExpandBuffer = nil
              @expandBuffer = @createBufferObject.createBuffer(dataSpan, numRecords)
              @prevExpandBuffer = @createBufferObject.createBuffer(dataSpan, numRecords)
              @expandBufferSize = expandedBlockSize
              @prevExpandBufferSize = expandedBlockSize
            end

            t1 = Time.now
            expRet = @expandBlockObject.expandBlock(@binScores, @expandBuffer, dataSpan, numRecords, sizeOfBlock, 0)

            raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
            @currExpandBufferId = currBlock['id']
            @prevExpandBufferId = currBlock['id']
            @intersectObject.intersectTracks(@expandBuffer, @globalArray, @spanMedianArray, fstart, fstop, start, stop,
                                             dataSpan, @optionsHash['spanAggFunction'],
                                            [@attributeHash['gbTrackDenominator'], blockScale, blockLowLimit], MEDIAN_LIMIT)
            @trackContHash[fileName] = [startOffsetFromFile, offsetInBuffer, byteRead, offset]
          else
            if((startOffsetFromFile + byteRead > offset + sizeOfBlock))
              if(@currExpandBufferId != currBlock['id']) # current block id not one we need....what about prev block id?
                # Swap expand buffer so it uses the other malloc'd buffer. Make sure to save current malloc'd buffer in prevExpandBuffer
                tmpBuff = @expandBuffer
                @expandBuffer = @prevExpandBuffer
                @prevExpandBuffer = tmpBuff
                @prevExpandBufferSize, @expandBufferSize = @expandBufferSize, @prevExpandBufferSize
                @prevExpandBufferId, @currExpandBufferId = @currExpandBufferId, @prevExpandBufferId
                # Can we use prev buff or not?
                if(@currExpandBufferId != currBlock['id'])
                  expandedBlockSize = numRecords * dataSpan
                  #$stderr.puts "DEBUG: expandedBlockSize 3: #{expandedBlockSize.inspect}"
                  if(expandedBlockSize > @expandBufferSize)
                    @setBufferSizeObj.setBufferSize(@expandBuffer, @expandBufferSize) # Reset to original size to avoid memory leak
                    @expandBuffer = nil
                    @expandBuffer = @createBufferObject.createBuffer(dataSpan, numRecords)
                    @expandBufferSize = expandedBlockSize
                  end
                  offsetInBuffer = offsetInBuffer + (offset - prevOffsetInFile)
                  t1 = Time.now
                  expRet = @expandBlockObject.expandBlock(@binScores, @expandBuffer, dataSpan,
                                                 numRecords, sizeOfBlock, offsetInBuffer)
                  raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
                  @currExpandBufferId = currBlock['id']
                  @intersectObject.intersectTracks(@expandBuffer, @globalArray, @spanMedianArray, fstart, fstop, start, stop,
                                              dataSpan, @optionsHash['spanAggFunction'],
                                              [@attributeHash['gbTrackDenominator'], blockScale, blockLowLimit], MEDIAN_LIMIT)
                else
                  offsetInBuffer = offsetInBuffer + (offset - prevOffsetInFile)
                  @intersectObject.intersectTracks(@expandBuffer, @globalArray, @spanMedianArray, fstart, fstop, start, stop,
                                              dataSpan, @optionsHash['spanAggFunction'],
                                              [@attributeHash['gbTrackDenominator'], blockScale, blockLowLimit], MEDIAN_LIMIT)
                end
              else
                offsetInBuffer = offsetInBuffer + (offset - prevOffsetInFile)
                @intersectObject.intersectTracks(@expandBuffer, @globalArray, @spanMedianArray, fstart, fstop, start, stop,
                                              dataSpan, @optionsHash['spanAggFunction'],
                                              [@attributeHash['gbTrackDenominator'], blockScale, blockLowLimit], MEDIAN_LIMIT)
              end
              @trackContHash[fileName] = [startOffsetFromFile, offsetInBuffer, byteRead, offset]
            else # is not in memory
              binReader = @fileHash[fileName]
              binReader.seek(offset)
              startOffsetFromFile = offset
              offsetInBuffer = 0
              byteRead = 0
              # If entire block is present in the buffer
              if(sizeOfBlock <= bufferSize)
                @binScores = binReader.read(bufferSize)
                byteRead = byteRead + bufferSize
              # read in entire block.
              else
                @binScores = binReader.read(sizeOfBlock)
                byteRead = byteRead + sizeOfBlock
              end
              expandedBlockSize = numRecords * dataSpan
              if(expandedBlockSize > @expandBufferSize)
                @setBufferSizeObj.setBufferSize(@expandBuffer, @expandBufferSize) # Reset to original size to avoid memory leak
                @expandBuffer = nil
                @setBufferSizeObj.setBufferSize(@prevExpandBuffer, @prevExpandBufferSize) # Reset to original size to avoid memory leak
                @prevExpandBuffer = nil
                @expandBuffer = @createBufferObject.createBuffer(dataSpan, numRecords)
                @prevExpandBuffer = @createBufferObject.createBuffer(dataSpan, numRecords)
                @expandBufferSize = expandedBlockSize
                @prevExpandBufferSize = expandedBlockSize
              end
              t1 = Time.now
              expRet = @expandBlockObject.expandBlock(@binScores, @expandBuffer, dataSpan, numRecords, sizeOfBlock, 0)
              raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
              @currExpandBufferId = currBlock['id']
              @prevExpandBufferId = currBlock['id']
              @intersectObject.intersectTracks(@expandBuffer, @globalArray, @spanMedianArray, fstart, fstop, start, stop,
                                               dataSpan, @optionsHash['spanAggFunction'],
                                              [@attributeHash['gbTrackDenominator'], blockScale, blockLowLimit], MEDIAN_LIMIT)
              @trackContHash[fileName] = [startOffsetFromFile, offsetInBuffer, byteRead, offset]
            end
          end
        end
        currBlockIndex += 1
        if(currBlockIndex < @blockRecsSize)
          currBlock = blockRecs[currBlockIndex]
          stop = currBlock['fstop']
          start = currBlock['fstart']
        else
          break
        end
      end # end while
      if(@globalArray[2] > 0) # Update aggregates
        updateAggs()
        return blockIndex
      else
        updateAggsWithNil()
        return blockIndex
      end
    else
      updateAggsWithNil()
      return blockIndex
    end
  end

  # Close resources in use, including aggressive closing of @dbu's cached connections
  def clear()
    closeBuffers()
    closeFileHandles()
    @dbu.clear(true) if(@dbu) # The true argument tells it to shut and clear all the cached connections as well.
  end

  def closeBuffers()
    # Reset key buffers to original size to avoid memory leak
    @setBufferSizeObj.setBufferSize(@expandBuffer, @expandBufferSize) if(@expandBuffer and @expandBuffer.is_a?(String) and @expandBufferSize)
    @expandBuffer = nil
    # Reset to original size to avoid memory leak
    @setBufferSizeObj.setBufferSize(@prevExpandBuffer, @prevExpandBufferSize) if(@prevExpandBuffer and @prevExpandBuffer.is_a?(String) and @prevExpandBufferSize)
    @prevExpandBuffer = nil
  end

  # Closes all file handlers in the @fileHash
  def closeFileHandles()
    # Close all file handles
    if(@fileHash)
      @fileHash.each_key { |file|
        reader = @fileHash[file]
        reader.close() if(reader and reader.is_a?(IO) and !reader.closed?)
      }
    end
  end

  # Update aggregates for format specific classes 'bedFile.rb, lffFile.rb, etc' can make use of it.
  # [+returns+] nil
  def updateAggs()
    sum = @globalArray[4]
    count = @globalArray[5]
    soq = @globalArray[8]
    max = @globalArray[6]
    min = @globalArray[7]
    trackMin = @globalArray[9]
    trackMax = @globalArray[10]
    realScores = @globalArray[2]
    case @spanAggFunction
    when :avg
      @avgStructObj.sum = sum
      @avgStructObj.count = count
    when :avgbylength
      @avgByLengthStructObj.sum = sum
    when :sum
      @sumStructObj.sum = sum
    when :count
      @countStructObj.count = count
    when :max
      @maxStructObj.max = max
    when :min
      @minStructObj.min = min
    when :stdev
      @stdevStructObj.sum = sum
      @stdevStructObj.soq = soq
      @stdevStructObj.count = count
    when :med
      @medianStructObj.string = @spanMedianArray
      @medianStructObj.numRecords = realScores
    end
    # Reset aggregates
    @globalArray[2] = 0 # Number of actual (non NaN) scores
    @globalArray[4] = 0.0 # Sum
    @globalArray[5] = 0 # Count
    @globalArray[8] = 0.0 # Sum of Squares
    @globalArray[6] = trackMin
    @globalArray[7] = trackMax
  end

  # Set aggregates to nil
  # [+returns+] nil
  def updateAggsWithNil()
    case @spanAggFunction
    when :avg
      @avgStructObj.sum = nil
      @avgStructObj.count = nil
    when :avgbylength
      @avgByLengthStructObj.sum = nil
    when :sum
      @sumStructObj.sum = nil
    when :count
      @countStructObj.count = nil
    when :max
      @maxStructObj.max = nil
    when :min
      @minStructObj.min = nil
    when :stdev
      @stdevStructObj.sum = nil
      @stdevStructObj.soq = nil
      @stdevStructObj.count = nil
    when :med
      @medianStructObj.string = ""
      @medianStructObj.numRecords = nil
    end
  end

  # Casts all block record values appropriately
  # [+blockRecs+] 'blockLevelDataInfo' recs
  # [+return+] blockRecs
  def castBlockRecs(blockRecs)
    blockRecs.each_index { |ii|
      blockRec = blockRecs[ii].to_h
      blockRec['id'] = blockRec['id'].to_i
      blockRec['offset'] = blockRec['offset'].to_i
      blockRec['byteLength'] = blockRec['byteLength'].to_i
      blockRec['numRecords'] = blockRec['numRecords'].to_i
      blockRec['fileName'] = blockRec['fileName']
      blockRec['fstart'] = blockRec['fstart'].to_i
      blockRec['fstop'] = blockRec['fstop'].to_i
      blockRec['blockSpan'] = (blockRec['gbBlockBpSpan'] ? blockRec['gbBlockBpSpan'].to_i : @attributeHash['gbTrackBpSpan'])
      blockRec['blockStep'] = (blockRec['gbBlockBpStep'] ? blockRec['gbBlockBpStep'].to_i : @attributeHash['gbTrackBpStep'])
      blockRec['blockScale'] = (blockRec['gbBlockScale'] ? blockRec['gbBlockScale'].to_f : @attributeHash['gbTrackScale'])
      blockRec['blockLowLimit'] = (blockRec['gbBlockLowLimit'] ? blockRec['gbBlockLowLimit'].to_f : @attributeHash['gbTrackLowLimit'])
      blockRecs[ii] = blockRec
    }
    return blockRecs
  end


  # Writes output line (with emptyScoreValue) to buffer
  # [+returns+] nil
  def writeEmtpyValueScoresToBuffer(blockHeader, esValue, chr, fstart, fstop, fmethod, fsource, retTypeValue)
    case retTypeValue
    when 1 # fixedStep
      @outBuffer << "#{blockHeader}#{esValue}\n"
    when 2 # variableStep
      @outBuffer << "#{blockHeader}#{fstart} #{esValue}\n"
    when 3 # bed
      @outBuffer << "#{chr}\t#{fstart - 1}\t#{fstop}\t.\t#{esValue}\n"
    when 4 # bedGraph
      @outBuffer << "#{chr}\t#{fstart - 1}\t#{fstop}\t#{esValue}\n"
    when 5 # lff
      @outBuffer << "High Density Score Data\t#{chr}-#{fstart}:#{fstop}\t#{fmethod}\t#{fsource}\t#{chr}" +
                  "\t#{fstart}\t#{fstop}\t+\t.\t#{esValue}\n"
    when 6 # gff
      @outBuffer << "#{chr}\t#{fmethod}\t#{fsource}\t#{fstart}\t#{fstop}\t#{esValue}\t.\t.\t#{chr}:#{fstart}-#{fstop}\n"
    when 7 # gff3
      @outBuffer << "#{chr}\t#{fmethod}\t#{fsource}\t#{fstart}\t#{fstop}\t#{esValue}\t.\t.\tName=#{chr}:#{fstart}-#{fstop}\n"
    when 8 # gtf
      @outBuffer << "#{chr}\t#{fmethod}\t#{fsource}\t#{fstart}\t#{fstop}\t#{esValue}\t.\t.\tgene_id \"#{chr}:#{fstart}-#{fstop}\"; transcript_id \"#{chr}:#{fstart}-#{fstop}\"\n"
    end
  end

  # Yields score for a High Density Score track for regions provided via a Regions Of Interest (ROI) Track
  # [+fdata2Recs+] fdata2 records of the Regions of Interest Track
  # [+rid+] chromosome id
  # [+returnType+] format of the string returned
  # [+optsHash+] format specific options hash
  # [+returns+] nil
  def getScoreByRidWithROI(fdata2Recs, rid, returnType=nil, optsHash=nil)
    # Initialize all required variables
    returnType = "bedGraph" if(returnType.nil?)
    bufferSize = BUFFERSIZE
    emptyScoreValue = nil
    @proxyDownload = nil
    if(!optsHash.nil? and !optsHash.empty?)
      if(optsHash.has_key?('noUcscScale'))
        @optionsHash['scaleScores'] = 0 if(optsHash['noUcscScale'] == true)
      end
      @optionsHash['spanAggFunction'] = optsHash['spanAggFunction'] if(optsHash.key?('spanAggFunction'))
      # Check if only +ve or only -ve scores are to be retrieved
      # First make sure that both are not true
      posScores = optsHash['posScoresOnly'] if(optsHash.has_key?('posScoresOnly'))
      negScores = optsHash['negScoresOnly'] if(optsHash.has_key?('negScoresOnly'))
      @posScores = if(posScores and !posScores.empty? and posScores =~ /^(?:yes|true)/i) then 1 else 0 end
      @negScores = if(negScores and !negScores.empty? and negScores =~ /^(?:yes|true)/i) then 1 else 0 end
      @posScores = @negScores = 0 if(@posScores == 1 and @negScores == 1)
      @optionsHash['posScoresOnly'] = @posScores
      @optionsHash['negScoresOnly'] = @negScores
      emptyScoreValue = optsHash['emptyScoreValue']
      @proxyDownload = true if(optsHash['hasROIInPayload'])
    end
    emptyScoreValue.strip! if(!emptyScoreValue.nil?)
    # Convert the spanAggFunction value from Symbol to an int (as needed by C function)
    @optionsHash['spanAggFunction'] = SPAN_AGG_FUNCTIONS[@optionsHash['spanAggFunction']]
    if(@optionsHash['spanAggFunction'] == 1)
      @spanMedianArray = @createBufferObject.createBuffer(@attributeHash['gbTrackDataSpan'], 20_000_000) # Allocate memory for 20_000_000 records
    else
      @spanMedianArray = ""
    end
    frefData = @dbu.selectFrefsByRid(rid)
    chrom = frefData.first['refname']
    @spanSum = 0.0
    @spanCount = 0
    @spanMin = @attributeHash['gbTrackDataMax']
    @spanMax = @attributeHash['gbTrackDataMin']
    @spanSoq = 0.0
    fmethodFSource = @trackName.split(":")
    fmethod = fmethodFSource[0]
    fsource = fmethodFSource[1]
    # Apart for the median array, pack the other values into one array
    # This makes it easy to pass these values to the C functions
    @globalArray = [0, 0, 0, 0, @spanSum, @spanCount, @spanMax, @spanMin, @spanSoq, @spanMax, @spanMin, 0]
    # Write out the remaining chunk, if any
    retTypeValue = nil
    if(returnType == "bed")
      retTypeValue = 3
    elsif(returnType == "bedGraph")
      retTypeValue = 4
    elsif(returnType == "lff")
      retTypeValue = 5
    elsif(returnType == "gff")
      retTypeValue = 6
    elsif(returnType == "gff3")
      retTypeValue = 7
    elsif(returnType == "gtf")
      retTypeValue = 8
    elsif(returnType == "fixedStep")
      retTypeValue = 1
    elsif(returnType == "variableStep")
      retTypeValue = 2
    else
      $stderr.puts "Unsupported file format: #{returnType}"
    end
    blockLevelRecs = []
    tempBlockCounter = 0
    blockVal = nil
    previousIndexNumber = 0
    expandBuffer = @createBufferObject.createBuffer(2, 4_000_000) #Allocating 8_000_000 bytes of memory
    expandBufferSize = 2 * 4_000_000
    prevExpandBuffer = @createBufferObject.createBuffer(2, 4_000_000) #Allocating 8_000_000 bytes of memory
    prevExpandBufferSize = 2 * 4_000_000
    currExpandBufferId = nil
    prevExpandBufferId = nil
    blockIndex = 0
    # Get the corresponding blockLevelDataInfo records for the current chunk of fdata2 recs
    chunkStart = fdata2Recs[0]['fstart']
    chunkStop = fdata2Recs[fdata2Recs.size - 1]['fstop']
    blockRecs = @dbu.selectBlockLevelDataInfoRecordsByLandmark(rid, @ftypeId, chunkStart, chunkStop)
    if((blockRecs.nil? or blockRecs.empty?) and !emptyScoreValue.nil?)
      fdata2Recs.size.times { |fdataCount|
        fdataRec = fdata2Recs[fdataCount]
        fstart = fdataRec['fstart'].to_i
        fstop = fdataRec['fstop'].to_i
        @desiredSpan = (fstop - fstart) + 1
        blockHeader = makeBlockHeader(chrom, (fstop - fstart) + 1, (fstop - fstart) + 1, fstart, returnType) if(returnType == "fixedStep" or returnType == "variableStep")
        writeEmtpyValueScoresToBuffer(blockHeader, emptyScoreValue, chrom, fstart, fstop, fmethod, fsource, retTypeValue)
        if(@outBuffer.size >= MAX_OUT_BUFFER)
          yield @outBuffer
          @outBuffer = ""
        end
      }
    end
    if(!blockRecs.nil? and !blockRecs.empty?)
      blockRecsSize = blockRecs.size
      blockRecs = castBlockRecs(blockRecs)
      # Now start going through each of the fdata2 record and pull out the corresponding blockLevelDataInfo record for THAT fdata2 record
      fdata2Recs.size.times { |fdataCount|
        fdataRec = fdata2Recs[fdataCount]
        fstart = fdataRec['fstart'].to_i
        fstop = fdataRec['fstop'].to_i
        @desiredSpan = (fstop - fstart) + 1
        blockHeader = makeBlockHeader(chrom, (fstop - fstart) + 1, (fstop - fstart) + 1, fstart, returnType) if(returnType == "fixedStep" or returnType == "variableStep")
        if(blockIndex < blockRecsSize)
          currBlockRec = blockRecs[blockIndex]
          while(currBlockRec['fstart'] <= fstop and !(fstart <= currBlockRec['fstop'] and fstop >= currBlockRec['fstart']))
            blockIndex += 1
            break if(blockIndex >= blockRecsSize)
            currBlockRec = blockRecs[blockIndex]
          end
        end
        if(blockIndex < blockRecsSize)
          currBlockIndex = blockIndex
          currBlock = blockRecs[currBlockIndex]
          stop = currBlock['fstop']
          start = currBlock['fstart']
          while(fstop >= start and fstart <= stop)
            blockSpan = currBlock['blockSpan']
            blockStep = currBlock['blockStep']
            blockScale = currBlock['blockScale']
            blockLowLimit = currBlock['blockLowLimit']
            offset = currBlock['offset']
            fileName = currBlock['fileName']
            sizeOfBlock = currBlock['byteLength']
            numRecords = currBlock['numRecords']
            dataSpan = @attributeHash['gbTrackDataSpan']
            # New file
            if(!@fileHash.has_key?(fileName))
              binReader = nil
              if(File.exists?("#{@dir}/#{fileName}"))
                binReader = File.open("#{@dir}/#{fileName}")
              else
                raise "FATAL ERROR: bin file: #{fileName} does not exist."
                currBlockIndex += 1
                if(currBlockIndex < @blockRecsSize)
                  currBlock = blockRecs[currBlockIndex]
                  stop = currBlock['fstop']
                  start = currBlock['fstart']
                  next
                else
                  break
                end
              end
              startOffsetFromFile = offset
              offsetInBuffer = 0
              binReader.seek(offset)
              byteRead = 0
              # If entire block is present in the buffer
              if(sizeOfBlock <= bufferSize)
                @binScores = binReader.read(bufferSize)
                byteRead = byteRead + bufferSize
              # read in entire block.
              else
                @binScores = binReader.read(sizeOfBlock)
                byteRead = byteRead + sizeOfBlock
              end
              expandedBlockSize = numRecords * dataSpan
              if(expandedBlockSize > expandBufferSize)
                @setBufferSizeObj.setBufferSize(expandBuffer, expandBufferSize) # Reset to original size to avoid memory leak
                expandBuffer = nil
                @setBufferSizeObj.setBufferSize(prevExpandBuffer, prevExpandBufferSize) # Reset to original size to avoid memory leak
                prevExpandBuffer = nil
                expandBuffer = @createBufferObject.createBuffer(dataSpan, numRecords)
                prevExpandBuffer = @createBufferObject.createBuffer(dataSpan, numRecords)
                expandBufferSize = expandedBlockSize
                prevExpandBufferSize = expandedBlockSize
              end
              expRet = @expandBlockObject.expandBlock(@binScores, expandBuffer, dataSpan, numRecords, sizeOfBlock, 0)
              raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
              currExpandBufferId = currBlock['id']
              prevExpandBufferId = currBlock['id']
              @intersectObject.intersectTracks(expandBuffer, @globalArray, @spanMedianArray, fstart, fstop, start, stop,
                                               dataSpan, @optionsHash['spanAggFunction'], [@attributeHash['gbTrackDenominator'], blockScale, blockLowLimit], MEDIAN_LIMIT)
              @trackContHash[fileName] = [startOffsetFromFile, offsetInBuffer, byteRead, offset]
              @fileHash[fileName] = binReader
            # File contents already in memory
            else
              # Check if the block is in buffer
              startOffsetFromFile = @trackContHash[fileName][0]
              offsetInBuffer = @trackContHash[fileName][1]
              byteRead = @trackContHash[fileName][2]
              prevOffsetInFile = @trackContHash[fileName][3]
              if(prevOffsetInFile > offset)
                binReader = @fileHash[fileName]
                binReader.seek(offset)
                startOffsetFromFile = offset
                offsetInBuffer = 0
                byteRead = 0
                # If entire block is present in the buffer
                if(sizeOfBlock <= bufferSize)
                  @binScores = binReader.read(bufferSize)
                  byteRead = byteRead + bufferSize
                # read in entire block.
                else
                  @binScores = binReader.read(sizeOfBlock)
                  byteRead = byteRead + sizeOfBlock
                end
                expandedBlockSize = numRecords * dataSpan
                if(expandedBlockSize > expandBufferSize)
                  @setBufferSizeObj.setBufferSize(expandBuffer, expandBufferSize) # Reset to original size to avoid memory leak
                  expandBuffer = nil
                  @setBufferSizeObj.setBufferSize(prevExpandBuffer, prevExpandBufferSize) # Reset to original size to avoid memory leak
                  prevExpandBuffer = nil
                  expandBuffer = @createBufferObject.createBuffer(dataSpan, numRecords)
                  prevExpandBuffer = @createBufferObject.createBuffer(dataSpan, numRecords)
                  expandBufferSize = expandedBlockSize
                  prevExpandBufferSize = expandedBlockSize
                end
                expRet = @expandBlockObject.expandBlock(@binScores, expandBuffer, dataSpan, numRecords, sizeOfBlock, 0)
                raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
                currExpandBufferId = currBlock['id']
                prevExpandBufferId = currBlock['id']
                @intersectObject.intersectTracks(expandBuffer, @globalArray, @spanMedianArray, fstart, fstop, start, stop,
                                                 dataSpan, @optionsHash['spanAggFunction'],
                                                [@attributeHash['gbTrackDenominator'], blockScale, blockLowLimit], MEDIAN_LIMIT)
                @trackContHash[fileName] = [startOffsetFromFile, offsetInBuffer, byteRead, offset]
              else
                if((startOffsetFromFile + byteRead > offset + sizeOfBlock))
                  if(currExpandBufferId != currBlock['id']) # current block id not one we need....what about prev block id?
                    # Swap expand buffer so it uses the other malloc'd buffer. Make sure to save current malloc'd buffer in prevExpandBuffer
                    tmpBuff = expandBuffer
                    expandBuffer = prevExpandBuffer
                    prevExpandBuffer = tmpBuff
                    prevExpandBufferSize, expandBufferSize = expandBufferSize, prevExpandBufferSize
                    prevExpandBufferId, currExpandBufferId = currExpandBufferId, prevExpandBufferId
                    # Can we use prev buff or not?
                    if(currExpandBufferId != currBlock['id']) # then previous block is available
                      # Put block we need into expandbuffer
                      # populate with block we need
                      expandedBlockSize = numRecords * dataSpan
                      if(expandedBlockSize > expandBufferSize)
                        @setBufferSizeObj.setBufferSize(expandBuffer, expandBufferSize) # Reset to original size to avoid memory leak
                        expandBuffer = nil
                        expandBuffer = @createBufferObject.createBuffer(dataSpan, numRecords)
                        expandBufferSize = expandedBlockSize
                      end
                      offsetInBuffer = offsetInBuffer + (offset - prevOffsetInFile)
                      expRet = @expandBlockObject.expandBlock(@binScores, expandBuffer, dataSpan,
                                                     numRecords, sizeOfBlock, offsetInBuffer)
                      raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
                      currExpandBufferId = currBlock['id']
                      @intersectObject.intersectTracks(expandBuffer, @globalArray, @spanMedianArray, fstart, fstop, start, stop,
                                                  dataSpan, @optionsHash['spanAggFunction'],
                                                  [@attributeHash['gbTrackDenominator'], blockScale, blockLowLimit], MEDIAN_LIMIT)
                    else
                      offsetInBuffer = offsetInBuffer + (offset - prevOffsetInFile)
                      @intersectObject.intersectTracks(expandBuffer, @globalArray, @spanMedianArray, fstart, fstop, start, stop,
                                                  dataSpan, @optionsHash['spanAggFunction'],
                                                  [@attributeHash['gbTrackDenominator'], blockScale, blockLowLimit], MEDIAN_LIMIT)
                    end
                  else
                    offsetInBuffer = offsetInBuffer + (offset - prevOffsetInFile)
                    @intersectObject.intersectTracks(expandBuffer, @globalArray, @spanMedianArray, fstart, fstop, start, stop,
                                                  dataSpan, @optionsHash['spanAggFunction'],
                                                  [@attributeHash['gbTrackDenominator'], blockScale, blockLowLimit], MEDIAN_LIMIT)
                  end
                  @trackContHash[fileName] = [startOffsetFromFile, offsetInBuffer, byteRead, offset]
                else # is not in memory
                  binReader = @fileHash[fileName]
                  binReader.seek(offset)
                  startOffsetFromFile = offset
                  offsetInBuffer = 0
                  byteRead = 0
                  # If entire block is present in the buffer
                  if(sizeOfBlock <= bufferSize)
                    @binScores = binReader.read(bufferSize)
                    byteRead = byteRead + bufferSize
                  # read in entire block.
                  else
                    @binScores = binReader.read(sizeOfBlock)
                    byteRead = byteRead + sizeOfBlock
                  end
                  expandedBlockSize = numRecords * dataSpan
                  if(expandedBlockSize > expandBufferSize)
                    @setBufferSizeObj.setBufferSize(expandBuffer, expandBufferSize) # Reset to original size to avoid memory leak
                    expandBuffer = nil
                    @setBufferSizeObj.setBufferSize(prevExpandBuffer, prevExpandBufferSize) # Reset to original size to avoid memory leak
                    prevExpandBuffer = nil
                    expandBuffer = @createBufferObject.createBuffer(dataSpan, numRecords)
                    prevExpandBuffer = @createBufferObject.createBuffer(dataSpan, numRecords)
                    expandBufferSize = expandedBlockSize
                    prevExpandBufferSize = expandedBlockSize
                  end
                  expRet = @expandBlockObject.expandBlock(@binScores, expandBuffer, dataSpan, numRecords, sizeOfBlock, 0)
                  raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
                  currExpandBufferId = currBlock['id']
                  prevExpandBufferId = currBlock['id']
                  @intersectObject.intersectTracks(expandBuffer, @globalArray, @spanMedianArray, fstart, fstop, start, stop,
                                                   dataSpan, @optionsHash['spanAggFunction'],
                                                  [@attributeHash['gbTrackDenominator'], blockScale, blockLowLimit], MEDIAN_LIMIT)
                  @trackContHash[fileName] = [startOffsetFromFile, offsetInBuffer, byteRead, offset]
                end
              end
            end
            currBlockIndex += 1
            if(currBlockIndex < blockRecsSize)
              currBlock = blockRecs[currBlockIndex]
              stop = currBlock['fstop']
              start = currBlock['fstart']
            else
              break # break out of the blockLevel chunk
            end
          end # end while
          if(@globalArray[2] > 0) # Yield the chunk if the number of non Nan scores for the block > 0
            if(@proxyDownload.nil?)
              @intersectYieldObject.yieldIntersectTracks(@globalArray, @spanMedianArray, @cBuffer, fstart, fstop, dataSpan, @optionsHash['spanAggFunction'],
                      @optionsHash['scaleScores'], chrom, @scaleFactor, retTypeValue, fmethod, fsource)
              if(returnType == "fixedStep" or returnType == "variableStep")
                @outBuffer << "#{blockHeader}#{@cBuffer}"
              else
                @outBuffer << @cBuffer
              end
            else
              @intersectYieldObject.yieldIntersectTracks( @globalArray, @spanMedianArray, @cBuffer, fstart, fstop, dataSpan, @optionsHash['spanAggFunction'],
                                                          @optionsHash['scaleScores'], chrom, @scaleFactor, 1, fmethod, fsource
                                                        )
              makeProxyLine(fdataRec, @cBuffer, returnType)
            end
            if(@outBuffer.size >= MAX_OUT_BUFFER)
              yield @outBuffer
              @outBuffer = ""
            end
          else
            if(!emptyScoreValue.nil?)
              @proxyDownload.nil? ? writeEmtpyValueScoresToBuffer(blockHeader, emptyScoreValue, chrom, fstart, fstop, fmethod, fsource, retTypeValue) : makeProxyLine(fdataRec, emptyScoreValue, returnType)
              if(@outBuffer.size >= MAX_OUT_BUFFER)
                yield @outBuffer
                @outBuffer = ""
              end
            end
          end
        else
          if(!emptyScoreValue.nil?)
            @proxyDownload.nil? ? writeEmtpyValueScoresToBuffer(blockHeader, emptyScoreValue, chrom, fstart, fstop, fmethod, fsource, retTypeValue) : makeProxyLine(fdataRec, emptyScoreValue, returnType)
            if(@outBuffer.size >= MAX_OUT_BUFFER)
              yield @outBuffer
              @outBuffer = ""
            end
          else
            break # break out of the fdata2 chunk
          end
        end
      }
    end
    yield @outBuffer if(!@outBuffer.empty?)
    @outBuffer = ""
    @setBufferSizeObj.setBufferSize(expandBuffer, expandBufferSize) # Reset to original size to avoid memory leak
    expandBuffer = nil
    @setBufferSizeObj.setBufferSize(prevExpandBuffer, prevExpandBufferSize) # Reset to original size to avoid memory leak
    prevExpandBuffer = nil
  end

  # Constructs a record w.r.t to the 'ROI' track
  # [+fdataRec+]
  # [+score+]
  # [+returnType+]
  # [+returns+] nil
  def makeProxyLine(fdataRec, score, returnType)
    score.strip!
    if(returnType == "bed")
      @outBuffer << "#{fdataRec['chr']}\t#{fdataRec['fstart'].to_i-1}\t#{fdataRec['fstop']}\t#{fdataRec['name']}\t#{score}\t#{fdataRec['strand']}\n"
    elsif(returnType == "bedGraph")
      @outBuffer << "#{fdataRec['chr']}\t#{fdataRec['fstart'].to_i-1}\t#{fdataRec['fstop']}\t#{score}\n"
    elsif(returnType == "lff")
      @outBuffer << "#{fdataRec['class']}\t#{fdataRec['name']}\t#{fdataRec['type']}\t#{fdataRec['subtype']}\t#{fdataRec['chr']}\t#{fdataRec['fstart']}\t"
      @outBuffer << "#{fdataRec['fstop']}\t#{fdataRec['strand']}\t#{fdataRec['phase']}\t#{score}"
      @outBuffer << "\t#{fdataRec['qstart']}" if(fdataRec['qstart'])
      @outBuffer << "\t#{fdataRec['qstop']}" if(fdataRec['qstop'])
      @outBuffer << "\t#{fdataRec['avp']}" if(fdataRec['avp'])
      @outBuffer << "\t#{fdataRec['seq']}" if(fdataRec['seq'])
      @outBuffer << "\t#{fdataRec['comments']}" if(fdataRec['comments'])
      @outBuffer << "\n"
    elsif(returnType == "gff")
      @outBuffer << "#{fdataRec['chr']}\t#{fdataRec['type']}\t#{fdataRec['subtype']}\t#{fdataRec['fstart']}\t#{fdataRec['fstop']}\t#{score}\t#{fdataRec['strand']}\t#{fdataRec['phase']}\t#{fdataRec['name']}\n"
    elsif(returnType == "gff3")
      @outBuffer << "#{fdataRec['chr']}\t#{fdataRec['type']}\t#{fdataRec['subtype']}\t#{fdataRec['fstart']}\t#{fdataRec['fstop']}\t#{score}"
      @outBuffer << "#{fdataRec['strand']}\t#{fdataRec['phase']}"
      if(!fdataRec['avp'].nil? and !fdataRec['avp'].empty?)
        @outBuffer << "\t#{fdataRec['avp']}"
      end
      @outBuffer << "\n"
    elsif(returnType == "gtf")
      @outBuffer << "#{fdataRec['chr']}\t#{fdataRec['type']}\t#{fdataRec['subtype']}\t#{fdataRec['fstart']}\t#{fdataRec['fstop']}\t#{score}\t#{fdataRec['strand']}\t#{fdataRec['phase']}\t#{fdataRec['avp']}\n"
    else
      # Do nothing
    end
  end


  # Receives chunks of database block level records, processes the chunk and 'yields' the processed
  # chunk (one block at a time). The scores are collapsed (averaged) for a base in case there is more
  # than a single score for that base before aggregating with the desired aggregating function.
  # This is possible in case of overlapping blocks. A limit of 20_000_000 has been set for the requested
  # span size to minimize memory spikes.
  # It is recommended to create a new hdhv object for every rid
  # of the same track since the order of the chromosomes in the binary file may be random
  # [+rid+] rid (chromosome)
  # [+start+] start coordinate
  # [+stop+] stop coordinate
  # [+returnType+] format of the string returned ('bed', 'fixedStep', 'variableStep', 'bedGraph', etc)
  # [+bufferSize+] size of the buffer that will be read from the file into memory (default: 32000000 bytes)
  # [+optsHash+] format specific options hash
  # [+returns+] yields non wig or wig formatted string
  def getCollapsedScoreByRid(rid, start = nil, stop = nil, returnType = nil, bufferSize = nil, optsHash = nil)
    bufferSize = BUFFERSIZE if(bufferSize.nil?)

    # Convert the spanAggFunction value from Symbol to an int (as needed by C function)
    @optionsHash['spanAggFunction'] = SPAN_AGG_FUNCTIONS[@optionsHash['spanAggFunction']]
    frefData = @dbu.selectFrefsByRid(rid)
    chrom = frefData.first['refname']
    @chromLength = frefData.first['rlength']
    bufferSize = BUFFERSIZE if(bufferSize.nil?)
    @desiredSpan = @optionsHash['desiredSpan']

    # Perform checks
    raise "cannot collapse scores if no span is provided" if(@desiredSpan == 0)
    raise "desired span less than 1 for requested wig format" if(@desiredSpan < 1 and (returnType == "fixedStep" or returnType == "variableStep"))
    raise "desired span greater than 20,000,000 with 'collapsedCoverage' not allowed" if(@desiredSpan > 20_000_000)
    if(returnType == "fixedStep" or returnType == "variableStep")
      if(@optionsHash['spanAggFunction'] == 1)
        if(@desiredSpan == 1)
          @spanMedianArray = ""
        elsif(@desiredSpan > 1)
          if(@attributeHash['gbTrackDataSpan'] == 4 or @attributeHash['gbTrackDataSpan'] == 1)
            @spanMedianArray = @createBufferObject.createBuffer(4, @desiredSpan)
          else
            @spanMedianArray = @createBufferObject.createBuffer(8, @desiredSpan)
          end
        end
      else
        @spanMedianArray = ""
      end
    else
      @spanMedianArray = ""
      if(@annosSpan > 0 and @optionsHash['spanAggFunction'] == 1)
        if(@attributeHash['gbTrackDataSpan'] == 4 or @attributeHash['gbTrackDataSpan'] == 1)
          @spanMedianArray = @createBufferObject.createBuffer(4, @desiredSpan)
        else
          @spanMedianArray = @createBufferObject.createBuffer(8, @desiredSpan)
        end
      end
    end

    #Initialize  globals
    @spanSum = 0.0
    @spanCount = 0
    @spanMin = @attributeHash['gbTrackDataMax']
    @spanMax = @attributeHash['gbTrackDataMin']
    @spanSoq = 0.0

    # Convert to integers early on if possible.
    start = start.to_i unless(start.nil?)
    stop = stop.to_i unless(stop.nil?)
    raise "ERROR: start coordinate cannot be a negative value or 0" if(!start.nil? and start <= 0)
    raise "ERROR: stop coordinate cannot be a negative value or 0" if(!stop.nil? and stop <= 0)
    @chromLength = @chromLength.to_i

    # Set requested start and end coords
    @startLandmark = start.nil? ? 1 : start
    @stopLandmark = stop.nil? ? @chromLength.to_i : stop
    @stopLandmark = @stopLandmark <= @chromLength ? @stopLandmark : @chromLength
    @stopLandmark -= 1 if(@ucscModLastSpan)
    landmarkSize = (@stopLandmark - @startLandmark) + 1

    # Do not allow span to be larger than requested region if modulus last span is requested
    raise "requested span cannot be larger than requested region if modulusLastSpan selected" if(@optionsHash['modulusLastSpan'] == 1 and @desiredSpan > landmarkSize and landmarkSize < @chromLength)
    if(@desiredSpan > landmarkSize and landmarkSize >= @chromLength)
      @desiredSpan = landmarkSize
    end
    @globalArray = [0, @startLandmark, 0, 0, @spanSum, @spanCount, @spanMax, @spanMin, @spanSoq, @spanMax, @spanMin, 0, @addLeadingEmptyScores, @startLandmark, 0, @startLandmark]
    @emptyScoreValue = @optionsHash['emptyScoreValue']
    @modLastSpan = @optionsHash['modulusLastSpan']

    # Initialize buffers specific for collapsing
    @preCollapseBuffer = @callocObject.createBuffer(4, @desiredSpan) if(@attributeHash['gbTrackDataSpan'] == 4 or @attributeHash['gbTrackDataSpan'] == 1)
    @preCollapseBuffer = @callocObject.createBuffer(8, @desiredSpan) if(@attributeHash['gbTrackDataSpan'] == 8)
    @countBuffer = @callocObject.createBuffer(4, @desiredSpan) # 4 bytes per count
    @windowStart = @startLandmark
    @addBlockHeader = @emptyScoreValue.empty? ? 1 : 0

    # Get block level records in chunks of 20_000 recs at a time in sorted order (sorted by start and end coord)
    @dbu.eachBlockOfBlockLevelDataInfoByLandmarkOrderedByCoord(rid, @ftypeId, @startLandmark, @stopLandmark, BLOCKSIZE){|blockRecs|
      yieldCollapsedHdhvBlocks(blockRecs, returnType, chrom, bufferSize) {|chunk| yield chunk}
    }

    # Add trailing empty scores values if required
    if(!@emptyScoreValue.empty?)
      @outBuffer << makeBlockHeader(chrom, @windowStart, returnType) if(@windowStart == @startLandmark)
      windowEnd = @windowStart + (@desiredSpan - 1)
      while(windowEnd < @stopLandmark)
        yieldFakeRecs(returnType, chrom, @windowStart, windowEnd)
        @windowStart = windowEnd + 1
        windowEnd += @desiredSpan
        if(@outBuffer.size >= MAX_OUT_BUFFER)
          yield @outBuffer
          @outBuffer = ''
        end
      end

      if(@windowStart <= @stopLandmark)
        # Add block header if modulus last span option is provided
        if(@modLastSpan == 1 or @modLastSpan == 2)
          if(windowEnd > @stopLandmark)
            @desiredSpan = (@stopLandmark - @windowStart) + 1
            @outBuffer << makeBlockHeader(chrom, @windowStart, returnType)
            @desiredSpan = @optionsHash['desiredSpan']
          end
          yieldFakeRecs(returnType, chrom, @windowStart, @stopLandmark)
        else
          yieldFakeRecs(returnType, chrom, @windowStart, windowEnd)
        end
      end
    end
    yield @outBuffer if(!@outBuffer.empty?)
    @binReader.close if(@binReader and @binReader.is_a?(IO) and !@binReader.closed?)
    @outBuffer = ""
    @cBuffer = ""
    @expandBuffer = ""
    @preCollapseBuffer = ""
    @postCollapseBuffer = ""
    @countBuffer = ""
  end

  # Called by 'getCollapsedScoreByRid'. Processes a chunk of database block level records at a time
  # May have to process one or more records if the blocks are overlapping, i.e, more than one score for
  # a base. In that case, the scores for the base will be collapsed (averaged) before applying the aggregating
  # function.
  # [+blockLevelRec+] array of arrays of database records from the 'blockLevelDataInfo' table
  # [+retType+] requested return type
  # [+chrom+] chromosome
  # [+bufferSize+] size of the buffer that will be read from the file into memory
  # [+returns+] yields wig and non wig formatted strings, one block at a time
  def yieldCollapsedHdhvBlocks(blockLevelRec, retType, chrom, bufferSize)
    @blockIndex = 0
    prevBlockId = nil
    prevFile = nil
    blockLevelSize = blockLevelRec.size

    # Change the return type to an integer for the C side of things
    returnType = nil
    if(retType == "fixedStep")
      returnType = 1
    elsif(retType == "variableStep")
      returnType = 2
    elsif(retType == "bed")
      returnType = 3
    elsif(retType == "bedGraph")
      returnType = 4
    elsif(retType == "lff")
      returnType = 5
    elsif(retType == "gff")
      returnType = 6
    elsif(retType == "gff3")
      returnType = 7
    elsif(retType == "gtf")
      returnType = 8
    elsif(retType == "psl")
      returnType = 9
    else
      raise "Unkown format type: #{retType}"
    end

    @attributeArr = [@attributeHash['gbTrackDataSpan'], @attributeHash['gbTrackDenominator']]

    # Loop over the chunk untill we have either processed all the block recs in the chunk or reached @stopLandmark
    while(@blockIndex < blockLevelSize)
      blockRecs = []
      blockItems = getBlockVariables(blockLevelRec[@blockIndex])
      blockStartCoord = blockLevelRec[@blockIndex]['fstart'].to_i
      blockStopCoord = blockLevelRec[@blockIndex]['fstop'].to_i

      # Add block header for variableStep/fixedStep
      # 'emptyScoreValue' needs to be added
      if(retType == 'fixedStep' or retType == 'variableStep')
        if(!@emptyScoreValue.empty?)
          if(@emptyScoreValueBlockHeaderCount == 0)
            @outBuffer << makeBlockHeader(chrom, @windowStart, retType)
            @emptyScoreValueBlockHeaderCount = 1
          end
        end
      end

      # If window start is smaller than block start coord, make block start the new window start if no 'emptyScoreValue' provided
      # Otherwise, fill the gap with 'emptyScoreValue'
      if(@windowStart < blockStartCoord)
        # Make the blockStart the new windowStart if we don't want 'emptyScoreValue'
        if(@emptyScoreValue.empty?)
          @windowStart = blockStartCoord
          @addBlockHeader = 1
        # If 'emptyScoreValue' is provided, we need to fill the gap with 'emptyScoreValue'
        else
          windowEnd = @windowStart + (@desiredSpan - 1)
          while(windowEnd < blockStartCoord)
            yieldFakeRecs(retType, chrom, @windowStart, windowEnd)
            @windowStart = windowEnd + 1
            windowEnd += @desiredSpan
            if(@outBuffer.size >= MAX_OUT_BUFFER)
              yield @outBuffer
              @outBuffer = ''
            end
          end
        end
      end

      # Make sure that the window start is smaller/equal to the block stop
      # If not move index by 1
      while(@windowStart > blockStopCoord)
        @blockIndex += 1
        break if(@blockIndex == blockLevelSize)
        blockStopCoord = blockLevelRec[@blockIndex]['fstop'].to_i
        blockStartCoord = blockLevelRec[@blockIndex]['fstart'].to_i
      end
      break if(@blockIndex == blockLevelSize)
      tempBlockIndex = @blockIndex
      windowEnd = @windowStart + (@desiredSpan - 1)

      # Its possible that block start is larger than window end
      # Deal with it based on the presence/absence of 'emptyScoreValue'
      if(@emptyScoreValue.empty?)
        if(windowEnd < blockStartCoord)
          @addBlockHeader = 1
          @windowStart = blockStartCoord
          windowEnd = @windowStart + (@desiredSpan - 1)
        end
      else
         while(windowEnd < blockStartCoord)
           yieldFakeRecs(retType, chrom, @windowStart, windowEnd)
           @windowStart = windowEnd + 1
           windowEnd += @desiredSpan
           if(@outBuffer.size >= MAX_OUT_BUFFER)
             yield @outBuffer
             @outBuffer = ''
           end
         end
      end

      # Make sure we have all the blocks that contain the window
      while(windowEnd >= blockStartCoord)
        blockRecs << blockLevelRec[tempBlockIndex]
        tempBlockIndex += 1
        break if(tempBlockIndex == blockLevelSize)
        blockStartCoord = blockLevelRec[tempBlockIndex]['fstart'].to_i
      end

      # Walk through the all the records relevant to the current window/span
      blockRecs.each { |blockLevelData|
        blockItems = getBlockVariables(blockLevelData)
        fileName = blockItems['fileName']
        offset = blockItems['offset']
        blockId = blockItems['id']
        byteLength = blockItems['byteLength']
        numRecords = blockItems['numRecords']
        blockStart = blockItems['start']
        blockEnd = blockItems['stop']
        blockLowLimit = blockItems['blockLowLimit']
        blockScale = blockItems['blockScale']
        next if(@optionsHash['modulusLastSpan'] == 1 and blockStart > @stopLandmark) # We have reached the end
        if(byteLength < 1)
          $stderr.puts "Warning: 'byteLength' smaller than 1 for #{chrom}:#{blockStart}-#{blockEnd}. Corrupted track? Skipping block.."
          next
        end
        if(prevFile.nil? or prevFile != fileName)
          @binReader.close if(@binReader and @binReader.is_a?(IO) and !@binReader.closed?)
          @binReader = File.open("#{@dir}/#{fileName}")
          readBinData(byteLength, bufferSize, offset)
          @startOffsetFromFile = offset
          if(@attributeHash['gbTrackDataSpan'] * numRecords > @expandBufferSize)
            @expandBuffer = @createBufferObject.createBuffer(@attributeHash['gbTrackDataSpan'], numRecords)
            @expandBufferSize = @attributeHash['gbTrackDataSpan'] * numRecords
          end
          @bufferOffset = 0
          expRet = @expandBlockObject.expandBlock(@binScores, @expandBuffer, @attributeHash['gbTrackDataSpan'], numRecords, byteLength, 0)
          raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
        else
          # new block encountered
          if(blockId != prevBlockId)
            # Check if we have it in memory
            if(@startOffsetFromFile + @byteRead > offset + byteLength)
              if(offset > @prevOffset)
                @bufferOffset = @bufferOffset + (offset - @prevOffset)
              else
                @bufferOffset = @buffserOffset - (@prevOffset - offset)
              end
              if(@attributeHash['gbTrackDataSpan'] * numRecords > @expandBufferSize)
                @expandBuffer = @createBufferObject.createBuffer(@attributeHash['gbTrackDataSpan'], numRecords)
                @expandBufferSize = @attributeHash['gbTrackDataSpan'] * numRecords
              end
              expRet = @expandBlockObject.expandBlock(@binScores, @expandBuffer, @attributeHash['gbTrackDataSpan'], numRecords, byteLength, @bufferOffset)
              raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
            # We dont have the new block in memory
            # Will have the read in the raw bin data again
            else
              readBinData(byteLength, bufferSize, offset)
              @startOffsetFromFile = offset
              if(@attributeHash['gbTrackDataSpan'] * numRecords > @expandBufferSize)
                @expandBuffer = @createBufferObject.createBuffer(@attributeHash['gbTrackDataSpan'], numRecords)
                @expandBufferSize = @attributeHash['gbTrackDataSpan'] * numRecords
              end
              @bufferOffset = 0
              expRet = @expandBlockObject.expandBlock(@binScores, @expandBuffer, @attributeHash['gbTrackDataSpan'], numRecords, byteLength, 0)
              raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
            end
          end
        end
        @computeCollapsedScoresObject.computeScores(@preCollapseBuffer, @countBuffer, @expandBuffer, @attributeArr, [blockStart, blockEnd, blockScale, blockLowLimit],
        [@desiredSpan, @optionsHash['spanAggFunction'], @optionsHash['modulusLastSpan']], [@startLandmark, @stopLandmark], chrom, @windowStart, @optionsHash['emptyScoreValue'])
        @prevOffset = offset
        prevBlockId = blockId
        prevFile = fileName
      }

      # Span/Window computed. Print score to buffer
      @emptyWindow = @printCollapsedScoresObject.printScores(@cBuffer, @preCollapseBuffer, @countBuffer, @attributeArr,
       [@desiredSpan, @optionsHash['spanAggFunction'], @optionsHash['modulusLastSpan']] , [@startLandmark, @stopLandmark], chrom, @windowStart, @optionsHash['emptyScoreValue'],
       @globalArray, @spanMedianArray, returnType, @trackType, @trackSubType, [@optionsHash['scaleScores'], @scaleFactor])
      if(@emptyWindow == 0)
        if(@addBlockHeader == 1)
          if(retType == 'fixedStep')
            @outBuffer << makeBlockHeader(chrom, @windowStart, retType)
          elsif(retType == 'variableStep')
            if(@varStepBlockHeaderCount == 0)
              @outBuffer << makeBlockHeader(chrom, @windowStart, 'variableStep')
              @varStepBlockHeaderCount = 1
            end
          else
            # Do nothing for other formats, i.e, no block header to be added for non wig formats
          end
        end
        @outBuffer << @cBuffer
        @addBlockHeader = 0
      else
        @addBlockHeader = 1
      end
      if(@outBuffer.size >= MAX_OUT_BUFFER)
        yield @outBuffer
        @outBuffer = ''
      end
      @windowStart += @desiredSpan
      break if(@windowStart > @stopLandmark)

      # Add a new block header is modulus last span is 1 or 2 (ucsc style) is selected and the next window/span end coord is going beyond the
      # requested stop coord
      if(@modLastSpan == 1)
        windowEnd = @windowStart + (@desiredSpan - 1)
        if(windowEnd > @stopLandmark)
          @desiredSpan = (@stopLandmark - @windowStart) + 1
          @outBuffer << makeBlockHeader(chrom, @windowStart, retType)
          @desiredSpan = @optionsHash['desiredSpan']
        end
      end
    end
  end

  # Reads binary data from the binary file
  # [+sizeOfBlock+]
  # [+bufferSize+]
  # [+offset+]
  # [+returns+] nil
  def readBinData(sizeOfBlock, bufferSize, offset)
    @binReader.seek(offset)
    if(sizeOfBlock <= bufferSize)
      @binScores = @binReader.read(bufferSize)
      @byteRead = bufferSize
    else
      @binScores = @binReader.read(sizeOfBlock)
      @byteRead = sizeOfBlock
    end
  end

  # Constructs records with 'emptyScoreValue'
  # [+retType+] format type
  # [+chrom+] chrom name
  # [+windowStart+]
  # [+windowEnd+]
  # [+returns+] nil
  def yieldFakeRecs(retType, chrom, windowStart, windowEnd)
    if(retType == "fixedStep")
      @outBuffer << "#{@emptyScoreValue}\n"
    elsif(retType == "variableStep")
      @outBuffer << "#{windowStart} #{@emptyScoreValue}\n"
    elsif(retType == "bed")
      @outBuffer << "#{chrom}\t#{windowStart - 1}\t#{windowEnd}\t#{chrom}:#{windowStart - 1}-#{windowEnd}\t#{@emptyScoreValue}\n"
    elsif(retType == "bedGraph")
      @outBuffer << "#{chrom}\t#{windowStart - 1}\t#{windowEnd}\t#{@emptyScoreValue}\n"
    elsif(retType == "lff")
      @outBuffer << "High Density Score Data\t#{chrom}:#{windowStart}-#{windowEnd}\t#{@trackType}\t#{@trackSubType}\t#{chrom}\t#{windowStart}\t#{windowEnd}\t+\t.\t#{@emptyScoreValue}\n"
    elsif(retType == "gff")
      @outBuffer << "#{chrom}\t#{@trackType}\t#{@trackSubType}\t#{windowStart}\t#{windowEnd}\t#{@emptyScoreValue}\t.\t.\t#{chrom}:#{windowStart}-#{windowEnd}\n"
    elsif(retType == "gff3")
      @outBuffer << "#{chrom}\t#{@trackType}\t#{@trackSubType}\t#{windowStart}\t#{windowEnd}\t#{@emptyScoreValue}\t.\t.\tName=#{chrom}:#{windowStart}-#{windowEnd}\n"
    elsif(retType == "gtf")
      @outBuffer << "#{chrom}\t#{@trackType}\t#{@trackSubType}\t#{windowStart}\t#{windowEnd}\t#{@emptyScoreValue}\t.\t.\tgene_id \"#{chrom}:#{windowStart}-#{windowEnd}\"; transcript_id \"#{chrom}:#{windowStart}-#{windowEnd}\"\n"
    end
  end

  # sets up the options hash
  # [+optsHash+]
  # [+returns+] nil
  def setOptsHash(optsHash)
    @optionsHash['scaleScores'] = optsHash['scaleScores']
    @optionsHash['desiredSpan'] = (optsHash['desiredSpan'] ? optsHash['desiredSpan'].to_i : 0)
    @annosSpan = @optionsHash['desiredSpan']
    @optionsHash['spanAggFunction'] = optsHash['spanAggFunction'] if(optsHash.key?('spanAggFunction'))
    # Check if only +ve or only -ve scores are to be retrieved
    # First make sure that both are not true
    posScores = optsHash['posScoresOnly'] if(optsHash.has_key?('posScoresOnly'))
    negScores = optsHash['negScoresOnly'] if(optsHash.has_key?('negScoresOnly'))
    @posScores = if(posScores and !posScores.empty? and posScores =~ /^(?:yes|true)/i) then 1 else 0 end
    @negScores = if(negScores and !negScores.empty? and negScores =~ /^(?:yes|true)/i) then 1 else 0 end
    @posScores = @negScores = 0 if(@posScores == 1 and @negScores == 1)
    @optionsHash['posScoresOnly'] = @posScores
    @optionsHash['negScoresOnly'] = @negScores
    @optionsHash['emptyScoreValue'] = optsHash['emptyScoreValue'] if(!optsHash['emptyScoreValue'].nil? and !optsHash['emptyScoreValue'].empty?)
    @optionsHash['endSpan'] = optsHash['endSpan'] if(optsHash['endSpan'])
    modLastSpan = optsHash['modulusLastSpan'] if(optsHash.has_key?('modulusLastSpan'))
    @ucscModLastSpan = false
    if(modLastSpan and !modLastSpan.empty? and modLastSpan =~ /^(?:yes|true|ucscStyle)/i)
      @optionsHash['modulusLastSpan'] = 1
      @ucscModLastSpan = true if(modLastSpan =~ /^ucscStyle/i)
    else
      @optionsHash['modulusLastSpan'] = 0
    end
    colCoverage = optsHash['collapsedCoverage']
    @optionsHash['collapsedCoverage'] = if(colCoverage and !colCoverage.empty? and colCoverage =~ /^(?:yes|true)/i) then 1 else 0 end

  end

  # Processes data for one chromosome (rid) at a time
  # Receives chunks of database block level records, processes the chunk and 'yields' the processed
  # chunk (one block at a time). Note that in case of overlapping blocks (more than one score for a base),
  # new blocks will be created starting from the first overlapped base.
  # It is recommended to create a new hdhv object for every rid
  # of the same track since the order of the chromosomes in the binary file may be random
  # [+rid+] rid (chromosome)
  # [+start+] start coordinate
  # [+stop+] stop coordinate
  # [+returnType+] format of the string returned ('bed', 'fixedStep', 'variableStep', 'bedGraph', etc)
  # [+bufferSize+] size of the buffer that will be read from the file into memory (default: 32000000 bytes)
  # [+optsHash+] format specific options hash
  # [+returns+] yields non wig or wig formatted string
  def getScoreByRid(rid, start = nil, stop = nil, returnType = nil, bufferSize = nil, optsHash = nil)
    returnType = "fixedStep" if(returnType.nil?)
    @optionsHash['emptyScoreValue'] = ""
    setOptsHash(optsHash) if(!optsHash.nil? and !optsHash.empty?)
    frefData = @dbu.selectFrefsByRid(rid)
    chrom = frefData.first['refname']
    @chromLength = frefData.first['rlength']

    # Check if there are overlaps, if the user wants collapsed scores
    # Download block level recs in chunks. break if overlap found in any chunk
    if(@optionsHash['collapsedCoverage'] == 1)
      overlap = false
      blockStartCoord = nil
      prevBlockStopCoord = nil
      @dbu.eachBlockOfBlockLevelDataInfoByLandmarkOrderedByCoord(rid, @ftypeId, 1, @chromLength.to_i, BLOCKSIZE){|blockRecs|
        blockRecs.each { |blockRec|
          if(!prevBlockStopCoord.nil?)
            blockStartCoord = blockRec['fstart'].to_i
            if(blockStartCoord <= prevBlockStopCoord)
              overlap = true
              break
            end
          end
          break if(overlap)
          prevBlockStopCoord = blockRec['fstop'].to_i
        }
        break if(overlap)
      }
      #$stderr.puts "overlap: #{overlap.inspect}"

      # If overlaps are present, we need to call a different function
      if(overlap)
        getCollapsedScoreByRid(rid, start, stop, returnType, bufferSize, optsHash) { |chunk| yield chunk}
        return
      end
    end

    # Convert the spanAggFunction value from Symbol to an int (as needed by C function)
    @optionsHash['spanAggFunction'] = SPAN_AGG_FUNCTIONS[@optionsHash['spanAggFunction']]
    bufferSize = BUFFERSIZE if(bufferSize.nil?)
    @desiredSpan = @optionsHash['desiredSpan']
    raise "desired span less than 1 for requested wig format" if(@desiredSpan < 1 and (returnType == "fixedStep" or returnType == "variableStep"))
    raise "desired span greater than 10,000,000 with median as aggregating function not allowed" if(@desiredSpan > 10_000_000 and @optionsHash['spanAggFunction'] == 1)
    if(returnType == "fixedStep" or returnType == "variableStep")
      if(@optionsHash['spanAggFunction'] == 1)
        if(@desiredSpan == 1)
          @spanMedianArray = ""
        elsif(@desiredSpan > 1)
          if(@attributeHash['gbTrackDataSpan'] == 4 or @attributeHash['gbTrackDataSpan'] == 1)
            @spanMedianArray = @createBufferObject.createBuffer(4, @desiredSpan)
          else
            @spanMedianArray = @createBufferObject.createBuffer(8, @desiredSpan)
          end
        end
      else
        @spanMedianArray = ""
      end
    else
      @spanMedianArray = ""
      if(@annosSpan > 0 and @optionsHash['spanAggFunction'] == 1)
        if(@attributeHash['gbTrackDataSpan'] == 4 or @attributeHash['gbTrackDataSpan'] == 1)
          @spanMedianArray = @createBufferObject.createBuffer(4, @annosSpan)
        else
          @spanMedianArray = @createBufferObject.createBuffer(8, @annosSpan)
        end
      end
    end
    @spanSum = 0.0
    @spanCount = 0
    @spanMin = @attributeHash['gbTrackDataMax']
    @spanMax = @attributeHash['gbTrackDataMin']
    @spanSoq = 0.0
    @addLeadingEmptyScores = 1 if(!@optionsHash['emptyScoreValue'].empty?)

    # Set landmarks
    start = start.to_i unless(start.nil?)
    stop = stop.to_i unless(stop.nil?)

    raise "ERROR: start coordinate cannot be a negative value or 0" if(!start.nil? and start <= 0 )
    raise "ERROR: stop coordinate cannot be a negative value or 0" if(!stop.nil? and stop <= 0 )
    @chromLength = @chromLength.to_i
    @startLandmark = start.nil? ? 1 : start
    @stopLandmark = stop.nil? ? @chromLength.to_i : stop
    @stopLandmark = @stopLandmark <= @chromLength ? @stopLandmark : @chromLength
    @stopLandmark -= 1 if(@ucscModLastSpan)
    @startLandmark, @stopLandmark = @stopLandmark, @startLandmark if(@startLandmark > @stopLandmark)
    landmarkSize = (@stopLandmark - @startLandmark) + 1

    # Do not allow span to be larger than requested region if modulus last span is requested
    raise "requested span cannot be larger than requested region if modulusLastSpan selected" if(@optionsHash['modulusLastSpan'] == 1 and @desiredSpan > landmarkSize and landmarkSize < @chromLength)
    if(@desiredSpan > landmarkSize and landmarkSize >= @chromLength)
      @desiredSpan = landmarkSize
    end
    # Check if there are any records on this chromosome. If there are aren't and @emptyScoreValue is provided, we need to return records
    blockLevelRows = @dbu.selectBlockLevelDataExistsForFtypeId(@ftypeId)
    @globalArray = [0, @startLandmark, 0, 0, @spanSum, @spanCount, @spanMax, @spanMin, @spanSoq, @spanMax, @spanMin, 0, @addLeadingEmptyScores, @startLandmark, 0, @startLandmark]
    if(( blockLevelRows.nil? or blockLevelRows.empty? ) and !@optionsHash['emptyScoreValue'].empty?)
      addTrailingEmptyScoreValues(returnType, chrom) { |chunk| yield chunk }
    end

    @dbu.eachBlockOfBlockLevelDataInfoByLandmark(rid, @ftypeId, @startLandmark, @stopLandmark, BLOCKSIZE, true){|blockRecs|
      @binReader.close() if(@binReader and @binReader.is_a?(IO) and !@binReader.closed?)
      yieldBlock(blockRecs, returnType, chrom, bufferSize) {|score| yield score}
    }

    # Write out the remaining chunk, if any
    retTypeValue = nil
    if(returnType == "fixedStep")
      retTypeValue = 1
    elsif(returnType == "variableStep")
      retTypeValue = 2
    elsif(returnType == "bed")
      retTypeValue = 3
    elsif(returnType == "bedGraph")
      retTypeValue = 4
    elsif(returnType == "lff")
      retTypeValue = 5
    elsif(returnType == "gff")
      retTypeValue = 6
    elsif(returnType == "gff3")
      retTypeValue = 7
    elsif(returnType == "gtf")
      retTypeValue = 8
    elsif(returnType == "psl")
      retTypeValue = 9
    end
    if(retTypeValue == 1 or retTypeValue == 2)
      @yieldLastChunkObject.returnLastChunk(@cBuffer, @spanMedianArray, @globalArray[2], @optionsHash['spanAggFunction'], @attributeHash['gbTrackDataSpan'],
                                            retTypeValue, @globalArray, @optionsHash['emptyScoreValue'], @stopLandmark, @desiredSpan, @optionsHash['modulusLastSpan'], chrom)
      @outBuffer << @cBuffer
    else
      @yieldLastChunkForNonWigObject.returnLastChunkForNonWig(@cBuffer, @spanMedianArray, @globalArray[2], @optionsHash['spanAggFunction'], @attributeHash['gbTrackDataSpan'], retTypeValue,
                                                            @globalArray, [@stopLandmark, @annosSpan, @optionsHash['modulusLastSpan']], @trackName, @optionsHash['scaleScores'], chrom, @scaleFactor, @optionsHash['emptyScoreValue'])
      @outBuffer << @cBuffer
    end
    @spanMedianArray = ""
    yield @outBuffer if(!@outBuffer.empty?)
    @outBuffer = ""
    # In case 'emptyScoreValue' is used, we may need to add trailing empty score values
    if(!@optionsHash['emptyScoreValue'].empty?)
      addTrailingEmptyScoreValues(returnType, chrom) {|chunk| yield chunk}
    end
    yield @outBuffer if(!@outBuffer.empty?)
    @binReader.close if(@binReader and @binReader.is_a?(IO) and !@binReader.closed?)
    @outBuffer = nil
    (@setBufferSizeObj.setBufferSize(@cBuffer, @origCBufferSize)) rescue nil
    @cBuffer = nil
    (@setBufferSizeObj.setBufferSize(@expandBuffer, @expandBufferSize)) rescue nil
    @expandBuffer = nil
    @binScores = nil
  end

  # Adds 'emptyScoreValues' after the 'real' scores are done but the requested end coord has not been reached
  # [+retType+] format requested
  # [+chrom+] chromosome name
  # [+returns+] yields chunks of lines
  def addTrailingEmptyScoreValues(retType, chrom)
    prevEndCoord = 0
    @outBuffer << makeBlockHeader(chrom, @startLandmark, retType) if((retType == "fixedStep" or retType == "variableStep") and @globalArray[1] == @startLandmark and @globalArray[2] == 0)
    if(@globalArray[3] != 0)
      prevEndCoord = @globalArray[1] + (@desiredSpan - 1)
    else
      prevEndCoord = @globalArray[1] - 1
    end
    @emptyScoreValue = @optionsHash['emptyScoreValue']
    modLastSpan = @optionsHash['modulusLastSpan']
    @desiredSpan = 1 if(@desiredSpan == 0) # For cases where non-wig format is requested without any span
    if(prevEndCoord < @stopLandmark)
      endCoord = prevEndCoord
      while(endCoord < @stopLandmark)
        startCoord = endCoord + 1
        endCoord = startCoord + (@desiredSpan - 1)
        if(modLastSpan == 0)
          if(retType == "fixedStep")
            @outBuffer << "#{@emptyScoreValue}\n"
          elsif(retType == "variableStep")
            @outBuffer << "#{startCoord} #{@emptyScoreValue}\n"
          elsif(retType == "bed")
            @outBuffer << "#{chrom}\t#{startCoord - 1}\t#{endCoord}\t#{chrom}:#{startCoord - 1}-#{endCoord}\t#{@emptyScoreValue}\n"
          elsif(retType == "bedGraph")
            @outBuffer << "#{chrom}\t#{startCoord - 1}\t#{endCoord}\t#{@emptyScoreValue}\n"
          elsif(retType == "lff")
            @outBuffer << "High Density Score Data\t#{chrom}:#{startCoord}-#{endCoord}\t#{@trackType}\t#{@trackSubType}\t#{chrom}\t#{startCoord}\t#{endCoord}\t+\t.\t#{@emptyScoreValue}\n"
          elsif(retType == "gff")
            @outBuffer << "#{chrom}\t#{@trackType}\t#{@trackSubType}\t#{startCoord}\t#{endCoord}\t#{@emptyScoreValue}\t.\t.\t#{chrom}:#{startCoord}-#{endCoord}\n"
          elsif(retType == "gff3")
            @outBuffer << "#{chrom}\t#{@trackType}\t#{@trackSubType}\t#{startCoord}\t#{endCoord}\t#{@emptyScoreValue}\t.\t.\tName=#{chrom}:#{startCoord}-#{endCoord}\n"
          elsif(retType == "gtf")
            @outBuffer << "#{chrom}\t#{@trackType}\t#{@trackSubType}\t#{startCoord}\t#{endCoord}\t#{@emptyScoreValue}\t.\t.\tgene_id \"#{chrom}:#{startCoord}-#{endCoord}\"; transcript_id \"#{chrom}:#{startCoord}-#{endCoord}\"\n"
          end
        else
          if(endCoord > @stopLandmark)
            if(retType == "fixedStep" or retType == "variableStep")
              @desiredSpan = (@stopLandmark - startCoord) + 1
              @outBuffer << makeBlockHeader(chrom, startCoord, retType)
            end
          end
          if(retType == "fixedStep")
            @outBuffer << "#{@emptyScoreValue}\n"
          elsif(retType == "variableStep")
            @outBuffer << "#{startCoord} #{@emptyScoreValue}\n"
          elsif(retType == "bed")
            @outBuffer << "#{chrom}\t#{startCoord - 1}\t#{startCoord + (@desiredSpan - 1)}\t#{chrom}:#{startCoord - 1}-#{startCoord + (@desiredSpan - 1)}\t#{@emptyScoreValue}\n"
          elsif(retType == "bedGraph")
            @outBuffer << "#{chrom}\t#{startCoord - 1}\t#{startCoord + (@desiredSpan - 1)}\t#{@emptyScoreValue}\n"
          elsif(retType == "lff")
            @outBuffer << "High Density Score Data\t#{chrom}:#{startCoord}-#{startCoord + (@desiredSpan - 1)}\t#{@trackType}\t#{@trackSubType}\t#{chrom}\t#{startCoord}\t#{startCoord + (@desiredSpan - 1)}\t+\t.\t#{@emptyScoreValue}\n"
          elsif(retType == "gff")
            @outBuffer << "#{chrom}\t#{@trackType}\t#{@trackSubType}\t#{startCoord}\t#{startCoord + (@desiredSpan - 1)}\t#{@emptyScoreValue}\t.\t.\t#{chrom}:#{startCoord}-#{startCoord + (@desiredSpan - 1)}\n"
          elsif(retType == "gff3")
            @outBuffer << "#{chrom}\t#{@trackType}\t#{@trackSubType}\t#{startCoord}\t#{startCoord + (@desiredSpan - 1)}\t#{@emptyScoreValue}\t.\t.\tName=#{chrom}:#{startCoord}-#{startCoord + (@desiredSpan - 1)}\n"
          elsif(retType == "gtf")
            @outBuffer << "#{chrom}\t#{@trackType}\t#{@trackSubType}\t#{startCoord}\t#{startCoord + (@desiredSpan - 1)}\t#{@emptyScoreValue}\t.\t.\tgene_id \"#{chrom}:#{startCoord}-#{startCoord + (@desiredSpan - 1)}\"; transcript_id \"#{chrom}:#{startCoord}-#{startCoord + (@desiredSpan - 1)}\"\n"
          end
        end
        if(@outBuffer.size > MAX_OUT_BUFFER)
          yield @outBuffer
          @outBuffer = ""
        end
      end
    end
  end

  # Reads the binary block content in a buffer
  # [+sizeOfBlock+] size of the block in bytes
  # [+bufferSize+] size of the buffer to read
  # [+returns+] nil
  def readBuffer(sizeOfBlock, bufferSize)
    if(sizeOfBlock <= bufferSize)
      @binScores = @binReader.read(bufferSize)
      @byteRead = @byteRead + bufferSize
    else
      @binScores = @binReader.read(sizeOfBlock)
      @byteRead = @byteRead + sizeOfBlock
    end
  end

  # Called by 'getScoreByrid'. Processes a chunk of database block level records at time
  # Goes through the array of arrays, processes each block at a time and yields the format
  # requested. Makes use of the buffer read for the first record of the chunk. For the subsequent
  # blocks, seeks in memory rather than string if block is contained in the buffer.
  # Note that binary data for each block is gzipped. the 'zlib' library is used for unpacking
  # and subsequently the raw binary data is passed to the C function
  # [+blockLevelRec+] array of arrays of database records from the 'blockLevelDataInfo' table
  # [+retType+] requested return type ('bed', 'fixedStep', 'variableStep')
  # [+chrom+] chromosome
  # [+bufferSize+] size of the buffer that will be read from the file into memory
  # [+returns+] yields wig and non wig formatted strings, one block at a time
  def yieldBlock(blockLevelRec, retType, chrom, bufferSize)
    # Iterate over block records
    # Consider all possible cases:
    #   - when 'start' and 'stop' both not provided
    #   - only 'start' provided
    #   - only 'stop' provided
    #   - both 'start' and 'stop' provided
    @fileHash = {}
    blockLevelRec.size.times { |@blockRec|
      # If new file
      if(!@fileHash.has_key?(blockLevelRec[@blockRec]['fileName']))
        # Close the previous file handler
        @binReader.close if(@binReader and @binReader.is_a?(IO) and !@binReader.closed?)
        @fileHash[blockLevelRec[@blockRec]['fileName']] = nil
        @binReader = File.open("#{@dir}/#{blockLevelRec[@blockRec]['fileName']}")
        blockVar = getBlockVariables(blockLevelRec[@blockRec])
        next if(@optionsHash['modulusLastSpan'] == 1 and blockVar['start'] > @chromLength) # We have reached the end
        if(blockVar['byteLength'] < 1)
          $stderr.puts "Warning: 'byteLength' smaller than 1 for #{chrom}:#{blockVar['start']}-#{blockVar['stop']}}. Skipping.."
          next
        end
        # Both start and end coords are contained within the record
        if((@startLandmark >= blockVar['start'] and @startLandmark <= blockVar['stop']) and (@stopLandmark >= blockVar['start'] and @stopLandmark <= blockVar['stop']))
          seekLength = (@startLandmark - blockVar['start'])
          blockVar['start'] = @startLandmark
          @startOffsetFromFile = seekLength * @attributeHash['gbTrackDataSpan']
          seekTill = @stopLandmark - @startLandmark
          sizeOfBlock = blockVar['byteLength']
          @binReader.seek(blockVar['offset'])
          readBuffer(sizeOfBlock, bufferSize)
          inflatedBinScoresToProcess = getInflatedScoresToProcess(sizeOfBlock, seekLength, blockVar)
          getBackScores(retType, chrom, blockVar, inflatedBinScoresToProcess, seekTill + 1) {|scores| yield scores}
        # only start coord is contained within the record
        elsif((@startLandmark >= blockVar['start'] and @startLandmark <= blockVar['stop']) and !(@stopLandmark >= blockVar['start'] and @stopLandmark <= blockVar['stop']))
          # Jump over the unwanted region
          seekLength = (@startLandmark - blockVar['start'])
          @startOffsetFromFile = seekLength * @attributeHash['gbTrackDataSpan']
          sizeOfBlock = blockVar['byteLength']
          @offsetInBuffer = 0
          blockVar['start'] = blockVar['start'] + (seekLength * blockVar['blockSpan'])
          @binReader.seek(blockVar['offset'])
          readBuffer(sizeOfBlock, bufferSize)
          inflatedBinScoresToProcess = getInflatedScoresToProcess(sizeOfBlock, seekLength, blockVar)
          getBackScores(retType, chrom, blockVar, inflatedBinScoresToProcess, (blockVar['numRecords'] - seekLength)) {|scores| yield scores}
          @prevOffsetInFile = blockVar['offset']
        # only end coord is contained within the record.
        elsif(!(@startLandmark >= blockVar['start'] and @startLandmark <= blockVar['stop']) and (@stopLandmark >= blockVar['start'] and @stopLandmark <= blockVar['stop']))
          seekTill = @stopLandmark - blockVar['start']
          sizeOfBlock = blockVar['byteLength']
          @startOffsetFromFile = blockVar['offset']
          @binReader.seek(blockVar['offset'])
          readBuffer(sizeOfBlock, bufferSize)
          if(@attributeHash['gbTrackDataSpan'] * blockVar['numRecords'] > @expandBufferSize)
            @setBufferSizeObj.setBufferSize(@expandBuffer, @expandBufferSize) # Reset to original size to avoid memory leak
            @expandBuffer = nil
            @expandBuffer = @createBufferObject.createBuffer(@attributeHash['gbTrackDataSpan'], blockVar['numRecords'])
            @expandBufferSize = @attributeHash['gbTrackDataSpan'] * blockVar['numRecords']
          end
          expRet = @expandBlockObject.expandBlock(@binScores, @expandBuffer, @attributeHash['gbTrackDataSpan'], blockVar['numRecords'], sizeOfBlock, 0)
          raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
          getBackScores(retType, chrom, blockVar, @expandBuffer, seekTill + 1) {|scores| yield scores}
        # both start and end coords are not conatained within the block
        elsif(!(@startLandmark >= blockVar['start'] and @startLandmark <= blockVar['stop']) and !(@stopLandmark >= blockVar['start'] and @stopLandmark <= blockVar['stop']))
          sizeOfBlock = blockVar['byteLength']
          @offsetInBuffer = 0
          @binReader.seek(blockVar['offset'])
          @startOffsetFromFile = blockVar['offset']
          readBuffer(sizeOfBlock, bufferSize)
          if(@attributeHash['gbTrackDataSpan'] * blockVar['numRecords'] > @expandBufferSize)
            @setBufferSizeObj.setBufferSize(@expandBuffer, @expandBufferSize) # Reset to original size to avoid memory leak
            @expandBuffer = nil
            @expandBuffer = @createBufferObject.createBuffer(@attributeHash['gbTrackDataSpan'], blockVar['numRecords'])
            @expandBufferSize = @attributeHash['gbTrackDataSpan'] * blockVar['numRecords']
          end
          expRet = @expandBlockObject.expandBlock(@binScores, @expandBuffer, @attributeHash['gbTrackDataSpan'], blockVar['numRecords'], sizeOfBlock, 0)
          raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
          getBackScores(retType, chrom, blockVar, @expandBuffer, blockVar['numRecords']) {|scores| yield scores}
          @prevOffsetInFile = blockVar['offset']
        else # Not possible to hit this case
          # Do nothing
        end
      # For old file
      else
        @binReader = File.open("#{@dir}/#{blockLevelRec[@blockRec]['fileName']}") if(@binReader.closed?) # File handler may have been closed just before yielding chunk (to avoid pooling up of file handles)
        blockVar = getBlockVariables(blockLevelRec[@blockRec])
        next if(@optionsHash['modulusLastSpan'] == 1 and blockVar['start'] > @chromLength) # We have reached the end
        if(blockVar['byteLength'] < 1)
          $stderr.puts "Warning: 'byteLength' smaller than 1 for #{chrom}:#{blockVar['start']}-#{blockVar['stop']}}. Skipping.."
          next
        end
        sizeOfBlock = blockVar['byteLength']
        # end coord contained in the block
        if(@stopLandmark >= blockVar['start'] and @stopLandmark <= blockVar['stop'])
          seekTill = @stopLandmark - blockVar['start']
          @binReader.seek(blockVar['offset'])
          readBuffer(sizeOfBlock, bufferSize)
          if(@attributeHash['gbTrackDataSpan'] * blockVar['numRecords'] > @expandBufferSize)
            @setBufferSizeObj.setBufferSize(@expandBuffer, @expandBufferSize) # Reset to original size to avoid memory leak
            @expandBuffer = nil
            @expandBuffer = @createBufferObject.createBuffer(@attributeHash['gbTrackDataSpan'], blockVar['numRecords'])
            @expandBufferSize = @attributeHash['gbTrackDataSpan'] * blockVar['numRecords']
          end
          expRet = @expandBlockObject.expandBlock(@binScores, @expandBuffer, @attributeHash['gbTrackDataSpan'], blockVar['numRecords'], sizeOfBlock, 0)
          raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
          getBackScores(retType, chrom, blockVar, @expandBuffer, seekTill + 1) {|scores| yield scores}
        # end coord not contained within the record
        else
          if(@byteRead > bufferSize)
            @byteRead = 0
            @startOffsetFromFile = blockVar['offset']
            @offsetInBuffer = 0
            @binReader.seek(blockVar['offset'])
            readBuffer(sizeOfBlock, bufferSize)
            if(@attributeHash['gbTrackDataSpan'] * blockVar['numRecords'] > @expandBufferSize)
              @setBufferSizeObj.setBufferSize(@expandBuffer, @expandBufferSize) # Reset to original size to avoid memory leak
              @expandBuffer = nil
              @expandBuffer = @createBufferObject.createBuffer(@attributeHash['gbTrackDataSpan'], blockVar['numRecords'])
              @expandBufferSize = @attributeHash['gbTrackDataSpan'] * blockVar['numRecords']
            end
            expRet = @expandBlockObject.expandBlock(@binScores, @expandBuffer, @attributeHash['gbTrackDataSpan'], blockVar['numRecords'], sizeOfBlock, 0)
            raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
            getBackScores(retType, chrom, blockVar, @expandBuffer, blockVar['numRecords']) {|scores| yield scores}
          else
            if((blockVar['offset'] + sizeOfBlock) < (@startOffsetFromFile + @byteRead))
              @offsetInBuffer = @offsetInBuffer + (blockVar['offset'] - @prevOffsetInFile)
              if(@attributeHash['gbTrackDataSpan'] * blockVar['numRecords'] > @expandBufferSize)
                @setBufferSizeObj.setBufferSize(@expandBuffer, @expandBufferSize) # Reset to original size to avoid memory leak
                @expandBuffer = nil
                @expandBuffer = @createBufferObject.createBuffer(@attributeHash['gbTrackDataSpan'], blockVar['numRecords'])
                @expandBufferSize = @attributeHash['gbTrackDataSpan'] * blockVar['numRecords']
              end
              expRet = @expandBlockObject.expandBlock(@binScores, @expandBuffer, @attributeHash['gbTrackDataSpan'], blockVar['numRecords'], sizeOfBlock, @offsetInBuffer)
              raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
              getBackScores(retType, chrom, blockVar, @expandBuffer, blockVar['numRecords']) {|scores| yield scores}
            else
              @byteRead = 0
              @startOffsetFromFile = blockVar['offset']
              @offsetInBuffer = 0
              @binReader.seek(blockVar['offset'])
              readBuffer(sizeOfBlock, bufferSize)
              if(@attributeHash['gbTrackDataSpan'] * blockVar['numRecords'] > @expandBufferSize)
                @setBufferSizeObj.setBufferSize(@expandBuffer, @expandBufferSize) # Reset to original size to avoid memory leak
                @expandBuffer = nil
                @expandBuffer = @createBufferObject.createBuffer(@attributeHash['gbTrackDataSpan'], blockVar['numRecords'])
                @expandBufferSize = @attributeHash['gbTrackDataSpan'] * blockVar['numRecords']
              end
              expRet = @expandBlockObject.expandBlock(@binScores, @expandBuffer, @attributeHash['gbTrackDataSpan'], blockVar['numRecords'], sizeOfBlock, 0)
              raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
              getBackScores(retType, chrom, blockVar, @expandBuffer, blockVar['numRecords']) {|scores| yield scores}
            end
          end
          @prevOffsetInFile = blockVar['offset']
        end
      end
      @zInflater.reset()
    }
  end

  # Used for identifying the 'recordType' of the track
  # Note that currently hdhv data is only stored as one of the 'fixedStep' formats
  # [+returns+] dataType ('fixedStep' or 'variableStep')
  def dataType()
    recType = @attributeHash['gbTrackRecordType']
    if(recType == "int8Score" or recType == "int16Score" or recType == "int32Score" or recType == "floatScore" or recType == "doubleScore")
      return "fixedStep"
    elsif(recType == "coordInt8Score")
      return "variableStep"
    end
  end

  # Used for making a hash with information from the block
  # [+blockRec+] one record from the 'blockLevelRec' passed to 'getWiggleOrBed'
  # [+returns+] hash with block level information
  def getBlockVariables(blockRec)
    id = blockRec['id'].to_i
    offset = blockRec['offset'].to_i
    byteLength = blockRec['byteLength'].to_i
    numRecords = blockRec['numRecords'].to_i
    fileName = blockRec['fileName']
    start = blockRec['fstart'].to_i
    stop = blockRec['fstop'].to_i
    @lastStop = stop
    blockSpan = (blockRec['gbBlockBpSpan'] ? blockRec['gbBlockBpSpan'].to_i : @attributeHash['gbTrackBpSpan'])
    blockStep = (blockRec['gbBlockBpStep'] ? blockRec['gbBlockBpStep'].to_i : @attributeHash['gbTrackBpStep'])
    blockScale = (blockRec['gbBlockScale'] ? blockRec['gbBlockScale'].to_f : @attributeHash['gbTrackScale'])
    blockLowLimit = (blockRec['gbBlockLowLimit'] ? blockRec['gbBlockLowLimit'].to_f : @attributeHash['gbTrackLowLimit'])
    blockHash = {
      'id' => id,
      'offset' => offset,
      'byteLength' => byteLength,
      'numRecords' => numRecords,
      'start' => start,
      'stop' => stop,
      'blockSpan' => blockSpan,
      'blockStep' => blockStep,
      'blockScale' => blockScale,
      'blockLowLimit' => blockLowLimit,
      'fileName' => fileName
      }
    return blockHash
  end

  # Expand compressed zlib stream and return the 'required' string to process
  # the required string contains only the scores within the requested region
  # [+sizeOfBlock+] size of the compressed zlib stream (byteLength from blockLevelDataInfo)
  # [+seekLength+] multiply this value to the dataSpan and start from that offset
  # [+return+] inflatedBinScoresToProcess. This is the string which will be passed to the C function
  def getInflatedScoresToProcess(sizeOfBlock, seekLength, blockVar)
    if(@attributeHash['gbTrackDataSpan'] * blockVar['numRecords'] > @expandBufferSize)
      @setBufferSizeObj.setBufferSize(@expandBuffer, @expandBufferSize) # Reset to original size to avoid memory leak
      @expandBuffer = nil
      @expandBuffer = @createBufferObject.createBuffer(@attributeHash['gbTrackDataSpan'], blockVar['numRecords'])
      @expandBufferSize = @attributeHash['gbTrackDataSpan'] * blockVar['numRecords']
    end
    expRet = @expandBlockObject.expandBlock(@binScores, @expandBuffer, @attributeHash['gbTrackDataSpan'], blockVar['numRecords'], sizeOfBlock, 0)
    raise "ERROR: Could not expand zlib stream..." if(expRet == 0)
    @startOffsetFromFile = seekLength * @attributeHash['gbTrackDataSpan']
    inflatedBinScoresIO = StringIO.new(@expandBuffer)
    inflatedBinScoresIO.seek(@startOffsetFromFile)
    inflatedBinScoresToProcess = inflatedBinScoresIO.read()
    return inflatedBinScoresToProcess
  end


  # [+retType+] requested return type
  # [+chrom+] chromosome
  # [+blockVar+] hash with block level information
  # [+binScores+] A string with binary scores read from the binary file
  # [+numRec+] Number of records for the block
  # [+returns+] a properly formatted string depending on the requested return type
  def getBackScores(retType, chrom, blockVar, binScores, numRec)
    numRecordsProcessed = nil
    blockHeader = ""
    if(retType == "fixedStep")
      # Make block Header
      blockHeader << makeBlockHeader(chrom, blockVar['start'], retType) if(@globalArray[3] == 0 and @optionsHash['emptyScoreValue'].empty?)
      if(!@optionsHash['emptyScoreValue'].empty? and @emptyScoreValueBlockHeaderCount == 0)
        blockHeader << makeBlockHeader(chrom, @startLandmark, retType)
        @emptyScoreValueBlockHeaderCount = 1
      end
      tt = Time.now
      @getScoresAsStringObject.getRawScoresAsString(
                                                      binScores, @attributeHash['gbTrackDataSpan'], numRec, @attributeHash['gbTrackDenominator'], blockVar['blockScale'], blockVar['blockLowLimit'], @cBuffer, chrom,
                                                      [blockVar['start'], blockVar['stop']], 1, blockVar['blockSpan'], [@optionsHash['desiredSpan'], @optionsHash['spanAggFunction'], @optionsHash['posScoresOnly'],
                                                      @optionsHash['negScoresOnly'], @optionsHash['endSpan'], @stopLandmark, @optionsHash['modulusLastSpan'], @startLandmark, @optionsHash['collapsedCoverage']],
                                                      @spanMedianArray, @globalArray, @optionsHash['emptyScoreValue']
                                                    )
      @cTime += Time.now - tt
      if(@cBuffer.index("fixedStep") == 0)
        @outBuffer << @cBuffer
      else
        @outBuffer << "#{blockHeader}#{@cBuffer}"
      end
      if(@outBuffer.size >= MAX_OUT_BUFFER)
        yield @outBuffer
        @outBuffer = ""
      end
      numRecordsProcessed = @globalArray[0]
      if(numRec != numRecordsProcessed)
        while(numRec != numRecordsProcessed)
          start = blockVar['start'] + (numRecordsProcessed * blockVar['blockSpan'])
          tt = Time.now
          @getScoresAsStringObject.getRawScoresAsString(
                                                          binScores,
                                                          @attributeHash['gbTrackDataSpan'],
                                                          numRec,
                                                          @attributeHash['gbTrackDenominator'],
                                                          blockVar['blockScale'],
                                                          blockVar['blockLowLimit'],
                                                          @cBuffer,
                                                          chrom,
                                                          [start, blockVar['stop']],
                                                          1,
                                                          blockVar['blockSpan'],
                                                          [@optionsHash['desiredSpan'], @optionsHash['spanAggFunction'], @optionsHash['posScoresOnly'], @optionsHash['negScoresOnly'], @optionsHash['endSpan'], @stopLandmark, @optionsHash['modulusLastSpan'], @startLandmark, @optionsHash['collapsedCoverage']],
                                                          @spanMedianArray,
                                                          @globalArray,
                                                          @optionsHash['emptyScoreValue']
                                                        )

          numRecordsProcessed = @globalArray[0]
          @cTime += Time.now - tt
          #raise ''
          @outBuffer << @cBuffer
          if(@outBuffer.size >= MAX_OUT_BUFFER)
            yield @outBuffer
            @outBuffer = ""
          end
        end
      end
    elsif(retType == "variableStep")
      # Make block Header
      if(@varStepBlockHeaderCount == 0 and @optionsHash['emptyScoreValue'].empty?)
        yield makeBlockHeader(chrom, blockVar['start'], retType)
        @varStepBlockHeaderCount = 1
      end
      if(!@optionsHash['emptyScoreValue'].empty? and @emptyScoreValueBlockHeaderCount == 0)
        yield makeBlockHeader(chrom, @startLandmark, retType)
        @emptyScoreValueBlockHeaderCount = 1
      end
      @getScoresAsStringObject.getRawScoresAsString(
                                                      binScores, @attributeHash['gbTrackDataSpan'], numRec, @attributeHash['gbTrackDenominator'], blockVar['blockScale'], blockVar['blockLowLimit'], @cBuffer,
                                                      chrom, [blockVar['start'], blockVar['stop']], 2, blockVar['blockSpan'], [@optionsHash['desiredSpan'], @optionsHash['spanAggFunction'], @optionsHash['posScoresOnly'],
                                                      @optionsHash['negScoresOnly'], @optionsHash['endSpan'], @stopLandmark, @optionsHash['modulusLastSpan'], @startLandmark, @optionsHash['collapsedCoverage']],
                                                      @spanMedianArray, @globalArray, @optionsHash['emptyScoreValue']
                                                    )
      numRecordsProcessed = @globalArray[0]
      @outBuffer << @cBuffer
      if(@outBuffer.size >= MAX_OUT_BUFFER)
        yield @outBuffer
        @outBuffer = ""
      end
      if(numRec != numRecordsProcessed)
        while(numRec != numRecordsProcessed)
          start = blockVar['start'] + (numRecordsProcessed * blockVar['blockSpan'])
          @getScoresAsStringObject.getRawScoresAsString(
            binScores,
            @attributeHash['gbTrackDataSpan'],
            numRec,
            @attributeHash['gbTrackDenominator'],
            blockVar['blockScale'],
            blockVar['blockLowLimit'],
            @cBuffer,
            chrom,
            [start, blockVar['stop']],
            2,
            blockVar['blockSpan'],
            [@optionsHash['desiredSpan'], @optionsHash['spanAggFunction'], @optionsHash['posScoresOnly'], @optionsHash['negScoresOnly'], @optionsHash['endSpan'], @stopLandmark, @optionsHash['modulusLastSpan'], @startLandmark,
             @optionsHash['collapsedCoverage']],
            @spanMedianArray,
            @globalArray,
            @optionsHash['emptyScoreValue']
          )
          numRecordsProcessed = @globalArray[0]
          @outBuffer << @cBuffer
          if(@outBuffer.size >= MAX_OUT_BUFFER)
            yield @outBuffer
            @outBuffer = ""
          end
        end
      end
    elsif(retType == 'bed' or retType == 'gff3' or retType == 'gff' or retType == 'gtf' or
          retType == 'bedGraph' or retType == 'lff' or retType == 'psl')
      retTypeVal = nil
      if(retType == 'bed')
        retTypeVal = 1
      elsif(retType == 'bedGraph')
        retTypeVal = 2
      elsif(retType == 'lff')
        retTypeVal = 3
      elsif(retType == 'gff')
        retTypeVal = 4
      elsif(retType == 'gff3')
        retTypeVal = 5
      elsif(retType == 'gtf')
        retTypeVal = 6
      elsif(retType == 'psl')
        retTypeVal = 7
      end
      @getNonWigObject.getNonWig(
        binScores,
        @attributeHash['gbTrackDataSpan'],
        numRec,
        @attributeHash['gbTrackDenominator'],
        blockVar['blockScale'],
        blockVar['blockLowLimit'],
        @cBuffer,
        "#{chrom}:#{@trackName}",
        [blockVar['start'], blockVar['stop']],
        [@optionsHash['scaleScores'], @optionsHash['spanAggFunction'], @optionsHash['posScoresOnly'], @optionsHash['negScoresOnly'], @optionsHash['emptyScoreValue'], @optionsHash['modulusLastSpan'], @startLandmark, @stopLandmark,
         @optionsHash['collapsedCoverage']],
        @scaleFactor,
        @annosSpan,
        retTypeVal,
        @spanMedianArray,
        @globalArray
      )
      numRecordsProcessed = @globalArray[0]
      @outBuffer << @cBuffer
      if(@outBuffer.size >= MAX_OUT_BUFFER)
        yield @outBuffer
        @outBuffer = ""
      end
      if(numRec != numRecordsProcessed)
        while(numRec != numRecordsProcessed)
          start = blockVar['start'] + (numRecordsProcessed * blockVar['blockSpan'])
          @getNonWigObject.getNonWig(
            binScores,
            @attributeHash['gbTrackDataSpan'],
            numRec,
            @attributeHash['gbTrackDenominator'],
            blockVar['blockScale'],
            blockVar['blockLowLimit'],
            @cBuffer,
            "#{chrom}:#{@trackName}",
            [start, blockVar['stop']],
            [@optionsHash['scaleScores'], @optionsHash['spanAggFunction'], @optionsHash['posScoresOnly'], @optionsHash['negScoresOnly'], @optionsHash['emptyScoreValue'], @optionsHash['modulusLastSpan'], @startLandmark, @stopLandmark, @optionsHash['collapsedCoverage']],
            @scaleFactor,
            @annosSpan,
            retTypeVal,
            @spanMedianArray,
            @globalArray
          )
          numRecordsProcessed = @globalArray[0]
          @outBuffer << @cBuffer
          if(@outBuffer.size >= MAX_OUT_BUFFER)
            yield @outBuffer
            @outBuffer = ""
          end
        end
      end
    else
      raise ArgumentError, "Unknown return type: #{retType}", caller
    end
    @globalArray[0] = 0 # Set the number of records Processed to 0
  end
end

# Main Wrapper class for hdhv.rb. Wraps other modules needed for retrieving data
# from mysql records and binary files. A database name and ftypeid for the track is
# required to create an object of this class. A check is performed to see if the
# track with the ftypeid provided exists in the database provided. A connection to the
# database is established by the dbUtil object. Other required objects (for C classes)
# are also initialized. The hdhv object can then be used to call other methods

# Author: Sameer Paithankar
# == Example usage:
#
#   require 'brl/genboree/hdhv'
#   hdhvObj = BRL::Genboree::Hdhv.new('genboree_r_a9da7d23f4574131ff1b5e138e6924c1', 10)
#   scores = hdhvObj.getScoreByRid(rid = 1, start = nil, stop = nil, returnType = nil)
class Hdhv
  include BRL::Genboree::ReadHDHV
  # ############################################################################
  # INSTANCE VARIABLES
  # ############################################################################
  attr_accessor :databaseName, :ftypeId, :dbu, :trackName, :rawScores, :cBuffer, :fileHash, :byteRead, :binIO
  attr_accessor :attributeHash, :dir, :getScoresAsStringObject, :createBufferObject, :blockNum, :binReader
  attr_accessor :startOffsetFromFile, :prevOffsetInFile, :offsetInBuffer, :blockRec, :binScores, :landmarkStart
  attr_accessor :landmarkStop, :getBedObject, :getBedGraphObject, :startLandmark, :stopLandmark, :zInflater
  attr_accessor :range, :scaleFactor, :desiredSpan, :getLFFObject, :getGFFObject, :getGFF3Object, :getGTFObject
  attr_accessor :totalNumberOfRecordsToProcess, :totalNumberOfRecordsProcessed, :globalArray, :yieldLastChunkObject
  attr_accessor :spanMedianArray, :spanSum, :spanCount, :spanAvg, :spanStdDev, :spanMax, :spanMin, :spanSoq
  attr_accessor :annosSpan, :getNonWigObject , :yieldLastChunkForNonWigObject, :lastStop, :posScores, :negScores
  attr_accessor :outBuffer, :expandBuffer, :expandBlockObject, :expandBufferSize, :intersectObject, :intersectYieldObject
  attr_accessor :aggFunction
  # Instance variables for getScoreByAnnos():
  attr_accessor :varInitForGetScoreByAnnos, :tempBlockHash, :trackContHash
  attr_accessor :prevExpandBuffer, :prevExpandBufferSize, :currExpandBufferId, :prevExpandBufferId, :blockRecsSize
  # Structs:
  AvgStruct = Struct.new(:sum, :count)
  AvgByLengthStruct = Struct.new(:sum)
  MaxStruct = Struct.new(:max)
  MinStruct = Struct.new(:min)
  StdevStruct = Struct.new(:sum, :count, :soq)
  CountStruct = Struct.new(:count)
  MedianStruct = Struct.new(:string, :numRecords)
  SumStruct = Struct.new(:sum)
  # Struct Objects:
  attr_accessor :avgStructObj
  attr_accessor :avgByLengthStructObj
  attr_accessor :maxStructObj
  attr_accessor :minStructObj
  attr_accessor :stdevStructObj
  attr_accessor :countStructObj
  attr_accessor :medianStructObj
  attr_accessor :sumStructObj
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  BUFFER = 2000000 # No of bytes to be allocated for buffer (to store output string)

  # ############################################################################
  # METHODS
  # ############################################################################
  # CONSTRUCTOR. Creates an object to make use of methods for getting back hdhv data
  # Also creates objects of other required C classes
  # [+databaseName+] full databaseName of the database
  # [+ftypeId+] ftypeid of the hdhv track#
  # [+returns+]  Instance of +Hdhv+
  def initialize(databaseName, ftypeId)
    @optionsHash = OPTIONSHASH.dup
    @databaseName = databaseName
    @ftypeId = ftypeId.to_i
    @rawScores = nil
    gc = BRL::Genboree::GenboreeConfig.load
    @zInflater = Zlib::Inflate.new()
    @dbu = BRL::Genboree::DBUtil.new("#{gc.dbrcKey}", nil, nil)
    @dbu.setNewDataDb(@databaseName)
    @dbu.connectToDataDb()
    @fileHash = Hash.new
    @outBuffer = ""
    @binReader = nil
    @annosSpan = 0
    @spanMedianArray = ""
    @varInitForGetScoreByAnnos = 0
    @addLeadingEmptyScores = 0
    @varStepBlockHeaderCount = 0
    @cTime = 0
    @emptyScoreValueBlockHeaderCount = 0
    @trackContHash = {}
    initStructs()
    @globalArray = [] # this array is used by the C function to keep track of global ruby values:

    # 1) the number of records processed from the block (as the first element),
    # 2) the start coordinate of the current window (which is used by the next block to either start a new block or continue the previous block),
    # 3) the number of 'real' (non NaN) scores passed from the previous block (for the current window)
    # 4) the 'trackWindowSize' which tracks the number of bases covered for a window being processed
    # 5) 'sum' for the current window
    # 6) 'count' for the current window
    # 7) 'max' for the current window (initialized as gbTrackDataMin)
    # 8) 'min' for the current window (initialized as gbTrackDataMax)
    # 9) 'sum of squares' for the current window
    # 10) gbTrackDataMin
    # 11) gbTrackDataMax
    # 12) stop coordinate of the previous annotation
    # 13) 'addLeadingEmptyScores' - 1 or 0 (Variable to track if the leading empty score values have been added)
    # 14) 'coordTracker'
    # 15) 'spanTracker'
    # 16) 'windowStartTracker'
    @cBuffer = nil
    @totalNumberOfRecordsToProcess = @totalNumberOfRecordsProcessed = 0
    @fileHash = Hash.new
    @byteRead = 0

    # Make sure if track exists in the database
    retVal = @dbu.selectFtypesByIds([@ftypeId])
    if(retVal.empty?)
      $stderr.puts "Track with ftypeId: #{@ftypeId} does not exist in #{@databaseName}\n\n"
    else
      @trackName = "#{retVal.first['fmethod']}:#{retVal.first['fsource']}"
      @trackType = retVal.first['fmethod']
      @trackSubType = retVal.first['fsource']

      # Get all track-wide attributes
      @attributeHash = {
                          'gbTrackBpSpan' => nil,
                          'gbTrackBpStep' => nil,
                          'gbTrackScale' => nil,
                          'gbTrackLowLimit' => nil,
                          'gbTrackDenominator' => nil,
                          'gbTrackUseLog' => nil,
                          'gbTrackDataMax' => nil,
                          'gbTrackDataMin' => nil,
                          'gbTrackWindowingMethod' => nil,
                          'gbTrackRecordType' => nil,
                          'gbTrackDataSpan' => nil,
                          'gbTrackFormula' => nil
                       }
        @attributeHash.each_key { |key|
        attrName_id = @dbu.selectFtypeAttrNameByName(key)
        if(attrName_id.nil? or attrName_id.empty?)
          @attributeHash[key] = nil
        else
          value = @dbu.selectFtypeAttrValueByFtypeIdAndAttributeNameId(@ftypeId, attrName_id.first['id'])
          if(value.nil? or value.empty?)
            @attributeHash[key] = nil
          else
            @attributeHash[key] = value.first['value']
          end
        end
      }

      # Cast all track attributes appropriately
      @attributeHash['gbTrackDataSpan'] = @attributeHash['gbTrackDataSpan'].to_i
      @attributeHash['gbTrackBpSpan'] = @attributeHash['gbTrackBpSpan'].to_i
      @attributeHash['gbTrackBpStep'] = @attributeHash['gbTrackBpStep'].to_i
      @attributeHash['gbTrackScale'] = @attributeHash['gbTrackScale'].to_f if(!@attributeHash['gbTrackScale'].nil?)
      @attributeHash['gbTrackLowLimit'] = @attributeHash['gbTrackLowLimit'].to_f if(!@attributeHash['gbTrackLowLimit'].nil?)
      @attributeHash['gbTrackDenominator'] = @attributeHash['gbTrackDenominator'].to_f
      @attributeHash['gbTrackDataMax'] = @attributeHash['gbTrackDataMax'].to_f
      @attributeHash['gbTrackDataMin'] = @attributeHash['gbTrackDataMin'].to_f

      # Set @scaleFactor and @range for bed scores
      @range = @attributeHash['gbTrackDataMax'].to_f - @attributeHash['gbTrackDataMin'].to_f
      if(@range > 0)
        @scaleFactor = @range / 1000
      else
        @scaleFactor = (@attributeHash['gbTrackDataMax'].to_f > 0 ? @attributeHash['gbTrackDataMax'].to_f : 1)
      end

      # Make objects of C classes
      @getScoresAsStringObject = BRL::Genboree::C::Hdhv::GetWiggle.new()
      @getNonWigObject = BRL::Genboree::C::Hdhv::GetNonWig.new()
      @createBufferObject = BRL::Genboree::CreateBuffer.new()
      @setBufferSizeObj = BRL::Genboree::SetBufferSize.new()
      @callocObject = BRL::Genboree::CallocBuffer.new()
      @segFault = BRL::Genboree::C::Hdhv::TestSegFault.new()
      @testBinScores = BRL::Genboree::C::Hdhv::TestBinScores.new()

      # NOTE: allocating <4MB often 10x cheaper than allocation >4MB. Test alloc size times.
      @cBuffer = @createBufferObject.createBuffer(1, BUFFER) # Allocate memory for approximately a megabyte
      @origCBufferSize = @cBuffer.size
      @expandBuffer = @createBufferObject.createBuffer(2, BUFFER) # Allocate memory for expanding the zlib blocks
      @expandBufferSize = @expandBuffer.size
      @prevExpandBuffer = @createBufferObject.createBuffer(2, BUFFER) #Allocating 8_000_000 bytes of memory
      @prevExpandBufferSize = @prevExpandBuffer.size
      @yieldLastChunkObject = BRL::Genboree::C::Hdhv::YieldLastChunkForWig.new()
      @yieldLastChunkForNonWigObject = BRL::Genboree::C::Hdhv::YieldLastChunkForNonWig.new()
      @expandBlockObject = BRL::Genboree::C::Hdhv::ExpandZlibBlocks.new()
      @intersectObject = BRL::Genboree::C::Hdhv::IntersectHdhv.new()
      @intersectYieldObject = BRL::Genboree::C::Hdhv::YieldIntersectHdhv.new()
      @computeCollapsedScoresObject = BRL::Genboree::C::Hdhv::ComputeCollapsedScores.new()
      @printCollapsedScoresObject = BRL::Genboree::C::Hdhv::PrintCollapsedScores.new()

      #Get sequence directory
      @dir = @dbu.selectValueFmeta('RID_SEQUENCE_DIR')
      @dir = dir.first['fvalue']

      # Other Variables
      @varsInitialized = 0
    end
  end

  # ############################################################################
  # GENERIC METHODS
  # ############################################################################
  # Makes blockHeader depending on the 'retType'
  # [+chrom+] chromosome
  # [+start+] start coordinate of the block
  # [+retType+] type of the block header to be returned ('variableStep' or 'fixedStep')
  # [+returns+] blockHeader (A string)
  def makeBlockHeader(chrom, start, retType)
    blockHeader = nil
    if(retType == "fixedStep")
      blockHeader = "fixedStep chrom=#{chrom} start=#{start} step=#{@desiredSpan} span=#{@desiredSpan}\n"
    elsif(retType == "variableStep")
      blockHeader = "variableStep chrom=#{chrom} span=#{@desiredSpan}\n"
    end
    return blockHeader
  end

  # Initializes structs for getScoreByAnnos()
  # This will be used by 'annotationFile.rb' for updating its aggregateArray
  # [+returns+] nil
  def initStructs()
    @avgStructObj = AvgStruct.new(nil, nil)
    @avgByLengthStructObj = AvgByLengthStruct.new(nil)
    @maxStructObj = MaxStruct.new(nil)
    @minStructObj = MinStruct.new(nil)
    @countStructObj = CountStruct.new(nil)
    @stdevStructObj = StdevStruct.new(nil, nil, nil)
    @medianStructObj = MedianStruct.new("", nil)
    @sumStructObj = SumStruct.new(nil)
  end

end




# An inline Class for allocating memory using the 'malloc' function in C
# This class can be used for efficiently allocating memory for a block of
# high density data which ruby can use
# [+span+] byte span for each record
# [+blockSize+] No of records in the block
# [+returns+] An empty ruby string with size = span * blockSize
class CreateBuffer
  #Config::CONFIG['CFLAGS'] = ' -fPIC -g '
  #Config::CONFIG['CCDLFLAGS'] = ' -fPIC -g '
  #Config::CONFIG['DLDFLAGS'] = ' -g '
  #Config::CONFIG['LDSHARED'] = 'gcc -g -shared '
  #Config::CONFIG['STRIP'] = ''
  #Config::CONFIG['LDFLAGS'] = " -g #{Config::CONFIG['LDFLAGS']} "
  include BRL::C
  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base))
    builder.c <<-EOC
    /* C Function to allocate memory and return a ruby string. */
    VALUE createBuffer(int span, int blockSize)
    {
      /* Allocating memory*/
      int sizeOfBuffer = (span * blockSize) ;
      char* buff = (char *)malloc(sizeOfBuffer) ;
      /* Convert the allocated buffer into a ruby string (actually doing a copy) */
      VALUE buffer = rb_str_new(buff, sizeOfBuffer) ;
      free(buff) ; // free it from the C side
      return buffer ;
    }
    EOC
  }
end


class SetBufferSize
  include BRL::C
  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base, :glib))
    builder.c <<-EOC
    /* C Function to allocate memory and return a ruby string. */
    void setBufferSize(VALUE buffer, int size)
    {
      RSTRING_LEN(buffer) = size ;
    }
    EOC
  }
end

# An inline Class for allocating memory using the 'calloc' function in C
# This class can be used for efficiently allocating memory for a block of
# high density data which ruby can use
# [+span+] byte span for each record
# [+blockSize+] No of records in the block
# [+returns+] An empty ruby string with size = span * blockSize
class CallocBuffer
  #Config::CONFIG['CFLAGS'] = ' -fPIC -g '
  #Config::CONFIG['CCDLFLAGS'] = ' -fPIC -g '
  #Config::CONFIG['DLDFLAGS'] = ' -g '
  #Config::CONFIG['LDSHARED'] = 'gcc -g -shared '
  #Config::CONFIG['STRIP'] = ''
  #Config::CONFIG['LDFLAGS'] = " -g #{Config::CONFIG['LDFLAGS']} "
  include BRL::C
  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base))
    builder.c <<-EOC
    /* C Function to allocate memory and return a ruby string. */
    VALUE createBuffer(int span, int blockSize)
    {
      /* Allocating memory*/
      char* buff = (char *)calloc(blockSize, span) ;
      /* Convert the allocated buffer into a ruby string */
      VALUE buffer = rb_str_new(buff, blockSize * span) ;
      free(buff) ; // free it from the C side
      return buffer ;
    }
    EOC
  }
end




# An inline class for converting ruby array with scores (from wiggle file) into strings of binary scores
# This class is used by thw wig importer both for processing fixedStep and variableStep files
# Since variableStep data is converted into fixedStep and then processed, this single class is used in both cases
# [+data+] A ruby array with scores from wiggle files
# [+dataSpan+] No of bytes used to store one record (1, 2, 4, 8)
# [+cBuffer+] An empty ruby string to save the output string
# [+returns+] A ruby string of binary scores
class ReadFixedStep
  include BRL::C
  includeHeader = `pkg-config --cflags glib-2.0`
  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:glib))
    builder.include CFunctionWrapper::GLIB_HEADER_INCLUDE
    builder.c <<-EOC
      /* Compute the binary scores using wiggle formuala from UCSC for 'fixedStep' data*/
      VALUE computeFixedStep(VALUE data, int dataSpan, VALUE cBuffer, double nullScore)
      {
        int ii;
        int length = 0;
        double score, binScore;
        double checkForNull = 4290772992.0000; /* Special value to indicate nulls */
        /* Extracting info from the array with scores*/
        VALUE *dataArray = RARRAY_PTR(data);
        int dataLen = RARRAY_LEN(data);
        /* Getting pointer to prep allocated memory block */
        void *buff = RSTRING_PTR(cBuffer);
        /* Evaluate floatScore */
        if(dataSpan == 4)
        {
          gfloat* gfloatCastBuff;
          guint32* nullPointer;
          guint32 nullForFloatScore = (guint32)4290772992;
          gfloatCastBuff = (gfloat *)buff;
          nullPointer = (guint32 *)buff;
          for(ii = 0; ii < dataLen; ii++)
          {
            score = NUM2DBL(dataArray[ii]) ;
            if(score == nullScore)
            {
              *nullPointer = nullForFloatScore;
              nullPointer ++;
              gfloatCastBuff ++;
            }
            else
            {
              *gfloatCastBuff = (gfloat)score ;
              gfloatCastBuff ++;
              nullPointer ++;
            }
            length += 4;
          }
        }
        /* Evaluate doubleScore */
        else if(dataSpan == 8)
        {
          gdouble* gdoubleCastBuff;
          guint64* nullPointer64;
          guint64 nullForDoubleScore = G_GUINT64_CONSTANT(18410152326737166336) ;
          gdoubleCastBuff = (gdouble *)buff;
          nullPointer64 = (guint64 *)buff;
          for(ii = 0; ii < dataLen; ii++)
          {
            score = NUM2DBL(dataArray[ii]) ;
            if(score == nullScore)
            {
              *nullPointer64 = nullForDoubleScore;
              nullPointer64 ++;
              gdoubleCastBuff ++;
            }
            else
            {
              *gdoubleCastBuff = (gdouble)score;
              gdoubleCastBuff ++;
              nullPointer64 ++;
            }
            length += 8;
          }
        }
        RSTRING_LEN(cBuffer) = length;
        return cBuffer;
      }
      EOC
  }
end
end; end
