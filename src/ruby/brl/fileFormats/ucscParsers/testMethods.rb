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
require 'brl/fileFormats/ucscParsers/ucscTables'
require 'brl/fileFormats/ucscParsers/tableToHashCreator'

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

class TestMethods

  def self.testValueToNameHash(optsHash)
    return nil unless( optsHash.key?('--knownToEnsemblFile') )
      # Read ccdsGene file
    fileName = optsHash['--knownToEnsemblFile']

    knownToensembl = TableToHashCreator.nameToValueHash(fileName)
      knownToensembl.each_key {|key|
      tempHash = knownToensembl[key]
      tempHash.each_key{|value|
        puts "#{key} and value #{value}"
      }
    }
    sleep(3)

    ensemblToKnown = TableToHashCreator.valueToNameHash(fileName)
    ensemblToKnown.each_key {|key|
      tempHash = ensemblToKnown[key]
      tempHash.each_key{|value|
        puts "#{key} and value #{value}"
      }
    }
  end
 
  def self.testCcdsIdToHugoName(optsHash)
     return nil unless( optsHash.key?('--ccdsInfoFile') )
      # Read ccdsGene file
    fileName = optsHash['--ccdsInfoFile']
    
    return nil unless( optsHash.key?('--knownToRefSeqFile') )
    fileName2 = optsHash['--knownToRefSeqFile']
    return nil unless( optsHash.key?('--refFlatFile') )
    fileName3 = optsHash['--refFlatFile']
    return nil unless( optsHash.key?('--knownToEnsemblFile') )
    fileName4 = optsHash['--knownToEnsemblFile']

    ccdsIdToHugoNameHash = TableToHashCreator.ccdsToHugoNameHash(fileName, fileName2, fileName3, fileName4)
    
