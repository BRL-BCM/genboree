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

class Integer
  def commify
    self.to_s.gsub(/(\d)(?=(\d{3})+$)/,'\1,')
  end
end

class AttributeRetriever

attr_accessor :propertyFile, :lffFile, :attrNameHash, :globalCounter, :jsonFileName, :jsonHash, :properties
SPECIAL = "dbSNPRS"

  def initialize(lffFile, jsonFile, resultFileName)
        @lffFile = lffFile
        @propertyFile = jsonFile
        @attrNameHash = Hash.new{|hh,kk| hh[kk]=nil;}
        @globalCounter = 0
        @properties = nil
        @jsonFileName = resultFileName
        @jsonHash = Hash.new{|hh,kk| hh[kk]=nil;}
        readLFF()
  end

  def readLFF()     
    
    reader = BRL::Util::TextReader.new(@lffFile)
    reader.each { |line|
      next if(line !~ /\S/ or line =~ /^\s*[#|\[]/)
      line.strip!
      ff = line.split(/\t/)
      next if(ff.length == 3 or ff.length == 7)
      raise "\n\nERROR: not a valid LFF line:\n\n#{line}\n\n" unless(ff.length >= 10)

      attributes = ff[12]
      next if(attributes.nil? or attributes !~ /\S/ or attributes =~ /^\s*\.\s*$/)
      @globalCounter += 1
      attributes.scan(/([^ =]+)\s*=\s*([^=;]+);/) { |attr,val|

        if(!@attrNameHash.has_key?(attr))
          @attrNameHash[attr] = Hash.new{|hh,kk| hh[kk]=nil;}
          @attrNameHash[attr][val] = 1
        else  
          if(!@attrNameHash[attr].has_key?(val))
            @attrNameHash[attr][val] = 1
          else 
            @attrNameHash[attr][val] += 1
          end
        end
        }
    }
    reader.close()

  end
    
  def printRawValues()
      puts "the number of attributes are #{@attrNameHash.size}"
      puts "They are :"
      attCounter = 0
      @attrNameHash.keys.sort.each{|attr|
        attCounter += 1
        puts "\t#{attCounter}. #{attr}"
        counter = 0
        @attrNameHash[attr].each_key{|val|
          tempValue = @attrNameHash[attr][val].to_i
          counter += tempValue
          }
        puts "\t\tthe number of assigned values are #{counter} and the total number is #{@globalCounter} missing #{@globalCounter - counter}"
        puts "\t\t#There are #{attr}  #{@attrNameHash[attr].size} values for and they are "
        if(@attrNameHash[attr].keys.size < 20)
          @attrNameHash[attr].keys.sort.each{|val|
              puts "\t\t\t#{val} = #{@attrNameHash[attr][val]}"
            }
          end
        }
    end
  
    def createJsonHash()
      @properties = JSON.parse(File.read(@propertyFile))
      @properties.each_key{|prop|
        @jsonHash[prop.upcase] = Hash.new{|hh,kk| hh[kk]=nil;}
        tempArray = @properties[prop]
        tempArray.each{|val|
          @jsonHash[prop.upcase][val.upcase] = "0"
          }
      }
      
        @properties.each_key{|prop|         
          counter = 0
#          $stderr.puts "The property is #{prop}"
          if(@attrNameHash.has_key?(prop))
            @attrNameHash[prop].each_key{|val|
              tempValue = @attrNameHash[prop][val].to_i
              counter += tempValue
              @jsonHash[prop.upcase][val.upcase] = tempValue.commify if(prop != SPECIAL)
            }
          end
          @jsonHash[prop.upcase]["DBSNPRS"] = counter.commify if(prop == SPECIAL)
          unKnown = @globalCounter - counter
          @jsonHash[prop.upcase]["unknown".upcase] = unKnown.commify if(unKnown > 0)
          }
          @jsonHash["TOTAL"] = Hash.new{|hh,kk| hh[kk]=nil;}
          @jsonHash["TOTAL"]["TOTAL"] = @globalCounter.commify
    end
    
  def saveJsonStr()
    begin 
    fileWriter = BRL::Util::TextWriter.new(@jsonFileName)      
    fileWriter.puts JSON.pretty_generate(@jsonHash)
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
#
#optsHash.each {|key, value|
#
#  puts "#{key} == #{value}" if(!key.nil?)
#  }




attrib = BRL::FileFormats::TCGAParsers::AttributeRetriever.new(ARGV[0], ARGV[1], ARGV[2] )
#attrib.printRawValues()
attrib.createJsonHash()
attrib.saveJsonStr()

