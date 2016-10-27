#!/usr/bin/env ruby
$VERBOSE = nil

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
module BRL ; module Genboree; module Pipelines; module Acgh; module Applications

class MapFiles



   
   def self.lffFilesToTable(optsHash)
    #--fileWithQueries --fileWithTargets --tabDelimitedFileName --fileWithNoHits --fileWithMultipleHits --outPutFileName
    methodName = "lffFilesToTable"
    fileWithTargets = nil 
    fileWithQueries = nil
    tabDelimitedFileName = nil
    fileWithNoHits = "nohits.txt"
    fileWithMultipleHits = "multihits.txt"
    outPutFileName      =  nil

    fileWithTargets = optsHash['--fileWithTargets'] if( optsHash.key?('--fileWithTargets') )
    fileWithQueries = optsHash['--fileWithQueries'] if( optsHash.key?('--fileWithQueries') )
    tabDelimitedFileName = optsHash['--tabDelimitedFileName'] if( optsHash.key?('--tabDelimitedFileName') )
    outPutFileName =  optsHash['--outPutFileName'] if( optsHash.key?('--outPutFileName') ) 
    title ="#Segment\tnameOfGenesAffected"

    if(fileWithTargets.nil? || fileWithQueries.nil? || tabDelimitedFileName.nil? ||  outPutFileName.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts " --fileWithTargets=#{fileWithTargets}"
      $stderr.puts " --fileWithQueries=#{fileWithQueries}"
      $stderr.puts " --tabDelimitedFileName=#{tabDelimitedFileName}"
      $stderr.puts "--outPutFileName=#{outPutFileName}"
      return
    end

    mapping = BRL::FileFormats::TCGAParsers::GenerateMappingFile.new(fileWithTargets, fileWithQueries,  "some", "thing", ".", tabDelimitedFileName, fileWithNoHits, fileWithMultipleHits, title )
    mapping.execute()
    avps = BRL::FileFormats::TCGAParsers::AddCommaSeparatedVptoLffFromTabDelimitedFile.new(tabDelimitedFileName, fileWithQueries, outPutFileName)
    avps.execute()
    
    File.delete(fileWithNoHits)
    File.delete(fileWithMultipleHits)
    File.delete(tabDelimitedFileName)
    

  end 
   
 
end
end; end; end; end; end #namespace



optsHash = Hash.new {|hh,kk| hh[kk] = 0}
numberOfArgs = ARGV.size
i = 0
while i < numberOfArgs
	key = "''"
	value = "''"
	key = ARGV[i] if( !ARGV[i].nil? )
	value =  ARGV[i + 1]  if( !ARGV[i + 1].nil? )
	optsHash[key] = value
	i += 2
end

#--fileWithQueries --fileWithTargets --tabDelimitedFileName --fileWithNoHits --fileWithMultipleHits --outPutFileName
BRL::Genboree::Pipelines::Acgh::Applications::MapFiles.lffFilesToTable(optsHash)

