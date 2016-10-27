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
  class DeleteTracksJobHelper < WorkbenchJobHelper

    TOOL_ID = 'deleteTracks'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      trksToDel = @workbenchJobObj.settings['trksToDel']
      dbUriObj = URI.parse(@dbApiHelper.extractPureUri(@workbenchJobObj.inputs[0]))
      apiCaller = ApiCaller.new(dbUriObj.host, "#{dbUriObj.path}/trks?trackNames=#{trksToDel.join(',')}", @hostAuthMap)
      apiCaller.delete()
      if(!apiCaller.succeeded?)
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = apiCaller.parseRespBody
      end
      return success
    end


  end
end ; end ; end # module BRL ; module Genboree ; module Tools
