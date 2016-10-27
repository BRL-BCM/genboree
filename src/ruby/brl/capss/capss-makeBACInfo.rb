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
require 'brl/fileFormats/aceFile'

module BRL ; module CAPSS

class DeconvBAC
	attr_accessor :bacID, :indices

	def initialize(bacID)
		@bacID = bacID
		@indices = []
	end

	def numReads(idxOrder=4, cummulative=false)
		numReads = 0
		indices.each { |idx|
			numReads += idx[8].size	if(	(cummulative and (idx[7] >= idxOrder)) or
																	(!cummulative and (idx[7] == idxOrder)))
		}
		return numReads
	end

	def numIndices(idxOrder=4, cummulative=false)
		numIndices = 0
		indices.each { |idx|
			numIndices += 1	if( (cummulative and (idx[7] >= idxOrder)) or
													(!cummulative and (idx[7] == idxOrder)))
		}
		return numIndices
	end

	def getReadsList(idxOrder=4, cummulative=false)
		readList = []
		indices.each { |idx|
			readList += idx[8]	if(	(cummulative and (idx[7] >= idxOrder)) or
															(!cummulative and (idx[7] == idxOrder)))
		}
		return readList
	end

	def getContigsList(idxOrder=4, cummulative=false)
		contigList = []
		indices.each { |idx|
			contigList << idx[2]	if(	(cummulative and (idx[7] >= idxOrder)) or
																(!cummulative and (idx[7] == idxOrder)))
		}
		return contigList
	end

	def sumContigsLength(idxOrder=4, cummulative=false)
		sum = 0
		indices.each { |idx|
			sum += idx[3]	if(	(cummulative and (idx[7] >= idxOrder)) or
												(!cummulative and (idx[7] == idxOrder)))
		}
		return sum
	end

	def n50Contigs(idxOrder=4, cummulative=false)
		sum = 0
		sumSqrs = 0
		indices.each { |idx|
			if(	(cummulative and (idx[7] >= idxOrder)) or
					(!cummulative and (idx[7] == idxOrder)))
				sum += idx[3]
				sumSqrs += idx[3] ** 2
			end
		}
		return (sumSqrs > 0) ? (sumSqrs.to_f / sum.to_f) : 0
	end

	def to_s
		asStr = @bacID + "\t" +
						sumContigsLength(4).to_s + "\t" +  # 1 - total contig lengths, idx = 4
						sumContigsLength(3).to_s + "\t" + # 2 - total contig lengths, idx = 3
						sumContigsLength(2).to_s + "\t" + # 3 - total contig lengths, idx = 2
						sumContigsLength(3, true).to_s + "\t" + # 4 - total contig lengths, idx >= 3
						sumContigsLength(2, true).to_s + "\t" + # 5 - total contig lengths, idx >= 2

						sprintf('%.2f', n50Contigs(4)) + "\t" +  # 6 - total contig n50, idx = 4
						sprintf('%.2f', n50Contigs(3)) + "\t" +  # 7 - total contig n50, idx = 3
						sprintf('%.2f', n50Contigs(2)) + "\t" +  # 8 - total contig n50, idx = 2
						sprintf('%.2f', n50Contigs(3, true)) + "\t" +  # 9 - total contig n50, idx >= 3
						sprintf('%.2f', n50Contigs(2, true)) + "\t" +  # 10 - total contig n50, idx >= 2

						numIndices(4).to_s + "\t" +  # 11 - num indices of order 4
						numIndices(3).to_s + "\t" +  # 12 - num indices of order 3
						numIndices(2).to_s + "\t" +  # 13 - num indices of order 2
						numIndices(3, true).to_s + "\t" +  # 14 - num indices >= 3
						numIndices(2, true).to_s + "\t" +  # 15 - num indices >= 2

						numReads(4).to_s + "\t" +  # 16 - num reads, idx = 4
						numReads(3).to_s + "\t" +  # 17 - num reads, idx = 3
						numReads(2).to_s + "\t" +  # 18 - num reads, idx = 2
						numReads(3, true).to_s + "\t" +  # 19 - num reads, idx >= 3
						numReads(2, true).to_s + "\t" +  # 20 - num reads, idx >= 2

						getReadsList(4).join(',') + "\t" + # 21 - readIDs list, idx = 4
						getReadsList(3).join(',') + "\t" + # 22 - readIDs list, idx = 3
						getReadsList(2).join(',') + "\t" + # 23 - readIDs list, idx = 2
						getReadsList(3, true).join(',') + "\t" + # 24 - readIDs list, idx >= 3
						getReadsList(2, true).join(',') + "\t" + # 25 - readIDs list, idx >= 2

						getContigsList(4).join(',') + "\t" + # 26 - contigIDs list, idx = 4
						getContigsList(3).join(',') + "\t" + # 27 - contigIDs list, idx = 3
						getContigsList(2).join(',') + "\t" + # 28 - contigIDs list, idx = 2
						getContigsList(3, true).join(',') + "\t" + # 29 - contigIDs list, idx >= 3
						getContigsList(2, true).join(',') + "\t" + # 30 - contigIDs list, idx >= 4

						'' # End of string
		return asStr
	end
