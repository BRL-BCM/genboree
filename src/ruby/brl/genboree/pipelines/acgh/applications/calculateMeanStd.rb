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
          
class RunCalculateMeanAndSTD
  def self.runCalculateMeanStd(optsHash)
    #--lffFilesWithScores --prefFileWithScoreAndStd
    methodName = "runCalculateMeanStd"
    lffFilesWithScores = nil
    prefFileWithScoreAndStd =  nil 

    
    lffFilesWithScores =    optsHash['--lffFilesWithScores'] if( optsHash.key?('--lffFilesWithScores') )
    prefFileWithScoreAndStd =    optsHash['--prefFileWithScoreAndStd'] if( optsHash.key?('--prefFileWithScoreAndStd') )

    
    if( lffFilesWithScores.nil? ||  prefFileWithScoreAndStd.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--lffFilesWithScores=#{lffFilesWithScores}"
      $stderr.puts "--prefFileWithScoreAndStd=#{prefFileWithScoreAndStd}"
      return
    end

    meanStd = CalculateMeanAndSTD.new(lffFilesWithScores, prefFileWithScoreAndStd)
    meanStd.calculateMeanAndStd()
    return meanStd
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

#CGI.unescape(value) if(value.class == String) 

#testing basic functions not used for implementation
propHash = BRL::Genboree::Pipelines::Acgh::Applications::RunCalculateMeanAndSTD.runCalculateMeanStd(optsHash)



