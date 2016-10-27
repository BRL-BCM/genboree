#!/usr/bin/env ruby

require 'rubygems'
require 'rein'
require 'fileutils'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'
require 'brl/fileFormats/lffHash'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications

class RunChangeColors
  
    def self.runAddColors(optsHash)
    #--inputFile --outPutFile --thresholdValue --positiveColor --negativeColor --colorClass --colorType --colorSubType --propFile
    methodName = "runAddColors"
    inputFile = nil
    outPutFile =  nil 
    thresholdValue = nil        
    positiveColor =  nil  
    negativeColor =  nil
    colorClass = nil
    colorType = nil
    colorSubType = nil
    propFile = nil

    
    inputFile =    optsHash['--inputFile'] if( optsHash.key?('--inputFile') )
    outPutFile =           optsHash['--outPutFile'] if( optsHash.key?('--outPutFile') )
    thresholdValue =     optsHash['--thresholdValue'] if( optsHash.key?('--thresholdValue') )
    positiveColor =   optsHash['--positiveColor'] if( optsHash.key?('--positiveColor') )
    negativeColor = optsHash['--negativeColor'] if( optsHash.key?('--negativeColor') )
    colorClass = optsHash['--colorClass'] if( optsHash.key?('--colorClass') )
    colorType = optsHash['--colorType'] if( optsHash.key?('--colorType') )
    colorSubType = optsHash['--colorSubType'] if( optsHash.key?('--colorSubType') )
    propFile =    optsHash['--propFile'] if( optsHash.key?('--propFile') )

#CGI.unescape(outFile) if(outFile.class == String)
    
    if( !propFile.nil?)
      changeColors = OpenErrorExtractValues.new(propFile)
      changeColors.createFiles()
#      changeColors.printOptions()
      propHash = changeColors.propHash
      thresholdValue = propHash['mean'] if(!propHash.nil?)
    end

    
    if( inputFile.nil? || outPutFile.nil? || thresholdValue.nil? ||  positiveColor.nil? || negativeColor.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--inputFile=#{inputFile}"
      $stderr.puts "--outPutFile=#{outPutFile}"
      $stderr.puts "--thresholdValue=#{thresholdValue}"
      $stderr.puts "--positiveColor=#{positiveColor}"
      $stderr.puts "--negativeColor=#{negativeColor}"
      $stderr.puts "--propFile=#{propFile}"
      return
    end


    changeColors = ChangeColors.new(inputFile, outPutFile, thresholdValue, positiveColor, negativeColor, colorClass, colorType, colorSubType)
    changeColors.createFiles()
    end
    
end

end; end; end; end; end#namespace

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



#testing basic functions not used for implementation
#propHash = BRL::Genboree::Pipelines::Acgh::Applications::RunChangeColors.runExtractProp(optsHash)

#optsHash['--thresholdValue'] = propHash["mean"] if(!propHash.nil?)
BRL::Genboree::Pipelines::Acgh::Applications::RunChangeColors.runAddColors(optsHash)


