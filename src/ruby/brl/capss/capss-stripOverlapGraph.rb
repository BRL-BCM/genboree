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

class GraphStripper
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	JOB_NAME_BASE = 'crf-'
	NODE_RE = /^(\S+)\s+((?:\S+\s+\{\S+\}\s*)+)$/
	EDGE_RE = /(\S+)\s+(\{\S+\})/
	BLANK_RE = /^\s*$/

	def initialize()
		@overlapGraph = {}
		@adjExcRepeats = {}
	end

	def run()
		$stdout.sync = true
		@params = processArguments()
		loadFonFile()
		$stderr.puts "STATUS: done loading fon file"
		loadGraphFile()
		$stderr.puts "STATUS: done loading graph file"
		dumpGraph()
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

	def loadFonFile
		@readRemoveList = {}
		reader = BRL::Util::TestReader.new(@readFonName)
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE)
			@readRemoveList[line] = ''
		}		
		reader.close
		return
	end

	def loadGraphFile()
		reader = BRL::Util::TextReader.new(@graphFile)
		nodeCount = 0
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE)
			next if(!@readRE.nil? and (line !~ @readRE))
			nodeCount += 1
			# parse the node label from edges
			# remove node if it's in the list
			if(line =~ NODE_RE)
				readID = $1
				next if(@readRemoveList.key?(readID))
				edgeStr = $2
				@overlapGraph[readID] = {} unless(@overlapGraph.key?(readID))
				# parse edges
				# remove the edge if it's to a read in the remove list
				edgeStr.scan(EDGE_RE) { |subMatches|
					next if(subMatches[0] == readID or @readRemoveList.key?(readID)) # self-to-self edge or to a remove node
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
									['--graphFile', '-g', GetoptLong::REQUIRED_ARGUMENT],
									['--readsFile', '-r', GetoptLong::OPTIONAL_ARGUMENT],
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
		@readFonName = optsHash['--readsFile']
		@graphFile = optsHash['--graphFile']
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -f     => Overlap graph file (can be gzipped or not)
    -r     => An fon file naming reads to remove from the graph.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-stripOverlapGraph.rb -g all.overlaps.graph.gz -r removeReads.fon
";
		exit(134);
	end
end

end ; end

stripper = BRL::CAPSS::GraphStripper.new()
stripper.run()
exit(0)
