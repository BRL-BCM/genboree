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



reader = BRL::Util::TextReader.new("/users/hgsc/rharris1/brl/blastdb/Hs.GoldenPath/#{genome}/linear/#{chr}.linear.fa")
#reader = BRL::Util::TextReader.new("/users/hgsc/rharris1/brl/phylogeny/refSeq/sequence/#{genome}/refSeq/#{chr}/#{chr}.linear")

seq = ""

reader.each do
	|line|
	
	unless (line =~ /^>/)
		seq = line
	end
end

reader = BRL::Util::TextReader.new("/users/hgsc/rharris1/brl/phylogeny/refSeq/sequence/#{genome}/#{chr}/reflat.IncludedGenes")

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
	
	fileName = name
	
	arrExonStarts = exonStarts.split(",")
	arrExonStops = exonStops.split(",")
	
	start = txStart - 20000
	stop = txStop + 20000
	
	if (start < 0)
		start = 1
	end
	
	if (stop > seq.length)
		stop = seq.length
	end
	
	if ((start < seq.length) && (stop <= seq.length))
		gene20k = seq.slice((start - 1 )..(stop - 1))
		
		exons = ""
		cds = ""
		boCds = 0
		
		arrExonStarts.each do
			| exonStart |
						
			index = arrExonStarts.index(exonStart)
			
			exonStop = arrExonStops[index]
			
			exonStart = exonStart.to_i - 1
			exonStop = exonStop.to_i - 1
			
			exons << seq.slice(exonStart..exonStop)
			
			tempCdsStart = cdsStart - 1
			tempCdsStop = cdsStop - 1
			
			if ((tempCdsStart >= exonStart) && (tempCdsStart <= exonStop))
				cds << seq.slice(tempCdsStart..exonStop)
				boCds = 1
			elsif ((tempCdsStop >= exonStart) && (tempCdsStop <= exonStop))
				cds << seq.slice(exonStart..tempCdsStop)
				boCds = 0
			elsif (boCds == 1)
				cds << seq.slice(exonStart..exonStop)
			end
		end
		
		re = Regexp.compile("[a-zA-Z]{1,50}")
		
		# write gene + 20k
		writer = BRL::Util::TextWriter.new("/users/hgsc/rharris1/brl/phylogeny/refSeq/sequence/#{genome}/#{chr}/gene+20k/#{fileName}","w",false)
		writer.write ">#{bin}|#{geneName}|#{name}|#{genome}|#{chrom}|#{start.to_s}|#{stop.to_s}|#{strand}\n"
				
		gene20k.scan(re) {
			| line |
			writer.write "#{line}\n"
		}
		
		# write exons
		writer = BRL::Util::TextWriter.new("/users/hgsc/rharris1/brl/phylogeny/refSeq/sequence/#{genome}/#{chr}/exons/#{fileName}","w",false)
		writer.write ">#{bin}|#{geneName}|#{name}|#{genome}|#{chrom}|#{exonStarts}|#{exonStops}|#{strand}\n"
				
		exons.scan(re) {
			| line |
			writer.write "#{line}\n"
		}
		
		# write cds
		writer = BRL::Util::TextWriter.new("/users/hgsc/rharris1/brl/phylogeny/refSeq/sequence/#{genome}/#{chr}/cds/#{fileName}","w",false)
		writer.write ">#{bin}|#{geneName}|#{name}|#{genome}|#{chrom}|#{cdsStart.to_s}|#{cdsStop.to_s}|#{strand}\n"
				
		cds.scan(re) {
			| line |
			writer.write "#{line}\n"
		}
		
	else
		puts "Gene + 20k lies outside of chromosome:  #{geneName}\t#{start.to_s}\t#{start.to_s}"
	end
end


