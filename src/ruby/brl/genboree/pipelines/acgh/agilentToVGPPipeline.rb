#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: take a agilent file and some intersection tracks and generate a vgp file

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################

require 'rubygems'
require 'erb'
require 'yaml'
require 'cgi'
require 'rein'
require 'erubis'
require 'timeout'
require 'uri'
require 'json'
require 'interval'
require 'fileutils'
require 'ftools'
require 'sha1'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/net/erubisContext'
require 'brl/fileFormats/lffHash'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/toolPlugins/util/util'
require 'brl/genboree/genboreeContext'
require 'brl/genboree/dbUtil'
require 'brl/genboree/projectManagement/projectManagement'
require 'brl/util/emailer'
require 'net/http'
require 'net/smtp'


# ##############################################################################
# HELPER FUNCTIONS
# ##############################################################################
# Process command line args
# Note:
#      - extra alias files are optional, but clearly should be provided
module BRL ; module Genboree; module Pipelines; module Acgh
        
# ##############################################################################
# CONSTANTS
# ##############################################################################
GZIP = BRL::Util::TextWriter::GZIP_OUT
STANDARDCHROM="chr1,chr2,chr3,chr4,chr5,chr6,chr7,chr8,chr9,chr10,chr11,chr12,chr13,chr14,chr15,chr16,chr17,chr18,chr19,chr20,chr21,chr22,chrX,chrY"
AGILENT_PIPELINE_VERSION = "0.1"
AGILENT_DEFAULTS = "conf/acghDefaults.json"


class Acgh
          def self.compressFile( fileName )   
            `gzip #{fileName}` if(File.exist?(fileName))
          end 
end

