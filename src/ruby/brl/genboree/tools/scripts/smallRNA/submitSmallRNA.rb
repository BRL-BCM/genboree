#!/usr/bin/env ruby

#Program for submitting a cluster job for prepareSmallRNA.rb (removing adaptor sequences from small RNAs) and PASH-3.0 (mapping small RNAs to reference genome)

#Author: Sameer Paithankar

#Loading Libraries

require 'brl/util/textFileUtil'
require 'brl/util/util'



class SubmitSmallRNA

  attr_accessor :readsFile, :outputDir, :targetGenome, :kWeight, :maxMapping
  attr_accessor :scratch, :diagonals, :gap, :topPercent, :ignorePercent
  attr_accessor :nodes, :kspan
	
  def initialize(readsFile, outputDir, targetGenome, kWeight, maxMapping, scratch, diagonals, gap, topPercent, ignorePercent, nodes, kspan)

    @readsFile=readsFile
    @outputDir=outputDir
    @targetGenome=targetGenome
    
    if(kWeight)
      @kWeight=kWeight.to_i
    else
      @kWeight=12
    end
    
    if(maxMapping)
      @maxMapping=maxMapping.to_i
    else
      @maxMapping=1
    end
    
    @scratch=scratch
    
    if(diagonals)
      @diagonals=diagonals.to_i
    else
      @diagonals=500
    end
    
    if(gap)
      @gap=gap.to_i
    else
      @gap=6
    end
    
    if(topPercent)
      @topPercent=topPercent.to_i
    else
      @topPercent=1
    end
    
    if(ignorePercent)
      @ignorePercent=ignorePercent.to_i
    end
    
    if(nodes)
      @nodes=nodes.to_i
    else
      @nodes=1
    end
    
    if(kspan)
      @kspan=kspan.to_i
    else
      @kspan=18
    end
    
    system("mkdir -p #{@outputDir}") # Making Output Directory 
    
    sleep(2)
    
    submit() # Method for creating and submitting script to cluster  
    
  end
    
  def submit  
    
    dName=File.basename(@outputDir)
    
    # Creating script for submission
    
    begin
    
      baseName = File.basename(@readsFile)
      scriptName="submitSmallRNA_job.pbs"	
      scriptFile = File.open("#{@outputDir}/#{scriptName}", "w")
      scriptFile.puts "#!/bin/bash";
      scriptFile.puts "#PBS -q dque";
      scriptFile.puts "#PBS -l nodes=1:ppn=#{@nodes}\n";
      scriptFile.puts "#PBS -l walltime=24:00:00\n";
      scriptFile.puts "#PBS -l cput=24:00:00\n";
      #scriptFile.puts "#PBS -l ppn=1\n";
      scriptFile.puts "#PBS -M #{ENV["USER"]}\@bcm.tmc.edu\n";
      scriptFile.puts "#PBS -m ea\n";
      scriptFile.puts "#PBS -N submit_prepareSmallRNA_PASH3.0" 
      scriptFile.puts "prepareSmallRNA.rb -r #{@readsFile} -o #{@outputDir}"
      scriptFile.puts "sleep 2"
      scriptFile.puts "#PBS -o #{@outputDir}/#{dName}.pash3.#{Process.pid}.o";
      scriptFile.puts "#PBS -e #{@outputDir}/#{dName}.pash3.#{Process.pid}.e";
      scriptFile.puts "time pash-3.0.exe -v #{@outputDir}/#{baseName}_WithoutAdaptors.fa -h #{@targetGenome} -k #{@kWeight} -n #{@kspan} -S #{@scratch} -s 22 -G #{@gap} -d #{@diagonals} -o #{@outputDir}/#{baseName}.pash3.0Map.output.txt -N #{@maxMapping}" 
      scriptFile.puts "sleep 2"
      scriptFile.close()
    
    # Submitting script on cluster
    
    command="qsub #{@outputDir}/#{scriptName}"
    system(command)
    
    rescue => err
        
      $stderr.puts "Details: #{err.message}"
      return -1
      
    end
    
    
  end

end

class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="
    
  Program description: #Program for submitting a cluster job for prepareSmallRNA.rb (for trimming adaptor from small RNA reads) and mapping job (Pash-3.0)
        
     
  Mandatory Arguments: 
    
    -r  --readsFile  #read file in fasta format 
    -o  --outputDir  #output Dir for storing all output files.
    -t  --targetGenome #reference genome
    -k  --kWeight #kmer weight (default 12)
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
    
    Usage: submitSmallRNA.rb -r file.fa -o outputDir -t target.fa
    
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
    methodName="performSubmitSmallRNA"
    optsArray=[
      ['--readsFile','-r',GetoptLong::REQUIRED_ARGUMENT],
      ['--outputDir','-o',GetoptLong::REQUIRED_ARGUMENT],
      ['--targetGenome','-t',GetoptLong::REQUIRED_ARGUMENT],
      ['--kWeight','-k',GetoptLong::OPTIONAL_ARGUMENT],
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
    
  def self.performSubmitSmallRNA(optsHash)
    SubmitSmallRNA.new(optsHash['--readsFile'], optsHash['--outputDir'], optsHash['--targetGenome'], optsHash['--kWeight'], optsHash['--maxMapping'], optsHash['--scratch'], optsHash['--diagonals'], optsHash['--gap'], optsHash['--topPercent'], optsHash['--ignorePercent'], optsHash['--nodes'], optsHash['--kspan'])
  end
    
end


optsHash = RunScript.parseArgs()
RunScript.performSubmitSmallRNA(optsHash)
	


