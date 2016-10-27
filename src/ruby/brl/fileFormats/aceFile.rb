#!/usr/bin/env ruby

=begin
=end
# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class

module BRL ; module FileFormats

class AceFileIndexRecord
	attr_accessor :contigID, :recOffset, :recLength, :aceFileName
	attr_accessor :deflineLength
	attr_accessor :seqOffset, :seqLength
	attr_accessor :bqOffset, :bqLength
	attr_accessor :afListOffset, :afListLength
	attr_accessor :bsListOffset, :bsListLength
	attr_accessor :rdListOffset, :rdListLength

	def initialize(contigID, fileName, recOffset, recLength)
		@contigID, @aceFileName, @recOffset, @recLength = contigID, fileName, recOffset, recLength
	end

	def AceFileIndexRecord.from_s(recStr)
		recStr = recStr.strip!
		return nil if(recStr.empty?)
		fields = recStr.split("\t")
		newRec = BRL::FileFormats::AceFileIndexRecord.new(
				fields[0], fields[1],
				(fields[2].nil? ? nil : fields[2].to_i),
				(fields[3].nil? ? nil : fields[3].to_i))
		newRec.deflineLength = (fields[4] == 'nil' ? nil : fields[4].to_i)
		newRec.deflineLength = (fields[5] == 'nil' ? nil : fields[5].to_i)
		newRec.seqOffset = (fields[6] == 'nil' ? nil : fields[6].to_i)
		newRec.seqLength = (fields[7] == 'nil' ? nil : fields[7].to_i)
		newRec.bqOffset = (fields[8] == 'nil' ? nil : fields[8].to_i)
		newRec.bqLength = (fields[9] == 'nil' ? nil : fields[9].to_i)
		newRec.afListOffset = (fields[10] == 'nil' ? nil : fields[10].to_i)
		newRec.afListLength = (fields[11] == 'nil' ? nil : fields[11].to_i)
		newRec.bsListOffset = (fields[12] == 'nil' ? nil : fields[12].to_i)
		newRec.bsListLength = (fields[13] == 'nil' ? nil : fields[13].to_i)
		newRec.rdListOffset = (fields[14] == 'nil' ? nil : fields[14].to_i)
		return newRec
	end

	def to_s()
		fields =	[
								@contigID, @aceFileName, @recOffset, @recLength,
								@deflineLength,
								@seqOffset, @seqLength,
								@bqOffset, @bqLength,
								@afListOffset, @afListLength,
								@bsListOffset, @bsListLength,
								@rdListOffset, @rdListLength
							]
		fields.each_index {
			|ii|
			if(fields[ii].nil?)
				fields[ii] =  'nil'
			else
				fields[ii] = fields[ii].to_s
			end
		}
		return fields.join("\t")
	end

	alias :deflineOffset :recOffset
end

