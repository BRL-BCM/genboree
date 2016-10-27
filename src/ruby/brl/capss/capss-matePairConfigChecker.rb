#!/usr/bin/env ruby

=begin
=end
# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/lsf/lsfBatchJob'

module BRL ; module CAPSS

class MatePairConfigChecker
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	JOB_NAME_BASE = 'cmpcc-'
	EDGE_RE = /(\S+)\s+(\{\S+\})/
	BLANK_RE = /^\s*$/
	COMMENT_RE = /^\s*#/
	BIN, CO, AF, START, BS = 0, 1, 2, 3, 4
	READ_START, READ_ORIENT = 0, 1
	BIN_RE = /^BIN (?:.+_)?(\d+)$/
	CO_RE = /^CO Contig(\d+)\s+(\d+)\s+(\d+)/
	AF_RE = /^AF (\S+)\s+(\S+)\s+(\S+)$/
	BS_RE = /^BS (\d+)\s+(\d+)\s+(\S+)$/
	NONE_RE = /none/i
	TRUE_RE = /true/i
	U_RE = /U/
	
	def initialize()
	end

	def run()
		$stderr.puts "STATUS: begin analysis"
		@params = processArguments()
		$stderr.puts "STATUS: processed args"
		loadContigSummaryFile()
		$stderr.puts "STATUS: loaded contig summary file"
		#$stderr.puts "\n\nContig Summary info:\n\n'#{@contigData}'\n\n"
		loadReadLengthsFile()
		$stderr.puts "STATUS: loaded read lengths file"
		loadMatePairInfoFile()
		$stderr.puts "STATUS: loaded mate pair info file"
		analyseMatePairConfiguration()
		$stderr.puts "STATUS: analysed mate pair configurations"
		return
	end

	def analyseMatePairConfiguration()
		# For each mate pair
		@matePairInfo.each { |insert, fields|
			# Do we have both mates?
			next if(fields[2] =~ NONE_RE)
			# Are the contigs the same?
			next unless(fields[10] =~ TRUE_RE)
			# Get contig name, read names
			contigID = fields[8]
			readID1 = fields[1]
			readID2 = fields[2]
			orientOk = matePairOrientOk?(contigID, readID1, readID2)
			gap = matePairGap(contigID, readID1, readID2)
			begin
				gapOk = (gap <= @maxGap and gap >= @minGap)
			rescue => err
				$stderr.puts "\n\nERROR: maxGap '#{@maxGap}', minGap '#{@minGap}', calcGap: '#{gap}'\n\n"
				raise err
			end
			# Dump info
			puts 	fields[0]	+ "\t" +	# insert name
						contigID	+ "\t" +
						orientOk.to_s	+ "\t" +	# complements ok?
						gapOk.to_s	+ "\t" + 	# distance ok?
						insertSize(contigID, readID1, readID2).to_s + "\t" +
						uBeforeC?(contigID, readID1, readID2).to_s	+ "\t" +  # U before C?
						(!uBeforeC?(contigID,readID1,readID2) ? (startOffset(contigID, readID1, readID2) <= @maxShortInsertOffset ? 'true' : 'false') : 'n.a.') + "\t" +
						fields[3].to_s + "\t" +
						"\n"
		}
		return
	end

	def loadMatePairInfoFile()
		@matePairInfo = {}
		BRL::Util::TextReader.new(@matePairInfoFile).each { |line|
			line.strip!
			next if(line =~ BLANK_RE or line =~ COMMENT_RE)
			fields = line.split("\t")
			@matePairInfo[fields[0]] = fields
		}
		return
	end

	def loadReadLengthsFile()
		@readLengths = {}
		BRL::Util::TextReader.new(@lengthsFile).each { |line|
			line.strip!
			next if(line =~ BLANK_RE or line =~ COMMENT_RE)
			fields = line.split(/\s+/)
			@readLengths[fields[0]] = fields[1].to_i
		}
		return
	end

	def loadContigSummaryFile()
		@contigData = {}
		reader = BRL::Util::TextReader.new(@contigsFile)
		parseState = START
		currBinID = nil
		currContigID = nil
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE)
			if((parseState == START or parseState == AF or parseState == BS) and (line =~ BIN_RE))
				currBinID = $1
				parseState = BIN
			elsif((parseState == BIN or parseState == AF or parseState == BS) and (line =~ CO_RE))
				currContigID = currBinID + '.' + $1
				@contigData[currContigID] = {}
				parseState = AF
			elsif((parseState == AF) and (line =~ AF_RE))
				readName = $1
				readOrient = $2
				readStart = $3.to_i
				@contigData[currContigID][readName] = [readStart, readOrient]
				parseState == AF
			elsif((parseState == AF or parseState == BS) and (line =~ BS_RE))
				# Don't Care about these lines
				parseState = BS
			end
		}
