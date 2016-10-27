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





class CreateSlidesFromReports

attr_accessor :jasonFileName, :phase, :resultHash, :fileNameHash
CENTERS = [ 'bcm', 'broad', 'wu' ]
DIRECTORIES = [ 'ampliconCompletion', 'geneCompletion', 'geneOneXCoverage', 'geneTwoXCoverage', 'sampleCompletion' ]
LISTOFSLICES = ['0-to-20', '20-to-40', '40-to-60',  '60-to-80',  '80-to-100']
STATICFILENAME = 'results.txt'

 
  def initialize(phase, jfileName)
    @jasonFileName = jfileName
    @phase = phase
    @fileNameHash = Hash.new {|hh,kk| hh[kk] = nil}
    @resultHash = Hash.new {|hh,kk| hh[kk] = nil}
    CENTERS.each {|center|
            fileNameHash[center] = Hash.new {|hh,kk| hh[kk] = nil}
            DIRECTORIES.each{|dir|
                  fileNameHash[center][dir] = "#{center}/#{@phase}/#{dir}/#{STATICFILENAME}"
            }
      }
      createJsonStr()
    saveJsonStr()
  end


  def createJsonStr()

    @fileNameHash.each_key{ |center|
      @resultHash[center] = Hash.new {|hh,kk| hh[kk] = nil}
      dirFileHash = @fileNameHash[center]
      dirFileHash.each_key{|dir|
						newType = "error"
            if(dir  =~ /ampliconCompletion/)
              newType = "amplicon"
            elsif(dir  =~ /geneCompletion/)
              newType = "gene" 
            elsif(dir  =~ /geneOneXCoverage/)
              newType = "1x"
            elsif(dir  =~ /geneTwoXCoverage/)
              newType = "2x"
            elsif(dir  =~ /sampleCompletion/)
              newType = "sample"
            end
            @resultHash[center][newType] = Hash.new {|hh,kk| hh[kk] = nil}
            fileName = dirFileHash[dir] 
            reader = BRL::Util::TextReader.new(fileName) #reading a the file of centerX 
            begin
              reader.each { |line|
                next if(line !~ /\S/ or line =~ /^\s*[\[#]/ )
                aa = line.chomp.split(/\t/)
                slide = aa[0].chomp if(!aa[0].nil?)
                slideValue = aa[1].chomp if(!aa[1].nil?)
                slideValue = slideValue.to_i               
                @resultHash[center][newType][slide] = slideValue
          
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
    @resultHash.each_key{|center|
      centerAveHash = @resultHash[center]
      centerAveHash.each_key{|type|
        slides = centerAveHash[type]
        slides.each_key{|slide|
          puts "#{center} #{type} #{slide} = #{slides[slide]}"
        }
      }    
    }
        
      begin 
            fileWriter = BRL::Util::TextWriter.new(@jasonFileName)
            fileWriter.puts JSON.pretty_generate(@resultHash)
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

BRL::FileFormats::TCGAParsers::CreateSlidesFromReports.new(ARGV[0], ARGV[1])

#add the tabular files to the lffs as value pairs
#--tabDelimitedFileName  --lffFileName --outPutFileName
#BRL::FileFormats::TCGAParsers::ModifyLffs.testAddVptoLffFromTabDelimitedFile(optsHash)



