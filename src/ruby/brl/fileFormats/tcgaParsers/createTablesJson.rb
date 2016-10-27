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

class SlideValues
attr_accessor :slideName, :centerHash

  def initialize(sName)
        @slideName = sName
        @centerHash = Hash.new {|hh,kk| hh[kk] = nil}
  end
  
  def addValue(cName, value)
    @centerHash[cName] = value
  end
  

end

class Integer
  def commify
    self.to_s.gsub(/(\d)(?=(\d{3})+$)/,'\1,')
  end
end


class CreateTablesJson

attr_accessor :tableType, :jasonFileName, :phase, :sliceHash, :sliceObjHash
CENTERS = [ 'bcm', 'broad', 'wu' ]
DIRPOSTFIX = 'Completion'
FILEPOSTFIX = 'b.report'
LISTOFSLICES = ['0.0-20.0', '20.0-40.0', '40.0-60.0',  '60.0-80.0',  '80.0-100.0']
    

  def initialize(tableName, phase, fileName)
    @tableType = tableName
    @jasonFileName = fileName
    @phase = phase
    @sliceHash = Hash.new {|hh,kk| hh[kk] = nil}
    @sliceObjHash = Hash.new {|hh,kk| hh[kk] = nil}

    LISTOFSLICES.each{|slice|
      fileNameHash = Hash.new {|hh,kk| hh[kk] = nil}
      CENTERS.each {|center|
        fileNameHash[center] = "#{center}/#{@phase}/#{@tableType}#{DIRPOSTFIX}/#{@tableType}#{DIRPOSTFIX}_#{slice}_#{FILEPOSTFIX}"
      }
      @sliceHash[slice] = fileNameHash
    }
    createJsonStr()
    saveJsonStr()
  end

  def saveJsonStr()
    begin 
    fileWriter = BRL::Util::TextWriter.new(@jasonFileName)
    jsonObjHash = Hash.new {|hh,kk| hh[kk] = nil}
    tableName = "#{@tableType}#{DIRPOSTFIX}"
    jsonObjHash[tableName] = Hash.new {|hh,kk| hh[kk] = nil}

      @sliceObjHash.keys.sort.each{|slice|
        jsonObjHash[tableName][slice] = @sliceObjHash[slice].centerHash        
        }

       jsonObjHash[tableName].each_key{|slice|
	                                sliceHash = jsonObjHash[tableName][slice]
	                                sliceHash.each_key{|center|
                                                         sliceHash[center] = sliceHash[center].commify
                                                         }
                                      }
      
     fileWriter.puts JSON.pretty_generate(jsonObjHash)
     fileWriter.close
    rescue => err
            $stderr.puts "ERROR: bad line found. Blank columns? . Details: #{err.message}"
            $stderr.puts err.backtrace.join("\n")
            $stderr.puts "LINE: #{line.inspect}"
            exit 137
    end
  end
  
  def createJsonStr()
    totalNamesHash = Hash.new {|hh,kk| hh[kk] = 0}
    @sliceHash.each_key{ |slice|
      sliceObj = SlideValues.new(slice)
      @sliceObjHash[slice] = sliceObj
      namesHash = Hash.new {|hh,kk| hh[kk] = 0}
      fileNameHash = @sliceHash[slice]
      fileNameHash.each_key{|center|
        localNamesHash = Hash.new {|hh,kk| hh[kk] = nil}
        fileName = fileNameHash[center]
        reader = BRL::Util::TextReader.new(fileName) #reading a the file of Slide A centerX 
        begin
        reader.each { |line|
          next if(line !~ /\S/ or line =~ /^\s*[\[#]/ )
          aa = line.chomp.split(/\t/)
          name = aa[0].chomp if(!aa[0].nil?)
          localNamesHash[name] = 0 if( !localNamesHash.key?(name) )
          namesHash[name] = 0 if( !namesHash.key?(name) )
          totalNamesHash[name] = 0 if(!totalNamesHash.key?(name))
        }
        reader.close()
        rescue => err
          $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
          $stderr.puts err.backtrace.join("\n")
          $stderr.puts "LINE: #{line.inspect}"
          exit 137
        end
        sliceObj.addValue(center.upcase, localNamesHash.size()) 
      }

      sliceObj.addValue("total", namesHash.size())
    }


    sumHash = Hash.new {|hh,kk| hh[kk] = 0}
    @sliceObjHash.keys.sort.each{|slice|
       puts "SliceName = #{slice}"
       sliceObj = @sliceObjHash[slice]
       mycenterHash = sliceObj.centerHash
       mycenterHash.keys.sort.each{|center|
         sumHash[center] = sumHash[center] + mycenterHash[center]
          puts "#{center.downcase} = #{mycenterHash[center]}"
         }
      }
    sumHash["total"] = totalNamesHash.size()
    sliceObj = SlideValues.new("all")
    puts "SliceName = all"
    sumHash.each_key{|center|
      puts "#{center.downcase} = #{sumHash[center]}"
      sliceObj.addValue(center, sumHash[center])
      }
    @sliceObjHash["all"] = sliceObj

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

BRL::FileFormats::TCGAParsers::CreateTablesJson.new(ARGV[0], ARGV[1], ARGV[2])

#add the tabular files to the lffs as value pairs
#--tabDelimitedFileName  --lffFileName --outPutFileName
#BRL::FileFormats::TCGAParsers::ModifyLffs.testAddVptoLffFromTabDelimitedFile(optsHash)



