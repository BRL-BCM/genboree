#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'gsl'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/util/logger'
require 'brl/genboree/genboreeUtil'
include BRL::Genboree
include GSL

$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

module BRL ; module Genboree

module LFFStats
	CLASS, NAME, TYPE, SUBTYPE, REF, START, STOP, STRAND, PHASE, SCORE, QSTART, QSTOP =
		0,1,2,3,4,5,6,7,8,9,10,11
	CHR_SORT_RE =  /^.*chr(.+)$/i
	LENGTHS, SCORES, SCORE_DENSITIES, CHR_LENGTH_SUMS = 0,1,2,3
	
	ts = te = 0 # Time start, Time end ; for timing things in this module
	
	# ############################################################################
	# CLASS: Stats
	# - Superclass for all specific stats classes. Common code & properties.
	# ############################################################################
	class Stats
		NUM_HISTO_BINS = 25
		attr_accessor :verbose
		attr_accessor :count, :sumLengths, :sumRefSeqLengths, :countPerEntryPoint
		attr_accessor :refSeqs, :sumRefSeqLengths
		attr_accessor :avgLength, :sdLength, :medianLength, :minLength, :maxLength, :n50Length
		attr_accessor :avgScore, :sdScore, :medianScore, :minScore, :maxScore
		attr_accessor :avgScoreDensity, :sdScoreDensity, :medianScoreDensity, :minScoreDensity, :maxScoreDensity
		attr_accessor :chrCoverages, :refSeqCover
		attr_accessor :lengthHistogram, :scoreHistogram
		
		attr_accessor :lengths, :squareLengths, :scores, :scoreDensities, :n50Scores
		attr_accessor :lengthSumsPerChr
		attr_accessor :maxNameLength
		
		# --------------------------------------------------------------------------
		def initialize(refSeqs)
			@verbose = true
			@count = @sumLengths = @sumRefSeqLengths = 0
			@countPerEntryPoint = Hash.new(0) # Default value for unknown keys is 0
			@avgLength = @sdLength = @medianLength = @minLength = @maxLength = @n50Length = 0
			@avgScore = @sdScore = @medianScore = @minScore = @maxScore = @avgN50Score = 0
			@avgScoreDensity = @sdScoreDensity = @medianScoreDensity = @minScoreDensity = @maxScoreDensity = 0
			@chrCoverages = Hash.new(0) # Default value for unknown keys is 0
			@refSeqCover = 0.0
			@lengthHistogram = @scoreHistogram = nil 
			@refSeqs = refSeqs
			computeRefSeqStats()
		end # def initialize(refSeqs)
				
		# --------------------------------------------------------------------------
		def computeRefSeqStats()
			@refSeqs.values.each { |xx| @sumRefSeqLengths += xx }
			return
		end # def computeRefSeqStats()
				
		# --------------------------------------------------------------------------
		def calcLengthStats(lengths)
			@count = lengths.size
			@sumLengths = Stats::sum(lengths)
			$stderr.puts "#{ts = Time.now} => START: calculate length mean/sd..." if(@verbose)
			gslVector = Vector.alloc(lengths)
			@avgLength = gslVector.mean(lengths)
			@sdLength = gslVector.sd()
			$stderr.puts "#{te = Time.now} => DONE: ...calculated length mean/sd. (#{sprintf('%.2f',te-ts)} secs)" if(@verbose)
			$stderr.puts "#{ts = Time.now} => START: calculate length median..." if(@verbose)
			gslVector.sort!
			@medianLength = gslVector.median(lengths)
			$stderr.puts "#{te = Time.now} => DONE: ...median length calculated. (#{sprintf('%.2f',te-ts)} secs)" if(@verbose)
			@minLength = gslVector.min()
			@maxLength = gslVector.max()
			@n50Length = Stats::n50(lengths)
			return
		end # def calcLengthStats(lengths)
				
		# --------------------------------------------------------------------------
		def calcScoreStats(scores)
			$stderr.puts "#{ts = Time.now} => START: calculate score mean/sd..." if(@verbose)
			gslVector = Vector.alloc(scores)
			@avgScore = gslVector.mean(scores)
			@sdScore = gslVector.sd()
			$stderr.puts "#{te = Time.now} => DONE: ...calculated score mean/sd. (#{sprintf('%.2f',te-ts)} secs)" if(@verbose)
			$stderr.puts "#{ts = Time.now} => START: calculate score median..."	if(@verbose)
			gslVector.sort!
			@medianScore = gslVector.median(scores)
			$stderr.puts "#{te = Time.now} => DONE: ...median score calculated. (#{sprintf('%.2f',te-ts)} secs)" if(@verbose)
			@minScore = gslVector.min()
			@maxScore = gslVector.max()
			return
		end # def calcScoreStats(scores)
				
		# --------------------------------------------------------------------------
		def calcScoreDensityStats(scoreDensities)
			$stderr.puts "#{ts = Time.now} => START: calculate score densities mean/sd..." if(@verbose)
			gslVector = Vector.alloc(scoreDensities)
			@avgScoreDensity = gslVector.mean(scoreDensities)
			@sdScoreDensity = gslVector.sd()
			$stderr.puts "#{te = Time.now} => DONE: ...calculated score densities mean/sd. (#{sprintf('%.2f',te-ts)} secs)" if(@verbose)
			$stderr.puts "#{ts = Time.now} => START: calculate score densities median..."	if(@verbose)
			gslVector.sort!
			@medianScoreDensity = gslVector.median(scoreDensities)
			$stderr.puts "#{te = Time.now} => DONE: ...median score densities calculated. (#{sprintf('%.2f',te-ts)} secs)" if(@verbose)
			@minScoreDensity = gslVector.min()
			@maxScoreDensity = gslVector.max()
			return
		end # def calcScoreDensityStats(scoreDensities)
				
		# --------------------------------------------------------------------------
		def calcCoverages(chrLengthSums)
			@refSeqCover = @sumLengths.to_f / @sumRefSeqLengths.to_f
			chrLengthSums.each { |ep, lengthSum|
				if(@refSeqs.key?(ep))
					@chrCoverages[ep] = lengthSum.to_f / @refSeqs[ep].to_f
				else
					@chrCoverages[ep] = nil
				end
			}
			return
		end # def calcCoverages(chrLengthSums)
				
		# --------------------------------------------------------------------------
		def computeHistograms(lengths, scores)
			unless(lengths.nil?)
				$stderr.puts "#{ts = Time.now} => START: create length histogram..." if(@verbose)
				@lengthHistogram = GSL::Histogram.alloc(NUM_HISTO_BINS)
				@lengthHistogram.set_ranges_uniform(0, @maxLength.to_f+0.0000001)
				lengths.each { |len| @lengthHistogram.increment(len) }
				$stderr.puts "#{te = Time.now} => DONE: ...created length histogram. (#{sprintf('%.2f',te-ts)} secs)" if(@verbose)
			end
			
			unless(scores.nil?)
				$stderr.puts "#{ts = Time.now} => START: create score histogram..." if(@verbose)
				@scoreHistogram = GSL::Histogram.alloc(NUM_HISTO_BINS)
				@scoreHistogram.set_ranges_uniform((@minScore == @maxScore ? 0 : @minScore), @maxScore.to_f+0.0000001)
				$stderr.puts "#{te = Time.now} => DONE: ...create score histogram. (#{sprintf('%.2f',te-ts)} secs)" if(@verbose)
				scores.each { |scr| @scoreHistogram.increment(scr) }
			end
			return
		end # def computeHistograms()
				
		# --------------------------------------------------------------------------
		def Stats::sum(dataArray)
			dataSum = 0
			dataArray.each { |item| dataSum += item }
			return dataSum
		end # def Stats::sum(dataArray)
		
		# --------------------------------------------------------------------------
		def Stats::n50(dataArray)
  		sortedArray = dataArray.sort { |aa,bb| bb <=> aa }
			runningSum = 0
  		dataSum = Stats::sum(sortedArray)
  	  sortedArray.each { |item|
				runningSum += item
    		return item if(runningSum >= dataSum/2)
    	}
    	return nil
  	end # def Stats::n50(dataArray)
		
	end # class Stats
	
	# ############################################################################-
	# CLASS: AnnoStats
	# - stats for individual annotations
	# ############################################################################
	class AnnoStats < Stats
		def initialize(refSeqs)
			super(refSeqs)
		end # def initialize(refSeqs)
	
		# --------------------------------------------------------------------------
		def extractData(lffRecords)
			$stderr.puts "#{ts = Time.now} => START: collect length and score info for annotations ..." if(@verbose)
			lengths = []
			scores = []
			scoreDensities = []
			chrAnnoLengthSums = Hash.new(0) # Default value for unknown keys is 0
			lffRecords.each { |ep, lffByTrack|
				lffByTrack.each { |trackName, recs|
					recs.each { |lffRecord|
						len = ((lffRecord[STOP]-lffRecord[START]).abs + 1)
						lengths << len
						scores << lffRecord[SCORE]
						scoreDensities << lffRecord[SCORE] / len.to_f
						@countPerEntryPoint[lffRecord[REF]] += 1
						chrAnnoLengthSums[lffRecord[REF]] += len
					}
				}
			}
			$stderr.puts "#{te = Time.now} => DONE: ...collected length and score info about #{lengths.size} annotations. (#{sprintf('%.2f',te-ts)} secs)" if(@verbose)
			return [ lengths, scores, scoreDensities, chrAnnoLengthSums ]
		end # def extractData(lffRecords)
			
		# --------------------------------------------------------------------------
		def computeStats(lffRecords)
			$stderr.puts "\n#{'-'*60}\n#{Time.now} => STATUS: Processing ANNOTATION Stats." if(@verbose)
			# Get the relevant data
			lengths, scores, scoreDensities, chrAnnoLengthSums = self.extractData(lffRecords)
			# Stats for annotation lengths
			self.calcLengthStats(lengths)
			# Stats for annotation scores
			self.calcScoreStats(scores)
			# Stats for annotation score densities
			self.calcScoreDensityStats(scoreDensities)
			# Stats for coverage
			self.calcCoverages(chrAnnoLengthSums)
			# Histograms, using info calculated above to set params
			self.computeHistograms(lengths, scores)
			# Force clean-up
			lengths, scores, scoreDensities, chrAnnoLengthSums = nil ; GC.start()
			return
		end # def computeStats(lffRecords)
	end # class AnnoStats
	
	# ############################################################################
	# CLASS: GroupStats
	# - stats for annotations groups
	# ############################################################################
	class GroupStats < Stats
		NUM_ANNOS_PER_GROUP, GROUP_ANNO_DENSITIES = 1,2
		
		attr_accessor :avgAnnosPerGroup, :sdAnnosPerGroup, :medianAnnosPerGroup, :minAnnosPerGroup, :maxAnnosPerGroup
		attr_accessor :avgAnnosPerGroupBP, :sdAnnosPerGroupBP, :medianAnnosPerGroupBP, :minAnnosPerGroupBP, :maxAnnosPerGroupBP
		attr_accessor :medianAnnoLength
			
		# --------------------------------------------------------------------------
		def initialize(refSeqs)
			super(refSeqs)
			@avgAnnosPerGroup = @sdAnnosPerGroup = @medianAnnosPerGroup = @minAnnosPerGroup = @maxAnnosPerGroup = 0
		end
			
		# --------------------------------------------------------------------------
		def extractData(lffRecords, medianAnnoLength)
			$stderr.puts "#{ts = Time.now} => START: collect length and score info for groups ..." if(@verbose)
			# First find group start/stops
			groups = Hash.new(){ |hh,key| hh[key]={} }	# Default value for unknown keys is a 2nd Hash.
			lffRecords.each { |ep, lffByTrack|
				lffByTrack.each { |trackName, recs|
					recs.each { |rec|
						groupName = rec[NAME]						
						lffstart = (rec[START] <= rec[STOP]) ? rec[START] : rec[STOP]
						lffstop = (rec[STOP] >= rec[START]) ? rec[STOP] : rec[START]
						
						if(groups.key?(ep) and groups[ep].key?(groupName))
							groups[ep][groupName].first = lffstart if(lffstart < groups[ep][groupName].first)
							groups[ep][groupName].last = lffstop if(lffstop > groups[ep][groupName].last)
							groups[ep][groupName].count += 1
						else # group not seen yet
							window = BRL::Genboree::FullClosedWindow.new(lffstart, lffstop, 1)
							groups[ep][groupName] = window
						end
					}
				}
			}
			# compute regular stats for the covering regions
			lengths = []
			numAnnosPerGroup = []
			groupAnnoDensities = []
			chrGroupLengthSums = Hash.new(0) # Default value for unknown keys is 0
			groups.each { |ep, groupsByName|
				groupsByName.each { |groupName, group|
					groupLength = (group.last - group.first).abs + 1
					lengths << groupLength
					numAnnosPerGroup << group.count
					# Only use the estimate medianAnnoLength if it's smaller than the current group length
					annoEst = (medianAnnoLength < groupLength) ? medianAnnoLength : groupLength
					groupAnnoDensities << (group.count / groupLength.to_f) * annoEst
					@countPerEntryPoint[ep] += 1
					chrGroupLengthSums[ep] += groupLength
				}
			}
			$stderr.puts "#{te = Time.now} => DONE: ...collected length and score info about #{lengths.size} groups. (#{sprintf('%.2f',te-ts)} secs)" if(@verbose)
			return [ lengths, numAnnosPerGroup, groupAnnoDensities, chrGroupLengthSums ]
		end # def extractData(lffRecords)
			
		# --------------------------------------------------------------------------
		def calcAnnosPerGroupStats(numAnnosPerRegion)
			# Use generic score stats to do this, then copy to group-specific variables since score properties are unused
			self.calcScoreStats(numAnnosPerRegion)
			@avgAnnosPerGroup, @sdAnnosPerGroup, @medianAnnosPerGroup, @minAnnosPerGroup, @maxAnnosPerGroup =
				@avgScore, @sdScore, @medianScore, @minScore, @maxScore
			return
		end
			
		# --------------------------------------------------------------------------
		def calcAnnosPerGroupBPStats(groupAnnoDensities)
			# Use generic score density stats to do this, then copy to region-specific variables since score properties are unused
			self.calcScoreDensityStats(groupAnnoDensities)
			@avgAnnosPerRegionBP, @sdAnnosPerRegionBP, @medianAnnosPerRegionBP, @minAnnosPerRegionBP, @maxAnnosPerRegionBP =
				@avgScoreDensity, @sdScoreDensity, @medianScoreDensity, @minScoreDensity, @maxScoreDensity
			return
		end
			
		# --------------------------------------------------------------------------
		def computeStats(lffRecords, medianAnnoLength)
			$stderr.puts "\n#{'-'*60}\n#{Time.now} => STATUS: Processing GROUP Stats." if(@verbose)
			# Get the relevant data
			lengths, numAnnosPerGroup, groupAnnoDensities, chrGroupLengthSums = self.extractData(lffRecords, medianAnnoLength)
			# Stats for region lengths
			self.calcLengthStats(lengths)
			# Stats for annos/region stats
			self.calcAnnosPerGroupStats(numAnnosPerGroup)
			# Stats for anno densities per group BP stats
			self.calcAnnosPerGroupBPStats(groupAnnoDensities)
			# Stats for region coverage
			self.calcCoverages(chrGroupLengthSums)
			# Histograms, using info calculated above to set params
			self.computeHistograms(lengths, nil)
			# Force clean-up
			lengths, numAnnosPerGroup, groupAnnoDensities, chrGroupLengthSums = nil ; GC.start()
			
		end # def computeStats()
	end # class GroupStats
	
	# ############################################################################
	# CLASS: RegionStats
	# - stats for unique regions covered by annotations (annotation projection regions)
	# - calculates GapStats also
	# ############################################################################
	class RegionStats < Stats
		NUM_ANNOS_PER_REGION, REGION_ANNO_DENSITIES, GAP_REGIONS = 1,2,4

		attr_accessor :avgAnnosPerRegion, :sdAnnosPerRegion, :medianAnnosPerRegion, :minAnnosPerRegion, :maxAnnosPerRegion
		attr_accessor :avgAnnosPerRegionBP, :sdAnnosPerRegionBP, :medianAnnosPerRegionBP, :minAnnosPerRegionBP, :maxAnnosPerRegionBP
		attr_accessor :numMergings
		attr_accessor :gapStats
			
		# --------------------------------------------------------------------------
		def initialize(refSeqs)
			super(refSeqs)
			@avgAnnosPerRegion = @sdAnnosPerRegion = @medianAnnosPerRegion = @minAnnosPerRegion = @maxAnnosPerRegion = 0
			@avgAnnosPerRegionBP = @sdAnnosPerRegionBP = @medianAnnosPerRegionBP = @minAnnosPerRegionBP = @maxAnnosPerRegionBP = 0
			@gapStats = GapStats.new(refSeqs)	; @gapStats.verbose = true
		end
			
		# --------------------------------------------------------------------------
		def extractData(lffRecords, medianAnnoLength)
			$stderr.puts "#{ts = Time.now} => START: collect length and score info for regions (and gaps) ..." if(@verbose)
			# First Project all annotations onto refSeq
			mergedRegions = Hash.new(){ [] }	# Default value for unknown keys is an array. {}->[]
			gapRegions = Hash.new(){ [] }			# Default value for unknown keys is an array. {}->[]
			prevRegion = nil
			@numMergings = 0 # Default value for unknown keys is 0
			lffRecords.each { |ep, lffByTrack|
				prevRegion = nil # new track for this entrypoint
				lffByTrack.each { |trackName, recs|
					prevRegion = nil # new track for this track
					recs.each { |lffRecord|
						lffstart = (lffRecord[START] <= lffRecord[STOP]) ? lffRecord[START] : lffRecord[STOP]
						lffstop = (lffRecord[STOP] >= lffRecord[START]) ? lffRecord[STOP] : lffRecord[START]
						currRegion = BRL::Genboree::FullClosedWindow.new(lffstart, lffstop)
						if(prevRegion.nil?) # then new entrypoint, new track, or such
							prevRegion = currRegion
							# Does this track start with a gap on this entrypoint?
							gapRegions[ep] <<= BRL::Genboree::FullClosedWindow.new(1, lffstart) if(lffstart > 1)
						elsif((currRegion.last >= prevRegion.first) and (prevRegion.last >= currRegion.first)) # then curr overlaps prev ; merge them
							prevRegion.last = (currRegion.last > prevRegion.last) ? currRegion.last : prevRegion.last
							prevRegion.count += 1
							@numMergings += 1
						else # don't overlap and we have a previous region
							mergedRegions[ep] <<= prevRegion
							# Is the gap significant?
							if((currRegion.first - prevRegion.last) > 1)
								gapRegions[ep] <<= BRL::Genboree::FullClosedWindow.new(prevRegion.last+1, currRegion.first-1)
							end
							prevRegion = currRegion
						end
					}
				}
				# don't miss the last region we were working on
				mergedRegions[ep] <<= prevRegion unless(prevRegion.nil?)
				# Does this track end with a gap on this entrypoint?
				if(@refSeqs.key?(ep) and (prevRegion.last < @refSeqs[ep]))
					gapRegions[ep] <<= BRL::Genboree::FullClosedWindow.new(prevRegion.last+1, @refSeqs[ep])
				end
			}
			
			# compute regular stats for the covering regions
			lengths = []
			numAnnosPerRegion = []
			regionAnnoDensities = []
			chrRegionLengthSums = Hash.new(0) # Default value for unknown keys is 0
			mergedRegions.each { |ep, regions|
				regions.each { |region|
					len = (region.last - region.first).abs + 1
					lengths << len
					numAnnosPerRegion << region.count
					# Only use the estimate medianAnnoLength if it's smaller than the current region length
					annoEst = (medianAnnoLength < len) ? medianAnnoLength : len
					regionAnnoDensities << (region.count / len.to_f) * annoEst
					@countPerEntryPoint[ep] += 1
					chrRegionLengthSums[ep] += len
				}
			}
			$stderr.puts "#{te = Time.now} => DONE: ...collected length and score info about #{lengths.size} regions. (#{sprintf('%.2f',te-ts)} secs)" if(@verbose)
			return [ lengths, numAnnosPerRegion, regionAnnoDensities, chrRegionLengthSums, gapRegions ]
		end # def extractData(lffRecords)
			
		# --------------------------------------------------------------------------
		def calcAnnosPerRegionStats(numAnnosPerRegion)
			# Use generic score stats to do this, then copy to region-specific variables since score properties are unused
			self.calcScoreStats(numAnnosPerRegion)
			@avgAnnosPerRegion, @sdAnnosPerRegion, @medianAnnosPerRegion, @minAnnosPerRegion, @maxAnnosPerRegion =
				@avgScore, @sdScore, @medianScore, @minScore, @maxScore
			return
		end
			
		# --------------------------------------------------------------------------
		def calcAnnosPerRegionBPStats(regionAnnoDensities)
			# Use generic score density stats to do this, then copy to region-specific variables since score properties are unused
			self.calcScoreDensityStats(regionAnnoDensities)
			@avgAnnosPerRegionBP, @sdAnnosPerRegionBP, @medianAnnosPerRegionBP, @minAnnosPerRegionBP, @maxAnnosPerRegionBP =
				@avgScoreDensity, @sdScoreDensity, @medianScoreDensity, @minScoreDensity, @maxScoreDensity
			return
		end
			
		# --------------------------------------------------------------------------
		def computeStats(lffRecords, medianAnnoLength)
			$stderr.puts "\n#{'-'*60}\n#{Time.now} => STATUS: Processing REGION Stats." if(@verbose)
			# Get the relevant data
			lengths, numAnnosPerRegion, regionAnnoDensities, chrRegionLengthSums, gapRegions = self.extractData(lffRecords, medianAnnoLength)
			# Stats for region lengths
			self.calcLengthStats(lengths)
			# Stats for annos/region stats
			self.calcAnnosPerRegionStats(numAnnosPerRegion)
			# Stats for anno densities per region BP stats
			self.calcAnnosPerRegionBPStats(regionAnnoDensities)
			# Stats for region coverage
			self.calcCoverages(chrRegionLengthSums)
			# Histograms, using info calculated above to set params
			self.computeHistograms(lengths, nil)
			# Force clean-up
			lengths, numAnnosPerRegion, regionAnnoDensities, chrRegionLengthSums = nil ; GC.start()
			
			# Do gap info too, while we have the info at hand:
			
			$stderr.puts "\n#{'-'*60}\n#{Time.now} => STATUS: Processing GAP Stats." if(@verbose)
			# Get the relevant data
			lengths, tmp, tmp, chrGapLengthSums = @gapStats.extractData(gapRegions)
			# Stats for gap lengths
			@gapStats.calcLengthStats(lengths)
			# Stats for gap coverage
			@gapStats.calcCoverages(chrGapLengthSums)
			# Histograms, using info calculated above to set params
			@gapStats.computeHistograms(lengths, nil)
			# Force clean-up
			lengths, tmp, tmp, chrGapLengthSums, gapRegions = nil ; GC.start()
			return
		end # def computeStats()		
	end # class RegionStats
	
	# ############################################################################
	# CLASS: GapStats
	# - stats for regions uncovered by annotation projections
	# - calculated mainly during RegionStats' computeStats()
	# ############################################################################
	class GapStats < Stats	
		# --------------------------------------------------------------------------
		def initialize(refSeqs)
			super(refSeqs)
		end
	
		# --------------------------------------------------------------------------
		def extractData(gapRegions)
			lengths = []
			@countPerEntryPoint = Hash.new(0) # Default value for unknown keys is 0
			chrGapLengthSums = Hash.new(0) # Default value for unknow keys is 0
			gapRegions.each { |ep, gaps|
				gaps.each { |gap|
					gapLength = (gap.last - gap.first).abs + 1
					lengths << gapLength
					@countPerEntryPoint[ep] += 1
					chrGapLengthSums[ep] += gapLength
				}
			}
			return [ lengths, nil, nil, chrGapLengthSums ]
		end
	end # class GapStats

	# ############################################################################
	# CLASS: LFFStats
	# - generic operations class ; holds stats objects ; loads data ; etc
	# ############################################################################
	class LFFStats
		attr_accessor :refSeqFile, :lffFileName, :trackName, :trackType, :trackSubtype
		attr_accessor :lffRecords, :annoStats, :gapStats, :groupStats, :regionStats, :refSeqs
			
		# --------------------------------------------------------------------------
		def initialize(lffFileName, refSeqFile, trackName)
			@lffFileName, @refSeqFile, @trackName = lffFileName, refSeqFile, trackName
			@trackName =~ TRACKNAME_RE
			@trackType, @trackSubtype = $1, $2
			@refSeqs = {}
			@lffRecords = {}
			@annoStats, @gapStats, @groupStats, @regionStats = nil
			@initialized = false
			@verbose = true
		end
		
		# --------------------------------------------------------------------------
		def isInitialized?()
			return ((@refSeqs.empty? or @lffRecords.empty? or !@initialized) ? false : true)
		end
			
		# --------------------------------------------------------------------------
		def loadRefSeqs()
			@refSeqs = loadValidRefSeqs(@refSeqFile) # from genboreeUtils
		end
			
		# --------------------------------------------------------------------------
		def loadData()
			$stderr.puts "#{ts = Time.now} START: load reference sequence records...." if(@verbose)
			loadRefSeqs()
			$stderr.puts "#{te = Time.now} END: ...loading '#{@refSeqs.size}' reference sequence records. (#{sprintf('%.2f',te-ts)} secs)" if(@verbose)
			loadLFFRecords()
		end
	
		# --------------------------------------------------------------------------
		def loadLFFRecords()
			$stderr.puts "#{ts = Time.now} START: load and validate annotation records...." if(@verbose)
			@lffRecords = readLFFRecords(@lffFileName, nil, false, @trackName)
			$stderr.puts "#{te = Time.now} END: ...loading and validating annotation data. (#{sprintf('%.2f',te-ts)} secs)" if(@verbose)
			$stderr.puts "#{ts = Time.now} START: sort records..." if(@verbose)
			sortLFFRecords(@lffRecords) # from genboreeUtils
			$stderr.puts "#{te = Time.now} END: ...sort records. (#{sprintf('%.2f',te-ts)} secs)" if(@verbose)
		end
	
		# --------------------------------------------------------------------------
		def init()
			@annoStats = AnnoStats.new(@refSeqs)			; @annoStats.verbose = true
			@gapStats = nil # This is acquired from the regionStats			
			@groupStats = GroupStats.new(@refSeqs)		; @groupStats.verbose = true
			@regionStats = RegionStats.new(@refSeqs)	; @regionStats.verbose = true
			return @initialized = true
		end
			
		# --------------------------------------------------------------------------
		def computeStats()
			return false unless(self.isInitialized?)
			@annoStats.computeStats(@lffRecords)
			@groupStats.computeStats(@lffRecords, @annoStats.medianLength)
			@regionStats.computeStats(@lffRecords, @annoStats.medianLength) # also does gapStats.computeStats(@lffRecords)
			return true
		end # def computeStats()
	end # class LFFStats
end # module LFFStats

end ; end # module BRL ; module Genboree
