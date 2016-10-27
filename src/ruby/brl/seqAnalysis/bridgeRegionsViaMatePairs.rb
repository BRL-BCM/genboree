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
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes
require 'brl/seqAnalysis/matePair.rb'
require 'brl/seqAnalysis/region.rb'

# ##############################################################################
# Constants
# ##############################################################################
COMMENT_RE = /^\s*#/
BLANK_RE = /^\s*$/
REC_SPLIT_RE = /\t/
CLASS,QNAME,TYPE,SUBTYPE,TNAME,TSTART,TEND,STRAND,PHASE,SCORE,QSTART,QEND = 0,1,2,3,4,5,6,7,8,9,10,11

module BRL ; module SeqAnalysis

class MateBridgeFinder

	# Constants
	BRIDGE,INTERNAL,EXTERNAL,NEITHER, = 0,1,2,3
	BRIDGE_TYPES = [ 'bridge', 'internal', 'external' ]
	REG1_CHR, REG1_START, REG1_END, REG2_CHR, REG2_START, REG2_END = 0,1,2,3,4,5
	READ_ID,LCHR,LARM,RCHR,RARM,LCOORD,LORI,RORI,RCOORD,LEN,VALID,WARN = 0,1,2,3,4,5,6,7,8,9,10,11
	
	attr_accessor :regionPairs, :regionChrs
	attr_accessor :lffClass, :lffType
	
	def initialize(optsHash)
		@lffClass = 'Matepair'
		@lffType = optsHash['--lffType']
		@regionsFile = optsHash['--regionsFile']
		@matePairsFile = optsHash['--matePairsFile']
		@altInput = optsHash.key?('--altInputFormat') ? true : false
		@inputOffset = @altInput ? 1 : 0
		@regionPairs = []
		@regionChrs = {}
	end
	
	# Load region definition file
	def loadRegionsFile()
		reader = BRL::Util::TextReader.new(@regionsFile)
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE or line =~ COMMENT_RE)
			fields = line.split("\t")
			regionPair = RegionPair::create(*fields)
			@regionPairs << regionPair
			@regionChrs[regionPair.leftRegion.chrom] = ''
			@regionChrs[regionPair.rightRegion.chrom] = ''
		}
		reader.close()
		$stderr.puts "STATS: There are #{@regionPairs.size} regions to examine"
		$stderr.puts "STATS: There are #{@regionChrs.size} chromosomes involved"
		return
	end
	
	# Process matepairs file
	def scanMatePairsFile()
		reader = BRL::Util::TextReader.new(@matePairsFile)
		$stderr.puts "STATUS: opened mate pair file...about to examine each matepair"
		numMatesInvolvingCorrectChr = 0
		reader.each { |line|
			if((reader.lineno % 20000 == 0) and reader.lineno > 0)
				$stderr.puts "  PROGRESS: read #{reader.lineno} lines of the matepair file"
			end
			line.strip!
			next if(line =~ BLANK_RE or line =~ COMMENT_RE)
			fields = line.split("\t")
			fields.map! { |xx| xx.strip }
			next unless((!fields[LCHR].empty? and @regionChrs.key?(fields[LCHR])) or (!fields[RCHR-@inputOffset].empty? and @regionChrs.key?(fields[RCHR-@inputOffset])))
			numMatesInvolvingCorrectChr += 1
			matepair = CompactMatePair.new(fields[READ_ID], fields[LCHR], fields[RCHR-@inputOffset], fields[LCOORD-@inputOffset*2], fields[RCOORD-@inputOffset*2], fields[LORI-@inputOffset*2], fields[RORI-@inputOffset*2])
			if(matepair.nil?)
				raise "\n\nERROR: wtf? new() returned nil?? Line:\n'#{line}'\n\n"
			end
			# For each region, try to use this matepair to form an interesting link
			@regionPairs.each { |regionPair|
				# classify: neither touch regions, both touch same region, both region touched, only one matepair touches a region
				subtype = self.classifyBridge(matepair, regionPair)
				next if(subtype.nil? or (subtype == NEITHER))
				subTypeStr = BRIDGE_TYPES[subtype]
				matepair.lffClass = @lffClass
				matepair.lffType = @lffType
				matepair.lffSubtype = subTypeStr
				puts matepair.to_lff
			}
			matepair.clear
			matepair = nil
		}
		$stderr.puts "\tSTATS: # mate pairs where at least 1 mate was on correct chr: #{numMatesInvolvingCorrectChr}"
		return
	end
	
	def run()
		$stderr.puts "STATUS: initialization complete"
		loadRegionsFile()
		$stderr.puts "STATUS: loaded region definition file"
		scanMatePairsFile()
		$stderr.puts "STATUS: done scanning all mate pairs for possible bridges"
		return		
	end
	
	def classifyBridge(matepair, regionPair)
		lRegion = regionPair.leftRegion
		rRegion = regionPair.rightRegion
		# First, are both mate chrs of regionPair?
		if(matepair.nil?)
			raise "\n\nERROR: wtf? matepair nil??\n\n"
		end
		return nil unless((matepair.leftChr == lRegion.chrom or matepair.leftChr == rRegion.chrom) and (matepair.rightChr == lRegion.chrom or matepair.rightChr == rRegion.chrom))
		# Else, classify
		leftOvLeftReg = matepair.leftOverlapsRegion?(regionPair.leftRegion)
		rightOvLeftReg = matepair.rightOverlapsRegion?(regionPair.leftRegion)
		leftOvRightReg = matepair.leftOverlapsRegion?(regionPair.rightRegion)
		rightOvRightReg = matepair.rightOverlapsRegion?(regionPair.rightRegion)
		
		if(!(leftOvLeftReg or rightOvLeftReg or leftOvRightReg or rightOvRightReg))
			# then the matepair doesn't fall within the regions
			return NEITHER
		elsif((leftOvLeftReg and rightOvRightReg) or (leftOvRightReg and rightOvLeftReg))
			# then we have a bridge!!!!
			return BRIDGE
		elsif((leftOvLeftReg and rightOvLeftReg) or (leftOvRightReg and rightOvRightReg))
			# then we have and internal link
			return INTERNAL
		else
			# we have a dangling link
			return EXTERNAL
		end
	end
	
	# Process arguments
	def MateBridgeFinder.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--lffType', '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--regionsFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
									['--matePairsFile', '-m', GetoptLong::REQUIRED_ARGUMENT],
									['--altInputFormat', '-a', GetoptLong::NO_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		BRL::SeqAnalysis::MateBridgeFinder.usage() if(optsHash.empty? or optsHash.key?('--help'));
		return optsHash
	end
	
	def MateBridgeFinder.usage(msg='')
		unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "

  PROGRAM DESCRIPTION:
    Attempts to bridge or link the region-pairs defined in the regions file]
    using the matepairs provided in the mate-pair file. Three types of link are
    detected and returned:
    
      bridge    =>  The matepair connects two regions of 1+ region-pairs
      internal  =>  The matepair falls entirely within a region
      external  =>  The matepair has one end within a region
      
    If the matepair doesn't fall in one of these 3 categories, it is discarded.
    
    These categories are used as the LFF subtype. You provide the LFF type
    string.

    The output is the relevant matepairs, in LFF format. They use the
    strand/phase convention used by the mate-pair drawing styles.

    COMMAND LINE ARGUMENTS:
      --lffType      | -l    => LFF *type* string to use for new track
      --matePairFile | -m    => Matepair file
      --regionFile   | -r    => Region *Pairs* file
      --altInput      | -a    => Input file has the alternative input format
                                 (when LARM/RARM cols are missing)
     --help         | -h    => [optional flag] Output this usage info and exit

	";
			exit(2);
	end
end

end ; end

# ##############################################################################
# MAIN
# ##############################################################################
optsHash = BRL::SeqAnalysis::MateBridgeFinder::processArguments()
finder = BRL::SeqAnalysis::MateBridgeFinder.new(optsHash)
finder.run()
exit(0)
