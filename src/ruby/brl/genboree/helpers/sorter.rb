#!/usr/bin/env ruby
# Author: Sameer Paithankar

# Load required libraries
require 'brl/util/textFileUtil'
require 'stringio'
module BRL; module Genboree; module Helpers

#############################################################################
# This class is implemented to sort file(s) of any of the Genboree supported file formats
#
# Usage:
# sorterObj = Sorter.new(fileType='fixedStep', pathToUnsortedFile)
# sorterObj.sortFile()
# fullPathToSortedFile = sorterObj.sortedFileName
#
# Notes:
#  - Assumes the file is validated.
#  - Assumes that the file is uncompressed
#  - Sorting variable step file(s) involves two steps since there are two levels of sorting required for
#   variable step files
#  - The first step is to sort the records within a block. This step may or may not be required.
#  - The second step is similar to sorting of fixed step files. This involves sorting blocks relative to each other, i.e,
#  the blocks are arranged in increasing order of their start coordinates. In order for the second step to be successful, it is
#  vital that the records within each block of a variable step file are sorted.
#############################################################################
class Sorter

  # ############################################################################
  # CONSTANTS
  # ############################################################################
  VARIABLESTEPRECORDS = "variableStepRecords"
  VARIABLESTEP = "variableStep"
  FIXEDSTEP = "fixedStep"
  BUFFERSIZE = 32000000
  SORTEDTABDELIMITEDFILE = "sortedTabDelimitedFile.txt"
  UNSORTEDTABDELIMITEDFILE = "unsortedTabDelimitedFile.txt"
  MAXIMUMOUTPUTBUFFER = 5000000
  SORTEDBLOCKS = "sortedBlocks.txt" # A file for writing sorted variable step blocks (the records within the blocks are sorted). This file is re-written for each block
  # A hash to indicate the file formats supported by Genboree
  FILETYPEHASH = {
    FIXEDSTEP => nil,
    VARIABLESTEP => nil,
    VARIABLESTEPRECORDS => nil
  }
  # ############################################################################
  # VARIABLES
  # ############################################################################
  attr_accessor :fileHandler, :fileType, :fileName, :dirToUse
  attr_accessor :chrHash, :sortedFile
  # ############################################################################
  # METHODS
  # ############################################################################
  # Constructor
  # To make an object of the sorter class, two parameters are required:
  # 1) the fileType
  # 2) the full path to the file to be sorted
  # [+returns+] nil
  def initialize(fileType, pathToUnsortedFile)
    @fileType = fileType
    @fileName = pathToUnsortedFile
    # Make sure the file exists
    raise ArgumentError, "File: #{@fileName} does not exist.", caller if(!File.exists?(@fileName))
    # Make sure the file type is supported
    displayErrorMsgAndExit("Unsupported file format: #{fileType}") if(!FILETYPEHASH.has_key?(fileType))
    # Okay. Since we are done with error checking. We can proceed...
    # Make file handler first
    @fileHandler = BRL::Util::TextReader.new(@fileName)
    @dirToUse = File.dirname(@fileName)
    @sortedFile = "#{@dirToUse}/sorted_#{Time.now().to_f}_#{File.basename(@fileName)}"
    @chrHash = Hash.new
  end

  # Calls the appropriate method for sorting
  # [+returns+] nil
  def sortFile()
    if(@fileType == FIXEDSTEP)
      sortFixedStepBlocks()
    elsif(@fileType == VARIABLESTEP)
      sortVariableStepBlocks()
    elsif(@fileType == VARIABLESTEPRECORDS)
      sortVariableStepRecordsInBlocks()
    end
  end

  # Sorts fixedStep wiggle file
  # The initial file will be tab delimited : startCoordinate\tchr\toffset\tbytesForBlock which is sorted by unix sort
  # The sorted tab delimited file is later used by the method to create a sorted replica of the original unsorted fixed step file
  # [+returns+] nil
  def sortFixedStepBlocks()
    # Make fileHandler for the initial unsorted tab delimited file
    unsortedTabDelimitedFile = "#{@dirToUse}/#{Time.now().to_f}_#{UNSORTEDTABDELIMITEDFILE}"
    unsortedTabDelimitedFileWriter = BRL::Util::TextWriter.new(unsortedTabDelimitedFile)
    # Initialize all required variables
    fileOffset = 0
    bufferRead = 0
    orphan = nil
    buffer = nil
    writeBuffer = ""
    previousOffset = nil
    # Read until end of file
    while(!@fileHandler.eof?)
      # Read file in chunks
      # Going through a file in memory is much faster than doing too may disk IO operations
      buffer = @fileHandler.read(BUFFERSIZE)
      bufferRead += BUFFERSIZE
      buffIO = StringIO.new(buffer)
      buffIO.each_line { |line|
        line = orphan + line if(!orphan.nil?)
        orphan = nil
        if(line =~ /\n$/)
          line.strip!
          # Process the line if the line is a block header
          if(line =~ /^fixedStep/)
            chr = nil
            start = nil
            data = line.split(/\s+/)
            data.each { |attr|
              avp = attr.split("=")
              chr = avp[1] if(avp[0] == 'chrom')
              start = avp[1].to_i if(avp[0] == 'start')
            }
            # Add chromosome to @chrHash. This will be later used when using unix sort
            @chrHash[chr] = nil if(!@chrHash.has_key?(chr))
            if(previousOffset.nil?)
              writeBuffer << "#{start}\t#{chr}\t#{fileOffset}\t"
            else
              blockSize = fileOffset - previousOffset # Get the size of the block in bytes
              writeBuffer << "#{blockSize}\n#{start}\t#{chr}\t#{fileOffset}\t"
            end
            previousOffset = fileOffset
          end
          fileOffset = bufferRead - (BUFFERSIZE - buffIO.pos())
        else
          orphan = line
        end
        # Write to file if it reaches
        if(writeBuffer.size >= MAXIMUMOUTPUTBUFFER)
          unsortedTabDelimitedFileWriter.print(writeBuffer)
          writeBuffer = ""
        end
      }
    end
    blockSize = fileOffset - previousOffset
    writeBuffer << "#{blockSize}\n"
    unsortedTabDelimitedFileWriter.print(writeBuffer)
    unsortedTabDelimitedFileWriter.close()
    # Now call the unix sort command and sort the unsorted tab delimited file by the first column (coordinate)
    sortedTabDelimitedFile = "#{@dirToUse}/#{Time.now().to_f}_#{SORTEDTABDELIMITEDFILE}"
    @chrHash.each_key{ |chr|
      # grep with Perl style reg expressions.
      # First take out all the block headers once chromosome at a time.
      # cut the required columns and sort numerically by the first column
      # Direct the output to a file
      system("grep -P '#{chr}\t' #{unsortedTabDelimitedFile} | cut -f 1,2,3,4 | sort -n >> #{sortedTabDelimitedFile}")
    }
    # Now go through the sorted tab delimited file and write out a sorted version of the original unsorted file
    sortedTabDelimitedFileReader = BRL::Util::TextReader.new("#{sortedTabDelimitedFile}")
    # Make writer for the sorted version of the original unsorted file
    sortedVersionOfOriginalFileWriter = BRL::Util::TextWriter.new("#{@sortedFile}")
    # Write out the final sorted wiggle file
    writeSortedWiggleFile(sortedTabDelimitedFileReader, sortedVersionOfOriginalFileWriter)
    sortedVersionOfOriginalFileWriter.close()
    sortedTabDelimitedFileReader.close()
    # Remove the sorted and the unsorted tab delimited files
    system("rm #{sortedTabDelimitedFile} #{unsortedTabDelimitedFile}")
  end

  # Sort records within each block of a variable step file
  # Calling this method first is essential before calling sortVariableStepBlocks()
  # if the records inside blocks are not sorted
  # [+returns+] nil
  def sortVariableStepRecordsInBlocks()
    orphan = nil
    blockCount = 0
    blockBuffer = ""
    @fileHandler.rewind()
    fileWithSortedRecordsForEachBlock = "#{@dirToUse}/#{Time.now().to_f}_#{SORTEDBLOCKS}"
    fileWithSortedRecordsForEachBlockWriter = BRL::Util::TextWriter.new(fileWithSortedRecordsForEachBlock)
    while(!@fileHandler.eof?)
      buffer = @fileHandler.read(BUFFERSIZE)
      buffIO = StringIO.new(buffer)
      buffIO.each_line { |line|
        line = orphan + line if(!orphan.nil?)
        orphan = nil
        # Check if line is complete (has new line character)
        if(line =~ /\n$/)
          line.strip!
          if(line =~ /^variableStep/)
            # skip for first block
            if(blockCount > 0)
              fileWithSortedRecordsForEachBlockWriter.print(blockBuffer)
              fileWithSortedRecordsForEachBlockWriter.close()
              # Sort using unix 'sort'
              system("cut -d '\s' -f 1,2 #{fileWithSortedRecordsForEachBlock} | sort -n >> #{@sortedFile}")
              fileWithSortedRecordsForEachBlockWriter = BRL::Util::TextWriter.new(fileWithSortedRecordsForEachBlock)
              blockBuffer = ""
            end
            # Write block header to what is going to be the sorted version of the file
            system("echo '#{line}' >> #{@sortedFile}")
            blockCount += 1
          elsif(line =~ /^(?:(\+|\-)?\d+)\s+(?:(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?)$/i) # This regular expression matches the variable step record line
            blockBuffer << "#{line}\n"
          end
          # print to file if blockBuffer is large enough
          if(blockBuffer.size >= MAXIMUMOUTPUTBUFFER)
            fileWithSortedRecordsForEachBlockWriter.print(blockBuffer)
            blockBuffer = ""
          end
        # save line as orphan
        else
          orphan = line
        end
      }
    end
    fileWithSortedRecordsForEachBlockWriter.print(blockBuffer)
    fileWithSortedRecordsForEachBlockWriter.close()
    # Sort using unix 'sort'
    system("cut -f 1,2 #{fileWithSortedRecordsForEachBlock} | sort -d >> #{@sortedFile}")
    system("rm #{fileWithSortedRecordsForEachBlock}")
    blockBuffer = ""
  end

  # Sorts variableStep blocks in a wiggle file
  # The initial file will be tab delimited : startCoordinate\tchr\toffset\tbytesForBlock which is sorted by unix sort
  # The sorted tab delimited file is later used by the method to create a sorted replica of the original unsorted variable step file
  # Only run if sure that the records within a block are sorted
  # [+returns+] nil
  def sortVariableStepBlocks()
    # Make fileHandler for the initial unsorted tab delimited file
    unsortedTabDelimitedFile = "#{@dirToUse}/#{Time.now().to_f}_#{UNSORTEDTABDELIMITEDFILE}"
    unsortedTabDelimitedFileWriter = BRL::Util::TextWriter.new(unsortedTabDelimitedFile)
    fileOffset = 0
    bufferRead = 0
    orphan = nil
    startCoord = nil
    writeBuffer = ""
    previousOffset = nil
    tempOffset = nil
    blockHeader = nil
    while(!@fileHandler.eof?)
      buffer = @fileHandler.read(BUFFERSIZE)
      bufferRead += BUFFERSIZE
      buffIO = StringIO.new(buffer)
      buffIO.each_line { |line|
        line = orphan + line if(!orphan.nil?)
        orphan = nil
        if(line =~ /\n$/)
          line.strip!
          if(line =~ /^variableStep/)
            chr = nil
            data = line.split(/\s+/)
            data.each { |attr|
              avp = attr.split("=")
              chr = avp[1] if(avp[0] == "chrom")
            }
            # Add chromosome to @chrHash. This will be later used when using unix sort
            @chrHash[chr] = nil if(!@chrHash.has_key?(chr))
            blockHeader = "#{chr}\t#{fileOffset}\t"
            tempOffset = fileOffset
            startCoord = nil
          elsif(line =~ /^(?:(\+|\-)?\d+)\s+(?:(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?)$/i) # This regular expression matches the variable step record line
            if(startCoord.nil?)
              data = line.split(/\s+/)
              startCoord = data[0].to_i
              if(previousOffset.nil?)
                writeBuffer << "#{startCoord}\t#{blockHeader}"
              else
                blockSize = tempOffset - previousOffset
                writeBuffer << "#{blockSize}\n#{startCoord}\t#{blockHeader}"
              end
              previousOffset = tempOffset
            end
          end
          fileOffset = bufferRead - (BUFFERSIZE - buffIO.pos())
        else
          orphan = line
        end
        if(writeBuffer.size >= MAXIMUMOUTPUTBUFFER)
          unsortedTabDelimitedFileWriter.print(writeBuffer)
          writeBuffer = ""
        end
      }
    end
    blockSize = fileOffset - previousOffset
    writeBuffer << "#{blockSize}\n"
    unsortedTabDelimitedFileWriter.print(writeBuffer)
    unsortedTabDelimitedFileWriter.close()
    sortedTabDelimitedFile = "#{@dirToUse}/#{Time.now().to_f}_#{SORTEDTABDELIMITEDFILE}"
    # Now call the unix sort command and sort the unsorted tab delimited file by the first column (coordinate)
    @chrHash.each_key{ |chr|
      # grep with Perl style reg expressions.
      # First take out all the block headers once chromosome at a time.
      # cut the required columns and sort numerically by the first column
      # Direct the output to a file
      system("grep -P '#{chr}\t' #{unsortedTabDelimitedFile} | cut -f 1,2,3,4 | sort -n >> #{sortedTabDelimitedFile}")
    }
    # Now go through the sorted tab delimited file and write out a sorted version of the original unsorted file
    sortedTabDelimitedFileReader = BRL::Util::TextReader.new(sortedTabDelimitedFile)
    # Make writer for the sorted version of the original unsorted file
    sortedVersionOfOriginalFileWriter = BRL::Util::TextWriter.new("#{@sortedFile}")
    # Write out the final sorted wiggle file
    writeSortedWiggleFile(sortedTabDelimitedFileReader, sortedVersionOfOriginalFileWriter)
    sortedVersionOfOriginalFileWriter.close()
    sortedTabDelimitedFileReader.close()
    # remove the sorted and the unsorted tab delimited files
    system("rm #{sortedTabDelimitedFile} #{unsortedTabDelimitedFile}")
  end

  # returns the full path of the sorted file
  # [+returns+] sortedFileName (full path of the sorted file)
  def sortedFileName
    return @sortedFile
  end

  # Writes the entire wiggle (sorted) using the sorted tab delimited file reader
  # Based on my research, the algorithm implemented in this method is the most efficient for our needs
  # It is suited for both cases:
  # 1) Large but few blocks
  # 2) small but numerous blocks
  # [+sortedTabDelimitedFileReader+] reader for the sorted tab delimited file
  # [+sortedVersionOfOriginalFileWriter+] writer for the final sorted wiggle file
  def writeSortedWiggleFile(sortedTabDelimitedFileReader, sortedVersionOfOriginalFileWriter)
    orphan = nil
    while(!sortedTabDelimitedFileReader.eof?)
      tabDelimitedFileBuffer = sortedTabDelimitedFileReader.read(BUFFERSIZE)
      tabDelimitedFileBufferIO = StringIO.new(tabDelimitedFileBuffer)
      tabDelimitedFileBufferIO.each_line { |tabDelimitedFileLine|
        tabDelimitedFileLine = orphan + tabDelimitedFileLine if(!orphan.nil?) # Add orphan line from previous buffer, if required
        orphan = nil
        if(tabDelimitedFileLine =~ /\n$/)
          tabDelimitedFileLine.strip!
          tabDelimitedData = tabDelimitedFileLine.split(/\t/)
          blockSizeInBytes = tabDelimitedData[3].to_i
          fileOffset = tabDelimitedData[2].to_i
          @fileHandler.rewind()
          # Seek to the offset in the file
          # If size of block is larger than BUFFERSIZE, keep on reading BUFFERSIZE amount of bytes from the block until the block is written
          # else write out the block in one shot
          @fileHandler.seek(fileOffset)
          if(blockSizeInBytes <= BUFFERSIZE)
            fileBuffer = @fileHandler.read(blockSizeInBytes)
            sortedVersionOfOriginalFileWriter.print(fileBuffer)
          else
            bytesProcessed = 0
            bytesToProcess = BUFFERSIZE
            while(!(bytesProcessed >= blockSizeInBytes))
              fileBuffer = @fileHandler.read(bytesToProcess)
              bytesProcessed += fileBuffer.size
              if(blockSizeInBytes - bytesProcessed > BUFFERSIZE)
                bytesToProcess = BUFFERSIZE
              else
                bytesToProcess = blockSizeInBytes - bytesProcessed
              end
              sortedVersionOfOriginalFileWriter.print(fileBuffer)
            end
          end
        else
          orphan = tabDelimitedFileLine
        end
      }
    end
  end

  # Displays error message and quits
  # [+msg+]  error message
  #  [+returns+] nil
  def displayErrorMsgAndExit(msg)
    msg = "Errors:\n" + msg.to_s
    $stderr.puts msg
    exit(14)
  end

end
end; end; end
