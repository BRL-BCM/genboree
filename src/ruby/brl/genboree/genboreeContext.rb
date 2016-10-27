require 'brl/net/erubisContext'
require 'brl/genboree/genboreeUtil'

module BRL ; module Genboree

class GenboreeContext < BRL::Net::ErubisContext
  attr_accessor :genbConf, :title, :addHeadData

  # Intantiates AND LOADS the genboree config file in one step
  def self.load(cgi, env, outHdrs={}, didHdrs=false, didResult=false)
    retVal = self.new(cgi, env, outHdrs, didHdrs, didResult)
    retVal.loadGenboreeConfig()
    return retVal
  end

  def initialize(cgi, env, outHdrs={}, didHdrs=false, didResult=false)
    @genbConf = loadGenboreeConfig()
    super(cgi, env, outHdrs, didHdrs, didResult)
  end

  def loadGenboreeConfig()
    @genbConf = nil
    begin
      @genbConf = BRL::Genboree::GenboreeConfig.new()
      @genbConf.loadConfigFile()
    rescue => err
      $stderr.puts "-"*40
      $stderr.puts "ERROR in BRL::Genboree::GenboreeContext#loadGenboreeConfig() => #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "-"*40
      @genbConf = nil
    end
    return @genbConf
  end

  def jsVerStr()
    retVal = ""
    retVal = "jsVer=#{@genbConf.jsVer}" unless(@genbConf.nil?)
    return retVal
  end

  def clear()
  end
end

end ; end
