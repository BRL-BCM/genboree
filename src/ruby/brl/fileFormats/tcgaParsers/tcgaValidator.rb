#!/usr/bin/env ruby

require 'md5'

class Constants
  ChromosomeHash = {
                    "4" => 191273063,
                    "18" => 76117153,
                    "5" => 180857866,
                    "6" => 170899992,
                    "1" => 247249719,
                    "17" => 78774742,
                    "19" => 63811651,
                    "16" => 88827254,
                    "Y" => 57772954,
                    "x" => 154913754,
                    "y" => 57772954,
                    "X" => 154913754,
                    "10" => 135374737,
                    "3" => 199501827,
                    "8" => 146274826,
                    "21" => 46944323,
                    "9" => 140273252,
                    "13" => 114142980,
                    "20" => 62435964,
                    "14" => 106368585,
                    "2" => 242951149,
                    "12" => 132349534,
                    "11" => 134452384,
                    "7" => 158821424,
                    "22" => 49691432,
                    "15" => 100338915
    }
  

  ErrorLevelHash = {
                    0 => "OK",
                    1 => "Roi_id is empty",
                    2 => "entrezGeneId is empty",
                    3 => "Line is empty!",
                    4 => "Too many columns in line",
                    5 => "Missing columns in line",
                    6 => "Amplicon_id is empty",
                    7 => "NCBI_Build is not a valid value ",
                    8 => "Chromosome is empty",
                    9 => " is not present in the current assembly, the normal chromosome values are ",
                    10 => "Coordinates are outside the range ",
                    11 => "Coordinates are outside the range the maximum value for ",
                    12 => "Coordinates are 0 or negative",
                    13 => "primer_fw is empty",
                    14 => "primer_rv is empty",
                    15 => "Status is empty",
                    16 => "Status contains unknown value = ",
                    17 => "SampleId is empty ",
                    18 => "SampleType is empty",
                    19 => "PatientId is empty",
                    20 => "Number of samples is empty we expect a positive number",
                    21 => "The sequence length of the amplicon is empty we expect a positive number ",
                    22 => "The sequence of the amplicon is empty we expect the sequence of the amplicon",
                    23 => "The lenght of the sequence do not match the length value provided",
                    24 => "The 1XCoverage values is empty we expect a comma separated list of values",
                    25 => "The 1XCoverage size do not match the length of the sequence",
                    26 => "The 2XCoverage values is empty we expect a comma separated list of values",
                    27 => "The 2XCoverage size do not match the length of the sequence",
                    28 => "NumberOfReadsAtempted is not a positive number",
                    29 => "Q30/amplicon value should be a float value less than 1.0",
                    30 => "Chemistry value is empty",
                    31 => " is not present in not part of the allowed values, valid values are ",     
                    32 => "The hugoSymbol is empty",                   
                    33 => "The Center is empty",
                    34 => " is not present in not part of the allowed values, valid values are ",
                    35 => "Strand value is empty",
                    36 => " is not present in not part of the allowed values, valid values are ",
                    37 => "VariantClassification value is empty",
                    38 => " is not present in not part of the allowed values, valid values are ",
                    39 => "VariantType value is empty",
                    40 => " is not present in not part of the allowed values, valid values are ",
                    41 => "referenceAllele value is empty",
                    42 => "tumorSeqAllele1 value is empty",
                    43 => "tumorSeqAllele2 value is empty",
                    44 => "dbSNPRS value is empty",
                    45 => "dbSNPValStatus value is empty",
                    46 => "matchNormSeqAllele1 value is empty",
                    47 => "matchNormSeqAllele1 value is empty",
                    48 => "tumorValidationAllele1 value is empty",
                    49 => "tumorValidationAllele2 value is empty",
                    50 => "matchNormValidationAllele1 value is empty",
                    51 => "matchNormValidationAllele2 value is empty",
                    52 => "verificationStatus value is empty",
                    53 => " is not present in not part of the allowed values, valid values are ",
                    54 => "validationStatus value is empty",
                    55 => " is not present in not part of the allowed values, valid values are ",
                    56 => "mutationStatus value is empty",
                    57 => " is not present in not part of the allowed values, valid values are ",
                    58 => "Line appears to be a header line, comments should contain '#' at the begining of the line",
                    59 => "Values from the 1X quality are larger that the number of samples",
                    60 => "Values from the 2X quality are larger that the number of samples",
                    61 => "Value from the tumor_Sample_Barcode is empty",
                    62 => "Value from the matched_Norm_Sample_Barcode is empty"
  }
  
  
  StandHash  =  {
                    "+" => nil,
                    "-" => nil
  }
  
  StatusHash =  {
                    "PASS" => nil,
                    "FAIL" => nil,
                    "HELD" => nil
  }

  ChemistryHash  =  {
                    "STANDARD" => 0,
                    "Q-BUFFER" => 1,
                    "ROCHEKIT" => 2,
                    "UNKNOWN" => 3
  }

  CenterHash  =  {
                    "BCM" => "BCM",
                    "BROAD" => "BROAD",
                    "WUGSC" => "WUGSC",
  }
  

  
  CurrentBuild = 35.9
  
