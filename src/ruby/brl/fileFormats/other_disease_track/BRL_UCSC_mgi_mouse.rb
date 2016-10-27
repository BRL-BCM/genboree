#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC multiple files (MGI Mouse Quantitative Trait Loci Coarsely Mapped to Human) to equivalent LFF version
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
                ['--makeSeparateTracks', '-s', GetoptLong::REQUIRED_ARGUMENT],
                ['--makeCombinedTracks', '-c', GetoptLong::REQUIRED_ARGUMENT],
                ['--trackName', '-t', GetoptLong::REQUIRED_ARGUMENT],
                ['--className', '-l', GetoptLong::REQUIRED_ARGUMENT],
                ['--cDirectoryInput', '-i', GetoptLong::REQUIRED_ARGUMENT],
                ['--fileToOutput', '-f', GetoptLong::REQUIRED_ARGUMENT],
                ['--cDirectoryOutput', '-d', GetoptLong::REQUIRED_ARGUMENT],

                ['--jaxQtlAsIsFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
                ['--jaxQtlPaddedFile', '-p', GetoptLong::OPTIONAL_ARGUMENT],
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
  Convert from UCSC multiple files to equivalent LFF version. The other flag must be turned off (-1) while one flag is set on (1)  

  COMMAND LINE ARGUMENTS:
    --makeSeparateTracks       | -s    => This flag is turned on (1), the converter should have [optional] arguments for each of the UCSC
                                          files it can take (--jaxQtlAsIsFile, --jaxQtlPaddedFile). For each one of 
                                          these files provided, it runs the appropriate converter and outputs the correct track.
    --makeCombinedTracks       | -c    => > This flag is turned on (1), the converter makes a RGD:MGI MOUSE QTL track that combines all the
                                            annotations in the separate tracks.
    --trackName             | -t    => Track name for Variants:UCSC track.
                                       (type:subtype)
    --className             | -l    => Class name for Variants:UCSC track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file

    --jaxQtlAsIsFile       | -o    => UCSC jaxQtlAsIs file to convert
    --jaxQtlPaddedFile       | -p    => UCSC jaxQtlPadded file to convert
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  1) --makeSeparateTracks flag is turned on: 
  i.e. BRL_UCSC_mgi_mouse.rb -s 1 -c -1 -t 'RGD:MGI MOUSE QTL' -l 'Phenotype Disease Ass' -i /users/ybai/work/Project3/MGI_MOUSE_QTL -f MGI_MOUSE_QTL_LFF.txt -d /users/ybai/work/Project3/MGI_MOUSE_QTL -o jaxQtlAsIs.txt.gz -p jaxQtlPadded.txt.gz
  2) --makeCombinedTracks flag is turned on: 
  i.e. BRL_UCSC_mgi_mouse.rb -s -1 -c 1 -t 'RGD:MGI MOUSE QTL' -l 'Phenotype Disease Ass' -i /users/ybai/work/Project3/MGI_MOUSE_QTL -f MGI_MOUSE_QTL_LFF.txt -d /users/ybai/work/Project3/MGI_MOUSE_QTL -o jaxQtlAsIs.txt.gz -p jaxQtlPadded.txt.gz
