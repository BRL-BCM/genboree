#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/util/util'					# for to_hash extension of GetoptLong class
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes
require 'GSL'

# ##############################################################################
# INIT
# ##############################################################################
COMMENT_RE = /^\s*#/
BLANK_RE = /^\s*$/
MINUS_RE = /\-/
FASTAID_RE = /^(\S+)/
FASTAID, EP, START, STOP = 0,1,2,3
COORD_EP, COORD_START, COORD_STOP = 0,1,2
RUN_SCR, RUN_START, RUN_STOP = 0,1,2

# ##############################################################################
# PROCESS ARGS
# ##############################################################################
if(ARGV.size >= 4 and !ARGV[2].index(':').nil?)
	fastaScoreFile = ARGV[0]
	windowSize = ARGV[1].to_i
	trackName = ARGV[2]
	lffType, lffSubtype = ARGV[2].split(':')
	coordFile = ARGV[3]
	baseAnnoName = ARGV.size > 4 ? ARGV[4] : nil
else
	$stderr.puts "\n\nUSAGE:\n  runEncodeScoresToLFF.rb <fastaFile> <windowSize> <trackName> <coordFile> [baseAnnoName]"
	$stderr.puts "\nNOTES:\n  - the fasta file show look like a fasta quality file"
	$stderr.puts "  - if windowSize is 0, then simple run-encoding is done; no window-averaging"
	$stderr.puts "  - chrName is the chromosome or entrypoint name"
	$stderr.puts "  - the coordFile is a tab delimited file giving the chromosome (entrypoint) name, start, and stop\n    for each fastaID found in the fastaFile"
	$stderr.puts "  - the fastaID is the first WORD (non-whitespace) after the > on the defline"
	$stderr.puts "  - the first base is 1; and coordinates are inclusive"
	$stderr.puts "  - you should provide a baseAnnoName, such as 'Segment', otherwise all annotations will be in the \n   same group."
	$stderr.puts "\n\n"
	exit(134)
end

$stderr.puts "\n\n"
$stderr.puts "#{Time.now} STATUS: now reading the coord file"
coordMap = {}
File.open(coordFile) { |file|
	file.each { |line|
		next if(line =~ COMMENT_RE or line =~ BLANK_RE)
		fields = line.split("\t")
		coordMap[fields[FASTAID]] = [ fields[EP], fields[START].to_i, fields[STOP].to_i ]
	}
}
$stderr.puts "#{Time.now} STATUS: Starting to process the fasta score file"
dataIO = File.open(fastaScoreFile)
rawContent = dataIO.read
dataIO.close
$stderr.puts "#{Time.now} STATUS: splitting into separate fasta records"
fastaScrRecs = rawContent.split('>') # chop file into records
fastaScrRecs.shift # remove first empty record
$stderr.puts "#{Time.now} STATUS: about to process each fasta record"
# For each fasta score record, figure out where to read, do run-encodings, output lff records
recCount = 0
fastaScrRecs.each { |fastaScrRec|
	fastaScrRec =~ FASTAID_RE
	fastaID = $1
	annoName = baseAnnoName.nil? ? fastaID : baseAnnoName
	recCount += 1
	lines = fastaScrRec.split("\n")
	lines.shift # remove the defline
	scrStr = lines.join(' ').strip
	scrs = scrStr.split(' ')
	unless(coordMap.key?(fastaID))
		$stderr.puts "   WARNING: no coordMap record found for this fastaID: '#{fastaID}'. Skipping fasta record."
		next
	end
	ep = coordMap[fastaID][COORD_EP]
	startCoord = coordMap[fastaID][COORD_START]
	stopCoord = coordMap[fastaID][COORD_STOP]
	# Now do run encoding
	aRun = nil
	runCount = 0
	if(windowSize == 0) # no window-averaging, so run-encode
		scrs.each_index { |ii|
			if(aRun.nil?)
				aRun = [ scrs[ii], ii, ii ]
			else
				# We have a run...extend?
				if(aRun[RUN_SCR] == scrs[ii]) # same score as our current run-of-scores, so extend
					aRun[RUN_STOP] = ii
				else # then old run is done; output it
					runCount += 1
					puts "Assembly\t#{baseAnnoName.nil? ? fastaID : baseAnnoName+'.'+runCount.to_s}\t#{lffType}\t#{lffSubtype}\t#{ep}\t#{startCoord+aRun[RUN_START]}\t#{startCoord+aRun[RUN_STOP]}\t+\t.\t#{aRun[RUN_SCR]}\t#{aRun[RUN_START]+1}\t#{aRun[RUN_STOP]+1}"
					# start the new run
					aRun = [ scrs[ii], ii, ii ]
				end
			end
		}
	else # do fixed window averaging
		ii = 0
		while(ii < scrs.lastIndex)
			jj = ii + windowSize
			jj = scrs.lastIndex if(jj > scrs.lastIndex)
			window = scrs[ii, windowSize]
			window.map! {|xx| xx.to_f}
			windowScr = GSL::Stats::mean(window, 1)
			runCount += 1
			puts "QualityMetrics\t#{fastaID}.#{runCount}\t#{lffType}\t#{lffSubtype}\t#{ep}\t#{startCoord+ii}\t#{startCoord+jj}\t+\t.\t#{windowScr}\t#{ii}\t#{jj}"
			ii = jj+1
		end
	end
}
$stderr.puts "#{Time.now} STATUS: Done Processing all records."
exit(0)
