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
  class DeleteSampleListsJobHelper < WorkbenchJobHelper

    TOOL_ID = 'deleteSampleLists'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      inputs = @workbenchJobObj.inputs
      wbNodeIds = @workbenchJobObj.context['wbNodeIds']
      userId = @userId
      @killList = []
      sampleListsDeleted = 0
      nodeCount = 0
      inputs.each { |input|
        uri = URI.parse(input)
        host = uri.host
        rsrcPath = uri.path
        apiCaller = WrapperApiCaller.new(host, "#{rsrcPath}", userId)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.delete()
        if(apiCaller.succeeded?)
          @killList.push(wbNodeIds[nodeCount])
          sampleListsDeleted += 1
        else
          $stderr.debugPuts(__FILE__, __method__, "ERROR:", "(jobId: #{workbenchJobObj.settings['jobId']}) apicaller response: \n#{apiCaller.respBody.inspect}")
        end
        nodeCount += 1
      }
      if(sampleListsDeleted != inputs.size)
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = "#{inputs.size - sampleListsDeleted} entity lists could not be removed. "
      end
      @workbenchJobObj.context['entityListsDeleted'] = sampleListsDeleted
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
      uiType = msgType == :Warnings ? "jobWarnings" : "jobDeletion"
      toolIdStr = wbJobEntity.context['toolIdStr']
      wbJobEntity.context['resourceType'] = 'sampleEntityLists'
      wbJobEntity.context['killList'] = @killList
      # Add genbConf and toolIdStr to the evaluate() context so they are available
      # as @genbConf and @toolIdStr in the rhtml
      respHtml = renderDialogContent(toolIdStr, uiType, wbJobEntity.getEvalContext(:genbConf => @genbConf, :toolIdStr => toolIdStr))
      return respHtml
    end

  end


end ; end ; end # module BRL ; module Genboree ; module Tools