#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'getoptlong'						# for GetoptLong class (command line option parse)
require 'brl/util/util'					# for to_hash extension of GetoptLong class
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes
require 'brl/similarity/blastHit'
require 'brl/util/logger'
include BRL::Util

module BRL ; module FormatMapper
	FATAL, OK, OK_WITH_ERRORS, FAILED, USAGE_ERR = 30,0,10,20,16
	MAX_NUM_ERRS = 150
	MAX_EMAIL_ERRS = 25
	MAX_EMAIL_SIZE = 30_000
  RECS_PER_BLOCK = 16_000

class BlastToLff
	attr_accessor :errMsgs
  
	def initialize(optsHash)
		@blastFile = optsHash['--blastFile']
		@doGzip = optsHash.key?('--doGzipOutput') ? true : false
		if(optsHash.key?('--outputFile'))
			@outputFile = optsHash['--outputFile']
		else
		  @outputFile = @blastFile + (@doGzip ? '.lff.gz' : '.lff')
		end
		@lffClass = optsHash.key?('--class') ? optsHash['--class'] : BRL::Similarity::BlastHit::LFF_CLASS
		@lffType = optsHash.key?('--type') ? optsHash['--type'] : BRL::Similarity::BlastHit::LFF_TYPE
		@lffSubtype = optsHash.key?('--subtype') ? optsHash['--subtype'] : BRL::Similarity::BlastHit::LFF_SUBTYPE
		@recsPerBlock = optsHash.key?('--recsPerBlock') ? optsHash['--recsPerBlock'] : RECS_PER_BLOCK
	end

	def convert()
    BRL::Util.setLowPriority()
		retVal = OK
		reader = BRL::Util::TextReader.new(@blastFile)
		writer = BRL::Util::TextWriter.new(@outputFile, "w+", @doGzip)
		# Track query names having hits
		seen = Hash.new{ |hh, kk| hh[kk] = 0 }
		# Process line-by-line
		@errMsgs = []
		blastHit = BRL::Similarity::BlastHit.new(nil, true)
		blastHit.lffClass = @lffClass
		blastHit.lffType = @lffType
		blastHit.lffSubType = @lffSubtype
		reader.each { |line|
		  sleep(rand() + 2.5 + rand(3)) if(reader.lineno > 0 and (reader.lineno % @recsPerBlock == 0))
			line.strip!
			# is it a header or blank or comment line?
			next if(line =~ /^\s*$/ or line =~ /^\s*#/)
			begin
				blastHit.reinitialize(line, true)
			rescue BRL::Similarity::BlastParseError => bpe
				errMsg = "Line #{reader.lineno} doesn't look like Blast tab-delimited data. You sure this a Blast hit?\n" + bpe.message
				@errMsgs << errMsg
				if(@errMsgs.size > MAX_NUM_ERRS)
					retVal = FAILED
					break
				else
					next
				end
			end
			# Increment query hit count
			qCount = (seen[blastHit.qName] += 1)
			# Line must be ok, output it
			writer.print blastHit.to_lffStr((qCount <= 1 ? '' : ".#{qCount}"))
		}
		# Close files
		reader.close()
		writer.close()
		retVal = OK_WITH_ERRORS if(retVal == OK and @errMsgs.size > 0)
		return retVal
	end

	def BlastToLff.processArguments()
		optsArray =	[	['--blastFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
									['--outputFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
									['--doGzipOutput', '-z', GetoptLong::NO_ARGUMENT],
									['--class', '-c', GetoptLong::OPTIONAL_ARGUMENT],
									['--type', '-t', GetoptLong::OPTIONAL_ARGUMENT],
									['--subtype', '-s', GetoptLong::OPTIONAL_ARGUMENT],
									['--recsPerBlock', '-r', GetoptLong::OPTIONAL_ARGUMENT],
									['--blocksSeparate', '-b', GetoptLong::OPTIONAL_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		BlastToLff.usage() if(optsHash.empty? or optsHash.key?('--help'))
		return optsHash
	end

	def BlastToLff.usage(msg='')
		puts "\n#{msg}\n" unless(msg.empty?)
		puts "

  PROGRAM DESCRIPTION:
    Converts a Blast file to a Genboree-compliant LFF file. The Blast output
    file should have been produced using the -m 8 or -m 9 option to blastall.

    The reference sequence is assumed to be the blast target.

    Only the input file need be specified and each entire hit will be turned
    into one LFF record using defaults for class, type, subtype and output file.
    The output file can be gzipped for you, if you want.

   Each blast hit will be a unique LFF hit. If a query sequence has multiple
    hits, the name column in the LFF file will be:
      queryName   for the 1st hit
      queryName.2 for the 2nd hit
      queryName.3 for the 3rd hit
      ...
      etc

    COMMAND LINE ARGUMENTS:
      -f    => Blast file to convert to LFF.
      -o    => [optional] Override the output file location.
               Default is the blastFile.lff, minus the .psl if present.
      -z    => [optional flag] Gzip the LFF output file.
               Adds .gz extension unless you are overriding the output file.
      -c    => [optional] Override the LFF class value to use.
               Defaults to 'Blast'.
      -t    => [optional] Override the LFF type value to use.
               Defaults to 'Blast'.
      -s    => [optional] Override the LFF subtype value to use.
               Defaults to 'Hit'.
      -r    => [optional] For scalability with other processes, the app will
               pause 4 sec after seeing this many more lines.
               Defaults to 16_000.
      -b    => Ignored. Compatible with blat2lff.rb.
      -h    => [optional flag] Output this usage info and exit

    USAGE:
    blast2lff.rb  -f myBlastHits.psl
	"
		exit(BRL::FormatMapper::USAGE_ERR)
	end

end # class BlastToLff

end ; end

# ##############################################################################
# MAIN
# ##############################################################################
optsHash = BRL::FormatMapper::BlastToLff::processArguments()
converter = BRL::FormatMapper::BlastToLff.new(optsHash)
exitVal = converter.convert()
if(exitVal == BRL::FormatMapper::FAILED)
	errStr =	"ERROR: Too many errors while coverting Blast hits to LFF annotations.\n" +
	          "Please check that you really have an actual tab-delimited Blast output file.\n\n" +
	          "Here is a sample of the formatting errors detected:\n" + ('-'*40) + "\n\n"
	$stderr.print errStr
	msgSize = errStr.size
	msgCount = 0
	converter.errMsgs.each { |msg|
		msgSize += msg.size
		msgCount += 1
		break if(msgSize > BRL::FormatMapper::MAX_EMAIL_SIZE or msgCount > BRL::FormatMapper::MAX_EMAIL_ERRS)
		$stderr.print "#{msg}\n\n"
	}
elsif(exitVal == BRL::FormatMapper::OK_WITH_ERRORS)
	errStr =  "WARNING: some of your blast data was badly formatted and thus ignored.\n\n" +
	          "Here is a sample of the formatting errors detected:\n" + ('-'*40) + "\n\n"
	$stderr.print errStr
	msgSize = errStr.size
	msgCount = 0
	converter.errMsgs.each { |msg|
		msgSize += msg.size
		msgCount += 1
		break if(msgSize > BRL::FormatMapper::MAX_EMAIL_SIZE or msgCount > BRL::FormatMapper::MAX_EMAIL_ERRS)
		$stderr.print "#{msg}\n\n"
	}
end

exit(exitVal)
