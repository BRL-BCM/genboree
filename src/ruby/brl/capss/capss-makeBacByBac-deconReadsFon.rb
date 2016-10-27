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

class DeconReadFon
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	JOB_NAME_BASE = 'cmbbbdrf-'
	BLANK_RE = /^\s*$/
	BIN, CO, AF, START, BS = 0, 1, 2, 3, 4
	BIN_RE = /^BIN (?:.*\D)?(\d+)$/
	CO_RE = /^CO Contig(\d+)\s+(\d+)\s+(\d+)/ # 1=>ID, 2=>length, 3=>numReads
	AF_RE = /^AF (\S+)\s+(\S+)\s+(\S+)$/      # 1=>readName, 2=>dir, 3=>readStartInContig
	BS_RE = /^BS (\d+)\s+(\d+)\s+(\S+)$/      # 1=>start, 2=>stop, 3=>readName
	COMMENT_RE = /^\s*#/
	IDX_HDR_RE = /^#?idxID/
	DECON_FILE = 'deconvoluted.reads.fon'

	def initialize()
		@indexCount = 0
	end

	def run()
		$stderr.puts "STATUS: begin analysis"
		@params = processArguments()
		$stderr.puts "STATUS: processed args"
		loadIndexFile()
		$stderr.puts "STATUS: loaded index file"
		makeBacDeconFons()
		$stderr.puts "STATUS: made deconvoluted read lists for each bac."
		return
	end

	def makeBacDeconFons()
		# For each bac
		@bac2reads.each { |bacID, reads|
			reads.sort!
			# Create a subdir
			subdir = "#{@outDir}/#{bacID}"
			BRL::Util::Dir.safeMkdir(subdir)
			# Open up the decon fon file
			writer = BRL::Util::TextWriter.new(subdir + '/' + @deconFile, 'w+')
			# dump the list of reads to it
			writer.puts reads.join("\n")
			reads.each { |read| puts "#{bacID}\t#{read}" }
			# close the file
			writer.close
		}
		return
	end

	def loadIndexFile()
		@bac2reads = {}
		reader = BRL::Util::TextReader.new(@indexFile)
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE or line =~ COMMENT_RE or line =~ IDX_HDR_RE)
			fields = line.split("\t")
			fields[8] = fields[8].split(',') # read list
			@bac2reads[fields[4]] = [] unless(@bac2reads.key?(fields[4]))
			@bac2reads[fields[4]] += fields[8]
		}
		reader.close
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--outDir', '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--indexFile', '-i', GetoptLong::REQUIRED_ARGUMENT],
									['--deconFile', '-d', GetoptLong::OPTIONAL_ARGUMENT],
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
		@outDir = optsHash['--outDir']
		@verbose = optsHash.key?('--verbose') ? true : false
		@indexFile = optsHash['--indexFile']
		@deconFile = optsHash.key?('--deconFile') ? optsHash['--deconFile'] : DECON_FILE
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -o     => Where to put a subdir for each BAC and to put the .fon files.
    -i     => File with capss indices.
    -d     => [optional] Name of deconvoluted fon File placed in dir of each bac.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-makeBacByBac-DeconReadsFon.rb -o . -i contigIndexes.txt
";
		exit(134);
	end
end

end ; end

fonner = BRL::CAPSS::DeconReadFon.new()
fonner.run()
exit(0)

