#!/usr/bin/env ruby

require 'uri'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST
require "brl/db/dbrc"
require 'json'

module BRL; module Genboree ; module Abstract ; module Resources

class JobFile


  attr_accessor :inputs
  
  attr_accessor :outputs
  
  attr_accessor :settings
  
  attr_accessor :context
  
  attr_accessor :jobFile
  
  attr_accessor :jobHash
  
  # Constructor
  # [+uriPath+] REST URI to json file
  # [+rackEnv+] rack env obj
  def initialize(uriPath, rackEnv=nil)
    @rackEnv = rackEnv
    @jobFile = uriPath  
    @inputs = nil
    @outputs = nil
    @settings = nil
    @context = nil
  end

  # Parses job file and sets up the 4 parts of the job file, i.e, inputs, outputs, settings and context
  # [+returns+] nil
  def parseJobFile()
    begin
      uri = URI.parse(@jobFile)
      host = uri.host
      rcscUri = uri.path.chomp("?")
      rcscUri.gsub!("/files/", "/file/")
      rcscUri << "/data?"
      genbConf = BRL::Genboree::GenboreeConfig.load()
      suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc()
      apiDbrc = suDbDbrc
      apiCaller = ApiCaller.new(host, rcscUri, apiDbrc.user, apiDbrc.password)
      # Do internal request if enabled (in this case, if we've been given a Rack env hash to work from)
      retVal = ""
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      resp = apiCaller.get()
      if(apiCaller.succeeded?)
        retVal = apiCaller.respBody
      else
        raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
      end
      buff = ''
      buffIO = StringIO.new(retVal)
      buffIO.each_line { |line|
        buff << line  
      }
      @jobHash = JSON.parse(buff)
      @inputs = @jobHash['inputs']
      @outputs = @jobHash['outputs']
      @settings = @jobHash['settings']
      @context = @jobHash['context']
    rescue => err
      raise err    
    end
      
  end
  
end


end; end; end; end