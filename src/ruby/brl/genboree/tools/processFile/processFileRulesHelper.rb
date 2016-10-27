require 'uri'
require 'brl/genboree/tools/workbenchRulesHelper'

module BRL ; module Genboree ; module Tools

  class ProcessFileRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        # If outputs are empty, then we need to check if user can write to inputs.
        # This is sufficient in this case since tool will process file in-place if no output Database is provided.
        if(wbJobEntity.outputs.empty?)
          retVal = testUserPermissions(wbJobEntity.inputs, 'w')
          unless(retVal)
            wbJobEntity.context['wbErrorMsg'] = "NO WRITE PERMISSION: You do not have permission to write to the output target. Please contact your user group administrator to arrange write-access if you should have access."
            rulesSatisfied = false
          end
        end
        if(rulesSatisfied)
          # ------------------------------------------------------------------
          # CHECK SETTINGS
          # ------------------------------------------------------------------
          if(sectionsToSatisfy.include?(:settings))
            unpack = wbJobEntity.settings['unpack']
            convToUnix = wbJobEntity.settings['convToUnix']
            if(!unpack and !convToUnix)
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: You must check at least one of the options to launch this tool. "
              rulesSatisfied = false
            else
              if(convToUnix and wbJobEntity.settings['fileOpts'] == 'createName')
                if(wbJobEntity.settings['fileName'].nil? or wbJobEntity.settings['fileName'].empty?)
                  wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The extension for the new file cannot be empty."
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
      warningsExist = true
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else # Look for warnings
        hasEntityList = false
        wbJobEntity.inputs.each {|input|
          if(input =~ /\/files\/entityList\//)
            hasEntityList = true
            break
          end
        }
        if(hasEntityList or wbJobEntity.inputs.size > 1)
          wbJobEntity.context['wbErrorMsg'] = "Since you are processing more than 1 file, make sure the input files do not contain files (if unpacking/extracting) with the same names. This will cause the files processed earlier to be overwritten by the files processed later if you are using a common target folder."
        else
          warningsExist = false
        end
      end
      return warningsExist
    end

  end
end; end; end
