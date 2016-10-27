require 'brl/util/util'
require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class RandomForestEntityListRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        errorMsg = ""
        versionsMatch = true
        dbVer = nil
        roiPresent = false
        roiFromUser = nil
        # Loop over all dbs check if all them have the same genome version
        inputs.each { |input|
          dbUri = @dbApiHelper.extractPureUri(input)
          if(@trkApiHelper.extractName(input))
            roiPresent = true
            roiFromUser = input
          end
          if(dbVer.nil?)
            dbVer = @dbApiHelper.dbVersion(dbUri, @hostAuthMap)
          else
            if(@dbApiHelper.dbVersion(dbUri, @hostAuthMap) != dbVer)
              errorMsg = "INVALID_INPUTS: All inputs must come from the same genome assembly."
              versionsMatch = false
              break
            end
          end
        }
        outputs.each { |output|
          if(@dbApiHelper.extractName(output))
            if(@dbApiHelper.dbVersion(output, @hostAuthMap) != dbVer)
              errorMsg = "INVALID_INPUTS: All inputs/outputs must come from the same genome assembly."
              versionsMatch = false
            end
          end
        }
        if(!versionsMatch)
          wbJobEntity.context['wbErrorMsg'] = errorMsg
          rulesSatisfied = false
        else
          # Get the list of ROI tracks if no ROI track dragged
          roiList = []
          unless(roiPresent)
            roiRepo = "#{@genbConf.roiRepositoryGrp}#{dbVer}"
            uriObj = URI.parse(roiRepo)
            apiCaller = ApiCaller.new(uriObj.host, "#{uriObj.path}/trks/attributes/map", @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            if(apiCaller.succeeded?)
              resp = apiCaller.parseRespBody['data']
              resp.each_key { |trk|
                attrMap = resp[trk]
                if(attrMap.key?('gbROITrack') and attrMap['gbROITrack'] == 'true')
                  roiList << trk
                end
              }
            else
              # No such db exists. Cannot present user with roi list. Only fixed windows
            end
          else
            # Make sure that the ROI dragged by the user is not a hdhv track
            if(@trkApiHelper.isHdhv?(roiFromUser, @hostAuthMap))
              rulesSatisfied = false
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The ROI Track cannot be a High Density Score Track. Please consult the Genboree team."
            end
          end
          wbJobEntity.settings['roiPresent'] = roiPresent
          wbJobEntity.settings['roiList'] = roiList
          wbJobEntity.settings['dbVer'] = dbVer
        end
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
            # Cutoff and Min Value Count should be integers
            cutoff = String.new(wbJobEntity.settings['cutoff'].strip)
            minValueCount = String.new(wbJobEntity.settings['minValueCount'].strip)
            if(!cutoff.valid?(:int) or !minValueCount.valid?(:int))
              rulesSatisfied = false
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Cutoff and Min Value Count need to be integer values."
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
      inputs = wbJobEntity.inputs
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
