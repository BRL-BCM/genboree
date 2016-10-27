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
require 'GSL'
include GSL

module BRL ; module CAPSS

class RepeatFinder
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	JOB_NAME_BASE = 'crf-'
	NODE_RE = /^(\S+)\s+((?:\S+\s+\{\S+\}\s*)+)$/
	EDGE_RE = /(\S+)\s+(\{\S+\})/
	BLANK_RE = /^\s*$/
	REGULAR_REPEAT = 20
	EXCESSIVE_REPEAT = 300
	REG_REP_FON = 'regRepeats.fon'
	ADJ_EXC_FON = 'overlappingExcessiveRepeats.fon'
	NOT_REG_REP_FON = 'notRegRepeats.fon'
	NOT_ADJ_EXC_FON = 'notRegRepeats.notOverlappingExc.fon'
	SINGLES_FON = 'singletons.fon'
	NOT_REG_REP_GRAPH = 'noRegRepeats.graph'
	NOT_ADJ_EXC_GRAPH = 'noRegRepeats.noneOverlappingExcessiveRepeats.graph'

	def initialize()
		@overlapGraph = {}
		@adjExcRepeats = {}
	end

	def run()
		$stdout.sync = true
		@params = processArguments()
		loadGraphFile()
		$stderr.puts "STATUS: done loading graph file"
		dumpInitialGraphStats()
		$stderr.puts "STATUS: done dumping initial graph stats"
		getSingletonList()
		$stderr.puts "STATUS: get list of reads with no overlap (singles: #{@singletons.size})"
#		removeSingles()
#		$stderr.puts "STATUS: removed singles from graph. Left with #{@overlapGraph.size} reads in graph."
		getRepeatLists()
		$stderr.puts "STATUS: got repeat lists (reg: #{@regularRepeats.size}, exc: #{@excessiveRepeats.size})"
		removeRegularRepeats()
		$stderr.puts "STATUS: removed regular repeats from graph. Left with #{@overlapGraph.size} reads in graph."
		dumpCurrentNodeList(NOT_REG_REP_FON)
		dumpGraph(NOT_REG_REP_GRAPH)
		removeNodesAdjacentToExcessiveRepeats()
		$stderr.puts "STATUS: removed reads overlapping execessive repeats from graph. Left with #{@overlapGraph.size} reads in graph."
		dumpCurrentNodeList(NOT_ADJ_EXC_FON)
		dumpGraph(NOT_ADJ_EXC_GRAPH)
		dumpLists()
		return
	end

	def dumpGraph(fileName)
		writer = BRL::Util::TextWriter.new("#{@params['--outDir']}/#{fileName}")
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

	def removeNodesAdjacentToExcessiveRepeats()
		@overlapGraph.keys.each { |readID|
			edges = @overlapGraph[readID]
			edges.keys.each { |adjReadID|
				if(@excessiveRepeats.key?(adjReadID))
					@overlapGraph.delete(readID)
					@adjExcRepeats[readID] = nil
					break
				end
			}
		}
		puts "Num Reads After Removing Repeats and Overlapping with Excessive: #{@overlapGraph.size}"
		return
	end

	def dumpCurrentNodeList(fileName)
		writer = BRL::Util::TextWriter.new("#{@params['--outDir']}/#{fileName}")
		writer.puts @overlapGraph.keys.join("\n")
		writer.close()
		return
	end

	def removeRegularRepeats()
		@overlapGraph.keys.each { |readID|
			if(@regularRepeats.key?(readID))
				@overlapGraph.delete(readID)
			end
		}
		return
	end

