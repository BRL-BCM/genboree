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

class CreateGlobalReport

attr_accessor :propertyFile, :centersHash, :jsonFileName, :properties, :type


  def initialize(phase, propFile, resultFileName)
        @propertyFile = propFile
        @centersHash = Hash.new{|hh,kk| hh[kk]=nil;}
        @properties = nil
        @type = phase
        @jsonFileName = resultFileName
        populateCeterHash()
        saveJsonStr()
  end

  def populateCeterHash()
      @properties = JSON.parse(File.read(@propertyFile))
      centerArray = @properties["CENTERS"]
      centerArray.each{|center|
        @centersHash[center] = Hash.new{|hh,kk| hh[kk]=nil;}
        }
      @centersHash["all"] = Hash.new{|hh,kk| hh[kk]=nil;}
      @centersHash["all"]["CASES"] = @properties["CASES"].to_i.commify
      @centersHash["all"]["TARGETED"] = @properties["TARGETED"].to_i.commify
      @centersHash["all"]["DELIVERED"] = @properties["DELIVERED"].to_i.commify
      @centersHash["all"]["ALLMINIMUM"] = @properties["ALLMINIMUM"].to_i.commify
#SAMPLESREPORTED      

      sampleFiles = Array.new()
      centerArray.each{|center|
        sampleFile = "#{@properties["BASEDIR"]}#{center}/#{@type}/#{@properties["samplesDefinition"]}"
        sampleFiles << sampleFile
        tempArray = [sampleFile]
        @centersHash[center]["SAMPLESREPORTED"] = countUniqueSamples(tempArray).to_i
#        puts "number of unique samples for #{center} = #{@centersHash[center]["SAMPLESREPORTED"]}"
      }
      @centersHash["all"]["SAMPLESREPORTED"] = countUniqueSamples(sampleFiles).to_i
      @centersHash["all"]["COMPLETED"] = 0
#puts "number of unique samples for all = #{@centersHash["all"]["SAMPLESREPORTED"]}"

#REPROIS
      roiFiles = Array.new()
      centerArray.each{|center|
        roiFile = "#{@properties["BASEDIR"]}#{center}/#{@type}/#{@properties["roisDefinition"]}"
        roiFiles << roiFile
        tempArray = [roiFile]
        @centersHash[center]["REPROIS"] = countUniqueNamesOnLff(tempArray).to_i
#        puts "number of unique rois for #{center} = #{@centersHash[center]["REPROIS"]}"
        @centersHash[center]["COMPLETED"] = @centersHash[center]["SAMPLESREPORTED"] * @centersHash[center]["REPROIS"]
        @centersHash[center]["REPROIS"] = @centersHash[center]["REPROIS"].commify
        @centersHash[center]["SAMPLESREPORTED"] = @centersHash[center]["SAMPLESREPORTED"].commify
        @centersHash["all"]["COMPLETED"] += @centersHash[center]["COMPLETED"]
        @centersHash[center]["COMPLETED"] = @centersHash[center]["COMPLETED"].commify
      }
      @centersHash["all"]["REPROIS"] = countUniqueNamesOnLff(roiFiles).to_i
#      puts "The unique number of rois is #{countUniqueNamesOnLff(roiFiles).to_i} and the sample reported are #{@centersHash["all"]["SAMPLESREPORTED"]}"
#      @centersHash["all"]["COMPLETED"] = @centersHash["all"]["SAMPLESREPORTED"] * @centersHash["all"]["REPROIS"]
      @centersHash["all"]["REPROIS"] = @centersHash["all"]["REPROIS"].commify
      @centersHash["all"]["SAMPLESREPORTED"] = @centersHash["all"]["SAMPLESREPORTED"].commify
      @centersHash["all"]["COMPLETED"] = @centersHash["all"]["COMPLETED"].commify
    

#GENESREPORTED

      geneFiles = Array.new()
      centerArray.each{|center|
        genModel = 
        geneFile = "#{@properties["BASEDIR"]}#{center}/#{@type}/#{@properties["geneNames"]}"
        geneFiles << geneFile
        tempArray = [geneFile]
        @centersHash[center]["GENESREPORTED"] = countUniqueList(tempArray).to_i.commify 
      }
      @centersHash["all"]["GENESREPORTED"] = countUniqueList(geneFiles).to_i.commify

