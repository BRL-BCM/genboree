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

class PoolInfoRec
	attr_accessor :poolID, :bacInfoRecs

	def initialize(poolID)
		@poolID = poolID
		@bacInfoRecs = []
	end

	def numBacs(idxOrder=4, cummulative=false)
		ii =	case idxOrder
						when 4 then 16
						when 3 then (cummulative ? 19 : 17)
						when 2 then (cummulative ? 20 : 18)
					end
		numBacs = 0
		@bacInfoRecs.each { |rec|
			numBacs += 1 if(rec[ii] > 0)
		}
		return numBacs
	end

	def readsByBac(idxOrder=4, cummulative=false)
		ii = case idxOrder
					when 4 then 21
					when 3 then (cummulative ? 24 : 22)
					when 2 then (cummulative ? 25 : 23)
				end
		readCounts = []
		@bacInfoRecs.each { |rec|
			readCount = 0
			rec[ii].each { |read|
				proj = read[0,4]
				next unless(proj == poolID)
				readCount += 1
			}
			readCounts << readCount
		}
		return readCounts
	end

	def bacList(idxOrder=4, cummulative=false)
		ii =	case idxOrder
						when 4 then 16
						when 3 then (cummulative ? 19 : 17)
						when 2 then (cummulative ? 20 : 18)
					end
		bacList = []
		@bacInfoRecs.each { |rec|
			bacList << rec[0] if(rec[ii] >= 0)
		}
		return bacList
	end

	def to_s()
		asStr = @poolID + "\t" +
						numBacs(4).to_s + "\t" +
						numBacs(3).to_s + "\t" +
						numBacs(2).to_s + "\t" +
						numBacs(3, true).to_s + "\t" +
						numBacs(2, true).to_s + "\t" +

						readsByBac(3, true).join(',')  + "\t" +
						readsByBac(2, true).join(',')  + "\t" +

						bacList(3, true).join(',') + "\t" +
						bacList(2, true).join(',') + "\t" +

						''
		return asStr
	end
end

class PoolInfo
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
		loadInfoFile()
		$stderr.puts "STATUS: loaded bac info file"
		makePoolInfo()
		$stderr.puts "STATUS: generated info for each pool"
		dumpPoolInfo()
		$stderr.puts "STATUS: dumped info for each pool"
		return
	end

	def makePoolInfo()
		@poolRecs = {}
		seenPools = {}
		# For each bac
		@infoRecs.keys.sort.each { |bacID|
			$stderr.print '.' if(bacID.to_i % 10 == 0)
			# For each infoRec for the bac
			@infoRecs[bacID].each { |infoRec|
				# Put this infoRec into each pool involved
				seenPools.clear
				infoRec[25].each { |read|
					proj = read[0,4]
					next if(seenPools.key?(proj))
					@poolRecs[proj] = PoolInfoRec.new(proj) unless(@poolRecs.key?(proj))
					@poolRecs[proj].bacInfoRecs << infoRec
					seenPools[proj] = ''
				}
			}
		}
		$stderr.puts ''
		return
	end

	def dumpPoolInfo()
		@poolRecs.keys.sort.each { |poolID|
			poolRec = @poolRecs[poolID]
			puts poolRec.to_s
		}
		return
	end

	def loadInfoFile()
		@infoRecs = {}
		reader = BRL::Util::TextReader.new(@infoFile)
		parseState = START
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE or line =~ COMMENT_RE)
			fields = line.split("\t")
			(21..30).each { |ii| fields[ii] = fields[ii].split(',') }
			(1..5).each { |ii| fields[ii] = fields[ii].to_i }
			(6..10).each { |ii| fields[ii] = fields[ii].to_f }
			(11..20).each { |ii| fields[ii] = fields[ii].to_i }
			@infoRecs[fields[0]] = [] unless(@infoRecs.key?(fields[0]))
			@infoRecs[fields[0]] << fields
		}
		reader.close
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--infoFile', '-i', GetoptLong::REQUIRED_ARGUMENT],
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
		@infoFile = optsHash['--infoFile']
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -i     => File with bac deconvolution info records
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-makePoolInfo.rb -i bacInfo.clearDeconvContigs.txt
"
		exit(134)
	end
end

end ; end

info = BRL::CAPSS::PoolInfo.new()
info.run()
exit(0)
