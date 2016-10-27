#!/usr/bin/env ruby

=begin
=end
# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/lsf/lsfBatchJob'

module BRL ; module CAPSS

class PhrapLauncher
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	REG_QUEUE = 'linux'
	SHORT_QUEUE = 'rh62_short'
	# Retrieval command (base'clpprl-'
	PHRAP = '/home/hgsc/bin/phrap-19990329.manyreads '
	JOB_NAME_BASE = 'clpd-'
	BLANK_RE = /^\s*$/
	PHRAP_OPTS = ' -ace -forcelevel 10 '
	MANY_RECS = 1000
	SOME_JOBS = 100
	MANY_JOBS = 1000
	SHORT_PAUSE = 60
	LONG_PAUSE = 120
	GREP_C_RE = /^(\d+)/

	def initialize()
	end

	def run()
		@params = processArguments()
		@fastaIDs = {}
		findDirs()
		phrapDirs()
		return
	end

	def findDirs()
		@dirs = Dir.glob("#{@topDir}/#{@dirPattern}")
		return
	end

	def	phrapDirs()
		origDir = Dir.pwd()
		jobCount = 0
		@dirs.each { |pDir|
			jobCount += 1
			lsfMsgDir = File.expand_path("#{pDir}/lsfMsgs")
			jobName = "#{JOB_NAME_BASE}-#{jobCount}"
			Dir.safeMkdir(lsfMsgDir)
			Dir.chdir(pDir)
			unless(File.exists?(@fastaFileName) and File.exists?(@fastaFileName+'.qual'))
				$stderr.puts "WARNING: missing either or both of sequence and qual files in #{pDir}"
			end
			cmdStr = "'#{PHRAP} #{@fastaFileName} #{@phrapOptsStr} \> phrap.out 2\> phrap.err'"
			lsf = BRL::LSF::LSFBatchJob.new(jobName)
			lsf.errorFile = "#{lsfMsgDir}/#{jobName}.err"
			lsf.outputFile = "#{lsfMsgDir}/#{jobName}.out"
			File.delete(lsf.errorFile) if(File.exists?(lsf.errorFile))
			File.delete(lsf.outputFile) if(File.exists?(lsf.outputFile))
			# How many fasta records?
			numRecStr = `grep -c ">" #{@fastaFileName}`
			if(numRecStr =~ GREP_C_RE)
				numRecs = $1.to_i
			else
				$stderr.puts "WARNING: tried to count number of records in fasta file to phrap using grep.\nGrep output: '#{numRecStr}' rather than the count. Why? Skipping...."
			end
			@queue = numRecs > MANY_RECS ? REG_QUEUE : SHORT_QUEUE
			lsf.queueName = @queue
			lsf.commandStrToRun = cmdStr
			if(jobCount % SOME_JOBS == 0)
				sleep(SHORT_PAUSE)
			elsif(jobCount % MANY_JOBS == 0)
				sleep(LONG_PAUSE)
			end
			lsf.submit()
			$stderr.puts lsf.bsubMsg
			Dir.chdir(origDir)
		}
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--topDir', '-t', GetoptLong::REQUIRED_ARGUMENT],
									['--dirPattern', '-d', GetoptLong::REQUIRED_ARGUMENT],
									['--fastaFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
									['--phrapOptString', '-p', GetoptLong::OPTIONAL_ARGUMENT],
									['--verbose', '-v', GetoptLong::OPTIONAL_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		PROP_KEYS.each {
			|propName|
			argPropName = "--#{propName}"
			optsArray << [argPropName, GetoptLong::OPTIONAL_ARGUMENT]
		}
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		usage() if(optsHash.empty? or optsHash.key?('--help'))
		@verbose = optsHash.key?('--verbose') ? true : false
		@topDir = optsHash['--topDir']
		@dirPattern = optsHash['--dirPattern']
		@fastaFileName = optsHash['--fastaFile']
		@phrapOptsStr = optsHash.key?('--phrapOptString') ? optsHash['--phrapOptString'] : PHRAP_OPTS
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -t     => Location of dir with sub-dirs to run phrap within.
    -d     => File pattern matching the sub-dirs to process.
    -f     => File within the sub-dirs containing fasta sequences to phrap.
    -p     => [optional, '-ace -forcelevel 10'] Phrap options string to use.
    -u     => [optional] LSF cluster to use. Default is 'short'.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-launch-phrapDirs.rb -t ./betterGraph_BINS -d ../*bin -f bin.reads
";
		exit(134);
	end
end

end ; end

launcher = BRL::CAPSS::PhrapLauncher.new()
launcher.run()
exit(0)
