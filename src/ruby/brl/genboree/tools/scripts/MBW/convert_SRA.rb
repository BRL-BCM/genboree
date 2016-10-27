#!/usr/bin/env ruby
#  Convert SRA/SFF file to fasta/fastq files
#   input: 1) The location of  input SRA or SFF file
#          2) The directory of output folder for FASTA and FASTQ files.
#   output: 1) FASTA file for each SRA or SFF file.
#            2) FASTQ file for each SRA or SFF file. 

require 'fileutils'

def usage()
  if ARGV.size != 2 || ARGV[0] =~ /--help/
    $stderr.puts "--USAGE----------------------------"
    $stderr.print "ruby convert_SRA.rb <the location of input SRA and SFF file>"
    $stderr.print " <output folder directory> \n"
    $stderr.puts "-----------------------------------"
    exit
  end
end

#print usage if we do not have exactly 5 cmd line arguments
usage()

#input folder for all sras and sffs
inputfile = File.expand_path(ARGV[0])
inDir=File.dirname(inputfile)
#output folder
outDir = File.expand_path(ARGV[1]) + "/"
FileUtils.mkdir_p outDir

#executable to convert sra into sff
sraEXE = "sff-dump"
#executable to convert sff into fasta, fasta.qual, and xml
sffEXE = "sff_extract"
#executable to convert fasta and fasta.qual into fq
fqEXE = "linear_convert-FAQUAL-FQ.rb"

file=inputfile.strip
basename=File.basename(file)
#extension to substitue (either sra or sff)
if basename =~ /\.sra/
  extSub = "sra"
elsif basename =~ /\.sff/
  extSub = "sff"
end

#create file names based on orifinal sff or sra file name
sffFile = basename.gsub(/#{extSub}/, "sff")
faFile = basename.gsub(/#{extSub}/, "fasta")
qualFile = basename.gsub(/#{extSub}/, "fasta.qual")
xmlFile = basename.gsub(/#{extSub}/, "xml")
fqFile = basename.gsub(/#{extSub}/, "fq")
sffFile="#{inDir}/#{sffFile}"
faFile="#{inDir}/#{faFile}"
qualFile="#{inDir}/#{qualFile}"
xmlFile="#{inDir}/#{xmlFile}"
fqFile="#{inDir}/#{fqFile}"


#if we have an sra file, convert it into an sff file
`#{sraEXE} #{file} -O #{inDir}`  if file =~ /\.sra/
 #convert sff file into fasta, fasta.qual, and xml files 
`#{sffEXE} #{sffFile}`
 #convert fasta and fasta.qual into fq file
`#{fqEXE} #{faFile} #{qualFile} #{fqFile}`
 #remove xml file
`rm -f #{xmlFile}`
 #remove sff file if we started with an sra file
`rm -f #{sffFile}`  if file =~ /\.sra/
 #remove quality file
`rm -f #{qualFile}`
 #move files to output folder
`mv #{faFile} #{outDir}`
`mv #{fqFile} #{outDir}`
puts "done with #{basename}"


