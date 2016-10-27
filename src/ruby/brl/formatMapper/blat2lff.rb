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
require 'brl/similarity/blatHit'
require 'brl/util/logger'
include BRL::Util

module BRL ; module FormatMapper
	FATAL, OK, OK_WITH_ERRORS, FAILED, USAGE_ERR = 1,0,10,20,16
	MAX_NUM_ERRS = 25
	MAX_EMAIL_ERRS = 25
	MAX_EMAIL_SIZE = 30_000
  RECS_PER_BLOCK = 16_000

class BlatToLff
	attr_accessor :errMsgs

	def initialize(optsHash)
		@blatFile = optsHash['--blatFile']
		@baseFileName = @blatFile.strip.gsub(/\.psl$/, '')
		@doGzip = optsHash.key?('--doGzipOutput') ? true : false
		if(optsHash.key?('--outputFile'))
			@outputFile = optsHash['--outputFile']
		else
			@outputFile = @baseFileName + (@doGzip ? '.lff.gz' : '.lff')
		end
		@wholeHitIsLFFRec = optsHash.key?('--blocksSeparate') ? false : true
		@lffClass = optsHash.key?('--class') ? optsHash['--class'] : BRL::Similarity::BlatHit::LFF_CLASS
		@lffType = optsHash.key?('--type') ? optsHash['--type'] : BRL::Similarity::BlatHit::LFF_TYPE
		@lffSubtype = optsHash.key?('--subtype') ? optsHash['--subtype'] : BRL::Similarity::BlatHit::LFF_SUBTYPE
		@recsPerBlock = optsHash.key?('--recsPerBlock') ? optsHash['--recsPerBlock'].to_i : RECS_PER_BLOCK.to_i
		@doStripFa = optsHash.key?('--stripFa') 
	end

	def convert()
    BRL::Util.setLowPriority()
		retVal = OK
		reader = BRL::Util::TextReader.new(@blatFile)
		writer = BRL::Util::TextWriter.new(@outputFile, "w+", @doGzip)
		# Track query names having hits (so can make unique names per query hit)
		seen = Hash.new{ |hh, kk| hh[kk] = 0 }
		# Process line-by-line
		@errMsgs = []
		blatHit = BRL::Similarity::BlatHit.new(nil, true)
		blatHit.lffClass = @lffClass
		blatHit.lffType = @lffType
		blatHit.lffSubType = @lffSubtype
		reader.each { |line|
		  sleep(rand() + 2.5 + rand(3)) if(reader.lineno > 0 and (reader.lineno % @recsPerBlock == 0))
			line.strip!
			# Is it a header or blank or comment line?
			next if(line =~ /^\s*$/ or line =~ /^\s*#/ or line =~ /^(?:psLayout|match|\s+match|\-+)/)
			begin
				blatHit.reinitialize(line, true)
			rescue BRL::Similarity::BlatParseError => bpe
				errMsg = "Line #{reader.lineno} doesn't look like Blat PSL fomat. You sure this a Blat hit?\n" + bpe.message
				@errMsgs << errMsg
				if(@errMsgs.size >= MAX_NUM_ERRS)
					retVal = FAILED
					break
				else
					next
				end
			end
			# Strip .fa from chr (target name) column?
		  blatHit.tName.gsub!(/\.fa(?:\.masked)?$/, '') if(@doStripFa)
			# Increment query hit count
			qCount = (seen[blatHit.qName] += 1)
			# Line must be ok, output it
			writer.print blatHit.to_lffStr(true, (qCount <= 1 ? '' : ".#{qCount}"), @wholeHitIsLFFRec)
		}
		# Close files
		reader.close()
		writer.close()
		retVal = OK_WITH_ERRORS if(retVal == OK and @errMsgs.size > 0)
		return retVal
	end

	def BlatToLff.processArguments()
		optsArray =	[	['--blatFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
									['--outputFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
									['--doGzipOutput', '-z', GetoptLong::NO_ARGUMENT],
									['--blocksSeparate', '-b', GetoptLong::NO_ARGUMENT],
									['--class', '-c', GetoptLong::OPTIONAL_ARGUMENT],
									['--type', '-t', GetoptLong::OPTIONAL_ARGUMENT],
									['--subtype', '-s', GetoptLong::OPTIONAL_ARGUMENT],
									['--recsPerBlock', '-r', GetoptLong::OPTIONAL_ARGUMENT],
									['--stripFa', '-a', GetoptLong::NO_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		BlatToLff.usage() if(optsHash.empty? or optsHash.key?('--help'))
		return optsHash
	end

	def BlatToLff.usage(msg='')
		puts "\n#{msg}\n" unless(msg.empty?)
		puts "

  PROGRAM DESCRIPTION:
    Converts a Blat PSL file to a Genboree-compliant LFF file.
    PSL headers will be ignored wherever they occur, allowing concatenation of
    many psl files into one.

    The reference sequence is assumed to be the blat target.

    Only the input file need be specified and each entire hit will be turned
    into one LFF record using defaults for class, type, subtype and output file.
    The output file can be gzipped for you, if you want.

    Alternatively, you can have each block of a hit converted separately and/or
    override the class/type/subtype and/or override the output file.

    Each blat hit will be a unique LFF hit. If a query sequence has multiple
    hits, the name column in the LFF file will be:
      queryName   for the 1st hit
      queryName.2 for the 2nd hit
      queryName.3 for the 3rd hit
      ...
      etc

    NOTE: The 'score' column in the LFF will be an alignment score calculated
          from the hit details.
          [ score= 2*matches - mismatches - gaps - 2*(gapBases-gaps) ]

    COMMAND LINE ARGUMENTS:
      -f    => Blat file to convert to LFF.
      -o    => [optional] Override the output file location.
               Default is the blatFile.lff, minus the .psl if present.
      -z    => [optional flag] Gzip the LFF output file.
               Adds .gz extension unless you are overriding the output file.
      -b    => [optional flag] Each blat block will be a separate LFF record,
               all having the same name value for the hit. *Big* output.
      -c    => [optional] Override the LFF class value to use.
               Defaults to 'Blat'.
      -t    => [optional] Override the LFF type value to use.
               Defaults to 'Blat'.
      -s    => [optional] Override the LFF subtype value to use.
               Defaults to 'Hit'.
      -r    => [optional] For scalability with other processes, the app will
               pause 4 sec after seeing *this* many more lines.
               Defaults to 16_000.
      -a    => [optional flag] Strip .fa from chr (target name) column, if
               present. Will also remove .fa.masked if present.
      -h    => [optional flag] Output this usage info and exit

    USAGE:
    blat2lff.rb  -f myBlatHits.psl
	"
		exit(BRL::FormatMapper::USAGE_ERR)
	end

end # class BlatToLff

end ; end

# ##############################################################################
# MAIN
# ##############################################################################
optsHash = BRL::FormatMapper::BlatToLff::processArguments()
converter = BRL::FormatMapper::BlatToLff.new(optsHash)
exitVal = converter.convert()
if(exitVal == BRL::FormatMapper::FAILED)
	errStr =	"ERROR: Too many errors while coverting Blat hits to LFF annotations.\n" +
	          "Please check that you really have an actual Blat output file.\n\n" +
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
	errStr =  "WARNING: some of your blat data was badly formatted and thus ignored.\n\n" +
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
