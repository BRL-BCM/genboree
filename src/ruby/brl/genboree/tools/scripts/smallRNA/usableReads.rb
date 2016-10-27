#!/usr/bin/env ruby
#Script for getting usable Reads by extending smallRNA pipeline

require 'rubygems'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'stringio'
require 'zlib'
require 'ap'
require 'bigdecimal'

class Usable

  def initialize(optsHash)
    @file     = optsHash['--file']
    @output   = optsHash['--output']
  end


  def readFasta()
  outputFile = @output+"_new_filtered.fastq"  
  r = File.open(@file)
    w = File.open(outputFile, "w")
    
    done = false
    while ! done
      l1 = r.gets
      l2 = r.gets
      l3 = r.gets
      l4 = r.gets
      
      break if (l1.nil?||l2.nil?||l3.nil?||l4.nil?)
      sequence = l2.strip
      l1=~/_(\d+)/
      count = $1.to_i
      result = false
      if (sequence.size>=10 && sequence.size <=30 && count >=5) then
        if (sequence=~/(A+|C+|G+|N+|T+)$/) then
          if ($1.size>=9) then
            result = false
          else
            result = true
          end
        else
          result = true
        end
      end
      if (result) then
        w.print l1
        w.print l2
        w.print l3
        w.print l4
      end
    end
    
    r.close()
    w.close()
  end


  # Process Arguements form the command line input
  def Usable.processArguements()
    # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--file'  ,    '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--output',    '-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--help'       ,'-h',GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      Usable.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
    
      Usable if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
  end
  
  
  # Display usage info and quit.
  def Usable.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "

  PROGRAM DESCRIPTION:
    keep track of reads
    -- having length >=10 and <= 30
    -- occur at least 4 times
    -- reads end up in AAAA, CCCC, GGGG and TTTT with streak of the nucleotide' length <= 9
   
  COMMAND LINE ARGUMENTS:
    --file         | -f => fastq file ( see below for example)
    --output       | -o => Output directroy with base name
    --help         | -h => [Optional flag]. Print help info and exit.

  usage:
 
  usableReads.rb -f 'file.fastq' -o /home1/s_1


  ";
      exit;
  end # 
end

# Process command line options
 optsHash = Usable.processArguements()
 exp = Usable.new(optsHash)
 exp.readFasta
