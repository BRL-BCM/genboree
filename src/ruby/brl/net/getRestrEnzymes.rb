#!/usr/bin/env ruby
#
# 3 args
#
# arg0 - 3col chromosome file 
# arg1 - restriction enzyme (ie HindIII)
# arg2 - lff outfile

if (ARGV[0].nil?)

  puts "

Fetches and converts restriction enzyme sites from UCSC
genome browser.  Assumes genome build 36 (hg18)

Usage:  ruby getRestrEnzymes.rb 
Arg 1 = 3 column chromosome file
(for brl, at ~/brl/blastdb/Hs.GoldenPath/hg18/genboreeTemplate/hg18.entrypoints.3cols.lff)

Arg 2 = restriction enzyme (ie 'HindIII')

Arg 3 = output file (lff)

ruby getRestrEnzymes.rb ~/brl/blastdb/Hs.GoldenPath/hg18/genboreeTemplate/hg18.\\
entrypoints.3cols.lff HindIII HindIII.allSites.lff


"
  raise "No Arguments given"
end


infile = File.new(ARGV[0])
outfile = File.new(ARGV[2],"w")

counter = 0

infile.each_line {|line|
    if (line != "")
      line.chomp!
      data = line.split(/\t/)
      #puts "wget \"http://genome.ucsc.edu/cgi-bin/hgc?hgsid=96098004&g=cutters&l=0&r=#{data[2]}&c=#{data[0]}&doGetBed=#{ARGV[1]}\" -o #{ARGV[1]}.#{data[0]}.bed"
      `wget 'http://genome.ucsc.edu/cgi-bin/hgc?hgsid=96098004&g=cutters&l=0&r=#{data[2]}&c=#{data[0]}&doGetBed=#{ARGV[1]}' -O #{ARGV[1]}.#{data[0]}.bed`        
      infile2 = File.new("#{ARGV[1]}.#{data[0]}.bed")
    
      infile2.each_line{ |line2|
      if (!(line2=~/\</) && (line2 != ""))
        line2.chomp!
        data2 = line2.split(/\t/)
        if (!(data2[1].nil?) && !(data2[1].nil?))
          outfile.print "Enzymes\t"
          outfile.print "#{counter}\t"
          outfile.print "#{ARGV[1]}\t"
          outfile.print "Sites\t"
          outfile.print "#{data2[0]}\t"
          outfile.print "#{data2[1].to_i + 1}\t"
          outfile.print "#{data2[2]}\t"
          outfile.print ".\t"
          outfile.print ".\t"
          outfile.print "#{data2[4]}\n"
        end
        counter += 1
      end
    }
    end
  `rm #{ARGV[1]}.#{data[0]}.bed`
}

