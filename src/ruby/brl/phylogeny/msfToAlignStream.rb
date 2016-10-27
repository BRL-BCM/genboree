#!/usr/bin/env ruby
$VERBOSE = 1

require 'brl/util/textFileUtil'
require 'brl/util/util'


unless (ARGV.empty?)
	if(ARGV.include?"-h")
		puts "The following commands are available to msfToAlignStream:\n\n"
		puts "-h     This help message.\n"
		puts "-f     MSF file to convert to AlignStream.\n"
		puts "-o     Output file.\n"
		puts "-a     Annotation file. [OPTIONAL]\n"
	elsif((ARGV.include?("-f")) && (ARGV.include?("-o")))
		switch = ARGV.index("-f")
		file = ARGV.at(switch + 1)
		
		switch = ARGV.index("-o")
		output = ARGV.at(switch + 1)
				
		if(ARGV.include?("-a"))
			switch = ARGV.index("-a")
			annotationFile = ARGV.at(switch + 1)
		else
			annotationFile = ""
		end
	else
		raise "\nIncorrect argument to msfToAlignStream.\n"
	end
end

#----Read in annotation file and create an annotation hash with the type of annotation as the key and a hash of the postions of that annotation as the value

reader = BRL::Util::TextReader.new(annotationFile)

defLine = ""
referenceSequenceIdentifier = ""
sequenceStartPosition = 0
hashAnnotations = Hash.new

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
		else
			hashPositions = Hash.new
			
			hashPositions[line.to_i] = ""
			
			hashAnnotations[defLine] = hashPositions
		end
	end
end

#----Read in msf file and make an array of record arrays.  Each record array consists of the defline [0] and sequence [1] 
reader = BRL::Util::TextReader.new(file)

defLine = ""
seqLength = 0
i = -1

arrRecords = Array.new

reader.each do
	|line|
	
	if (line =~ /^>/)
		
		defLine = line.chomp
		
		arrRecord = Array.new
		
		arrRecord.push(defLine)
		arrRecord.push("")
				
		arrRecords.push(arrRecord)
		
		i += 1
		
		#Fix for alignment not starting at 1
		if(line =~ /.+#{referenceSequenceIdentifier}.+/)
			
			if (line =~ /^>1\:\d+-/)
				offset = $&
				offset = offset.gsub(">1:", "")
				offset = offset.gsub("-", "")
				
				sequenceStartPosition = sequenceStartPosition + (offset.to_i - 1)
			end
		
		end
	else
		arrRecord = arrRecords[i]
		
		arrRecord[1] = arrRecord[1] << line
		
		arrRecords[i] = arrRecord
	end
end

#----Replace newlines in sequenece and make sequence into an array
arrRecords.each do
	| arrRecord |
	
	seq = arrRecord[1]
	
	seq.gsub!("\n","")
	
	arrSeq = seq.scan(/./)
	
	arrRecord[1] = arrSeq
	
	#  Find length of reference sequence
	if(arrRecord[0] =~ /.+#{referenceSequenceIdentifier}.+/)
		seqLength = arrSeq.length
	end
end

#----- Output Align Stream file

writer = BRL::Util::TextWriter.new(output,"w",false)

arrRecords.each do
	| arrRecord |
		
	writer.write("#{arrRecord[0]}\n")
	
end

genomePosition = sequenceStartPosition
i = 0	
	
while (i < seqLength)
	
	hashAnnotations.each do
		| annotation, hashPositions |
		
		if(hashPositions.has_key?(genomePosition))
			writer.write("#{annotation}.#{genomePosition}\n")	
		end
	end
	
	arrRecords.each do
		| arrRecord |
		
		seq = arrRecord[1]
		
		if((arrRecord[0] =~ /.+#{referenceSequenceIdentifier}.+/) && (seq[i] != "-"))
			genomePosition += 1
		end
		
		writer.write(seq[i])
	end
	
	writer.write("\n")
	
	i += 1
end

