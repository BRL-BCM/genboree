#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Some Auxiliary methods that stores the files into a hash table

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'md5'
require 'brl/fileFormats/validators/tcgaFiles/constants'
require 'brl/fileFormats/validators/tcgaFiles/formatReader'


# ##############################################################################
# CONSTANTS
# ##############################################################################



module BRL ; module FileFormats; module Validators; module TcgaFiles

class FilesToHash
  def self.sampleIdToSampleTableHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )

    reader = File.open(fileName, "r")
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = SampleFile.new(line)
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
        if(retVal.has_key?(rg.sampleId))
          $stderr.puts "Sample Id #{rg.sampleId} from line #{lineCounter} is present multiple times line skipped"
        else
          retVal[rg.sampleId] = rg 
        end
        lineCounter = lineCounter + 1
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

  def self.ampliconIdToAmpliconTableHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read amplicon file
    reader = File.open(fileName, "r")
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
          $stderr.puts "AmpliconId #{rg.ampliconId} from line #{lineCounter} is present multiple times line skipped"
        else
          retVal[rg.ampliconId] = rg 
        end
        lineCounter = lineCounter + 1
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
 
   def self.roiIdToHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read amplicon file
    reader = File.open(fileName, "r")
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
          retVal[rg.roiId] = rg          
        end
        lineCounter = lineCounter + 1
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

  def self.roiIdToRoiSequencingTableHash(roiSequencingFileName, numberOfSamples, roiHash)
    errorCounter = 0
    maxNumberOfErrors = 1000
    retVal = {}
    return retVal unless( !roiSequencingFileName.nil? )

    reader = File.open(roiSequencingFileName, "r")
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        
        if(errorCounter > maxNumberOfErrors)
          $stderr.puts "Too many errors in file #{roiSequencingFileName} please fix the problems and re-submit the file!"
          return nil
        end 
        
        rg = RoiSequencingFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
            errorCounter += 1
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
            errorCounter += 1
          end
        elsif(retVal.has_key?(rg.roiId))
          $stderr.puts "Roi Id #{rg.roiId} from line #{lineCounter} is present multiple times line skipped"
          errorCounter += 1
        elsif(rg.samples > numberOfSamples)
          $stderr.puts "error in line #{lineCounter} The number of samples in the sample definition file is #{numberOfSamples} and the number of samples reported in this line is #{rg.samples} --> line rejected"
          errorCounter += 1
        elsif(!roiHash.has_key?(rg.roiId))   
          $stderr.puts "error in line #{lineCounter} The #{rg.roiId} is not defined in the Roi-definition file --> line rejected"
          errorCounter += 1
        #elsif(rg.samples < numberOfSamples)
        #  $stderr.puts "Warning for line #{lineCounter} The number of samples in the sample definition file is #{numberOfSamples} and the number of samples in this line is #{rg.samples}, this line will be analyzed but you should verify the information since the values in both files should match. The current values may affect your Coverage score in this report"
        #  retVal[rg.roiId] = rg
        else
          retVal[rg.roiId] = nil #rg
        end
        lineCounter += 1
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

 def self.sampleSequencingToHash(sampleSequencingFileName, ampliconHash, sampleHash)
    retVal = {}
    ampSampKey = nil
    sampleId = nil
    ampliconId = nil
    errorCounter = 0
    maxNumberOfErrors = 1000

    
    return retVal unless( !sampleSequencingFileName.nil? )
    # Read amplicon file
    reader = File.open(sampleSequencingFileName, "r")
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        
        if(errorCounter > maxNumberOfErrors)
          $stderr.puts "Too many errors in file #{sampleSequencingFileName} please fix the problems and re-submit the file!"
          return nil
        end
        rg = SampleSequencingFile.new(line)
        errorLevel = rg.errorLevel
        sampleId = rg.sampleId if(errorLevel < 1)
        ampliconId = rg.ampliconId if(errorLevel < 1)
        ampSampKey = MD5.md5("#{rg.sampleId}-#{rg.ampliconId}") if(errorLevel < 1)
        
        
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
            errorCounter += 1
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
            errorCounter += 1
          end
        elsif(!sampleHash.has_key?(sampleId))
          $stderr.puts "error in line #{lineCounter} Sample-Sequencing-File SampleId #{sampleId} is not in the Sample Definition File -> line rejected"
          errorCounter += 1
        elsif(!ampliconHash.has_key?(ampliconId))
          $stderr.puts "error in line #{lineCounter} Sample-Sequencing-File AmpliconId #{ampliconId} is not in the Amplicon Definition File -> line rejected"
          errorCounter += 1
        elsif(retVal.has_key?(ampSampKey))
          $stderr.puts "The sampleId #{rg.sampleId}-#{rg.ampliconId} from line #{lineCounter} is present multiple times line skipped"
          errorCounter += 1
        else
          retVal[ampSampKey] = nil          
        end
        lineCounter += 1
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


end

        
end; end; end; end;
