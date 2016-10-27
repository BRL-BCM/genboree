#!/usr/bin/env ruby

def usage()
  if ARGV.size != 2 || ARGV[0] =~ /--help/
    $stderr.puts "--USAGE----------------------------"
    $stderr.print "ruby combine_RDP.rb <location of folder for RDP output> <location of folder for project output> \n"
    $stderr.puts "-----------------------------------"
    exit
  end
end



require "fileutils"
usage()
outRDPDir = ARGV[0]
outDir = ARGV[1]+"/"

`rm -rf #{outRDPDir}`
`rm -rf #{outDir}RDPreport/`

sampleFolders=`ls #{outDir}`.to_a
arr = %w(domain phylum class order family genus)
arr.each{ |tax|
  FileUtils.mkdir_p "#{outRDPDir}#{tax}"
}

sampleFolders.each { |folder|
       folder.chop!
       arr.each{ |tax|
       if (File.directory?("#{outDir}#{folder}/#{tax}/"))
         cmd = "cp #{outDir}#{folder}/#{tax}/* #{outRDPDir}#{tax}/"
         `#{cmd}` 
       end
      }
}
