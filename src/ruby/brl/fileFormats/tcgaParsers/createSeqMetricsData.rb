#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC table to equivalent LFF version

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'json'
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





class CreateSeqMetricsData

attr_accessor :jasonFileName, :phase, :fileNameHash, :averageHash
CENTERS = [ 'bcm', 'broad', 'wu' ]

FILENAMES = ['sampleCompletion.summary', 'geneCompletion.summary', 'ampliconCompletion.summary', 'geneCoverage.summary']



    

  def initialize(phase, jfileName)
    @jasonFileName = jfileName
    @phase = phase
    @fileNameHash = Hash.new {|hh,kk| hh[kk] = nil}
    @averageHash = Hash.new {|hh,kk| hh[kk] = nil}
    CENTERS.each {|center|
            fileNameHash[center] = Hash.new {|hh,kk| hh[kk] = nil}
            FILENAMES.each{|file|
                  fileNameHash[center][file] = "#{center}/#{@phase}/#{file}"
            }
            
      }

    createJsonStr()
    saveJsonStr()
  end


  
  def createJsonStr()

    @fileNameHash.each_key{ |center|
      @averageHash[center] = Hash.new {|hh,kk| hh[kk] = nil}
      typeFilesHash = @fileNameHash[center]
      

      typeFilesHash.each_key{|type|

        fileName = typeFilesHash[type]
        reader = BRL::Util::TextReader.new(fileName) #reading a the file of centerX 
        begin
        reader.each { |line|
          next if(line !~ /\S/ or line !~ /^\s*#Average/ )
          newType = ""
          aa = line.chomp.split(/\t/)
          column3 = aa[3].chomp if(!aa[3].nil?)
          column3 = column3.gsub(/%/, "")
          column3 = column3.to_f
          if(fileName  =~ /sampleCompletion.summary/)
            newType = "sampleAverage"
            @averageHash[center][newType] = column3
          elsif(fileName  =~ /geneCompletion.summary/)
            newType = "geneAverage" 
            column4 = aa[4].chomp if(!aa[4].nil?)
            column4 = column4.gsub(/%/, "")
            column4 = column4.to_f
            @averageHash[center][newType] = column4
          elsif(fileName  =~ /ampliconCompletion.summary/)
            newType = "ampliconAverage"
            @averageHash[center][newType] = column3
          elsif(fileName  =~ /geneCoverage.summary/)
           @averageHash[center]["1x"] = column3 
            column4 = aa[4].chomp if(!aa[4].nil?)
            column4 = column4.gsub(/%/, "")
            column4 = column4.to_f
            @averageHash[center]["2x"] = column4 
          end
          
      
        }
        reader.close()
        rescue => err
          $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
          $stderr.puts err.backtrace.join("\n")
          $stderr.puts "LINE: #{line.inspect}"
          exit 137
        end
 
      }


    }
    

      end

  def saveJsonStr()
      @averageHash.each_key{|center|
          centerAveHash = @averageHash[center]
          centerAveHash.each_key{|type|
                puts "#{center} #{type} #{centerAveHash[type]}"
          }    
      }
        
      begin 
            fileWriter = BRL::Util::TextWriter.new(@jasonFileName)
            fileWriter.puts JSON.pretty_generate(@averageHash)
            fileWriter.close
      rescue => err
            $stderr.puts "ERROR: bad line found. Blank columns? . Details: #{err.message}"
            $stderr.puts err.backtrace.join("\n")
            $stderr.puts "LINE: #{line.inspect}"
            exit 137
      end
  end

end
end; end; end #namespace

#optsHash = Hash.new {|hh,kk| hh[kk] = 0}
#optsHash[ARGV[0]] = ARGV[1]
#optsHash[ARGV[2]] = ARGV[3]
#optsHash[ARGV[4]] = ARGV[5]
#optsHash[ARGV[6]] = ARGV[7]
#optsHash[ARGV[8]] = ARGV[9]
#optsHash[ARGV[10]] = ARGV[11]
#optsHash[ARGV[12]] = ARGV[13]
#optsHash[ARGV[14]] = ARGV[15]
#optsHash[ARGV[16]] = ARGV[17]
#optsHash[ARGV[18]] = ARGV[19]
#optsHash[ARGV[20]] = ARGV[21]
#optsHash[ARGV[22]] = ARGV[23]
#optsHash[ARGV[24]] = ARGV[25]
#optsHash[ARGV[26]] = ARGV[27]
#optsHash[ARGV[28]] = ARGV[29]
#optsHash[ARGV[30]] = ARGV[31]
#optsHash[ARGV[32]] = ARGV[33]
#
#
#
#
#optsHash.each {|key, value|
#
#  $stderr.puts "#{key} == #{value}" if(!key.nil?)
#  }

BRL::FileFormats::TCGAParsers::CreateSeqMetricsData.new(ARGV[0], ARGV[1])

#add the tabular files to the lffs as value pairs
#--tabDelimitedFileName  --lffFileName --outPutFileName
#BRL::FileFormats::TCGAParsers::ModifyLffs.testAddVptoLffFromTabDelimitedFile(optsHash)



