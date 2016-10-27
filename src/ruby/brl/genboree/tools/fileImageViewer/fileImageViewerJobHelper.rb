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
  class FileImageViewerJobHelper < WorkbenchJobHelper

    TOOL_ID = 'fileImageViewer'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      # Grab file input from work bench
      inputs = @workbenchJobObj.inputs
      inputs.each { |file|
        # Parse URI and grab resource path
        targetUri = URI.parse(file)
        rsrcPath = targetUri.path
        rsrcPath << "/data?format=imgHtml&uriTemplate=apiCaller.jsp%3FrsrcPath%3D%7BURI%7D%26apiMethod%3DGET%26fileDownload=true"
        # Create the API caller
        apiCaller = WrapperApiCaller.new(targetUri.host, rsrcPath, @userId)
        # Making internal API call
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        # Grab the image URI requested
        apiCaller.get()
        # If the API call didn't succeed, then we want to print information about the error and set success to false
        if(!apiCaller.succeeded?)
          $stderr.puts(apiCaller.parseRespBody)
          success = false
        # Otherwise, if the API call did succeed, then we will set the 'imgResponse' field of our settings to be the requested text
        else
          @workbenchJobObj.settings['imgResponse'] = apiCaller.respBody
        end
      }
      # If we do not succeed, then we will set up an error message for the user
      if(!success)
        @workbenchJobObj.context['wbErrorMsg'] = "Your file could not be viewed.  Please contact Genboree team (paithank@bcm.edu) for help."
      end
      # Finally, we return whether we were successful in grabbing the text
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
