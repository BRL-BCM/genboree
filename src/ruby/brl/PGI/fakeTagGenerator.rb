#!/usr/bin/env ruby

=begin

=end
# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/dna/fastaRecord'
require 'brl/pgi/pooledBacInfo'	# for PoolBAC and PooledBACHash classes
require 'GSL'
include GSL::Random

# Turn on extra warnings and such
$VERBOSE = true

module BRL ; module PGI

	ALPHABET = ['A','T','G','C']

	GLOBAL_RNG = GSL::Random::RNG.new2(GSL::Random::RNG::CMRG)
#- ----------------------------------------------------------------------------
	#=== *Purpose* :
	# Represents a source chromosome pulled from an actual genome.
	class SrcChr
		attr_accessor :chrID, :length, :chrFile

		def initialize(chrID, length, chrFile)
			@chrID = chrID
			@length = length
			@chrFile = chrFile
		end

		def size()
			return @length
		end
	end

#- ----------------------------------------------------------------------------
	#=== *Purpose* :
	# Represents a fake BAC pulled from an actual genome.
	class FakeBAC
		attr_accessor :sequence
		attr_accessor :bacSuffix, :bacID, :proj
		attr_accessor :chrObj
		attr_accessor :chrStart, :chrStop, :cleared

		@@currBacID = 0
		HEADER = "#id\tlength\tstart\tstop\tchrID\tchrLength\tchrFile"

		def initialize(range, chrObj, bacID=nil, proj=nil, bacSuffix='fakeBAC.')
			@bacSuffix = bacSuffix
			@chrObj = chrObj
			@chrStart = range.first
			@chrStop = range.last
			if(bacID.nil?)
				@@currBacID += 1
				@bacID = "FakeBac_#{@@currBacID}"
			else
				@bacID = bacID
			end
			unless(proj.nil?)
				@proj = proj
			else
				@proj = ''
				4.times { @proj += ((GLOBAL_RNG.uniform * 26)+65).floor.chr }
			end
			@cleared = false
		end

		def clear()
			@bacID = @proj = @chrObj = @chrStart = @chrStop = @bacSuffix = nil
			@sequence = '' ; @sequence = nil
			@cleared = true
		end

		def size()
			return @chrStop - @chrStart
		end

		def length()
			return size()
		end

		def makeDefline()
			defline = ">#{self.defLineID()} " +
								"ORIG_LENGTH: #{self.size} " +
								"START: #{@chrStart} " +
								"STOP: #{@chrStop} " +
								"CHR_ID: #{@chrObj.chrID} " +
								"CHR_LENGTH: #{@chrObj.length} "
			return defline
		end

		def defLineID()
			return (@chrObj.chrID + '.' + @bacSuffix.to_s + @bacID.to_s)
		end

		def to_s()
			return "#{self.defLineID()}\t#{self.size}\t#{@chrStart}\t#{@chrStop}\t#{@chrObj.chrID}\t#{@chrObj.length}\t#{@chrObj.chrFile}"
		end
	end

	#- ----------------------------------------------------------------------------
	#=== *Purpose* ;
	# Represents a fake read (possibly from a fake BAC).
	class FakeRead
		attr_accessor :sequence
		attr_accessor :readSuffix, :readID, :readLength, :isWGS, :srcObj, :isFwd
		attr_accessor :srcStart, :srcStop, :poolID
		attr_accessor :mateRead

		@@currReadID = 0

		def initialize( range, srcObj, isWGS, projID=nil, readID=nil, isFwd=true, readSuffix='.fakeRead.')
			@readSuffix = readSuffix
			@isWGS = isWGS
			@isFwd = isFwd
			@srcStart = range.first
			@srcStop = range.last
			@srcObj = srcObj
			@poolID = projID
			@sequence = ''
			@readID = readID.nil?() ? FakeRead.makeReadID(@poolID, @isFwd) : readID
			@cleared = false
			@readLength = range.size
			@mateRead = nil
		end

		def FakeRead.makeReadID(projID, isFwd=true)
			readID = ''
			unless(projID.nil?)
				readID = projID
			else # we need to make a projID
				4.times { readID += ((GLOBAL_RNG.uniform * 26)+65).floor.chr }
			end
			readID += 'A1'
			readID += (isFwd ? 'D' : 'E')
			readID += sprintf('%06d', (@@currReadID += 1))
			return readID.upcase
		end

		def clear()
			@mateRead = @realdLength = @srcObj = @readSuffix = @isWGS = @srcStart = @srcStop = @poolID = @readID = nil
			@sequence = '' ; @sequence = nil
			@cleared = true
		end

		def size()
			return @srcStop - @srcStart
		end

		def length()
			return size()
		end

		def makeDefline()
			poolStr = (@poolID.nil? or @poolID.empty?) ? '' : "POOL_ID: #{@poolID} "

			defline = ">#{self.defLineID()} " +
								"ORIG_LENGTH: #{self.size()} " +
								"START: #{@srcStart} " +
								"STOP: #{@srcStop} " +
								"ORIENT: #{@isFwd ? 'FWD' : 'REV'} "

			unless(@isWGS)
				defline <<	"BAC_ID: #{@srcObj.bacID} " +
										"BAC_START: #{@srcObj.chrStart} " +
										"BAC_STOP: #{@srcObj.chrStop} " +
										"BAC_LENGTH: #{@srcObj.size} " +
										poolStr +
										"CHR_ID: #{@srcObj.chrObj.chrID} " +
										"CHR_LENGTH: #{@srcObj.chrObj.size} "
			else
				defline <<	"CHR_ID: #{@srcObj.chrID} " +
										"CHR_LENGTH: #{@srcObj.size} "
			end
			unless(@mateRead.nil?)
				defline <<  "MATE READ: #{@mateRead.defLineID()} "
			end
			return defline
		end

		def defLineID()
			return @readID.to_s
		end

		def header()
			headerStr = "#id\tLength\tStart\tStop\t"
			poolStr = (@poolID.nil? or @poolID.empty?) ? '' : "PoolID\t"

			unless(@isWGS)
				headerStr <<	"BacID\tBacStart\tBacStop\tBacLength\t" +
											poolStr
			end
			headerStr << "ChrID\tChrLength\tChrFile"
			unless(@mateRead.nil?)
				headerStr << "\tOrient\tMatePairName"
			end
			return headerStr
		end

		def to_s
			poolStr = (@poolID.nil? or @poolID.empty?) ? '' : "#{@poolID}\t"

			asStr =	"#{self.defLineID()}\t#{self.size}\t#{@srcStart}\t#{@srcStop}\t"

			unless(@isWGS)
				asStr <<	"#{@srcObj.bacID}\t#{@srcObj.chrStart}\t#{@srcObj.chrStop}\t#{@srcObj.size}\t" +
									poolStr +
									"#{@srcObj.chrObj.chrID}\t#{@srcObj.chrObj.size}\t#{@srcObj.chrObj.chrFile}"
			else
				asStr <<	"#{@srcObj.chrID}\t#{@srcObj.size}\t#{@srcObj.chrFile}"
			end
			unless(@mateRead.nil?)
				asStr << "\t#{@isFwd ? 'FWD' : 'REV'}\t#{@mateRead.defLineID}"
			end
			return asStr
		end
	end

#- ----------------------------------------------------------------------------
	#=== *Purpose* :
	# Represents a single base mutation event: a base transformation or an indel.
	class MutationEvent
		attr_accessor :mutType, :mutValue, :offset

		TRANSFORMATION_MUT, INDEL_MUT = 0,1
		INSERTION_MUT, DELETION_MUT = 0,1

		def initialize(offset=nil, mutType=nil, mutValue=nil)
			@offset,@mutType,@mutValue = offset,mutType,mutValue
		end
	end

