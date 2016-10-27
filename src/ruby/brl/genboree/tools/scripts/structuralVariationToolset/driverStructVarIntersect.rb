#!/usr/bin/env ruby
require 'fileutils'
require 'brl/util/textFileUtil'
require 'brl/util/util'

	
class StructVarIntersectDriver
  DEBUG = true
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end  
  
  def setParameters()
		@fullScratchDir = nil
		
    @querySVLff = File.expand_path(@optsHash['--querySVLff'])
    
    @targetSVLFFFilesList = []
    @numberOfSVLffTargets = 0
    if (@optsHash.key?('--targetSVLFFFiles')) then
      @targetSVLFFFiles = File.expand_path(@optsHash['--targetSVLFFFiles'])
      @targetSVLFFFilesList = Dir[@targetSVLFFFiles]
      @numberOfSVLffTargets  = @targetSVLFFFilesList.size
      if (@numberOfSVLffTargets<1) then
				$stderr.puts "sv target files yields 0 files: #{@targetSVLFFFiles}"
				exit(2)
      end
    end
    
    @targetGenomicFilesList = []
    @numberOfGenomicLffTargets = 0
    if (@optsHash.key?('--targetGenomicFiles')) then
      @targetGenomicFiles = File.expand_path(@optsHash['--targetGenomicFiles'])
      @targetGenomicFilesList = Dir[@targetGenomicFiles]
      @numberOfGenomicLffTargets = @targetGenomicFilesList.size
      if (@numberOfGenomicLffTargets == 0) then
        $stderr.puts "Genomic target file pattern yields 0 files: #{@targetGenomicFiles}"
        exit(2)
      end
    end
    
    
    @genomicRadius = 0
    if (@optsHash.key?('--genomicRadius')) then
			@genomicRadius = @optsHash['--genomicRadius'].to_i
			if (@genomicRadius<0) then
				$stderr.puts "genomicRadius should be greater than or equal to 0"
				exit(2)
			end
    end
    
    @operation = @optsHash['--operation']
    if (@operation !~ /int|dif/i) then
      $stderr.puts "Operation should be intersection of difference"
    end
    @setOperation = "Intersection"
    if (@operation =~ /dif/) then
      @setOperation = "Difference"
    end
    
    @outputFile = File.expand_path(@optsHash['--outputFile'])
    check = system("touch #{@outputFile}")
    if (check != true) then
      $stderr.puts "Cannot create output file #{@outputFile}"
      exit(2)
    end
  
    @experimentName = @optsHash['--experimentName'].strip.gsub(/\s/,"_")
    
    @numberOfTargets = @targetGenomicFilesList.size + @targetSVLFFFilesList.size
    @tgpFile = nil
    if (@optsHash.key?('--tgpFile')) then
      @tgpFile = File.expand_path(@optsHash['--tgpFile'])
      if (!File.exist?(@tgpFile)) then
        $stderr.puts "1000 genome SVs file #{@tgpFile} does not exist"+
        exit(2)
      end
      @numberOfTargets += 1
    end
    
    
    if (@numberOfTargets==0) then
			$stderr.puts "No targets specified"
			cleanup()
			exit(2)
    end
    
    if (@setOperation == "Intersection") then
			@minTargetNumber = 1
    else
			@minTargetNumber = @numberOfTargets
    end
    
    if (@optsHash.key?('--minTargetNumber')) then
      @minTargetNumber = @optsHash['--minTargetNumber'].to_i
      if (@minTargetNumber<1) then
        $stderr.puts "min target number should be greater than or equal to 1"
        exit(2)
      end
      if (@minTargetNumber>@numberOfTargets) then
				$stderr.puts "The mimimum numer of targets #{@minTargetNumber} exceeds the total number of targets #{@numberOfTargets}"
				exit(2)
      end
    end
    
		@scratchDir = File.expand_path(@optsHash['--scratchDir'])
		if (!File.directory?(@scratchDir)) then
			$stderrr.puts "#{@scratchDir} is not a directory"
			exit(2)
		end
  end

	def loadSVHash()
		svReader = BRL::Util::TextReader.new(@querySVLff)
		@svHash = {}
		@svIntStruct = Struct.new("SVIntersectionStruct", :intersectSV, :intersectGenomic, :intersectTGP, :keepFlag)
		svReader.each {|l|
			next if (l=~/^\s*#/)
			ff = l.strip.split(/\t/)
			if (!@svHash.key?(ff[1])) then
				@svHash[ff[1]]=@svIntStruct.new(0, 0, 0, nil)
			end
		}
		svReader.close()
	end
	
	def intersectWithSVs()
		return 0 if (@targetSVLFFFilesList.size==0)
		targetIndex = 0
		queryMaxInsertSize = getMaxInsertSize(@querySVLff)
		
		@targetSVLFFFilesList.each {|targetName|
			$stderr.puts "about to perform SV intersect with #{targetName}"
			maxInsertSizeTarget = getMaxInsertSize(targetName)
			if (maxInsertSizeTarget<queryMaxInsertSize) then
				maxInsertSizeTarget = queryMaxInsertSize
			end
			tmpIntFile = "#{@fullScratchDir}/int.#{File.basename(@querySVLff)}-#{File.basename(targetName)}.lff"
			svSvCommand = "svSvTrackCoverage.rb -q #{@querySVLff} -t #{targetName} -r #{maxInsertSizeTarget} -S #{tmpIntFile} -e svIntegratorOverlap"
			$stderr.puts "svSvCommand #{svSvCommand}"
			result = system(svSvCommand)
			if (result!=true) then
				$stderr.puts "command #{svSvCommand} failed"
				exit(2)
			end
			r = File.open(tmpIntFile)
			if (r.nil?) then
				$stderr.puts "could not open temporary result file #{tmpIntFile}"
				exit(2)
			end
			
			r.each {|l|
				f = l.strip.split(/\t/)
				svName = f[1]
				@svHash[svName].intersectSV += 0.5 # will traverse it twice
			}
			r.close()
			targetIndex+=1
		}
		return 0
	end
	
	def intersectWithGenomicFeatures()
		return 0 if (@targetGenomicFilesList.size==0)
		featureIndex = 0
		@targetGenomicFilesList.each {|featureName|
			tmpIntFile = "#{@fullScratchDir}/intfeature.#{File.basename(@querySVLff)}-#{File.basename(featureName)}.lff"
			svFeatureCommand = "svLffTrackCoverage.rb -s #{@querySVLff} -c #{featureName} -r #{@genomicRadius} -S #{tmpIntFile} -C #{tmpIntFile}.xls "
			svFeatureCommand << " -a MyFeatureIntersect -A MyFeatureIntersect"
			$stderr.puts "svFeatureCommand #{svFeatureCommand}"
			result = system(svFeatureCommand)
			if (result!=true) then
				$stderr.puts "command #{svFeatureCommand} failed"
				exit(2)
			end

			r = File.open(tmpIntFile)
			if (r.nil?) then
				$stderr.puts "could not open file #{tmpIntFile}"
				exit(2)
			end
			r.each {|l|
				f = l.strip.split(/\t/)
				svName = f[1]
				@svHash[svName].intersectGenomic += 0.5
			}
			r.close()
			featureIndex+=1
		}
	end
	
	def getMaxInsertSize(svLffFile)
		r = BRL::Util::TextReader.new(svLffFile)
		result = 0
		r.each {|l|
			next if (l=~/^\s*#/)
			l=~/maxInsert=(\d+)/
			result = $1.to_i
			break
		}
		if (result==0) then
			$stderr.puts "File #{svLffFile} does not have a properly defined max insert size"
			exit(2)
		end
		
		return result
	end
	
	def intersectWithTGP()
		return 0 if (@tgpFile.nil?)
		tmpIntersectTGPOverSV = "#{@fullScratchDir}/intTGPoverSV.#{File.basename(@tgpFile)}-#{File.basename(@querySVLff)}"
		tmpIntersectSVOverTGP = "#{@fullScratchDir}/intSVOverTGP.#{File.basename(@tgpFile)}-#{File.basename(@querySVLff)}"
		# get max insert size for TGP
		maxInsertSizeQuery = getMaxInsertSize(@querySVLff)
		maxInsertSizeTGP = getMaxInsertSize(@tgpFile)
		if (maxInsertSizeTGP<maxInsertSizeQuery) then
			maxInsertSizeTGP = maxInsertSizeQuery
		end
		svSvCommandTGPOverSV = "svSvTrackCoverage.rb -t #{@querySVLff} -q #{@tgpFile} -r #{maxInsertSizeTGP} -S #{tmpIntersectTGPOverSV} -e svIntegratorOverlap"
		$stderr.puts "svSvCommandTGPOverSV #{svSvCommandTGPOverSV}"
		result = system(svSvCommandTGPOverSV)
		if (result!=true) then
			$stderr.puts "command #{svSvCommandTGPOverSV} failed"
			exit(2)
		end
		svSvCommandSVOverTGP = "svSvTrackCoverage.rb -q #{@querySVLff} -t #{tmpIntersectTGPOverSV} -r #{maxInsertSizeTGP} -S #{tmpIntersectSVOverTGP} -e svIntegratorOverlap"
		$stderr.puts "svSvCommandSVOverTGP #{svSvCommandSVOverTGP}"
		result = system(svSvCommandSVOverTGP)
		if (result!=true) then
			$stderr.puts "command #{svSvCommandSVOverTGP} failed"
			exit(2)
		end
		
		r = File.open(tmpIntersectSVOverTGP)
		if (r.nil?) then
			$stderr.puts "could not open file #{tmpIntersectSVOverTGP}"
			exit(2)
		end
		r.each {|l|
			f = l.strip.split(/\t/)
			svName = f[1]
			@svHash[svName].intersectTGP += 0.5
		}
		r.close()
	end
	
  def work()
		@fullScratchDir = "#{@scratchDir}/driverSvIntersect.#{File.basename(@outputFile)}.#{Process.pid}"
		result = FileUtils.mkdir_p(@fullScratchDir)
		if (result==nil) then
			$stderr.puts "could not create directory #{@fullScratchDir}"
			exit(2)
		end
		loadSVHash()
		intersectWithSVs()
		intersectWithGenomicFeatures()
		intersectWithTGP()
		finalizeSetOperation()
		cleanup()
  end
  
  def finalizeSetOperation()
		# determine which SVs get preserved
		@svHash.keys.each {|k|
			totalIntersect = @svHash[k].intersectSV+ @svHash[k].intersectGenomic + @svHash[k].intersectTGP
			totalDifference = @numberOfTargets - totalIntersect
			if  ( (@setOperation == "Intersection" && totalIntersect>=@minTargetNumber) ||
					  (@setOperation == "Difference" && totalDifference>=@minTargetNumber) ) then
				@svHash[k].keepFlag = true
			else
				@svHash[k].keepFlag = false
			end
			$stderr.puts "SV #{k} #{totalIntersect} #{totalDifference} #{@svHash[k].keepFlag}"
		}
		
		svReader = BRL::Util::TextReader.new(@querySVLff)
		if (svReader.nil?) then
			$stderr.puts "could not open file #{@querySVLff}"
			exit(2)
		end
		
		svWriter = BRL::Util::TextWriter.new(@outputFile)
		if (svWriter.nil?) then
			$stderr.puts "could not open file #{@outputFile} for writing"
			exit(2)
		end
		
		svReader.each {|l|
			ff = l.strip.split(/\t/)
			$stderr.puts "keep flag #{ff[1]} #{@svHash[ff[1]]}"
			next if (@svHash[ff[1]].keepFlag != true)
			
			ff[1] =~ /(\S+)\.SV\.(\d+)/
			ff[1] = "#{@experimentName}.SV.#{$2}"
			ff[2] = @experimentName
			svWriter.puts ff.join("\t")
		}
		
		svReader.close()
		svWriter.close()
  end
  
  def cleanup()
		if (!@fullScratchDir.nil?) then
			system("rm -rf #{@fullScratchDir}")
		end
  end
  
  def StructVarIntersectDriver.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--querySVLff',        '-q', GetoptLong::REQUIRED_ARGUMENT],
                  ['--targetSVLFFFiles',  '-t', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--targetGenomicFiles','-g', GetoptLong::OPTIONAL_ARGUMENT],
                  #['--svRadius',          '-r', GetoptLong::REQUIRED_ARGUMENT],
                  ['--genomicRadius',     '-R', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--operation',         '-O', GetoptLong::REQUIRED_ARGUMENT],
                  ['--outputFile',        '-o', GetoptLong::REQUIRED_ARGUMENT],
                  ['--experimentName',    '-E', GetoptLong::REQUIRED_ARGUMENT],
									['--tgpFile',   '-K', GetoptLong::OPTIONAL_ARGUMENT],
									['--minTargetNumber',   '-m', GetoptLong::OPTIONAL_ARGUMENT],
									['--scratchDir',        '-s', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--help',           '-h', GetoptLong::NO_ARGUMENT]
								]
		
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		StructVarIntersectDriver.usage() if(optsHash.key?('--help'));
		
		unless(progOpts.getMissingOptions().empty?)
			StructVarIntersectDriver.usage("USAGE ERROR: some required arguments are missing") 
		end
	
		StructVarIntersectDriver.usage() if(optsHash.empty?);
		return optsHash
	end
	
	def StructVarIntersectDriver.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  This utility performs an intersection of a breakpoint (SV) LFF track with multiple target tracks
  * other breakpoint LFF tracks
  * genomic features LFF tracks (one track per file)
  * a subset of the 1000 genomes structural variants

COMMAND LINE ARGUMENTS:
  --querySVLff         | -q   => query SV lff file
  --targetSVLFFFiles   | -t   => [optional] target SV lff file pattern
  --targetGenomicFiles | -g   => [optional] target genomic annotations LFF file pattern
  --tgpFile            | -K   => [optional] subset of 1000 genomies structural variants
  --genomicRadius      | -R   => [optional] radius overlap to be used with the target genomic lff files
  --operation          | -O   => int/dif for intersection/difference
  --minTargetNumber    | -M   => [optional] minimum number of targets to intersect/differ for an individual breakpoint to be reported
                                 default 1
  --outputFile         | -o   => output lff file with the resulting breakpoints
  --experimentName     | -E   => experiment name, to be used as type of the of output file and to name individual breakpoints
                                 all white spaces in the experiment name will be replaced by _
  --scratchDir         | -s   => scratch directory
  --help               | -h   =>  [optional flag] Output this usage info and exit
  

USAGE:
  rubyScript.rb  -r requiredArg -o optionalArg
";
			
#	--svRadius           | -r   => radius overlap to be used with the target SV lff files
	
			exit(2);
	end
end


########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = StructVarIntersectDriver.processArguments()
# Instantiate analyzer using the program arguments
StructVarIntersectDriver = StructVarIntersectDriver.new(optsHash)
# Analyze this !
StructVarIntersectDriver.work()
exit(0);
