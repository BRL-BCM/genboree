require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'uri'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class TabularTrackViewerJobHelper < WorkbenchJobHelper

    TOOL_ID = 'tabularTrackViewer'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      trkList = []
      inputs = @workbenchJobObj.inputs
      inputs.each { |input|
        trkList << CGI.escape(@trkApiHelper.extractName(input))
      }
      @workbenchJobObj.settings['trkList'] = trkList.join(",")
      # Get the refseqId of the database
      uri = URI.parse(@dbApiHelper.extractPureUri(inputs[0]))
      apiCaller = WrapperApiCaller.new(uri.host, uri.path, @userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      resp = JSON.parse(apiCaller.respBody)['data']
      @workbenchJobObj.settings['refseqId'] = resp['refSeqId']
      @workbenchJobObj.settings['host'] = uri.host
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
