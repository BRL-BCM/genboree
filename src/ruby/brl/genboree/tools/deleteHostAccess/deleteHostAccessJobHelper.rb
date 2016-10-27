
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
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class DeleteHostAccessJobHelper < WorkbenchJobHelper

    TOOL_ID = 'deleteHostAccess'

    include BRL::Cache::Helpers::DNSCacheHelper

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      # Get user's host-auth info, for user mentioned in @workbenchJobObj
      inputs = @workbenchJobObj.inputs
      uri = URI.parse(inputs.first)
      remoteHost = uri.host
      # The target FROM which we are removing access is this one.
      targetHost = @genbConf.machineName
      # We need (a) the remote host removed from input data panel and (b) the whole data tree refreshed
      wbNodeIds = @workbenchJobObj.context['wbNodeIds']
      # We aren't trying to set access info for THIS host are we? It's not remote.
      # - Need to check thoroughly via canonical addresses AND domain names
      if(!self.class.canonicalAddressesMatch?(remoteHost, [ @genbConf.machineName, @genbConf.machineNameAlias ]))
        # We MUST have access info for the targetHost in @hostAuthMap.
        authRec = @hostAuthMap[self.class.canonicalAddress(targetHost)]
        if(authRec and !authRec.empty?)
          userLoginAtHost = authRec[0]
          userTokenAtHost = authRec[1]
          @killList = []
          nodeCount = 0
          apiCaller = ApiCaller.new(targetHost, "/REST/v1/usr/{usr}/host/{host}?", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          resp = apiCaller.delete({:usr => userLoginAtHost, :host => remoteHost})
          if(!apiCaller.succeeded?)
            success = false
            @workbenchJobObj.context['wbErrorMsg'] = JSON.parse(apiCaller.respBody)['status']['msg']
          else
            @workbenchJobObj.context['response'] = JSON.parse(apiCaller.respBody)['status']['msg']
            @killList << wbNodeIds[nodeCount]
            nodeCount = 1
            @workbenchJobObj.context['hostDeleted'] = 1
            @workbenchJobObj.context['wbAcceptMsg'] = "Access info for #{remoteHost.inspect} has been removed."
            success = true
          end
        else
          success = false
          @workbenchJobObj.context['wbErrorMsg'] = "Failed: no permission to delete access from the server #{targetHost.inspect}."
        end
      else
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = "You cannot remove your access to #{remoteHost.inspect} as a remote Genboree host, because it is not remote. It is that same as the server you are working on (#{targetHost.inspect})."
      end
      return success
    end

    # [+msgType+]   Symbol: Should be one of :Accepted, :Rejected :Warnings or :Failure
    # [+returns+]   String; Html text
    def getMessage(msgType, wbJobEntity)
      # A String with technical details about the error. Not for users. Backtraces for example. This will just end up in the stderr log.
      # This one may be optional depending on the error (maybe it was a user error or the nature of an input or something) and whether the info is already in the stderr log.
      if(!wbJobEntity.context['wbErrorDetails'].nil?)
        $stderr.puts wbJobEntity.context['wbErrorDetails']
      end
      # Try to render the appropriate job message into HTML depending on message type
      # (:Accepted, :Rejected, :Failure, :Warnings)
      # - key for jobDeletion.rhtml processing which will apply the killList to the UI.
      uiType = msgType == :Warnings ? "jobWarnings" : "jobDeletion"
      toolIdStr = wbJobEntity.context['toolIdStr']
      wbJobEntity.context['resourceType'] = 'hosts'
      wbJobEntity.context['killList'] = @killList
      # Add genbConf and toolIdStr to the evaluate() context so they are available
      # as @genbConf and @toolIdStr in the rhtml
      respHtml = renderDialogContent(toolIdStr, uiType, wbJobEntity.getEvalContext(:genbConf => @genbConf, :toolIdStr => toolIdStr))
      return respHtml
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