#- ----------------------------------------------------------------------------

	#=== *Purpose* :
	# A class that generates fake reads and tags based on user settings.
	class FakeTagGenerator
		attr_accessor :chrSrcs, :selectedBACs, :selectedReads
		attr_accessor :currFakeBAC, :currSelectedReads
		attr_accessor :currFullSeqRecord
		attr_accessor :curr_region
		
		DEFLINE, SEQLINE = 0,1

		# Required properties
		PROP_KEYS = 	%w{
											input.src.chrDir
											input.src.chrFilePrefix
											input.src.chrFileSuffix
											input.src.chrIDList
											input.src.chrIDPrefix
											input.src.chrIDSuffix
											input.info.chrLengthsFile
											input.pooling.bac2poolMapFile
											input.randomSeed
											param.approach.makeWGSReads
											param.approach.numWGSReadsToMake
											param.approach.doPoolAssignment
											param.weightChrSelectionByLength
											param.pooling.numArrays
											param.pooling.numPoolsPerBAC
											param.pooling.doNonUniformPoolAssignment
											param.pooling.poolBiasByRankFile
											param.bacs.maxPercentNsInSelectedSrc
											param.bacs.numBACsToGenerate
											param.bacs.doMutateBacs
											param.bacs.bacMutationProbability
											param.bacs.bacProbabilityMutationIsInDel
											param.bacs.fakeBACLength
											param.bacs.minReadsPerFakeBAC
											param.bacs.maxReadsPerFakeBAC
											param.bacs.allowBACOverlap
											param.reads.doMatePairs
											param.reads.insertMean
											param.reads.insertStdev
											param.reads.minInsertCutoff
											param.reads.maxPercentNsInSelectedSrc
											param.reads.doMutateReads
											param.reads.readMutationProbability
											param.reads.readProbabilityMutationIsInDel
											param.reads.fakeReadLength
											param.reads.allowReadOverlap
											param.doOutputMutationMasks
											output.outDir
											output.bacSubDir
											output.readSubDir
											output.bacs.fakeBACFileBase
											output.fakeReadFileBase

										} ;

		# * *Function*: Instantiates a FakeTagGenerator class.
		# * *Usage*   : <tt> tagGenerator = BRL::PGI::FakeTagGenerator </tt>
		# * *Args*    :
		#   - +optsHash+  ->  Hash of user-provided command line arguments.
		# * *Returns* :
		#   - +FakeTagGenerator+  ->  Instance of BRL::PGI::FakeTagGenerator
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def initialize(optsHash)
			@optsHash = optsHash
			@propTable = BRL::Util::PropTable.new(File.open(optsHash['--propFile']))
			# If options supplied on command line instead, use them rather than those in propfile
			PROP_KEYS.each {
				|propName|
				argPropName = "--#{propName}"
				unless(optsHash[argPropName].nil?)
					@propTable[propName] = optsHash[argPropName]
				end
			}
			# Verify the proptable contains what we need
			@curr_region = nil
			@propTable.verify(PROP_KEYS)
			@chrSrcs = {}
			@chrLengths = {}
			@chrWeights = []
			@chrObjs = {}
			@selectedBACs = {}
			@selectedReads = {}
			@pooledBacHash = {}
			@currFullSeq = ''
			@selReadsInBac = {}
			setParameters()
			# instantiate a random number generator
			GLOBAL_RNG.set(@rngSeed.to_i)
			# setup pool info if necessary
			if(@doPoolAssignment)
				$stderr.puts "START: Read BAC to Pools map"
				readBac2PoolsMap()
				$stderr.puts "STOP: Done reading BAC to Pools map"
				if(@doNonUniformPoolAssignment)
					# set up pool bias pattern
					$stderr.puts "START: create pool bias model"
					loadPoolBiasInfo()
					$stderr.puts "STATUS: loaded pool bias model from file"
					shuffleBacLists()
					$stderr.puts "STATUS: shuffled BAC lists for each pool"
					makeBacRanksInPools()
					$stderr.puts "STATUS: made POOL->BAC->RANK mappings"
					$stderr.puts "STOP: Done creating pool bias model"
				end
			end
			# setup src lengths hash
			readChrLengths()
		end

		def loadPoolBiasInfo()
			percRep_byBac = []
			reader = BRL::Util::TextReader.new(@poolBiasFile)
			reader.each { |line|
				line.strip!
				percRep_byBac << line.to_f
			}
			# sort the percRep, low->high
			percRep_byBac.sort! { |aa,bb| bb <=> aa }
			# operationally, need perc of read rejection by rank
			@probReadRejectByRank = []
			percRep_byBac.each { |pp|
				@probReadRejectByRank << (1.0 - (pp / percRep_byBac[0]))
			}
			# print to stderr for tracking
			$stderr.puts "POOL BIAS MODEL:\nRank\t%"
			percRep_byBac.each_with_index { |rep, ii|
				$stderr.puts "#{ii}\t#{sprintf('%.2f',rep)}%"
			}
			return
		end

		# * *Function*: Sets up all the user's settings and parameters for use in generating reads/tags.
		# * *Usage*   : <tt>    </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - +none+
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def setParameters()
			@chrDir      													= @propTable['input.src.chrDir']
			@chrFilePrefix      									= @propTable['input.src.chrFilePrefix']
			@chrFileSuffix      									= @propTable['input.src.chrFileSuffix']
			@chrIDList      											= @propTable['input.src.chrIDList']
			@chrIDPrefix                          = @propTable['input.src.chrIDPrefix']
			@chrIDSuffix                          = @propTable['input.src.chrIDSuffix']
			@chrIDList.each {
				|cid|
				chrID = "#{@chrIDPrefix}#{cid}#{@chrIDSuffix}"
				@chrSrcs[chrID] = "#{@chrDir}/#{@chrFilePrefix}#{cid}#{@chrFileSuffix}"
			}
			@chrLengthFileName      							= @propTable['input.info.chrLengthsFile']
			@bac2poolMapFileName      						= @propTable['input.pooling.bac2poolMapFile']
			@rngSeed	= @propTable['input.randomSeed'].nil? ?  (Time.now().to_i  ^ ($$+($$<<15))) : @propTable['input.randomSeed'].to_i

			@makeWGSReads      										= @propTable['param.approach.makeWGSReads'].to_i == 1 ? true : false
			@wgsProj = ''
			if(@makeWGSReads)
				4.times { @wgsProj += ((GLOBAL_RNG.uniform * 26)+65).floor.chr }
			end
			@numWGSReadsToMake										= @propTable['param.approach.numWGSReadsToMake'].to_i
			@doPoolAssignment      								= @propTable['param.approach.doPoolAssignment'].to_i == 1 ? true : false
			@weightChrSelectionByLength      			= @propTable['param.weightChrSelectionByLength'].to_i == 1 ? true : false
			@numArrays      											= @propTable['param.pooling.numArrays'].to_i
			@numPoolsPerBAC      									= @propTable['param.pooling.numPoolsPerBAC'].to_i
			@doNonUniformPoolAssignment      			= @propTable['param.pooling.doNonUniformPoolAssignment'].to_i == 1 ? true : false
			if(@doNonUniformPoolAssignment)
				@poolBiasFile                       = @propTable['param.pooling.poolBiasByRankFile']
			end
			@bacsMaxPercNsInSrc      							= @propTable['param.bacs.maxPercentNsInSelectedSrc'].to_f / 100.0
			@numBACsToGenerate      							= @propTable['param.bacs.numBACsToGenerate'].to_i
			@doMutateBacs      										= @propTable['param.bacs.doMutateBacs'].to_i == 1 ? true : false
			@bacMutationProbability      					= @propTable['param.bacs.bacMutationProbability'].to_f / 100.0
			@bacProbabilityMutationIsInDel      	= @propTable['param.bacs.bacProbabilityMutationIsInDel'].to_f / 100.0
			@fakeBacLength      									= @propTable['param.bacs.fakeBACLength'].to_i
			@minReadsPerFakeBac      							= @propTable['param.bacs.minReadsPerFakeBAC'].to_i
			@maxReadsPerFakeBac      							= @propTable['param.bacs.maxReadsPerFakeBAC'].to_i
			@allowBACOverlap      								= @propTable['param.bacs.allowBACOverlap'].to_i == 1 ? true : false
			@doMatePairs                          = @propTable['param.reads.doMatePairs'].to_i == 1 ? true : false
			if(@doMatePairs)
				@insertMean                         = @propTable['param.reads.insertMean'].to_f
				@insertStdev                        = @propTable['param.reads.insertStdev'].to_f
				@insertMin                          = @propTable['param.reads.minInsertCutoff'].to_f
			end
			@readsMaxPercNsInSrc     							= @propTable['param.reads.maxPercentNsInSelectedSrc'].to_f / 100.0
			@doMutateReads      									= @propTable['param.reads.doMutateReads'].to_i == 1 ? true : false
			@doOutputMutationMasks                = @propTable['param.doOutputMutationMasks'].to_i == 1 ? true : false
			@readMutationProbability      				= @propTable['param.reads.readMutationProbability'].to_f / 100.0
			@readProbabilityMutationIsInDel      	= @propTable['param.reads.readProbabilityMutationIsInDel'].to_f / 100.0
			@fakeReadLength      									= @propTable['param.reads.fakeReadLength'].to_i
			@allowReadOverlap      								= @propTable['param.reads.allowReadOverlap'].to_i == 1 ? true : false
			@outDir      													= @propTable['output.outDir']
			@fakeBacFileBase      								= @propTable['output.bacs.fakeBACFileBase']
			@fakeReadFileBase      								= @propTable['output.fakeReadFileBase']
			@bacSubDir                            = @propTable['output.bacSubDir']
			@readSubDir                           = @propTable['output.readSubDir']
			return
		end # END: def setParameters()

		def selectInsertSize()
			insertSize = nil
			loop {
				modifier = RND::gaussian(GLOBAL_RNG, @insertStdev)
				insertSize = (@insertMean + modifier).round
				if(insertSize < @insertMin)
					redo
				else
					break
				end
			}
			return insertSize
		end

		# * *Function*:
		# * *Usage*   : <tt>    </tt>
		# * *Args*    :
		#   - ++  ->
		# * *Returns* :
		#   - ++  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def readChrLengths()
			chrLengthFile = BRL::Util::TextReader.new(@chrLengthFileName)
			totalLength = 0
			chrLengthFile.each { |line|
				if(line =~ /^(\S+)\s+(\S+)/)
					next unless(@chrSrcs.key?($1))
					@chrLengths[$1] = $2.to_i
					@chrObjs[$1] = BRL::PGI::SrcChr.new($1, $2.to_i, @chrSrcs[$1])
					totalLength += $2.to_i
				end
			}
			totalLength = totalLength.to_f
			chrLengthFile.close unless(chrLengthFile.nil? or chrLengthFile.closed?)
			@chrLengths.keys.each_with_index {
				|chrID, ii|
				if(@weightChrSelectionByLength)
					@chrWeights << [ (@chrLengths[chrID].to_f / totalLength) + (ii<1 ? 0 : @chrWeights[ii-1][0]), chrID ]
				else
					@chrWeights << [ 1.0 / @chrLengths.size + (ii<1 ? 0 : @chrWeights[ii-1][0]), chrID ]
				end
			}
			$stderr.puts "Chr\tWeight\tLength"
			@chrWeights.each { |wRec|
				$stderr.puts "'#{wRec[1]}'\t'#{wRec[0]}'\t'#{@chrLengths[wRec[1]]}'"
			}
			return
		end

		# * *Function*:
		# * *Usage*   : <tt>    </tt>
		# * *Args*    :
		#   - ++  ->
		# * *Returns* :
		#   - ++  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def readBac2PoolsMap
			# Create PooledBACHash
			@pooledBacHash = BRL::PGI::PooledBACHash.new(@bac2poolMapFileName, @numArrays)
			@pool2bacsList = {}
			@pooledBacHash.keys.each { |bacID|
				@pooledBacHash[bacID].pools.each { |pool|
					@pool2bacsList[pool] = [] unless(@pool2bacsList.key?(pool))
					@pool2bacsList[pool] << bacID
				}
			}
			return
		end

		def shuffleBacLists()
			@pool2bacsList.keys.each { |pool|
				@pool2bacsList[pool].shuffle(GLOBAL_RNG)
			}
			return
		end

		def makeBacRanksInPools()
			@bacRankInPools = {}
			@pool2bacsList.each { |pool, bacArray|
				@bacRankInPools[pool] = {}
				bacArray.each_with_index { |bac, ii|
					@bacRankInPools[pool][bac] = ii
				}
			}
