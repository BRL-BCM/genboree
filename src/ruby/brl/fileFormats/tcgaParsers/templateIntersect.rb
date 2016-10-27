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
require 'interval' # Implements Interval arithmetic!!!
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


class IntersectTracksChangeNamesWrapper

   def self.intersectTracksChangeNamesWrapper(optsHash)
    #--targetFile --queryFile --fileWithExtractedGenes --className --typeName --subTypeName
    methodName = "extractGenesInsideLocusWrapper"
    targetFile = nil 
    queryFile = nil
    fileWithExtractedGenes = nil
    className = nil
    typeName = nil
    subTypeName = nil


    targetFile = optsHash['--targetFile'] if( optsHash.key?('--targetFile') )
    queryFile = optsHash['--queryFile'] if( optsHash.key?('--queryFile') )
    fileWithExtractedGenes = optsHash['--fileWithExtractedGenes'] if( optsHash.key?('--fileWithExtractedGenes') )
    className = optsHash['--className'] if( optsHash.key?('--className') )
    typeName = optsHash['--typeName'] if( optsHash.key?('--typeName') )
    subTypeName = optsHash['--subTypeName'] if( optsHash.key?('--subTypeName') )


    if(targetFile.nil? || queryFile.nil? || fileWithExtractedGenes.nil? )
      $stderr.print "Error missing parameters in method #{methodName} --targetFile=#{targetFile} --queryFile=#{queryFile} "
      $stderr.print "--className=#{className} --typeName=#{typeName} --subTypeName=#{subTypeName}"
      $stderr.puts " --fileWithExtractedGenes=#{fileWithExtractedGenes}"
      return
    end

    mapping = IntersectTracksChangeNames.new(targetFile, queryFile, fileWithExtractedGenes, className, typeName, subTypeName)
    mapping.execute()

  end
   
  
end
end; end; end #namespace

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



#Generating Mapping Files
    #--targetFile --queryFile --fileWithExtractedGenes --className --typeName --subTypeName
BRL::FileFormats::TCGAParsers::IntersectTracksChangeNamesWrapper.intersectTracksChangeNamesWrapper(optsHash)