end


class RoiSequencingFile

  attr_accessor :roiId, :samples, :length, :sequence, :oneXCoverage, :twoXCoverage, :oneXCoverageArray, :twoXCoverageArray,
  :oneXCoverageSize, :twoXCoverageSize, :sequenceArray, :errorLevel, :currentLine

  ExpectedLineLength = 6 

  def returnErrorMessage(errLev)
    if(errLev == 4 or errLev == 5 )
          errorString = "#{Constants::ErrorLevelHash[errLev]} = #{@currentLine}"
          return errorString
    else
      return "#{Constants::ErrorLevelHash[errLev]}"
    end
  end


  def initialize(line)
    @roiId, @sequence, @oneXCoverage, @twoXCoverage, @oneXCoverageArray, @sequenceArray, @twoXCoverageArray = nil
    @samples, @length, @oneXCoverageSize, @twoXCoverageSize = 0
    @currentLine = line
    @errorLevel = 0

    @errorLevel = 3 if(line.nil? or line.empty?)
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @roiId = aa[0].chomp if(!aa[0].nil?)
      @samples = aa[1].to_i if(!aa[1].nil?)
      @length = aa[2].to_i if(!aa[2].nil?)
      @sequence = aa[3].chomp if(!aa[3].nil?)
      @sequenceArray = @sequence.split("") if(!@sequence.nil? and @sequence.length > 0)
      if(!aa[4].nil?)
        @oneXCoverage = aa[4].chomp
        @oneXCoverageArray = @oneXCoverage.split(",").map{|xx| xx.to_i}
        @oneXCoverageSize = @oneXCoverageArray.size
      end
      if(!aa[5].nil?)
        @twoXCoverage = aa[5].chomp
        @twoXCoverageArray = @twoXCoverage.split(",").map{|xx| xx.to_i}
        @twoXCoverageSize = @twoXCoverageArray.size
      end
      lineLength = aa.length
    end
    validate(line, lineLength)
  end
 
  def validate(line, lineLength)

      if(lineLength > ExpectedLineLength || lineLength < ExpectedLineLength)
        if(lineLength > ExpectedLineLength)
          @errorLevel = 4
        else
          @errorLevel = 5
        end
        return
      end

      if(@roiId.nil? || @roiId.length < 1)
              @errorLevel = 6
              return
      end
      if(@samples < 1)
          @errorLevel = 20
          return
      end
      
      if(@length < 1)
          @errorLevel = 21
          return
      end
      
      if(@sequence.nil? || @sequence.length < 1)
          @errorLevel =  22
          return
      end
      
      if(@sequence.length != @length)
        @errorLevel =  23
        return
      end
      
      if(@oneXCoverage.nil? || @oneXCoverage.length < 1 || @oneXCoverageSize < 1)
        @errorLevel =  24
        return
      end
      
      if(@oneXCoverageSize != @length)
        @errorLevel =  25
        return
      end
      
      @oneXCoverageArray.each{|oneX|
        if(oneX  >  @samples)
          @errorLevel =  59
        end
        }
    
      if(@twoXCoverage.nil? || @twoXCoverage.length < 1 || @twoXCoverageSize < 1)
        @errorLevel =  26
        return
      end
      
           
      if(@twoXCoverageSize != @length)
        @errorLevel =  27
        return
      end
      
      @twoXCoverageArray.each{|twoX|
        if(twoX  >  @samples)
          @errorLevel =  60
        end
        }
    end
  end

