require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'uri'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require 'brl/genboree/abstract/resources/user'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class DeleteGroupJobHelper < WorkbenchJobHelper

    TOOL_ID = 'deleteGroup'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      inputs = @workbenchJobObj.inputs
      gpToDelete = inputs[0]
      genbConf = BRL::Genboree::GenboreeConfig.load()
      dbu = BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, nil)
      userId = @userId
      @killList = []
      problemList = []
      nodeCount = 0
      uri = URI.parse(gpToDelete)
      apiCaller = ApiCaller.new(uri.host, uri.path, @hostAuthMap)
      # Making internal API call
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      resp = apiCaller.delete()
      if(apiCaller.succeeded?)
        @killList.push(gpToDelete)
      else
        @workbenchJobObj.context['wbErrorMsg'] = JSON.parse(apiCaller.respBody)['status']['msg']
        success = false
      end
      nodeCount += 1
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
      $stderr.puts "msgType: #{msgType.inspect}"
      uiType = nil
      if(msgType == :Warnings)
        uiType = "jobWarnings"
      elsif(msgType == :Rejected)
        uiType = "jobRejected"
      else
        uiType = "jobDeletion"
      end
      toolIdStr = wbJobEntity.context['toolIdStr']
      wbJobEntity.context['resourceType'] = 'group'
      wbJobEntity.context['killList'] = @killList
      # Add genbConf and toolIdStr to the evaluate() context so they are available
      # as @genbConf and @toolIdStr in the rhtml
      respHtml = renderDialogContent(toolIdStr, uiType, wbJobEntity.getEvalContext(:genbConf => @genbConf, :toolIdStr => toolIdStr))
      return respHtml
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
