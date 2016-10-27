#!/usr/bin/env ruby

require 'brl/util/util.rb'
require 'brl/similarity/comparisonHit.rb'

module BRL ; module Similarity

class PashHit < ComparisonHit
	@@MAXSEQSIZE=4294967296
	attr_accessor :qName, :qStart, :qEnd, :qSize, :qNumGapBases
	attr_accessor :tName, :tStart, :tEnd, :tSize, :tNumGapBases
	attr_accessor :orientation	
	attr_accessor :numMatches, :numGaps
	attr_accessor :adaptiveScore
	
	#-----------------------------------------------
	#:section: Interface Methods
	#-----------------------------------------------
	
	def initialize(lineStr)
    
		ff = lineStr.chomp.split(/\t|\s+/)
		@tName = ff[0].to_s
		@tStart = ff[1].to_i-1
		@tEnd = ff[2].to_i-1
			
		@qName = ff[3].to_s
		@qStart = ff[4].to_i-1
		@qEnd = ff[5].to_i-1
		
		@qBlockStarts = ff[13].to_s
		@tBlockStarts = ff[12].to_s
		@orientation = ff[6].to_s
		@numMatches = ff[7].to_i
		@numGaps = ff[8].to_i
		@qNumGapBases = ff[9].to_i
		@tNumGapBases = ff[9].to_i
		@blockCount = ff[10].to_i
		@blockSizes = ff[11].to_s
		score()
		@qSize = @@MAXSEQSIZE
		@tSize = @@MAXSEQSIZE
    if (ff.size() == 15) then
      @adaptiveScore=ff[14]
    else
      @adaptiveScore=""
    end
	end
	
	def  replace(lineStr)
		ff = lineStr.chomp.split(/\t|\s+/)
		@tName = ff[0].to_s
		@tStart = ff[1].to_i-1
		@tEnd = ff[2].to_i-1
			
		@qName = ff[3].to_s
		@qStart = ff[4].to_i-1
		@qEnd = ff[5].to_i-1
		@qBlockStarts = ff[13].to_s.split(/,/)
		@tBlockStarts = ff[12].to_s.split(/,/) 	
		@orientation = ff[6].to_s
		@numMatches = ff[7].to_i
		@numGaps = ff[8].to_i
		@qNumGapBases = ff[9].to_i
		@tNumGapBases = ff[9].to_i
		@blockCount = ff[10].to_i
		@blockSizes = ff[11].to_s.split(/,/)
		score()
    @qSize = @@MAXSEQSIZE
		@tSize = @@MAXSEQSIZE
		if (ff.size() == 15) then
      @adaptiveScore=ff[14]
    else
      @adaptiveScore=""
    end
	end
	
	def  score(matchReward=2, mismatchPenalty=1, gapOpenPenalty=2, gapExtension=1)
		@score = matchReward*@numMatches - @numGaps*gapOpenPenalty- (@qNumGapBases-@numGaps)*gapExtension
	end
	
	def score=(score)		
		@score = score
	end
	
	def  to_lff(lffType='Abstract', lffSubtype='Hit', lffClass='Hits')
    lffString = "#{lffClass}\tPash\t#{lffType}\t#{lffSubtype}\t#{@tName}\t#{@tStart}\t#{@tEnd}\t#{@orientation}\t.\t#{@score}\t#{@qStart}\t#{@qEnd}"
    if (@adaptiveScore.to_s != "") then
			lffString = "#{lffString}\tadaptiveScore=#{@adaptiveScore}"
    end
    lffString
	end
	
	def  to_a()
    a= [@tName]
    a.push(@tStart+1)
    a.push(@tEnd+1)
    a.push(@qName)
    a.push(@qStart+1)
    a.push(@qEnd+1)
    a.push(@orientation)
    a.push(@numMatches)
    a.push(@numGaps)
    a.push(@qNumGapBases)
    a.push(@blockCount)
    a.push(@blockSizes)
    a.push(@tBlockStarts)
    a.push(@qBlockStarts)
    puts "#{@adaptiveScore}"
    if (@adaptiveScore.to_s == "") then
    else
      a.push(@adaptiveScore)
    end
    return a
	end
	
	def  columnHeaders()
    a = ["Target"];
    a.push("Target start")
    a.push("Target end")
    a.push("Query")
    a.push("Query start")
    a.push("Query end")
    a.push("Orientation")
    a.push("Matching bases")
    a.push("Gaps")
    a.push("Gap bases")
    a.push("Block count")
    a.push("Block lengths")
    a.push("Target block starts")
    a.push("Query block starts")
    if (@adaptiveScore.to_s != "")
      a.push("Adaptive score")
    end
    return a
	end
	
	def to_s
    self.to_a.join("\t")
	end
	
	##-----------------------------------------------
	##  :section: Overridable Methods
	##-----------------------------------------------
	#
	#def  qSpan()
	#end
	#def  tSpan()
	#end
	#def  firstBasePos()
	#end
	#def  queryPercentIdentity()
	#end
	#def  numRepeatMatches()
	#end
	#def  numRepeatMatches=(numRepeats)
	#end
	#def  queryPercentGapBases()
	#end
	#def  targetPercentGapBases()
	#end
	##-----------------------------------------------
	## :section: Helper Methods
	##-----------------------------------------------
	#def  raiseNotImplemented()
	#end
	#
	#def thisMethod(callerContext)
	#end

end

end; end
