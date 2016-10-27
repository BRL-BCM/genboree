#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC multiple files (cnp* and del*) to equivalent LFF version
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

                ['--cnpIafrate2File', '-o', GetoptLong::OPTIONAL_ARGUMENT],
                ['--cnpLockeFile', '-p', GetoptLong::OPTIONAL_ARGUMENT],
                ['--cnpRedonFile', '-q', GetoptLong::OPTIONAL_ARGUMENT],
                ['--cnpSebat2File', '-u', GetoptLong::OPTIONAL_ARGUMENT],
                ['--cnpSharp2File', '-v', GetoptLong::OPTIONAL_ARGUMENT],
                ['--cnpTuzunFile', '-w', GetoptLong::OPTIONAL_ARGUMENT],
                ['--delConrad2File', '-x', GetoptLong::OPTIONAL_ARGUMENT],
                ['--delHinds2File', '-y', GetoptLong::OPTIONAL_ARGUMENT],
                ['--delMccarrollFile', '-z', GetoptLong::OPTIONAL_ARGUMENT],
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
  Convert from UCSC multiple files (cnp* and del*) to equivalent LFF version. The other flag must be turned off (-1) while one flag is set on (1)  

  COMMAND LINE ARGUMENTS:
    --makeSeparateTracks       | -s    => This flag is turned on (1), the converter should have [optional] arguments for each of the UCSC
                                          files it can take (--cnpRedonFile, --cnpSebat2File, --delConrad2File, etc). For each one of 
                                          these files provided, it runs the appropriate converter and outputs the correct track.
    --makeCombinedTracks       | -c    => > This flag is turned on (1), the converter makes a Variants:UCSC track that combines all the
                                            annotations in the separate tracks.
    --trackName             | -t    => Track name for Variants:UCSC track.
                                       (type:subtype)
    --className             | -l    => Class name for Variants:UCSC track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file

    --cnpIafrate2File       | -o    => UCSC cnpIafrate2 file to convert
    --cnpLockeFile       | -p    => UCSC cnpLocke file to convert
    --cnpRedonFile       | -q    => UCSC cnpRedon file to convert
    --cnpSebat2File       | -u    => UCSC cnpSebat2 file to convert
    --cnpSharp2File       | -v    => UCSC cnpSharp2 file to convert
    --cnpTuzunFile       | -w    => UCSC cnpTuzun file to convert
    --delConrad2File       | -x    => UCSC delConrad2 file to convert
    --delHinds2File       | -y    => UCSC delHinds2 file to convert
    --delMccarrollFile       | -z    => UCSC delMccarroll file to convert
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  1) --makeSeparateTracks flag is turned on: 
  i.e. BRL_UCSC_structuralVariants.rb -s 1 -c -1 -t Variants:UCSC -l 'Structural Variants' -i /users/ybai/work/Structural_Variants_Combine -f Variants_UCSC_LFF.txt -d /users/ybai/work/Structural_Variants_Combine -o cnpIafrate2.txt.gz -p cnpLocke.txt.gz -q cnpRedon.txt.gz -u cnpSebat2.txt.gz -v cnpSharp2.txt.gz -w cnpTuzun.txt.gz -x delConrad2.txt.gz -y delHinds2.txt.gz -z delMccarroll.txt.gz
  2) --makeCombinedTracks flag is turned on: 
  i.e. BRL_UCSC_structuralVariants.rb -s -1 -c 1 -t Variants:UCSC -l 'Structural Variants' -i /users/ybai/work/Structural_Variants_Combine -f Variants_UCSC_LFF.txt -d /users/ybai/work/Structural_Variants_Combine -o cnpIafrate2.txt.gz -p cnpLocke.txt.gz -q cnpRedon.txt.gz -u cnpSebat2.txt.gz -v cnpSharp2.txt.gz -w cnpTuzun.txt.gz -x delConrad2.txt.gz -y delHinds2.txt.gz -z delMccarroll.txt.gz
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
      if(inputsHash.key?('--cnpIafrate2File'))
        `BRL_UCSC_cnpIafrate2.rb -r cnpIafrate2.txt.gz -t CNP:Iafrate2 -l 'Structural Variants' -i /users/ybai/work/Structural_Variants_Combine -f cnpIafrate2_LFF.txt -d /users/ybai/work/Structural_Variants_Combine` 
      end
      if(inputsHash.key?('--cnpLockeFile'))
        `BRL_UCSC_cnpLocke.rb -r cnpLocke.txt.gz -t CNP:Locke -l 'Structural Variants' -i /users/ybai/work/Structural_Variants_Combine -f cnpLocke_LFF.txt -d /users/ybai/work/Structural_Variants_Combine`
      end
      if(inputsHash.key?('--cnpRedonFile'))
        `BRL_UCSC_cnpRedon.rb -r cnpRedon.txt.gz -t CNP:Redon -l 'Structural Variants' -i /users/ybai/work/Structural_Variants_Combine -f cnpRedon_LFF.txt -d /users/ybai/work/Structural_Variants_Combine`
      end
      if(inputsHash.key?('--cnpSebat2File'))
        `BRL_UCSC_cnpSebat2.rb -r cnpSebat2.txt.gz -t CNP:Sebat2 -l 'Structural Variants' -i /users/ybai/work/Structural_Variants_Combine -f cnpSebat2_LFF.txt -d /users/ybai/work/Structural_Variants_Combine`
      end
      if(inputsHash.key?('--cnpSharp2File'))
        `BRL_UCSC_cnpSharp2.rb -r cnpSharp2.txt.gz -t CNP:Sharp2 -l 'Structural Variants' -i /users/ybai/work/Structural_Variants_Combine -f cnpSharp2_LFF.txt -d /users/ybai/work/Structural_Variants_Combine`
      end
      if(inputsHash.key?('--cnpTuzunFile'))
        `BRL_UCSC_cnpTuzun.rb -r cnpTuzun.txt.gz -t CNP:Tuzun -l 'Structural Variants' -i /users/ybai/work/Structural_Variants_Combine -f cnpTuzun_LFF.txt -d /users/ybai/work/Structural_Variants_Combine`
      end
      if(inputsHash.key?('--delConrad2File'))
        `BRL_UCSC_delConrad2.rb -r delConrad2.txt.gz -t DEL:Conrad2 -l 'Structural Variants' -i /users/ybai/work/Structural_Variants_Combine -f delConrad2_LFF.txt -d /users/ybai/work/Structural_Variants_Combine`
      end
      if(inputsHash.key?('--delHinds2File'))
        `BRL_UCSC_delHinds2.rb -r delHinds2.txt.gz -t DEL:Hinds2 -l 'Structural Variants' -i /users/ybai/work/Structural_Variants_Combine -f delHinds2_LFF.txt -d /users/ybai/work/Structural_Variants_Combine`
      end
      if(inputsHash.key?('--delMccarrollFile'))
        `BRL_UCSC_delMccarroll.rb -r delMccarroll.txt.gz -t DEL:Mccarroll -l 'Structural Variants' -i /users/ybai/work/Structural_Variants_Combine -f delMccarroll_LFF.txt -d /users/ybai/work/Structural_Variants_Combine`
      end
    elsif("#{makeCombinedTracks_flag}" == '1')  ### --makeCombinedTracks flag is turned on: 
      open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
        if(inputsHash.key?('--cnpIafrate2File'))
          cnpIafrate2File = inputsHash['--cnpIafrate2File'].strip
          unless(File.size?("#{cDirectoryInput}/#{cnpIafrate2File}"))
            $stderr.puts "WARNING: the file '#{cnpIafrate2File}' is empty. Nothing to do."
            exit(FAILED)
          end
          # CONVERT cnpIafrate2 TO LFF RECORDS USING WHAT WE HAVE SO FAR
          cnpIafrate2 = Hash.new { |hh, kk| hh[kk] = 0 }
          # Open the file
          reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{cnpIafrate2File}")
          line = nil
          begin
            # Go through each line
            reader.each { |line|
              next if(line =~ /^\s*#/ or line !~ /\S/)
              # Chop it up
              # bin chrom chromStart chromEnd name normalGain normalLoss patientGain patientLoss total cohortType 
              ff = line.chomp.split(/\t/)
              ff[1] = ff[1].to_sym    #chrom
              ff[2] = ff[2].to_i      #chromStart
              ff[3] = ff[3].to_i      #chromEnd
              ff[4].strip!  # name 
              cnpIafrate2[ff[4]] += 1
              ff[4] = ("#{ff[4]}.#{cnpIafrate2[ff[4]]}".to_sym) if(cnpIafrate2[ff[4]] > 1)
              ff[5] = ff[5].to_i      #normalGain
              ff[6] = ff[6].to_i      #normalLoss
              ff[7] = ff[7].to_i      #patientGain
              ff[8] = ff[8].to_i      #patientLoss
              ff[9] = ff[9].to_i      #total
              ff[10] = ff[10].to_sym  #cohortType

              # Dump each linked feature as LFF
              ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
              f.print "#{className}\t#{ff[4]}.cnpIafrate2\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t+\t.\t1.0\t.\t.\t"
              # attributes in order of useful information (in LFF anyway)
              ### normalGain, normalLoss, patientGain, patientLoss, total, cohortType
              f.print "normalGain=#{ff[5]}; normalLoss=#{ff[6]}; patientGain=#{ff[7]}; patientLoss=#{ff[8]}; total=#{ff[9]}; cohortType=#{ff[10]}"
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
        end #if
        if(inputsHash.key?('--cnpLockeFile'))
            cnpLockeFile = inputsHash['--cnpLockeFile'].strip
            unless(File.size?("#{cDirectoryInput}/#{cnpLockeFile}"))
              $stderr.puts "WARNING: the file '#{cnpLockeFile}' is empty. Nothing to do."
              exit(FAILED)
            end
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
            # Go through each line
            reader.each { |line|
              next if(line =~ /^\s*#/ or line !~ /\S/)
              # Chop it up
              # bin chrom chromStart chromEnd name variationType 
              ff = line.chomp.split(/\t/)
              ff[1] = ff[1].to_sym    #chrom
              ff[2] = ff[2].to_i      #chromStart
              ff[3] = ff[3].to_i      #chromEnd
              ff[4].strip!  # name 
              cnpLocke[ff[4]] += 1
              ff[4] = ("#{ff[4]}.#{cnpLocke[ff[4]]}".to_sym) if(cnpLocke[ff[4]] > 1)
              ff[5] = ff[5].to_sym    #variationType

              if("#{ff[5]}".eql?("Gain"))
                assigned_color = gain_loss_color_hex['Gain']
              elsif("#{ff[5]}".eql?("Loss"))
                assigned_color = gain_loss_color_hex['Loss']
              elsif("#{ff[5]}".eql?("Gain and Loss"))
                assigned_color = gain_loss_color_hex['Gain and Loss']
              end

              # Dump each linked feature as LFF
              ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
              f.print "#{className}\t#{ff[4]}.cnpLocke\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t+\t.\t1.0\t.\t.\t"
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
          rescue => err
            $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
            $stderr.puts err.backtrace.join("\n")
            $stderr.puts "LINE: #{line.inspect}"
            exit(OK_WITH_ERRORS)
          end
        end #if2
        if(inputsHash.key?('--cnpRedonFile'))
          cnpRedonFile = inputsHash['--cnpRedonFile'].strip
          unless(File.size?("#{cDirectoryInput}/#{cnpRedonFile}"))
            $stderr.puts "WARNING: the file '#{cnpRedonFile}' is empty. Nothing to do."
            exit(FAILED)
          end

          # CONVERT cnpRedon TO LFF RECORDS USING WHAT WE HAVE SO FAR
          cnpRedon = Hash.new { |hh, kk| hh[kk] = 0 }
          # Open the file
          reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{cnpRedonFile}")
          line = nil
          begin
          # Go through each line
            reader.each { |line|
              next if(line =~ /^\s*#/ or line !~ /\S/)
              # Chop it up
              # bin chrom chromStart chromEnd name score strand 
              ff = line.chomp.split(/\t/)
              ff[1] = ff[1].to_sym    #chrom
              ff[2] = ff[2].to_i      #chromStart
              ff[3] = ff[3].to_i      #chromEnd
              ff[4].strip!  # name 
              cnpRedon[ff[4]] += 1
              ff[4] = ("#{ff[4]}.#{cnpRedon[ff[4]]}".to_sym) if(cnpRedon[ff[4]] > 1)
              ff[5] = ff[5].to_i      #score
              ff[6] = ff[6].to_sym    #strand

              # Dump each linked feature as LFF
              ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
              f.print "#{className}\t#{ff[4]}.cnpRedon\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t#{ff[6]}\t.\t#{ff[5]}\t.\t.\t"
              # attri_comments
              f.print "Landmark=#{ff[1]}:#{ff[2]}..#{ff[3]}"
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
        end #if3
        if(inputsHash.key?('--cnpSebat2File'))
          cnpSebat2File = inputsHash['--cnpSebat2File'].strip
          unless(File.size?("#{cDirectoryInput}/#{cnpSebat2File}"))
            $stderr.puts "WARNING: the file '#{cnpSebat2File}' is empty. Nothing to do."
            exit(FAILED)
          end

          # Assign several colors for Gain, Loss, Gain and Loss
          gain_loss_color_hex = {
            'Gain' => '00ff00',
            'Loss' => 'ff0000',
            'Gain and Loss' => '0000ff'
          }

          # CONVERT cnpSebat2 TO LFF RECORDS USING WHAT WE HAVE SO FAR
          cnpSebat2 = Hash.new { |hh, kk| hh[kk] = 0 }
          # Open the file
          reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{cnpSebat2File}")
          line = nil
          begin
           # Go through each line
            reader.each { |line|
              next if(line =~ /^\s*#/ or line !~ /\S/)
              # Chop it up
              # chrom chromStart chromEnd name probes 
              ff = line.chomp.split(/\t/)
              ff[0] = ff[0].to_sym    #chrom
              ff[1] = ff[1].to_i      #chromStart
              ff[2] = ff[2].to_i      #chromEnd
              ff[3] = ff[3].to_sym    #name

              cnpSebat2[ff[0]] += 1
              inter_name = ("#{ff[0]}.#{cnpSebat2[ff[0]]}".to_sym) if(cnpSebat2[ff[0]] >= 1)

              if("#{ff[3]}".eql?("Gain"))
                assigned_color = gain_loss_color_hex['Gain']
              elsif("#{ff[3]}".eql?("Loss"))
                assigned_color = gain_loss_color_hex['Loss']
              end

              ff[3] = "#{ff[3]}:#{inter_name}".to_sym #final name
              ff[4] = ff[4].to_i      #probes

              # Dump each linked feature as LFF
              ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
              f.print "#{className}\t#{ff[3]}.cnpSebat2\t#{lffType}\t#{lffSubtype}\t#{ff[0]}\t#{ff[1]}\t#{ff[2]}\t+\t.\t1.0\t.\t.\t"
              ## attributes in order of useful information (in LFF anyway)
              # Landmark probes
              f.print "Landmark=#{ff[0]}:#{ff[1]}..#{ff[2]}; probes=#{ff[4]}; annotationColor=##{assigned_color}"
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
        end #if4
        if(inputsHash.key?('--cnpSharp2File'))
          cnpSharp2File = inputsHash['--cnpSharp2File'].strip
          unless(File.size?("#{cDirectoryInput}/#{cnpSharp2File}"))
            $stderr.puts "WARNING: the file '#{cnpSharp2File}' is empty. Nothing to do."
            exit(FAILED)
          end

          # Assign several colors for Gain, Loss, Gain and Loss
          gain_loss_color_hex = {
            'Gain' => '00ff00',
            'Loss' => 'ff0000',
            'Gain and Loss' => '0000ff'
          }

          # CONVERT cnpSharp2 TO LFF RECORDS USING WHAT WE HAVE SO FAR
          cnpSharp2 = Hash.new { |hh, kk| hh[kk] = 0 }
          # Open the file
          reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{cnpSharp2File}")
          line = nil
          begin
            # Go through each line
            reader.each { |line|
              next if(line =~ /^\s*#/ or line !~ /\S/)
              # Chop it up
              # bin chrom chromStart chromEnd name variationType 
              ff = line.chomp.split(/\t/)
              ff[1] = ff[1].to_sym    #chrom
              ff[2] = ff[2].to_i      #chromStart
              ff[3] = ff[3].to_i      #chromEnd
              ff[4].strip!  # name 
              cnpSharp2[ff[4]] += 1
              ff[4] = ("#{ff[4]}.#{cnpSharp2[ff[4]]}".to_sym) if(cnpSharp2[ff[4]] > 1)
              ff[5] = ff[5].to_sym    #variationType

              if("#{ff[5]}".eql?("Gain"))
                assigned_color = gain_loss_color_hex['Gain']
              elsif("#{ff[5]}".eql?("Loss"))
                assigned_color = gain_loss_color_hex['Loss']
              elsif("#{ff[5]}".eql?("Gain and Loss"))
                assigned_color = gain_loss_color_hex['Gain and Loss']
              end

              # Dump each linked feature as LFF
              ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
              f.print "#{className}\t#{ff[4]}.cnpSharp2\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t+\t.\t1.0\t.\t.\t"
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
          rescue => err
            $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
            $stderr.puts err.backtrace.join("\n")
            $stderr.puts "LINE: #{line.inspect}"
            exit(OK_WITH_ERRORS)
          end
        end #if5
        if(inputsHash.key?('--cnpTuzunFile'))
          cnpTuzunFile = inputsHash['--cnpTuzunFile'].strip
          unless(File.size?("#{cDirectoryInput}/#{cnpTuzunFile}"))
            $stderr.puts "WARNING: the file '#{cnpTuzunFile}' is empty. Nothing to do."
            exit(FAILED)
          end

          # CONVERT cnpTuzun TO LFF RECORDS USING WHAT WE HAVE SO FAR
          cnpTuzun = Hash.new { |hh, kk| hh[kk] = 0 }
          # Open the file
          reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{cnpTuzunFile}")
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
              cnpTuzun[ff[4]] += 1
              ff[4] = ("#{ff[4]}.#{cnpTuzun[ff[4]]}".to_sym) if(cnpTuzun[ff[4]] > 1)

              # Dump each linked feature as LFF
              ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
              f.print "#{className}\t#{ff[4]}.cnpTuzun\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t+\t.\t1.0\t.\t.\t"
              # attri_comments
              f.print "Landmark=#{ff[1]}:#{ff[2]}..#{ff[3]}"
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
        end #if6
        if(inputsHash.key?('--delConrad2File'))
          delConrad2File = inputsHash['--delConrad2File'].strip
          unless(File.size?("#{cDirectoryInput}/#{delConrad2File}"))
            $stderr.puts "WARNING: the file '#{delConrad2File}' is empty. Nothing to do."
            exit(FAILED)
          end

          # CONVERT delConrad2 TO LFF RECORDS USING WHAT WE HAVE SO FAR
          delConrad2 = Hash.new { |hh, kk| hh[kk] = 0 }
          # Open the file
          reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{delConrad2File}")
          line = nil
          begin
            # Go through each line
            reader.each { |line|
              next if(line =~ /^\s*#/ or line !~ /\S/)
              # Chop it up
              # bin chrom chromStart chromEnd name score strand thickStart thickEnd count1 count2 offspring population 
              ff = line.chomp.split(/\t/)
              ff[1] = ff[1].to_sym    #chrom
              ff[2] = ff[2].to_i      #chromStart
              ff[3] = ff[3].to_i      #chromEnd
              ff[4].strip!  # name 
              delConrad2[ff[4]] += 1
              ff[4] = ("#{ff[4]}.#{delConrad2[ff[4]]}".to_sym) if(delConrad2[ff[4]] > 1)
              ff[5] = ff[5].to_i      #score
              ff[6] = ff[6].to_sym    #strand
              ff[7] = ff[7].to_i      #thickStart
              ff[8] = ff[8].to_i      #thickEnd
              ff[9] = ff[9].to_i      #count1
              ff[10] = ff[10].to_i    #count2
              ff[11] = ff[11].to_sym  #offspring
              ff[12] = ff[12].to_sym  #population

              # Dump each linked feature as LFF
              ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
              f.print "#{className}\t#{ff[4]}.delConrad2\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t#{ff[6]}\t.\t#{ff[5]}\t.\t.\t"
              ## attributes in order of useful information (in LFF anyway)
              # attri_comments
              f.print "Landmark=#{ff[1]}:#{ff[2]}..#{ff[3]}; thickStart=#{ff[7]}; thickEnd=#{ff[8]}; count1=#{ff[9]}; count2=#{ff[10]}; offspring=#{ff[11]}; population=#{ff[
12]}"
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
        end #if7
        if(inputsHash.key?('--delHinds2File'))
          delHinds2File = inputsHash['--delHinds2File'].strip
          unless(File.size?("#{cDirectoryInput}/#{delHinds2File}"))
            $stderr.puts "WARNING: the file '#{delHinds2File}' is empty. Nothing to do."
            exit(FAILED)
          end

          # CONVERT delHind2 TO LFF RECORDS USING WHAT WE HAVE SO FAR
          delHinds2 = Hash.new { |hh, kk| hh[kk] = 0 }
          # Open the file
          reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{delHinds2File}")
          line = nil
          begin
            # Go through each line
            reader.each { |line|
              next if(line =~ /^\s*#/ or line !~ /\S/)
              # Chop it up
              # bin chrom chromStart chromEnd name frequency 
              ff = line.chomp.split(/\t/)
              ff[1] = ff[1].to_sym    #chrom
              ff[2] = ff[2].to_i      #chromStart
              ff[3] = ff[3].to_i      #chromEnd
              ff[4].strip!  # name 
              delHinds2[ff[4]] += 1
              ff[4] = ("#{ff[4]}.#{delHinds2[ff[4]]}".to_sym) if(delHinds2[ff[4]] > 1)
              ff[5] = ff[5].to_f      #frequency

              # Dump each linked feature as LFF
              ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
              f.print "#{className}\t#{ff[4]}.delHinds2\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t+\t.\t#{ff[5]}\t.\t.\t"
              # attri_comments (none)
              f.print "Landmark=#{ff[1]}:#{ff[2]}..#{ff[3]}"
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
        end #if8
        if(inputsHash.key?('--delMccarrollFile'))
          delMccarrollFile = inputsHash['--delMccarrollFile'].strip
          unless(File.size?("#{cDirectoryInput}/#{delMccarrollFile}"))
            $stderr.puts "WARNING: the file '#{delMccarrollFile}' is empty. Nothing to do."
            exit(FAILED)
          end

          # CONVERT delMccarroll TO LFF RECORDS USING WHAT WE HAVE SO FAR
          delMccarroll = Hash.new { |hh, kk| hh[kk] = 0 }
          # Open the file
          reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{delMccarrollFile}")
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
              delMccarroll[ff[4]] += 1
              ff[4] = ("#{ff[4]}.#{delMccarroll[ff[4]]}".to_sym) if(delMccarroll[ff[4]] > 1)

              # Dump each linked feature as LFF
              ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
              f.print "#{className}\t#{ff[4]}.delMccarroll\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t+\t.\t1.0\t.\t.\t"
              #attri_comments
              f.print "Landmark=#{ff[1]}:#{ff[2]}..#{ff[3]}"
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
        end #if9
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
