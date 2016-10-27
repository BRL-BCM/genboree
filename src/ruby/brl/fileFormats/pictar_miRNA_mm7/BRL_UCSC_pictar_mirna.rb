#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC PicTar miRNA Data table to equivalent LFF version

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
# Process command line args
# Note:
#      - did not find optional extra alias files
def processArguments()
  optsArray = [
                ['--picTarmiRNAFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
                ['--trackName', '-t', GetoptLong::REQUIRED_ARGUMENT],
                ['--className', '-l', GetoptLong::REQUIRED_ARGUMENT],
                ['--cDirectoryInput', '-i', GetoptLong::REQUIRED_ARGUMENT],
                ['--fileToOutput', '-f', GetoptLong::REQUIRED_ARGUMENT],
                ['--cDirectoryOutput', '-d', GetoptLong::REQUIRED_ARGUMENT],
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
  Converts from UCSC PicTar miRNA data table to equivalent LFF version.

  COMMAND LINE ARGUMENTS:
    --picTarmiRNAFile       | -r    => UCSC PicTar miRNA data file to convert
    --trackName             | -t    => Track name for PicTar miRNA data track.
                                       (type:subtype)
    --className             | -l    => Class name for PicTar miRNA data track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  BRL_UCSC_pictar_mirna.rb -r picTarMiRNADog.txt.gz -t 'MicroRNA:PicTar' -l 'Expression and Regulation' -i /users/ybai/work/Project6/Expression_Regulation/PicTar_miRNA -f picTarMiRNADog_LFF.txt -d /users/ybai/work/Project6/Expression_Regulation/PicTar_miRNA

"
end

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    picTarmiRNAFile = inputsHash['--picTarmiRNAFile'].strip
    className = inputsHash['--className'].strip
    cDirectoryInput = inputsHash['--cDirectoryInput'].strip
    fileToOutput = inputsHash['--fileToOutput'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip

    unless(File.size?("#{cDirectoryInput}/#{picTarmiRNAFile}"))
      $stderr.puts "WARNING: the file '#{picTarmiRNAFile}' is empty. Nothing to do."
      exit(FAILED)
    end

    # Set the track type/subtype
    lffType, lffSubtype = inputsHash['--trackName'].strip.split(':')


    # CONVERT knownGene TO LFF RECORDS USING WHAT WE HAVE SO FAR
    picTarmiRNA = Hash.new { |hh, kk| hh[kk] = 0 }
    # Open the file
    reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{picTarmiRNAFile}")
    line = nil
    begin
      open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
     # Go through each line
      reader.each { |line|
        next if(line =~ /^\s*#/ or line !~ /\S/)
        # Chop it up
        ff = line.chomp.split(/\t/)
        ff[1] = ff[1].to_sym	#chrom
        ff[2] = ff[2].to_i	#chromStart
        ff[3] = ff[3].to_i	#chromEnd
        ff[4].strip!
        picTarmiRNA[ff[4]] += 1  
        ff[4] = ("#{ff[4]}.#{picTarmiRNA[ff[4]]}".to_sym) if(picTarmiRNA[ff[4]] >= 1)
        ff[5] = ff[5].to_i	#score
        ff[6] = ff[6].to_sym	#strand
        ff[7] = ff[7].to_i	#thickStart
        ff[8] = ff[8].to_i	#thickEnd
        ff[9] = ff[9].to_i	#reserved

        f.print "#{className}\t#{ff[4]}\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t#{ff[6]}\t.\t#{ff[5]}\t.\t.\t"
        f.print "thickStart=#{ff[7]}; thickEnd=#{ff[8]}; reserved=#{ff[9]}; "
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
