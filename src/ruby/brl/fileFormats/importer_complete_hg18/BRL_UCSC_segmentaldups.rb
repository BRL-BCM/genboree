#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC Segmental Dups table to equivalent LFF version

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
                ['--segDupsFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
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
  Converts from UCSC segmental Dups table to equivalent LFF version.

  COMMAND LINE ARGUMENTS:
    --segDupsFile       | -r    => UCSC segmental Dups file to convert
    --trackName             | -t    => Track name for segmental Dups track.
                                       (type:subtype)
    --className             | -l    => Class name for segmental Dups track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  BRL_UCSC_segmentaldups.rb -r genomicSuperDups.txt.gz -t 'Segmental:Duplications' -l 'Structural Variants' -i /users/ybai/work/Human_Project6/Variation_Repeats/Segmental_Dups -f genomicSuperDups_LFF.txt -d /users/ybai/work/Human_Project6/Variation_Repeats/Segmental_Dups
"
end

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    segDupsFile = inputsHash['--segDupsFile'].strip
    className = inputsHash['--className'].strip
    cDirectoryInput = inputsHash['--cDirectoryInput'].strip
    fileToOutput = inputsHash['--fileToOutput'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip

    unless(File.size?("#{cDirectoryInput}/#{segDupsFile}"))
      $stderr.puts "WARNING: the file '#{segDupsFile}' is empty. Nothing to do."
      exit(FAILED)
    end

    # Set the track type/subtype
    lffType, lffSubtype = inputsHash['--trackName'].strip.split(':')


    # CONVERT Affy GNF1H TO LFF RECORDS USING WHAT WE HAVE SO FAR
    segDups = Hash.new { |hh, kk| hh[kk] = 0 }
    # Open the file
    reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{segDupsFile}")
    line = nil
    begin
      open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
     # Go through each line
      reader.each { |line|
        next if(line =~ /^\s*#/ or line !~ /\S/)
        # Chop it up
        ff = line.chomp.split(/\t/)
        ff[4].strip!
        segDups[ff[4]] += 1  
        ff[4] = ("#{ff[4]}.#{segDups[ff[4]]}".to_sym) if(segDups[ff[4]] >= 1)
        alignedStart = ff[8].to_i
        alignedEnd = ff[9].to_i
        similarity = ff[26].to_f
        ### class, name, type, subtype, entry pint(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
        if((alignedEnd - alignedStart) >= 1000)
          f.print "#{className}\t#{ff[4]}\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]+1}\t#{ff[3]}\t#{ff[6]}\t.\t#{ff[5]}\t.\t.\t"
          f.print "otherChrom=#{ff[7]}; otherSize=#{ff[10]}; uid=#{ff[11]}; posBasesHit=#{ff[12]}; testResult=#{ff[13]}; verdict=#{ff[14]}; chits=#{ff[15]}; ccov=#{ff[16]}; alignfile=#{ff[17]}; alignL=#{ff[18]}; indelN=#{ff[19]}; indelS=#{ff[20]}; alignB=#{ff[21]}; matchB=#{ff[22]}; mismatchB=#{ff[23]};" +
                "transtionsB=#{ff[24]}; transversionB=#{ff[25]}; fracMatch=#{ff[26]}; fracMatchIndel=#{ff[27]}; jcK=#{ff[28]}; k2K=#{ff[29]}; "
          if((similarity >= 0.9) && (similarity < 0.98))
            f.print "annotationColor=#00ff00 "
          elsif((similarity >= 0.98) && (similarity < 0.99))
            f.print "annotationColor=#ffff00 "
          elsif(similarity >= 0.99)
            f.print "annotationColor=#00ffff "
          end
          # sequence (none)
          f.print "\t.\t"
          # summary (free form comments)
          f.print "."

          # done with record
          f.puts ""
        end
      } # reader close
      reader.close
      end #open
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
