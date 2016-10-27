#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# A wrapper to validate tcga files

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################

require 'brl/fileFormats/validators/tcgaFiles/constants'
require 'brl/fileFormats/validators/tcgaFiles/formatReader'
require 'brl/fileFormats/validators/tcgaFiles/filesToHash'





module BRL ; module FileFormats; module Validators; module TcgaFiles



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
    sampleHash = FilesToHash.sampleIdToSampleTableHash(sampleFileName)
    $stderr.puts "number of well formatted records #{sampleHash.length}"
    $stderr.puts "-------------------- END OF Sample File Validation -------------------------------------------"


    $stderr.puts "-------------------- START OF Amplicon File Validation -------------------------------------------"
    ampliconHash = FilesToHash.ampliconIdToAmpliconTableHash(ampliconFileName)
    $stderr.puts "number of well formatted records #{ampliconHash.length}"
    $stderr.puts "-------------------- END OF Amplicon File Validation -------------------------------------------"
      
    $stderr.puts "-------------------- START OF ROI File Validation -------------------------------------------"
    roiHash = FilesToHash.roiIdToHash(roiFileName)
    $stderr.puts "number of well formatted records #{roiHash.length}"
    $stderr.puts "-------------------- END OF ROI File Validation -------------------------------------------"
 
    $stderr.puts "-------------------- START OF Roi Sequencing File Validation -------------------------------------------"
    roiSequencingHash = FilesToHash.roiIdToRoiSequencingTableHash(roiSequencingFileName, sampleHash.length, roiHash)
    $stderr.puts "number of well formatted records #{roiSequencingHash.length}" if(!roiSequencingHash.nil?)
    $stderr.puts "-------------------- END OF Roi Sequencing File Validation -------------------------------------------"

    $stderr.puts "-------------------- START OF Sample Sequencing File Validation -------------------------------------------"
    sampleSequencingHash = FilesToHash.sampleSequencingToHash(sampleSequencingFileName, ampliconHash, sampleHash)
    $stderr.puts "number of well formatted records #{sampleSequencingHash.length}" if(!sampleSequencingHash.nil?)
    $stderr.puts "-------------------- END OF Sample Sequencing File Validation -------------------------------------------"
  end
  
end

end; end; end; end;


