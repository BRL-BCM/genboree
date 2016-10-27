require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'uri'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class MicrobiomeSampleGridViewerJobHelper < WorkbenchJobHelper

    TOOL_ID = 'microbiomeSampleGridViewer'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      dbList = []
      inputs = @workbenchJobObj.inputs
      inputs.each { |input|
        dbList << CGI.escape(input)
      }
      @workbenchJobObj.settings['dbList'] = dbList.join(",")
      return success
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