class SampleFile

  attr_accessor :sampleId, :sampleType, :patientId, :errorLevel, :currentLine

  ExpectedLineLength = 3 

  def returnErrorMessage(errLev)
    if(errLev == 4 or errLev == 5 )
          errorString = "#{Constants::ErrorLevelHash[errLev]} = #{@currentLine}"
          return errorString
    else
      return "#{Constants::ErrorLevelHash[errLev]}"
    end
  end


  def initialize(line)
    @sampleId, @sampleType, @patientId = nil
    @currentLine = line
    @errorLevel = 0

    @errorLevel = 3 if(line.nil? or line.empty?)
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @sampleId = aa[0].chomp if(!aa[0].nil?)
      @sampleType = aa[1].chomp if(!aa[1].nil?)
      @patientId = aa[2].chomp if(!aa[2].nil?)
      lineLength = aa.length
    end
    validate(line, lineLength)
  end
 
  def validate(line, lineLength)
      if(lineLength > ExpectedLineLength || lineLength < ExpectedLineLength)
        if(lineLength > ExpectedLineLength)
          @errorLevel = 4
        else
          @errorLevel = 5
        end
        return
      end

      if(@sampleId.nil? || @sampleId.length < 1)
              @errorLevel = 17
              return
      end
      if(@sampleType.nil? || @sampleType.length < 1)
          @errorLevel = 18
          return
      end
      if(@patientId.nil? || @patientId.length < 1)
          @errorLevel = 19
          return
      end
  end
end

