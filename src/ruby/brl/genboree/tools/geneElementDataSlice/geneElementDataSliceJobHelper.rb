require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'uri'

module BRL ; module Genboree ; module Tools
  class GeneElementDataSliceJobHelper < WorkbenchJobHelper

    TOOL_ID = 'geneElementDataSlice'


    # Must be defined in subclass. DO NOT USE CLASS VARIABLES WITH INHERITANCE.
    # CAN USE "class level instance variables" HOWEVER. THERE IS ONLY ONE (1)
    # CLASS VARIABLE, EVEN IF INHERITED (i.e. not separate storage, shared storage...many bugs.)
    #@@commandName = 'wrapperSearchSignalSim.rb'

    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "wrapperGeneElementDataSlice.rb"
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