class CalculateMeanAndSTD
  attr_accessor :readFileStr, :readFiles, :outPutFile, :scoreArray, :mean, :std

  def initialize(readFile, outFile)
    @readFileStr = readFile
    @readFileStr = CGI.unescape(@readFileStr) if(@readFileStr.class == String) 
    @readFiles = @readFileStr.split(/,/) if(!readFileStr.nil? and readFileStr.length > 0)
    @outPutFile = outFile
    @outPutFile = CGI.unescape(@outPutFile) if(@outPutFile.class == String)
    @scoreArray = Array.new()
    @mean = 0.0
    @std = 0.0
  end

  def calculateMean(ary)
    return 0 if(ary.nil? || ary.length < 1)
    ary.inject(0) { |sum, i| sum += i }/ary.length.to_f 
  end


  def std_dev(ary, mean)
    return 0 if(ary.nil? || ary.length < 1)
    Math.sqrt( (ary.inject(0) { |dev, i| 
                  dev += (i - mean) ** 2}/ary.length.to_f) )
  end

  def calculateMeanAndStd()
    # Read  file
    reader = nil
    fileWriterOutPutFile = BRL::Util::TextWriter.new(@outPutFile)
    line = nil
    lineCounter = 1
    lffHash = nil
    begin
      @readFiles.each {|lffFile|
        reader = BRL::Util::TextReader.new(lffFile)  
        reader.each { |line|
          errofLevel = 0
          if(line !~ /\S/ or line =~ /^\s*[\[#]/)
            lineCounter = lineCounter + 1
            next
          end
          aa = line.strip.split(/\t/)
          next if( aa.length < 10 )
          lffHash = LFFHash.new(line)
          @scoreArray << lffHash.lffScore
          lineCounter = lineCounter + 1
        }
        reader.close()
      }
      @mean = calculateMean(@scoreArray)
      @std = std_dev(@scoreArray, @mean)
      fileWriterOutPutFile.puts "mean = #{@mean}"
      fileWriterOutPutFile.puts "std = #{@std}"
      fileWriterOutPutFile.close()

    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{lineCounter}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
 end   
 
end #end of Class

class OpenErrorExtractValues
  attr_accessor :readFileStr, :propHash
 def initialize(readFile)
  @readFileStr = readFile 
  @readFileStr = CGI.unescape(@readFileStr) if(@readFileStr.class == String)
  @propHash = Hash.new {|hh,kk| hh[kk] = nil}
 end
 
  def createFiles()
    # Read  file
    reader = BRL::Util::TextReader.new(@readFileStr)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
       next if(line =~ /^\s*[\[#]/ or line !~ /^.*=.*$/ )
        line.scan(/([^ =]+)\s*=\s*([^=]+)/) { |attr,val|

        if(!@propHash.has_key?(attr))        
          @propHash[attr] = val
        end
        }
    }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
  end
  
   def printOptions()
     puts "And the props are "
   @propHash.each_key{|key|
     
     puts "#{key} = #{@propHash[key]}"
     
     }
   end  
end

class ChangeColors
  attr_accessor :readFileStr, :outPutFile, :thresholdValue, :positiveColor, :negativeColor, :colorAttName, :lffHash, :originalHash
  attr_accessor :colorClass, :colorType, :colorSubType

  def initialize(readFile, outFile, value, posColor, negColor, colorClass, colorType, colorSubType)
    @readFileStr = readFile
    @readFileStr = CGI.unescape(@readFileStr) if(@readFileStr.class == String)
    @outPutFile = outFile
    @outPutFile = CGI.unescape(@outPutFile) if(@outPutFile.class == String)
    @thresholdValue = value
    @thresholdValue = CGI.unescape(@thresholdValue) if(@thresholdValue.class == String)
    @thresholdValue = @thresholdValue.to_f
    @positiveColor = posColor    
    @positiveColor = CGI.unescape(@positiveColor) if(@positiveColor.class == String)
    @negativeColor = negColor
    @negativeColor = CGI.unescape(@negativeColor) if(@negativeColor.class == String)    
    @colorAttName = "annotationColor".to_sym
    @lffHash = nil
    @originalHash = nil
    @colorClass = colorClass
    @colorClass = CGI.unescape(@colorClass) if(@colorClass.class == String)  
    @colorType = colorType
    @colorType = CGI.unescape(@colorType) if(@colorType.class == String)  
    @colorSubType = colorSubType
    @colorSubType = CGI.unescape(@colorSubType) if(@colorSubType.class == String)  
  end

  def createFiles()
    # Read  file
    reader = BRL::Util::TextReader.new(@readFileStr)
    fileWriterOutPutFile = BRL::Util::TextWriter.new(@outPutFile)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        newName = ""
        newSubType = ""
        newAttr = ""
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        aa = line.strip.split(/\t/)
        next if( aa.length < 10 )
        @lffHash = LFFHash.new(line)
        if(@lffHash.lffScore >= @thresholdValue)
           @lffHash[@colorAttName] = @positiveColor
        else
            @lffHash[@colorAttName] = @negativeColor
        end
        
        @lffHash.lffClass = @colorClass.to_sym if(!@colorClass.nil?)
        @lffHash.lffType = @colorType.to_sym if(!@colorType.nil?)
        @lffHash.lffSubtype = @colorSubType.to_sym if(!@colorSubType.nil?)
        
        fileWriterOutPutFile.puts @lffHash.to_lff
        lineCounter = lineCounter + 1
      }

      fileWriterOutPutFile.close()
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
 end   
 
  
end #end of Class



class AddVPsToFiles
  attr_accessor :readFileStr, :outPutFile, :vpName, :vpValue, :lffHash, :readFiles

  def initialize(readFile, outFile, vpName, vpValue)
    @readFiles = nil
    @readFileStr = readFile
    @readFileStr = CGI.unescape(@readFileStr) if(@readFileStr.class == String) 
    @readFiles = @readFileStr.split(/,/) if(!readFileStr.nil? and readFileStr.length > 0)
    @outPutFile = outFile
    @outPutFile = CGI.unescape(@outPutFile) if(@outPutFile.class == String)
    @vpName = vpName
    @vpName = CGI.unescape(@vpName) if(@vpName.class == String) 
    @vpName = @vpName.to_sym
    @vpValue = vpValue
    @vpValue  = CGI.unescape(@vpValue) if(@vpValue.class == String)
    @lffHash = nil
    createFiles()
  end


  def createFiles()
    # Read  file
    reader = nil
    fileWriterOutPutFile = BRL::Util::TextWriter.new(@outPutFile)
    line = nil
    lineCounter = 1
    begin
      @readFiles.each {|lffFile|
      reader = BRL::Util::TextReader.new(lffFile)  
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        aa = line.strip.split(/\t/)
        next if( aa.length < 10 )
        @lffHash = LFFHash.new(line)
        @lffHash[@vpName] = @vpValue
        fileWriterOutPutFile.puts @lffHash.to_lff
        lineCounter = lineCounter + 1
      }
      reader.close()
      }
      fileWriterOutPutFile.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
 end   
    
end #end of Class


class CreateVGPTracksDescriptionFile
  attr_accessor :vgpTrackConfFile, :trackHash, :chomosomic, :genomic
  attr_accessor :trackPropHash, :agilentTrack, :refTrackName

  def initialize(outPutConfFile, agilentTrack, refTrackName, trackString, chromosomic=false)
    @vgpTrackConfFile = outPutConfFile
    @vgpTrackConfFile = CGI.unescape(@vgpTrackConfFile) if(@vgpTrackConfFile.class == String)
    @trackHash = Hash.new{|hh,kk| hh[kk]=nil;}
    @agilentTrack = agilentTrack
    @agilentTrack = CGI.unescape(@agilentTrack) if(@agilentTrack.class == String)
    @refTrackName = refTrackName
    @refTrackName = CGI.unescape(@refTrackName) if(@refTrackName.class == String)
    trackStringTmp = trackString
    trackStringTmp = CGI.unescape(trackStringTmp) if(trackStringTmp.class == String)    
    @trackPropHash = generateTrackHash(trackStringTmp)
    
    
    if(chromosomic)
      @chomosomic = true
      @genomic = false
      generateChomosomicTrackPropHash()
    else
      @chomosomic = false
      @genomic = true
      generateGenomicTrackPropHash()
    end

    printPropertiesFile()
  end



#TRACK = "OMIM:Morbid%gain=#008000%loss=#FF0000;variations:TCAG_UCS:gain=#669933:loss=#ffff00;"
#NOINTERSECT = "Segment:NoIntersect%gain=#6600cc%loss=#cc6633;"

def generateTrackHash(track)
    tracks = track.split(/;/)
    trackHash = Hash.new{|hh,kk| hh[kk]=nil;}
    tracks.each{|trackProp|   
            if (trackProp =~ /([^%]+)%gain=([^%]+)%loss=([^;]+)/)
              trackName = $1.strip
              gainColor = $2.strip
              lossColor= $3.strip
              trackHash[trackName] = Hash.new{|hh,kk| hh[kk]=nil;}
              trackHash[trackName]['gain'] = gainColor
              trackHash[trackName]['loss'] = lossColor
            end
    }
    return trackHash
end  

  def generateChomosomicTrackPropHash()
    zIndex = 1
    trackName = @agilentTrack   
    @trackHash[trackName] = Hash.new{|hh,kk| hh[kk]=nil;}
    style = 'doubleSidedScore'
    @trackHash[trackName][style] = Hash.new{|hh,kk| hh[kk]=nil;}
    position = 1
    color = 'annoColor' 
    @trackHash[trackName][style]['position'] =  position
    @trackHash[trackName][style]['color'] = color
    @trackHash[trackName][style]['zIndex'] = zIndex
    zIndex += 1
 

    @trackPropHash.each_key{|trProp|
        trackName = "#{trProp}_Gain"
        @trackHash[trackName] = Hash.new{|hh,kk| hh[kk]=nil;}
        style = 'doubleSidedScore'
        @trackHash[trackName][style] = Hash.new{|hh,kk| hh[kk]=nil;}
        @trackHash[trackName][style]['position'] =  2
        @trackHash[trackName][style]['zIndex'] = zIndex
        @trackHash[trackName][style]['color'] = @trackPropHash[trProp]['gain']
        style = 'callout'
        @trackHash[trackName][style] = Hash.new{|hh,kk| hh[kk]=nil;}
        @trackHash[trackName][style]['position'] =  3
        @trackHash[trackName][style]['zIndex'] = zIndex
        zIndex += 1
        @trackHash[trackName][style]['color'] = @trackPropHash[trProp]['gain']  
    
        trackName = "#{trProp}_Loss"
        @trackHash[trackName] = Hash.new{|hh,kk| hh[kk]=nil;}
        style = 'doubleSidedScore'
        @trackHash[trackName][style] = Hash.new{|hh,kk| hh[kk]=nil;}
        @trackHash[trackName][style]['position'] =  2
        @trackHash[trackName][style]['zIndex'] = zIndex
        @trackHash[trackName][style]['color'] = @trackPropHash[trProp]['loss']
        style = 'callout'
        @trackHash[trackName][style] = Hash.new{|hh,kk| hh[kk]=nil;}
        @trackHash[trackName][style]['position'] =  3
        @trackHash[trackName][style]['zIndex'] = zIndex
        zIndex += 1
        @trackHash[trackName][style]['color'] = @trackPropHash[trProp]['loss']
           
     }

    
    trackName = @refTrackName
    @trackHash[trackName] = Hash.new{|hh,kk| hh[kk]=nil;}
    style = 'callout'
    @trackHash[trackName][style] = Hash.new{|hh,kk| hh[kk]=nil;}
    position = -1
    @trackHash[trackName][style]['zIndex'] = zIndex
    zIndex += 1
    color = '#000000'
    @trackHash[trackName][style]['position'] =  position
    @trackHash[trackName][style]['color'] = color    
    @trackHash[trackName][style]['margin'] = 5
    @trackHash[trackName][style]['width'] = 1 
    
  end
  
  
  def generateGenomicTrackPropHash()
    zIndex = 1
    trackName = @agilentTrack 
    @trackHash[trackName] = Hash.new{|hh,kk| hh[kk]=nil;}
    style = 'doubleSidedScore'
    @trackHash[trackName][style] = Hash.new{|hh,kk| hh[kk]=nil;}
    position = 1
    color = 'annoColor' 
    @trackHash[trackName][style]['position'] =  position
    @trackHash[trackName][style]['color'] = color
    @trackHash[trackName][style]['zIndex'] = zIndex
    zIndex += 1 


    @trackPropHash.each_key{|trProp|
        trackName = "#{trProp}_Gain"
        @trackHash[trackName] = Hash.new{|hh,kk| hh[kk]=nil;}
        style = 'block'
        @trackHash[trackName][style] = Hash.new{|hh,kk| hh[kk]=nil;}
        @trackHash[trackName][style]['position'] =  2
        @trackHash[trackName][style]['color'] = @trackPropHash[trProp]['gain']
        @trackHash[trackName][style]['zIndex'] = zIndex
        zIndex += 1
        trackName = "#{trProp}_Loss"
        @trackHash[trackName] = Hash.new{|hh,kk| hh[kk]=nil;}
        style = 'block'
        @trackHash[trackName][style] = Hash.new{|hh,kk| hh[kk]=nil;}
        @trackHash[trackName][style]['position'] =  2
        @trackHash[trackName][style]['color'] = @trackPropHash[trProp]['loss']
        @trackHash[trackName][style]['zIndex'] = zIndex
        zIndex += 1
     }

    end
    

  def printPropertiesFile()    
      fileWriter = nil
      begin  
        fileWriter = BRL::Util::TextWriter.new(@vgpTrackConfFile)
        fileWriter.puts JSON.pretty_generate(@trackHash)
        fileWriter.close
      rescue => err
        $stderr.puts "ERROR: bad line found. Blank columns? . Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        $stderr.puts "LINE: #{line.inspect}"
        exit 137
      end
  end #end of method
    
end #end of class




class CreateVGPDefaultPropertyFile
  attr_accessor :vgpDefaultConfFile, :defaultsProp

  def initialize(outPutConfFile)
    @vgpDefaultConfFile = outPutConfFile
    @vgpDefaultConfFile = CGI.unescape(@vgpDefaultConfFile) if(@vgpDefaultConfFile.class == String)
    @defaultsProp = Hash.new{|hh,kk| hh[kk]=nil;}
    generateDefaultPropHash()
    printPropertiesFile()
  end
  


  def generateDefaultPropHash()
  
    @defaultsProp['referenceTrack_Chr'] = Hash.new{|hh,kk| hh[kk]=nil;}
    @defaultsProp['referenceTrack_Chr']['displayName'] = "Cyto:Band"
    @defaultsProp['referenceTrack_Chr']['margin'] =  10
    @defaultsProp['referenceTrack_Chr']['drawingStyle'] = "cytoband"
    @defaultsProp['referenceTrack_Chr']['width'] = 35
    
    @defaultsProp['referenceTrack_Gen'] = Hash.new{|hh,kk| hh[kk]=nil;}
    @defaultsProp['referenceTrack_Gen']['displayName'] = "Cyto:Band"
    @defaultsProp['referenceTrack_Gen']['margin'] =  2
    @defaultsProp['referenceTrack_Gen']['drawingStyle'] = "cytoband"
    @defaultsProp['referenceTrack_Gen']['width'] = 14
    
    @defaultsProp['legend'] = Hash.new{|hh,kk| hh[kk]=nil;}
    @defaultsProp['legend']['border'] = true
    @defaultsProp['legend']['position'] = "bottom"

    @defaultsProp['figureTitle'] = "Result"
    @defaultsProp['outputFormat'] =  "png"
    @defaultsProp['drawReferenceTrack'] = true
    @defaultsProp['drawChromosomeBandNames'] = true
    @defaultsProp['chrDefinitionFile'] = "chromosomes.das"

    @defaultsProp['chromosomeLabels'] = true
    @defaultsProp['outputDirectory'] = "results"
    @defaultsProp['subtitle'] = "Result for Project "    
    @defaultsProp['yAxisLabel'] = "Base-pair coordinates"
    @defaultsProp['xAxisLabel'] = "Chromosome"
    @defaultsProp['yAxisLabelFormat'] = "left"

    
    @defaultsProp['genomeView'] = Hash.new{|hh,kk| hh[kk]=nil;}
    @defaultsProp['genomeView']['margin'] = 1
    @defaultsProp['genomeView']['height'] = 300
    @defaultsProp['genomeView']['width'] = 400

    @defaultsProp['chromosomeView'] = Hash.new{|hh,kk| hh[kk]=nil;}
    @defaultsProp['chromosomeView']['height'] = 660
    @defaultsProp['chromosomeView']['width'] = 500
      
    @defaultsProp['genomicTracks'] = Hash.new{|hh,kk| hh[kk]=nil;}
    genomicTracks = @defaultsProp['genomicTracks']

    genomicTracks['block'] = Hash.new{|hh,kk| hh[kk]=nil;}
    genomicTracks['block']['margin'] = 1
    genomicTracks['block']['width'] = 14
    genomicTracks['block']['overrridesColor'] = true
    genomicTracks['block']['color'] = "#0212FF"   
    genomicTracks['callout'] = Hash.new{|hh,kk| hh[kk]=nil;}
    genomicTracks['callout']['margin'] = 1
    genomicTracks['callout']['width'] = 20
    genomicTracks['callout']['position'] = 3
    genomicTracks['callout']['overrridesColor'] = true
    genomicTracks['callout']['color'] = "#008000"
    genomicTracks['doubleSidedScore'] = Hash.new{|hh,kk| hh[kk]=nil;}
    genomicTracks['doubleSidedScore']['margin'] = 5
    genomicTracks['doubleSidedScore']['width'] = 25
    genomicTracks['doubleSidedScore']['overrridesColor'] = true
    genomicTracks['doubleSidedScore']['color'] = "#FF0000"           
    genomicTracks['doubleSidedScore']['positiveThreshold'] = 1
    genomicTracks['doubleSidedScore']['negativeThreshold'] = -1
    genomicTracks['doubleSidedScore']['direction'] = "left"
    genomicTracks['doubleSidedScore']['drawScoreAxis'] = true
    genomicTracks['doubleSidedScore']['scoreAxisIncrement'] = 1.0
    genomicTracks['doubleSidedScore']['minScore'] = -1
    genomicTracks['doubleSidedScore']['maxScore'] = 1
    genomicTracks['doubleSidedScore']['border'] = false
    
    @defaultsProp['chromosomicTracks'] = Hash.new{|hh,kk| hh[kk]=nil;}
    chromosomicTracks = @defaultsProp['chromosomicTracks']    
    chromosomicTracks['block'] = Hash.new{|hh,kk| hh[kk]=nil;}
    chromosomicTracks['block']['margin'] = 1
    chromosomicTracks['block']['width'] = 30
    chromosomicTracks['block']['overrridesColor'] = true
    chromosomicTracks['block']['color'] = "#0212FF"   
    chromosomicTracks['callout'] = Hash.new{|hh,kk| hh[kk]=nil;}
    chromosomicTracks['callout']['margin'] = 1
    chromosomicTracks['callout']['width'] = 20
    chromosomicTracks['callout']['position'] = 3
    chromosomicTracks['callout']['overrridesColor'] = true
    chromosomicTracks['callout']['color'] = "#008000"
    chromosomicTracks['doubleSidedScore'] = Hash.new{|hh,kk| hh[kk]=nil;}
    chromosomicTracks['doubleSidedScore']['margin'] = 10
    chromosomicTracks['doubleSidedScore']['width'] = 100
    chromosomicTracks['doubleSidedScore']['overrridesColor'] = true
    chromosomicTracks['doubleSidedScore']['color'] = "#FF0000"           
    chromosomicTracks['doubleSidedScore']['positiveThreshold'] = 1
    chromosomicTracks['doubleSidedScore']['negativeThreshold'] = -1
    chromosomicTracks['doubleSidedScore']['direction'] = "left"
    chromosomicTracks['doubleSidedScore']['drawScoreAxis'] = true
    chromosomicTracks['doubleSidedScore']['scoreAxisIncrement'] = 1.0
    chromosomicTracks['doubleSidedScore']['minScore'] = -2
    chromosomicTracks['doubleSidedScore']['maxScore'] = 2
    chromosomicTracks['doubleSidedScore']['border'] = true
  
  end

  def printPropertiesFile()    
      fileWriter = nil
      begin  
        fileWriter = BRL::Util::TextWriter.new(@vgpDefaultConfFile)
        fileWriter.puts JSON.pretty_generate(@defaultsProp)
        fileWriter.close
      rescue => err
        $stderr.puts "ERROR: bad line found. Blank columns? . Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        $stderr.puts "LINE: #{line.inspect}"
        exit 137
      end
  end #end of method
    
end #end of class

class ProccessRhtmlTemplate

  attr_accessor :rhtmlFile, :htmlOutPutFile, :jsonFile, :properties


  def initialize(rhtmlFile, htmlOutPutFile, jsonFile)    
    @rhtmlFile = rhtmlFile
    @rhtmlFile = CGI.unescape(@rhtmlFile) if(@rhtmlFile.class == String)
    @htmlOutPutFile =  htmlOutPutFile  
    @htmlOutPutFile = CGI.unescape(@htmlOutPutFile) if(@htmlOutPutFile.class == String)
    @jsonFile = jsonFile
    @jsonFile = CGI.unescape(@jsonFile) if(@jsonFile.class == String)
    @properties = JSON.parse(File.read(@jsonFile))
    transfromFile()
  end

  def transfromFile()
    begin
      properties = @properties
    rescue => err
      $stderr.puts "ERROR: calling class ProccessRhtmlTemplate: bad json file #{@jsonFile}. Details: #{err.message}"
      exit(134)
    end      
      
    begin
      reader = File.read(@rhtmlFile)
    rescue => err
      $stderr.puts "ERROR: calling class ProccessRhtmlTemplate: bad template file: #{@rhtmlFile}. Details: #{err.message}"
      exit(156)
    end      
      
    begin 
      eruby = Erubis::Eruby.new(reader) 
      fileWriterOutPutFile = BRL::Util::TextWriter.new(@htmlOutPutFile)
      fileWriterOutPutFile.puts eruby.result(binding()) 
      fileWriterOutPutFile.close()
    rescue => err
      $stderr.puts "ERROR: calling class ProccessRhtmlTemplate: during processing templateFile: #{@rhtmlFile} with json file #{@jsonFile}. Details: #{err.message}"
      exit(100)
    end
 end   

end #end of class



class ProccessJavaScriptTemplate

  attr_accessor :rhtmlFile, :htmlOutPutFile, :jsonFile, :properties, :defaultProperties

  def initialize(rhtmlFile, htmlOutPutFile, refSeqId, link, projectlink, baseProject, projectName, defaultPropFile)    
    @rhtmlFile = rhtmlFile
    @rhtmlFile = CGI.unescape(@rhtmlFile) if(@rhtmlFile.class == String)
    @htmlOutPutFile =  htmlOutPutFile  
    @htmlOutPutFile = CGI.unescape(@htmlOutPutFile) if(@htmlOutPutFile.class == String)
    genbConfig = GenboreeConfig.load()
    tempFile = defaultPropFile
    tempFile = CGI.unescape(tempFile) if(tempFile.class == String)
    @defaultProperties = JSON.parse(File.read(tempFile))
    @properties = Hash.new{|hh,kk| hh[kk]=nil;}
    @properties['refSeqId'] = refSeqId
    serverName = genbConfig.machineName
    projectPath = genbConfig.gbProjectContentDir
    resourcePath = genbConfig.gbResourcesDir
    tempLink = CGI.unescape(link) if(link.class == String)
    @properties['link'] = "http://#{serverName}/#{tempLink}"
    tempProjectLink = projectlink
    tempProjectLink = CGI.unescape(tempProjectLink) if(tempProjectLink.class == String)
    @properties['projectlink'] = "http://#{serverName}/#{tempProjectLink}"
    @properties['baseProject'] = baseProject
    @properties['projectName'] = projectName
    @properties['additionalPageDir'] = @defaultProperties['ADDITIONAL_PAGES']
    transfromFile()
  end  



  def transfromFile()
    begin
      properties = @properties
    rescue => err
      $stderr.puts "ERROR: calling class ProccessRhtmlTemplate: bad json file #{@jsonFile}. Details: #{err.message}"
      exit(134)
    end      
      
    begin
      reader = File.read(@rhtmlFile)
    rescue => err
      $stderr.puts "ERROR: calling class ProccessRhtmlTemplate: bad template file: #{@rhtmlFile}. Details: #{err.message}"
      exit(156)
    end      
      
    begin 
      eruby = Erubis::Eruby.new(reader) 
      fileWriterOutPutFile = BRL::Util::TextWriter.new(@htmlOutPutFile)
      fileWriterOutPutFile.puts eruby.result(binding()) 
      fileWriterOutPutFile.close()
    rescue => err
      $stderr.puts "ERROR: calling class ProccessRhtmlTemplate: during processing templateFile: #{@rhtmlFile} with json file #{@jsonFile}. Details: #{err.message}"
      exit(100)
    end
 end   

end #end of class




class CreateVGPPropertyFile
  attr_accessor :vgpConfigurationFile, :properties, :lffFilesArray
  attr_accessor :outPutDir, :figureTitle, :subTitle, :lffFiles, :chrDefinitionFile
  attr_accessor :trackArray, :genomicView, :chromosomeView, :defaultVGPValues
  attr_accessor :omitTitle, :omitSubTitle, :omitLegend
  attr_accessor :listTracksWithPropHash, :chrDefinitionFileExtension 

  
  def initialize(outFile, lffFiles, outPutDir, figureTitle,
                 subTitle, chromosomeView, vgpDefValFile, trackPropFile,
                 omitTitle=false, omitSubTitle=false, omitLegend=false,
                 chrDefinitionFile=nil, chrDefinitionFileExtension = nil )


    @vgpConfigurationFile = outFile
    @vgpConfigurationFile = CGI.unescape(@vgpConfigurationFile) if(@vgpConfigurationFile.class == String)
    
    @properties = Hash.new{|hh,kk| hh[kk]=nil;}
    @lffFiles = lffFiles
    @lffFiles = CGI.unescape(@lffFiles) if(@lffFiles.class == String)

    if(chromosomeView)
      @chromosomeView = true
      @genomicView = false
    else
      @chromosomeView = false
      @genomicView = true
    end
    
    @omitTitle = omitTitle
    @omitSubTitle = omitSubTitle
    @omitLegend = omitLegend
    @chrDefinitionFile = nil
    @chrDefinitionFile = chrDefinitionFile if(!chrDefinitionFile.nil?)
    @chrDefinitionFile = CGI.unescape(@chrDefinitionFile) if(@chrDefinitionFile.class == String)
    @chrDefinitionFileExtension = nil
    @chrDefinitionFileExtension = chrDefinitionFileExtension if(!chrDefinitionFileExtension.nil?)
    @chrDefinitionFileExtension = CGI.unescape(@chrDefinitionFileExtension) if(@chrDefinitionFileExtension.class == String)
    
    @lffFilesArray = @lffFiles.split(/,/)
    @outPutDir = outPutDir
    @outPutDir = CGI.unescape(@outPutDir) if(@outPutDir.class == String)
    @figureTitle = figureTitle
    @figureTitle = CGI.unescape(@figureTitle) if(@figureTitle.class == String)
    @subTitle = subTitle
    @subTitle = CGI.unescape(@subTitle) if(@subTitle.class == String)
    vgpDefValFileTmp = vgpDefValFile
    vgpDefValFileTmp = CGI.unescape(vgpDefValFileTmp) if(vgpDefValFileTmp.class == String)
    @defaultVGPValues = JSON.parse(File.read(vgpDefValFileTmp))
    trackPropFileTmp = trackPropFile
    trackPropFileTmp = CGI.unescape(trackPropFileTmp) if(trackPropFileTmp.class == String)    
    @listTracksWithPropHash = JSON.parse(File.read(trackPropFileTmp))
    @trackProperties = generateTrackProperties()
    createFiles()
    printPropertiesFile()
  end


  def generatePropHash(idNumber, trackStyleHash, propertiesHash)
      generatedHash = Hash.new{|hh,kk| hh[kk]=nil;}
      propertiesHash.each {|key,value|
        generatedHash[key] = value
        }
      trackStyleHash.each {|key,value|
        generatedHash[key] = value
        }      
      generatedHash['idNumber'] = idNumber      

      return generatedHash
    end


  def generateTrackProperties()

      if(@chromosomeView)
        defalultHash = @defaultVGPValues['chromosomicTracks']
      else
        defalultHash = @defaultVGPValues['genomicTracks']
      end

      trackPropsHash = Hash.new{|hh,kk| hh[kk]=nil;}
      @listTracksWithPropHash.each_key{|trackName|
          trackPropsHash[trackName] = Hash.new{|hh,kk| hh[kk]=nil;}
          trackStyles = @listTracksWithPropHash[trackName]
          index = 0
          trackStyles.each_key{|style|
             styleHash = trackStyles[style]
              trackPropsHash[trackName][style] = generatePropHash(index, styleHash, defalultHash[style])
              index += 1  
          }
      }
      return trackPropsHash
  end


    def generateCytoBand(trackArray, displayName, margin, width, idNumber)
      style = "cytoband"  
      trackArray[idNumber] = Hash.new{|hh,kk| hh[kk]=nil;}
      trackArray[idNumber]['displayName'] = displayName
      trackArray[idNumber]['drawingStyle'] = style
      trackArray[idNumber]['margin'] = margin
      trackArray[idNumber]['width'] = width
      trackArray[idNumber]['zIndex'] = 0     
    end

    def fillTrackArray(trackArray, displayName, style, props)
      idNumber = props['idNumber']
      trackArray[idNumber] = props
      trackArray[idNumber]['displayName'] = displayName
      trackArray[idNumber]['drawingStyle'] = style            
      trackArray[idNumber].delete('idNumber')
   end
    
    
  def generateChromosomeView(width, height)
      @properties['chromosomeView'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties['chromosomeView']['width'] = width
      @properties['chromosomeView']['height'] = height
  end


  
  def generateGenomicView(width, height, margin)
      @properties['genomeView'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties['genomeView']['width'] = width
      @properties['genomeView']['height'] = height
      @properties['genomeView']['margin'] = margin    
  end
  


    def createFiles()
      referenceTrack = @defaultVGPValues['drawReferenceTrack']
      chromosomeBandNames = @defaultVGPValues['drawChromosomeBandNames']


      if(@chromosomeView)
        referenceTrackName = @defaultVGPValues['referenceTrack_Chr']['displayName']
        referenceMargin = @defaultVGPValues['referenceTrack_Chr']['margin']
        referenceWidth = @defaultVGPValues['referenceTrack_Chr']['width']
      else
        referenceTrackName = @defaultVGPValues['referenceTrack_Gen']['displayName']
        referenceMargin = @defaultVGPValues['referenceTrack_Gen']['margin']
        referenceWidth = @defaultVGPValues['referenceTrack_Gen']['width']
      end
            

      
      chromosomeWidth = @defaultVGPValues['chromosomeView']['width']
      chromosomeHeight = @defaultVGPValues['chromosomeView']['height']
      genomeWidth = @defaultVGPValues['genomeView']['width']
      genomicHeight = @defaultVGPValues['genomeView']['height']
      genomicMargin = @defaultVGPValues['genomeView']['margin']
    
      
      @properties['lffFiles'] = @lffFilesArray

      if(@chrDefinitionFile.nil?)
        @properties['chrDefinitionFile'] = @defaultVGPValues['chrDefinitionFile']
      else
        @properties['chrDefinitionFile'] = @chrDefinitionFile
      end

      if(@chrDefinitionFileExtension.nil?)
        @properties['chrDefinitionFileExtension'] = @defaultVGPValues['chrDefinitionFileExtension']
      else
        @properties['chrDefinitionFileExtension'] = @chrDefinitionFileExtension
      end




      
      @properties['outputDirectory'] = @outPutDir

      @properties['outputFormat'] = @defaultVGPValues['outputFormat']
      @properties['figureTitle'] = @figureTitle unless(@omitTitle)      
      @properties['subtitle'] = @subTitle  unless(@omitSubTitle)
      @properties['yAxisLabelFormat'] = @defaultVGPValues['yAxisLabelFormat']
      @properties['xAxisLabel'] = @defaultVGPValues['xAxisLabel']
      @properties['yAxisLabel'] = @defaultVGPValues['yAxisLabel']
      
      generateChromosomeView(chromosomeWidth, chromosomeHeight) if(@chromosomeView)
      generateGenomicView(genomeWidth, genomicHeight, genomicMargin) if(@genomicView)
      
      @properties['chromosomeLabels'] = @defaultVGPValues['chromosomeLabels']     


      unless(@omitLegend)
        @properties['legend'] = Hash.new{|hh,kk| hh[kk]=nil;}
        @properties['legend']['position'] = @defaultVGPValues['legend']['position']
        @properties['legend']['border'] = @defaultVGPValues['legend']['border']
      end
      
      if(referenceTrack)        
        typeOfTrack = 'referenceTrack'      
        @properties[typeOfTrack] = Hash.new{|hh,kk| hh[kk]=nil;}
        trackName = referenceTrackName
        @properties[typeOfTrack][trackName] = Array.new()
        generateCytoBand(@properties[typeOfTrack][trackName], referenceTrackName , referenceMargin, referenceWidth, 0)
      end        
  
  
      typeOfTrack = 'tracks'        
      @properties[typeOfTrack] = Hash.new{|hh,kk| hh[kk]=nil;}
      


     
      @trackProperties.each_key{|trackName|
          @properties[typeOfTrack][trackName] = Array.new()
          trackStyle = @trackProperties[trackName]
          trackStyle.each_key{|style|
                fillTrackArray(@properties[typeOfTrack][trackName], trackName, style, trackStyle[style])            
            }
          }
  
    end #end of method
      
    def printPropertiesFile()    
        fileWriter = nil
        begin  
          fileWriter = BRL::Util::TextWriter.new(@vgpConfigurationFile)
          fileWriter.puts JSON.pretty_generate(@properties)
          fileWriter.close
        rescue => err
          $stderr.puts "ERROR: bad line found. Blank columns? . Details: #{err.message}"
          $stderr.puts err.backtrace.join("\n")
          $stderr.puts "LINE: #{line.inspect}"
          exit 137
        end
    end #end of method
    
end #end of class

class DownloadLffFile
  attr_accessor :lffFileName, :refSeqId, :userId, :trackNames, :numberOfExtraFiles, :entryPointHash 
  attr_accessor :extra, :onlyStandardChrom, :nameOfExtraFiles, :fileExtension

 def initialize(lffFile, refSeqId, userId, trackNames, entryPointsOnly=false,
                onlyStdChrom=false, numberOfExtraFiles="1", fileExtension=nil)
  @lffFileName = lffFile
  @lffFileName = CGI.unescape(@lffFileName) if(@lffFileName.class == String)
  @fileExtension = nil
  @fileExtension = fileExtension
  @fileExtension = CGI.unescape(@fileExtension) if(@fileExtension.class == String)
  @refSeqId = refSeqId
  @refSeqId= CGI.unescape(@refSeqId) if(@refSeqId.class == String)  
  @userId = userId
  @numberOfExtraFiles = 1
  @numberOfExtraFiles = numberOfExtraFiles.to_i if(!numberOfExtraFiles.nil?)
  @entryPointHash = Hash.new {|hh, kk| hh[kk] = []}
  @nameOfExtraFiles = Array.new()
  @userId = CGI.unescape(@userId) if(@userId.class == String)  
  if(entryPointsOnly)
      @extra = " -i "
    else
      @extra = " -b "
  end
  @onlyStandardChrom = onlyStandardChrom

  @trackNames = trackNames
  @trackNames = CGI.unescape(@trackNames) if(@trackNames.class == String) 
  @trackNames = @trackNames.split(/,/)
  downloadLff()
  filterEntryPoints() if(entryPointsOnly and onlyStdChrom)
  createExtraFiles() if(@numberOfExtraFiles > 1)
 end
 
 
 def createExtraFiles()
   status = "createExtraFiles"
   stdChom = STANDARDCHROM.split(/,/)
  begin
      if(@numberOfExtraFiles > 1)
        tempNum = @numberOfExtraFiles.to_f
        numberPerGroup = (stdChom.length / tempNum ).ceil
        i = 0
        counter = 0
        @numberOfExtraFiles.times do
          group = stdChom.slice(i,numberPerGroup)
          break if(group.nil?)
          fileWriterOutPutFile = BRL::Util::TextWriter.new("#{@lffFileName}_#{counter}.#{@fileExtension}")
          @nameOfExtraFiles << "#{@lffFileName}_#{counter}.#{@fileExtension}"
          group.each{|key|
            line = @entryPointHash[key]
            fileWriterOutPutFile.puts line
            }
          fileWriterOutPutFile.close()
          i += numberPerGroup
          counter += 1
        end
      end
      rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? status = #{status} Line num: #{counter}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 125
    end    
  end 
 

  def downloadLff()
    if(@fileExtension.nil?)
      fileName = @lffFileName
    else
      fileName = "#{@lffFileName}.#{@fileExtension}"
    end

      commandStr = "java -classpath #{JCLASS_PATH} -Xmx1800M " +
        " org.genboree.downloader.AnnotationDownloader " +
        " -r '#{@refSeqId}' " +
        " -u '#{@userId}' #{@extra}" +
        " -m '#{@trackNames.join(",")}' " +
        " -f '#{fileName}' " +
        " 2> #{@lffFileName}.err "

      puts commandStr
      cmdOk = system(commandStr)
      unless(cmdOk)
        raise "\n\nERROR: downloadLff => error with calling annotation downloader.\n" +
        "    - exit code: #{$?}\n" +
        "    - command:   #{commandStr}\n"
        exit($?)
      end
  end
  
  def filterEntryPoints()
    reader = nil
    if(@fileExtension.nil?)
      fileName = @lffFileName
    else
      fileName = "#{@lffFileName}.#{@fileExtension}"
    end
    
    line = nil
    status = "reading"
    counter = 0
    begin
      reader = BRL::Util::TextReader.new(fileName)  
      reader.each { |line|
        errofLevel = 0
        lineArray = line.strip.split(/\t/) if(!line.nil?)
        if(line !~ /\S/ or line =~ /^\s*[\[#]/ or lineArray.length < 3)
            counter += 1
          next
        end
        @entryPointHash[lineArray[0].strip] = line
        counter += 1
      }
      reader.close()
      line = nil

      status = "filtering"
      fileWriterOutPutFile = BRL::Util::TextWriter.new(fileName)
      stdChom = STANDARDCHROM.split(/,/)
      stdHash = Hash.new{|hh,kk| hh[kk]=nil;}
      stdChom.each{|key|
        stdHash[key] = nil
      }
      @entryPointHash.each_key{|key|
        if(stdHash.has_key?( key ))
          line = @entryPointHash[key]
          fileWriterOutPutFile.puts line
        end
      }
      fileWriterOutPutFile.close()

    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? status = #{status} Line num: #{counter}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    
  end
end


class RenameTracksInLffFile
  attr_accessor :readFileStr, :outPutFile
  attr_accessor :className, :typeName, :subTypeName


  def initialize(readFile, outFile, className=nil, typeName=nil, subTypeName=nil)
    @readFileStr = readFile
    @readFileStr = CGI.unescape(@readFileStr) if(@readFileStr.class == String)
    @outPutFile = outFile
    @outPutFile = CGI.unescape(@outPutFile) if(@outPutFile.class == String)
    @className = className
    @className = CGI.unescape(@className) if(@className.class == String)
    @className = @className.to_sym if(!@className.nil?)
    @typeName = typeName
    @typeName = CGI.unescape(@typeName) if(@typeName.class == String)
    @typeName = @typeName.to_sym if(!@typeName.nil?)
    @subTypeName = subTypeName
    @subTypeName = CGI.unescape(@subTypeName) if(@subTypeName.class == String)
    @subTypeName = @subTypeName.to_sym if(!@subTypeName.nil?)
    createFiles()
  end


  def createFiles()
    # Read  file
    lffHash = nil
    reader = BRL::Util::TextReader.new(@readFileStr)
    fileWriterOutPutFile = BRL::Util::TextWriter.new(@outPutFile)
    line = nil
    lineCounter = 1
    gainLoss = false
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        aa = line.strip.split(/\t/)
        next if( aa.length < 10 )
        lffHash = LFFHash.new(line)
        lffHash.lffClass= @className if(!@className.nil?)
        lffHash.lffType= @typeName if(!@typeName.nil?)
        lffHash.lffSubtype= @subTypeName if(!@subTypeName.nil?)
        fileWriterOutPutFile.puts lffHash.to_lff
        lineCounter = lineCounter + 1
      }

      fileWriterOutPutFile.close()
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
 end   
    
end #end of Class

	class SendEmailToUser
    attr_accessor :userId, :serverName, :baseProject, :projectName, :emailAddresses, :duplicatedProject
		
		def initialize(baseProject, projectName, userId, rawFileName, messageType, defaultPropFile, duplicatedProject=false, originalProjName=nil)
      @userId = userId
      @rawFileName = rawFileName
      @baseProject = baseProject
      @projectName = projectName
      @message = "empty"
      @duplicatedProject = duplicatedProject
      @originalProjName = originalProjName
			tempFile = defaultPropFile
			tempFile = CGI.unescape(tempFile) if(tempFile.class == String)
			@defaultProperties = JSON.parse(File.read(tempFile))
      @userObj = BRL::Genboree::ToolPlugins.getUser( userId )
      genbConfig = BRL::Genboree::GenboreeConfig.load()
      @serverName = genbConfig.machineName
			@name = "#{@userObj[3]} #{@userObj[4]}"
			@email = @userObj[6]
			@sender = genbConfig.gbFromAddress
			@projectPath = genbConfig.gbProjectContentDir
			@resourcesDir = genbConfig.gbResourcesDir
			@properties = Hash.new{|hh,kk| hh[kk]=nil;}
			@properties['userName'] = @name
 			@properties['acghFileName'] = @rawFileName
 			@properties['directLinkToProject'] = "http://#{@serverName}#{@defaultProperties['REGISTERSUBPRO_PART3']}#{@baseProject}/#{@projectName}"
			@properties['directLinkToProjectHTML'] = "<a href=\"http://#{@serverName}#{@defaultProperties['REGISTERSUBPRO_PART3']}#{@baseProject}/#{@projectName}\" >#{@projectName}</a>"
			@properties['mainProjectLink'] = "http://#{@serverName}#{@defaultProperties['REGISTERSUBPRO_PART3']}#{@baseProject}"
			@properties['mainProjectLinkHTML'] = "<a href=\"http://#{@serverName}#{@defaultProperties['REGISTERSUBPRO_PART3']}#{@baseProject}\" >#{@baseProject}</a>"
			@properties['genbadmin'] = @sender
			@properties['projectName'] = projectName
			generateSubject(messageType)			
			generateMessageBody(messageType)

			
			sendEmail()
		end
		
		
		def generateSubject(messageType)
			if(messageType == "succed")
				@subject = @defaultProperties['SUCCESS_SUBJECT']
      elsif(messageType == "succedButDuplicatedProject")
				@subject = @defaultProperties['DUP_SUCCESS_SUBJECT']
      else
				@subject = @defaultProperties['FAIL_SUBJECT']
			end
		end

      def sendEmail()
        begin
					mailer = BRL::Util::Emailer.new()
          mailer.setHeaders( @sender, @email, @subject )
          mailer.addHeader("Content-Transfer-Encoding: 7bit")
          mailer.addHeader('Content-Type: multipart/alternative; boundary="_---[boundary]---_"')
          mailer.addHeader('MIME-Version: 1.0')
          mailer.setBody( @message )
          mailer.addRecipient( @email )
          mailer.setMailFrom( @sender )
          mailer.send()
        rescue => @err
          $stderr.puts @err
          $stderr.puts @err.backtrace
        end
      end
		
		
		
		def generateMessageBody(messageType)

			templateDir = "#{@resourcesDir}/#{@defaultProperties['TEMPLATES']}/"
			
			if(messageType == "succed")
				templateFile = "#{templateDir}#{@defaultProperties['SUCCESS_TEMPLATE']}"
				if(@duplicatedProject)
          templateFile = "#{templateDir}#{@defaultProperties['DUP_SUCCESS_TEMPLATE']}"
          if(!@originalProjName.nil? and @originalProjName.size > 1)
            @properties['originalProjName'] = @originalProjName
          else
            @properties['originalProjName'] = "unknown value"
          end
				end
			else
				templateFile = "#{templateDir}#{@defaultProperties['FAIL_TEMPLATE']}"
			end
			
			begin
				reader = File.read(templateFile)
			rescue => err
				$stderr.puts "ERROR: calling class SendEmailToUser: bad template file: #{templateFile}. Details: #{err.message}"
				exit(158)
			end
				
			begin 
				eruby = Erubis::Eruby.new(reader) 
				@message = eruby.result(binding())
			rescue => err
				$stderr.puts "ERROR: calling class SendEmailToUser: during processing templateFile: #{templateFile}. Details: #{err.message}"
				exit(101)
			end	
			
		end
	
end


	class RegisterSubProjects
    attr_accessor :serverName, :baseProject, :projectName, :mainProjectUpdateFile
		attr_accessor :mainProjectCustomFile, :projectQuickLinkFile, :defaultProperties
		

		def initialize(projectsPath, serverName, baseProject, projectName, defaultPropFile)
      @serverName = serverName
      @serverName = CGI.unescape(@serverName) if(@serverName.class == String)
      @baseProject = baseProject
      @projectName = projectName
      tempFile = defaultPropFile
      tempFile = CGI.unescape(tempFile) if(tempFile.class == String)
      @defaultProperties = JSON.parse(File.read(tempFile))
      @projectsPath = projectsPath
      @projectsPath = CGI.unescape(@projectsPath) if(@projectsPath.class == String)
      @mainProjectUpdateFile = "#{@projectsPath}/#{baseProject}/#{@defaultProperties['PROJECT_OPTIONAL']}/#{@defaultProperties['UPDATESFILE']}"
      @mainProjectCustomFile = "#{@projectsPath}/#{baseProject}/#{@defaultProperties['PROJECT_OPTIONAL']}/#{@defaultProperties['CUSTOMFILE']}"
      @projectQuickLinkFile = "#{@projectsPath}/#{baseProject}/#{projectName}/#{@defaultProperties['PROJECT_OPTIONAL']}/#{@defaultProperties['QUICKLINKS']}"
      registerToUpdateText()
      registerToCustomLinks()
      addBackToMainLink()

		end 

    def registerToUpdateText()
        tempHash = Hash.new {|hh,kk| hh[kk] = nil }
        tempHash['updateText'] = "#{@defaultProperties['REGISTERSUBPRO_PART1']}#{@defaultProperties['REGISTERSUBPRO_PART2']}#{@serverName}#{@defaultProperties['REGISTERSUBPRO_PART3']}#{@baseProject}/#{@projectName}\">#{CGI.unescape(@projectName)}#{@defaultProperties['REGISTERSUBPRO_PART4']}"
        t = Time.new()
        tempHash['date'] = "#{t.year}/#{t.month}/#{t.day}"
        addToJsonFile(@mainProjectUpdateFile, tempHash, "a") 
    end


    def registerToCustomLinks()
      tempHash = Hash.new {|hh,kk| hh[kk] = nil }
			tempHash['linkDesc'] = ""
			tempHash['url'] = "#{@defaultProperties['REGISTERSUBPRO_PART2']}#{@serverName}#{@defaultProperties['REGISTERSUBPRO_PART3']}#{@baseProject}/#{@projectName}"
			tempHash['linkText'] = "#{@defaultProperties['REGISTERSUBPRO_PART5']} #{CGI.unescape(@projectName)}" 
      addToJsonFile(@mainProjectCustomFile, tempHash, "b")      
		end

    def addBackToMainLink()
			tempHash = Hash.new {|hh,kk| hh[kk] = nil }
			tempHash['url'] = "#{@defaultProperties['REGISTERSUBPRO_PART2']}#{@serverName}#{@defaultProperties['REGISTERSUBPRO_PART3']}#{@baseProject}"
			tempHash['linkText'] = "#{@defaultProperties['REGISTERSUBPRO_PART6']} #{CGI.unescape(@baseProject)} #{@defaultProperties['REGISTERSUBPRO_PART7']}"
			addToJsonFile(@projectQuickLinkFile, tempHash, "b")  
		end	




    def addToJsonFile(fileName, tempHash, mode="a")
      
      bigArrayWithContent = nil
      begin
        bigArrayWithContent = JSON.parse(File.read(fileName))
      rescue
        bigArrayWithContent = Array.new()
      end
  
      if(mode == "b")
          bigArrayWithContent.unshift(tempHash)
      else
         bigArrayWithContent << tempHash  
      end

		 begin
			fileWriter = BRL::Util::TextWriter.new(fileName)
			fileWriter.puts JSON.pretty_generate(bigArrayWithContent)
			fileWriter.close()

		 rescue => err
			$stderr.puts "ERROR: File #{fileName} do not exist!. Details: method = registerToUpdateText() #{err.message}"
			#      exit 345 #Do not exit just record the error!
			end     
		end

	
	end

class DeployVGPFilesToProject
	attr_accessor :destinationHTMLDir, :destinationImageDir, :chrHtmlOrigTag, :projectName, :baseProject
	attr_accessor :chrHtmlNewTag, :htmlFilesDir, :imageFilesDir, :imageSubFix, :defaultProperties, :destinationContentPart
	attr_accessor :htmlSubFix, :scratchDir, :contentPart, :numberOfGenomicPanels, :resultDirNamePrefix


	def initialize(baseProject, projectName,resultDirNamePrefix, scratchDir, contentPart, numberOfGenomicPanels, defaultPropFile)
	    genbConfig = GenboreeConfig.load()
	    projectPath = genbConfig.gbProjectContentDir
	    @defaultProperties = JSON.parse(File.read(defaultPropFile))
	    @scratchDir = scratchDir
	    @contentPart = contentPart
	    @baseProject = baseProject
	    @projectName = projectName
	    @resultDirNamePrefix = resultDirNamePrefix
	    @numberOfGenomicPanels = numberOfGenomicPanels.to_i
	    projectFullPath = "#{projectPath}/#{baseProject}/#{projectName}"
	    @destinationHTMLDir = "#{projectFullPath}/#{@defaultProperties['ADDITIONAL_PAGES']}"
	    @destinationImageDir = "#{projectFullPath}/#{@defaultProperties['ADDITIONAL_FILES']}/#{@defaultProperties['GRAPHIC_DIRNAME']}"
	    @destinationContentPart = "#{projectFullPath}/#{@defaultProperties['PROJECT_OPTIONAL']}/#{@defaultProperties['FILE_WITH_HTML_CONTENT']}"
	    @chrHtmlOrigTag = @defaultProperties['CHRHTMLORIGTAG']
	    @chrHtmlNewTag = "/projects/#{baseProject}/#{projectName}/#{@defaultProperties['ADDITIONAL_FILES']}/#{@defaultProperties['GRAPHIC_DIRNAME']}"
	    @htmlFilesDir = "#{scratchDir}/#{resultDirNamePrefix}/#{@defaultProperties['HTMLDIR']}"
	    @imageFilesDir = "#{scratchDir}/#{resultDirNamePrefix}/#{@defaultProperties['IMAGESDIR']}"
	    @genomicVGPJavaScriptCall = "<script type=\"text/javascript\" src=\"/projects/#{baseProject}/#{projectName}/#{@defaultProperties['ADDITIONAL_PAGES']}/#{@defaultProperties['VGPGENOMIC_SCRIPT']}\"></script>"
      @genomicHtmlOrigTag = "#{@defaultProperties['GENOMICHTMLORIGTAG']}"
      @genomicImageOrigTag = "#{@defaultProperties['CHRHTMLORIGTAG']}/#{@defaultProperties['GENOMIC_IMAGE_FILE_NAME']}"


	    moveChromosomeFiles()
	    moveGenomicFiles()
	end 
              
	def fixChromosomeHtmlFile(fileName)
	   fileArray = nil
	   begin 
	      fileArray = Array.new()  
	      reader = BRL::Util::TextReader.new(fileName)
	      reader.each { |line|
            line.gsub!(%r{#{@chrHtmlOrigTag}}, @chrHtmlNewTag) if(line =~ /\S/ and line =~ %r{#{@chrHtmlOrigTag}} ) 
            fileArray << line #if(line =~ /\S/)
	      }
	      reader.close()
	  rescue => err
	    $stderr.puts "ERROR: opening and reading file: #{fileName}. Details: #{err.message}"
	    $stderr.puts err.backtrace.join("\n")
	    exit 137
	  end
	  begin
	    fileWriterOutPutFile = BRL::Util::TextWriter.new(fileName)
	    fileWriterOutPutFile.puts fileArray
	    fileWriterOutPutFile.puts @defaultProperties['CHROMOSOMEVGPJAVASCRIPTCALL']
	    fileWriterOutPutFile.close()
	  rescue => err
	    $stderr.puts "ERROR: writting to file: #{fileName}. Details: #{err.message}"
	    $stderr.puts err.backtrace.join("\n")
	    exit 138
	  end
	end


	
	def appendGenomicFileToContentPart(fileName, genomicImageName, counter)
	   fileArray = nil
	   genomicHtmlNewTag = "#{@genomicHtmlOrigTag}_#{counter}"
	   genomicImageNewTag = "/projects/#{@baseProject}/#{@projectName}/#{@defaultProperties['ADDITIONAL_FILES']}/#{@defaultProperties['GRAPHIC_DIRNAME']}/#{genomicImageName}"
	   begin 
	      fileArray = Array.new()  
	      reader = BRL::Util::TextReader.new(fileName)
	      reader.each { |line|
		  line.gsub!(%r{#{@genomicHtmlOrigTag}}, genomicHtmlNewTag) if(line =~ /\S/ and line =~ %r{#{@genomicHtmlOrigTag}} )
		  line.gsub!(%r{#{@genomicImageOrigTag}}, genomicImageNewTag) if(line =~ /\S/ and line =~ %r{#{@genomicImageOrigTag}} ) 
		  fileArray << line #if(line =~ /\S/)
	      }
	      reader.close()
	  rescue => err
	    $stderr.puts "ERROR: opening and reading file: #{fileName}. Details: #{err.message}"
	    $stderr.puts err.backtrace.join("\n")
	    exit 137
	  end
	  begin
	    fileWriterOutPutFile = BRL::Util::TextWriter.new(@contentPart, 'a')
	    fileWriterOutPutFile.puts fileArray
	    fileWriterOutPutFile.puts "\n\n"
	    fileWriterOutPutFile.close()
	  rescue => err
	    $stderr.puts "ERROR: writting to file: #{fileName}. Details: #{err.message}"
	    $stderr.puts err.backtrace.join("\n")
	    exit 138
	  end
	end
	

	def moveGenomicFiles()
            begin
                fileWriterOutPutFile = BRL::Util::TextWriter.new(@contentPart, 'a')
                fileWriterOutPutFile.puts @genomicVGPJavaScriptCall
                fileWriterOutPutFile.puts "\n\n"
                fileWriterOutPutFile.close()
            rescue => err
                $stderr.puts "ERROR: writting to file: #{@contentPart}. Details: #{err.message}"
                $stderr.puts err.backtrace.join("\n")
                exit 135
            end
            currentDir = Dir.getwd
            genomicDirectoryArray = Array.new()
            genomicFileNamePrefix = Array.new()

            tempCounter = 0
            @numberOfGenomicPanels.times do
                genomicDirectoryArray << "#{resultDirNamePrefix}_#{tempCounter}"
                genomicFileNamePrefix << "#{@defaultProperties['GENOMIC_PREFIX']}#{tempCounter}"
                tempCounter += 1
            end

	      
            Dir.mkdir( @destinationImageDir ) unless(File.directory?(@destinationImageDir))

            
            genomicDirectoryArray.each_index{|genomicIndex|
                  genomicDir = genomicDirectoryArray[genomicIndex]
                  genomicNewImageFileName = "#{genomicFileNamePrefix[genomicIndex]}.#{@defaultProperties['IMAGETYPE']}"
                  genomicHtmlDir = "#{@scratchDir}/#{genomicDir}/#{@defaultProperties['HTMLDIR']}"
                  genomicImageFilesDir = "#{@scratchDir}/#{genomicDir}/#{@defaultProperties['IMAGESDIR']}"
                  genomicMapFileName = "#{genomicHtmlDir}/#{@defaultProperties['GENOMIC_MAP_FILE_NAME']}"
                  File.copy("#{genomicImageFilesDir}/#{@defaultProperties['GENOMIC_IMAGE_FILE_NAME']}", "#{@destinationImageDir}/#{genomicNewImageFileName}")
                  appendGenomicFileToContentPart(genomicMapFileName, genomicNewImageFileName, genomicIndex)
              }
            File.copy(@contentPart, @destinationContentPart)
	end 
              
              
	def moveChromosomeFiles()
	      currentDir = Dir.getwd
	      Dir.chdir(@htmlFilesDir)
	       resultFiles =  Dir[ "#{@htmlFilesDir}/*#{@defaultProperties['HTMLDIR']}" ]

	       resultFiles.each { | fileName |
            fixChromosomeHtmlFile(fileName)
            File.copy(fileName, "#{@destinationHTMLDir}/#{File.basename(fileName)}")
	      }
	      Dir.mkdir( @destinationImageDir ) unless(File.directory?(@destinationImageDir))
	      Dir.chdir(@imageFilesDir)
	      resultFiles =  Dir[ "#{@imageFilesDir}/*#{@defaultProperties['IMAGETYPE']}" ]
        resultFiles.each { | fileName |
          File.copy(fileName, "#{@destinationImageDir}/#{File.basename(fileName)}")
	      }
	      Dir.chdir(currentDir)
	end 
              
end

	class JsonFromLff
    attr_accessor :listOfProps, :hashOfGenes, :lffFileName, :tableHeaders
    attr_accessor :bigArrayWithContent, :jsonFileName, :properties

		def initialize(lffFileName, jsonFileName, refSeqId, trackName, serverName, baseProject, projectName)
		 @listOfProps = [ "@lffName", "@lffChr", "@lffStart", "@lffStop", "@lffLength",
			 "@lffScore", :nameOfGenesAffected, :originalAnnotationName  ]
		 @tableHeaders = [ "Name", "Chromosome", "Start", "Stop", "Length",
			 "Score", "Affected Genes", "Segment Name"  ]
		 @hashOfGenes = Hash.new {|hh,kk| hh[kk] = nil }
		 @bigArrayWithContent = Array.new()
		 @bigArrayWithContent << @tableHeaders
		 @lffFileName = lffFileName
		 @jsonFileName = jsonFileName
		 @properties = Hash.new{|hh,kk| hh[kk]=nil;}
		 @properties['refSeqId'] = refSeqId
		 tempTrackName = CGI.unescape(trackName) if(trackName.class == String)
		 tempTrackName = CGI.escape(tempTrackName)
		 @properties['trackName'] = tempTrackName
		 @properties['serverName'] = CGI.unescape(serverName) if(serverName.class == String)
		 tempBaseProject = CGI.unescape(baseProject) if(baseProject.class == String)
		 tempProjectName = CGI.unescape(projectName) if(projectName.class == String)
		 @properties['projectName'] = "#{tempBaseProject} #{tempProjectName}"

		 
		 readLffFile()
		 printList()
		end 

		def readLffFile()
		 begin
			lffReader = BRL::Util::TextReader.new(@lffFileName)
			lffReader.each { |line|
				line.strip!
				tAnno = line.split(/\t/)
				next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)				
				myHash = LFFHash.new(line)
				key = SHA1.new(line).to_s
#				name = "#{myHash.lffName}".strip().gsub(/\.\d+$/, "").strip
				@hashOfGenes[key] = myHash if(!@hashOfGenes.has_key?(key))
			}

			lffReader.close()
		 rescue => err
			$stderr.puts "ERROR: File #{lffFileName} do not exist!. Details: method = readLffFile() #{err.message}"
			#      exit 345 #Do not exit just record the error!
			end     
		end

		def printList()
			begin
				@hashOfGenes.each_key { |myKey|
					myHash = @hashOfGenes[myKey]
						list = Array.new()
						@listOfProps.each{|key|
              temp = myHash[key]
              begin
              temp = myHash.instance_variable_get(key) if(temp.nil?)
              rescue
                temp = ""
              end
              temp = "#{temp}"
              if(temp =~ /.*[,].*/ )
                elements = temp.split(/,/)
                if(elements.size > 10)
                  temp = "too many elements to display (#{elements.size} elements)"
                else
                  temp = temp.gsub(/,/, ", ")
                end
              end
						  list << temp
					}
					@bigArrayWithContent << list
				}  
			rescue => err
				$stderr.puts "ERROR:  #{err.message}"
				#      exit 345 #Do not exit just record the error!
			end
			
      @properties['content'] = @bigArrayWithContent
			fileWriter = BRL::Util::TextWriter.new(@jsonFileName)
			fileWriter.puts JSON.pretty_generate(@properties)
			fileWriter.close()
		end
	end

class ReadACGHJsonFile
  attr_accessor :arrayOfApplications, :scratchDir


  def initialize(fileName, scratchDir, mode="exec")
    tempmode = mode
    tempmode = CGI.unescape(tempmode) if(tempmode.class == String)
    @scratchDir =  scratchDir  
    @scratchDir = CGI.unescape(@scratchDir) if(@scratchDir.class == String)
    Dir.chdir( @scratchDir )
    tempFileName = fileName
    tempFileName = CGI.unescape(tempFileName) if(tempFileName.class == String)
    @arrayOfApplications = JSON.parse(File.read(tempFileName))
    @sendEmail = nil
    extractSendEmail()
    if(tempmode  == "printOnly")
      printProp()
    else
      execProp()
    end
  end
  

  def extractSendEmail()
  @arrayOfApplications.each{|applicationHash|
    if(applicationHash.has_key?("emailUser.rb"))
      @sendEmail = applicationHash  
      @arrayOfApplications.delete(applicationHash)
    end
  }
  end


  def execProp()
    toExec = ""
    cmdOK = false
    valid = 0
    
      @arrayOfApplications.each{|applicationHash|
        applicationHash.each_key{|app|
          toExec = "#{app} "
          commands = applicationHash[app]
          encode = false
          separator = commands['sepPrefix']
          commands.delete('sepPrefix')
          encode = commands['encode'] if(commands.has_key?('encode'))
          commands.delete('encode') if(commands.has_key?('encode'))
          commands.each_key{|comm|
              argum = commands[comm]
              argum = CGI.escape(argum) if(encode)
                  toExec += " #{separator}#{comm} \"#{argum}\""
                }
          }
        
        cmdOK = system( toExec )
        if(cmdOK)
          puts "Command successfull #{toExec}"
        else
          errMsg = "\n\nThe \n#{toExec}\n program failed and did not fully complete.\n\n"
          $stderr.puts  "DETECTOR ERROR: pipeLine died: '#{errMsg.strip}'\n"
          raise errMsg
        end
        }
      
      
      if(cmdOK)
        @sendEmail['emailUser.rb']['messageType'] = 'succed'
      else
        @sendEmail['emailUser.rb']['messageType'] = 'fail'
      end
      
    toExec = ""
    cmdOK = false  
      @sendEmail.each_key{|app|
          toExec = "#{app} "
          commands = @sendEmail[app]
          encode = false
          separator = commands['sepPrefix']
          commands.delete('sepPrefix')
          encode = commands['encode'] if(commands.has_key?('encode'))
          commands.delete('encode') if(commands.has_key?('encode'))
          commands.each_key{|comm|
              argum = commands[comm]
              argum = CGI.escape(argum) if(encode)
                  toExec += " #{separator}#{comm} \"#{argum}\""
          }


        cmdOK = system( toExec )
        if(cmdOK)
          puts "Command successfull #{toExec}"
        else
          errMsg = "\n\nThe \n#{toExec}\n program failed and did not fully complete.\n\n"
          $stderr.puts  "DETECTOR ERROR: pipeLine died: '#{errMsg.strip}'\n"
          raise errMsg
        end
      }
      
  end


  def printProp()
    
      @arrayOfApplications.each{|applicationHash|
        applicationHash.each_key{|app|
          printf " #{app} "
          commands = applicationHash[app]
          encode = false
          separator = commands['sepPrefix']
          commands.delete('sepPrefix')
          encode = commands['encode'] if(commands.has_key?('encode'))
          commands.delete('encode') if(commands.has_key?('encode'))
          commands.each_key{|comm|
            var1 = " #{separator}#{comm} "
            printf "%s", var1
            if(encode)
              value = " '#{CGI.escape(commands[comm])}' "
            else
              value = " '#{commands[comm]}' "
            end
            printf "%s",value
            }
          }
        puts ""
        }
  end

end #end of Class


class CreatePipeLine
  attr_accessor :jsonFileWithPipeLine, :properties, :filesWithIntersectingTracksArray
  attr_accessor :agilentFileName, :agilentType, :agilentSubtype, :filesToUpload, :numberOfGenomicPanels
  attr_accessor :agilentClass, :agilentSegmentStddev, :agilentMinProbes, :scratchDir, :defaultPropFile
  attr_accessor  :trackHash, :refSeqId, :userId, :baseProjectName, :projectId, :allFiles, :resourcePath
  attr_accessor :segmentClassName, :segmentType, :segmentSubtype, :defaultProps, :genboreeGroupId
  
  
  def initialize(agilentFileName, agilentSegmentStddev, agilentMinProbes, listOfIntersectionTracks,
                 listOfGainColors, listOfLossColors, userId, refSeqId, baseProjectName, projectId, scratchDir,
                 agilentClass, agilentType, agilentSubtype, segmentClassName,
                 segmentType, segmentSubtype, genboreeGroupId, outFile=nil, defaultPropFile=nil, numberOfGenomicPanels=3)
        
    

    genbConfig = GenboreeConfig.load()
    @resourcePath = genbConfig.gbResourcesDir
    @serverName = genbConfig.machineName
    @projectPath = genbConfig.gbProjectContentDir
    
    tempFile = defaultPropFile
    tempFile = CGI.unescape(tempFile) if(tempFile.class == String)
    tempFile = "#{@resourcePath}/#{AGILENT_DEFAULTS}" if(tempFile.nil?)

    
    @defaultPropFile = tempFile
    @defaultProps = JSON.parse(File.read(tempFile))  
    @jsonFileWithPipeLine = nil
    tempFile = outFile
    @jsonFileWithPipeLine = CGI.unescape(tempFile) if(tempFile.class == String)
    @jsonFileWithPipeLine = @defaultProps['PIPELINE_FILE_NAME'] if(@jsonFileWithPipeLine.nil?)
    @filesWithIntersectingTracks = Array.new()
    @filesToUpload = Array.new()
    @allFiles = Array.new()
    @agilentFileName = agilentFileName
    @numberOfGenomicPanels = numberOfGenomicPanels
    @agilentFileName = CGI.unescape(@agilentFileName) if(@agilentFileName.class == String)
    @agilentType = agilentType
    @agilentType = CGI.unescape(@agilentType) if(@agilentType.class == String)
    @agilentSubtype = agilentSubtype
    @agilentSubtype = CGI.unescape(@agilentSubtype) if(@agilentSubtype.class == String)
    @agilentClass = agilentClass
    @agilentClass = CGI.unescape(@agilentClass) if(@agilentClass.class == String)
    @segmentClassName = segmentClassName 
    @segmentClassName = CGI.unescape(@segmentClassName) if(@segmentClassName.class == String)
    @segmentType = segmentType
    @segmentType = CGI.unescape(@segmentType) if(@segmentType.class == String)
    @segmentSubtype = segmentSubtype
    @segmentSubtype = CGI.unescape(@segmentSubtype) if(@segmentSubtype.class == String)
    @scratchDir =  scratchDir  
    @scratchDir = CGI.unescape(@scratchDir) if(@scratchDir.class == String)
    Dir.chdir( @scratchDir )
    @agilentSegmentStddev = agilentSegmentStddev
    @agilentSegmentStddev = CGI.unescape(@agilentSegmentStddev) if(@agilentSegmentStddev.class == String)
    @agilentMinProbes = agilentMinProbes
    @agilentMinProbes = CGI.unescape(@agilentMinProbes) if(@agilentMinProbes.class == String)
    @refSeqId =  refSeqId
    @refSeqId = CGI.unescape(@refSeqId) if(@refSeqId.class == String)
    @userId = userId
    @userId = CGI.unescape(@userId) if(@userId.class == String)
    @baseProjectName = baseProjectName
    @baseProjectName = CGI.unescape(@baseProjectName) if(@baseProjectName.class == String)
    @projectId = projectId    
    @projectId = CGI.unescape(@projectId) if(@projectId.class == String)
    @mainProjectExist = false
    @mainProjectExist = true if(File.exists?("#{@projectPath}/#{@baseProjectName}") and File.directory?("#{@projectPath}/#{@baseProjectName}") )
    @duplicatedProject = false
    @duplicatedProject = true if(File.exists?("#{@projectPath}/#{@baseProjectName}/#{@projectId}") )
    @originalProjectName = nil
    
    if(@duplicatedProject)
      @originalProjectName = @projectId
      @projectId = "#{@projectId}_#{Time.now.to_i.to_s}"
    end

    @genboreeGroupId =  genboreeGroupId   
    @genboreeGroupId = CGI.unescape(@genboreeGroupId) if(@genboreeGroupId.class == String)
    intersectionTracks =  listOfIntersectionTracks   
    intersectionTracks = CGI.unescape(intersectionTracks) if(intersectionTracks.class == String)
    gainColors = listOfGainColors
    gainColors = CGI.unescape(gainColors) if(gainColors.class == String)
    lossColors = listOfLossColors
    lossColors = CGI.unescape(lossColors) if(lossColors.class == String)        
    @trackHash = generateTrackHash(intersectionTracks, gainColors, lossColors)

    @properties = Array.new()
    createFiles()
    
  end
  
def generateTrackHash(tracklist, gainList, lossList)
    tracks = tracklist.split(/;/)
    gainColors = gainList.split(/,/)
    lossColors = lossList.split(/,/)

    trackHash = Hash.new{|hh,kk| hh[kk]=nil;}
    tracks.each_index{|trackId|        
              trackName = tracks[trackId]
              gainColor = gainColors[trackId]
              lossColor = lossColors[trackId]
              trackHash[trackName] = Hash.new{|hh,kk| hh[kk]=nil;}
              trackHash[trackName]['order'] = trackId
              trackHash[trackName]['gain'] = gainColor
              trackHash[trackName]['loss'] = lossColor
    }
    return trackHash
end


    


#TRACKAVSTRING = 'OMIM:Morbid:track=OMIM:Morbid;variations:TCAG_UCSC:track=variations:TCAG_UCSC;'
def generateTrackAVString(trackHash, vp_name_static)
    trackAVString = ""
    trackHash.each_key{|track|
        trackAVString += "#{track}:#{vp_name_static}=#{track};"
        }
    return trackAVString
end


def generateArrayTracksInOrder(trackHash)
        trackNamesInOrder = Array.new()
        max = trackHash.size()
        trackHash.each_key{|trackName|
            order = trackHash[trackName]['order']
            trackNamesInOrder[order] = trackName
            }
        return trackNamesInOrder
end


def generateVGPString(trackHash, defaultTrackName, defaultGainColor, defaultLossColor)
    vgpString = ""

    trackNamesInOrder = generateArrayTracksInOrder(trackHash)
    
    trackNamesInOrder.each{|track|
        vgpString += "#{track}%gain=#{trackHash[track]['gain']}%loss=#{trackHash[track]['loss']};"
        }
    
    vgpString += "#{defaultTrackName}%gain=#{defaultGainColor}%loss=#{defaultLossColor};"
    return vgpString
end




  def createFiles()
    fileWriter = nil
    counter = 0
    

    
    begin

      fileWriter = BRL::Util::TextWriter.new(@jsonFileWithPipeLine)

      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['emailUser.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['emailUser.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['emailUser.rb']['encode'] = false
      @properties[counter]['emailUser.rb']['userId'] =  @userId.to_i
      @properties[counter]['emailUser.rb']['baseProject'] =  @baseProjectName
      @properties[counter]['emailUser.rb']['projectName'] =  @projectId
      @properties[counter]['emailUser.rb']['rawFileName'] =  @agilentFileName
      @properties[counter]['emailUser.rb']['messageType'] =  "fail"
      if(@duplicatedProject and !@originalProjectName.nil?)
        @properties[counter]['emailUser.rb']['originalProjName'] = @originalProjectName
        @properties[counter]['emailUser.rb']['duplicatedProject'] = @duplicatedProject
      end
      @properties[counter]['emailUser.rb']['defaultPropFile'] = @defaultPropFile
      counter += 1

      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['manageGenboreeProjects.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['manageGenboreeProjects.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['manageGenboreeProjects.rb']['encode'] = true
      @properties[counter]['manageGenboreeProjects.rb']['groupId'] = @genboreeGroupId.to_i      
      @properties[counter]['manageGenboreeProjects.rb']['userId'] = @userId.to_i
      @properties[counter]['manageGenboreeProjects.rb']['projectName'] = @projectId 
      @properties[counter]['manageGenboreeProjects.rb']['baseProject'] = @baseProjectName
      @properties[counter]['manageGenboreeProjects.rb']['action'] = "create"
      counter += 1
      
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['registerSubproject.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['registerSubproject.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['registerSubproject.rb']['encode'] = true
      @properties[counter]['registerSubproject.rb']['projectPath'] =  @projectPath
      @properties[counter]['registerSubproject.rb']['serverName'] =  @serverName
      @properties[counter]['registerSubproject.rb']['baseProject'] =  @baseProjectName
      @properties[counter]['registerSubproject.rb']['projectName'] =  @projectId
      @properties[counter]['registerSubproject.rb']['defaultPropFile'] = @defaultPropFile
      counter += 1
      
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['generateJavaScripts.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['generateJavaScripts.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['generateJavaScripts.rb']['encode'] = true
      @properties[counter]['generateJavaScripts.rb']['templateName'] =  "#{@resourcePath}/#{@defaultProps['TEMPLATES']}/#{@defaultProps['VGPCALLBACK_GENOMIC_TEMPLATE']}"
      @properties[counter]['generateJavaScripts.rb']['refSeqId'] =  @refSeqId
      @properties[counter]['generateJavaScripts.rb']['link'] =  @defaultProps['GBROWSERLINK']
      @properties[counter]['generateJavaScripts.rb']['projectlink'] =  @defaultProps['PROJECT_LINK']
      @properties[counter]['generateJavaScripts.rb']['javaScriptName'] =  "#{@projectPath}/#{@baseProjectName}/#{@projectId}/#{@defaultProps['ADDITIONAL_PAGES']}/#{@defaultProps['VGPCALLBACK_GENOMIC_FILE']}"
      @properties[counter]['generateJavaScripts.rb']['baseProject'] =  @baseProjectName
      @properties[counter]['generateJavaScripts.rb']['projectName'] =  @projectId
      @properties[counter]['generateJavaScripts.rb']['defaultPropFile'] = @defaultPropFile
      counter += 1      
      
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['generateJavaScripts.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['generateJavaScripts.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['generateJavaScripts.rb']['encode'] = true
      @properties[counter]['generateJavaScripts.rb']['templateName'] =  "#{@resourcePath}/#{@defaultProps['TEMPLATES']}/#{@defaultProps['VGPCALLBACK_CHROMOSOMIC_TEMPLATE']}"
      @properties[counter]['generateJavaScripts.rb']['refSeqId'] =  @refSeqId
      @properties[counter]['generateJavaScripts.rb']['link'] =  @defaultProps['GBROWSERLINK']
      @properties[counter]['generateJavaScripts.rb']['projectlink'] =  @defaultProps['PROJECT_LINK']
      @properties[counter]['generateJavaScripts.rb']['javaScriptName'] =  "#{@projectPath}/#{@baseProjectName}/#{@projectId}/#{@defaultProps['ADDITIONAL_PAGES']}/#{@defaultProps['VGPCALLBACK_CHROMOSOMIC_FILE']}"
      @properties[counter]['generateJavaScripts.rb']['baseProject'] =  @baseProjectName
      @properties[counter]['generateJavaScripts.rb']['projectName'] =  @projectId
      @properties[counter]['generateJavaScripts.rb']['defaultPropFile'] = @defaultPropFile
      counter += 1 
      

      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['downloadLffFiles.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['downloadLffFiles.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['downloadLffFiles.rb']['encode'] = true
      @properties[counter]['downloadLffFiles.rb']['refSeqId'] = @refSeqId     
      @properties[counter]['downloadLffFiles.rb']['trackNames'] =  @defaultProps['REFTRACK']
      @properties[counter]['downloadLffFiles.rb']['userId'] = @userId
      @properties[counter]['downloadLffFiles.rb']['lffFileToDownload'] = @defaultProps['CYTOBAND_LFF_FILE']
      counter += 1
      
      @allFiles << @defaultProps['CYTOBAND_LFF_FILE']
      @allFiles << "#{@defaultProps['CYTOBAND_LFF_FILE']}.err"
      
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['downloadLffFiles.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['downloadLffFiles.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['downloadLffFiles.rb']['encode'] = true
      @properties[counter]['downloadLffFiles.rb']['refSeqId'] = @refSeqId
      @properties[counter]['downloadLffFiles.rb']['trackNames'] =  @defaultProps['REFTRACK']
      @properties[counter]['downloadLffFiles.rb']['userId'] = @userId
      @properties[counter]['downloadLffFiles.rb']['lffFileToDownload'] = @defaultProps['DASFILE']
      @properties[counter]['downloadLffFiles.rb']['entryPointsOnly'] = ""
      @properties[counter]['downloadLffFiles.rb']['removeExtraEntryPoints'] = ""
      @properties[counter]['downloadLffFiles.rb']['numberOfExtraFiles'] =   @numberOfGenomicPanels
      @properties[counter]['downloadLffFiles.rb']['chrDefinitionFileExtension'] = @defaultProps['DAS_EXTENSION']

      counter += 1   
 
      @allFiles << "#{@defaultProps['DASFILE']}.#{@defaultProps['DAS_EXTENSION']}"
      @allFiles << "#{@defaultProps['DASFILE']}.err"
      
      if(@numberOfGenomicPanels > 1)
        tempCounter = 0
        @numberOfGenomicPanels.times do
          @allFiles << "#{@defaultProps['DASFILE']}_#{tempCounter}.#{@defaultProps['DAS_EXTENSION']}"
          tempCounter += 1
        end
      end

    @trackHash.each_key{|trackName|
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['downloadLffFiles.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['downloadLffFiles.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['downloadLffFiles.rb']['encode'] = true
      @properties[counter]['downloadLffFiles.rb']['trackNames'] =  trackName
      @properties[counter]['downloadLffFiles.rb']['refSeqId'] = @refSeqId
      @properties[counter]['downloadLffFiles.rb']['userId'] = @userId
      @properties[counter]['downloadLffFiles.rb']['lffFileToDownload'] = "#{trackName}_#{@refSeqId}.lff"

      counter += 1
      @filesWithIntersectingTracks << "#{trackName}_#{@refSeqId}.lff"
      @allFiles << "#{trackName}_#{@refSeqId}.lff"
      @allFiles << "#{trackName}_#{@refSeqId}.lff.err"
    }



      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}     
      @properties[counter]['createTempFileForAttriLifter.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['createTempFileForAttriLifter.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['createTempFileForAttriLifter.rb']['encode'] = true
      @properties[counter]['createTempFileForAttriLifter.rb']['lffFileToLabel'] = @filesWithIntersectingTracks.join(",")
      @properties[counter]['createTempFileForAttriLifter.rb']['lffWithVPs'] = @defaultProps['FILE_WITH_TRACKS_INTERSECT']
      @properties[counter]['createTempFileForAttriLifter.rb']['newVPName'] = @defaultProps['VP_NAME_STATIC']
      @properties[counter]['createTempFileForAttriLifter.rb']['newVPValue'] = @defaultProps['VP_VALUE_STATIC']
      counter += 1
      
      @allFiles << @defaultProps['FILE_WITH_TRACKS_INTERSECT']

      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['agilent2lff.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['agilent2lff.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['agilent2lff.rb']['encode'] = false
      @properties[counter]['agilent2lff.rb']['aFile'] = @agilentFileName
      @properties[counter]['agilent2lff.rb']['outputFile'] = "#{@agilentFileName}_res.lff"
      @properties[counter]['agilent2lff.rb']['type'] = @defaultProps['AGILENTSTATICTYPE']
      @properties[counter]['agilent2lff.rb']['subtype'] = @defaultProps['AGILENTSTATICSUBTYPE']
      @properties[counter]['agilent2lff.rb']['class'] = @defaultProps['AGILENTSTATICCLASS']
      @properties[counter]['agilent2lff.rb']['segmentStddev'] = @agilentSegmentStddev
      @properties[counter]['agilent2lff.rb']['minProbes'] = @agilentMinProbes
      counter += 1
      
      @allFiles << @agilentFileName
      @allFiles << "#{@agilentFileName}_res.lff"
      @allFiles << "#{@agilentFileName}_res.lff.raw.lff"
      @allFiles << "#{@agilentFileName}_res.lff.seg.err"
      @allFiles << "#{@agilentFileName}_res.lff.seg.lff"
      @allFiles << "#{@agilentFileName}_res.lff.seg.lff.segs.lff"
      @allFiles << "#{@agilentFileName}_res.lff.seg.lff.strip"
      
 
      # This file is to generate vgp and to upload to db      
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['changeColors.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['changeColors.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['changeColors.rb']['encode'] = true
      @properties[counter]['changeColors.rb']['inputFile'] = "#{@agilentFileName}_res.lff.raw.lff"
      @properties[counter]['changeColors.rb']['propFile'] = "#{@agilentFileName}_res.lff.seg.err"
      @properties[counter]['changeColors.rb']['outPutFile'] = @defaultProps['AGILENT_FILE_WITH_RIGHT_COLOR']
      @properties[counter]['changeColors.rb']['positiveColor'] = @defaultProps['POSITIVECOLOR']
      @properties[counter]['changeColors.rb']['negativeColor'] = @defaultProps['NEGATIVECOLOR']
      @properties[counter]['changeColors.rb']['colorClass'] = @agilentClass
      @properties[counter]['changeColors.rb']['colorType'] = @agilentType
      @properties[counter]['changeColors.rb']['colorSubType'] = @agilentSubtype
      counter += 1
      
      @filesToUpload << @defaultProps['AGILENT_FILE_WITH_RIGHT_COLOR']
      @allFiles << @defaultProps['AGILENT_FILE_WITH_RIGHT_COLOR']

      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['changeColors.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['changeColors.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['changeColors.rb']['encode'] = true
      @properties[counter]['changeColors.rb']['inputFile'] = "#{@agilentFileName}_res.lff.seg.lff.segs.lff"
      @properties[counter]['changeColors.rb']['outPutFile'] = @defaultProps['AGILENT_SEGMENT_FILE_WRC']
      @properties[counter]['changeColors.rb']['thresholdValue'] = @defaultProps['STATIC_THRESHOLD']
      @properties[counter]['changeColors.rb']['positiveColor'] = @defaultProps['POSITIVECOLOR']
      @properties[counter]['changeColors.rb']['negativeColor'] = @defaultProps['NEGATIVECOLOR']
      @properties[counter]['changeColors.rb']['colorClass'] = @agilentClass
      @properties[counter]['changeColors.rb']['colorType'] = @agilentType
      @properties[counter]['changeColors.rb']['colorSubType'] = @defaultProps['FINALINTERSECTTYPE']
      counter += 1
      
      @allFiles << @defaultProps['AGILENT_SEGMENT_FILE_WRC']
      
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['calculateMeanStd.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['calculateMeanStd.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['calculateMeanStd.rb']['encode'] = true
      @properties[counter]['calculateMeanStd.rb']['lffFilesWithScores'] = @defaultProps['AGILENT_SEGMENT_FILE_WRC']
      @properties[counter]['calculateMeanStd.rb']['prefFileWithScoreAndStd'] = @defaultProps['FILE_WITH_STD']
      counter += 1
      
      @allFiles << @defaultProps['FILE_WITH_STD']
      
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['attributeLifter.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['attributeLifter.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['attributeLifter.rb']['encode'] = false
      @properties[counter]['attributeLifter.rb']['firstOperandTrack'] = "#{@agilentType}:#{@defaultProps['FINALINTERSECTTYPE']}"
      @properties[counter]['attributeLifter.rb']['lffFiles'] = "#{@defaultProps['AGILENT_SEGMENT_FILE_WRC']},#{@defaultProps['FILE_WITH_TRACKS_INTERSECT']}"
      @properties[counter]['attributeLifter.rb']['outputFile'] = @defaultProps['INTERSECT_RESULT_FILE']
      @properties[counter]['attributeLifter.rb']['intersectAll'] = ""
      @properties[counter]['attributeLifter.rb']['newTrackName'] = "#{@agilentType}:#{@defaultProps['FINALINTERSECTTYPE']}"
      @properties[counter]['attributeLifter.rb']['class'] = @agilentClass
      @properties[counter]['attributeLifter.rb']['attributes'] =   generateTrackAVString(@trackHash, @defaultProps['VP_NAME_STATIC'])
      counter += 1
      
      @allFiles << @defaultProps['INTERSECT_RESULT_FILE']

      #this file is to generate the vgp
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['segInter.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['segInter.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['segInter.rb']['encode'] = true
      @properties[counter]['segInter.rb']['intersectFileName'] = @defaultProps['INTERSECT_RESULT_FILE']
      @properties[counter]['segInter.rb']['classifiedFile'] = @defaultProps['INTERSECT_IN_MULTIPLE_TRACKS']
      @properties[counter]['segInter.rb']['trackColors'] = generateVGPString(@trackHash, @defaultProps['DEFAULT_TRACKNAME'], @defaultProps['DEFAULTGAIN'], @defaultProps['DEFAULTLOSS'])
      @properties[counter]['segInter.rb']['threshold'] = @defaultProps['STATIC_THRESHOLD']
      @properties[counter]['segInter.rb']['classifiedTypeName'] = @defaultProps['INTERSECTTYPE']
      @properties[counter]['segInter.rb']['classifiedClassName'] = @defaultProps['CLASSIFIED_CLASS_NAME']
      @properties[counter]['segInter.rb']['defaultTrackName'] = @defaultProps['DEFAULT_TRACKNAME']
      @properties[counter]['segInter.rb']['defaultPropFile'] = @defaultPropFile
      counter += 1
      
      @allFiles << @defaultProps['INTERSECT_IN_MULTIPLE_TRACKS']

      #This file is for uploading into a db
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['renameTracks.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['renameTracks.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['renameTracks.rb']['encode'] = true
      @properties[counter]['renameTracks.rb']['lffFileToModify'] =  @defaultProps['INTERSECT_IN_MULTIPLE_TRACKS']
      @properties[counter]['renameTracks.rb']['newLffFile'] = @defaultProps['INTERSECT_IN_SINGLE_TRACK']
      @properties[counter]['renameTracks.rb']['className'] = @segmentClassName
      @properties[counter]['renameTracks.rb']['typeName'] = @segmentType
      @properties[counter]['renameTracks.rb']['subTypeName'] = @segmentSubtype
      counter += 1      

      @allFiles << @defaultProps['INTERSECT_IN_SINGLE_TRACK']
      

      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['mapFiles.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['mapFiles.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['mapFiles.rb']['encode'] = false
      @properties[counter]['mapFiles.rb']['fileWithTargets'] =  "#{@resourcePath}/#{@defaultProps['LOCI_FILE']}"
      @properties[counter]['mapFiles.rb']['fileWithQueries'] = @defaultProps['INTERSECT_IN_SINGLE_TRACK']
      @properties[counter]['mapFiles.rb']['outPutFileName'] = @defaultProps['INTERSECT_WITH_GENE_NAMES']
      @properties[counter]['mapFiles.rb']['tabDelimitedFileName'] = @defaultProps['TEMPTABDELIMITEDFILENAME']
      counter += 1

  
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['generateJsonFromLff.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['generateJsonFromLff.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['generateJsonFromLff.rb']['encode'] = false
      @properties[counter]['generateJsonFromLff.rb']['lffFileName'] = @defaultProps['INTERSECT_WITH_GENE_NAMES']
      @properties[counter]['generateJsonFromLff.rb']['jsonFileName'] = @defaultProps['COLORED_JSON_FILE']
      @properties[counter]['generateJsonFromLff.rb']['refSeqId'] = @refSeqId
      @properties[counter]['generateJsonFromLff.rb']['serverName'] = @serverName
      @properties[counter]['generateJsonFromLff.rb']['projectName'] = @projectId
      @properties[counter]['generateJsonFromLff.rb']['baseProject'] = @baseProjectName
      @properties[counter]['generateJsonFromLff.rb']['trackName'] = "#{@segmentType}:#{@segmentSubtype}"
      counter += 1 
      
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['processHtmlTemplate.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['processHtmlTemplate.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['processHtmlTemplate.rb']['encode'] = false
      @properties[counter]['processHtmlTemplate.rb']['htmlOutputFile'] = @defaultProps['FILE_WITH_HTML_CONTENT']
      @properties[counter]['processHtmlTemplate.rb']['rhtmlFile'] = "#{@resourcePath}/#{@defaultProps['TEMPLATES']}/#{@defaultProps['COLORED_TEMPLATE']}"
      @properties[counter]['processHtmlTemplate.rb']['jsonPropFile'] = @defaultProps['COLORED_JSON_FILE']
      counter += 1
      

      @filesToUpload << @defaultProps['INTERSECT_WITH_GENE_NAMES']
      @allFiles << @defaultProps['INTERSECT_WITH_GENE_NAMES']
       
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['createVGPDefaultPropFile.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['createVGPDefaultPropFile.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['createVGPDefaultPropFile.rb']['encode'] = true
      @properties[counter]['createVGPDefaultPropFile.rb']['vgpDefaultConfFile'] = @defaultProps['VGP_DEFAULT_VALUES']
      counter += 1

      @allFiles << @defaultProps['VGP_DEFAULT_VALUES']

      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['createTrackPropFile.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['createTrackPropFile.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['createTrackPropFile.rb']['encode'] = true
      @properties[counter]['createTrackPropFile.rb']['trackPropFile'] = @defaultProps['VGP_TRACK_PROPERTIES_CHROM_FILE']
      @properties[counter]['createTrackPropFile.rb']['agilentTrack'] = "#{@agilentType}:#{@agilentSubtype}"
      @properties[counter]['createTrackPropFile.rb']['refTrackName'] =  @defaultProps['REFTRACK']    
      @properties[counter]['createTrackPropFile.rb']['trackString'] = generateVGPString(@trackHash, "#{@defaultProps['INTERSECTTYPE']}:#{@defaultProps['DEFAULTSUBTYPE']}", @defaultProps['DEFAULTGAIN'], @defaultProps['DEFAULTLOSS'])      
      @properties[counter]['createTrackPropFile.rb']['chromosomeView'] = ""
      counter += 1
      
      @allFiles << @defaultProps['VGP_TRACK_PROPERTIES_CHROM_FILE']
          
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['createVGPPropertyFile.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['createVGPPropertyFile.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['createVGPPropertyFile.rb']['encode'] = true
      @properties[counter]['createVGPPropertyFile.rb']['vgpConfigurationFile'] = @defaultProps['VGP_CHROMO_JSON_FILE']
      @properties[counter]['createVGPPropertyFile.rb']['chromosomeView'] = ""      
      @properties[counter]['createVGPPropertyFile.rb']['lffFiles'] = "#{@defaultProps['CYTOBAND_LFF_FILE']},#{@defaultProps['AGILENT_FILE_WITH_RIGHT_COLOR']},#{@defaultProps['INTERSECT_IN_MULTIPLE_TRACKS']}"      
      @properties[counter]['createVGPPropertyFile.rb']['outPutDir'] = @defaultProps['VGP_RESULTS_DIR']
      @properties[counter]['createVGPPropertyFile.rb']['figureTitle'] = @defaultProps['VGP_TITLE']      
      @properties[counter]['createVGPPropertyFile.rb']['subTitle'] = "#{@defaultProps['VGP_SUBTITLE']} #{@projectId}"
      @properties[counter]['createVGPPropertyFile.rb']['vgpDefValFile'] = @defaultProps['VGP_DEFAULT_VALUES']  
      @properties[counter]['createVGPPropertyFile.rb']['trackPropFile'] = @defaultProps['VGP_TRACK_PROPERTIES_CHROM_FILE'] 
      counter += 1

      @allFiles << @defaultProps['VGP_CHROMO_JSON_FILE']
       
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['vgp.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['vgp.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['vgp.rb']['encode'] = false
      @properties[counter]['vgp.rb']['parameterFile'] = "#{@scratchDir}#{@defaultProps['VGP_CHROMO_JSON_FILE']}"
      counter += 1
        
      @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['createTrackPropFile.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
      @properties[counter]['createTrackPropFile.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
      @properties[counter]['createTrackPropFile.rb']['encode'] = true
      @properties[counter]['createTrackPropFile.rb']['trackPropFile'] = @defaultProps['VGP_TRACK_PROPERTIES_GENOMIC_FILE']
      @properties[counter]['createTrackPropFile.rb']['agilentTrack'] = "#{@agilentType}:#{@agilentSubtype}"
      @properties[counter]['createTrackPropFile.rb']['refTrackName'] =  @defaultProps['REFTRACK']    
      @properties[counter]['createTrackPropFile.rb']['trackString'] = generateVGPString(@trackHash, "#{@defaultProps['INTERSECTTYPE']}:#{@defaultProps['DEFAULTSUBTYPE']}", @defaultProps['DEFAULTGAIN'], @defaultProps['DEFAULTLOSS'])
      counter += 1
      
      @allFiles << @defaultProps['VGP_TRACK_PROPERTIES_GENOMIC_FILE']

      tempCounter = 0
      @numberOfGenomicPanels.times do
        if(@numberOfGenomicPanels == 1)
          outPutDir = @defaultProps['VGP_RESULTS_DIR']
          chrDefinitionFile = "#{@defaultProps['DASFILE']}.#{@defaultProps['DAS_EXTENSION']}"
          vgpPropFile = "#{@defaultProps['VGP_GENOMIC_JSON_FILE']}.json"
        else
          outPutDir = "#{@defaultProps['VGP_RESULTS_DIR']}_#{tempCounter}"
          chrDefinitionFile = "#{@defaultProps['DASFILE']}_#{tempCounter}.#{@defaultProps['DAS_EXTENSION']}"
          vgpPropFile = "#{@defaultProps['VGP_GENOMIC_JSON_FILE']}_#{tempCounter}.json"
        end  
  
        @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
        @properties[counter]['createVGPPropertyFile.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
        @properties[counter]['createVGPPropertyFile.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
        @properties[counter]['createVGPPropertyFile.rb']['encode'] = true
        @properties[counter]['createVGPPropertyFile.rb']['vgpConfigurationFile'] = vgpPropFile 
        @properties[counter]['createVGPPropertyFile.rb']['lffFiles'] = "#{@defaultProps['CYTOBAND_LFF_FILE']},#{@defaultProps['AGILENT_FILE_WITH_RIGHT_COLOR']},#{@defaultProps['INTERSECT_IN_MULTIPLE_TRACKS']}"      
        @properties[counter]['createVGPPropertyFile.rb']['outPutDir'] = outPutDir
        @properties[counter]['createVGPPropertyFile.rb']['figureTitle'] = @defaultProps['VGP_TITLE']      
        @properties[counter]['createVGPPropertyFile.rb']['subTitle'] = "#{@defaultProps['VGP_SUBTITLE']} #{@projectId}"
        @properties[counter]['createVGPPropertyFile.rb']['vgpDefValFile'] = @defaultProps['VGP_DEFAULT_VALUES']  
        @properties[counter]['createVGPPropertyFile.rb']['trackPropFile'] = @defaultProps['VGP_TRACK_PROPERTIES_GENOMIC_FILE']
        @properties[counter]['createVGPPropertyFile.rb']['chrDefinitionFile'] = chrDefinitionFile
        @properties[counter]['createVGPPropertyFile.rb']['omitLegend'] = '' if(tempCounter < (@numberOfGenomicPanels -1 ))
        @properties[counter]['createVGPPropertyFile.rb']['omitTitle'] = '' unless(tempCounter == 0)
        @properties[counter]['createVGPPropertyFile.rb']['omitSubTitle'] = '' unless(tempCounter == 0)
        counter += 1
  
        @allFiles << vgpPropFile
        
        @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
        @properties[counter]['vgp.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
        @properties[counter]['vgp.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
        @properties[counter]['vgp.rb']['encode'] = false
        @properties[counter]['vgp.rb']['parameterFile'] = "#{@scratchDir}#{vgpPropFile}"
        counter += 1        
        tempCounter += 1
      end
      
        @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
        @properties[counter]['deployVGPFilesToProject.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
        @properties[counter]['deployVGPFilesToProject.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
        @properties[counter]['deployVGPFilesToProject.rb']['encode'] = false
        @properties[counter]['deployVGPFilesToProject.rb']['baseProject'] =@baseProjectName
        @properties[counter]['deployVGPFilesToProject.rb']['projectName'] = @projectId
        @properties[counter]['deployVGPFilesToProject.rb']['resultDirNamePrefix'] = @defaultProps['VGP_RESULTS_DIR']
        @properties[counter]['deployVGPFilesToProject.rb']['scratchDir'] = @scratchDir
        @properties[counter]['deployVGPFilesToProject.rb']['contentPart'] = @defaultProps['FILE_WITH_HTML_CONTENT']
        @properties[counter]['deployVGPFilesToProject.rb']['numberOfGenomicPanels'] = @numberOfGenomicPanels
        @properties[counter]['deployVGPFilesToProject.rb']['defaultPropFile'] = @defaultPropFile
        counter += 1
      


      @filesToUpload.each{|fileToUpload|
        @properties[counter] = Hash.new{|hh,kk| hh[kk]=nil;}
        @properties[counter]['uploadLffFile.rb'] = Hash.new{|hh,kk| hh[kk]=nil;}
        @properties[counter]['uploadLffFile.rb']['sepPrefix'] = @defaultProps['SEPPREFIX']
        @properties[counter]['uploadLffFile.rb']['encode'] = true
        @properties[counter]['uploadLffFile.rb']['lffFileToUpload'] = "#{scratchDir}#{fileToUpload}"
        @properties[counter]['uploadLffFile.rb']['refSeqId'] = @refSeqId
        @properties[counter]['uploadLffFile.rb']['userId'] = @userId
        @properties[counter]['uploadLffFile.rb']['standard'] = ""
        @properties[counter]['uploadLffFile.rb']['compressFiles'] = ""
        counter += 1 
    }

      
      fileWriter.puts JSON.pretty_generate(@properties)


      fileWriter.close
    rescue => err
          $stderr.puts "ERROR: bad line found. Blank columns? . Details: #{err.message}"
          $stderr.puts err.backtrace.join("\n")
          $stderr.puts "LINE: #{line.inspect}"
          exit 137
    end
  end #end of method
    
end #end of class


class AddColorsAndProp
  attr_accessor :readFileStr, :outPutFile, :defaultType, :defaultSubType
  attr_accessor  :trackColorString, :tracksHash, :threshold, :defaltTrack, :defaultProperties
  attr_accessor :classifiedTypeName, :classifiedClassName, :defaultGain, :defaultLoss





  COLORATTNAME = "annotationColor".to_sym

  def initialize(readFile, outFile, trackcolors, threshold,
                 classifiedTypeName, classifiedClassName, defaultTrack, defaultPropFile)
    
    @trackColorString = trackcolors
    @trackColorString = CGI.unescape(@trackColorString) if(@trackColorString.class == String) 
    @tracksHash = Hash.new {|hh,kk| hh[kk] = nil }
    tempFile = defaultPropFile
    tempFile = CGI.unescape(tempFile) if(tempFile.class == String)
    @defaultProperties = JSON.parse(File.read(tempFile)) 
    @threshold = threshold
    @threshold = @defaultProperties['DEFAULTTHRESHOLD']  if(!threshold.nil? and threshold.size > 0)
    @threshold = CGI.unescape(@threshold) if(@threshold.class == String)     
    @threshold = threshold.to_f    
    @readFileStr = readFile
    @readFileStr = CGI.unescape(@readFileStr) if(@readFileStr.class == String) 
    @outPutFile = outFile
    @outPutFile = CGI.unescape(@outPutFile) if(@outPutFile.class == String)    
    @classifiedTypeName = classifiedTypeName
    @classifiedTypeName = CGI.unescape(@classifiedTypeName) if(@classifiedTypeName.class == String)    
    @classifiedClassName = classifiedClassName
    @classifiedClassName = CGI.unescape(@classifiedClassName) if(@classifiedClassName.class == String)
  
    @defaultTrack = defaultTrack
    @defaultTrack  = CGI.unescape(@defaultTrack) if(@defaultTrack.class == String)  
    @defaultType =  @defaultProperties['DEFAULTTYPE']
    @defaultSubType = @defaultProperties['DEFAULTSUBTYPE']
    @defaultGain = @defaultProperties['DEFAULTCOLORGAIN']
    @defaultLoss = @defaultProperties['DEFAULTCOLORLOSS']   
     parseTrackColors()
     createFiles()
  end


    def parseTrackColors()
        if(!@trackColorString.nil? and @trackColorString.size > 0)
            tracksColorArray = @trackColorString.split(/;/)
            counter = 0
            tracksColorArray.each{ |trkClr|
                if (trkClr =~ /([^:]+):([^%]+)%gain=([^%]+)%loss=(.+)/)
                    typeSubtype = "#{$1.strip}:#{$2.strip}"
                    gainColor = $3.strip
                    lossColor = $4.strip
                    if(typeSubtype == @defaultTrack)
                        @defaultType =  $1.strip
                        @defaultSubType = $2.strip
                        @defaultGain = $3.strip
                        @defaultLoss = $4.strip
                    else
                        @tracksHash[counter] = Hash.new {|hh,kk| hh[kk] = nil }
                        if(@tracksHash[counter].has_key?(typeSubtype))
                            @tracksHash[counter][typeSubtype][@defaultProperties['GAIN']] = gainColor
                            @tracksHash[counter][typeSubtype][@defaultProperties['LOSS']] = lossColor
                        else
                            @tracksHash[counter][typeSubtype] = Hash.new {|hh,kk| hh[kk] = nil }
                            @tracksHash[counter][typeSubtype][@defaultProperties['GAIN']] = gainColor
                            @tracksHash[counter][typeSubtype][@defaultProperties['LOSS']] = lossColor
                        end
                    end
                else
                    stderr.put "ERROR: the track with colors string is not formatted correctly the " +
                        "correct format should be Type:Subtype:(gain/loss)=color in hexcode"
                end
                counter += 1
            }
        end
    end


    def modLff(lffHash, lengthInKb, gainLoss)
        @tracksHash.keys.sort.reverse.each{|counter|
          track = @tracksHash[counter]
          track.each_key{|trackIn|          
            newTrackArray = "#{trackIn}".split(/:/)
            newType = newTrackArray[0].strip
            newSubType = newTrackArray[1].strip
            newAttr = "#{@defaultProperties['ATTPREFIX']}_#{newTrackArray[0].strip}:#{newTrackArray[1].strip}"
            if(lffHash.has_key?("#{trackIn}".to_sym) )
              if(gainLoss)
                color = track[trackIn][@defaultProperties['GAIN']] 
                newName = "#{newType}-GAIN-#{lengthInKb}kb"
                newSubType = "#{newSubType}_Gain"
              else
                color = track[trackIn][@defaultProperties['LOSS']]
                newName = "#{newType}-LOSS-#{lengthInKb}kb"
                newSubType = "#{newSubType}_Loss"
              end
                lffHash[@defaultProperties['COLORATTNAME'].to_sym] = color
                lffHash[newAttr.to_sym] = "Yes"
                lffHash.lffName="#{newName}".to_sym
                lffHash.lffSubtype= "#{newSubType}".to_sym
                lffHash.lffType = newType.to_sym
            else
                lffHash[newAttr.to_sym] = "No"
            end
          }     
        }
        return lffHash
    end


  def createFiles()
    # Read  file
    lffHash = nil
    reader = BRL::Util::TextReader.new(@readFileStr)
    fileWriterOutPutFile = BRL::Util::TextWriter.new(@outPutFile)
    line = nil
    lineCounter = 1
    gainLoss = false
    begin
      reader.each { |line|
        newType = nil
        newSubType = nil
        newAttr = nil
        newName = nil
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        aa = line.strip.split(/\t/)
        next if( aa.length < 10 )
        lffHash = LFFHash.new(line)
        lengthInKb = ((lffHash.lffLength.to_f) / 1000).ceil  #the kbs have to be rounded using the ceil function
        gainLoss = (lffHash.lffScore >= @threshold)

        lffHash[@defaultProperties['ORIGINALANNOTATIONNAME'].to_sym] = "#{lffHash.lffName}"
        if(gainLoss)
          color = @defaultGain
          newName = "#{@defaultType}-GAIN-#{lengthInKb}kb"
          newSubType = "#{@defaultSubType}_Gain"
        else
          color = @defaultLoss
          newName = "#{@defaultType}-LOSS-#{lengthInKb}kb"
          newSubType = "#{@defaultSubType}_Loss"
        end
        lffHash.lffClass= "#{@classifiedClassName}".to_sym if(!@classifiedClassName.nil? and @classifiedClassName.size > 0)
        lffHash.lffType= "#{@classifiedTypeName}".to_sym if(!@classifiedTypeName.nil? and @classifiedTypeName.size > 0)
        lffHash[@defaultProperties['COLORATTNAME'].to_sym] = color
        lffHash.lffName="#{newName}".to_sym
        lffHash.lffSubtype= "#{newSubType}".to_sym
        
        lffHash = modLff(lffHash, lengthInKb, gainLoss)

        fileWriterOutPutFile.puts lffHash.to_lff
        lineCounter = lineCounter + 1
      }

      fileWriterOutPutFile.close()
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
 end   
    
end #end of Class



class UploadLffFile
  LISTOFFICIALARGS = ['-u', '-t', '-x', '-s', '-o', '-d', '-n', '-b', '-p', '-i', '-w', '-z', '-v', '-k', '-y']  
  JAVAPATH = "java "
  CLASSPATH = "-classpath "
  APPNAME = " -Xmx800M org.genboree.upload.AutoUploader "
          
  attr_accessor :lffFileName, :refSeqId, :extraArgs, :hashWithAdditionalValues, :fileList

  
 def initialize(lffFile, refSeqId, hashWithAdditionalValues=nil)
    @lffFileName = lffFile
    return if( !File.exist?(@lffFileName)  or (File.size(@lffFileName) < 1) )
    @fileList = Array.new()
    @refSeqId = refSeqId
    @hashWithAdditionalValues = hashWithAdditionalValues
    createExtraArgs()   
    uploadLff()
 end

 
 
 def createExtraArgs()   
   @extraArgs = ""

    if(!@hashWithAdditionalValues.nil? and @hashWithAdditionalValues.size > 0)
      LISTOFFICIALARGS.each{|arg|
        if(@hashWithAdditionalValues.has_key?(arg))
          temp = @hashWithAdditionalValues[arg]
          temp = CGI.unescape(temp) if(temp.class == String)
          @extraArgs +=  " #{arg} #{temp} "
          @hashWithAdditionalValues.delete(arg)
        end
        }
    end

    if(!@hashWithAdditionalValues.nil? and @hashWithAdditionalValues.size > 0)
      @hashWithAdditionalValues.each_key{|key|
          temp = @hashWithAdditionalValues[key]
          temp = CGI.unescape(temp) if(temp.class == String)
        @extraArgs +=  " #{key} #{temp} " 
        }
    end
    
 end
 

  def uploadLff()
    uploaderCmd = "#{JAVAPATH} #{CLASSPATH} #{JCLASS_PATH} #{APPNAME} -f #{@lffFileName} " +
                  "-r #{@refSeqId} #{@extraArgs} > #{@lffFileName}.errors 2>&1 "
    
    $stderr.puts "\nGENBOREE UPLOADER CMD: #{uploaderCmd}\n\n"
    uploadOutput = `#{uploaderCmd}`
    exitStatus = $?
    uploadOK = (exitStatus.exitstatus == 0)
# Andrew recommend this    uploadOK = $?.success?

    @fileList << @lffFileName
    @fileList << "#{@lffFileName}.errors"
    @fileList << "#{@lffFileName}.log"
    @fileList << "#{@lffFileName}.full.log"
    @fileList << "#{@lffFileName}.entrypoints.lff" unless(@extraArgs =~ / -v / )

    unless(uploadOK)
      $stderr.puts "\n\nGENBOREE UPLOADER FAILED. Exit status from uploader = #{exitStatus.inspect}\n\n"
      raiseStr = "\n\nThere was an error creating your Genboree tracks from the tool output.\n\nFor assistance resolving this issue, please contact a Genboree admin (genboree_admin@genboree.org).\n\nGenboree complained that:\n"
        if(exitStatus.exitstatus == 20)
          raiseStr << "The results cannot be uploaded due to too many errors (for example: incompatible chromosome names or coordinates).\n\n"
        elsif(exitStatus.exitstatus == 10)
          raiseStr << "Some results could not be uploaded due to errors (for example: incompatible chromosome names or coordinates).\n\n"
        else
          raiseStr << "\n\nThere was an error creating your Genboree tracks from the tool output.\n\nFor assistance resolving this issue, please contact a Genboree admin (genboree_admin@genboree.org).\n\nGenboree complained that:\n#{uploadOutput}\n\n"
        end
      raise raiseStr
    end
  end

end


class ManageGenboreeProjects
  attr_accessor :groupId, :userId, :projectName
  attr_accessor :action, :context, :baseProject, :newProjectName
  attr_accessor :fullProjectName, :newFullProjectName
  
 def initialize(groupId, userId, projectName, action, baseProject, newProjectName)
    @groupId = groupId.to_i
    @userId = userId.to_i
    @projectName = projectName
    @projectName = CGI.unescape(@projectName) if(@projectName.class == String)
    @baseProject = baseProject
    @baseProject = CGI.unescape(@baseProject) if(@baseProject.class == String)
    @newProjectName = newProjectName
    @newProjectName = CGI.unescape(@newProjectName) if(@newProjectName.class == String)
    @action = action
    @context = BRL::Genboree::GenboreeContext.load(nil, ENV)
    @context[:groupId] = groupId
    @context[:userId] = userId
    @context[:dbu] = BRL::Genboree::DBUtil.new(@context.genbConf.dbrcKey, nil, nil)

    if(!@baseProject.nil? and @baseProject.size > 0)
      @fullProjectName = "#{@baseProject}/#{@projectName}"
      @newFullProjectName = "#{@baseProject}/#{@newProjectName}" if(action == "rename" and !@newProjectName.nil?)
    else
      @fullProjectName = "#{@projectName}"
      @newFullProjectName = "#{@newProjectName}" if(action == "rename" and !@newProjectName.nil?)
    end
    
    
    
    if(action.nil? || action== "create")
      actionOk = BRL::Genboree::ProjectManagement.createNewProject(@fullProjectName, @context)
    elsif(action == "delete")
      deleteOK = BRL::Genboree::ProjectManagement.deleteProject(@fullProjectName, @context)
    elsif(action == "rename")
      renameOK = BRL::Genboree::ProjectManagement.renameProject(@fullProjectName, @newFullProjectName, @context)
    end
    
 end
end

end; end; end; end#namespace