class AmpliconFile

  attr_accessor :ampliconId, :ncbiBuild, :chromosome, :start, :stop, :size, :currentLine
  attr_accessor :primer_frw, :primer_frwStart, :primer_frwStop, :primer_frwSize, :primer_fwOr
  attr_accessor :primer_rv, :primer_rvStart, :primer_rvStop, :primer_rvSize, :primer_rvOr 
  attr_accessor :status, :errorLevel

  ExpectedLineLength = 8

  def returnErrorMessage(errLev)
      if(errLev == 9)
          chromosomeValues = Constants::ChromosomeHash.keys.sort.join(",")
          errorString = "The chromosome #{@chromosome} #{Constants::ErrorLevelHash[errLev]} #{chromosomeValues}"
          return errorString
      elsif(errLev == 4 or errLev == 5 )
          errorString = "#{Constants::ErrorLevelHash[errLev]} = #{@currentLine}"
          return errorString
      elsif(errLev == 10)
         errorString = "#{Constants::ErrorLevelHash[errLev]} and you are providing start = #{@start} and stop = #{@stop}"
         return errorString
      elsif(errLev == 11)
         errorString = "#{Constants::ErrorLevelHash[errLev]} chromosome #{@chromosome} is #{Constants::ChromosomeHash[@chromosome]} and you are providing start = #{@start} and stop = #{@stop}"
         return errorString
      elsif(errLev == 16)
          statusValuesArray = Constants::StatusHash.keys.sort
          statusValuesArray.each {|st|
            st.capitalize!
            }
          statusValues = statusValuesArray.join(",")
          errorString = "#{Constants::ErrorLevelHash[errorLevel]} #{@status} the approved values are #{statusValues}}"
          eturn errorString
      
      else
            return "#{Constants::ErrorLevelHash[errLev]}"
      end
  
  end

  def initialize(line)
    @ampliconId, @ncbiBuild, @chromosome, @start, @stop, @size,
    @primer_frw, @primer_rv, @status = nil
    @primer_frwSize, @primer_frwStart,
    @primer_frwStop,@primer_rvSize, @primer_frwStart, @primer_frwStop = 0
    @primer_fwOr , @primer_rvOr = nil
    @currentLine = line
    @errorLevel = 0
    chromosomeLength = 0
    @errorLevel = 3 if(line.nil? or line.empty?)
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @ampliconId = aa[0].chomp if(!aa[0].nil?)
      @ncbiBuild = aa[1].to_f if(!aa[1].nil?)
      @chromosome = aa[2].chomp if(!aa[2].nil?)
      @start = aa[3].to_i 
      @stop = aa[4].to_i
      @size = @stop - @start
 
      if(!aa[5].nil?)
        @primer_frw = aa[5].chomp
        @primer_frwSize = @primer_frw.length
        @primer_frwStart = @start
        @primer_frwStop = @start + @primer_frwSize
        @primer_fwOr = "+"
      end
      
      if(!aa[6].nil?)
        @primer_rv = aa[6].chomp
        @primer_rvSize = @primer_rv.length 
        @primer_rvStart = @stop - @primer_rvSize
        @primer_rvStop =  @stop
        @primer_rvOr = "-"
      end
      @status = aa[7].chomp if(!aa[7].nil?)
      lineLength = aa.length
    end
    validate(line, lineLength)
  end
  
  def validate(line, lineLength)

      if(lineLength > ExpectedLineLength || lineLength < ExpectedLineLength)
        if(lineLength > ExpectedLineLength)
          @errorLevel = 4
        else
          @errorLevel = 5
        end
        return
      end

      if(@ampliconId.nil? || @ampliconId.length < 1)
              @errorLevel = 6
              return
      end
      if(@ncbiBuild < Constants::CurrentBuild)
          @errorLevel = 7
          return
      end
      if(@chromosome.nil? || @chromosome.length < 1)
          @errorLevel = 8
          return
      end
      
      if(!Constants::ChromosomeHash.has_key?(@chromosome))
          @errorLevel =  9
          return
      end
      
      chromosomeLength = Constants::ChromosomeHash[@chromosome]
    
      if(@start >= @stop)
        @errorLevel =  10
        return
      end
    
      if(@start > chromosomeLength || @stop > chromosomeLength)
        @errorLevel = 11
        return
      end
      
      if(@start < 1 || @stop < 1)
        @errorLevel = 12
        return
      end
      @chromosome = "chr#{@chromosome.upcase}"
      
      
      
      if(@primer_frw.nil? || @primer_frw.length < 10 )
        @errorLevel = 13
        return
      end
      
      if(@primer_rv.nil? || @primer_rv.length < 10 )
        @errorLevel = 14
        return
      end

      if(@status.nil? || @status.length < 1 )
        @errorLevel = 15
        return
      end
      
      if(!Constants::StatusHash.has_key?(@status.upcase))
          @errorLevel =  16
          return
      end
      
      @status.capitalize!
       
    end
  end




