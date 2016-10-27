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

class ReadStats
	# CONSTANTSr
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	MIN_PHRED_QUAL = 20
	MIN_PASS_QUALS = 100
	MIN_PASS_SCREENS = 100
	# Retrieval command (base)
	JOB_NAME_BASE = 'crs-'

	def initialize()
		@colPools = {}
		@rowPools = {}
		@arrayLayout = {}
		@avgBacLength = 200000
	end

	def run()
		@params = processArguments()
		loadArrayLayouts()
		$stderr.puts "STATUS: got array layouts"
		loadFileOfFiles()
		$stderr.puts "STATUS: got fofs"
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

	def loadFileOfFiles()
		reader = BRL::Util::TextReader.new(@params['--faFof'])
		@faFofList = reader.readlines("\n")
		@faFofList.collect! { |xx| xx.strip }
		reader.close()
		reader = BRL::Util::TextReader.new(@params['--qualFof'])
		@qualFofList = reader.readlines("\n")
		@qualFofList.collect! { |xx| xx.strip }
		reader.close()
		return
	end

	def	getReadStats()
		#### ARJ 11/6/2003 1:36PM
		readStatFileName = "./readByRead.screen.stats.txt"
		readStatWriter = BRL::Util::TextWriter.new(readStatFileName)
		readStatWriter.puts "readID\tlength\tnumRealBases\tnumScreenBases\treal/total\tnumPassQualBases\tavgQual\tnumGABases\tGA/length"
		@readCounts = []
		@baseCounts = []
		@nonScreenedBaseCount = []
		@passQualReadCount = 0
		@passVectorReadCount = 0
		@numBacs = 0
		@rowPools.each { |arrayID, rowpools|
			@numBacs = @colPools[arrayID].size * @rowPools[arrayID].size
	}
		@faFofList.each_index { |ii|
			faFile = @faFofList[ii]
			qualFile = @qualFofList[ii]
			faFile += '.gz' unless(File.exists?(faFile))
			qualFile += '.gz' unless(File.exists?(qualFile))
			faRecHash = BRL::DNA::FastaSeqRecordHash.new(BRL::Util::TextReader.new(faFile))
			$stderr.print 's'
			qualRecHash = BRL::DNA::FastaQualRecordHash.new(BRL::Util::TextReader.new(qualFile))
			$stderr.print 'q'
			raise "ERROR: num records in #{faFile} not same as in #{qualFile}. Do the seq and qual FOF files have the same order?" unless(faRecHash.size == qualRecHash.size)
			@readCounts << faRecHash.size
			readProgress = 0
			faRecHash.each { |readName, faRec|
				readProgress += 1
				@baseCounts << faRec.seqLength()
				# does it pass min qual?
				qualRec = qualRecHash[readName]
				numPassQualBases = 0
				numQuals = 0
				sumQuals = 0
				#### ARJ 11/6/2003 3:05PM
				qualRec.qualities.split(' ').each { |xx| sumQuals += xx.to_i ; numQuals += 1 ; numPassQualBases += 1 if(xx.to_i >= MIN_PHRED_QUAL) }
				avgQual = sumQuals.to_f / numQuals.to_f
				#### ARJ 11/6/2003 1:41PM
				numGAs = faRec.countChars('GAga')
				readStatWriter.print "#{readName}\t#{faRec.seqLength()}\t#{faRec.countBases}\t#{faRec.seqLength() - faRec.countBases()}\t"
				readStatWriter.puts "#{sprintf('%.4f', faRec.countBases().to_f/faRec.seqLength().to_f)}\t#{numPassQualBases}\t#{sprintf('%.4f', avgQual)}\t#{numGAs}\t#{sprintf('%.4f', numGAs.to_f/faRec.countBases().to_f)}"
				unless(numQuals == faRec.seqLength())
					raise "ERROR: num quals (#{numQuals}) is not equal to num bases (#{faRec.seqLength()}) for read #{readName}"
				end
				$stderr.print 'p' if(readProgress % 1000 == 0)
				if(numPassQualBases >= @minNumPhred20Bases)
					@passQualReadCount += 1
					# does is pass min vector?
					realBases = faRec.countBases()
					@nonScreenedBaseCount << realBases
					if(realBases >= @minNonScreenBases)
						@passVectorReadCount += 1
					end
				end
				$stderr.print 'v' if(readProgress % 1000 == 0)
			}
			$stderr.print '.'
		}
		$stderr.puts ''
		#### ARJ 11/6/2003 1:41PM
		readStatWriter.close()
		return
	end

	def dumpReadStats()
		puts "Total Number of Bacs: #{@numBacs}"
		numReads = 0
		@readCounts.each { |xx| numReads += xx }
		puts "Total Number of Reads: #{numReads}"
		puts "Total Number of Reads Passing Min Quality: #{@passQualReadCount}"
		puts "Total Number of Reads Passing Min Quality and Min Non-Screen: #{@passVectorReadCount}"
		numBases = 0
		@baseCounts.each { |xx| numBases += xx }
		puts "Total Number of Bases: #{numBases}"
		puts "Average Number of Bases Per Read: #{GSL::Stats::mean(@baseCounts,1)} (sd: #{GSL::Stats::sd(@baseCounts,1)})"
		numNonVectorBases = 0
		@nonScreenedBaseCount.each { |xx| numNonVectorBases += xx }
		puts "Total Number of Non-Vector Bases: #{numNonVectorBases}"
		puts "Average Number of Non-Vector Bases Per Pass-Qual Read: #{GSL::Stats::mean(@nonScreenedBaseCount,1)} (sd: #{GSL::Stats::sd(@nonScreenedBaseCount,1)})"
		puts '-'*50
		puts "Average BAC coverage by bases: #{numBases / @numBacs} per BAC"
		puts "Average BAC coverage by non-vector bases: #{numNonVectorBases / @numBacs} per BAC"
		puts "Overall base coverage: #{numBases.to_f / (@numBacs.to_f * @avgBacLength)}X"
		puts "Overall non-vector coverage: #{numNonVectorBases.to_f / (@numBacs.to_f * @avgBacLength)}X"
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--arrayList', '-a', GetoptLong::REQUIRED_ARGUMENT],
									['--layoutDir', '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--faFof', '-f', GetoptLong::REQUIRED_ARGUMENT],
									['--qualFof', '-q', GetoptLong::REQUIRED_ARGUMENT],
									['--bacLength', '-b', GetoptLong::OPTIONAL_ARGUMENT],
									['--minPhred20Bases', '-p', GetoptLong::OPTIONAL_ARGUMENT],
									['--minNonScreenBases', '-s', GetoptLong::OPTIONAL_ARGUMENT],
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
		@avgBacLength = (optsHash.key?('--bacLength')) ? optsHash['--bacLength'].to_i : 200_000
		@minNumPhred20Bases = (optsHash.key?('--minPhred20Bases')) ? optsHash['--minPhred20Bases'].to_i : MIN_PASS_QUALS
		@minNonScreenBases = (optsHash.key?('--minNonScreenBases')) ? optsHash['--minNonScreenBases'].to_i : MIN_PASS_SCREENS
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

stats = BRL::CAPSS::ReadStats.new()
stats.run()
exit(0)
