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

class OverUseFilter
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	JOB_NAME_BASE = 'carbi-'
	BLANK_RE = /^\s*$/
	BIN, CO, AF, START, BS = 0, 1, 2, 3, 4
	BIN_RE = /^BIN (?:.*\D)?(\d+)$/
	CO_RE = /^CO Contig(\d+)\s+(\d+)\s+(\d+)/ # 1=>ID, 2=>length, 3=>numReads
	AF_RE = /^AF (\S+)\s+(\S+)\s+(\S+)$/      # 1=>readName, 2=>dir, 3=>readStartInContig
	BS_RE = /^BS (\d+)\s+(\d+)\s+(\S+)$/      # 1=>start, 2=>stop, 3=>readName
	COMMENT_RE = /^\s*#/
	IDX_HDR_RE = /^#?idxID/

	def initialize()
		@indexCount = 0
	end

	def run()
		$stderr.puts "STATUS: begin analysis"
		@params = processArguments()
		$stderr.puts "STATUS: processed args"
		loadIndexFile()
		$stderr.puts "STATUS: loaded index file"
		countReadOverUse()
		$stderr.puts "STATUS: checked over use of reads in multiple indices per contig"
		removeIndicesWithReadOverUse()
		$stderr.puts "STATUS: filtered indices by read over use in multiple indices per contig"
		return
	end

	def removeIndicesWithReadOverUse()
		@indices.keys.sort.each { |binID|
			@indices[binID].keys.sort.each { |contigID|
				# For each index in the contig, delete unless passes criteria
				@indices[binID][contigID].each { |bacID, fields|
					unless(anyPoolOverUsed?(fields))
						# Output all non single pool indices
						fields[5] = fields[5].join(',')
						fields[6] = fields[6].join(',')
						fields[8] = fields[8].join(',')
						fields[9] = fields[9].join(',')
						fields = fields.join("\t")
						puts fields
					end
				}
			}
		}
		return
	end
	
	def countReadOverUse()
		@pool2contigCount = {}
		@indices.each { |binID, byContig|
			byContig.each { |contigID, byBac|
				byBac.each { |bacID, fields|
					fields[5].each_index { |ii|
						poolID = fields[5][ii]
						readCount = fields[6][ii]
						@pool2contigCount[poolID] = {} unless(@pool2contigCount.key?(poolID))
						@pool2contigCount[poolID][contigID] = 0 unless(@pool2contigCount[poolID].key?(contigID))
						@pool2contigCount[poolID][contigID] += 1 if(readCount > 0)
					}
				}
			}
		}
		return
	end
	
	def anyPoolOverUsed?(fields)
		overUsed = false
		fields[5].each_index { |ii|
			poolID = fields[5][ii]
			contigID = fields[2]
			if(@pool2contigCount.key?(poolID) and @pool2contigCount[poolID].key?(contigID) and @pool2contigCount[poolID][contigID] > 1)
				overUsed = true
				break
			end
		}
		return overUsed			
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
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -i     => File with capss indices
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-poolOverUseFilter.rb -i contigIndexes.txt
"
		exit(134)
	end
end

end ; end

filter = BRL::CAPSS::OverUseFilter.new()
filter.run()
exit(0)

