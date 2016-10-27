require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class CopyTracksJobHelper < WorkbenchJobHelper

    TOOL_ID = 'copyTracks'
    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "#{@genbConf.toolScriptPrefix}wbCopyTracks.rb"
    end

    def buildCmd()
      return "cp #{@workbenchJobObj.context['scratchDir']}/#{@genbConf.gbJobJSONFile}  #{@workbenchJobObj.context['scratchDir']}/#{@genbConf.gbJobJSONFile}.copy "
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
