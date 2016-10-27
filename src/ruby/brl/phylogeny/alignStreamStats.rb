require 'brl/util/textFileUtil'
require 'brl/util/util'


unless (ARGV.empty?)
	if(ARGV.include?"-h")
		puts "The following commands are available to AlignStreamStats:\n\n"
		puts "-h     This help message.\n"
		puts "-f     Align Stream file to analyze.\n"
		puts "-o     Output file.\n"
		puts "-a     Annotation file. [OPTIONAL]\n"
		#puts "-t     Phylogenetic tree. [OPTIONAL]\n"
	elsif((ARGV.include?"-f") || (ARGV.include?"-o"))
		switch = ARGV.index("-f")
		file = ARGV.at(switch + 1)
		
		switch = ARGV.index("-o")
		output = ARGV.at(switch + 1)
		
		#switch = ARGV.index("-t")
		#tree = ARGV.at(switch + 1)
		
		if(ARGV.include?("-a"))
			switch = ARGV.index("-a")
			annotationFile = ARGV.at(switch + 1)
		else
			annotationFile = ""
		end
	else
		raise "\nIncorrect argument to AlignStreamStats.\n"
	end
end

#----Read in and process annotation file

reader = BRL::Util::TextReader.new(annotationFile)

defLine = ""
referenceSequenceIdentifier = ""
sequenceStartPosition = 0
hashAnnotations = Hash.new
lastExonStop = 0

reader.each do
	|line|
	
	line.chomp!
	
	if (defLine =~ /^>referenceSequenceIdentifier/)
		
		referenceSequenceIdentifier = line
		
		defLine = ""
	elsif (defLine =~ /^>sequenceStartPosition/)
		
		sequenceStartPosition = line.to_i
		
		defLine = ""
		
	elsif (line =~ /^>/)
		
		defLine = line
		
	else
		if(line.include?(","))
		
			arrPositions = line.split(",")
			
			hashPositions = Hash.new
			
			arrPositions.each do
				| position |
				
				hashPositions[position.to_i] = ""
			end
			
			hashAnnotations[defLine] = hashPositions
			
			if (defLine == ">exonStop")
				lastExonStop = arrPositions[arrPositions.length - 1].to_i
			end
		else
			hashPositions = Hash.new
			
			hashPositions[line.to_i] = ""
			
			hashAnnotations[defLine] = hashPositions
			
			if (defLine == ">exonStop")
				lastExonStop = line.to_i
			end
		end
	end
end

#Parse tree

#arrTree = tree.scan(/./)
#boParentheis = 0
#organism = ""
#
#
#
#arrTree.each do
#	| char |
#	
#	if (char == "(")
#	 	boParenthesis = 1
#	elsif (char == ")")
#		boParenthesis = 0
#	elsif ((boParenthesis == 1) && (char != " "))
#		organism << char
#	elsif ((boParenthesis == 1) && (char == " "))
#		
#	end
#	
#	
#
#end
#
#while (treestr[i]!='(') { i++; } i++;
#
#  while ((treestr[i] != ')') && (treestr[i] != '\0')) {
#    //    printf("%d: %s\n", *depth, treestr+i);
#
#
#    if (treestr[i]=='(') {
#      i += treeToRPN(treestr+i, stack, depth);
#    }
#    else if (isalnum(treestr[i])) {
#      k = 0;
#      // push alignment
#      while((!isspace(treestr[i])) && (treestr[i]!='(') && (treestr[i]!=')')) {
#        buffer[k++] = treestr[i++];
#      }
#      buffer[k] = 0;
#      stack[(*depth)++]=findAlignByName(simaligns, buffer);
#      //      printf("pushed: %s\n", stack[*depth-1]->seqs[0]->name);
#    }
#    else if (treestr[i]==')')
#      // (*depth)++;
#      break;
#    else { i++; }
#
#  }
#
#  if (treestr[i]==')') {
#    (*depth)++; //null is '+'
#    return i+1;
#  }
# if (treestr[i] == '\0') {
#   fprintf(stderr, "ERROR parsing tree, depth %d, %d chars read", *depth, i);
#   exit(1);
# }   

#---Read in and process align stream file

reader = BRL::Util::TextReader.new(file)

hashComparisons = Hash.new
arrSequences = Array.new

strand = ""

