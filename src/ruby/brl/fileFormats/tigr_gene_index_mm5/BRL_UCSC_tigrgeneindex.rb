#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC TIGR Gene Index - Alignment of TIGR Gene Index TCs Against the Mouse Genome table to equivalent LFF version

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
                ['--tigrGeneIndexFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
                ['--trackName', '-t', GetoptLong::REQUIRED_ARGUMENT],
                ['--className', '-l', GetoptLong::REQUIRED_ARGUMENT],
                ['--cDirectoryInput', '-i', GetoptLong::REQUIRED_ARGUMENT],
                ['--fileToOutput', '-f', GetoptLong::REQUIRED_ARGUMENT],
                ['--screenToOutput', '-s', GetoptLong::REQUIRED_ARGUMENT],
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
  Converts from UCSC TIGR Gene Index table to equivalent LFF version.

  COMMAND LINE ARGUMENTS:
    --tigrGeneIndexFile       | -r    => UCSC tigrGeneIndex file to convert
    --trackName             | -t    => Track name for tigrGeneIndex track.
                                       (type:subtype)
    --className             | -l    => Class name for tigrGeneIndex track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --screenToOutput          | -s    => collected screen output file name
    --cDirectoryOutput      | -d    => directory location of converted file
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  BRL_UCSC_tigrgeneindex.rb -r tigrGeneIndex.txt.gz -t Alignment:TGI -l 'mRNA and EST' -i /users/ybai/work/Project6/mRNA_EST/TIGR_Gene_Index -f tigrGeneIndex_LFF.txt -s tigrGeneIndex.txt -d /users/ybai/work/Project6/mRNA_EST/TIGR_Gene_Index
"
end

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    tigrGeneIndexFile = inputsHash['--tigrGeneIndexFile'].strip
    className = inputsHash['--className'].strip
    cDirectoryInput = inputsHash['--cDirectoryInput'].strip
    fileToOutput = inputsHash['--fileToOutput'].strip
    screenToOutput = inputsHash['--screenToOutput'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip

    unless(File.size?("#{cDirectoryInput}/#{tigrGeneIndexFile}"))
      $stderr.puts "WARNING: the file '#{tigrGeneIndexFile}' is empty. Nothing to do."
      exit(FAILED)
    end

    # Set the track type/subtype
    lffType, lffSubtype = inputsHash['--trackName'].strip.split(':')


    # CONVERT tigrGeneIndex TO LFF RECORDS USING WHAT WE HAVE SO FAR
    geneIndex = Hash.new { |hh, kk| hh[kk] = 0 }
    # Open the file
    reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{tigrGeneIndexFile}")
    line = nil
    begin
      open("#{cDirectoryOutput}/#{screenToOutput}", 'w') do |fs|
      open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
     # Go through each line
      reader.each { |line|
        next if(line =~ /^\s*#/ or line !~ /\S/)
        # Chop it up
        # name chrom strand txStart txEnd cdsStart cdsEnd exonCount exonStarts exonEnds  
        ff = line.chomp.split(/\t/)
        ff[0].strip!
        geneIndex[ff[0]] += 1  
        ff[0] = ("#{ff[0]}.Transcript_#{geneIndex[ff[0]]}".to_sym) if(geneIndex[ff[0]] >= 1)
        ff[1] = ff[1].to_sym	#chrom
        ff[2] = ff[2].to_sym	#strand
        ff[3] = ff[3].to_i	#txStart
        ff[4] = ff[4].to_i	#txEnd
        ff[5] = ff[5].to_i	#cdsStart
        ff[6] = ff[6].to_i	#cdsEnd
        exonCount = ff[7].to_i
        exonStarts = ff[8].chomp(',').split(/,/).map{|xx| xx.to_i}
        exonStops = ff[9].chomp(',').split(/,/).map{|xx| xx.to_i}

        unless(exonStarts.size == exonCount and exonStops.size == exonCount)
          $stderr.puts "\n\nERROR: this line doesn't have the right number of exons (#{exonCount}).\n\n#{line}"
        end

        fs.print "#{ff[0]}\t#{exonCount}\n"

        exonCount.times { |ii|  ### start from index 0
          ### print each exon's information
          ### class, name, type, subtype, entry pint(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
          if(ff[2] == :'+') # + strand
            exonNum = ii+1
          else # - strand
            exonNum = exonCount-ii ### 0 ==> 8 
          end
          f.print "#{className}\t#{ff[0]}.Exon_#{exonNum}\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{exonStarts[ii].to_i+1}\t#{exonStops[ii].to_i}\t#{ff[2]}\t.\t1.0\t.\t.\t"

          f.print "cdsStart=#{ff[5].to_i+1}; cdsEnd=#{ff[6].to_i}; " +
                "txStart=#{ff[3].to_i+1}; txEnd=#{ff[4].to_i}; " +
                "exonCount=#{exonCount} "

          # sequence (none)
          f.print "\t.\t"
          # summary (free form comments)
          f.print "."

          # done with record
          f.puts ""
        }
      } # reader close
      reader.close
      end #open
      end #open
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