#    ccdsIdToHugoNameHash.each_key {|ccdsId|
    ccdsIdToHugoNameHash.keys.sort.each {|ccdsId|
#     puts "#{ccdsId.inspect}  #{ccdsIdToHugoNameHash[ccdsId].inspect}"
       tempHash = ccdsIdToHugoNameHash[ccdsId]
        tempHash.each_key{|refSeqId|
      puts "#{ccdsId} and refSeqId #{refSeqId}"
      }
    }
    
  end
  


  def self.testCcdsKgMapTable(optsHash) 
     return nil unless( optsHash.key?('--ccdsKgMapFile') )
      # Read ccdsGene file
    fileName = optsHash['--ccdsKgMapFile']
    

    ccdkgMap = TableToHashCreator.ccdsToKnownGeneIdHash(fileName)
    ccdkgMap.each_key {|key|
    tempHash = ccdkgMap[key]
    tempHash.each_key{|knownGene|
      puts "#{key} and knownGene #{knownGene}"
      }
    } 
  end


  def self.testCCDSToMRAHash(optsHash)
    ccds2mRNAHash = Hash.new {|hh,kk| hh[kk] = nil}
     return nil unless( optsHash.key?('--ccdsInfoFile') )
      # Read ccdsGene file
    fileName = optsHash['--ccdsInfoFile']


    ccds2mRNAHash = TableToHashCreator.ccdsToNucAccHash(fileName)
    ccds2mRNAHash.each_key {|key|
    tempHash = ccds2mRNAHash[key]
    tempHash.each_key{|mrna|
      puts "#{key} and mRNA #{mrna}"
      }
    }
  end

  def self.testCCDSToProtHash(optsHash)
    ccds2protHash = Hash.new {|hh,kk| hh[kk] = nil}
    return nil unless( optsHash.key?('--ccdsInfoFile') )
      # Read ccdsGene file
    fileName = optsHash['--ccdsInfoFile']
    ccds2protHash = TableToHashCreator.ccdsToProtAccHash(fileName)
    ccds2protHash.each_key {|key|
    tempHash = ccds2protHash[key]
    tempHash.each_key{|prot|
      puts "#{key} and protein #{prot}"
      }
    }
    
  end


  def self.testCcdsToLocusLink(optsHash)
    ccdsTolocusLinkHash = Hash.new {|hh,kk| hh[kk] = nil}
     return nil unless( optsHash.key?('--ccdsKgMapFile') )
    fileName = optsHash['--ccdsKgMapFile']
    return nil unless( optsHash.key?('--knownToLocusLink') )
    fileName2 = optsHash['--knownToLocusLink']

    ccdsTolocusLinkHash = TableToHashCreator.ccdsToLocusLinkHash(fileName, fileName2)

      ccdsTolocusLinkHash.each_key {|key|
      tempHash = ccdsTolocusLinkHash[key]
        tempHash.each_key{|value|
          puts "#{key} and value #{value}"
        }
    }
  end
 
 
  def self.testCcdsToSwissProt(optsHash)
    puts "at the top of testCcdsToSwissprot"
    ccdsToSwissProtHash = Hash.new {|hh,kk| hh[kk] = nil}
    return nil unless( optsHash.key?('--ccdsKgMapFile') )
    fileName = optsHash['--ccdsKgMapFile']
    return nil unless( optsHash.key?('--knownGeneFile') )
    fileName2 = optsHash['--knownGeneFile']
       
    ccdsToSwissProtHash = TableToHashCreator.ccdsToSwissProtHash(fileName, fileName2)
    ccdsToSwissProtHash.each_key {|key|
      tempHash = ccdsToSwissProtHash[key]
        tempHash.each_key{|value|
          puts "#{key} and value #{value}"
        }
    }
  end

  def self.testEnsembleToKnownGeneHash(optsHash)
    return nil unless( optsHash.key?('--knownToEnsemblFile') )
      # Read ccdsGene file
    fileName = optsHash['--knownToEnsemblFile']
    ensemblToKnown = TableToHashCreator.valueToNameHash(fileName)
    ensemblToKnown.each_key {|key|
      tempHash = ensemblToKnown[key]
      tempHash.each_key{|value|
        puts "#{key} and value #{value}"
      }
    }
  end
  
  def self.testknownToHugoNameHash(optsHash)
    knownToHugoName = Hash.new {|hh,kk| hh[kk] = nil}
    return nil unless( optsHash.key?('--knownToRefSeqFile') )
    fileName = optsHash['--knownToRefSeqFile']
    return nil unless( optsHash.key?('--refFlatFile') )
    fileName2 = optsHash['--refFlatFile']


    knownToHugoName = TableToHashCreator.createKnownToHugoNameHash(fileName, fileName2)
    
    knownToHugoName.each_key {|key|
      tempHash = knownToHugoName[key]
      tempHash.each_key{|value|
        puts "#{key} and value #{value}"
      }
    }
    
  end

  def self.testEnsemblToHugoNameHash(optsHash)
    return nil unless( optsHash.key?('--knownToRefSeqFile') )
    fileName = optsHash['--knownToRefSeqFile']
    return nil unless( optsHash.key?('--refFlatFile') )
    fileName2 = optsHash['--refFlatFile']
    return nil unless( optsHash.key?('--knownToEnsemblFile') )
    fileName3 = optsHash['--knownToEnsemblFile']


    ensemblToHugoName = TableToHashCreator.createEnsemblToHugoNameHash(fileName, fileName2, fileName3)


    ensemblToHugoName.each_key {|key|
      tempHash = ensemblToHugoName[key]
      tempHash.each_key{|value|
        puts "#{key} and value #{value}"
      }
    }
    
  end
 
  
  def self.testCcdsGenePlainTable(optsHash)
