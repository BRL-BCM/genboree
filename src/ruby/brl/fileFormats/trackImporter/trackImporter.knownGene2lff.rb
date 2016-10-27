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
# HELPER FUNCTIONS
# ##############################################################################
# Process command line args
# Note:
#      - extra alias files are optional, but clearly should be provided
def processArguments()
  optsArray = [
    ['--knownGeneFile', '-k', GetoptLong::REQUIRED_ARGUMENT],
    ['--trackName', '-t', GetoptLong::REQUIRED_ARGUMENT],
    ['--kgAlias', '-a', GetoptLong::OPTIONAL_ARGUMENT],
    ['--keggPathway', '-g', GetoptLong::OPTIONAL_ARGUMENT],
    ['--kgXref', '-x', GetoptLong::OPTIONAL_ARGUMENT],
    ['--ensembl', '-e', GetoptLong::OPTIONAL_ARGUMENT],
    ['--kg3tokg4', '-y', GetoptLong::OPTIONAL_ARGUMENT],
    ['--kg2tokg3', '-z', GetoptLong::OPTIONAL_ARGUMENT],
    ['--locusLink', '-l', GetoptLong::OPTIONAL_ARGUMENT],
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
  Converts from UCSC knownGene table to equivalent LFF version.

  Supports the following alias files from UCSC, to link the Known Genes
  to other databases:

    keggPathway
    kgAlias
    kgXref
    knownToEnsembl
    knownToLocusLink
    knownToRefSeq
    kg3tokg4
    kg2tokg3

  These files are optional and may not be available for all species.
  However, if available they should be downloaded and used!

  COMMAND LINE ARGUMENTS:
    --knownGene   |  -k    => UCSC Known Genes file to convert
    --trackName   |  -t    => Track name for known gene track. (type:subtype)
    --kgAlias     |  -a    => [optional] kgAlias file name
    --keggPathway |  -g    => [optional] KEGG pathway cross-ref file
    --kgXref      |  -x    => [optional] eXternal references file
    --ensembl     |  -e    => [optional] Known gene to ensembl cross-ref file.
    --locusLink   |  -l    => [optional] Known gene to LocusLink cross-ref file.
    --kg3tokg4    |  -y    => [optional] UCSC Gene name 2 to UCSC Gene name 1
    --kg2tokg3    |  -z    => [optional] UCSC Gene name 1 to old Gene name
    --help        |  -h    => [optional flag] Output this usage info and exit.

  USAGE:
  ruby knownGene2LFF.rb -k ./knownGenes.txt -t Protein:StartStop
"
  exit(134)
end

def loadKgAlias(optsHash)
  return nil unless( optsHash.key?('--kgAlias') )
  kgAliases = Hash.new { |hh,kk| hh[kk] = [] }
  # Read aliases file
  reader = BRL::Util::TextReader.new(optsHash['--kgAlias'])
  reader.each { |line|
    next if(line !~ /\S/ or line =~ /^\s*#/)
    fields = line.strip.split(/\t/)
    kgAliases[fields[0].strip] << fields[1].strip
  }
  reader.close()
  # Sort alias lists
  kgAliases.each_key { |kk|
    kgAliases[kk].sort! { |aa,bb|
      retVal = (aa.downcase <=> bb.downcase)
      retVal = (aa <=> bb) if(retVal == 0)
      retVal
    }
  }
  return kgAliases
end

def loadKgNames(optsHash)
  return nil unless( optsHash.key?('--kg3tokg4') )
  return nil unless( optsHash.key?('--kg2tokg3') )
  kgNames = Hash.new { |hh,kk| hh[kk] = "" }

  # Read in the UCSC 2 to UCSC 1 file
  reader = BRL::Util::TextReader.new(optsHash['--kg3tokg4'])
  reader.each { |line|
    next if(line !~ /\S/ or line =~ /^\s*#/)
    fields = line.strip.split(/\t/)
    kgNames[fields[4].strip] = fields[0].strip
  }
  reader.close()

  # Read in the UCSC 1 to Old Gene name file
  reader = BRL::Util::TextReader.new(optsHash['--kg2tokg3'])
  reader.each { |line|
    next if(line !~ /\S/ or line =~ /^\s*#/)
    fields = line.strip.split(/\t/)
    index = kgNames.index(fields[4].strip)
    if(not index == nil)
      kgNames[index] = fields[0].strip
    end
  }
  reader.close()
 
  return kgNames
end

def loadKeggPathway(optsHash)
  return nil unless( optsHash.key?('--keggPathway') )
  keggMapIds = Hash.new { |hh,kk| hh[kk] = [] }
  # Read aliases file
  reader = BRL::Util::TextReader.new(optsHash['--keggPathway'])
  reader.each { |line|
    next if(line !~ /\S/ or line =~ /^\s*#/)
    fields = line.strip.split(/\t/)
    keggMapIds[fields[0].strip] << fields[2].strip
  }
  reader.close()
  # Sort alias lists
  keggMapIds.each_key { |kk|
    keggMapIds[kk].sort! { |aa,bb|
      retVal = (aa.downcase <=> bb.downcase)
      retVal = (aa <=> bb) if(retVal == 0)
      retVal
    }
  }
  return keggMapIds
end

def loadXrefs(optsHash)
  return nil unless( optsHash.key?('--kgXref') )
  # What xrefs do we store?
  xrefs = Hash.new { |hh,kk| hh[kk] = {
      :mRNAids => [],
      :swissProtIds => [],
      :swissProtDisplayNames => [],
      :geneSymbols => [],
      :refSeqIds => [],
      :protAccs => [],
      :descriptions => []
    }
  }
  # Read aliases file
  reader = BRL::Util::TextReader.new(optsHash['--kgXref'])
  reader.each { |line|
    next if(line !~ /\S/ or line =~ /^\s*#/)
    fields = line.strip.split(/\t/)
    kgId = fields[0].strip
    xrefs[kgId][:mRNAids] << fields[1].strip
    xrefs[kgId][:swissProtIds] << fields[2].strip
    xrefs[kgId][:swissProtDisplayNames] << fields[3].strip
    xrefs[kgId][:geneSymbols] << fields[4].strip
    xrefs[kgId][:refSeqIds] << fields[5].strip
    xrefs[kgId][:protAccs] << fields[6].strip
    fields[7].strip!
    fields[7] << '.' unless(fields[7] =~ /\.$/)
    xrefs[kgId][:descriptions] << fields[7]
  }
  reader.close()
  # Sort xref lists
  xrefs.each_key { |kk|
    [ :mRNAids, :swissProtIds, :swissProtDisplayNames, :geneSymbols,
      :refSeqIds, :protAccs, :descriptions ].each { |xref|
      xrefs[kk][xref].sort! { |aa,bb|
        retVal = (aa.downcase <=> bb.downcase)
        retVal = (aa <=> bb) if(retVal == 0)
        retVal
      }
    }
  }
  return xrefs
end

def loadEnsembl(optsHash)
  return nil unless( optsHash.key?('--ensembl') )
  ensemblMap = Hash.new { |hh,kk| hh[kk] = [] }
  # Read aliases file
  reader = BRL::Util::TextReader.new(optsHash['--ensembl'])
  reader.each { |line|
    next if(line !~ /\S/ or line =~ /^\s*#/)
    fields = line.strip.split(/\t/)
    ensemblMap[fields[0].strip] << fields[1].strip
  }
  reader.close()
  # Sort alias lists
  ensemblMap.each_key { |kk|
    ensemblMap[kk].sort! { |aa,bb|
      retVal = (aa.downcase <=> bb.downcase)
      retVal = (aa <=> bb) if(retVal == 0)
      retVal
    }
  }
  return ensemblMap
end

def loadLocusLinks(optsHash)
  return nil unless( optsHash.key?('--locusLink') )
  locusLinks = Hash.new { |hh,kk| hh[kk] = [] }
  # Read aliases file
  reader = BRL::Util::TextReader.new(optsHash['--locusLink'])
  reader.each { |line|
    next if(line !~ /\S/ or line =~ /^\s*#/)
    fields = line.strip.split(/\t/)
    locusLinks[fields[0].strip] << fields[1].strip
  }
  reader.close()
  # Sort alias lists
  locusLinks.each_key { |kk|
    locusLinks[kk].sort! { |aa,bb|
      retVal = (aa.downcase <=> bb.downcase)
      retVal = (aa <=> bb) if(retVal == 0)
      retVal
    }
  }
  return locusLinks
end

# ------------------------------------------------------------------------------

# ##############################################################################
# MAIN
# ##############################################################################
class KnownGene2lff
  def initialize()
  end

  def main(optsHash)
    writer = BRL::Util::TextWriter.new(optsHash['outputFile'],  "w", 0)
    $stderr.puts "#{Time.now} BEGIN"
    knownGeneFile = optsHash['--knownGeneFile'].strip
    # Set the track type/subtype
    lffType, lffSubtype = optsHash['--trackName'].strip.split(':')
    # Do we have these alias files? Load them if so.
    $stderr.puts "#{Time.now} START: Load KgAliases (if present)"
    kgAliases = loadKgAlias(optsHash)
    $stderr.puts "#{Time.now} START: Load KEGG Pathway links (if present)"
    keggLinks = loadKeggPathway(optsHash)
    $stderr.puts "#{Time.now} START: Load various Xref links (if present)"
    kgXrefs = loadXrefs(optsHash)
    $stderr.puts "#{Time.now} START: Load Ensembl links (if present)"
    ensembl = loadEnsembl(optsHash)
    $stderr.puts "#{Time.now} START: Load LocusLink links (if present)"
    locusLinks = loadLocusLinks(optsHash)
    $stderr.puts "#{Time.now} START: Load KgNames (if present)"
    kgNames = loadKgNames(optsHash)

    genes = Hash.new { |hh, kk| hh[kk] = 0 }
    # Open the file
    reader = BRL::Util::TextReader.new(knownGeneFile)
    # Go through each line
    reader.each { |line|
      next if(line =~ /^\s*#/ or line !~ /\S/)
      # Chop it up
      # #name chrom strand  txStart txEnd cdsStart  cdsEnd  exonCount exonStarts  exonEnds  proteinID alignID
      ff = line.strip.split(/\t/)
      ff[0].strip!
      genes[ff[0]] += 1
      ff[0] += ('.' + genes[ff[0]].to_s) if(genes[ff[0]] > 1)
      # Split the exonStarts and exonStops
      exonCount = ff[7].to_i
      exonStarts = ff[8].chomp(',').split(/,/)
      exonStops = ff[9].chomp(',').split(/,/)
      unless(exonStarts.size == exonCount and exonStops.size == exonCount)
        raise "\n\nERROR: this line doesn't have the right number of exons (#{exonCount}).\n\n#{line}"
      end
      # Dump each exon as LFF
      # SNP	78324_558	African	BCM	chr4	118931873	118931873	+	.	0.03125	.	.	alleles=CT; genotypeStr=CC0,CT1,TT15; genotypes=CC,CT,TT; genotypeCounts=0,1,15; minorAlleleFreq=0.031; minorAllele=C; majorAllele=T; minorAlleleCount=1; majorAlleleCount=32; snpId=78324_558; ampliconID=78324; snpLocalCoord=558; populationCode=YRI;
      exonCount.times { |ii|
        
        name = ff[0]
        #Changes the name to the oldest version available
        if((kgNames != nil) && (kgNames.has_key?(name)))
          name = kgNames[name]
        end
        
        writer.print "Gene\t#{name}\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{exonStarts[ii].to_i+1}\t#{exonStops[ii].to_i}\t#{ff[2]}\t.\t1\t"
        writer.print ".\t.\t"
        # attributes in order of useful information (in LFF anyway)
        # kgAlias list
        writer.print "aliases=" + (kgAliases[ff[0]].join(',')).gsub(/;/, '.') + "; " if(kgAliases)
        writer.print "cdsStart=#{ff[5].to_i+1}; cdsEnd=#{ff[6].to_i}; " +
        "txStart=#{ff[3].to_i+1}; txEnd=#{ff[4].to_i}; " +
        "exonCount=#{ff[7]}; "
        # descriptions
        if(kgXrefs and kgXrefs.key?(ff[0]))
          writer.print "descriptions=" + (kgXrefs[ff[0]][:descriptions].join(' ')).gsub(/;/, '.') + "; "
        elsif(kgXrefs and not kgXrefs.key?(ff[0]))
          writer.print "descriptions=; "
        end
        # geneSymbols
        if(kgXrefs and kgXrefs.key?(ff[0]))
          writer.print "geneSymbols=" + (kgXrefs[ff[0]][:geneSymbols].join(',')).gsub(/;/, '.') + "; "
        elsif(kgXrefs and not kgXrefs.key?(ff[0]))
          writer.print "geneSymbols=; "
        end
        # ensembl
        writer.print "ensemblIds=" + (ensembl[ff[0]].join(',')).gsub(/;/, '.') + "; " if(ensembl)
        # locus links
        writer.print "locusLinkIds=" + (locusLinks[ff[0]].join(',')).gsub(/;/, '.') + "; " if(locusLinks)
        # mRNAs
        if(kgXrefs and kgXrefs.key?(ff[0]))
          writer.print "mRNAids=" + (kgXrefs[ff[0]][:mRNAids].join(',')).gsub(/;/, '.') + "; "
        elsif(kgXrefs and not kgXrefs.key?(ff[0]))
          writer.print "mRNAids=; "
        end
        # pathways
        writer.print "keggPathwayIds=" + (keggLinks[ff[0]].join(',')).gsub(/;/, '.') + "; " if(keggLinks)
        # protAccs
        if(kgXrefs and kgXrefs.key?(ff[0]))
          writer.print "protAccs=" + (kgXrefs[ff[0]][:protAccs].join(',')).gsub(/;/, '.') + "; "
        elsif(kgXrefs and not kgXrefs.key?(ff[0]))
          writer.print "protAccs=; "
        end
        # refSeqIds
        if(kgXrefs and kgXrefs.key?(ff[0]))
          writer.print "refSeqIds=" + (kgXrefs[ff[0]][:refSeqIds].join(',')).gsub(/;/, '.') + "; "
        elsif(kgXrefs and not kgXrefs.key?(ff[0]))
          writer.print "refSeqIds=; "
        end
        # swissProtsIds
        if(kgXrefs and kgXrefs.key?(ff[0]))
          writer.print "swissProtIds=" + (kgXrefs[ff[0]][:swissProtIds].join(',')).gsub(/;/, '.') + "; "
        elsif(kgXrefs and not kgXrefs.key?(ff[0]))
          writer.print "swissProtIds=; "
        end
        # swissProtDisplayNames
        if(kgXrefs and kgXrefs.key?(ff[0]))
          writer.print "swissProtDisplayNames=" + (kgXrefs[ff[0]][:swissProtDisplayNames].join(',')).gsub(/;/, '.') + "; "
        elsif(kgXrefs and not kgXrefs.key?(ff[0]))
          writer.print "swissProtDisplayNames=; "
        end
        # proteinId & alignId
        writer.print "alignId=#{ff[11]}; proteinId=#{ff[10]}; "

        writer.puts ""
      }
    }
    # Close
    reader.close
    writer.close
    $stderr.puts "#{Time.now} DONE"
  end
end