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
include BRL::Util;
include BRL::Genboree;

module BRL ; module Genboree

# ##############################################################################
# SuperClass for the Specific Operator classes
# ##############################################################################
class LFFOperator
	include BRL::Genboree
	TRACK_TYPE, TRACK_SUBTYPE = 0,1

	attr_accessor :loggers, :outFileName, :newTrackRec, :srcLffFiles, :lffRecords, :doValidation, :newTrackClass

	def initialize(optsHash)
		@opNameCaps = 'LFF_OPERATOR'
		@loggers = {}
		@outFileName = optsHash['--outputFile']
		@newTrackRec = optsHash['--newTrackName'].gsub(/\\,/, ',').split(':')
		@newTrackClass = optsHash.key?('--newTrackClass') ? optsHash['--newTrackClass'] : 'TrackOp'
		@doValidation = optsHash.key?('--noValidation') ? false : true
		
		unless(@newTrackRec.size == 2)
			$stderr.puts "#{Time.now()} #{@opNameCaps} ERROR - track names have colons (':') between the type and subtype.\nNew track name arg doesn't: #{optsHash['--newTrackName']}."
			exit(BRL::Genboree::USAGE_ERROR)
		end
		@srcLffFiles = optsHash['--lffFiles'].split(',')
		unless(@srcLffFiles.kind_of?(Array)) then @srcLffFiles = [ @srcLffFiles ] ; end
	end

	def run()
		$stderr.puts "#{Time.now()} #{@opNameCaps} - Start processing"
		# 1) Nice yourself
		setLowPriority()
		# 2) Read in all lff data
		@lffRecords = {}
		retVal = self.readLFF()
		$stderr.puts "#{Time.now()} #{@opNameCaps} - Loaded lff file data (read #{@lffRecords.size} records)"
		return retVal if(retVal == BRL::Genboree::FAILED)
		# 3) Sort the data
		@lffRecords = BRL::Genboree::sortLFFRecords(@lffRecords)
		$stderr.puts "#{Time.now()} #{@opNameCaps} - Sorted lff data"
		# 4) Do any preprocessing necessary
		self.preProcess()
		$stderr.puts "#{Time.now()} #{@opNameCaps} - Pre-processing of annotations done"
		# 5) Apply the operator
		self.applyOperation()
		$stderr.puts "#{Time.now()} #{@opNameCaps} - Applied operation to lff data"
		# 6) Do any cleanup
		self.cleanUp()
		$stderr.puts "#{Time.now()} #{@opNameCaps} - Clean up completed"
		return retVal
	end

	def preProcess()
		$stderr.puts "#{Time.now()} #{@opNameCaps} - WARNING - LFFOperator class detected bad code! You are required to implement the preProcess() method in your child class."
		return
	end

	# Apply the operation.
	# This should go through the data in @lffRecords and write out the output.
	def applyOperation()
		$stderr.puts "#{Time.now()} #{@opNameCaps} - WARNING - LFFOperator class detected bad code! You are required to implement the applyOperation() method in your child class."
		return
	end

	def cleanUp()
		$stderr.puts "#{Time.now()} #{@opNameCaps} - WARNING - LFFOperator class detected bad code! You are required to implement the cleanUp() method in your child class."
		return
	end

	def readLFF()
		@srcLffFiles.each { |fileName|
			@loggers[fileName] = BRL::Util::Logger.new()
			lffRecordsForFile = BRL::Genboree::readLFFRecords(fileName, @loggers[fileName], @doValidation)
			# Did we halt due to errors?
			if(@loggers[fileName].size > BRL::Genboree::MAX_NUM_ERRS)
				$stderr.puts("#{Time.now()} #{@opNameCaps} ERROR - the following file has too many (#{MAX_NUM_ERRS}+) formatting errors:\n\t'#{fileName}'\n. All processing abandoned.")
				break
			elsif(@loggers[fileName].size > 0)
				$stderr.puts("#{Time.now()} #{@opNameCaps} WARNING - the following file has some (#{MAX_NUM_ERRS}+) formatting errors:\n\t'#{fileName}'\n. Will *try* to proceed.")
				next
			end
			# Suck the data into a global structure.
			#   keyed by entrypoint, then by track name
			lffRecordsForFile.keys.each { |ep|
				@lffRecords[ep] = {} unless(@lffRecords.key?(ep))
				lffRecordsForFile[ep].keys.each { |tn|
					@lffRecords[ep][tn] = [] unless(@lffRecords[ep].key?(tn))
					@lffRecords[ep][tn] += lffRecordsForFile[ep][tn]
				}
			}
		}
		# Did we have too many errors overall?
		numErrors = 0
		@loggers.each { |fileName, logger| numErrors += logger.size }
		if(numErrors > BRL::Genboree::MAX_NUM_ERRS)
			return BRL::Genboree::FAILED
		elsif(numErrors > 0)
			return BRL::Genboree::OK_WITH_ERRORS
		else
			return BRL::Genboree::OK
		end
	end
end # class LFFOperator

end ; end
