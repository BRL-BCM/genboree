require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/data/workbenchJobEntity'

module BRL ; module Genboree ; module Tools
  class WorkbenchValidationHelper

    attr_accessor :genbConf

    def initialize(genbConf=nil, *args)
      @genbConf = genbConf || BRL::Genboree::GenboreeConfig.load()
    end

  end # class WorkbenchValidationHelper
end ; end ; end # module BRL ; module Genboree ; module Tools
