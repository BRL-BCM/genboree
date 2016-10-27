#!/usr/bin/env ruby


# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
module BRL ;  module DataStructure

# The elements of MatchScoreBoundedQueue must have
# the method replace and the readable attribute score

class MatchScoreBoundedQueue
	attr_reader :bound, :minElem
	def initialize(bound=10)
		@bound = bound
		@minElem = nil
		@myArray = []
		@size = 0
	end

	def push(a)
		if (@size < @bound)
			@myArray.push(a.dup)
			@size += 1
		else  #(@size == @bound)
			if ( a.score > @minElem.score)
				@minElem.replace(a)
			else
				return
			end
		end
		
		@minElem = @myArray.first
		@myArray.each {|x|
			if (x.score < @minElem.score)
				@minElem = x
			end
		}
		#puts "new min #{@minElem.to_s}"
	end
	
	def pop
		if (not @myArray.empty?)
			@size -= 1
			return @myArray.pop
		else
			return nil
		end
	end

	def empty?
		@myArray.empty?
	end
	def dump
    @myArray.each {|x|
			puts "#{x.to_s}"
		}
  end	

end

end; end