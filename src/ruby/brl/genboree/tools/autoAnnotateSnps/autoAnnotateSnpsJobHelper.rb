require 'uri'
require 'json'
require 'brl/util/util'
require "brl/db/dbrc"
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'uri'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/helpers/fileApiUriHelper'

module BRL ; module Genboree ; module Tools
  class AutoAnnotateSNPsJobHelper < WorkbenchJobHelper
    TOOL_NAME = 'Auto-Annotate SNPs'

    TOOL_ID = 'autoAnnotateSnps'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "#{@genbConf.toolScriptPrefix}wrapperAutoAnnotateSNPs.rb"
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
