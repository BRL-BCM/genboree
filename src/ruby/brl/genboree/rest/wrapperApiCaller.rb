#!/usr/bin/env ruby

require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/abstract/resources/user'


module BRL #:nodoc:
module Genboree #:nodoc:
module REST #:nodoc:
  attr_accessor :dbu
  attr_accessor :genbConf
  # Extends the ApiCaller class
  # Intended to be used by tool wrappers for making them multi-host compliant.
  class WrapperApiCaller < BRL::Genboree::REST::ApiCaller
    # Constructor
    # Instantiates the parent ApiCaller class by using 'hostAuthMap'
    # [+host+] name or IP of the machine trying to connect to
    # [+rsrcPath+] Resource path of the entity
    # [+userId+]
    # [+genbConf+]
    # [+returns+] nil
    def initialize(host, rsrcPath, userId, genbConf=nil)
      @genbConf = (genbConf ? genbConf : BRL::Genboree::GenboreeConfig.load())
      # BUG: dbrcKey should be "DB:#{genbConf.machineName}"
      # dbu = BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, nil)
      @dbu = BRL::Genboree::DBUtil.new("DB:#{@genbConf.machineName}", nil, nil)
      hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, userId)
      # Done with this dbu, clear it out, including caches
      @dbu.clear(true)
      @dbu = nil
      # Initialize ApiCaller parent class using hostAuthMap
      super(host, rsrcPath, hostAuthMap)
    end
  end
end; end; end
