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

class MatePair
	def MatePair::makeInsertID(readID)
		insertID = readID.dup
		insertID[6] = '_'
		return insertID
	end
end

class MatePairRecruiter
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

	def initialize()
		@indexCount = 0
	end

	def run()
		$stderr.puts "STATUS: begin analysis"
		@params = processArguments()
		$stderr.puts "STATUS: processed args"
		loadAvailMatePairFonFile()
		$stderr.puts "STATUS: loaded index file"
		recruitMatePairs()
		$stderr.puts "STATUS: recruited mate pairs to bac read lists."
		return
	end

	def recruitMatePairs()
		# Get Bac dirs
		bacDirs = getBacDirs()
		# For each bac dir
		bacDirs.each { |bacDir|
			# load decon reads
			reads = loadDeconFonFile(File::basename(bacDir))
			next if(reads.empty?)
			# for each decon read, see if its mate is available and add it
			(0...reads.size).each { |ii|
				readID = reads[ii]
				insert = MatePair::makeInsertID(readID)
				if(@matePairs.key?(insert))
					reads << @matePairs[insert]
					puts "#{File::basename(bacDir)}\t#{@matePairs[insert]}"
				end
			}
			# sort read list so mate pairs go together
			reads.sort! { |aa,bb|
				xx, yy = MatePair::makeInsertID(aa), MatePair::makeInsertID(bb)
				if((retVal = (xx <=> yy)) != 0)
					retVal
				else
					aa[6] <=> bb[6]
				end
			}
			# save the augmented reads list
			writer = BRL::Util::TextWriter.new("#{bacDir}/#{@deconPlusMatesFile}", 'w+')
			writer.puts reads.join("\n")
			writer.close
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

	def loadDeconFonFile(bacID)
		reads = {}
		bacDeconFon = "#{@bacDir}/#{bacID}/#{@deconFile}"
		if(File.exists?(bacDeconFon))
			reader = BRL::Util::TextReader.new(bacDeconFon)
			reader.each { |line|
				line.strip!
				next if(line =~ BLANK_RE or line =~ COMMENT_RE)
				reads[line] = ''
			}
			reader.close
		end
		return reads.keys
	end

	def loadAvailMatePairFonFile()
		@matePairs = {}
		reader = BRL::Util::TextReader.new(@availMatePairsFile)
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE or line =~ COMMENT_RE)
			insert = MatePair::makeInsertID(line)
			@matePairs[insert] = line
		}
		reader.close
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--bacDir', '-t', GetoptLong::REQUIRED_ARGUMENT],
									['--availMatePairsFon', '-a', GetoptLong::REQUIRED_ARGUMENT],
									['--deconReadsFile', '-d', GetoptLong::REQUIRED_ARGUMENT],
									['--deconPlusMatesFile', '-m', GetoptLong::REQUIRED_ARGUMENT],
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
		@availMatePairsFile = optsHash['--availMatePairsFon']
		@deconFile = optsHash['--deconReadsFile']
		@deconPlusMatesFile = optsHash['--deconPlusMatesFile']
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -t     => Top level dir where bac subdirs are with deconvoluted.reads.fon files.
    -a     => The all-available mate pairs fon file.
    -d     => name of File with deconvoluted reads for each bac.
    -m     => name of File to write with deconvoluted reads plus mates for each bac.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-bacByBac-matePairRecruit.rb -o . -a all.NON-deconvoluted.reads.fon
";
		exit(134);
	end
end

end ; end

recruiter = BRL::CAPSS::MatePairRecruiter.new()
recruiter.run()
exit(0)

