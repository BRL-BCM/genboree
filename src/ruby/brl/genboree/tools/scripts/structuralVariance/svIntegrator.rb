#!/usr/bin/env ruby
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'set'


module BRL; module Pash

class SVIntegrator
  DEBUG = true
  DEBUG_CALL = false 
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end

  def setParameters()
		@fullScratchDir = nil
		@querySVLff =  @optsHash['--querySVLff']
		if (!File.exist?(@querySVLff)) then
			$stderr.puts "Query file #{@querySVLff} not found"
			exit(2)
		end
		@targetSVLffFiles = []
		@numberOfSVLffTargets = 0
		
		if (@optsHash.key?('--targetSVLffFiles')) then
			@targetSVLffFiles = @optsHash['--targetSVLffFiles']
			$stderr.puts "targetSVLffFiles |#{@targetSVLffFiles}|"
			@targetSVLFFFilesList = Dir[@targetSVLffFiles]
			@numberOfSVLffTargets  = @targetSVLFFFilesList.size
			if (@numberOfSVLffTargets<1) then
				$stderr.puts "sv target files yields 0 files: #{@targetSVLFFFiles}"
				exit(2)
			end
		end
		
		@targetGenomicFilesList = []
    @numberOfGenomicLffTargets = 0
    if (@optsHash.key?('--targetGenomicFiles')) then
			@targetGenomicFiles = @optsHash['--targetGenomicFiles']
      @targetGenomicFilesList = Dir[@targetGenomicFiles]
      @numberOfGenomicLffTargets = @targetGenomicFilesList.size
      if (@numberOfGenomicLffTargets == 0) then
        $stderr.puts "Genomic target file pattern yields 0 files: #{@targetGenomicFiles}"
        exit(2)
      end
    end
		
    @radiusFeatures = @optsHash['--radiusFeatures'].to_i
    if (@radiusFeatures<0) then
			$stderr.puts "genomicRadius should be greater than or equal to 0"
			exit(2)
		end
    
    @outputSpreadsheet    = 	@optsHash['--outputSpreadsheet']
    check = system("touch #{@outputSpreadsheet}")
    if (check != true) then
      $stderr.puts "Cannot create output file #{@outputFileRootTest}"
      exit(2)
    else
			result = system("rm #{@outputSpreadsheet}")
			if (result!= true) then
				$stderr.puts "Cannot remove temp file #{@outputSpreadsheet}"
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
		
		$stderr.puts "sv intersection of #{@querySVLff} using #{@targetSVLffFiles};
    write output to #{@outputSpreadsheet}" if (DEBUG)
  end

	def loadTargetLabels()
		@targetLabels = []
		@numberOfTargets = 0
		if (@targetSVLFFFilesList.size>0) then
			@targetSVLFFFilesList.each {|targetName|
				targetExperiment = getExperimentName(targetName)
				@targetLabels.push(File.basename(targetExperiment))
			}
			@numberOfTargets = @targetLabels.size
		end
	end
	
	def loadFeatureLabels()
		@featureLabels = []
		@numberOfFeatures = 0
		if (@targetGenomicFilesList.size>0) then
			@targetGenomicFilesList.each {|featureName|
				featureTrack = getTrackName(featureName)
				@featureLabels.push(featureTrack)
			}
			@numberOfFeatures = @featureLabels.size
			$stderr.puts "Feature Labels #{@featureLabels.join(",")} size #{@featureLabels.size}"
		end
	end

	def loadQuerySV()
		@svStruct = Struct.new("SVStruct", :name, :chrom1, :start1, :stop1, :strand1, :chrom2, :start2, :stop2, :strand2, :svType, :svOverlap, :featureOverlap, :tgpOverlap)
		@querySVHash = {}
		r = BRL::Util::TextReader.new(@querySVLff)
		done = false
		while (!done)
			l1 = r.gets
			l2 = r.gets
			break if (l1.nil? || l2.nil?)
			f1 = l1.strip.split(/\t/)
			f2 = l2.strip.split(/\t/)
			if (f1[1]!=f2[1]) then
				$stderr.puts "yikes! #{l1} #{l2}"
				exit(2)
			end
			l1=~/mateType=([^;]+)/
			svType = $1
			@querySVHash[f1[1]]=@svStruct.new(f1[1], f1[4], f1[5], f1[6], f1[7], f2[4], f2[5], f2[6], f2[7], svType,
																				["No"]*@numberOfTargets, [nil]*@numberOfFeatures, nil)
			$stderr.puts "#{f1[1]} ---> #{@querySVHash[f1[1]]} #{@querySVHash[f1[1]].featureOverlap.size}" if (DEBUG_CALL)
		end
		r.close()
	end
  
	def outputQuerySV()
		writer = File.open(@outputSpreadsheet, "w")
		queryExperiment = getExperimentName(@querySVLff)
		buffer = "#{queryExperiment}\tChrom1\tStart1\tStop1\tStrand1\tChrom2\tStart2\tStop2\tStrand2\tType"
		if (@targetLabels.size>0) then
			buffer<<"\t#{@targetLabels.join("\t")}"
		end
		if (@featureLabels.size>0) then
			buffer << "\t#{@featureLabels.join("\t")}"
		end
		if (!@tgpFile.nil?) then
			buffer << "\t1000 Genomes Overlap"	
		end
		
		writer.puts(buffer)
		@querySVHash.keys.each {|k|
			thisSV = @querySVHash[k]
			buffer = "#{k}\t#{thisSV.chrom1}\t#{thisSV.start1}\t#{thisSV.stop1}\t#{thisSV.strand1}\t#{thisSV.chrom2}\t#{thisSV.start2}\t#{thisSV.stop2}\t#{thisSV.strand2}\t#{thisSV.svType}\t"
			if (@targetLabels.size>0) then
				buffer << "#{thisSV.svOverlap.join("\t")}\t"
			end
			if (@featureLabels.size>0) then
				$stderr.puts "#{k} hasy #{thisSV.featureOverlap.size}" if (DEBUG_CALL)
				thisSV.featureOverlap.each {|f|
					if (f==nil) then
						buffer << "N/A\t"
					else
						buffer << "#{f.to_a.sort.join(",")}\t"
						$stderr.puts "#{k}-->#{f.class} #{f.size} #{f.to_a.join("--")}" if (DEBUG_CALL)
					end
				}
			end
			if (!@tgpFile.nil?) then
				if (thisSV.tgpOverlap.nil?) then
					buffer << "\tNo"
				else
					buffer << "\tYes"
				end
			end
			writer.puts buffer
		}
		writer.close()
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
				l =~/svIntegratorOverlap=([^;]+)(;|\s|$)/
				@querySVHash[svName].svOverlap[targetIndex]=$1.strip
			}
			r.close()
			targetIndex+=1
		}
		return 0
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
		check = system(svSvCommandTGPOverSV)
		if (check!=true) then
			$stderr.puts "command #{svSvCommandTGPOverSV} failed"
			exit(2)
		end
		svSvCommandSVOverTGP = "svSvTrackCoverage.rb -q #{@querySVLff} -t #{tmpIntersectTGPOverSV} -r #{maxInsertSizeTGP} -S #{tmpIntersectSVOverTGP} -e svIntegratorOverlap"
		$stderr.puts "svSvCommandSVOverTGP #{svSvCommandSVOverTGP}"
		check= system(svSvCommandSVOverTGP)
		if (check!=true) then
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
				l =~/svIntegratorOverlap=([^;]+)(;|\s|$)/
				@querySVHash[svName].tgpOverlap=$1.strip
		}
		r.close()
	end

	
	def intersectWithGenomicFeatures()
		return 0 if (@targetGenomicFilesList.size==0)
		featureIndex = 0
		@targetGenomicFilesList.each {|featureName|
			tmpIntFile = "#{@fullScratchDir}/intfeature.#{File.basename(@querySVLff)}-#{File.basename(featureName)}.lff"
			svFeatureCommand = "svLffTrackCoverage.rb -s #{@querySVLff} -c #{featureName} -r #{@genomicRadius} -S #{tmpIntFile} -C #{tmpIntFile}.xls "
			svFeatureCommand << " -a MyFeatureIntersect -A MyFeatureIntersect"
			$stderr.puts "svFeatureCommand #{svFeatureCommand}"
			check= system(svFeatureCommand)
			if (check!=true) then
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
				l =~/MyFeatureIntersect=([^;]+)(;|\s|$)/
				featureNames = $1.strip.split(/,/)
				#$stderr.puts "#{svName} hasee #{@querySVHash[svName].featureOverlap.size}" if (DEBUG)
				if (@querySVHash[svName].featureOverlap[featureIndex]==nil) then
					@querySVHash[svName].featureOverlap[featureIndex] = Set.new()
				end
				#$stderr.puts "#{svName} haseye #{@querySVHash[svName].featureOverlap.size}" if (DEBUG)
				featureNames.each {|individFeature|
					@querySVHash[svName].featureOverlap[featureIndex].add(individFeature)
				}
				# $stderr.puts "#{svName} hase #{@querySVHash[svName].featureOverlap.size}" if (DEBUG)
			}
			r.close()
			featureIndex+=1
		}
	end
	
  def work()
		@fullScratchDir = "#{@scratchDir}/svIntegrator.#{File.basename(@outputSpreadsheet)}.#{Process.pid}"
		check=system("mkdir #{@fullScratchDir}")
		if (check!=true) then
			$stderr.puts "Could not create temp dir #{@fullScratchDir}"
			exit(2)
		end
		
		# setup feature labels (drop lff from name)
		loadFeatureLabels()
		loadTargetLabels()
		# load all input SVs
		loadQuerySV()
		# create two arrays per sv: 1 per sv track, 1 per feature track
		# for each sv target track
		#  run svSvTrackCoverage
		#   traverse result; for each input SV mark it in the corresponding hash/array
		intersectWithSVs()
		# for each feature track
		#  run svLffTrackCoverage
		#   traverseResults; for each input SV, mark a reduced set of feature names in the correpsonding hash/array
		intersectWithGenomicFeatures()
		intersectWithTGP()
		# output a spreadsheet with the input SVs
		outputQuerySV()
	end

  def SVIntegrator.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--querySVLff',   		'-q', GetoptLong::REQUIRED_ARGUMENT],
									['--targetSVLffFiles',  	'-t', GetoptLong::OPTIONAL_ARGUMENT],
									['--targetGenomicFiles',  '-g', GetoptLong::OPTIONAL_ARGUMENT],
									['--tgpFile',             '-K', GetoptLong::OPTIONAL_ARGUMENT],
									['--outputSpreadsheet',  	'-o', GetoptLong::REQUIRED_ARGUMENT],
									['--radiusFeatures',      '-R', GetoptLong::REQUIRED_ARGUMENT],
									['--scratchDir',          '-s', GetoptLong::REQUIRED_ARGUMENT],
									['--help',              	'-h', GetoptLong::NO_ARGUMENT]
			]

		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		SVIntegrator.usage() if(optsHash.key?('--help'));

		unless(progOpts.getMissingOptions().empty?)
			SVIntegrator.usage("USAGE ERROR: some required arguments are missing")
		end

		SVIntegrator.usage() if(optsHash.empty?);
		return optsHash
	end

	def SVIntegrator.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  This utility takes in a query sv track, a set of target SV lff files, optional feature lff files, 
