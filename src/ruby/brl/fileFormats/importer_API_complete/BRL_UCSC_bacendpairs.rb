#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC BAC_EndPairs table to equivalent LFF version

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
                ['--bacEndPairsFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
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
  Converts from UCSC fosEndPairs table to equivalent LFF version.

  COMMAND LINE ARGUMENTS:
    --bacEndPairsFile       | -r    => UCSC bacEndPairs file to convert
    --trackName             | -t    => Track name for bacEndPairs track.
                                       (type:subtype)
    --className             | -l    => Class name for bacEndPairs track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  BRL_UCSC_bacendpairs.rb -r bacEndPairs.txt.gz -t BAC:EndPairs -l 'End Pairs' -i /users/ybai/work/Human_Project5/BAC_EndPairs -f bacEndPairs_LFF.txt -d /users/ybai/work/Human_Project5/BAC_EndPairs
"
end

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    bacEndPairsFile = inputsHash['--bacEndPairsFile'].strip
    className = inputsHash['--className'].strip
    cDirectoryInput = inputsHash['--cDirectoryInput'].strip
    fileToOutput = inputsHash['--fileToOutput'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip

    unless(File.size?("#{cDirectoryInput}/#{bacEndPairsFile}"))
      $stderr.puts "WARNING: the file '#{bacEndPairsFile}' is empty. Nothing to do."
      exit(FAILED)
    end

    # Set the track type/subtype
    lffType, lffSubtype = inputsHash['--trackName'].strip.split(':')

    # CONVERT bacEndPairs TO LFF RECORDS USING WHAT WE HAVE SO FAR
    bac = Hash.new { |hh, kk| hh[kk] = 0 }
    # Open the file
    reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{bacEndPairsFile}")
    line = nil
    begin
      open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
     # Go through each line
      reader.each { |line|
        next if(line =~ /^\s*#/ or line !~ /\S/)
        # Chop it up
        # bin chrom chromStart chromEnd name score strand pslTable lfCount lfStarts lfSizes lfNames 
        ff = line.chomp.split(/\t/)
        bin = ff[0].strip.gsub(/;/, '.').to_sym #bin
        ff[1] = ff[1].to_sym	#chrom
        #ff[2] = ff[2].to_i	#chromStart
        #ff[3] = ff[3].to_i	#chromEnd
        ff[4].strip!  # name 
        bac[ff[4]] += 1
        ff[4] = ("#{ff[4]}.#{bac[ff[4]]}".to_sym) if(bac[ff[4]] > 1)
        ff[5] = ff[5].to_i	#score
        ff[6] = ff[6].to_sym	#strand
        pslTable = ff[7].strip.gsub(/;/, '.').to_sym	#pslTable
        lfCount = ff[8].to_i
        lfStarts = ff[9].chomp(',').split(/,/).map{|xx| xx.to_i}
        lfSizes = ff[10].chomp(',').split(/,/).map{|xx| xx.to_i}
        lfNames = ff[11].chomp(',').split(/,/).map{|xx| xx.to_sym}

        unless(lfStarts.size == lfCount and lfSizes.size == lfCount and lfNames.size == lfCount)
    	  $stderr.puts "\n\nERROR: this line doesn't have the right number of linked features (#{lfCount}).\n\n#{line}"
  	end
        # Dump each linked feature as LFF
        ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
        read_name = Hash.new { |hh, kk| hh[kk] = 0 }
        strand = [] ## to hold strand information for each read
        read_index = 0 ## index counter for current read in each fosmid name
        lfCount.times { |ii|  
          ##start to assign the strand for this read: The orientation of the first BAC end sequence must be "+" and the orientation of the second BAC end sequence must be "-".
          if(ii == 0) ## this is the first BAC in the readName
              strand[ii] = '+'
          elsif(ii == 1) ## this is the second BAC in the readName
              strand[ii] = '-'
          else
              strand[ii] = 'unknown'
          end
          ##---------------> if there are multiple attempts (>1) to sequence both ends of the BAC (The following code handles 2 x M X N assignment)
          read_name[lfNames[ii]] += 1 
          lfNames[ii] = ("#{lfNames[ii]}.#{read_name[lfNames[ii]]}".to_sym) if(read_name[lfNames[ii]] > 2)	
          if lfCount >  2 then
            $stderr.puts "\n\nWARNING: Multiple sequenced ends of the BAC found: (#{lfCount}).\n\n#{line}" 
          end
          while(read_index <= lfCount - 1)
            if(read_index != ii and strand[read_index] != strand[ii]) ## if not current read and not the same sequenced end
              ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop
              f.print "#{className}\t#{ff[4]}\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{lfStarts[ii].to_i}\t#{lfStarts[ii].to_i+lfSizes[ii].to_i}\t#{strand[ii]}\t.\t#{ff[5]}\t.\t.\t"
              # attributes in order of useful information (in LFF anyway)
              ### bin, pslTable, lfCount, readName, mateName, mateStart, mateStop, mateChr
              f.print "pslTable=#{pslTable}; lfCount=#{lfCount}; "
              f.print "readName=#{lfNames[ii].to_sym}; mateName=#{lfNames[read_index].to_sym}; " +
                "mateStart=#{lfStarts[read_index].to_i}; mateStop=#{lfStarts[read_index].to_i + lfSizes[read_index].to_i}; mateChr=#{ff[1]} "
            end
            read_index += 1	
          end	 
          ####------------> Done with this multiple FWD and multiple REV assignment   
          # sequence (none)
          f.print "\t.\t"

          # summary (free form comments)
          f.print "."

          # done with record
          f.puts ""
          read_index = 0
        } #lfCount
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
