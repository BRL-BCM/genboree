#!/usr/bin/env ruby
$VERBOSE = 1

require 'brl/util/textFileUtil'
require 'brl/util/util'


unless (ARGV.empty?)
	if(ARGV.include?"-h")
		puts "The following commands are available to GeneSequence:\n\n"
		puts "-h     This help message.\n"
		puts "-c     Human chromosome.\n"
		puts "-f     Blat results file.\n"
	elsif( (ARGV.include?"-f"))
		switch = ARGV.index("-c")
		hsChr = ARGV.at(switch + 1)
		
		switch = ARGV.index("-f")
		blatFile = ARGV.at(switch + 1)
	else
		raise "\nIncorrect argument to GeneSequence.\n"
	end
end

blatReader = BRL::Util::TextReader.new(blatFile)

blatReader.each do
	| line |
	
	if (line =~ /^\d/)
		arrSplit = line.split(/\s+/)
		
		strand = arrSplit[8]
		query = arrSplit[9]
		chrom = arrSplit[13]
		txStart = arrSplit[15].to_i
		txStop = arrSplit[16].to_i
		
		index = chrom.index(".")
		chrom = chrom.slice(0..(index - 1))
		
		arrQuery = query.split(".")
		
		fileName = arrQuery[2]
		
		start = txStart - 20000
		stop = txStop + 20000
				
		reader = BRL::Util::TextReader.new("/users/hgsc/rharris1/brl/blastdb/Pt.GoldenPath/panTro1/linear/#{chrom}.linear.fa")

		seq = ""

		reader.each do
			|line|
	
			unless (line =~ /^>/)
				seq = line
			end
		end
		
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
			writer = BRL::Util::TextWriter.new("/users/hgsc/rharris1/brl/phylogeny/refSeq/sequence/panTro1/orthologousGenes/#{hsChr}/gene+20k/#{fileName}.pt","w",false)
			writer.write ">#{fileName}|panTro1|#{chrom}|#{start}|#{stop}|#{strand}\n"
			
			gene20k.scan(re) {
				| sequence |
				writer.write "#{sequence}\n"
			}
		else
			puts "Gene + 20k lies outside of chromosome:  #{query}\t#{start.to_s}\t#{start.to_s}"
		end
	end
end

