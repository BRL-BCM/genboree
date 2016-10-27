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

class MappingFilesGenerator

  def self.testRoiSequencingFileToCoverageTable(optsHash)
    #--roiSequencingFileName --roiTableFile --sampleFileName
    methodName = "testRoiSequencingFileToCoverageTable"
    roiSequencingFileName = nil
    roiTableFile = nil
    sampleFileName  = nil
    numberOfSamples = 0
    
    sampleFileName  = optsHash['--sampleFileName'] if( optsHash.key?('--sampleFileName') )
    roiSequencingFileName = optsHash['--roiSequencingFileName'] if(optsHash.key?('--roiSequencingFileName'))
    roiTableFile = optsHash['--roiTableFile'] if(optsHash.key?('--roiTableFile'))
    numberOfSamples = optsHash['--numberOfSamples'] if(optsHash.key?('--numberOfSamples'))

    if(roiSequencingFileName.nil? || roiTableFile.nil? || sampleFileName.nil?)
      $stderr.puts "Error missing parameters in method #{methodName} --roiSequencingFileName=#{roiSequencingFileName} --roiTableFile=#{roiTableFile} --sampleFileName=#{sampleFileName} --numberOfSamples=#{numberOfSamples}"
      return
    end
 
    TableToHashCreator.roiSequencingFileToCoverageTable(roiSequencingFileName, roiTableFile, sampleFileName, numberOfSamples)
  end


  def self.testGenerateAmplicon2LociMappingFile(optsHash)
    #--ampliconLffFileName  --lociLffFileName --ampliconToLociFileName --ampliconToLociMissingFileName --ampliconToLociMultipleFileName
    methodName = "testGenerateAmplicon2LociMappingFile"
    ampliconLffFileName = nil
    lociLffFileName = nil
    ampliconToLociFileName = nil
    ampliconToLociMissingFileName = nil
    ampliconToLociMultipleFileName = nil


    ampliconLffFileName = optsHash['--ampliconLffFileName'] if( optsHash.key?('--ampliconLffFileName') )
    lociLffFileName = optsHash['--lociLffFileName'] if( optsHash.key?('--lociLffFileName') )
    ampliconToLociFileName = optsHash['--ampliconToLociFileName'] if( optsHash.key?('--ampliconToLociFileName') )
    ampliconToLociMissingFileName = optsHash['--ampliconToLociMissingFileName'] if( optsHash.key?('--ampliconToLociMissingFileName') )
    ampliconToLociMultipleFileName = optsHash['--ampliconToLociMultipleFileName']      if( optsHash.key?('--ampliconToLociMultipleFileName') )

    title ="#ampliconId\t#geneName"

    if(ampliconLffFileName.nil? || lociLffFileName.nil? || ampliconToLociFileName.nil? || ampliconToLociMissingFileName.nil? || ampliconToLociMultipleFileName.nil?)
      $stderr.print "Error missing parameters in method #{methodName} --ampliconLffFileName=#{ampliconLffFileName} --lociLffFileName=#{lociLffFileName}"
      $stderr.print " --ampliconToLociFileName=#{ampliconToLociFileName} --ampliconToLociMissingFileName=#{ampliconToLociMissingFileName}"
      $stderr.puts " --ampliconToLociMultipleFileName=#{ampliconToLociMultipleFileName}"
      return
    end
    
    mapping = GenerateMappingFile.new(lociLffFileName ,ampliconLffFileName,  "some", "thing", ".", ampliconToLociFileName, ampliconToLociMissingFileName, ampliconToLociMultipleFileName, title )
    mapping.execute()

  end


   def self.generateListOfGenesFile(optsHash)
    #--listOfGenesFileName --lociLffFileName
    methodName = "generateListOfGenesFile"
    listOfGenesFileName = nil 
    lociLffFileName = nil


    listOfGenesFileName = optsHash['--listOfGenesFileName'] if( optsHash.key?('--listOfGenesFileName') )
    lociLffFileName = optsHash['--lociLffFileName'] if( optsHash.key?('--lociLffFileName') )



    if(listOfGenesFileName.nil? || lociLffFileName.nil?)
      $stderr.puts "Error missing parameters in method #{methodName} --listOfGenesFileName=#{listOfGenesFileName} --lociLffFileName=#{lociLffFileName}"
      return
    end

    TableToHashCreator.generateListOfGenesFileFromLff(listOfGenesFileName, lociLffFileName)

  end 



 
 
   def self.testGenerateAmplicon2RoiMappingFile(optsHash)
    #--ampliconLffFileName  --roiLffFileName --ampliconToRoiFileName --ampliconToRoiMissingFileName --ampliconToRoiMultipleFileName
    methodName = "testGenerateAmplicon2RoiMappingFile"
    ampliconLffFileName = nil
    roiLffFileName = nil
    ampliconToRoiFileName = nil
    ampliconToRoiMissingFileName = nil
    ampliconToRoiMultipleFileName = nil


    ampliconLffFileName = optsHash['--ampliconLffFileName'] if( optsHash.key?('--ampliconLffFileName') ) 
    roiLffFileName = optsHash['--roiLffFileName'] if( optsHash.key?('--roiLffFileName') )
    ampliconToRoiFileName = optsHash['--ampliconToRoiFileName'] if( optsHash.key?('--ampliconToRoiFileName') )
    ampliconToRoiMissingFileName = optsHash['--ampliconToRoiMissingFileName'] if( optsHash.key?('--ampliconToRoiMissingFileName') )
    ampliconToRoiMultipleFileName = optsHash['--ampliconToRoiMultipleFileName'] if( optsHash.key?('--ampliconToRoiMultipleFileName') )

    title ="#ampliconId\t#RoiId"


    if(ampliconLffFileName.nil? || roiLffFileName.nil? || ampliconToRoiFileName.nil? || ampliconToRoiMissingFileName.nil? || ampliconToRoiMultipleFileName.nil?)
      $stderr.print "Error missing parameters in method #{methodName} --ampliconLffFileName=#{ampliconLffFileName} --roiLffFileName=#{roiLffFileName}"
      $stderr.print " --ampliconToRoiFileName=#{ampliconToRoiFileName} --ampliconToRoiMissingFileName=#{ampliconToRoiMissingFileName}"
      $stderr.puts " --ampliconToRoiMultipleFileName=#{ampliconToRoiMultipleFileName}"
      return
    end
 
    mapping = GenerateMappingFile.new(roiLffFileName ,ampliconLffFileName,  "some", "thing", ".", ampliconToRoiFileName, ampliconToRoiMissingFileName, ampliconToRoiMultipleFileName ,title)
    mapping.execute()

  end

   
   def self.testGenerateRoi2LociMappingFile(optsHash)
    #--roiLffFileName --lociLffFileName --roiToLociFileName --roiToLociMissingFileName --roiToLociMultipleFileName
    methodName = "testGenerateRoi2LociMappingFile"
    lociLffFileName = nil 
    roiLffFileName = nil
    roiToLociFileName = nil
    roiToLociMissingFileName = nil
    roiToLociMultipleFileName = nil

    lociLffFileName = optsHash['--lociLffFileName'] if( optsHash.key?('--lociLffFileName') )
    roiLffFileName = optsHash['--roiLffFileName'] if( optsHash.key?('--roiLffFileName') )
    roiToLociFileName = optsHash['--roiToLociFileName'] if( optsHash.key?('--roiToLociFileName') )
    roiToLociMissingFileName = optsHash['--roiToLociMissingFileName'] if( optsHash.key?('--roiToLociMissingFileName') )
    roiToLociMultipleFileName = optsHash['--roiToLociMultipleFileName'] if( optsHash.key?('--roiToLociMultipleFileName') )
    title ="#RoiId\tgeneName"

    if(lociLffFileName.nil? || roiLffFileName.nil? || roiToLociFileName.nil? || roiToLociMissingFileName.nil? || roiToLociMultipleFileName.nil?)
      $stderr.print "Error missing parameters in method #{methodName} --lociLffFileName=#{lociLffFileName} --roiLffFileName=#{roiLffFileName}"
      $stderr.print " --roiToLociFileName=#{roiToLociFileName} --roiToLociMissingFileName=#{roiToLociMissingFileName}"
      $stderr.puts " --roiToLociMultipleFileName=#{roiToLociMultipleFileName}"
      return
    end

    mapping = GenerateMappingFile.new(lociLffFileName, roiLffFileName,  "some", "thing", ".", roiToLociFileName, roiToLociMissingFileName, roiToLociMultipleFileName, title )
    mapping.execute()

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
#--roiLffFileName --lociLffFileName --roiToLociFileName --roiToLociMissingFileName --roiToLociMultipleFileName
BRL::FileFormats::TCGAParsers::MappingFilesGenerator.testGenerateRoi2LociMappingFile(optsHash)


