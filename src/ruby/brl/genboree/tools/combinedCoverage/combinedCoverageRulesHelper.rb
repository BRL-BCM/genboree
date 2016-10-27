require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'

module BRL ; module Genboree ; module Tools
  class CombinedCoverageRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'combinedCoverage'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        # Check 1: does user have write permission to the db?
        userId = wbJobEntity.context['userId']

        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check 1: either all of the sampleTypes are n/a are none are n/a
          rulesSatisfied = false
          settings = wbJobEntity.settings
          sampleType = nil
          naOcc = 0
          sample = control = 0
          settings.each_key { |setting|
            next unless(setting =~ /^sampleType/)
            naOcc += 1 if(settings[setting] == 'na')
            sample += 1 if(settings[setting] == 'sample')
            control += 1 if(settings[setting] == 'control')
          }
          if(naOcc > 0 and naOcc < inputs.size) # Failed
            wbJobEntity.context['wbErrorMsg'] = "Input Error: Either all sample types should be n/a or none. "
          else
            # Check 2: if no of n/a occurances is 0, then there should be at least one of rach sample type
            if(naOcc == 0)
              if(sample == 0 or control == 0) # Failed
                wbJobEntity.context['wbErrorMsg'] = "Input Error: There should be at least one sample and one control. "
              else
                rulesSatisfied = true
              end
            else
              rulesSatisfied = true
            end
          end
        end
      end
      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

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
