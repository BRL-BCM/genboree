#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'gsl'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/util/logger'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/lffStats'

include BRL::Genboree

module BRL ; module Genboree

$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

module LFFStats

	# ############################################################################
	# CLASS: Stats
	# - Superclass for all specific stats classes. Common code & properties.
	# - extend this class by defining methods for dumping text reports
	# ############################################################################
	class Stats
		# --------------------------------------------------------------------------
		def dumpCountPerChromReport(typeStr='')
			puts <<-EOT
  Number of #{typeStr}s: #{commify(@count)}
  Number of #{typeStr}s Per Reference Sequence:
			EOT
			printf '    Name: '; printf "%13.13s\n", 'Count:'
			printf '    ----- '; printf "%13.13s\n", '------'
			@countPerEntryPoint.keys.sort{ |aa, bb|
				xx = (aa =~ BRL::Genboree::LFFStats::CHR_SORT_RE) ? $1 : aa
				yy = (bb =~ BRL::Genboree::LFFStats::CHR_SORT_RE) ? $1 : bb
				if(xx =~ DIGIT_RE and yy =~ DIGIT_RE)
					xx.to_i <=> yy.to_i
				else
					xx <=> yy
				end
			} .each { |name|	printf "    %*s ", @maxNameLength, name ; printf "%13.13s\n", commify(@countPerEntryPoint[name])}
			return
		end # def dumpCountPerChromReport(typeStr='')
		
		# --------------------------------------------------------------------------
		def dumpLengthReport(typeStr='')
			puts <<-EOT

  #{typeStr} Length:
    Mean (stdev): #{commify(sprintf('%.002f', @avgLength))} (#{commify(sprintf('%.002f', @sdLength))})
    Median:       #{commify(sprintf('%.002f', @medianLength))}
    N50:          #{commify(sprintf('%.002f', @n50Length))}
    Min:          #{commify(sprintf('%.002f', @minLength))}
    Max:          #{commify(sprintf('%.002f', @maxLength))}
				EOT
			return
		end # def dumpLengthReport(typeStr='')
		
		# --------------------------------------------------------------------------
		def dumpLengthHistogramReport(typeStr='')
			maxHist = @lengthHistogram.max.to_i.to_s.size+((@lengthHistogram.max.to_i / 1000).floor).to_s.size
			maxHistWidth = (maxHist*2+3).to_i.to_s.size
			puts "\n  #{typeStr} Length Distribution (#{BRL::Genboree::LFFStats::Stats::NUM_HISTO_BINS} bins):"
			printf('    %*s', maxHistWidth, 'Length Range:')
			printf((' '*(maxHistWidth+10) + "%*s\n"), commify(@count).size+8, 'Count:')
			printf('    %*s', maxHistWidth, '-------------')
			printf((' '*(maxHistWidth+10) + "%*s\n"), commify(@count).size+8, '------')
			@lengthHistogram.bins.times { |binIdx|
				min,max = @lengthHistogram.get_range(binIdx)
				min,max = min.to_i,max.to_i
				printf('%*s - ', maxHist, commify(min))
				printf('%*s', maxHist, commify(max))
				printf((' '*(maxHistWidth+10) + "%*s"), commify(@count).size, commify(@lengthHistogram[binIdx].to_i))
				puts ''
			}		
			return
		end # def dumpLengthHistogramReport(typeStr='')
		
		# --------------------------------------------------------------------------
		def dumpCoverageReport(typeStr='')
			puts <<-EOT
			
  #{typeStr} Coverage:
    Sum of #{typeStr} Lengths:                      #{commify(@sumLengths)}
    Overall #{typeStr} Coverage:                    #{sprintf('%.00004f X', @refSeqCover)}
    #{typeStr} Coverage By Reference Sequence:
			EOT
			printf '        Name: '; printf "%13.13s\n", 'Coverage:'
			printf '        ----- '; printf "%13.13s\n", '---------'
			@chrCoverages.keys.sort { |aa, bb|
  			xx = (aa =~ BRL::Genboree::LFFStats::CHR_SORT_RE) ? $1 : aa
  			yy = (bb =~ BRL::Genboree::LFFStats::CHR_SORT_RE) ? $1 : bb
  			if(xx =~ DIGIT_RE and yy =~ DIGIT_RE)
  				xx.to_i <=> yy.to_i
  			else
  				xx <=> yy
  			end
			}.each { |name|
			  printf "        %*s ", @maxNameLength, name
			  if(@chrCoverages[name])
			    printf "%13.13s\n", sprintf('%.00004f X', @chrCoverages[name])
			  else
			    printf "%13.19s\n", "UNKNOWN CHR LENGTH!"
			  end
			}
			return
		end # def dumpCoverageReport(typeStr='')
		
		# --------------------------------------------------------------------------
		def dumpScoreReport(typeStr='', header='Scores')
			puts <<-EOT
			
  #{header}:
    Mean (stdev): #{commify(sprintf('%.002f', @avgScore))} (#{commify(sprintf('%.002f', @sdScore))})
    Median:       #{commify(sprintf('%.002f', @medianScore))}
    Min:          #{commify(sprintf('%.002f', @minScore))}
    Max:          #{commify(sprintf('%.002f', @maxScore))}			
			EOT
			return
		end # def dumpScoreReport(typeStr='')
		
		# --------------------------------------------------------------------------
		def dumpScoreDensitiyReport(typeStr='', header='Score Densities (score / bp length)')
			puts <<-EOT
			
  #{header}:
    Mean (stdev): #{commify(sprintf('%.002f', @avgScoreDensity))} (#{commify(sprintf('%.002f', @sdScoreDensity))})
    Median:       #{commify(sprintf('%.002f', @medianScoreDensity))}
    Min:          #{commify(sprintf('%.002f', @minScoreDensity))}
    Max:          #{commify(sprintf('%.002f', @maxScoreDensity))}
    	EOT
			return
		end # def dumpScoreDensitiyReport(typeStr='')
		
		# --------------------------------------------------------------------------
		def dumpScoreHistogramReport(typeStr='')
			maxHist = @scoreHistogram.max.to_i.to_s.size+5
			maxHistWidth = (maxHist*2+3).to_i.to_s.size
			puts "\n  #{typeStr} Score Distribution (#{BRL::Genboree::LFFStats::Stats::NUM_HISTO_BINS} bins):"
			printf('    %*s', maxHistWidth, '  Score Range:')
			printf((' '*(maxHistWidth+10) + "%*s\n"), commify(@count).size+8, 'Count:')
			printf('    %*s', maxHistWidth, '  ------------')
			printf((' '*(maxHistWidth+10) + "%*s\n"), commify(@count).size+8, '------')
			@scoreHistogram.bins.times { |binIdx|
				min,max = @scoreHistogram.get_range(binIdx)
				min,max = sprintf('%.00004f', min.to_f),sprintf('%.00004f', max.to_f)
				printf('    %*s - ', maxHist, min)
				printf('%*s', maxHist, max)
				printf((' '*(maxHistWidth+10) + "%*s"), commify(@count).size, commify(@scoreHistogram[binIdx].to_i))
				puts ''
			}
			return
		end # def dumpScoreHistogramReport(typeStr='')
	end # class Stats
	
	# ----------------------------------------------------------------------------
	# CLASS: AnnoStats
	# - extend this class by defining methods for dumping text reports
	# ----------------------------------------------------------------------------
	class AnnoStats
		TYPE_STR = 'Individual Annotation'
		
		# --------------------------------------------------------------------------
		def dumpReport()
			puts <<-EOT
			
			
	----------------------------------------------------------------------------		
  B. STATS FOR INDIVIDUAL ANNOTATIONS
  ----------------------------------------------------------------------------
  		EOT
			self.dumpCountPerChromReport(TYPE_STR)
			self.dumpLengthReport(TYPE_STR)
			self.dumpLengthHistogramReport(TYPE_STR)
			self.dumpCoverageReport(TYPE_STR)			
			self.dumpScoreReport(TYPE_STR, 'Individual Annotation Scores')
			self.dumpScoreDensitiyReport(TYPE_STR, 'Individual Annotation Score Densities (score / bp length)')
			self.dumpScoreHistogramReport(TYPE_STR)
			return		
		end # dumpReport()
	end # class AnnoStats
	
	# ############################################################################
	# CLASS: GroupStats
	# ############################################################################
	class GroupStats
		TYPE_STR = 'Annotation Group'
		
		# --------------------------------------------------------------------------
		def dumpReport()
			puts <<-EOT
			
			
	----------------------------------------------------------------------------
  C. STATS FOR ANNOTATION GROUPS
     - these are stats on a group-basis (i.e. genes)
       rather than annotation basis (i.e. exons)
     - if each annotation is alone in its group, these number are the same as in B.
  ----------------------------------------------------------------------------
  		EOT
			self.dumpCountPerChromReport(TYPE_STR)
			self.dumpLengthReport(TYPE_STR)
			self.dumpLengthHistogramReport(TYPE_STR)
			self.dumpCoverageReport(TYPE_STR)			
			self.dumpScoreReport(TYPE_STR, 'Annotations Per Group')
			self.dumpScoreDensitiyReport(TYPE_STR, 'Annotations Per Group BasePair (rough estimate)')			
			return 
		end
	end # class GroupStats
	
	# ############################################################################
	# CLASS: RegionStats
	# ############################################################################
	class RegionStats
		TYPE_STR = 'Projection Region'
		
		# --------------------------------------------------------------------------
		def dumpReport()
			puts <<-EOT
			
			
	----------------------------------------------------------------------------
  D. STATS FOR PROJECTION REGIONS
     - projection regions are the regions of the genome covered by annotations
     - thus, these regions do not overlap
  ----------------------------------------------------------------------------
  		EOT
			self.dumpCountPerChromReport(TYPE_STR)
  		puts "  Total Number of Projection Regions Involving *Overlapping* Annotations: #{@numMergings}"
			self.dumpLengthReport(TYPE_STR)
			self.dumpLengthHistogramReport(TYPE_STR)
			self.dumpCoverageReport(TYPE_STR)			
			self.dumpScoreReport(TYPE_STR, 'Annotations Per Projection Region')
			self.dumpScoreDensitiyReport(TYPE_STR, 'Annotations Per Projection Region BasePair (rough estimate)')			
			return
		end # def dumpReport()
	end # class RegionStats
	
	# ############################################################################
	# CLASS: RegionStats
	# ############################################################################
	class GapStats
		TYPE_STR = 'Gap'
		
		# --------------------------------------------------------------------------
		def dumpReport()
			puts <<-EOT
	
	
	----------------------------------------------------------------------------
  E. GAPS BETWEEN PROJECTION REGIONS
     - projection regions are the regions of the genome covered by annotations
     - thus, the gaps are the regions of the genome NOT covered by annotations
	----------------------------------------------------------------------------
			EOT
			self.dumpCountPerChromReport(TYPE_STR)
			self.dumpLengthReport(TYPE_STR)
			self.dumpLengthHistogramReport(TYPE_STR)
			self.dumpCoverageReport(TYPE_STR)			
			return
		end # def dumpReport()
	end # class GapStats
	
	# ############################################################################
	# CLASS: LFFStatsTextReport
	# ############################################################################
	class LFFStatsTextReport
		attr_accessor :optsHash, :refSeqFile, :lffFileName, :trackName, :lffStats
	
		# --------------------------------------------------------------------------
		def initialize()
			@optsHash = processArguments()
			@lffStats = BRL::Genboree::LFFStats::LFFStats.new(@lffFileName, @refSeqFile, @trackName)
			@lffStats.loadData()
			if(@lffStats.lffRecords.size < 1)
				exitWithMessage("ERROR: There are no '#{@trackName.to_s}' annotations in the file!!")
			end
			GC.start()
		end # def initialize()
	
		# --------------------------------------------------------------------------
		def exitWithMessage(message)
			puts "\n\n#{message}\n\n"
			exit(135)
		end # def exitWithMessage(message)

		# --------------------------------------------------------------------------
		def run()
			$stderr.puts "#{Time.now.to_s} STATUS: LFFStatsReport instantiated."
			@lffStats.init()
			$stderr.puts "#{Time.now.to_s} STATUS: LFFStatsReport initialized."
			$stderr.puts "#{Time.now.to_s} START: compute annotation statistics..."
			@lffStats.annoStats.computeStats(@lffStats.lffRecords) ; GC.start()
			$stderr.puts "#{Time.now.to_s} END: ...computed annotation sequence statistics."
			$stderr.puts "#{Time.now.to_s} START: compute group statistics..."
			@lffStats.groupStats.computeStats(@lffStats.lffRecords, @lffStats.annoStats.medianLength) ; GC.start()
			$stderr.puts "#{Time.now.to_s} END: ...computed group sequence statistics."
			$stderr.puts "#{Time.now.to_s} START: compute projection region & gap statistics..."
			@lffStats.regionStats.computeStats(@lffStats.lffRecords, @lffStats.annoStats.medianLength)
			@lffStats.gapStats = @lffStats.regionStats.gapStats
			$stderr.puts "#{Time.now.to_s} END: ...computed projection region & gap statistics."
			dumpReport()
			return
		end # def run()

		# --------------------------------------------------------------------------
		def dumpReport() # Coordinate the dumping of reports from the stats objects in @lffStats
			puts <<-EOT
  ============================================================================
  DESCRIPTIVE STATISTICS FOR '#{trackName}'
  ============================================================================
			EOT
			self.dumpRefSeqSection()
			@lffStats.annoStats.dumpReport()
			@lffStats.groupStats.dumpReport()
			@lffStats.regionStats.dumpReport()
			@lffStats.gapStats.dumpReport()
			puts <<-EOT
  ============================================================================
  
  		EOT
			return
		end # def dumpReport()
		
		# --------------------------------------------------------------------------
		def dumpRefSeqSection()
			puts <<-EOT
			
			
  A. REFERENCE SEQUENCES
  ----------------------
  Number of Reference Sequences: #{@lffStats.refSeqs.size}
  Total Length of Reference Sequences: #{commify(@lffStats.annoStats.sumRefSeqLengths)}
  Reference Sequence Lengths:
			EOT
			printf '    Name: '; printf "%13.13s\n", 'Length:'
			printf '    ----- '; printf "%13.13s\n", '-------'	
			@maxNameLength = 0 ; @lffStats.refSeqs.keys.each { |name| @maxNameLength = name.size if(name.size > @maxNameLength) }
			@lffStats.annoStats.maxNameLength = @lffStats.groupStats.maxNameLength = @lffStats.regionStats.maxNameLength = @lffStats.gapStats.maxNameLength = @maxNameLength
			@lffStats.refSeqs.keys.sort { |aa, bb|
				xx = (aa =~ BRL::Genboree::LFFStats::CHR_SORT_RE) ? $1 : aa
				yy = (bb =~ BRL::Genboree::LFFStats::CHR_SORT_RE) ? $1 : bb
				if(xx =~ DIGIT_RE and yy =~ DIGIT_RE)
					xx.to_i <=> yy.to_i
				else
					xx <=> yy
				end
			} .each { |name|	printf "    %*s ", @maxNameLength, name ; printf "%13.13s\n", commify(@lffStats.refSeqs[name])}
			return
	 end # def dumpRefSeqSection()
			
	def processArguments()
		optsArray =	[
									['--refSeqFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
									['--lffFile', '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--trackName', '-t', GetoptLong::REQUIRED_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		usage() if(optsHash.empty? or optsHash.key?('--help'))
		usage("USER ERROR: invalid reference sequence file.") unless(optsHash.key?('--refSeqFile') or !File.exist?(optsHash['--refSeqFile']))
		@refSeqFile = optsHash['--refSeqFile']
		usage("USER ERROR: invalid LFF file.") unless(optsHash.key?('--lffFile') or !File.exist?(optsHash['--lffFile']))
		@lffFileName = optsHash['--lffFile']
		usage("USER ERROR: invalid track name. Check format of track name is correct.") unless(optsHash.key?('--trackName') or !(optsHash['-trackName'].strip =~ TRACKNAME_RE))
		@trackName = optsHash['--trackName']
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:
	Computes and outputs stats related to the annotations of a particular track in
	an LFF file. Degree of overall coverage, per-chromosome-coverage, length
	distributions, length N50s, score distributions, and similar stats are
	presented.

	You need to supply a reference seqeunce file (with LFF reference sequence
	records) which define the chromosomes on which your annotations lie.

	You need to supply the LFF file which has the annotations you want to analyse.

	You need to give the track name (in simple '<type>:<subtype>' format) that
	you want to produce stats for.

  COMMAND LINE ARGUMENTS:
    --refSeqFile | -r     => Reference sequence file name with chromosome info.
    --lffFile    | -l     => LFF file with your annotations.
    --trackName  | -t     => Name of the track to analyse. Eg: 'WGS:MatePairs'
    --help       | -h     => [optional flag] Output this usage info and exit.

  USAGE EXAMPLE:
    lffStats.rb -r myRefSeq.lff -l myAnnotations.lff -t 'WGS:MatePairs'

";
		exit(134);
	end
	end # class LFFStatsReport
end # module LFFStats

end ; end # module BRL ; module Genboree

# ##############################################################################
# MAIN
# ##############################################################################
$stderr.puts "INFO: GSL Version (1.5+ I hope): #{GSL::VERSION}"
report = BRL::Genboree::LFFStats::LFFStatsTextReport.new()
report.run()
exit(0)
