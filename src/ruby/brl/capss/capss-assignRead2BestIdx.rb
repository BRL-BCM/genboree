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

class ReadInContig
	attr_accessor :name, :name, :start
	attr_accessor :asmDetails

	def initialize(readName, contigName, startLoc)
		@name, @contig, @start = readName, contigName, startLoc
		@asmDetails = []
	end

	def addAssemblyDetail(start, stop)
		@asmDetails << [start, stop]
		return
	end
end

class Read2BestIdxAssigner
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	JOB_NAME_BASE = 'carbi-'
	BLANK_RE = /^\s*$/
	BIN, CO, AF, START, BS = 0, 1, 2, 3, 4
	BIN_RE = /^BIN (?:.*\D)?(\d+)$/
	CO_RE = /^CO Contig(\d+)\s+(\d+)\s+(\d+)/ # 1=>ID, 2=>length, 3=>numReads
	AF_RE = /^AF (\S+)\s+(\S+)\s+(\S+)$/      # 1=>readName, 2=>dir, 3=>readStartInContig
	BS_RE = /^BS (\d+)\s+(\d+)\s+(\S+)$/      # 1=>start, 2=>stop, 3=>readName
	COMMENT_RE = /^\s*#/
	IDX_HDR_RE = /^#?idxID/

	def initialize()
		@indexCount = 0
	end

	def run()
		$stderr.puts "STATUS: begin analysis"
		@params = processArguments()
		$stderr.puts "STATUS: processed args"
#		loadContigsFile()
#		$stderr.puts "STATUS: loaded contig file"
		loadIndexFile()
		$stderr.puts "STATUS: loaded index file"
		cleanRead2Idx()
		$stderr.puts "STATUS: assigned each read to it's highest class index(es)"
		return
	end

	def cleanRead2Idx()
		bestReadIdx = {}
		# For each bin
		@indices.keys.sort.each { |binID|
			# For each contig in the bin
			@indices[binID].keys.sort.each { |contigID|
				bestReadIdx.clear
				# For each bac/index in the contig
				@indices[binID][contigID].each { |bacID, fields|
					# Look at each read and find its highest order index
					fields[8].each { |readID|
						idxOrder = fields[7]
						bestReadIdx[readID] = idxOrder if(!bestReadIdx.key?(readID) or (bestReadIdx[readID] < idxOrder))
					}
				}
				# For each index in the contig
				@indices[binID][contigID].each { |bacID, fields|
					# Look at each read and find its highest order index
					if(fields.nil?)
						$stderr.puts "ERROR: fields is nil. bacID is '#{bacID}'. contigID is '#{contigID}'. binID is '#{binID}'"
						exit(9)
					end
					fields[8].delete_if { |readID|
						if(fields[7] != bestReadIdx[readID])
							# Correct the pool count
							proj = readID[0,4]
							poolIdx = fields[5].index(proj)
							oldReadCount = fields[6][poolIdx]
							fields[6][poolIdx] -= 1
							if(fields[6][poolIdx] == 0 and oldReadCount > 0)
								fields[7] -= 1
							end
							true
						else
							false
						end
					}
				}
				# For each index in the contig
				@indices[binID][contigID].each { |bacID, fields|
					# Output all non single pool indices
					if(fields[7] > 1)
						fields[5] = fields[5].join(',')
						fields[6] = fields[6].join(',')
						fields[8] = fields[8].join(',')
						fields[9] = fields[9].join(',')
						fields = fields.join("\t")
						puts fields
					end
				}
			}
		}
		return
	end

	def loadIndexFile()
		@indices = {}
		reader = BRL::Util::TextReader.new(@indexFile)
		parseState = START
		currBinID = nil
		currContigID = nil
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE or line =~ COMMENT_RE or line =~ IDX_HDR_RE)
			fields = line.split("\t")
			fields[5] = fields[5].split(',') # pool list
			fields[6] = fields[6].split(',') # num reads from pool in contig/index
			fields[8] = fields[8].split(',') # read list
			fields[9] = fields[9].split(',') # read starts
			fields[7] = fields[7].to_i
			fields[6].map! { |xx| xx.to_i }
			@indices[fields[1]] = Hash.new() unless(@indices.key?(fields[1]))
			@indices[fields[1]][fields[2]] = Hash.new unless(@indices[fields[1]].key?(fields[2]))
			@indices[fields[1]][fields[2]][fields[4]] = fields
		}
		reader.close
		return
	end

	def loadContigsFile()
		@contigData = {}
#		@contigLengths = {}
#		@contigNumReads = {}
#		@readStarts = {}
		reader = BRL::Util::TextReader.new(@contigsFile)
		parseState = START
		currBinID = nil
		currContigID = nil
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE)
			if((parseState == START or parseState == BS) and (line =~ BIN_RE)) # Then correctly found a bin
				currBinID = $1
				@contigData[currBinID] = {}
				parseState = BIN
				#$stderr.puts "BIN: #{currBinID}"
			elsif((parseState == BIN or parseState == BS) and (line =~ CO_RE)) # Then correctly found a contig
				currContigID = currBinID + '.' + $1
				contigLength = $2.to_i
				numReads = $3.to_i
#				@contigLengths[currContigID] = contigLength
#				@contigNumReads[currContigID] = numReads
				@contigData[currBinID][currContigID] = {}
				parseState = AF
				#$stderr.puts "CONTIG: #{currContigID}"
			elsif((parseState == AF) and (line =~ AF_RE))                     # Then correctly found an AF line
				read = ReadInContig.new($1, currContigID, $3.to_i)
				@contigData[currBinID][currContigID][read.name] = read
#				if(@readStarts.key?(read.name))
#					raise "\n\nERROR: The read '#{readName}' is assembled into multiple contigs. Not expected/allowed."
#				end
#				@readStarts[read.name] = read.start
				parseState == AF
			elsif((parseState == AF or parseState == BS) and (line =~ BS_RE))
				@contigData[currBinID][currContigID][$3].addAssemblyDetail($1.to_i, $2.to_i)
				parseState = BS
			end
		}
		reader.close()
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--outDir', '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--indexFile', '-i', GetoptLong::REQUIRED_ARGUMENT],
									['--contigFile', '-c', GetoptLong::REQUIRED_ARGUMENT],
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
		@contigsFile = optsHash['--contigFile']
		@indexFile = optsHash['--indexFile']
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -o     => Where to put any output that doesn't go to stdout or stderr.
    -i     => File with capss indices
    -c     => File with contig structure info (CO and AF and BS lines)
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-assignRead2bestIdx.rb -o ./poolReads -i contigIndexes.txt -c allContigsWithStructInfo.txt
";
		exit(134);
	end
end

end ; end

assigner = BRL::CAPSS::Read2BestIdxAssigner.new()
assigner.run()
exit(0)