"
end

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    makeSeparateTracks_flag = inputsHash['--makeSeparateTracks'].strip
    makeCombinedTracks_flag = inputsHash['--makeCombinedTracks'].strip
    # Set the track type/subtype
    lffType, lffSubtype = inputsHash['--trackName'].strip.split(':')
    className = inputsHash['--className'].strip
    cDirectoryInput = inputsHash['--cDirectoryInput'].strip
    fileToOutput = inputsHash['--fileToOutput'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip

    ### --makeSeparateTracks flag is turned on: 
    if("#{makeSeparateTracks_flag}" == '1')
      if(inputsHash.key?('--jaxQtlAsIsFile'))
        `BRL_UCSC_mgi_mouse.rb -s 1 -c -1 -t 'RGD:MGI MOUSE QTL' -l 'Phenotype Disease Ass' -i /users/ybai/work/Project3/MGI_MOUSE_QTL -f MGI_MOUSE_QTL_LFF.txt -d /users/ybai/work/Project3/MGI_MOUSE_QTL -o jaxQtlAsIs.txt.gz`
      end
      if(inputsHash.key?('--jaxQtlPaddedFile'))
        `BRL_UCSC_mgi_mouse.rb -s 1 -c -1 -t 'RGD:MGI MOUSE QTL' -l 'Phenotype Disease Ass' -i /users/ybai/work/Project3/MGI_MOUSE_QTL -f MGI_MOUSE_QTL_LFF.txt -d /users/ybai/work/Project3/MGI_MOUSE_QTL -p jaxQtlPadded.txt.gz`
      end
    elsif("#{makeCombinedTracks_flag}" == '1')  ### --makeCombinedTracks flag is turned on: 
      open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
        if(inputsHash.key?('--jaxQtlAsIsFile'))
            jaxQtlAsIsFile = inputsHash['--jaxQtlAsIsFile'].strip
            unless(File.size?("#{cDirectoryInput}/#{jaxQtlAsIsFile}"))
              $stderr.puts "WARNING: the file '#{jaxQtlAsIsFile}' is empty. Nothing to do."
              exit(FAILED)
            end

            # CONVERT cnpLocke TO LFF RECORDS USING WHAT WE HAVE SO FAR
            jaxQtlAsIs = Hash.new { |hh, kk| hh[kk] = 0 }
            # Open the file
            reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{jaxQtlAsIsFile}")
            line = nil
            begin
            # Go through each line
            reader.each { |line|
              next if(line =~ /^\s*#/ or line !~ /\S/)
              # Chop it up
              # bin chrom chromStart chromEnd name 
              ff = line.chomp.split(/\t/)
              ff[1] = ff[1].to_sym    #chrom
              ff[2] = ff[2].to_i      #chromStart
              ff[3] = ff[3].to_i      #chromEnd
              ff[4].strip!  # name 
              jaxQtlAsIs[ff[4]] += 1
              ff[4] = ("#{ff[4]}.#{jaxQtlAsIs[ff[4]]}".to_sym) if(jaxQtlAsIs[ff[4]] > 1)

              # Dump each linked feature as LFF
              ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
              f.print "#{className}\t#{ff[4]}.jaxQtlAsIs\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t+\t.\t1.0\t.\t.\t"
              ## attributes in order of useful information (in LFF anyway)
              f.print "annotationColor=#FF0000"
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
          end
        end #if1
        if(inputsHash.key?('--jaxQtlPaddedFile'))
          jaxQtlPaddedFile = inputsHash['--jaxQtlPaddedFile'].strip
          unless(File.size?("#{cDirectoryInput}/#{jaxQtlPaddedFile}"))
            $stderr.puts "WARNING: the file '#{jaxQtlPaddedFile}' is empty. Nothing to do."
            exit(FAILED)
          end

          # CONVERT jaxQtlPadded TO LFF RECORDS USING WHAT WE HAVE SO FAR
          jaxQtlPadded = Hash.new { |hh, kk| hh[kk] = 0 }
          # Open the file
          reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{jaxQtlPaddedFile}")
          line = nil
          begin
            # Go through each line
            reader.each { |line|
              next if(line =~ /^\s*#/ or line !~ /\S/)
              # Chop it up
              # bin chrom chromStart chromEnd name 
              ff = line.chomp.split(/\t/)
              ff[1] = ff[1].to_sym    #chrom
              ff[2] = ff[2].to_i      #chromStart
              ff[3] = ff[3].to_i      #chromEnd
              ff[4].strip!  # name 
              jaxQtlPadded[ff[4]] += 1
              ff[4] = ("#{ff[4]}.#{jaxQtlPadded[ff[4]]}".to_sym) if(jaxQtlPadded[ff[4]] > 1)

              # Dump each linked feature as LFF
              ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
              f.print "#{className}\t#{ff[4]}.jaxQtlPadded\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t+\t.\t1.0\t.\t.\t"
              # attri_comments
              f.print "annotationColor=#0000FF"
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
          end
        end #if2
      end #open
    end #elsif
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
