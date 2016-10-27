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

class MatePairExtracter

	# Constants
	INTERNAL,EXTERNAL,NEITHER, = 0,1,2
	BRIDGE_TYPES = [ 'internal', 'external' ]
	REG_CHR, REG_START, REG_END = 0,1,2
	READ_ID,LCHR,LARM,RCHR,RARM,LCOORD,LORI,RORI,RCOORD,LEN,VALID,WARN = 0,1,2,3,4,5,6,7,8,9,10,11
	
	attr_accessor :regions, :regionChrs
	attr_accessor :lffClass, :lffType
	
	def initialize(optsHash)
		@lffClass = 'Matepair'
		@lffType = optsHash['--lffType']
		@regionsFile = optsHash['--regionsFile']
		@matePairsFile = optsHash['--matePairsFile']
		@doEightTracks = optsHash.key?('--doEightTracks') ? true : false
		@altInput = optsHash.key?('--altInputFormat') ? true : false
		@inputOffset = @altInput ? 1 : 0
		@regions = []
		@regionChrs = {}
	end
	
	# Load region definition file
	def loadRegionsFile()
		reader = BRL::Util::TextReader.new(@regionsFile)
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE or line =~ COMMENT_RE)
			fields = line.split("\t")
			region = Region.new(*fields)
			@regions << region
			@regionChrs[region.chrom] = ''
		}
		reader.close()
		$stderr.puts "STATS: There are #{@regions.size} regions to examine"
		$stderr.puts "STATS: There are #{@regionChrs.size} chromosomes involved"
		return
	end
	
	# Process matepairs file
	def scanMatePairsFile()
		typeCount = {}
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
			@regions.each { |region|
				# classify: neither touch regions, both touch same region, both region touched, only one matepair touches a region
				subtype = self.classifyLink(matepair, region)
				typeCount[subtype] = 0 unless(typeCount.key?(subtype))
				typeCount[subtype] += 1
				next if(subtype.nil? or (subtype == NEITHER))
				matepair.lffSubtype = BRIDGE_TYPES[subtype] unless(@doEightTracks)
				matepair.lffClass = @lffClass
				matepair.lffType = @lffType
				puts matepair.to_lff(@doEightTracks)
			}
			matepair.clear
			matepair = nil
		}
		$stderr.puts "\tSTATS: # mate pairs where at least 1 mate was on correct chr: #{numMatesInvolvingCorrectChr}"
		$stderr.puts "\tSTATS: classification breakdown:\n"
		typeCount.each { |key, val|
			$stderr.puts "\t\t#{key.nil? ? key.inspect : key}  =>  #{val}"
		}
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
	
	def classifyLink(matepair, region)
		# First, are both mate chrs of regionPair?
		if(matepair.nil?)
			raise "\n\nERROR: wtf? matepair nil??\n\n"
		end
		return nil unless((matepair.leftChr == region.chrom) and (matepair.rightChr == region.chrom))
		# Else, classify
		leftOvReg = matepair.leftOverlapsRegion?(region)
		rightOvReg = matepair.rightOverlapsRegion?(region)
		
		if(!(leftOvReg or rightOvReg))
			# then the matepair doesn't fall within the regions
			return NEITHER
		elsif(leftOvReg and rightOvReg)
			# then we have a bridge!!!!
			return INTERNAL
		else
			# we have a dangling link
			return EXTERNAL
		end
	end
	
	# Process arguments
	def MatePairExtracter.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--lffType', '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--regionsFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
									['--matePairsFile', '-m', GetoptLong::REQUIRED_ARGUMENT],
									['--altInputFormat', '-a', GetoptLong::NO_ARGUMENT],
									['--doEightTracks', '-8', GetoptLong::NO_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		$stderr.puts "COMMAND ARGS:"
		optsHash.each { |key, val|
			$stderr.puts "  #{key}\t#{val}"
		}
		BRL::SeqAnalysis::MatePairExtracter.usage() if(optsHash.empty? or optsHash.key?('--help'));
		return optsHash
	end
	
	def MatePairExtracter.usage(msg='')
		unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "

  PROGRAM DESCRIPTION:
    Extracts matepairs falling within or overlapping with one or more regions
    defined in the region file. The LFF subtype can be set to 2-track (default)
    or 8-track output.
    
    2-track output:
      internal  =>  The matepair falls entirely within a region
      external  =>  The matepair has one end within a region
      
    8-track output (must be internal/external to be output, but the subtype is
    set to one of these cases instead):
      +-, -+, ++, --, +., .-, .+, -.
     
    If the matepair isn't internal/external, it is discarded.
    You provide the LFF type string.

    The output is the relevant matepairs, in LFF format. They use the
    strand/phase convention used by the mate-pair drawing styles.

    COMMAND LINE ARGUMENTS:
      --lffType       | -l    => LFF *type* string to use for the new tracks
      --matePairFile  | -m    => Matepair file
      --regionFile    | -r    => Regions file
      --altInput      | -a    => Input file has the alternative input format
                                 (when LARM/RARM cols are missing)
      --doEightTracks | -8    => [optional flag] Separate regions into 8 tracks,
                                 not just 2 (internal, external).
      --help          | -h    => [optional flag] Output this usage info and exit

	";
			exit(2)
	end
end

end ; end

# ##############################################################################
# MAIN
# ##############################################################################
optsHash = BRL::SeqAnalysis::MatePairExtracter::processArguments()
extracter = BRL::SeqAnalysis::MatePairExtracter.new(optsHash)
extracter.run()
exit(0)