#		$stderr.puts "numContigs---->'#{@contigData.size}'"
#		$stderr.puts "check 00000.14359---->>> #{@contigData['00000.14359']} <<< but is it a key? >>> #{@contigData.key?('00000.14359').to_s} <<<"
#		$stderr.puts "check first: >>> #{@contigData[@contigData.keys.sort.first].inspect} <<< for key >>> #{@contigData.keys.sort.first.inspect} <<<"
		reader.close()
		return
	end

	def uBeforeC?(contigID, readID1, readID2)
		first = @contigData[contigID][readID1][READ_START] <= @contigData[contigID][readID2][READ_START] ?
									@contigData[contigID][readID1][READ_ORIENT] :
									@contigData[contigID][readID2][READ_ORIENT]
		return ((first =~ U_RE and matePairOrientOk?(contigID, readID1, readID2)) ? true : false)
	end
	
	def startOffset(contigID, readID1, readID2)
		startOffset = (@contigData[contigID][readID1][READ_START] - @contigData[contigID][readID2][READ_START]).abs
		return startOffset
	end

	def matePairGap(contigID, readID1, readID2)
		firstRead, lastRead = @contigData[contigID][readID1][READ_START] <= @contigData[contigID][readID2][READ_START] ?
									[readID1, readID2] :
									[readID2, readID1]
		endOfFirst = @contigData[contigID][firstRead][READ_START] + @readLengths[firstRead]
		gap = @contigData[contigID][lastRead][READ_START] - endOfFirst
		return gap
	end

	def insertSize(contigID, readID1, readID2)
		firstRead, lastRead = @contigData[contigID][readID1][READ_START] <= @contigData[contigID][readID2][READ_START] ?
									[readID1, readID2] :
									[readID2, readID1]
		startOfFirst = @contigData[contigID][firstRead][READ_START]
		endOfLast = @contigData[contigID][lastRead][READ_START] + @readLengths[lastRead]
		length = (endOfLast - startOfFirst) + 1
		return length
	end
	
	def matePairOrientOk?(contigID, readID1, readID2)
		begin
		retVal = 	@contigData[contigID][readID1][READ_ORIENT] == @contigData[contigID][readID2][READ_ORIENT] ?
							false :
							true
		rescue => err
			$stderr.puts "\nERROR: '#{contigID},#{readID1},#{readID2}':\n\tnumContigs: '#{@contigData.size}'\n\tcontigIDrec: '#{@contigData[contigID].inspect}'\n"
			raise err
		end
		return retVal
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--matePairInfoFile', '-m', GetoptLong::REQUIRED_ARGUMENT],
									['--readLengthsFile', '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--contigSummaryFile', '-c', GetoptLong::REQUIRED_ARGUMENT],
									['--maxMatePairGap', '-x', GetoptLong::REQUIRED_ARGUMENT],
									['--maxOffsetForShortInserts', '-s', GetoptLong::REQUIRED_ARGUMENT],
									['--minMatePairGap', '-n', GetoptLong::OPTIONAL_ARGUMENT],
									['--verbose', '-v', GetoptLong::OPTIONAL_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		PROP_KEYS.each {
			|propName|
			argPropName = "--#{propName}"
			optsArray << [argPropName, GetoptLong::OPTIONAL_ARGUMENT]
		}
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		usage() if(optsHash.empty? or optsHash.key?('--help'))
		@verbose = optsHash.key?('--verbose') ? true : false
		@matePairInfoFile = optsHash['--matePairInfoFile']
		@maxShortInsertOffset = optsHash['--maxOffsetForShortInserts'].to_i
		@lengthsFile = optsHash['--readLengthsFile']
		@contigsFile = optsHash['--contigSummaryFile']
		@minGap = optsHash['--minMatePairGap'][ /(-?\d+)/, 1 ].to_i
		@maxGap = optsHash['--maxMatePairGap'].to_i
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -m     => File with full mate pair info records.
    -l     => File with read lengths (in contigs) file.
    -c     => File with contig summary info.
    -x     => Max gap between mate pairs in a contig.
    -n     => Min gap between mate pairs in a contig.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-matePairConfigChecker.rb -m matePair.info.txt -l readLengths.txt -c contigInfo.txt -x 3000 -n '\-1200'
";
		exit(134);
	end
end

end ; end

checker = BRL::CAPSS::MatePairConfigChecker.new()
checker.run()
exit(0)
