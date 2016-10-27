#!/usr/bin/env ruby
# ##############################################################################
# PURPOSE
# ##############################################################################

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
include BRL::Util

# ##############################################################################
# CONSTANTS
# ##############################################################################
GZIP = BRL::Util::TextWriter::GZIP_OUT

# ##############################################################################
# CLASSES
# ##############################################################################
class MorbidRecord
  @@gene2record = Hash.new {|hh, kk| hh[kk] = []}
  @@morbidRecords = []

  attr_accessor :desc, :genes, :omimId, :cytoStr, :cytoBands, :foundAsGene

  def initialize(line)
    line.tr!('{}', '[]')
    @foundAsGene = false
    @genes = {}
    @cytoBands = {}
    fields = line.split(/\|/)
    if(fields.size == 4)
      @desc = fields[0].strip
      @omimId = fields[2].strip
      genesStr = fields[1].strip
      genes = genesStr.split(/,/)
      genes.each { |gene|
        @genes[gene.strip] = true
      }
      @cytoStr = fields[3].strip
    else
      raise "ERROR: bad MorbidMap line detected:\n    #{line}"
    end
    @genes.each_key { |gene| @@gene2record[gene] << self }
    @@morbidRecords << self
  end

  def to_rec()
    return "#{@desc}  |#{@genes.keys.sort.join(', ')}  |#{omimId}|#{@cytoStr}"
  end

  def self.gene2record()
    return @@gene2record
  end

  def self.morbidRecords()
    return @@morbidRecords
  end
end

class LFFRecord
  attr_accessor :lffClass, :name, :type, :subtype, :chrom, :start, :stop, :strand, :phase, :score, :qstart, :qstop, :avps
  def initialize(line)
    fields = line.split(/\t/)
    if(fields.size >= 13)
      @lffClass, @name, @type, @subtype, @chrom, @start, @stop, @strand, @phase, @score, @qstart, @qstop, @avps, @seq, @comm = *fields
      @start = @start.to_i
      @stop = @stop.to_i
      @start = 1 if(@start < 1)
      @stop = 1 if(@stop < 1)
      @score = @score.to_f
    else
      raise "ERROR: bad LFF line detected:\n    #{line}"
    end
  end

  def addAvp(attribute, value)
    @avps << "#{attribute.strip}=#{value.strip}; "
  end

  def to_lff()
    return  "#{@lffClass}\t#{@name}\t#{@type}\t#{@subtype}\t#{@chrom}\t#{@start}\t#{@stop}\t" +
            "#{@strand}\t#{@phase}\t#{@score}\t#{@qstart}\t#{@qstop}\t#{@avps}"
  end
end

