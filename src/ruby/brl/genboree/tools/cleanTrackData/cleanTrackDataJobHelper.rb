require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'uri'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require 'brl/genboree/abstract/resources/user'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class CleanTrackDataJobHelper < WorkbenchJobHelper

    TOOL_ID = 'cleanTrackData'


    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "cleanTrackDataWrapper.rb"
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
