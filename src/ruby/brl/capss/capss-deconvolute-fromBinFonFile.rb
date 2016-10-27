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

class DeconvoluteFromBinFon
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	JOB_NAME_BASE = 'cfppr-'
	OUT_DIR = 'reads'
	NODE_RE = /^(\S+)(?:\s+((?:\S+\s+\{\S+\}\s*)+))*$/
	EDGE_RE = /(\S+)\s+(\{\S+\})/
	BLANK_RE = /^\s*$/
	GRAPH_OUT_FILE = 'noRepeats.noProblematic.reads.graph'
	NOT_PROB_FON = 'noRegRepeats.noProblematic.reads.fon'
	PROB_FON = 'problematic.reads.fon'
	BIN, CO, AF, START = 0, 1, 2, 3
	BIN_RE = /^BIN (\d+)/
	CO_RE = /^CO Contig(\d+)\s+(\d+)\s+(\d+)/
	AF_RE = /^AF (\S+)\s+\S+\s+(\S+)$/
	BINID_RE = /.+_(\d+)\.bin/

	def initialize()
		@colPools = {}
		@rowPools = {}
		@arrayLayout = {}
		@indexCount = 0
	end

	def run()
		@params = processArguments()
		loadArrayLayouts()
		$stderr.puts "STATUS: loaded array layouts"
		makeIntersectingPoolLists()
		$stderr.puts "STATUS: found intersecting pools"
		deconvoluteBins()
		$stderr.puts "STATUS: deconvoluted and wrote out all indices"
		return
	end

	def deconvoluteBins()
		origDir = Dir.pwd()
		Dir.chdir(@topDir)
		binDirs = Dir.glob(@dirPattern)
		binDirs.each { |binDir|
			fonFile = "#{binDir}/#{File.basename(binDir)}.fon"
			deconvoluteBin(fonFile, binDir)
		}
		Dir.chdir(origDir)
		return
	end

	def deconvoluteBin(fonFile, binDir)
		binDir =~ BINID_RE
		binID = $1
		return if(binID == '00000')
		$stderr.puts "BIN: #{binID}"
		reader = BRL::Util::TextReader.new(fonFile)
		idxWriter = BRL::Util::TextWriter.new(binDir + '/' + 'capssIndicesForBIN.txt')
		cSummaryWriter = BRL::Util::TextWriter.new(binDir + '/' + 'summary.capssBIN.txt')
		idxWriter.puts "#idxID\tbinID\tbinSize\tbacID\tpoolsForBac\treadsPerPool\t#Pools\treadList"
		cSummaryWriter.puts "binID\tbinSize\ttotalNumPools\ttotalNumBacsWithIdx\tnumBacsWith2PoolIdx\tnumBacsWith3PoolIdx\tnumBacsWith4PoolIdx\tbacList\tidxOrder"
		@indices = []
		indexedBacsInBin = {}
		readsInIndex = {}
		allPools = {}
		allBacs = {}
		indexTypeCounts = {}
		readsInBin = 0
		summRec = Array.new(9)
		summRec[0] = binID
		summRec[1] = 0
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE)
			summRec[1] += 1
			pool = line[0,4]
			allPools[pool] = nil
			@clonePools.each { |cloneID, poolsHash|
				next unless(poolsHash.key?(pool))
				# This read is from pool containing this BAC
				indexedBacsInBin[cloneID] = {} unless(indexedBacsInBin.key?(cloneID))
				indexedBacsInBin[cloneID][pool] = 0 unless(indexedBacsInBin[cloneID].key?(pool))
				indexedBacsInBin[cloneID][pool] += 1
				readsInIndex[cloneID] = [] unless(readsInIndex.key?(cloneID))
				readsInIndex[cloneID] << line
			}
		}
		# Save all indices that have at least 2 pools
		return if(indexedBacsInBin.empty?)
		indexedBacsInBin.each { |bacID, pools|
			next if(pools.size < 2)
			allBacs[bacID] = pools.size
			indexTypeCounts[pools.size] = 0 unless(indexTypeCounts.key?(pools.size))
			indexTypeCounts[pools.size] += 1
			# This bac has an index to this contig
			indexRec = Array.new(8)
			indexRec[0] = @indexCount += 1
			indexRec[1] = binID
			indexRec[2] = summRec[1]
			indexRec[3] = bacID
			poolsForBac = @clonePools[bacID].keys.sort
			readsPerPool = Array.new(poolsForBac.size)
			indexRec[4] = poolsForBac.join(',')
			ii = 0
			poolsForBac.each { |poolID, val|
				readsPerPool[ii] = (pools.key?(poolID) ? pools[poolID] : 0)
				ii += 1
			}
			indexRec[5] = readsPerPool.join(',')
			indexRec[6] = pools.size
			indexRec[7] = readsInIndex[bacID].join(',')
			idxWriter.puts indexRec.join("\t")
			indexRec.clear()
			poolsForBac.clear()
			readsPerPool.clear()
		}
		summRec[2] = allPools.size
		summRec[3] = allBacs.size
		summRec[4] = indexTypeCounts.key?(2) ? indexTypeCounts[2] : 0
		summRec[5] = indexTypeCounts.key?(3) ? indexTypeCounts[3] : 0
		summRec[6] = indexTypeCounts.key?(4) ? indexTypeCounts[4] : 0
		summRec[7] = allBacs.keys.sort.join(',')
		idxOrders = []
		allBacs.keys.sort.each { |bac| idxOrders << allBacs[bac] }
		summRec[8] = idxOrders.join(',')
		idxOrders.clear()
		cSummaryWriter.puts summRec.join("\t")
		summRec.clear()
		allPools.clear()
		allBacs.clear()
		indexTypeCounts.clear()
		idxWriter.close()
		cSummaryWriter.close()
		return
	end

	def loadArrayLayouts()
		@params['--arrayList'].each { |arrayID|
			# open layout file
			layoutFileName = "#{@params['--layoutDir']}/array.#{arrayID}.layout.txt"
			reader = BRL::Util::TextReader.new(layoutFileName)
			# skip header row
			reader.readline()
			# grab col pools row
			fields = reader.readline().split("\t")
			fields.shift ; fields.shift
			fields.map! { |aa| aa.strip }
			fields.delete_if { |aa| aa.empty? }
			@colPools[arrayID] = fields
			@rowPools[arrayID] = []
			# process row pool lines
			@arrayLayout[arrayID] = []
			reader.each { |line|
				line.strip!
				next if(line =~ /^\s*$/ or line =~ /^\s*#/)
				fields = line.split("\t")
				fields.shift
				fields.map! { |aa| aa.strip }
				@rowPools[arrayID] << fields.shift
				@arrayLayout[arrayID] << fields
			}
			reader.close()
		}
		return
	end

	def makeIntersectingPoolLists()
		@intersectingPools = {}
		@rowPoolContents = {}
		@colPoolContents = {}
		@clonePools = {}
		@rowPools.keys.each { |arrayID|
			@rowPools[arrayID].size.times { |ii|
				rowPool = @rowPools[arrayID][ii]
				@rowPoolContents[rowPool] = {} unless(@rowPoolContents.key?(rowPool))
				@colPools[arrayID].size.times { |jj|
					colPool = @colPools[arrayID][jj]
					@colPoolContents[colPool] = {} unless(@colPoolContents.key?(colPool))
					cloneID = @arrayLayout[arrayID][ii][jj]
					@rowPoolContents[rowPool][cloneID] = nil
					@colPoolContents[colPool][cloneID] = nil
					@clonePools[cloneID] = {} unless(@clonePools.key?(cloneID))
					@clonePools[cloneID][rowPool] = nil
					@clonePools[cloneID][colPool] = nil
				}
			}
		}
		# Find intersecting using contents
		@clonePools.each { |cloneID, poolHash|
			poolIDs = poolHash.keys
			poolIDs.each_index { |ii|
				poolID = poolIDs[ii]
				@intersectingPools[poolID] = {} unless(@intersectingPools.key?(poolID))
				poolIDs.each_index { |jj|
					intPoolID = poolIDs[jj]
					next if(intPoolID == poolID)
					@intersectingPools[poolID][intPoolID] = nil
				}
			}
		}
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--topDir', '-t', GetoptLong::REQUIRED_ARGUMENT],
									['--arrayList', '-a', GetoptLong::REQUIRED_ARGUMENT],
									['--layoutDir', '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--dirPattern', '-d', GetoptLong::REQUIRED_ARGUMENT],
									['--fonPattern', '-f', GetoptLong::REQUIRED_ARGUMENT],
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
		optsHash['--arrayList'] = optsHash['--arrayList'].split(',')
		@verbose = optsHash.key?('--verbose') ? true : false
		@topDir = optsHash.key?('--topDir') ? optsHash['--topDir'] : OUT_DIR
		@contigsFile = optsHash['--contigFile']
		@dirPattern = optsHash['--dirPattern']
		@fonPattern = optsHash['--fonPattern']
		usage() unless(optsHash['--arrayList'].size > 0)
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -t     => Top level dir where each bin sub-dir is.
    -a     => Comma separated list of array numbers to get from database
    -l     => Dir where the array layout files (from capss-get-arrayLayouts) can be found.
    -f     => Pattern for bin's fon file
    -d     => Pattern for bin dirs
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-deconvolute-fromBinFonFile.rb -o ./poolReads -l ./mapsAndIndices -a 23,24
";
		exit(134);
	end
end

end ; end

deconvoluter = BRL::CAPSS::DeconvoluteFromBinFon.new()
deconvoluter.run()
exit(0)
