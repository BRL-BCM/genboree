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
  class CopySampleListsJobHelper < WorkbenchJobHelper

    TOOL_ID = 'copySampleLists'


    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      listsCopied = 0
      multiSelectInputList = @workbenchJobObj.settings['multiSelectInputList']
      deleteSourceSamplesRadio = CGI.escape(@workbenchJobObj.settings['deleteSourceSamplesRadio'])
      output = @workbenchJobObj.outputs[0]
      @user = @superuserApiDbrc.user
      @password = @superuserApiDbrc.password
      targetUri = URI.parse(output)
      targetHost = targetUri.host
      targetRsrcPath = targetUri.path
      # First construct the payload for 'putting' by getting the 'urls' for all the inputs
      multiSelectInputList.each { |input|
        uri = URI.parse(input)
        host = uri.host
        rsrcPath = uri.path
        apiCallerSrc = WrapperApiCaller.new(host, rsrcPath, @userId)
        apiCallerSrc.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCallerSrc.get()
        resp = JSON.parse(apiCallerSrc.respBody)['data']
        urlList = []
        resp.each { |urlHash|
          urlList << {"url" => urlHash['url']}
        }
        sampleEntityList = @sampleEntityListApiHelper.extractName(input)
        # Do a 'put' on the target db:
        apiCaller = WrapperApiCaller.new(targetHost, "#{targetRsrcPath}/samples/entityList/#{sampleEntityList}?", @userId)
        payload = {"data" => urlList}
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        resp = apiCaller.put(payload.to_json)
        if(apiCaller.succeeded?)
          listsCopied += 1
        end
        if(deleteSourceSamplesRadio == 'move') # We need to nuke the source entity list if we are doing a move
          apiCallerSrc.delete()
        end
      }
      @workbenchJobObj.context['listsCopied'] = listsCopied
      if(multiSelectInputList.size != listsCopied)
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = "Only #{listsCopied} sample entity list(s) were copied/moved."
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
