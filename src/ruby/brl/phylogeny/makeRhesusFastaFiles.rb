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

output = "/users/hgsc/rharris1/brl/phylogeny/refSeq/sequence/rm1/orthologousGenes/#{chrom}/gene+20k/"

hashHumanGenes = Hash.new

reader = BRL::Util::TextReader.new("/users/hgsc/rharris1/brl/phylogeny/refSeq/sequence/hg16/#{chrom}/reflat.IncludedGenes")

reader.each do
	| line |
	
	line.strip!
	
	arrSplit = line.split(/\s+/)
	
	gene = arrSplit[2]
	bin = arrSplit[0]
	
	hashHumanGenes[bin] = gene
end

reader = BRL::Util::TextReader.new("/users/hgsc/anjunc/brl/anjunc/macaca/CSA-gene/#{chrom}/ASM3/rm1.orthologousGenes.fof")

reader.each do
	| line |
	
	line.strip!
	
	arrSplit = line.split("/")
	
	bin = arrSplit[10]
	
	bin = bin.gsub("bin","")
	
	gene = hashHumanGenes[bin]
	#puts "#{output}/#{gene}.rm"
	writer = BRL::Util::TextWriter.new("#{output}#{gene}.rm","w",false)
	
	writer.write(">#{gene}|rm1|+|")
	
	fastaReader = BRL::Util::TextReader.new(line)
	
	fastaReader.each do
		|fastaLine|
		
		if (line =~ /^>/)
			writer.write(fastaLine)
		else
			re = Regexp.compile("[a-zA-Z]{1,50}")
		
			fastaLine.scan(re) {
				| sequence |
				writer.write "#{sequence}\n"
			}
		end
	end
end
