#!/usr/bin/env ruby

faFile = File.open(ARGV[0], "r")
qualFile =  File.open(ARGV[1], "r")
outFile = File.open(ARGV[2], "w")

matches = 0
count = 0

faFile.each{ |line|
  faHeader = line
  seq = faFile.gets
  
  fqHeader = qualFile.gets
  qual = qualFile.gets
  qualArr = qual.split(" ")

  if faHeader == fqHeader
    seqLen = seq.length

    outFile.puts faHeader.gsub(/\>/, "@")
    outFile.puts seq
    outFile.puts "+"
  
    n = 0 
    while n < seqLen-1
      #print "#{qualArr[n]}:"
      score = qualArr[n].to_i + 33
      outFile.print score.chr
      n += 1
    end
    outFile.puts

    matches += 1
  end
  count += 1
  #break if count > 2
}

$stderr.puts "matches: #{matches}"
$stderr.puts "count: #{count}"

faFile.close()
qualFile.close()
outFile.close()
