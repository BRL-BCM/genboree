#!/usr/bin/env ruby

require 'json'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications


class RunCreateVGPPropertyFile
    def self.runCreateVGPPropertyFile(optsHash)
    #--vgpConfigurationFile --lffFiles --outPutDir --figureTitle --subTitle --chromosomeView
    methodName = "runCreateVGPPropertyFile"
    vgpConfigurationFile = nil
    lffFiles =  nil
    outPutDir =  nil
    figureTitle = nil
    subTitle =   nil
    chromosomeView = false
    vgpDefValFile = nil
    trackPropFile = nil
    omitTitle = false
    omitSubTitle = false
    omitLegend = false
    chrDefinitionFile = nil

  
    vgpConfigurationFile =        optsHash['--vgpConfigurationFile'] if( optsHash.key?('--vgpConfigurationFile') )
    lffFiles =   optsHash['--lffFiles'] if( optsHash.key?('--lffFiles') ) 
    outPutDir =  optsHash['--outPutDir'] if( optsHash.key?('--outPutDir') )
    figureTitle = optsHash['--figureTitle'] if( optsHash.key?('--figureTitle') )
    subTitle =   optsHash['--subTitle'] if( optsHash.key?('--subTitle') )
    vgpDefValFile = optsHash['--vgpDefValFile'] if( optsHash.key?('--vgpDefValFile') )
    trackPropFile = optsHash['--trackPropFile'] if( optsHash.key?('--trackPropFile') )
    chromosomeView = ( optsHash.key?('--chromosomeView') )
    omitTitle  = ( optsHash.key?('--omitTitle') )
    omitSubTitle = ( optsHash.key?('--omitSubTitle') )
    omitLegend = ( optsHash.key?('--omitLegend') )
    chrDefinitionFile = optsHash['--chrDefinitionFile'] if( optsHash.key?('--chrDefinitionFile') )    


    
    if( vgpConfigurationFile.nil? || lffFiles.nil? || outPutDir.nil? ||
        figureTitle.nil? || subTitle.nil? || vgpDefValFile.nil? || trackPropFile.nil?)
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--vgpConfigurationFile=#{vgpConfigurationFile}"
        $stderr.puts "--lffFiles=#{lffFiles}"
        $stderr.puts "--outPutDir=#{outPutDir}"
        $stderr.puts "--figureTitle=#{figureTitle}"
        $stderr.puts "--subTitle=#{subTitle}"
        $stderr.puts "--vgpDefValFile=#{vgpDefValFile}"
        $stderr.puts "--trackPropFile=#{trackPropFile}"
        $stderr.puts "--chromosomeView"
        $stderr.puts "--omitTitle"        
        $stderr.puts "--omitSubTitle"
        $stderr.puts "--omitLegend"
        $stderr.puts "--chrDefinitionFile"
      return
    end

    CreateVGPPropertyFile.new(vgpConfigurationFile, lffFiles, outPutDir, figureTitle, subTitle, chromosomeView, vgpDefValFile, trackPropFile, omitTitle, omitSubTitle, omitLegend, chrDefinitionFile)
  end
  
end
end; end; end; end; end #namespace

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


#--vgpConfigurationFile "chrom.json" --lffFiles  "cytoBand.lff,posCytoBand.lff,color.lff,classified.lff"
#--outPutDir  "results" --figureTitle "Array CGH Result" --subTitle "Result for Project ID #12345"
#--vgpDefValFile --trackPropFile --chromosomeView


BRL::Genboree::Pipelines::Acgh::Applications::RunCreateVGPPropertyFile.runCreateVGPPropertyFile(optsHash)
