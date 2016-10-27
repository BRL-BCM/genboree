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
		
		@targetSVLffFiles = @optsHash['--targetSVLffFiles']
		$stderr.puts "targetSVLffFiles |#{@targetSVLffFiles}|"
		@targetSVLFFFilesList = Dir[@targetSVLffFiles]
		@numberOfSVLffTargets  = @targetSVLFFFilesList.size
		if (@numberOfSVLffTargets<1) then
			$stderr.puts "sv target files yields 0 files: #{@targetSVLFFFiles}"
			exit(2)
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
    
    #@svRadius = @optsHash['--svRadius'].to_i
    #if (@svRadius<0) then
    #  $stderr.puts "svRadius should be greater than or equal to 0"
    #  exit(2)
    #end
    
    @genomicRadius = 0
    if (@optsHash.key?('--genomicRadius')) then
			@genomicRadius = @optsHash['--genomicRadius'].to_i
			if (@genomicRadius<0) then
				$stderr.puts "genomicRadius should be greater than or equal to 0"
				exit(2)
			end
    end
    
    @outputFileRoot = File.expand_path(@optsHash['--outputFileRoot'])
    @outputFileRootTest = "#{@outputFileRoot}.test"
    check = system("touch #{@outputFileRootTest}")
    if (check != true) then
      $stderr.puts "Cannot create output file #{@outputFileRootTest}"
      exit(2)
    else
			result = system("rm #{@outputFileRootTest}")
			if (result!= true) then
				$stderr.puts "Cannot remove temp file #{@outputFileRootTest}"
			end
    end
    
    @tgpFile = nil
    if (@optsHash.key?('--tgpFile')) then
      @tgpFile = File.expand_path(@optsHash['--tgpFile'])
      if (!File.exist?(@tgpFile)) then
        $stderr.puts "1000 genome SVs file #{@tgpFile} does not exist"+
        exit(2)
      end
    end
    
		@scratchDir = File.expand_path(@optsHash['--scratchDir'])
		if (!File.directory?(@scratchDir)) then
			$stderrr.puts "#{@scratchDir} is not a directory"
			exit(2)
		end
  end

	def getExperimentName(svLffFile)
		r = BRL::Util::TextReader.new(svLffFile)
		result = nil
		r.each {|l|
			next if (l=~/^\s*#/)
			ff=l.strip.split(/\t/)
			ff[1]=~/(.*)\.SV\.(\d+)/
			result = $1
			break
		}
		if (result==nil) then
			$stderr.puts "File #{svLffFile} does not have a properly defined experiment type"
			exit(2)
		end
		
		return result
	end

  def work()
		@fullScratchDir = "#{@scratchDir}/driverSvReport.#{File.basename(@outputFileRoot)}.#{Process.pid}"
		result = FileUtils.mkdir_p(@fullScratchDir)
		if (result==nil) then
			$stderr.puts "could not create directory #{@fullScratchDir}"
			exit(2)
		end
		
		genomicTargetsOption = ""
		if (@targetGenomicFilesList.size>=2) then
			genomicTargetsOption << " -g {#{@targetGenomicFilesList.join(",")}}"
		else
			genomicTargetsOption << " -g #{@targetGenomicFilesList[0]} "
		end
		
		tgpTargetsOption = ""
		if (@tgpFile != nil) then
			tgpTargetsOption << " -K #{@tgpFile} "
		end
		
		radiusOption = " -R 0 "
		if (@optsHash.key?('--genomicRadius')) then
			radiusOption = " -R #{@genomicRadius} "
		end
		
		# generate one report per each target SV lff file
		@targetSVLFFFilesList.each {|svFile|
			$stderr.puts "processing report for #{svFile}"
			otherTargetsList = []
			@targetSVLFFFilesList.each {|target|
				if (target != svFile) then
					otherTargetsList.push(target)
				end
			}
			otherTargetsOption = ""
			if (otherTargetsList.size>=2) then
				otherTargetsOption << " -t {#{otherTargetsList.join(",")}} "
			elsif (otherTargetsList.size==1) then
				otherTargetsOption << " -t #{otherTargetsList[0]} "
			end
			
			experimentName = getExperimentName(svFile).gsub(/\s/,"_")
			svOutputFile = "#{@outputFileRoot}.#{experimentName}.xls"
			svIntegratorCommand = "svIntegrator.rb -q #{svFile} #{otherTargetsOption} #{genomicTargetsOption} #{tgpTargetsOption} #{radiusOption} "
			svIntegratorCommand << " -o #{svOutputFile} -s #{@fullScratchDir}"
	    $stderr.puts "svIntegratorCommand for #{svFile} is #{svIntegratorCommand}"
	    check = system(svIntegratorCommand)
	    if (check!=true ) then
				$stderr.puts "FAILED svIntegratorCommand #{svIntegratorCommand}"
				exit(2)
	    end
		}
		finalizeReports()
		cleanup()
  end
  
  def finalizeReports()
  end
  
  def cleanup()
		if (!@fullScratchDir.nil?) then
			system("rm -rf #{@fullScratchDir}")
		end
  end
  
  def StructVarIntersectDriver.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--targetSVLffFiles',  '-t', GetoptLong::REQUIRED_ARGUMENT],
                  ['--targetGenomicFiles','-g', GetoptLong::OPTIONAL_ARGUMENT],
                  #['--svRadius',          '-r', GetoptLong::REQUIRED_ARGUMENT],
                  ['--genomicRadius',     '-R', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--outputFileRoot',    '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--tgpFile',           '-K', GetoptLong::OPTIONAL_ARGUMENT],
									['--scratchDir',        '-s', GetoptLong::REQUIRED_ARGUMENT],
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
  This utility generates TAB-delimited reports for one or multiple breakpoint (SV) LFF track(s).
  It reports for each track and for each breakpoint
  * intersection with the remaining SV LFF files
  * intersection with genomic features LFF tracks (one track per file)
  * intersection with a subset of the 1000 genomes structural variants

COMMAND LINE ARGUMENTS:
  --targetSVLffFiles   | -t   => [optional] target SV lff file pattern
  --targetGenomicFiles | -g   => [optional] target genomic annotations LFF file pattern
  --tgpFile            | -K   => [optional] subset of 1000 genomies structural variants
  --genomicRadius      | -R   => [optional] radius overlap to be used with the target genomic lff files
  --outputFileRoot     | -o   => output lff file with the resulting breakpoints
  --scratchDir         | -s   => scratch directory
  --help               | -h   => [optional flag] Output this usage info and exit

USAGE:
  
  
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