# 			$stderr.puts "Bac rejection values by pool:"
# 			@bacRankInPools.keys.sort.each  { |pool|
# 				sbacs = @bacRankInPools[pool].keys.sort { |aa,bb| @bacRankInPools[pool][aa] <=> @bacRankInPools[pool][bb] }
# 				sbacs.each { |bac|
# 					val = @bacRankInPools[pool][bac]
# 					$stderr.puts "#{pool} --> #{bac} --> #{val}"
# 				}
# 				$stderr.puts '-'*25
# 			}
			return
		end

		# * *Function*:
		# * *Usage*   : <tt>    </tt>
		# * *Args*    :
		#   - ++  ->
		# * *Returns* :
		#   - ++  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def makeFakeReads()
			progressBasis = @makeWGSReads ? @numWGSReadsToMake : @numBACsToGenerate
			progressStep = 10 ** Math.log10(progressBasis.to_f / 10.0).round()
			progressStep = 1000 if(progressStep < 1)

			# place holders for data that *may* be used
			thePoolID = nil

			$stderr.puts "START: selection of read locations."
			@pooledBacList = (@doPoolAssignment ? @pooledBacHash.keys : nil)

			ii = 0
			while(true) do
				# exit tests
				unless(@makeWGSReads)
					if(ii >= @numBACsToGenerate) then break ; end
				else
					if(ii >= @numWGSReadsToMake) then break ; end
				end
				# progress message
				if(ii % progressStep == 0 and ii > 0)
					$stderr.puts "\tPROGRESS: '#{ii}' so-called fake #{@makeWGSReads ? 'wgs reads' : 'BACs'} completed"
					GC.start
				end
				chrID =	chrObj = bacID = bacRange = nil
				numReads = 1 # This is for WGS...will be changed if doing BACs
				unless(@makeWGSReads) # then need to select a BAC region
					loop {
						# select a chr
						chrID = selectChr()
						chrObj = @chrObjs[chrID]
						# get num reads
						numReads = selectNumReads()
						# ####### Select A BAC ##########################################
						bacID = @doPoolAssignment ? @pooledBacList[ii] : nil
						bacRange = selectRegion(@chrLengths[chrID], @fakeBacLength)
						unless(@allowBACOverlap)
							unless(isNovelBacRange?(chrID, bacRange, @selectedBACs))
								redo	# until we get a novel region
							else
								break	# got a novel region
							end
						else # don't care about overlap, take anything
							break
						end
					}
					fakeBac = FakeBAC.new(bacRange, chrObj, bacID)
					bacID = fakeBac.bacID # get the actual one used
					if(@selectedBACs[chrID].nil?) then @selectedBACs[chrID] = [] end
					@selectedBACs[chrID] << fakeBac
					@selReadsInBac[bacID] = [] unless(@selReadsInBac.key?(bacID))
					ii += 1
				end

				# select reads
				readRange = nil
				numReads.times { |jj|
					# First, should we even *make* this read? Or should skip it?
					# This only applies to pool assignment with non-uniform bias:
					#   - assign the read to a pool
					#   - reject the read if the pool bias says to, for that bac in that pool
					if(@doPoolAssignment and !@makeWGSReads)
						poolIndex = uniformPoolSelection()
						thePoolID = @pooledBacHash[fakeBac.bacID].pools[poolIndex]
						# Are we doing non-uniform pool assignment? If so, we may just skip this read!!!!
						if(@doNonUniformPoolAssignment)
							rejectProbRank = @bacRankInPools[thePoolID][fakeBac.bacID]
							rejectProb = @probReadRejectByRank[rejectProbRank]
							randProb = GLOBAL_RNG.uniform
							next if(randProb < rejectProb) # This read is being removed to yield bias
						end
					end
					loop {		# If here, then we will try to select a location for the read
						if(@makeWGSReads) # then we still need to select a chr
							chrID = selectChr()
							chrObj = @chrObjs[chrID]
						end
						# select the read from the appropriate source (chr or bac)
						readRange = selectRegion((@makeWGSReads ? chrObj.size : bacRange.size), @fakeReadLength)
						isNovel = true
						if(@makeWGSReads)
							unless(@allowReadOverlap)
								isNovel = isNovelReadRange?(chrID, readRange, @selectedReads)
							end
						else # making bacs
							unless(@allowReadOverlap)
								isNovel = isNovelReadRangeWithinBac?(readRange, @selReadsInBac[bacID])
							end
						end
						break if(isNovel) # else repeat
					}
					# if doing mate pairs, we need to find the mate's range and make some decisions
					if(@doMatePairs)
						# select an insert size
						insertSize = self.selectInsertSize()
						if((readRange.first + insertSize) < (@makeWGSReads ? chrObj.size : bacRange.size))
							# then the other mate can be downstream from the current one and be the reverse
							mateReadRange = Range.new((readRange.first + insertSize) - @fakeReadLength, readRange.first + insertSize)
							mateIsRev = true
						elsif(readRange.first - insertSize > 0)
							# then the other mate has to be upstream from the current one and be the forward
							mateReadRange = Range.new(readRange.last - insertSize, (readRange.last - insertSize) + @fakeReadLength)
							mateIsRev = false
						else # arg....the src is smaller than the insert size!!!
							$stderr.puts "\nERROR: your src regions (chromosomes for wgs or bacs) are too small! They are smaller than the read insert size!! Can't make mate pairs if that's the case!!!"
							exit(141)
						end
					end
					fakeRead = FakeRead.new(readRange, (@makeWGSReads ? chrObj : fakeBac), @makeWGSReads)
					if(@doMatePairs)
						revFakeRead = FakeRead.new(mateReadRange, (@makeWGSReads ? chrObj : fakeBac ), @makeWGSReads)
						if(mateIsRev)
							revFakeRead.isFwd = false
						else
							fakeRead.isFwd = false
						end
						fakeRead.mateRead = revFakeRead
						revFakeRead.mateRead = fakeRead
					end
					if(@doPoolAssignment)
						fakeRead.poolID = thePoolID
						fakeRead.readID = FakeRead.makeReadID(fakeRead.poolID, fakeRead.isFwd)
						if(@doMatePairs)
							revFakeRead.poolID = thePoolID
							revFakeRead.readID = FakeRead.makeReadID(revFakeRead.poolID, revFakeRead.isFwd)
						end
					end
					ii += 1 if(@makeWGSReads)
					if(@selectedReads[chrID].nil?) then @selectedReads[chrID] = [] end
					@selectedReads[chrID] << fakeRead
					unless(@makeWGSReads) # keep track of reads in this bac
						@selReadsInBac[bacID] << fakeRead
					end
				}
			end
			numSelBacs = 0
			numSelReads = 0
			@selectedBACs.each { |chrID, fakeBacs| numSelBacs += fakeBacs.size }
			@selectedReads.each { |chrID, fakeReads| numSelReads += fakeReads.size }
			$stderr.puts "STOP: all reads selected ; num bacs: '#{numSelBacs}' ; num reads: '#{numSelReads}'"
			unless(@makeWGSReads)
				# $stderr.puts "Bac IDs are:"
				# @selectedBACs.each { |chrID, fakeBacs| fakeBacs.each { |fakeBac| $stderr.puts "\t'#{fakeBac.bacID}' on '#{fakeBac.chrObj.chrID}'" }}
				$stderr.puts "BACs / CHROMOSOME:"
				@selectedBACs.each { |chrID, fakeBacs| $stderr.puts "\t'#{chrID}'  -->  '#{fakeBacs.size}'" }
			end
			$stderr.puts "READs / CHROMOSOME:"
			@selectedReads.each { |chrID, fakeReads| $stderr.puts "\t'#{chrID}'  -->  '#{fakeReads.size}'" }
			GC.start()
			return
		end

		# * *Function*:
		# * *Usage*   : <tt>    </tt>
		# * *Args*    :
		#   - ++  ->
		# * *Returns* :
		#   - ++  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def dumpFakeRegions()
			bacDir = nil
			@deletedReadSeqFile = {}
			@openReadSeqFiles = {}
			$stderr.puts "START: extract, mutate, and dump fake BACs and their reads"
			# open info outputs
			Dir.recursiveSafeMkdir(@outDir)
			unless(@makeWGSReads)
				bacInfoFileName = "#{@outDir}/fakeBac.info"
				bacInfoFile = BRL::Util::TextWriter.new(bacInfoFileName, 'w', false)
			end
			readInfoFileName = "#{@outDir}/fakeRead.info"
			readInfoFile = BRL::Util::TextWriter.new(readInfoFileName, 'w', false)
			
			# header info
			bacInfoFile.puts FakeBAC::HEADER unless(@makeWGSReads)
			readInfoFile.puts @selectedReads[@selectedReads.keys[0]][0].header

			baseBacSeqFileName = "#{@fakeBacFileBase}.fakeBacs.fa" unless(@makeWGSReads)
			baseReadFileName = "#{@fakeReadFileBase}.fakeReads.fa"

			# open the one output file for WGS reads
			if(@makeWGSReads)
				outDir = "#{@outDir}" + (@readSubDir.to_s.empty?() ? '' : "/#{@readSubDir}")
				Dir.recursiveSafeMkdir(outDir)
				readSeqFileName = "#{outDir}/#{baseReadFileName}"
				unless(@deletedReadSeqFile.key?(readSeqFileName))
					File.delete(readSeqFileName) if(File.exists?(readSeqFileName))
					@deletedReadSeqFile[readSeqFileName] = true # even if doesn't exist, make sure to flag so we don't delete it next time!
				end
				readSeqFile = BRL::Util::TextWriter.new(readSeqFileName, 'w+', false)
			end

			# for each chr, suck in chr fasta file and make its BACs & reads
			@chrIDList.each {	|cid|
				chrID = "#{@chrIDPrefix}#{cid}#{@chrIDSuffix}"
				$stderr.puts "\tPROGRESS: Doing fake #{@makeWGSReads ? 'reads' : 'BACs'} from chr '#{chrID}'"
				next if(!@makeWGSReads and (@selectedBACs[chrID].nil? or @selectedBACs[chrID].empty?))
				$stderr.print "\t\t- getting src sequence to work with..."
				getSeqRecordForID(cid)
				$stderr.puts " ...done. Sequence is #{@currFullSeqRecord.size} long. "

				# ############ DUMP BAC DATA #######################################
				unless(@makeWGSReads)
					 # make ALL BAC data for current chr
					fakeBacs = @selectedBACs[chrID]
					fakeBacs.each { |fakeBac|
						# open chr-seq outputs
						$stderr.puts "\t\tDoing Bac '#{fakeBac.bacID}' on chr '#{chrID}' (BAC is on '#{fakeBac.chrObj.chrID}')"
						bacDir = "#{@outDir}/" + (@bacSubDir.to_s.empty?() ? '' : "#{@bacSubDir}/") + "#{fakeBac.bacID}"
						Dir.recursiveSafeMkdir(bacDir)
						bacSeqFileName = "#{bacDir}/#{baseBacSeqFileName}"
						bacSeqFile = BRL::Util::TextWriter.new(bacSeqFileName, 'w', false)
						fakeBac.chrObj.chrFile = @chrSrcs[chrID]
						# dump BAC info
						$stderr.print "\t\t  - dumping bac INFO to info file..."
						bacInfoFile.puts fakeBac.to_s
						$stderr.puts "done"
						# ############# Get bac sequence filled in
						$stderr.puts "FILLING IN SEQUENCE FOR FAKE BAC who has this info:\n\n#{fakeBac}\n\n"
						fakeBac = fillInBacSequence(fakeBac)
						$stderr.puts "FILLED IN THE SEQUENCE...it is #{fakeBac.sequence.size} long."
						# create the final fake bac sequence
						if(@doMutateBacs)
							$stderr.print "\t\t  - mutating...."
							@curr_region = fakeBac
							mutateRegion(@bacMutationProbability, @bacProbabilityMutationIsInDel)
							fakeBac = @curr_region
							$stderr.puts "done"
						end
						# dump BACs seq
						$stderr.print "\t\t  - dumping defline..."
						bacSeqFile.puts fakeBac.makeDefline()
						$stderr.puts "done"
						$stderr.print "\t\t  - dumping sequence..."
						bacSeqFile.puts fakeBac.sequence
						$stderr.puts "done"
						bacSeqFile.close unless(@makeWGSReads or bacSeqFile.nil? or bacSeqFile.closed?)
					}
					# Keep bac sequence around until we make all the reads from it
				end

				# ############ DUMP READ DATA #######################################
				$stderr.puts "\t\t------------------------------------------------------------------"
				$stderr.puts "\t\tMaking reads from '#{chrID}' as source (or from BACs from this chr)"
				$stderr.puts "\t\tThere are '#{@selectedReads[chrID].size}' reads to make"
				$stderr.puts "\t\t------------------------------------------------------------------"
				readProgressBasis = @selectedReads[chrID].size
				readProgressStep = 10 ** Math.log10(readProgressBasis.to_f / 10.0).round()
				readProgressStep = 1000 if(readProgressStep < 1)
				kk = 0
				fakeReads = @selectedReads[chrID]
				fakeReads.each { |fakeRead|
					kk += 1
					if(kk % readProgressStep == 0 and kk > 0)
						$stderr.puts "\t\t  - PROGRESS: '#{kk}' so-called fake reads completed"
						GC.start
					end
					unless(@makeWGSReads)
						fakeBac = fakeRead.srcObj
						if(@doPoolAssignment)
							fakePool = fakeRead.poolID
						end
					  if(@doPoolAssignment) # making and pooling bacs
							poolReadDir = "#{@outDir}/" + (@readSubDir.to_s.empty?() ? '' : "#{@readSubDir}/") + "#{fakeRead.poolID}"
							Dir.recursiveSafeMkdir(poolReadDir)
							if(@fakeReadFileBase =~ /^(.*)\/[^\/]+$/)
								subPath = $1
								realPoolReadDir = "#{poolReadDir}/#{subPath}"
								Dir.recursiveSafeMkdir(realPoolReadDir)
							end
							readSeqFileName = "#{poolReadDir}/#{baseReadFileName}"
						else # making bacs but not pooling them
							outDir = "#{@outDir}/" + (@bacSubDir.to_s.empty?() ? '' : "#{@bacSubDir}/" ) + "#{fakeRead.srcObj.bacID}"
							Dir.recursiveSafeMkdir(outDir)
							readSeqFileName = "#{outDir}/#{baseReadFileName}"
						end
						unless(@deletedReadSeqFile.key?(readSeqFileName))
							File.delete(readSeqFileName) if(File.exists?(readSeqFileName))
							@deletedReadSeqFile[readSeqFileName] = true # even if doesn't exist, make sure to flag so we don't delete it next time!
						end
						readSeqFile = getReadSeqFile(readSeqFileName)
					end

					# ###### Get read sequence filled int
					# create fake read sequence
					fakeRead = fillInReadSequence(fakeRead)
					if(@doMutateReads)
						@curr_region = fakeRead
						mutateRegion(@readMutationProbability, @readProbabilityMutationIsInDel)
						fakeRead = @curr_region
						if(@doMatePairs)
							@curr_region = fakeRead.mateRead
							mutateRegion(@readMutationProbability, @readProbabilityMutationIsInDel)
							fakeRead.mateRead = @curr_region
						end
					end
					# dump read info
					readInfoFile.puts fakeRead.to_s
					# dump read seq
					readSeqFile.puts fakeRead.makeDefline()
					readSeqFile.puts fakeRead.sequence
					if(@doMatePairs)
						# dump read info
						readInfoFile.puts fakeRead.mateRead.to_s
						# dump read seq
						readSeqFile.puts fakeRead.mateRead.makeDefline()
						readSeqFile.puts fakeRead.mateRead.sequence
						# clear out what we can ; done with this read
						# fakeRead.mateRead.sequence = '' ; fakeRead.mateRead.sequence = nil
						fakeRead.mateRead.clear()
					end
					# clear out what we can ; done with this read
					# fakeRead.sequence = '' ; fakeRead.sequence = nil
					fakeRead.clear()
					fakeReads[kk-1] = nil
				} # Done all reads (and bacs) on this chromosome
				@selectedReads[chrID].clear()
				@selectedReads.delete(chrID)

				# done with bac sequences on this chr too
				unless(@makeWGSReads)
					@selectedBACs[chrID].each { |fakeBac|
						# Remove the reads/bac list for this bac
						@selReadsInBac[fakeBac.bacID].each_index { |ii| @selReadsInBac[fakeBac.bacID][ii] = nil }
						@selReadsInBac[fakeBac.bacID].clear()
						@selReadsInBac.delete(fakeBac.bacID)
						if(fakeBac.chrObj.chrID == chrID)
							#fakeBac.sequence = '' ; fakeBac.sequence = nil ; fakeBac.cleared = true
							fakeBac.clear()
						# else not safe to delete bac yet....haven't done the reads for it yet
						end
					}
				end
				@currFullSeqRecord = '' ; @currFullSeqRecord = nil
				GC.start
			} # END: @chrIDList.each
			# close info files
			bacInfoFile.close unless(@makeWGSReads or bacInfoFile.nil? or bacInfoFile.closed?)
			readInfoFile.close unless(bacInfoFile.nil? or bacInfoFile.closed?)
			$stderr.puts "STOP: done dumping fake sequence data"
			# close the output file if doing wgs
			if(@makeWGSReads)
				readSeqFile.close unless(readSeqFile.nil? or readSeqFile.closed?)
			end
			# close any open cached writers
			@openReadSeqFiles.each { |fileName, writer| writer.close }
			return
		end

		def getReadSeqFile(readSeqFileName)
			unless(@openReadSeqFiles.key?(readSeqFileName))
				if(@openReadSeqFiles.size > 96) # then need to make room in cache
					@openReadSeqFiles[@openReadSeqFiles.keys[0]].close
					@openReadSeqFiles.delete(@openReadSeqFiles.keys[0])
				end
				# open the file and cache the io object
				@openReadSeqFiles[readSeqFileName] = BRL::Util::TextWriter.new(readSeqFileName, 'a+', false)
			end
			return @openReadSeqFiles[readSeqFileName]
		end

		# * *Function*:
		# * *Usage*   : <tt>    </tt>
		# * *Args*    :
		#   - ++  ->
		# * *Returns* :
		#   - ++  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def fillInBacSequence(fakeBac)
			$stderr.print "\t\t  - getting bac sequence..."
			retries = 0
			currChr = lastChr = origChr = fakeBac.chrObj.chrID
			tmpChrSeqRec = nil
			loop {
				if(currChr == origChr) 		# then use currently worked on sequence in mem
					$stderr.print "\n\t\t    -- Picking seq from the region on '#{origChr}'..."
					fakeBac.sequence = @currFullSeqRecord[SEQLINE][(fakeBac.chrStart)...(fakeBac.chrStop)]
					$stderr.puts "done"
				elsif((currChr != lastChr) or (tmpChrSeqRec.nil?))	# then we selected a new one...get into mem
					$stderr.print "\n\t\t    ** Loading sequence of new chr '#{currChr}'..."
					tmpChrSeqRec = nil
					GC.start
					tmpChrSeqRec = getSeqRecordForChrID(currChr)
					$stderr.puts "done"
					$stderr.print "\n\t\t    ** Getting sequence from new location on chr '#{currChr}'..."
					fakeBac.sequence = tmpChrSeqRec[SEQLINE][(fakeBac.chrStart)...(fakeBac.chrStop)]
					$stderr.puts "done"
				elsif(currChr == lastChr)	# then we are using a new area on the same new chr
					$stderr.print "\n\t\t    ** Selecting a new area on chr '#{currChr}'..."
					fakeBac.sequence = tmpChrSeqRec[SEQLINE][(fakeBac.chrStart)...(fakeBac.chrStop)]
					$stderr.print "done"
				else
					$stderr.puts "Shouldn't be able to get HERE! BAC Sequence will be empty...."
				end
				# Do N checking
				numNs = fakeBac.sequence.count("Nn").to_f
				percNs = numNs / fakeBac.size
				if(percNs > @bacsMaxPercNsInSrc) # then too many Ns
					$stderr.puts "\n\t\t    ** TOO MANY Ns! Found more than '#{@bacsMaxPercNsInSrc}'"
					if(retries > 20)
						$stderr.puts "BAC WARNING FOR #{fakeBac.bacID}: Can't find a region of #{fakeBac.chrObj.chrID} with <#{@bacsMaxPercNsInSrc}% Ns (tried 20 random spots). Using the last selected region."
						break
					else
						selRange = nil
						chrID = nil ;	chrObj = nil
						loop {
							# select a "new" chr
							lastChr = currChr # gonna select a new one
							currChr = chrID = selectChr()
							$stderr.puts "\t\t    ** New ChrID Selected: '#{chrID}'"
							chrObj = @chrObjs[chrID]
							# ####### Select A BAC ##########################################
							selRange = selectRegion(@chrLengths[chrID], @fakeBacLength)
							$stderr.puts "\t\t    ** New Region Selected: '#{selRange.first}, #{selRange.last}'"
							unless(@allowBACOverlap)
								unless(isNovelBacRange?(chrID, selRange, @selectedBACs))
									$stderr.puts "\t\t    ** It is NOT novel, and overlap not allowed! Redo!"
									redo
								else
									$stderr.puts "\t\t    ** It is a novel region"
									break
								end
							else # BAC overlap ok
								$stderr.puts "\t\t    ** Bac overlap is ok, so not gonna check the region."
								break
							end
						}
						fakeBac.chrStart = selRange.first
						fakeBac.chrStop = selRange.last
						fakeBac.chrObj = chrObj
						retries += 1
					end
				else # not too many Ns, done
					break
				end
			}
			$stderr.puts "\t\t  - done"
			return fakeBac
		end

		# * *Function*:
		# * *Usage*   : <tt>    </tt>
		# * *Args*    :
		#   - ++  ->
		# * *Returns* :
		#   - ++  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def fillInReadSequence(fakeRead)
			retries = 0
			currChr = lastChr = origChr = (@makeWGSReads ? fakeRead.srcObj.chrID : fakeRead.srcObj.chrObj.chrID)
			tmpChrSeqRec = nil
			noMore = false
			loop {
				chrStart = @makeWGSReads ? 0 : fakeRead.srcObj.chrStart
				chrStop = @makeWGSReads ? 0 : fakeRead.srcObj.chrStop
				if(@doMatePairs)
					revChrStart = @makeWGSReads ? 0 : fakeRead.mateRead.srcObj.chrStart
					revChrStop = @makeWGSReads ? 0 : fakeRead.mateRead.srcObj.chrStop
				end
				chrID = @makeWGSReads ? fakeRead.srcObj.chrID : fakeRead.srcObj.chrObj.chrID
				if(@makeWGSReads)	# then we are allowed to select new chromosomes and such
					if(currChr == origChr)	# then use currently worked on sequence in mem
						$stderr.print "\t\t    -- Picking seq from the region on '#{origChr}'..."
						fakeRead.sequence = @currFullSeqRecord[SEQLINE][ ((chrStart+fakeRead.srcStart)...(chrStart+fakeRead.srcStop)) ]
						fakeRead.sequence = fakeRead.sequence.reverse.tr('AGTCagtc','TCAGtcag') unless(fakeRead.isFwd)
						if(@doMatePairs)
							fakeRead.mateRead.sequence = @currFullSeqRecord[SEQLINE][ ((revChrStart+fakeRead.mateRead.srcStart)...(revChrStart+fakeRead.mateRead.srcStop)) ]
							fakeRead.mateRead.sequence = fakeRead.mateRead.sequence.reverse.tr('AGTCagtc','TCAGtcag') unless(fakeRead.mateRead.isFwd)
						end
						$stderr.puts "done"
					elsif((currChr != lastChr) or (tmpChrSeqRec.nil?))	# then we selected a new one...get into mem
						$stderr.print "\t\t    ** Loading sequence of new chr '#{currChr}'..."
						tmpChrSeqRec = nil
						GC.start
						tmpChrSeqRec = getSeqRecordForChrID(currChr)
						$stderr.puts "done"
						$stderr.print "\t\t    ** Getting sequence from new location on chr '#{currChr}'..."
						fakeRead.sequence = tmpChrSeqRec[SEQLINE][ ((chrStart+fakeRead.srcStart)...(chrStart+fakeRead.srcStop)) ]
						fakeRead.sequence = fakeRead.sequence.reverse.tr('AGTCagtc','TCAGtcag') unless(fakeRead.isFwd)
						if(@doMatePairs)
							fakeRead.mateRead.sequence = tmpChrSeqRec[SEQLINE][ ((revChrStart+fakeRead.mateRead.srcStart)...(revChrStart+fakeRead.mateRead.srcStop)) ]
							fakeRead.mateRead.sequence = fakeRead.mateRead.sequence.reverse.tr('AGTCagtc','TCAGtcag') unless(fakeRead.mateRead.isFwd)
						end
						$stderr.puts "done"
					elsif(currChr == lastChr)	# then we are using a new area on the same new chr
						$stderr.print "\t\t    ** Selecting a new area on chr '#{currChr}'..."
						fakeRead.sequence = tmpChrSeqRec[SEQLINE][ ((chrStart+fakeRead.srcStart)...(chrStart+fakeRead.srcStop)) ]
						fakeRead.sequence = fakeRead.sequence.reverse.tr('AGTCagtc','TCAGtcag') unless(fakeRead.isFwd)
						if(@doMatePairs)
							fakeRead.mateRead.sequence = tmpChrSeqRec[SEQLINE][ ((revChrStart+fakeRead.mateRead.srcStart)...(revChrStart+fakeRead.mateRead.srcStop)) ]
							fakeRead.mateRead.sequence = fakeRead.mateRead.sequence.reverse.tr('AGTCagtc','TCAGtcag') unless(fakeRead.mateRead.isFwd)
						end
						$stderr.print "done"
					else
						$stderr.puts "Shouldn't be able to get HERE! Read Sequence will be empty...."
					end
				else # picking region from BAC
					fakeRead.sequence = fakeRead.srcObj.sequence[ (fakeRead.srcStart...fakeRead.srcStop) ]
					fakeRead.sequence = fakeRead.sequence.reverse.tr('AGTCagtc','TCAGtcag') unless(fakeRead.isFwd)
					if(@doMatePairs)
						fakeRead.mateRead.sequence = fakeRead.srcObj.sequence[ (fakeRead.mateRead.srcStart...fakeRead.mateRead.srcStop) ]
						fakeRead.mateRead.sequence = fakeRead.mateRead.sequence.reverse.tr('AGTCagtc','TCAGtcag') unless(fakeRead.mateRead.isFwd)
					end
				end
				# Do N checking
				numNs = fakeRead.sequence.count("Nn").to_f
				percNs = numNs / fakeRead.size
				if(@doMatePairs)
					revNumNs = fakeRead.mateRead.sequence.count("Nn").to_f
					revPercNs = revNumNs / fakeRead.mateRead.size
				end
				if(percNs > @readsMaxPercNsInSrc or (@doMatePairs ? revPercNs > @readsMaxPercNsInSrc : false ) ) # then too many Ns
					if((!@makeWGSReads and retries > 100) or(@makeWGSReads and retries > 10))
						$stderr.puts "READ WARNING FOR #{fakeRead.readID}: Can't find a region of #{@makeWGSReads ? fakeRead.srcObj.chrID : fakeRead.srcObj.bacID} with <#{@readsMaxPercNsInSrc}% Ns (tried #{(@makeWGSReads ? 10 : 10000)} random spots). Using the last selected region."
						break
					else # re-selection still an option
						selRange = nil
						begin
						if(retries > 100)
								$stderr.puts "READ WARNING FOR #{fakeRead.readID}: Can't find a region of #{@makeWGSReads ? fakeRead.srcObj.chrID : fakeRead.srcObj.bacID} with <#{@readsMaxPercNsInSrc}% Ns (tried #{(@makeWGSReads ? 10 : 10000)} random spots). Using the last selected region."
								noMore = true
								break
							end
							if(@makeWGSReads) # then we still need to select a chr
								lastChr = currChr
								currChr = chrID = selectChr()
								fakeRead.srcObj = chrObj = @chrObjs[chrID]
								fakeRead.mateRead.srcObj = chrObj if(@doMatePairs)
							end
							# select a region of the chr or of the BAC
							selRange = selectRegion(fakeRead.srcObj.size, @fakeReadLength)
							isNovel = true
							if(@makeWGSReads)
								unless(@allowReadOverlap)
									isNovel = isNovelReadRange?(chrID, selRange, @selectedReads)
								end
							else # making bacs
								unless(@allowReadOverlap)
									isNovel = isNovelReadRangeWithinBac?(selRange, @selReadsInBac[fakeRead.srcObj.bacID])
								end
							end
						end until(isNovel)
						# if doing mate pairs, we need to find the mate's range and make some decisions
						if(@doMatePairs)
							# select an insert size
							insertSize = self.selectInsertSize()
							if((selRange.first + insertSize) < (@makeWGSReads ? chrObj.size : fakeRead.srcObj.size))
								# then the other mate can be downstream from the current one and be the reverse
								mateReadRange = Range.new((selRange.first + insertSize) - @fakeReadLength, selRange.first + insertSize)
								mateIsRev = true
							elsif((selRange.first - insertSize) > 0)
								# then the other mate has to be upstream from the current one and be the forward
								mateReadRange = Range.new(selRange.last - insertSize, (selRange.last - insertSize) + @fakeReadLength)
								mateIsRev = false
							else # arg....the src is smaller than the insert size!!!
								$stderr.puts "\nERROR: your src regions (chromosomes for wgs or bacs) are too small! They are smaller than the read insert size!! Can't make mate pairs if that's the case!!!"
								exit(141)
							end
						end
						fakeRead.srcStart = selRange.first
						fakeRead.srcStop = selRange.last
						if(@doMatePairs)
							fakeRead.mateRead.srcStart = mateReadRange.first
							fakeRead.mateRead.srcStop = mateReadRange.last
							if(mateIsRev)
								fakeRead.mateRead.isFwd = false
							else
								fakeRead.mateRead.isFwd = false
							end
						end

						break if(noMore)
					end
					retries += 1
				else
					break
				end
			}
			return fakeRead
		end

		# * *Function*:
		# * *Usage*   : <tt>    </tt>
		# * *Args*    :
		#   - ++  ->
		# * *Returns* :
		#   - ++  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def getSeqRecordForID(cid)
			chrID = "#{@chrIDPrefix}#{cid}#{@chrIDSuffix}"
			@currFullSeqRecord = nil
			GC.start
			@currFullSeqRecord = getSeqRecordForChrID(chrID)
			return
		end

		def getSeqRecordForChrID(chrID)
			srcFileName = @chrSrcs[chrID]
			currFullSeqRecord = nil
			# $stderr.puts "SRC FILE: '#{srcFileName}'"
			reader = BRL::Util::TextReader.new(srcFileName)
			# ASSUMES LINEARIZED chrom FILE (line 1 is defline, line 2 is seq)
			chrRec = []
			chrRec[0] = reader.readline.strip
			chrRec[1] = reader.readline.strip
			reader.close() unless(reader.nil? or reader.closed?)
			GC.start
			return chrRec
		end

		# * *Function*: Randomly picks a "chromosome" from a list, using a uniform pseudorandom number generator.
		# * *Usage*   : <tt>  chrID = fakeTagGen.selectChr()  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - +String+  ->  ID string of the chromosome selected
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def selectChr()
			loop {
				randNum = GLOBAL_RNG.uniform
				@chrWeights.each_index {
					|ii|
					if((randNum < @chrWeights[ii][0]) and @chrSrcs.key?(@chrWeights[ii][1]))
						return @chrWeights[ii][1]
					end
				}
			}
		end

		# * *Function*: Randomly picks a "sub-region" given a full sequence length.
		#   This region will be a fake read or a fake tag, depending on the context.
		#   Uses a uniform pseudorandom number generator to select the start position.
		#   Only novel regions are selected, using the prevSelRegions Array.
		# * *Usage*   : <tt>  chrID = fakeTagGen.selectRegion(totalLength, regionLength)  </tt>
		# * *Args*    :
		#   - +totalLength+  ->  Length of the full sequence.
		#   - +regionLength+ ->  Desired length of the selected region.
		#   - +prevSelRegions+ -> Array of previously selected regions.
		# * *Returns* :
		#   - +Range+  ->  Range instance with start and end defining the region.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def selectRegion(totalLength, regionLength)
			selRange = nil
			if(totalLength <= regionLength)
				return Range.new(0, totalLength, true)
			else
				loop {
					startPos = (GLOBAL_RNG.uniform * (totalLength-1)).round()
					endPos = startPos + regionLength
					redo if(endPos > totalLength) # region goes beyond the end of the src sequence.
					selRange = Range.new(startPos, endPos, true)
					break
				}
				return selRange
			end
		end

		# * *Function*:
		# * *Usage*   : <tt>    </tt>
		# * *Args*    :
		#   - ++  ->
		# * *Returns* :
		#   - ++  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def uniformPoolSelection
			poolIndex = (GLOBAL_RNG.uniform * (@numPoolsPerBAC-1)).round()
			return poolIndex
		end


		# * *Function*: Determines if the range has been selected before in whole or
		#   in part. The prevSelRegions Array is assumed to be unsorted.
		# * *Usage*   : <tt>  novelRange = fakeTagGen.isNovelRange?(someRange, prevSelRegions)  </tt>
		# * *Args*    :
		#   - +selRange+  ->  A Range that is the region in question.
		#   - +prevSelRegions+ ->  An Array of previously selected regions (as Ranges).
		# * *Returns* :
		#   - +true+ | +false+  ->  If the selRange is novel or not.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def isNovelReadRange?(chrID, selRange, prevSelReads)
			return true if(!prevSelReads.key?(chrID) or prevSelReads[chrID].nil? or prevSelReads[chrID].empty?)
			prevSelReads[chrID].each { |fakeRead|
				# begin
					readRange = Range.new(fakeRead.srcStart, fakeRead.srcStop, true)
					return false if(readRange.rangesOverlap?(selRange))
				# rescue => err
				# $stderr.puts "\n\nfakeRead:\n'#{fakeRead.inspect}'\nselRange:\n'#{selRange.inspect}'"
				# $stderr.puts "\n\n'#{err.inspect}'"
				# $stderr.puts err.backtrace.join("\n")
				# exit
				# end
			}
			return true
		end

		def isNovelReadRangeWithinBac?(selRange, selReadsInBac)
			return true if(selReadsInBac.nil? or selReadsInBac.empty?)
			selReadsInBac.each { |fakeRead|
				readRange = Range.new(fakeRead.srcStart, fakeRead.srcStop, true)
				return false if(readRange.rangesOverlap?(selRange))
			}
			return true
		end

		# * *Function*: Determines if the range has been selected before in whole or
		#   in part. The prevSelRegions Array is assumed to be unsorted.
		# * *Usage*   : <tt>  novelRange = fakeTagGen.isNovelRange?(someRange, prevSelRegions)  </tt>
		# * *Args*    :
		#   - +selRange+  ->  A Range that is the region in question.
		#   - +prevSelRegions+ ->  An Array of previously selected regions (as Ranges).
		# * *Returns* :
		#   - +true+ | +false+  ->  If the selRange is novel or not.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def isNovelBacRange?(chrID, selRange, prevSelBacs)
			return true if(!prevSelBacs.key?(chrID) or prevSelBacs[chrID].nil? or prevSelBacs[chrID].empty?)
			prevSelBacs[chrID].each {	|fakeBac|
				bacRange = Range.new(fakeBac.chrStart, fakeBac.chrStop, true)
				return false if(bacRange.rangesOverlap?(selRange))
			}
			return true
		end

		# * *Function*: Picks a number of tags to pull from a fake read. Uses a uniform
		#   random number generator to select some number between the min and max number
		#   of tags for the read.
		# * *Usage*   : <tt>  numTags = fakeTagGen.selectNumTags()  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - +Fixnum+  ->  Number of tags to pull from the read.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def selectNumReads()
			if(@minReadsPerFakeBac == @maxReadsPerFakeBac) then return @minReadsPerFakeBac  end
			cardinality = @maxReadsPerFakeBac - @minReadsPerFakeBac
			selNum = (GLOBAL_RNG.uniform * cardinality).round() + @minReadsPerFakeBac
			return selNum
		end

		# * *Function*: Mutates a read object according to user setting and pseuodo-random
		#   probability.
		# * *Usage*   : <tt>  mutieTag = fakeReadGen.mutateRead(oldTag)  </tt>
		# * *Args*    :
		#   - +oldTag+  ->   Instance of BRL::PGI::FakeRead to mutate.
		# * *Returns* :
		#   - +FakeTag+  ->  New instance of BRL::PGI::FakeRead.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def mutateRegion(mutationProbability, probabilityMutationIsInDel)
			# get list of mutation events
			transMutationEvents = []
			indelMutationEvents = []
			indelCounts = [0,0]
			$stderr.print "\nMEM BEFORE MUTATION: #{BRL::Util::MemoryInfo.getMemUsageStr()}\n"
			$stderr.print "\nMUTATING SEQUENCE THAT IS #{@curr_region.size} LONG\n"
			$stderr.print "ORIGINAL SEQUENCE IS #{@curr_region.sequence.size} LONG\n"
			$stderr.print "#{Time.now()} STATUS: being mutating...\n"
			$stderr.print "MUTATION MASK:\n" if(@doOutputMutationMasks)
			@curr_region.size.times {	|ii|
				mutProb = GLOBAL_RNG.uniform
				unless(mutProb <= mutationProbability)
					$stderr.print "." if(@doOutputMutationMasks)
					next
				end
				# We're gonna mutate here
				mutationEvent = MutationEvent.new(ii)
				inDelProb = GLOBAL_RNG.uniform
				if(inDelProb > probabilityMutationIsInDel) # not an indel
					mutationEvent.mutType = MutationEvent::TRANSFORMATION_MUT
					letterIdx = (GLOBAL_RNG.uniform * (ALPHABET.size-1)).round()
					letter = ALPHABET[letterIdx]
					$stderr.print letter if(@doOutputMutationMasks)
					mutationEvent.mutValue = letter
					transMutationEvents << mutationEvent
				else # is an indel
					$stderr.print "I"  if(@doOutputMutationMasks)
					mutationEvent.mutType = MutationEvent::INDEL_MUT
					indelType = GLOBAL_RNG.uniform.round()
					mutationEvent.mutValue = indelType
					indelCounts[indelType] += 1
					indelMutationEvents << mutationEvent
				end
			}
			$stderr.print "\n" if(@doOutputMutationMasks)
			$stderr.print "#{Time.now()} DONE CREATING MUTATION MASK. NOW NEED TO APPLY IT TO THE SEQUENCE.\n"
			# Apply transformation mutations
			# ARJ TEMP
			GC.start()
			$stderr.print "#{Time.now()} APPLYING TRANSMUTATIONS FIRST..."
			transMutationEvents.each { |mutation|
				# $stderr.print "MUT VALUE: #{mutation.mutValue[0].to_s}    ; " if(@doOutputMutationMasks)
				# $stderr.print "MUT OFFSET: #{mutation.offset}\n" if(@doOutputMutationMasks)
				@curr_region.sequence[mutation.offset] = mutation.mutValue[0]
			}
			$stderr.print "...DONE\n"
			# Apply indel mutations
			$stderr.print "#{Time.now()} APPLYING INDELS SECOND...\n"
			adjust = 0
			indelMutationEvents.sort! { |xx,yy| xx.offset <=> yy.offset }
			$stderr.print "   There are #{indelMutationEvents.size} indels. Inserts: #{indelCounts[0]}. Deletes: #{indelCounts[1]}. \n"
			GC.start()
			idCount = 0
			buffer = @curr_region.sequence.dup
			GC.start()
			segmentStartIndex = 0
			currBufferIndex = 0
			indelMutationEvents.each { |mutation|
				idCount += 1
				# offset = mutation.offset + adjust
				offset = mutation.offset
				# Copy the original segment.
				unless(offset == 0)
					segRange = (segmentStartIndex..(offset-1))
					buffer[currBufferIndex, segRange.size] = @curr_region.sequence[segRange]
					currBufferIndex += segRange.size
				end
				if(mutation.mutValue == MutationEvent::INSERTION_MUT)
					# select the letter to insert
					letterIdx = (GLOBAL_RNG.uniform * (ALPHABET.size-1)).round()
					letter = ALPHABET[letterIdx]
					# Add the inserted base
					buffer[currBufferIndex, letter.size] = letter
					currBufferIndex += letter.size
					# Set the start of the next original segment
					segmentStartIndex = offset
					adjust += 1
				else # is deletion
					# Set the start of the next original segment (such that delete is performed)
					segmentStartIndex = offset + 1
					adjust -= 1
				end
#				if(idCount > 1 and (idCount % 500 == 0))
#					$stderr.puts "\t#{Time.now()} PROCESSED #{idCount} indels ; seq is now #{currBufferIndex} long ; (MEM: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
					GC.start() if(idCount % 500 == 0)
#				end
			}
			# We probably have a trailing original segment to add. If not trim off the end.
			if(segmentStartIndex < (@curr_region.sequence.size - 1))
				segRange = (segmentStartIndex..(@curr_region.sequence.size - 1))
				buffer[currBufferIndex, segRange.size] = @curr_region.sequence[segRange]
			elsif(segmentStartIndex >= @curr_region.sequence.size - 1)
				# remove any of the leftover sequence since dels > ins
				buffer.slice!(currBufferIndex, @curr_region.sequence.size)
			end
			$stderr.puts "\tBUFFER is #{buffer.size}. ORIG is: #{@curr_region.sequence.size}. ins-dels is: #{indelCounts[0] - indelCounts[1]}."
			# Replace the original sequence
			@curr_region.sequence = buffer
			$stderr.print "#{Time.now()} ...DONE APPLYING INDELS\n"
			$stderr.puts "\nMEM AFTER MUTATION: #{BRL::Util::MemoryInfo.getMemUsageStr()}"
			return
		end

		# * *Function*: Processes all the command-line options and dishes them back as a hash
		# * *Usage*   : <tt>    </tt>
		# * *Args*  :
		#   - +none+
		# * *Return* :
		#   - +Hash+  -> Hash of the command-line args with arg names as keys associated with
		#     values. Values can be nil empty string if user gave '' or even nil if user didn't provide
		#     an optional argument.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def FakeTagGenerator.processArguments
			# We want to add all the prop_keys as potential command line options
			optsArray =	[
										['--propFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
										['--randomSeed', '-s', GetoptLong::OPTIONAL_ARGUMENT],
										['--help', '-h', GetoptLong::NO_ARGUMENT]
									]
			PROP_KEYS.each {
				|propName|
				argPropName = "--#{propName}"
				optsArray << [argPropName, GetoptLong::OPTIONAL_ARGUMENT]
			}
			progOpts = GetoptLong.new(*optsArray)
			optsHash = progOpts.to_hash
			FakeTagGenerator.usage() if(optsHash.empty? or optsHash.key?('--help'));
			return optsHash
		end

	  # * *Function*: Displays some basic usage info on STDOUT
	  # * *Usage*   : <tt>    </tt>
	  # * *Args*  :
	  #   - +String+ Optional message string to output before the usage info.
	  # * *Return* :
	  #   - +none+
	  # * *Throws*  :
	  #   - +none+
		# --------------------------------------------------------------------------
		def FakeTagGenerator.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "

  PROGRAM DESCRIPTION:

    COMMAND LINE ARGUMENTS:
      -p    => Properties file to use for  parameters, etc.
      -h    => [optional flag] Output this usage info and exit

    USAGE:
	";
			exit(2);
		end # def LFFMerger.usage(msg='')
	end

end ; end


# ##############################################################################
# MAIN
# ##############################################################################
begin
	optsHash = BRL::PGI::FakeTagGenerator.processArguments()
	generator = BRL::PGI::FakeTagGenerator.new(optsHash)
	# Make the reads, etc
	generator.makeFakeReads()
	# Dump info and sequence(s) to file
	generator.dumpFakeRegions()
rescue => err
	$stderr.puts "\n\nERROR: caught exception with this message\n\t'#{err.message}'"
	$stderr.puts "\nThis was the backtrace:\n\n" + err.backtrace.join("\n") + "\n\n"
end

exit(0)

