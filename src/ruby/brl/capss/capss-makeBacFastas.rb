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

class BacFastaGenerator
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	JOB_NAME_BASE = 'cbbbdrf-'
	BLANK_RE = /^\s*$/
	BIN, CO, AF, START, BS = 0, 1, 2, 3, 4
	BIN_RE = /^BIN (?:.*\D)?(\d+)$/
	CO_RE = /^CO Contig(\d+)\s+(\d+)\s+(\d+)/ # 1=>ID, 2=>length, 3=>numReads
	AF_RE = /^AF (\S+)\s+(\S+)\s+(\S+)$/      # 1=>readName, 2=>dir, 3=>readStartInContig
	BS_RE = /^BS (\d+)\s+(\d+)\s+(\S+)$/      # 1=>start, 2=>stop, 3=>readName
	COMMENT_RE = /^\s*#/
	IDX_HDR_RE = /^#?idxID/
	DECON_FILE = 'deconvoluted.reads.fon'
	MATE_FILE = 'deconvoluted.plusMatePairs.fon'
	BAC_RE = /^[^\-]+\-\d+\D+\d+$/
	SEQ_OUT_FILE = 'bacReads.byCapss.fa'
	QUAL_OUT_FILE = 'bacReads.byCapss.qual'

	def initialize()
		@indexCount = 0
	end

	def run()
		$stderr.puts "STATUS: begin analysis"
		@params = processArguments()
		$stderr.puts "STATUS: processed args"
		loadFastaIndices()
		$stderr.puts "STATUS: loaded indices for all read sequences and all read qualities"
		generateFastaFiles()
		$stderr.puts "STATUS: make fasta files for reads for all bacs"
		return
	end

	def generateFastaFiles()
		# Get Bac dirs
		bacDirs = getBacDirs()
		# For each bac dir
		bacDirs.each { |bacDir|
			# load reads list
			reads = loadReadList(File::basename(bacDir))
			next if(reads.empty?)
			# open the output files
			seqWriter = BRL::Util::TextWriter.new("#{bacDir}/#{SEQ_OUT_FILE}", 'w+')
			qualWriter = BRL::Util::TextWriter.new("#{bacDir}/#{QUAL_OUT_FILE}", 'w+')
			# for each read, grab its full record and write it to the out files
			reads.each { |readID|
				seqRec = @allReadSeqIdx.getFastaRecordStr(readID)
				qualRec = @allReadQualIdx.getFastaRecordStr(readID)
				if(seqRec.nil?)
					raise "\nERROR: can't find an entry for '#{readID}' in the seq index file '#{@seqIdxFile}'. Fatal error.\n\n"
				elsif(qualRec.nil?)
					raise "\nERROR: can't fine an entry for '#{readID}' in the qual index file '#{@qualIdxFile}'. Fatal error.\n\n"
				end
				seqWriter.puts seqRec
				qualWriter.puts qualRec
			}
			seqWriter.close
			qualWriter.close
		}
		return
	end

	def getBacDirs()
		dirs = []
		Dir::foreach(@bacDir) { |entry|
			fullPath = "#{@bacDir}/#{entry}"
			next unless(File::directory?(fullPath) and entry =~ BAC_RE)
			dirs << fullPath
		}
		return dirs
	end

	def loadReadList(bacID)
		reads = {}
		fonFile = "#{@bacDir}/#{bacID}/#{@fonFile}"
		if(File.exists?(fonFile))
			reader = BRL::Util::TextReader.new(fonFile)
			reader.each { |line|
				line.strip!
				next if(line =~ BLANK_RE or line =~ COMMENT_RE)
				reads[line] = ''
			}
			reader.close
		end
		return reads.keys
	end

	def loadFastaIndices()
		@allReadSeqIdx = BRL::DNA::FastaFileIndexer.new()
		@allReadQualIdx = BRL::DNA::FastaFileIndexer.new()
		$stderr.puts 'STATUS: loading sequence index for all reads....'
		@allReadSeqIdx.loadIndex(@seqIdxFile)
		$stderr.puts 'STATUS: loading quality index for all reads....'
		@allReadQualIdx.loadIndex(@qualIdxFile)
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--bacDir', '-t', GetoptLong::REQUIRED_ARGUMENT],
									['--bacReadFon', '-b', GetoptLong::REQUIRED_ARGUMENT],
									['--seqIdx', '-s', GetoptLong::REQUIRED_ARGUMENT],
									['--qualIdx', '-q', GetoptLong::REQUIRED_ARGUMENT],
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
		@bacDir = optsHash['--bacDir']
		@verbose = optsHash.key?('--verbose') ? true : false
		@fonFile = optsHash['--bacReadFon']
		@seqIdxFile = optsHash['--seqIdx']
		@qualIdxFile = optsHash['--qualIdx']
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -t     => Top level dir where bac subdirs are with fon files are.
    -b     => The fon file name in each bac subdir that lists the reads belonging to the bac.
    -s     => The index for the fasta sequence file with ALL the reads in it
    -q     => The index for the fasta quality file with ALL the read qualities in them.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-makeBacFastas.rb -t . -b deconvoluted.plusMatePairs.fon -s ../../all.reads.screen.fine.course.idx -q all.reads.screen.fine.course.qual.idx
";
		exit(134);
	end
end

end ; end

generator = BRL::CAPSS::BacFastaGenerator.new()
generator.run()
exit(0)

