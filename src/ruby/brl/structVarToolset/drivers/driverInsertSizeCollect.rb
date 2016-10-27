#!/usr/bin/env ruby
require 'getoptlong'
require 'fileutils'

class BreakoutCollectInsertDriver
  DEBUG =true 
  def initialize(optsHash)
    @optsHash = optsHash
    setParameters()
  end

  def setParameters()
		@fullScratch = nil
    @orientation = @optsHash['--orientation']
    if (@orientation != "same" && @orientation!="opposite") then
	    BreakoutCollectInsertDriver.usage("The orientation should have the values same or opposite")
    end
    $stderr.puts "Relative expected strand orientation of consistent matepairs #{@sameStrandPairs}" 
    
    @forwardFiles = @optsHash['--forwardFiles']
    @reverseFiles = @optsHash['--reverseFiles']
    
    @forwardSuffix = @optsHash['--forwardSuffix']
    @reverseSuffix = @optsHash['--reverseSuffix']
    
    @outputHistogram = @optsHash['--outputHistogram']
    @suggestedBoundsFile = @optsHash['--suggestedBoundsFile']
    
    @scratchDirectory = @optsHash['--scratchDirectory']
    if (!File.exists?(@scratchDirectory) || !File.directory?(@scratchDirectory)) then
			$stderr.puts "the scratch  #{@scratchDirectory} directory does not exist"
			exit(2)
		end
    @numberOfCores = 1
    if (@optsHash.key?('--numberOfCores')) then
      @numberOfCores=@optsHash['--numberOfCores'].to_i
      if (@numberOfCores<1) then
	      BreakoutCollectInsertDriver.usage("Number of cores should be a positive integer number")
      end
    end
    
    @fileType = @optsHash['--fileType'].downcase()
    if (@fileType !~/^(sam|bam)$/) then
	    BreakoutCollectInsertDriver.usage("File type should be one of SAM/BAM")
    end
    @numberOfParts = 100
  end
	
	def splitInputFiles()
		@fullScratch = "#{@scratchDirectory}/collectInsertSizeDriver.#{Process.pid}"
		$stderr.puts "fullScratch directory #{@fullScratch}" if (DEBUG)
		results = FileUtils.mkdir_p(@fullScratch)
		if (results == nil) then
			cleanup()
			exit(2)
		end
		forwardMappingSplitCommand = "genericMappingsSplitter.exe -m \"#{@forwardFiles}\" -T #{@fileType} -S #{@forwardSuffix.size} -o #{@fullScratch} -n #{@numberOfParts} -r map.forward"
		reverseMappingSplitCommand = "genericMappingsSplitter.exe -m \"#{@reverseFiles}\" -T #{@fileType} -S #{@reverseSuffix.size} -o #{@fullScratch} -n #{@numberOfParts} -r map.reverse"
		$stderr.puts "\n forwardMappingSplitCommand #{forwardMappingSplitCommand}\n reverseMappingSplitCommand #{reverseMappingSplitCommand}" if (DEBUG)
		resultSplitForward = system(forwardMappingSplitCommand)
		resultSplitReverse = system(reverseMappingSplitCommand)
		if (resultSplitReverse!=true || resultSplitForward!=true) then
			$stderr.puts "\n resultSplitForward #{resultSplitForward}\n resultSplitReverse #{resultSplitReverse}" 
			cleanup()
			exit(2)
		end
	end

	def prepareInputSets()
		@forwardListFile = "#{@fullScratch}/forwardList"
		@reverseListFile = "#{@fullScratch}/reverseList"
		
		
		forwardListFileWriter = File.open(@forwardListFile, "w")
		reverseListFileWriter = File.open(@reverseListFile, "w")
		if (forwardListFileWriter==nil || reverseListFileWriter == nil) then
			cleanup()
			exit(2)
		end
		
	  0.upto(@numberOfParts-1).each {|idx|
			forwardListFileWriter.puts "#{@fullScratch}/map.forward.part.#{idx}"
			reverseListFileWriter.puts "#{@fullScratch}/map.reverse.part.#{idx}"
		}	
		
		forwardListFileWriter.close()
		reverseListFileWriter.close()
	end
	
	def submitSizeCollection()
		breakoutInsertSizeCollectCommand = " breakout-insert-size-collect.rb -O #{@orientation} -F #{@forwardListFile} -R #{@reverseListFile} "
		breakoutInsertSizeCollectCommand << " -s \\\"#{@forwardSuffix}\\\" -S \\\"#{@reverseSuffix}\\\" -T bed -N #{@numberOfCores} -M -o #{@outputHistogram} "
		$stderr.puts "breakoutInsertSizeCollectCommand #{breakoutInsertSizeCollectCommand}" if (DEBUG)
		result = system(breakoutInsertSizeCollectCommand)
		$stderr.puts "insertSizeCollectCommand result = #{result}" if (DEBUG)
		if (result!=true) then
			cleanup()
			exit(2)
		end
	end
	
  def work()
		splitInputFiles()
		prepareInputSets()
		submitSizeCollection()
		centralizeResults()
		cleanup()
  end
	
	def centralizeResults()
		illuminaFlag = false
		if (@orientation =~ /opp/i) then
			illuminaFlag = true
		end
		result = generateAdviceFile(@outputHistogram, @suggestedBoundsFile, illuminaFlag)
		if (result!=0) then
			$stderr.puts "Failed to generate advice file"
			cleanup()
			exit(2)
		end
		
	end
	
	def generateAdviceFile(histogram, advice, illuminaFlag)
		r = File.open(histogram)
		if (r==nil) then
			cleanup()
			exit(2)
		end
		sum = 0
		# conservatively, if data is illumina, skip matepairs with less than 300bp insert
		insertHash = {}
		r.each {|l|
			f = l.split(/\t/)
			insert =  f[0].to_i
			next if (insert>100000)
			next if (illuminaFlag==true && insert<300)
			insertHash[insert]=f[1].to_i
			sum += f[1].to_f
		}
		# determine 0.5% - 99.5% bounds
		lBound = insertHash.keys.sort.first
		uBound = insertHash.keys.sort.last
		ignoreBound = 0
		if (illuminaFlag) then
			ignoreBound = 300
		end
		cumulativeSum=0.0
		previousSum=0.0
		lowerBoundSum = sum*0.005
		upperBoundSum = sum*0.995
		insertHash.keys.sort.each {|k|
			previousSum = cumulativeSum
			cumulativeSum+= insertHash[k].to_f
			if (previousSum<lowerBoundSum && cumulativeSum>=lowerBoundSum) then
				lBound = k
				$stderr.puts "lower bound #{lBound}" if (DEBUG)
			end
			if (previousSum<upperBoundSum&& cumulativeSum>=upperBoundSum) then
				uBound = k
				$stderr.puts "upper bound #{uBound}" if (DEBUG)
			end
			$stderr.puts "#{k}\t#{insertHash[k]}\t#{previousSum}\t#{cumulativeSum}"
		}
	
		r.close()
		
		suggestedBoundsWriter = File.open(advice, "w")
		if (suggestedBoundsWriter==nil) then
			cleanup()
			$stderr.puts "Could not open file #{advice} for writing"
			exit(2)
		end
		
		suggestedBoundsWriter.puts "Ignore insert size for malformed pairs #{ignoreBound}"
		suggestedBoundsWriter.puts "Lower bound for insert size #{lBound}"
		suggestedBoundsWriter.puts "Upper bound for insert size #{uBound}"
		suggestedBoundsWriter.close()
		
		return 0
	end


  def cleanup()
    if (!@fullScratch.nil?) then
			system("rm -rf #{@fullScratch}")
		end
  end
	
  def BreakoutCollectInsertDriver.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--orientation',   	'-O', GetoptLong::OPTIONAL_ARGUMENT],
				  ['--forwardFiles',	'-F', GetoptLong::OPTIONAL_ARGUMENT],
				  ['--reverseFiles',	'-R', GetoptLong::OPTIONAL_ARGUMENT],
				  ['--forwardSuffix',	'-s', GetoptLong::REQUIRED_ARGUMENT],
				  ['--reverseSuffix',	'-S', GetoptLong::REQUIRED_ARGUMENT],
				  ['--outputHistogram', '-o', GetoptLong::REQUIRED_ARGUMENT],
				  ['--numberOfCores',	'-N', GetoptLong::OPTIONAL_ARGUMENT],
				  ['--fileType',	'-T', GetoptLong::REQUIRED_ARGUMENT],
				  ['--suggestedBoundsFile', '-A', GetoptLong::REQUIRED_ARGUMENT],
				  ['--scratchDirectory', '-X', GetoptLong::REQUIRED_ARGUMENT],
				   ['--help',            '-h', GetoptLong::NO_ARGUMENT]
			]

		progOpts = GetoptLong.new(*optsArray)
		optsHash = {}
		
		progOpts.each do |opt, arg|
      case opt
        when '--help'
          BreakoutCollectInsertDriver.usage("")
        when '--orientation'
          optsHash['--orientation'] = arg
        when '--forwardFiles'
          optsHash['--forwardFiles']=arg
        when '--reverseFiles'
          optsHash['--reverseFiles']=arg
        when '--forwardSuffix'
          optsHash['--forwardSuffix']=arg
        when '--reverseSuffix'
          optsHash['--reverseSuffix']=arg
        when '--outputHistogram'
          optsHash['--outputHistogram']=arg
          when '--suggestedBoundsFile'
          optsHash['--suggestedBoundsFile']=arg
        when '--numberOfCores'
          optsHash['--numberOfCores']=arg
        when '--scratchDirectory'
          optsHash['--scratchDirectory']=arg  
        when '--fileType'
          optsHash['--fileType']=arg  
      end
    end

		BreakoutCollectInsertDriver.usage() if(optsHash.empty?);
		if (!optsHash.key?('--orientation') ||
				!optsHash.key?('--forwardSuffix') ||
				!optsHash.key?('--reverseSuffix') ||
				!optsHash.key?('--fileType') ||
				!optsHash.key?('--forwardFiles') ||
				!optsHash.key?('--reverseFiles') ||
				!optsHash.key?('--scratchDirectory') ||
				!optsHash.key?('--outputHistogram') ) then
			BreakoutCollectInsertDriver.usage("USAGE ERROR: some required arguments are missing")
		end
		return optsHash
	end

	def BreakoutCollectInsertDriver.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "
