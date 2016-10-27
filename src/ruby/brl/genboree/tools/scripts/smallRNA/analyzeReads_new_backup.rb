#!/usr/bin/env ruby


# Program for preparing reads (removing adaptors), mapping (Pash-3.0), intersection with lff annotations and generating a comprehensive report

# The program is a wrapper for prepareSmallRNA.rb, pash-3.0.exe, makeReadsOffset.rb and accountForMappings.rb

# Author : Sameer Paithankar


#Loading Libraries

require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'spreadsheet'


class AnalyzeReads
  
  attr_accessor :readsFile, :outputDir, :targetGenome, :kWeight, :maxMapping
  attr_accessor :scratch, :diagonals, :gap, :topPercent, :ignorePercent, :usableReads
  attr_accessor :nodes, :kspan, :refGenome, :basename, :lffFile, :readName
  
 
  #Initializes all the variables and runs the following commands
  #  - prepareSmallRNA.rb
  #  - pash-3.0.exe
  #  - accountForMappings.rb
  def initialize(readsFile, outputDir, targetGenome, kWeight, refGenome, lffFile, maxMapping, scratch, diagonals, gap, topPercent, ignorePercent, nodes, kspan)
    
    @readsFile = readsFile
    @refGenome = refGenome
    if(outputDir)
      @outputDir = outputDir
    else
      @outputDir = Dir.pwd
    end
    @readName = File.basename(@readsFile)
    @readName = @readName.split(".")
    @readName = readName[0]
    @targetGenome = targetGenome
    @lffFile = lffFile
    if(kWeight)
      @kWeight = kWeight.to_i
    else
      @kWeight = 12
    end
    
    if(maxMapping)
      @maxMapping = maxMapping.to_i
    else
      @maxMapping = 1
    end
    
    @scratch = scratch
    
    if(diagonals)
      @diagonals = diagonals.to_i
    else
      @diagonals = 500
    end
    
    if(gap)
      @gap = gap.to_i
    else
      @gap = 6
    end
    
    if(topPercent)
      @topPercent = topPercent.to_i
    else
      @topPercent = 1
    end
    
    if(ignorePercent)
      @ignorePercent = ignorePercent.to_i
    end
    
    if(nodes)
      @nodes = nodes.to_i
    else
      @nodes = 1
    end
    
    if(kspan)
      @kspan = kspan.to_i
    else
      @kspan = 18
    end
    
   
    
    @baseName = File.basename(@readsFile)
    
    system("mkdir -p #{@outputDir}")
    
    fastQType = isFastQ() # Is the reads file FastQ?
    puts "Is the file fastQ? #{fastQType}"
    
    if(fastQType)
      #convertFastaToFastQ()
      puts "Finished converting to FASTA from FastQ"
    end
    
    removeAdaptors() # Wrapper for prepareSmallRNA.rb
    puts "Adaptors removed ....."
    
    generateFastQ() # Wrapper for convertFastaQualToFastQ.rb
    puts "FastQ trimmed files generated"
    
    map() # Wrapper for pash-3.0.exe
    puts "Mapping done......"
    
    analyze() # Wrapper for accountForMappings.rb
    puts "Mappings analyzed..."

    
    puts "All done...."
  
  end
  
  #Wrapper to run the prepareSmallRNA.rb script and convertFastaQualToFastQ.rb
  def removeAdaptors
    
    command = "prepareSmallRNA.fastq_backup.rb -r #{@readsFile} -o #{@outputDir} > #{@outputDir}/log.prepareSmallRNA 2>&1"
    system(command)
    $stderr.puts "prepareSmallRNA command = #{command}"
  end
  
  #Wrapper to run the convertFastaQualToFastQ script inside a loop
  def generateFastQ
    command2 = "for f in #{@outputDir}/#{@baseName}_WithoutAdaptors.fa; do echo $f; convertFastaQualToFastQ.rb -f $f -i 40 -o $f.fastq; done"
    system(command2)
    $stderr.puts "convertFastaQualToFastQ command = #{command2}"
    
  end
  
  #Wrapper to run pash-3.0.exe
  def map
    
    #command = "ruby usableReads.rb -f #{@outputDir}/#{@baseName}_WithoutAdaptors.fa.fastq -o #{@outputDir}/#{@baseName}> usable_error.log"
    #system(command)
    

   command = "pash-3.0lx.exe -v #{@outputDir}/#{@baseName}.output.tags -h #{@targetGenome} -k #{@kWeight} -n #{@kspan} -S #{@scratch} -s 22 -G #{@gap} -d #{@diagonals} -o #{@outputDir}/#{@baseName}.pash3.0.Map.output.txt -N #{@maxMapping} > #{@outputDir}/log.pash-3.0 2>&1"
    #command = "pash-3.0lx.exe -v #{@outputDir}/#{@baseName}_WithoutAdaptors.fa.fastq -h #{@targetGenome} -k #{@kWeight} -n #{@kspan} -S #{@scratch} -s 22 -G #{@gap} -d #{@diagonals} -o /scratch/#{@basename} -N #{@maxMapping} > #{@outputDir}/log.pash-3.0 2>&1"
   
    
    
    system(command)
    #system("mv #{@scratch} @outputDir}/#{@baseName}.pash3.0.Map.output.txt")
    $stderr.puts "pash command = #{command}"
  
  end
  
  #Wrapper to run the accountForMappings.rb script
  def analyze
    
    system("mv /scratch/#{@basename} @outputDir}/#{@baseName}.pash3.0.Map.output.txt")
    command = "accountForMappings.rb -p #{@outputDir}/#{@baseName}.pash3.0.Map.output.txt -o #{@outputDir} -r #{@outputDir}/#{@baseName}_WithoutAdaptors.fa -R #{@refGenome} -l #{@lffFile} }"
    system(command)
    $stderr.puts "accountForMappings command = #{command}"
  
  end
  
  def isFastQ
    returns = false
    
    checkFile = BRL::Util::TextReader.new(@readsFile)
    checkFile.each { | line |
      if(line[0,1] == "@")
        returns = true
      end
      
      break
    }    
    
    returns
  end
  
  def convertFastaToFastQ()
    $stderr.puts "Start summary fastq #{Time.now()}"
    @totalTags = 0
    @forwardTrimmed = 0
    @notTrimmed = 0
    
    presortedFastqFile = "#{@outputDir}/#{@baseName}.presorted.fastq.#{Process.pid}"
    sortedFastqFile = "#{@outputDir}/#{@baseName}.sorted.fastq.#{Process.pid}"
    @summaryReadsFile = "#{@outputDir}/#{@baseName}.summary.fastq.#{Process.pid}"
    presortedWriter = BRL::Util::TextWriter.new(presortedFastqFile)
    
    inputReader = BRL::Util::TextReader.new(@readsFile)
    inputReader.each {|l|
      if (inputReader.lineno%4==2) then
        presortedWriter.print l
        @totalTags += 1
      end
    }
    presortedWriter.close()
    inputReader.close()
    
    sortCmd = "sort -T #{@outputDir} -o #{sortedFastqFile} #{presortedFastqFile}"
    $stderr.puts "sort command #{sortCmd}"
    system(sortCmd)
    summaryWriter = BRL::Util::TextWriter.new(@summaryReadsFile)
    sortedReader = BRL::Util::TextReader.new(sortedFastqFile)
    count = 0
    prevSeq = nil
    qualString = nil
    sortedReader.each {|l|
      if (l.strip == prevSeq) then
        count += 1
      else
        if (!prevSeq.nil?) then
          trimmedTag = removeAdapter(prevSeq)
          if (trimmedTag.size==prevSeq.size) then
            @notTrimmed += count
          else
            @forwardTrimmed += count
          end
          if (trimmedTag.size>0) then
            qualString = "h"*trimmedTag.size
            summaryWriter.puts "#{trimmedTag}\t#{count}"  
          end
          
        end
        prevSeq = l.strip
        count = 1
      end
    }
    if (!prevSeq.nil?) then
      trimmedTag = removeAdapter(prevSeq)
      if (trimmedTag.size==prevSeq.size) then
        @notTrimmed += count
      else
            @forwardTrimmed += count
      end
      if (trimmedTag.size>0) then
        qualString = "h"*trimmedTag.size
        summaryWriter.puts "#{trimmedTag}\t#{count}"  
      end
    end
    sortedReader.close()
    summaryWriter.close()
    $stderr.puts "Finished tag trimming step at #{Time.now()}"
    system("unlink #{presortedFastqFile}")
    system("unlink #{sortedFastqFile}")
    sortedTrimmedTagsFile = "#{@outputDir}/#{@baseName}.trimmed.tags.#{Process.pid}"

    sortCmd = "sort -k1,1 -T #{@outputDir} -o #{sortedTrimmedTagsFile} #{@summaryReadsFile}"
    system(sortCmd)
    
    
    outputWriter = BRL::Util::TextWriter.new("#{@outputDir}/#{@baseName}.output.tags.#{Process.pid}")
    sortedTrimmedTagsReader = BRL::Util::TextReader.new(sortedTrimmedTagsFile)
    count = 0
    prevSeq = nil
    qualString = nil
    sortedTrimmedTagsReader.each {|l|
      ff = l.strip.split(/\t/)
      if (ff[0] == prevSeq) then
        count += ff[1].to_i
      else
        if (!prevSeq.nil?) then
          #qualString = "h"*prevSeq.size
          #outputWriter.puts "@#{prevSeq}__#{count}\n#{prevSeq}\n+\n#{qualString}"
          outputWriter.puts ">#{count}\n#{prevSeq}"
        end
        prevSeq = ff[0]
        count = ff[1].to_i
      end
    }
    if (!prevSeq.nil?) then
      #qualString = "h"*prevSeq.size
      #outputWriter.puts "@#{prevSeq}__#{count}\n#{prevSeq}\n+\n#{qualString}"
      outputWriter.puts ">#{count}\n#{prevSeq}"
    end
    sortedTrimmedTagsReader.close()
    outputWriter.close()
    system("unlink #{sortedTrimmedTagsFile}")
    system("unlink #{@summaryReadsFile}")
    $stderr.puts "Done with summary fastq #{Time.now()}"
    
    @readsFile = "#{@outputDir}/#{@baseName}.output.tags.#{Process.pid}"
    @baseName = File.basename(@readsFile)
  end
  
  def removeAdapter_old(tag)
    populateSubAdapterSequences()
    @discardedShortTags = 0
    
    trimTag = tag
    reverseTag = tag.reverse.tr("actgnACTGN", "TGACNTGACN")
    trimReverseTag = reverseTag  
    # now check for subadapter substring
    @adapterArray.each {|a|
      ind = tag.index(a)
      #$stderr.puts "#{a} --> #{ind}"
      if (!ind.nil?) then
        trimTag = tag[0,ind]
        trimTag = "" if (trimTag.nil?)
        if (trimTag.size < 10) then
          #$stderr.puts "tag #{tag} trims to #{trimTag} by #{a}, which is too short"
          @discardedShortTags += 1
          trimTag = ""
        end
        break
      end
    }

  
    #$stderr.puts "R: #{reverseTag}"
    # now check for subadapter substring
    @adapterArray.each {|a|
      ind = reverseTag.index(a)
      #$stderr.puts "R: #{a} --> #{ind}"
      if (!ind.nil?) then
        trimReverseTag = reverseTag[0,ind]
        trimReverseTag = "" if (trimReverseTag.nil?)
        if (trimReverseTag.size < 10) then
          #$stderr.puts "reverse tag #{reverseTag} trims to #{trimReverseTag} by #{a}, which is too short"
          if (trimTag.size > 0) then
            trimTag = ""
            @discardedShortTags += 1
          end
          trimReverseTag = ""
        end
        break
      end
    }
    return trimTag
  end
  
  def removeAdapter(tag) # [AN][TN][CN][TN][CN][GN]
	trimTag = tag
	if (tag =~ /(.*)[AN][TN][CN][TN][CN][GN]/) then
		trimTag = $1
	end
	return trimTag
  end    
  
  def populateSubAdapterSequences
    adapter = "TCGTATGCCGTCTTCTGCTTG"
    @adapterArray = []
    adapterSize = adapter.size
    adapterSize.downto(5) { |i|
      subAdaptor = adapter[0, i]
      #$stderr.puts "added subadapter #{subAdaptor}"
      @adapterArray.push(subAdaptor)
    }
  end
  
