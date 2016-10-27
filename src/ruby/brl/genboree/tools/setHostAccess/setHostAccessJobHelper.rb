
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/cache/helpers/dnsCacheHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/rest/data/hostRecordEntity'

include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class SetHostAccessJobHelper < WorkbenchJobHelper

    TOOL_ID = 'setHostAccess'

    include BRL::Cache::Helpers::DNSCacheHelper

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      remoteHost = @workbenchJobObj.settings['remoteHost']
      remoteLogin = @workbenchJobObj.settings['remoteLogin']
      remoteToken = @workbenchJobObj.settings['remoteToken']
      # The RulesHelper has run and ok'd this. So we know:
      # 1. The target is THIS genboree server
      # 2. The remote host entered is NOT THIS genboree server
      # 3. The credentials provided do actually work
      # 4. The user confirmed they want to replace the existing credentials for that host (if existed)
      #
      # Make sure we have all the info we need
      if(remoteHost and remoteLogin and remoteToken and !(remoteHost.empty? or remoteLogin.empty? or remoteToken.empty?))
        # What is the target host at which we are registering host access?
        targetHost = @workbenchJobObj.outputs[0]
        uri = URI.parse(targetHost)
        host = uri.host
        # We MUST have access info for this user at that host in @hostAuthMap.
        authRec = @hostAuthMap[self.class.canonicalAddress(host)]
        if(authRec and !authRec.empty?)
          userLoginAtHost = authRec[0]
          userTokenAtHost = authRec[1]
          # Create payload object
          payloadObj = BRL::Genboree::REST::Data::HostRecordEntity.new(false, remoteHost, remoteLogin, remoteToken)
          # Make apiCaller, using USER's auth info at whatever host
          apiCaller = ApiCaller.new(host, "/REST/v1/usr/{usr}/host/{host}?", @hostAuthMap)
          # Making internal API call
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          resp = apiCaller.put({:usr => userLoginAtHost, :host => remoteHost}, payloadObj.to_json)
          if(!apiCaller.succeeded?)
            success = false
            @workbenchJobObj.context['wbErrorMsg'] = JSON.parse(apiCaller.respBody)['status']['msg']
          else
            @workbenchJobObj.context['response'] = JSON.parse(apiCaller.respBody)['status']['msg']
            @workbenchJobObj.context['doRefreshMainTree'] = true
            @workbenchJobObj.context['wbAcceptMsg'] = "Access info for #{remoteHost} has been saved."
            success = true
          end
        else
          success = false
          @workbenchJobObj.context['wbErrorMsg'] = "ERROR: your credential info here at #{host.inspect} is corrupt."
        end
      else
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = "You must provide ALL of: Remote Host, Remote Login, Remote Password."
      end
      return success
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
