#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'getoptlong'            # For GetoptLong class (command line option parse)
require 'fileutils'
require 'brl/util/util'         # For to_hash extension of GetoptLong class
require 'brl/util/textFileUtil' # For TextReader/Writer classes

module BRL ; module DNA

class ChromCoord
  attr_accessor :chrom, :startCoord, :stopCoord, :name, :strand
  
  def initialize(chrom, startCoord, stopCoord, coordName, strand="+")
      @chrom, @startCoord, @stopCoord, @name, @strand = chrom, startCoord, stopCoord, coordName, strand
  end
  
  def to_s()
      return "ChromCoord:{ #{@chrom}, #{@startCoord}, #{@stopCoord}, #{name}, #{@strand} }"
  end

end

class SeqExtractor
  # ----------------------------------------------------------------------------
  # CONSTANTS
  # ----------------------------------------------------------------------------

  # ----------------------------------------------------------------------------
  # ATTRIBUTES
  # ----------------------------------------------------------------------------
  # ----------------------------------------------------------------------------
  # OBJECT METHODS
  # ----------------------------------------------------------------------------
  
  def initialize(optsHash)
    @optsHash = optsHash
    setParameters()
  end # END: def initialize(optsHash)

  ########################################################################
  # * *Function*: Returns the compliment sequence to the given sequence of interest.
  #   
  # * *Usage*   : <tt>  getReverseCompliment( seq )  </tt>
  # * *Args*    :
  #   - +seq+ -> The sequence for which we want the compliment.
  # * *Returns* :
  #   - +String+ -> A string of bases representing the complimented sequence of interest
  ########################################################################
  def getReverseCompliment( seq )
      return seq.reverse.tr( 'acgtACGT', 'tgcaTGCA' )
  end

  def setParameters()
    @fastaDir = @optsHash['--linearFastaDir']
    @fastaExt = @optsHash.key?('--fastaExt') ? @optsHash['--fastaExt'] : '.linear.fa.gz'
    @coordFileName = @optsHash['--coordFile']
    @chromCol = @optsHash.key?('--chromCol') ? @optsHash['--chromCol'].to_i : 4
    @chromPrefix = @optsHash.key?('--chromPrefix') ? @optsHash['--chromPrefix'] : 'chr'
    @startCoordCol = @optsHash.key?('--startCoordCol') ? @optsHash['--startCoordCol'].to_i : 5
    @endCoordCol = @optsHash.key?('--endCoordCol') ? @optsHash['--endCoordCol'].to_i : 6
    @strandCol = @optsHash.key?('--strandCol') ? @optsHash['--strandCol'].to_i : 7
    @nameCol = @optsHash.key?('--nameCol') ? @optsHash['--nameCol'].to_i : 1
    @zeroBased = @optsHash.key?('--0based') ? true : false
    @doRevCompl = @optsHash.key?('--doRevCompl') ? true : false
  end # END: def setParameters()
  
  def readCoordsFile()
    @coords = Hash.new { |hh, kk| hh[kk] = [] }
    reader = BRL::Util::TextReader.new(@coordFileName)
    reader.each { |line|
      # line.strip!
      next if(line =~ /^\s*[#\[]/ or line =~ /^\s*$/)
      ff = line.split("\t")
      strand = ff[@strandCol].to_s.strip == "-" ? "-" : "+"
      startCoord = ff[@startCoordCol].to_i
      startCoord -= 1 unless(@zeroBased)
      stopCoord = ff[@endCoordCol].to_i - 1
      startCoord, stopCoord = stopCoord, startCoord if startCoord > stopCoord
      chrom = ff[@chromCol]
      chrom = @chromPrefix + chrom unless(chrom =~ /^chr/)
      annoName = ff[@nameCol]
      @coords[chrom] << ChromCoord.new(chrom, startCoord, stopCoord, annoName, strand)
    }
    reader.close
    return
  end
  
  def getFastaSeqs()
    str = ""
    # For each chrom
    @coords.each_key { |chrom|
      # Open the chrom file
      chromFileName = @fastaDir + '/' + chrom + @fastaExt
      reader = BRL::Util::TextReader.new(chromFileName)
      # Read in the linear sequence
      reader.readline # defline
      chromSeq = reader.readline
      # For each ChromCoord
      @coords[chrom].each { |coord|
        $stderr.puts coord.to_s
        # Get seq
        seq = chromSeq[ coord.startCoord..coord.stopCoord ]
        # If the strand is "-", we need the reverse compliment
        seq = getReverseCompliment( seq ) if(@doRevCompl and (coord.strand == "-"))
        # Make defline
        defline = ">#{coord.name.strip}|#{coord.chrom}|#{@zeroBased ? coord.startCoord : coord.startCoord+1 }|#{coord.stopCoord+1}| DNA_SRC: #{coord.chrom} START: #{@zeroBased ? coord.startCoord : coord.startCoord+1} STOP: #{coord.stopCoord+1} STRAND: #{coord.strand}"
        # Output defline
        str << defline + "\n"
        # Output seq
        str << seq + "\n"
      }
      # Clear linear sequence
      chromSeq = nil
    }
    return str
  end

  def outputFastaSeqs()
    puts getFastaSeqs()
    return    
  end
  
  # ----------------------------------------------------------------------------
  # CLASS METHODS
  # ----------------------------------------------------------------------------
  
  def SeqExtractor.processArguments
    optsArray =  [  ['--linearFastaDir', '-d', GetoptLong::REQUIRED_ARGUMENT],
                  ['--fastaExt', '-x', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--coordFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                  ['--nameCol', '-n', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--chromCol', '-k', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--startCoordCol', '-b', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--endCoordCol', '-e', GetoptLong::OPTIONAL_ARGUMENT],
		  ['--chromPrefix', '-p', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--0based', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--1based', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--strandCol', '-s', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--doRevCompl', '-r', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--help', '-h', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    optsHash = progOpts.to_hash
    SeqExtractor.usage() if(optsHash.key?('--help') or !progOpts.getMissingOptions().empty?);
    return optsHash
  end

  def SeqExtractor.usage(msg='')
     puts "\n#{msg}\n" unless(msg.empty?)
    puts "
  
  PROGRAM DESCRIPTION:
  
  COMMAND LINE ARGUMENTS:
    --linearFastaDir  | -d  =>  Dir where linearized fasta files for chroms are.
    --coordFile       | -f  =>  Tab-delimited file with coordinates.
    --nameCol         | -n  =>  Col in coordFile where something like a name can
                                be found. Default = 1, like LFF.
    --chromCol        | -k  =>  Col in coordFile where chromosome name is [0,n).
                                Default = 4, like in LFF.
    --startCoordCol   | -b  =>  Col in coordFile where start-coord is [0,n).
                                Default = 5, like in LFF.
    --endCoordCol     | -e  =>  Col in coordFile where end-coord is [0,n).
                                Default = 6, like in LFF.
    --strandCol       | -s  =>  [optional] Col in coordFile where strand is defined
                                or defaults to  '+' strand.
    --chromPrefix     | -p  =>  [optional] Prefix for chromosome name
    				Default = 'chr'
    --fastaExt        | -x  =>  [optional] Extension for the linear fasta file.
                                Default = '.linear.fa.gz'
    --0based                =>  [optional flag] Coords are [0,n).
    --1based                =>  [optional flag] DEFAULT. Coords are [1,n].
    --doRevCompl      | -r  =>  [optional flag] Turn on reverse complement if
                                strand is negative. Default is false.
    --help            | -h  =>  [optional flag] Print usage info and exit.
  
  USAGE:
  
  " ;
    exit(134);
  end # def SeqExtractor.usage(msg='')
end # class SeqExtractor

end ; end 

if( __FILE__ == $0 )
  # ##############################################################################
  # MAIN
  # ##############################################################################
  # Get command line args
  optsHash = BRL::DNA::SeqExtractor.processArguments()
  # Init deployment object, read properties file, set params
  extractor = BRL::DNA::SeqExtractor.new(optsHash)
  # Read coords file
  extractor.readCoordsFile()
  # Get sequence on a chrom-by-chrom basis, output to stdout
  extractor.outputFastaSeqs()
  exit(0)
end
