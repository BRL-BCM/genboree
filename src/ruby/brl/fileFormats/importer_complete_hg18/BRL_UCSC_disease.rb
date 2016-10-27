#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC multiple files (phenotype and disease associations - case control) to equivalent LFF version
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

                ['--cccTrendPvalBdFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
                ['--cccTrendPvalCadFile', '-p', GetoptLong::OPTIONAL_ARGUMENT],
                ['--cccTrendPvalCdFile', '-q', GetoptLong::OPTIONAL_ARGUMENT],
                ['--cccTrendPvalHtFile', '-u', GetoptLong::OPTIONAL_ARGUMENT],
                ['--cccTrendPvalRaFile', '-v', GetoptLong::OPTIONAL_ARGUMENT],
                ['--cccTrendPvalT1dFile', '-w', GetoptLong::OPTIONAL_ARGUMENT],
                ['--cccTrendPvalT2dFile', '-x', GetoptLong::OPTIONAL_ARGUMENT],
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
  Convert from UCSC multiple files (phenotype and disease associations - case control) to equivalent LFF version.  

  COMMAND LINE ARGUMENTS:
    --trackName             | -t    => Track name for DIS:CCC track.
                                       (type:subtype)
    --className             | -l    => Class name for DIS:CCC track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file

    --cccTrendPvalBdFile       | -o    => UCSC Bipolar disorder file to convert
    --cccTrendPvalCadFile       | -p    => UCSC Coronary artery disease file to convert
    --cccTrendPvalCdFile       | -q    => UCSC Coronary's disease file to convert
    --cccTrendPvalHtFile       | -u    => UCSC Hypertension file to convert
    --cccTrendPvalRaFile       | -v    => UCSC Rheumatoid arthritis file to convert
    --cccTrendPvalT1dFile       | -w    => UCSC Type 1 diabetes file to convert
    --cccTrendPvalT2dFile       | -x    => UCSC Type 2 diabetes file to convert
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  i.e. BRL_UCSC_disease.rb -t DIS:CCC -l 'Phenotype Disease Ass' -i /users/ybai/work/Project3/DIS_CCC -f DIS_CCC_LFF.txt -d /users/ybai/work/Project3/DIS_CCC -o cccTrendPvalBd.txt.gz -p cccTrendPvalCad.txt.gz -q cccTrendPvalCd.txt.gz -u cccTrendPvalHt.txt.gz -v cccTrendPvalRa.txt.gz -w cccTrendPvalT1d.txt.gz -x cccTrendPvalT2d.txt.gz
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

    #color_hex = {
    #  'black' => '000000',
    #  'green' => '00ff00',
    #  'red' => 'ff0000',
    #  'yellow' => 'ffff00',
    #  'blue' => '0000ff'
    #  'purple' => 'ff00ff'
    #  'gray' => '909090'
    #}

    open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
      if(inputsHash.key?('--cccTrendPvalBdFile'))
        cccTrendPvalBdFile = inputsHash['--cccTrendPvalBdFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{cccTrendPvalBdFile}"))
          $stderr.puts "WARNING: the file '#{cccTrendPvalBdFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        cccTrendPvalBd = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{cccTrendPvalBdFile}")
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
            cccTrendPvalBd[ff[0]] += 1
            chromIndex = ("#{ff[0]}.#{cccTrendPvalBd[ff[0]]}".to_sym) if(cccTrendPvalBd[ff[0]] >= 1)
            chromStart = ff[1] - 10
            chromEnd = ff[1] + 10
            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{chromIndex}.cccTrendPvalBd\t#{lffType}\t#{lffSubtype}\t#{ff[0]}\t#{chromStart+1}\t#{chromEnd+1}\t+\t.\t1.0\t.\t.\t"
            # attributes in order of useful information (in LFF anyway)
            ### val
            f.print "val=#{ff[2]}; annotationColor=#000000"
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
      if(inputsHash.key?('--cccTrendPvalCadFile'))
        cccTrendPvalCadFile = inputsHash['--cccTrendPvalCadFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{cccTrendPvalCadFile}"))
          $stderr.puts "WARNING: the file '#{cccTrendPvalCadFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        cccTrendPvalCad = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{cccTrendPvalCadFile}")
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
            cccTrendPvalCad[ff[0]] += 1
            chromIndex = ("#{ff[0]}.#{cccTrendPvalCad[ff[0]]}".to_sym) if(cccTrendPvalCad[ff[0]] >= 1)
            chromStart = ff[1] - 10
            chromEnd = ff[1] + 10
            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{chromIndex}.cccTrendPvalCad\t#{lffType}\t#{lffSubtype}\t#{ff[0]}\t#{chromStart+1}\t#{chromEnd+1}\t+\t.\t1.0\t.\t.\t"
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
      end #if2
      if(inputsHash.key?('--cccTrendPvalCdFile'))
        cccTrendPvalCdFile = inputsHash['--cccTrendPvalCdFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{cccTrendPvalCdFile}"))
          $stderr.puts "WARNING: the file '#{cccTrendPvalCdFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        cccTrendPvalCd = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{cccTrendPvalCdFile}")
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
            cccTrendPvalCd[ff[0]] += 1
            chromIndex = ("#{ff[0]}.#{cccTrendPvalCd[ff[0]]}".to_sym) if(cccTrendPvalCd[ff[0]] >= 1)
            chromStart = ff[1] - 10
            chromEnd = ff[1] + 10
            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{chromIndex}.cccTrendPvalCd\t#{lffType}\t#{lffSubtype}\t#{ff[0]}\t#{chromStart+1}\t#{chromEnd+1}\t+\t.\t1.0\t.\t.\t"
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
      end #if3
      if(inputsHash.key?('--cccTrendPvalHtFile'))
        cccTrendPvalHtFile = inputsHash['--cccTrendPvalHtFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{cccTrendPvalHtFile}"))
          $stderr.puts "WARNING: the file '#{cccTrendPvalHtFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        cccTrendPvalHt = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{cccTrendPvalHtFile}")
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
            cccTrendPvalHt[ff[0]] += 1
            chromIndex = ("#{ff[0]}.#{cccTrendPvalHt[ff[0]]}".to_sym) if(cccTrendPvalHt[ff[0]] >= 1)
            chromStart = ff[1] - 10
            chromEnd = ff[1] + 10
            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{chromIndex}.cccTrendPvalHt\t#{lffType}\t#{lffSubtype}\t#{ff[0]}\t#{chromStart+1}\t#{chromEnd+1}\t+\t.\t1.0\t.\t.\t"
            # attributes in order of useful information (in LFF anyway)
            ### val
            f.print "val=#{ff[2]}; annotationColor=#ffff00"
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
      end #if4
      if(inputsHash.key?('--cccTrendPvalRaFile'))
        cccTrendPvalRaFile = inputsHash['--cccTrendPvalRaFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{cccTrendPvalRaFile}"))
          $stderr.puts "WARNING: the file '#{cccTrendPvalRaFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        cccTrendPvalRa = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{cccTrendPvalRaFile}")
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
            cccTrendPvalRa[ff[0]] += 1
            chromIndex = ("#{ff[0]}.#{cccTrendPvalRa[ff[0]]}".to_sym) if(cccTrendPvalRa[ff[0]] >= 1)
            chromStart = ff[1] - 10
            chromEnd = ff[1] + 10
            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{chromIndex}.cccTrendPvalRa\t#{lffType}\t#{lffSubtype}\t#{ff[0]}\t#{chromStart+1}\t#{chromEnd+1}\t+\t.\t1.0\t.\t.\t"
            # attributes in order of useful information (in LFF anyway)
            ### val
            f.print "val=#{ff[2]}; annotationColor=#0000ff"
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
      end #if5
      if(inputsHash.key?('--cccTrendPvalT1dFile'))
        cccTrendPvalT1dFile = inputsHash['--cccTrendPvalT1dFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{cccTrendPvalT1dFile}"))
          $stderr.puts "WARNING: the file '#{cccTrendPvalT1dFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        cccTrendPvalT1d = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{cccTrendPvalT1dFile}")
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
            cccTrendPvalT1d[ff[0]] += 1
            chromIndex = ("#{ff[0]}.#{cccTrendPvalT1d[ff[0]]}".to_sym) if(cccTrendPvalT1d[ff[0]] >= 1)
            chromStart = ff[1] - 10
            chromEnd = ff[1] + 10
            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{chromIndex}.cccTrendPvalT1d\t#{lffType}\t#{lffSubtype}\t#{ff[0]}\t#{chromStart+1}\t#{chromEnd+1}\t+\t.\t1.0\t.\t.\t"
            # attributes in order of useful information (in LFF anyway)
            ### val
            f.print "val=#{ff[2]}; annotationColor=#ff00ff"
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
      end #if6
      if(inputsHash.key?('--cccTrendPvalT2dFile'))
        cccTrendPvalT2dFile = inputsHash['--cccTrendPvalT2dFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{cccTrendPvalT2dFile}"))
          $stderr.puts "WARNING: the file '#{cccTrendPvalT2dFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        cccTrendPvalT2d = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{cccTrendPvalT2dFile}")
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
            cccTrendPvalT2d[ff[0]] += 1
            chromIndex = ("#{ff[0]}.#{cccTrendPvalT2d[ff[0]]}".to_sym) if(cccTrendPvalT2d[ff[0]] >= 1)
            chromStart = ff[1] - 10
            chromEnd = ff[1] + 10
            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{chromIndex}.cccTrendPvalT2d\t#{lffType}\t#{lffSubtype}\t#{ff[0]}\t#{chromStart+1}\t#{chromEnd+1}\t+\t.\t1.0\t.\t.\t"
            # attributes in order of useful information (in LFF anyway)
            ### val
            f.print "val=#{ff[2]}; annotationColor=#909090"
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
      end #if7
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
