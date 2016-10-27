#!/usr/bin/env ruby 

require "fileutils"
require "brl/MBW/sample_class"
#require "/home/junm/microbiomeWorkbench/brlheadmicrobiome/sample_class"


def usage()
  if ARGV.size != 2 || ARGV[0] =~ /--help/
    $stderr.puts "--USAGE----------------------------"
    $stderr.print "ruby run_convert_SRAToFASTQ.rb <location of input table file> <location of output folder> \n"
    $stderr.puts "-----------------------------------"
    exit
  end
end


usage()
inputFilePath=File.expand_path(ARGV[0])
inputFile=File.open(inputFilePath,"r")
line=inputFile.gets.chop!
colnames=line.split("\t")
#curDir="/home/junm/microbiomeWorkbench/brlheadmicrobiome/"

#read in information for each sample
inputFile.each_line{ |line|
  line.chop!
  cols=line.split("\t")
  fileLocation=cols[colnames.index("fileLocation")]
  basename=File.basename(fileLocation)
  basename.gsub!(/.(sra|sff)/,"")
  outSffDir=File.expand_path(ARGV[1])+"/#{basename}/"
  fastaname="#{outSffDir}#{basename}.fasta"
  if !(File.exist?(fastaname))
     FileUtils.mkdir_p outSffDir
     puts cmdConvert="convert_SRA.rb #{fileLocation} #{outSffDir}"
     system("#{cmdConvert}")
  else 
     puts "#{fastaname} exists"
  end
}



