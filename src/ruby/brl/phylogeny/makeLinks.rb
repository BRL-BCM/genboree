#!/usr/bin/env ruby
$VERBOSE = 1

require 'brl/util/textFileUtil'
require 'brl/util/util'


unless (ARGV.empty?)
	if(ARGV.include?"-h")
		puts "The following commands are available to DoAlignments:\n\n"
		puts "-h     This help message.\n"
		puts "-c     Chromosome.\n"
		puts "-o     Orthology file.\n"
	elsif((ARGV.include?"-o") || (ARGV.include?"-c"))
		switch = ARGV.index("-c")
		chrom = ARGV.at(switch + 1)
		
		switch = ARGV.index("-o")
		orthologyFile = ARGV.at(switch + 1)
	else
		raise "\nIncorrect argument to DoAlignments.\n"
	end
end

output = "/users/hgsc/rharris1/brl/phylogeny/refSeq/orthology/#{chrom}/gene+20k/"

hashHumanGenes = Hash.new

reader = BRL::Util::TextReader.new("/users/hgsc/rharris1/brl/phylogeny/refSeq/orthology/#{chrom}/hg16.#{chrom}.orthologousGenes.fof")

reader.each do
	| line |
	
	line.strip!
	
	arrSplit = line.split("/")
	
	gene = arrSplit[11]
	
	hashHumanGenes[gene] = line
end

hashMouseGenes = Hash.new

reader = BRL::Util::TextReader.new("/users/hgsc/rharris1/brl/phylogeny/refSeq/orthology/mm4.orthologousGenes.fof")

reader.each do
	| line |
	
	line.strip!
	
	arrSplit = line.split("/")
	
	gene = arrSplit[12]
	
	hashMouseGenes[gene] = line
end

hashRatGenes = Hash.new

reader = BRL::Util::TextReader.new("/users/hgsc/rharris1/brl/phylogeny/refSeq/orthology/rn3.1.orthologousGenes.fof")

reader.each do
	| line |
	
	line.strip!
	
	arrSplit = line.split("/")
	
	gene = arrSplit[12]
	
	hashRatGenes[gene] = line
end

reader = BRL::Util::TextReader.new(orthologyFile)

reader.each do
	|line|
	
	arrSplit = line.split(/\s+/)
	
	humanGene = arrSplit[0]
	mouseGene = arrSplit[1]
	ratGene = arrSplit[2]
		
	if hashHumanGenes.has_key?(humanGene) 
		File.symlink(hashHumanGenes[humanGene], "#{output}#{humanGene}/#{humanGene}")  
				
		if ((mouseGene == "none") && (ratGene == "none"))
			boDoAlign = 0
		elsif (mouseGene == "none")
			if hashRatGenes.has_key?(ratGene)
				
				File.symlink(hashRatGenes[ratGene], "#{output}#{humanGene}/#{ratGene}")
			end
		elsif (ratGene == "none")
			if hashMouseGenes.has_key?(mouseGene)
								
				File.symlink(hashMouseGenes[mouseGene], "#{output}#{humanGene}/#{mouseGene}")
				
			end
		else
			if hashMouseGenes.has_key?(mouseGene)
								
				File.symlink(hashMouseGenes[mouseGene], "#{output}#{humanGene}/#{mouseGene}")
				
			end
			
			if hashRatGenes.has_key?(ratGene)
							
				File.symlink(hashRatGenes[ratGene], "#{output}#{humanGene}/#{ratGene}")
				
			end
		end
	end
end
