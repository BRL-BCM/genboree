#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC snp_128 file to equivalent LFF version
# and output 1+ tracks

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'

# ##############################################################################
# CONSTANTS
# ##############################################################################
FATAL = BRL::Genboree::FATAL
OK = BRL::Genboree::OK
OK_WITH_ERRORS = BRL::Genboree::OK_WITH_ERRORS
FAILED = BRL::Genboree::FAILED
USAGE_ERR = BRL::Genboree::USAGE_ERR

# ##############################################################################
# HELPER FUNCTIONS AND CLASS
# ##############################################################################

def processArguments()
  optsArray = [
                ['--trackName', '-t', GetoptLong::REQUIRED_ARGUMENT],
                ['--className', '-l', GetoptLong::REQUIRED_ARGUMENT],
                ['--cDirectoryInput', '-i', GetoptLong::REQUIRED_ARGUMENT],
                ['--fileToOutput', '-f', GetoptLong::REQUIRED_ARGUMENT],
                ['--cDirectoryOutput', '-d', GetoptLong::REQUIRED_ARGUMENT],

                ['--snps128File', '-o', GetoptLong::REQUIRED_ARGUMENT],
                ['--help', '-h', GetoptLong::NO_ARGUMENT]
              ]
  progOpts = GetoptLong.new(*optsArray)
  optsHash = progOpts.to_hash
  # Try to use getMissingOptions() from Ruby's standard GetoptLong class
  optsMissing = progOpts.getMissingOptions()
  # If no argument given or request help information, just print usage...
  if(optsHash.empty? or optsHash.key?('--help'))
    usage()
    exit(USAGE_ERR)
  # If there is NOT any required argument file missing, then return an empty array; otherwise, report error
  elsif(optsMissing.length != 0)
    usage("Error: the REQUIRED args are missing!")
    exit(USAGE_ERR)
  else
    return optsHash
  end
end

def usage(msg='')
  puts "\n#{msg}\n" unless(msg.empty?)
  puts "

PROGRAM DESCRIPTION:
  Convert from UCSC multiple files (NIMH Bipolar Disease) to equivalent LFF version.  

  COMMAND LINE ARGUMENTS:
    --trackName             | -t    => Track name for Polymorphisms:SNPs (128) track.
                                       (type:subtype)
    --className             | -l    => Class name for Polymorphisms:SNPs (128) track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file

    --snps128File       | -o    => UCSC SNPs (128) file to convert
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  i.e. BRL_UCSC_snps128.rb -t 'Polymorphisms:SNPs (128)'  -l 'Structural Variants' -i /users/ybai/work/Project4/SNPs_128 -f SNPs_128_LFF.txt -d /users/ybai/work/Project4/SNPs_128 -o snp128.txt.gz
"
end

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    # Set the track type/subtype
    snps128File = inputsHash['--snps128File'].strip
    lffType, lffSubtype = inputsHash['--trackName'].strip.split(':')
    className = inputsHash['--className'].strip
    cDirectoryInput = inputsHash['--cDirectoryInput'].strip
    fileToOutput = inputsHash['--fileToOutput'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip

    unless(File.size?("#{cDirectoryInput}/#{snps128File}"))
      $stderr.puts "WARNING: the file '#{snps128File}' is empty. Nothing to do."
      exit(FAILED)
    end

    # Set the track type/subtype
    lffType, lffSubtype = inputsHash['--trackName'].strip.split(':')

    # CONVERT cnpLocke TO LFF RECORDS USING WHAT WE HAVE SO FAR
    snps128 = Hash.new { |hh, kk| hh[kk] = 0 }

    # Open the file
    reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{snps128File}")
    line = nil
    begin
      open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
     # Go through each line
      reader.each { |line|
        next if(line =~ /^\s*#/ or line !~ /\S/)
        # Chop it up
        # bin chrom chromStart chromEnd name variationType 
        ff = line.chomp.split(/\t/)
        ff[1] = ff[1].to_sym    #chrom
        ff[2] = ff[2].to_i      #chromStart
        ff[3] = ff[3].to_i      #chromEnd
        ff[4].strip!  # name 
        snps128[ff[4]] += 1
        ff[4] = ("#{ff[4]}.#{snps128[ff[4]]}".to_sym) if(snps128[ff[4]] > 1)
        ff[5] = ff[5].to_i    #score
        ff[6] = ff[6].to_sym  #strand
        ff[7] = ff[7].to_sym  #refNCBI
        ff[8] = ff[8].to_sym  #refUCSC
        ff[9] = ff[9].to_sym  #observed
        ff[10] = ff[10].to_sym  #molType
        ff[11] = ff[11].to_sym  #class
        ff[12] = ff[12].to_sym  #valid
        ff[13] = ff[13].to_sym  #avHet
        ff[14] = ff[14].to_sym  #avHetSE
        ff[15] = ff[15].to_sym  #func
        ff[16] = ff[16].to_sym  #locType
        ff[17] = ff[17].to_sym  #weight
   
        # Dump each linked feature as LFF
        ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
        f.print "#{className}\t#{ff[4]}\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t#{ff[6]}\t.\t#{ff[5]}\t.\t.\t"
        ## attributes in order of useful information (in LFF anyway)
        f.print "refNCBI=#{ff[7]}; refUCSC=#{ff[8]}; observed=#{ff[9]}; molType=#{ff[10]}; class=#{ff[11]}; valid=#{ff[12]}; avHet=#{ff[13]}; avHetSE=#{ff[14]}; func=#{ff[15]}; locType=#{ff[16]}; weight=#{ff[17]}"
        # sequence (none)
        f.print "\t.\t"
        # summary (free form comments)
        f.print "."

        # done with record
        f.puts ""
      } # reader close
      reader.close
      end
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit(OK_WITH_ERRORS)
    end
  end
end


# ##############################################################################
# MAIN
# ##############################################################################
$stderr.puts "#{Time.now} BEGIN (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
begin
  optsHash = processArguments()
  converter = MyConverter.new(optsHash)
  converter.convert(optsHash)
  $stderr.puts "#{Time.now} DONE"
  exit(OK)
rescue => err
  $stderr.puts "Error occurs... Details: #{err.message}"
  $stderr.puts err.backtrace.join("\n")
  exit(FATAL)
end
