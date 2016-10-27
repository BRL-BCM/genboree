require 'time'
require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class GettingStartedRulesHelper < WorkbenchRulesHelper
    TOOL_LABEL = '[NOT SET]' # Keep this as NOT SET. Will be discarded from the job list
    TOOL_ID = 'gettingStarted'
    TOOL_TYPE = 'Utility'
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      return true
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
