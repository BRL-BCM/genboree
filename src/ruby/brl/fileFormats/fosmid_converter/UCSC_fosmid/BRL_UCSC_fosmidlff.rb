#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC fosEndPairs table to equivalent LFF version

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
                ['--fosEndPairsFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
                ['--trackName', '-t', GetoptLong::REQUIRED_ARGUMENT],
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
    --fosEndPairsFile       | -r    => UCSC fosEndPairs file to convert
    --trackName             | -t    => Track name for fosEndPairs track.
                                       (type:subtype)
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  BRL_UCSC_fosmidlff.rb -r fosEndPairs.txt.gz -t Fosmid:EndPairs >fosEndPairs_LFF.txt
"
end

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    fosEndPairsFile = inputsHash['--fosEndPairsFile'].strip
    unless(File.size?(fosEndPairsFile))
      $stderr.puts "WARNING: the file '#{fosEndPairsFile}' is empty. Nothing to do."
      exit(FAILED)
    end
    # Set the track type/subtype
    lffType, lffSubtype = inputsHash['--trackName'].strip.split(':')

    # CONVERT fosEndPairs TO LFF RECORDS USING WHAT WE HAVE SO FAR
    fosmids = Hash.new { |hh, kk| hh[kk] = 0 }
    # Open the file
    reader = BRL::Util::TextReader.new(fosEndPairsFile)
    line = nil
    begin
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
        fosmids[ff[4]] += 1
        ff[4] = ("#{ff[4]}.#{fosmids[ff[4]]}".to_sym) if(fosmids[ff[4]] > 1)
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
          ##start to assign the strand for this read: FWD READ <<+if+, -if->>; REV READ <<-if+,+if->>
          if("#{lfNames[ii].to_sym}".count("F") == 1) ## there is one unique  F char in the readName
            if("#{lfNames[ii].to_sym}".delete("#{ff[4]}") == 'F') # it is F stand
              if("#{ff[6]}" == '+')
                strand[ii] = '+'
              else
                strand[ii] = '-'
              end
            elsif("#{lfNames[ii].to_sym}".delete("#{ff[4]}") == 'R') # it is R stand
              if("#{ff[6]}" == '+')
                strand[ii] = '-'
              else
                strand[ii] = '+'
              end
            else
              $stderr.puts "\n\nERROR: Weird char found: ("#{lfNames[ii].to_sym}".delete("#{ff[4]}")).\n\n#{line}"
              strand[ii] = 'unknown'
            end
          elsif("#{lfNames[ii].to_sym}".count("F") > 1) ## there is more than one  F char in the readName
            if("#{lfNames[ii].to_sym}".delete("#{ff[4]}") == '') #and it is a F strand
              if("#{ff[6]}" == '+')
                strand[ii] = '+'
              else
                strand[ii] = '-'
              end
            elsif("#{lfNames[ii].to_sym}".delete("#{ff[4]}") == 'R') # it is R stand
              if("#{ff[6]}" == '+')
                strand[ii] = '-'
              else
                strand[ii] = '+'
              end
            else
              $stderr.puts "\n\nERROR: Weird char found: ("#{lfNames[ii].to_sym}".delete("#{ff[4]}")).\n\n#{line}"
              strand[ii] = 'unknown'
            end
          else ## enter no F case
            if("#{lfNames[ii].to_sym}".count("R") == 1)
              if("#{ff[6]}" == '+')
                strand[ii] = '-'
              else
                strand[ii] = '+'
              end
            else # either count("R") > 1 or No R case
              if("#{lfNames[ii].to_sym}".delete("#{ff[4]}") == '') #and it is a R strnd
                if("#{ff[6]}" == '+')
                  strand[ii] = '-'
                else
                  strand[ii] = '+'
                end
              else
                $stderr.puts "\n\nERROR: Weird char found: ("#{lfNames[ii].to_sym}".delete("#{ff[4]}")).\n\n#{line}"
                strand[ii] = 'unknown'
              end
            end
          end
          ##---------------> if there are multiple attempts (>1) to sequence both ends of the fosmid (The following code handles 2 x M X N assignment)
          read_name[lfNames[ii]] += 1 
          lfNames[ii] = ("#{lfNames[ii]}.#{read_name[lfNames[ii]]}".to_sym) if(read_name[lfNames[ii]] > 2)	
          if lfCount >  2 then
            $stderr.puts "\n\nWARNING: Multiple sequenced ends of the fosmid found: (#{lfCount}).\n\n#{line}" 
          end
          while(read_index <= lfCount - 1)
            if(read_index != ii and strand[read_index] != strand[ii]) ## if not current read and not the same sequenced end
              ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop
              print "End Pairs\t#{ff[4]}\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{lfStarts[ii].to_i}\t#{lfStarts[ii].to_i+lfSizes[ii].to_i}\t#{strand[ii]}\t.\t#{ff[5]}\t.\t.\t"
              # attributes in order of useful information (in LFF anyway)
              ### bin, pslTable, lfCount, readName, mateName, mateStart, mateStop, mateChr
              print "bin=#{bin}; pslTable=#{pslTable}; lfCount=#{lfCount}; "
              print "readName=#{lfNames[ii].to_sym}; mateName=#{lfNames[read_index].to_sym}; " +
                "mateStart=#{lfStarts[read_index].to_i}; mateStop=#{lfStarts[read_index].to_i + lfSizes[read_index].to_i}; mateChr=#{ff[1]} "
            end
            read_index += 1	
          end	 
          ####------------> Done with this multiple FWD and multiple REV assignment   
          # sequence (none)
          print "\t.\t"

          # summary (free form comments)
          print "."

          # done with record
          puts ""
          read_index = 0
        } #lfCount
      } # reader close
      reader.close
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
