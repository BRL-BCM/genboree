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
require 'brl/fileFormats/aceFile'

module BRL ; module CAPSS

class IndexSeparator
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	JOB_NAME_BASE = 'cicdc-'
	BLANK_RE = /^\s*$/
	BIN, CO, AF, START, BS = 0, 1, 2, 3, 4
	BIN_RE = /^BIN (?:.*\D)?(\d+)$/
	CO_RE = /^CO Contig(\d+)\s+(\d+)\s+(\d+)/ # 1=>ID, 2=>length, 3=>numReads
	AF_RE = /^AF (\S+)\s+(\S+)\s+(\S+)$/      # 1=>readName, 2=>dir, 3=>readStartInContig
	BS_RE = /^BS (\d+)\s+(\d+)\s+(\S+)$/      # 1=>start, 2=>stop, 3=>readName
	CONTIG_NUM_RE = /^\d+\.(\d+)$/

	COMMENT_RE = /^\s*#/
	IDX_HDR_RE = /^#?idxID/

	def initialize()
		@indexCount = 0
	end

	def run()
		$stderr.puts "STATUS: begin analysis"
		@params = processArguments()
		$stderr.puts "STATUS: processed args"
		@passedIndexFile = BRL::Util::TextWriter.new(@passedIndexFileName, "w+")
		@failedIndexFile = BRL::Util::TextWriter.new(@failedIndexFileName, "w+")
		loadIndexFile()
		$stderr.puts "STATUS: loaded index file"
		cleanIndices()
		$stderr.puts "STATUS: contigs separated by clear vs unclear deconvolutions"
		@passedIndexFile.close
		@failedIndexFile.close
		return
	end

	def cleanIndices()
		# For each bin
		@indices.keys.sort.each { |binID|
			next if(!@ignoreBinRE.nil? and binID =~ @ignoreBinRE)
			$stderr.print '.' if(binID.to_i % 100 == 0)
			# For each contig in the bin
			@indices[binID].keys.sort.each { |contigID|
				# Count number of BACs mapped to this contig (same as number of indices)
				numBacsMappedToContig = @indices[binID][contigID].size
				# Separate the indices for this contig based on number of BACs mapping to it.
				@indices[binID][contigID].each { |bacID, fields|
					idxOrd = fields[7]
					fields[5] = fields[5].join(',')
					fields[6] = fields[6].join(',')
					fields[8] = fields[8].join(',')
					fields[9] = fields[9].join(',')
					fields = fields.join("\t")
					if((numBacsMappedToContig <= @maxBACsPerContig) or (!@applyToIdxOrds.key?(idxOrd)))
						@passedIndexFile.puts fields
					else
						@failedIndexFile.puts fields
					end
				}
			}
		}
		$stderr.puts ''
		return
	end

	def loadIndexFile()
		@indices = {}
		reader = BRL::Util::TextReader.new(@indexFile)
		parseState = START
		currBinID = nil
		currContigID = nil
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE or line =~ COMMENT_RE or line =~ IDX_HDR_RE)
			fields = line.split("\t")
			fields[5] = fields[5].split(',') # pool list
			fields[6] = fields[6].split(',') # num reads from pool in contig/index
			fields[8] = fields[8].split(',') # read list
			fields[9] = fields[9].split(',') # read starts
			fields[7] = fields[7].to_i
		fields[6].map! { |xx| xx.to_i }
			@indices[fields[1]] = Hash.new() unless(@indices.key?(fields[1]))
			@indices[fields[1]][fields[2]] = Hash.new unless(@indices[fields[1]].key?(fields[2]))
			@indices[fields[1]][fields[2]][fields[4]] = fields
		}
		reader.close
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--indexFile', '-i', GetoptLong::REQUIRED_ARGUMENT],
									['--maxBacsPerContig', '-m', GetoptLong::REQUIRED_ARGUMENT],
									['--passedIndexFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
									['--failedIndexFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
									['--idxOrds', '-x', GetoptLong::REQUIRED_ARGUMENT],
									['--ignoreBinRE', '-b', GetoptLong::REQUIRED_ARGUMENT],
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
		@indexFile = optsHash['--indexFile']
		@maxBACsPerContig = optsHash['--maxBacsPerContig'].to_i
		@passedIndexFileName = optsHash['--passedIndexFile']
		@failedIndexFileName = optsHash['--failedIndexFile']
		if(optsHash.key?('--idxOrds'))
			optsHash['--idxOrds'].each { |xx| @applyToIdxOrds[xx.to_i] = '' }
		else
			@applyToIdxOrds = { 4=>'', 3=>'', 2=>'' }
		end
		@ignoreBinRE = optsHash.key?('--ignoreBinRE') ? /#{optsHash['--ignoreBinRE']}/ : nil
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -i     => File with capss indices
    -m     => Max number of BACs per contig before becomes unclear.
    -p     => Output file with passed indices.
    -f     => Output file with failed indices.
    -x     => List of index orders to which to apply the cleaning.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-idClearDeconContigs.rb -i contigIndexes.txt -m 2 -p ./clearDeconContigs.indices.txt -f ./unclearDeconContigs.indices.txt
"
		exit(134)
	end
end

end ; end

filter = BRL::CAPSS::IndexSeparator.new()
filter.run()
exit(0)
