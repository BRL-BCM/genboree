require 'brl/genboree/tools/workbenchJobHelper'

module BRL; module Genboree; module Tools
  class KbBulkUploadJobHelper < WorkbenchJobHelper
    TOOL_ID = "kbBulkUpload"

    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "kbBulkUploadWrapper.rb"
    end
  end
end; end; end
