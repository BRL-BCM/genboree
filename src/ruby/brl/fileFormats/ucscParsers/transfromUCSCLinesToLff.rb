#!/usr/bin/env ruby

require 'rubygems'
require 'rein'
require 'fileutils'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/fileFormats/ucscParsers/tableToHashCreator'
require 'brl/fileFormats/ucscParsers/ucscTables'
require 'net/ftp'
require 'brl/net/fetchFromFTP'

module BRL ; module FileFormats; module UcscParsers

          
class RunUcscTableFromBrowserToLff
  def self.runUcscTableFromBrowserToLff(optsHash)
    #--fileName --lffFileName --clName --type --subtype
    methodName = "runUcscTableFromBrowserToLff"
    fileName = nil
    lffFileName = nil
    clName = nil
    type = nil
    subtype = nil
    
    fileName =    optsHash['--fileName'] if( optsHash.key?('--fileName') )
    lffFileName =    optsHash['--lffFileName'] if( optsHash.key?('--lffFileName') )
    clName =    optsHash['--clName'] if( optsHash.key?('--clName') )
    type =    optsHash['--type'] if( optsHash.key?('--type') )
    subtype =    optsHash['--subtype'] if( optsHash.key?('--subtype') )
    
    if( fileName.nil? ||  lffFileName.nil? || clName.nil? || type.nil? || subtype.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--fileName=#{fileName}"
      $stderr.puts "--lffFileName=#{lffFileName}"
      $stderr.puts "--clName=#{clName}"
      $stderr.puts "--type=#{type}"
      $stderr.puts "--subtype=#{subtype}"
      return
    end

    TableToHashCreator.ucscTableFromBrowserToLff(fileName, lffFileName, clName, type, subtype)
  end
    
  
end

end; end; end #namespace

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


BRL::FileFormats::UcscParsers::RunUcscTableFromBrowserToLff.runUcscTableFromBrowserToLff(optsHash)



