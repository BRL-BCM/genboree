#!/usr/bin/env ruby
# ##############################################################################
# $Copyright:$
# ##############################################################################

# Author: Andrew R Jackson (andrewj@bcm.tmc.edu)
# Date: 3/31/2004 4:38PM
# Purpose:
# Maps pash hit coordinates in a Pash output file back to their original
# sequence coordinates, assuming faConcat.rb was used to create a single
# concatenated fasta record from many prior to Pashing. The index file
# created by faConcat.rb is required for this.

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/util'					# For standard BRL extensions to built-ins
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
require 'brl/dna/fastaRecord'
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

# CONSTANTS
GENOME_ID1, START1, STOP1, GENOME_ID2, START2, STOP2, ORIENT, IDENTITIES, BITSCORE =
 0,1,2,3,4,5,6,7
INTS = [1,2,4,5, 7]

# Accepted program arguments
optsArray =	[
							['--pashFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
							['--idxFileV', '--Iv', GetoptLong::REQUIRED_ARGUMENT],
							['--readLenV', '--Lv', GetoptLong::REQUIRED_ARGUMENT],
							['--idxFileH', '--Ih', GetoptLong::REQUIRED_ARGUMENT],
							['--readLenH', '--Lh', GetoptLong::REQUIRED_ARGUMENT],
							['--help', '-h', GetoptLong::NO_ARGUMENT]
						]
progOpts = GetoptLong.new(*optsArray)
optsHash = progOpts.to_hash

# Print usage info?
if(optsHash.empty? or !optsHash.key?('--pashFile') or optsHash.key?('--help'))
	puts "\nPROGRAM DESCRIPTION:\n
  Maps pash hit coordinates in a Pash output file back to their original
  sequence coordinates, assuming faConcat.rb was used to create a single
  concatenated fasta record from many prior to Pashing. The index file
  created by faConcat.rb is required for this.
  
  For reads vs genome, the reads are expected to be the vertical ('-v' when
  running Pash.exe) data  set when running pash and thus the 4th, 5th, 6th
  columns in the Pash output are the hit coordinates within the read. In this
  case, only provide the index and the read length arguments.
  
  For reads vs reads in which BOTH the horizontal ('-h' when running Pash.exe)
  and vertical ('-v') data sets are concatenated reads, you must provide a
  second index file and read length argument for the horizontal reads.
  
  COMMAND-LINE ARGUMENTS:

  --pashFile         | -p    => Location of the Pash output file to process.
  --idxFileV         | --Iv  => Location of the concatenation index file. This is
                                the index for the vertical reads (4th, 5th, 6th
                                columns in Pash output file).
  --readLenV         | --Lv  => Length of 1 read. This is usually the
                                'padToLength' used for the faConcat.rb.This is
                                the read length for the vertical reads (4th, 5th,
                                6th columns in Pash output file).
  --idxFileH         | --Ih  => [optional] Location of the concatenation index
                                file for the horizontal reads (1st, 2nd, 3rd
                                columns in Pash output file), if Pashing reads vs
                                reads.
  --readLenH         | --Lh  => [optional] Length of 1 read for the horizontal
                                reads (1st, 2nd, 3rd columns in Pash output
                                file).
  --help             | -h    => [optional] Prints this help info.
                              
  " 
	puts "\nUSAGE:\n\n"
	puts "  pashDeconcat.rb -p <pashOutputFile> --Iv <idxFileName> --Lv <readLength>"
	puts "      or"
	puts "  pashDeconcat.rb -p <pashOutputFile> --Iv <idxFile> --Lv <readLen> \\\n    --Ih <otherIdxFile> --Lh <otherReadLen>\n\n"
	exit(134)
end

# Examine arguments
pashFile = optsHash['--pashFile']
if(FileTest.exist?(pashFile))
	pashReader = BRL::Util::TextReader.new(pashFile)
else
	$stderr.puts "\nERROR: Pash File '#{pashFile}' does not exist.\n"
	exit(135)
end
# Do we have info for converting the vertical data set?
if(optsHash.key?('--idxFileV') or optsHash.key?('--readLenV'))
	unless(optsHash.key?('--idxFileV') and optsHash.key?('--readLenV'))
		$stderr.puts "\nERROR: you must provide *both* an index file AND a 'read' length argument to map the Pash hit coordinates for the vertical data set back to their original locations.\n\n"
		exit(135)
	else
		indexFile1 = optsHash['--idxFileV']
		readLength1 = optsHash['--readLenV'].to_i
		doVert = true
		unless(FileTest.exists?(indexFile1))
			$stderr.puts "\nERROR: Index File #{indexFile1} does not exist.\n"
			exit(135)
		end
	end
else
	doVert = false
end
# Do we have info for converting the horizontal data set?
if(optsHash.key?('--idxFileH') or optsHash.key?('--readLenH'))
	unless(optsHash.key?('--idxFileH') and optsHash.key?('--readLenH'))
		$stderr.puts "\nERROR: you must provide *both* an index file AND a read length argument to map the Pash hit coordinated for the horizontal data set back to their original locations.\n\n"
		exit(135)
	else
		indexFile2 = optsHash['--idxFileH']
		readLength2 = optsHash['--readLenH'].to_i
		doHorz = true
		unless(FileTest.exists?(indexFile2))
			$stderr.puts "\nERROR: Index File #{indexFile2} does not exist.\n"
			exit(135)
		end
	end
else
	doHorz = false
end
unless(doHorz or doVert) # then, um, we aren't doing anything??
	$stderr.puts "\nERROR: you must provide either the --Iv and --Lv arguments, or the --Ih and --Lh arguments, or all four. Maybe you need to try the -h argument for Help?\n\n"
	exit(136)
end

# Open output file
newPashFile = pashFile.chomp('.txt.gz')
pashWriter = BRL::Util::TextWriter.new(newPashFile + '.corrected','w',false)

# Load the indices (slow, for now)
if(doVert)
	concatter1 = BRL::DNA::FastaRecordConcatenator.new()
	concatter1.loadConcatFastaIdx(indexFile1)
end
if(doHorz)
	concatter2 = BRL::DNA::FastaRecordConcatenator.new()
	concatter2.loadConcatFastaIdx(indexFile2)
end

# Process each Pash hit
pashReader.each { |pashLine|
	# For Reference, Pash Output is like this:
	#  genome1 start1 stop1 genome2 start2 stop2 orientation identities [bitscore others....]
	fields = pashLine.split(/\s+/)
	INTS.each { |intIdx| fields[intIdx] = fields[intIdx].to_i }
	if(doVert)
		# What genome2 ('query' if reads) do we have?
		fields[GENOME_ID2] = concatter1.fastaIDAt(fields[GENOME_ID2], fields[START2], fields[STOP2], false)
		# Actual start and stop of hit within genome2 record (or within the read)
		fields[START2] = fields[START2] % readLength1
		fields[STOP2] =	fields[STOP2] % readLength1
		fields[START2] = readLength1 if(fields[START2] == 0)
		fields[STOP2] = readLength1 if(fields[STOP2] == 0)
	end
	if(doHorz) # then we have reads or something, so also do this mappping for genome1
		# What genome1 ('target read' if reads) do we have?
		fields[GENOME_ID1] = concatter2.fastaIDAt(fields[GENOME_ID1], fields[START1], fields[STOP1], false)
		# Actual start and stop of hit within genome2 record (or within the read)
		fields[START1] = fields[START1] % readLength2
		fields[STOP1] =	fields[STOP1] % readLength2
		fields[START1] = readLength2 if(fields[START1] == 0)
		fields[STOP1] = readLength2 if(fields[STOP1] == 0)
	end
	# Write out actual mapping
	pashWriter.write(fields.join("\t")+"\n")
}
# Close output file
pashWriter.close

exit(0)
