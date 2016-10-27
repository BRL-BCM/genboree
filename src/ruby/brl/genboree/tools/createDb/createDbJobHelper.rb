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
  class CreateDbJobHelper < WorkbenchJobHelper

    TOOL_ID = 'createDb'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      wbNodeIds = @workbenchJobObj.context['wbNodeIds']
      dbName = CGI.escape(@workbenchJobObj.settings['dbName'].strip)
      desc = @workbenchJobObj.settings['description']
      species = @workbenchJobObj.settings['species']
      version = @workbenchJobObj.settings['version']
      refPlatform = @workbenchJobObj.settings['refPlatform']
      output = @workbenchJobObj.outputs[0]
      uri = URI.parse(output)
      host = uri.host
      rsrcPath = uri.path
      apiCaller = nil
      if(refPlatform == 'userWillUpload')
        apiCaller = WrapperApiCaller.new(host, "#{rsrcPath}/db/#{dbName}?", @userId)
      else
        apiCaller = WrapperApiCaller.new(host, "#{rsrcPath}/db/#{dbName}?templateName=#{CGI.escape(refPlatform)}", @userId)
      end
      # Making internal API call
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      payload = {"data"=>{"name"=>dbName, "entrypoints"=>nil, "gbKey"=>"", "version"=>version, "description"=>desc, "refSeqId"=>"", "species"=>species, "public" => false}}
      resp = apiCaller.put(payload.to_json)
      if(!apiCaller.succeeded?)
        @workbenchJobObj.context['wbErrorMsg'] = apiCaller.parseRespBody['status']['msg']
        success = false
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
