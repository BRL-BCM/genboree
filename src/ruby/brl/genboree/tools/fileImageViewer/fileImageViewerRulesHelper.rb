require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require "brl/genboree/helpers/sniffer"
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class FileImageViewerRulesHelper < WorkbenchRulesHelper
    TOOL_ID = 'fileImageViewer'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      # If we pass that initial check, we need to make sure that our file is an image
      if(rulesSatisfied)
        # Grab inputs (or just input in this case)
        inputs = wbJobEntity.inputs
        # Grab the URI for that input
        fileUriObj = URI.parse(inputs[0])
        # Create apiCaller for checking format of file
        apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/format?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
        # Grab file format
        apiCaller.get()
        type = apiCaller.parseRespBody["data"]["text"]
        # If the type is NOT image, then we reject the file because this is an image viewer
        if(type != "image") 
          rulesSatisfied = false
          errorMsg = "INVALID_FILE_FORMAT: Input file is not in an image format. Please check the file format."
          wbJobEntity.context['wbErrorMsg'] = errorMsg
        end
        if(rulesSatisfied)
          # Check to see whether file is hosted on remote server - we will raise error if it is (we don't currently support remote servers for this tool)
          apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/storageType?", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          storageType = apiCaller.parseRespBody["data"]["text"]
          if(storageType != "local") 
            rulesSatisfied = false
            errorMsg = "INVALID_STORAGE_TYPE: You cannot currently use this tool to view image files hosted on our FTP server."
            wbJobEntity.context['wbErrorMsg'] = errorMsg
          end
        end
      end
      return rulesSatisfied
    end

  end
end ; end; end # module BRL ; module Genboree ; module Tools
