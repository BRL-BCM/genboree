#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC knownGene table to protein start/ends in LFF

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
def processArguments()
  optsArray = [
                ['--knownGeneFile', '-k', GetoptLong::REQUIRED_ARGUMENT],
                ['--trackName', '-t', GetoptLong::REQUIRED_ARGUMENT],
                ['--withExons', '-e', GetoptLong::NO_ARGUMENT],
                ['--help', '-h', GetoptLong::NO_ARGUMENT]
              ]
  progOpts = GetoptLong.new(*optsArray)
  optsHash = progOpts.to_hash
  usage() if(optsHash.empty? or optsHash.key?('--help') or !optsHash.key?('--knownGeneFile') or !optsHash.key?('--trackName'))
  return optsHash
end

def usage(msg='')
  puts "\n#{msg}\n" unless(msg.empty?)
  puts "

PROGRAM DESCRIPTION:
  Converts from UCSC knownGene table to protein start/ends in LFF.
   
  You provide the track name.

  COMMAND LINE ARGUMENTS:
    --knownGene  |  -k    => UCSC Known Genes file to convert
    --trackName  |  -t    => Track name for protein start/end track. (type:subtype)
    --withExons  |  -e    => [optional flag] Should we output the exons or a single annotation?
    --help       |  -h    => [optional flag] Output this usage info and exit.

  USAGE:
  ruby knownGene2proteinLFF.rb -k ./knownGenes.txt -t Protein:StartStop
"
  exit(134)
end

# ------------------------------------------------------------------------------

# ##############################################################################
# MAIN
# ##############################################################################
$stderr.puts "#{Time.now} STARTING"
optsHash = processArguments()
knownGeneFile = optsHash['--knownGeneFile'].strip
withExons = optsHash.key?('--withExons')
# Set the track type/subtype
lffType, lffSubtype = optsHash['--trackName'].strip.split(':')
genes = {}
# Open the file
reader = BRL::Util::TextReader.new(knownGeneFile)
# Go through each line
reader.each { |line|
  next if(line =~ /^\s*#/ or line =~ /^\s*$/)
  # Chop it up
  # #name chrom strand  txStart txEnd cdsStart  cdsEnd  exonCount exonStarts  exonEnds  proteinID alignID
  ff = line.strip.split("\t")
  if(genes.key?(ff[0]))
    genes[ff[0]] += 1
    ff[0] += ('.' + genes[ff[0]].to_s)
  else
    genes[ff[0]] = 1
  end
  codingStart,codingStop = ff[5].to_i + 1, ff[6].to_i + 1
  # Dump as LFF
  # SNP	78324_558	African	BCM	chr4	118931873	118931873	+	.	0.03125	.	.	alleles=CT; genotypeStr=CC0,CT1,TT15; genotypes=CC,CT,TT; genotypeCounts=0,1,15; minorAlleleFreq=0.031; minorAllele=C; majorAllele=T; minorAlleleCount=1; majorAlleleCount=32; snpId=78324_558; ampliconID=78324; snpLocalCoord=558; populationCode=YRI;
  if(withExons)
    # Split the exonStarts and exonStops
    exonCount = ff[7].to_i
    exonStarts = ff[8].chomp(',').split(',')
    exonStops = ff[9].chomp(',').split(',')
    unless(exonStarts.size == exonCount and exonStops.size == exonCount)
      raise "\n\nERROR: this line doesn't have the right number of exons (#{exonCount}).\n\n#{line}"
    end
    # Dump each exon as LFF
    # SNP	78324_558	African	BCM	chr4	118931873	118931873	+	.	0.03125	.	.	alleles=CT; genotypeStr=CC0,CT1,TT15; genotypes=CC,CT,TT; genotypeCounts=0,1,15; minorAlleleFreq=0.031; minorAllele=C; majorAllele=T; minorAlleleCount=1; majorAlleleCount=32; snpId=78324_558; ampliconID=78324; snpLocalCoord=558; populationCode=YRI;
    exonCount.times { |ii|
      exonStarts[ii] = exonStarts[ii].to_i + 1
      exonStops[ii] = exonStops[ii].to_i + 1
      # Is this a coding exon?
      next if((exonStarts[ii] < codingStart and (exonStops[ii] < codingStart)) or (exonStarts[ii] > codingStop and (exonStops[ii] > codingStop)))
      exonStart = (exonStarts[ii] < codingStart ? codingStart : exonStarts[ii])
      exonStop = (exonStops[ii].to_i > codingStop ? codingStop : exonStops[ii])
      puts "Gene\t#{ff[0]}\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{exonStart}\t#{exonStop}\t#{ff[2]}\t.\t1\t.\t.\tproteinID=#{ff[10]}; exonCount=#{ff[7]}; txStart=#{ff[3].to_i+1}; txEnd=#{ff[4].to_i+1}; cdsStart=#{ff[5].to_i+1}; cdsEnd=#{ff[6].to_i+1}; "
    }
  else
    puts "Gene\t#{ff[0]}\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{codingStart}\t#{codingStop}\t#{ff[2]}\t.\t1\t.\t.\tproteinID=#{ff[10]}; txStart=#{ff[3].to_i+1}; txEnd=#{ff[4].to_i+1}; exonCount=#{ff[7]}"
  end
}
# Close
reader.close
$stderr.puts "#{Time.now} DONE"
exit(0)