class CytoBand < LFFRecord
  @@band2record = {}
  @@centromereInfo = Hash.new {|hh, kk| hh[kk] = []}
  @@qtermByChr = {}
  @@ptermByChr = {}

  def initialize(line)
    super(line)
    @@band2record[@name] = self
  end

  def self.deriveSpecialInfo()
    @@band2record.each_key { |band|
      rec = @@band2record[band]
      rec.name =~ /^(..?)([pq]).+$/
      chromArm = $2
      chrom = "chr#{$1}"
      if(rec.avps =~ /bandType=acen/)
        if(chromArm == 'p')
          @@centromereInfo[chrom][0] = rec
        else
          @@centromereInfo[chrom][1] = rec
        end
      end
      if((!@@ptermByChr.key?(chrom)) or (rec.start < @@ptermByChr[chrom].start))
        @@ptermByChr[chrom] = rec
      end
      if((!@@qtermByChr.key?(chrom)) or (rec.start > @@qtermByChr[chrom].start))
        @@qtermByChr[chrom] = rec
      end
    }
    return
  end

  def self.fuzzyGet(key)
    retVal = [ @@band2record[key] ]
    if(@@band2record[key].nil?)
      retVal = []
      @@band2record.each_key { |kk|
        retVal << @@band2record[kk] if(kk =~ /^#{key}/)
      }
    end
    return retVal
  end

  def self.band2record()
    return @@band2record
  end

  def self.qtermByChr()
    return @@qtermByChr
  end

  def self.ptermByChr()
    return @@ptermByChr
  end

  def self.centromereInfo()
    return @@centromereInfo
  end
end

class KnownGene < LFFRecord
  attr_accessor :aliases
  def initialize(line)
    @aliases = {}
    super(line)
    if(@avps =~ /aliases\s*=\s*([^;]+);/)
      aliasesStr = $1
      aliases = aliasesStr.split(/,/)
      aliases.each {|anAlias| @aliases[anAlias.strip] = true }
    end
  end
end

class RefGene < LFFRecord
  @@refGenes = Hash.new {|hh,kk| hh[kk] = []}

  def self.refGenes()
    return @@refGenes
  end
end

# ##############################################################################
# HELPER FUNCTIONS
# ##############################################################################
# Process command line args
# Note:
#      - extra alias files are optional, but clearly should be provided
def processArguments()
  optsArray = [
                ['--morbidMapFile', '-m', GetoptLong::REQUIRED_ARGUMENT],
                ['--entryPointFile', '-e', GetoptLong::REQUIRED_ARGUMENT],
                ['--knownGeneFile', '-k', GetoptLong::OPTIONAL_ARGUMENT],
                ['--refGeneFile', '-r', GetoptLong::OPTIONAL_ARGUMENT],
                ['--cytoBandFile', '-c', GetoptLong::OPTIONAL_ARGUMENT],
                ['--trackType', '-t', GetoptLong::OPTIONAL_ARGUMENT],
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
    usage("ERROR: the REQUIRED args are missing!")
    exit(USAGE_ERR)
  else
    return optsHash
  end
  return optsHash
end

def usage(msg='')
  puts "\n#{msg}\n" unless(msg.empty?)
  puts "

PROGRAM DESCRIPTION:
  Converts NCBI's OMIM morbidmap data file to a set of Known Gene annotations
  and/or a set of cytoband-based regions.

  NOTE: because NCBI uses non-standard or old aliases for some genes, it's
  possible some of the OMIM morbidity map records might be missing. These are
  output on stderr.

  One or both of knownGeneFile + refGeneFile or cytoBandFile must be provided.

  COMMAND LINE ARGUMENTS:
    --morbidMapFile  |  -m    => NCBI OMIM morbidmap file
    --entryPointFile |  -e    => 3-col LFF entrypoints file
    --knownGeneFile  |  -k    => [optional] Known:Gene LFF file
    --refGeneFile    |  -r    => [optional] RefSeq:Gene LFF file
                                 Used to find a gene if no Known:Gene is found
    --cytoBandFile   |  -c    => [optional] Cyto:Band LFF file
    --trackType      |  -t    => [optional] Track type to use for output
                                 track(s). Subtype is fixed. Default is 'OMIM',
                                 yielding:
                                    OMIM:MorbidGene
                                    OMIM:MorbidRegion
    --help           |  -h    => [optional flag] Output this usage info and exit.

  USAGE:
  ruby omimMorbid2lff.rb -m morbidmap.txt -k ./knownGenes.lff -r ./refGene.lff \
       -c cytoBand.lff -t Omim
"
  exit(134)
end

 ------------------------------------------------------------------------------

# ##############################################################################
# MAIN
# ##############################################################################
begin
  $stderr.puts "#{Time.now} BEGIN (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
  optsHash = processArguments()
  trackType = (optsHash['--trackType'] or "OMIM")
  # Load entrypoints file
  entryPoints = {}
  entryPointFile = optsHash['--entryPointFile'].strip
  reader = BRL::Util::TextReader.new(entryPointFile)
  reader.each { |line|
    line.strip!
    next if(line !~ /\S/ or line =~ /^\s*#/)
    fields = line.split(/\t/)
    entryPoints[fields[0].strip] = fields[2].to_i
  }
  reader.close()
  $stderr.puts "#{Time.now} STATUS: Loaded entrypoints file (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"

  # Load morbid map file
  morbidMapFile = optsHash['--morbidMapFile'].strip
  reader = BRL::Util::TextReader.new(morbidMapFile)
  reader.each { |line|
    line.strip!
    next if(line !~ /\S/ or line =~ /^\s*#/)
    morbidRec = MorbidRecord.new(line)
  }
  reader.close()
  $stderr.puts "#{Time.now} STATUS: Loaded morbid map file (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"

  # Process cytoband file
  cytoBandFile = optsHash['--cytoBandFile']
  unless(cytoBandFile.nil? or cytoBandFile.empty?)
    # Load cytoband file
    reader = BRL::Util::TextReader.new(cytoBandFile)
    reader.each { |line|
      line.strip!
      next if(line !~ /\S/ or line =~ /^\s*#/)
      cytoRec = CytoBand.new(line)
    }
    reader.close()
    CytoBand.deriveSpecialInfo()

    $stderr.puts "#{Time.now} STATUS: Loaded cytoband file (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
    # Go through each MorbidRec and make a region based on its cytoband data
    MorbidRecord.morbidRecords.each { |record|
      cytoStr = record.cytoStr.strip
      bandNames = cytoStr.split(/-/)
      rStart, rStop = nil
      bandChrShort = bandChr = nil
      bandNames.each { |bandName|
        bandName.strip!
        if(bandName =~ /^Chr\.(.+)$/i)
          bandChrShort = $1
          bandChr = "chr#{$1}"
          rStart = 1
          rStop = entryPoints[bandChr]
        elsif(bandName =~ /^([^-]+)?qter/)
          begin
            unless($1.nil?)
              bandChrShort = $1
              bandChr = "chr#{$1}"
            end
            cytoRec = CytoBand.qtermByChr[bandChr]
            rStart = cytoRec.start if(rStart.nil? or cytoRec.start < rStart)
            rStop = cytoRec.stop if(rStop.nil? or cytoRec.stop > rStop)
          rescue => err
            $stderr.puts "ERROR INFO: #{bandChrShort.inspect}\t#{bandChr.inspect}\t#{bandName.inspect}\t#{cytoRec.inspect}\t#{rStart}\t#{rStop}\t#{CytoBand.qtermByChr.inspect}"
            $stderr.puts err.message
            $stderr.puts err.backtrace.join("\n")
          end
        elsif(bandName =~ /^([^-]+)?pter/)
          begin
            unless($1.nil?)
              bandChrShort = $1
              bandChr = "chr#{$1}"
            end
            cytoRec = CytoBand.ptermByChr[bandChr]
            rStart = cytoRec.start if(rStart.nil? or cytoRec.start < rStart)
            rStop = cytoRec.stop if(rStop.nil? or cytoRec.stop > rStop)
          rescue => err
            $stderr.puts "ERROR INFO: #{bandChrShort.inspect}\t#{bandChr.inspect}\t#{bandName.inspect}\t#{cytoRec.inspect}\t#{rStart}\t#{rStop}\t#{CytoBand.qtermByChr.inspect}"
            $stderr.puts err.message
            $stderr.puts err.backtrace.join("\n")
          end
        elsif(bandName =~ /^([^-]+)?cen/)
          begin
            unless($1.nil?)
              bandChrShort = $1
              bandChr = "chr#{$1}"
            end
            rStart = CytoBand.centromereInfo[bandChr][0].start
            rStop = CytoBand.centromereInfo[bandChr][1].stop
          rescue => err
            $stderr.puts "ERROR INFO: #{bandChrShort.inspect}\t#{bandChr.inspect}\t#{bandName.inspect}\t#{cytoRec.inspect}\t#{rStart}\t#{rStop}\t#{CytoBand.centromereInfo.inspect}"
            $stderr.puts err.message
            $stderr.puts err.backtrace.join("\n")
          end
        elsif(bandName =~ /^(.+)?([pq])(.+)?$/)
          begin
            if($1.nil?)
              bandName = "#{bandChrShort}#{$2}#{$3}"
            else
              bandChrShort = $1
              bandChr = "chr#{$1}"
            end
            cytoRecs = CytoBand.fuzzyGet(bandName)
            cytoRecs.each { |cytoRec|
              rStart = cytoRec.start if(rStart.nil? or cytoRec.start < rStart)
              rStop = cytoRec.stop if(rStop.nil? or cytoRec.stop > rStop)
            }
          rescue => err
            $stderr.puts "ERROR INFO: #{bandChrShort.inspect}\t#{bandChr.inspect}\t#{bandName.inspect}\t#{cytoRecs.inspect}\t#{rStart}\t#{rStop}"
            $stderr.puts err.message
            $stderr.puts err.backtrace.join("\n")
          end
        else
          $stderr.puts "DEBUG: unknown band/region type for this morbid record:\n  #{record.to_rec}"
        end
      }
      # Output an OMIM:MorbidRegion annotation
      puts  "OMIM\t#{record.desc}\tOMIM\tMorbidRegion\t#{bandChr}\t#{rStart}\t#{rStop}\t+\t.\t1.0\t.\t.\t" +
            "omimId=#{record.omimId}; description=#{record.desc}; cytoBand=#{record.cytoStr}; " +
            "geneAliases=#{record.genes.keys.sort.join(',')};"
    }
    $stderr.puts "#{Time.now} STATUS: Output morbid regions (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
  end

  # Process knownGene file
  knownGeneFile = optsHash['--knownGeneFile']
  refGeneFile = optsHash['--refGeneFile']
  unless(knownGeneFile.nil? or knownGeneFile.empty? or refGeneFile.nil? or refGeneFile.empty?)
    $stderr.puts "#{Time.now} STATUS: start processing refGenes (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
    # Load refgene first (used to try to resolve if no Known:Gene is found)
    reader = BRL::Util::TextReader.new(refGeneFile)
    reader.each { |line|
      line.strip!
      next if(line !~ /\S/ or line =~ /^\s*#/)
      rg = RefGene.new(line)
      if(rg.name =~ /^(.+)(?:\.\d+)?$/)
        genericName = $1
      else
        genericName = rg.name
      end
      RefGene.refGenes[genericName] << rg
    }
    reader.close()
    $stderr.puts "#{Time.now} STATUS: start processing known genes (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
    # Go through each known gene record
    reader = BRL::Util::TextReader.new(knownGeneFile)
    reader.each { |line|
      line.strip!
      next if(line !~ /\S/ or line =~ /^\s*#/)
      kg = KnownGene.new(line)
      # Determine if it or any of its aliases are associated with an OMIM morbid region
      # If so, add omim info to gene
      omimRecCount = 1
      hasOmim = false
      omimRecsVisited = {}
      kg.aliases.keys.sort.each {|kgAlias|
        if(MorbidRecord.gene2record().key?(kgAlias))
          hasOmim = true
          morbidRecs = MorbidRecord.gene2record()[kgAlias]
          morbidRecs.each {|morbidRec|
            next if(omimRecsVisited.key?(morbidRec))
            omimRecsVisited[morbidRec] = true
            kg.addAvp("omimRegionDesc_#{omimRecCount}", morbidRec.desc)
            kg.addAvp("omimRegionId_#{omimRecCount}", morbidRec.omimId)
            morbidRec.foundAsGene = true
            omimRecCount += 1
          }
        end
      }
      kg.type = trackType
      kg.subtype = "MorbidGene"
      kg.lffClass = "OMIM"
      puts kg.to_lff if(hasOmim)
    }
    reader.close()
    $stderr.puts "#{Time.now} STATUS: Output known genes in morbid omim regions (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"

    # Go through OMIM morbid regions with no known gene records are try to find a RefGene
    MorbidRecord.morbidRecords().each {|morbidRec|
      unless(morbidRec.foundAsGene)
        # Go through each gene listed and look for a RefGene matching it
        morbidRec.genes.each_key { |gene|
          if(RefGene.refGenes.key?(gene))
            # If found one, output all genes mapping to that name and stop looking
            refGenes = RefGene.refGenes[gene]
            refGenes.each {|refGene|
              refGene.addAvp("omimRegionDesc", morbidRec.desc)
              refGene.addAvp("omimRegionId", morbidRec.omimId)
              refGene.type = trackType
              refGene.subtype = "MorbidGene"
              refGene.lffClass = "OMIM"
              puts refGene.to_lff
            }
            morbidRec.foundAsGene = true
            break
          end
        }
      end
    }

    # Output OMIM morbid regions with no gene records of any kind
    MorbidRecord.morbidRecords().each {|morbidRec|
      unless(morbidRec.foundAsGene)
        $stderr.puts morbidRec.to_rec
      end
    }
    $stderr.puts "#{Time.now} STATUS: Output on stderr morbid regions for which no known gene could be found (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
  end

  $stderr.puts "#{Time.now} DONE"
  exit(OK)

rescue => err
  $stderr.puts "Error occurs... Details: #{err.message}"
  $stderr.puts err.backtrace.join("\n")
  exit(FATAL)
end

exit(OK)
