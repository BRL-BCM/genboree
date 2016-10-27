#!/usr/bin/env ruby

=begin
=end
# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/lsf/lsfBatchJob'
require 'brl/dna/fastaRecord'
require 'GSL'
include GSL

module BRL ; module CAPSS

class PoolReadTrimmer
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	MIN_PHRED_QUAL = 20
	MIN_PASS_QUALS = 100
	MIN_PASS_SCREENS = 100
	# Retrieval command (base)
	JOB_NAME_BASE = 'cprs-'
	NOT_PROB_FON = 'noRegRepeats.noProblematic.reads.fon'
	PROB_FON = 'problematic.reads.fon'
	REPORT_FILE = 'reads/problemFinder.out'

	TOTAL_READS_RE = /Total number of reads in original overlap graph: (\d+)/
	INTRA_ONLY_READS_RE =	/Total number of reads with overlaps only in their own pool: (\d+)/
	PARA_EXC_READS_RE = /Total number of reads with overlaps in more than (\d+) parallel pools: (\d+)/
	INTER_EXC_READS_RE =	/Total number of reads with overlaps in more than (\d+) intersecting pools: (\d+)/
	TOTAL_PROB_READS_RE = /Total number of problematic reads: (\d+)/
	TOTAL_OK_READS_RE = /Total number of ok reads: (\d+)/
	BLANK_RE = /^\s*$/

	def initialize()
		@colPools = {}
		@rowPools = {}
		@arrayLayout = {}
		@avgBacLength = 200000
		@totalOrigReads = @intraOnlyReads = @paraExcReads = @interExcReads = @totalProbReads = @totalOKReads = 0
	end

	def run()
		@params = processArguments()
		loadArrayLayouts()
		$stderr.puts "STATUS: got array layouts"
		getReadStats()
		$stderr.puts "STATUS: got stats"
		dumpReadStats()
		return
	end

	def loadArrayLayouts()
		@params['--arrayList'].each { |arrayID|
			# open layout file
			layoutFileName = "#{@params['--layoutDir']}/array.#{arrayID}.layout.txt"
			reader = BRL::Util::TextReader.new(layoutFileName)
			# skip header row
			reader.readline()
			# grab col pools row
			fields = reader.readline().split("\t")
			fields.shift ; fields.shift
			fields.map! { |aa| aa.strip }
			fields.delete_if { |aa| aa.empty? }
			@colPools[arrayID] = fields
			@rowPools[arrayID] = []
			# process row pool lines
			@arrayLayout[arrayID] = []
			reader.each { |line|
				line.strip!
				next if(line =~ /^\s*$/ or line =~ /^\s*#/)
				fields = line.split("\t")
				fields.shift
				fields.map! { |aa| aa.strip }
				@rowPools[arrayID] << fields.shift
				@arrayLayout[arrayID] << fields
			}
			reader.close()
		}
		return
	end

	def	getReadStats()
		topDir = "#{@params['--topDir']}/poolProjects"
		@rowPools.keys.each { |arrayID|
			(@rowPools[arrayID] | @colPools[arrayID]).each { |poolID|
				projDir = "#{topDir}/array.#{arrayID}/#{poolID}"
				reportFileName = "#{projDir}/#{REPORT_FILE}"
				reportFile = BRL::Util::TextReader.new(reportFileName)
				reportFile.each { |line|
					line.strip!
					next if(line =~ BLANK_RE)
					if(line =~ TOTAL_READS_RE)
						@totalOrigReads += $1.to_i
					elsif(line =~ INTRA_ONLY_READS_RE)
						@intraOnlyReads += $1.to_i
					elsif(line =~ PARA_EXC_READS_RE)
						@paraExcReads += $2.to_i
						@numExcParaPools = $1.to_i
					elsif(line =~ INTER_EXC_READS_RE)
						@intersectExcReads = $1.to_i
						@interExcReads += $2.to_i
					elsif(line =~ TOTAL_PROB_READS_RE)
						@totalProbReads += $1.to_i
					elsif(line =~ TOTAL_OK_READS_RE)
						@totalOKReads += $1.to_i
					else
						# skip
					end
				}
			}
		}
		return
	end

	def dumpReadStats()
		puts "Total number of reads before problem finding: #{@totalOrigReads}"
		puts "Total number of reads with only overlaps within their own pool: #{@intraOnlyReads}"
		puts "Total number of reads with connections to > #{@numExcParaPools} to parallel pools: #{@paraExcReads}"
		puts "Total number of reads with connections to > #{@intersectExcReads} to intersecting pools: #{@interExcReads}"
		puts "Total number of problem reads: #{@totalProbReads}"
		puts "Total number of ok reads: #{@totalOKReads}"
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--topDir', '-t', GetoptLong::REQUIRED_ARGUMENT],
									['--arrayList', '-a', GetoptLong::REQUIRED_ARGUMENT],
									['--layoutDir', '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--verbose', '-v', GetoptLong::OPTIONAL_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		PROP_KEYS.each {
			|propName|
			argPropName = "--#{propName}"
			optsArray << [argPropName, GetoptLong::OPTIONAL_ARGUMENT]
		}
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		usage() if(optsHash.empty? or optsHash.key?('--help'))
		optsHash['--arrayList'] = optsHash['--arrayList'].split(',')
		@verbose = optsHash.key?('--verbose') ? true : false
		usage() unless(optsHash['--arrayList'].size > 0)
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -a     => Comma separated list of array numbers to get from database
    -l     => Dir where the array layout files (from capss-get-arrayLayouts) can be found.
    -f     => File-of-files with locations of all the read seq files to examine.
    -q     => File-of-files with locations of all the read qual files to examine. (same order)
    -b     => [200000, optional] Estimated average bac length.
    -p     => [100, optional] Min number of phred 20+ bases in a read to count as pass-qual
    -s     => [100, optional] Min number of non-screen bases in a read to cound as pass-screen
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-read-stats.rb -l ./mapsAndIndices -a 23,24 -f ./x2n.fof
";
		exit(134);
	end
end

end ; end

trimmer = BRL::CAPSS::PoolReadTrimmer.new()
trimmer.run()
exit(0)


