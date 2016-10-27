require 'uri'
require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'brl/genboree/rest/helpers/trackEntityListApiUriHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'

include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class DeleteHostAccessRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'deleteHostAccess'

    include BRL::Cache::Helpers::DNSCacheHelper

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        # Get the host to remove from target
        inputs = wbJobEntity.inputs
        uri = URI.parse(inputs.first)
        remoteHost = uri.host
        # The target FROM which we are removing access is this one.
        targetHost = @genbConf.machineName
        # Are they trying to remove access to THIS server (it's no remote...)
        if(self.class.canonicalAddressesMatch?(remoteHost, [ @genbConf.machineName, @genbConf.machineNameAlias ]))
          wbJobEntity.context['wbErrorMsg'] = "SAME SERVER: You cannot remove access to Genboree at #{remoteHost.inspect} because it's the same as this Genboree server (#{targetHost.inspect}) and thus not remote."
          rulesSatisfied = false
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
      inputs = wbJobEntity.inputs
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else # No warnings for now
        # Get the host to remove from target
        inputs = wbJobEntity.inputs
        uri = URI.parse(inputs.first)
        remoteHost = uri.host
        # The target FROM which we are removing access is this one.
        targetHost = @genbConf.machineName
        msg = "Your access info for #{remoteHost.inspect} will be removed from #{targetHost.inspect}. This means that #{targetHost.inspect} will not know how to access data and services at #{remoteHost.inspect} on your behalf."
        wbJobEntity.context['wbErrorMsg'] = msg
        wbJobEntity.context['wbErrorMsgHasHtml'] = true
      end
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