#    return nil unless( optsHash.key?('--ccdsGeneFile') )
      # Read ccdsGene file
    ccdsGeneFileName = optsHash['--ccdsGeneFile']
    ccdsKgMapFileName = optsHash['--ccdsKgMapFile']
    knownGeneFileName = optsHash['--knownGeneFile']
    ccdsInfoFileName = optsHash['--ccdsInfoFile']
    knownToLocusLinkName = optsHash['--knownToLocusLink']
    knownToRefSeqFileName = optsHash['--knownToRefSeqFile']
    refFlatFileName = optsHash['--refFlatFile']
    knownToEnsemblFileName = optsHash['--knownToEnsemblFile']
    
    
    
    ccds2ccdsGeneTable = TableToHashCreator.ccdsToccdsGeneTableHash(ccdsGeneFileName)
    ccdsToSwissProtHash = TableToHashCreator.ccdsToSwissProtHash(ccdsKgMapFileName, knownGeneFileName)
    ccds2mRNAHash = TableToHashCreator.ccdsToNucAccHash(ccdsInfoFileName)
    ccds2ProtHash = TableToHashCreator.ccdsToProtAccHash(ccdsInfoFileName)
    ccdsTolocusLinkHash = TableToHashCreator.ccdsToLocusLinkHash(ccdsKgMapFileName, knownToLocusLinkName)
    ccdsIdToHugoNameHash = TableToHashCreator.ccdsToHugoNameHash(ccdsInfoFileName, knownToRefSeqFileName, refFlatFileName, knownToEnsemblFileName)
    ccdsToUcscGeneIdHash = TableToHashCreator.ccdsToKnownGeneIdHash(ccdsKgMapFileName)

    
    
    ccds2ccdsGeneTable.each_key {|key|
      ccdsRecord = ccds2ccdsGeneTable[key]
        exons = ccdsRecord.exonEnds
        counter = 0
        exons.each {|exon|
          frame = ccdsRecord.exonFrames[exon].to_i 
          if(frame == -1)
            exonFrame = "."
          else
            exonFrame = "#{frame}"
          end
          print "CLASSNAME\t#{ccdsRecord.name}\tmyType\tmySubType\t#{ccdsRecord.chrom}\t"
          print "#{ccdsRecord.exonStarts[counter]}\t#{ccdsRecord.exonEnds[counter]}\t#{ccdsRecord.strand}\t#{exonFrame}\t0\t.\t.\t"
          print "alternativeName=#{ccdsRecord.name2}; txStart=#{ccdsRecord.txStart}; txEnd=#{ccdsRecord.txEnd}; "
          print "cdsStart=#{ccdsRecord.cdsStart}; cdsEnd=#{ccdsRecord.cdsEnd}; "
          print "exonCount=#{ccdsRecord.exonCount};  iD=#{ccdsRecord.iD}; "
          print "alternativeName=#{ccdsRecord.name2}; " if(!ccdsRecord.name2.nil?)
          swissProtAcc = TableToHashCreator.returnVPEntriesForHashOfHashes(ccdsToSwissProtHash, key, "swissProtAcc")
          print swissProtAcc if(!swissProtAcc.nil?)
          accNumbStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ccds2mRNAHash, key, "accNumb")
          print accNumbStr if(!accNumbStr.nil?)
          accProtStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ccds2ProtHash, key, "proteinAcc")
          print accProtStr if(!accProtStr.nil?)
          ucscGeneId = TableToHashCreator.returnVPEntriesForHashOfHashes(ccdsToUcscGeneIdHash, key, "ucscGeneId")
          print ucscGeneId if(!ucscGeneId.nil?)

          locusLinkStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ccdsTolocusLinkHash, key, "locusLinkId")
          print locusLinkStr if(!locusLinkStr.nil?)
          refSeqStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ccdsIdToHugoNameHash, key, "refSeqId")
          print refSeqStr if(!refSeqStr.nil?)
          
#          print "exonStarts=#{ccdsRecord.exonStarts.join(",")}; exonEnds=#{ccdsRecord.exonEnds.join(",")}; "
          print "exonNum=#{counter + 1};"         
#          print "exonFrames=#{ccdsRecord.exonFrames.join(",")}; "
          print "cdsStartStatus=#{ccdsRecord.cdsStartStatus}; cdsEndStatus=#{ccdsRecord.cdsEndStatus};"
          puts ""
          counter = counter + 1
        }
    }
  end
  
 

  def self.testEnsGeneTable(optsHash)
