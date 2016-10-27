#!/usr/bin/env ruby
require 'fileutils'
require 'brl/util/textFileUtil'
require 'brl/util/util'

	
class StructVarPeaksEnrichmentDriver
  DEBUG = true
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end  
  
  def setParameters()
		@fullScratchDir = nil
		
		@breakpointLffFiles = @optsHash['--breakpointLffFiles']
		$stderr.puts "breakpointLffFiles|#{@breakpointLffFiles}|"
		@breakpointLffFilesList = Dir[@breakpointLffFiles]
		@numberOfBreakpointFiles = @breakpointLffFilesList.size
		if (@numberOfBreakpointFiles<1) then
			$stderr.puts "breakpoint file pattern files yields 0 files: #{@breakpointLffFiles}"
			exit(2)
		end
     
		@peakAnnotationFiles = File.expand_path(@optsHash['--peakAnnotationFiles'])
		@peakAnnotationFilesList = Dir[@peakAnnotationFiles]
		@numberOfPeakAnnotationFiles= @peakAnnotationFilesList.size
		if (@numberOfPeakAnnotationFiles== 0) then
			$stderr.puts "Genomic target file pattern yields 0 files: #{@peakAnnotationFiles}"
			exit(2)
		end
        
    @genomicRadius = 0
    if (@optsHash.key?('--genomicRadius')) then
			@genomicRadius = @optsHash['--genomicRadius'].to_i
			if (@genomicRadius<0) then
				$stderr.puts "genomicRadius should be greater than or equal to 0"
				exit(2)
			end
    end
    
    @outputReport = File.expand_path(@optsHash['--outputReport'])
    @outputFileRootTest = "#{@outputReport}"
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
    
		@scratchDir = File.expand_path(@optsHash['--scratchDir'])
		if (!File.directory?(@scratchDir)) then
			$stderrr.puts "#{@scratchDir} is not a directory"
			exit(2)
		end
	  
	  @chromosomeOffsets= File.expand_path(@optsHash['--chromosomeOffsets'])
		if (!File.exist?(@chromosomeOffsets)) then
			$stderrr.puts "#{@chromosomeOffsets} not found"
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

	def getTrackName(lffFile)
		r = BRL::Util::TextReader.new(lffFile)
		result = nil
		r.each {|l|
			next if (l=~/^\s*#/)
			ff=l.strip.split(/\t/)
			result = "#{ff[2]}:#{ff[3]}"
			break
		}
		if (result==nil) then
			$stderr.puts "File #{svLffFile} does not have a properly defined experiment type"
			exit(2)
		end
		
		return result
	end

	def getBreakpointTypes(svLffFile, experimentName)
		r = BRL::Util::TextReader.new(svLffFile)
		svTypeFileHandleHash = {}
		r.each {|l|
			next if (l=~/^\s*#/)
			if (l=~/mateType=([^;]+)/) then
				mateType = $1.strip
				if (!svTypeFileHandleHash.key?(mateType)) then
					svTypeSVLffFile = "#{@fullScratchDir}/tmp.#{experimentName}.#{mateType}.lff"
					writer = File.open(svTypeSVLffFile, "w")
					if (writer.nil?) then
						$stderr.puts "could not open temporary file #{svTypeSVLffFile}"
						exit(2)
					end
					svTypeFileHandleHash[mateType] = writer
				end
				svTypeFileHandleHash[mateType].print l
			else
				$stderr.puts "Incorrect breakpoint line #{l.strip}"
				exit(2)
			end
		}
		
		svTypeFileHandleHash.keys.each {|k|
			svTypeFileHandleHash[k].close()
		}
		
		result = svTypeFileHandleHash.keys
		if (result.size==0) then
			$stderr.puts "File #{svLffFile} does not contain any breakpoints"
		end
		
		return result
	end

  def work()
		@fullScratchDir = "#{@scratchDir}/driverSvPeakEnrich.#{File.basename(@outputReport)}.#{Process.pid}"
		result = FileUtils.mkdir_p(@fullScratchDir)
		if (result==nil) then
			$stderr.puts "could not create directory #{@fullScratchDir}"
			exit(2)
		end
		
		outputWriter = File.open(@outputReport, "w")
		if (outputWriter.nil?) then
			$stderr.puts "Could not open output report #{@outputReport} for writing"
			exit(2)
		end
		outputWriter.puts "SV Experiment\tEpigenomic Dataset\tEnrichment of Peaks nearby Breakpoints\tP-value"
		
		# prepare SV files by experiment name and sv type (deletions, inversions, translocations)
		@breakpointLffFilesList.each {|breakpointFile|
			experimentName = getExperimentName(breakpointFile).gsub(/\s/, "_")
			svTypesList = getBreakpointTypes(breakpointFile, experimentName)
			svTypesList.each {|svType|
				svTypeSVLffFile = "#{@fullScratchDir}/tmp.#{experimentName}.#{svType}.lff"
				$stderr.puts "processing #{svTypeSVLffFile} "
				@peakAnnotationFilesList.each {|peakFile|
					peakTrackName = getTrackName(peakFile)	
					# get enrichment
					reportFile = "#{@fullScratchDir}/tmp.#{experimentName}.#{svType}.#{File.basename(peakFile)}.txt"
					svPeakEnrichmentCommand = "breakpointAnnotationEnrichment.rb -c #{@chromosomeOffsets} -l #{svTypeSVLffFile} -L #{peakFile} "
					svPeakEnrichmentCommand << " -n 10 -r #{@genomicRadius} -o #{reportFile}> #{@fullScratchDir}/log.#{File.basename(reportFile)} 2>&1 "
					$stderr.puts "about to run enrichment command #{svPeakEnrichmentCommand} "
					check = system(svPeakEnrichmentCommand)
					if (check != true) then
						$stderr.puts "Command #{svPeakEnrichmentCommand} failed"
						exit(2)
					end
					r = File.open(reportFile)
					if (r.nil?) then
						$stderr.puts "Could not open file #{reportFile}"
						exit(2)
					end
					l = r.gets
					ff = l.strip.split(/\t/)
					r.close()
					enrichment = ff[9]
					pValue = ff[10]
					outputWriter.puts "#{experimentName}.#{svType}\t#{peakTrackName}\t#{enrichment}\t#{pValue}"
				}
			}
		}
		# run enrichment tool and get results; output results in output file
		
		outputWriter.close()
	#	genomicTargetsOption = ""
	#	if (@targetGenomicFilesList.size>=2) then
	#		genomicTargetsOption << " -g {#{@targetGenomicFilesList.join(",")}}"
	#	else
	#		genomicTargetsOption << " -g #{@targetGenomicFilesList[0]} "
	#	end
	#	
	#	tgpTargetsOption = ""
	#	if (@tgpFile != nil) then
	#		tgpTargetsOption << " -K #{@tgpFile} "
	#	end
	#	
	#	radiusOption = " -R 0 "
	#	if (@optsHash.key?('--genomicRadius')) then
	#		radiusOption = " -R #{@genomicRadius} "
	#	end
	#	
	#	# generate one report per each target SV lff file
	#	@targetSVLFFFilesList.each {|svFile|
	#		$stderr.puts "processing report for #{svFile}"
	#		otherTargetsList = []
	#		@targetSVLFFFilesList.each {|target|
	#			if (target != svFile) then
	#				otherTargetsList.push(target)
	#			end
	#		}
	#		otherTargetsOption = ""
	#		if (otherTargetsList.size>=2) then
	#			otherTargetsOption << " -t {#{otherTargetsList.join(",")}} "
	#		elsif (otherTargetsList.size==1) then
	#			otherTargetsOption << " -t #{otherTargetsList[0]} "
	#		end
	#		
	#		experimentName = getExperimentName(svFile).gsub(/\s/,"_")
	#		svOutputFile = "#{@outputFileRoot}.#{experimentName}.xls"
	#		svIntegratorCommand = "svIntegrator.rb -q #{svFile} #{otherTargetsOption} #{genomicTargetsOption} #{tgpTargetsOption} #{radiusOption} "
	#		svIntegratorCommand << " -o #{svOutputFile} -s #{@fullScratchDir}"
	#    $stderr.puts "svIntegratorCommand for #{svFile} is #{svIntegratorCommand}"
	#    check = system(svIntegratorCommand)
	#    if (check!=true ) then
	#			$stderr.puts "FAILED svIntegratorCommand #{svIntegratorCommand}"
	#			exit(2)
	#    end
	#	}
	#	finalizeReports()
	#	cleanup()
  end
  
  def finalizeReports()
  end
  
  def cleanup()
		if (!@fullScratchDir.nil?) then
			system("rm -rf #{@fullScratchDir}")
		end
  end
  
  def StructVarPeaksEnrichmentDriver.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--breakpointLffFiles',  '-b', GetoptLong::REQUIRED_ARGUMENT],
                  ['--peakAnnotationFiles', '-p', GetoptLong::REQUIRED_ARGUMENT],
                  ['--genomicRadius',       '-R', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--outputReport',        '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--scratchDir',          '-s', GetoptLong::REQUIRED_ARGUMENT],
									['--chromosomeOffsets',   '-c', GetoptLong::REQUIRED_ARGUMENT],
                  ['--help',                '-h', GetoptLong::NO_ARGUMENT]
								]
		
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		StructVarPeaksEnrichmentDriver.usage() if(optsHash.key?('--help'));
		
		unless(progOpts.getMissingOptions().empty?)
			StructVarPeaksEnrichmentDriver.usage("USAGE ERROR: some required arguments are missing") 
		end
	
		StructVarPeaksEnrichmentDriver.usage() if(optsHash.empty?);
		return optsHash
	end
	
	def StructVarPeaksEnrichmentDriver.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  This utility takes as input
  * one or multiple SV tracks in lff format, with one file per track
  * one or multiple LFF annotation tracks
  and generats a TAB-delimited reports containing the enrichment of peaks near breakpoints
  for each input experiment and for each type of breakpoint (eg Deletions, Inversions, Translocations)
  using a permutation test

COMMAND LINE ARGUMENTS:
  --breakpointLffFiles  | -b   => breakpoint LFF file pattern
  --peakAnnotationFiles | -p   => peak annotations LFF file pattern
  --genomicRadius       | -R   => [optional] radius overlap to be used with the target genomic lff files; default 0
  --outputReport        | -o   => output TAB delimited file containing peak enrichment results
  --chromosomeOffsets   | -c   => chromosome offsets and sizes file
  --scratchDir          | -s   => scratch directory
  --help                | -h   => [optional flag] Output this usage info and exit

USAGE:
  
  driverBreakpointPeaksEnrichment.rb -b \"*sv.lff\" -p \"peaks*lff\" -R 50000 -o enrichment.xls -s scratch  
";
			
#	--svRadius           | -r   => radius overlap to be used with the target SV lff files
	
			exit(2);
	end
end


########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = StructVarPeaksEnrichmentDriver.processArguments()
# Instantiate analyzer using the program arguments
StructVarPeaksEnrichmentDriver = StructVarPeaksEnrichmentDriver.new(optsHash)
# Analyze this !
StructVarPeaksEnrichmentDriver.work()
exit(0);