end




class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="
    
  Program description: # Program for preparing reads (removing adaptors), mapping (Pash-3.0), intersection with lff annotations and generating a comprehensive report
  
  # The program is a wrapper for prepareSmallRNA.rb, pash-3.0.exe, makeReadsOffset.rb and accountForMappings.rb
  
  #Note : use . as scratch

  
        
     
  Mandatory Arguments: 
    
    -r  --readsFile  #reads file 
    -o  --outputDir #output directory
    -t  --targetGenome #reference genome
    -k  --kWeight #kmer weight (default 12)
    -R  --refGenome # chromosome offset file
    -L  --lffFile # lff File for intersection
    -n  --maxMapping  #[optional] maximum number of mappings within
                              top percent of best score  (default 1). Reads
                              with a larger number of mappings that this
                              value are discarded from mapping results
    
    -s  --scratch # scratch directory
    -d  --diagonals #number of diagonals, default 500
    -G  --gap #gap, default 6
    -P  --topPercent  #[optional] top percent of mappings to be kept
                              (default 1)
    
    -i  --ignorePercent #ignore below this percent
    -N  --nodes # processors per node, default 1
    -l  --kspan # kmer length (default 18)
    -v  --version #Version of the program
    -h  --help #Display help 
    
    Usage: 
    
  "
  def self.printUsage(additionalInfo=nil)
      puts DEFAULTUSAGEINFO
      puts additionalInfo unless(additionalInfo.nil?)
      if(additionalInfo.nil?)
        exit(0)
      else
        exit(15)
      end
    end
    
  def self.printVersion()
    puts VERSION_NUMBER
    exit(0)
  end
    
  def self.parseArgs()
    methodName="performAnalyzeReads"
    optsArray=[
      ['--readsFile','-r',GetoptLong::REQUIRED_ARGUMENT],
      ['--outputDir','-o',GetoptLong::OPTIONAL_ARGUMENT],
      ['--targetGenome','-t',GetoptLong::REQUIRED_ARGUMENT],
      ['--kWeight','-k',GetoptLong::OPTIONAL_ARGUMENT],
      ['--refGenome','-R',GetoptLong::OPTIONAL_ARGUMENT],
      ['--lffFile','-L',GetoptLong::OPTIONAL_ARGUMENT],
      ['--maxMapping','-n',GetoptLong::OPTIONAL_ARGUMENT],
      ['--scratch','-s',GetoptLong::REQUIRED_ARGUMENT],
      ['--diagonals','-d',GetoptLong::OPTIONAL_ARGUMENT],
      ['--gap','-G', GetoptLong::OPTIONAL_ARGUMENT],
      ['--topPercent','-P', GetoptLong::OPTIONAL_ARGUMENT],
      ['--ignorePercent','-i', GetoptLong::OPTIONAL_ARGUMENT],
      ['--nodes','-N', GetoptLong::OPTIONAL_ARGUMENT],
      ['--kspan','-l', GetoptLong::OPTIONAL_ARGUMENT],
      ['--version','-v',GetoptLong::NO_ARGUMENT],
      ['--help','-h',GetoptLong::NO_ARGUMENT],
    ]
    progOpts=GetoptLong.new(*optsArray)
    optsHash=progOpts.to_hash
    if(optsHash.key?('--help'))
      printUsage()
    elsif(optsHash.key?('--version'))
      printVersion()
    end
    printUsage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    return optsHash
  end
    
  def self.performAnalyzeReads(optsHash)
    AnalyzeReads.new(optsHash['--readsFile'], optsHash['--outputDir'], optsHash['--targetGenome'], optsHash['--kWeight'], optsHash['--refGenome'], optsHash['--lffFile'], optsHash['--maxMapping'], optsHash['--scratch'], optsHash['--diagonals'], optsHash['--gap'], optsHash['--topPercent'], optsHash['--ignorePercent'], optsHash['--nodes'], optsHash['--kspan'])
  end
    
end


optsHash = RunScript.parseArgs()
RunScript.performAnalyzeReads(optsHash)
