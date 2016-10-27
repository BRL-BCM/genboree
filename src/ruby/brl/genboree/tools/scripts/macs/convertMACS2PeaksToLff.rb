#!/usr/bin/env ruby
require 'brl/util/util'

def usage()
  $stderr.puts "convertPeaksToEDACCLff.rb <macs xls file> <lff output> <new track> <new class> <avp>"
end

if (ARGV.size==0 || ARGV[0]=='-h' || ARGV[0]=='--help') then
  usage()
  exit(2)
end

if (ARGV.size != 5) then
  usage()
  exit(2)
end

# BAD SCRIPT THAT DOESN"T USE SCRIPT DRIVER CLASS.
# - THEREFORE WAS BROKEN b/c DIDN"T USE getOptLong and our classes
# - BUT Sameer assumed it was getOptlong compatible when calling it...bad process, not following SOPs
pashFile = ARGV[0]
lffFile = ARGV[1]
track = CGI.unescape(ARGV[2])
track =~ /([^:]+):(.+)/
nType = $1
nSubtype = $2
nClass = ARGV[3]
avp = CGI.unescape(ARGV[4])

r = File.open(pashFile, "r")
w = File.open(lffFile, "w")
l = nil
cStart = 0
cStop = 0
cAdjust = 0
chrom =  nil
val = nil
bandWidth = 200
r.each {|l|
  if (l=~/^\s*#/) then
    if (l=~ /band\s*width\s*=\s*(\d+)/) then
      bandWidth = $1
    end
    next
  end
  if ( l =~ /^\s*$/) then
    next
  end
  if (l=~/fold_enrichment/) then
    next
  end
  ff = l.strip.split(/\t/)
  chrom = ff[0]
  cStart = ff[1].to_i
  cStop = ff[2].to_i
  val = ff[5]
  minusLog10Pvalue = ff[6]
  foldEnrichment = ff[7]
  minusLog10Qvalue = ff[8]
  w.puts "#{nClass}\t#{chrom}_#{cStart}_#{cStop}\t#{nType}\t#{nSubtype}\t#{chrom}\t#{cStart}\t#{cStop}\t+\t.\t#{val}\t.\t.\tpileup=#{val}; minusLog10Qvalue=#{minusLog10Qvalue}; foldEnrichment=#{foldEnrichment}; minusLog10Qvalue=#{minusLog10Qvalue}; #{avp}"
}
r.close()
w.close()