and generates a spreadsheet containing the query SVs and the overlap status with the target SV files and
the feature lff files.

COMMAND LINE ARGUMENTS:
  --querySVLff           | -q   => SVs in lff format
                                   each annotation has the attributes mateChrom, mateChromStart, mateChromStop
  --targetSVLffFiles     | -t   => [optional] LFF files pattern, containing SV tracks for which we want to report the overlap
  --targetGenomicFiles   | -g   => [optional] target genomic annotations LFF file pattern for which we want to report the overlap 
  --outputSpreadsheet    | -o   => lff output file, annotating the query SVs that overlap w/ target SVs
  --tgpFile              | -K   => [optional] subset of 1000 genomies structural variants
  --radiusFeatures       | -R   => [optional] radius used for overlap detection
  --help                 | -h   => [optional] output this usage info and exit

USAGE:
  SVIntegrator -q svCallsQuery.lff -t targetSVLffPattern -f lffFeatureFilesPattern -o svCallsQuery.xls -r 3000";
			exit(2);
	end
end

end; end
########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = BRL::Pash::SVIntegrator.processArguments()
# Instantiate analyzer using the program arguments
boilerPlate = BRL::Pash::SVIntegrator.new(optsHash)
# Analyze this !
boilerPlate.work()
exit(0);
