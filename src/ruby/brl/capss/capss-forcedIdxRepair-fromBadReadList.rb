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

class ReadStripper
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
		loadRepairList()
		$stderr.puts 'STATUS: loaded repair list'
		loadIndexFile()
		$stderr.puts "STATUS: loaded index file"
		stripReads()
		$stderr.puts "STATUS: forcibly removed reads from indices."
		return
	end

	def loadRepairList()
		@badReads = {}
		BRL::Util::TextReader.new(@repairFileName).each { |line|
			line.strip!
			next if(line =~ BLANK_RE or line =~ COMMENT_RE)
			@badReads[line] = ''
		}
		return
	end

	def stripReads()
		# For each bin
		@indices.keys.sort.each { |binID|
			# For each contig in the bin
			@indices[binID].keys.sort.each { |contigID|
				# For each bac/index in the contig
				@indices[binID][contigID].each { |bacID, fields|
					# Look at each read and remove it if it is known to be 'bad'
					if(fields.nil?)
						$stderr.puts "ERROR: fields is nil. bacID is '#{bacID}'. contigID is '#{contigID}'. binID is '#{binID}'"
						exit(9)
					end
					fields[8].delete_if { |readID|
						if(@badReads.key?(readID))
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

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--outDir', '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--indexFile', '-i', GetoptLong::REQUIRED_ARGUMENT],
									['--badReadList', '-b', GetoptLong::REQUIRED_ARGUMENT],
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
		@repairFileName = optsHash['--badReadList']
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
    -b     => File with list of bad reads
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-forcedIdxRepair-fromBadReadList.rb -o ./poolReads -i contigIndexes.txt -b badReadList.txt
";
		exit(134);
	end
end

end ; end

stripper = BRL::CAPSS::ReadStripper.new()
stripper.run()
exit(0)

