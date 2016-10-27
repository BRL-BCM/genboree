require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class MicrobiomeResultUploaderRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'micriobiomeResultUploader'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        outputs = wbJobEntity.outputs
        userId = wbJobEntity.context['userId']
        # Get the values for 'mbwAnnotationType' and 'mbwMetricType' to display in the drop list in the UI
        resultUploaderUri = URI.parse(@genbConf.microbiomeResultUploaderDbUri)
        host = resultUploaderUri.host
        rsrcPath = resultUploaderUri.path
        apiCaller = ApiCaller.new(host, "#{rsrcPath}/trks/attributes/map?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody)['data']
        annoType = {}
        metricType = {}
        resp.each_key { |key|
          attrMap = resp[key]
          attrMap.each_key { |attr|
            if(attr == 'mbwAnnotationType')
              annoType[attrMap[attr]] = nil
            elsif(attr == 'mbwMetricType')
              metricType[attrMap[attr]] = nil
            else
              # Do nothing
            end
          }
        }
        wbJobEntity.settings['avpMap'] = resp # For quickly selecting the ROI track without making another API call (will be done on the job helper side)
        wbJobEntity.settings['annoTypeValues'] = annoType
        wbJobEntity.settings['metricTypeValues'] = metricType
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
           unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
             raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
           end
           rulesSatisfied = false
           # Check 1: The user has to select one of annoType and of of metricType
           annoType = wbJobEntity.settings['annoType']
           metricType = wbJobEntity.settings['metricType']
           $stderr.debugPuts(__FILE__, __method__, "DEBUG", "annoType: #{annoType.inspect}; metricType: #{metricType.inspect}")
           if( (annoType.nil? or annoType.empty?) or (metricType.nil? or metricType.empty?) )
             wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: You must select one value both for 'Annotation Type' and 'Metric Type'."
           else
             rulesSatisfied = true
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
      else # No warnings for now
        warningsExist = false
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
