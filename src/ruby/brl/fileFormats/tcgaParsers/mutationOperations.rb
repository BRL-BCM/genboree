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

class MutationOperations

   def self.generateMutationCompletionFile(optsHash)
#--mutationLffFileName --mutationSummaryFileName --mutationAttribute variantClassification --listOfGenes

    methodName = "generateMutationCompletionFile"
    mutationClassType = "CountMutationsVariantClassification"
    mutationAttribute = nil
    mutationLffFileName = nil
    mutationSummaryFileName = nil
    numberOfSamples = 0
    
    mutationAttribute = optsHash['--mutationAttribute'] if( optsHash.key?('--mutationAttribute') )
    mutationLffFileName = optsHash['--mutationLffFileName'] if( optsHash.key?('--mutationLffFileName') )
    mutationSummaryFileName = optsHash['--mutationSummaryFileName'] if( optsHash.key?('--mutationSummaryFileName') )
    
    
    if( mutationLffFileName.nil? || mutationSummaryFileName.nil? || mutationAttribute.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--mutationLffFileName=#{mutationLffFileName}"
      $stderr.puts "--mutationSummaryFileName=#{mutationSummaryFileName}"
      $stderr.puts "--mutationAttribute=#{mutationAttribute}"
      return
    end
    

      puts "-------------------- START OF generateMutationCompletionFile -------------------------------------------"
      stats = PerformeOperationOnLffFile.new(mutationLffFileName, mutationSummaryFileName, mutationAttribute, mutationClassType)
      stats.execute()
      puts "-------------------- END OF Sample PerformeOperationOnLffFile -------------------------------------------"
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



#Validator
BRL::FileFormats::TCGAParsers::MutationOperations.generateMutationCompletionFile(optsHash)
#--mutationFileName


