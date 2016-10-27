#!/usr/bin/env ruby
# ##############################################################################
# $Copyright:$
# ##############################################################################

# Author: Andrew R Jackson (andrewj@bcm.tmc.edu)
# Date: 3/31/2004 4:38PM
# Purpose:
# Concatenates fasta records into a single record according to user
# parameters. Generates an index of locations. Needed for Pashing reads.

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/util'
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
require 'brl/dna/fastaRecord'
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

# ##############################################################################
# CONSTANTS
# ##############################################################################
MAX_REC_SIZE  = 1_000_000_000
MAX_FILE_SIZE = 1_000_000_000
MAC_REC_PER_FILE = 1
IDX_EXT = '.idx'

# Accepted program arguments
optsArray =	[
							['--faFile', '-i', GetoptLong::REQUIRED_ARGUMENT],
							['--maxRecordSize', '-r', GetoptLong::OPTIONAL_ARGUMENT],
							['--maxFileSize', '-f', GetoptLong::OPTIONAL_ARGUMENT],
							['--maxRecPerFile', '-p', GetoptLong::OPTIONAL_ARGUMENT],
							['--padToLength', '-a', GetoptLong::OPTIONAL_ARGUMENT],
							['--truncateToLength', '-t', GetoptLong::OPTIONAL_ARGUMENT],
							['--fixedPadLength', '-x', GetoptLong::OPTIONAL_ARGUMENT],
							['--help', '-h', GetoptLong::NO_ARGUMENT]
						]						
progOpts = GetoptLong.new(*optsArray)
optsHash = progOpts.to_hash
# Print usage info?
if(optsHash.empty? or optsHash.key?('--help'))
	puts "\nPROGRAM DESCRIPTION:\n"
	puts "  Concatenates fasta records into a single record according to user"
  puts "  parameters. Generates an index of locations. Needed for Pashing reads."
	puts "\nUSAGE:\n"
	puts "  faConcat.rb -i <fastaFileName>\n\n"
	puts "OPTIONAL ARGS:
  --maxRecordSize    | -r => Max length of a concatenated fasta record.
                             When exceeded a new record is started.
  --maxFileSize      | -f => Max file size for a concatenated fasta file.
                             When exceeded a new file is started.
  --maxRecPerFile    | -p => Max number of concatenated fasta records per file.
                             When exceeded a new file is started.
  --padToLength      | -a => Size to pad each *input* record to, if shorter,
                             prior to concatenating. If at least this length,
                             do nothing.
  --truncateToLength | -t => Size to trim each *input* record to, if longer,
                             prior to concatenating.
  --fixedPadLength   | -x => Number of Ns to add to each *input* record,
                             no matter what.
                             
"
	exit(134)
end

# Examine arguments
faFile = optsHash['--faFile']
maxRecordSize = optsHash.key?('--maxRecordSize') ? optsHash['--maxRecordSize'].to_i : MAX_REC_SIZE
maxFileSize = optsHash.key?('--maxFileSize') ? optsHash['--maxFileSize'].to_i : MAX_FILE_SIZE
maxRecPerFile = optsHash.key?('--maxRecPerFile') ? optsHash['--maxRecPerFile'].to_i : MAC_REC_PER_FILE

# Do concatenations
concat = BRL::DNA::FastaRecordConcatenator.new()
concat.truncateToLength = optsHash['--truncateToLength'].to_i if(optsHash.key?('--truncateToLength'))
concat.padToLength = optsHash['--padToLength'].to_i if(optsHash.key?('--padToLength'))
concat.fixedPaddingLength = optsHash['--fixedPadLength'].to_i if(optsHash.key?('--fixedPadLength'))
concat.concatenateFastaRecords(faFile, maxRecordSize, maxFileSize, maxRecPerFile)
concat.saveConcatFastaIdx(faFile + IDX_EXT)

exit(0)
