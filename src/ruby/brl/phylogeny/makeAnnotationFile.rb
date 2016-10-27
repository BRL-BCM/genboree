#!/usr/bin/env ruby
$VERBOSE = 1

require 'brl/util/textFileUtil'
require 'brl/util/util'


unless (ARGV.empty?)
	if(ARGV.include?"-h")
		puts "The following commands are available to makeAnnotationFile:\n\n"
		puts "-h     This help message.\n"
		puts "-f     RefFlat file containing annotations.\n"
		puts "-o     Output directory.\n"
	elsif((ARGV.include?("-f")) && (ARGV.include?("-o")))
		switch = ARGV.index("-f")
		file = ARGV.at(switch + 1)
		
		switch = ARGV.index("-o")
		output = ARGV.at(switch + 1)
	else
		raise "\nIncorrect argument to makeAnnotationFile.\n"
	end
end

reader = BRL::Util::TextReader.new(file)

reader.each do
	| line |
	
	arrSplit = line.split(/\s+/)
	
	bin = arrSplit[0]
	geneName = arrSplit[1]
	name = arrSplit[2]
	chrom = arrSplit[3]
	strand = arrSplit[4]
	txStart = arrSplit[5].to_i
	txStop = arrSplit[6].to_i
	cdsStart = arrSplit[7].to_i
	cdsStop = arrSplit[8].to_i
	exonCount = arrSplit[9]
	exonStarts = arrSplit[10]
	exonStops = arrSplit[11]
	
	start = txStart - 20000
	
	if (start < 0)
		start = 1
	end
	
	writer = BRL::Util::TextWriter.new("#{output}/#{name}.anno","w",false)
	
	writer.write(">referenceSequenceIdentifier\n")
	writer.write("hg16\n")
	writer.write(">sequenceStartPosition\n")
	writer.write("#{start}\n")
	writer.write(">exonStart\n")
	writer.write("#{exonStarts}\n")
	writer.write(">exonStop\n")
	writer.write("#{exonStops}\n")
	writer.write(">cdsStart\n")
	writer.write("#{cdsStart}\n")
	writer.write(">cdsStop\n")
	writer.write("#{cdsStop}\n")	
end
