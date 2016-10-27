require 'uri'
require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class SetHostAccessRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'setHostAccess'

    include BRL::Cache::Helpers::DNSCacheHelper

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      # What is the target host at which we are registering host access?
      targetHost = wbJobEntity.outputs[0]
      if(targetHost.nil?)
       rulesSatisfied = false
      else # have some target host
        uri = URI.parse(targetHost)
        host = uri.host
        # Assert that the target is THIS genboree server (no proxied remote host management)
        if(rulesSatisfied)
          unless(self.class.canonicalAddressesMatch?(host, [ @genbConf.machineName, @genbConf.machineNameAlias ]))
            wbJobEntity.context['wbErrorMsg'] = "BAD TARGET: The target host at which you want to register remote host access must be THIS Genboree host (#{@genbConf.machineName.inspect}), not some remote Genboree."
            rulesSatisfied = false
          else # OK, target is THIS genboree server
            targetHost = @genbConf.machineName
            if(sectionsToSatisfy.include?(:settings))
              # Get the host to add remote access FOR
              remoteHost = wbJobEntity.settings['remoteHost']
              # Are they trying to add access to THIS server (it's not remote...)
              if(self.class.canonicalAddressesMatch?(remoteHost, [ @genbConf.machineName, @genbConf.machineNameAlias ]))
                wbJobEntity.context['wbErrorMsg'] = "SAME SERVER: You cannot add #{remoteHost.inspect} as a remote Genboree host because it's the same as this Genboree server (#{targetHost.inspect}) and thus not remote."
                rulesSatisfied = false
              else
                # Check that user/pass will work at remote host. If not, error.
                # - get remote creds
                remoteToken = wbJobEntity.settings['remoteToken']
                remoteLogin = wbJobEntity.settings['remoteLogin']
                # - create temp host auth map
                tmpHostAuthMap  = { self.class.canonicalAddress(remoteHost) => [ remoteLogin, remoteToken, :external ] }
                remoteLoginWorks = self.checkAccess(@userId, @toolConf, tmpHostAuthMap)
                if(remoteLoginWorks)
                  rulesSatisfied = true
                else
                  wbJobEntity.context['wbErrorMsg'] = "BAD CREDENTIALS: We did NOT save your access info for #{remoteHost.inspect} because either the host doesn't exist or the credentials do not work (we checked). Possibly you have a typo in the login or password?"
                  rulesSatisfied = false
                end
              end
            end
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
      warningsExist = false
      inputs = wbJobEntity.inputs
      unless(wbJobEntity.context['warningsConfirmed'])  # Skip the following if the user has confirmed the warnings and wants to proceed
        # Get the host to add remote access FOR
        remoteHost = wbJobEntity.settings['remoteHost']
        # The target TO which we are added a remote host is this one.
        targetHost = @genbConf.machineName
        # Are they trying to add access to THIS server (it's not remote...). If so, skip exists check and let rulesSatisfied?() take care of error.
        unless(self.class.canonicalAddressesMatch?(remoteHost, [ @genbConf.machineName, @genbConf.machineNameAlias ]))
          # Check if already have record for this host. If so, warn and ask for confirm.
          remoteHostAuthRec = Abstraction::User.getAuthRecForUserAtHost(remoteHost, @hostAuthMap, @genbConf)
          if(remoteHostAuthRec and !remoteHostAuthRec.nil?)
            msg = "You have existing access info saved for remote host #{remoteHost.inspect}. If you continue, that saved information will be replaced  with the new values you provided."
            wbJobEntity.context['wbErrorMsg'] = msg
            wbJobEntity.context['wbErrorMsgHasHtml'] = true
            warningsExist = true
          end
        end
      end
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
