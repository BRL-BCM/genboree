#!/usr/bin/env ruby

require 'brl/util/util'
require 'brl/util/textFileUtil'


r = BRL::Util::TextReader.new(ARGV[0])
w = BRL::Util::TextWriter.new(ARGV[1])
w.puts "Chrom 1\tChrom 1 start\tChrom 1 stop\tChrom1 Strand\tChrom 2\tChrom 2 start\tChrom 2 stop\tChrom2 strand\tCoverage\tType"

l = nil

while 1
  l1 = r.gets
  l2 = r.gets
  break if (l1.nil? || l2.nil?)
  f1=l1.split(/\t/)
  f2=l2.split(/\t/)
  if (f1[1]!=f2[1]) then
    $stderr.puts "yikes ! #{l1} #{l2}"
    exit(2)
  end
  l1 =~/ount=(\d+)/
  count=$1
  l1 =~/ype=([^;]+)/
  mtype =$1
  w.puts "#{f1[4]}\t#{f1[5]}\t#{f1[6]}\t#{f1[7]}\t#{f2[4]}\t#{f2[5]}\t#{f2[6]}\t#{f2[7]}\t#{count}\t#{mtype}"
end

r.close()
w.close()
