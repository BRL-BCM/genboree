#!/usr/bin/env ruby

if (ARGV.size==0 || ARGV[0]=="-h" || ARGV[0]=="--help") then
  puts "
prepareSmallRNAs.rb <Solexa fasta file> <genome directory> <job name> <ignore list>.
   Each sequence name corresponds to the occurences count\n.";
  exit(0)
end

fastaFile = ARGV[0]
genomeDir = ARGV[1]
jobName = ARGV[2]
ignoreList = ARGV[3]

tagsFile = nil
if (fastaFile =~ /^(.*)\.fa/) then
   tagsFile = "#{$1}.tags.txt"
else 
   $stderr.print "make sure the fasta file name ends in .fa\n"
   exit(1)
end

f=File.open(fastaFile, "r")
g=File.open(tagsFile,"w")
f.each {|l| 
  if (l=~ />\s*(\d+)\s*$/) then
    g.print $1; g.print "\t" 
  else  
    g.print l
  end 
} 
g.close
f.close

trimmedSequencesFastaFile = "#{tagsFile}.adapter.fa"
trimCommand = "trimSmallRNAreads.rb -t #{tagsFile} -o #{trimmedSequencesFastaFile}  -c 10 > #{File.dirname(fastaFile)}/log.#{File.basename(trimmedSequencesFastaFile)} 2>&1"
$stderr.puts "trimming sequences : executing #{trimCommand}"
system(trimCommand)
# generate .seq and .off files
buildFastaIndexCommand = "buildFastaIndex.rb -r #{trimmedSequencesFastaFile} -o #{trimmedSequencesFastaFile}.off -s #{trimmedSequencesFastaFile}.seq"
$stderr.puts "buildFastaIndex command :#{buildFastaIndexCommand}"
system(buildFastaIndexCommand)
# submitPash mapping job

pashSubmitCommand = "for f in #{genomeDir}/*10parts*.fof; do echo $f; gen-pash-jobs-align.pl -submit -v #{trimmedSequencesFastaFile} -h $f -J #{jobName}.adapter.d36.k11.n11.s25.G2.O64k.P0.01-100k`basename $f`  -G 2 -tasks 1  -d 36 -f 0 -l 35 -k 11 -n 11 -s 25 -scratch /scratch/#{jobName}.#{Process.pid}  -ignore #{ignoreList} -diagBatch 2 -P 0.01 -cutoffMappings 100000 -readOffset #{trimmedSequencesFastaFile}.off -readSequence #{trimmedSequencesFastaFile}.seq -genomeOffset $f.off -genomeSequence $f.seq -binSize 64000 ; done"
#pashSubmitCommand = "for f in #{genomeDir}/chr*.fa; do echo $f; gen-pash-jobs-align.pl -submit -v #{trimmedSequencesFastaFile} -h $f -J #{jobName}.adapter.d36.k11.n11.s25.G2.O64k.P0.01-100k`basename $f`  -G 2 -tasks 1  -d 36 -f 0 -l 35 -k 11 -n 11 -s 25 -scratch /scratch/#{jobName}.#{Process.pid}  -ignore #{ignoreList} -diagBatch 2 -P 0.01 -cutoffMappings 100000 -readOffset #{trimmedSequencesFastaFile}.off -readSequence #{trimmedSequencesFastaFile}.seq -genomeOffset $f.off -genomeSequence $f.seq -binSize 64000 ; done"
#pashSubmitCommand = "for f in #{genomeDir}/*part*.fof; do echo $f; gen-pash-jobs-align.pl -submit -v #{trimmedSequencesFastaFile} -h $f -J #{jobName}.adapter.d36.k11.n11.s25.G2.O64k.P0.01-100k`basename $f`  -G 2 -tasks 1  -d 36 -f 0 -l 35 -k 11 -n 11 -s 25 -scratch /scratch/#{jobName}.#{Process.pid}  -ignore #{ignoreList} -diagBatch 2 -P 0.01 -cutoffMappings 100000 -readOffset #{trimmedSequencesFastaFile}.off -readSequence #{trimmedSequencesFastaFile}.seq -genomeOffset $f.off -genomeSequence $f.seq -binSize 64000 ; done"
$stderr.puts "pashSubmitCommand: #{pashSubmitCommand}"
system(pashSubmitCommand)
