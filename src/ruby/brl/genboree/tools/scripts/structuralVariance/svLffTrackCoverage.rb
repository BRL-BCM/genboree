#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/structVarToolset/lib/annotationIndex.rb'

module BRL; module Pash

class SVGenesCoverage
  DEBUG = false
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end

  def setParameters()
		@svLffFile = 	@optsHash['--svLffFile']
		@coverageLffFile = 	@optsHash['--coverageLffFile']
		@attributeNameSV = 	@optsHash['--attributeNameSV']
		@attributeNameAnno = 	@optsHash['--attributeNameAnno']
		@outCoverageFile = @optsHash['--outCoverageFile']
		@outCoveredAnnos = @optsHash['--outCoveredAnnos']
		@radius = 0
                if (@optsHash.key?('--radius')) then
                  @radius = @optsHash['--radius'].to_i
                end
		$stderr.puts "sv intersection of #{@svLffFile} using #{@coverageLffFile};
		write output to #{@outCoverageFile}, attribute #{@attributeNameSV}, and #{@outCoveredAnnos}" if (DEBUG)
  end


  def indexCoverageTrack()
		@annoInfoArray = []
		annoReader = BRL::Util::TextReader.new(@coverageLffFile)
	  @annoCoverageStruct = Struct.new("AnnoStruct", :name, :line, :chrom, :start, :stop, :coverage)
	  l = nil
	  chrom = nil
	  chromStart = nil
	  chromStop = nil
	  name = nil
	  strand = nil
	  annoReader.each {|l|
			f = l.split(/\t/)
			chrom = f[4]
			chromStart = f[5].to_i-@radius
			if (chromStart<1) then
				chromStart = 1
			end
			chromStop = f[6].to_i+@radius
			name = f[1]
			annoInfo = @annoCoverageStruct.new(name, l.strip, chrom, chromStart, chromStop, Set.new())
			$stderr.puts "adding gene coverage info #{name} #{chrom}: #{chromStart}-#{chromStop} " if (DEBUG)
			@annotationIndex.addAnnotation(chrom, chromStart, chromStop, annoInfo)
			@annoInfoArray.push(annoInfo)
		}
	  annoReader.close()
	  @annotationIndex.dumpAnnotationIndex() if (DEBUG)
	end

	# return gene list, or nil if none covered
	def lookupCluster(chrom, chromStart, chromStop, coverage)
		$stderr.puts "looking up #{chrom} : #{chromStart}-#{chromStop} w/ coverage #{coverage}" if (DEBUG)
		overlappingAnnos = @annotationIndex.getOverlappingAnnotations(chrom,chromStart,chromStop)
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
				annoInfo = anno.info
				annoInfo.coverage.add(coverage)
				gList.push(anno.info.name)
			end
		}
		if (gList.size>0) then
			return gList
		else
			return nil
		end
	end

  def computeCoverage()
		svReader = BRL::Util::TextReader.new(@svLffFile)
		coveredSVWriter = BRL::Util::TextWriter.new(@outCoverageFile)
		l = nil
		covered_clusters = []
		adjAnnoStart = 0
		adjAnnoStop = 0
		svType = ""
		currentHash = {}
		avp=nil
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
			if (svType == "Translocation") then
				gList1 = lookupCluster(chrom1, chrom1Start, chrom1Stop, f[1])
				gList2 = lookupCluster(mateChrom, mateStart, mateStop, f[1])
				if (gList1==nil) then
						gList1 = gList2
				elsif(gList2 != nil) then
					gList1.concat(gList2)
				end
			else
				if (chrom1Start<=mateStop) then
					gList1 = lookupCluster(chrom1, chrom1Start, mateStop, f[1])
				else
					gList1 = lookupCluster(chrom1, mateStart, chrom1Stop, f[1])
				end
			end
			if (gList1 != nil) then
				f[12]<<";  #{@attributeNameSV}=#{gList1.join(",")}"
				coveredSVWriter.puts f.join("\t")
			end
		}
		svReader.close()
		coveredSVWriter.close()
  end

	def writeCoveredAnnos()
		annoWriter = BRL::Util::TextWriter.new(@outCoveredAnnos)
		annoName=""
		annoType=""
		sum = 0
		individualCoverage = 0
		@annoInfoArray.each {|annoInfo|
			if (annoInfo.coverage.size>0) then
				name= annoInfo.name
				sum=annoInfo.coverage.to_a.join(",")
				annoWriter.puts "#{name}\t#{annoInfo.chrom}\t#{annoInfo.start}\t#{annoInfo.stop}\t#{sum}"
			end
		}
		annoWriter.close()
	end

  def work()
		@annotationIndex = BRL::Pash::AnnotationIndex.new()
		indexCoverageTrack()
		computeCoverage()
    writeCoveredAnnos()
  end

  def SVGenesCoverage.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--svLffFile',   			'-s', GetoptLong::REQUIRED_ARGUMENT],
									['--coverageLffFile',   '-c', GetoptLong::REQUIRED_ARGUMENT],
									['--outCoverageFile',   '-S', GetoptLong::REQUIRED_ARGUMENT],
									['--attributeNameSV',  	'-a', GetoptLong::REQUIRED_ARGUMENT],
									['--attributeNameAnno', '-A', GetoptLong::REQUIRED_ARGUMENT],
									['--outCoveredAnnos',   '-C', GetoptLong::REQUIRED_ARGUMENT],
									['--radius',   		'-r', GetoptLong::OPTIONAL_ARGUMENT],
									['--help',              '-h', GetoptLong::NO_ARGUMENT]
			]

		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		SVGenesCoverage.usage() if(optsHash.key?('--help'));

		unless(progOpts.getMissingOptions().empty?)
			SVGenesCoverage.usage("USAGE ERROR: some required arguments are missing")
		end

		SVGenesCoverage.usage() if(optsHash.empty?);
		return optsHash
	end

	def SVGenesCoverage.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  This utility takes in SV calls, gene lists (whole gene and promoters),
and generates
 - a list of SVs with type annotation, coverage and covered genes
 - score-annotated gene list


COMMAND LINE ARGUMENTS:
  --svLffFile            | -s   => SVs in lff format
                                   each annotation has the fields mateChrom, mateChromStart, mateChromStop
  --coverageLffFile      | -c   => LFF file containing a track for which we want to compute the coverage
  --outCoverageFile      | -S   => lff output file, cotaining the SVs that overlap w/ annos in the coverage
                                   file, with a covered annos attribute
  --attributeNameSV      | -a   => additional attribute containing the list of covered annos
  --attributeNameAnno    | -A   => additional attribute containing the sv coverage
  --outCoveredAnnos      | -C   => second lff output file: contains the annotations covered by the sv track,
                                  with a mpCoverage attribute
  --radius               | -r   => radius around the feature to look for overlap 
  --help                 | -h   => [optional] output this usage info and exit

USAGE:
  svLffTrackCoverage.rb  -s svcalls.lff -c geneList.lff -S genicSVs -C coveredGenes -a coveredGenes
";
			exit(2);
	end
end

end; end
########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = BRL::Pash::SVGenesCoverage.processArguments()
# Instantiate analyzer using the program arguments
boilerPlate = BRL::Pash::SVGenesCoverage.new(optsHash)
# Analyze this !
boilerPlate.work()
exit(0);
