#!/usr/bin/env ruby
# Turn on extra warnings and such

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
$VERBOSE = nil
require 'zlib'
HAVE_BZ2 =  begin
              require 'bz2'
              true
            rescue LoadError => lerr
              false
            end
require 'delegate'
require 'brl/util/util'
# ##############################################################################

module BRL ; module Util

	class TextReader < SimpleDelegator
		include BRL::Util
		def initialize(fileStr)
			# First, make sure we have a string obj and that the file indicated
			# exists and is readable
			unless(fileStr.kind_of?(String))
				raise(TypeError, "The file to read from must be provided as a String.")
			end
			unless(FileTest.exists?(fileStr))
				raise(IOError, "The file '#{fileStr}' doesn't exist.")
			end
			unless(FileTest.readable?(fileStr))
				raise(IOError, "The file '#{fileStr}' isn't readable.")
			end
			# Ok, figure out if we've got a gzip file or plain text file (default)
			# Once we know, use an appropriate IO delegate.
			if(Gzip.isGzippedFile?(fileStr))
				@ioObj = Zlib::GzipReader.open(fileStr)
			elsif(HAVE_BZ2 and Bzip2.isBzippedFile?(fileStr))
				@ioObj = BZ2::Reader.open(fileStr)
			else
				@ioObj = File.open(fileStr, "r")
			end
			super(@ioObj)
		end

	end # class TextReader

	class TextWriter < SimpleDelegator
		include BRL::Util
		
		GZIP_OUT, BZIP_OUT, TEXT_OUT = 0,1,2
		
		def initialize(fileStr, modeStr="w+", outputType=false)
			# First, make sure we have a string obj and that the file indicated
			# is writable
			unless(fileStr.kind_of?(String))
				raise(TypeError, "The file to write to must be provided as a String.")
			end
			if(FileTest.exists?(fileStr) and !FileTest.writable?(fileStr))
				raise(IOError, "The file '#{fileStr}' exists but isn't writable.")
			end
			# Ok, figure out if we've got a gzip file or plain text file (default)
			# Once we know, use an appropriate IO delegate.
			file = File.open(fileStr, modeStr)
			# Figure out how to zip output if asked for

			if((outputType == true) or (outputType == GZIP_OUT) or (outputType =~ /gzip/i))	# Back-compatible: true [*specifically*, not just if(outputType)] means do GZIP
				@ioObj = Zlib::GzipWriter.new(file)
			elsif(HAVE_BZ2 and ((outputType == BZIP_OUT) or (outputType =~ /bzip/i)))
				@ioObj = BZ2::Writer.new(file)
			else
				@ioObj = file
			end
			super(@ioObj)
		end
	end # class TextWriter

  class TextFileIndexer
    RECORD_SAMPLES = 10

    def self.createIndexFile(dataFilePath, indexFilePath, debug=false)
      # We build our index file by creating indices every sqrt(n), where n = number of rows. 
      # The offset for each index is kept for fast seeking when we are searching for a row,
      # along with the number of non-data rows present before the line
      # Format: <line number>,<file seek offset>,<non-data rows <= curr. line>
      # NOTE: Subindices (like a parse skip list) are not used because we will never keep the 
      #     : indices in memory (since there is no session handling from request to request)
      debugTimeStart = Time.now()
      $stderr.puts("[TextFileIndexer] #{debugTimeStart}] Creating index file: #{indexFilePath}")

      # Our index for this file does not exist, we have to create it
      count = 0
      binSize = 0
      totRecLength = 0
      totalRecords = -1
      dataFile = File.open(dataFilePath)
      fileIdx = File.new(indexFilePath, 'w+')

      # We estimate the number of indices (bins) needed by sampling the first 10 rows of data and dividing by the file size
      # NOTE: This can easily give us an overestimation for widely varied data
      while(count < RECORD_SAMPLES)
        begin
          line = dataFile.readline()
          next if(line.match(%r{^\s*(#.*|$)$}))

          totRecLength += line.length()
          count += 1
        rescue EOFError
          # Do nothing, we are finished
          break
        end
      end
      dataFile.rewind()

      # No records, so we exit (either legit or most likely error, either way, we can't return data)
      unless(totRecLength == 0)
        binSize = Math.sqrt((dataFile.stat().size() / (totRecLength / RECORD_SAMPLES))).floor()

        # Iterate over the file, not estimate records since it is not guaranteed to be accurrate
        lineNo = 0
        totalRecords = 0
        nonDataRecords = 0
        fileIdx.puts("0,0,0")
        dataFile.each_line() { |line|
          lineNo += 1

          # Check if we are a data row or not (either empty or comment)
          if(line.match(%r{^\s*(#.*|$)$}))
            nonDataRecords += 1
          else
            totalRecords += 1
          end

          if((lineNo % binSize) == 0)
            # We have a bin, so write our line number and file offset
            fileIdx.puts("#{lineNo},#{dataFile.pos},#{nonDataRecords}")
          end
        }

        # Because there could be a discrepancy between bins and actual file size, write our last lineNo and file pos
        fileIdx.puts("#{lineNo},#{dataFile.pos},#{nonDataRecords}")
        fileIdx.flush()
        debugTimeStop = Time.now()
        $stderr.puts("[TextFileIndexer: #{Time.now()}] Index file created: [lineNo: #{lineNo}]")

        # Make sure we close our file handles
        dataFile.close()
        fileIdx.close()
      end

      if(debug)
        # Total number of data records, data file size, index file creation time, index file size
        return [totalRecords, File.stat(dataFilePath).size(), (debugTimeStop - debugTimeStart), File.stat(indexFilePath).size()]
      end
    
      return totalRecords
    end

    def self.seekDataFileToIndex(reqLine, file, fileIdx)
      # Find our file offset for the desired record (line number):
      # Our index file is ordered, so if the line number of the current index line is > requested line, 
      # our index line is the prev line. Note we have to take the nonrecord lines into consideration
      # as to not return non record (comment) lines
      prevLine = ''
      recFound = false
      while(!recFound)
        begin
          currLine = fileIdx.readline()
          lineNo, offset, nonRecs = currLine.split(',').map { |val| val.to_i }
          lineNo += nonRecs

          if(reqLine > lineNo)
            prevLine = currLine
          elsif(reqLine < lineNo)
            # Our reqLine is now less than the line number, so our desired index is the previous
            recLine, recOffset, recSkips = prevLine.split(',').map { |val| val.to_i }

            # Now seek to the correct spot
            file.seek(recOffset)
            1.upto((reqLine + recSkips) - recLine) { |num|
              file.readline()
            }

            recFound = true
          else
            # Right on our index - seek right to the offset
            file.seek(offset)
            recFound = true
          end
        rescue EOFError
          return false
        end
      end

      return true
    end

    def self.readRecords(start, limit, dataFile, indexFile, debug=false)
      readLines = 0
      records = Array.new()
      
      # Ensure we have file handles
			unless(dataFile.kind_of?(File) and indexFile.kind_of?(File))
				raise(TypeError, "The data and index file must be of type File")
			end
     
      # Seek to the appropriate index
      debugTimeStart = Time.now()
      seekResult = self.seekDataFileToIndex(start, dataFile, indexFile)
      
      # Our file pointer should be at the right position, now construct our data to return
      if(seekResult)
        while(readLines <= limit)
          begin
            line = dataFile.readline()
            unless(line.match(%r{^\s*(#.*|$)$}))
              # Only send back the data for the grid, comment lines will be hidden in the UI
              readLines += 1
              records << line.split("\t").map { |val| val.chomp }
            end
          rescue EOFError
            # We hit the end of the file, no more to read
            break
          end
        end
      else
        $stderr.puts("[TextFileIndexer] Could not seek to the desired index in the data file (#{datFile.path()}), exiting...")
      end
      debugTimeStop = Time.now()

      if(debug)
        return [records, (debugTimeStop - debugTimeStart)]
      end

      return records
    end
  end # class TextFileIndexer
end ; end # module BRL ; module Util

	# ##############################################################################
	# TEST DRIVER (run this file on its own)
	# ##############################################################################
if(__FILE__ == $0)
	module TestTextFileUtil
		require 'getoptlong'

		def TestTextFileUtil.processArguments
			progOpts =
				GetoptLong.new(
					['--fileToRead', '-i', GetoptLong::REQUIRED_ARGUMENT],
					['--fileToWrite', '-o', GetoptLong::REQUIRED_ARGUMENT],
					['--writeZip', '-z', GetoptLong::NO_ARGUMENT],
					['--help', '-h', GetoptLong::NO_ARGUMENT]
				)

			optsHash = progOpts.to_hash
			return optsHash
		end

		def TestTextFileUtil.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "

	PROGRAM DESCRIPTION:

	COMMAND LINE ARGUMENTS:
	  -i		=> Location of the input file (plain or gzipped text)
	  -o    => Location of output file
	  -z    => [optional flag; default is no] Should output file be gzipped text?

	USAGE:
		textFileUtil.rb -i ./myTestFile.txt.maybeGZ.maybeNot -o ./myTestOutput.gz

	";
			exit(2);
		end # TestTextFileUtil.usage(msg='')
	end # module TestTextFileUtil

	optsHash = TestTextFileUtil.processArguments()  
	if(optsHash.key?('--help') or optsHash.empty?())
		TestTextFileUtil.usage()
	end

	reader = BRL::Util::TextReader.new(optsHash['--fileToRead'])
	writer = BRL::Util::TextWriter.new(optsHash['--fileToWrite'], optsHash.key?('--writeZip'))
	
	writer.write("OUTPUT OF TextReader & TextWriter TEST DIRVER in textFileUtil.rb\n")

	reader.each {
		|line|
		writer.write(line)
	}

	reader.close()
	writer.close()
end # if(__FILE__ == $0)
