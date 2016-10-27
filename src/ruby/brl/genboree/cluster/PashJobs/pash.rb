#!/usr/bin/env ruby
require 'fileutils'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'pashUtils'

class PashMap
  DEBUG = true
  DEBUG_LEVEL = 2
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end

  def setParameters()
		@queryFile = @optsHash['--queryFile']
		if (!File.exists?(@queryFile)) then
			$stderr.puts "Query file #{@queryFile} not found!"
			exit(1)
		end

    if (@optsHash.key?('--genomeReferenceDir')) then
		  @referenceEnvDirectory  = @optsHash['--genomeReferenceDir']
		else
			@genomeReference = @optsHash['--genomeReference']
			if (!File.exists?(@genomeReference)) then
				$stderr.puts "Query file #{@genomeReference} not found!"
				exit(1)
			end
			@referenceEnvDirectory = "#{File.dirname(@genomeReference)}/PashMappingEnv_#{File.basename(@genomeReference)}"
		end
		# check if genome reference was prepared
		if (!File.exists?(@referenceEnvDirectory)) then
			$stderr.puts "Mapping env of the reference genome #{@referenceEnvDirectory} not found"
			exit(1)
		end
		@readsType = @optsHash['--readsType']
		if (@readsType != "454" && @readsType!="Sanger"&&@readsType!="Solexa") then
			$stderr.puts "Accepted read types  are 454, Solexa, and Sanger."
			exit(1)
		end
		@scratchDirectory = @optsHash['--scratchDirectory']
		@outputFile = @optsHash['--outputFile']
		if (@optsHash.key?("--xmOutput")) then
			@xmOutput = true
		else
			@xmOutput = false
		end
		if (@optsHash.key?("--topPercent")) then
			@topPercent = @optsHash["--topPercent"].to_f/100
		else
			@topPercent = 0.01
		end
		if (@optsHash.key?("--maxNumberOfTopMappings")) then
			@maxNumberOfTopMappings = @optsHash["--maxNumberOfTopMappings"].to_i
		else
			@maxNumberOfTopMappings = 1
		end
		@minIdentity = 0.9
		if (@optsHash.key?("--minIdentity")) then
			@minIdentity = @optsHash['--minIdentity'].to_f
		end

		if (@xmOutput && @readsType!="454") then
			$stderr.puts "cross_match output is currently supported only for 454 reads"
			exit(2)
		end
  end

  def buildReadIndex()
		fastaOffset = 0
		scoreOffset = 0
		@numberOfQuerySequences = 0
		@querySequenceSize = 0
		@maxQuerySize = 0
		@queryOffsetFileName = "#{@fullScratchDir}#{File::SEPARATOR}#{File.basename(@queryFile)}.off"
		@querySequenceFileName = "#{@fullScratchDir}#{File::SEPARATOR}#{File.basename(@queryFile)}.seq"
		queryOffsetWriter = File.open(@queryOffsetFileName, "w")
		querySequenceWriter = File.open(@querySequenceFileName, "w")
		tmpMaxSequenceSize = 0
		tmpNumberOfSequences = 0
		tmpSequenceSize=0
		qualityFileRoot = nil
		qualityScoreFileName = nil
		qualityScoreFileReader = nil
		@qualityOffsetFileName = nil
		@qualityScoresFileName = nil
		qualityOffsetWriter = nil
		qualityScoreWriter = nil
		tmpNumberOfSequencesQual = 0
		tmpSequenceSizeQual = 0
		tmpMaxSequenceSizeQual = 0
		if (@xmOutput && readsType=="454")
			@qualityOffsetFileName= "#{@fullScratchDir}#{File::SEPARATOR}#{File.basename(@queryFile)}.qual.off"
			@qualityScoresFileName= "#{@fullScratchDir}#{File::SEPARATOR}#{File.basename(@queryFile)}.qual.seq"
			qualityOffsetWriter = File.open(@qualityOffsetFileName, "w")
			qualityScoreWriter= File.open(@qualityScoresFileName, "w")
		end
		# add part that indexes quality scores files
		if (@queryFile =~ /\.fof/) then
			r = File.open(@queryFile,"r")
			r.each {|l|
				l.strip!
				queryFileReader = File.open(l, "r")
				(tmpNumberOfSequences, tmpSequenceSize, tmpMaxSequenceSize, fastaOffset) =
					PashUtils::indexFastaFile(queryFileReader, querySequenceWriter, queryOffsetWriter, fastaOffset)
				$stderr.puts "Tmp number of sequences: #{tmpNumberOfSequences}" if (DEBUG)
				$stderr.puts "Tmp sequence size: #{tmpSequenceSize}" if (DEBUG)
				$stderr.puts "Tmp tmp max sequence size: #{tmpMaxSequenceSize}" if (DEBUG)
				@numberOfQuerySequences+= tmpNumberOfSequences
				@querySequenceSize += tmpSequenceSize
				if (@maxQuerySize < tmpMaxSequenceSize) then
					@maxQuerySize = tmpMaxSequenceSize
				end
				$stderr.print "fa: #{tmpNumberOfSequences} #{tmpSequenceSize} #{tmpMaxSequenceSize}" if (DEBUG)
				queryFileReader.close()
				if (@xmOutput && @readsType=="454") then
					l =~/(.*)\.(fna|fa)/
					qualityFileRoot = $1
					qualityFileNameCandidates = Dir["#{qualityFileRoot}*qual*"]
					if (qualityFileNameCandidates == nil) then
						$stderr.puts "could not find quality file for #{l}"
						return 1
					elsif (qualityFileNameCandidates.size>1) then
						$stderr.print "multiple candidates found for quality files for #{l}: #{qualityFileNameCandidates.join("\t")}"
						return 1
					else
						qualityScoreFileName = qualityFileNameCandidates[0]
						$stderr.puts "quality file name #{qualityScoreFileName}" if (DEBUG)
					end
					qualityScoreFileReader = BRL::Util::TextReader.new(qualityScoreFileName)
					(tmpNumberOfSequencesQual, tmpSequenceSizeQual, tmpMaxSequenceSizeQual, scoreOffset) =
						PashUtils::index454QualityFile(qualityScoreFileReader, qualityScoreWriter, qualityOffsetWriter, scoreOffset)
					$stderr.print "fa: #{tmpNumberOfSequencesQual} #{tmpSequenceSizeQual} #{tmpMaxSequenceSizeQual}" if (DEBUG)
					if (tmpNumberOfSequencesQual!=tmpNumberOfSequences || tmpSequenceSizeQual!=tmpSequenceSize ||
							tmpMaxSequenceSizeQual != tmpMaxSequenceSize) then
						$stderr.puts "Inconsistency between #{l} and #{qualityScoresFileName}"
						return 1
					end
					qualityScoreFileReader.close()
					$stderr.puts "quality file root is #{$1}"
				end
			}
			r.close()
		else
			queryFileReader = File.open(@queryFile, "r")
			(tmpNumberOfSequences, tmpSequenceSize, tmpMaxSequenceSize, fastaOffset) =
				PashUtils::indexFastaFile(queryFileReader, querySequenceWriter, queryOffsetWriter, fastaOffset)
			$stderr.puts "Tmp number of sequences: #{tmpNumberOfSequences}" if (DEBUG)
			$stderr.puts "Tmp sequence size: #{tmpSequenceSize}" if (DEBUG)
			$stderr.puts "Tmp tmp max sequence size: #{tmpMaxSequenceSize}" if (DEBUG)
			@numberOfQuerySequences+= tmpNumberOfSequences
			@querySequenceSize += tmpSequenceSize
			if (@maxQuerySize < tmpMaxSequenceSize) then
				@maxQuerySize = tmpMaxSequenceSize
			end
			queryFileReader.close()
			if (@xmOutput && @readsType=="454") then
				@queryFile =~/(.*)\.(fna|fa)/
				qualityFileRoot = $1
				$stderr.puts "quality file root is #{qualityFileRoot}" if (DEBUG)
				qualityFileNameCandidates = Dir["#{qualityFileRoot}*qual*"]
				$stderr.puts "qualityFileNameCandidates #{qualityFileNameCandidates}" if (DEBUG)
				if (qualityFileNameCandidates == nil) then
					$stderr.puts "could not find quality file for #{@queryFile}"
					return 1
				elsif (qualityFileNameCandidates.size>1) then
					$stderr.print "multiple candidates found for quality files for #{l}: #{qualityFileNameCandidates.join("\t")}"
					return 1
				else
					qualityScoreFileName = qualityFileNameCandidates[0]
					$stderr.puts "quality file name #{qualityScoreFileName}" if (DEBUG)
				end
				qualityScoreFileReader = BRL::Util::TextReader.new(qualityScoreFileName)
				(tmpNumberOfSequencesQual, tmpSequenceSizeQual, tmpMaxSequenceSizeQual, scoreOffset) =
					PashUtils::index454QualityFile(qualityScoreFileReader, qualityScoreWriter, qualityOffsetWriter, scoreOffset)
				$stderr.print "fa: #{tmpNumberOfSequencesQual} #{tmpSequenceSizeQual} #{tmpMaxSequenceSizeQual}" if (DEBUG)
				if (tmpNumberOfSequencesQual!=tmpNumberOfSequences || tmpSequenceSizeQual!=tmpSequenceSize ||
						tmpMaxSequenceSizeQual != tmpMaxSequenceSize) then
					$stderr.puts "Inconsistency between #{@queryFile} and #{qualityScoreFileName}"
 					exit 1
					return 1
				end
				qualityScoreFileReader.close()

			end
		end
		queryOffsetWriter.close()
		querySequenceWriter.close()
		if (@xmOutput && readsType=="454")
			qualityOffsetWriter.close()
			qualityScoreWriter.close()
		end
		# also determine avg size
		@avgReadSize = @querySequenceSize/@numberOfQuerySequences
		$stderr.puts "Loaded #{@numberOfQuerySequences} sequences, with a total size of #{@querySequenceSize} bases, maximum query length #{@maxQuerySize} and average query length of #{@avgReadSize}"
  end

	def createFullScratchDirectory()
		if (File.exist?(@scratchDirectory)) then
			@removeScratchDir = false
		else
			@removeScratchDir = true
		end
		@fullScratchDir = "#{@scratchDirectory}/pashMap.#{Process.pid}"
		begin
			FileUtils.mkdir_p(@fullScratchDir, :verbose=>true)
		rescue Exception => e
			$stderr.puts "Could not create temporary directory #{@fullScratchDir}\n#{e.message}\n#{e.backtrace.join("\n")}"
			return false
		end
		return true
	end

  def setMappingParams()
		quantile_995cmd = "sort -k3,3n #{@queryOffsetFileName}|tail -#{@numberOfQuerySequences*5/1000+1}|head -1|cut -f3"
		$stderr.puts "quantile command #{quantile_995cmd}"
		qRes = `#{quantile_995cmd}`.to_i + 1
						@maxQuerySize=qRes.to_i
						$stderr.puts "@maxSize reduced to #{@maxQuerySize}"
		# can change the parameters based on the avg size
		# under 100, between 100 and 400, over 400
		if (@maxQuerySize>1000)
			@numberOfDiagonals = 1000
		else
			@numberOfDiagonals = @maxQuerySize
		end
		if (@maxNumberOfTopMappings<=20) then
			@ignoreList = "#{@referenceEnvDirectory}/ref.k12.n18.75p.ignoreList"
		else
			@ignoreList = "#{@referenceEnvDirectory}/ref.k12.n18.95p.ignoreList"
		end

		if (@avgReadSize<=50) then
			@mapParams = " -d #{@numberOfDiagonals} -f 0 -l #{@numberOfDiagonals-1} -i 0 -a  #{@numberOfDiagonals-1} -k 12 -n 18 -s 30 -g 1 -G 2 -L #{@ignoreList} -O 24000 -M 10"
		elsif (@avgReadSize<=100) then
			@mapParams = " -d #{@numberOfDiagonals} -f 0 -l #{@numberOfDiagonals-1} -i 0 -a  #{@numberOfDiagonals-1} -k 12 -n 18 -s 40 -g 1 -G 4 -L #{@ignoreList} -O 24000 -M 15"
		elsif (@avgReadSize<=400)
			@mapParams = " -d #{@numberOfDiagonals} -f 0 -l #{@numberOfDiagonals-1} -i 0 -a  #{@numberOfDiagonals-1}  -k 12 -n 18 -s 40 -g 1 -G 6 -L #{@ignoreList} -O 24000 -M 20 "
		else
			 @mapParams = " -d #{@numberOfDiagonals} -f 0 -l #{@numberOfDiagonals-1} -i 0 -a  #{@numberOfDiagonals-1} -k 12 -n 18 -s 100 -g 1 -G 12 -L #{@ignoreList} -O 24000 -M 20"
		end
		$stderr.puts "Pash mapping params set to #{@mapParams}"
  end

  def pashMapAgainstAllReferenceParts()
		@pashScratchDir = "#{@fullScratchDir}/pashScratch"
		begin
			FileUtils.mkdir_p(@pashScratchDir)
		rescue Exception=>e
			$stderr.puts "Could not create temporary output directory #{@pashScratchDir} #{e.message}"
			return false
		end

		fileList = Dir["#{@referenceEnvDirectory}/*fa"]
		fName = nil

		fileList.each {|fName|
			# for each reference part
			# run pash
			# run filtering program
			# remove anchoring output
			$stderr.puts "mapping against #{fName}" if (DEBUG)
			fOutputDir = "#{@fullScratchDir}/#{File.basename(fName)}"
			begin
				FileUtils.mkdir_p(fOutputDir)
			rescue Exception=>e
				$stderr.puts "Could not create temporary output directory #{fOutputDir} #{e.message}"
				return false
			end
			partialPashOutput = "#{fOutputDir}/mappingsOnto.#{File.basename(fName)}"
			partialPashAlignedOutput = "#{fOutputDir}/alignedMappingsOnto.#{File.basename(fName)}.top-#{@topPercent}.cutoff-#{@maxNumberOfTopMappings}"
			pashCommand = "Pash-sc.exe -v #{@queryFile} -h #{fName} -o #{partialPashOutput} #{@mapParams} -S #{@pashScratchDir}"
			system(pashCommand)
			hitsFilterCommand = "hitsFilterNS.exe -p #{partialPashOutput} -r #{@queryOffsetFileName} -R #{@querySequenceFileName}"
			hitsFilterCommand << " -g #{fName}.off  -G #{fName}.seq -P #{@topPercent} -n #{@maxNumberOfTopMappings} "
			hitsFilterCommand << " -s #{@pashScratchDir} -o #{partialPashAlignedOutput} -a -M -C 2000000"
			$stderr.puts "Executing filtering command #{hitsFilterCommand}"
			system(hitsFilterCommand)
			system("rm -rf #{@pashScratchDir}/*")
		}
		return true
  end

	def combineMappings()
		# subset mappings command
		subsetMappingsCommand="subsetMappings.exe -p \"#{@fullScratchDir}/*/aligned*Onto*top*cutoff*\" -r #{@queryOffsetFileName} -o #{@outputFile} -P #{@topPercent} -n #{@maxNumberOfTopMappings} -I #{@minIdentity}"
		if (@xmOutput) then
			subsetMappings << " -S "
		end
		$stderr.puts "Computing global results: #{subsetMappingsCommand}"
		system(subsetMappingsCommand)
	end

	def cleanupScratchDir()
		system("/bin/rm -rf #{@fullScratchDir}")
	end


	def convertOutputToXM()
		fileList = Dir["#{@outputFile}-*"]
		puts fileList.join("\t") if (DEBUG)
		f = nil
		fileList.each {|f|
			# figure out which reference to use
                        f=~/Onto.(.*).top-/
			refName = $1
			pash2XMcmd ="Pash2CM.exe -p #{f} -o #{f}.xm "
			pash2XMcmd << " -r #{@queryOffsetFileName} -R #{@querySequenceFileName} "
			pash2XMcmd << " -q #{@qualityOffsetFileName} -Q #{@qualityScoresFileName} "
			pash2XMcmd << " -g #{@referenceEnvDirectory}/#{refName}.off  -G #{@referenceEnvDirectory}/#{refName}.seq "
		       $stderr.puts "Converting pash output to cross_match format #{pash2XMcmd}"
                       system(pash2XMcmd)
		}
		system("cat #{@outputFile}-*.xm > #{@outputFile}")
		sleep(1)
		system("rm -r #{@outputFile}-*")
	end

  def work()
		$stderr.puts "Job started at #{Time.now}"
		# create a job-specific scratch directory
		if (!createFullScratchDirectory()) then
			return
		end
		# convert reads to read index
		buildReadIndex()
		setMappingParams()
		if (!pashMapAgainstAllReferenceParts()) then
			cleanupScratchDir()
			return false
		end
		# at the end, submitMappings.exe
		combineMappings()
		if (@xmOutput) then
			convertOutputToXM()
		end
		# cleanup
		# cleanupScratchDir()
		$stderr.puts "Job stopped at #{Time.now}"
		return true
  end

  def PashMap.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--queryFile',         '-q', GetoptLong::REQUIRED_ARGUMENT],
									['--genomeReference',   '-t', GetoptLong::OPTIONAL_ARGUMENT],
									['--genomeReferenceDir',   '-T', GetoptLong::OPTIONAL_ARGUMENT],
									['--readsType',         '-r', GetoptLong::REQUIRED_ARGUMENT],
									['--scratchDirectory',  '-S', GetoptLong::REQUIRED_ARGUMENT],
									['--outputFile',        '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--xmOutput',          '-x', GetoptLong::OPTIONAL_ARGUMENT],
									['--topPercent',        '-P', GetoptLong::OPTIONAL_ARGUMENT],
									['--maxNumberOfTopMappings',        '-n', GetoptLong::OPTIONAL_ARGUMENT],
									['--minIdentity',        '-I', GetoptLong::OPTIONAL_ARGUMENT],
									['--help',           '-h', GetoptLong::NO_ARGUMENT]
								]

		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		PashMap.usage() if(optsHash.key?('--help'));

		unless(progOpts.getMissingOptions().empty?)
			PashMap.usage("USAGE ERROR: some required arguments are missing")
		end

		PashMap.usage() if(optsHash.empty?);
		return optsHash
	end

	def PashMap.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  Driver for the Pash mapping software.

