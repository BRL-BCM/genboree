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

orthologyDir = "/users/hgsc/rharris1/brl/phylogeny/refSeq/orthology/#{chrom}/gene+20k/"

output = "/users/hgsc/rharris1/brl/phylogeny/refSeq/alignments/human-mouse-rat/#{chrom}/gene+20k/"

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
	
	boDoAlign = 0
	boMouse = 0
	boRat = 0
	mlaganFiles = ""
	tree = ""
	
	if hashHumanGenes.has_key?(humanGene) 
		mlaganFiles << "#{orthologyDir}#{humanGene}/#{humanGene} "
				
		if ((mouseGene == "none") && (ratGene == "none"))
			boDoAlign = 0
		elsif (mouseGene == "none")
			if hashRatGenes.has_key?(ratGene)
				boDoAlign = 1
				
				mlaganFiles << "#{orthologyDir}#{humanGene}/#{ratGene}"
				
				tree = "(hg16 rn3.1)"
			end
		elsif (ratGene == "none")
			if hashMouseGenes.has_key?(mouseGene)
				boDoAlign = 1
				
				mlaganFiles << "#{orthologyDir}#{humanGene}/#{mouseGene}"
				
				tree = "(hg16 mm4)"
			end
		else
			if hashMouseGenes.has_key?(mouseGene)
				boDoAlign = 1
				boMouse = 1
				
				mlaganFiles << "#{orthologyDir}#{humanGene}/#{mouseGene} "
				
				tree = "(hg16 mm4)"
			end
			
			if hashRatGenes.has_key?(ratGene)
				boDoAlign = 1
				boRat = 1
				
				mlaganFiles << "#{orthologyDir}#{humanGene}/#{ratGene}"
				
				tree = "(hg16 mm4)"
			end
			
			if((boMouse == 1) && (boRat == 1))
				tree = "(hg16 (mm4 rn3.1))"
			elsif(boMouse == 1)
				tree = "(hg16 mm4)"
			elsif(boRat == 1)
				tree = "(hg16 rn3.1)"
			end
		end
		
		if(boDoAlign == 1)
			#puts "#{mlaganFiles} -tree '#{tree}' -fastreject -out #{output}#{humanGene}/#{humanGene}"
			
			#writer.write("#{mlaganFiles} -tree '#{tree}' -fastreject -out #{output}#{humanGene}\n")
			
			`mlagan #{mlaganFiles} -tree '#{tree}' -fastreject -out #{output}#{humanGene}`
		end
	end
end
