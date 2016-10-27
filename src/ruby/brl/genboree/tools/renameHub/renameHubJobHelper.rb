require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'uri'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class RenameHubJobHelper < WorkbenchJobHelper

    TOOL_ID = 'renameHub'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      newName = @workbenchJobObj.settings['newName'].strip
      input = @workbenchJobObj.inputs.first
      @userId = @workbenchJobObj.context['userId']
      @renameList = [input, newName]
      targetUri = URI.parse(input)
      targetHost = targetUri.host
      targetRsrcPath = targetUri.path
      apiCaller = WrapperApiCaller.new(targetHost, "#{targetRsrcPath}?detailed=true", @userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(!apiCaller.succeeded?)
        @workbenchJobObj.context['wbErrorMsg'] = JSON.parse(apiCaller.respBody)['status']['msg']
        success = false
      else
        #update the name and make a new put request
        resp = JSON.parse(apiCaller.respBody)['data']
        resp['name'] = newName
        grpUri = @grpApiHelper.extractPureUri(input)
        grpObj = URI.parse(grpUri)
        apiCall = WrapperApiCaller.new(targetHost, "#{grpObj.path}/hub/#{CGI.escape(newName)}?detailed=true", @userId)
        apiCall.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCall.put({}, resp.to_json)
        if(!apiCall.succeeded?)
          @workbenchJobObj.context['wbErrorMsg'] = JSON.parse(apiCall.respBody)['status']['msg']
          success = false
        else
          # delete the original hub
          apiCaller.delete()
        end

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
      if(wbJobEntity.context['wbErrorMsg'].nil? or wbJobEntity.context['wbErrorMsg'].empty?)
        # Try to render the appropriate job message into HTML depending on message type
        # (:Accepted, :Rejected, :Failure, :Warnings)
        uiType = msgType == :Warnings ? "jobWarnings" : "jobRenaming"
        toolIdStr = wbJobEntity.context['toolIdStr']
        wbJobEntity.context['resourceType'] = 'hub'
        wbJobEntity.context['renameList'] = @renameList
        # Add genbConf and toolIdStr to the evaluate() context so they are available
        # as @genbConf and @toolIdStr in the rhtml
        respHtml = renderDialogContent(toolIdStr, uiType, wbJobEntity.getEvalContext(:genbConf => @genbConf, :toolIdStr => toolIdStr))
      else
        # Try to render the appropriate job message into HTML depending on message type
        # (:Accepted, :Rejected, :Failure, :Warnings)
        uiType = "job#{msgType}"
        toolIdStr = wbJobEntity.context['toolIdStr']
        # Add genbConf and toolIdStr to the evaluate() context so they are available
        # as @genbConf and @toolIdStr in the rhtml
        respHtml = renderDialogContent(toolIdStr, uiType, wbJobEntity.getEvalContext(:genbConf => @genbConf, :toolIdStr => toolIdStr))
      end
      return respHtml
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
