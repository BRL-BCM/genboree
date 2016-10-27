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

class MutationValidator

    def self.validateMutationTableHash(mutationFileName)
    #--mutationFileName
    errorCounter = 0
    maxNumberOfErrors = 1000
    retVal = {}
    return retVal if( mutationFileName.nil? )

    reader = BRL::Util::TextReader.new(mutationFileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/ or line =~ /^\s*Hugo_Symbol/i)
          lineCounter = lineCounter + 1
          next
        end
        
        if(errorCounter > maxNumberOfErrors)
          $stderr.puts "Too many errors in file #{mutationFileName} please fix the problems and re-submit the file!"
          return nil
        end 
        
        rg = MutationFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
            errorCounter += 1
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
            errorCounter += 1
          end
        elsif(retVal.has_key?(rg.id))
          $stderr.puts "Mutation #{rg.chromosome}.#{rg.start}.#{rg.strand}.#{rg.entrezGeneId} from line #{lineCounter} is present multiple times line skipped"
          errorCounter += 1
        else
          retVal[rg.id] = rg
        end
        lineCounter += 1
      }
      reader.close()
      puts "The number of records in file #{mutationFileName} is #{retVal.length} and the number of lines in the file are #{lineCounter}"

    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end



  def self.validateMutationFile(optsHash)
    #--mutationFileName

    methodName = "validateMutationFile"
    tabDelimitedFileName =  nil 

    mutationFileName =  optsHash['--mutationFileName'] if(optsHash.key?('--mutationFileName'))
    if(mutationFileName.nil? )
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--mutationFileName=#{mutationFileName}"
      return 
    end
    
    validateMutationTableHash(mutationFileName)

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
BRL::FileFormats::TCGAParsers::MutationValidator.validateMutationFile(optsHash)
#--mutationFileName


