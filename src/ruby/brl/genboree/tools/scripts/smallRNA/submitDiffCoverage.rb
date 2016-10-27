#!/usr/bin/env ruby

# Author : Sameer Paithankar


#Loading Libraries

require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'spreadsheet'


class SubmitDiffCoverage
  
  attr_accessor :lffFirst, :lffSecond, :mappedFirst, :mappedSecond, :outputDir, :file, :record, :trackHash1, :trackHash2, :count, :node
  
  def initialize(lffFirst, lffSecond, mappedFirst, mappedSecond, outputDir, node, file)
    
    @lffFirst = lffFirst
    @lffSecond = lffSecond
    @mappedFirst = mappedFirst.to_i
    @mappedSecond = mappedSecond.to_i
    @file = file
    
    if(node)
      @node = node.to_i
    else
      @node = 1
    end
    
    if(outputDir)
      @outputDir = outputDir
      system("mkdir -p #{@outputDir}")
    else
      @outputDir = Dir.pwd
    end
    
    
    submit()
    
  end
  
  def submit()
    
    begin
    
    
      scriptName="submitDiffCoverage_job.pbs"	
      scriptFile = File.open("#{scriptName}", "w")
      scriptFile.puts "#!/bin/bash";
      scriptFile.puts "#PBS -q dque";
      scriptFile.puts "#PBS -l nodes=1:ppn=#{@node}\n";
      scriptFile.puts "#PBS -l walltime=48:00:00\n";
      scriptFile.puts "#PBS -l cput=48:00:00\n";
      scriptFile.puts "#PBS -M #{ENV["USER"]}\@bcm.tmc.edu\n";
      scriptFile.puts "#PBS -m ea\n";
      scriptFile.puts "#PBS -N submitDiffCoverage.rb" 
      scriptFile.print "diffCoverage.rb -a #{@lffFirst} -b #{@lffSecond} -x #{@mappedFirst} -y #{@mappedSecond} -d #{@outputDir} -f #{@file} > #{@outputDir}/log.submitDiffCoverage 2>&1"
      scriptFile.close()
    
    # Submitting script on cluster
    
      command="qsub #{scriptName}"
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
    
  Program description: # Program for submitting diffCoverage.rb to the cluster
  Author: Sameer Paithankar
  

  
        
     
  Mandatory Arguments: 
    -a  --lffFirst  #Coverage file from the first sample
    -b  --lffSecond  #Coverage file from the second sample
    -x  --mappedFirst # No of reads mapped from the first sample
    -y  --mappedSecond # No of reads mapped from the second sample
    -d  --outputDir # Output Dir (default: pwd)
    -n  --node # Processors per node (default: 1)
    -f  --file  # output file names root
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
    methodName="performSubmitDiffCoverage"
    optsArray=[
      ['--lffFirst','-a',GetoptLong::REQUIRED_ARGUMENT],
      ['--lffSecond','-b',GetoptLong::REQUIRED_ARGUMENT],
      ['--mappedFirst','-x',GetoptLong::REQUIRED_ARGUMENT],
      ['--mappedSecond','-y',GetoptLong::REQUIRED_ARGUMENT],
      ['--outputDir','-d',GetoptLong::OPTIONAL_ARGUMENT],
      ['--node','-n',GetoptLong::OPTIONAL_ARGUMENT],
      ['--file','-f',GetoptLong::REQUIRED_ARGUMENT],
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
    
  def self.performSubmitDiffCoverage(optsHash)
    SubmitDiffCoverage.new(optsHash['--lffFirst'], optsHash['--lffSecond'], optsHash['--mappedFirst'], optsHash['--mappedSecond'], optsHash['--outputDir'], optsHash['--node'], optsHash['--file'])
  end
    
end


optsHash = RunScript.parseArgs()
RunScript.performSubmitDiffCoverage(optsHash)

