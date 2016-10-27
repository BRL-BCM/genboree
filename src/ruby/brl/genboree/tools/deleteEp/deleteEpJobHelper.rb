require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'uri'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class DeleteEpJobHelper < WorkbenchJobHelper

    TOOL_ID = 'deleteEp'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      userId = @userId
      settings = @workbenchJobObj.settings
      baseWidget = settings['baseWidget']
      epList = []
      settings.each_key { |key|
        if(key =~ /^#{baseWidget}/)
          widgetId = key.split("|")
          if(settings[key] and settings[key] == 'on')
            epList << {"text" => widgetId[1]}
          end
        end
      }
      targetUri = URI.parse(@workbenchJobObj.outputs[0])
      targetHost = targetUri.host
      targetRsrcPath = targetUri.path
      apiCaller = WrapperApiCaller.new(targetHost, "#{targetRsrcPath}/eps?", userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      payload = {"data" => epList }
      apiCaller.delete(nil, payload.to_json)
      if(!apiCaller.succeeded?)
        @workbenchJobObj.context['wbErrorMsg'] = JSON.parse(apiCaller.respBody)['status']['msg']
        success = false
      end
      return success
    end


  end
end ; end ; end # module BRL ; module Genboree ; module Tools
