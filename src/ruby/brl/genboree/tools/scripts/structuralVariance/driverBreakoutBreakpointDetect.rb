#!/usr/bin/env ruby
require 'getoptlong'
require 'fileutils'


class BreakoutSVDetect
	
  DEBUG =true 
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end

  def setParameters()
		@fullScratch = nil
		@orientation = @optsHash['--orientation']
		if (@orientation != "same" && @orientation!="opposite") then
			BreakoutSVDetect.usage("The orientation should have the values same or opposite")
		end
		$stderr.puts "Relative expected strand orientation of consistent matepairs #{@sameStrandPairs}" 
		
		@forwardFiles = @optsHash['--forwardFiles']
		@reverseFiles = @optsHash['--reverseFiles']
		
		@forwardSuffix = @optsHash['--forwardSuffix']
		@reverseSuffix = @optsHash['--reverseSuffix']
		
		@outputStructVars = @optsHash['--structuralVariants']
		@systemType = "shm"
		@numberOfCores = 1
		if (@optsHash.key?('--numberOfCores')) then
			@numberOfCores=@optsHash['--numberOfCores'].to_i
			if (@numberOfCores<1) then
				BreakoutSVDetect.usage("Number of cores should be a positive integer number")
			end
		end
		
		@fileType = @optsHash['--fileType'].downcase()
		if (@fileType !~/^(sam|bam)$/) then
			BreakoutSVDetect.usage("File type should be one of sam/bam")
		end
		
		@chromosomeList = @optsHash['--chromosomeList']
		if (!File.exists?(@chromosomeList)) then
			$stderr.puts "Chromosome list file #{@chromosomeList} does not exist"
			cleanup()
		end	
		
		@minimumInsertSize = @optsHash['--minimumInsertSize'].to_i
		@maximumInsertSize = @optsHash['--maximumInsertSize'].to_i
		if (@minimumInsertSize<=0 || @maximumInsertSize<=0 || @minimumInsertSize >= @maximumInsertSize) then
			BreakoutSVDetect.usage("Insert size range incorrect")
		end
		
    @inconsistentMatePairs = @optsHash['--inconsistentMatePairs']
    @inconsistentMatepairsOption = " "
    if (@optsHash.key?('--inconsistentMatePairs')) then
      @inconsistentMatepairsOption = " -J #{@optsHash['--inconsistentMatePairs']}"
			$stderr.puts "Inconsistent matepairs option #{@inconsistentMatepairsOption}"
    end
    
    @consistentMatePairs = @optsHash['--consistentMatePairs']
    @consistentMatepairsOption = " "
    if (@optsHash.key?('--consistentMatePairs')) then
      @consistentMatepairsOption = " -C #{@optsHash['--consistentMatePairs']}"
      $stderr.puts "Consistent matepairs option #{@consistentMatepairsOption}"
    end
  
  	@minNonChimericInsert = 100
    
    if (@optsHash.key?('--minNonChimericInsert')) then
      @minNonChimericInsert = @optsHash['--minNonChimericInsert']
    end
    
    @scratchDirectory=@optsHash['--scratchDirectory']
    if (!File.directory?(@scratchDirectory)) then
			$stderr.puts "Scratch directory #{@scratchDirectory} does not exist"
			cleanup()
			exit(2)
    end
    
    @experimentName = @optsHash['--experimentName'].strip.gsub(/\s/, "_")
    if (@experimentName == "") then
			$stderr.puts "Invalid experiment name #{@experimentName}"
			cleanup()
			exit(2)
    end
    
    @breakpointsLff = @optsHash['--breakpointsLff']
    @breakpointsXLS = @optsHash['--breakpointsXLS']
    
    @summaryFile = @optsHash['--experimentSummary']
    
    $stderr.puts "Consistent matepairs file #{@consistentMatePairs} inconsistent matepairs file #{@inconsistentMatePairs}" 
  end

	def splitInputFiles()
    @numberOfParts = 200
		@fullScratch = "#{@scratchDirectory}/breakpointBreakoutDriver.#{Process.pid}"
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
			$stderr.puts "Could not open for writing files #{@forwardListFile} and #{@reverseListFile}"
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
	
	
	def submitBreakpointCallingJob()
		breakpointBreakoutDetectCommand = " breakout-sv-detect.rb -O #{@orientation} -F #{@forwardListFile}  -R #{@reverseListFile} "
		breakpointBreakoutDetectCommand << " -s \\\"#{@forwardSuffix}\\\" -S \\\"#{@reverseSuffix}\\\" -T bed -N #{@numberOfCores} -M "
		breakpointBreakoutDetectCommand << " -o #{@fullScratch}/raw.svs -i #{@minimumInsertSize} -I #{@maximumInsertSize} -k #{@minNonChimericInsert} "
		breakpointBreakoutDetectCommand << " #{@consistentMatepairsOption} #{@inconsistentMatepairsOption} -L #{@chromosomeList} "
		$stderr.puts "breakpointBreakoutDetectCommand #{breakpointBreakoutDetectCommand}" if (DEBUG)
		result = system(breakpointBreakoutDetectCommand)
		$stderr.puts "breakpointBreakoutDetectCommand result = #{result}" if (DEBUG)
		if (result!=true) then
      $stderr.puts "breakpointBreakoutDetectCommand failed"
			cleanup()
			exit(2)
		end
	end
	
	def stripChromosomeList()
		tmpChromosomeFile = "#{@fullScratch}/chromosomeList"
		reader = File.open(@chromosomeList)
		writer = File.open(tmpChromosomeFile, "w")
		
		if (reader == nil) then
			$stderr.puts "Could not open #{@chromosomeList} file"
			exit(2)
		end
		
		if (reader == nil) then
			$stderr.puts "Could not open #{tmpChromosomeFile} file for writing"
			exit(2)
		end
		
		reader.each {|l|
			ff = l.strip.split(/\s+/)
			writer.puts ff[0]
		}
		reader.close()
		writer.close()
		
		@chromosomeList = tmpChromosomeFile
	end
	
  def work()
		$stderr.print "SV DETECT START#{Time.now()}"
		splitInputFiles()
		stripChromosomeList()
		prepareInputSets()
		submitBreakpointCallingJob()
		centralizeResults()
		cleanup()
		$stderr.print "SV DETECT STOP#{Time.now()}"
  end

	def centralizeResults()
    # generate reports
    svToLffCommand = "sv-to-lff.rb -O #{@orientation} -b #{@fullScratch}/raw.svs -l #{@breakpointsLff} -X #{@breakpointsXLS} "
    svToLffCommand << " -x 3 -m #{@minimumInsertSize} -M #{@maximumInsertSize} "
    svToLffCommand << " -E #{@experimentName} "
    $stderr.puts "svToLffCommand #{svToLffCommand}" if (DEBUG)
    result = system(svToLffCommand)
    if (result!=true) then
			$stderr.puts "svToLffCommand failed"
			cleanup()
			exit(2)
    end
    getSummary(@consistentMatePairs, @inconsistentMatePairs, "#{@fullScratch}/map.forward.*", "#{@fullScratch}/map.reverse.*", @minimumInsertSize, @maximumInsertSize, @breakpointsXLS, @summaryFile)
	end
	
	
	def getSummary(consistentMatepairs, inconsistentMatepairs, forwardFilesPattern, reverseFilePattern, minInsert, maxInsert, breakpointsXLS, summaryFile)
    # get consistent matepairs
    numberOfConsistentPairs = `cat #{consistentMatepairs} | wc -l`.to_i
    numberOfInconsistentPairs = `cat #{inconsistentMatepairs}  | wc -l`.to_i
    totalReads = `cat #{forwardFilesPattern} #{reverseFilePattern} | wc -l`.to_i
    singletons = totalReads-2*(numberOfInconsistentPairs+numberOfConsistentPairs)
    mappedPairs = singletons+numberOfConsistentPairs+numberOfInconsistentPairs
    summaryWriter = File.open(summaryFile, "w")
    svHash = {}
    r = File.open(breakpointsXLS)
    r.each {|l|
      next if (r.lineno==1)
      f = l.strip.split(/\t/)
      if (!svHash.key?(f.last)) then
        svHash[f.last]=1
      else
        svHash[f.last]+=1
      end
      
    }
    r.close()
    
    summaryWriter.puts "Mapped Pairs\t#{mappedPairs}"
    summaryWriter.puts "Singletons\t#{singletons}"
    summaryWriter.puts "Consistent Pairs\t#{numberOfConsistentPairs}"
    summaryWriter.puts "Inconsistent Pairs\t#{numberOfInconsistentPairs}"
    summaryWriter.puts "Minimum Insert Size\t#{minInsert}"
    summaryWriter.puts "Maximum Insert Size\t#{maxInsert}"
    svHash.keys.each { |k|
      summaryWriter.puts "#{k}\t#{svHash[k]}"  
    }
    summaryWriter.close()
  end
	
	def cleanup()
		if (!@fullScratch.nil?) then
			# system("rm -rf #{@fullScratch}")
		end
		
	end
	
  def BreakoutSVDetect.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--orientation',   	'-O', GetoptLong::OPTIONAL_ARGUMENT],
									['--forwardFiles',	  '-F', GetoptLong::OPTIONAL_ARGUMENT],
									['--reverseFiles',    '-R', GetoptLong::OPTIONAL_ARGUMENT],
									['--forwardSuffix',		'-s', GetoptLong::REQUIRED_ARGUMENT],
									['--reverseSuffix',		'-S', GetoptLong::REQUIRED_ARGUMENT],
									['--structuralVariants', '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--breakpointsLff', '-b', GetoptLong::REQUIRED_ARGUMENT],
									['--breakpointsXLS', '-B', GetoptLong::REQUIRED_ARGUMENT],
									['--numberOfCores',		'-N', GetoptLong::OPTIONAL_ARGUMENT],
									['--fileType',				'-T', GetoptLong::REQUIRED_ARGUMENT],
									['--minimumInsertSize',			'-i', GetoptLong::REQUIRED_ARGUMENT],
									['--minNonChimericInsert', 	'-k', GetoptLong::OPTIONAL_ARGUMENT],
									['--maximumInsertSize',			'-I', GetoptLong::REQUIRED_ARGUMENT],
									['--consistentMatePairs',		'-C', GetoptLong::REQUIRED_ARGUMENT],
									['--inconsistentMatePairs',	'-J', GetoptLong::REQUIRED_ARGUMENT],
									['--chromosomeList',				'-L', GetoptLong::REQUIRED_ARGUMENT],
									['--scratchDirectory',		  '-X', GetoptLong::REQUIRED_ARGUMENT],
									['--experimentName',		    '-E', GetoptLong::REQUIRED_ARGUMENT],
									['--experimentSummary',		  '-A', GetoptLong::REQUIRED_ARGUMENT],									
									['--help',            '-h', GetoptLong::NO_ARGUMENT]
			]

		progOpts = GetoptLong.new(*optsArray)
		optsHash = {}
		
		progOpts.each do |opt, arg|
      case opt
        when '--help'
          BreakoutSVDetect.usage("")
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
        when '--structuralVariants'
          optsHash['--structuralVariants']=arg
        when '--sharedMem'
          optsHash['--sharedMem']=1
        when '--pbs'
          optsHash['--pbs']=1
        when '--numberOfCores'
          optsHash['--numberOfCores']=arg
        when '--fileType'
          optsHash['--fileType']=arg
        when '--minimumInsertSize'
          optsHash['--minimumInsertSize']=arg
        when '--minNonChimericInsert'
          optsHash['--minNonChimericInsert']=arg
        when '--maximumInsertSize'
          optsHash['--maximumInsertSize']=arg
        when '--chromosomeList'
          optsHash['--chromosomeList']=arg
        when '--inconsistentMatePairs'
          optsHash['--inconsistentMatePairs']=arg
        when '--consistentMatePairs'
          optsHash['--consistentMatePairs']=arg
        when '--scratchDirectory'
          optsHash['--scratchDirectory']=arg
        when '--experimentName'
          optsHash['--experimentName']=arg
        when '--experimentSummary'
          optsHash['--experimentSummary']=arg
        when '--breakpointsXLS'
          optsHash['--breakpointsXLS']=arg
        when '--breakpointsLff'
          optsHash['--breakpointsLff']=arg 
      end
    end

		BreakoutSVDetect.usage() if(optsHash.empty?);
		if (!optsHash.key?('--orientation') ||
				!optsHash.key?('--forwardSuffix') ||
				!optsHash.key?('--reverseSuffix') ||
				!optsHash.key?('--fileType') ||
				!optsHash.key?('--minimumInsertSize') ||
				!optsHash.key?('--maximumInsertSize') ||
				!optsHash.key?('--fileType') ||
				!optsHash.key?('--chromosomeList') ||
				!optsHash.key?('--scratchDirectory') ||
				!optsHash.key?('--experimentName') ||
				!optsHash.key?('--experimentSummary') ||
				!optsHash.key?('--structuralVariants') ) then
			BreakoutSVDetect.usage("USAGE ERROR: some required arguments are missing")
		end
		return optsHash
	end

	def BreakoutSVDetect.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "
