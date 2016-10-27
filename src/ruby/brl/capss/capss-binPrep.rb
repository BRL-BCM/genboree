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
require 'brl/dna/fastaRecord'

module BRL ; module CAPSS

class BinPrep
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	BLANK_RE = /^\s*$/

	def initialize()
		@fastaIDs = {}
	end

	def run()
		@params = processArguments()
		loadFastaIDs()
		prepBin()
		return
	end

	def	prepBin()
		# create link to fon file
		linkFile = "#{@binDir}/#{File.basename(@fonFile)}"
		File::symlink(@fonFile, "#{linkFile}") unless(File.exists?("#{linkFile}"))
		# get indices
		seqIndex = BRL::DNA::FastaFileIndexer.new()
		seqIndex.loadIndex(@seqFile)
		$stderr.puts "STATUS: loaded #{seqIndex.fastaRecordIndices.size} seq indices (first is #{seqIndex.fastaRecordIndices.keys[0]} => #{seqIndex.fastaRecordIndices[seqIndex.fastaRecordIndices.keys[0]].join(',')})"
		qualIndex = BRL::DNA::FastaFileIndexer.new()
		qualIndex.loadIndex(@qualFile)
		$stderr.puts "STATUS: loaded #{qualIndex.fastaRecordIndices.size} qual indices (first is #{qualIndex.fastaRecordIndices.keys[0]} => #{qualIndex.fastaRecordIndices[qualIndex.fastaRecordIndices.keys[0]].join(',')})"
		# output files
		seqWriter = BRL::Util::TextWriter.new(@binDir + '/bin.reads.fasta')
		qualWriter = BRL::Util::TextWriter.new(@binDir + '/bin.reads.fasta.qual')
		@fastaIDs.each { |fastaID, val|
			unless(seqIndex.fastaRecordIndices.key?(fastaID))
				$stderr.puts "WARNING: '#{fastaID}' is not a key in the sequence index...skip? There are #{seqIndex.fastaRecordIndices.size} index"
				$stderr.puts seqIndex.getFastaRecordStr(fastaID)
				next
			end
			unless(qualIndex.fastaRecordIndices.key?(fastaID))
				$stderr.puts "WARNING: '#{fastaID}' is not a key in the quality index...skip? There are #{qualIndex.fastaRecordIndices.size} index"
				$stderr.puts qualIndex.getFastaRecordStr(fastaID)
				next
			end
			seqRec = seqIndex.getFastaRecordStr(fastaID)
			qualRec = qualIndex.getFastaRecordStr(fastaID)
			seqWriter.puts seqRec
			qualWriter.puts qualRec
		}
		seqWriter.close()
		qualWriter.close()
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--binOutputDir', '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--seqFile', '-s', GetoptLong::REQUIRED_ARGUMENT],
								['--qualFile', '-q', GetoptLong::REQUIRED_ARGUMENT],
									['--fonFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
									['--queue', '-u', GetoptLong::OPTIONAL_ARGUMENT],
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
		@topDir = optsHash['--topDir']
		@seqFile = optsHash['--seqFile']
		@qualFile = optsHash['--qualFile']
		@fonFile = optsHash['--fonFile']
		@binDir = optsHash.key?('--binOutputDir') ? optsHash['--binOutputDir'] : '.'
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
  	-o     => Bin output dir.
    -s     => Name of index file for the fasta sequence file from which to pull reads.
    -q     => Name of index file for the quality sequence file from which to pull reads.
    -f     => Name of fon file to use for creating bin.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-binPrep.rb -o ./betterGraph_BINS/bin0001.fon -s ../all.reads ../all.reads.qual -f ./betterGraph_BINS/bin0001.fon
";
		exit(134);
	end
end

end ; end

prepper = BRL::CAPSS::BinPrep.new()
prepper.run()
exit(0)
