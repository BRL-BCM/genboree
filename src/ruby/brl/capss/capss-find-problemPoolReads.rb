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

class ProblemPoolReadFinder
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

	def initialize()
		@colPools = {}
		@rowPools = {}
		@arrayLayout = {}
		@overlapGraph = {}
		@readRE = nil
	end

	def run()
		@params = processArguments()
		loadArrayLayouts()
		$stderr.puts "STATUS: loaded array layouts"
		makeIntersectingPoolLists()
		$stderr.puts "STATUS: found intersecting pools"
		loadGraphFile()
		$stderr.puts "STATUS: loaded graph file"
		findProblemPoolReads()
		$stderr.puts "STATUS: found problem reads"
		getProblemPoolReadStats()
		$stderr.puts "STATUS: got problematic pool read stats"
		dumpProblemPoolReadLists()
		$stderr.puts "STATUS: dumpbed lists of non-problematic and problematic pool reads"
		dumpProblemPoolReadsStats()
		$stderr.puts "STATUS: dumped problematic pool read stats"
		removeProblemRepeats()
		$stderr.puts "STATUS: removed problem repeats"
		dumpGraph(GRAPH_OUT_FILE)
		$stderr.puts "STATUS: dumped non-problematic pool read graph"
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

	def loadGraphFile()
		reader = BRL::Util::TextReader.new(@params['--graphFile'])
		nodeCount = 0
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE)
			next if(!@readRE.nil? and (line !~ @readRE))
			nodeCount +=1
			# parse the node label from edges
			if(line =~ NODE_RE)
				readID = $1
				@overlapGraph[readID] = {} unless(@overlapGraph.key?(readID))
				# parse edges
				next if($2.nil?)
				edgeStr = $2
				edgeStr.scan(EDGE_RE) { |subMatches|
					next if(subMatches[0] == readID) # self-to-self edge
					@overlapGraph[readID][subMatches[0]] = subMatches[1]
				}
			else
				raise "WARNING: the following line doesn't look like a node line:\n\t#{line}"
			end
			$stderr.print '.' if(nodeCount % 10000 == 0)
		}
		$stderr.puts ''
		reader.close()
		return
	end

	def	findProblemPoolReads()
		@readParallelPoolOverlaps = {}
		@readIntersectPoolOverlaps = {}
		@readSamePoolOverlaps = {}
		@overlapGraph.each { |readID, edges|
			@readIntersectPoolOverlaps[readID] = {} unless(@readIntersectPoolOverlaps.key?(readID))
			@readParallelPoolOverlaps[readID] = {} unless(@readParallelPoolOverlaps.key?(readID))
			@readSamePoolOverlaps[readID] = 0
			poolID = readID[0,4]
			intersectingPools = @intersectingPools[poolID]
			edges.each { |ovlReadID, infoStr|
				ovlPoolID = ovlReadID[0,4]
				if(intersectingPools.key?(ovlPoolID)) # overlaps an intersecting pool
					@readIntersectPoolOverlaps[readID][ovlPoolID] = 0 unless(@readIntersectPoolOverlaps[readID].key?(ovlPoolID))
					@readIntersectPoolOverlaps[readID][ovlPoolID] += 1
				elsif(poolID == ovlPoolID) # overlaps within this pool
					@readSamePoolOverlaps[readID] += 1
				else # must be a parallel pool overlap
					@readParallelPoolOverlaps[readID][ovlPoolID] = 0 unless(@readParallelPoolOverlaps[readID].key?(ovlPoolID))
					@readParallelPoolOverlaps[readID][ovlPoolID] += 1
				end
			}
		}
		return
	end

	def getProblemPoolReadStats()
		# total num reads in overlap graph
		@numReadsInGraph = @overlapGraph.size
		# total num reads overlapping within the pool only or are singletons
		@numReadsOnlySamePool = 0
		@overlapGraph.each { |readID, edges|
			next unless(@readIntersectPoolOverlaps[readID].empty?)
			next unless(@readParallelPoolOverlaps[readID].empty?)
			# then must have overlaps within its pool or be a signleton
			@numReadsOnlySamePool += 1
		}
		# total num reads with more than max allowed parallel pool overlaps
		# total num reads with more than max allowed intersecting pool overlaps
		@numReadsTooManyParallelPools = 0
		@numReadsTooManyIntersectPools = 0
		@problematicReads = {}
		@overlapGraph.each { |readID, edges|
			if(@readParallelPoolOverlaps.key?(readID) and @readParallelPoolOverlaps[readID].size > @maxParallelPools)
				@numReadsTooManyParallelPools += 1
				@problematicReads[readID] = nil
			end
			if(@readIntersectPoolOverlaps.key?(readID) and @readIntersectPoolOverlaps[readID].size > @maxIntersectPools)
				@numReadsTooManyIntersectPools += 1
				@problematicReads[readID] = nil
			end
		}
		@numProblematicReads = @problematicReads.size
		return
	end

	def dumpProblemPoolReadLists()
		okWriter = BRL::Util::TextWriter.new(@outDir + '/' + NOT_PROB_FON)
		probWriter = BRL::Util::TextWriter.new(@outDir + '/' + PROB_FON)
		@overlapGraph.each { |readID, edges|
			if(@problematicReads.key?(readID))
				probWriter.puts readID
			else
				okWriter.puts readID
			end
		}
		okWriter.close()
		probWriter.close()
		return
	end

	def dumpProblemPoolReadsStats()
		puts "Total number of reads in original overlap graph: #{@numReadsInGraph}"
		puts "Total number of reads with overlaps only in their own pool: #{@numReadsOnlySamePool}"
		puts "Total number of reads with overlaps in more than #{@maxParallelPools} parallel pools: #{@numReadsTooManyParallelPools}"
		puts "Total number of reads with overlaps in more than #{@maxIntersectPools} intersecting pools: #{@numReadsTooManyIntersectPools}"
		puts '-'*50
		puts "Total number of problematic reads: #{@numProblematicReads}"
		puts "Total number of ok reads: #{@numReadsInGraph - @numProblematicReads}"
		return
	end

	def removeProblemRepeats()
		@overlapGraph.keys.each { |readID|
			if(@problematicReads.key?(readID))
				@overlapGraph.delete(readID)
			end
		}
		return
	end

	def dumpGraph(fileName)
		outFile = "#{@outDir}/#{fileName}"
		writer = BRL::Util::TextWriter.new("#{outFile}")
		@overlapGraph.each { |readID, edges|
			# next if(edges.empty?)
			writer.print readID
			edges.each { |adjReadID, infoStr|
				writer.print "\t#{adjReadID} #{infoStr}"
			}
			writer.puts ''
		}
		writer.close()
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--outDir', '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--arrayList', '-a', GetoptLong::REQUIRED_ARGUMENT],
									['--layoutDir', '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--graphFile', '-g', GetoptLong::REQUIRED_ARGUMENT],
									['--maxParallelPools', '-p', GetoptLong::REQUIRED_ARGUMENT],
									['--maxIntersectingPools', '-i', GetoptLong::REQUIRED_ARGUMENT],
									['--queue', '-q', GetoptLong::OPTIONAL_ARGUMENT],
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
		optsHash['--queue'] = DEFAULT_QUEUE unless(optsHash.key?('--queue'))
		@verbose = optsHash.key?('--verbose') ? true : false
		@outDir = optsHash.key?('--outDir') ? optsHash['--outDir'] : OUT_DIR
		@graphFile = optsHash['--graphFile']
		@maxParallelPools = optsHash['--maxParallelPools'].to_i
		@maxIntersectPools = optsHash['--maxIntersectingPools'].to_i
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
    -o     => Where to put various repeat list files, pruned graph files, etc, under the project dir tree.
    -a     => Comma separated list of array numbers to get from database
    -l     => Dir where the array layout files (from capss-get-arrayLayouts) can be found.
    -g     => Name of graph file to examine.
    -p     => Number of *parallel* pools a read can have overlap with. Depends on degree of bac coverage of genome in the array.
    -i     => Number of *intersecting* pools a read can have overlap with. Depends on degree of bac coverage of a genome in all the pools that contain a given bac (eg 4 pools for a basic transversal design)
    -q     => [optional] LSF cluster to use. Default is 'linux'.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-launch-repeatFinder.rb -t ./poolReads -l ./mapsAndIndices -a 23,24
";
		exit(134);
	end
end

end ; end

finder = BRL::CAPSS::ProblemPoolReadFinder.new()
finder.run()
exit(0)
