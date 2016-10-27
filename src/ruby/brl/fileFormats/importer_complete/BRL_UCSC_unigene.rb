#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC UniGene table to equivalent LFF version

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
                ['--allUniGeneFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
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
  Converts from UCSC UniGene table to equivalent LFF version.

  COMMAND LINE ARGUMENTS:
    --allUniGeneFile       | -r    => UCSC UniGene file to convert
    --trackName             | -t    => Track name for UniGene track.
                                       (type:subtype)
    --className             | -l    => Class name for UniGene track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  BRL_UCSC_unigene.rb -r uniGene_3.txt.gz -t UCSC:UniGene -l 'mRNA and EST' -i /users/ybai/work/Human_Project6/mRNA_EST/Uni_Gene -f uniGene_3_LFF.txt -d /users/ybai/work/Human_Project6/mRNA_EST/Uni_Gene
"
end

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    allUniGeneFile = inputsHash['--allUniGeneFile'].strip
    className = inputsHash['--className'].strip
    cDirectoryInput = inputsHash['--cDirectoryInput'].strip
    fileToOutput = inputsHash['--fileToOutput'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip

    unless(File.size?("#{cDirectoryInput}/#{allUniGeneFile}"))
      $stderr.puts "WARNING: the file '#{allUniGeneFile}' is empty. Nothing to do."
      exit(FAILED)
    end

    # Set the track type/subtype
    lffType, lffSubtype = inputsHash['--trackName'].strip.split(':')


    # CONVERT knownGene TO LFF RECORDS USING WHAT WE HAVE SO FAR
    allUniGene = Hash.new { |hh, kk| hh[kk] = 0 }
    # Open the file
    reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{allUniGeneFile}")
    line = nil
    begin
      open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
     # Go through each line
      reader.each { |line|
        next if(line =~ /^\s*#/ or line !~ /\S/)
        # Chop it up
        # bin matches misMatches repMatches nCount qNumInsert qBaseInsert tNumInsert tBaseInsert strand qName qSize qStart qEnd tName tSize tStart tEnd blockCount blockSizes qStarts tStarts  
        ff = line.chomp.split(/\t/)
        ff[9] = ff[9].to_sym
        ff[10].strip!
        allUniGene[ff[10]] += 1  
        ff[10] = ("#{ff[10]}.#{allUniGene[ff[10]]}".to_sym) if(allUniGene[ff[10]] >= 1)

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
          f.print "#{className}\t#{ff[10]}.Block_#{blockNum}\t#{lffType}\t#{lffSubtype}\t#{ff[14]}\t#{tStarts[ii]+1}\t#{tStarts[ii]+blockSizes[ii]}\t#{ff[9]}\t.\t1.0\t.\t.\t"

          f.print "matches=#{ff[1]}; misMatches=#{ff[2]}; repMatches=#{ff[3]}; nCount=#{ff[4]}; qNumInsert=#{ff[5]}; qBaseInsert=#{ff[6]}; tNumInsert=#{ff[7]}; tBaseInsert=#{ff[8]}; " +
                "qSize=#{ff[11]}; tName=#{ff[14]}; tSize=#{ff[15]}; qStart=#{qStarts[ii]};" +
                "blockCount=#{blockCount} "

          # sequence (none)
          f.print "\t.\t"
          # summary (free form comments)
          f.print "."

          # done with record
          f.puts ""
        }
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
