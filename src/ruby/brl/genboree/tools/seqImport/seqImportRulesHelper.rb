require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class SeqImportRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'seqImporter'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      outputs = wbJobEntity.outputs
      if(rulesSatisfied)
        userId = wbJobEntity.context['userId']
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)

        # determine if user can access children in their inputs, provide detail if they cannot
        rulesSatisfied, context, childArray = childrenAccessible?(wbJobEntity.inputs, :sample, userId, 'r')
        if(rulesSatisfied)
          # then access check went ok on children, update inputs
          wbJobEntity.inputs = childArray
          # ------------------------------------------------------------------
          # CHECK SETTINGS
          # ------------------------------------------------------------------
          if(sectionsToSatisfy.include?(:settings))
            # Check :settings together with info from :outputs :
            unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
              raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
            end
            genbConf = BRL::Genboree::GenboreeConfig.load()
            user = @superuserApiDbrc.user
            pass = @superuserApiDbrc.password
            rulesSatisfied = false
            # Check 1: The dir for sample set name should not exist
            uri = URI.parse(outputs[0])
            host = uri.host
            rcscUri = uri.path
            rcscUri = rcscUri.chomp("?")
            rcscUri << "/file/MicrobiomeData/#{CGI.escape(wbJobEntity.settings['sampleSetName'])}/jobFile.json?"
            apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            if(apiCaller.succeeded?) # Failed: job dir already exists
              wbJobEntity.context['wbErrorMsg'] = "A job with the sample set name: #{wbJobEntity.settings['sampleSetName']} has already been launched before. Please select a different sample set name."
            else
              rulesSatisfied = true
            end
          end
        else
          # then user does not have access to children, set error message
          wbJobEntity.context.merge!(context)
        end # end 2nd rules satisfied
      end # end 1st rules satisified
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
