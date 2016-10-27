#!/usr/bin/env ruby
$VERBOSE = 1

require 'brl/util/textFileUtil'
require 'brl/util/util'


unless (ARGV.empty?)
	if(ARGV.include?"-h")
		puts "The following commands are available to GeneSequence:\n\n"
		puts "-h     This help message.\n"
		puts "-f     Human genes.\n"
		puts "-m     Human-mouse orthology file.\n"
		puts "-r     Human-rat orthology file.\n"
		puts "-n     Mouse file of files.\n"
		puts "-s     Rat file of files."
	elsif((ARGV.include?"-f") || (ARGV.include?"-m"))
		switch = ARGV.index("-f")
		humanGeneFile = ARGV.at(switch + 1)
		
		switch = ARGV.index("-m")
		mmhsOrthologyFile = ARGV.at(switch + 1)
		
		switch = ARGV.index("-r")
		rnhsOrthologyFile = ARGV.at(switch + 1)
		
		switch = ARGV.index("-n")
		mmFof = ARGV.at(switch + 1)
		
		switch = ARGV.index("-s")
		rnFof = ARGV.at(switch + 1)
	else
		raise "\nIncorrect argument to GeneSequence.\n"
	end
end

reader = BRL::Util::TextReader.new(humanGeneFile)

hashHumanGenes = Hash.new

reader.each do
	|line|
	
	line.strip!
	
	arrOrthologs = Array.new
	
	hashHumanGenes[line] = arrOrthologs
end

reader = BRL::Util::TextReader.new(mmFof)

hashMouseGenes = Hash.new

reader.each do
	|line|
	
	line.strip!
	
	arrSplit = line.split("/")
	
	gene = arrSplit[12]
	
	hashMouseGenes[gene] = ""
end

reader = BRL::Util::TextReader.new(rnFof)

hashRatGenes = Hash.new

reader.each do
	|line|
	
	line.strip!
	
	arrSplit = line.split("/")
	
	gene = arrSplit[12]
	
	hashRatGenes[gene] = ""
end

reader = BRL::Util::TextReader.new(mmhsOrthologyFile)

reader.each do
	| line |
	
	arrSplit = line.split("|")
		
	humanGene = arrSplit[5]
	index = humanGene.index(".")
	humanGene = humanGene.slice(0..(index - 1))
	
	ortholog = arrSplit[8]

	if((hashHumanGenes.has_key?(humanGene)) && (hashMouseGenes.has_key?(ortholog)))
		arrOrthologs = hashHumanGenes[humanGene]
	
		arrOrthologs.push(ortholog)
	end
	
end

reader = BRL::Util::TextReader.new(rnhsOrthologyFile)

reader.each do
	| line |
	
	arrSplit = line.split("|")
		
	humanGene = arrSplit[5]
	index = humanGene.index(".")
	humanGene = humanGene.slice(0..(index - 1))
	#puts humanGene
	ortholog = arrSplit[8]

	if((hashHumanGenes.has_key?(humanGene)) && (hashRatGenes.has_key?(ortholog)))
		arrOrthologs = hashHumanGenes[humanGene]
	
		if(arrOrthologs.length == 0)
			arrOrthologs.push("none")
			arrOrthologs.push(ortholog)
		else
			arrOrthologs.push(ortholog)
		end
	
	end
	
end

hashHumanGenes.each do
	| humanGene, arrOrthologs |
	
	if(arrOrthologs.length == 0)
		arrOrthologs.push("none")
		arrOrthologs.push("none")
	elsif(arrOrthologs.length == 1)
		arrOrthologs.push("none")
	end
		
	orthoString = arrOrthologs.join("\t")
	
	puts "#{humanGene}\t#{orthoString}"
end
