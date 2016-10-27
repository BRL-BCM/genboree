#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'getoptlong'						# for GetoptLong class (command line option parse)
require 'brl/util/util'					# for to_hash extension of GetoptLong class
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes
require 'brl/util/logger'

# Constants
CPG_CLASS = CPG_TYPE = 'GC'
CPG_SUBTYPE = 'CpgIslands'
REJECT_CHR_RE = /^chr[^_]+_\d+$/
HEADER_RE = /^chrom\s+chromStart/
COMMENT_RE = /^\s*#/
BLANK_RE = /^\s*$/
REC_SPLIT_RE = /\t/
CHR_ID_RE = /chr(\S+)/
CHROM,CHROM_START,CHROM_STOP,CPG_NAME,CPG_LEN,CPG_NUM,CPG_GC_NUM,CPG_PERC_CPG,CPG_PERC_GC,CPG_OBSEXP = 0,1,2,3,4,5,6,7,8,9
CLASS,QNAME,TYPE,SUBTYPE,TNAME,TSTART,TEND,STRAND,PHASE,SCORE,QSTART,QEND,COMMENTS,SEQUENCE = 0,1,2,3,4,5,6,7,8,9,10,11,12,13

unless(ARGV.size > 0 and File.exists?(ARGV[0]))
	$stderr.puts "\n\nPROPER USAGE:\n\n\tcpgMunge_to1track.rb <gcPercentDataFile>\n\n"
	exit(134)
end

fileName = ARGV[0]
cpgCounter = Hash.new(){|hh,kk| hh[kk] = Hash.new(0)}

# Go through each line of the file and make LFF rec
lffRec1 = Array.new(13)
lffRec1[TYPE] = CPG_TYPE
lffRec1[SUBTYPE] = CPG_SUBTYPE
lffRec1[CLASS] = CPG_CLASS
lffRec1[QSTART] =  '.'
lffRec1[QEND] = '.'
lffRec1[STRAND] = '+'
lffRec1[PHASE] = '.'

reader = BRL::Util::TextReader.new(fileName)
reader.each { |line|
	next if(line =~ HEADER_RE or line =~ COMMENT_RE or line =~ BLANK_RE)
	fields = line.split(REC_SPLIT_RE)
	#$stderr.puts "%CPG: #{fields[CPG_PERC_CPG]}  %GC: #{fields[CPG_PERC_GC]}"
	fields.map! { |xx| xx.strip }
	fields[CHROM] =~ CHR_ID_RE
	chrID = $1
	#lffRec1[QNAME] = fields[CPG_NAME].gsub(/\s+/,'') + '(' + fields[CHROM] + '_' + fields[CHROM_START] + '_' + fields[CHROM_STOP] + ')'
	#fields.delete_at(CPG_NAME) unless(fields.size <= 9)
	fields[CPG_NAME].gsub!(/\s+/,'')
	cpgCounter[chrID][fields[CPG_NAME]] += 1
	lffRec1[QNAME] = 'chr' + chrID + '.' + fields[CPG_NAME] + '.' + cpgCounter[chrID][fields[CPG_NAME]].to_s
	lffRec1[TNAME] = fields[CHROM]
	lffRec1[TSTART] = fields[CHROM_START]
	lffRec1[TEND] = fields[CHROM_STOP]
	lffRec1[SCORE] = fields[CPG_PERC_CPG]
	lffRec1[COMMENTS] = "CpG=#{fields[CPG_PERC_CPG]}%; GC=#{fields[CPG_PERC_GC]}%; length=#{fields[CPG_LEN]}; cpgNum=#{fields[CPG_NUM]}; gcNum=#{CPG_GC_NUM}; "
	lffRec1[COMMENTS] << "obsExp=#{fields[CPG_OBSEXP]};" if(fields.length >= 9)
	puts lffRec1.join("\t")
}
reader.close

exit(0)
