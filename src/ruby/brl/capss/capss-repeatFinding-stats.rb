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

module BRL ; module CAPSS

class RepeatStats
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	JOB_NAME_BASE = 'crfs-'
	OUT_DIR = 'reads'
	REG_REP_FON = 'regRepeats.fon'
        ADJ_EXC_FON = 'overlappingExcessiveRepeats.fon'
        NOT_REG_REP_FON = 'notRegRepeats.fon'
        NOT_ADJ_EXC_FON = 'notRegRepeats.notOverlappingExc.fon'
	SINGLES_FON = 'singletons.fon'
	BLANK_RE = /^\s*$/

	def initialize()
		@colPools = {}
		@rowPools = {}
		@arrayLayout = {}
		
	end

	def run()
		@params = processArguments()
		loadArrayLayouts()
		getStats()
		puts "Total num reads regular repeats: #{@numRegRepeats}"
		puts "Total num reads overlapping excessive repeats: #{@numAdjExcRepeats}" 
		puts "Total Num Reads NOT regular repeats: #{@numNonRegRepeats}"
		puts "Total Num Reads also NOT overlapping excessive repeat: #{@numAlsoNotAdjExcRepeats}"
		puts "Total Num Singletons detected by overlapper # singles: #{@numSingletons}"
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

	def getStats()
		@numNonRegRepeats = 0
		@numAlsoNotAdjExcRepeats = 0
		@numRegRepeats = 0
		@numAdjExcRepeats = 0
		@numSingletons = 0
		topLevel = "#{@params['--topDir']}/poolProjects"
		origDir = Dir.pwd
		jobCount = 0
		@arrayLayout.each { |arrayID, rowArrays|
			$stderr.print "Array #{arrayID}: "
			(@rowPools[arrayID] | @colPools[arrayID]).each { |poolID|
				jobCount += 1
				projDir = "#{topLevel}/array.#{arrayID}/#{poolID}"
				nrrfFile = "#{projDir}/#{@outDir}/#{@nonRegRepFON}"
				neafFile = "#{projDir}/#{@outDir}/#{@nonExcAdjFON}"
				rrfFile = "#{projDir}/#{@outDir}/#{@regRepFON}"
				aerFile = "#{projDir}/#{@outDir}/#{@adjExcFON}"
				sfFile = "#{projDir}/#{@outDir}/#{@singlesFON}"
				unless(File.exists?(nrrfFile) and File.exists?(neafFile) and File.exists?(sfFile))
					$stderr.puts "\nWARNING: project #{poolID} doesn't have a #{@nonRegRepFON} and a #{@nonExcAdjFON} and a #{@singlesFON}\n"
					next
				end
				notRegFonReader = BRL::Util::TextReader.new(nrrfFile)
				notAdjExcFonReader = BRL::Util::TextReader.new(neafFile)
				singlesFonReader = BRL::Util::TextReader.new(sfFile)
				regRepReader = BRL::Util::TextReader.new(rrfFile)
				adjExcReader = BRL::Util::TextReader.new(aerFile)
				readHash = {}
				notRegFonReader.each { |line|
					line.strip!
					next if(line =~ BLANK_RE)
					readHash[line] = nil
				}
				notRegFonReader.close()
				@numNonRegRepeats += readHash.size
				readHash.clear()
				notAdjExcFonReader.each { |line|
					line.strip!
					next if(line =~ BLANK_RE)
					readHash[line] = nil
				}
				notAdjExcFonReader.close()
				@numAlsoNotAdjExcRepeats += readHash.size
				readHash.clear()
				singlesFonReader.each { |line|
					line.strip!
					next if(line =~ BLANK_RE)
					readHash[line] = nil
				}
				singlesFonReader.close()
				@numSingletons += readHash.size
				readHash.clear()
				regRepReader.each { |line|
					line.strip!
					next if(line =~ BLANK_RE)
					readHash[line] = nil
				}
				regRepReader.close()
				@numRegRepeats += readHash.size
				readHash.clear()
				adjExcReader.each { |line|
					line.strip!
					next if(line = ~ BLANK_RE)
					readHash[line] = nil
				}
				adjExcReader.close()
				@numAdjExcRepeats += readHash.size
				readHash.clear()
				$stderr.print '.'
			}
			$stderr.puts ''
		}
		$stderr.puts ''
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--topDir', '-t', GetoptLong::REQUIRED_ARGUMENT],
									['--outDir', '-o', GetoptLong::OPTIONAL_ARGUMENT],
									['--arrayList', '-a', GetoptLong::REQUIRED_ARGUMENT],
									['--layoutDir', '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--notRegRepeatList', '-r', GetoptLong::OPTIONAL_ARGUMENT],
									['--notRegRepNorAdjToExecessiveList', '-e', GetoptLong::OPTIONAL_ARGUMENT],
									['--regRepeatList', '-R', GetoptLong::OPTIONAL_ARGUMENT],
									['--excRepeatList', '-E', GetoptLong::OPTIONAL_ARGUMENT],
									['--singtonsList', '-s', GetoptLong::OPTIONAL_ARGUMENT],
									['--queue', '-q', GetoptLong::OPTIONAL_ARGUMENT],
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
		optsHash['--queue'] = DEFAULT_QUEUE unless(optsHash.key?('--queue'))
		@verbose = optsHash.key?('--verbose') ? true : false
		@outDir = optsHash.key?('--outDir') ? optsHash['--outDir'] : OUT_DIR
		@nonRegRepFON = optsHash.key?('--notRegRepeatList') ? optsHash['--notRegRepeatList'] : NOT_REG_REP_FON
		@nonExcAdjFON = optsHash.key?('--notRegRepNorAdjToExecessiveList') ? optsHash['--notRegRepNorAdjToExecessiveList'] : NOT_ADJ_EXC_FON
		@regRepFON = optsHash.key?('--regRepeatList') ? optsHash['--regRepeatList'] : REG_REP_FON
		@adjExcFON = optsHash.key?('--excRepeatList') ? optsHash['--excRepeatList'] : ADJ_EXC_FON
		@singlesFON = optsHash.key?('--singtonsList') ? optsHash['--singtonsList'] : SINGLES_FON
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
    -t     => Top-level output dir where to put project dir-trees for each array
    -o     => [optional, 'reads'] Where to put various repeat list files, pruned graph files, etc, under the project dir tree.
    -a     => Comma separated list of array IDs (use array #'s from database if you have them)
    -l     => Dir where the array layout files (from capss-get-arrayLayouts) can be found.
    -r     => [optional] File-of-names of non-repeat reads ('noRegRepeats.fon')
    -e     => [optional] File-of-names of non-repeat and non-adjacent to excessive repeat reads ('noRegRepeats.noneOverlappingExcessiveRepeats.fon')
    -q     => [optional] LSF cluster to use. Default is 'linux'.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-launch-repeatFinder.rb -t ./poolReads -l ./mapsAndIndices -a 23,24
";
		exit(134);
	end
end

end ; end

stats = BRL::CAPSS::RepeatStats.new()
stats.run()
exit(0)
