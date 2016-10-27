require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class TrkCombineRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        unless(checkDbVersions(inputs + outputs, skipNonDbUris=true))
          # FAILED: No, some versions didn't match
          wbJobEntity.context['wbErrorMsg'] =
          {
            :msg => 'Some tracks are from a different genome assembly version than other tracks, or from the output database.',
            :type => :versions,
            :info =>
            {
              :inputs =>  @trkApiHelper.dbVersionsHash(inputs),
              :outputs => @dbApiHelper.dbVersionsHash(outputs)
            }
          }
          rulesSatisfied = false
        else
          # Get the number of annotations for all the track
          annosCount = 0
          inputs.each { |input|
            trkUriObj = URI.parse(input)
            apiCaller = ApiCaller.new(trkUriObj.host, "#{trkUriObj.path}/annos/count?", @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias)
            apiCaller.get()
            annosCount += JSON.parse(apiCaller.respBody)['data']['count'].to_i
          }
          wbJobEntity.settings['annosCount'] = annosCount
        end
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings) and rulesSatisfied)
          settings = wbJobEntity.settings
          featureDistance = wbJobEntity.settings['featureDistance']
          if(!featureDistance.valid?(:int))
            rulesSatisfied = false
            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Feature distance must be an integer."
          else
            if(settings.key?('namePrefix'))
              namePrefix = settings['namePrefix'].strip
              if(namePrefix.empty?)
                wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Name Prefix cannot be left blank."
                rulesSatisfied = false
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
      warningsExist = true
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else # Look for warnings
        # Generate a warning if one of the tracks(s) is a high density track
        hdTrks = []
        wbJobEntity.inputs.each { |input|
          if(@trkApiHelper.isHdhv?(input, @hostAuthMap))
            hdTrks << input            
          end
        }
        if(!hdTrks.empty?)
          errorMsg = "The following tracks are high density tracks. We highly recommend not using these as part of your combine operation:"
          errorMsg << "<ul>"
          hdTrks.each { |trk|
            errorMsg << "<li>#{@trkApiHelper.extractName(trk)}</li>"
          }
          errorMsg << "</ul>  "
          wbJobEntity.context['wbErrorMsg'] = errorMsg
          wbJobEntity.context['wbErrorMsgHasHtml'] = true
          warningsExist = true
        else
          # Warn the user if the 'combined' track is present in the target db
          trkType = wbJobEntity.settings['lffType']
          trkSubType = wbJobEntity.settings['lffSubType']
          trkName = "#{trkType}:#{trkSubType}"
          targetDbUriObj = URI.parse(wbJobEntity.outputs[0])
          apiCaller = ApiCaller.new(targetDbUriObj.host, "#{targetDbUriObj.path}/trk/#{CGI.escape(trkName)}?", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?)
            warningsExist = true
            wbJobEntity.context['wbErrorMsg'] = "The track: #{trkName} is already present in the target database. Your operation will add more data to the same track."
          else
            warningsExist = false
          end
        end
      end
      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
