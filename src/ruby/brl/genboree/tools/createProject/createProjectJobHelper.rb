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
  class CreateProjectJobHelper < WorkbenchJobHelper

    TOOL_ID = 'createProject'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      inputs = @workbenchJobObj.inputs
      wbNodeIds = @workbenchJobObj.context['wbNodeIds']
      projectName = CGI.escape(@workbenchJobObj.settings['projectName'])
      projectTitle = @workbenchJobObj.settings['projectTitle']
      projectDesc = @workbenchJobObj.settings['projectDescription']
      userId = @userId
      output = @workbenchJobObj.outputs[0]
      uri = URI.parse(output)
      host = uri.host
      rsrcPath = uri.path
      apiCaller = WrapperApiCaller.new(host, "#{rsrcPath}/prj/#{projectName}?", userId)
      # Making internal API call
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      resp = apiCaller.put()
      if(apiCaller.succeeded?)
        # Add the title if provided
        if(projectTitle)
          apiCaller = WrapperApiCaller.new(host, "#{rsrcPath}/prj/#{projectName}/title?", userId)
          payload = {"data"=>{"text"=>"#{projectTitle}"}}
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.put(payload.to_json)
          if(!apiCaller.succeeded?)
            workbenchJobObj.context['wbErrorMsg'] = apiCaller.parseRespBody['status']['msg']
            success = false
          end
        end
        if(projectDesc and success) # Only proceed if project Description is provided and we didn't encounter a failure for the previous API call
          apiCaller = WrapperApiCaller.new(host, "#{rsrcPath}/prj/#{projectName}/description?", userId)
          payload = {"data"=>{"text"=>"#{projectDesc}"}}
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.put(payload.to_json)
          if(!apiCaller.succeeded?)
            @workbenchJobObj.context['wbErrorMsg'] = apiCaller.parseRespBody['status']['msg']
            success = false
          end
        end
      else
        @workbenchJobObj.context['wbErrorMsg'] = apiCaller.parseRespBody['status']['msg']
        success = false
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
