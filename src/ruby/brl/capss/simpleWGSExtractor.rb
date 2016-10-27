#!/usr/bin/env ruby

=begin
  Author: Andrew R Jackson <andrewj@bcm.tmc.edu>
=end
# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/dna/fastaRecord'

BLANK_RE = /^\s*$/
FILE_RE = /^FILE:\s+(.+)$/
BAC_RE = /^BAC:\s+(.+)$/

$stdout.sync = true

bacDir = "/users/hgsc/andrewj/brl/capss/seaUrchin/06-10-2003/poolProjects/betterGraph_BINS/12-12-2003/BACS_with_ALL_decon_reads"
scratch = "/users/hgsc/andrewj/brl/capss/seaUrchin/06-10-2003/poolProjects/betterGraph_BINS/12-12-2003/BACS_with_ALL_decon_reads/scratch"

wgs2BacMapFileName = ARGV[0]
seqFile2wgsReadsFileName = ARGV[1]
qualFile2wgsReadsFileName = ARGV[2]

# Suck in wgs read to bac map
print "STATUS: Loading wgs to bac map"
read2bac = {}
reader = BRL::Util::TextReader.new(wgs2BacMapFileName)
reader.each { |line|
	line.strip!
	next if(line =~ BLANK_RE)
	if(line =~ BAC_RE)
		bac = $1
		readLine = reader.readline().strip
		reads = readLine.split(/\s+/)
		reads.each { |readID| read2bac[readID] = bac }
	end
}
reader.close()
puts "...done ('#{read2bac.size}' wgs reads needed)"

# Suck in wgs read seq location map
# print "STATUS: Loading wgs read seq location map"
# read2seqFaFile = {}
# reader = BRL::Util::TextReader.new(seqFile2wgsReadsFileName)
# reader.each { |line|
# 	line.strip!
# 	next if(line =~ BLANK_RE)
# 	if(line =~ FILE_RE)
# 		fileLoc = $1
# 		readLine = reader.readline().strip
# 		reads = readLine.split(/\s+/)
# 		reads.each { |readID|
# 			# Only save a record if it's one of the ones we need to know about
# 			next unless(read2bac.key?(readID))
# 			read2seqFaFile[readID] = fileLoc
# 		}
# 	end
# }
# reader.close()
# puts "...done. ('#{read2seqFaFile.size}' wgs reads with seq locations)"

# Suck in wgs read qual location map
print "STATUS: Loading wgs read qual location map"
read2qualFaFile = {}
reader = BRL::Util::TextReader.new(qualFile2wgsReadsFileName)
reader.each { |line|
	line.strip!
	next if(line =~ BLANK_RE)
	if(line =~ FILE_RE)
		fileLoc = $1
		readLine = reader.readline().strip
		reads = readLine.split(/\s+/)
		reads.each { |readID|
			# Only save a record if it's one of the ones we need to know about
			next unless(read2bac.key?(readID))
			read2qualFaFile[readID] = fileLoc
		}
	end
}
reader.close()
puts "...done. ('#{read2qualFaFile.size}' wgs reads with seq locations)"

# For each read seq file, we want the list of reads needed from that file
# print "STATUS: inverting wgs->seqFile hash"
# seqFile2reads = {}
# read2bac.each { |readID, bac|
# 	# What file is the read in?
# 	if(read2seqFaFile.key?(readID))
# 		readFile = read2seqFaFile[readID]
# 	else
# 		$stderr.puts "WARNING: read 'readID' is not in any known file???"
# 		next
# 	end
# 	unless(seqFile2reads.key?(readFile)) then seqFile2reads[readFile] = [] end
# 	seqFile2reads[readFile] << readID
# }
# puts "...done ('#{seqFile2reads.size}' seq files to look at)"

# For each read qual file, we want the list of reads needed from that file
print "STATUS: inverting wgs->qualFile hash"
qualFile2reads = {}
read2bac.each { |readID, bac|
	# What file is the read in?
	if(read2qualFaFile.key?(readID))
		readFile = read2qualFaFile[readID]
	else
		$stderr.puts "WARNING: read 'readID' is not in any known file???"
		next
	end
	unless(qualFile2reads.key?(readFile)) then qualFile2reads[readFile] = [] end
	qualFile2reads[readFile] << readID
}
puts "...done ('#{qualFile2reads.size}' qual files to look at)"

# Loop over each relevant file, suck in the fastas, append each fasta to the correct bac's WGS fa file
puts "STATUS: extract needed reads"
tmpFileBase = 'fa.tmp'
tmpFile = nil
# [seqFile2reads, qualFile2reads].each { |file2reads|
# 	puts "\tSTATUS: doing new file type"
# 	file2reads.each { |readFile, reads|
qualFile2reads.each { |readFile, reads|
		print '.'
		# gunzip the file to a nice spot
		tmpFile = "#{scratch}/#{tmpFileBase}"
		`gunzip -c #{readFile} > #{tmpFile}`
		reader = BRL::Util::TextReader.new(tmpFile)
		faHash = BRL::DNA::FastaQualRecordHash.new(reader)
		reads.each { |readID|
			# what is the bac this read fished to?
			bac4read = read2bac[readID]
			# what is the wgs output file?
# 			wgsFaFile = "#{bacDir}/#{bac4read}/#{file2reads == seqFile2reads ? 'wgsReads.fa' : 'wgsReads.fa.qual'}"
			wgsFaFile = "#{bacDir}/#{bac4read}/wgsReads.fa.qual"
			writer = BRL::Util::TextWriter.new(wgsFaFile, "a")
			# get the fasta record
			readRec = faHash[readID]
			if(readRec.nil?)
				$stderr.puts "ERROR: read 'readID' not found in the hash! Keys in hash:\n#{faHash.keys.sort.join(',')}"
				exit(135)
			end
			writer.print(readRec)
			writer.close()
		}
		# reader.close()
		# clean up tmp file
		`rm -f #{tmpFile}`
	}
# }
puts "\n ALL DONE!"
exit(0)
