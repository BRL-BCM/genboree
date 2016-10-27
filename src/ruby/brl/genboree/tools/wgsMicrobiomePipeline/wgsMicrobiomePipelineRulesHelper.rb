require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class WgsMicrobiomePipelineRulesHelper < WorkbenchRulesHelper
    REQUIRED_FIELDS = ['#name', '#FP-1_1', '#FP-1_2', '#HOST', '#GROUP', '#DB', '#FOLDER']
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          if(wbJobEntity.settings['functionalAnnotation'] and !wbJobEntity.settings['digitalNormalization'])
            rulesSatisfied = false
            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: You cannot run the Functional Annotation step without running the Digital Normalization step."
          else
            eValCutoffORFs = wbJobEntity.settings['eValCutoffORFs']
            if(eValCutoffORFs and ( !eValCutoffORFs.valid?(:float) or eValCutoffORFs.to_f < 0 or eValCutoffORFs.to_f > 1))
              rulesSatisfied = false
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: E-value cutoff for mapping ORFs must be a floating point number between 0 and 1."
            else
              eValCutoffUnassembledReads = wbJobEntity.settings['eValCutoffUnassembledReads']
              if(eValCutoffUnassembledReads and ( !eValCutoffUnassembledReads.valid?(:float) or eValCutoffUnassembledReads.to_f < 0 or eValCutoffUnassembledReads.to_f > 1))
                rulesSatisfied = false
                wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: E-value cutoff for mapping unassembled reads must be a floating point number between 0 and 1."
              else
                # Read the first non-empty line of the metadata file. It should be a header line and it should have ALL the required cols
                uriObj = URI.parse(wbJobEntity.inputs[0])
                apiCaller = ApiCaller.new(uriObj.host, "#{uriObj.path}/data?", @hostAuthMap)
                apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
                headerLine = ""
                headerFound = false
                apiCaller.get() { |chunk|
                  chunk.each_line { |line|
                    if(line =~ /\n$/)
                      headerFound = true
                      line.strip!
                      headerLine << line
                      cols = headerLine.split(/\t/)
                      colHash = {}
                      cols.each { |col|
                        if(!colHash.key?(col))
                          colHash[col] = true  
                        else
                          rulesSatisfied = false
                          wbJobEntity.context['wbErrorMsg'] = "INVALID_METADATA_FILE: The field: #{col.inspect} is present more than once in the header line. "
                          break
                        end
                      }
                      REQUIRED_FIELDS.each { |field|
                        if(!colHash.key?(field))
                          rulesSatisfied = false
                          wbJobEntity.context['wbErrorMsg'] = "INVALID_METADATA_FILE: One or more of the required field headers (#{REQUIRED_FIELDS.join(",")}) is missing in the metdata file. "
                          break
                        end
                      }
                      break
                    else
                      headerLine = chunk
                    end
                  }
                  break if(headerFound)
                }
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
