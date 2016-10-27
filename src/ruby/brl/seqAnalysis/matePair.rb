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

module BRL ; module SeqAnalysis

FWD,REV = 0,1

class CompactMatePair
	# Constants
	MP_SUBTYPES = [ '+-', '-+', '++', '--', '+.', '.-', '-.', '.+' ]
	MP_PHASE = '.'
	ANCHOR_LEN = 500
	DEFAULT_SUBTYPE = 'matepair'
	
	attr_accessor :mateID, :leftChr, :rightChr, :leftStart, :rightStart, :leftOri, :rightOri
	attr_accessor :lffType, :lffClass, :lffSubtype
	
	def initialize(mateID, leftChr, rightChr, leftStart, rightStart, leftOriStr, rightOriStr)
		@mateID, @leftChr, @rightChr, @leftStart, @rightStart = mateID, leftChr, rightChr, leftStart.to_i, rightStart.to_i
		@lffType = 'Matepair'
		@lffClass = 'Matepair'
		@lffSubtype = nil
		
		if(leftOriStr == '>' or leftOriStr == '+')
			@leftOri = FWD
		elsif(leftOriStr == '<' or leftOriStr == '-')
			@leftOri = REV
		else
			@leftOri = nil
		end
		
		if(rightOriStr == '>' or rightOriStr == '+')
			@rightOri = FWD
		elsif(rightOriStr == '<' or rightOriStr == '-')
			@rightOri = REV
		else
			@rightOri = nil
		end
	end
	
	def clear()
		@mateID, @leftChr, @rightChr, @leftStart, @rightStart, @lffType, @lffSubtype, @lffClass = nil
		return
	end
	
	def orientType()
		if(!@leftOri.nil? and !@rightOri.nil? and (@leftChr == @rightChr)) # then we have 2 ends on the same chr
			# strand,subtype, and such
			if(@leftOri == FWD and @rightOri == REV)		# >__<	|	+-
				return 0
			elsif(@leftOri == REV and @rightOri == FWD)	# <__>	|	-+
				return 1
			elsif(@leftOri == FWD and @rightOri == FWD)	# >__>  |	++
				return 2
			elsif(@leftOri == REV and @rightOri == REV)	# <__<  |	--
				return 3
			else # what?
				raise "\n\nERROR: funny situation where can't determine what orientation.\n'#{self.inspect}'\n\n"
			end
		else # either chrs are different or we only have one end
			if(!@leftOri.nil?) # then we have the left end
				# strand,subtype, and such
				if(@leftOri == FWD)			# >__	| +.
					return 4
				elsif(@leftOri == REV)	# <__	|	-.
					return 6
				else # what?
					raise "\n\nERROR: funny situation where can't determine what orientation.\n'#{self.inspect}'\n\n"
				end
			end
			if(!@rightOri) # then we have the right end
				if(@rightOri == REV) 		# __<	|	.-
					return 5
				elsif(@rightOri == FWD) # __>	| .+
					return 7
				else # what?
					raise "\n\nERROR: funny situation where can't determine what orientation.\n'#{self.inspect}'\n\n"
				end
			end
		end # if(!@leftOri.nil? and !@rightOri.nil? and (@leftChr == @rightChr)
	end	# orientType()
	
	def orientTypeStr()
		return MP_SUBTYPES[self.orientType()]
	end
	
	def leftOverlapsRegion?(region)
		return (@leftStart >= region.start and @leftStart <= region.stop) ? true : false
	end
	
	def rightOverlapsRegion?(region)
		return (@rightStart >= region.start and @rightStart <= region.stop) ? true : false
	end
	
	def to_lff(doEightTracks=false)
		retVal = []
		lffRec = Array.new(12)
		lffRec[TYPE] = @lffType
		lffRec[CLASS] = @lffClass
		if(doEightTracks)	# Then we have to figure out the subtype
			lffRec[SUBTYPE] = self.orientTypeStr()
		else 	# Then someone must have set the lff subtype for us already and we
					# don't have to figure it out.
			unless(@lffSubtype.nil?)
				lffRec[SUBTYPE] = @lffSubtype
			else
				lffRec[SUBTYPE] = DEFAULT_SUBTYPE
			end				
		end
		
		lffRec[QSTART] =  '.'
		lffRec[QEND] = '.'
		lffRec[SCORE] = 1
		lffRec[QNAME] = @mateID
		if(!@leftChr.nil? and !@rightChr.nil? and (@leftChr == @rightChr)) # then we have 2 ends on the same chr
			lffRec[TNAME] = @leftChr
			lffRec[TSTART] = @leftStart
			lffRec[TEND] = @rightStart
			# strand,subtype, and such
			if(@leftOri == FWD and @rightOri == REV)		# >__<
				lffRec[STRAND] = '+'
				lffRec[PHASE] = 0
			elsif(@leftOri == REV and @rightOri == FWD)	# <__>
				lffRec[STRAND] = '-'
				lffRec[PHASE] = 0
			elsif(@leftOri == FWD and @rightOri == FWD)	# >__>
				lffRec[STRAND] = '+'
				lffRec[PHASE] = 1
			elsif(@leftOri == REV and @rightOri == REV)	# <__<
				lffRec[STRAND] = '-'
				lffRec[PHASE] = 1
			else # what?
				raise "\n\nERROR: funny situation where can't determine what orientations we have.\n'#{self.inspect}'\n\n"
			end
			# Dump
			retVal << lffRec.join("\t")
		else # either chrs are different or we only have one end
			lffRec[TNAME] = @leftChr
			lffRec[TSTART] = @leftStart
			lffRec[TEND] = @leftStart + ANCHOR_LEN
			if(!@leftOri.nil?)
				# strand,subtype, and such
				if(@leftOri == FWD) 		# >__
					lffRec[STRAND] = '+'
					lffRec[PHASE] = 0 
				elsif(@leftOri == REV) # <__
					lffRec[STRAND] = '-'
					lffRec[PHASE] = 1	
				else # what?
					raise "\n\nERROR: funny situation where can't determine what orientations we have.\n'#{self.inspect}'\n\n"
				end
				retVal << lffRec.join("\t")
			end
			if(!@rightOri.nil?) # then we have the right end
				lffRec[TNAME] = @rightChr
				lffRec[TSTART] = @rightStart
				lffRec[TEND] = @rightStart + ANCHOR_LEN
				if(@rightOri == REV) 		# __<
					lffRec[STRAND] = '-'
					lffRec[PHASE] = 0 
				elsif(@rightOri == FWD) # __>
					lffRec[STRAND] = '+'
					lffRec[PHASE] = 1 	
				else # what?
					raise "\n\nERROR: funny situation where can't determine what orientations we have.\n'#{self.inspect}'\n\n"
				end
				retVal << lffRec.join("\t")
			end
		end
		return retVal.join("\n")
	end	# def to_lff(doEightTracks=false)
end	# class CompactMatePair

end ; end
