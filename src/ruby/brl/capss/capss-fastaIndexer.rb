#!/usr/bin/env ruby

=begin
=end
# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' 		# for PropTable class
require 'brl/lsf/lsfBatchJob'
require 'brl/dna/fastaRecord'

module BRL ; module CAPSS

class PoolReadIndexer
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	ROW,COL = 0,1
	# Retrieval command (base)
	JOB_NAME_BASE = 'cfi-'

	def initialize()
		@colPools = {}
		@rowPools = {}
		@arrayLayout = {}
		@clonePools = {}
	end

	def run()
		@params = processArguments()
		indexFastaFiles()
		return
	end

	def	indexFastaFiles()
		seqFile = @params['--seqFile']
		qualFile = @params['--qualFile']
		unless(File.exists?(@params['--seqFile']))
			seqFile += '.gz'
			unless(File.exists?(seqFile))
				raise "ERROR: #{@params['--seqFile']} doesn't exist, neither does a .gz version"
			end
		end
		unless(File.exists?(@params['--qualFile']))
			qualFile += '.gz'
			unless(File.exists?(seqFile))
				raise "ERROR: #{@params['--qualFile']} doesn't exist, neither does a .gz version"
			end
		end
		# index seq file
		seqIndexer = BRL::DNA::FastaFileIndexer.new()
		seqIndexer.indexFile(seqFile)
		seqIdxFile = seqFile + '.idx'
		seqIndexer.saveIndex(seqIdxFile)
		seqIndexer.clear()
		# index qual file
		qualIndexer = BRL::DNA::FastaFileIndexer.new()
		qualIndexer.indexFile(qualFile)
		qualIdxFile = qualFile + '.idx'
		qualIndexer.saveIndex(qualIdxFile)
		qualIndexer.clear()
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--seqFile', '-s', GetoptLong::REQUIRED_ARGUMENT],
									['--qualFile', '-q', GetoptLong::REQUIRED_ARGUMENT],
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
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
  	-s     => Seq file to index
  	-q     => Qual file to index
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-fastaIndexer.rb -s ./ok.reads.fa -q ./ok.reads.fa.qual

";
		exit(134);
	end
end

end ; end

indexer = BRL::CAPSS::PoolReadIndexer.new()
indexer.run()
exit(0)
