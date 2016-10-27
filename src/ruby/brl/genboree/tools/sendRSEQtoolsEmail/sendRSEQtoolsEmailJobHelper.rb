require 'brl/genboree/tools/workbenchJobHelper'

module BRL; module Genboree; module Tools
  class SendRSEQtoolsEmailJobHelper < WorkbenchJobHelper
    TOOL_ID = "sendRSEQtoolsEmail"

    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "sendRSEQtoolsEmailWrapper.rb"
    end
  end
end; end; end
