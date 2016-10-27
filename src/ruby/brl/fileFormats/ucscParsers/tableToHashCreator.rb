#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC table to equivalent LFF version

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/util/textFileUtil'
require 'brl/fileFormats/ucscParsers/ucscTables'



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
module BRL ; module FileFormats; module UcscParsers
      

class TableToHashCreator

  
  def self.valueToNameHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read NameToValue file
    reader = BRL::Util::TextReader.new(fileName)
    begin
      reader.each { |line|
          next if(line !~ /\S/ or line =~ /^\s*#/)
          rg = NameToValueTable.new(line)           
          if(retVal.has_key?(rg.value))
            retVal[rg.value][rg.name] = nil if(!rg.name.nil? or !rg.nameHash.empty?)
          else
            if(!rg.name.nil? or !rg.nameHash.empty?)
              retVal[rg.value] = rg.nameHash
            else
              retVal[rg.value] = {}
            end
          end
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
 
   def self.valueToNameRawHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read NameToValue file
    reader = BRL::Util::TextReader.new(fileName)
    begin
      reader.each { |line|
          next if(line !~ /\S/ or line =~ /^\s*#/)
          rg = NameToValueRawTable.new(line)           
          if(retVal.has_key?(rg.value))
            retVal[rg.value][rg.name] = nil if(!rg.name.nil? or !rg.nameHash.empty?)
          else
            if(!rg.name.nil? or !rg.nameHash.empty?)
              retVal[rg.value] = rg.nameHash
            else
              retVal[rg.value] = {}
            end
          end
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
 
 
  
  def self.nameToValueHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read NameToValue file
    reader = BRL::Util::TextReader.new(fileName)
    begin
      reader.each { |line|
          next if(line !~ /\S/ or line =~ /^\s*#/)
          rg = NameToValueTable.new(line)           
          if(retVal.has_key?(rg.name))
            retVal[rg.name][rg.value] = nil if(!rg.value.nil? or !rg.valueHash.empty?)
          else
            if(!rg.value.nil? or !rg.valueHash.empty?)
              retVal[rg.name] = rg.valueHash
            else
              retVal[rg.name] = {}
            end
          end
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
 
   def self.nameToValueRawHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read NameToValue file
    reader = BRL::Util::TextReader.new(fileName)
    begin
      reader.each { |line|
          next if(line !~ /\S/ or line =~ /^\s*#/)
          rg = NameToValueRawTable.new(line)           
          if(retVal.has_key?(rg.name))
            retVal[rg.name][rg.value] = nil if(!rg.value.nil? or !rg.valueHash.empty?)
          else
            if(!rg.value.nil? or !rg.valueHash.empty?)
              retVal[rg.name] = rg.valueHash
            else
              retVal[rg.name] = {}
            end
          end
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
  
   
  def self.ccdsToKnownGeneIdHash(ccdsKgMapFileName)
    retVal = {}
    return retVal unless( !ccdsKgMapFileName.nil? )
    # Read ccdsKgMapFile file
    reader = BRL::Util::TextReader.new(ccdsKgMapFileName)
    line = nil
    begin
        reader.each { |line|
            next if(line !~ /\S/ or line =~ /^\s*#/)
            rg = CcdsKgMapTable.new(line)
            if(retVal.has_key?(rg.ccdsId))
              retVal[rg.ccdsId][rg.geneId] = nil if(!rg.geneId.nil? or !rg.geneId.empty?)
            else
              if(!rg.geneId.nil? or !rg.geneId.empty?)
                retVal[rg.ccdsId] = rg.geneIdHash
              else
                retVal[rg.ccdsId] = {}
              end
            end
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


  def self.ccdsIdToKgMapTableHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read ccdsKgMapFile file
    reader = BRL::Util::TextReader.new(fileName)
    line = nil
    begin
        reader.each { |line|
            next if(line !~ /\S/ or line =~ /^\s*#/)
            rg = CcdsKgMapTable.new(line)      
            if(retVal.has_key?(rg.ccdsId))
              retVal["#{retVal[rg.ccdsId].ccdsId}_#{retVal[rg.ccdsId].chrom}"] = retVal[rg.ccdsId]
              retVal.delete(rg.ccdsId)
              rg.ccdsId = "#{rg.ccdsId}_#{rg.chrom}"
            end
            
            if(retVal.has_key?(rg.ccdsId))
              retVal[rg.ccdsId].geneIdHash[rg.geneId] = nil
            else
              retVal[rg.ccdsId] = rg
            end            
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


  def self.nucAcc2RefFlatTable(fileName)
    retVal = {}
    seenNames = Hash.new {|hh,kk| hh[kk] = 0}
    return retVal unless( !fileName.nil? )
    # Read refFlat file
    reader = BRL::Util::TextReader.new(fileName)
    line = nil
    begin
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*#/)
          rg = RefFlatTable.new(line)
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

  def self.hugoName2RefFlatTable(fileName)
    retVal = {}
    seenNames = Hash.new {|hh,kk| hh[kk] = 0}
    return retVal unless( !fileName.nil? )
    # Read refFlat file
    reader = BRL::Util::TextReader.new(fileName)
    line = nil
    begin
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*#/)
          rg = RefFlatTable.new(line)
          seenNames[rg.geneName] += 1
          rg.geneName = "#{rg.geneName}.#{seenNames[rg.geneName]}" if(seenNames[rg.geneName] > 1)
          retVal[rg.geneName] = rg 
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

  def self.returnVPEntriesForHashOfHashes(hashName, key, vpName)
    swissProtAcc = nil
#   puts key.inspect
#    puts hashName.inspect
    swissprotHash = hashName[key]
#    if(key == :ENST00000350498)
#      puts swissprotHash.inspect
#    end
    if(!swissprotHash.nil? and swissprotHash.size > 0 )
      swissprotArray = swissprotHash.keys
      swissProtAcc = "#{vpName}=#{swissprotArray.join(",")}; "
    end
    return swissProtAcc
  end

  def self.knownGeneIdToSwissProtId(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )

    reader = BRL::Util::TextReader.new(fileName)
    line = nil
    begin
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*#/)
        rg = KnownGeneTable.new(line)
        if(retVal.has_key?(rg.name))
          retVal[rg.name][rg.proteinId] = nil
        else
          if(!rg.proteinId.nil?)
            retVal[rg.name] = rg.proteinIdHash
          else
            retVal[rg.name] = {}
          end
        end
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


  def self.ucscTableFromBrowserToLff(fileName, lffFileName, clName, type, subtype)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read amplicon file
    reader = BRL::Util::TextReader.new(fileName)
    fileWriter = BRL::Util::TextWriter.new(lffFileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = UCSCBrowserTable.new(line, clName, type, subtype)

        if(rg.lffLines.nil?)
          $stderr.puts "Line is not valid skipped #{line}"
          lineCounter = lineCounter + 1
          next
        else
          rg.lffLines.each{|lff|
            fileWriter.puts lff
            }
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
      fileWriter.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
  end








  def self.knownGeneIdToKnownGeneTableHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read ccdsGene file
    reader = BRL::Util::TextReader.new(fileName)
    line = nil
    begin
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*#/)
        rg = KnownGeneTable.new(line)
        if(retVal.has_key?(rg.name))
          $stderr.puts "knownGene #{rg.name} is present multiple times line skipped"
        else
          retVal[rg.name] = rg 
        end
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

  def self.ccdsToccdsGeneTableHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read ccdsGene file
    reader = BRL::Util::TextReader.new(fileName)
    line = nil
    begin
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*#/)
        rg = CcdsGeneTable.new(line)
        if(retVal.has_key?(rg.name))
          retVal["#{retVal[rg.name].name}_#{retVal[rg.name].chrom}"] = retVal[rg.name]
          retVal.delete(rg.name)
          rg.name = "#{rg.name}_#{rg.chrom}"
        end
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


  def self.createccdsIdToccdsInfoHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    reader = BRL::Util::TextReader.new(fileName)
    begin
        reader.each { |line|
            next if(line !~ /\S/ or line =~ /^\s*#/)
            rg = CcdsInfoTable.new(line)
            if(retVal.has_key?(rg.ccds))
              retVal[rg.ccds].mrnaAccHash[rg.mrnaAcc] = rg.srcDb
            else
              retVal[rg.ccds] = rg 
            end

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

  def self.ccdsToLocusLinkHash(ccdsKgMapFileName, knownToLocusLinkFileName)
    ccdsTolocusLinkHash = Hash.new {|hh,kk| hh[kk] = nil}

    ccdsToKnownGeneId = TableToHashCreator.ccdsToKnownGeneIdHash(ccdsKgMapFileName)
    knownToLocusLink = TableToHashCreator.nameToValueHash(knownToLocusLinkFileName)
    
    ccdsToKnownGeneId.each_key {|ccdsId|
      tempHash = ccdsToKnownGeneId[ccdsId]
      tempHash.each_key{|knownGeneId|
        if(!knownToLocusLink[knownGeneId].nil?)
          ccdsTolocusLinkHash[ccdsId] = knownToLocusLink[knownGeneId]
      end
      }
    }
    
    return ccdsTolocusLinkHash
  end


  def self.ccdsToSwissProtHash(ccdsKgMapFileName, knownGeneFileName)
    ccdsToSwissProtHash = Hash.new {|hh,kk| hh[kk] = nil}
    ccdsToKnownGeneId = TableToHashCreator.ccdsToKnownGeneIdHash(ccdsKgMapFileName) 
    knownToSwissProt = TableToHashCreator.knownGeneIdToSwissProtId(knownGeneFileName)
    
    ccdsToKnownGeneId.each_key {|ccdsId|
      tempHash = ccdsToKnownGeneId[ccdsId]
      tempHash.each_key{|knownGeneId|
        if(!knownToSwissProt[knownGeneId].nil?)
          ccdsToSwissProtHash[ccdsId] = knownToSwissProt[knownGeneId]
      end
      }
    }
    
    return ccdsToSwissProtHash

  end

    def self.createEnsembleToHugoHash(ensemblToKnownHash, knownToRefSeqHash)
      ensembleToHugoHash = Hash.new {|hh,kk| hh[kk] = nil}
      ensembleToKnownHash.each_key{|ensemblAcc|
      ensembleToHugoHash[ensemblAcc] = knownToRefSeqHash[ensembleToKnownHash[ensemblAcc]] if(!ensembleToKnownHash[ensemblAcc].nil? and !knownToRefSeqHash[ensembleToKnownHash[ensemblAcc]].nil?)      
      }    
    return ensembleToHugoHash
  end

  def self.createEnsemblToHugoNameHash(knownToRefSeqFileName, refFlatFileName, knownToEnsemblFileName)
    knownToHugoName = Hash.new {|hh,kk| hh[kk] = nil}
    ensemblToHugoName = Hash.new {|hh,kk| hh[kk] = nil}


    knownToNuc = TableToHashCreator.nameToValueHash(knownToRefSeqFileName)
    nucAccToHugo = TableToHashCreator.createNucAccToHugoNameHash(refFlatFileName)
    ensemblToKnown = TableToHashCreator.valueToNameHash(knownToEnsemblFileName)

    
    knownToNuc.each_key {|knownGeneId|
      tempHash = knownToNuc[knownGeneId]
      tempHash.each_key{|nucAcc|
        if(!nucAccToHugo[nucAcc].nil?)
          knownToHugoName[knownGeneId] = nucAccToHugo[nucAcc]
      end
      }
    }

    ensemblToKnown.each_key {|ensembl|
      tempHash = ensemblToKnown[ensembl]
      tempHash.each_key{|knownGeneId|
        if(!knownToHugoName[knownGeneId].nil?)
          ensemblToHugoName[ensembl] = knownToHugoName[knownGeneId]
        end
      }
    }

  return ensemblToHugoName
    
  end

  def self.createKnownToHugoNameHash(knownToRefSeqFileName, refFlatFileName)
    knownToHugoName = Hash.new {|hh,kk| hh[kk] = nil}
    knownToNuc = TableToHashCreator.nameToValueHash(knownToRefSeqFileName)
    nucAccToHugo = TableToHashCreator.createNucAccToHugoNameHash(refFlatFileName)


    
    knownToNuc.each_key {|knownGeneId|
      tempHash = knownToNuc[knownGeneId]
      tempHash.each_key{|nucAcc|
        if(!nucAccToHugo[nucAcc].nil?)
          knownToHugoName[knownGeneId] = nucAccToHugo[nucAcc]
      end
      }
    }
    
    return knownToHugoName
    
  end

  def self.ccdsToHugoNameHash(ccdsInfoFileName, knownToRefSeqFileName, refFlatFileName, knownToEnsemblFileName)
    test = "H"
    ccdsIdToHugoNameHash = Hash.new {|hh,kk| hh[kk] = nil}   
    ccdsInfo = TableToHashCreator.createccdsIdToccdsInfoHash(ccdsInfoFileName)
   ensemblToHugoName = TableToHashCreator.createEnsemblToHugoNameHash(knownToRefSeqFileName, refFlatFileName, knownToEnsemblFileName)
    nucAccToHugoName = TableToHashCreator.createNucAccToHugoNameHash(refFlatFileName)
    ccdsInfo.each_key {|ccdsId|
      tempMRNAHash = ccdsInfo[ccdsId].mrnaAccHash
      tempMRNAHash.each{|mRNA, src|
        srcDb = "#{src}"
        if(srcDb[0] == test[0])
          ccdsHugoNames = ensemblToHugoName[mRNA]
        else
          ccdsHugoNames = nucAccToHugoName[mRNA]
        end

        if(ccdsIdToHugoNameHash.has_key?(ccdsId))
          ccdsIdToHugoNameHash[ccdsId].merge!(ccdsHugoNames) if(!ccdsHugoNames.nil? and !ccdsIdToHugoNameHash[ccdsId].nil?)
        else   
            ccdsIdToHugoNameHash[ccdsId] = ccdsHugoNames if(!ccdsHugoNames.nil?)
        end

      } 
    }
    
    return ccdsIdToHugoNameHash
    
  end



  def self.createNucAccToHugoNameHash(refFlatFileName)
    retVal = {}
    return retVal unless( !refFlatFileName.nil? )
    # Read refFlat file
    reader = BRL::Util::TextReader.new(refFlatFileName)
    line = nil
    begin
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*#/)
        rg = RefFlatTable.new(line)
        if(retVal.has_key?(rg.name))
          retVal[rg.name][rg.geneName] = nil if(!rg.geneName.nil? )
        else
          if(!rg.geneName.nil? or !rg.geneNameHash.empty?)
            retVal[rg.name] = rg.geneNameHash
          else
            retVal[rg.name] = {}
          end
        end
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

  def self.ccdsToNucAccHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read refStatus file
    reader = BRL::Util::TextReader.new(fileName)
    begin
        reader.each { |line|
            next if(line !~ /\S/ or line =~ /^\s*#/)
            rg = CcdsInfoTable.new(line)
            if(retVal.has_key?(rg.ccds))
              retVal[rg.ccds][rg.mrnaAcc] = rg.srcDb if(!rg.mrnaAcc.nil? or !rg.mrnaAccHash.empty?)
            else
              if(!rg.mrnaAcc.nil? or !rg.mrnaAccHash.empty?)
                retVal[rg.ccds] = rg.mrnaAccHash
              else
                retVal[rg.ccds] = {}
              end
            end
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

  def self.ccdsToProtAccHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read refStatus file
    reader = BRL::Util::TextReader.new(fileName)
    begin
        reader.each { |line|
            next if(line !~ /\S/ or line =~ /^\s*#/)
            rg = CcdsInfoTable.new(line)
            if(retVal.has_key?(rg.ccds))
              retVal[rg.ccds][rg.protAcc] = rg.srcDb if(!rg.protAcc.nil? or !rg.protAccHash.empty?)
            else
              if(!rg.protAcc.nil? or !rg.protAccHash.empty?)
                retVal[rg.ccds] = rg.protAccHash
              else
                retVal[rg.ccds] = {}
              end
            end
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



  def self.ccdsToHugoNameHashFromOtherHashes(fileName, refNameToHugoHash, ensemblToHugoHash)
    retVal = {}
    return retVal unless( !fileName.nil? )
    reader = BRL::Util::TextReader.new(fileName)
    test = "H"
    begin
        reader.each { |line|
            next if(line !~ /\S/ or line =~ /^\s*#/)
            ccdsToHugoNameHash = Hash.new {|hh,kk| hh[kk] = nil}
            rg = CcdsInfo.new(line)
              if(rg.srcDb[0] == test[0])
                ccdsHugoName = ensemblToHugoHash[rg.mrnaAcc]
              else
                ccdsHugoName = refNameToHugoHash[rg.mrnaAcc]
              end
            if(retVal.has_key?(rg.ccds))
                retVal[rg.ccds][ccdsHugoName] = nil if(!ccdsHugoName.nil?)
            else
                ccdsToHugoNameHash[ccdsHugoName] = nil if(!ccdsHugoName.nil?)
                retVal[rg.ccds] = ccdsToHugoNameHash  
            end
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



  def self.ensToEnsGeneTableHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read EnsGeneTable file
    reader = BRL::Util::TextReader.new(fileName)
    line = nil
    begin
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*#/)
        rg = EnsGeneTable.new(line)
        retVal[rg.name] = rg if(!retVal.has_key?(rg.name))
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

  def self.nucAccToCcdsHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read refStatus file
    reader = BRL::Util::TextReader.new(fileName)
    begin
        reader.each { |line|
            next if(line !~ /\S/ or line =~ /^\s*#/)
            rg = CcdsInfoTable.new(line)
            if(retVal.has_key?(rg.rawMrnaAcc))
              retVal[rg.rawMrnaAcc][rg.ccds] = rg.srcDb if(!rg.rawMrnaAcc.nil?)
            else
              tempRawMrnaHash = Hash.new {|hh,kk| hh[kk] = nil}
              tempRawMrnaHash[rg.ccds] = rg.srcDb if(!rg.rawMrnaAcc.nil?)
              retVal[rg.rawMrnaAcc] = tempRawMrnaHash
            end
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

  def self.nucAccToProtAcc(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read refStatus file
    reader = BRL::Util::TextReader.new(fileName)
    begin
        reader.each { |line|
            next if(line !~ /\S/ or line =~ /^\s*#/)
            rg = CcdsInfoTable.new(line)
            if(retVal.has_key?(rg.rawMrnaAcc))
              retVal[rg.rawMrnaAcc][rg.protAcc] = rg.srcDb if(!rg.rawMrnaAcc.nil?)
            else
              tempRawMrnaHash = Hash.new {|hh,kk| hh[kk] = nil}
              tempRawMrnaHash[rg.protAcc] = rg.srcDb if(!rg.rawMrnaAcc.nil?)
              retVal[rg.rawMrnaAcc] = tempRawMrnaHash
            end
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

  def self.ensemblToLocusLinkHash(knownToEnsemblFileName, knownToLocusLinkFileName)
    ensemblTolocus = Hash.new {|hh,kk| hh[kk] = nil}

    ensemblToKnownGeneId = TableToHashCreator.valueToNameHash(knownToEnsemblFileName)
#    puts "after the ensemblToKnownGeneId the size is #{ensemblToKnownGeneId.size}"
    knownToLocusLink = TableToHashCreator.nameToValueHash(knownToLocusLinkFileName)
#    puts "after the knownToLocusLink the size is #{knownToLocusLink.size}"    
    ensemblToKnownGeneId.each_key {|ensemblId|

      tempHash = ensemblToKnownGeneId[ensemblId]
      tempHash.each_key{|knownGeneId|
#        puts "the knownGeneId = #{knownGeneId.inspect} and the ensembleId = #{ensemblId.inspect}"
        if(!knownToLocusLink[knownGeneId].nil?)
          ensemblTolocus[ensemblId] = knownToLocusLink[knownGeneId]
      end
      }
    }
    
    return ensemblTolocus
  end

#ensembleGeneName
  def self.ensemblTranscriptToensembleGeneName(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )

    reader = BRL::Util::TextReader.new(fileName)
    line = nil
    begin
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*#/)
        rg = EnsGtpTable.new(line)
        
        if(retVal.has_key?(rg.transcript))
          retVal[rg.transcript][rg.gene] = nil if(!rg.gene.nil?)
        else
          if(!rg.gene.nil?)
            retVal[rg.transcript] = rg.geneHash
          else
            retVal[rg.transcript] = {}
          end
        end
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


  def self.ensemblTranscriptToensembleProteinName(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )

    reader = BRL::Util::TextReader.new(fileName)
    line = nil
    begin
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*#/)
        rg = EnsGtpTable.new(line)
        
        if(retVal.has_key?(rg.transcript))
          retVal[rg.transcript][rg.protein] = nil if(!rg.protein.nil?)
        else
          if(!rg.protein.nil?)
            retVal[rg.transcript] = rg.proteinHash
          else
            retVal[rg.transcript] = {}
          end
        end
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
  
end # class tableToHashCreator

end; end; end #namespace


    #ensemblToKnown = BRL::FileFormats::UcscParsers::TableToHashCreator.valueToNameHash(ARGV[0])
    #ensemblToKnown.each_key {|key|
    #  tempHash = ensemblToKnown[key]
    #  tempHash.each_key{|value|
    #    puts "#{key} and value #{value}"
    #  }
    #}
