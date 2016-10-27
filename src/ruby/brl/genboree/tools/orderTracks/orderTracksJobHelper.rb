require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class OrderTracksJobHelper < WorkbenchJobHelper

    TOOL_ID = 'orderTracks'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    
    def runInProcess()
      success = true
      begin
        settings = @workbenchJobObj.settings
        btnType = settings['btnType']
        userId = settings['userId']
        trkOrderHash = settings['trkOrderHash']
        count = 0
        uriObj = URI.parse(@workbenchJobObj.inputs[0])
        if(btnType == 'Save' or btnType == 'Set As Default')
          aspect = ( btnType == 'Save' ? 'order' : 'defaultOrder')
          apiCaller = ApiCaller.new(uriObj.host, "#{uriObj.path}/trks/#{aspect}?", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          payload = {'data' => {'hash' => trkOrderHash }}
          apiCaller.put(payload.to_json)
          if(!apiCaller.succeeded?)
            raise JSON.parse(apiCaller.respBody)['status']['msg']
          end
        elsif(btnType == 'Reset to default') # Nuke all user specific settings
          apiCaller = ApiCaller.new(uriObj.host, "#{uriObj.path}/trks/order?", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.delete()
          if(!apiCaller.succeeded?)
            raise JSON.parse(apiCaller.respBody)['status']['msg']
          end
        end
      rescue => err
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = "#{err.message}"
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
