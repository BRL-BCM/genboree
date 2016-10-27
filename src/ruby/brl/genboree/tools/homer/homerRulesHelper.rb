require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class HomerRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        # Check which output is the database
        dbUri = nil
        outputs.each { |output|
          if(@dbApiHelper.extractName(output))
            dbUri = output
            break
          end
        }
        unless(checkDbVersions(inputs + [dbUri], skipNonDbUris=true))
          # FAILED: No, some versions didn't match
          wbJobEntity.context['wbErrorMsg'] =
          {
            :msg => 'Some tracks are from a different genome assembly version than other tracks, or from the output database.',
            :type => :versions,
            :info =>
            {
              :inputs =>  @trkApiHelper.dbVersionsHash(inputs),
              :outputs => @dbApiHelper.dbVersionsHash([dbUri])
            }
          }
          rulesSatisfied = false
        else
          targetDbUriObj = URI.parse(dbUri)
          apiCaller = ApiCaller.new(targetDbUriObj.host, "#{targetDbUriObj.path}?", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          resp = JSON.parse(apiCaller.respBody)['data']
          genomeVersion = resp['version'].decapitalize
          wbJobEntity.settings['genomeVersion'] = genomeVersion
          # Make sure the genome version is supported by HOMER
          gbHomerGenomesInfo = JSON.parse(File.read(@genbConf.gbHomerGenomesInfo))
          if(!gbHomerGenomesInfo.key?(genomeVersion))
            rulesSatisfied = false
            wbJobEntity.context['wbErrorMsg'] = "INVALID_GENOME: The genome version: #{genomeVersion} is not currently supported by HOMER. Supported genomes include: #{gbHomerGenomesInfo.keys.join(",")}"
          end
        end
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings) and rulesSatisfied)
          
          
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
        # No warnings
        warningsExist = false
      end
      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
