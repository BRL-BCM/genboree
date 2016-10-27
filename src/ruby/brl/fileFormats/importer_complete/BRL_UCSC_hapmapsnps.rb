#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC multiple files (hapmapSnps tables) to equivalent LFF version
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

                ['--hapmapSnpsCEUFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
                ['--hapmapSnpsCHBFile', '-p', GetoptLong::OPTIONAL_ARGUMENT],
                ['--hapmapSnpsJPTFile', '-q', GetoptLong::OPTIONAL_ARGUMENT],
                ['--hapmapSnpsYRIFile', '-u', GetoptLong::OPTIONAL_ARGUMENT],
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
  Convert from UCSC multiple files (HapMap SNPs) to equivalent LFF version.  

  COMMAND LINE ARGUMENTS:
    --trackName             | -t    => Track name for Polymorphisms:HapMap SNPs track.
                                       (type:subtype)
    --className             | -l    => Class name for Polymorphisms:HapMap SNPs track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file

    --hapmapSnpsCEUFile       | -o    => UCSC HapMap SNPs CEU file to convert
    --hapmapSnpsCHBFile       | -p    => UCSC HapMap SNPs CHB file to convert
    --hapmapSnpsJPTFile       | -q    => UCSC HapMap SNPs JPT file to convert
    --hapmapSnpsYRIFile       | -u    => UCSC HapMap SNPs YRI file to convert
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  i.e. BRL_UCSC_hapmapsnps.rb -t 'Polymorphisms:HapMap SNPs' -l 'Structural Variants' -i /users/ybai/work/Project4/HapMap_SNPs -f HapMap_SNPs_LFF.txt -d /users/ybai/work/Project4/HapMap_SNPs -o hapmapSnpsCEU.txt.gz -p hapmapSnpsCHB.txt.gz -q hapmapSnpsJPT.txt.gz -u hapmapSnpsYRI.txt.gz
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
      if(inputsHash.key?('--hapmapSnpsCEUFile'))
        hapmapSnpsCEUFile = inputsHash['--hapmapSnpsCEUFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{hapmapSnpsCEUFile}"))
          $stderr.puts "WARNING: the file '#{hapmapSnpsCEUFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        hapmapSnpsCEU = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{hapmapSnpsCEUFile}")
        line = nil
        begin
          # Go through each line
          reader.each { |line|
            next if(line =~ /^\s*#/ or line !~ /\S/)
            ff = line.chomp.split(/\t/)
   #         ff[1] = ff[1].to_sym    #chrom
   #         ff[2] = ff[2].to_i      #chromStart
   #         ff[3] = ff[3].to_i      #chromEnd
            ff[4].strip!  # name 
            hapmapSnpsCEU[ff[4]] += 1
            ff[4] = ("#{ff[4]}.#{hapmapSnpsCEU[ff[4]]}") if(hapmapSnpsCEU[ff[4]] >= 1)
   #         ff[5] = ff[5].to_i    #score
   #         ff[6] = ff[6].to_sym  #strand
   #         ff[7] = ff[7].to_sym  #observed
   #         ff[8] = ff[8].to_sym  #allele1
   #         ff[9] = ff[9].to_i  #homoCount1
   #         ff[10] = ff[10].to_sym  #allele2
   #         ff[11] = ff[11].to_i  #homoCount2
   #         ff[12] = ff[12].to_i  #heteroCount

            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{ff[4]}.hapmapSnpsCEU\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t#{ff[6]}\t.\t#{ff[5]}\t.\t.\t"
            # attributes in order of useful information (in LFF anyway)
            f.print "observed=#{ff[7]}; allele1=#{ff[8]}; homoCount1=#{ff[9]}; allele2=#{ff[10]}; homoCount1=#{ff[11]}; heteroCount=#{ff[12]}; annotationColor=#00ff00"
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
      if(inputsHash.key?('--hapmapSnpsCHBFile'))
        hapmapSnpsCHBFile = inputsHash['--hapmapSnpsCHBFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{hapmapSnpsCHBFile}"))
          $stderr.puts "WARNING: the file '#{hapmapSnpsCHBFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        hapmapSnpsCHB = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{hapmapSnpsCHBFile}")
        line = nil
        begin
          # Go through each line
          reader.each { |line|
            next if(line =~ /^\s*#/ or line !~ /\S/)
            ff = line.chomp.split(/\t/)
            ff[4].strip!  # name 
            hapmapSnpsCHB[ff[4]] += 1
            ff[4] = ("#{ff[4]}.#{hapmapSnpsCHB[ff[4]]}") if(hapmapSnpsCHB[ff[4]] >= 1)

            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{ff[4]}.hapmapSnpsCHB\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t#{ff[6]}\t.\t#{ff[5]}\t.\t.\t"
            # attributes in order of useful information (in LFF anyway)
            f.print "observed=#{ff[7]}; allele1=#{ff[8]}; homoCount1=#{ff[9]}; allele2=#{ff[10]}; homoCount1=#{ff[11]}; heteroCount=#{ff[12]}; annotationColor=#ff0000"
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
      if(inputsHash.key?('--hapmapSnpsJPTFile'))
        hapmapSnpsJPTFile = inputsHash['--hapmapSnpsJPTFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{hapmapSnpsJPTFile}"))
          $stderr.puts "WARNING: the file '#{hapmapSnpsJPTFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        hapmapSnpsJPT = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{hapmapSnpsJPTFile}")
        line = nil
        begin
          # Go through each line
          reader.each { |line|
            next if(line =~ /^\s*#/ or line !~ /\S/)
            ff = line.chomp.split(/\t/)
            ff[4].strip!  # name 
            hapmapSnpsJPT[ff[4]] += 1
            ff[4] = ("#{ff[4]}.#{hapmapSnpsJPT[ff[4]]}") if(hapmapSnpsJPT[ff[4]] >= 1)

            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{ff[4]}.hapmapSnpsJPT\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t#{ff[6]}\t.\t#{ff[5]}\t.\t.\t"
            # attributes in order of useful information (in LFF anyway)
            f.print "observed=#{ff[7]}; allele1=#{ff[8]}; homoCount1=#{ff[9]}; allele2=#{ff[10]}; homoCount1=#{ff[11]}; heteroCount=#{ff[12]}; annotationColor=#ffff00"
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
      if(inputsHash.key?('--hapmapSnpsYRIFile'))
        hapmapSnpsYRIFile = inputsHash['--hapmapSnpsYRIFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{hapmapSnpsYRIFile}"))
          $stderr.puts "WARNING: the file '#{hapmapSnpsYRIFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        hapmapSnpsYRI = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{hapmapSnpsYRIFile}")
        line = nil
        begin
          # Go through each line
          reader.each { |line|
            next if(line =~ /^\s*#/ or line !~ /\S/)
            ff = line.chomp.split(/\t/)
            ff[4].strip!  # name 
            hapmapSnpsYRI[ff[4]] += 1
            ff[4] = ("#{ff[4]}.#{hapmapSnpsYRI[ff[4]]}") if(hapmapSnpsYRI[ff[4]] >= 1)

            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{ff[4]}.hapmapSnpsYRI\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t#{ff[6]}\t.\t#{ff[5]}\t.\t.\t"
            # attributes in order of useful information (in LFF anyway)
            f.print "observed=#{ff[7]}; allele1=#{ff[8]}; homoCount1=#{ff[9]}; allele2=#{ff[10]}; homoCount1=#{ff[11]}; heteroCount=#{ff[12]}; annotationColor=#0000ff"
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
