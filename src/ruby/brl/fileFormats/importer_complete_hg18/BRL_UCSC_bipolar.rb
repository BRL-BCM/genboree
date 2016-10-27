#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC multiple files (NIMH Bipolar Disease) to equivalent LFF version
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

                ['--nimhBipolarDeFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
                ['--nimhBipolarUsFile', '-p', GetoptLong::OPTIONAL_ARGUMENT],
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
    --trackName             | -t    => Track name for NIMH Bipolar track.
                                       (type:subtype)
    --className             | -l    => Class name for NIMH Bipolar track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file

    --nimhBipolarDeFile       | -o    => UCSC Bipolar German file to convert
    --nimhBipolarUsFile       | -p    => UCSC Bipolar US file to convert
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  i.e. BRL_UCSC_bipolar.rb -t NIMH:BIPOL -l 'Phenotype Disease Ass' -i /users/ybai/work/Project3/NIMH_BIPOLAR -f NIMH_BIPOLAR_LFF.txt -d /users/ybai/work/Project3/NIMH_BIPOLAR -o nimhBipolarDe.txt.gz -p nimhBipolarUs.txt.gz
"
end

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    # Set the track type/subtype
    lffType, lffSubtype = inputsHash['--trackName'].strip.split(':')
    className = inputsHash['--className'].strip
    cDirectoryInput = inputsHash['--cDirectoryInput'].strip
    fileToOutput = inputsHash['--fileToOutput'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip

    open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
      if(inputsHash.key?('--nimhBipolarDeFile'))
        nimhBipolarDeFile = inputsHash['--nimhBipolarDeFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{nimhBipolarDeFile}"))
          $stderr.puts "WARNING: the file '#{nimhBipolarDeFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        nimhBipolarDe = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{nimhBipolarDeFile}")
        line = nil
        begin
          # Go through each line
          reader.each { |line|
            next if(line =~ /^\s*#/ or line !~ /\S/)
            #chrom_info = []
            # Chop it up
            # chrom chromStart val 
            ff = line.chomp.split(/\t/)
            ff[0] = ff[0].to_sym    #chrom
            ff[1] = ff[1].to_i      #chromStart
            ff[2] = ff[2].to_f      #val
            nimhBipolarDe[ff[0]] += 1
            chromIndex = ("#{ff[0]}.#{nimhBipolarDe[ff[0]]}".to_sym) if(nimhBipolarDe[ff[0]] >= 1)
            chromStart = ff[1] - 10
            chromEnd = ff[1] + 10
            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{chromIndex}.De\t#{lffType}\t#{lffSubtype}\t#{ff[0]}\t#{chromStart+1}\t#{chromEnd+1}\t+\t.\t1.0\t.\t.\t"
            # attributes in order of useful information (in LFF anyway)
            ### val
            f.print "val=#{ff[2]}; annotationColor=#00ff00"
            # sequence (none)
            f.print "\t.\t"
            # summary (free form comments)
            f.print "."

            # done with record
            f.puts ""
          } # reader close
          reader.close
        rescue => err
          $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
          $stderr.puts err.backtrace.join("\n")
          $stderr.puts "LINE: #{line.inspect}"
          exit(OK_WITH_ERRORS)
        end #begin
      end #if1
      if(inputsHash.key?('--nimhBipolarUsFile'))
        nimhBipolarUsFile = inputsHash['--nimhBipolarUsFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{nimhBipolarUsFile}"))
          $stderr.puts "WARNING: the file '#{nimhBipolarUsFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        nimhBipolarUs = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{nimhBipolarUsFile}")
        line = nil
        begin
          # Go through each line
          reader.each { |line|
            next if(line =~ /^\s*#/ or line !~ /\S/)
            #chrom_info = []
            # Chop it up
            # chrom chromStart val 
            ff = line.chomp.split(/\t/)
            ff[0] = ff[0].to_sym    #chrom
            ff[1] = ff[1].to_i      #chromStart
            ff[2] = ff[2].to_f      #val
            nimhBipolarUs[ff[0]] += 1
            chromIndex = ("#{ff[0]}.#{nimhBipolarUs[ff[0]]}".to_sym) if(nimhBipolarUs[ff[0]] >= 1)
            chromStart = ff[1] - 10
            chromEnd = ff[1] + 10
            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{chromIndex}.Us\t#{lffType}\t#{lffSubtype}\t#{ff[0]}\t#{chromStart+1}\t#{chromEnd+1}\t+\t.\t1.0\t.\t.\t"
            # attributes in order of useful information (in LFF anyway)
            ### val
            f.print "val=#{ff[2]}; annotationColor=#ff0000"
            # sequence (none)
            f.print "\t.\t"
            # summary (free form comments)
            f.print "."

            # done with record
            f.puts ""
          } # reader close
          reader.close
        rescue => err
          $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
          $stderr.puts err.backtrace.join("\n")
          $stderr.puts "LINE: #{line.inspect}"
          exit(OK_WITH_ERRORS)
        end #begin
      end #if2
    end #open
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
