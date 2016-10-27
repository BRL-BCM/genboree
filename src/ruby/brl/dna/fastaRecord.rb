#!/usr/bin/env ruby
# Turn on extra warnings and such
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))
# ##############################################################################
# $Copyright:$
# ##############################################################################

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/util'					# For standard BRL extensions to built-ins
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
# ##############################################################################

module BRL ; module DNA
	class FastaParseError < StandardError ; end ;

	# ############################################
	# FastaSeqRecord -- for fasta sequence records
	# ############################################
	class FastaSeqRecord
		attr_accessor :fastaID, :defLine, :sequence
		attr_accessor :basesPerLine

		DEF_BASES_PER_LINE = 50
		def FastaSeqRecord.newFromRecordString(recordStr, basesPerLine=BRL::DNA::FastaSeqRecord::DEF_BASES_PER_LINE)
			if(recordStr.nil? or recordStr.empty?)
				return FastaSeqRecord.new(nil, nil)
			else # we should have a record
				re = Regexp.new("^(>[^\n]+\n)")
				mm = re.match(recordStr)
				unless(mm.nil?)
					defLine = $1
					seq = recordStr.slice(mm.end(0)...recordStr.length)
					return BRL::DNA::FastaSeqRecord.new(defLine, seq, basesPerLine)
				else # match failed...not a valid fasta record
					raise(FastaParseError, "ERROR: you didn't give a valid fasta record to FastaSeqRecord.newFromRecordString")
				end
			end
		end

		def initialize(defLine=nil, sequence=nil, basesPerLine=BRL::DNA::FastaSeqRecord::DEF_BASES_PER_LINE)
			@basesPerLine = basesPerLine
			@defLine, @sequence = defLine, sequence
			unless(defLine.nil? or defLine.empty?)
				if(@defLine =~ /^>(\S+)/)
					@fastaID = $1
					@defLine.chomp!
				else
					raise(FastaParseError, "ERROR: you gave a bad defline to FastaSeqRecord.new:\n'#{defLine}'\nfasta deflines start with '>' followed by an ID\n")
				end
			else # defLine is nil or empty, so set a nil fastaID
				@fastaID = nil
			end
			# Go through the sequence and linearize it
			unless(@sequence.nil? or @sequence.empty?)
				@sequence = @sequence.split("\n").join('')
			end
		end

		def countChars(basesStr)
			return (@sequence.nil? or @sequence.empty?) ? 0 : @sequence.count(basesStr)
		end

		def countNs()
			return self.countChars('nN')
		end

		def countXs()
			return self.countChars('xX')
		end

		def countBases()
			return self.countChars('agtcAGTC')
		end

		def seqLength
			return @sequence.length
		end

		def getFormattedSeq
			seq = ''
			unless(@sequence.nil? or @sequence.empty?)
				re = Regexp.compile("[a-zA-Z]{1,#{@basesPerLine}}")
				@sequence.scan(re) {
					|seqLine|
					seq << "#{seqLine}\n"
				}
			end
			return seq
		end

		def to_s()
			strToRet = (@defLine.nil? or @defLine.empty?) ? ">UNKNOWN_ID\n" : "#{@defLine}\n"
			strToRet << self.getFormattedSeq()
			return strToRet
		end

		alias :size :seqLength
		alias :length :seqLength
	end # class FastaSeqRecord

	# ###############################################
	# FastaSeqRecordHash -- for collections of fasta
	#                        sequence records, keyed
	#                        by record id
	# ###############################################
	class FastaSeqRecordHash < Hash
		attr_accessor :basesPerLine

		def initialize(inputSrc, basesPerLine=BRL::DNA::FastaSeqRecord::DEF_BASES_PER_LINE)
			@basesPerLine = basesPerLine
			unless(inputSrc.nil?) # Then we have a source to read from
				# ARJ 11/13/2002 1:30PM => We let the source be a String, IO (including socket/file), or our TextReader
				#                          This means it will reply to "each" so we can walk through the lines.
				# ARJ 11/13/2002 1:31PM => NOTE: If the source has "issues", it may raise an IOError or something. Since
				#                                that is the user's fault, we'll let them rescue the situation.
				#                                We will re-raise the error but ensure the source is closed
				lineNum = 0
				begin
					if(inputSrc.kind_of?(String) or inputSrc.kind_of?(IO) or inputSrc.kind_of?(BRL::Util::TextReader)) # then init from string
						# read each line, using a state machine to find records
						prevDefLine = nil
						prevSeq = ''
						inputSrc.each {
							|line|
							line.strip!
							lineNum+= 1
							next if(line =~ /^\s*$/) # Skip blank lines
							next if(line =~ /^\s*#/) # Skip comment lines
							# Is it a defLine?
							if(line =~ /^>/)
								# Is there a previous defline (and thus previous record to create)?
								unless(prevDefLine.nil?)
									offset = prevDefLine =~ /^>(\S+)/
									fastaID = $1
									if(fastaID.nil?) # then match failed and we have a bad record
										raise(FastaParseError, "ERROR: not valid fasta record file/source. See the record preceeding line #{lineNum}")
									end
									if(self.key?(fastaID)) # then the fastaID's aren't unique in this file! Bad!
										raise(FastaParseError, "ERROR: fasta IDs aren't unique in your source! Found two of '#{fastaID}' (2nd is at line num #{lineNum}).\nThe first word after the > in the defline must be unique within a fasta file.\nRead the fasta specs maybe?\n")
									else
										self[fastaID] = BRL::DNA::FastaSeqRecord.new(prevDefLine, prevSeq, basesPerLine)
									end
								end
								prevDefLine = line
								prevSeq = ''
							else # it is a sequence line, store it
								prevSeq << line
							end # if(line =~ /^>/)
						} # END: inputSrc.each {
						# State machine has ended, but we need to flush the last state
						unless(prevDefLine.nil?)
							offset = prevDefLine =~ /^>(\S+)/
							fastaID = $1
							if(self.key?(fastaID)) # then the fastaID's aren't unique in this file! Bad!
								raise(FastaParseError, "ERROR: fasta IDs aren't unique in your source!\nThe first word after the > in the defline must be unique within a fasta file.\nRead the fasta specs maybe?\n")
							else
								self[fastaID] = BRL::DNA::FastaSeqRecord.new(prevDefLine, prevSeq, basesPerLine)
							end
						end
					else # dunno the type
						raise(TypeError, "Cannot initialize a BlatMappedContigArray from #{inputSrc.type}. Try a String, IO, or BRL::Util::TextReader object.");
					end # if(source.kind_of?(String) or source.kind_of?(IO) or source.kind_of?(BRL::Util::TextReader))
				ensure
					inputSrc.close() unless(!inputSrc.respond_to?("close") or inputSrc.nil? or inputSrc.closed?)
				end # begin
			else # no-arg constructor
				super.new()
			end
		end # def initialize(inputSrc, basesPerLine=BRL::DNA::FastaSeqRecord::DEF_BASES_PER_LINE)
	end # class FastaSeqRecordArray < Hash

	# ############################################
	# FastaQualRecord -- for fasta quality records
	# ############################################
	class FastaQualRecord
		attr_accessor :fastaID, :defLine, :qualities
		attr_accessor :qualitiesPerLine

		DEF_QUALS_PER_LINE = 50

		def FastaQualRecord.newFromRecordString(recordStr, basesPerLine=BRL::DNA::FastaQualRecord::DEF_QUALS_PER_LINE)
			if(recordStr.nil? or recordStr.empty?)
				return FastaQualRecord.new(nil, nil)
			else # we should have a record
				re = Regexp.new("^(>[^\n]+\n)")
				mm = re.match(recordStr)
				unless(mm.nil?)
					defLine = $1
					quals = recordStr.slice(mm.end(0)...recordStr.length)
					return BRL::DNA::FastaQualRecord.new(defLine, quals, basesPerLine)
				else # match failed...not a valid fasta record
					raise(FastaParseError, "ERROR: you didn't give a valid fasta record to FastaQualRecord.newFromRecordString")
				end
			end
		end

		def initialize(defLine=nil, qualities=nil, qualitiesPerLine=BRL::DNA::FastaQualRecord::DEF_QUALS_PER_LINE)
			@qualitiesPerLine = qualitiesPerLine
			@defLine, @qualities = defLine, qualities
			unless(defLine.nil? or defLine.empty?)
				if(@defLine =~ /^>(\S+)/)
					@fastaID = $1
					@defLine.chomp!
				else
					raise(FastaParseError, "ERROR: you gave a bad defline to FastaQualRecord.new:\n'#{defLine}'\nfasta deflines start with '>' followed by an ID\n")
				end
			else # defLine is nil or empty, so set a nil fastaID
				@fastaID = nil
			end
			# Go through the qualities and linearize it
			unless(@qualities.nil? or @qualities.empty?)
				@qualities = @qualities.split("\n").collect { |line| line.strip! }.join(' ')
				@qualities += ' ' # to make last record easy to scan for
			end
		end

		def countQualities()
			return (@qualities.nil? or @qualities.empty?) ? 0 : @qualities.split(/\s+/).size
		end

		def getFormattedQuals
			quals = ''
			unless(@qualities.nil? or @qualities.empty?)
				re = Regexp.compile("(?:\\d+\\d?\\s+){1,#{@qualitiesPerLine}}")
				@qualities.scan(re) {
					|qualLine|
					quals << "#{qualLine}\n"
				}
			end
			return quals
		end

		def to_s()
			strToRet = (@defLine.nil? or @defLine.empty?) ? ">UNKNOWN_ID\n" : "#{@defLine}\n"
			strToRet << self.getFormattedQuals()
			return strToRet
		end

		alias :size :countQualities
		alias :length :countQualities
	end # class FastaQualRecord

	# #################################################
	# FastaQualRecordHash -- for collections of fasta
	#                         quality records, keyed by
	#                         record id
	# #################################################
	class FastaQualRecordHash < Hash
		attr_accessor :qualitiesPerLine

		def initialize(inputSrc, qualitiesPerLine=BRL::DNA::FastaQualRecord::DEF_QUALS_PER_LINE)
			@qualitiesPerLine = qualitiesPerLine
			unless(inputSrc.nil?) # Then we have a source to read from
				# ARJ 11/13/2002 1:30PM => We let the source be a String, IO (including socket/file), or our TextReader
				#                          This means it will reply to "each" so we can walk through the lines.
				# ARJ 11/13/2002 1:31PM => NOTE: If the source has "issues", it may raise an IOError or something. Since
				#                                that is the user's fault, we'll let them rescue the situation.
				#                                We will re-raise the error but ensure the source is closed
				lineNum = 0
				begin
					if(inputSrc.kind_of?(String) or inputSrc.kind_of?(IO) or inputSrc.kind_of?(BRL::Util::TextReader)) # then init from string
						# read each line, using a state machine to find records
						prevDefLine = nil
						prevQuals = ''
						inputSrc.each {
							|line|
							line.strip!
							lineNum+= 1
							next if(line =~ /^\s*$/) # Skip blank lines
							next if(line =~ /^\s*#/) # Skip comment lines
							# Is it a defLine?
							if(line =~ /^>/)
								# Is there a previous defline (and thus previous record to create)?
								unless(prevDefLine.nil?)
									offset = prevDefLine =~ /^>(\S+)/
									fastaID = $1
									if(fastaID.nil?) # then match failed and we have a bad record
										raise(FastaParseError, "\nERROR: not valid fasta record file/source. See the record preceeding line #{lineNum}\n")
									end
									if(self.key?(fastaID)) # then the fastaID's aren't unique in this file! Bad!
										raise(FastaParseError, "\nERROR: fasta IDs aren't unique in your source!\nThe first word after the > in the defline must be unique within a fasta file.\nRead the fasta specs maybe?\n")
									else
										self[fastaID] = BRL::DNA::FastaQualRecord.new(prevDefLine, prevQuals, qualitiesPerLine)
									end
								end
								prevDefLine = line
								prevQuals = ''
							else # it is a qualities line, store it
								prevQuals << line
								prevQuals << ' '
							end # if(line =~ /^>/)
						} # END: inputSrc.each {
						# State machine has ended, but we need to flush the last state
						unless(prevDefLine.nil?)
							offset = prevDefLine =~ /^>(\S+)/
							fastaID = $1
							if(self.key?(fastaID)) # then the fastaID's aren't unique in this file! Bad!
								raise(FastaParseError, "\nERROR: fasta IDs aren't unique in your source!\nThe first word after the > in the defline must be unique within a fasta file.\nRead the fasta specs maybe?\n")
							else
								self[fastaID] = BRL::DNA::FastaQualRecord.new(prevDefLine, prevQuals, qualitiesPerLine)
							end
						end
					else # dunno the type
						raise(TypeError, "\nERROR: Cannot initialize a FastaQualRecordHash from #{inputSrc.type}. Try a String, IO, or BRL::Util::TextReader object.\n");
					end # if(source.kind_of?(String) or source.kind_of?(IO) or source.kind_of?(BRL::Util::TextReader))
				ensure
					inputSrc.close() unless(!inputSrc.respond_to?("close") or inputSrc.nil? or inputSrc.closed?)
				end # begin
			else # no-arg constructor
				super.new()
			end
		end # def initialize(inputSrc, qualitiesPerLine=BRL::DNA::FastaQualRecord::DEF_QUALS_PER_LINE)
	end # class FastaQualRecordHash < Hash

	class FastaFileIndexer
		FA_ID, FA_FILE_ID, REC_OFFSET, REC_LEN, DEF_LEN, SEQ_OFFSET, SEQ_LEN =
			0,1,2,3,4,5,6
		GT_ASCII, LT_ASCII = 62,60
		BLANK_RE = /^\s*$/
		COMMENT_RE = /^\s*#/
		FASTAID_RE = /^>(\S+)/
		FILE_RE = /^<FILE>\t(\d+)\t(\S+)/

		attr_accessor :fastaRecordIndices, :fileIDs, :verbose

		def initialize()
			@fastaRecordIndices = {}
			@files2IDs = {}
			@ids2files = {}
			@srcFiles = {}
			@lastFileID = 0
			@verbose = false
		end

		def getSrcReader(faFile)
			reader = nil
			if(@srcFiles.key?(faFile))
				reader = @srcFiles[faFile]
			else # need a new one
				# Do we have too many open?
				if(@srcFiles.size > 750)
					# then arbitrarily close one (the first hash key let's say)
					@srcFiles[@srcFiles.keys[0]].close
					@srcFiles.delete(@srcFiles.keys[0])
				end
				@srcFiles[faFile] = BRL::Util::TextReader.new(faFile)
				reader = @srcFiles[faFile]
			end
			return reader
		end

		def indexFile(faFile)
			faFile = File::expand_path(faFile)
			faFileID = self.getFileID(faFile)
			raise "\nERROR: '#{faFile}' is a gzipped file. Cannot properly index compressed data.\n" if(BRL::Util::Gzip.isGzippedFile?(faFile))
			#fastaReader = BRL::Util::TextReader.new(faFile)
			fastaReader = self.getSrcReader(faFile)
			currFastaIndex = nil
			fastaReader.each {
				|line|
				next if(line =~ BLANK_RE or line =~ COMMENT_RE)
				#if(line =~ /^>(\S+)/ or fastaReader.eof?)
				if(line[0] == GT_ASCII or fastaReader.eof?())
					unless(currFastaIndex.nil?)
						currFastaIndex[SEQ_LEN] = fastaReader.pos - currFastaIndex[SEQ_OFFSET] - (fastaReader.eof? ? 0 : line.length)
						currFastaIndex[REC_LEN] = fastaReader.pos - currFastaIndex[REC_OFFSET] - (fastaReader.eof? ? 0 : line.length)
						if(@fastaRecordIndices.key?(currFastaIndex[FA_ID]))
							raise "\nERROR: The ID '#{currFastaIndex[FA_ID]}' for the record preceeding line #{fastaReader.lineno} is not unique within the fasta file.\n"
						else
							@fastaRecordIndices[currFastaIndex[FA_ID]] = currFastaIndex
							if(@fastaRecordIndices.size > 0 and (@fastaRecordIndices.size % 1000 == 0) and (@verbose))
								$stderr.print '.'
							end
						end
					end
					unless(fastaReader.eof?)
						line =~ FASTAID_RE
						currFastaIndex =
							[$1, faFileID, fastaReader.pos - line.length, nil, line.length, fastaReader.pos, nil]
					end
				end
			}
			$stderr.puts '' if(@verbose)
			return
		end

		def getFileID(faFile)
			faFile = File::expand_path(faFile)
			if(@files2IDs.key?(faFile))
				return @files2IDs[faFile]
			else
				@lastFileID += 1
				@files2IDs[faFile] = @lastFileID
				@ids2files[@lastFileID] = faFile
				return @lastFileID
			end
		end

		def addFilename(faFile)
			faFile = File::expand_path(faFile)
			if(@files2IDs.key?(faFile))
				return @files2IDs[faFile]
			else
				@lastFileID += 1
				@files2IDs[faFile] = @lastFileID
				@ids2files[@lastFileID] = faFile
				return @lastFileID
			end
		end

		def getFileName(fileID)
			return @ids2files[fileID]
		end

		def loadIndex(indexFileName)
			indexReader = BRL::Util::TextReader.new(indexFileName)
			indexReader.each {
				|line|
				line.strip!
				if(line =~ BLANK_RE or line =~ COMMENT_RE)
					next
				elsif(line[0] == LT_ASCII)
					line =~ FILE_RE
					fileID = $1.to_i
					@files2IDs[$2] = fileID
					@ids2files[fileID] = $2
					if(fileID > @lastFileID) then @lastFileID = fileID ; end
				else
					indexRecord = line.split("\t")
					(1..6).each {
						|ii|
						indexRecord[ii] = indexRecord[ii].to_i
					}
					if(@fastaRecordIndices.key?(indexRecord[FA_ID]))
						raise "\nERROR: The ID '#{indexRecord[FA_ID]}' is already in the index. Either you forgot to clear the index before reusing it or you've got duplicate index entries for the same fasta record.\n"
					else
						@fastaRecordIndices[indexRecord[FA_ID]] = indexRecord
					end
				end
			}
			indexReader.close() unless(indexReader.nil? or indexReader.closed?)
			return
		end

		def saveIndex(indexFileName, doGzip=true)
			writer = BRL::Util::TextWriter.new(indexFileName, "w+", doGzip)
			@ids2files.each {
				|fileID, fileName|
				writer.puts "<FILE>\t#{fileID}\t#{fileName}"
			}
			@fastaRecordIndices.each {
				|fastaID, rec|
				writer.puts rec.join("\t")
			}
			writer.close()
			return
		end

		def getFastaRecordStr(fastaID)
			return nil if(@fastaRecordIndices.nil? or @fastaRecordIndices.empty? or !@fastaRecordIndices.key?(fastaID))
			# get the record
			indexRecord = @fastaRecordIndices[fastaID]
			return self.getFastaData(indexRecord[FA_FILE_ID], indexRecord[REC_OFFSET], indexRecord[REC_LEN]).strip
		end

		def getFastaDefline(fastaID)
			return nil if(@fastaRecordIndices.nil? or @fastaRecordIndices.empty? or !@fastaRecordIndices.key?(fastaID))
			# get the record
			indexRecord = @fastaRecordIndices[fastaID]
			return self.getFastaData(indexRecord[FA_FILE_ID], indexRecord[REC_OFFSET], indexRecord[DEF_LEN]).strip
		end

		def getFastaSequence(fastaID)
			return nil if(@fastaRecordIndices.nil? or @fastaRecordIndices.empty? or !@fastaRecordIndices.key?(fastaID))
			# get the record
			indexRecord = @fastaRecordIndices[fastaID]
			return self.getFastaData(indexRecord[FA_FILE_ID], indexRecord[SEQ_OFFSET], indexRecord[SEQ_LEN]).strip
		end

		def getFastaData(fileID, offset, length)
			fileName = @ids2files[fileID].dup.untaint
			# open the file
			# reader = BRL::Util::TextReader.new(fileName)
			reader = self.getSrcReader(fileName)
			reader.seek(offset)
			retStr = reader.read(length)
#			# close the file
#			reader.close() unless(reader.nil? or reader.closed?())
			return retStr
		end

		def clear()
			self.close()
			@srcFiles.clear
			return @fastaRecordIndices.clear
		end

		def close()
			@srcFiles.each {
				|fileName, fh|
				fh.close unless(fh.nil? or fh.closed?)
			}
			return
		end
	end # class FastaFileIndexer

	class FastaRecordConcatenator
		attr_accessor :lastConcatRecID, :lastConcatFileNum
		attr_accessor :concatContents, :recID2location, :rawConcatContents
		attr_accessor :fixedPaddingLength, :padToLength, :truncateToLength
		attr_accessor :resolution

		FA_ID, START_BASE, END_BASE, FA_LENGTH = 0,1,2,3
		def initialize()
			@rawConcatContents = {}
			@recID2location = Hash.new {|hh,kk| hh[kk] = [] }
			@maxRecLength = -100000
			@concatContents = {}
			@concatLengths = {}
			@concat2file = {}
			@currConcatRecNum = 0
			@currConcatRecID = nil
			@currConcatFileNum = 0
			@currConcatFile = nil
			@fixedPaddingLength = nil
			@padToLength = nil
			@truncateToLength = nil
		end

		def concatenateFastaRecords(faFile, maxRecordSize=1_000_000_000, maxFileSize=1_000_000_000, maxNumRecsPerFile=1)
			faFile = File::expand_path(faFile)
			fixedNString = 'N'*@fixedPaddingLength unless(@fixedPaddingLength.nil?)
			numRecsInFile = 0
			reader = BRL::Util::TextReader.new(faFile)
			lastIndex = nil
			concatNumBases = 0
			currRecNumBases = 0
			doneCurrRec = false
			concatWriter = nil
			newFile = false
			reader.each{ |line|
				line.strip!
				next if(line =~ /^\s*$/ or line =~ /^\s*#/)
				if(line =~ /^>(\S+)/ or reader.eof?)
					# If eof, then finish up last record
					if(reader.eof?)
						# Do we need to truncate the current fasta record before concatenating?
						if(!@truncateToLength.nil? and !doneCurrRec)
							diff = @truncateToLength - currRecNumBases
							if(diff < 0)
								line = ''
								doneCurrRec = true
							elsif(line.length > diff)
								line = line.slice(0, diff.abs)
								doneCurrRec = true
							end
						end
						currRecNumBases += line.length
						concatNumBases += line.length
						lastIndex[END_BASE] = concatNumBases
						recLength = (lastIndex[END_BASE]-lastIndex[START_BASE]).abs + 1
						@maxRecLength = recLength if(recLength > @maxRecLength)
						@concatLengths[@currConcatRecID] = concatNumBases
						concatWriter.puts(line)
						# Before outputting rest of record, do we need to pad it or anything>
						unless(@padToLength.nil?)
							diff = @padToLength - currRecNumBases
							if(diff > 0)
								concatWriter.puts 'N' * diff.abs
								concatNumBases += diff.abs
							end
						end
						unless(@fixedPaddingLength.nil?)
							concatWriter.puts fixedNString
							concatNumBases += @fixedPaddingLength
						end
						concatWriter.close() unless(concatWriter.nil? or concatWriter.closed?)
					else # not eof, but found another record
						# if the there is a previous fasta record, store its end position
						unless(lastIndex.nil?)
							# save prev record's info
							lastIndex[END_BASE] = concatNumBases
							recLength = (lastIndex[END_BASE]-lastIndex[START_BASE]).abs + 1
							@maxRecLength = recLength if(recLength > @maxRecLength)
							@concatLengths[@currConcatRecID] = concatNumBases
							# Before outputting rest of record, do we need to pad it or anything>
							unless(@padToLength.nil?)
								diff = @padToLength - currRecNumBases
								if(diff > 0)
									concatWriter.puts 'N' * diff.abs
									concatNumBases += diff.abs
								end
							end
							unless(@fixedPaddingLength.nil?)
								concatWriter.puts fixedNString
								concatNumBases += @fixedPaddingLength
							end
						end
						# Set up the current record now that we dealt with the previous
						currIndex = [$1, concatNumBases+1, 0]
						# Do we need a new concat file?
						if(lastIndex.nil? or (concatWriter.pos >= maxFileSize) or ((concatNumBases  > maxRecordSize) and (numRecsInFile+1 > maxNumRecsPerFile)))
							@currConcatFileNum += 1
							@currConcatFile = "#{faFile}.concat.#{@currConcatFileNum}"
							numRecsInFile = 0
							concatWriter.close() unless(concatWriter.nil? or concatWriter.closed?)
							concatWriter = BRL::Util::TextWriter.new(@currConcatFile)
							newFile = true
						end
						# Do we need a new concat record?
						if((concatNumBases  > maxRecordSize) or newFile)
							numRecsInFile += 1
							# form the new concat rec
							@currConcatRecNum += 1
							@currConcatRecID = "#{@currConcatFileNum}.concat.#{@currConcatRecNum}"
							@concat2file[@currConcatRecID] = @currConcatFile
							# Need a defline
							concatWriter.print '>'
							concatWriter.puts @currConcatRecID
							concatNumBases = 0
							currIndex[START_BASE] = 1
						end

						lastIndex = currIndex
						newFile = false
						# Store the new fasta record's info
						@rawConcatContents[@currConcatRecID] = [] unless(@rawConcatContents.key?(@currConcatRecID))
						@rawConcatContents[@currConcatRecID] << lastIndex
					end
					currRecNumBases = 0
					doneCurrRec = false
				else # found a sequence line
					next if(doneCurrRec)
					# Do we need to truncate the current fasta record before concatenating?
					unless(@truncateToLength.nil?)
						diff = @truncateToLength - currRecNumBases
						if(diff < 0)
							line = ''
							doneCurrRec = true
						elsif(line.length > diff)
							line = line.slice(0, diff.abs)
							doneCurrRec = true
						end
					end
					currRecNumBases += line.length
					concatNumBases += line.length
					concatWriter.puts line unless(line.empty?)
					newFile = false
				end
			}
			convertRawToBinned()
			return
		end
		
		def convertRawToBinned()
			@resolution = 10*@maxRecLength
			@rawConcatContents.each { |recID, recArray|
				@concatContents[recID] = {} unless(@concatContents.key?(recID))
				recArray.each { |rec|
					startBin = (rec[START_BASE] / @resolution).to_i
					@concatContents[recID][startBin] = [ ] unless(@concatContents[recID].key?(startBin))
					@concatContents[recID][startBin] << rec
				}
			}
			# Sort each concat record's contents, just to be sure
			# We'll sort by end value. That way, when searching when queryStart > recordStart, stop search
			@concatContents.keys.each { |concatID|
				@concatContents[concatID].keys.each { |startBin|
					@concatContents[concatID][startBin].sort!{ |aa,bb| aa[END_BASE] <=> bb[END_BASE] }
				}
			}
		end
		
		def loadConcatFastaIdx(indexFile)
			reader = BRL::Util::TextReader.new(indexFile)
			currConcatID = nil
			reader.each {
				|line|
				line.strip!
				next if(line =~ /^\s*$/ or line =~ /^\s*#/)
				if(line =~ /^<CONCAT_FASTA_REC>\t(\S+)\t(\d+)\t(\S+)/)
					currConcatID = $1
					@rawConcatContents[currConcatID] = [] 
					@concatLengths[currConcatID] = $2.to_i
					@concat2file[currConcatID] = $3
				elsif(line =~ /^<FASTA_REC>\t(\S+)\t(\d+)\t(\d+)/)
					start,stop = $2.to_i, $3.to_i
					indexRecord = [ $1, start, stop ]
					@recID2location[indexRecord[0]] << [ start, stop, currConcatID ]
					@rawConcatContents[currConcatID] << indexRecord
					recLength = (indexRecord[END_BASE] - indexRecord[START_BASE]).abs + 1
					@maxRecLength = recLength if(recLength > @maxRecLength)					
				else
					raise "\nERROR: badly formatted concatentated fasta index file '#{indexFile}'.\n"
				end
			}
			convertRawToBinned()
			return
		end

		def saveConcatFastaIdx(indexFile)
			writer = BRL::Util::TextWriter.new(indexFile, 'w+', true)
			@concatContents.each {
				|concatRecID, contentHash|
				writer.puts "<CONCAT_FASTA_REC>\t#{concatRecID}\t#{@concatLengths[concatRecID]}\t#{@concat2file[concatRecID]}"
				contentHash.each {
					|startBin, contentArray|
					contentArray.each {
						|idx|
						idxStr = idx.join("\t")
						writer.puts "\t<FASTA_REC>\t#{idxStr}"
					}
				}
			}
			writer.close()
		end

		def fastaIDAt(concatRecID, start, stop, wantDetails=true)
			start = start.to_i
			stop = stop.to_i
			if(stop < start) # then swap (start comes before stop...duh)
				#$stderr.puts "DEBUG: '#{start}' > '#{stop}'. Swapping start<->stop."
				start,stop = stop,start
			end
			#$stderr.puts "DEBUG: your parameters:\n   '#{concatRecID}'\n   '#{start}'\n   '#{stop}'\n   '#{wantDetails}'"
			#$stderr.puts "DEBUG: are the concatContents empty/nil etc?"
			return nil if(	@concatContents.nil? 													or
											!@concatContents.key?(concatRecID) 						or
											@concatContents[concatRecID].empty?)
			allRecords = []
			#$stderr.puts "DEBUG: ...nope not empty."
			# Need to look through all start bins spanned by the start,stop range
			# Need to check special case of previous start bin as well, in case range starts in
			# next bin, but read is binned in prev bin b/c where it starts.
			lastStartBin = (stop / @resolution).to_i
			currStartBin = ((start / @resolution) - 1).to_i
			currStartBin = 0 if(currStartBin < 0)
			#$stderr.puts "DEBUG: the current start bin is: '#{currStartBin}'\nDEBUG: the last start bin is '#{lastStartBin}'"
			while(currStartBin <= lastStartBin) do
				#$stderr.puts "DEBUG: Looking in bin '#{currStartBin}'..."
				unless(!@concatContents[concatRecID].key?(currStartBin) or @concatContents[concatRecID][currStartBin].empty?)
					#$stderr.puts "DEBUG: ...this bin is not empty, so let's look."
					@concatContents[concatRecID][currStartBin].each { |content|
						# Look through the contentArray until start > currRecEnd
						#$stderr.puts "   - first bin item is: '#{content.inspect}'   your start/stop is: '#{start}' / '#{stop}'"
						next if(start > content[END_BASE]) # go to next content record
						#$stderr.puts "      . start can be in this bin!"
						if((start <= content[END_BASE]) and (content[START_BASE] <= stop))
							#$stderr.puts "      . Yes! Found the bin! Now add to allRecords list."
							# then range contains this fasta rec
							# Convert the range to coordinates within the fasta rec as best we can
							fstart = start - content[START_BASE] + (start < content[START_BASE] ? 0 : 1)
							fstop = stop - content[START_BASE] + 1
							flength = content[END_BASE] - content[START_BASE] + 1
							allRecords << [content[FA_ID], fstart, fstop, flength]
						end
					}
				end
				currStartBin += 1
			end

			unless(wantDetails)
				unless(allRecords.empty?)
					maxCovered = allRecords[0]
					maxDist = allRecords[0][2] - allRecords[0][1]
					allRecords.each {
						|frec|
						fdist = frec[2] - frec[1]
						if(fdist > maxDist)
							maxDist = fdist
							maxCovered = frec
						end
					}
					return maxCovered[0]
				else # allrecords empty (not found)
					return nil
				end
			else # wantDetails
				return allRecords.sort{|aa,bb| (bb[2]-bb[1]) <=> (aa[2]-aa[1]); }
			end
		end
		
		def getSeqForFastaRecID(recID, concatFileName, padding=500)
		  locationRec = @recID2location[recID][0]
		  return getSeqForFastaRecStartStop(locationRec[0], locationRec[1], concatFileName, padding=500)  
		end
		
	  def getSeqForFastaRecStartStop(recStart, recStop, concatFileName, padding=500)
	    retVal = nil
	    concatFile = BRL::Util::TextReader.new(concatFileName)
	    div = "N" * padding
	    currSeqStart = 1 # Where we are in the *sequence* (start)
      currSeqStop = -1 # Where we are in the *sequence* (stop)
	    # Read the "lines" which are actually fasta sequence divided by a padding number of Ns.
	    ii = 0
	    loop {
	      currRec = concatFile.readline(div)
	      if(currRec =~ /^(>[^\n]+\n)/) # then we are starting a new concat record (reset offsets)
	        defLine = $1
	        currSeqStart = 1
	        currSeqStop = -1
	        currRec = currRec[defLine.size, currRec.size] # strip off defline
	      end
	      strippedRec = currRec.gsub(/\n/, '')
        currSeqStop = currSeqStart + strippedRec.size - div.size - 1
        nextSeqStart = currSeqStart + strippedRec.size
        if(currSeqStart == recStart and currSeqStop = recStop)
          retVal = currRec.chomp(div)
          break # got it!
        else
          currSeqStart = nextSeqStart
        end
      }
      concatFile.close
      return retVal
	  end
	  
	end # class FastaRecordMerger
end ; end # module BRL ; module DNA

