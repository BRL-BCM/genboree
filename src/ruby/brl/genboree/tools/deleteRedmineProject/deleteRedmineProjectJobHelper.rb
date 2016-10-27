require 'brl/genboree/tools/workbenchJobHelper'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/rest/helpers/redminePrjApiUriHelper'

module BRL; module Genboree; module Tools
  class DeleteRedmineProjectJobHelper < WorkbenchJobHelper
    TOOL_ID = "deleteRedmineProject"
    def runInProcess
      success = false
      redminePrjUrl = @workbenchJobObj.outputs[0]
      redmineApiHelper = BRL::Genboree::REST::Helpers::RedminePrjApiUriHelper.new()
      redmineApiHelper.apiCaller = BRL::Genboree::REST::WrapperApiCaller.new("", "", @userId)
      respObj = redmineApiHelper.deleteRedminePrj(redminePrjUrl)
      if(respObj[:success])
        success = true
      else
        success = false
        # @todo would be nice to have HTTP_STATUS_NAMES as in REST resources
        @workbenchJobObj.context['wbErrorName'] = :"Internal Server Error"
        @workbenchJobObj.context['wbErrorMsg'] = respObj[:msg]
      end
      return success
    end
  end
end; end; end
