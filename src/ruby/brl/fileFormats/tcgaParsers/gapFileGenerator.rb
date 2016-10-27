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

class GapFileGenerator

  def self.generateGapsFromRoiLff(optsHash)
#--roiLffFileName --gapLffFile --attributeName --attributeThreshold --type --subtype --className
    methodName = "generateGapsFromRoiLff"
    roiLffFileName =  nil 
    gapLffFile =  nil
    attributeName = nil
    attributeThreshold = nil
    type = nil
    subtype = nil
    className = nil
    operation = "lessThan"
    maxValue = nil
    

    roiLffFileName =  optsHash['--roiLffFileName'] if(optsHash.key?('--roiLffFileName'))
    gapLffFile =    optsHash['--gapLffFile'] if(optsHash.key?('--gapLffFile'))
    attributeName = optsHash['--attributeName'] if(optsHash.key?('--attributeName'))
    attributeThreshold = optsHash['--attributeThreshold'] if(optsHash.key?('--attributeThreshold'))
    type = optsHash['--type']  if( optsHash.key?('--type') )
    subtype  = optsHash['--subtype'] if( optsHash.key?('--subtype') )
    className = optsHash['--className'] if( optsHash.key?('--className') )
    operation = optsHash['--operation'] if( optsHash.key?('--operation') )
    maxValue = optsHash['--maxValue'] if( optsHash.key?('--maxValue') )
    
    if(roiLffFileName.nil? ||  gapLffFile.nil? || attributeName.nil? || attributeThreshold.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--roiLffFileName=#{roiLffFileName}"
      $stderr.puts "--gapLffFile=#{gapLffFile}"
      $stderr.puts "--attributeName=#{attributeName}"
      $stderr.puts "--attributeThreshold=#{attributeThreshold}"
      $stderr.puts "--type=#{type}"
      $stderr.puts "--subtype=#{subtype}"
      $stderr.puts "--className=#{className}"
      $stderr.puts "--operation=#{operation} [optional]"
      $stderr.puts "--maxValue=#{maxValue} [optional]"
      return 
    end

    TableToHashCreator.filteringLffUsingNumericAttValue(roiLffFileName, gapLffFile, attributeName, attributeThreshold.to_f, operation, type, subtype, className, maxValue)

    
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




#--roiLffFileName --gapLffFile --attributeName --attributeThreshold --type --subtype --className
BRL::FileFormats::TCGAParsers::GapFileGenerator.generateGapsFromRoiLff(optsHash)


