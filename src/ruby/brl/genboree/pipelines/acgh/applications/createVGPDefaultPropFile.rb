#!/usr/bin/env ruby

require 'json'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications

class RunCreateVGPDefaultPropertyFile
  
    def self.runCreateVGPDefaultPropertyFile(optsHash)
    #--vgpDefaultConfFile
    methodName = "runCreateVGPDefaultPropertyFile"
    vgpDefaultConfFile = nil

    vgpDefaultConfFile =        optsHash['--vgpDefaultConfFile'] if( optsHash.key?('--vgpDefaultConfFile') )

    if( vgpDefaultConfFile.nil?)
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--vgpDefaultConfFile=#{vgpDefaultConfFile}"        
      return
    end

    CreateVGPDefaultPropertyFile.new(vgpDefaultConfFile)
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



#--vgpDefaultConfFile

BRL::Genboree::Pipelines::Acgh::Applications::RunCreateVGPDefaultPropertyFile.runCreateVGPDefaultPropertyFile(optsHash)
