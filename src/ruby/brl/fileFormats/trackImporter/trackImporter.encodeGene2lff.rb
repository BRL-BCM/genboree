#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC knownGene table to equivalent LFF version

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class

# ##############################################################################
# CONSTANTS
# ##############################################################################
GZIP = BRL::Util::TextWriter::GZIP_OUT

# ##############################################################################
# HELPER FUNCTIONS
# ##############################################################################
# Process command line args
# Note:
#      - extra alias files are optional, but clearly should be provided
def processArguments()
  optsArray = [
    ['--refFlatFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
    ['--trackName', '-t', GetoptLong::REQUIRED_ARGUMENT],
    ['--help', '-h', GetoptLong::NO_ARGUMENT]
  ]
  progOpts = GetoptLong.new(*optsArray)
  optsHash = progOpts.to_hash
  usage() if(optsHash.empty? or optsHash.key?('--help') or !optsHash.key?('--refFlatFile') or !optsHash.key?('--trackName'))
  return optsHash
end

def usage(msg='')
  puts "\n#{msg}\n" unless(msg.empty?)
  puts "

PROGRAM DESCRIPTION:
  Converts from UCSC refFlat table to equivalent LFF version.

  Supports the following extra files from UCSC, which provide more
  info about the gene or links to other databases:

  COMMAND LINE ARGUMENTS:
    --refFlatFile       | -r    => UCSC RefFlat file to convert
    --trackName         | -t    => Track name for ref gene track.
    --help              | -h   => [optional flag] Output this usage
                                   info and exit.

  USAGE:
  ruby encodeGene2lff.rb -r refFlat.txt.gz -t MyRef:Genes
"
  exit(134)
end

class EncodeGene
  attr_accessor :bin, :name, :chrom, :strand, :txStart, :txEnd
  attr_accessor :cdsStart, :cdEnd, :exonCount, :exonStart, :exonEnds
  attr_accessor :id, :name2, :cdsStartStatus, :cdsEndStatus, :exonFrames
  def initialize(line)
    @bin, @name, @chrom, @strand, @txStart, @txEnd,
    @cdsStart, @cdEnd, @exonCount, @exonStart, @exonEnds,
    @iD, @name2, @cdsStartStatus, @cdsEndStatus, @exonFrames = nil
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      unless(aa[0] =~ /^\d+$/)
        aa.unshift(0)
      end
      @bin = aa[0].to_i
      @name = aa[1].gsub(/;/, '.').to_sym
      @chrom = aa[2].gsub(/;/, '.').to_sym
      @strand = aa[3].to_sym
      @txStart = aa[4].to_i
      @txEnd = aa[5].to_i
      @cdsStart = aa[6].to_i
      @cdsEnd = aa[7].to_i
      @exonCount = aa[8].to_i
      @exonStarts = aa[9].split(/,/).map{|xx| xx.to_i}
      @exonEnds = aa[10].split(/,/).map{|xx| xx.to_i}
      @iD = aa[11].to_i
      @name2 = aa[12].gsub(/;/, '.').to_sym if(aa.length > 12 and !aa[12].empty?)
      @cdsStartStatus = aa[13].gsub(/;/, '.').to_sym if(aa.length > 13)
      @cdsEndStatus = aa[14].gsub(/;/, '.').to_sym if(aa.length > 14)
      @exonFrames = aa[15].split(/,/).map{|xx| xx.to_i} if(aa.length > 15)
    end
  end

  def self.loadEncodeGene(optsHash)
    retVal = {}
    seenNames = Hash.new {|hh,kk| hh[kk] = 0}
    return retVal unless( optsHash.key?('--encodeGeneFile') )
    # Read refEncodeGene file
    reader = BRL::Util::TextReader.new(optsHash['--encodeGeneFile'])
    line = nil
    begin
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*#/)
        rg = EncodeGene.new(line)
        seenNames[rg.name] += 1
        rg.name = "#{rg.name}.#{seenNames[rg.name]}" if(seenNames[rg.name] > 1)
        retVal[rg.name] = rg
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end

    return retVal
  end
end # class EncodeGene

#class RefLink
#  attr_accessor :name, :productType, :mrnaAcc, :protAcc, :geneName, :prodName, :locusLinkId, :omimId
#  def initialize(line)
#    @name, @productType, @mrnaAcc, @protAcc, @geneName, @prodName, @locusLinkId, @omimId = nil
#    unless(line.nil? or line.empty?)
#      aa = line.chomp.split(/\t/)
#      if(aa[0].nil? or aa[0].empty?)
#        aa[1] =~ /(\S+)$/
#        aa[0] = $1
#      end
#      @name = aa[0].gsub(/;/, '.').to_sym
#      @productType = (aa[1].empty? ? '' : aa[1].gsub(/;/, '.').to_sym)
#      @mrnaAcc = aa[2].gsub(/;/, '.').to_sym
#      @protAcc = (aa[3].empty? ? '' : aa[3].gsub(/;/, '.').to_sym)
#      @geneNameId = aa[4].to_i
#      @prodNameId = aa[5].to_i
#      @locusLinkId = aa[6].to_i
#      @omimId = aa[7].to_i
#    end
#  end
#
#  def self.loadRefLink(optsHash)
#    retVal = {}
#    return retVal unless( optsHash.key?('--refLinkFile') )
#    # Read refGene file
#    reader = BRL::Util::TextReader.new(optsHash['--refLinkFile'])
#    reader.each { |line|
#      next if(line !~ /\S/ or line =~ /^\s*#/)
#      aa = line.chomp.split(/\t/)
#      next if( (aa[0].nil? or aa[0].empty? ) and (aa[1].nil? or aa[1].empty? ))
#      rl = RefLink.new(line)
#      retVal[rl.mrnaAcc] = rl
#    }
#    reader.close()
#    return retVal
#  end
#end # class RefLink
#
#class RefSeqStatus
#  attr_accessor :mrnaAcc, :status
#  def initialize(line)
#    @mrnaAcc, @status = nil
#    unless(line.nil? or line.empty?)
#      aa = line.chomp.split(/\t/)
#      @mrnaAcc = aa[0].gsub(/;/, '.').to_sym
#      @status = aa[1].gsub(/;/, '.').to_sym
#    end
#  end
#
#  def self.loadRefSeqStatus(optsHash)
#    retVal = {}
#    return retVal unless( optsHash.key?('--refSeqStatusFile') )
#    # Read refStatus file
#    reader = BRL::Util::TextReader.new(optsHash['--refSeqStatusFile'])
#    reader.each { |line|
#      next if(line !~ /\S/ or line =~ /^\s*#/)
#      rss = RefSeqStatus.new(line)
#      retVal[rss.mrnaAcc] = rss
#    }
#    reader.close()
#    return retVal
#  end
#end # class RefSeqStatus
#
#class RefSeqSummary
#  attr_accessor :mrnaAcc, :completeness, :summary
#  def initialize(line)
#    @mrnaAcc, @completeness, @summary = nil
#    unless(line.nil? or line.empty?)
#      aa = line.chomp.split(/\t/)
#      @mrnaAcc = aa[0].gsub(/;/, '.').to_sym
#      @completeness = aa[1].gsub(/;/, '.').to_sym
#      @summary = (aa[2].nil? or aa[2].empty? ? '' : (aa[2].gsub(/;/, '.').to_sym))
#    end
#  end
#
#  def self.loadRefSeqSummary(optsHash)
#    retVal = {}
#    return retVal unless( optsHash.key?('--refSeqSummaryFile') )
#    # Read refGene file
#    reader = BRL::Util::TextReader.new(optsHash['--refSeqSummaryFile'])
#    reader.each { |line|
#      next if(line !~ /\S/ or line =~ /^\s*#/)
#      rss = RefSeqSummary.new(line)
#      retVal[rss.mrnaAcc] = rss
#    }
#    reader.close()
#    return retVal
#  end
#end # class RefSeqSummary

# ------------------------------------------------------------------------------

# ##############################################################################
# MAIN
# ##############################################################################
class EncodeGene2lff
  def initialize()
  end

  def main(optsHash)

    writer = BRL::Util::TextWriter.new(optsHash['outputFile'],  "w", 0)
    refFlatFile = optsHash['--refFlatFile'].strip
    $stderr.puts "#{Time.now} BEGIN (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
    unless(File.size?(refFlatFile))
      $stderr.puts "WARNING: the file '#{refFlatFile}' is empty. Nothing to do."
    end
    # Set the track type/subtype
    lffType, lffSubtype = optsHash['--trackName'].strip.split(':')
    # Do we have these alias files? Load them if so.
    #$stderr.puts "#{Time.now} START: Load RefGenes (if present)"
    #refGenes = RefGene.loadRefGene(optsHash)
    #$stderr.puts "#{Time.now} END: Loaded #{refGenes.size} refGene records (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})\n#{Time.now} START: Load RefLink (if present)"
    #refLinks = RefLink.loadRefLink(optsHash)
    #$stderr.puts "#{Time.now} END: Loaded #{refLinks.size} refLink records (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})\n#{Time.now} START: Load RefSeq Statuses (if present)"
    #refStatus = RefSeqStatus.loadRefSeqStatus(optsHash)
    #$stderr.puts "#{Time.now} END: Loaded #{refStatus.size} refseq status (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})\n#{Time.now} START: Load RefSeq Summaries (if present)"
    #refSums = RefSeqSummary.loadRefSeqSummary(optsHash)
    #$stderr.puts "#{Time.now} END: Loaded #{refSums.size} refseq summary records (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"

    # CONVERT refFlat TO LFF RECORDS USING WHAT WE HAVE SO FAR
    genes = Hash.new { |hh, kk| hh[kk] = 0 }
    # Open the file
    reader = BRL::Util::TextReader.new(refFlatFile)
    # Go through each line
    reader.each { |line|
      next if(line =~ /^\s*#/ or line !~ /\S/)
      # Chop it up
      # #name chrom strand  txStart txEnd cdsStart  cdsEnd  exonCount exonStarts  exonEnds  proteinID name2
      ff = line.chomp.split(/\t/)
      # ff[12] /name 2 is the gene name we are interested in
      ff[12].strip!
      genes[ff[12]] += 1
      ff[12] = ("#{ff[12]}.#{genes[ff[12]]}".to_sym) if(genes[ff[12]] > 1)
      accNum = ff[1].strip.gsub(/;/, '.').to_sym
      ff[3] = ff[3].to_sym
      # Split the exonStarts and exonStops
      exonCount = ff[8].to_i
      exonStarts = ff[9].chomp(',').split(/,/).map{|xx| xx.to_i}
      exonStops = ff[10].chomp(',').split(/,/).map{|xx| xx.to_i}

      unless(exonStarts.size == exonCount and exonStops.size == exonCount)
        raise "\n\nERROR: this line doesn't have the right number of exons (#{exonCount}).\n\n#{line}"
      end
      # Dump each exon as LFF
      # SNP	78324_558	African	BCM	chr4	118931873	118931873	+	.	0.03125	.	.	alleles=CT; genotypeStr=CC0,CT1,TT15; genotypes=CC,CT,TT; genotypeCounts=0,1,15; minorAlleleFreq=0.031; minorAllele=C; majorAllele=T; minorAlleleCount=1; majorAlleleCount=32; snpId=78324_558; ampliconID=78324; snpLocalCoord=558; populationCode=YRI;
      exonCount.times { |ii|
        # Class, name, track, coord, strand
        writer.print "Gene\t#{ff[12]}\t#{lffType}\t#{lffSubtype}\t#{ff[2]}\t#{exonStarts[ii].to_i+1}\t#{exonStops[ii].to_i}\t#{ff[3]}\t"
        # What is exonNum?
        if(ff[3] == :'+') # + strand
          exonNum = ii+1
          phaseIdx = ii
        else # - strand
          exonNum = exonCount-ii
          phaseIdx = (-(ii+1))
        end
        # Determine suitable phase
        phase = '.'
        #if(refGenes.key?(accNum) and !refGenes[accNum].exonFrames.nil?) # then we have the potential for a phase-lookup
        #  phase = refGenes[accNum].exonFrames[phaseIdx]
        #  phase = '.' unless(!phase.nil? and phase.to_s =~ /^[0,1,2]$/)
        #end
        # phase, qstart, qstop
        writer.print "#{phase}\t1.0\t.\t.\t"
        # attributes in order of useful information (in LFF anyway)
        # accNum, proteinAcc, txStart/Rnd, cdsStart/End, exonCount
        #writer.print "accNum=#{accNum}; proteinAcc=#{refLinks.key?(accNum) ? refLinks[accNum].protAcc : ''}; "
        #writer.print "productInfo=#{refLinks.key?(accNum) ? refLinks[accNum].productType : ''}; "
        writer.print "cdsStart=#{ff[6].to_i+1}; cdsEnd=#{ff[7].to_i}; " +
        "txStart=#{ff[4].to_i+1}; txEnd=#{ff[5].to_i}; " +
        "exonNum=#{exonNum}; exonCount=#{exonCount}; ensGene=#{ff[1]}"
        # status
        #writer.print "geneStatus=#{refStatus.key?(accNum) ? refStatus[accNum].status : ''}; "
        ## completeness, cdsStartStatus, cdsEndStatus
        #writer.print "completeness=#{refSums.key?(accNum) ? refSums[accNum].completeness : ''}; "
        #writer.print "cdsStartStatus=#{refGenes.key?(accNum) ? refGenes[accNum].cdsStartStatus : ''}; "
        #writer.print "cdsEndStatus=#{refGenes.key?(accNum) ? refGenes[accNum].cdsEndStatus : ''}; "
        ## productType, locusLinkId, omimId
        #writer.print "locusLinkId=#{refLinks.key?(accNum) ? refLinks[accNum].locusLinkId : ''}; "
        #writer.print "omimId=#{refLinks.key?(accNum) ? refLinks[accNum].omimId : ''}; "

        # sequence (none)
        writer.print "\t\t"
        #
        ## summary (free form comments)
        #writer.print "#{refSums.key?(accNum) ? refSums[accNum].summary : ''}"

        # done with record
        writer.puts ""
      }
    }
    # Close
    reader.close
    writer.close
    $stderr.puts "#{Time.now} DONE"
  end
end
