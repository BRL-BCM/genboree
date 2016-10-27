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
  class CreateGroupJobHelper < WorkbenchJobHelper

    TOOL_ID = 'createGroup'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      wbNodeIds = @workbenchJobObj.context['wbNodeIds']
      gpName = CGI.escape(@workbenchJobObj.settings['gpName'])
      desc = @workbenchJobObj.settings['description']
      output = @workbenchJobObj.outputs[0]
      uri = URI.parse(output)
      host = uri.host
      rsrcPath = "/REST/v1/grp/#{gpName}?"
      apiCaller = WrapperApiCaller.new(host, rsrcPath, @userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      payload = { "data"=>{ "name"=>CGI.unescape(gpName), "description"=>desc } }
      resp = apiCaller.put(payload.to_json)
      if(!apiCaller.succeeded?)
        @workbenchJobObj.context['wbErrorMsg'] = apiCaller.parseRespBody['status']['msg']
        success = false
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
