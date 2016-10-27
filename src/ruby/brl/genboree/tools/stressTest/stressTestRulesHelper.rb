require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class StressTestRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        outputs = wbJobEntity.outputs
        inputs = wbJobEntity.inputs
        userId = wbJobEntity.context['userId']
        # Check 1: Version matching
        unless(checkDbVersions(inputs + outputs, skipNonDbUris=true)) # Failed
          wbJobEntity.context['wbErrorMsg'] = "The database version of one or more inputs does not match the version of the target database."
        else
          rulesSatisfied = true
        end
          # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end
          rulesSatisfied = false
          output = wbJobEntity.outputs[0]
          uri = URI.parse(output)
          host = uri.host
          rcscUri = uri.path
          rcscUri = rcscUri.chomp("?")
          analysisName = CGI.escape(wbJobEntity.settings['analysisName'])
          rcscUri << "/file/EpigenomeSlice/#{analysisName}/jobFile.json?"
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{analysisName.inspect} has already been launched before. Please select a different analysis name."
          else
            settings = wbJobEntity.settings
            # Check 1: If ROI track is Hdhv?
            wrongInput = false
            roiTrack = wbJobEntity.settings['roiTrack']
            wrongInput = true if(roiTrack.nil? or roiTrack.empty? or @trkApiHelper.isHdhv?(wbJobEntity.settings['roiTrack'], @hostAuthMap))
            if(wrongInput)
              wbJobEntity.context['wbErrorMsg'] = "Invalid Input: ROI Track not selected or is a high density track. "
            else
              rulesSatisfied = true
            end
          end
        end
      end
      return rulesSatisfied
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
