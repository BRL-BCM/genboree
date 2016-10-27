require 'brl/genboree/tools/workbenchRulesHelper'

module BRL; module Genboree; module Tools
  class AlleleReg_v1RulesHelper < WorkbenchRulesHelper

    # @note SIDE-EFFECT: will set wbJobEntity.settings['alleleRegConfig'] to alleleRegConfig property from genboree.config.properties.
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>>START rulesSatisfied? <<<")
      retVal = false
      begin
        # Check basic rules from workbench.rules.json as normal
        rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
        # Other more specific checks
        if(rulesSatisfied)
          # ------------------------------------------------------------------
          # CHECK SETTINGS
          # ------------------------------------------------------------------
          if(sectionsToSatisfy.include?(:settings))
            # We will set the alleleRegConfig doc here, from the toolConf
            confDocUrl = wbJobEntity.settings['alleleRegConfig'] = @toolConf.getSetting('settings', 'alleleRegConfig')
            # Is the alleleRegConfig doc accessible? Should be public?
            if(confDocUrl and confDocUrl =~ /\S/)
              permission = testUserPermission(confDocUrl, 'r')
              if(permission)
                rulseSatisfied = true
              else # no permssion
                rulesSatisfied = false
              end # bad looking confDocUrl
            else # not a URL
              rulseSatisfied = false
            end
            # Everything ok?
            unless(rulseSatisfied)
              errMsg = "TOOL BUG: The tool is configured INCORRECTLY on this Genboree server. The alleleRegConfig property does not point to a publicly accessible Allele Registration configuration KB Doc that can be used to run the tool appropriately. Please contact your Genboree Administrators for help rectifying this BUG."
              wbJobEntity.context['wbErrorMsg'] = errMsg
              $stderr.debugPuts(__FILE__, __method__, "ERROR (CONFIG)", "#{errMsg} The alleleRegConfig tool conf setting is:\n\n    #{confDocUrl.inspect}\n\nAnd the testUserPermission() gave: #{permission.inspect rescue 'n/a'}")
            end
          end
          retVal = rulesSatisfied
        end
      rescue => err
        logAndPrepareError(err, wbJobEntity)
        retVal = false
      end
      return retVal
    end
  end
end ; end ; end
