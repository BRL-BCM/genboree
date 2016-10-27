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

class HbContigMapRecord
	attr_accessor :trimName, :origName, :origLen, :trimPos
	
	def initialize(arrayRec)
		@trimName, @origName, @origLen, @trimPos = 
			arrayRec[0], arrayRec[1], arrayRec[2].to_i, arrayRec[3].to_i
	end
end

transFile = ARGV[0]
trimToOrigMap = {}
origToTrimMap = {}

File.open(transFile).each { |line|
	next if(line =~ COMMENT_RE or line =~ BLANK_RE)
	ff = line.split(TAB_RE)
	hbCRec = HbContigMapRecord.new(ff)
	trimToOrigMap[hbCRec.trimName] = hbCRec
	origToTrimMap[hbCRec.origName] = hbCRec
}

scafAgpRecsByGroup = {}
scafAgpRecsByName = {}
scafAgpFile = ARGV[1]
gapCount = 0
nonGapCount = 0
$stderr.puts "STATUS: starting to load scaffold AGP records from file..."
File.open(scafAgpFile) { |file|
	file.each { |line|
		next if(line =~ COMMENT_RE or line =~ BLANK_RE)
		ff = line.split(TAB_RE)
		scafAgpRecsByGroup[ff[0]] = [] unless(scafAgpRecsByGroup.key?(ff[0]))
		if(BRL::FileFormats::AGPGapRecord.isGapRecord?(ff))
			scafAgpRecsByGroup[ff[0]] << BRL::FileFormats::AGPGapRecord.new(ff)
			gapCount += 1
		elsif(BRL::FileFormats::AGPNonGapRecord.isNonGapRecord?(ff))
			nonGapRec = BRL::FileFormats::AGPNonGapRecord.new(ff)
			scafAgpRecsByGroup[ff[0]] << nonGapRec
			scafAgpRecsByName[nonGapRec.compID] = nonGapRec
			nonGapCount += 1
		else
			$stderr.puts "ERROR: can't determine AGP record type for this line:\n\n'#{line}'\n\n"
			exit(137)
		end
	}
}
$stderr.puts "STATUS: Read in scaffold AGP records for #{scafAgpRecsByGroup.size} groups. #{gapCount} gap records and #{nonGapCount} (#{scafAgpRecsByName.size}) non-gap records."

contigAgpFile = ARGV[2]
$stderr.puts "STATUS: starting to convert contig AGP records to LFF..."
File.open(contigAgpFile) { |file|
	file.each { |line|
		next if(line =~ COMMENT_RE or line =~ BLANK_RE)
		ff = line.split(TAB_RE)
		if(BRL::FileFormats::AGPGapRecord.isGapRecord?(ff))
			$stderr.puts "WARNING: gap contig record? Look:\n\n'#{line}'\n\n"
		elsif(BRL::FileFormats::AGPNonGapRecord.isNonGapRecord?(ff))
			contigRec = BRL::FileFormats::AGPNonGapRecord.new(ff)
			scafRec = scafAgpRecsByName[contigRec.objName]
			groupName = scafRec.objName
			contigStart = scafRec.objStart + contigRec.objStart - 1
			contigEnd = scafRec.objStart + contigRec.objEnd - 1
			puts "Assembly\t#{contigRec.compID}\tAssembly\tContigs\t#{groupName}\t#{contigStart}\t#{contigEnd}\t#{contigRec.orientation =~ /^U$/i ? '.' : contigRec.orientation}\t.\t1.0\t#{contigRec.compStart}\t#{contigRec.compEnd}"
		else
			$stderr.puts "ERROR: can't determine AGP record type for this line:\n\n'#{line}'\n\n"
			exit(137)
		end
	}
}
$stderr.puts "STATUS: DONE"

exit(0)


