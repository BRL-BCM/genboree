#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC table to equivalent LFF version

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'sha1'
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
module BRL ; module FileFormats; module TCGAParsers

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
                    "hgsc.bcm.edu" => "BCM",
                    "broad.mit.edu" => "BROAD",
                    "genome.wustl.edu" => "WUGSC"
  }
  
  VariantTypeHash  =  {
                    "DEL" => "Del",
                    "DELETION" => "Del",
                    "INS" => "Ins",
                    "INSERTION" => "Ins",
                    "SNP" => "SNP",
                    "REF" => "Ref"
  }
  
  SequencingPhaseHash = {
                    "PHASE_I" => "Phase_I",
                    "PHASE_II" => "Phase_II" 
  }
  
  VariantClassificationHash  =  {
                    "CODING_IN_FRAME" => "Unknown",
                    "CODING_FRAME_SHIFT" => "Unknown",
                    "EXON_BOUNDARY" => "Unknown",
                    "FRAME_SHIFT" => "Unknown",
                    "FRAMESHIFT_DEL" => "Frame_Shift_Del",
                    "FRAME_SHIFT_DEL" => "Frame_Shift_Del",
                    "FRAMESHIFT_INS" => "Frame_Shift_Ins",
                    "FRAME_SHIFT_INS" => "Frame_Shift_Ins",
                    "INFRAME_DEL" => "In_Frame_Del",
                    "IN_FRAME_DEL" => "In_Frame_Del",
                    "INFRAME_DELETION" => "In_Frame_Del",
                    "IN_FRAME_DELETION" => "In_Frame_Del",
                    "INFRAME_INS" => "In_Frame_Ins",
                    "IN_FRAME_INS" => "In_Frame_Ins",
                    "INFRAME_INSERTION" => "In_Frame_Ins",
                    "IN_FRAME_INSERTION" => "In_Frame_Ins",
                    "MISSENSE_MUTATION" => "Missense_Mutation",
                    "MISSENSE" => "Missense_Mutation",
                    "NON_SENSE_MUTATION" => "Nonsense_Mutation",
                    "NONSENSE_MUTATION" => "Nonsense_Mutation",
                    "NONSENSE" => "Nonsense_Mutation",
                    "REFERENCE" => "Unknown",
                    "SILENT" => "Silent",
                    "SILENT_MUTATION" => "Silent",
                    "SPLICE_REGION" => "Unknown",
                    "SPLICE_REGION_SNP" => "Unknown",
                    "SPLICE_SITE" => "Splice_Site",
                    "SPLICE_SITE_INDEL" => "Splice_Site_Indel",
                    "SPLICE_SITE_SNP" => "Splice_Site_SNP",
                    "SPLICE_SITE_MUTATION" => "Unknown",
                    "SYNONYMOUS" => "Silent",
                    "TARGETED_REGION" => "Targeted_Region",
                    "UNKNOWN" => "Unknown"
  }

  VerificationStatusHash  =  {
                    "VALID" => "Valid",
                    "WILDTYPE" => "Wildtype",
                    "GERMLINE" => "Valid",
                    "Somatic" => "Valid",
                    "UNKNOWN" => "Unknown"
  }

  ValidationStatusHash  =  {
                    "VALID" => "Valid",
                    "WILDTYPE" => "Wildtype",
                    "UNKNOWN" => "Unknown",
                    "ALLELEMISMATCH" => "Valid"
  }

  MutationStatusHash  =  {
                    "GERMLINE" => "Germline",
                    "LOH" => "LOH",
                    "SOMATIC" => "Somatic",
                    "SOMATIC, HETEROZYGOUS" => "Somatic",
                    "SOMATIC, HOMOZYGOUS" => "Somatic",
                    "UNKNOWN" => "Unknown",
                    "NONE" => "None"
  }
  
  CurrentBuild = 35.9
  
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
      elsif(aa[5].nil?)
        aa[5] = "0"
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

