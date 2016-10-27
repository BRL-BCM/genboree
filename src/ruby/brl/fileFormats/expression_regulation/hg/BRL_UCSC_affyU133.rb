#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC Affy U133 table to equivalent LFF version

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
                ['--affyU133File', '-r', GetoptLong::REQUIRED_ARGUMENT],
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
  Converts from UCSC Affy U133 table to equivalent LFF version.

  COMMAND LINE ARGUMENTS:
    --affyU133File       | -r    => UCSC affyU133 file to convert
    --trackName             | -t    => Track name for affyU133 track.
                                       (type:subtype)
    --className             | -l    => Class name for affyU133 track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  BRL_UCSC_affyU133.rb -r affyU133.txt.gz -t 'Affy:U133' -l 'Expression and Regulation' -i /users/ybai/work/Human_Project6/Expression_Regulation/Affy_U133 -f affyU133_LFF.txt -d /users/ybai/work/Human_Project6/Expression_Regulation/Affy_U133
"
end

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    affyU133File = inputsHash['--affyU133File'].strip
    className = inputsHash['--className'].strip
    cDirectoryInput = inputsHash['--cDirectoryInput'].strip
    fileToOutput = inputsHash['--fileToOutput'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip

    unless(File.size?("#{cDirectoryInput}/#{affyU133File}"))
      $stderr.puts "WARNING: the file '#{affyU133File}' is empty. Nothing to do."
      exit(FAILED)
    end

    # Set the track type/subtype
    lffType, lffSubtype = inputsHash['--trackName'].strip.split(':')

    # CONVERT GNF Atlas 2 TO LFF RECORDS USING WHAT WE HAVE SO FAR
    affyU133 = Hash.new { |hh, kk| hh[kk] = 0 }
    # Open the file
    reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{affyU133File}")
    line = nil
    begin
      open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
     # Go through each line
      reader.each { |line|
        next if(line =~ /^\s*#/ or line !~ /\S/)
        # Chop it up
        ff = line.chomp.split(/\t/)
        ff[1] = ff[1].to_i      #matches
        ff[2] = ff[2].to_i      #misMatches
        ff[3] = ff[3].to_i      #repMatches
        ff[4] = ff[4].to_i      #nCount
        ff[5] = ff[5].to_i      #qNumInsert
        ff[6] = ff[6].to_i      #qBaseInsert
        ff[7] = ff[7].to_i      #tNumInsert
        ff[8] = ff[8].to_i      #tBaseInsert
        ff[9] = ff[9].to_sym    #strand
        ff[10].strip!
        affyU133[ff[10]] += 1  
        ff[10] = ("#{ff[10]}.#{affyU133[ff[10]]}".to_sym) if(affyU133[ff[10]] >= 1)
        ff[11] = ff[11].to_i    #qSize
        ff[12] = ff[11].to_i    #qSize
        ff[13] = ff[11].to_i    #qSize
        ff[14] = ff[14].to_sym  #tName
        ff[15] = ff[15].to_i    #tSize
        ff[16] = ff[11].to_i    #qSize
        ff[17] = ff[11].to_i    #qSize
        blockCount = ff[18].to_i
        blockSizes = ff[19].chomp(',').split(/,/).map{|xx| xx.to_i}

        qStarts = ff[20].chomp(',').split(/,/).map{|xx| xx.to_i}
        tStarts = ff[21].chomp(',').split(/,/).map{|xx| xx.to_i}

        unless(blockSizes.size == blockCount and qStarts.size == blockCount and tStarts.size == blockCount)
          $stderr.puts "\n\nERROR: this line doesn't have the right number of blocks (#{blockCount}).\n\n#{line}"
        end

        blockCount.times { |ii|  ### start from index 0
          ### print each block's information
          ### class, name, type, subtype, entry pint(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
          if(ff[9] == :'+') # + strand
            blockNum = ii+1
          else # - strand
            blockNum = blockCount-ii 
          end
          f.print "#{className}\t#{ff[10]}.Block_#{blockNum}\t#{lffType}\t#{lffSubtype}\t#{ff[14]}\t#{tStarts[ii].to_i+1}\t#{tStarts[ii].to_i+blockSizes[ii].to_i}\t#{ff[9]}\t.\t1.0\t.\t.\t"

          f.print "matches=#{ff[1]}; misMatches=#{ff[2]}; repMatches=#{ff[3]}; nCount=#{ff[4]}; qNumInsert=#{ff[5]}; qBaseInsert=#{ff[6]}; tNumInsert=#{ff[7]}; tBaseInsert=#{ff[8]}; " +
                "qSize=#{ff[11]}; tName=#{ff[14]}; tSize=#{ff[15]}; qStart=#{qStarts[ii].to_i};" +
                "blockCount=#{blockCount} "

          # sequence (none)
          f.print "\t.\t"

          # summary (free form comments)
          f.print "."

          # done with record
          f.puts ""
        } #blockCount
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
