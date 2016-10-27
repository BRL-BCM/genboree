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
  ii = 0
  check = false
  fileOpen = File.open(@file)
  fileOpen1 = File.new(outputFile,"w+")
  fileOpen.each { |line|
     if(ii%4 == 0)
       check = false
      if(line =~/^\@(\S+)__(\d+)/ )
       if($1.size>=10 && $1.size<=30 && $2.to_i>=5)
         if($1 =~ /((A+)|(C+)|(G+)|(T+)|(N+))$/)
           if($1.size < 10)
             check = true
           end
         end
        end
      end
     end
     ii += 1
     if( check == true)
       fileOpen1.puts line
     end
      
   }
     
    
    
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