#	def removeSingles()
#		@overlapGraph.keys.each { |readID|
#				@overlapGraph.delete(readID) if(@overlapGraph[readID].empty?)
#		}
#		return
#	end

	def dumpLists()
		regRepFile = BRL::Util::TextWriter.new("#{@params['--outDir']}/#{REG_REP_FON}")
		excRepFile = BRL::Util::TextWriter.new("#{@params['--outDir']}/#{ADJ_EXC_FON}")
		singlesFile = BRL::Util::TextWriter.new("#{@params['--outDir']}/#{SINGLES_FON}")
		regRepFile.puts @regularRepeats.keys.join("\n")
		excRepFile.puts @adjExcRepeats.keys.join("\n")
		singlesFile.puts @singletons.keys.join("\n")
		regRepFile.close()
		excRepFile.close()
		singlesFile.close()
		return
	end

	def getRepeatLists()
		@regularRepeats = {}
		@excessiveRepeats = {}
		@overlapGraph.each { |readID, edges|
			@regularRepeats[readID] = edges.size if(edges.size > @regRepeat)
			@excessiveRepeats[readID] = edges.size if(edges.size > @excRepeat)
		}
		return
	end

	def getSingletonList()
		@singletons = {}
		@overlapGraph.each { |readID, edges|
			@singletons[readID] = edges.size if(edges.empty?)
		}
		return
	end

	def dumpInitialGraphStats()
		puts "Total Unique Reads in Overlap Graph: #{@overlapGraph.size}"
		numEdges = []
		@overlapGraph.each { |readID, edges| numEdges << edges.size }
		$stderr.puts "STATUS: done getting all edge counts for analysis"
		puts "Avg Num Overlaps Per Read: #{GSL::Stats::mean(numEdges,1)} (sd: #{GSL::Stats::sd(numEdges,1)})"
		puts "Max Num Overlaps Per Read: #{GSL::Stats::max(numEdges,1)}"
		numRegRepeat = 0
		numExcRepeat = 0
		numSingles = 0
		numEdges.each { |ii| numRegRepeat += 1 if(ii > @regRepeat) ; numExcRepeat += 1 if(ii > @excRepeat) ; numSingles += 1 if(ii == 0) }
		puts "Num Singleton Reads: #{numSingles}"
		puts "Num Reads with more than #{@regRepeat} overlaps: #{numRegRepeat}"
		puts "Num Reads with more than #{@excRepeat} overlaps: #{numExcRepeat}"
		puts "Num Non-Repeat Reads: #{@overlapGraph.size - numRegRepeat}"
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
				edgeStr = $2
				@overlapGraph[readID] = {} unless(@overlapGraph.key?(readID))
				# parse edges
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

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--outDir', '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--graphFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
									['--regularRepeat', '-r', GetoptLong::OPTIONAL_ARGUMENT],
									['--excessiveRepeat', '-e', GetoptLong::OPTIONAL_ARGUMENT],
									['--requiredReadPattern', '-p', GetoptLong::OPTIONAL_ARGUMENT],
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
		optsHash['--queue'] = DEFAULT_QUEUE unless(optsHash.key?('--queue'))
		@verbose = optsHash.key?('--verbose') ? true : false
		@regRepeat = optsHash.key?('--regularRepeat') ? optsHash['--regularRepeat'].to_i : REGULAR_REPEAT
		@excRepeat = optsHash.key?('--excessiveRepeat') ? optsHash['--excessiveRepeat'].to_i : EXCESSIVE_REPEAT
		@readREStr = optsHash.key?('--requiredReadPattern') ? optsHash['--requiredReadPattern'] : nil
		@readRE = @readREStr.nil?() ? nil : /#{@readREStr}/
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -o     => Dir where to dump output files and reports.
    -f     => Overlap graph file (can be gzipped or not)
    -r     => [optional, 20] Number of overlaps identifying a regular repeat node.
    -e     => [optional, 300] Number of overlaps identifying an excessive repeat node.
    -p     => [optional, nil] RegExp that the read node must match for consideration. For parallel processing of many pools/sub-sets.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-repeatFinding-fromOverlaps.rb -o /home/po4a/brl/capss/seaUrchin/06-10-2003/mapAndIndices -f all.overlaps.graph.gz -r 20 -h 300
";
		exit(134);
	end
end

end ; end

finder = BRL::CAPSS::RepeatFinder.new()
finder.run()
exit(0)
