require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'uri'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class RemoveFilesFromEntityListJobHelper < WorkbenchJobHelper

    TOOL_ID = 'removeFilesFromEntityList'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      multiSelectInputList = @workbenchJobObj.settings['multiSelectInputList']
      input = @workbenchJobObj.inputs[0]
      targetUri = URI.parse(input)
      targetHost = targetUri.host
      targetRsrcPath = targetUri.path
      fileEntityList = @fileEntityListApiHelper.extractName(@workbenchJobObj.inputs[0])
      # First construct the payload for 'putting' by getting the 'urls' for all the inputs
      multiSelectInputList.each { |input|
        urlList = []
        urlList << {"url" => input } 
        # Do a 'put' on the target db:
        apiCaller = WrapperApiCaller.new(targetHost, "#{targetRsrcPath}/files/entityList/#{CGI.escape(fileEntityList)}?", @workbenchJobObj.context['userId'])
        payload = {"data" => urlList}
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        resp = apiCaller.delete({}, payload.to_json)
        if(!apiCaller.succeeded?)
          success = false
          @workbenchJobObj.context['wbErrorMsg'] = apiCaller.parseRespBody
        end
      }
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
