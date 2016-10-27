#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC cnpLocke table to equivalent LFF version

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
                ['--cnpLockeFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
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
  Converts from UCSC cnpLocke table to equivalent LFF version.

  COMMAND LINE ARGUMENTS:
    --cnpLockeFile       | -r    => UCSC cnpLocke file to convert
    --trackName             | -t    => Track name for cnpLocke track.
                                       (type:subtype)
    --className             | -l    => Class name for cnpLocke track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  BRL_UCSC_cnpLocke.rb -r cnpLocke.txt.gz -t CNP:Locke -l 'Structural Variants' -i /users/ybai/work/Project2/converter_cnpLocke -f cnpLocke_LFF.txt -d /users/ybai/work/Project2/converter_cnpLocke
"
end

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    cnpLockeFile = inputsHash['--cnpLockeFile'].strip
    className = inputsHash['--className'].strip
    cDirectoryInput = inputsHash['--cDirectoryInput'].strip
    fileToOutput = inputsHash['--fileToOutput'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip

    unless(File.size?("#{cDirectoryInput}/#{cnpLockeFile}"))
      $stderr.puts "WARNING: the file '#{cnpLockeFile}' is empty. Nothing to do."
      exit(FAILED)
    end

    # Set the track type/subtype
    lffType, lffSubtype = inputsHash['--trackName'].strip.split(':')

    # Assign several colors for Gain, Loss, Gain and Loss
    gain_loss_color_hex = {
      'Gain' => '00ff00',
      'Loss' => 'ff0000',
      'Gain and Loss' => '0000ff'
    }

    # CONVERT cnpLocke TO LFF RECORDS USING WHAT WE HAVE SO FAR
    cnpLocke = Hash.new { |hh, kk| hh[kk] = 0 }
    # Open the file
    reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{cnpLockeFile}")
    line = nil
    begin
      open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
     # Go through each line
      reader.each { |line|
        next if(line =~ /^\s*#/ or line !~ /\S/)
        # Chop it up
        # bin chrom chromStart chromEnd name variationType 
        ff = line.chomp.split(/\t/)
        ff[1] = ff[1].to_sym	#chrom
        ff[2] = ff[2].to_i	#chromStart
        ff[3] = ff[3].to_i	#chromEnd
        ff[4].strip!  # name 
        cnpLocke[ff[4]] += 1
        ff[4] = ("#{ff[4]}.#{cnpLocke[ff[4]]}".to_sym) if(cnpLocke[ff[4]] > 1)
        ff[5] = ff[5].to_sym	#variationType

        if("#{ff[5]}".eql?("Gain"))
          assigned_color = gain_loss_color_hex['Gain']
        elsif("#{ff[5]}".eql?("Loss"))
          assigned_color = gain_loss_color_hex['Loss']
        elsif("#{ff[5]}".eql?("Gain and Loss"))
          assigned_color = gain_loss_color_hex['Gain and Loss']
        end

        # Dump each linked feature as LFF
        ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
        f.print "#{className}\t#{ff[4]}\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t+\t.\t1.0\t.\t.\t"
        ## attributes in order of useful information (in LFF anyway)
        # variationType
        f.print "variationType=#{ff[5]}; annotationColor=##{assigned_color}"
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
