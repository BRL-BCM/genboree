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


class RunAddVPsToFiles
    def self.runAddVPsToFiles(optsHash)
    #--lffFileToLabel --lffWithVPs --newVPName --newVPValue --tracksDir
    methodName = "runAddVPsToFiles"
    lffFileToLabel = nil
    lffWithVPs =  nil 
    newVPName = nil        
    newVPValue =  nil
    
    lffFileToLabel =    optsHash['--lffFileToLabel'] if( optsHash.key?('--lffFileToLabel') )
    lffWithVPs =           optsHash['--lffWithVPs'] if( optsHash.key?('--lffWithVPs') )
    newVPName =     optsHash['--newVPName'] if( optsHash.key?('--newVPName') )
    newVPValue =   optsHash['--newVPValue'] if( optsHash.key?('--newVPValue') )

    
    if( lffFileToLabel.nil? || lffWithVPs.nil? || newVPName.nil? ||  newVPValue.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--lffFileToLabel=#{lffFileToLabel}"
      $stderr.puts "--lffWithVPs=#{lffWithVPs}"
      $stderr.puts "--newVPName=#{newVPName}"
      $stderr.puts "--newVPValue=#{newVPValue}"
      return
    end
    AddVPsToFiles.new(lffFileToLabel, lffWithVPs, newVPName, newVPValue)
    
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



#testing basic functions not used for implementation
BRL::Genboree::Pipelines::Acgh::Applications::RunAddVPsToFiles.runAddVPsToFiles(optsHash)




