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
require 'brl/util/logger'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/LFFOperator'

module BRL ; module Genboree

class LFFIntersector < LFFOperator
	# We have these instance variables available already:
	# :loggers, :outFileName, :newTrackRec, :srcLffFiles, :lffRecords
	attr_accessor :opNameCaps

	def initialize(optsHash)
		super(optsHash)	# Get generic, required properties
		@opNameCaps =  'LFF_COMBINER'	# Override generic name with a specific one
		# Process the right-hand operands.
		@trackNames = optsHash['--tracksToCombine'].split(',')
		# The track names might be double-escaped to encode the list delimiter , and any
		# raw hex sequences (%XX) that are actually part of the track names.
		@trackNames.map!{ |xx| CGI.unescape(xx) }
		@trackNames.each { |trackName|
			unless(trackName.include?(58))
				$stderr.puts "#{Time.now()} #{@opNameCaps} ERROR - track names have colons (':') between the type and subtype.\nNew track name arg doesn't: #{trackName}."
				exit(BRL::Genboree::USAGE_ERROR)
			end
		}
	end

	def preProcess() # Required to implement this. Do any preprocessing of the data in @lffRecords, if needed.
		return
	end

	def cleanUp() # Required to implement this. Do any cleanup following operation, if needed.
		return
	end

	def applyOperation() # Required to implement this. Do the operation on the data in @lffRecords.
		# Open output file
		writer = BRL::Util::TextWriter.new(@outFileName, 'w+')
		# Loop over each chr (entrypoint)
		@lffRecords.keys.each { |ep|
			# For each annotation for the first track operand, look for any annotation
			# in any of the other tracks that 'intersects' with it. Output the annotation
			# if one is found.
			# NOTE: this is O(M*N) as written. It could be sped up if necessary by using
			# a coord-aware data structure for the annotations (currently in an array)
			# or one that ameliorates the zeroing in on the relevant coords (eg a Skip
			# List is good for that). Currently, however, terminating states are found quickly to
			# reduce the price of the M*N operations.
			# Loop over each record of the various tracks we want to combine.
			@trackNames.each { |trackName|
				next unless(@lffRecords[ep].key?(trackName))
				@lffRecords[ep][trackName].each { |rec|
					rec[TYPEID], rec[SUBTYPE] = @newTrackRec[TRACK_TYPE], @newTrackRec[TRACK_SUBTYPE]
				  rec[CLASSID] = @newTrackClass
					writer.puts rec.join("\t")
				}
			}
		}
		writer.close
		return
	end

	def LFFIntersector.processArguments()
		optsArray =	[	['--tracksToCombine', '-t', GetoptLong::REQUIRED_ARGUMENT],
									['--outputFile', '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--lffFiles', '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--newTrackName', '-n', GetoptLong::REQUIRED_ARGUMENT],
									['--newTrackClass', '-c', GetoptLong::OPTIONAL_ARGUMENT],
									['--noValidation', '-V', GetoptLong::NO_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		LFFIntersector.usage() if(optsHash.empty? or optsHash.key?('--help'))
		unless(	optsHash['--newTrackName'].include?(58))
			$stderr.puts "#{Time.now()} LLF_INTERSECTOR ERROR - track names have colons (':') between the type and subtype.\nNew track name arg doesn't: #{optsHash['--newTrackName']}."
			exit(BRL::Genboree::USAGE_ERROR)
		end
		return optsHash
	end

	def LFFIntersector.usage(msg='')
		puts "\n#{msg}\n" unless(msg.empty?)
		puts "

  PROGRAM DESCRIPTION:
    Given a list of LFF files and a list of track names, outputs an LFF file
    containing a single track that is the combination of all the listed tracks.

    Track names follow this convention, as displayed in Genboree:
       Type:SubType
    That is to say, the track Type and its Subtype are separated by a colon, to
    form the track name. This format is *required* when identifying tracks.

    The --lffFiles (or -l) option, the --otherOperandTracks (or -o) option,
    support both a single name or a comma-separated list of names. Enclosing
    in quotes is often a good practice, but shouldn't be required.

    COMMAND LINE ARGUMENTS:
      -t    => A comma separated list of track names to be combined into a
               single new track.
      -l    => A list of LFF files where annotations can be found to work on.
               Annotations with irrelevant track names will be ignored and not
               output.
      -o    => Name of output file in which to put data.
      -n    => New track name for annotations having intersection.
               Should be in form of type:subtype.
      -c    => [optional] Class for new track.
      -V    => [optional flag] Turns OFF lff record validation. For use when
               Genboree is calling this program. Saves time, in theory.
      -h    => [optional flag] Output this usage info and exit.

    USAGE:
    lffCombine.rb -t ESTs:Ut1,ESTs:others -l ./myData.lff -o myCombinedData.lff -n ESTs:wGenes
	"
		exit(BRL::Genboree::USAGE_ERROR)
	end

end # class LFFIntersector

end ; end

# ##############################################################################
# MAIN
# ##############################################################################
begin
	optsHash = BRL::Genboree::LFFIntersector::processArguments()
	$stderr.puts "\n#{Time.now()} - STARTING"
	intersector = BRL::Genboree::LFFIntersector.new(optsHash)
	exitVal = intersector.run()
	if(exitVal == BRL::Genboree::FAILED)
		$stderr.puts("#{Time.now()} #{intersector.opNameCaps} ERROR - too many errors amongst your files. Processing abandoned.")
		errStr =	"ERROR: Too many formatting errors in your file(s).\n"
	elsif(exitVal == BRL::Genboree::OK_WITH_ERRORS)
		$stderr.puts("#{Time.now()} #{intersector.opNameCaps} WARNING - some formatting errors amongst your files.")
		errStr =	"WARNING: Found some formatting errors in your file(s).\n"
	end
	if(exitVal == BRL::Genboree::FAILED or exitVal == BRL::Genboree::OK_WITH_ERRORS)
		maxPerFile = (BRL::Genboree::MAX_NUM_ERRS.to_f / intersector.loggers.size.to_f).floor
		errStr +=	"Please check that you really are using the LFF file format.\n"
		errStr += "\nHere is a sample of the formatting errors detected:\n"
		errStr += "\n"
		msgSize = errStr.size
		puts errStr
		intersector.loggers.each { |fileName, logger|
			puts "File: #{fileName}" unless(intersector.loggers.keys.size <= 1)
			msg = logger.to_s(maxPerFile)
			msgSize += msg.size
			break if(msgSize > BRL::Genboree::MAX_EMAIL_SIZE)
			print "#{msg}\n\n"
		}
	else
		$stderr.puts "\n#{Time.now()} #{intersector.opNameCaps} - SUCCESSFUL"
		puts "The Combine Track Operation was successful."
	end
rescue => err
	errTitle =  "#{Time.now()} LFF_COMBINER - FATAL ERROR: The track operation exited without processing the data, due to a fatal error.\n"
	msgTitle =  "FATAL ERROR: The track operation exited without processing the data, due to a fatal error.\n"
	errstr   =  "   The error message was: '#{err.message}'.\n"
	errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
	puts msgTitle
	$stderr.puts errTitle + errstr
	exitVal = BRL::Genboree::FATAL
end
puts ''

$stderr.puts "#{Time.now()} LFF_COMBINER - DONE (exitVal: '#{exitVal}')"
exit(exitVal)
