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

COMMENT_RE = /^\s*#/
BLANK_RE = /^\s*$/
TAB_RE = /\t/

agpRecs = {}
agpFile = ARGV[0]
gapCount = 0
nonGapCount = 0

$stderr.puts "STATUS: starting to load AGP records from file..."
File.open(agpFile) { |file|

	file.each { |line|
		next if(line =~ COMMENT_RE or line =~ BLANK_RE)
		ff = line.split(TAB_RE)
		agpRecs[ff[0]] = [] unless(agpRecs.key?(ff[0]))
		if(BRL::FileFormats::AGPGapRecord.isGapRecord?(ff))
			agpRecs[ff[0]] << BRL::FileFormats::AGPGapRecord.new(ff)
			gapCount += 1
		elsif(BRL::FileFormats::AGPNonGapRecord.isNonGapRecord?(ff))
			agpRecs[ff[0]] << BRL::FileFormats::AGPNonGapRecord.new(ff)
			nonGapCount += 1
		else
			$stderr.puts "ERROR: can't determine AGP record type for this line:\n\n'#{line}'\n\n"
			exit(137)
		end
	}
}
$stderr.puts "STATUS: Read in AGP records for #{agpRecs.size} groups. #{gapCount} gap records and #{nonGapCount} non-gap records."

$stderr.puts "STATUS: Output each record as LFF."
agpRecs.each { |objName, recs|
	gapCount = 1
	nonGapCount = 1
	prevRec = nil
	recs.each { |rec|
		if(rec.kind_of?(BRL::FileFormats::AGPGapRecord))
			puts rec.to_lff(gapCount)
			gapCount += 1
		elsif(rec.kind_of?(BRL::FileFormats::AGPNonGapRecord))
			puts rec.to_lff(nonGapCount)
			nonGapCount += 1
		else
			$stderr.puts "ERROR: can't determine AGP record type for this record:\n\n'#{rec.to_s}'\n\n"
			exit(137)
		end
		prevRec = rec
	}
}
$stderr.puts "STATUS: DONE."
exit(0)
