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

class LffGenerator

  def self.testRoiToLff(optsHash)
    #--roiFileName --type --roiSubtype  --roiClassName --roiLffFileName
    methodName = "testRoiToLff"
    roiFileName =  nil 
    type = nil        
    roiSubtype =  nil  
    roiClassName =  nil
    roiLffFileName = nil
    
    roiFileName =    optsHash['--roiFileName'] if( optsHash.key?('--roiFileName') )
    type =           optsHash['--type'] if( optsHash.key?('--type') )
    roiSubtype =     optsHash['--roiSubtype'] if( optsHash.key?('--roiSubtype') )
    roiClassName =   optsHash['--roiClassName'] if( optsHash.key?('--roiClassName') )
    roiLffFileName = optsHash['--roiLffFileName'] if( optsHash.key?('--roiLffFileName') )
    
    if( roiFileName.nil? || type.nil? || roiSubtype.nil? ||  roiClassName.nil? || roiLffFileName.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--roiFileName=#{roiFileName}"
      $stderr.puts "--type=#{type}"
      $stderr.puts "--roiSubtype=#{roiSubtype}"
      $stderr.puts "--roiClassName=#{roiClassName}"
      $stderr.puts "--roiLffFileName=#{roiLffFileName}"
      return
    end

    TableToHashCreator.roiIdToLff(roiFileName, roiLffFileName, roiClassName, type, roiSubtype)
  end
  
  
  def self.testAmpliconIdToLff(optsHash)
    #--ampliconFile  --type --ampliconSubtype --ampliconClassName --ampliconLffFileName
    methodName = "testAmpliconIdToLff"
    ampliconFileName    = nil
    type                = nil
    ampliconSubtype     = nil
    ampliconClassName   = nil
    ampliconLffFileName = nil
    
    ampliconFileName    = optsHash['--ampliconFileName']    if( optsHash.key?('--ampliconFileName') )   
    type                = optsHash['--type']                if( optsHash.key?('--type') )                  
    ampliconSubtype     = optsHash['--ampliconSubtype']     if( optsHash.key?('--ampliconSubtype') )          
    ampliconClassName   = optsHash['--ampliconClassName']   if( optsHash.key?('--ampliconClassName') )   
    ampliconLffFileName = optsHash['--ampliconLffFileName'] if( optsHash.key?('--ampliconLffFileName') )
    
    if( ampliconFileName.nil? || type.nil? || ampliconSubtype.nil? || ampliconClassName.nil? || ampliconLffFileName.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--ampliconFileName=#{ampliconFileName}"
      $stderr.puts "--type=#{type}"
      $stderr.puts "--ampliconSubtype=#{ampliconSubtype}"
      $stderr.puts "--ampliconClassName=#{ampliconClassName}"
      $stderr.puts "--ampliconLffFileName=#{ampliconLffFileName}"
      return
    end


    TableToHashCreator.ampliconIdToLff(ampliconFileName, ampliconLffFileName, ampliconClassName, type, ampliconSubtype)
  end  

  def self.testAmpliconIdToPrimerLff(optsHash)
    #--ampliconFileName  --type --primerSubtype --primerClassName --primerLffFileName
    methodName = "testAmpliconIdToPrimerLff"
    ampliconFileName  = nil
    type              = nil
    primerSubtype     = nil
    primerClassName   = nil
    primerLffFileName = nil

    ampliconFileName  = optsHash['--ampliconFileName']       if( optsHash.key?('--ampliconFileName') )
    type              = optsHash['--type']                   if( optsHash.key?('--type') )
    primerSubtype     = optsHash['--primerSubtype']          if( optsHash.key?('--primerSubtype') )
    primerClassName   = optsHash['--primerClassName']        if( optsHash.key?('--primerClassName') )
    primerLffFileName = optsHash['--primerLffFileName']      if( optsHash.key?('--primerLffFileName') )
    
    if( ampliconFileName.nil? || type.nil? || primerSubtype.nil? || primerClassName.nil? || primerLffFileName.nil? )
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--ampliconFileName=#{ampliconFileName}"
      $stderr.puts "--type=#{type}"
      $stderr.puts "--primerSubtype=#{primerSubtype}"
      $stderr.puts "--primerClassName=#{primerClassName}"
      $stderr.puts "--primerLffFileName=#{primerLffFileName}"
      return
    end


    TableToHashCreator.ampliconIdToPrimersLff(ampliconFileName, primerLffFileName, primerClassName, type, primerSubtype)
  end  

  def self.testAmpliconSequencingFileToLff(optsHash)
#--ampliconSequencingFileName   --ampliconFileName  --type  --ampliconSeqclassName --ampliconSeqLffFileName
    methodName = "testAmpliconSequencingFileToLff"
    ampliconSequencingFileName = nil
    ampliconFileName  = nil
    type  = nil
    ampliconSeqclassName = nil
    ampliconSeqLffFileName = nil
    
    ampliconSequencingFileName = optsHash['--ampliconSequencingFileName'] if( optsHash.key?('--ampliconSequencingFileName') )
    ampliconFileName  = optsHash['--ampliconFileName']       if( optsHash.key?('--ampliconFileName') )
    type  = optsHash['--type'] if( optsHash.key?('--type') )
    ampliconSeqclassName = optsHash['--ampliconSeqclassName'] if( optsHash.key?('--ampliconSeqclassName') )
    ampliconSeqLffFileName = optsHash['--ampliconSeqLffFileName'] if( optsHash.key?('--ampliconSeqLffFileName') )


    if( ampliconFileName.nil? || ampliconSequencingFileName.nil? || ampliconSeqLffFileName.nil? || type.nil? || ampliconSeqclassName.nil? )
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--ampliconFileName=#{ampliconFileName}"
        $stderr.puts "--ampliconSequencingFileName=#{ampliconSequencingFileName}"
        $stderr.puts "--ampliconSeqLffFileName=#{ampliconSeqLffFileName}"
        $stderr.puts "--type=#{type}"
        $stderr.puts "--ampliconSeqclassName=#{ampliconSeqclassName}"
        return
    end 
    
    TableToHashCreator.ampliconSequencingFileToLff(ampliconFileName, ampliconSeqLffFileName ,ampliconSequencingFileName, ampliconSeqclassName, type)
  end

 

  def self.testRoiSequencingFileToLff(optsHash)
    #--roiFileName --roiSequencingFileName --type --roiSeqclassName --roiSequencingLffFileName
    methodName = "testRoiSequencingFileToLff"
    roiFileName                = nil            
    roiSequencingLffFileName   = nil
    roiSequencingFileName      =  nil
    type                       =  nil                 
    roiSeqclassName            = nil                 
    
    roiFileName =                 optsHash['--roiFileName']               if( optsHash.key?('--roiFileName') )                     
    roiSequencingLffFileName =    optsHash['--roiSequencingLffFileName']  if( optsHash.key?('--roiSequencingLffFileName') )     
    roiSequencingFileName =       optsHash['--roiSequencingFileName']     if( optsHash.key?('--roiSequencingFileName') )        
    type =                        optsHash['--type']                      if( optsHash.key?('--type') )                    
    roiSeqclassName =             optsHash['--roiSeqclassName']           if( optsHash.key?('--roiSeqclassName') )
    
    if( roiFileName.nil? || roiSequencingLffFileName.nil? || roiSequencingFileName.nil? || type.nil? || roiSeqclassName.nil? )
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--roiFileName=#{roiFileName}"
        $stderr.puts "--roiSequencingLffFileName=#{roiSequencingLffFileName}"
        $stderr.puts "--roiSequencingFileName=#{roiSequencingFileName}"
        $stderr.puts "--type=#{type}"
        $stderr.puts "--roiSeqclassName=#{roiSeqclassName}"
        return
    end
    
    TableToHashCreator.roiSequencingFileToLff(roiFileName, roiSequencingLffFileName, roiSequencingFileName, roiSeqclassName, type)
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
optsHash[ARGV[34]] = ARGV[35]
optsHash[ARGV[36]] = ARGV[37]
optsHash[ARGV[38]] = ARGV[39]
optsHash[ARGV[40]] = ARGV[41]

optsHash.each {|key, value|

  $stderr.puts "#{key} == #{value}" if(!key.nil?)
  }





#lff Generators
# --type --ampliconSubtype  --ampliconClassName --ampliconLffFileName
#--ampliconFileName --primerSubtype  --primerClassName --primerLffFileName
#--roiFileName --type --roiSubtype  --roiClassName --roiLffFileName
#--roiSequencingFileName --roiSeqclassName --roiSequencingLffFileName

#--ampliconFile  --type --ampliconSubtype --ampliconClassName --ampliconLffFileName
BRL::FileFormats::TCGAParsers::LffGenerator.testAmpliconIdToLff(optsHash)
#--ampliconFileName  --type --primerSubtype --primerClassName --primerLffFileName
BRL::FileFormats::TCGAParsers::LffGenerator.testAmpliconIdToPrimerLff(optsHash)
#--roiFileName --type --roiSubtype  --roiClassName --roiLffFileName
BRL::FileFormats::TCGAParsers::LffGenerator.testRoiToLff(optsHash)
#--roiFileName --roiSequencingFileName --type --roiSeqclassName --roiSequencingLffFileName
BRL::FileFormats::TCGAParsers::LffGenerator.testRoiSequencingFileToLff(optsHash)
BRL::FileFormats::TCGAParsers::LffGenerator.testAmpliconSequencingFileToLff(optsHash)
#example of command
# ~/brl/fileFormats/tcgaParsers/lffGenerator.rb --ampliconFileName Cancer_Platform_TCGA_Amplicon.txt.gz --type Broad --ampliconSubtype amplicon --ampliconClassName "Broad Report Data" --ampliconLffFileName amp2.lff --primerSubtype primer --primerClassName "Broad Report Data" --primerLffFileName prim2.lff --roiFileName Cancer_Platform_TCGA_ROI.txt.gz --roiSubtype roi --roiClassName "Broad Report Data" --roiLffFileName roi2.lff --roiSequencingLffFileName roiSeq2.lff --roiSequencingFileName Cancer_Platform_TCGA_ROI_Sequence.txt.gz --roiSeqclassName "Broad Report Data"
#--ampliconSequencingFileName   --ampliconFileName  --type  --ampliconSeqclassName --ampliconSeqLffFileName
