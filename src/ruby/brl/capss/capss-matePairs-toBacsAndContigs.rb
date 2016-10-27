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

CONTIGS_2_BACS = {}

class MatePairRec
	attr_accessor :insertID, :matePairs
	
	def initialize(readID, bacID, contigID, idxOrd)
		@insertID = MatePairRec::makeInsertID(readID)
		@matePairs = {}
		@matePairs[readID] = [bacID, contigID, idxOrd]
	end

	def addReadID(readID, bacID, contigID, idxOrd)
		insertID = MatePairRec::makeInsertID(readID)
		if(@matePairs.key?(readID))		# then already mapped this read to this BAC? 
			raise "ERROR: the read '#{readID}' has already been assigned to '#{@matePairs[readID]}' but trying to assign it to '#{bacID},#{contigID},#{idxOrd}'"
		else # haven't mapped this read to bac yet
			@matePairs[readID] = [bacID, contigID, idxOrd]
		end
		return
	end

	def to_s
		# insert id
		asStr =	@insertID + "\t"
		# reads for insert
		asStr += (@matePairs.keys.sort.join("\t") + "\t")
		# index order(s) for each read
		if(@matePairs.size < 2) then asStr += ("none\t") end
		idxOrds = []
		@matePairs.keys.sort.each { |readID|
			asStr += (@matePairs[readID][2].to_s) + "\t"
		}
		if(@matePairs.size < 2) then asStr += ("none\t") end
		# bacs for each read
		bacList = []
		@matePairs.keys.sort.each { |readID|
			bacList << @matePairs[readID][0]
			asStr += (@matePairs[readID][0] + "\t")
		}
		if(@matePairs.size < 2) then asStr += ("none\t") end
		# Are bacs same for both reads or at least compatible?
		bacsSame = nil
		if(@matePairs.size >= 2)
			bacList.uniq!
			if(bacList.size == 1)
				asStr += true.to_s
				bacsSame = true
			else
				asStr += false.to_s
				bacsSame = false
			end
			asStr += "\t"
		else
			asStr += "n.a.\t"
		end
		# contigs for each read
		allContigs = []
		@matePairs.keys.sort.each { |readID|
			contigList = []
			allContigs << @matePairs[readID][1]
			asStr += @matePairs[readID][1] + "\t"
		}
		if(@matePairs.size < 2) then asStr += ("none\t") end
		# all in same contig?
		if(@matePairs.size >= 2)
			allContigs.uniq!
			if(allContigs.size == 1)
				asStr += true.to_s
			elsif(bacsSame)
				asStr += 'maybe'
			else
				asStr += false.to_s
			end
			asStr += "\t"
		else
			asStr += "n.a.\t"
		end
		return asStr
	end

	def areAllBacsSame?()
		bacList = []
		@matePairs.each { |readID, rec| bacList << rec[0] } 
		bacList.uniq!
		return (bacList.size == 1 ? true : false)
	end

	def areAllContigsSame?()
		contigList = []
		@matePairs.each { |readID, rec| contigList << rec[1] } 
		contigList.uniq!
		return (contigList.size == 1 ? true : false)
	end

	def MatePairRec::makeInsertID(readID)
		insertID = readID.dup
		insertID[6] = '_'
		return insertID
	end
end