boUpstream = 1
boExon = 0
bo5UTR = 0
boCdsStart = 0
boCdsStop = 0
boCds = 0
bo3UTR = 0
boIntron = 0
boDownstream = 0

boDeflines = 0

reader.each do
	|line|
	#puts genomePosition
	line.chomp!
	
	if (line =~ /^>/)
	
		# Sequence deflines
		if (boDeflines == 0)
			
			arrSequences.push(line)
			
			#Find Strand
			arrSplit = line.split("|")
			
			currentStrand = arrSplit.last.gsub("_aligned","")
			
			if ((strand == currentStrand) || (strand == ""))
				strand = currentStrand			
			else
				strand = "opposite"
			end
						
			if (arrSequences.length > 1)
			
				length = arrSequences.length
				targetSequence1 = arrSequences[length - 1]
				i = 0
				
				while (i <= (length - 2)) do
				
					targetSequence2 = arrSequences[i]
					
					hashData = Hash.new
				
					hashData["upstream"] = Array.new
					hashData["exons"]  = Array.new
					hashData["5UTR"] = Array.new
					hashData["cds"]  = Array.new
					hashData["3UTR"] = Array.new
					hashData["introns"] = Array.new
					hashData["downstream"] = Array.new
					
					hashComparisons["#{targetSequence1}--#{targetSequence2}"] = hashData
					
					i += 1
				end
			end
			
		#-----Turn on exon and off intron
		elsif (line =~ /^>exonStart/)
			boUpstream = 0
			boExon = 1
			boIntron = 0
			
			if (boCdsStart == 1)
				boCds = 1
			end
		#-----Turn off exon and on intron	
		elsif (line =~ /^>exonStop/)
			boExon = 0
			boIntron = 1
			
			if (boCdsStart == 1)
				boCds = 0
			end
			
			# Turn on downstream
			if (line =~ /.+\.#{lastExonStop}$/)
				boIntron = 0			
				boDownstream = 1
			end
		#-----Turn on CDS	
		elsif (line =~ /^>cdsStart/)
			boCdsStart = 1
			boCds = 1
		#-----Turn off CDS
		elsif (line =~ /^>cdsStop/)
			boCdsStop = 1
			boCds = 0
		end
		
		# 5'UTR
		if ((boExon == 1) && (boCdsStart == 0) && (boCds == 0))
			bo5UTR = 1
		elsif ((boExon == 1) && (boCdsStart == 1))
			bo5UTR = 0
		elsif ((boExon == 0) && (boCdsStart == 0))
			bo5UTR = 0
		end
		
		# 3'UTR
		if ((boExon == 1) && (boCdsStop == 1))
			bo3UTR = 1
		elsif ((boExon == 0) && (boCdsStop == 1))
			bo3UTR = 0
		end
		
	else
		boDeflines = 1
		
		# Do pairwise comparisons
		
		arrNucleotides = line.scan(/./)
				
		length = arrNucleotides.length
		index = 0
		nextIndex = 1
		i = 1
				
		arrNucleotides.each do
			| nucleotide |
			
			i = nextIndex
			
			while (i < length) do
			
				targetSequence1 = arrSequences[i]
				targetSequence2 = arrSequences[index]
				
				hashData = hashComparisons["#{targetSequence1}--#{targetSequence2}"]
				
				unless (((nucleotide == "N") || (arrNucleotides[i] == "N")) || ((nucleotide == "-") && (arrNucleotides[i] == "-")))
					#Conserved
					if ((nucleotide == arrNucleotides[i]) && (arrNucleotides[i] != "-") && (nucleotide != "-"))
					
						if (boUpstream == 1)
							hashData["upstream"].push "C"
						elsif (boExon == 1)
							hashData["exons"].push "C"
						elsif (boIntron == 1)
							hashData["introns"].push "C"
						elsif (boDownstream == 1)
							hashData["downstream"].push "C"
						end
						
						if (boCds == 1)
							hashData["cds"].push "C"
						end
						
						if (bo5UTR == 1)
							hashData["5UTR"].push "C"
						elsif (bo3UTR == 1)
							hashData["3UTR"].push "C"
						end
						
					#Gap in first sequence
					elsif ((arrNucleotides[i] == "-") && (nucleotide != "-"))
						
						if (boUpstream == 1)
							hashData["upstream"].push 1
						elsif (boExon == 1)
							hashData["exons"].push 1
						elsif (boIntron == 1)
							hashData["introns"].push 1
						elsif (boDownstream == 1)
							hashData["downstream"].push 1
						end
						
						if (boCds == 1)
							hashData["cds"].push 1
						end
						
						if (bo5UTR == 1)
							hashData["5UTR"].push 1
						elsif (bo3UTR == 1)
							hashData["3UTR"].push 1
						end
					
					#Gap in second sequence
					elsif ((nucleotide == "-") && (arrNucleotides[i] != "-"))
					
						if (boUpstream == 1)
							hashData["upstream"].push 2
						elsif (boExon == 1)
							hashData["exons"].push 2
						elsif (boIntron == 1)
							hashData["introns"].push 2
						elsif (boDownstream == 1)
							hashData["downstream"].push 2
						end
						
						if (boCds == 1)
							hashData["cds"].push 2
						end
						
						if (bo5UTR == 1)
							hashData["5UTR"].push 2
						elsif (bo3UTR == 1)
							hashData["3UTR"].push 2
						end
					
					#Diverged
					else
						if (boUpstream == 1)
							hashData["upstream"].push "D"
						elsif (boExon == 1)
							hashData["exons"].push "D"
						elsif (boIntron == 1)
							hashData["introns"].push "D"
						elsif (boDownstream == 1)
							hashData["downstream"].push"D"
						end
						
						if (boCds == 1)
							hashData["cds"].push "D"
						end
						
						if (bo5UTR == 1)
							hashData["5UTR"].push "D"
						elsif (bo3UTR == 1)
							hashData["3UTR"].push "D"
						end
					
					end
				end
				
				hashComparisons["#{targetSequence1}--#{targetSequence2}"] = hashData
			
				i += 1
			end
			
			index += 1
			nextIndex += 1
		end
	end
end


#---Upstream by range function

def upstreamByRange(number, hashData2)

	upstreamStart = @upstreamLength - number
	upstreamStop = @upstreamLength - 1
	
	upstreamRange =  hashData2["upstream"].slice(upstreamStart..upstreamStop)
	
	upstreamRangeConserved = 0
	upstreamRangeAlignedLength = 0
	upstreamRangeSequence1Gap = 0
	upstreamRangeSequence2Gap = 0
	
	unless (upstreamRange == nil)
		upstreamRange.each do
			| comparison |
			
			if (comparison == "C")
				upstreamRangeConserved += 1
				upstreamRangeAlignedLength += 1
			elsif (comparison == "D")
				upstreamRangeAlignedLength += 1
			elsif (comparison == 1)
				upstreamRangeSequence1Gap += 1
			elsif (comparison == 2)
				upstreamRangeSequence2Gap += 1
			end
		end
	
	
		upstreamRangeLength = upstreamRange.length
		#puts upstreamRangeLength
		conserved = upstreamRangeConserved/upstreamRangeAlignedLength.to_f
		sequence1GapPercent = upstreamRangeSequence1Gap/upstreamRangeLength.to_f
		sequence2GapPercent = upstreamRangeSequence2Gap/upstreamRangeLength.to_f
		overallIdentity = upstreamRangeConserved/upstreamRangeLength.to_f
			
		@writer.write "Upstream#{number}Conserved: #{conserved}\n"
		@writer.write "Upstream#{number}Sequence1Gap: #{sequence1GapPercent}\n"
		@writer.write "Upstream#{number}Sequence2Gap: #{sequence2GapPercent}\n"
		@writer.write "Upstream#{number}OverallIdentity: #{overallIdentity}\n"
	end
end

#---Downstream by range function
	
def downstreamByRange(number, hashData2)

	downstreamStart = 0
	downstreamStop = number - 1
	
	downstreamRange =  hashData2["downstream"].slice(downstreamStart..downstreamStop)
	
	downstreamRangeConserved = 0
	downstreamRangeAlignedLength = 0
	downstreamRangeSequence1Gap = 0
	downstreamRangeSequence2Gap = 0
	
	unless (downstreamRange == nil)
		downstreamRange.each do
			| comparison |
			
			if (comparison == "C")
				downstreamRangeConserved += 1
				downstreamRangeAlignedLength += 1
			elsif (comparison == "D")
				downstreamRangeAlignedLength += 1
			elsif (comparison == 1)
				downstreamRangeSequence1Gap += 1
			elsif (comparison == 2)
				downstreamRangeSequence2Gap += 1
			end
		end
		
		downstreamRangeLength = downstreamRange.length
		#puts downstreamRangeLength
		conserved = downstreamRangeConserved/downstreamRangeAlignedLength.to_f
		sequence1GapPercent = downstreamRangeSequence1Gap/downstreamRangeLength.to_f
		sequence2GapPercent = downstreamRangeSequence2Gap/downstreamRangeLength.to_f
		overallIdentity = downstreamRangeConserved/downstreamRangeLength.to_f
			
		@writer.write "Downstream#{number}Conserved: #{conserved}\n"
		@writer.write "Downstream#{number}Sequence1Gap: #{sequence1GapPercent}\n"
		@writer.write "Downstream#{number}Sequence2Gap: #{sequence2GapPercent}\n"
		@writer.write "Downstream#{number}OverallIdentity: #{overallIdentity}\n"
	end

end

#-----Write out comparison data


@writer = BRL::Util::TextWriter.new(output,"w",false)

hashComparisons.each do
	| sequences, hashData |
	
	@writer.write "#{sequences}\n"
		
	#---Cds data
	conserved = 0
	alignedLength = 0
	sequence1Gap = 0
	sequence2Gap = 0
	overallIdentity = 0
	cdsConserved = 0
	
	hashData["cds"].each do
		| comparison |
		#puts comparison
		if (comparison == "C")
			cdsConserved += 1
			alignedLength += 1
		elsif (comparison == "D")
			alignedLength += 1
		elsif (comparison == 1)
			sequence1Gap += 1
		elsif (comparison == 2)
			sequence2Gap += 1
		end
	end
	
	length = hashData["cds"].length
	
	conserved = cdsConserved/alignedLength.to_f
	sequence1GapPercent = sequence1Gap/length.to_f
	sequence2GapPercent = sequence2Gap/length.to_f
	overallIdentity = cdsConserved/length.to_f
		
	@writer.write "CDSconserved: #{conserved}\n"
	@writer.write "CDSsequence1Gap: #{sequence1GapPercent}\n"
	@writer.write "CDSsequence2Gap: #{sequence2GapPercent}\n"
	@writer.write "CDSoverallIdentity: #{overallIdentity}\n"
		
	#---Exon data
	exonConserved = 0
	exonAlignedLength = 0
	exonSequence1Gap = 0
	exonSequence2Gap = 0
	
	hashData["exons"].each do
		| comparison |
		
		if (comparison == "C")
			exonConserved += 1
			exonAlignedLength += 1
		elsif (comparison == "D")
			exonAlignedLength += 1
		elsif (comparison == 1)
			exonSequence1Gap += 1
		elsif (comparison == 2)
			exonSequence2Gap += 1
		end
	end
	
	exonLength = hashData["exons"].length
	
	conserved = exonConserved/exonAlignedLength.to_f
	sequence1GapPercent = exonSequence1Gap/exonLength.to_f
	sequence2GapPercent = exonSequence2Gap/exonLength.to_f
	overallIdentity = exonConserved/exonLength.to_f
		
	@writer.write "ExonConserved: #{conserved}\n"
	@writer.write "ExonSequence1Gap: #{sequence1GapPercent}\n"
	@writer.write "ExonSequence2Gap: #{sequence2GapPercent}\n"
	@writer.write "ExonOverallIdentity: #{overallIdentity}\n"
		
	#---Intron data
	intronConserved = 0
	intronAlignedLength = 0
	intronSequence1Gap = 0
	intronSequence2Gap = 0
	
	hashData["introns"].each do
		| comparison |
		
		if (comparison == "C")
			intronConserved += 1
			intronAlignedLength += 1
		elsif (comparison == "D")
			intronAlignedLength += 1
		elsif (comparison == 1)
			intronSequence1Gap += 1
		elsif (comparison == 2)
			intronSequence2Gap += 1
		end
	end
	
	intronLength = hashData["introns"].length
	
	conserved = intronConserved/intronAlignedLength.to_f
	sequence1GapPercent = intronSequence1Gap/intronLength.to_f
	sequence2GapPercent = intronSequence2Gap/intronLength.to_f
	overallIdentity = intronConserved/intronLength.to_f
		
	@writer.write "IntronConserved: #{conserved}\n"
	@writer.write "IntronSequence1Gap: #{sequence1GapPercent}\n"
	@writer.write "IntronSequence2Gap: #{sequence2GapPercent}\n"
	@writer.write "IntronOverallIdentity: #{overallIdentity}\n"
		
	#---Overall gene data
		
	conserved = (exonConserved + intronConserved)/(exonAlignedLength + intronAlignedLength.to_f)
	sequence1GapPercent = (exonSequence1Gap + intronSequence1Gap)/(exonLength + intronLength.to_f)
	sequence2GapPercent = (exonSequence2Gap + intronSequence2Gap)/(exonLength + intronLength.to_f)
	overallIdentity = (exonConserved + intronConserved)/(exonLength + intronLength.to_f)
		
	@writer.write "OverallGene: #{conserved}\n"
	@writer.write "OverallGeneSequence1Gap: #{sequence1GapPercent}\n"
	@writer.write "OverallGeneSequence2Gap: #{sequence2GapPercent}\n"
	@writer.write "OverallGeneOverallIdentity: #{overallIdentity}\n"
		
	#---5UTR data
	fiveUTRConserved = 0
	fiveUTRAlignedLength = 0
	fiveUTRSequence1Gap = 0
	fiveUTRSequence2Gap = 0
	
	hashData["5UTR"].each do
		| comparison |
		
		if (comparison == "C")
			fiveUTRConserved += 1
			fiveUTRAlignedLength += 1
		elsif (comparison == "D")
			fiveUTRAlignedLength += 1
		elsif (comparison == 1)
			fiveUTRSequence1Gap += 1
		elsif (comparison == 2)
			fiveUTRSequence2Gap += 1
		end
	end
	
	fiveUTRLength = hashData["5UTR"].length
	
	conserved = fiveUTRConserved/fiveUTRAlignedLength.to_f
	sequence1GapPercent = fiveUTRSequence1Gap/fiveUTRLength.to_f
	sequence2GapPercent = fiveUTRSequence2Gap/fiveUTRLength.to_f
	overallIdentity = fiveUTRConserved/fiveUTRLength.to_f
		
	if (strand == "+")
		@writer.write "5UTRConserved: #{conserved}\n"
		@writer.write "5UTRSequence1Gap: #{sequence1GapPercent}\n"
		@writer.write "5UTRSequence2Gap: #{sequence2GapPercent}\n"
		@writer.write "5UTRoverallIdentity: #{overallIdentity}\n"
	elsif (strand == "-")
		@writer.write "3UTRConserved: #{conserved}\n"
		@writer.write "3UTRSequence1Gap: #{sequence1GapPercent}\n"
		@writer.write "3UTRSequence2Gap: #{sequence2GapPercent}\n"
		@writer.write "3UTRoverallIdentity: #{overallIdentity}\n"
	end
	
	#---3UTR data
	
	threeUTRConserved = 0
	threeUTRAlignedLength = 0
	threeUTRSequence1Gap = 0
	threeUTRSequence2Gap = 0
	
	hashData["3UTR"].each do
		| comparison |
		
		if (comparison == "C")
			threeUTRConserved += 1
			threeUTRAlignedLength += 1
		elsif (comparison == "D")
			threeUTRAlignedLength += 1
		elsif (comparison == 1)
			threeUTRSequence1Gap += 1
		elsif (comparison == 2)
			threeUTRSequence2Gap += 1
		end
	end
	
	threeUTRLength = hashData["3UTR"].length
	
	conserved = threeUTRConserved/threeUTRAlignedLength.to_f
	sequence1GapPercent = threeUTRSequence1Gap/threeUTRLength.to_f
	sequence2GapPercent = threeUTRSequence2Gap/threeUTRLength.to_f
	overallIdentity = threeUTRConserved/threeUTRLength.to_f
		
	if (strand == "+")
		@writer.write "3UTRConserved: #{conserved}\n"
		@writer.write "3UTRSequence1Gap: #{sequence1GapPercent}\n"
		@writer.write "3UTRSequence2Gap: #{sequence2GapPercent}\n"
		@writer.write "3UTRoverallIdentity: #{overallIdentity}\n"
	elsif (strand == "-")
		@writer.write "5UTRConserved: #{conserved}\n"
		@writer.write "5UTRSequence1Gap: #{sequence1GapPercent}\n"
		@writer.write "5UTRSequence2Gap: #{sequence2GapPercent}\n"
		@writer.write "5UTRoverallIdentity: #{overallIdentity}\n"
	end
	
	#Overall UTR Data
	
	conserved = (fiveUTRConserved + threeUTRConserved)/(fiveUTRAlignedLength + threeUTRAlignedLength.to_f)
	sequence1GapPercent = (fiveUTRSequence1Gap + threeUTRSequence1Gap)/(fiveUTRLength + threeUTRLength.to_f)
	sequence2GapPercent = (fiveUTRSequence2Gap + threeUTRSequence2Gap)/(fiveUTRLength + threeUTRLength.to_f)
	overallIdentity = (fiveUTRConserved + threeUTRConserved)/(fiveUTRLength + threeUTRLength.to_f)
	
	@writer.write "UTRConserved: #{conserved}\n"
	@writer.write "UTRSequence1Gap: #{sequence1GapPercent}\n"
	@writer.write "UTRSequence2Gap: #{sequence2GapPercent}\n"
	@writer.write "UTRoverallIdentity: #{overallIdentity}\n"
	
	#---Upstream data
	upstreamConserved = 0
	upstreamAlignedLength = 0
	upstreamSequence1Gap = 0
	upstreamSequence2Gap = 0
	
	hashData["upstream"].each do
		| comparison |
		
		if (comparison == "C")
			upstreamConserved += 1
			upstreamAlignedLength += 1
		elsif (comparison == "D")
			upstreamAlignedLength += 1
		elsif (comparison == 1)
			upstreamSequence1Gap += 1
		elsif (comparison == 2)
			upstreamSequence2Gap += 1
		end
	end
	
	@upstreamLength = hashData["upstream"].length
	
	conserved = upstreamConserved/upstreamAlignedLength.to_f
	sequence1GapPercent = upstreamSequence1Gap/@upstreamLength.to_f
	sequence2GapPercent = upstreamSequence2Gap/@upstreamLength.to_f
	overallIdentity = upstreamConserved/@upstreamLength.to_f
		
	@writer.write "UpstreamConserved: #{conserved}\n"
	@writer.write "UpstreamSequence1Gap: #{sequence1GapPercent}\n"
	@writer.write "UpstreamSequence2Gap: #{sequence2GapPercent}\n"
	@writer.write "UpstreamOverallIdentity: #{overallIdentity}\n"

	upstreamByRange(200, hashData)
	upstreamByRange(500, hashData)
	upstreamByRange(1000, hashData)
	upstreamByRange(1500, hashData)
	upstreamByRange(2000, hashData)
	
	#---Downstream data
	downstreamConserved = 0
	downstreamAlignedLength = 0
	downstreamSequence1Gap = 0
	downstreamSequence2Gap = 0
	
	hashData["downstream"].each do
		| comparison |
		
		if (comparison == "C")
			downstreamConserved += 1
			downstreamAlignedLength += 1
		elsif (comparison == "D")
			downstreamAlignedLength += 1
		elsif (comparison == 1)
			downstreamSequence1Gap += 1
		elsif (comparison == 2)
			downstreamSequence2Gap += 1
		end
	end
	
	downstreamLength = hashData["downstream"].length
	
	conserved = downstreamConserved/downstreamAlignedLength.to_f
	sequence1GapPercent = downstreamSequence1Gap/downstreamLength.to_f
	sequence2GapPercent = downstreamSequence2Gap/downstreamLength.to_f
	overallIdentity = downstreamConserved/downstreamLength.to_f
		
	@writer.write "DownstreamConserved: #{conserved}\n"
	@writer.write "DownstreamSequence1Gap: #{sequence1GapPercent}\n"
	@writer.write "DownstreamSequence2Gap: #{sequence2GapPercent}\n"
	@writer.write "DownstreamOverallIdentity: #{overallIdentity}\n"
	
	downstreamByRange(200, hashData)
	downstreamByRange(500, hashData)
	downstreamByRange(1000, hashData)
	downstreamByRange(1500, hashData)
	downstreamByRange(2000, hashData)
end
