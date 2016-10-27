#!/usr/bin/env ruby
$VERBOSE = 1

require 'brl/util/textFileUtil'
require 'brl/util/util'


unless (ARGV.empty?)
	if(ARGV.include?"-h")
		puts "The following commands are available to GeneSequence:\n\n"
		puts "-h     This help message.\n"
		puts "-g     Genomes from which to extract sequence.\n"
		puts "-c     Chromosome from which to extract sequence."
	elsif((ARGV.include?"-g") || (ARGV.include?"-c"))
		switch = ARGV.index("-g")
		genome = ARGV.at(switch + 1)
		
		switch = ARGV.index("-c")
		chr = ARGV.at(switch + 1)
	else
		raise "\nIncorrect argument to GeneSequence.\n"
	end
end



#reader = BRL::Util::TextReader.new("/users/hgsc/rharris1/brl/blastdb/Hs.GoldenPath/#{genome}/linear/#{chr}.linear.fa")
reader = BRL::Util::TextReader.new("/users/hgsc/rharris1/brl/phylogeny/refSeq/sequence/#{genome}/refSeq/#{chr}/#{chr}.linear")

seq = ""

reader.each do
	|line|
	
	unless (line =~ /^>/)
		seq = line
	end
end

reader = BRL::Util::TextReader.new("/users/hgsc/rharris1/brl/phylogeny/refSeq/sequence/#{genome}/orthologousGenes/#{chr}/genes.unique.psl")

reader.each do
	| line |
	
	arrSplit = line.split(/\s+/)
	
	strand = arrSplit[8]
	query = arrSplit[9]
	chrom = arrSplit[13]
	txStart = arrSplit[15].to_i
	txStop = arrSplit[16].to_i
	
	index = chrom.index(".")
	chrom = chrom.slice(0..(index - 1))
	
	arrQuery = query.split("|")
	
	fileName = arrQuery[3]
	
	start = txStart - 20000
	stop = txStop + 20000
	
	if (start < 0)
		start = 1
	end
	
	if (stop > seq.length)
		stop = seq.length
	end
	
	if ((start < seq.length) && (stop <= seq.length))
		gene20k = seq.slice((start - 1)..(stop - 1))
				
		re = Regexp.compile("[a-zA-Z]{1,50}")
		
		# write gene + 20k
		writer = BRL::Util::TextWriter.new("/users/hgsc/rharris1/brl/phylogeny/refSeq/sequence/#{genome}/orthologousGenes/#{chr}/gene+20k/#{fileName}","w",false)
		writer.write ">#{query}#{genome}|#{chrom}|#{start}|#{stop}|#{strand}\n"
		
		gene20k.scan(re) {
			| sequence |
			writer.write "#{sequence}\n"
		}
	else
		puts "Gene + 20k lies outside of chromosome:  #{query}\t#{start.to_s}\t#{start.to_s}"
	end
end