end

class BacInfo
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	JOB_NAME_BASE = 'cicdc-'
	BLANK_RE = /^\s*$/
	BIN, CO, AF, START, BS = 0, 1, 2, 3, 4
	BIN_RE = /^BIN (?:.*\D)?(\d+)$/
	CO_RE = /^CO Contig(\d+)\s+(\d+)\s+(\d+)/ # 1=>ID, 2=>length, 3=>numReads
	AF_RE = /^AF (\S+)\s+(\S+)\s+(\S+)$/      # 1=>readName, 2=>dir, 3=>readStartInContig
	BS_RE = /^BS (\d+)\s+(\d+)\s+(\S+)$/      # 1=>start, 2=>stop, 3=>readName
	CONTIG_NUM_RE = /^\d+\.(\d+)$/

	COMMENT_RE = /^\s*#/
	IDX_HDR_RE = /^#?idxID/

	def initialize()
		@indexCount = 0
	end

	def run()
		$stderr.puts "STATUS: begin analysis"
		@params = processArguments()
		$stderr.puts "STATUS: processed args"
		loadIndexFile()
		$stderr.puts "STATUS: loaded index file"
		makeBacInfo()
		$stderr.puts "STATUS: generated info for each bac"
		dumpBacInfo()
		$stderr.puts "STATUS: dumped info for each bac"
		return
	end

	def makeBacInfo()
		@bacRecs = {}
		# For each bin
		@indices.keys.sort.each { |binID|
			$stderr.print '.' if(binID.to_i % 100 == 0)
			# For each contig in the bin
			@indices[binID].keys.sort.each { |contigID|
				# Examine each index
				@indices[binID][contigID].each { |bacID, fields|
					@bacRecs[bacID] = DeconvBAC.new(bacID) unless(@bacRecs.key?(bacID))
					@bacRecs[bacID].indices << fields
				}
			}
		}
		$stderr.puts ''
		return
	end

	def dumpBacInfo()
		@bacRecs.each { |bacID, bacRec|
			puts bacRec.to_s
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
			fields[3] = fields[3].to_i
			fields[6].map! { |xx| xx.to_i }
			@indices[fields[1]] = Hash.new() unless(@indices.key?(fields[1]))
			@indices[fields[1]][fields[2]] = Hash.new unless(@indices[fields[1]].key?(fields[2]))
			@indices[fields[1]][fields[2]][fields[4]] = fields
		}
		reader.close
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--indexFile', '-i', GetoptLong::REQUIRED_ARGUMENT],
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
		@indexFile = optsHash['--indexFile']
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -i     => File with capss indices
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-makeBACInfo.rb -i contigIndexes.txt
"
		exit(134)
	end
end

end ; end

info = BRL::CAPSS::BacInfo.new()
info.run()
exit(0)