#    return nil unless( optsHash.key?('--ccdsGeneFile') )
      # Read ccdsGene file
    ensGeneFileName = optsHash['--ensGeneFileName']
    #ccdsKgMapFileName = optsHash['--ccdsKgMapFile']
    #knownGeneFileName = optsHash['--knownGeneFile']
    ccdsInfoFileName = optsHash['--ccdsInfoFileName']
    knownToLocusLinkFileName = optsHash['--knownToLocusLinkFileName']
    knownToRefSeqFileName = optsHash['--knownToRefSeqFileName']
    refFlatFileName = optsHash['--refFlatFileName']
    knownToEnsemblFileName = optsHash['--knownToEnsemblFile']
    
    
    
    ensGenTableHash = TableToHashCreator.ensToEnsGeneTableHash(ensGeneFileName)
    ensembl2ccdsHash = TableToHashCreator.nucAccToCcdsHash(ccdsInfoFileName)
    ensembl2protAccHash = TableToHashCreator.nucAccToProtAcc(ccdsInfoFileName)
    ensemblToHugoNameHash = TableToHashCreator.createEnsemblToHugoNameHash(knownToRefSeqFileName, refFlatFileName, knownToEnsemblFileName)
    ensemblToKnownHash = TableToHashCreator.valueToNameRawHash(knownToEnsemblFileName)
    ensemblToLocusLinkHash =  TableToHashCreator.ensemblToLocusLinkHash(knownToEnsemblFileName, knownToLocusLinkFileName)



    
    
    ensGenTableHash.each_key {|key|
      ensemblRecord = ensGenTableHash[key]
        exons = ensemblRecord.exonEnds
        counter = 0
        exons.each {|exon|
        exonFrame = "0"

          print "CLASSNAME\t#{ensemblRecord.name}\tmyType\tmySubType\t#{ensemblRecord.chrom}\t"
          print "#{ensemblRecord.exonStarts[counter]}\t#{ensemblRecord.exonEnds[counter]}\t#{ensemblRecord.strand}\t#{exonFrame}\t0\t.\t.\t"
          print "txStart=#{ensemblRecord.txStart}; txEnd=#{ensemblRecord.txEnd}; "
          print "cdsStart=#{ensemblRecord.cdsStart}; cdsEnd=#{ensemblRecord.cdsEnd}; "
          print "exonCount=#{ensemblRecord.exonCount};  "

          ccdsAcc = TableToHashCreator.returnVPEntriesForHashOfHashes(ensembl2ccdsHash, key, "ccdsAcc")
          print ccdsAcc if(!ccdsAcc.nil?)
          refSeqStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ensemblToHugoNameHash, key, "refSeqId")
          print refSeqStr if(!refSeqStr.nil?)
          accProtStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ensembl2protAccHash, key, "proteinAcc")
          print accProtStr if(!accProtStr.nil?)
          ucscGeneId = TableToHashCreator.returnVPEntriesForHashOfHashes(ensemblToKnownHash, key, "ucscGeneId")
          print ucscGeneId if(!ucscGeneId.nil?)
          locusLinkStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ensemblToLocusLinkHash, key, "locusLinkId")
          print locusLinkStr if(!locusLinkStr.nil?)

          
          print "exonNum=#{counter + 1};"         

          puts ""
          counter = counter + 1
        }
    }
  end

  def self.testNucAccToCcdsHash(optsHash)
    return nil unless( optsHash.key?('--ccdsInfoFileName') )
    ccdsInfoFileName = optsHash['--ccdsInfoFileName']


    ensembl2protAcc = TableToHashCreator.nucAccToProtAcc(ccdsInfoFileName)
    
    ensembl2protAcc.each_key {|key|
      tempHash = ensembl2protAcc[key]
      tempHash.each_key{|value|
        puts "#{key.inspect} and value #{value.inspect}"
      }
    }
    
  end


  def self.testNucAccToCcdsHash(optsHash)
    return nil unless( optsHash.key?('--ccdsInfoFileName') )
    ccdsInfoFileName = optsHash['--ccdsInfoFileName']


    ensembl2protAcc = TableToHashCreator.nucAccToProtAcc(ccdsInfoFileName)
    
    ensembl2protAcc.each_key {|key|
      tempHash = ensembl2protAcc[key]
      tempHash.each_key{|value|
        puts "#{key.inspect} and value #{value.inspect}"
      }
    }
    
  end

  def self.testEnsembl2LocusLinkHash(optsHash)

    knownToLocusLinkFileName = optsHash['--knownToLocusLinkFileName']
    knownToEnsemblFileName = optsHash['--knownToEnsemblFile']

    ensemblToLocusHash =  TableToHashCreator.ensemblToLocusLinkHash(knownToEnsemblFileName, knownToLocusLinkFileName)
    ensemblToLocusHash.each_key {|key|
      tempHash = ensemblToLocusHash[key]
      tempHash.each_key{|value|
        puts "#{key.inspect} and value #{value.inspect}"
      }
    }
    
  end
  
 #.ensemblTranscriptToensembleGeneName(EnsGtpFileName) 
 #ensembleGeneName
 
  def self.testEnsemblTrans2EGNHash(optsHash)

    ensGtpFileName = optsHash['--ensGtpFileName']

    ensemblTrans2GeneNameHash =  TableToHashCreator.ensemblTranscriptToensembleGeneName(ensGtpFileName)
    ensemblTrans2GeneNameHash.each_key {|key|
      tempHash = ensemblTrans2GeneNameHash[key]
      tempHash.each_key{|value|
        puts "#{key.inspect} and value #{value.inspect}"
      }
    }
    
  end