PROGRAM DESCRIPTION:
This driver takes in forward and reverse files, corresponding
to mappings of matepair data, and the expected insert size range.
It can utilize multiple CPUs to determine the consistent and inconsistent
matepairs, and call structural variants.

This tool can make use of multiple available cores, other via
* shared memory, default mode

COMMAND LINE ARGUMENTS:
  --orientation          | -O   => consistent matepair orientation: same/opposite
  --forwardFiles         | -F   => LFF file containing the sv calls
  --reverseFiles         | -R   => [optional] class of the lff output file, default StructVariants
  --forwardSuffix        | -s   => suffix of forward reads 
  --reverseSuffix        | -S   => suffix of reverse reads 
  --structuralVariants   | -o   => raw structural variants detected
  --breakpointsLff       | -b   => structural variants in LFF format
  --breakpointsXLS       | -B   => structural variants in XLS format
  --numberOfCores        | -N   => [optional] number of cores used for computation, default 1
  --fileType             | -T   => input file types: sam, bam
  --minimumInsertSize    | -i   => lower bound of the expected insert size range
  --maximumInsertSize    | -I   => upper bound of the expected insert size range
  --minNonChimericInsert | -k   => minimum insert size which is not attributed to failed pairs 
  --consistentMatePairs  | -C   => [optional] consistent matepairs
  --inconsistentMatePairs| -J   => [optional] inconsistent matepairs
  --chromosomeList       | -L   => list of chromosomes; breakout works for genome assemblies with at most 1024 chromosomes
  --scratchDirectory     | -X   => temporary directory to be used
  --experimentName       | -E   => experiment name; it should not contain spaces
  --help                 | -h   => [optional] output this usage info and exit

USAGE:
  driverBreakoutBreakpointDetect.rb -O opp -F \"mapped.forward.reads.*.bam\" -r \"mapped.reverse.reads.*.bam\" \
	  -o output.svs.txt -s \"/0\" -S \"/1\" -N 2  -T bam -i 3000 -I 4000         \
		-C consistent.txt -J inconsistent.txt -L chromosomes.txt -X /scratch 
";
		exit(2);
	end
end

########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = BreakoutSVDetect.processArguments()
# Instantiate analyzer using the program arguments
boilerPlate = BreakoutSVDetect.new(optsHash)
# Analyze this !
boilerPlate.work()
exit(0);
