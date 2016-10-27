#!/usr/bin/env ruby
require 'brl/genboree/genboreeUtil'

module BRL ; module Util

#############################################################################
# This class is used to validate and parse a vcf file
# Can be used to convert into lff
#############################################################################
class VcfParser
  RESERVED_METAINFO_FIELDS = { 'INFO' => nil, 'FILTER' => nil, 'FORMAT' => nil, 'contig' => nil, 'SAMPLE' => nil, 'ALT' => nil }
  REFVCFHASH =  {
                  "CHROM" => nil,
                  "POS" => nil,
                  "ID" => nil,
                  "REF" => nil,
                  "ALT" => nil,
                  "QUAL" => nil,
                  "FILTER" => nil,
                  "INFO" => nil,
                  "FORMAT" => nil
                }
  # These keys are added by us during record parse/print and have no cooresponding columns in the actual data line
  IGNORE_KEYS =
  {
    'snpType'     => true,
    'indelLength' => true,
    'sampleSpecificGT' => true,  # This is determined for each sample column, else wrong Ins/Del calc and wrong "ALT" allele will be reported when there are many many different genotypes for this SNP seen amongst the samples
    'genoTypeSummary' => true
  }


  attr_accessor :vcfIdxHash     # Hash for storing index of each column item
  attr_accessor :vcfDataHash    # Hash for storing data for each column
  attr_accessor :columnSize     # No of columns in the column header line
  attr_accessor :samples        # Samples, keyed by sample name in column header
  attr_accessor :frefHash       # Hash of the known frefs
  attr_accessor :skipUnknownChr # [Default=true] Should we just ignore chromosomes we don't know about?

  # [+filePath+] full path to vcf file (file needs to be uncompressed)
  # [+returns+] true or false (true if valid, false if invalid)
  def self.validate(filePath)
    cmd = "module load vcftools; cat #{filePath} | vcf-to-tab > /dev/null 2> #{filePath}.vcf-to-tab.err"
    $stderr.debugPuts(__FILE__, __method__, "COMMAND", "LAUNCHING COMMAND: #{cmd}")
    `#{cmd}`
    return ( $?.dup.exitstatus == 0 ? true : false)
  end

  # Constructor
  # [+colHeaderLine+]
  # [+fileHeaderLine+] optional
  # [+frefHash+] hash for storing entrypoints
  # [+skipUnknownChr+] [Boolean; default=true] Should we just ignore chromosomes we don't know about?
  # [+returns+] nil
  def initialize(colHeaderLine, fileHeaderLine=nil, frefHash={}, skipUnknownChr=true)
    @skipUnknownChr = skipUnknownChr
    raise ArgumentError, "No Column Header provided.", caller if(colHeaderLine.nil? or colHeaderLine.empty?)
    raise ArgumentError, "Column header line does not start with a '#'" if(colHeaderLine !~ /^#/)
    # Initialize idx and data hashes
    @vcfIdxHash = {}
    @vcfDataHash = {}
    @samples = []
    @columnSize = nil
    @samplesHash = {}
    @frefHash = frefHash
    initVCFHashes(colHeaderLine)
    # Here are some reusable data structures we use to hold key bits of data as we parse the lines (e.g. we don't want to create 100+ million arrays unnecessarily). Obviously they need clearing between lines, so they are ready to be reused.
    @alleleNums = [ nil, nil ]
    @lffSnpTypes = [ 'UNK', 'UNK' ]
  end
  
  # Class method to parse Meta Info lines in a vcf file
  # @param [String] line
  # @param [Hash] metaInfoHash: An already initialized hash
  # @return [Hash] returns updated metaInfoHash
  def self.parseMetaInfoLines(line, metaInfoHash)
    fieldDefLine = line.gsub(/^##/, "")
    fieldEls = fieldDefLine.split("=")
    fieldName = fieldEls[0].strip
    fieldValue = fieldEls[1..fieldEls.size-1].join("=")
    fieldValue.strip!
    if(RESERVED_METAINFO_FIELDS.key?(fieldName))
      if(metaInfoHash.key?(fieldName))
        metaInfoHash[fieldName] << fieldValue
      else
        metaInfoHash[fieldName] = [fieldValue]
      end
    else
      metaInfoHash[fieldName] = fieldValue  
    end      
    return metaInfoHash    
  end

  # Initializes vcf idx and data hash structures
  # [+colHeaderLine+]
  # [+returns+] nil
  def initVCFHashes(colHeaderLine)
    begin
      colHeaderLine = colHeaderLine.dup
      colHeaderLine.strip!
      colHeaderLine.gsub!("#", "")
      columns = colHeaderLine.split(/\t/)
      columns.size.times { |columnIdx|
        @vcfIdxHash[columns[columnIdx]] = columnIdx
        @vcfDataHash[columns[columnIdx]] = nil
        @samples.push(columns[columnIdx]) if(!REFVCFHASH.has_key?(columns[columnIdx]))
        @samplesHash[columns[columnIdx]] = nil
      }
      @columnSize = columns.size
      # Normalize key and contents of @frefHash
      if(@frefHash)
        normFrefHash = {}
        @frefHash.each_key { |key|
          # Normalize the key so we can try to deal with folks who use "Chr1" when
          # database has "chr1" (HGSC...sometimes) and such
          normChrom = key.downcase
          # Keep the proper chrom name and the length under this normalized key
          normFrefHash[normChrom] = { :chrom => key, :length => @frefHash[key].to_i }
        }
        @frefHash = normFrefHash
      end
    rescue => err
      raise err
    end
  end

  def deleteNonCoreKeys()
    @vcfDataHash.each_key { |key|
      @vcfDataHash.delete(key) if(!REFVCFHASH.key?(key) and !@samplesHash.key?(key))
    }
  end

  def cleanObj()
    @vcfDataHash.clear
    @vcfIdxHash.clear
    @samples.clear
  end

  # Parses vcf line into @vcfDataHash
  # [+line+]
  # [+returns+] true if parsed line, false if not (e.g. if skipped the record for some reason, etc)
  def parseLine(line)
    retVal = false
    # First, cannot safely parse the line without clearing things we've saved from previous lines (bad, evil practice, sloppy)
    self.deleteNonCoreKeys()
    # Similarly, clear out the VALUEs in @vcfDataHash which we've seen carry over from line to line inappropriately in some cases (again, sloppy design; so we do this to be sure of what we're dealing with w.r.t. object state as we go from line to line. It's even worse if making LFF because that process used to change the object state just to make some LFF string!!!)
    @vcfDataHash.each_key { |key| @vcfDataHash[key] = nil }
    # Here are some reusable data structures we use to hold key bits of data as we parse the lines (e.g. we don't want to create 100+ million arrays unnecessarily). Obviously they need clearing between lines, so they are ready to be reused.
    @alleleNums[0] = @alleleNums[1] = nil
    # Ok, now process the line of data
    begin
      line.strip!
      raise ArgumentError, "Line: #{line.inspect} is empty", caller if(line.empty?)
      raise ArgumentError, "Line: #{line.inspect} starts with a '#' sign.", caller if(line =~ /^#/)
      data = line.split(/\t/)
      raise ArgumentError, "Line: #{line.inspect} has incorrect number of columns: #{data.size}. Number of Columns in column Header: #{@columnSize.inspect}" if(@columnSize != data.size)
      chromColIdx, formatColIdx = @vcfIdxHash['CHROM'], @vcfIdxHash['FORMAT']  # For speed, to prevent 100+ million array accesses to find the same 2 indices over and over...
      # Once we encounter the format column for this data record, we'll keep it hear for reference as each sample column value is processed
      format = {}
      formatIdxHash = {}
      # Can be set to true while considering the chromosome. e.g. skip unknown chromosomes.
      skipRec = false
      # First, let's try visit all the core VCF keys we should have in our record. Before looking at sample columns and such.
      # - extract needed info first
      REFVCFHASH.each_key { |key|
        value = data[@vcfIdxHash[key]]
        if(value) # then we have this core column (should...it's core...)
            # Make sure the entrypoint/chr is a valid one and the POS is not beyond the length of the chromosome
            if(key == 'CHROM')
              # Normalize chromosome names so can use safely as a key (e.g. to handle chr1 vs Chr1 and such)
              recChromName = value.downcase
              unless(@frefHash.empty?) # For AtlasSNP tools @frefHash will be empty, so do not do this check & chrom processing
                if(@frefHash.key?(recChromName))
                  # Update this chrom name in the record to match "official" name we have from database in @frefHash
                  value = @frefHash[recChromName][:chrom]
                else # No such chromosome
                  if(@skipUnknownChr) # Skip this, unless user indicates they WANT an error when unknown chromosome seen.
                    skipRec = true
                  else
                    skipRec = false
                    raise "Chromoosome/Entrypoint #{value.inspect} on from VCF record is not a known chromosome in the target database."
                  end
                end
              end
            elsif(key == 'POS')
              value = value.to_i
              # First, ensure can also get at valid chromosome name for this record
              # - Normalize chromosome names so can use as a key
              recChromName = data[@vcfIdxHash['CHROM']].downcase
              unless(@frefHash.empty?) # For AtlasSNP tools @frefHash will be empty, so do not do this check & chrom processing
                if(@frefHash.key?(recChromName))
                  chromLength = @frefHash[recChromName][:length]
                  raise "POS: #{value.inspect} beyond the length of chromosome #{data[chromColIdx].inspect}, which is #{chromLength}" if(value.to_i > chromLength)
                else # No such chromosome
                  if(@skipUnknownChr) # Skip this, unless user indicates they WANT an error when unknown chromosome seen.
                    skipRec = true
                  else
                    skipRec = false
                      raise "Chromoosome/Entrypoint #{value.inspect} on from VCF record is not a known chromosome in the target database."
                  end
                end
              end
            elsif(key == 'ALT')
              # We need the ARRAY of possible alt alleles, otherwise will get wrong calculations and bad names when there are multiple samples:
              value = value.split(',')
              value.map! { |xx| xx.strip }
            elsif(key == 'FORMAT')
              # If seeing FORMAT column, save the format fields for use when we hit sample data columns
              # - this way we don't split() the format field for every sample column, only when we find the FORMAT column for this data record
              format = data[formatColIdx].split(":")
              formatIdxHash = {}
              # Make index for FORMAT (Cannot assume thats its the same throughout the file)
              format.size.times { |idx|
                formatIdxHash[format[idx]] = idx
              }
            else
              # Do nothing
            end
            # Store value (modified/parsed by above code or not)
            @vcfDataHash[key] = value unless(skipRec)
          end
      }
      # Now process the non-core (non-expected/standard) columns, which should contain sample-specific SNP info
      unless(skipRec)
        # Now we have required info (in theory). Focus on remaining colums, which should contain sample SNP info
        @vcfDataHash.each_key { |key|
          unless(IGNORE_KEYS.key?(key) or REFVCFHASH.key?(key))
            value = data[@vcfIdxHash[key]]  # Value in the line
            # Some VCF (e.g. from HGSC) may have "." or "" in 1+ sample columns for some SNP record lines).
            # Since there is no data to show for such Sample-SNPs, they will be skipped (no data for sample at this SNP, no LFF line output; makes sense)
            if(value)
              value.strip!
              unless(value.empty? or value == '.') # the value string for this column is not nil, empty string, or just '.'
                sampleInfo = value.split(":")
                raise "Either no FORMAT column describing the value elements, or the number of FORMAT elements not equal to number of elements declared in VCF header for sample column #{key.inspect}. Column contains data string #{value.inspect} which has these value elements: #{sampleInfo.inspect} elements while the FORMAT information from the header indicates sample columns will have these elements: #{format.inspect} elements." if(sampleInfo.size != format.size)
                sampleInfo.map! { |xx| xx.strip }
                # Store the sample-specific data in hash keyed by sample name (i.e. key):
                vcfDataRec = @vcfDataHash[key] = {} # Going to add a hash-based record as a result of parsing
                # Initialize the hash-based records to have the string values for each field as-is
                formatIdxHash.each_key { |formatItem|
                  vcfDataRec[formatItem] = sampleInfo[formatIdxHash[formatItem]]
                }
                # Check GT. We need the sample-specific allele TUPLE.
                # - default in case we're missing things or stuff is messed up in the VCF
                vcfDataRec['genoType'] = [ 'UNK', 'UNK' ]
                vcfDataRec['genoTypeSummary'] = 'UNK/UNK'
                # - Get the value of the GT field, it has the sample-specific allele number in it
                gtValue = sampleInfo[formatIdxHash['GT']]
                if(gtValue)
                  if(gtValue =~ /^(\d+|\.)\/(\d+|\.)$/)  # then have GT field
                    @alleleNums[0], @alleleNums[1] = $1.to_i, $2.to_i  # NOTE: ".", used for ref allele sometimes, will convert to 0 correctly
                    vcfDataRec['genoTypeSummary'] = "#{@alleleNums[0] == 0 ? 'REF' : 'ALT'}/#{@alleleNums[1] == 0 ? 'REF' : 'ALT'}"
                    # - figure out 1st and 2nd allele
                    @alleleNums.each_index { |ii|
                      alleleNum = @alleleNums[ii]
                      if(alleleNum == 0 and @vcfDataHash['REF'])  # REF is always allele number 0
                        vcfDataRec['genoType'][ii] = @vcfDataHash['REF']
                      elsif(alleleNum != 0 and @vcfDataHash['ALT']) # Then our allele is not 0 and we have ALT(s) to consider
                        altIdx = (alleleNum - 1)
                        # put correct allele str in 'genotype' TUPLE if we can:
                        vcfDataRec['genoType'][ii] = @vcfDataHash['ALT'][altIdx] if(@vcfDataHash['ALT'][altIdx])
                      end
                    }
                  end
                end
                # Try to determine a score
                # - try to use DP field if FORMAT field indicates it is there:
                if(formatIdxHash.key?('DP'))
                  dpValue = sampleInfo[formatIdxHash['DP']] = sampleInfo[formatIdxHash['DP']].to_i
                  # - try to involve VR field if FORMAT field indicates it is there:
                  if(formatIdxHash.key?('VR') and dpValue != 0)
                    vcfDataRec['score'] = (sampleInfo[formatIdxHash['VR']].to_i / dpValue.to_i)
                  else # just use DP itself
                    vcfDataRec['score'] = dpValue
                  end
                elsif(@vcfDataHash.key?('QUAL')) # fall back to QUAL
                  vcfDataRec['score'] = ( @vcfDataHash['QUAL'] == '.' ? 0 : @vcfDataHash['QUAL'] )
                else # nothing reasonable to use as score? set to 0
                  vcfDataRec['score'] = 0
                end
                # We have parsed the line.
                retVal = true
              end # unless(value.empty? or value == '.')
            end # if(value)
          end # unless(IGNORE_KEYS.key?(key) or REFVCFHASH.key?(key))
        }
      end # unless(skipRec)
    rescue => err
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error: #{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}\nDebug Info: @vcfDataHash:\n\n#{@vcfDataHash.inspect}\n\n")
      raise "Error Message:\n    #{err}\nWhen Processing This Line:\n  #{line.inspect}\n"
    end
    return retVal
  end

  def makeLffName(sample, nameIncludesPos=true)
    # Default is a nil gname, which means we can't figure out a suitable name. Worthy of warning/log info, but using code will just move onto next record
    gname = nil
    pos = @vcfDataHash['POS']
    chr = @vcfDataHash['CHROM']
    # Known allele info for this SNP (in general)
    refAllele = @vcfDataHash['REF'].dup
    maxAlleleLen = refAllele.size
    # - truncate if ref allele string too long for use in gname
    refAllele = "#{refAllele.slice!(0, 9)}..." if(refAllele.size > 12)
    altAlleles = @vcfDataHash['ALT'] # ARRAY of alt alleles seen amongst the samples (or which are known a priori)
    # This particular sample info:
    anyIndels = false
    sampleData = @vcfDataHash[sample]
    if(sampleData and !sampleData.nil?)
      snpLength = nil
      # Get genotype TUPLE for this particular sample
      gtArray = sampleData['genoType']
      gtSummaryArray = sampleData['genoTypeSummary'] # already has REF/REF or ALT/ALT or REF/ALT
      # For each allele, determine it is an substitution or indel
      # - and accumulate needed name info and whatnot
      # - we'll do this in some reusable object variables set assig for this. They need to be reset after each LFF name we make of course.
      @lffSnpTypes[0] = @lffSnpTypes[1] = 'UNK'
      gtArray.each_index { |ii|
        allele = gtArray[ii].dup
        maxAlleleLen = allele.size if(allele.size > maxAlleleLen)
        isIndel = isIndel?(allele)
        # isIndel?() also has some side-effects (ugh), populates some more @vcfDatahash entries (like 'indelLength' and 'snpType')
        snpLength = @vcfDataHash['indelLength'] # Also set for substitutions
        if(isIndel)
          @lffSnpTypes[ii] = (@vcfDataHash['snpType'] == 'insertion' ? 'Ins' : 'Del')
          @lffSnpTypes[ii] += ":#{snpLength}bp"
        else # substitution (but maybe multi nucleotide, be careful)
          # - truncate if sample-specific allele string too long for use in gname
          if(allele.size > 12)
            @lffSnpTypes[ii] = "#{allele.slice!(0, 9)}..."
          else
            @lffSnpTypes[ii] = allele
          end
        end
      }
      # Build gname
      gname = "#{gtSummaryArray} [#{@lffSnpTypes.join('/')}]"
      # Add position to name?
      endPos = @lffStop = (pos + maxAlleleLen - 1)
      if(nameIncludesPos)
        gname << " #{chr}:#{pos}-#{endPos}"
      end
    else
      gname = nil
    end
    return gname
  end

  # Creates Lff record based on the current data in @vcfDataHash contents
  # Will produce one lff record per sample
  # [+className+]
  # [+lffType] If empty, will use sample as type
  # [+lffSubType+]
  # [+returns+] lffLine
  def makeLFF(className, lffType, lffSubType, nameIncludesPos=true)
    lffLine = ''
    gname = nil
    recordFullSampleName = !(lffType.nil? or lffType.empty?)
    begin
      pos = @vcfDataHash['POS'].to_i
      chr = @vcfDataHash['CHROM']
      @samples.each { |sample|
        # Some VCF (e.g. from HGSC) may have "." or "" in 1+ sample columns for some SNP record lines).
        # Since there is no data to show for such Sample-SNPs, they will be skipped (no data for sample at this SNP, no LFF line output; makes sense)
        sampleVcfDataRec = @vcfDataHash[sample]
        if(sampleVcfDataRec)
          gname = makeLffName(sample, nameIncludesPos) # now have 'indelLength', 'snpType', @lffSnpTypes, and @lffStop set as a result
          if(gname.nil?) # Can't make sensible gname...bogus VCF or other problem. Log and move on.
            $stderr.puts "WARNING: cannot make LFF gname from parse VCF record data for sample #{sample.inspect}. Needs fixing. Info:\n@vcfDataHash:\n#{@vcfDataHash.inspect}\n\n"
          else
            # Come up reasonable lffType to use if not given
            if(lffType.nil? or lffType !~ /\S/) # no lffType given, derive from sample name
              # Does the full Sample name actually look like a file path?
              # We've seen that from HGSC. Makes very bad lffType!
              # - define "looks like file path" to be: has *more* than one / separated with letters
              # - idea is to prevent non-file name samples to make it through unmolested (e.g. male/id=17567658)
              if(sample =~ %r{/[^/]+/[^/]+}) # then /foo/bar or /foo/bar/boo/moo/ or foo/bar/boo or ./foo/bar etc. Looks like file path. foo/bar or //bar insufficent to trigger "looks like file path"
                lffType = File.basename(sample)
                recordFullSampleName = true
              else # not file like [enough], use as-is
                lffType = sample
              end
            end
            lffLine << "#{className}\t#{gname}\t#{lffType}\t#{lffSubType}\t#{chr}\t#{pos}\t#{@lffStop}\t+\t0\t#{sampleVcfDataRec['score']}\t.\t.\t"
            lffLine << "sampleName=#{sample.gsub(/;/, "|")};" if(recordFullSampleName) # Save sample name as AVP
            @vcfDataHash.each_key { |key|
              if(key != 'CHROM' and key != 'POS')
                if(key == sample) # the sample column...gather this sample's specific info
                  sampleVcfDataRec.each_key { |formatItem|
                    formatValue = sampleVcfDataRec[formatItem]
                    if(formatItem != "score")
                      if(formatItem == 'genoType')
                        formatValue = formatValue.join("/")
                      end
                      lffLine << "#{formatItem}=#{formatValue.to_s.gsub(/;/, "|")};"
                    end
                  }
                elsif(key != sample and @samples.index(key).nil?) # process other keys unless the key is name of OTHER samples, else they end up in the LFF all ugly
                  value = @vcfDataHash[key]
                  if(key == 'FILTER')
                    value.gsub!(";", ",")
                  elsif(key == 'ALT')
                    value = value.join(',')
                  end
                  lffLine << "#{key}=#{value.to_s.gsub(/;/, "|")}; "
                end
              end
            }
            lffLine << " \n"
            lffType = nil
          end
        end
      }
    rescue => err
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error: #{err}\n\nBacktrace: #{err.backtrace.join("\n")}")
      raise "Error:\n#{err}"
    end
    return lffLine
  end

  # [+returns+] true or false
  def isIndel?(allele)
    isIndel = false
    refSize = @vcfDataHash['REF'].size
    alleleSize = allele.size
    if(refSize == alleleSize) # although could be > 1 bp substitution
      @vcfDataHash['snpType'] = 'substitution'
      @vcfDataHash['indelLength'] = alleleSize
    elsif(refSize > alleleSize)
      @vcfDataHash['snpType'] = 'deletion'
      isIndel = true
      @vcfDataHash['indelLength'] = (refSize - alleleSize)
    else # (refSize < alleleSize)
      isIndel = true
      @vcfDataHash['snpType'] = 'insertion'
      @vcfDataHash['indelLength'] = (alleleSize - refSize)
    end
    return isIndel
  end
end
end ; end
