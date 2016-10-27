require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/helpers/sniffer'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class FileTextViewerRulesHelper < WorkbenchRulesHelper
    TOOL_ID = 'fileTextViewer'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      # If we pass that initial check, we need to make sure that our file is ASCII
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
        # If the type is NOT ascii-based, then we reject the file because we are only accepting ASCII text files at the moment.
        # The file types checked were determined by looking at the "ascii" value for each file type in the sniffer.
        if(type != "vwig" and type != "fwig" and type != "wig" and type != "bedGraph" and type != "newick" and type != "fastq" and type != "fa" and type != "ascii" and type != "UTF") 
          rulesSatisfied = false
          errorMsg = "INVALID_FILE_FORMAT: Input file is not in ASCII text format. Please check the file format."
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
            errorMsg = "INVALID_STORAGE_TYPE: You cannot currently use this tool to view text files hosted on our FTP server."
            wbJobEntity.context['wbErrorMsg'] = errorMsg
          end
        end
      end
      return rulesSatisfied
    end

  end
end ; end; end # module BRL ; module Genboree ; module Tools
