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

class DeconvoluteFromAceSummary
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
	BIN, CO, AF, START, BS = 0, 1, 2, 3, 4
	BIN_RE = /^BIN (?:.*\D)?(\d+)$/
	CO_RE = /^CO Contig(\d+)\s+(\d+)\s+(\d+)/ # 1=>ID, 2=>length, 3=>numReads
	AF_RE = /^AF (\S+)\s+(\S+)\s+(\S+)$/      # 1=>readName, 2=>dir, 3=>readStartInContig
	BS_RE = /^BS (\d+)\s+(\d+)\s+(\S+)$/      # 1=>start, 2=>stop, 3=>readName

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
		loadContigsFile()
		$stderr.puts "STATUS: loaded contig summary file covering #{@contigData.size} bins"
		deconvoluteContigs()
		$stderr.puts "STATUS: deconvoluted and wrote out all indices"
		return
	end

	def loadContigsFile()
		@contigData = {}
		@contigLengths = {}
		@contigNumReads = {}
		@readStarts = {}
		reader = BRL::Util::TextReader.new(@contigsFile)
		parseState = START
		currBinID = nil
		currContigID = nil
		reader.each { |line|
			line.strip
			next if(line =~ BLANK_RE)
			if((parseState == START or parseState == AF) and (line =~ BIN_RE))
				currBinID = $1
				@contigData[currBinID] = {}
				parseState = BIN
				#$stderr.puts "BIN: #{currBinID}"
			elsif((parseState == BIN or parseState == AF) and (line =~ CO_RE))
				currContigID = currBinID + '.' + $1
				contigLength = $2.to_i
				numReads = $3.to_i
				@contigLengths[currContigID] = contigLength
				@contigNumReads[currContigID] = numReads
				@contigData[currBinID][currContigID] = {}
				parseState = AF
				#$stderr.puts "CONTIG: #{currContigID}"
			elsif((parseState == AF) and (line =~ AF_RE))
				readName = $1
				readStart = $2.to_i
				@contigData[currBinID][currContigID][readName] = readStart
				if(@readStarts.key?(readName))
					raise "\n\nERROR: The read '#{readName}' is assembled into multiple contigs. Not expected/allowed."
				end
				@readStarts[readName] = readStart
				parseState == AF
			end
		}
		reader.close()
		return
	end

	def deconvoluteContigs()
		idxWriter = BRL::Util::TextWriter.new(@params['--outDir'] + '/' + 'capssIndicesForContigs.txt')
		cSummaryWriter = BRL::Util::TextWriter.new(@params['--outDir'] + '/' + 'summary.capssContigs.txt')
		idxWriter.puts "#idxID\tbinID\tcontigID\tcontigLength\tbacID\tpoolsForBac\treadsPerPool\t#Pools\treadList\treadStartsInContig"
		cSummaryWriter.puts "binID\tcontigID\tcontigLength\ttotalReadsInContig\ttotalNumPools\ttotalNumBacsWithIdx\tnumBacsWith2PoolIdx\tnumBacsWith3PoolIdx\tnumBacsWith4PoolIdx\tbacList\tidxOrder"
		@indices = []
		indexedBacsInContig = {}
		readsInIndex = {}
		readStarts = {}
		@contigData.each { |binID, contigs|
			$stderr.puts "BIN: #{binID}"
			contigs.each { |contigID, reads|
				summRec = Array.new(11)
				summRec[0] = binID
				summRec[1] = contigID
				summRec[2] = @contigLengths[contigID]
				summRec[3] = @contigNumReads[contigID]
				allPools = {}
				allBacs = {}
				indexTypeCounts = {}
				$stderr.puts "\tCONTIG: #{contigID}"
				indexedBacsInContig.clear()
				readsInIndex.clear()
				readStarts.clear()
				reads.each { |readID, startPos|
					pool = readID[0,4]
					allPools[pool] = nil
					@clonePools.each { |cloneID, poolsHash|
						next unless(poolsHash.key?(pool))
						# This read is from pool containing this BAC
						indexedBacsInContig[cloneID] = {} unless(indexedBacsInContig.key?(cloneID))
						indexedBacsInContig[cloneID][pool] = 0 unless(indexedBacsInContig[cloneID].key?(pool))
						indexedBacsInContig[cloneID][pool] += 1
						readsInIndex[cloneID] = [] unless(readsInIndex.key?(cloneID))
						readsInIndex[cloneID] << readID
						readStarts[cloneID] = [] unless(readStarts[cloneID])
						readStarts[cloneID] << startPos
					}
				}
				# Save all indices that have at least 2 pools
				next if(indexedBacsInContig.empty?)
				indexedBacsInContig.each { |bacID, pools|
					next if(pools.size < 2)
					allBacs[bacID] = pools.size
					indexTypeCounts[pools.size] = 0 unless(indexTypeCounts.key?(pools.size))
					indexTypeCounts[pools.size] += 1

					# This bac has an index to this contig
					indexRec = Array.new(10)
					indexRec[0] = @indexCount += 1
					indexRec[1] = binID
					indexRec[2] = contigID
					indexRec[3] = @contigLengths[contigID]
					indexRec[4] = bacID
					poolsForBac = @clonePools[bacID].keys.sort
					readsPerPool = Array.new(poolsForBac.size)
					indexRec[5] = poolsForBac.join(',')
					ii = 0
					poolsForBac.each { |poolID, val|
						readsPerPool[ii] = (pools.key?(poolID) ? pools[poolID] : 0)
						ii += 1
					}
					indexRec[6] = readsPerPool.join(',')
					indexRec[7] = pools.size
					indexRec[8] = readsInIndex[bacID].join(',')
					indexRec[9] = readStarts[bacID].join(',')
					idxWriter.puts indexRec.join("\t")
					indexRec.clear()
					poolsForBac.clear()
					readsPerPool.clear()
				}
				summRec[4] = allPools.size
				summRec[5] = allBacs.size
				summRec[6] = indexTypeCounts.key?(2) ? indexTypeCounts[2] : 0
				summRec[7] = indexTypeCounts.key?(3) ? indexTypeCounts[3] : 0
				summRec[8] = indexTypeCounts.key?(4) ? indexTypeCounts[4] : 0
				summRec[9] = allBacs.keys.sort.join(',')
				idxOrders = []
				allBacs.keys.sort.each { |bac| idxOrders << allBacs[bac] }
				summRec[10] = idxOrders.join(',')
				idxOrders.clear()
				cSummaryWriter.puts summRec.join("\t")
				summRec.clear()
				allPools.clear()
				allBacs.clear()
				indexTypeCounts.clear()
			}

		}
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
									['--outDir', '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--arrayList', '-a', GetoptLong::REQUIRED_ARGUMENT],
									['--layoutDir', '-l', GetoptLong::REQUIRED_ARGUMENT],
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
		@outDir = optsHash.key?('--outDir') ? optsHash['--outDir'] : OUT_DIR
		@contigsFile = optsHash['--contigFile']
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
    -o     => Where to put any output that doesn't go to stdout or stderr.
    -a     => Comma separated list of array numbers to get from database
    -l     => Dir where the array layout files (from capss-get-arrayLayouts) can be found.
		-c     => Name of contig file with content summary for all ace files
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-deconvolute-fromAceContigSummary.rb -o ./poolReads -l ./mapsAndIndices -a 23,24
";
		exit(134);
	end
end

end ; end

deconvoluter = BRL::CAPSS::DeconvoluteFromAceSummary.new()
deconvoluter.run()
exit(0)
