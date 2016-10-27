require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/rest/apiCaller'

module BRL ; module Genboree ; module Tools
  class NovelMiRNADetectionRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'novelMiRNADetection'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        outputs = wbJobEntity.outputs
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        # Check 1: does user have write permission to the db?
        userId = wbJobEntity.context['userId']
        # Check 2: The output db can be either one of: hg18, hg19 or mm9
        uri = URI.parse(outputs[0])
        # Making an API call to support the multi-host Genboree framework
        apiKey = @superuserApiDbrc
        apiCaller = BRL::Genboree::REST::ApiCaller.new(uri.host, uri.path, @hostAuthMap)
        ## Do internal request if enabled (in this case, if we've been given a Rack env hash to work from)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody)
        dbVer = resp['data']['version']
        if(dbVer != 'hg18' and dbVer != 'hg19' and dbVer != 'mm9')
          wbJobEntity.context['wbErrorMsg'] = "INVALID_OUTPUT: The genome version of the output database MUST be one of: ['hg18', 'hg19' or 'mm9']"
        else
          # Add the dbver in the setting so that we can access it in the UI side
          wbJobEntity.settings['dbVer'] = dbVer
          rulesSatisfied = true
        end
      end
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

      return rulesSatisfied
    end

    # It's a good idea to catch any potential errors now instead of relying on the job to do validation because,
    # the job may get queued and the user wouldn't be notified  for an unnecessarily long time that they have something minor wrong with their inputs.
    #
    # [+returns+] boolean
    def warningsExist?(wbJobEntity)
      warningsExist = true
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else # Look for warnings
        # no warnings for now
        warningsExist = false
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