class AmpliconSequencingFile

  attr_accessor :ampliconId, :samples, :length, :sequence, :oneXCoverage, :twoXCoverage, :oneXCoverageArray, :twoXCoverageArray,
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
    @ampliconId, @sequence, @oneXCoverage, @twoXCoverage, @oneXCoverageArray, @sequenceArray, @twoXCoverageArray = nil
    @samples, @length, @oneXCoverageSize, @twoXCoverageSize = 0
    @currentLine = line
    @errorLevel = 0

    @errorLevel = 3 if(line.nil? or line.empty?)
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @ampliconId = aa[0].chomp if(!aa[0].nil?)
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

      if(@ampliconId.nil? || @ampliconId.length < 1)
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
    
      if(@twoXCoverage.nil? || @twoXCoverage.length < 1 || @twoXCoverageSize < 1)
        @errorLevel =  26
        return
      end
      
           
      if(@twoXCoverageSize != @length)
        @errorLevel =  27
        return
      end 
      
    end
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

      #id = SHA1 name
      #00 = hugoSymbol
      #01 = entrezGeneId
      #02 = center
      #03 = ncbiBuild
      #04 = chromosome
      #05 = start
      #06 = stop
      #07 = strand
      #08 = variantClassification
      #09 = variantType
      #10 = referenceAllele
      #11 = tumorSeqAllele1
      #12 = tumorSeqAllele2
      #13 = dbSNPRS
      #14 = dbSNPValStatus 
      #15 = tumor_Sample_Barcode
      #16 = matched_Norm_Sample_Barcode
      #17 = matchNormSeqAllele1
      #18 = matchNormSeqAllele2
      #19 = tumorValidationAllele1
      #20 = tumorValidationAllele2
      #21 = matchNormValidationAllele1
      #22 = matchNormValidationAllele2 
      #23 = verificationStatus
      #24 = validationStatus
      #25 = mutationStatus
      #26 = sequencing_Phase
      #27 = mutation_id

class MutationFile
  attr_accessor :hugoSymbol, :entrezGeneId, :center, :ncbiBuild, :chromosome, :start, :stop, :strand,
  :variantClassification, :variantType, :referenceAllele, :tumorSeqAllele1, :tumorSeqAllele2,
  :dbSNPRS, :dbSNPValStatus, :sampleId, :matchNormSeqAllele1, :matchNormSeqAllele2, :novelMutation,
  :tumorValidationAllele1, :tumorValidationAllele2, :matchNormValidationAllele1, :SequencingPhase,
  :matchNormValidationAllele2, :verificationStatus, :validationStatus, :mutationStatus, :mutationId
  attr_accessor :errorLevel, :currentLine, :id, :tumor_Sample_Barcode, :matched_Norm_Sample_Barcode

