#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Few Static variables required to validate the files and describe errors

# ##############################################################################
# CONSTANTS
# ##############################################################################



module BRL ; module FileFormats; module Validators; module TcgaFiles

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


        
end; end; end; end;
