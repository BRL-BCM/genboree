#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# $Copyright:$
# ##############################################################################
# ##############################################################################
# VERSION INFO
# ##############################################################################
# $Id$
# $Header: $
# $LastChangedDate$
# $LastChangedDate$
# $Change: $
# $HeadURL$
# $LastChangedRevision$
# $LastChangedBy$
# ##############################################################################

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/util/util'

# ##############################################################################
# Constants
# ##############################################################################
module BRL ; module SeqAnalysis

class Region
	attr_accessor :chrom, :start, :stop
	
	def initialize(chrom, start, stop)
		@chrom, @start, @stop = chrom, start.to_i, stop.to_i
	end
end

class RegionPair
	attr_accessor :leftRegion, :rightRegion
	
	def initialize(leftRegion, rightRegion)
		@leftRegion, @rightRegion = leftRegion, rightRegion
	end
	
	def RegionPair::create(chrom1, start1, stop1, chrom2, start2, stop2)
		leftRegion = Region.new(chrom1, start1.to_i, stop1.to_i)
		rightRegion = Region.new(chrom2, start2.to_i, stop2.to_i)
		return RegionPair.new(leftRegion, rightRegion)
	end
end

end ; end
