#!/usr/bin/env ruby
require 'gsl'
require 'brl/util/textFileUtil'
require 'brl/util/util'

	
class AnnoEnrichmentAnalyzer
  DEBUG = true
  DEBUG_SIM = false
  DEBUG_SIM_BKP = false
  DEBUG_DEL = true
  def initialize(optsHash)
    @optsHash = optsHash
    setParameters()
  end  
  
  def setParameters()
    @chromosomeSizes = File.expand_path(@optsHash['--chromosomeSizes'])
    @lffFile1 = File.expand_path(@optsHash['--lffFile1'])
    @lffFile2 = File.expand_path(@optsHash['--lffFile2'])
    @iterations = @optsHash['--iterations'].to_i
    if (@iterations<=0) then
      @iterations = 1
    end
    #@iterations = 1
    @radius= @optsHash['--radius'].to_i
    if (@radius<0) then
      @radius = 0
    end
    @output = File.expand_path(@optsHash['--output'])
  end
  
  def loadOffsets
    @offStruct = Struct.new("SeqOffset", :chrom, :start,  :stop, :size)
    @offHash = {}
    @offArray = []
    @minPos = 4000000000
    @maxPos = 0
    @totalSize = 0
    r = File.open(@chromosomeSizes, "r")
    r.each {|l|
      f = l.strip.split(/\t/)
      start = f[1].to_i
      crtSize = f[2].to_i
      stop = start+crtSize-1
      if (@minPos>start) then
	@minPos = start
      end
      if (@maxPos<stop) then
	@maxPos = stop
      end
      currentOffset = @offStruct.new(f[0], start, start+crtSize-1, crtSize)
      @totalSize += crtSize
      @offHash[f[0]] = currentOffset
      @offArray.push(currentOffset)
    }
    r.close()
    @numSequences = @offArray.size
    $stderr.puts "loaded #{@numSequences} sequences in genome of coordinates #{@minPos} #{@maxPos} total size #{@totalSize}"
  end
  
  def getTrack(lffFile)
    r = BRL::Util::TextReader.new(lffFile)
    track = nil
    while true
      l = r.gets()
      next if (l.nil?)
      if (l=~/^\s*#/) then
	next
      end
      f = l.strip.split(/\t/)
      track = f[2,2].join(":")
      break
    end
    r.close()
    return track  
  end
  
  def basicIntersection()
    @track1 = getTrack(@lffFile1)
    @track2 = getTrack(@lffFile2)
    if (@track1.nil? || @track2.nil?) then
      $stderr.puts "Could not extract track from #{@lffFile1} and #{@lffFile2}"
      return 1
    end
    lffIntersect = "lffIntersect.rb -l #{@lffFile1},#{@lffFile2} -o #{@fullScratch}/basicIntersection.lff -s #{@track1} -f #{@track2} -n basic:int -r #{@radius}"
    $stderr.puts "lffIntersect: #{lffIntersect}"
    system(lffIntersect)
    @baseline = `cat #{@fullScratch}/basicIntersection.lff | wc -l`.strip.to_i
    svLffIntersect = "svLffTrackCoverage.rb -s #{@lffFile1} -c #{@lffFile2} -S #{@fullScratch}/basicIntersection.svLff.lff -A oo -a ooo -r 50000 -C #{@fullScratch}/basicFeatures.lff"
    $stderr.puts "svLffIntersect: #{svLffIntersect}"
    system(svLffIntersect)
    @baselineSvLff = `cat #{@fullScratch}/basicFeatures.lff | wc -l`.strip.to_i
    @baselineBkpOverlap = `cat #{@fullScratch}/basicIntersection.svLff.lff | wc -l`.strip.to_i
    $stderr.puts "basic intersection #{@baseline} #{@baselineSvLff}"
  end
  
  
  
  ## traverse second file
  ## permute annotations: 
  ##* get new coordinates
  ##* lookup actual chromosome coordinates
  ## generated permuted file
  ## generate intersection
  def oneSimulation(index)
    permutedFile = "#{@fullScratch}/permutaton.#{File.basename(@lffFile2)}.idx.#{index}"
    permutedIntersectionFile = "#{@fullScratch}/permutaton.#{File.basename(@lffFile2)}.idx.#{index}.int"
    r = BRL::Util::TextReader.new(@lffFile2)
    w = File.open(permutedFile, "w")
    r.each {|l|
      f = l.strip.split(/\t/)
      annotationSize = f[6].to_i-f[5].to_i+1
      if (annotationSize<10) then
	annotationSize = 10
      end
      values = permute(annotationSize)
      start = values[1]
      stop = values[2]
      chromOffset = values[0]
      $stderr.puts "#{f[4,3].join("\t")} ---> #{chromOffset.chrom}\t#{start-chromOffset.start+1}\t#{stop-chromOffset.start+1}" if (DEBUG_SIM)
      w.puts "Sim\t#{f[1]}\tSim\tLff2\t#{chromOffset.chrom}\t#{start-chromOffset.start+1}\t#{stop-chromOffset.start+1}\t+\t.\t1\t.\t."
    }
    w.close()
    r.close()
    lffIntersect = "lffIntersect.rb -l #{@lffFile1},#{permutedFile} -o #{permutedIntersectionFile} -s #{@track1} -f Sim:Lff2 -n basic:int -r #{@radius}"
    $stderr.puts "lffIntersect: #{lffIntersect}"
    system(lffIntersect)
    currentInt = `cat #{permutedIntersectionFile}| wc -l`.strip.to_i
    
    
    svLffIntersect = "svLffTrackCoverage.rb -s #{@lffFile1} -c #{permutedFile} -S #{@fullScratch}/basicIntersection.svLff.#{index}.lff -A oo -a ooo -r #{@radius} -C #{@fullScratch}/basicFeatures.#{index}.lff"
    $stderr.puts "svLffIntersect #{svLffIntersect}"
    system(svLffIntersect)
    currentSvLffInt= `cat #{@fullScratch}/basicFeatures.#{index}.lff | wc -l`.strip.to_i
    
    # traverse svLff file
    r = BRL::Util::TextReader.new(@lffFile1)
    permuteSvLffFile = "#{@fullScratch}/permutSvLff.#{index}.lff"
    w = BRL::Util::TextWriter.new(permuteSvLffFile)
    while 1
      l1 = r.gets
      l2 = r.gets
      break if (l1.nil? || l2.nil?)
      f1=l1.split(/\t/)
      f2=l2.split(/\t/)
      if (f1[1]!=f2[1]) then
	$stderr.puts "yikes ! #{l1} #{l2}"
	exit(2)
      end
      l1 =~/ount=(\d+)/
      coverage=$1
      l1 =~/ype=([^;]+)/
      mtype =$1
      l1 =~ /minInsert=(\d+)/
      minInsert = $1.to_i
      l1 =~ /maxInsert=(\d+)/
      maxInsert = $1.to_i
      $stderr.puts "Permuting #{l1.strip}     #{l2.strip}" if (DEBUG_SIM_BKP)
      
      if (mtype =~ /Translocation/i) then
	values1 = permute(f1[6].to_i-f1[5].to_i+1)
	chromOffset1 = values1[0]
	chrom1 = chromOffset1.chrom
	chrom1Start = values1[1].to_i-chromOffset1.start+1
	chrom1Stop = values1[2].to_i-chromOffset1.start+1
	
	values2 = permute(f2[6].to_i-f2[5].to_i+1)
	chromOffset2 = values2[0]
	chrom2 = chromOffset2.chrom
	chrom2Start = values2[1].to_i-chromOffset2.start+1
	chrom2Stop = values2[2].to_i-chromOffset2.start+1
      else
	if (mtype =~ /Deletion/i) then
	  $stderr.puts "Deletion\t#{f2[6].to_i-f1[5].to_i+1}" if (DEBUG_DEL)
	end
	if (f1[5].to_i<f2[5].to_i) then
	  values = permute(f2[6].to_i-f1[5].to_i+1)
	else
	  values = permute(f1[6].to_i-f2[5].to_i+1)
	end
	chromOffset = values[0]
	chrom1 = chromOffset.chrom
	chrom1Start = values[1].to_i-chromOffset.start+1
	chrom1Stop = chrom1Start + f1[6].to_i-f1[5].to_i
	
	chrom2 = chromOffset.chrom
	chrom2Stop = values[2].to_i-chromOffset.start+1
	chrom2Start = chrom2Stop - (f2[6].to_i-f2[5].to_i)
	if (chrom2Start<1) then
	  chrom2Start = 1
	end
	if (chrom1Stop>chrom2Start) then
	  chrom1Stop = chrom2Start-1
	end
      end
      avp1 = []
      avp1.push("mateType=#{mtype}")
      avp1.push("mateChrom=#{chrom2}")
      avp1.push("mateStart=#{chrom2Start}")
      avp1.push("mateStop=#{chrom2Stop}")
      avp1.push("matePairsCount=#{coverage}")
      avp1.push("minInsert=#{minInsert}")
      avp1.push("maxInsert=#{maxInsert}")
      avp2 = []
      avp2.push("mateType=#{mtype}")
      avp2.push("mateChrom=#{chrom1}")
      avp2.push("mateStart=#{chrom1Start}")
      avp2.push("mateStop=#{chrom1Stop}")
      avp2.push("matePairsCount=#{coverage}")
      avp2.push("minInsert=#{minInsert}")
      avp2.push("maxInsert=#{maxInsert}")
      w.puts "#{f1[0,4].join("\t")}\t#{chrom1}\t#{chrom1Start}\t#{chrom1Stop}\t+\t0\t1\t.\t.\t#{avp1.join("; ")}"
      w.puts "#{f1[0,4].join("\t")}\t#{chrom2}\t#{chrom2Start}\t#{chrom2Stop}\t+\t0\t1\t.\t.\t#{avp2.join("; ")}"
    end
    r.close()
    w.close()
    
    svLffIntersect = "svLffTrackCoverage.rb -s #{permuteSvLffFile} -c #{@lffFile2} -S #{@fullScratch}/permuteSvIntersection.#{index}.lff -A oo -a ooo -r #{@radius} -C #{@fullScratch}/basicFeatures.bkpPermutation.#{index}.lff"
    $stderr.puts "svLffIntersect #{svLffIntersect}"
    system(svLffIntersect)
    currentPermuteSvLffInt = `cat #{@fullScratch}/permuteSvIntersection.#{index}.lff | wc -l`.strip.to_i
    currentBasicFeaturesBkpPermuteInt = `cat #{@fullScratch}/basicFeatures.bkpPermutation.#{index}.lff | wc -l`.strip.to_i
    
    
    return [currentInt, currentSvLffInt, currentPermuteSvLffInt, currentBasicFeaturesBkpPermuteInt]  
  end
  
  def min(a,b)
    result =a
    if (a>b) then
      result = b
    end
    return b
  end
  
  def permute(annotationSize)
    start = rand(@totalSize-annotationSize)
    stop = start + annotationSize-1
    chrIdx = lookupSequence(start, stop)
    chromOffset = @offArray[chrIdx]
    if (stop > chromOffset.stop) then
      stop = chromOffset.stop
      start = stop - annotationSize+1
    end
    if (start < chromOffset.start) then
      start = chromOffset.start
    end
    return [chromOffset, start, stop]
  end
  
  def lookupSequence(start, stop)
    # binary search to find the best chromosome
    # then adjust coordinates to be fully in chromosome
    if (start < @minPos || start > @maxPos || stop < @minPos || stop>@maxPos || start>=stop) then
	    $stderr.puts "incorrect request for sequence #{start} #{stop} in genome of coordinates #{@minPos} #{@maxPos}"
	    exit(2)
    end
    min = 0
    max = @numSequences-1
    foundIdx = -1
    while (max-min>1)
	    $stderr.puts "min=#{min} max=#{max}" if (DEBUG_SIM)
	    mid = (max+min)/2
	    if (@offArray[mid].start <= stop && @offArray[mid].stop>= start) then
		    foundIdx = mid
		    break
	    end
	    if (@offArray[mid].start > stop) then
		    max = mid-1
	    else
		    min = mid+1
	    end
    end
    if (foundIdx==-1) then
	    if (@offArray[min].start <= stop && @offArray[min].stop>= start) then
		    foundIdx = min
	    else
		    foundIdx=max
	    end
    end
    return foundIdx
  end
  
  def doSimulations()
    sumIntersection = 0
    sumSvLffIntersection = 0
    sumPermuteBkpInt = 0
    sumFeaturePermuteBkpInt = 0

    sumIntersection2 = 0
    sumSvLffIntersection2 = 0
    sumPermuteBkpInt2 = 0
    sumFeaturePermuteBkpInt2 = 0

    sdIntersection = 0
    sdSvLffIntersection = 0
    sdPermuteBkpInt = 0
    sdFeaturePermuteBkpInt = 0
    
    1.upto(@iterations) {|i|
      intersectionArrasy = oneSimulation(i)
      $stderr.puts "#{i}:  #{intersectionArrasy.join("\t")}"
      sumIntersection += intersectionArrasy[0].to_f
      sumSvLffIntersection += intersectionArrasy[1].to_f
      sumPermuteBkpInt += intersectionArrasy[2].to_f
      sumFeaturePermuteBkpInt += intersectionArrasy[3].to_f

      sumIntersection2 += intersectionArrasy[0].to_f*intersectionArrasy[0].to_f
      sumSvLffIntersection2 += intersectionArrasy[1].to_f*intersectionArrasy[1].to_f
      sumPermuteBkpInt2 += intersectionArrasy[2].to_f*intersectionArrasy[2].to_f
      sumFeaturePermuteBkpInt2 += intersectionArrasy[3].to_f*intersectionArrasy[3].to_f
    }
    @average = sumIntersection.to_f/@iterations.to_f
    @svLffAverage = sumSvLffIntersection.to_f/@iterations.to_f
    @permuteBkpAverage = sumPermuteBkpInt.to_f/@iterations.to_f
    @featurePermuteBkpAverage = sumFeaturePermuteBkpInt.to_f/@iterations.to_f

    sdIntersection = Math::sqrt(sumIntersection2/@iterations.to_f-@average*@average)
    sdSvLffIntersection = Math::sqrt(sumSvLffIntersection2/@iterations.to_f-@svLffAverage*@svLffAverage)
    sdPermuteBkpInt = Math::sqrt(sumPermuteBkpInt2/@iterations.to_f-@permuteBkpAverage*@permuteBkpAverage)
    sdFeaturePermuteBkpInt = Math::sqrt(sumFeaturePermuteBkpInt2/@iterations.to_f-@featurePermuteBkpAverage*@featurePermuteBkpAverage)

    $stderr.puts "#{@iterations} iterations; avg = #{@average}"
    if (@average.to_f<1) then
      @average = 1
    end
    if (@svLffAverage<1) then
      @svLffAverage = 1
    end
    if (@permuteBkpAverage<1) then
      @permuteBkpAverage = 1
    end
    if (@featurePermuteBkpAverage<1) then
      @featurePermuteBkpAverage= 1
    end
    $stderr.puts "Enrichment #{@baseline.to_f/@average.to_f}"
    w = File.open(@output, "w")
    w.puts "#{File.basename(@lffFile1)}\t#{File.basename(@lffFile2)}\t#{@baseline}\t#{@average.to_f}\t#{@baselineSvLff}\t#{@svLffAverage}\t#{@iterations}\t#{@baseline.to_f/@average.to_f}\t#{pValue10Log10(@baseline,@average.to_f,sdIntersection)}\t#{@baselineSvLff.to_f/@svLffAverage.to_f}\t#{pValue10Log10(@baselineSvLff.to_f,@svLffAverage.to_f,sdSvLffIntersection)}\t#{@baselineBkpOverlap.to_f/@permuteBkpAverage.to_f}\t#{pValue10Log10(@baselineBkpOverlap.to_f,@permuteBkpAverage.to_f,sdPermuteBkpInt)}\t#{@baselineSvLff.to_f/@featurePermuteBkpAverage.to_f}\t#{pValue10Log10(@baselineSvLff.to_f,@featurePermuteBkpAverage.to_f,sdFeaturePermuteBkpInt)}\t"
    w.close()
  end
  
  def pValue10Log10(value, mean, sd)
    result = 1-GSL::Cdf::gaussian_P(value-mean, sd)
    if (value<mean) then
      result = GSL::Cdf::gaussian_P(value-mean, sd)
    end
    return result
  end
  
  def work()
    @fullScratch = "#{File.dirname(@output)}/annoEnrich.#{File.basename(@lffFile1)}.#{File.basename(@lffFile2)}.#{Process.pid}"
    system("mkdir -p #{@fullScratch}")
    ## load offsets
    loadOffsets()
    ## determine track names for the first file and second file
    ## determine intersection size
    flag=basicIntersection()
    if (flag==1) then
      system("rm -rf #{@fullScratch}")
      exit(2)
    end
    ## for 1 up to # iterations
    ## traverse second file
    ## permute annotations: 
    ##* get new coordinates
    ##* lookup actual chromosome coordinates
    ## generated permuted file
    ## generate intersection
    doSimulations()
    ## determine enrichment/loss; p-value using chi-square
    system("rm -rf #{@fullScratch}")
  end
  
  def AnnoEnrichmentAnalyzer.processArguments()
    # We want to add all the prop_keys as potential command line options
    optsArray = [ ['--chromosomeSizes', '-c', GetoptLong::REQUIRED_ARGUMENT],
		  ['--lffFile1',     	'-l', GetoptLong::REQUIRED_ARGUMENT],
		  ['--lffFile2',    	'-L', GetoptLong::REQUIRED_ARGUMENT],
		  ['--iterations',   	'-n', GetoptLong::REQUIRED_ARGUMENT],
		  ['--output',   	'-o', GetoptLong::REQUIRED_ARGUMENT],
		  ['--radius',		'-r', GetoptLong::REQUIRED_ARGUMENT],
		  ['--help',           	'-h', GetoptLong::NO_ARGUMENT]
		]
    
    progOpts = GetoptLong.new(*optsArray)
    optsHash = progOpts.to_hash
    AnnoEnrichmentAnalyzer.usage() if(optsHash.key?('--help'));
    
    unless(progOpts.getMissingOptions().empty?)
	    AnnoEnrichmentAnalyzer.usage("USAGE ERROR: some required arguments are missing") 
    end

    AnnoEnrichmentAnalyzer.usage() if(optsHash.empty?);
    return optsHash
  end
	
  def AnnoEnrichmentAnalyzer.usage(msg='')
    unless(msg.empty?)
	    puts "\n#{msg}\n"
    end
    puts "
PROGRAM DESCRIPTION:
  Utility that explores loss/enrichment of overlap between lff file1 and lff file2,
  by performing a permutation test on lff file2.

COMMAND LINE ARGUMENTS:
  --chromosomeSizes | -c   => tab delimited file containing chromosome names, srat in a linearized genome verstion, and their sizes
  --lffFile1        | -l   => first lff file
  --lffFile2        | -L   => second lff file
  --iterations      | -n   => number of iterations
  --radius          | -r   => number of iterations
  --output          | -o   => output report file
  --help            | -h   => [optional flag] Output this usage info and exit

USAGE:
  annoEnrichmentTool.rb  -r chromosomes.size -o report -l lffFile1 -L lffFile2 -n 100
";
			exit(2);
	end
end


########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = AnnoEnrichmentAnalyzer.processArguments()
# Instantiate analyzer using the program arguments
AnnoEnrichmentAnalyzer = AnnoEnrichmentAnalyzer.new(optsHash)
# Analyze this !
AnnoEnrichmentAnalyzer.work()
exit(0);
