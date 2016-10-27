#!/usr/bin/env ruby

=begin
	Converts PASH text output to 2 LFF files
  Author: Andrew R Jackson <andrewj@bcm.tmc.edu>
        Alan Harris <rharris1@bcm.tmc.edu>
  Date  : March 13, 2003
=end
# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/similarity/blastHit'

# Turn on extra warnings and such
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

#=== *Purpose* :
#  Namespace for BRL's directly-related Genboree Ruby code.
module BRL ; module Similarity
	class BlastMapper

# Required properties
		PROP_KEYS = 	%w{
											input.dir.blastResults
											input.filePattern.blastFiles
											output.file.mapResultsBase
											output.dir.outputDir
											output.alignScore
											output.doMapWholeReads
											param.doCalcAlignScores
											param.alignScore.matchReward
											param.alignScore.mismatchPenalty
											param.alignScore.gapOpenPenalty
											param.alignScore.gapExtensionPenalty
											param.hitFilter.minAlignScore
											param.hitFilter.minNumIdentities
											param.hitFilter.minPercentOfQueryMatching
											param.hitFilter.minQueryLength
											param.hitFilter.maxPercentQueryGaps
											param.mapFilter.useAlignScore
											param.mapFilter.keepPercent
											param.mapFilter.maxHitsPerQuery
											param.mapFilter.keepKhits
											param.doExcessiveCoverageFilter
											param.excessiveCoverage
											param.coverageRadius
											param.doFilterTargetsByNumProjs
											param.projRegExp
											param.maxNumProjsInRegion
											param.targetRegionRadius

										};

		# * *Function*:
		# * *Usage*   : <tt>    </tt>
		# * *Args*    :
		#   - ++  ->
		# * *Returns* :
		#   - ++  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def initialize(optsHash)
			@propTable = BRL::Util::PropTable.new(File.open(optsHash['--propFile']))
			# If options supplied on command line instead, use them rather than those in propfile
			PROP_KEYS.each {
				|propName|
				argPropName = "--#{propName}"
				unless(optsHash[argPropName].nil?)
					@propTable[propName] = optsHash[argPropName]
				end
			}
			setParameters()
			@queryHitsHash = {}
			@queriesWithTooManyHits = {}
			@queryLenFilteredCount = 0
			@numMatchesFilteredCount = 0
			@queryPercentFilteredCount = 0
			@keepTopHitsFilteredCount = 0
			@maxQueryHitsFilteredCount = 0
			@keepKHitsFilteredCount = 0
			@maxQueryHitsQueriesRemoved = 0
			@coverageFilteredHits = 0
			@totalHitsFiltered = 0
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
		def setParameters()
			@blastResultsDir = @propTable['input.dir.blastResults']
			@outputDir = @propTable['output.dir.outputDir']
			@blastFilePattern = @propTable['input.filePattern.blastFiles']
			@outputFileBase = @propTable['output.file.mapResultsBase']
			@doOutputAlignScore = @propTable['output.alignScore'].to_i == 1 ? true : false
			@minAlignScore = @propTable['param.hitFilter.minAlignScore'].to_i
			@maxPercentQueryGaps = @propTable['param.hitFilter.maxPercentQueryGaps'].to_f
			@minNumIdentities = @propTable['param.hitFilter.minNumIdentities'].to_i
			@minQueryPercent = @propTable['param.hitFilter.minPercentOfQueryMatching'].to_f
			@minQueryLength = @propTable['param.hitFilter.minQueryLength'].to_i
			@keepPercent = 100.0 - @propTable['param.mapFilter.keepPercent'].to_f
			
			@keepKhits = @propTable['param.mapFilter.keepKhits'].to_i
			@maxHitsPerQuery = @propTable['param.mapFilter.maxHitsPerQuery'].to_i
			@doMapWholeRead  = @propTable['output.doMapWholeRead'].to_i == 1 ? true : false
			@doExcessiveCoverageFilter = @propTable['param.doExcessiveCoverageFilter'].to_i == 1 ? true : false
			@excessiveCoverage = @propTable['param.excessiveCoverage'].to_i
			@coverageRadius = @propTable['param.coverageRadius'].to_i
			@doFilterTargetByNumProjs = @propTable['param.doFilterTargetsByNumProjs'].to_i == 1 ? true : false
			@projRegExp = Regexp.new(@propTable['param.projRegExp']) unless(@propTable['param.projRegExp'].nil?)
			@maxNumProjsInRegion = @propTable['param.maxNumProjsInRegion'].to_i
			@targetRegionRadius = @propTable['param.targetRegionRadius'].to_i
			@useAlignScoreForMapping = @propTable['param.mapFilter.useAlignScore'].to_i == 1 ? true : false
			
			@doCalcAlignScore = @propTable['param.doCalcAlignScores'].to_i == 1 ? true : false
			@alignMatchReward = @propTable['param.alignScore.matchReward'].to_i
			@alignMismatchPenalty = @propTable['param.alignScore.mismatchPenalty'].to_i
			@alignGapOpenPenalty = @propTable['param.alignScore.gapOpenPenalty'].to_i
			@alignGapExtendPenalty = @propTable['param.alignScore.gapExtensionPenalty'].to_i
			
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
		def applyHitFilters()
			# keep only top P% of hits
			numHitsKept = 0
			@queryHitsHash.each {
				|queryID, hitsArray|
				newArray = []
				hitsArray.each {
					|hit|
					if(checkHit(hit))
						newArray.push(hit)
						numHitsKept += 1
					end
				}
				hitsArray.clear
				@queryHitsHash[queryID] = newArray
			}
		 	$stderr.puts "STATUS: #{@totalHitsFiltered} total hits were removed by hit-filters"
			$stderr.puts "\t#{@queryLenFilteredCount} hits had query length < '#{@minQueryLength}'"
			$stderr.puts "\t#{@numMatchesFilteredCount} hits had number of identities < '#{@minNumIdentities}'"
			$stderr.puts "\t#{@queryPercentFilteredCount} hits had query percent identity < '#{@minQueryPercent}'"
			$stderr.puts "\t---------------------------------"
			return
		end

		def blastHitAlignScore(blastHit, matchReward=2, mismatchPenalty=1, gapOpenPenalty=2, gapExtension=1)
			score = 0
			score += (matchReward*(blastHit.percentIdentity * blastHit.length))
			score -= (mismatchPenalty*blastHit.numMismatches)
			score -= (gapOpenPenalty*blastHit.numGaps)
			if(blastHit.numGaps > 0)
				gaps = blastHit.querySpan - blastHit.targetSpan
				score -= (gapExtension*(gaps.abs-blastHit.numGaps))
			end
			return score
		end
		
		def alignScore(blastHit)
			return blastHitAlignScore(blastHit, @alignMatchReward, @alignMismatchPenalty, @alignGapOpenPenalty, @alignGapOpenPenalty)		
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
		def checkHit(blastHit)
			# Check min query length
			unless((queryLenOK = blastHit.querySpan >= @minQueryLength ? true : false))
				@queryLenFilteredCount += 1
			end
			# Check num matches
			unless((matchesOK = (blastHit.percentIdentity * blastHit.length) >= @minNumIdentities ? true : false))
				@numMatchesFilteredCount += 1
			end
			# Check query percent identity
			unless((queryPercentOK = blastHit.percentIdentity >= @minQueryPercent ? true : false))
				@queryPercentFilteredCount += 1
			end

			# Do we have too many gap bases on the query or not?
			qGapBasesOK = (blastHit.percentGaps() <= @maxPercentQueryGaps)
			# Does align score pass filter?
			if(@doCalcAlignScore and !@minAlignScore.nil?)
				alignScoreOK = (alignScore(blastHit) >= @minAlignScore ? true : false)
			end
			unless(queryLenOK and matchesOK and queryPercentOK and qGapBasesOK and  qGapBasesOK and ((@doCalcAlignScore and !@minAlignScore.nil?) ? alignScoreOK : true))
				@totalHitsFiltered += 1
			end
			return (queryLenOK and matchesOK and queryPercentOK and qGapBasesOK and ((@doCalcAlignScore and !@minAlignScore.nil?) ? alignScoreOK : true))
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
		def sortQueryHits()
			$stderr.puts "USING ALIGN SCR? '#{@useAlignScoreForMapping}'"
			unless(@useAlignScoreForMapping)
				@queryHitsHash.each {	|queryID, hitsArray|
					hitsArray.sort! {	|aa, bb|
						bb.percentIdentity <=> aa.percentIdentity
					}
				}
			else
				@queryHitsHash.each { |queryID, hitsArray|
					hitsArray.sort! { |aa, bb|
						alignScore(bb) <=> alignScore(aa)
					}
				}
			end
			return
		end

		def applyMappingFilters()
			# sort each query's hits
			self.sortQueryHits()
			# apply filters in proper order
			self.keepTopHits()
			self.applyMaxHitsPerQueryFilter()
			self.applyKeepKHitsFilter()
			self.applyCoverageFilter()
			self.applyTargetFilter()
		 	$stderr.puts "STATUS: #{@keepTopHitsFilteredCount + @maxQueryHitsFilteredCount + @keepKHitsFilteredCount} total hits were removed by mapping-filters."
			$stderr.puts "\t#{@keepTopHitsFilteredCount} were removed due to top-hits equivalence class creation."
			$stderr.puts "\t#{@maxQueryHitsFilteredCount} were removed due to too many top-hits for the query (#{@maxQueryHitsQueriesRemoved} queries removed)"
			$stderr.puts "\t#{@keepKHitsFilteredCount} were removed due to keeping only '#{@keepKhits}' top-hits per query."
			$stderr.puts "\t---------------------------------"
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
		def keepTopHits
			numDupHits = 0
			numUniqQnames = @queryHitsHash.size
			$stderr.puts "THERE ARE: '#{numUniqQnames}' unique query names"
			# keep hits that are within certain percentage of top
			@queryHitsHash.each {
				|queryID, hitsArray|
				next if(hitsArray.nil? or hitsArray.empty?())
				# $stderr.puts "USING ALIGN SCR? '#{@useAlignScoreForMapping}'"
				topScore = @useAlignScoreForMapping ? alignScore(hitsArray[0]) : hitsArray[0].bitScore()
				minScore = topScore * (@keepPercent / 100.0)
				newArray = [hitsArray[0]]
				(1..hitsArray.lastIndex).each {
					|ii|
					if((@useAlignScoreForMapping ? alignScore(hitsArray[ii]) : hitsArray[ii].bitScore()) >= minScore)
						newArray.push(hitsArray[ii])
					else
						@keepTopHitsFilteredCount += 1
					end
				}
				hitsArray.clear
				# remove duplicates
				lastHitStr = '' ; delHit = false 
				newArray.delete_if { |hit|
					hitStr = hit.to_s
					if(hitStr == lastHitStr)
						numDupHits += 1
						delHit = true
					else
						lastHitStr = hitStr
						delHit = false
					end
					delHit
				}
				@queryHitsHash[queryID] = newArray
			}
			$stderr.puts "DUPLICATE HITS REMOVED: '#{numDupHits}'"
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
		def applyMaxHitsPerQueryFilter()
			@queryHitsHash.keys.each {
				|queryID|
				if(@queryHitsHash[queryID].size > @maxHitsPerQuery)
					@maxQueryHitsFilteredCount += @queryHitsHash[queryID].size
					@maxQueryHitsQueriesRemoved += 1
					@queriesWithTooManyHits[queryID] = @queryHitsHash.delete(queryID)
				end
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
		def applyCoverageFilter()
			return unless(@doExcessiveCoverageFilter)
			@queryHitsHash.each {
				|queryID, hitsArray|
				coverage = 0
				hitsArray.each { | blastHit|
					coverage += (blastHit.tEnd + @coverageRadius) - (blastHit.tStart - @coverageRadius)
				}
				if(coverage > @excessiveCoverage)
					@queryHitsHash[queryID] = []
				end
			}
			@queryHitsHash.delete_if { |queryID, hitsArray|
				hitsArray.nil?() or hitsArray.empty?()
			}
			return
		end

		def applyTargetFilter()
			return unless(@doFilterTargetByNumProjs)
			@targRegions = {}
			@badTargRegions = {}
			@queryHitsHash.each { |queryID, hitsArray|
				hitsArray.each { |blastHit|
					unless(@targRegion.key?(blastHit.tName)) then @targRegion[tName] = [] end
					addToTargRegions(blastHit)
				}
			}
			findBadRegions()
			removeHitsInBadRegions()
			return
		end

		def removeHitsInBadRegions()
			@queryHitsHash.each { |queryID, hitsArray|
				hitsArray.each_index { |ii|
					blastHit = hitsArray[ii]
					@targRegions[blastHit.tName].each { |regions|
						regions.each { |region|
							if((blastHit.tStart <= (region[1]+@targetRegionRadius)) and (blastHit.tEnd >= (region[0]-@targetRegionRadius)))
								# then in bad region
								hitsArray.delete_at(ii)
								break
							end
						}
					}
				}
			}
			return
		end

		def findBadRegions()
			@targRegions.each { |targID, regions|
				regions.each { |region|
					projs = {}
					region[2].each { |blastHit|
						proj = blastHit.qName[ @projRegExp, 1 ]
						projs[proj] = ''
					}
					if(projs.size > @maxNumProjsInRegion)
						unless(@badTargRegions.key?(targID)) then @badTargRegions[targID] = [] end
						@badTargRegions << region
					end
				}
			}
			return
		end

		def addToTargRegion(blastHit)
			added = false
			@targRegions[blastHit.tName].each { |region|
				region.each { |region, queryList|
					break if(blastHit.tStart > region[1] and blastHit.tEnd > region[1])
					if((blastHit.tStart <= (region[1]+@targetRegionRadius)) and (blastHit.tEnd >= (region[0]-@targetRegionRadius))) # then overlaps
						region[0] = blastHit.tStart if(blastHit.tStart < region[0])
						region[1] = blastHit.tEnd if(blastHit.tEnd < region[1])
						region[2] << blastHit
						added = true
						break
					end
				}
				break if(added) # else keep looking
			}
			# Did we already find an existing spot for it? If so, we are done
			return if(added)
			# We didn't. So add it as a new region and resort. Naive. Check runtime.
			@targRegions[blastHit.tName] = [ [ blastHit.tStart, blastHit.tEnd, [ blastHit ] ] ]
			@targRegions[blastHit.tName].sort! { |aa, bb| aa[0] <=> bb[0] }
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
		def applyKeepKHitsFilter()
			@queryHitsHash.each {
				|queryID, hitsArray|
				if(hitsArray.size > @keepKhits)
					@keepKHitsFilteredCount += hitsArray.size - @keepKhits
					@queryHitsHash[queryID] = hitsArray[0,@keepKhits]
				end
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
		def mapWholeReads()
			return unless(@doMapWholeRead)
			@queryHitsHash.each {
				|queryID, hitsArray|
				hitsArray.each {
					|blastHit|
					blastHit.qStart = 0
					blastHit.qEnd = blastHit.qSize - 1
					blastHit.tStart = blastHit.zeroBasePos()
					blastHit.tEnd = blastHit.tStart + blastHit.qSize - 1
				}
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
		def processBlastHits()
			# apply hit filters
			self.applyHitFilters()
			# apply various mapping filters
			self.applyMappingFilters
			# map whole read to target, if appropriate
			self.mapWholeReads()
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
		def loadBlastHits()
			# get file list
			files = Dir.glob("#{@blastResultsDir}/#{@blastFilePattern}")
			numHits = 0
			files.each {
				|fileName|
				#reader = BRL::Util::TextReader.new(fileName)
				bhArray = BRL::Similarity::BlastMultiHit.new(fileName)
				numHits += bhArray.size
				#reader.close unless(reader.nil? or reader.closed?)
				bhArray.each {
					|blastHit|
					queryID = blastHit.qName
					unless(@queryHitsHash.key?(queryID))
						@queryHitsHash[queryID] = [ ]
					end
					@queryHitsHash[queryID].push(blastHit)
				}
				bhArray.clear
			}
			$stderr.puts "STATUS: loaded a total of '#{numHits}' blast hits."
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
		def saveBlastHits()
			pslFileName = "#{@outputDir}/#{@outputFileBase}.blast.gz"
			lffFileName = "#{@outputDir}/#{@outputFileBase}.lff.gz"
			pslWriter = BRL::Util::TextWriter.new(pslFileName, "w+", true)
			lffWriter = BRL::Util::TextWriter.new(lffFileName, "w+", true)
			
			@queryHitsHash.each {
				|queryID, hitsArray|
				hitsArray.each {
					|blastHit|
					pslStr = blastHit.to_s()
					if(@doOutputAlignScore)
						pslStr.gsub!(/\n/, '')
						pslStr += "\t#{alignScore(blastHit)}\n"
					end				
					pslWriter.print("#{pslStr}\n")
					lffWriter.print(blastHit.getAsLFFAnnotationString(true))
				}
			}
			pslWriter.close unless(pslWriter.nil? or pslWriter.closed?)
			lffWriter.close unless(lffWriter.nil? or lffWriter.closed?)
			return
		end

		# * *Function*:
		# * *Usage*   : <tt>   </tt>
		# * *Args*  :
		#   - +none+
		# * *Return* :
		#   - +Hash+  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def BlastMapper.processArguments
			# We want to add all the prop_keys as potential command line options
			optsArray =	[
										['--propFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
										['--help', '-h', GetoptLong::NO_ARGUMENT]
									]
			PROP_KEYS.each {
				|propName|
				argPropName = "--#{propName}"
				optsArray << [argPropName, GetoptLong::OPTIONAL_ARGUMENT]
			}
			progOpts = GetoptLong.new(*optsArray)
			optsHash = progOpts.to_hash
			BlastMapper.usage() if(optsHash.empty? or optsHash.key?('--help'));
			return optsHash
		end

	  # * *Function*: Displays some basic usage info on STDOUT
	  # * *Usage*   : <tt>  </tt>
	  # * *Args*  :
	  #   - +String+ Optional message string to output before the usage info.
	  # * *Return* :
	  #   - +none+
	  # * *Throws*  :
	  #   - +none+
		# --------------------------------------------------------------------------
		def BlastMapper.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "

  PROGRAM DESCRIPTION:


    COMMAND LINE ARGUMENTS:
      -p    => Properties file to use for conversion parameters, etc.
      -h    => [optional flag] Output this usage info and exit

    USAGE:
	";
			exit(2);
		end # def LFFMerger.usage(msg='')
	end # class BlastMapper
end ; end

# ##############################################################################
# MAIN
# ##############################################################################
# process command line options
optsHash = BRL::Similarity::BlastMapper.processArguments()
mapper = BRL::Similarity::BlastMapper.new(optsHash)
mapper.loadBlastHits()
mapper.processBlastHits()
mapper.saveBlastHits()
exit(0)
