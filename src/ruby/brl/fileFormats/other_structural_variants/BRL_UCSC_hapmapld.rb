#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC multiple files (hapmapLD tables) to equivalent LFF version
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

                ['--hapmapLdPhCeuFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
                ['--hapmapLdPhChbJptFile', '-p', GetoptLong::OPTIONAL_ARGUMENT],
                ['--hapmapLdPhYriFile', '-q', GetoptLong::OPTIONAL_ARGUMENT],
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
  Convert from UCSC multiple files (HapMap Ld) to equivalent LFF version.  

  COMMAND LINE ARGUMENTS:
    --trackName             | -t    => Track name for Polymorphisms:HapMap LD track.
                                       (type:subtype)
    --className             | -l    => Class name for Polymorphisms:HapMap LD track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file

    --hapmapLdPhCeuFile       | -o    => UCSC HapMap LD PhCeu file to convert
    --hapmapLdPhChbJptFile       | -p    => UCSC HapMap LD PhChbJpt file to convert
    --hapmapLdPhYriFile       | -q    => UCSC HapMap LD PhYri file to convert
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  i.e. BRL_UCSC_hapmapld.rb -t 'Polymorphisms:HapMap LD' -l 'Structural Variants' -i /users/ybai/work/Human_Project6/Variation_Repeats/HapMap_LD -f HapMap_LD_LFF.txt -d /users/ybai/work/Human_Project6/Variation_Repeats/HapMap_LD -o hapmapLdPhCeu.txt.gz -p hapmapLdPhChbJpt.txt.gz -q hapmapLdPhYri.txt.gz
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
      if(inputsHash.key?('--hapmapLdPhCeuFile'))
        hapmapLdPhCeuFile = inputsHash['--hapmapLdPhCeuFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{hapmapLdPhCeuFile}"))
          $stderr.puts "WARNING: the file '#{hapmapLdPhCeuFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        hapmapLdPhCeu = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{hapmapLdPhCeuFile}")
        line = nil
        begin
          # Go through each line
          reader.each { |line|
            next if(line =~ /^\s*#/ or line !~ /\S/)
            ff = line.chomp.split(/\t/)
            ff[4].strip!  # name 
            hapmapLdPhCeu[ff[4]] += 1
            ff[4] = ("#{ff[4]}.#{hapmapLdPhCeu[ff[4]]}") if(hapmapLdPhCeu[ff[4]] >= 1)

            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{ff[4]}.hapmapLdPhCeu\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t+\t.\t1.0\t.\t.\t"
            # attributes in order of useful information (in LFF anyway)
            f.print "ldCount=#{ff[5]}; dprime=#{ff[6]}; rsquared=#{ff[7]}; lod=#{ff[8]}; avgDprime=#{ff[9]}; avgRsquared=#{ff[10]}; avgLod=#{ff[11]}; tInt=#{ff[12]}; annotationColor=#00ff00"
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
      if(inputsHash.key?('--hapmapLdPhChbJptFile'))
        hapmapLdPhChbJptFile = inputsHash['--hapmapLdPhChbJptFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{hapmapLdPhChbJptFile}"))
          $stderr.puts "WARNING: the file '#{hapmapLdPhChbJptFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        hapmapLdPhChbJpt = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{hapmapLdPhChbJptFile}")
        line = nil
        begin
          # Go through each line
          reader.each { |line|
            next if(line =~ /^\s*#/ or line !~ /\S/)
            ff = line.chomp.split(/\t/)
 #           ff[1] = ff[1].to_sym    #chrom
 #           ff[2] = ff[2].to_i      #chromStart
 #           ff[3] = ff[3].to_i      #chromEnd
            ff[4].strip!  # name 
            hapmapLdPhChbJpt[ff[4]] += 1
            ff[4] = ("#{ff[4]}.#{hapmapLdPhChbJpt[ff[4]]}") if(hapmapLdPhChbJpt[ff[4]] >= 1)
#            ff[5] = ff[5].to_i    #ldCount
#            ff[6] = ff[6].to_sym  #dprime
#            ff[7] = ff[7].to_sym  #rsquared
#            ff[8] = ff[8].to_sym  #lod
#            ff[9] = ff[9].to_sym  #avgDprime
#            ff[10] = ff[10].to_sym  #avgRsquared
#            ff[11] = ff[11].to_sym  #avgLod
#            ff[12] = ff[12].to_sym  #tInt

            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{ff[4]}.hapmapLdPhChbJpt\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t+\t.\t1.0\t.\t.\t"
            # attributes in order of useful information (in LFF anyway)
            f.print "ldCount=#{ff[5]}; dprime=#{ff[6]}; rsquared=#{ff[7]}; lod=#{ff[8]}; avgDprime=#{ff[9]}; avgRsquared=#{ff[10]}; avgLod=#{ff[11]}; tInt=#{ff[12]}; annotationColor=#ff0000"
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
      if(inputsHash.key?('--hapmapLdPhYriFile'))
        hapmapLdPhYriFile = inputsHash['--hapmapLdPhYriFile'].strip
        unless(File.size?("#{cDirectoryInput}/#{hapmapLdPhYriFile}"))
          $stderr.puts "WARNING: the file '#{hapmapLdPhYriFile}' is empty. Nothing to do."
          exit(FAILED)
        end
        # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
        hapmapLdPhYri = Hash.new { |hh, kk| hh[kk] = 0 }
        # Open the file
        reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{hapmapLdPhYriFile}")
        line = nil
        begin
          # Go through each line
          reader.each { |line|
            next if(line =~ /^\s*#/ or line !~ /\S/)
            ff = line.chomp.split(/\t/)
#            ff[1] = ff[1].to_sym    #chrom
#            ff[2] = ff[2].to_i      #chromStart
#            ff[3] = ff[3].to_i      #chromEnd
            ff[4].strip!  # name 
            hapmapLdPhYri[ff[4]] += 1
            ff[4] = ("#{ff[4]}.#{hapmapLdPhYri[ff[4]]}") if(hapmapLdPhYri[ff[4]] >= 1)
#            ff[5] = ff[5].to_i    #ldCount
#            ff[6] = ff[6].to_sym  #dprime
#            ff[7] = ff[7].to_sym  #rsquared
#            ff[8] = ff[8].to_sym  #lod
#            ff[9] = ff[9].to_sym  #avgDprime
#            ff[10] = ff[10].to_sym  #avgRsquared
#            ff[11] = ff[11].to_sym  #avgLod
#            ff[12] = ff[12].to_sym  #tInt

            # Dump each linked feature as LFF
            ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            f.print "#{className}\t#{ff[4]}.hapmapLdPhYri\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t+\t.\t1.0\t.\t.\t"
            # attributes in order of useful information (in LFF anyway)
            f.print "ldCount=#{ff[5]}; dprime=#{ff[6]}; rsquared=#{ff[7]}; lod=#{ff[8]}; avgDprime=#{ff[9]}; avgRsquared=#{ff[10]}; avgLod=#{ff[11]}; tInt=#{ff[12]}; annotationColor=#ffff00"
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
