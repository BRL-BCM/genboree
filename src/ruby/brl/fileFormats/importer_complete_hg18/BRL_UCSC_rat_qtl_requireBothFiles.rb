#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC QTL files (Rat Quantitative Trait Locus from RGD Coarsely Mapped to Human) to equivalent LFF version

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
                ['--rgdQtlFile', '-o', GetoptLong::REQUIRED_ARGUMENT],
                ['--rgdQtlLinkFile', '-p', GetoptLong::OPTIONAL_ARGUMENT],
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
  Convert from UCSC Rat qtl file to equivalent LFF version.  

  COMMAND LINE ARGUMENTS:
    --trackName             | -t    => Track name for RGD:RAT QTL track.
                                       (type:subtype)
    --className             | -l    => Class name for RGD:RAT QTL track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file
    --rgdQtlFile            | -o    => UCSC qtl file to convert
    --rgdQtlLinkFile        | -p    => UCSC qtlLink file to convert
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  i.e. BRL_UCSC_rat_qtl_requireBothFiles.rb -t 'RGD:RAT QTL' -l 'Phenotype Disease Ass' -i /users/ybai/work/Project3/RGD_RAT_QTL -f RGD_RAT_QTL_LFF.txt -d /users/ybai/work/Project3/RGD_RAT_QTL -o rgdRatQtl.txt.gz -p rgdRatQtlLink.txt.gz 
"
end

class RgdQtlLink
  attr_accessor :id, :name, :description

  def initialize(line)
    @id, @name, @description = nil
    unless(line.nil? or line.empty?)
      qtl = line.chomp.split(/\t/)
      if(qtl[0].nil? or qtl[0].empty?)
        qtl[1] =~ /(\S+)$/ ### not empty line
        qtl[0] = $1  ### assign first match
      end
      @id = qtl[0].to_sym
      @name = qtl[1].to_sym
      @description = qtl[2].to_sym
    end
  end

  def self.loadRgdQtlLink(inputsHash)
    retVal = {}
    return retVal unless( inputsHash.key?('--rgdQtlLinkFile') ) ### if no this kind of file, just stop at here
    # Read rgdQtlLink file
    reader = BRL::Util::TextReader.new(inputsHash['--rgdQtlLinkFile'])  ### get the whole file's contents one time
    reader.each { |line|
      next if(line !~ /\S/ or line =~ /^\s*#/) ### if it is empty or comment line
      rl = RgdQtlLink.new(line)
      retVal[rl.name] = rl ### use id as the key to the line
    }
    reader.close()
    return retVal
  end
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

    # Do we have the alias files? Load it if so.
    rgdQtlLink = RgdQtlLink.loadRgdQtlLink(inputsHash)

    open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
      rgdQtlFile = inputsHash['--rgdQtlFile'].strip
      unless(File.size?("#{cDirectoryInput}/#{rgdQtlFile}"))
        $stderr.puts "WARNING: the file '#{rgdQtlFile}' is empty. Nothing to do."
        exit(FAILED)
      end
      # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
      # Open the file
      reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{rgdQtlFile}")
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
          ff[4] = ff[4].to_sym    #name

          # Dump each linked feature as LFF
          ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
          f.print "#{className}\t"
          if("#{ff[4]}" == "#{rgdQtlLink[ff[4]].name}")
           f.print "#{rgdQtlLink[ff[4]].description}\t"
          else
           f.print "#{ff[4]}\t"
          end

          f.print "#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]+1}\t#{ff[3]}\t+\t.\t1.0\t.\t.\t"
          # attributes in order of useful information (in LFF anyway)
          ### attri_comments
          f.print "id=#{rgdQtlLink[ff[4]].id}; symbolicName=#{ff[4]}"
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
