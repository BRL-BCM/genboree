#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/util/util'					# for to_hash extension of GetoptLong class
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes
require 'brl/fileFormats/AGP'
require 'GSL'

COMMENT_RE = /^\s*#/
BLANK_RE = /^\s*$/
TAB_RE = /\t/
SPACE_RE = /\s+/
GT_RE = />/
CONTIG_RE = /(Contig\d+)/
NEWLINE_RE = /\n/
MINUS_RE = /\-/

class HbContigMapRecord
	attr_accessor :trimName, :origName, :origLen, :trimPos
	
	def initialize(arrayRec)
		@trimName, @origName, @origLen, @trimPos = 
			arrayRec[0], arrayRec[1], arrayRec[2].to_i, arrayRec[3].to_i
	end
	
	def to_s()
		return "#{@trimName}\t#{@origName}\t#{@origLen}\t#{@trimPos}"
	end
end

class ContigLffRecord
	attr_accessor :contigName, :groupName, :groupStart, :groupEnd, :orientation, :contigStart, :contigEnd
	
	def initialize(arrayRec)
		@contigName, @groupName, @groupStart, @groupEnd, @orientation, @contigStart, @contigEnd =
			arrayRec[1], arrayRec[4], arrayRec[5].to_i, arrayRec[6].to_i,
			arrayRec[7], arrayRec[10].to_i, arrayRec[11].to_i
	end	
end
	
$stderr.puts "STATUS: Read contig name translation info..."
transFile = ARGV[0]
trimToOrigMap = {}
origToTrimMap = {}
File.open(transFile) { |file|
	file.each { |line|
		next if(line =~ COMMENT_RE or line =~ BLANK_RE)
		ff = line.split(TAB_RE)
		hbCRec = HbContigMapRecord.new(ff)
		trimToOrigMap[hbCRec.trimName] = hbCRec
		origToTrimMap[hbCRec.origName] = hbCRec
	}
}
$stderr.puts "STATUS: Done reading contig trans info."


$stderr.puts "STATUS: Starting to load contig LFF records from file..."
contigFile = ARGV[1]
contigLffRecs = {}
File.open(contigFile) { |file|
	file.each { |line|
		next if(line =~ COMMENT_RE or line =~ BLANK_RE)
		ff = line.split(TAB_RE)
		cLffRec = ContigLffRecord.new(ff)
		contigLffRecs[cLffRec.contigName] = cLffRec
	}	
}
$stderr.puts "STATUS: Done reading contig LFF info."

dataDir = ARGV[2]
dataExt = ARGV[3]
dataType = ARGV[4]
dataSubtype = ARGV[5]
runWindow = ARGV[6].to_i
dataPatt = "#{dataDir}/*#{dataExt}"
miaContigs = {}
ctgCount = 0

$stderr.puts "STATUS: Starting to process all the #{dataPatt} files:"
# Go through each fasta score file, chop it up, process each record
dataFiles = Dir.glob(dataPatt)
dataFiles.each { |dataFile|
	$stderr.print "\t#{dataFile} ... "
	dataIO = File.open(dataFile)
	rawContent = dataIO.read
	contigScrRecs = rawContent.split('>') # chop file into records
	contigScrRecs.shift # remove first empty record
	# For each contig score record, convert name to assembly
	# contig name, figure out where to read, do run-encodings, output lff records
	contigScrRecs.each { |contigScrRec|
		contigScrRec =~ CONTIG_RE
		origContigName = $1
		hbCRec = origToTrimMap[origContigName]	
		unless(origToTrimMap.key?(origContigName))
			miaContigs[origContigName] = ''
		else
			ctgCount += 1
			lines = contigScrRec.split("\n")
			lines.shift # remove the defline
			trimContigName = hbCRec.trimName
			scrStr = lines.join(' ').strip
			scrs = scrStr.split(' ')
			# Need to isolate relevant bases
			trimPos = hbCRec.trimPos
			trimLen = (contigLffRecs[trimContigName].contigEnd - contigLffRecs[trimContigName].contigStart) + 2
			trimScrs = scrs[trimPos, trimLen]
			# Reverse scrs if contig is -
			contigOri = contigLffRecs[trimContigName].orientation
			trimScrs.reverse! if(contigOri =~ MINUS_RE)
			# Now do run encoding
			grpName = contigLffRecs[trimContigName].groupName
			grpStart = contigLffRecs[trimContigName].groupStart
			lastIdx = trimScrs.size - 1
			run = nil
			runCount = 0
			if(runWindow == 0)
				trimScrs.each_index { |ii|
					if(run.nil?)
						run = [trimScrs[ii], ii, ii]
					else
						# We have a run...extend?
						if(run[0] == trimScrs[ii]) # then extend
							run[2] = ii
						else # then old run is done
							runCount += 1
							puts "QualityMetrics\t#{trimContigName}.#{runCount}\t#{dataType}\t#{dataSubtype}\t#{grpName}\t#{grpStart+run[1]}\t#{grpStart+run[2]}\t#{contigOri}\t.\t#{run[0]}\t#{run[1]}\t#{run[2]}"
							run = [trimScrs[ii], ii, ii]
						end
					end
				}
			else
				ii = 0
				while(ii < lastIdx)
					jj = ii+runWindow
					jj = (jj < lastIdx) ? jj : lastIdx
					window = trimScrs[ii, runWindow]
					window.map! {|xx| xx.to_f}
					windowScr = GSL::Stats::mean(window,1)
					runCount += 1
					puts "QualityMetrics\t#{trimContigName}.#{runCount}\t#{dataType}\t#{dataSubtype}\t#{grpName}\t#{grpStart+ii}\t#{grpStart+jj}\t#{contigOri}\t.\t#{windowScr}\t#{ii}\t#{jj}"
					ii = jj+1
				end
			end
		end
	}
	$stderr.puts "Done."
}
$stderr.puts "STATUS: Done Processing all the data files."
$stderr.puts "WARNING: couldn't place score records on assembly for '#{miaContigs.size}' contigs."
$stderr.puts "STATUS: DONE"
exit(0)
