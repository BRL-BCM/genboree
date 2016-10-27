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
  class ViewHubRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'viewHub'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        @user = wbJobEntity.context['userLogin']
        @userId = wbJobEntity.context['userId']
        @dbu = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil, nil)
        @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @userId)
        inputs = wbJobEntity.inputs

        unlock = false
        dbHash = {}
        genomeHash = Hash.new { |hh, kk| hh[kk] = [] }

        #Check1. Hub should be public - unlocked with gbKey public
        # Checking via "unlockedGroupResources" 
        hubUri = inputs.first
        hubUriObj = URI.parse(hubUri)
        grpUri = @grpApiHelper.extractPureUri(hubUri)
        grpUriObj = URI.parse(grpUri)

        apiCaller = ApiCaller.new(grpUriObj.host, "#{grpUriObj.path}/unlockedResources?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        if(apiCaller.succeeded?)
          apiCaller.parseRespBody()
          apiCaller.apiDataObj.each{ |res|
            if(res['url'] == hubUri.chomp('?') and res['public'])
              unlock = true
              break
            end
          }
        else
          rulesSatisfied = false 
          unlock = false
          wbJobEntity.context['wbErrorMsg'] = "API call failed get request at the hubresource. Check: #{apiCaller.respBody.inspect}"
        end
        unless(unlock)
          #Check for the user role
          #Check2. If not check user Role - if administrator, unlock it, else reject
          apiCaller = ApiCaller.new(grpUriObj.host, "#{grpUriObj.path}/usr/#{@user}/role?connect=no", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?)
            resp = apiCaller.parseRespBody["data"]
            if(resp["role"] != "administrator")
              rulesSatisfied = false
              wbJobEntity.context['wbErrorMsg'] = "FORBIDDEN: No permissions to unlock the hub resource.Check: #{apiCaller.respBody.inspect}"
            end
          else
            rulesSatisfied = false
            wbJobEntity.context['wbErrorMsg'] = "API call failed to get the user roles. Check: #{apiCaller.respBody.inspect}"
          end
        end
          # Prep some settings for the UI - get the genomes
        if(rulesSatisfied)
          apiCaller = ApiCaller.new(hubUriObj.host, "#{hubUriObj.path}/genomes?", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?)
            resp = apiCaller.parseRespBody["data"]
            resp.each{ |genHash|
             genomeHash[hubUri.chomp('?')] << genHash["genome"]
            }
          else
            rulesSatisfied = false
            wbJobEntity.context['wbErrorMsg'] = "API call failed to get the genomes list from the hubresource. Check: #{apiCaller.respBody.inspect}"
          end

          wbJobEntity.settings['genomeHash'] = genomeHash
          wbJobEntity.settings['hubUnlock'] = unlock
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "SETTINGS: #{wbJobEntity.settings.inspect}")
          # ------------------------------------------------------------------
          # CHECK SETTINGS
          # ------------------------------------------------------------------
          if(sectionsToSatisfy.include?(:settings))
            # Check :settings together with info from :outputs :
            unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
              raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
            end
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "SETTINGS: #{wbJobEntity.settings.inspect}")
            rulesSatisfied = false
            # At least one track must be checked
            settings = wbJobEntity.settings
            baseWidget = settings['baseWidget']
            genomeChecked = false
            settings.each_key { |key|
              if(key =~ /^#{baseWidget}/)
                if(settings[key] and settings[key] == 'on')
                  genomeChecked = true
                  break
                end
              end
            }
            unless(genomeChecked)
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: You must select at least one hubGenome to visualize."
            else
              rulesSatisfied = true
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
      warningsExist = true
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else # No Warnings
        warningsExist = false
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      @grpApiHelper.clear() if(!@grpApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
