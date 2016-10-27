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

output = "/users/hgsc/rharris1/brl/phylogeny/refSeq/alignments/human-chimp-rhesus-mouse-rat/#{chrom}/gene+20k/"

hashHumanGenes = Hash.new

reader = BRL::Util::TextReader.new("/users/hgsc/rharris1/brl/phylogeny/refSeq/orthology/#{chrom}/hg16.#{chrom}.orthologousGenes.fof")

reader.each do
	| line |
	
	line.strip!
	
	arrSplit = line.split("/")
	
	gene = arrSplit[11]
	
	hashHumanGenes[gene] = line
end

reader = BRL::Util::TextReader.new(orthologyFile)

reader.each do
	|line|
	
	arrSplit = line.split(/\s+/)
	
	humanGene = arrSplit[0]
	mouseGene = arrSplit[1]
	ratGene = arrSplit[2]
	chimpGene = arrSplit[3]
	rhesusGene = arrSplit[4]
	
	boDoAlign = 0
	boMouse = 0
	boRat = 0
	boChimp = 0
	boRhesus = 0
	mlaganFiles = ""
	primateTree = ""
	rodentTree = ""
	tree = ""
	
	if hashHumanGenes.has_key?(humanGene) 
		mlaganFiles << "#{orthologyDir}#{humanGene}/#{humanGene} "
				
		if ((mouseGene == "none") && (ratGene == "none") && (chimpGene == "none") && (rhesusGene == "none"))
			boDoAlign = 0
		end
		
		if (mouseGene != "none")
			boDoAlign = 1
			boMouse = 1	
			mlaganFiles << " #{orthologyDir}#{humanGene}/#{mouseGene}"
		end
		
		if (ratGene != "none")
			boDoAlign = 1
			boRat = 1	
			mlaganFiles << " #{orthologyDir}#{humanGene}/#{ratGene}"
		end
		
		if (chimpGene != "none")
			boDoAlign = 1
			boChimp = 1	
			mlaganFiles << " #{orthologyDir}#{humanGene}/#{chimpGene}"
		end
		
		if (rhesusGene != "none")
			boDoAlign = 1
			boRhesus = 1	
			mlaganFiles << " #{orthologyDir}#{humanGene}/#{rhesusGene}"
		end
		
		
		if ((boChimp == 1) && (boRhesus == 1))
			primateTree = "((hg16 panTro1) rm1)"
		elsif ((boChimp == 1) && (boRhesus == 0))
			primateTree = "(hg16 panTro1)"
		elsif ((boChimp == 0) && (boRhesus == 1))
			primateTree = "(hg16 rm1)"
		elsif ((boChimp == 0) && (boRhesus == 0))
			primateTree = " hg16"
		end
		
		if ((boMouse == 1) && (boRat == 1))
			rodentTree = "(mm4 rn3.1)"
		elsif ((boMouse == 1) && (boRat == 0))
			rodentTree = " mm4"
		elsif ((boMouse == 1) && (boRat == 0))
			rodentTree = " rn3.1"
		end
		
		if (rodentTree == "")
			tree = primateTree
		else
			tree = "(#{primateTree}#{rodentTree})"
		end
			
		if(boDoAlign == 1)
			#puts "#{mlaganFiles} -tree '#{tree}' -fastreject -out #{output}#{humanGene}/#{humanGene}"
			
			#writer.write("#{mlaganFiles} -tree '#{tree}' -fastreject -out #{output}#{humanGene}\n")
			
			`mlagan #{mlaganFiles} -tree '#{tree}' -fastreject -out #{output}#{humanGene}`
		end
	end
end
