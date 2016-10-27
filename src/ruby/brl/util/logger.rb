#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'getoptlong'						# for GetoptLong class (command line option parse)
require 'cgi'
require 'brl/util/util'					# for to_hash extension of GetoptLong class
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes

module BRL ; module Util

class ErrorRecord
	attr_accessor :errorTitle, :messageLines

	def initialize(errorTitle, messageLines=nil)
		@errorTitle = errorTitle
		@messageLines = messageLines.nil?() ? [] : messageLines
	end

	def <<(msgLine)
		@messageLines << msgLine
		return
	end

	def to_s()
		errorStr = "#{@errorTitle}\n"
		@messageLines.each { |msg|
			errorStr += "  - #{msg}\n"
		}
		return errorStr
	end

end

class Logger
	attr_accessor :errorList, :activeError, :logFileName, :logFile, :nextToWriteIdx

	def initialize(logFileName=nil)
		@errorList = []
		@activeError = nil
		@nextToWriteIdx = 0
		@logFileName = logFileName
		@logFile = nil
	end

	def size
		return @errorList.size
	end

	def <<(errorRecord)
		@errorList << errorRecord
		@activeError = @errorList.last
	end

	def addNewError(mainMsg, msgLines=nil)
		@errorList << ErrorRecord.new(mainMsg, msgLines)
		@activeError = @errorList.last
		return
	end

	def addToActiveError(msgLine)
		@activeError << msgLine
		return
	end

	def to_s(limit=nil)
		logStr = ''
		errCount = 0
		@errorList.each { |err|
			errCount += 1
			if(!limit.nil? and errCount > limit)
				logStr += "\n...\n...\n [ There were more errors, but only reporting top #{limit}.\n"
				break
			end
			logStr += (errCount.to_s + '.  ' + err.to_s + "\n")
		}
		return logStr
	end

	def writeToFile(logFormat=BRL::Util::TextWriter::TEXT_OUT)
		return false if(@logFileName.nil?)
		begin
			@logFile = BRL::Util::TextWriter.new(@logFileName, "w+", logFormat) if(@logFile.nil?)
			(@nextToWriteIdx...@errorList.size).each { |ii|
				logStr = ((ii+1).to_s + '.  ' + @errorList[ii].to_s + "\n\n")
				@logFile.print logStr
				@nextToWriteIdx += 1
			}
		rescue => err
			$stderr.puts "\n\nFATAL ERROR: couldn't write to log file. Error details:\n\n#{err.message}\n\n#{err.backtrace}\n\n"
		end
		return true
	end

	def close()
		unless(@logFile.nil?)
			begin
				@logFile.close()
			rescue
			end
		end
		return
	end

	def clear()
		self.close()
		@errorList.clear()
		return
	end
end

end ; end
