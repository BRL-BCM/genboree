#!/usr/bin/env ruby

=begin
=end
# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/dna/fastaRecord'
require 'GSL'
include GSL

module BRL ; module DNA

class ReadStats
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	MIN_PHRED_QUAL = 20
	MIN_PASS_QUALS = 100
	MIN_PASS_SCREENS = 100

	def initialize()

	end

	def run()
		@params = processArguments()
		loadFileOfFiles()
		$stderr.puts "STATUS: got fofs"
		getReadStats()
		$stderr.puts "STATUS: got stats"
		dumpReadStats()
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
		readStatFileName = "./readByRead.screen.stats.txt"
		readStatWriter = BRL::Util::TextWriter.new(readStatFileName)
		readStatWriter.puts "readID\tlength\tnumNonScreenBases\tnumScreenBases\tnonScreen/total\tnumPassQualBases\tavgQual\tnumGABases\tGA/totalLength\tnumNonvectorPassQualBases\tavgNonvectorQual"
		@readCounts = []
		@baseCounts = []
		@nonScreenedBaseCount = []
		@passQualReadCount = 0
		@passVectorReadCount = 0

		@faFofList.each_index { |ii|
			faFile = @faFofList[ii]
			qualFile = @qualFofList[ii]
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
				#### RAH 11/20/2003
				arrQualities = qualRec.qualities.split(' ')
				seqIndex = 0
				numNonvectorPassQual = 0
				numNonvectorQual = 0
				sumNonvectorQual = 0

				faRec.sequence.scan(/./) {
					| base |

					unless((base == "x") || (base == "X"))
						quality = arrQualities[seqIndex]

						if(quality.to_i >= MIN_PHRED_QUAL)
							numNonvectorPassQual += 1
						end

						numNonvectorQual += 1
						sumNonvectorQual += quality.to_i
					end

					seqIndex += 1
				}
				avgNonvectorQual = sumNonvectorQual.to_f/numNonvectorQual.to_f

				arrQualities.each { |xx| sumQuals += xx.to_i ; numQuals += 1 ; numPassQualBases += 1 if(xx.to_i >= MIN_PHRED_QUAL) }
				avgQual = sumQuals.to_f / numQuals.to_f
				#### ARJ 11/6/2003 1:41PM
				numGAs = faRec.countChars('GAga')
				readStatWriter.print "#{readName}\t#{faRec.seqLength()}\t#{faRec.countBases}\t#{faRec.seqLength() - faRec.countBases()}\t"
				readStatWriter.puts "#{sprintf('%.4f', faRec.countBases().to_f/faRec.seqLength().to_f)}\t#{numPassQualBases}\t#{sprintf('%.4f', avgQual)}\t#{numGAs}\t#{sprintf('%.4f', numGAs.to_f/faRec.seqLength().to_f)}\t#{numNonvectorPassQual}\t#{sprintf('%.4f', avgNonvectorQual)}"
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
		return
	end

	def dumpReadStats()
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
		puts "Total Number of Non-Vector Bases in Pass-Qual Reads: #{numNonVectorBases}"
		puts "Average Number of Non-Vector Bases Per Pass-Qual Read: #{GSL::Stats::mean(@nonScreenedBaseCount,1)} (sd: #{GSL::Stats::sd(@nonScreenedBaseCount,1)})"
		puts '-'*50
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--faFof', '-f', GetoptLong::REQUIRED_ARGUMENT],
									['--qualFof', '-q', GetoptLong::REQUIRED_ARGUMENT],
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
		@verbose = optsHash.key?('--verbose') ? true : false
		@minNumPhred20Bases = (optsHash.key?('--minPhred20Bases')) ? optsHash['--minPhred20Bases'].to_i : MIN_PASS_QUALS
		@minNonScreenBases = (optsHash.key?('--minNonScreenBases')) ? optsHash['--minNonScreenBases'].to_i : MIN_PASS_SCREENS
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -f     => File-of-files with locations of all the read seq files to examine.
    -q     => File-of-files with locations of all the read qual files to examine. (same order)
    -p     => [100, optional] Min number of phred 20+ bases in a read to count as pass-qual
    -s     => [100, optional] Min number of non-screen bases in a read to cound as pass-screen
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    read-stats.rb -l ./mapsAndIndices -a 23,24 -f ./x2n.fof
";
		exit(134);
	end
end

end ; end

stats = BRL::DNA::ReadStats.new()
stats.run()
exit(0)
