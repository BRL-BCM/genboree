#!/usr/bin/env ruby
$VERBOSE = 1

require 'brl/util/textFileUtil'
require 'brl/util/util'


unless (ARGV.empty?)
	if(ARGV.include?"-h")
		puts "The following commands are available to makeRhesusFastaFiles:\n\n"
		puts "-h     This help message.\n"
		puts "-c     Chromosome.\n"
	elsif((ARGV.include?"-c"))
		switch = ARGV.index("-c")
		chrom = ARGV.at(switch + 1)
	else
		raise "\nIncorrect argument to makeRhesusFastaFiles.\n"
	end
end

rhesusFof = "/users/hgsc/rharris1/brl/phylogeny/refSeq/sequence/rm1/orthologousGenes/#{chrom}/rm1.fof"
chimpFof = "/users/hgsc/rharris1/brl/phylogeny/refSeq/sequence/panTro1/orthologousGenes/#{chrom}/panTro1.fof"
orthologyFile = "/users/hgsc/rharris1/brl/phylogeny/refSeq/orthology/#{chrom}/human-mouse-rat.orthologies"

output = "/users/hgsc/rharris1/brl/phylogeny/refSeq/orthology/#{chrom}/gene+20k/"

hashHumanGenes = Hash.new

reader = BRL::Util::TextReader.new(orthologyFile)

reader.each do
	| line |
	
	line.strip!
	
	arrSplit = line.split(/\s+/)
	
	gene = arrSplit[0]
	
	hashHumanGenes[gene] = line
end

hashChimpGenes = Hash.new

reader = BRL::Util::TextReader.new(chimpFof)

reader.each do
	| line |
	
	line.strip!
		
	arrSplit = line.split("/")
		
	unless (arrSplit[12] == nil)
		chimpGene = arrSplit[12]
			
		humanGene = chimpGene.gsub(".pt","")
		
		hashChimpGenes[humanGene] = chimpGene
		
		File.symlink(line, "#{output}#{humanGene}/#{chimpGene}")
	end
	
end

hashRhesusGenes = Hash.new

reader = BRL::Util::TextReader.new(rhesusFof)

reader.each do
	| line |
	
	line.strip!
		
	arrSplit = line.split("/")
		
	unless (arrSplit[12] == nil)
		rhesusGene = arrSplit[12]
		#puts rhesusGene	
		humanGene = rhesusGene.gsub(".rm","")
		
		hashRhesusGenes[humanGene] = rhesusGene
	
		File.symlink(line, "#{output}#{humanGene}/#{rhesusGene}")
	end
	
end

writer = BRL::Util::TextWriter.new("/users/hgsc/rharris1/brl/phylogeny/refSeq/orthology/#{chrom}/human-mouse-rat-chimp-rhesus.orthologies","w",false)

hashHumanGenes.each do
	| humanGene, orthologies |
	
	if hashChimpGenes.has_key?(humanGene)
		chimpGene = hashChimpGenes[humanGene]
	else
		chimpGene = "none"
	end
	
	if hashRhesusGenes.has_key?(humanGene)
		rhesusGene = hashRhesusGenes[humanGene]
	else
		rhesusGene = "none"
	end
	
	writer.write ("#{orthologies}\t#{chimpGene}\t#{rhesusGene}\n")
end
