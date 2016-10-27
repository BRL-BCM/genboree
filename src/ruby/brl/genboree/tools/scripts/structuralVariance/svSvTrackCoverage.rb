#!/usr/bin/env ruby
require 'set'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/structVarToolset/lib/annotationIndex.rb'

module BRL; module Pash

class SvLffTrackCoverage
  DEBUG = false
  DEBUG_CALL = false
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end

  def setParameters()
		@querySVLffFile = 			@optsHash['--querySVLffFile']
		@targetSVLffFile = 			@optsHash['--targetSVLffFile']
		@attributeNameExact = 	@optsHash['--attributeNameExact']
		@svCoverageFile = @optsHash['--svCoverageFile']
		@radius = @optsHash['--radius'].to_i
		$stderr.puts "sv intersection of #{@querySVLffFile} using #{@targetSVLffFile};
    write output to #{@svCoverageFile}, attribute #{@attributeNameExact} and #{@attributeNameOverlap}" if (DEBUG)
  end


  def indexTargetSVTrack()
		@annoInfoArrayExact = []
		annoReader = BRL::Util::TextReader.new(@targetSVLffFile)
	  @annoCoverageStruct = Struct.new("AnnoStruct", :name, :chrom, :start, :stop, :mateChrom, :mateStart, :mateStop, :mateType)
	  l = nil
	  chrom = nil
	  chromStart = nil
	  chromStop = nil
	  mateChrom = nil
	  mateStart = nil
	  mateStop = nil
	  name = nil
	  strand = nil

	  annoReader.each {|l|
			f = l.split(/\t/)
			chrom = f[4]
			chromStart = f[5].to_i
			chromStop = f[6].to_i
			name = f[1]
			f[12]=~/mateChrom=([^;\s]+)/
			mateChrom = $1
			f[12]=~/mateStart=([^;\s]+)/
			mateStart = $1.to_i
			f[12]=~/mateStop=([^;\s]+)/
			mateStop = $1.to_i
			f[12]=~/mateType=([^;\s]+)/
			mateType = $1
			adjStart = chromStart - @radius
			if (adjStart<1) then
				adjStart = 1
			end
			adjMateStart = mateStart-@radius
			if (adjMateStart < 1) then
				adjMateStart = 1
			end
			annoInfo = @annoCoverageStruct.new(name, chrom, adjStart, chromStop+@radius, mateChrom, adjMateStart, mateStop+@radius, mateType)
			$stderr.puts "adding exact sv coverage info #{name} #{chrom}: #{chromStart}-#{chromStop} #{mateChrom}: #{mateStart}-#{mateStop}" if (DEBUG)
			$stderr.puts "adding adjusted exact sv coverage info #{annoInfo.name} #{annoInfo.chrom}: #{annoInfo.start}-#{annoInfo.stop} #{annoInfo.mateChrom}: #{annoInfo.mateStart}-#{annoInfo.mateStop}" if (DEBUG)
			@annotationIndexExact.addAnnotation(chrom, adjStart, chromStop+@radius, annoInfo)
			@annoInfoArrayExact.push(annoInfo)
		}
	  annoReader.close()
	  @annotationIndexExact.dumpAnnotationIndex() if (DEBUG)
	end

	# return gene list, or nil if none covered
	def lookupCluster(annotationIdx, chrom, chromStart, chromStop)
		$stderr.puts "looking up #{chrom} : #{chromStart}-#{chromStop}" if (DEBUG)
		overlappingAnnos = annotationIdx.getOverlappingAnnotations(chrom,chromStart,chromStop)
		if (overlappingAnnos==nil) then
			return nil
		end
		gList = []
		$stderr.puts "checking against #{overlappingAnnos.size} potential annos" if (DEBUG)
		anno = nil
		annoInfo=nil
		overlappingAnnos.each {|anno|
			$stderr.puts "checking against cluster id #{anno}" if (DEBUG)
			if(chromStart<=anno.chromStop && chromStop>=anno.chromStart) then
				gList.push(anno.info)
			end
		}
		if (gList.size>0) then
			return gList
		else
			return nil
		end
	end

  def computeCoverage()
		svReader = BRL::Util::TextReader.new(@querySVLffFile)
		coveredSVWriter = BRL::Util::TextWriter.new(@svCoverageFile)
		l = nil
		covered_clusters = []
		adjAnnoStart = 0
		adjAnnoStop = 0
		svType = ""
		currentHash = {}
		avp=nil
		exactAnnoSet = nil
		looseAnnoSet = nil
		svReader.each {|l|
			f = l.strip.split(/\t/)
			if (f[12]==nil) then
				$stderr.puts "weird #{l.strip}"
				exit(2)
			end
			avps = f[12].split(/;\s+/)
			currentHash = {}
			avps.each  {|avp|
				avp =~ /\s*(\S+)\s*=\s*(\S+)/
				currentHash [$1]=$2
			}
			if (DEBUG) then
				$stderr.print "#{l.strip}:   "
				currentHash.keys.each{|k|
					$stderr.print "#{k}=#{currentHash[k]}"
				}
				$stderr.puts ""
			end
			coverage  = currentHash["matePairsCount"].to_i
			mateChrom = currentHash["mateChrom"]
			mateStart = currentHash["mateStart"].to_i
			mateStop = currentHash["mateStop"].to_i
			svType = currentHash["mateType"]
			chrom1 = f[4]
			chrom1Start= f[5].to_i
			chrom1Stop = f[6].to_i
			avpExact = ""
			# look for exact overlap
			# gList1 = lookupCluster(@annotationIndexExact, chrom1, chrom1Start, chrom1Stop)
			$stderr.puts "looking up #{chrom1} : #{chrom1Start}-#{chrom1Stop}" if (DEBUG)
			overlappingAnnos = @annotationIndexExact.getOverlappingAnnotations(chrom1,chrom1Start,chrom1Stop)
			if (overlappingAnnos==nil) then
				next
			end
			annos = Set.new()
			$stderr.puts "checking against #{overlappingAnnos.size} potential annos" if (DEBUG)
			anno = nil
			annoInfo=nil
			overlappingAnnos.each {|anno|
				$stderr.puts "checking against cluster id #{anno.info}" if (DEBUG)
				# look at the other end of the mp
				if (mateChrom == anno.info.mateChrom&& anno.info.mateStart <= mateStop&& anno.info.mateStop >= mateStart && svType==anno.info.mateType) then
					$stderr.puts "Found exact overlap: #{l.strip} vs #{anno.info.name} #{anno.info.chrom} #{anno.info.start} #{anno.info.stop} #{anno.info.mateChrom} #{anno.info.mateStart} #{anno.info.mateStop} #{anno.info.mateType}" if (DEBUG_CALL)
					annos.add(anno.info.name)
				end
			}
			if (annos.size>0) then
				f[12] << "; #{@attributeNameExact}=#{annos.to_a.join(",")}"
				coveredSVWriter.puts f.join("\t")
			end
		}
		svReader.close()
		coveredSVWriter.close()
  end

  def work()
		@annotationIndexExact = BRL::Pash::AnnotationIndex.new()
		indexTargetSVTrack()
		computeCoverage()
  end

  def SvLffTrackCoverage.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--querySVLffFile',   	'-q', GetoptLong::REQUIRED_ARGUMENT],
									['--targetSVLffFile',   '-t', GetoptLong::REQUIRED_ARGUMENT],
									['--svCoverageFile',    '-S', GetoptLong::REQUIRED_ARGUMENT],
									['--attributeNameExact',  	'-e', GetoptLong::REQUIRED_ARGUMENT],
									['--radius',            '-r', GetoptLong::REQUIRED_ARGUMENT],
									['--help',              '-h', GetoptLong::NO_ARGUMENT]
			]

		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		SvLffTrackCoverage.usage() if(optsHash.key?('--help'));

		unless(progOpts.getMissingOptions().empty?)
			SvLffTrackCoverage.usage("USAGE ERROR: some required arguments are missing")
		end

		SvLffTrackCoverage.usage() if(optsHash.empty?);
		return optsHash
	end

	def SvLffTrackCoverage.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  This utility takes in a query sv track, a target SV track
and annotates the SVs that overlap with a target SVs

COMMAND LINE ARGUMENTS:
  --querySVLffFile       | -q   => SVs in lff format
                                   each annotation has the attributes mateChrom, mateChromStart, mateChromStop
  --targetSVLffFile      | -t   => LFF file containing an SV track for which we want to compute the overlap
  --svCoverageFile       | -S   => lff output file, annotating the query SVs that overlap w/ target SVs
  --attributeNameExact   | -e   => additional attribute specifying the strict overlap with a target SV
                                   corresponding mate pair ends are within maxInsert bp of each other
  --radius               | -r   => radius used for overlap detection
  --help                 | -h   => [optional] output this usage info and exit

USAGE:
  svSTrackCoverage.rb  -s svcalls.lff -c knownSVs.lff -S rediscoveredSVs.lff -a knownSVsExact -r 3000
";
			exit(2);
	end
end

end; end
########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = BRL::Pash::SvLffTrackCoverage.processArguments()
# Instantiate analyzer using the program arguments
boilerPlate = BRL::Pash::SvLffTrackCoverage.new(optsHash)
# Analyze this !
boilerPlate.work()
exit(0);
