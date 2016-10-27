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

SCF_RE = /^(.+)\.scf$/
FWD_CODES = [ 'D'[0] ]
REV_CODES = [ 'E'[0], 'Q'[0] ] 
MAX_INT32 = 2**32-1


class TemplateHits < Hash
	attr_accessor :templateID, :fwdHits, :revHits, :matchingHits
	
	def initialize(templateID)
		@templateID = templateID
		@fwdHits = []
		@revHits = []
		@matchingHits = []
	end
end

class MatchingHit
	attr_accessor :chrID, :fwdHit, :revHit
	
	def initialize(chrID=nil, fwdHit=nil, revHit=nil)
		@chrID, @fwdHit, @revHit = chrID, fwdHit, revHit
	end
end

def insertSize(hit1, hit2)
	return -1 if(hit1.tName != hit2.tName)
	tStart = [hit1.tStart, hit1.tEnd, hit2.tStart, hit2.tEnd].min
	tEnd = [hit1.tStart, hit1.tEnd, hit2.tStart, hit2.tEnd].max
	return (tEnd - tStart) + 1	
end

def getTemplateID(readID)
	templateID = readID.dup
	if(templateID =~ SCF_RE)
		templateID = $1
	end
	templateID[6] = '_'[0]
	return templateID
end

# Load the blat hits
file = ARGV[0]
maxInsertSize = ARGV[1].to_i

$stderr.puts "STATUS: Starting. Going to read data now."
reader = BRL::Util::TextReader.new(file)
bhArray = BRL::Similarity::BlatMultiHit.new(reader)
$stderr.puts "STATUS: loaded a total of '#{bhArray.size}' blat hits."
reader.close unless(reader.nil? or reader.closed?)

# Collect reads by template
hitsByTemplate = {}
bhArray.each {	|blatHit|
	templateID = getTemplateID(blatHit.qName)
	hitsByTemplate[templateID] = TemplateHits.new(templateID) unless(hitsByTemplate.key?(templateID))
	if(FWD_CODES.member?(blatHit.qName[6]))			# then a fwd read
		hitsByTemplate[templateID].fwdHits << blatHit
	elsif(REV_CODES.member?(blatHit.qName[6]))	# then a rev read
		hitsByTemplate[templateID].revHits << blatHit
	else # Error
		$stderr.puts "\n\nERROR: unknown read code '#{blatHit.qName[6].chr}'.\n\tCannot decide if fwd or rev read. The blatHit was:\n'#{blatHit.to_s}'"
		exit(135)
	end
}
$stderr.puts "STATUS: collected hits by template. There are '#{hitsByTemplate.size}' unique templates (possible mate-pairs)."

# For each template, try to match up fwd-rev hits into matching ones
numMatchingHits = 0
hitsByTemplate.each { |templateID, templHits|
	# Sort the fwd hits by alignScores
	templHits.fwdHits.sort! { |aa, bb| bb.alignScore <=> aa.alignScore }
	templHits.revHits.sort! { |aa, bb| bb.alignScore <=> aa.alignScore }
	# Go through each fwd hit and try to match it to the best rev hit
	templHits.fwdHits.each_index { |ii|
		fwdHit = templHits.fwdHits[ii]
		bestInsertSize = MAX_INT32
		bestRev = nil ; bestRevIdx = nil
		templHits.revHits.each_index { |jj|
			revHit = templHits.revHits[jj]
			next if(revHit.nil? or fwdHit.tName != revHit.tName)
			insertSize = insertSize(fwdHit, revHit)
			if(insertSize < maxInsertSize and insertSize < bestInsertSize) # then found new 'best' match-up for this fwdHit
				bestInsertSize = insertSize
				bestRev = revHit
				bestRevIdx = jj
			end
		}
		unless(bestRev.nil?) # then we found a good match for it
			matchingHit = MatchingHit.new(fwdHit.tName, fwdHit, bestRev)
			templHits.matchingHits << matchingHit
			templHits.fwdHits[ii] = nil
			templHits.revHits[bestRevIdx] = nil
			numMatchingHits += 1
		end
	}
	templHits.fwdHits.compact!
	templHits.revHits.compact!
}
$stderr.puts "STATUS: found matching pairs of hits. Formed '#{numMatchingHits}' such pairs.\n\n"

# Dump some numbers onto stderr
numReadsBefore = numReadsAfter = numFwdSingles = numRevSingles = numPairs = 0
avgInsertSize = 0.0
tmpHash = {}
bhArray.each { |hit| tmpHash[hit.qName] = '' }
$stderr.puts "Num Unique Reads Before Filtering: #{tmpHash.size}"
tmpHash.clear
fsReads = {} ; rsReads = {} ; mpReads = {}
hitsByTemplate.each { |id, ths|
	unless(ths.matchingHits.size > 0)
		ths.fwdHits.each { |hit| tmpHash[hit.qName] = '' ; fsReads[hit.qName] = '' }
		ths.revHits.each { |hit| tmpHash[hit.qName] = '' ; rsReads[hit.qName] = '' }
		numFwdSingles += ths.fwdHits.size
		numRevSingles += ths.revHits.size
	else
		ths.matchingHits.each { |hit|
			tmpHash[hit.fwdHit.qName] = '' ; mpReads[hit.fwdHit.qName] = ''
			tmpHash[hit.revHit.qName] = '' ; mpReads[hit.revHit.qName] = ''
			numPairs += 1
			avgInsertSize += insertSize(hit.fwdHit, hit.revHit)
		}
	end
}
avgInsertSize /= numPairs
$stderr.puts "Num Unique Reads After Filtering: #{tmpHash.size}"
$stderr.puts "\nNum FWD Single Hits: #{numFwdSingles} (out of #{numFwdSingles + numPairs})"
$stderr.puts "Num REV Single Hits: #{numRevSingles} (out of #{numRevSingles + numPairs})"
$stderr.puts "Num Pairs of Hits: #{numPairs}"
$stderr.puts "\nNum FWD Single Reads: #{fsReads.size} (out of #{tmpHash.size})"
$stderr.puts "Num REV Single Reads: #{rsReads.size} (out of #{tmpHash.size})"
$stderr.puts "Num Paired-Up Reads: #{mpReads.size} (out of #{tmpHash.size})"
$stderr.puts "\nAvg 'Insert' Size: #{avgInsertSize}"
$stderr.puts "\n\n"
$stderr.puts "Insert Sizes:"
hitsByTemplate.each { |id, ths|
	next unless(ths.matchingHits.size > 0)
	ths.matchingHits.each { |hit|
		$stderr.puts "#{getTemplateID(hit.fwdHit.qName)}\t#{insertSize(hit.fwdHit, hit.revHit)}"
	}
}
$stderr.puts "\n\n"
tmpHash.clear

# Now dump the data
hitsByTemplate.each { |templateID, templHits|
	# If there is 1+ matching hits for this template, output it (them)
	if(templHits.matchingHits.size > 0)
		templHits.matchingHits.each { |matchingHit|
			puts matchingHit.fwdHit.to_s.gsub(/\n/,'') + "\t#{matchingHit.fwdHit.alignScore()}"
			puts matchingHit.revHit.to_s.gsub(/\n/,'') + "\t#{matchingHit.revHit.alignScore()}"
			
		}
	# Else, output all the separate hits
	else
		templHits.fwdHits.each { |fwdHit|
			puts fwdHit.to_s.gsub(/\n/,'') + "\t#{fwdHit.alignScore()}"
		}
		templHits.revHits.each { |revHit|
			puts revHit.to_s.gsub(/\n/,'') + "\t#{revHit.alignScore()}"
		}
	end
}