#ESTROIS
#PROJECTEDROISAMPLE

      geneModesFiles = Array.new()
      centerArray.each{|center|
        geneModesFile = "#{@properties["BASEDIR"]}#{center}/#{@type}/#{@properties["GENEMODELS"][center]}"
        geneModesFiles << geneModesFile
        tempArray = [geneModesFile]
        @centersHash[center]["ESTROIS"] = countLinesOnLff(tempArray).to_i
        @centersHash[center]["PROJECTEDROISAMPLE"] = @centersHash[center]["ESTROIS"] *  @properties["ALLMINIMUM"].to_i  
        @centersHash[center]["PROJECTEDROISAMPLE"] = @centersHash[center]["PROJECTEDROISAMPLE"].commify
        @centersHash[center]["ESTROIS"] = @centersHash[center]["ESTROIS"].commify
      }
      @centersHash["all"]["ESTROIS"] = countLinesOnLff(geneModesFiles).to_i
      @centersHash["all"]["PROJECTEDROISAMPLE"] = @centersHash["all"]["ESTROIS"] *  @properties["ALLMINIMUM"].to_i  
      @centersHash["all"]["PROJECTEDROISAMPLE"] = @centersHash["all"]["PROJECTEDROISAMPLE"].commify
      @centersHash["all"]["ESTROIS"] = @centersHash["all"]["ESTROIS"].commify


#REPAMPLICONS

      ampliconFiles = Array.new()
      centerArray.each{|center|
        ampliconFile = "#{@properties["BASEDIR"]}#{center}/#{@type}/#{@properties["ampliconsDefinition"]}"
        ampliconFiles << ampliconFile
        tempArray = [ampliconFile]
        @centersHash[center]["REPAMPLICONS"] = countUniqueNamesOnLff(tempArray).to_i.commify
      }
      @centersHash["all"]["REPAMPLICONS"] = countUniqueNamesOnLff(ampliconFiles).to_i.commify

#GAPS      

      gapsFiles = Array.new()
      centerArray.each{|center|
        gapsFile = "#{@properties["BASEDIR"]}#{center}/#{@type}/#{@properties["gaps"]}"
        gapsFiles << gapsFile
        tempArray = [gapsFile]
        @centersHash[center]["GAPS"] = countUniqueNamesOnLff(tempArray).to_i.commify
      }
      @centersHash["all"]["GAPS"] = countUniqueNamesOnLff(gapsFiles).to_i.commify
  end
  
  def countUniqueList(listNameFiles)
    namesHash = Hash.new{|hh,kk| hh[kk]=nil;}
    listNameFiles.each{|listNameFile|
      reader = BRL::Util::TextReader.new(listNameFile)
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*[#|\[]/)
        line.strip!
        next if(line.nil? || line.length < 1)
        namesHash[line] = nil
      }
      reader.close()
    }
    return namesHash.size
  end  

  def countLinesOnLff(lffFileNames)
    counter = 0
    lffFileNames.each{|lffFileName|
      reader = BRL::Util::TextReader.new(lffFileName)
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*[#|\[]/)
        line.strip!
        ff = line.split(/\t/)
        next if(ff.length < 10)
        counter += 1
      }
      reader.close()
    }
    return counter
  end
 



  def countUniqueNamesOnLff(lffFileNames)
    namesHash = Hash.new{|hh,kk| hh[kk]=nil;}
    lffFileNames.each{|lffFileName|
      reader = BRL::Util::TextReader.new(lffFileName)
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*[#|\[]/)
        line.strip!
        ff = line.split(/\t/)
        next if(ff.length < 10)
        namesHash[ff[1].strip] = nil
      }
      reader.close()
    }
    return namesHash.size
  end
  
  def countUniqueSamples(sampleFiles)
    namesHash = Hash.new{|hh,kk| hh[kk]=nil;}
    sampleFiles.each{|sampleFileName|
    reader = BRL::Util::TextReader.new(sampleFileName)
    reader.each { |line|
      next if(line !~ /\S/ or line =~ /^\s*[#|\[]/)
      line.strip!
      ff = line.split(/\t/)
      next if(ff.length < 3)
      namesHash[ff[0].strip]
    }
    reader.close()
    }
    return namesHash.size
  end
    
  
  def saveJsonStr()
    begin 
    fileWriter = BRL::Util::TextWriter.new(@jsonFileName)      
    fileWriter.puts JSON.pretty_generate(@centersHash)
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



#(phase, propFile, resultFileName)
globalReport = BRL::FileFormats::TCGAParsers::CreateGlobalReport.new(ARGV[0], ARGV[1], ARGV[2] )


