#!/usr/bin/env ruby

require 'erb'
require 'yaml'
require 'cgi'
require 'json'
require 'rein'
require 'interval'
require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/toolPlugins/util/util.rb'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications

class RunUploadLffFile
    def self.runUploadLffFile(optsHash)
      #--lffFileToUpload --refSeqId
      methodName = "runUploadLffFile"
      lffFileToUpload = nil
      refSeqId =  nil
      path = nil
      standard = false
      compressFiles = false
      userId = nil
      
      lffFileToUpload =    optsHash['--lffFileToUpload'] if( optsHash.key?('--lffFileToUpload') )
      optsHash.delete('--lffFileToUpload') if( optsHash.key?('--lffFileToUpload') )
      lffFileToUpload =CGI.unescape(lffFileToUpload) if(lffFileToUpload.class == String)
      refSeqId =           optsHash['--refSeqId'] if( optsHash.key?('--refSeqId') )
      optsHash.delete('--refSeqId') if( optsHash.key?('--refSeqId') )
      refSeqId =CGI.unescape(refSeqId) if(refSeqId.class == String)
      userId =  optsHash['--userId'] if( optsHash.key?('--userId') )
      optsHash.delete('--userId') if( optsHash.key?('--userId') )
      userId =CGI.unescape(userId) if(userId.class == String)
      path = optsHash['--path'] if( optsHash.key?('--path') )
      optsHash.delete('--path') if( optsHash.key?('--path') )
      path =CGI.unescape(path) if(path.class == String)
      standard = ( optsHash.key?('--standard') )
      optsHash.delete('--standard') if( optsHash.key?('--standard') )
      compressFiles = ( optsHash.key?('--compressFiles') )
      optsHash.delete('--compressFiles') if( optsHash.key?('--compressFiles') ) 
      
      
      if( lffFileToUpload.nil? || refSeqId.nil? || userId.nil?)
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--lffFileToUpload=#{lffFileToUpload}"
        $stderr.puts "--refSeqId=#{refSeqId}"
        $stderr.puts "--userId=#{userId}"
        $stderr.puts "--path=#{path}"
        $stderr.puts "--standard"
        $stderr.puts "--compressFiles"
        return
      end
      
      if(path.nil?)
        path = Dir.pwd
      end
      


      unless(lffFileToUpload =~ /^\s*.*[\/]/ )
        lffFileToUpload = "#{path}/#{lffFileToUpload}"
      end



      hashWithAdditionalValues = Hash.new{|hh,kk| hh[kk]=nil;}
      hashWithAdditionalValues['-u'] = userId

      if(standard)
        hashWithAdditionalValues['-z'] = ""
        hashWithAdditionalValues['-v'] = "" 
      end

      optsHash.each{|key,value|
        hashWithAdditionalValues[key] = value
        }


      uploadLff = UploadLffFile.new(lffFileToUpload, refSeqId, hashWithAdditionalValues)

      if(compressFiles)
        uploadLff.fileList.each{ |upFile|
           Acgh.compressFile(upFile)
       }
      end


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

#optsHash.each {|key, value|
#
#  $stderr.puts "#{key} == #{value}" if(!key.nil?)
#  }

#testing basic functions not used for implementation
upload =   BRL::Genboree::Pipelines::Acgh::Applications::RunUploadLffFile.runUploadLffFile(optsHash)



