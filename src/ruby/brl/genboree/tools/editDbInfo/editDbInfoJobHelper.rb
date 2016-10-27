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
  class EditDbInfoJobHelper < WorkbenchJobHelper

    TOOL_ID = 'editDbInfo'



    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      newName = @workbenchJobObj.settings['newName'].strip
      desc = @workbenchJobObj.settings['desc'].strip
      version = @workbenchJobObj.settings['version'].strip
      species = @workbenchJobObj.settings['species'].strip
      output = @workbenchJobObj.outputs[0]
      @renameList = [output, newName] # Rename anyway, even if the name of the database has not been changed. This will refresh the db list and pull in the changes
      targetUri = URI.parse(output)
      targetHost = targetUri.host
      targetRsrcPath = targetUri.path
      apiCaller = WrapperApiCaller.new(targetHost, "#{targetRsrcPath}?", @userId)
      apiCaller.get()
      resp = JSON.parse(apiCaller.respBody)['data']
      # Only name, version, species and description are used for updating a db.
      payload = {"data"=>{"name"=>newName, "entrypoints"=>nil, "gbKey"=>resp['gbKey'], "version"=>version, "description"=>desc, "refSeqId"=>"", "species"=>species, "public" => resp['public']}}
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.put(payload.to_json)
      if(!apiCaller.succeeded?)
        @workbenchJobObj.context['wbErrorMsg'] = JSON.parse(apiCaller.respBody)['status']['msg']
        success = false
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
        wbJobEntity.context['resourceType'] = 'database'
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
