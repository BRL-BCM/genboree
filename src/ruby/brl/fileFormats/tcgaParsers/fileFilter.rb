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
require 'brl/fileFormats/tcgaParsers/tcgaFiles'
require 'brl/fileFormats/tcgaParsers/tableToHashCreator'
require 'brl/fileFormats/tcgaParsers/tcgaAuxiliaryMethods'
require 'brl/util/textFileUtil'



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
module BRL ; module FileFormats; module TCGAParsers

class FileFilter

  def self.filterRioFile(optsHash)
    #--roiFileName --roiToLociFileName  --lociFileName --roiFoundFileName -roiMissingFileName
    methodName = "filterRioFile"
    roiFileName = nil
    roiToLociFileName = nil
    lociFileName  = nil
    roiFoundFileName = nil
    roiMissingFileName = nil
    
    roiFileName        = optsHash['--roiFileName'] if( optsHash.key?('--roiFileName') )
    roiToLociFileName  = optsHash['--roiToLociFileName'] if(optsHash.key?('--roiToLociFileName'))
    lociFileName       = optsHash['--lociFileName'] if(optsHash.key?('--lociFileName'))
    roiFoundFileName   = optsHash['--roiFoundFileName'] if(optsHash.key?('--roiFoundFileName'))
    roiMissingFileName = optsHash['--roiMissingFileName'] if(optsHash.key?('--roiMissingFileName'))


    if(roiFileName.nil? || roiToLociFileName.nil? || lociFileName.nil? || roiFoundFileName.nil? || roiMissingFileName.nil?)
      $stderr.puts "Error missing parameters in method #{methodName} --roiFileName=#{roiFileName} --roiToLociFileName=#{roiToLociFileName} --lociFileName=#{lociFileName} --roiFoundFileName=#{roiFoundFileName} --roiMissingFileName=#{roiMissingFileName}"
      return
    end
 
    FileFilter.filterRoiFileWithLociFile(roiFileName, roiToLociFileName, lociFileName, roiFoundFileName, roiMissingFileName)
  end


   def self.filterRoiFileWithLociFile(roiFileName, roiToLociFileName, lociFileName, roiFoundFileName, roiMissingFileName)
    retVal = {}
    foundfileWriter = BRL::Util::TextWriter.new(roiFoundFileName)
    missingfileWriter = BRL::Util::TextWriter.new(roiMissingFileName)
    hashOfRoisToLoci = TableToHashCreator.loadTabDelimitedFileWithMultipleValues(roiToLociFileName, true)
    hashOfLociNames = TableToHashCreator.loadSingleColumnFile(lociFileName, true)
    reader = BRL::Util::TextReader.new(roiFileName)
    found = Hash.new{|hh,kk| hh[kk] = nil }

    hashOfRoisToLoci.each_key {|key|
      lociHash = hashOfRoisToLoci[key]
      lociHash.each_key {|ll|
        if(!ll.nil? and ll.length > 0)
          locus = ll.to_s.upcase
          locus = locus.to_sym
          found[key] = nil if(hashOfLociNames.has_key?(locus))
        end
      }
    }
             
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = RoiFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          end
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.roiId))
          $stderr.puts "The Roi_id #{rg.roiId} from line #{lineCounter} is present multiple times line skipped"
        else
          if(found.has_key?(rg.roiId.to_sym))
            foundfileWriter.puts line
          else
            missingfileWriter.puts line
          end          
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
      foundfileWriter.close()
      missingfileWriter.close()
    end 
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end





  def self.filterRioSequencingFile(optsHash)
    #--roiSequencingFileName --roiToLociFileName  --lociFileName --roiSequencingFoundFileName -roiSequencingMissingFileName
    methodName = "filterRioSequencingFile"
    roiSequencingFileName = nil
    roiToLociFileName = nil
    lociFileName  = nil
    roiSequencingFoundFileName = nil
    roiSequencingMissingFileName = nil
    
    roiSequencingFileName        = optsHash['--roiSequencingFileName'] if( optsHash.key?('--roiSequencingFileName') )
    roiToLociFileName  = optsHash['--roiToLociFileName'] if(optsHash.key?('--roiToLociFileName'))
    lociFileName       = optsHash['--lociFileName'] if(optsHash.key?('--lociFileName'))
    roiSequencingFoundFileName   = optsHash['--roiSequencingFoundFileName'] if(optsHash.key?('--roiSequencingFoundFileName'))
    roiSequencingMissingFileName = optsHash['--roiSequencingMissingFileName'] if(optsHash.key?('--roiSequencingMissingFileName'))


    if(roiSequencingFileName.nil? || roiToLociFileName.nil? || lociFileName.nil? || roiSequencingFoundFileName.nil? || roiSequencingMissingFileName.nil?)
      $stderr.puts "Error missing parameters in method #{methodName} --roiSequencingFileName=#{roiSequencingFileName} --roiToLociFileName=#{roiToLociFileName} --lociFileName=#{lociFileName} --roiSequencingFoundFileName=#{roiSequencingFoundFileName} --roiSequencingMissingFileName=#{roiSequencingMissingFileName}"
      return
    end
 
    FileFilter.filterRoiSequencingFileWithLociFile(roiSequencingFileName, roiToLociFileName, lociFileName, roiSequencingFoundFileName, roiSequencingMissingFileName)
  end


   def self.filterRoiSequencingFileWithLociFile(roiSequencingFileName, roiToLociFileName, lociFileName, roiSequencingFoundFileName, roiSequencingMissingFileName)
    retVal = {}
    foundfileWriter = BRL::Util::TextWriter.new(roiSequencingFoundFileName)
    missingfileWriter = BRL::Util::TextWriter.new(roiSequencingMissingFileName)
    hashOfRoisToLoci = TableToHashCreator.loadTabDelimitedFileWithMultipleValues(roiToLociFileName, true)
    hashOfLociNames = TableToHashCreator.loadSingleColumnFile(lociFileName, true)
    reader = BRL::Util::TextReader.new(roiSequencingFileName)
    found = Hash.new{|hh,kk| hh[kk] = nil }
    
    hashOfRoisToLoci.each_key {|key|
      lociHash = hashOfRoisToLoci[key]
      lociHash.each_key {|ll|
        if(!ll.nil? and ll.length > 0)
          locus = ll.to_s.upcase
          locus = locus.to_sym
          found[key] = nil if(hashOfLociNames.has_key?(locus))
        end
      }
    }
             
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = RoiSequencingFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          end
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.roiId))
          $stderr.puts "The Roi_id #{rg.roiId} from line #{lineCounter} is present multiple times line skipped"
        else
          if(found.has_key?(rg.roiId.to_sym))
            foundfileWriter.puts line
          else
            missingfileWriter.puts line
          end          
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
      foundfileWriter.close()
      missingfileWriter.close()
    end 
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end


  def self.filterAmpliconFile(optsHash)
    #--ampliconFileName --ampliconToLociFileName  --lociFileName --ampliconFoundFileName --ampliconMissingFileName
    methodName = "filterAmpliconFile"
    ampliconFileName = nil
    ampliconToLociFileName = nil
    lociFileName  = nil
    ampliconFoundFileName = nil
    ampliconMissingFileName = nil
    
    ampliconFileName        = optsHash['--ampliconFileName'] if( optsHash.key?('--ampliconFileName') )
    ampliconToLociFileName  = optsHash['--ampliconToLociFileName'] if(optsHash.key?('--ampliconToLociFileName'))
    lociFileName       = optsHash['--lociFileName'] if(optsHash.key?('--lociFileName'))
    ampliconFoundFileName   = optsHash['--ampliconFoundFileName'] if(optsHash.key?('--ampliconFoundFileName'))
    ampliconMissingFileName = optsHash['--ampliconMissingFileName'] if(optsHash.key?('--ampliconMissingFileName'))


    if(ampliconFileName.nil? || ampliconToLociFileName.nil? || lociFileName.nil? || ampliconFoundFileName.nil? || ampliconMissingFileName.nil?)
      $stderr.puts "Error missing parameters in method #{methodName} --ampliconFileName=#{ampliconFileName} --ampliconToLociFileName=#{ampliconToLociFileName} --lociFileName=#{lociFileName} --ampliconFoundFileName=#{ampliconFoundFileName} --ampliconMissingFileName=#{ampliconMissingFileName}"
      return
    end
 
    FileFilter.filterAmpliconWithLociFile(ampliconFileName, ampliconToLociFileName, lociFileName, ampliconFoundFileName, ampliconMissingFileName)
  end


   def self.filterAmpliconWithLociFile(ampliconFileName, ampliconToLociFileName, lociFileName, ampliconFoundFileName, ampliconMissingFileName)
    retVal = {}
    foundfileWriter = BRL::Util::TextWriter.new(ampliconFoundFileName)
    missingfileWriter = BRL::Util::TextWriter.new(ampliconMissingFileName)
    hashOfRoisToLoci = TableToHashCreator.loadTabDelimitedFileWithMultipleValues(ampliconToLociFileName, true)
    hashOfLociNames = TableToHashCreator.loadSingleColumnFile(lociFileName, true)
    reader = BRL::Util::TextReader.new(ampliconFileName)
    found = Hash.new{|hh,kk| hh[kk] = nil }

    hashOfRoisToLoci.each_key {|key|
      lociHash = hashOfRoisToLoci[key]
      lociHash.each_key {|ll|
        if(!ll.nil? and ll.length > 0)
          locus = ll.to_s.upcase
          locus = locus.to_sym
          found[key] = nil if(hashOfLociNames.has_key?(locus))
        end
      }
    }
             
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = AmpliconFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          end
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.ampliconId))
          $stderr.puts "The Amplicon_id #{rg.ampliconId} from line #{lineCounter} is present multiple times line skipped"
        else
          if(found.has_key?(rg.ampliconId.to_sym))
            foundfileWriter.puts line
          else
            missingfileWriter.puts line
          end          
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
      foundfileWriter.close()
      missingfileWriter.close()
    end 
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end


  def self.filterSampleSequencingFile(optsHash)
    #--sampleSequencingFileName --ampliconToLociFileName  --lociFileName --sampleSequencingFoundFileName --sampleSequencingMissingFileName
    methodName = "filterSampleSequencingFile"
    sampleSequencingFileName = nil
    ampliconToLociFileName = nil
    lociFileName  = nil
    sampleSequencingFoundFileName = nil
    sampleSequencingMissingFileName = nil
    
    sampleSequencingFileName        = optsHash['--sampleSequencingFileName'] if( optsHash.key?('--sampleSequencingFileName') )
    ampliconToLociFileName  = optsHash['--ampliconToLociFileName'] if(optsHash.key?('--ampliconToLociFileName'))
    lociFileName       = optsHash['--lociFileName'] if(optsHash.key?('--lociFileName'))
    sampleSequencingFoundFileName   = optsHash['--sampleSequencingFoundFileName'] if(optsHash.key?('--sampleSequencingFoundFileName'))
    sampleSequencingMissingFileName = optsHash['--sampleSequencingMissingFileName'] if(optsHash.key?('--sampleSequencingMissingFileName'))


    if(sampleSequencingFileName.nil? || ampliconToLociFileName.nil? || lociFileName.nil? || sampleSequencingFoundFileName.nil? || sampleSequencingMissingFileName.nil?)
      $stderr.puts "Error missing parameters in method #{methodName} --sampleSequencingFileName=#{sampleSequencingFileName} --ampliconToLociFileName=#{ampliconToLociFileName} --lociFileName=#{lociFileName} --sampleSequencingFoundFileName=#{sampleSequencingFoundFileName} --sampleSequencingMissingFileName=#{sampleSequencingMissingFileName}"
      return
    end
 
    FileFilter.filterSampleSequencingWithLociFile(sampleSequencingFileName, ampliconToLociFileName, lociFileName, sampleSequencingFoundFileName, sampleSequencingMissingFileName)
  end


   def self.filterSampleSequencingWithLociFile(sampleSequencingFileName, ampliconToLociFileName, lociFileName, sampleSequencingFoundFileName, sampleSequencingMissingFileName)
    retVal = {}
    ampSampKey = nil
    sampleId = nil
    ampliconId = nil
    errorCounter = 0
    maxNumberOfErrors = 1000
    foundfileWriter = BRL::Util::TextWriter.new(sampleSequencingFoundFileName)
    missingfileWriter = BRL::Util::TextWriter.new(sampleSequencingMissingFileName)
    hashOfRoisToLoci = TableToHashCreator.loadTabDelimitedFileWithMultipleValues(ampliconToLociFileName, true)
    hashOfLociNames = TableToHashCreator.loadSingleColumnFile(lociFileName, true)
    reader = BRL::Util::TextReader.new(sampleSequencingFileName)
    found = Hash.new{|hh,kk| hh[kk] = nil }

    hashOfRoisToLoci.each_key {|key|
      lociHash = hashOfRoisToLoci[key]
      lociHash.each_key {|ll|
        if(!ll.nil? and ll.length > 0)
          locus = ll.to_s.upcase
          locus = locus.to_sym
          found[key] = nil if(hashOfLociNames.has_key?(locus))
        end
      }
    }
             
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = SampleSequencingFile.new(line)
        errorLevel = rg.errorLevel
        sampleId = rg.sampleId if(errorLevel < 1)
        ampliconId = rg.ampliconId if(errorLevel < 1)
        ampSampKey = "#{rg.sampleId}-#{rg.ampliconId}" if(errorLevel < 1)
        
        
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
            errorCounter += 1
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
            errorCounter += 1
          end
        elsif(retVal.has_key?(ampSampKey))
          $stderr.puts "The sampleId #{rg.sampleId}-#{rg.ampliconId} from line #{lineCounter} is present multiple times line skipped"
          errorCounter += 1
        else
          if(found.has_key?(rg.ampliconId.to_sym))
            foundfileWriter.puts line
          else
            missingfileWriter.puts line
          end          
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
      foundfileWriter.close()
      missingfileWriter.close()
    end 
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end