class RoiFile

  attr_accessor :roiId, :ncbiBuild, :chromosome, :start, :stop, :size, :entrezGeneId,
  :errorLevel, :currentLine

  ExpectedLineLength = 6 

  def returnErrorMessage(errLev)
      if(errLev == 9)
          chromosomeValues = Constants::ChromosomeHash.keys.sort.join(",")
          errorString = "The chromosome #{@chromosome} #{Constants::ErrorLevelHash[errLev]} #{chromosomeValues}"
          return errorString
      elsif(errLev == 4 or errLev == 5 )
          errorString = "#{Constants::ErrorLevelHash[errLev]} = #{@currentLine}"
          return errorString
      elsif(errLev == 10)
         errorString = "#{Constants::ErrorLevelHash[errLev]} start = #{@start} and stop = #{@stop}"
         return errorString
      elsif(errLev == 11)
         errorString = "#{Constants::ErrorLevelHash[errLev]} chromosome #{@chromosome} is #{Constants::ChromosomeHash[@chromosome]} and you are providing start = #{@start} and stop = #{@stop}"
         return errorString
      else
            return "#{Constants::ErrorLevelHash[errLev]}"
      end
  
  end


  def initialize(line)
    @roiId, @ncbiBuild, @chromosome, @start, @stop, @size = nil
    @entrezGeneId = 0
    @currentLine = line
    @errorLevel = 0
    chromosomeLength = 0
    @errorLevel = 3 if(line.nil? or line.empty?)
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @roiId = aa[0].chomp if(!aa[0].nil?)
      @ncbiBuild = aa[1].to_f if(!aa[1].nil?)
      @chromosome = aa[2].chomp if(!aa[2].nil?)
      @start = aa[3].to_i
      @stop = aa[4].to_i
      @size = @stop - @start
      if(!aa[5].nil? and aa[5].size > 0)
        aa[5] = "0" if(aa[5] =~ /null/i)
        @entrezGeneId = aa[5].chomp.to_i
      end
      lineLength = aa.length
    end
    validate(line, lineLength)
  end
 
  def validate(line, lineLength)

      if(lineLength > ExpectedLineLength || lineLength < ExpectedLineLength)
        if(lineLength > ExpectedLineLength)
          @errorLevel = 4
        else
          @errorLevel = 5
        end
        return
      end

      if(@roiId.nil? || @roiId.length < 1)
              @errorLevel = 1
              return
      end
      if(@ncbiBuild < Constants::CurrentBuild)
          @errorLevel = 7
          return
      end
      if(@chromosome.nil? || @chromosome.length < 1)
          @errorLevel = 8
          return
      end
      
      if(!Constants::ChromosomeHash.has_key?(@chromosome))
          @errorLevel =  9
          return
      end
      
      chromosomeLength = Constants::ChromosomeHash[@chromosome]
    
      if(@start > @stop)
        @errorLevel =  10
        return
      end
    
      if(@start > chromosomeLength || @stop > chromosomeLength)
        @errorLevel = 11
        return
      end
      
      if(@start < 1 || @stop < 1)
        @errorLevel = 12
        return
      end
      @chromosome = "chr#{@chromosome.upcase}"
      
      if(@entrezGeneId < 0 )
        @errorLevel = 2
        return
      end
       
    end
  end


class Validator

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
          retVal[rg.roiId] = nil # rg
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

 def self.lightSampleSequencingToHash(sampleSequencingFileName, ampliconHash, sampleHash)
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
          retVal[ampSampKey] = rg          
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