#  ExpectedLineLength = 25 
  ExpectedLineLength = 28


  def initialize(line)
    @id, @hugoSymbol, @center, @ncbiBuild, @chromosome, @strand = nil
    @variantClassification, @variantType, @referenceAllele, @tumorSeqAllele1, @tumorSeqAllele = nil
    @dbSNPRS, @dbSNPValStatus, @matchNormSeqAllele1, @matchNormSeqAllele2, @mutationId = nil
    @tumorValidationAllele1, @tumorValidationAllele2, @matchNormValidationAllele1 = nil
    @matchNormValidationAllele2, @verificationStatus, @validationStatus, @mutationStatus = nil
    @tumor_Sample_Barcode, @matched_Norm_Sample_Barcode = nil, @novelMutation = false
    @entrezGeneId, @start, @stop = 0
    @currentLine = line
    @SequencingPhase = nil
    @errorLevel = 0

    @errorLevel = 3 if(line.nil? or line.empty?)
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @id = SHA1.new(line).to_s
      @hugoSymbol = aa[0].chomp if(!aa[0].nil?)
      @entrezGeneId = aa[1].chomp.to_i if(!aa[1].nil?)
      if(!aa[2].nil?)
        tempCenter = aa[2].chomp
        @center = Constants::CenterHash[tempCenter]
      end
      @center = "Unknown" if(@center.nil?)

      @ncbiBuild = aa[3].to_f if(!aa[3].nil?)
      @chromosome = aa[4].chomp if(!aa[4].nil?)
      @start = aa[5].chomp.to_i if(!aa[5].nil?)
      @stop = aa[6].chomp.to_i if(!aa[6].nil?)
      @strand = aa[7].chomp if(!aa[7].nil?)
      if(!aa[8].nil?)
        tempVariantClassification = aa[8].chomp
        tempVariantClassification.upcase! if(!tempVariantClassification.nil? and tempVariantClassification.length > 1)
        @variantClassification = Constants::VariantClassificationHash[tempVariantClassification]
      end
      @variantClassification = "Unknown" if(@variantClassification.nil?)

      if(!aa[9].nil? and aa[9].length > 0)
         tempVariantType = aa[9].chomp
         tempVariantType.upcase! if(!tempVariantType.nil? and tempVariantType.length > 1)
         @variantType = Constants::VariantTypeHash[tempVariantType]
      end
      @variantType = "Unknown" if(@variantType.nil?)
      
      if(@variantClassification == 'Splice_Site')
       if( @variantType == 'SNP')
         @variantClassification = 'Splice_Site_SNP'
       elsif(@variantType == 'Ins' or @variantType == 'Del')
         @variantClassification = 'Splice_Site_Indel'
       else
         @variantClassification = 'Unknown'
       end
      end
      
      
      @referenceAllele = aa[10].chomp if(!aa[10].nil?)
      @tumorSeqAllele1 = aa[11].chomp if(!aa[11].nil?)
      @tumorSeqAllele2 = aa[12].chomp if(!aa[12].nil?)

      
      if(!aa[13].nil? and aa[13].length > 0)
        @dbSNPRS = aa[13].chomp
        @dbSNPRS = "Unknown" if(@dbSNPRS == "0")
      else
        @dbSNPRS = "Unknown"
      end
      
      @novelMutation = true if(@dbSNPRS == "Unknown" or @dbSNPRS.downcase == "novel")
      
      
      if(!aa[14].nil?)
        @dbSNPValStatus = "Unknown"
      else
        @dbSNPValStatus = aa[14].chomp
        if(@dbSNPValStatus.nil? or @dbSNPValStatus.length < 1)
          @dbSNPValStatus = "Unknown"
        end
      end
      
      @tumor_Sample_Barcode = aa[15].chomp if(!aa[15].nil? and aa[15] !~ /null/i)
      @matched_Norm_Sample_Barcode = aa[16].chomp if(!aa[16].nil? and aa[16] !~ /null/i)
      @matchNormSeqAllele1 = aa[17].chomp if(!aa[17].nil? and aa[17] !~ /null/i)
      @matchNormSeqAllele2 = aa[18].chomp if(!aa[18].nil? and aa[18] !~ /null/i)
      @tumorValidationAllele1 = aa[19].chomp if(!aa[19].nil? and aa[19] !~ /null/i)
      @tumorValidationAllele2 = aa[20].chomp if(!aa[20].nil? and aa[20] !~ /null/i)
      @matchNormValidationAllele1 = aa[21].chomp if(!aa[21].nil? and aa[21] !~ /null/i)
      @matchNormValidationAllele2 = aa[22].chomp if(!aa[22].nil? and aa[22] !~ /null/i)

      if(!aa[23].nil?)
        tempVerificationStatus = aa[23].chomp
        tempVerificationStatus.upcase! if(!tempVerificationStatus.nil? and tempVerificationStatus.length > 0)
        @verificationStatus = Constants::VerificationStatusHash[tempVerificationStatus] 
      end 
      @verificationStatus = "Unknown" if(@verificationStatus.nil?)
      
      if(!aa[24].nil?)
        tempValidationStatus = aa[24].chomp
        tempValidationStatus.upcase! if(!tempValidationStatus.nil? and tempValidationStatus.length > 0)
        @validationStatus = Constants::ValidationStatusHash[tempValidationStatus]
      end
      @validationStatus = "Unknown" if(@validationStatus.nil?)
      
      if(!aa[25].nil?)
        tempMutationStatus = aa[25].chomp
        tempMutationStatus.upcase! if(!tempMutationStatus.nil? and tempMutationStatus.length > 0)
        @mutationStatus = Constants::MutationStatusHash[tempMutationStatus]
      end
      @mutationStatus = "Unknown" if(@mutationStatus.nil?)
 
      if(!aa[26].nil?)
        tempSequencingPhase = aa[26].chomp
        tempSequencingPhase.upcase! if(!tempSequencingPhase.nil? and tempSequencingPhase.length > 0)
        @SequencingPhase = Constants::SequencingPhaseHash[tempSequencingPhase]
      end


