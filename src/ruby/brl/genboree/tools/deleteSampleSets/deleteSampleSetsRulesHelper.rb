require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/dbUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class DeleteSampleSetsRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'deleteSampleSets'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        # Check 1: does user have access to the sample sets
        userId = wbJobEntity.context['userId']
        @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, userId)
        unless(@dbApiHelper.accessibleByUser?(@dbApiHelper.extractPureUri(inputs.first), userId, CAN_WRITE_CODES))
          # FAILED: doesn't have write access to output database
          wbJobEntity.context['wbErrorMsg'] =
          {
            :msg => "Access Denied: You don't have permission to access the sample sets.",
            :type => :writeableDbs,
            :info => @dbApiHelper.accessibleDatabasesHash(inputs, userId, CAN_WRITE_CODES)
          }
        else # OK: user can write to input database
          rulesSatisfied = true
        end
      end

      # Clean up helpers, which cache many things
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      return rulesSatisfied
    end

    # It's a good idea to catch any potential errors now instead of relying on the job to do validation because,
    # the job may get queued and the user wouldn't be notified  for an unnecessarily long time that they have something minor wrong with their inputs.
    #
    # [+returns+] boolean
    def warningsExist?(wbJobEntity)
      warningsExist = true
      inputs = wbJobEntity.inputs
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else
        warningMsg = "The following Sample Sets are going to be deleted:"
        warningMsg << "<ul>"
        inputs.sort.each { |sampleSet|
          warningMsg << "<li>#{@sampleSetApiHelper.extractName(sampleSet)}</li>"
        }
        warningMsg << "</ul>  "
        wbJobEntity.context['wbErrorMsg'] = warningMsg
        wbJobEntity.context['wbErrorMsgHasHtml'] = true
      end
      @sampleSetApiHelper.clear() if(!@sampleSetApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
