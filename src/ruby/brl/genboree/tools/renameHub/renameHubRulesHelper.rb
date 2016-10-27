require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class RenameHubRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'renameHub'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        userId = wbJobEntity.context['userId']
        user = wbJobEntity.context['userLogin']
        dbu = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil, nil)
        hostAuthMap = Abstraction::User.getHostAuthMapForUserId(dbu, userId)
        input = wbJobEntity.inputs.first
        # Check 1: Permission to rename Hub
        grpUri = @grpApiHelper.extractPureUri(input)
        grpUriObj = URI.parse(grpUri)
        apiCaller = ApiCaller.new(grpUriObj.host, "#{grpUriObj.path}/usr/#{user}/role?connect=no", hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        if(apiCaller.succeeded?)
          resp = apiCaller.parseRespBody["data"]
          if(resp["role"] != "administrator")
            rulesSatisfied = false
            wbJobEntity.context['wbErrorMsg'] = "FORBIDDEN: User has no sufficient permissions to delete hub from the group #{@grpApiHelper.extractName(input)}."
          end
        else
          rulesSatisfied = false
          wbJobEntity.context['wbErrorMsg'] = "API call failed to get the user roles. Check: #{apiCaller.respBody.inspect}"
        end

        if(sectionsToSatisfy.include?(:settings))
          # Check 2 :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end
          rulesSatisfied = false
          # Check 3: The name being used to rename should not already exist
          newName = wbJobEntity.settings['newName'].strip
          inUri = URI.parse(@grpApiHelper.extractPureUri(input))
          inHost = inUri.host
          inRsrcPath = inUri.path
          apiCaller = ApiCaller.new(inHost, "#{inRsrcPath}/hub/#{CGI.escape(newName)}?", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?)
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "hubname: #{newName}")
            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT_NAME: A hub with the name: '#{newName}' already exists in the target group. "
          else
            rulesSatisfied = true
          end
        end
      end
      
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
      else # No warnings for now
        warningsExist = false
      end
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
