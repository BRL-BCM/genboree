require 'brl/genboree/rest/helpers'
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
include BRL::Genboree::REST::Helpers

module BRL ; module Genboree ; module Tools
  class CreateRemoteStorageAreaRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'createRemoteStorageArea'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        userId = wbJobEntity.context['userId']
        permission = testUserPermissions(wbJobEntity.outputs, 'o')
        unless(permission)
          rulesSatisfied = false
          wbJobEntity.context['wbErrorMsg'] = "NO PERMISSION: You need administrator level access to create a remote area."
        else
          # ------------------------------------------------------------------
          # CHECK SETTINGS
          # ------------------------------------------------------------------
          if(sectionsToSatisfy.include?(:settings))
            # Check :settings together with info from :outputs :
            unless(sectionsToSatisfy.include?(:outputs) and sectionsToSatisfy.include?(:inputs))
              raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
            end
            rulesSatisfied = false
            # Grab new remote area name
            remoteStorageAreaName = CGI.escape(wbJobEntity.settings['remoteStorageAreaName'].strip)
            # Parse output as URI
            uri = URI.parse(wbJobEntity.outputs[0])
            # Find host and resource URI path for new remote area 
            host = uri.host
            rsrcUri = "#{uri.path}/files/#{remoteStorageAreaName}?"
            # Check 1: Check if another folder already has the same name as our new remote area
            apiCaller = WrapperApiCaller.new(host, rsrcUri, userId)
            apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv) # Make API call internal
            apiCaller.get()
            if(apiCaller.succeeded?)
              wbJobEntity.context['wbErrorMsg'] = "You already have a folder in your Files area with the name #{CGI.unescape(remoteStorageAreaName).inspect}. Please select another name for your new remote storage area."
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

  end
end ; end; end # module BRL ; module Genboree ; module Tools
