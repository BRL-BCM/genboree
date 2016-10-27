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

class Validator


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
    sampleHash = TableToHashCreator.sampleIdToSampleTableHash(sampleFileName)
    $stderr.puts "number of well formatted records #{sampleHash.length}"
    $stderr.puts "-------------------- END OF Sample File Validation -------------------------------------------"


    $stderr.puts "-------------------- START OF Amplicon File Validation -------------------------------------------"
    ampliconHash = TableToHashCreator.ampliconIdToAmpliconTableHash(ampliconFileName)
    $stderr.puts "number of well formatted records #{ampliconHash.length}"
    $stderr.puts "-------------------- END OF Amplicon File Validation -------------------------------------------"
      
    $stderr.puts "-------------------- START OF ROI File Validation -------------------------------------------"
    roiHash = TableToHashCreator.roiIdToHash(roiFileName)
    $stderr.puts "number of well formatted records #{roiHash.length}"
    $stderr.puts "-------------------- END OF ROI File Validation -------------------------------------------"
 
    $stderr.puts "-------------------- START OF Roi Sequencing File Validation -------------------------------------------"
    roiSequencingHash = TableToHashCreator.roiIdToRoiSequencingTableHash(roiSequencingFileName, sampleHash.length, roiHash)
    $stderr.puts "number of well formatted records #{roiSequencingHash.length}" if(!roiSequencingHash.nil?)
    $stderr.puts "-------------------- END OF Roi Sequencing File Validation -------------------------------------------"

    $stderr.puts "-------------------- START OF Sample Sequencing File Validation -------------------------------------------"
    sampleSequencingHash = TableToHashCreator.lightSampleSequencingToHash(sampleSequencingFileName, ampliconHash, sampleHash)
    $stderr.puts "number of well formatted records #{sampleSequencingHash.length}" if(!sampleSequencingHash.nil?)
    $stderr.puts "-------------------- END OF Sample Sequencing File Validation -------------------------------------------"
  end



  def self.validateAmpliconSequencingFile(optsHash)
    ampliconSequencingFile = nil
    ampliconSequencingFile = optsHash['--ampliconSequencingFile'] if( optsHash.key?('--ampliconSequencingFile') )

    if( ampliconSequencingFile.nil? )
      puts "Error missing parameters in method validateAmpliconSequencingFile --ampliconSequencingFile=#{ampliconSequencingFile} "
      return
    end
 
      puts "-------------------- START OF Amplicon Sequencing File Validation -------------------------------------------"
      ampliconSequencingHash = TableToHashCreator.ampliconIdToAmpliconSequencingTableHash(ampliconSequencingFile)
      puts "number of well formatted records #{ampliconSequencingHash.length}"
      puts "-------------------- END OF Amplicon Sequencing File Validation -------------------------------------------"
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

  puts "#{key} == #{value}" if(!key.nil?)
  }



#Validators
#--roiFileName --sampleFileName --ampliconFileName --sampleSequencingFileName --roiSequencingFileName --ampliconSequencingFile
BRL::FileFormats::TCGAParsers::Validator.validateFiles(optsHash)
#BRL::FileFormats::TCGAParsers::Validator.validateAmpliconSequencingFile(optsHash) #--ampliconSequencingFile

