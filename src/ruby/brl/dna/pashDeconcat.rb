#!/usr/bin/env ruby
# Turn on extra warnings and such
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

# ##############################################################################
# $Copyright:$
# ##############################################################################
# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/util'					# For standard BRL extensions to built-ins
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
require 'brl/dna/fastaRecord'
# ##############################################################################
IDX_EXT = '.idx'
GENOME1_NAME, GENOME1_START, GENOME1_END,GENOME2_NAME, GENOME2_START, GENOME2_END, STRAND, SCORE = 0,1,2,3,4,5,6,7
			
optsArray =	[
							['--idxFile', '-i', GetoptLong::REQUIRED_ARGUMENT],
							['--pashFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
							['--readLen', '-l', GetoptLong::REQUIRED_ARGUMENT],
							['--help', '-h', GetoptLong::NO_ARGUMENT]
						]
						
progOpts = GetoptLong.new(*optsArray)
optsHash = progOpts.to_hash
indexFile = optsHash['--idxFile']
pashFile = optsHash['--pashFile']

# Help?
if(optsHash.empty? or optsHash.key?('--help'))
	puts "\nUSAGE:\n"
	puts "\tfaConcat.rb -i <idxFileName> -p <pashOutputFile> -l <readLength>\n\n"
	exit(134)
end

readLength = optsHash['--readLen'].to_i

# Examine input files
if(FileTest.exists?(indexFile))
	pashReader = BRL::Util::TextReader.new(indexFile)
else
	raise "\nERROR: Index File #{indexFile} does not exist.\n"
end
if(FileTest.exists?(pashFile))
	pashReader = BRL::Util::TextReader.new(pashFile)
else
	raise "\nERROR: Pash File #{pashFile} does not exist.\n"
end

# Open output file for writing
newPashFile = pashFile.chomp('.txt.gz')
pashWriter = BRL::Util::TextWriter.new(newPashFile + ".deconcat","w",false)

# Process data
concatter = BRL::DNA::FastaRecordConcatenator.new()
concatter.loadConcatFastaIdx(indexFile)
pashReader.each { |pashLine|
	# Data that doesn't change:
	arrSplit = pashLine.split(/\s+/)
	chrom = arrSplit[0]
	query = arrSplit[3]
	queryStart = arrSplit[4].to_i
	queryStop = arrSplit[5].to_i
	identities = arrSplit[7].to_i
	
	# Actual query start and stop:
	correctedStart = queryStart % readLength
	correctedStop =	queryStop % readLength
	correctedStart = readLength if(correctedStart == 0)
	correctedStop = readLength if(correctedStop == 0)
	
	# What read are we actually dealing with?
	defLine = concatter.fastaIDAt(query, queryStart, queryStop, false)
	
	# Write out actual mapping
	pashWriter.write(chrom + "\t" + arrSplit[1].to_s + "\t" + arrSplit[2].to_s + "\t" + defLine.to_s + "\t" + correctedStart.to_s + "\t" + correctedStop.to_s + "\t" + arrSplit[6].to_s + "\t" + identities.to_s + "\n")
}
pashWriter.close

exit(0)
