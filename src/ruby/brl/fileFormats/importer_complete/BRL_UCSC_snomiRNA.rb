#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC wgRna table to equivalent LFF version

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
                ['--wgRnaFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
                ['--trackType', '-t', GetoptLong::REQUIRED_ARGUMENT],
                ['--trackSubtype', '-s', GetoptLong::REQUIRED_ARGUMENT],
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
  Converts from UCSC wgRna table to equivalent LFF version.

  COMMAND LINE ARGUMENTS:
    --wgRnaFile       | -r    => UCSC wgRna file to convert
    --trackType             | -t    => Track type for sno/miRNA track.
    --trackSubtype             | -s    => Track subtype for sno/miRNA track.
    --className             | -l    => Class name for sno/miRNA track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name prefix
    --cDirectoryOutput      | -d    => directory location of converted file
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  BRL_UCSC_snomiRNA.rb -r wgRna.txt.gz -t RNA -s Small -l 'Gene and Gene Prediction' -i /users/ybai/work/Human_sno-miRNA -f snomiRNA -d /users/ybai/work/Human_sno-miRNA
"
end

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    wgRnaFile = inputsHash['--wgRnaFile'].strip
    lffType = inputsHash['--trackType'].strip
    lffSubtype = inputsHash['--trackSubtype'].strip
    className = inputsHash['--className'].strip
    cDirectoryInput = inputsHash['--cDirectoryInput'].strip
    fileToOutput = inputsHash['--fileToOutput'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip

    unless(File.size?("#{cDirectoryInput}/#{wgRnaFile}"))
      $stderr.puts "WARNING: the file '#{wgRnaFile}' is empty. Nothing to do."
      exit(FAILED)
    end

    # Assign several colors for miRna, CDBox, HAcaBox, scaRna
    rna_hex = { 
      'miRna' => 'ff0000', 
      'CDBox' => '0000ff', 
      'HAcaBox' => '008000', 
      'scaRna' => 'ff00ff' 
    }

    # CONVERT wgRna TO LFF RECORDS USING WHAT WE HAVE SO FAR
    wgRna = Hash.new { |hh, kk| hh[kk] = 0 }
    # Open the file
    reader1 = BRL::Util::TextReader.new("#{cDirectoryInput}/#{wgRnaFile}")
    line1 = nil

    # Array to store 'type' column information
    type_arr = []
    begin
      reader1.each { |line1|
        next if(line1 =~ /^\s*#/ or line1 !~ /\S/)
        ff1 = line1.chomp.split(/\t/)
        ### LFF subtype argument is ignored if the wgRna.tar.gz file has 10 columns
        if(ff1.length == 10)
          type_arr << "Small" << "#{ff1[9]}"
        elsif("#{ff1[9]}" == '')
          type_arr << "#{lffSubtype}"
        end
      } # reader1 close
      reader1.close
      type_arr.uniq!
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader1.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line1.inspect}"
      exit(OK_WITH_ERRORS)
    end

    begin
      type_arr.map! {|xx|
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{wgRnaFile}")
        line = nil
        open("#{cDirectoryOutput}/#{fileToOutput}.#{xx}_LFF.txt", 'w') do |f|
        # Go through each line
        reader.each { |line|
          next if(line =~ /^\s*#/ or line !~ /\S/)
          # Chop it up
          # bin chrom chromStart chromEnd name score strand thickStart thickEnd type 
          ff = line.chomp.split(/\t/)
          ff[1] = ff[1].to_sym	#chrom
          ff[2] = ff[2].to_i	#chromStart
          ff[3] = ff[3].to_i	#chromEnd
          ff[4] = ff[4].to_sym    #name
          ff[5] = ff[5].to_i      #score
          ff[6] = ff[6].to_sym    #strand
          ff[7] = ff[7].to_i      #thickStart
          ff[8] = ff[8].to_i      #thickEnd
          ff[9] = ff[9].to_sym    #type

          wgRna[ff[4]] += 1
          ff[4] = ("#{ff[4]}.#{wgRna[ff[4]]}".to_sym) if(wgRna[ff[4]] >= 1)

          if("#{ff[9]}".eql?("miRna"))
            assigned_color = rna_hex['miRna']
          elsif("#{ff[9]}".eql?("CDBox"))
            assigned_color = rna_hex['CDBox']
          elsif("#{ff[9]}".eql?("HAcaBox"))
            assigned_color = rna_hex['HAcaBox']
          elsif("#{ff[9]}".eql?("scaRna"))
            assigned_color = rna_hex['scaRna']
          end

          # Dump each linked feature as LFF
          ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
          f.print "#{className}\t#{ff[4]}\t#{lffType}\t#{xx}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t#{ff[6]}\t.\t#{ff[5]}\t.\t.\t"
          ## attributes in order of useful information (in LFF anyway)
          # attri_comments
          f.print "smallRNAtype=#{ff[9]}; thickStart=#{ff[7]}; thickEnd=#{ff[8]}; annotationColor=##{assigned_color}"
          # sequence (none)
          f.print "\t.\t"
          # summary (free form comments)
          f.print "."

          # done with record
          f.puts ""
        } # reader close
        reader.close
        end
      }
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
