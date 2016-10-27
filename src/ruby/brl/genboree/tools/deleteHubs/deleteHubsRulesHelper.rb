require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/classApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class DeleteHubsRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      inputs = wbJobEntity.inputs
      # The user should have administrator access to all the hub groups to delete.
      if(rulesSatisfied)
        userId = wbJobEntity.context['userId']
        user = wbJobEntity.context['userLogin']
        dbu = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil, nil)
        hostAuthMap = Abstraction::User.getHostAuthMapForUserId(dbu, userId)

        # Check for user roles: has permission to delete?
        inputs.each{ |input|
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
        }

          if(sectionsToSatisfy.include?(:settings))
            # There should be at least one selected hub to delete
            hubSelected = false
            settings = wbJobEntity.settings
            baseWidget = settings['baseWidget']
            hubsToDel = []
            settings.each_key { |setting|
              if(setting =~ /^#{baseWidget}/ and settings[setting] == 'on')
                hubSelected = true
                hubsToDel << setting.gsub(/^#{baseWidget}\|/, '').gsub(/\|delete$/, '')
              end
            }
            unless(hubSelected)
              wbJobEntity.context['wbErrorMsg'] = "NO_HUBS_SELECTED: You must select at least one hub to delete."
              rulesSatisfied = false
            else
              wbJobEntity.settings['hubsToDel'] = hubsToDel
            end
          end
      end
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Settings: #{wbJobEntity.settings.inspect}")
      return rulesSatisfied
    end

    # It's a good idea to catch any potential errors now instead of relying on the job to do validation because,
    # the job may get queued and the user wouldn't be notified  for an unnecessarily long time that they have something minor wrong with their inputs.
    #
    # [+returns+] boolean
    def warningsExist?(wbJobEntity)
      warningsExist = true
      inputs = wbJobEntity.inputs
      hubToDelete = wbJobEntity.settings['hubsToDel'] 
      if(wbJobEntity.context['warningsConfirmed'])
        warningsExist = false
      else
        warningMsg = "The following hubs are going to be PERMANENTLY deleted with all of its contents:"
        hubToDelete.each { |uri|
          uriObj = URI.parse(uri)
          hub = File.basename(uriObj.path)
          warningMsg << "<ul>"
          warningMsg << "<li>#{CGI.unescape(hub)}</li>"
          warningMsg << "</ul>"
        }
        wbJobEntity.context['wbErrorMsg'] = warningMsg
        wbJobEntity.context['wbErrorMsgHasHtml'] = true
      end
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
