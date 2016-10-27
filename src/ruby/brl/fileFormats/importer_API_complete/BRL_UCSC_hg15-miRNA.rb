#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC RNA Genes table to equivalent LFF version

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
                ['--rnaGeneFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
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
  Converts from UCSC rnaGene table to equivalent LFF version.

  COMMAND LINE ARGUMENTS:
    --rnaGeneFile       | -r    => UCSC rnaGene file to convert
    --trackType             | -t    => Track type for RNA Genes track.
    --trackSubtype             | -s    => Track subtype for RNA Genes track.
    --className             | -l    => Class name for RNA Genes track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name prefix
    --cDirectoryOutput      | -d    => directory location of converted file
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  BRL_UCSC_hg15-miRNA.rb -r rnaGene.txt.gz -t RNA -s 'RNA Genes' -l 'Gene and Gene Prediction' -i /users/ybai/work/Human_hg15-miRNA -f RNA_Genes_LFF.txt -d /users/ybai/work/Human_hg15-miRNA
"
end

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    rnaGeneFile = inputsHash['--rnaGeneFile'].strip
    lffType = inputsHash['--trackType'].strip
    lffSubtype = inputsHash['--trackSubtype'].strip
    className = inputsHash['--className'].strip
    cDirectoryInput = inputsHash['--cDirectoryInput'].strip
    fileToOutput = inputsHash['--fileToOutput'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip

    unless(File.size?("#{cDirectoryInput}/#{rnaGeneFile}"))
      $stderr.puts "WARNING: the file '#{rnaGeneFile}' is empty. Nothing to do."
      exit(FAILED)
    end

    # Assign several colors for tRNA, rRNA, scRNA, snRNA, snoRNA, miRNA, misc_RNA
    rna_hex = { 
      'tRNA' => 'ff0000', 
      'rRNA' => '0000ff', 
      'scRNA' => '00ff00', 
      'snRNA' => '008000', 
      'snoRNA' => '800000', 
      'miRNA' => '000080', 
      'misc_RNA' => 'ff00ff' 
    }

    # CONVERT RNA Gene TO LFF RECORDS USING WHAT WE HAVE SO FAR
    rnaGene = Hash.new { |hh, kk| hh[kk] = 0 }
    # Open the file
    reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{rnaGeneFile}")
    line = nil

    begin
        open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
        # Go through each line
        reader.each { |line|
          next if(line =~ /^\s*#/ or line !~ /\S/)
          # Chop it up
          # chrom chromStart chromEnd name score strand source type fullScore isPsuedo 
          ff = line.chomp.split(/\t/)
          ff[0] = ff[0].to_sym	#chrom
          ff[1] = ff[1].to_i	#chromStart
          ff[2] = ff[2].to_i	#chromEnd
          ff[3] = ff[3].to_sym    #name
          ff[4] = ff[4].to_i      #score
          ff[5] = ff[5].to_sym    #strand
          ff[6] = ff[6].to_sym    #source
          ff[7] = ff[7].to_sym    #type
          ff[8] = ff[8].to_f      #fullScore
          ff[9] = ff[9].to_i    #isPsuedo

          rnaGene[ff[3]] += 1
          ff[3] = ("#{ff[3]}.#{rnaGene[ff[3]]}".to_sym) if(rnaGene[ff[3]] >= 1)

          if("#{ff[7]}".eql?("tRNA"))
            assigned_color = rna_hex['tRNA']
          elsif("#{ff[7]}".eql?("rRNA"))
            assigned_color = rna_hex['rRNA']
          elsif("#{ff[7]}".eql?("scRNA"))
            assigned_color = rna_hex['scRNA']
          elsif("#{ff[7]}".eql?("snRNA"))
            assigned_color = rna_hex['snRNA']
          elsif("#{ff[7]}".eql?("snoRNA"))
            assigned_color = rna_hex['snoRNA']
          elsif("#{ff[7]}".eql?("miRNA"))
            assigned_color = rna_hex['miRNA']
          elsif("#{ff[7]}".eql?("misc_RNA"))
            assigned_color = rna_hex['misc_RNA']
          else
            assigned_color = '000000'
          end
          # Dump each linked feature as LFF
          ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
          f.print "#{className}\t#{ff[3]}\t#{lffType}\t#{lffSubtype}\t#{ff[0]}\t#{ff[1]}\t#{ff[2]}\t#{ff[5]}\t.\t#{ff[4]}\t.\t.\t"
          ## attributes in order of useful information (in LFF anyway)
          # attri_comments
          f.print "type=#{ff[7]}; fullScore=#{ff[8]}; isPsuedo=#{ff[9]}; annotationColor=##{assigned_color}"
          # sequence (none)
          f.print "\t.\t"
          # summary (free form comments)
          f.print "."

          # done with record
          f.puts ""
        } # reader close
        reader.close
        end
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