PROGRAM DESCRIPTION:
This driver takes in forward and reverse files and uses potentially multiple CPUs
to determine the distribution of insert sizes.
This tool can make use of multiple available cores, other via
* shared memory, default mode

COMMAND LINE ARGUMENTS:
  --orientation          | -O   => consistent matepair orientation: same/opposite
  --forwardFiles         | -F   => forward mappings file pattern
  --reverseFiles         | -R   => reverse mappings file pattern
  --forwardSuffix        | -s   => suffix of forward reads 
  --reverseSuffix        | -S   => suffix of reverse reads 
  --outputHistogram      | -o   => output insert size histogram
  --suggestedBoundsFile  | -A   => file containing the suggeste lower/upper bounds
  --numberOfCores        | -N   => [optional] number of cores used for computation, default 1
  --fileType             | -T   => input file types: SAM, BAM, and (experimental) BED
  --scratchDirectory     | -X   => temporary directory to be used
  --help                 | -h   => [optional] output this usage info and exit

USAGE:
  driverInsertSizeCollect.rb -O opp -F listForwardReads -R listReverseReads \
	  -o output.txt -s \"/0\" -S \"/1\" -N 2  -A advice.txt
";
		exit(2);
	end
end

########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = BreakoutCollectInsertDriver.processArguments()
# Instantiate analyzer using the program arguments
boilerPlate = BreakoutCollectInsertDriver.new(optsHash)
# Analyze this !
boilerPlate.work()
exit(0);
