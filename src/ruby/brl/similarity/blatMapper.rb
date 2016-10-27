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
require 'brl/similarity/blatHit'

# Turn on extra warnings and such
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

#=== *Purpose* :
#  Namespace for BRL's directly-related Genboree Ruby code.
module BRL ; module Similarity
	class BlatMapper
    
# Required properties
		PROP_KEYS = 	%w{
											input.dir.blatResults
											input.filePattern.blatFiles
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
			PROP_KEYS.each { |propName|
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
			@blatResultsDir = @propTable['input.dir.blatResults']
			@outputDir = @propTable['output.dir.outputDir']
			@blatFilePattern = @propTable['input.filePattern.blatFiles']
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
			
			# Optional parameters (for backward compatibility)
			@maxPercentTargetGaps = @propTable.key?('param.hitFilter.maxPercentTargetGaps') ? @propTable['param.hitFilter.maxPercentTargetGaps'].to_f : nil
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
			queryID = nil
			@queryHitsHash.each_key {	|queryID|
        hitsArray = @queryHitsHash[queryID]
        # already filtered upon loading, just need the numbers now
        numHitsKept += hitsArray.length
			}
		 	$stderr.puts "#{Time.now} STATUS: #{@totalHitsFiltered} total hits were removed by hit-filters"
			$stderr.puts "\t#{@queryLenFilteredCount} hits had query length < '#{@minQueryLength}'"
			$stderr.puts "\t#{@numMatchesFilteredCount} hits had number of identities < '#{@minNumIdentities}'"
			$stderr.puts "\t#{@queryPercentFilteredCount} hits had query percent identity < '#{@minQueryPercent}'"
			$stderr.puts "\t---------------------------------"
			return
		end

		def alignScore(blatHit)
			return blatHit.alignScore(@alignMatchReward, @alignMismatchPenalty, @alignGapOpenPenalty, @alignGapOpenPenalty)		
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
		def checkHit(blatHit)
			# Check min query length
			unless((queryLenOK = blatHit.qSize >= @minQueryLength ? true : false))
				@queryLenFilteredCount += 1
			end
			# Check num matches
			unless((matchesOK = blatHit.numMatches >= @minNumIdentities ? true : false))
				@numMatchesFilteredCount += 1
			end
			# Check query percent identity
			unless((queryPercentOK = blatHit.queryPercentIdentity() >= @minQueryPercent ? true : false))
				@queryPercentFilteredCount += 1
			end

			# Do we have too many gap bases on the query or not?
			qGapBasesOK = (blatHit.percentGapBases() <= @maxPercentQueryGaps)
			
			# Do we have too many gap bases on the target or not?
			if(@maxPercentTargetGaps)
			  tGapBasesOK = (blatHit.percentTargetGapBases() <= @maxPercentTargetGaps)
			else
			  tGapBasesOK = true
			end
			
			# Does align score pass filter?
			if(@doCalcAlignScore and !@minAlignScore.nil?)
				alignScoreOK = (alignScore(blatHit) >= @minAlignScore ? true : false)
			end
			unless(queryLenOK and matchesOK and queryPercentOK and qGapBasesOK and tGapBasesOK and ((@doCalcAlignScore and !@minAlignScore.nil?) ? alignScoreOK : true))
				@totalHitsFiltered += 1
			end
			return (queryLenOK and matchesOK and queryPercentOK and qGapBasesOK and tGapBasesOK and ((@doCalcAlignScore and !@minAlignScore.nil?) ? alignScoreOK : true))
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
			$stderr.puts "#{Time.now} USING ALIGN SCR? '#{@useAlignScoreForMapping}'"
			queryID = nil
			unless(@useAlignScoreForMapping)
				@queryHitsHash.each_key {	|queryID|
          hitsArray = @queryHitsHash[queryID]
					hitsArray.sort! {	|aa, bb|
						bb.queryPercentIdentity() <=> aa.queryPercentIdentity()
					}
				}
			else
				@queryHitsHash.each_key { |queryID|
          hitsArray = @queryHitsHash[queryID]
					hitsArray.sort! { |aa, bb|
						alignScore(bb) <=> alignScore(aa)
					}
				}
			end
			return
		end

		def applyMappingFilters()
			# apply filters in proper order
			self.keepTopHits()
			self.applyMaxHitsPerQueryFilter()
			# sort each query's [now probably much short] hits list prior to keeping only k of them
			self.sortQueryHits()
			# self.removeDuplicates() # not really needed? blat bug work-around
			self.applyKeepKHitsFilter()
			self.applyCoverageFilter()
			self.applyTargetFilter()
		 	$stderr.puts "#{Time.now} STATUS: #{@keepTopHitsFilteredCount + @maxQueryHitsFilteredCount + @keepKHitsFilteredCount} total hits were removed by mapping-filters."
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
			keepPercentFrac = @keepPercent / 100.0
			$stderr.puts "#{Time.now} THERE ARE: '#{numUniqQnames}' unique query names"
			# keep hits that are within certain percentage of top
			queryID = nil
			@queryHitsHash.each_key { |queryID|
        hitsArray = @queryHitsHash[queryID]
				next if(hitsArray.nil? or hitsArray.empty?())
				# Pass 1: find topScore
				topScore = Integer::MIN32.to_f
				blatHit = nil
				hitsArray.each { |blatHit|
          currScr = (@useAlignScoreForMapping ? alignScore(blatHit) : blatHit.queryPercentIdentity())
          topScore = currScr.to_f if(currScr > topScore)
        }
        # Keep only those within a % of the top score
				minScore = topScore * keepPercentFrac
				newArray = []
				hitsArray.each { |blatHit|
          currScr = (@useAlignScoreForMapping ? alignScore(blatHit) : blatHit.queryPercentIdentity())
          if(currScr >= minScore)
            newArray << blatHit
					else
						@keepTopHitsFilteredCount += 1
					end
				}
				hitsArray.clear
				
				@queryHitsHash[queryID] = newArray
			}
			return
		end

    # Is this really necessary? Maybe not...blat *sometimes* does this, but not always.
    # The hitArrays for each query need to be sorted first (by score) for this to work, if used.
    def removeDuplicates()
      queryID = nil
      @queryHitsHash.each_key { |queryID|
        hitsArray = @queryHitsHash[queryID]
        next if(hitsArray.nil? or hitsArray.empty?())
        # remove duplicates
				lastHitStr = '' ; delHit = false
				hit = nil
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
		def applyMaxHitsPerQueryFilter()
			queryID = nil
			@queryHitsHash.each_key { |queryID|
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
			queryID = nil
			@queryHitsHash.each_key { |queryID|
        hitsArray = @queryHitsHash[queryID]
				coverage = 0
				blatHit = nil
				hitsArray.each { |blatHit|
					coverage += (blatHit.tEnd + @coverageRadius) - (blatHit.tStart - @coverageRadius)
				}
				if(coverage > @excessiveCoverage)
					@queryHitsHash[queryID] = []
				end
			}
			@queryHitsHash.delete_if { |queryID|
        hitsArray = @queryHitsHash[queryId]
				hitsArray.nil?() or hitsArray.empty?()
			}
			return
		end

		def applyTargetFilter()
			return unless(@doFilterTargetByNumProjs)
			@targRegions = {}
			@badTargRegions = {}
			queryID = nil
			@queryHitsHash.each_key { |queryID|
        hitsArray = @queryHitsHash[queryID]
        blatHit = nil
				hitsArray.each { |blatHit|
					unless(@targRegion.key?(blatHit.tName)) then @targRegion[tName] = [] end
					addToTargRegions(blatHit)
				}
			}
			findBadRegions()
			removeHitsInBadRegions()
			return
		end

		def removeHitsInBadRegions()
			queryID = nil
			@queryHitsHash.each_key { |queryID|
        hitsArray = @queryHitsHash[queryID]
        ii = nil
				hitsArray.each_index { |ii|
					blatHit = hitsArray[ii]
					regions = nil
					@targRegions[blatHit.tName].each { |regions|
            regions = nil
						regions.each { |region|
							if((blatHit.tStart <= (region[1]+@targetRegionRadius)) and (blatHit.tEnd >= (region[0]-@targetRegionRadius)))
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
      targID = nil
			@targRegions.each_key { |targID|
        regions = @targRegions[targID]
        regions = nil
				regions.each { |region|
					projs = {}
					blatHit = nil
					region[2].each { |blatHit|
						proj = blatHit.qName[ @projRegExp, 1 ]
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

		def addToTargRegion(blatHit)
			added = false
			regions = nil
			@targRegions[blatHit.tName].each { |regions|
        regions = nil
				regions.each { |region|
          queryList = region[region]
					break if(blatHit.tStart > region[1] and blatHit.tEnd > region[1])
					if((blatHit.tStart <= (region[1]+@targetRegionRadius)) and (blatHit.tEnd >= (region[0]-@targetRegionRadius))) # then overlaps
						region[0] = blatHit.tStart if(blatHit.tStart < region[0])
						region[1] = blatHit.tEnd if(blatHit.tEnd < region[1])
						region[2] << blatHit
						added = true
						break
					end
				}
				break if(added) # else keep looking
			}
			# Did we already find an existing spot for it? If so, we are done
			return if(added)
			# We didn't. So add it as a new region and resort. Naive. Check runtime.
			@targRegions[blatHit.tName] = [ [ blatHit.tStart, blatHit.tEnd, [ blatHit ] ] ]
			@targRegions[blatHit.tName].sort! { |aa, bb| aa[0] <=> bb[0] }
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
			queryID = nil
			@queryHitsHash.each_key { |queryID|
        hitsArray = @queryHitsHash[queryID]
				if(hitsArray.size > @keepKhits)
					@keepKHitsFilteredCount += hitsArray.size - @keepKhits
					@queryHitsHash[queryID] = hitsArray[0, @keepKhits]
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
			queryID = nil
			@queryHitsHash.each_key { |queryID|
        hitsArray = @queryHitsHash[queryID]
        blatHit = nil
				hitsArray.each { |blatHit|
					blatHit.qStart = 0
					blatHit.qEnd = blatHit.qSize - 1
					blatHit.tStart = blatHit.zeroBasePos()
					blatHit.tEnd = blatHit.tStart + blatHit.qSize - 1
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
		def processBlatHits()
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
		# * *Change* :
		#   As file is read, apply checkHit() rather than saving into a Hash first.
		#   Then add to Hash for later assessment via equivalence class filtering.
		# * *TODO* :
		#   - If limited-size EC, then use a bounded data structure to store hits
		#   - Change BlatHit class to use Symbols for redundant strings...much more effective.
		# --------------------------------------------------------------------------
		def loadBlatHits()
			# get file list
			files = Dir.glob("#{@blatResultsDir}/#{@blatFilePattern}")
			numHits = 0
			# process the reads in each file--hits from a single query couple be
			# spread across the several files.
			lineNum = 0
			files.each { |fileName|
				reader = BRL::Util::TextReader.new(fileName)
				line = nil
				reader.each { |line|
          lineNum += 1
          line.strip!
          next if(line =~ /^\s*$/ or line =~ /^(?:psLayout|match|\s+match|-+)/)
          fields = line.split(/\s+/)
          if(fields.length >= BRL::Similarity::BlatHit::NUM_FIELDS) # then everything ok enough...extra fields ignored
            blatHit = BRL::Similarity::BlatHit.new(fields)
            # Check if hit passes raw filters
            passedRawFilters = checkHit(blatHit)
            if(passedRawFilters)
              numHits += 1
              queryID = blatHit.qName
              unless(@queryHitsHash.key?(queryID))
                @queryHitsHash[queryID] = [ ]
              end
              @queryHitsHash[queryID] << blatHit
            end
					else
            raise("ERROR: Bad blat record. BLAT Version 3 should be used. Line Number: #{lineNum}. Line found:\n>>\n#{line}\n<<\n")
					end
        }
				reader.close unless(reader.nil? or reader.closed?)
			}
			$stderr.puts "#{Time.now} STATUS: loaded a total of '#{numHits}' blat hits."
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
		def saveBlatHits()
			pslFileName = "#{@outputDir}/#{@outputFileBase}.psl.gz"
			lffFileName = "#{@outputDir}/#{@outputFileBase}.lff.gz"
			pslWriter = BRL::Util::TextWriter.new(pslFileName, "w+", true)
			lffWriter = BRL::Util::TextWriter.new(lffFileName, "w+", true)
			pslWriter.print(BlatMultiHit.headerStr)
			queryID = nil
			@queryHitsHash.each_key { |queryID|
        hitsArray = @queryHitsHash[queryID]
        blatHit = nil
				hitsArray.each { |blatHit|
					pslStr = blatHit.to_s()
					if(@doOutputAlignScore)
						pslStr.gsub!(/\n/, '')
						pslStr += "\t#{alignScore(blatHit)}\n"
					end				
					pslWriter.print(pslStr)
					lffWriter.print(blatHit.getAsLFFAnnotationString(true))
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
		def BlatMapper.processArguments
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
			BlatMapper.usage() if(optsHash.empty? or optsHash.key?('--help'));
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
		def BlatMapper.usage(msg='')
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
	end # class BlatMapper
end ; end

# ##############################################################################
# MAIN
# ##############################################################################
# process command line options
$stderr.puts "#{Time.now} STATUS: STARTING"
optsHash = BRL::Similarity::BlatMapper.processArguments()
mapper = BRL::Similarity::BlatMapper.new(optsHash)
mapper.loadBlatHits()
mapper.processBlatHits()
mapper.saveBlatHits()
$stderr.puts "#{Time.now} STATUS: ENDED"
exit(0)
