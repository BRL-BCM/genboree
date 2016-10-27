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

class PoolConnectionFilter
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	JOB_NAME_BASE = 'cpcf-'
	BLANK_RE = /^\s*$/
	BIN, CO, AF, START, BS = 0, 1, 2, 3, 4
	BIN_RE = /^BIN (?:.*\D)?(\d+)$/
	CO_RE = /^CO Contig(\d+)\s+(\d+)\s+(\d+)/ # 1=>ID, 2=>length, 3=>numReads
	AF_RE = /^AF (\S+)\s+(\S+)\s+(\S+)$/      # 1=>readName, 2=>dir, 3=>readStartInContig
	BS_RE = /^BS (\d+)\s+(\d+)\s+(\S+)$/      # 1=>start, 2=>stop, 3=>readName
	CONTIG_NUM_RE = /^\d+\.(\d+)$/

	COMMENT_RE = /^\s*#/
	IDX_HDR_RE = /^#?idxID/
	BIN_FILE_BASE = 'betterGraph.r35.e300.p8.i4_%%.bin/bin.reads.fasta.ace'

	def initialize()
		@indexCount = 0
	end

	def run()
		$stderr.puts "STATUS: begin analysis"
		@params = processArguments()
		$stderr.puts "STATUS: processed args"
		loadIndexFile()
		$stderr.puts "STATUS: loaded index file"
		cleanByPoolConnect()
		$stderr.puts "STATUS: filtered reads by connection"
		return
	end

	def cleanByPoolConnect()
		poolConnections = {}
		# For each bin
		@indices.keys.sort.each { |binID|
			next if(!@ignoreBinRE.nil? and binID =~ @ignoreBinRE)
			$stderr.print '.' if(binID.to_i % 100 == 0)
			# Open the ace file for the bin
			aceFileName = @binFileBase.gsub('%%', binID)
			begin
				aceFile = BRL::FileFormats::AceFile.new(@binDir + '/' + aceFileName)
			rescue => err
				aceFile = nil
			end
			if(aceFile.nil?) # no contigs or missing file or something
				$stderr.puts "No contigs in?? :\n\t'#{aceFileName}'\nbinID:\t'#{binID}'"
				next # bin
			end
			# For each contig in the bin
			@indices[binID].keys.sort.each { |contigID|
				contigNum = contigID[ CONTIG_NUM_RE , 1]
				# For each index in the contig, check that all pools are connected
				poolConnections.clear
				@indices[binID][contigID].each { |bacID, fields|
					allConnected = true
					if(@idxOrders.key?(fields[7])) # Then need to filter based on pool connectedness (else just echo out)
						fields[5].each { |poolID|	poolConnections[poolID] = 0 }
						# Get the start and stops for each read in the contig
						readCoords = getReadCoords(aceFile, contigNum, fields[8])
						# Loop over each read in the pool and check if it overlaps with a read from other pool(s)' reads.
						readCoords.each_index { |ii|
							currPool = readCoords[ii][0][0,4]
							currCoords = readCoords[ii][1]
							((ii+1)...readCoords.size).each { |jj|
								pool = readCoords[jj][0][0,4]
								next if(currPool == pool)
								coords = readCoords[jj][1]
								if(coords.nil?)
									$stderr.puts "Bad coords found:\n\t'#{binID}'\n\t'#{contigID}'\n\t'#{aceFileName}'\n\t'#{aceFile.inspect}'\n\t'#{readCoords.inspect}'\n\t'#{currCoords.inspect}'\n\t'#{bacID}'\n\t'#{fields.join('__')}"
									exit
								end
								# do pools overlap?
								if(coords[0] <= currCoords[1] and currCoords[0] <= coords[1]) # then yes
									poolConnections[currPool] += 1
									poolConnections[pool] += 1
								end
							}
						}
						# Do all pools have min connections?
						allConnected = true
						fields[5].each_index { |kk|
						  poolID = fields[5][kk]
						  readCount = fields[6][kk]
						  next unless(readCount > 0)
							if(poolConnections[poolID] <= @minConnectionWeight)
								allConnected = false
								break
							end
						}
					end
					# Output the index if yes, else no
					if(allConnected)
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
		$stderr.puts ''
		return
	end

	def getReadCoords(aceFile, contigNum, readIDs)
		readCoords = []
		readIDs.each { |readID|
			readCoords << [ readID, aceFile.getReadStartEndInContig(contigNum, readID) ]
		}
		return readCoords
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

	def loadContigsFile()
		@contigData = {}
		reader = BRL::Util::TextReader.new(@contigsFile)
		parseState = START
		currBinID = nil
		currContigID = nil
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE)
			if((parseState == START or parseState == BS) and (line =~ BIN_RE)) # Then correctly found a bin
				currBinID = $1
				@contigData[currBinID] = {}
				parseState = BIN
			elsif((parseState == BIN or parseState == BS) and (line =~ CO_RE)) # Then correctly found a contig
				currContigID = currBinID + '.' + $1
				contigLength = $2.to_i
				numReads = $3.to_i
				@contigData[currBinID][currContigID] = {}
				parseState = AF
			elsif((parseState == AF) and (line =~ AF_RE))                     # Then correctly found an AF line
				read = ReadInContig.new($1, currContigID, $3.to_i)
				@contigData[currBinID][currContigID][read.name] = read
				parseState == AF
			elsif((parseState == AF or parseState == BS) and (line =~ BS_RE))
				@contigData[currBinID][currContigID][$3].addAssemblyDetail($1.to_i, $2.to_i)
				parseState == BS
			end
		}
		reader.close()
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--dir', '-d', GetoptLong::REQUIRED_ARGUMENT],
									['--indexFile', '-i', GetoptLong::REQUIRED_ARGUMENT],
									['--minConnectionWeight', '-m', GetoptLong::REQUIRED_ARGUMENT],
									['--ignoreBinRE', '-b', GetoptLong::REQUIRED_ARGUMENT],
									['--binFileBase', '-f', GetoptLong::OPTIONAL_ARGUMENT],
									['--idxOrdList', '-x', GetoptLong::REQUIRED_ARGUMENT],
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
		@binDir = optsHash['--dir']
		@ignoreBinRE = optsHash.key?('--ignoreBinRE') ? /#{optsHash['--ignoreBinRE']}/ : nil
		@minConnectionWeight = optsHash['--minConnectionWeight'].to_i
		@binFileBase = optsHash.key?('--binFileBase') ? optsHash['--binFileBase'] : BIN_FILE_BASE
		@idxOrders = {}
		optsHash['--idxOrdList'].split(',').each { |xx| @idxOrders[xx.to_i] = '' }
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -d     => Where the bin dirs are.
    -i     => File with capss indices
    -m     => Min number of connections (reads) between any two pools in the index.
    -b     => RegExp mathcing binIDs to ignore.
    -f     => Bin ace file base. Include subdir under the bin dir. The bin ID will be substituted for %%.
    -x     => Comma separated list of index orders to which to apply this filter.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-poolConnectionFilter.rb -d . -i contigIndexes.txt -m 1 -b '^0+$' -f 'betterGraph.r35.e300.p8.i4_%%.bin/bin.reads.fasta.ace'
"
		exit(134)
	end
end

end ; end

filter = BRL::CAPSS::PoolConnectionFilter.new()
filter.run()
exit(0)

