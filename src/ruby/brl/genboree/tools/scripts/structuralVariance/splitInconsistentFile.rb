#!/usr/bin/env ruby

inconsistentFilesRoot = ARGV[0]
startChrom = ARGV[1].to_i
stopChrom = ARGV[2].to_i
splitFilesRoot = ARGV[3]
startChrom.upto(stopChrom) { |chrom|
  splitCommand = "cat #{inconsistentFilesRoot}* | grep -P  \"^#{startChrom}\\s\\S+\\s\\S+\\s\\S+\\s#{chrom}\\s\" > #{splitFilesRoot}.#{startChrom}-#{chrom}" 
  $stderr.puts "split command : #{splitCommand}"
  system(splitCommand)
}

