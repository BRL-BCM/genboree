#!/usr/bin/env ruby
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable'
require "GSL"
include GSL

module PoolWindowInfo

# FILES
#@lffMergerFile = "/users/hgsc/andrewj/brl/poolData/Rhesus.macaque/96x96.3-9-2003/blastResults/blatReadsVsHg15/mappedReads.array2.poolsWithControls.txt.merged.lff.mergeWindows.lff"
@lffMergerFile = "/users/hgsc/rharris1/brl/poolData/Rhesus.macaque/hg15-29-5-2003/blastResults/blatReadsVsHG15/array1/allReads.mapped.unique.lff.merged.lff.poolMapped.unique.lff"

# PARAMS
@minReadsToDefineWindow = 2
@numberExpectedBACs = 48

# VARS
@pools = {}

class PoolWindows
	attr_accessor :poolName, :windows

	def initialize(poolName)
		@poolName = poolName
		@windows = {}
	end

	def addRead(fields)
		winName = fields[1]
		if(@windows.key?(winName))
			@windows[winName].addRead(fields)
		else
			@windows[winName] = PoolWindowInfo::Window.new(fields)
		end
		return
	end

	def getSortedWindows()
		windowsAry = @windows.values
		windowsAry.sort!()
		return windowsAry
	end
	
	def getWindows()
		windowsAry = @windows.values
		return windowsAry
	end
	
	def getWindowHash()
		return @windows
	end

	def maxNumReadsPerWindow()
		max = 0
		@windows.values.each { |window|
			if(window.numReads > max) then max = window.numReads end
		}
		return max
	end

	def minNumReadsPerWindow()
		min = 1_000_000
		@windows.values.each { |window|
			if(window.numReads < min) then min = window.numReads end
		}
		return min
	end

	def avgNumReadsPerWindow()
		avg = 0.0
		@windows.values.each { |window|
			avg += window.numReads.to_f
		}
		return avg / @windows.size.to_f
	end

	def maxWindowSize()
		max = 0
		@windows.values.each { |window|
			if(window.size > max) then max = window.size end
		}
		return max
	end

	def minWindowSize()
		min = 1_000_000
		@windows.values.each { |window|
			if(window.size < min) then min = window.size end
		}
		return min
	end

	def avgWindowSize()
		avg = 0.0
		@windows.values.each { |window|
			avg += window.size.to_f
		}
		return avg / @windows.size.to_f
	end

	def getNumReadsPerWindowKurtosis()
		numReads = @windows.values.map { |ww| ww.numReads }
		fillLength = 48 - numReads.length
		numReads = numReads.fill(0,numReads.length,fillLength)
		return GSL::Stats::kurtosis(numReads,1)
	end

	def getNumReadsPerWindowSkew()
		numReads = @windows.values.map { |ww| ww.numReads }
		fillLength = 48 - numReads.length
		numReads = numReads.fill(0,numReads.length,fillLength)
		return GSL::Stats::skew(numReads,1)
	end

	def getNumReadsPerWindowQuartiles()
		quartiles = []
		numReads = @windows.values.map { |ww| ww.numReads }
		numReads.sort!
		quartiles[0] = GSL::Stats::quantile_from_sorted_data(numReads, 1, 0.0)
		quartiles[1] = GSL::Stats::quantile_from_sorted_data(numReads, 1, 0.25)
		quartiles[2] = GSL::Stats::quantile_from_sorted_data(numReads, 1, 0.50)
		quartiles[3] = GSL::Stats::quantile_from_sorted_data(numReads, 1, 0.75)

		return quartiles
	end

	def to_s()
		return "<#{@poolName}>\t#{@windows.size}\t#{self.maxNumReadsPerWindow()}\t#{self.minNumReadsPerWindow()}\t#{self.avgNumReadsPerWindow()}\t #{self.getNumReadsPerWindowKurtosis()} \t #{self.getNumReadsPerWindowSkew()} \t#{self.maxWindowSize()}\t#{self.minWindowSize()}\t#{self.avgWindowSize()}"
	end
end

class Window
	include Comparable
	attr_accessor :poolName, :winNum, :numReads, :targ, :start, :stop, :score

	def initialize(fields)
		@winNum = fields[1][ /\.([^\.]+)$/ , 1].to_i
		@poolName = fields[1][ /^([^\.]+)\./ , 1]
		@numReads = 1
		@targ = fields[4][ /^([^\.]+)\./ , 1]
		@start = fields[5].to_i
		@stop = fields[6].to_i
		@score = fields[9].to_f
	end

	def addRead(fields)
		winNum = fields[1][ /\.([^\.]+)$/ , 1].to_i
		poolName = fields[1][ /^([^\.]+)\./ , 1]
		targ = fields[4][ /^([^\.]+)\./ , 1]
		rstart = fields[5].to_i
		rstop = fields[6].to_i
		score = fields[9].to_f
		unless(poolName == @poolName and targ == @targ and winNum == @winNum)
			$stderr.puts "ERROR: tried to add a read to this window that doesn't belong.\nREAD:\n\t'#{fields.join(' ')}'\nWIN:\n\t'#{self.to_s}'"
		else # add the read
			@numReads += 1
			@start = rstart if(rstart < @start)
			@stop = rstop if(rstop > @stop)
			@score += score
		end
	end

	def to_s()
		return "#{@poolName}\t#{@winNum}\t#{@numReads}\t#{self.size()}\t#{@targ}\t#{@start}\t#{@stop}\t#{@score}"
	end

	def size()
	return @stop - @start
	end

	def <=>(otherWin)
		return otherWin.numReads <=> @numReads
	end
end

	def PoolWindowInfo.loadPoolWindowsFile()
		reader =  BRL::Util::TextReader.new(@lffMergerFile)
		reader.each { |line|
			fields = line.strip.split("\t")
			poolName = fields[1][ /^([^\.]+)\./ , 1 ]
			unless(@pools.key?(poolName))
				@pools[poolName] = PoolWindowInfo::PoolWindows.new(poolName)
			end
			@pools[poolName].addRead(fields)
		}
		return
	end

	def PoolWindowInfo.dumpPoolWindowInfo(limit=1_000_000)
		@pools.each { |poolName, pool|
			windows = pool.getWindowHash
					
			windows.each { |winName, window|
				if(window.numReads < @minReadsToDefineWindow )
					windows.delete(winName)
				end
			}
		}
				
		puts "<poolName>\tnumWindows\tmaxReadsPerWin\tminReadsPerWin\tavgReadsPerWin\tkurtosis\tskew\tmaxWinSize\tminWinSize\tavgWinSize"
		@pools.each { |poolName, pool|
			puts pool.to_s
			puts "\t#poolName\twinNum\tnumReads\tsize\ttarg\tstart}\tstop\tscore"
			windows = pool.getSortedWindows[0,limit]
			windows.each { |window|
				puts "\t" + window.to_s
			}
		}
		return
	end

	def PoolWindowInfo.run()
		PoolWindowInfo.loadPoolWindowsFile()
#		PoolWindowInfo.dumpPoolWindowInfo()
		puts '-'*60
		PoolWindowInfo.dumpPoolWindowInfo(96)
		return
	end
end

# Main
PoolWindowInfo.run()
exit(0)