class SampleSequencingFile

  attr_accessor :sampleId, :ampliconId, :numberOfReadsAtempted, :numberOfReadsPassed, :pass, :q30OverAmpliconLength,
  :chemistry, :validate, :errorLevel, :currentLine

  ExpectedLineLength = 6 

  def returnErrorMessage(errLev)
    if(errLev == 31)
      chemistryValues = Constants::ChemistryHash.keys.sort.join(",")
      errorString = "The Chemistry #{@chemistry} #{Constants::ErrorLevelHash[errLev]} #{chemistryValues}"
      return errorString
      elsif(errLev == 4 or errLev == 5 )
          errorString = "#{Constants::ErrorLevelHash[errLev]} = #{@currentLine}"
          return errorString
    else
      return "#{Constants::ErrorLevelHash[errLev]}"
    end
  end


  def initialize(line)
    @sampleId = nil
    @ampliconId= nil
    @chemistry = nil
    @validate = true
    @numberOfReadsAtempted = nil
    @numberOfReadsPassed = nil
    @q30OverAmpliconLength = nil
    @pass = nil
    @currentLine = line
    @errorLevel = 0

    @errorLevel = 3 if(line.nil? or line.empty?)
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      lineLength = aa.length
      if(lineLength < 2 or aa[1].nil?)
        $stderr.puts "Line contains only one column Why??? #{aa}"
      elsif(lineLength == 2 and !aa[0].nil? and !aa[1].nil?) # we need an emptyClass
        @sampleId = aa[0].chomp if(!aa[0].nil?)
        @ampliconId = aa[1].chomp if(!aa[1].nil?)
        @numberOfReadsAtempted = ""
        @numberOfReadsPassed = ""
        @pass = ""
        @q30OverAmpliconLength = ""
        @chemistry = ""
        @validate = false
      else
        @sampleId = aa[0].chomp if(!aa[0].nil?)
        @ampliconId = aa[1].chomp if(!aa[1].nil?)
        @numberOfReadsAtempted = aa[2].to_i if(!aa[2].nil?)
        @numberOfReadsPassed = aa[3].to_i if(!aa[3].nil?)
        if(@numberOfReadsPassed > 1)
          @pass = true
        else
          @pass = false
        end
        @q30OverAmpliconLength = aa[4].to_f if(!aa[4].nil?)
        @chemistry = aa[5].chomp if(!aa[5].nil?)
      end
    end
    validate(line, lineLength) if(@validate)
  end
 
  def validate(line, lineLength)

      if(lineLength > ExpectedLineLength || lineLength < ExpectedLineLength)
        if(lineLength > ExpectedLineLength)
          @errorLevel = 4
        else
          @errorLevel = 5
        end
        return
      end

      if(@sampleId.nil? || @sampleId.length < 1)
              @errorLevel = 17
              return
      end

      if(@ampliconId.nil? || @ampliconId.length < 1)
              @errorLevel = 6
              return
      end
      
      if(@numberOfReadsAtempted < 1)
          @errorLevel = 28
          return
      end
      
      if(@q30OverAmpliconLength > 1.05)
          @errorLevel =  29
          return
      end
      
      if(@chemistry.nil? || @chemistry.length < 1)
        @errorLevel =  30
        return
      end
      
      if(!Constants::ChemistryHash.has_key?(@chemistry.upcase))
        @errorLevel =  31
        return
      end
      
  end

  def to_sample(standart_table=0)
    if(standart_table == 0)
      baseStr = "#{@sampleId}\t#{@ampliconId}\t#{@numberOfReadsAtempted}\t#{@numberOfReadsPassed}\t#{@q30OverAmpliconLength}\t#{@chemistry}"
    elsif(standart_table == 1)
      baseStr = "#{@ampliconId}\t#{@numberOfReadsAtempted}\t#{@numberOfReadsPassed}\t#{@pass}\t#{@q30OverAmpliconLength}\t#{Constants::ChemistryHash[@chemistry.upcase]}"   
    elsif(standart_table == 2)
      baseStr = "#{@numberOfReadsAtempted}\t#{@numberOfReadsPassed}\t#{@pass}\t#{@q30OverAmpliconLength}\t#{Constants::ChemistryHash[@chemistry.upcase]}"
    else
      @pass = false if(@pass.nil? || @pass == "")
      baseStr = "#{@pass}"
    end
    return baseStr
  end

  def self.getFields(standart_table=0)
    if(standart_table == 0)
      baseFields = "sampleId\tampliconId\tnumberOfReadsAtempted\tnumberOfReadsPassed\tq30/AmpliconLength\tchemistry"
    elsif(standart_table == 1)
      baseFields = "ampliconId\tnumberOfReadsAtempted\tnumberOfReadsPassed\tpass\tq30/AmpliconLength\tchemistryCode"   
    else
      baseFields = "numberOfReadsAtempted\tnumberOfReadsPassed\tpass\tq30/AmpliconLength\tchemistryCode"
    end
    return baseFields
      
  end
  
  def self.getFieldTypes(standart_table=0)
    if(standart_table == 0)
      baseFields = "text:255\ttext:255\tinteger_32\tinteger_32\tfloat\ttext:255"
    elsif(standart_table == 1)
      baseFields = "text:255\tinteger_32\tinteger_32\tboolean\tfloat\tinteger_32"   
    else
      baseFields = "integer_32\tinteger_32\tboolean\tfloat\tinteger_32"
    end
    return baseFields
      
  end
  

  end





  def self.validateFiles(optsHash)
    #--roiFileName --type --roiSubtype  --roiClassName --roiLffFileName
    methodName = "validateFiles"
    sampleFileName = nil
    ampliconFileName = nil
    roiFileName = nil
    roiSequencingFileName = nil
    sampleSequencingFileName = nil
    
    roiFileName = optsHash['--roiFileName'] if( optsHash.key?('--roiFileName') )
    ampliconFileName = optsHash['--ampliconFileName'] if( optsHash.key?('--ampliconFileName') )
    sampleFileName  = optsHash['--sampleFileName'] if( optsHash.key?('--sampleFileName') )
    roiSequencingFileName = optsHash['--roiSequencingFileName'] if( optsHash.key?('--roiSequencingFileName') )
    sampleSequencingFileName = optsHash['--sampleSequencingFileName'] if( optsHash.key?('--sampleSequencingFileName') )

    if( ampliconFileName.nil? || sampleFileName.nil? || roiFileName.nil? || roiSequencingFileName.nil? || sampleSequencingFileName.nil?)
      puts "Error missing parameters in method #{methodName}"
      puts "--ampliconFileName=#{ampliconFileName} "
      puts "--sampleFileName=#{sampleFileName} "
      puts "--roiFileName=#{roiFileName} "
      puts "--roiSequencingFileName=#{roiSequencingFileName} "
      puts "--sampleSequencingFileName=#{sampleSequencingFileName} "
      return
    end

    $stderr.puts "-------------------- START OF Sample File Validation -------------------------------------------"
    sampleHash = sampleIdToSampleTableHash(sampleFileName)
    $stderr.puts "number of well formatted records #{sampleHash.length}"
    $stderr.puts "-------------------- END OF Sample File Validation -------------------------------------------"


    $stderr.puts "-------------------- START OF Amplicon File Validation -------------------------------------------"
    ampliconHash = ampliconIdToAmpliconTableHash(ampliconFileName)
    $stderr.puts "number of well formatted records #{ampliconHash.length}"
    $stderr.puts "-------------------- END OF Amplicon File Validation -------------------------------------------"
      
    $stderr.puts "-------------------- START OF ROI File Validation -------------------------------------------"
    roiHash = roiIdToHash(roiFileName)
    $stderr.puts "number of well formatted records #{roiHash.length}"
    $stderr.puts "-------------------- END OF ROI File Validation -------------------------------------------"
 
    $stderr.puts "-------------------- START OF Roi Sequencing File Validation -------------------------------------------"
    roiSequencingHash = roiIdToRoiSequencingTableHash(roiSequencingFileName, sampleHash.length, roiHash)
    $stderr.puts "number of well formatted records #{roiSequencingHash.length}" if(!roiSequencingHash.nil?)
    $stderr.puts "-------------------- END OF Roi Sequencing File Validation -------------------------------------------"

    $stderr.puts "-------------------- START OF Sample Sequencing File Validation -------------------------------------------"
    sampleSequencingHash = lightSampleSequencingToHash(sampleSequencingFileName, ampliconHash, sampleHash)
    $stderr.puts "number of well formatted records #{sampleSequencingHash.length}" if(!sampleSequencingHash.nil?)
    $stderr.puts "-------------------- END OF Sample Sequencing File Validation -------------------------------------------"
  end





  
end


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

  puts "#{key} == #{value}" if(!key.nil?)
  }



#Validators
#--roiFileName --sampleFileName --ampliconFileName --sampleSequencingFileName --roiSequencingFileName --ampliconSequencingFile
Validator.validateFiles(optsHash)