#      if(!aa[27].nil?)
#        @id = aa[26].chomp
#        @mutationId = aa[26].chomp
#      end



      lineLength = aa.length
    end
    validate(line, lineLength)
  end
 
  def validate(line, lineLength)

      if(lineLength > ExpectedLineLength) # || lineLength < ExpectedLineLength)
        if(lineLength > ExpectedLineLength)
          @errorLevel = 4
#        else
#          @errorLevel = 5
        end
        return
      end
      
      if(@hugoSymbol.nil? || @hugoSymbol.length < 1)
        @hugoSymbol = "Unknown"
#        @errorLevel =  32
#        return
      end

      if(@entrezGeneId < 0 )
        @errorLevel = 2
        return
      end
      
      if(@center.nil? || @center.length < 1)
        @errorLevel =  33
        return
      end
      
      if(!Constants::CenterHash.has_key?(@center))
          @errorLevel =  34
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
    
      if(@start > chromosomeLength || @stop > chromosomeLength)
        @errorLevel = 11
        return
      end
      
      if(@start < 1 || @stop < 1)
        @errorLevel = 12
        return
      end
      @chromosome = "chr#{@chromosome.upcase}"
      
    
      if(@strand.nil? || @strand.length < 1)
          @errorLevel = 35
          return
      end
      
      if(!Constants::StandHash.has_key?(@strand))
          @errorLevel =  36
          return
      end

      if(@variantClassification.nil? || @variantClassification.length < 1)
          @errorLevel = 37
          return
      end
      
      if(!Constants::VariantClassificationHash.has_key?(@variantClassification.upcase))
          @errorLevel =  38
          return
      end

      if(@variantType.nil? || @variantType.length < 1)
          @errorLevel = 39
          return
      end
      
      if(!Constants::VariantTypeHash.has_key?(@variantType.upcase))
          @errorLevel =  40
          return
      end 

      if(@referenceAllele.nil? || @referenceAllele.length < 1)
          @errorLevel = 41
          return
      end
      
      if(@tumorSeqAllele1.nil? || @tumorSeqAllele1.length < 1)
          @errorLevel = 42
          return
      end

      if(@tumorSeqAllele2.nil? || @tumorSeqAllele2.length < 1)
          @errorLevel = 43
          return
      end
      
      if(@dbSNPRS.nil? || @dbSNPRS.length < 1)
          @errorLevel = 44
          return
      end
      
      if(@dbSNPValStatus.nil? || @dbSNPValStatus.length < 1)
          @errorLevel = 45
          return
      end

      
      #if(@matchNormSeqAllele1.nil? || @matchNormSeqAllele1.length < 1)
      #    @errorLevel = 46
      #    return
      #end

      #if(@matchNormSeqAllele2.nil? || @matchNormSeqAllele2.length < 1)
      #    @errorLevel = 47
      #    return
      #end
      #
      #if(@tumorValidationAllele1.nil? || @tumorValidationAllele1.length < 1)
      #    @errorLevel = 48
      #    return
      #end
      #
      #if(@tumorValidationAllele2.nil? || @tumorValidationAllele2.length < 1)
      #    @errorLevel = 49
      #    return
      #end

      #if(@matchNormValidationAllele1.nil? || @matchNormValidationAllele1.length < 1)
      #    @errorLevel = 50
      #    return
      #end
      
      if(@tumor_Sample_Barcode.nil? || @tumor_Sample_Barcode.length < 1)
          @errorLevel = 61
          return
      end

      if(@matched_Norm_Sample_Barcode.nil? || @matched_Norm_Sample_Barcode.length < 1)
          @errorLevel = 62
          return
      end
      

      #if(@matchNormValidationAllele2.nil? || @matchNormValidationAllele2.length < 1)
      #    @errorLevel = 51
      #    return
      #end
      
      if(@verificationStatus.nil? || @verificationStatus.length < 1)
          @errorLevel = 52
          return
      end
      
      if(!Constants::VerificationStatusHash.has_key?(@verificationStatus.upcase))
          @errorLevel =  53
          return
      end
      
      if(@validationStatus.nil? || @validationStatus.length < 1)
          @errorLevel = 54
          return
      end

      if(!Constants::ValidationStatusHash.has_key?(@validationStatus.upcase))
          @errorLevel =  55
          return
      end 
    
      if(@mutationStatus.nil? || @mutationStatus.length < 1)
          @errorLevel = 56
          return
      end
      
      if(!Constants::MutationStatusHash.has_key?(@mutationStatus.upcase))
          @errorLevel =  57
          return
      end 
      
  end
  
    def returnErrorMessage(errLev)
      if(errLev == 9)
          chromosomeValues = Constants::ChromosomeHash.keys.sort.join(",")
          errorString = "The chromosome #{@chromosome} #{Constants::ErrorLevelHash[errLev]} #{chromosomeValues}"
          return errorString
      elsif(errLev == 4 or errLev == 5 )
          errorString = "#{Constants::ErrorLevelHash[errLev]} = #{@currentLine}"
          return errorString
      elsif(errLev == 11)
         errorString = "#{Constants::ErrorLevelHash[errLev]} chromosome #{@chromosome} is #{Constants::ChromosomeHash[@chromosome]} and you are providing start = #{@start} and stop = #{@stop}"
         return errorString      
      elsif(errLev == 36)
        strandValues = Constants::StandHash.keys.sort.join(",")
        errorString = "The strand #{@strand} #{Constants::ErrorLevelHash[errLev]} #{strandValues}"
        return errorString
      elsif(errLev == 38)
        variantClassificationValues = Constants::VariantClassificationHash.keys.sort.join(",")
        errorString = "The variantClassification #{@variantClassification} #{Constants::ErrorLevelHash[errLev]} #{variantClassificationValues}"
        return errorString
      elsif(errLev == 40)
        variantTypeValues = Constants::VariantTypeHash.keys.sort.join(",")
        errorString = "The variantType #{@variantType} #{Constants::ErrorLevelHash[errLev]} #{variantTypeValues}"
        return errorString
      elsif(errLev == 53)
        verificationStatusValues = Constants::VerificationStatusHash.keys.sort.join(",")
        errorString = "The verificationStatus #{@verificationStatus} #{Constants::ErrorLevelHash[errLev]} #{verificationStatusValues}"
        return errorString
      elsif(errLev == 55)
        validationStatusValues = Constants::ValidationStatusHash.keys.sort.join(",")
        errorString = "The validationStatus #{@validationStatus} #{Constants::ErrorLevelHash[errLev]} #{validationStatusValues}"
        return errorString
      elsif(errLev == 57)
        mutationStatusValues = Constants::MutationStatusHash.keys.sort.join(",")
        errorString = "The mutationStatus #{@mutationStatus} #{Constants::ErrorLevelHash[errLev]} #{mutationStatusValues}"
        return errorString
      else
        return "#{Constants::ErrorLevelHash[errLev]}"
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
        @primer_frwStop = (@start + @primer_frwSize) -1
        @primer_fwOr = "+"
      end
      
      if(!aa[6].nil?)
        @primer_rv = aa[6].chomp
        @primer_rvSize = @primer_rv.length 
        @primer_rvStart = (@stop - @primer_rvSize) + 1
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





end; end; end #namespace
