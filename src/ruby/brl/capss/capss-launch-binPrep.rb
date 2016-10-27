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

class BinPrepLauncher
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	QUEUE = 'linux'
	PREPPER = '/users/hgsc/andrewj/work/brl/src/ruby/brl/capss/capss-binPrep.rb '
	JOB_NAME_BASE = 'clbp-'
	BLANK_RE = /^\s*$/
	DEF_EXT = '.fon'

	def initialize()
	end

	def run()
		@params = processArguments()
		initIndices()
		prepBins()
		return
	end

	def initIndices()
		# get indices
		@seqIndex = BRL::DNA::FastaFileIndexer.new()
		@seqIndex.loadIndex(@seqFile)
		$stderr.puts "STATUS: loaded #{@seqIndex.fastaRecordIndices.size} seq indices (first is #{@seqIndex.fastaRecordIndices.keys[0]} => #{@seqIndex.fastaRecordIndices[@seqIndex.fastaRecordIndices.keys[0]].join(',')})"
		@qualIndex = BRL::DNA::FastaFileIndexer.new()
		@qualIndex.loadIndex(@qualFile)
		$stderr.puts "STATUS: loaded #{@qualIndex.fastaRecordIndices.size} qual indices (first is #{@qualIndex.fastaRecordIndices.keys[0]} => #{@qualIndex.fastaRecordIndices[@qualIndex.fastaRecordIndices.keys[0]].join(',')})"
		return
	end

	def loadFastaIDs(fonFile)
		fastaIDs = {}
		reader = BRL::Util::TextReader.new(fonFile)
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE)
			fastaIDs[line] = nil
		}
		reader.close()
		return fastaIDs
	end

	def	prepBin(fonFile, outDir)
		# create link to fon file
		linkFile = "#{outDir}/#{File.basename(fonFile)}"
		File::symlink(fonFile, "#{linkFile}") unless(File.exists?("#{linkFile}"))
		fastaIDs = self.loadFastaIDs(fonFile)
		# output files
		seqWriter = BRL::Util::TextWriter.new(outDir + '/bin.reads.fasta')
		qualWriter = BRL::Util::TextWriter.new(outDir + '/bin.reads.fasta.qual')
		fastaIDs.each { |fastaID, val|
			unless(@seqIndex.fastaRecordIndices.key?(fastaID))
				$stderr.puts "WARNING: '#{fastaID}' is not a key in the sequence index...skip? There are #{@seqIndex.fastaRecordIndices.size} index"
				$stderr.puts @seqIndex.getFastaRecordStr(fastaID)
				next
			end
			unless(@qualIndex.fastaRecordIndices.key?(fastaID))
				$stderr.puts "WARNING: '#{fastaID}' is not a key in the quality index...skip? There are #{@qualIndex.fastaRecordIndices.size} index"
				$stderr.puts @qualIndex.getFastaRecordStr(fastaID)
				next
			end
			seqRec = @seqIndex.getFastaRecordStr(fastaID)
			qualRec = @qualIndex.getFastaRecordStr(fastaID)
			seqWriter.puts seqRec
			qualWriter.puts qualRec
		}
		seqWriter.close()
		qualWriter.close()
		return
	end

	def	prepBins()
		fonRE = /^(.+)#{@binFonExt}$/
		fonPattern = '*' + @binFonExt
		origDir = Dir.pwd()
		@seqFile = File.expand_path(@seqFile)
		@qualFile = File.expand_path(@qualFile)
		Dir.chdir(@topDir)
		fons = Dir.glob(fonPattern)
		fons.each { |fon|
			fon =~ fonRE
			binName = $1
			binDir = "#{@outDir}/#{binName}"
			Dir.safeMkdir(binDir)
			next unless(File.exists?(fon))
			fonFile = File.expand_path(fon)
			outDir = binDir
			self.prepBin(fonFile, outDir)
		}
		Dir.chdir(origDir)
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--topDir', '-t', GetoptLong::REQUIRED_ARGUMENT],
									['--outDir', '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--seqFile', '-s', GetoptLong::REQUIRED_ARGUMENT],
									['--qualFile', '-q', GetoptLong::REQUIRED_ARGUMENT],
									['--binFonExt', '-e', GetoptLong::OPTIONAL_ARGUMENT],
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
		@queue = optsHash.key?('--queue') ? optsHash['--queue'] : QUEUE
		@verbose = optsHash.key?('--verbose') ? true : false
		@topDir = optsHash['--topDir']
		@binFonExt = optsHash.key?('--binFonExt') ? optsHash['--binFonExt'] : DEF_EXT
		@seqFile = optsHash['--seqFile']
		@qualFile = optsHash['--qualFile']
		@outDir = optsHash.key?('--outDir') ? optsHash['--outDir'] : @topDir
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -t     => Directory with bin .fon files
    -s     => Name of index file for the fasta sequence file from which to pull reads.
    -q     => Name of index file for the quality sequence file from which to pull reads.
    -o     => [optional, '.'] Dir where to create bin sub-dirs.
    -e     => [optional, '.fon'] Extension of .fon files that define each bin.
    -u     => [optional] LSF cluster to use. Default is 'short'.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-launch-binPrep.rb -t ./betterGraph_BINS -s ../all.reads ../all.reads.qual
";
		exit(134);
	end
end

end ; end

launcher = BRL::CAPSS::BinPrepLauncher.new()
launcher.run()
exit(0)