class MatePair2BacInfo
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
	end

	def run()
		$stderr.puts "STATUS: begin analysis"
		@params = processArguments()
		$stderr.puts "STATUS: processed args"
		loadIndexFile()
		$stderr.puts "STATUS: loaded index file"
		# Find mate pair->bac assignments
		findMatePairs()
		# Write mate pair info
		dumpMatePairInfo()
		# Write bac info
		dumpBacInfo()
		# Wrtier contig info
		dumpContigInfo()
		return
	end

	def findMatePairs()
		@inserts = {}
		@byBac = {}
		@byContig = {}
		# Go through each detailed info rec (each bac)
		@indices.each { |bacID, indicesForBac|
			@byBac[bacID] = {} unless(@byBac.key?(bacID))
			indicesForBac.each { |fields|
				contigID = fields[2]
				@byContig[contigID] = {} unless(@byContig.key?(contigID))
				idxOrd = fields[7]
				@byBac[bacID][idxOrd] = [] unless(@byBac[bacID].key?(idxOrd))
				@byContig[contigID][idxOrd] = [] unless(@byContig[contigID].key?(idxOrd))
				# For each deconvoluted read
				fields[8].each { |readID|
					insertID = MatePairRec::makeInsertID(readID)
					if(@inserts.key?(insertID))
						@inserts[insertID].addReadID(readID, bacID, contigID, idxOrd)
					else # first of mate pair
						@inserts[insertID] = MatePairRec.new(readID, bacID, contigID, idxOrd)
						@byBac[bacID][idxOrd] << @inserts[insertID]
						@byContig[contigID][idxOrd] << @inserts[insertID]
					end
				}
			}
		}
		return
	end

	def dumpMatePairInfo()
		@matePairWriter = BRL::Util::TextWriter.new(@matePairFile, 'w+')
		@inserts.each { |insertID, rec|
			@matePairWriter.puts rec.to_s
		}
		@matePairWriter.close()
		return
	end

	def dumpBacInfo()
		@bacWriter = BRL::Util::TextWriter.new(@bacFile, 'w+')
		orders = [4, 3, 2]
		minOrders = [3,2]
		tmpArr = Array.new(4)
		@byBac.each { |bacID, byOrdHash|
			@bacWriter.print bacID + "\t"
			orders.each { |xx|
				@bacWriter.print numOkSingleReads(@byBac[bacID][xx]).to_s + "\t"
				@bacWriter.print numGoodMatePairs(@byBac[bacID][xx]).to_s + "\t"
				@bacWriter.print numMaybeMatePairs(@byBac[bacID][xx]).to_s + "\t"
				@bacWriter.print numBadMatePairs(@byBac[bacID][xx]).to_s + "\t"
			}
			minOrders.each { |xx|
				tmpArr = 0,0,0,0
				orders.each { |yy|
					if(yy >= xx)
						tmpArr[0] += numOkSingleReads(@byBac[bacID][yy])
						tmpArr[1] += numGoodMatePairs(@byBac[bacID][yy])
						tmpArr[2] += numMaybeMatePairs(@byBac[bacID][yy])
						tmpArr[3] += numBadMatePairs(@byBac[bacID][yy])
					end
				}
				@bacWriter.print tmpArr.join("\t") + "\t"
			}
			@bacWriter.puts ''
		}
		@bacWriter.close
		return
	end

	def dumpContigInfo()
		@contigWriter = BRL::Util::TextWriter.new(@contigFile, 'w+')
		orders = [4, 3, 2]
		minOrders = [3,2]
		tmpArr = Array.new(3)
		@byContig.each { |contigID, byOrdHash|
			@contigWriter.print contigID + "\t"
			orders.each { |xx|
				@contigWriter.print numOkSingleReads(@byContig[contigID][xx]).to_s + "\t"
				@contigWriter.print numGoodMatePairs(@byContig[contigID][xx]).to_s + "\t"
				@contigWriter.print numBadMatePairs(@byContig[contigID][xx]).to_s + "\t"
			}
			minOrders.each { |xx|
				tmpArr = 0,0,0
				orders.each { |yy|
					if(yy >= xx)
						tmpArr[0] += numOkSingleReads(@byContig[contigID][yy])
						tmpArr[1] += numGoodMatePairs(@byContig[contigID][yy])
						tmpArr[2] += numBadMatePairs(@byContig[contigID][yy])
					end
				}
				@contigWriter.print tmpArr.join("\t") + "\t"
			}
			@contigWriter.puts ''
		}
		@contigWriter.close
		return
	end

	def numOkSingleReads(inserts)
		numOK = 0
		unless(inserts.nil?)
			inserts.each { |mpRec|
				numOK += 1 if(mpRec.matePairs.size == 1)
			}
		end
		return numOK
	end

	def numBadMatePairs(inserts)
		numBad = 0
		unless(inserts.nil?)
			inserts.each { |mpRec|
				next unless(mpRec.matePairs.size == 2)
				numBad += 1 if(!mpRec.areAllBacsSame?())
			}
		end
		return numBad
	end

	def numGoodMatePairs(inserts)
		numGood = 0
		unless(inserts.nil?)
			inserts.each { |mpRec|
				next unless(mpRec.matePairs.size == 2)
				numGood += 1 if(mpRec.areAllBacsSame?() and mpRec.areAllContigsSame?())
			}
		end
		return numGood
	end

	def numMaybeMatePairs(inserts)
		numMaybe = 0
		unless(inserts.nil?)
			inserts.each { |mpRec|
				next unless(mpRec.matePairs.size == 2)
				numMaybe += 1 if((mpRec.areAllBacsSame?()) and !mpRec.areAllContigsSame?())
			}
		end
		return numMaybe
	end

	def loadIndexFile()
		@indices = {}
		@contigs2bacs = {}
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
			fields[3] = fields[3].to_i
			fields[6].map! { |xx| xx.to_i }
			@indices[fields[4]] = [] unless(@indices.key?(fields[4]))
			@indices[fields[4]] << fields
			CONTIGS_2_BACS[fields[2]] = {} unless(CONTIGS_2_BACS.key?(fields[2]))
			CONTIGS_2_BACS[fields[2]][fields[4]] = fields
		}
		reader.close
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--indexFile', '-i', GetoptLong::REQUIRED_ARGUMENT],
									['--matePairFile', '-m', GetoptLong::REQUIRED_ARGUMENT],
									['--bacFile', '-b', GetoptLong::REQUIRED_ARGUMENT],
									['--contigFile', '-c', GetoptLong::REQUIRED_ARGUMENT],
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
		@matePairFile = optsHash['--matePairFile']
		@contigFile = optsHash['--contigFile']
		@bacFile = optsHash['--bacFile']
		return
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -i     => File with bac deconvolution info records
    -m     => Output File to which matepair info will be written
    -b     => Output File to which bac matepair consistency info will be written
    -c     => Output File to which contig matepair consistency info will be written
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-matePairs-toBacsAndContigs.rb -i capssIndices.txt -m matePairInfo.out.txt -b bacInfo.out.txt -c
contigInfo.out.txt
"
		exit(134)
	end
end # class MatePair2BacInfo

end ; end

info = BRL::CAPSS::MatePair2BacInfo.new()
info.run()
exit(0)
