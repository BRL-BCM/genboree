require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/classApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class DownloadTracksRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        # First, make an API call to see how man chrs there are in the database. If there are <=500, only then
        # will we present the user with the option of selecting multiple chromosomes
        uriObj = URI.parse(@dbApiHelper.extractPureUri(wbJobEntity.inputs[0]))
        apiCaller = ApiCaller.new(uriObj.host, "#{uriObj.path}/eps/count?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias)
        apiCaller.get()
        frefCount = apiCaller.parseRespBody['data']['count']
        if(frefCount.to_i <= 500)
          # Make an API call to get all the chromosomes for presenting in the settings dialog
          apiCaller.setRsrcPath(uriObj.path)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias)
          apiCaller.get()
          if(apiCaller.succeeded?)
            resp = apiCaller.parseRespBody['data']
            if(resp['entrypoints'])
              if(resp['entrypoints']['entrypoints'] and !resp['entrypoints']['entrypoints'].empty?)
                wbJobEntity.settings['entrypoints'] = resp['entrypoints']['entrypoints']
              else
                wbJobEntity.context['wbErrorMsg'] = "NO_ENTRYPOINTS: There are no entrypoints in this database."
              end
            else
              wbJobEntity.context['wbErrorMsg'] = "NO_ENTRYPOINTS: There are no entrypoints in this database."
            end
          else
            wbJobEntity.context['wbErrorMsg'] = "API ERROR: could not retreive chromosome list from database:\n#{apiCaller.parseRespBody}"
          end
        else
          wbJobEntity.settings['entrypoints'] = []
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
