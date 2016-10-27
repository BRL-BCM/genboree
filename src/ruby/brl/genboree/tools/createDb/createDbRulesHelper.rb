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
  class CreateDbRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'createDb'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)

        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        userId = wbJobEntity.context['userId']
        permission = testUserPermissions(wbJobEntity.outputs, 'o')
        unless(permission)
          rulesSatisfied = false
          wbJobEntity.context['wbErrorMsg'] = "NO PERMISSION: You need administrator level access to create databases."
        else
          # ------------------------------------------------------------------
          # CHECK SETTINGS
          # ------------------------------------------------------------------
          if(sectionsToSatisfy.include?(:settings))
            # Check :settings together with info from :outputs :
            unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
              raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
            end
            rulesSatisfied = false
            # Check 1: check if resource already exists
            dbName = CGI.escape(wbJobEntity.settings['dbName'])
            uri = URI.parse(wbJobEntity.outputs[0])
            host = uri.host
            rsrcUri = "#{uri.path}/db/#{dbName}?"
            apiCaller = WrapperApiCaller.new(host, rsrcUri, userId)
            # Making internal API call
            apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            if(apiCaller.succeeded?)
              wbJobEntity.context['wbErrorMsg'] = "The database: #{CGI.unescape(dbName).inspect} already exists. Please select another name for the new database. "
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
      else
        refPlatform = wbJobEntity.settings['refPlatform']
        if(refPlatform == 'userWillUpload')
          wbJobEntity.context['wbErrorMsg'] = "You are creating a database without a template assembly. You will have to upload reference sequence(s) before you can upload annotations to this database. "
        else
          warningMsg = ""
          version = wbJobEntity.settings['version']
          allTemplates = @dbu.getAllTemplates()
          allTemplates.each { |template|
            if(template['refseqName'] == refPlatform and version != template['refseq_version'])
              warningMsg = "You have changed the version of a template assembly. This might cause tools that rely on genome assemblies to fail. "
            end
          }
          if(!warningMsg.empty?)
            wbJobEntity.context['wbErrorMsg'] = warningMsg
          else
            warningsExist = false
          end
        end
      end
      @sampleSetApiHelper.clear() if(!@sampleSetApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
