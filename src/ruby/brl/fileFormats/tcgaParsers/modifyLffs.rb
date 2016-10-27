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

class ModifyLffs

  def self.testAddVptoLffFromTabDelimitedFile(optsHash)
#--tabDelimitedFileName  --lffFileName --outPutFileName
    methodName = "testRoiSequencingFileToLff"
    tabDelimitedFileName  = nil            
    lffFileName   = nil
    outPutFileName      =  nil
    
    tabDelimitedFileName =  optsHash['--tabDelimitedFileName'] if( optsHash.key?('--tabDelimitedFileName') )                     
    lffFileName =    optsHash['--lffFileName']  if( optsHash.key?('--lffFileName') )     
    outPutFileName =  optsHash['--outPutFileName'] if( optsHash.key?('--outPutFileName') )        
    
    if( tabDelimitedFileName.nil? || lffFileName.nil? || outPutFileName.nil? )
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--tabDelimitedFileName=#{tabDelimitedFileName}"
        $stderr.puts "--lffFileName=#{lffFileName}"
        $stderr.puts "--outPutFileName=#{outPutFileName}"
        return
    end


    mapping = AddVptoLffFromTabDelimitedFile.new(tabDelimitedFileName, lffFileName, outPutFileName)
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


#add the tabular files to the lffs as value pairs
#--tabDelimitedFileName  --lffFileName --outPutFileName
BRL::FileFormats::TCGAParsers::ModifyLffs.testAddVptoLffFromTabDelimitedFile(optsHash)



