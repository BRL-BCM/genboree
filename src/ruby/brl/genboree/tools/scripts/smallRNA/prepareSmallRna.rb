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
