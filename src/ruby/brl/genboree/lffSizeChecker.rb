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

$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

module BRL ; module Genboree
	OK_CODE, FAIL_CODE, USAGE_ERR, FATAL_ERR = 4,8,16,32
	BLANK_RE = /^\s*$/
	COMMENT_RE = /^\s*#/
	HEADER_RE = /^\s*\[/
	OCTOTHORP_ASCII = 35
	OPENBRACKET_ASCII = 91

class LFFSizeChecker
	attr_accessor :lffFileName, :maxNumRecs

	def initialize(optsHash)
		@lffFileName = File.expand_path(optsHash['--lffFile'])
		@maxNumRecs = optsHash['--maxNumRecs'].to_i
		return
	end

	def setLowPriority()
		begin
			Process.setpriority(Process::PRIO_USER, 0, 19)
		rescue
		end
		return
	end

	def run()
		##########################################################################
    # Set low priority (or at least try to....)
 		##########################################################################
		setLowPriority()

		numRecs = 0
		begin
			lffFile = BRL::Util::TextReader.new(@lffFileName)
			lffFile.each { |line|
				line.strip!
				next if(line =~ BLANK_RE or line[0] == OCTOTHORP_ASCII or line[0] == OPENBRACKET_ASCII)
				fields = line.split("\t")
				next if(fields.size == 3 or fields.size == 7) # Don't count references or assembly records
				numRecs += 1
				break if(numRecs > @maxNumRecs)
			}
			lffFile.close()
		rescue => err
			$stderr.puts "\n\n#{Time.now()} SIZE CHECKER - FATAL ERROR: couldn't check file. Error details:\n\n#{err.message}\n\n" + err.backtrace().join("\n") + "\n\n"
			exit(FATAL_ERR)
		end
		return (numRecs <= @maxNumRecs ? OK_CODE : FAIL_CODE)
	end

	def LFFSizeChecker.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[	['--lffFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
									['--maxNumRecs', '-m', GetoptLong::REQUIRED_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		LFFSizeChecker.usage() if(optsHash.empty? or optsHash.key?('--help'));
		return optsHash
	end

	def LFFSizeChecker.usage(msg='')
		unless(msg.empty?)
			$stderr.puts "\n#{msg}\n"
		end
		$stderr.puts "\n\nUSAGE: lffSizeChecker.rb -f <lffFile> -m <maxRecords>\n\n"
		exit(USAGE_ERR)
	end
end

end ; end

# ##############################################################################
# MAIN
# ##############################################################################
begin
	optsHash = BRL::Genboree::LFFSizeChecker::processArguments()
	$stderr.puts "#{Time.now()} SIZE CHECKER - STARTING"
	checker = BRL::Genboree::LFFSizeChecker.new(optsHash)
	exitCode = checker.run()
	if(exitCode == BRL::Genboree::FAIL_CODE)
		puts "The annotation file is too big. We don't have the CPU resources to process it in good time."
		puts "Please run the merger locally yourself, or filter some of the low-significance annotations."
		puts "Alternatively, you could split the file into chunks of no more than 1 million annotations each."
	end
rescue Exception => err
	errTitle =  "#{Time.now()} MERGER - FATAL ERROR: The size checker exited without processing the data, due to a fatal error.\n"
	msgTitle =  "FATAL ERROR: The size checker exited without processing the data, due to a fatal error.\nPlease contact the Genboree admin. This error has been dated and logged.\n"
	errstr   =  "   The error message was: '#{err.message}'.\n"
	errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
	puts msgTitle
	$stderr.puts errTitle + errstr
	exitCode = BRL::Genboree::FATAL_ERR
end

$stderr.puts "#{Time.now()} SIZE CHECKER - DONE (#{exitCode})"
exit(exitCode)