class AceFileIndexer
	IDX_SUFFIX = '.ace.idx'
	START, CO, SEQ, BQ, AF, BS, RD, REST = 0,2,4,8,16,32,64,128
	BLANK_RE = /^\s*$/
	COMMENT_RE = /^\s*#/
	AS_RE = /^AS\s+/
	BQ_RE = /^BQ/
	AF_RE = /^AF/
	BS_RE = /^BS/
	RD_RE = /^RD/
	WA_RE = /^WA\{/

	attr_accessor :contigIndices, :numContigs, :currRecordIdx, :aceFileName
	attr_accessor :isNewAceFormat, :aceFileReader
	attr_accessor :sortedContigIDs, :currIteratorIdx

	def initialize()
		@contigIndices = {}
		@sortedContigIDs = []
		@currIteratorIdx = 0
		@numContigs = 0
		@currRecordIdx = nil
		@aceFileName = nil
		@aceFileReader = nil
	end

	def indexFile(aceFileName)
		@aceFileName = File.expand_path(aceFileName)
		aceFile = BRL::Util::TextReader.new(aceFileName)
		contigIndexRecords = []
		firstLine = aceFile.readline()
		if(firstLine =~ AS_RE)
			@isNewAceFormat = true
		else
			raise "ERROR: The old ace file format is obsolete and not supported. Run phrap with option to generate new ace file format."
		end
#		wholeFile = aceFile.read
		contigRS = @isNewAceFormat ? 'CO Contig' : 'DNA Contig'
		contigRsRE = /^\s*#{contigRS}(\d+)/
		currContigIdx = nil
		parseState = START
		aceFile.each { |line|
			next if(line =~ BLANK_RE or line =~ COMMENT_RE)
			if((parseState == START or parseState == REST or parseState == RD) and (line =~ contigRsRE or aceFile.eof?))
				if(parseState == RD) # then didn't notice end of previous contig rec and either on new rec or at end-of-file
					currContigIdx.rdListLength = (aceFile.pos - currContigIdx.rdListOffset) - line.length
					parseState = CO
				end
				if(!currContigIdx.nil? and parseState == CO) # then save the one we were working on
					currContigIdx.recLength = aceFile.pos - currContigIdx.recOffset
					@contigIndices[currContigIdx.contigID] = currContigIdx
				end
				unless(aceFile.eof?)
					contigID = $1
					if(@contigIndices.key?(contigID))
						raise "ERROR: problem reading ace file-->the Contig numbering is messed up. There is more than one Contig#{currContigIdx.contigID}."
					end
					currContigIdx = AceFileIndexRecord.new(contigID, @aceFileName, (aceFile.pos - line.length), line.length)
					currContigIdx.deflineLength = line.length
					currContigIdx.seqOffset = aceFile.pos
					parseState = SEQ
				end
			elsif(parseState == SEQ)
				if(line =~ BQ_RE)
					currContigIdx.seqLength = (aceFile.pos - currContigIdx.seqOffset) - line.length
					currContigIdx.bqOffset = aceFile.pos
					parseState = BQ
				end
			elsif(parseState == BQ)
				if(line =~ AF_RE)
					currContigIdx.bqLength = (aceFile.pos - currContigIdx.bqOffset) - line.length
					currContigIdx.afListOffset = aceFile.pos - line.length
					parseState = AF
				end
			elsif(parseState == AF)
				if(line =~ BS_RE)
					currContigIdx.afListLength = (aceFile.pos - currContigIdx.afListOffset) - line.length
					currContigIdx.bsListOffset = aceFile.pos - line.length
					parseState = BS
				end
			elsif(parseState == BS)
				if(line =~ RD_RE)
					currContigIdx.bsListLength = (aceFile.pos - currContigIdx.bsListOffset) - line.length
					currContigIdx.rdListOffset = aceFile.pos - line.length
					parseState = RD
				end
			elsif(parseState == RD)
				if(line =~ WA_RE)
					currContigIdx.rdListLength = (aceFile.pos - currContigIdx.rdListOffset) - line.length
					parseState = REST
				end
			end
		}
		# at end of file. Do clean up of last contig.
		currContigIdx.recLength = aceFile.pos - currContigIdx.recOffset
		if(parseState == RD) # then didn't notice end of previous contig rec and either on new rec or at end-of-file
			currContigIdx.rdListLength = (aceFile.pos - currContigIdx.rdListOffset) - line.length
			parseState = CO
		end
		@contigIndices[currContigIdx.contigID] = currContigIdx
		aceFile.close()
		@sortedContigIDs = @contigIndices.keys.sort { |aa,bb| aa <=> bb }
		return
	end

	def saveIndex(indexFileName, doGzip=true)
		writer = BRL::Util::TextWriter.new(indexFileName, 'w+', doGzip)
		@contigIndices.each { |contigID, rec|
			writer.puts rec.to_s
		}
		writer.close()
		return
	end

	def loadIndex(aceIndexFileName, aceFileName=nil)
		reader = BRL::Util::TextReader.new(aceIndexFileName)
		reader.each { |line|
			idxRec = AceFileIndexRecord.from_s(line)
			if(@contigIndices.key?(idxRec.contigID))
				raise "ERROR: There are multiple indices for Contig#{idxRec.contigID}. Each contigID must have a unique index. File corrupt."
			end
			@contigIndices[idxRec.contigID] = idxRec
		}
		reader.close()

		return
	end

	def nextContigID()
		return nil if(@contigIndices.empty? or @sortedContigIDs.empty?)
		retVal = @sortedContigIDs[@currIteratorIdx]
		@currIteratorIdx += 1
		return retVal
	end

	def resetIterator()
		@currIteratorIdx = 0
		return 0
	end

	def getFullRecordStr(contigID)
		contigID = contigID.to_s unless(contigID.kind_of?(String))
		return nil if(@contigIndices.nil? or @contigIndices.empty? or !@contigIndices.key?(contigID))
		idxRec = @contigIndices[contigID]
		return self.getRawContigData(idxRec.aceFileName, idxRec.recOffset, idxRec.recLength).strip
	end

	def getDefline(contigID)
		contigID = contigID.to_s unless(contigID.kind_of?(String))
		return nil if(@contigIndices.nil? or @contigIndices.empty? or !@contigIndices.key?(contigID))
		idxRec = @contigIndices[contigID]
		return self.getRawContigData(idxRec.aceFileName, idxRec.recOffset, idxRec.deflineLength).strip
	end

	def getContigSequence(contigID)
		contigID = contigID.to_s unless(contigID.kind_of?(String))
		return nil if(@contigIndices.nil? or @contigIndices.empty? or !@contigIndices.key?(contigID))
		idxRec = @contigIndices[contigID]
		return self.getRawContigData(idxRec.aceFileName, idxRec.seqOffset, idxRec.seqLength).strip
	end

	def getContigQualities(contigID)
		contigID = contigID.to_s unless(contigID.kind_of?(String))
		return nil if(@contigIndices.nil? or @contigIndices.empty? or !@contigIndices.key?(contigID))
		idxRec = @contigIndices[contigID]
		return self.getRawContigData(idxRec.aceFileName, idxRec.bqOffset, idxRec.bqLength).strip
	end

	def getAFListStr(contigID)
		contigID = contigID.to_s unless(contigID.kind_of?(String))
		return nil if(@contigIndices.nil? or @contigIndices.empty? or !@contigIndices.key?(contigID))
		idxRec = @contigIndices[contigID]
		return self.getRawContigData(idxRec.aceFileName, idxRec.afListOffset, idxRec.afListLength).strip
	end

	def getBSListStr(contigID)
		contigID = contigID.to_s unless(contigID.kind_of?(String))
		return nil if(@contigIndices.nil? or @contigIndices.empty? or !@contigIndices.key?(contigID))
		idxRec = @contigIndices[contigID]
		return self.getRawContigData(idxRec.aceFileName, idxRec.bsListOffset, idxRec.bsListLength).strip
	end

	def getRDListStr(contigID)
		contigID = contigID.to_s unless(contigID.kind_of?(String))
		return nil if(@contigIndices.nil? or @contigIndices.empty? or !@contigIndices.key?(contigID))
		idxRec = @contigIndices[contigID]
		return self.getRawContigData(idxRec.aceFileName, idxRec.rdListOffset, idxRec.rdListLength).strip
	end

	def getRawContigData(aceFileName, offset, length)
		@aceFileReader = BRL::Util::TextReader.new(aceFileName) if(@aceFileReader.nil? or @aceFileReader.closed?)
		@aceFileReader.seek(offset)
		retStr = @aceFileReader.read(length)
		return retStr
	end

	def clear()
		@contigIndices.clear() unless (@contigIndices.nil?)
		@numContigs = 0
		@currRecordIdx = nil
		@aceFileName = nil
		self.close()
	end

	def close()
		@aceFileReader.close() unless(@aceFileReader.nil? or @aceFileReader.closed?)
	end
end

class AceFile
	attr_accessor :aceIndex, :aceFileName, :aceIndexFileName, :aceFile, :phrapOutFileName
	attr_accessor :readsVsContigsSwatHits

	CONTIG_DEFLINE_RE = /^CO Contig\d+\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\w+)/
	BS_LINE_SCAN_RE = /^BS\s+.+$/
	AF_LINE_SCAN_RE = /^AF\s+.+$/
	AF_READ_SCAN_RE = /^AF\s+(\S+)\s+(\S+)\s+(-?\d+)/
	RD_DEFLINE_RE = /^RD\s+(\S+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)/
	RD_SEQ_RE = /RD.*\r?\n((?:[AGTCagtcXxNn\*]+\r?\n)+)\r?\n/
	RD_QA_RE = /^QA\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)/m

	def initialize(aceFileName, aceIndexFileName=nil, phrapOutFileName=nil)
		aceFileName = File.expand_path(aceFileName)
		aceIndexFileName = File.expand_path(aceIndexFileName) unless(aceIndexFileName.nil?)
		phrapOutFileName = File.expand_path(phrapOutFileName) unless(phrapOutFileName.nil?)
		@readsVsContigsSwatHits = {}
		@isNewAceFormat = nil
		# check aceFile exists first
		if(File.exists?(aceFileName))
			@aceFileName = aceFileName
			@aceIndex = AceFileIndexer.new()
			# if not given index file name, make index for aceFile
			if(aceIndexFileName.nil? or (!File.exists?(aceIndexFileName)))
				@aceIndex.indexFile(aceFileName)
			else # if given ace index, load it
				@aceIndexFileName = aceIndexFileName
				aceIndex.load(aceIndexFileName, aceFileName)
			end
			# open the file
			@aceFile = BRL::Util::TextReader.new(aceFileName)
		else
			@aceFile = nil
			@aceIndex = nil
		end
		if(!phrapOutFileName.nil? and File.exists?(phrapOutFileName))
			setPhrapOutFile(phrapOutFileName)
		end
	end

	def close()
		@aceIndex = nil
		@aceFile.close unless(@aceFile.nil? or @aceFile.closed?)
		@aceFileName = nil
	end

	def isNewAceFormat?()
		retVal = @aceIndex.isNewAceFormat
		return retVal.nil? ? false : retVal
	end

	def setPhrapOutFile(phrapOutFileName)
		oldPhrapOutFile = @phrapOutFileName.nil? ? nil : @phrapOutFileName
		@phrapOutFileName = phrapOutFileName
		parsePhrapOutFile(phrapOutFileName)
		return oldPhrapOutFile
	end

	def parsePhrapOutFile(phrapOutFileName)
		@readsVsContigsSwatHits.clear
		reader = BRL::Util::TextReader.new(phrapOutFileName)

		wholeFile = reader.read()
		reader.close()
		swatReadsVsContigRecords = wholeFile.split(/Contig\s+\d+\.\s+\d+\s+read/)
		swatReadsVsContigRecords.shift # shift off everything before 1st record
		contigNum = 0
		swatReadsVsContigRecords.each { |record|
			recstr = ''
			contigNum += 1
			lines = record.split("\n")
			lines.shift # remove trailing bit of record separator line
			# we want to store just the hit lines as a *string* (to save space), but
			# first need to process it for junk at end, just to be sure
			lines.each { |line|
				next if(line =~ /^\s+\*+\s+PROBABLE DELETION READ/)
				last if(line =~ /^\s*$/ or line =~ /^Max subclone/ or line =~ /^Contig quality/)
				recstr += "#{line}\n"
			}
			# store the recstr
			@readsVsContigsSwatHits[contigNum] = recstr
		}
		return true
	end

	def numContigs()
		return 0 if(@contigIndices.empty?)
		return @contigIndices.size
	end

	def contigLen(contigID)
		return nil unless(defline = @aceIndex.getDefline(contigID))
		return defline[ CONTIG_DEFLINE_RE, 1 ]
	end

	def getFullRecordStr(contigID)
		return @aceIndex.getFullRecordStr(contigID)
	end

	def defline(contigID)
		return nil unless(defline = @aceIndex.getDefline(contigID))
		return defline
	end

	def numReads(contigID)
		return nil unless(defline = self.defline(contigID))
		return defline[ CONTIG_DEFLINE_RE, 2 ].to_i
	end

	def numReadSegments(contigID)
		return nil unless(defline = self.defline(contigID))
		return defline[ CONTIG_DEFLINE_RE, 3 ].to_i
	end

	def isConsedComplemented?(contigID)
		return nil unless(defline = self.defline(contigID))
		code = defline[ CONTIG_DEFLINE_RE, 4 ].strip
		return code == 'C' ? true : false
	end

	def baseSegmentLines(contigID)
		return nil unless(bsListStr = @aceIndex.getBSListStr(contigID))
		return bsListStr.scan(BS_LINE_SCAN_RE)
	end

	def assembledFromLines(contigID)
		return nil unless(afListStr = @aceIndex.getAFListStr(contigID))
		retVal = afListStr.scan(AF_LINE_SCAN_RE)
		return retVal
	end

	def readOrientationInContig(contigID, readID)
		return nil unless(afLines = self.assembledFromLines(contigID))
		orient = nil
		afLines.each { |afLine|
			if(afLine =~ AF_READ_SCAN_RE)
				read = $1
				ori = $2
				if(read =~ /^#{readID}/)
					orient = (ori == 'U' ? 1 : -1)
					break
				end
			end
		}
		return orient
	end

	def readPaddedOffsetInContig(contigID, readID)
		return nil unless(afLines = self.assembledFromLines(contigID))
		start = nil
		#$stderr.puts "\nAF LINES\n" + afLines.join("\n")
		afLines.each { |afLine|
			if(afLine =~ AF_READ_SCAN_RE)
				read = $1
				strt = $3
				if(read =~ /^#{readID}/)
					start = strt.to_i
					break
				end
			end
		}
		return start
	end

	def readPaddedOffsetsInContig(contigID)
		return nil unless(afLines = self.assembledFromLines(contigID))
		starts = {}
		afLines.each { |afLine|
			if(afLine =~ AF_READ_SCAN_RE)
				starts[$1] = $3.to_i
			end
		}
		return starts
	end

	def readList(contigID)
		return nil unless(afLines = self.assembledFromLines(contigID))
		reads = Array.new(afLines.size)
		ii = 0
		afLines.each { |afLine|
			if(afLine =~ AF_READ_SCAN_RE)
				reads[ii] = $1
				ii += 1
			end
		}
		return reads
	end

	def readCoverage(contigID)
		return nil unless(contigLen = self.contigLen(contigID))
		return nil unless(readLengths = self.readLengths(contigID))
		totalReadLength = 0
		readLengths.each { |read, len| totalReadLenth += len }
		return (totalReadLength.to_f / contigLen.to_f)
	end

	def rawContigSequence(contigID,depad=false)
		return nil unless(seq = @aceIndex.getContigSequence(contigID))
		seq.strip!
		seq.delete('*') if(depad)
		return seq
	end

	def contigBaseQualities(contigID)
		return nil unless(quals = @aceIndex.getContigQualities(contigID))
		return quals.strip!\
	end

	def getReadRecord(contigID, readID)
		return nil unless(readListStr = @aceIndex.getRDListStr(contigID))
		retVal = nil
		readRecStrs = readListStr.split(/^RD\s+/m)
		readRecStrs.each { |readRec|
			if(readRec =~ /^#{readID}/)
				retVal = 'RD ' + readRec.strip
				break
			end
		}
		return retVal
	end

	def getReadSequence(contigID, readID, depad=false)
		return nil unless(readRec = self.getReadRecord(contigID, readID))
		retVal = nil
		readRec =~ RD_SEQ_RE
		retVal = $1
		retVal.delete('*') if(depad)
		return retVal
	end

	def readLength(contigID, readID)
		return nil unless(readRec = self.getReadRecord(contigID, readID))
		retVal = nil
		readRec =~ RD_DEFLINE_RE
		retVal = $2
		return retVal.nil? ? nil : retVal.to_i
	end

	def readLengths(contigID)
		return nil unless(readListStr = @aceIndex.getRDListStr(contigID))
		retVal = {}
		readDeflines = readListStr.scan(RD_DEFLINE_RE)
		readDeflines.each { |readDefline|
			retVal[readDefline[0]] = readDefline[1].to_i
		}
		return retVal
	end

	def getReadTrimmingCoords(contigID, readID)
		return nil unless(readRec = self.getReadRecord(contigID, readID))
		retVal = nil
		readRec =~ RD_QA_RE
		unless($1.nil? or $2.nil?)
			qualStart = $1.to_i
			qualEnd = $2.to_i
		end
		return [ qualStart, qualEnd ]
	end

	def getReadAlignmentCoords(contigID, readID)
		return nil unless(readRec = self.getReadRecord(contigID, readID))
		retVal = nil
		readRec =~ RD_QA_RE
		unless($3.nil? or $4.nil?)
		alignStart = $3.to_i
			alignEnd = $4.to_i
		end
		return [ alignStart, alignEnd ]
	end

	def getReadStartEndInContig(contigID, readID)
		return nil unless(startBase = self.readPaddedOffsetInContig(contigID, readID))
		return nil unless(readLength = self.readLength(contigID, readID))
		endBase = startBase + readLength
		return [ startBase, endBase ]
	end

	def allReadSwatHits(contigID)
		return nil if(@readsVsContigsSwatHits.nil? or @readsVsContigsSwatHits.empty?)
		return @readsVsContigsSwatHits[contigID].split("\n")
	end

	def readSwatHitForRead(contigID, readID)
		return nil unless(swatHits = self.allReadSwatHits(contigID))
		retVal = nil
		swatHits.each { |swatHit|
			next unless(swatHit =~ /#{readID}/)
			retVal = swatHit.strip
			break
		}
		return retVal
	end
end



end ; end
