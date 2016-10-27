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

class ReadRepFilter
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
		loadIndexFile()
		$stderr.puts "STATUS: loaded index file"
		cleanReadRep()
		$stderr.puts "STATUS: filtered reads by quality"
		return
	end

	def cleanReadRep()
		# For each bin
		@indices.keys.sort.each { |binID|
			# For each contig in the bin
			@indices[binID].keys.sort.each { |contigID|
				# For each index in the contig, delete unless passes criteria
				@indices[binID][contigID].delete_if { |bacID, fields|
					if(fields.nil?)
						$stderr.puts "ERROR: fields is nil. bacID is '#{bacID}'. contigID is '#{contigID}'. binID is '#{binID}'"
						exit(9)
					end
					unless(@indexOrders.key?(fields[7]))
						false # not one of the indexOrders we are filtering
					else
						# Count how many pools have at least min representation
						numPoolsWithMinRep = 0
						fields[6].each { |xx| numPoolsWithMinRep += 1 if(xx >= @minRep) }
						if(numPoolsWithMinRep >= @minPoolsWithMinRep)
							false
						else
							true
						end
					end
				}
				# For each index in the contig
				@indices[binID][contigID].each { |bacID, fields|
					# Output all non single pool indices
					fields[5] = fields[5].join(',')
					fields[6] = fields[6].join(',')
					fields[8] = fields[8].join(',')
					fields[9] = fields[9].join(',')
					fields = fields.join("\t")
					puts fields
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
									['--indexFile', '-i', GetoptLong::REQUIRED_ARGUMENT],
									['--minRep', '-r', GetoptLong::REQUIRED_ARGUMENT],
									['--minPoolsWithMinRep', '-p', GetoptLong::REQUIRED_ARGUMENT],
									['--indexOrders', '-x', GetoptLong::REQUIRED_ARGUMENT],
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
		@minRep = optsHash['--minRep'].to_i
		@minPoolsWithMinRep = optsHash['--minPoolsWithMinRep'].to_i
		@indexOrders = {}
		optsHash['--indexOrders'].split(',').each { |xx| @indexOrders[xx.to_i] = nil }
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -i     => File with capss indices
    -r     => Amount of minimum read representation from a pool
    -p     => Minimum number of pools having minimum read representation
    -x     => List of index orders to which the cut-offs apply
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-poolRepFilter.rb -o ./poolReads -i contigIndexes.txt -r 2 -p 2 -x 2,3
"
		exit(134)
	end
end

end ; end

filter = BRL::CAPSS::ReadRepFilter.new()
filter.run()
exit(0)

