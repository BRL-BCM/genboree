#!/usr/bin/env ruby

require 'brl/util/textFileUtil'
require 'brl/util/util'

# Program for making a reads offset file from a fasta file with reads (after being processed by prepareSmallRna.rb)
#Author: Sameer Paithankar
#Loading Libraries


class ReadsOffset
  
  attr_accessor :readsFile, :outputFile, :name, :offset, :length, :numberOfSequences
  
  def initialize(readsFile, outputFile)
    
    @readsFile = readsFile
    @outputFile = outputFile
    @outputFile = File.open(@outputFile, "w")
    
    @name = nil
    @offset = 0
    @length = 0
    
    numberOfRecords = countLines()
    
    if(numberOfRecords.to_i < 1)
      puts "#{@readsFile} is empty"
    end
    
    @numberOfSequences = numberOfRecords.to_i / 2

    makeFile()
    
  end

  def countLines
    
    reader = BRL::Util::TextReader.new(@readsFile)
    counter = 0
    reader.each { |line|
      counter +=1 
    }
    return counter  
  end
  
  def makeFile
    
    ff = File.new("#{@readsFile}")
    @offset = 0
    @numberOfSequences.times { |ii|
      
      
      @name = ff.readline
      @name = @name.chomp.split(">")
      @name = @name[1]
      temp = ff.readline
      temp = temp.chomp
      @length = temp.size
      @outputFile.print "#{@name}\t#{@offset}\t#{@length}\n"
      @offset = @offset + @length
    }
    
  end
  
end


class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="
    
  Program description: # Program for making a reads offset file from a fasta file with reads (after being processed by prepareSmallRna.rb)

        
     
  Mandatory Arguments: 
    
    -r  --readsFile  #read file in fasta format (generated from prepareSmallRna.rb) 
    -o  --outputFile  #output file
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
    methodName="performMakeReadsOffset"
    optsArray=[
      ['--readsFile','-r',GetoptLong::REQUIRED_ARGUMENT],
      ['--outputFile','-o',GetoptLong::REQUIRED_ARGUMENT],
      ['--version','-v',GetoptLong::NO_ARGUMENT],
      ['--help','-h',GetoptLong::NO_ARGUMENT]
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
    
  def self.performMakeReadsOffset(optsHash)
    ReadsOffset.new(optsHash['--readsFile'], optsHash['--outputFile'])
  end
    
end

optsHash = RunScript.parseArgs()
RunScript.performMakeReadsOffset(optsHash)
