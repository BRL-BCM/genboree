require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'brl/genboree/rest/helpers/fileEntityListApiUriHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'

include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class DeleteFileListsRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'deleteFileLists'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      return rulesSatisfied
    end

    # It's a good idea to catch any potential errors now instead of relying on the job to do validation because,
    # the job may get queued and the user wouldn't be notified  for an unnecessarily long time that they have something minor wrong with their inputs.
    #
    # [+returns+] boolean
    def warningsExist?(wbJobEntity)
      warningsExist = true
      inputs = wbJobEntity.inputs
      fileEntityListApiHelper = BRL::Genboree::REST::Helpers::FileEntityListApiUriHelper.new()
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else # No warnings for now
        # CHECK 1: does the output db already have any of the input tracks
        inputs = wbJobEntity.inputs
        msg = "The following file entity list(s) will be PERMANENTLY removed:"
        msg << "<ul>"
        inputs.each { |input|
          msg << "<li>#{fileEntityListApiHelper.extractName(input)}</li>"
        }
        msg << "</ul>  "
        wbJobEntity.context['wbErrorMsg'] = msg
        wbJobEntity.context['wbErrorMsgHasHtml'] = true
      end
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
