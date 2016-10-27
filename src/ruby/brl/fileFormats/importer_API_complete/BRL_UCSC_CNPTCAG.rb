#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from Database of Genomic Variants variation tables to equivalent LFF version

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
                ['--variantsTCAGFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
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
  Converts from UCSC Database of Genomic Variants variation table to equivalent LFF version.

  COMMAND LINE ARGUMENTS:
    --variantsTCAGFile       | -r    => UCSC variation file to convert
    --trackName             | -t    => Track name for Variants:TCAG.v3 track.
                                       (type:subtype)
    --className             | -l    => Class name for cnpSharp2 track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  BRL_UCSC_CNPTCAG.rb -r variation.hg18.v3.txt.gz -t Variants:TCAG.v3 -l 'Structural Variants' -i /users/ybai/work/Variants_TCAG -f variation.hg18.v3_LFF.txt -d /users/ybai/work/Variants_TCAG
  BRL_UCSC_CNPTCAG.rb -r variation.hg17.v3.txt.gz -t Variants:TCAG.v3 -l 'Structural Variants' -i /users/ybai/work/Variants_TCAG -f variation.hg17.v3_LFF.txt -d /users/ybai/work/Variants_TCAG
"
end

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    variantsTCAGFile = inputsHash['--variantsTCAGFile'].strip
    className = inputsHash['--className'].strip
    cDirectoryInput = inputsHash['--cDirectoryInput'].strip
    fileToOutput = inputsHash['--fileToOutput'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip

    unless(File.size?("#{cDirectoryInput}/#{variantsTCAGFile}"))
      $stderr.puts "WARNING: the file '#{variantsTCAGFile}' is empty. Nothing to do."
      exit(FAILED)
    end

    # Set the track type/subtype
    lffType, lffSubtype = inputsHash['--trackName'].strip.split(':')

    # CONVERT variantsTCAG TO LFF RECORDS USING WHAT WE HAVE SO FAR
    # Open the file
    reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{variantsTCAGFile}")
    line = nil
    begin
      open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
     # Go through each line
      reader.each { |line|
        next if(line =~ /^\s*#/ or line !~ /\S/)
        # Chop it up
        # VariationID	Landmark	Chr	Start	End	VariationType	LocusID	LocusChr	LocusStart	LocusEnd	Reference	PubMedID	Method/platform	Gain	Loss	TotalGainLossInv	SampleSize
        ff = line.chomp.split(/\t/)
        ff[0] = ff[0].to_sym	#VariationID
        ff[1] = ff[1].to_sym	#Landmark
        ff[2] = ff[2].to_sym	#chr
        ff[3] = ff[3].to_i	#chromStart
        ff[4] = ff[4].to_i	#chromEnd
        ff[5] = ff[5].to_sym	#variationType
        if("#{ff[6]}" != '') 
          ff[6] = ff[6].to_sym	#LocusID
        end
        if("#{ff[7]}" != '') 
          ff[7] = ff[7].to_sym	#LocusChr
        end
        if("#{ff[8]}" != '') 
          ff[8] = ff[8].to_i	#LocusStart
        end
        if("#{ff[9]}" != '') 
          ff[9] = ff[9].to_i	#LocusEnd
        end
        if("#{ff[10]}" != '') 
          ff[10] = ff[10].to_sym	#Reference
        end
        if("#{ff[11]}" != '') 
          ff[11] = ff[11].to_i	#PubMedID
        end
        if("#{ff[12]}" != '') 
          ff[12] = ff[12].to_sym	#Method/Platform
        end
        if("#{ff[13]}" != '') 
          ff[13] = ff[13].to_i	#Gain
        end
        if("#{ff[14]}" != '') 
          ff[14] = ff[14].to_i	#Loss
        end
        if("#{ff[15]}" != '') 
          ff[15] = ff[15].to_i	#TotalGainLossInv
        end
        if("#{ff[16]}" != '') 
          ff[16] = ff[16].to_sym	#SampleSize
        end

        # Dump each linked feature as LFF
        ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
        f.print "#{className}\t#{ff[0]}\t#{lffType}\t#{lffSubtype}\t#{ff[2]}\t#{ff[3]}\t#{ff[4]}\t+\t.\t1.0\t.\t.\t"
        ## attributes in order of useful information (in LFF anyway)
        f.print "VariationID=#{ff[0]}; Landmark=#{ff[1]}; variationType=#{ff[5]}; LocusID=#{ff[6]}; LocusChr=#{ff[7]}; LocusStart=#{ff[8]}; LocusEnd=#{ff[9]}; Reference=#{ff[10]}; PubMedID=#{ff[11]}; Method/Platform=#{ff[12]}; Gain=#{ff[13]}; Loss=#{ff[14]}; TotalGainLossInv=#{ff[15]}; SampleSize=#{ff[16]}"
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