end #className


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
optsHash[ARGV[20]] = ARGV[21]
optsHash[ARGV[22]] = ARGV[23]
optsHash[ARGV[24]] = ARGV[25]
optsHash[ARGV[26]] = ARGV[27]
optsHash[ARGV[28]] = ARGV[29]
optsHash[ARGV[30]] = ARGV[31]
optsHash[ARGV[32]] = ARGV[33]


optsHash.each {|key, value|

  $stderr.puts "#{key} == #{value}" if(!key.nil?)
  }



#Generating Mapping Files
#--roiFileName --roiToLociFileName --lociFileName --roiFoundFileName --roiMissingFileName
BRL::FileFormats::TCGAParsers::FileFilter.filterRioFile(optsHash)

#--ampliconFileName --ampliconToLociFileName  --lociFileName --ampliconFoundFileName --ampliconMissingFileName
BRL::FileFormats::TCGAParsers::FileFilter.filterAmpliconFile(optsHash)

#--roiSequencingFileName --roiToLociFileName  --lociFileName --roiSequencingFoundFileName --roiSequencingMissingFileName
BRL::FileFormats::TCGAParsers::FileFilter.filterRioSequencingFile(optsHash)
    

#--sampleSequencingFileName --ampliconToLociFileName  --lociFileName --sampleSequencingFoundFileName --sampleSequencingMissingFileName
BRL::FileFormats::TCGAParsers::FileFilter.filterSampleSequencingFile(optsHash)    

