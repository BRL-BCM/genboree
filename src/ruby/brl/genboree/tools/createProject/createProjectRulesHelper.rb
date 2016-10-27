require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class CreateProjectRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'createProject'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)

        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        userId = wbJobEntity.context['userId']
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end
          rulesSatisfied = false
          # Check 1: check if project already exists
          projectName = CGI.escape(wbJobEntity.settings['projectName'])
          uri = URI.parse(wbJobEntity.outputs[0])
          host = uri.host
          rsrcUri = "#{uri.path}/prj/#{projectName}?"
          apiCaller = WrapperApiCaller.new(host, rsrcUri, userId)
          # Making internal API call
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?)
            wbJobEntity.context['wbErrorMsg'] = "The project: #{CGI.unescape(projectName).inspect} already exists. Please select another name for the new project. "
          else
            # Project name should not have illegal chars
            if( ( CGI.unescape(projectName) =~ /^[A-Za-z0-9][A-Za-z0-9._\- \/]*$/ ) == nil)
              wbJobEntity.context['wbErrorMsg'] = "INVALID_NAME: The project name has illegal characters. All characters in the project name MUST come from the following set: [A-Za-z0-9][A-Za-z0-9._\- \/]"
            else
              rulesSatisfied = true
            end
          end
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
      else # No warnings for now
        warningsExist = false
      end
      @sampleSetApiHelper.clear() if(!@sampleSetApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