COMMAND LINE ARGUMENTS:
  --queryFile              | -q   => fasta/Fof file containing the reads to be mapped
  --genomeReference        | -t   => target genome fasta file, prepared previously
                                     with atlas-pash-prepare-reference.rb
  --genomeReferenceDir     | -T   => genome reference directory, specified explicitly,
	                                   that contains ignore lists k12.n18.76p.il and k12.n18.95p.il
  --readsType              | -r   => reads type; accepted types are Solexa, 454, Sanger
  --scratchDirectory       | -S   => scratch directory
  --xmOutput               | -x   => [optional] Convert the Pash output to cross_match format
  --topPercent             | -P   => keeps mappings within a certain ratio (default 1) from top mapping score
  --maxNumberOfTopMappings | -n   => accept reads with a maximum number of mappings within toPpercent
                                     of best mapping score; default 1
  --outputFile             | -o   => output file
  --minIdentity            | -I   => minimum read identity (default 0.9)
  --help                   | -h   => [optional flag] Output this usage info and exit

USAGE:
  atlas-pash-map.rb  -q reads.fa -t human.genome.36.fa -o mapped.reads -r 454 -S /scratch
";
			exit(2);
	end
end


########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = PashMap.processArguments()
# Instantiate analyzer using the program arguments
pashMapper = PashMap.new(optsHash)
# Analyze this !
pashMapper.work()
exit(0);
