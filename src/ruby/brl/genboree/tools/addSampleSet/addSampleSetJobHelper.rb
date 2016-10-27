require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'uri'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/user'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class AddSampleSetJobHelper < WorkbenchJobHelper

    TOOL_ID = 'addSampleSet'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      inputs = @workbenchJobObj.inputs
      wbNodeIds = @workbenchJobObj.context['wbNodeIds']
      genbConf = BRL::Genboree::GenboreeConfig.load()
      apiDbrc = @superuserApiDbrc
      sampleSet = @workbenchJobObj.settings['sampleSet']
      output = @workbenchJobObj.outputs[0]
      uri = URI.parse(output)
      apiCaller = ApiCaller.new(uri.host, "#{uri.path.chomp("?")}/sampleSet/#{CGI.escape(sampleSet)}?", @hostAuthMap)
      # Making internal API call
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      resp = apiCaller.put()
      if(!apiCaller.succeeded?)
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = "Internal Server Error: Could not create sample set:\n#{apiCaller.respBody.inspect}"
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
