#!/usr/bin/env ruby
$VERBOSE = 1

require 'brl/util/textFileUtil'
require 'brl/util/util'


unless (ARGV.empty?)
	if(ARGV.include?"-h")
		puts "The following commands are available to GeneSequence:\n\n"
		puts "-h     This help message.\n"
		puts "-a     File containing accession IDs.\n"
		puts "-f     Fasta file of sequences.\n"
		puts "-o     Output file.\n"
	elsif((ARGV.include?"-a") && (ARGV.include?"-f") && (ARGV.include?"-o"))
		switch = ARGV.index("-a")
		accessionFile = ARGV.at(switch + 1)
		
		switch = ARGV.index("-f")
		fastaFile = ARGV.at(switch + 1)
		
		switch = ARGV.index("-o")
		outputFile = ARGV.at(switch + 1)
	else
		raise "\nIncorrect argument to GeneSequence.\n"
	end
end

reader = BRL::Util::TextReader.new(accessionFile)

hashAccession = Hash.new

reader.each do
	|line|
	
	line.strip!
	
	hashAccession[line] = ""
end

writer = BRL::Util::TextWriter.new(outputFile,"w",false)

reader = BRL::Util::TextReader.new(fastaFile)

boWriteFasta = 0

reader.each do
	| line |
	
	if (line =~ /^>/)
		arrSplit = line.split("|")
	
		accessionID = arrSplit[3]
	
	
		if(hashAccession.has_key?(accessionID))
		
			writer.write line
			
			boWriteFasta = 1
		else
			boWriteFasta = 0		
		end
	else
		if(boWriteFasta == 1)
		
			writer.write line
			
		end
	end
end