#.ensemblTranscriptToensembleProteinName(fileName)
  def self.testEnsemblTrans2EPNHash(optsHash)

    ensGtpFileName = optsHash['--ensGtpFileName']

    ensemblTrans2ProteinNameHash =  TableToHashCreator.ensemblTranscriptToensembleProteinName(ensGtpFileName)
    ensemblTrans2ProteinNameHash.each_key {|key|
      tempHash = ensemblTrans2ProteinNameHash[key]
      tempHash.each_key{|value|
        puts "#{key.inspect} and value #{value.inspect}"
      }
    }
    
  end

 
  
end
end; end; end #namespace

optsHash = Hash.new {|hh,kk| hh[kk] = 0}
optsHash[ARGV[0]] = ARGV[1]
optsHash[ARGV[2]] = ARGV[3]
optsHash[ARGV[4]] = ARGV[5]
optsHash[ARGV[6]] = ARGV[7]
optsHash[ARGV[8]] = ARGV[9]
optsHash[ARGV[10]] = ARGV[11]
optsHash[ARGV[12]] = ARGV[13]
optsHash[ARGV[14]] = ARGV[15]
optsHash[ARGV[16]] = ARGV[17]
optsHash[ARGV[18]] = ARGV[19]

optsHash.each {|key, value|

  $stderr.puts "#{key} == #{value}" if(!key.nil?)
  }

#BRL::FileFormats::UcscParsers::TestMethods.testValueToNameHash(optsHash) #pass
#BRL::FileFormats::UcscParsers::TestMethods.testCcdsIdToHugoName(optsHash) #pass
#BRL::FileFormats::UcscParsers::TestMethods.testCCDSToMRAHash(optsHash) #pass
#BRL::FileFormats::UcscParsers::TestMethods.testCCDSToProtHash(optsHash) #pass
#BRL::FileFormats::UcscParsers::TestMethods.testCcdsToLocusLink(optsHash) #pass
#BRL::FileFormats::UcscParsers::TestMethods.testCcdsToSwissProt(optsHash) #pass
#BRL::FileFormats::UcscParsers::TestMethods.testEnsembleToKnownGeneHash(optsHash) #pass
#BRL::FileFormats::UcscParsers::TestMethods.testknownToHugoNameHash(optsHash) #pass
#BRL::FileFormats::UcscParsers::TestMethods.testEnsemblToHugoNameHash(optsHash) #pass
#BRL::FileFormats::UcscParsers::TestMethods.testCcdsGenePlainTable(optsHash)
#BRL::FileFormats::UcscParsers::TestMethods.testCcdsKgMapTable(optsHash)

#BRL::FileFormats::UcscParsers::TestMethods.testCcdsInfoTable(optsHash)
#BRL::FileFormats::UcscParsers::TestMethods.testEnsGeneTable(optsHash)
#BRL::FileFormats::UcscParsers::TestMethods.testNucAccToCcdsHash(optsHash)
#BRL::FileFormats::UcscParsers::TestMethods.testEnsembl2LocusLinkHash(optsHash)
#BRL::FileFormats::UcscParsers::TestMethods.testEnsemblTrans2EGNHash(optsHash)
BRL::FileFormats::UcscParsers::TestMethods.testEnsemblTrans2EPNHash(optsHash)
