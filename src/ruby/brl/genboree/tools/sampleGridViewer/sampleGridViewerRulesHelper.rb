require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class SampleGridViewerRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'sampleGridViewer'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        rulesSatisfied = false
        apiOK = true
        inputs = wbJobEntity.inputs
        attributes = {}
        errorMsg = ""
        # Get the list of attributes for the x and y axis
        inputs.each { |input|
          uri = URI.parse(input)
          host = uri.host
          rsrcPath = uri.path
          apiCaller = ApiCaller.new(host, "#{rsrcPath}/samples/attributes/names?", @hostAuthMap)
          # Making internal API call
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(!apiCaller.succeeded?)
            errorMsg = "INTERNAL_SERVER_ERROR: Failed to retrieve sample attribute map for database: #{@dbApiHelper.extractName(input)}."
            apiOK = false
            break
          else
            resp = JSON.parse(apiCaller.respBody)['data']
            resp.each { |attr|
              attributes[attr['text']] = nil
            }
          end
        }
        if(attributes.keys.size < 2)
          apiOK = false
          errorMsg = "INVALID_INPUTS: There should be at least 2 attributes to launch the grid viewer. "
        end
        unless(apiOK)
          wbJobEntity.context['wbErrorMsg'] = errorMsg
        else
          wbJobEntity.settings['attributes'] = attributes
          rulesSatisfied = true
        end
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end
          rulesSatisfied = false
          # Check 1: Both gbGridYAttr and gbGridXAttr must be selected
          gbGridXAttr = wbJobEntity.settings['gbGridXAttr']
          gbGridYAttr = wbJobEntity.settings['gbGridYAttr']
          if(gbGridXAttr.nil? or gbGridXAttr.empty? or gbGridYAttr.nil? or gbGridYAttr.empty?)
            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Both X axis attribute and Y axis attribute must be selected."
          else
            # Check 2: x axis attribute cannot be the same as the Y axis attribute
            if(gbGridXAttr == gbGridYAttr)
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The X axis attribute cannot be the same as the Y axis attribute. "
            else
              # Check 3: xLabel and yLabel cannot be empty
              xLabel = wbJobEntity.settings['xLabel']
              yLabel = wbJobEntity.settings['yLabel']
              if(xLabel.nil? or xLabel.empty? or yLabel.nil? or yLabel.empty?)
                wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: X axis or Y axis label cannot be empty."
              else
                # Check 4: xtype and ytype cannot be the same as each other
                # ARJ: This may not apply. It does for Roadmap-grids since the x & y are actually ids in Experiments & Samples tables
                #xtype = wbJobEntity.settings['xtype']
                #ytype = wbJobEntity.settings['ytype']
                #if(xtype == ytype)
                #  wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The X entity type cannot be the same as the Y entity type. "
                #else
                #  rulesSatisfied = true
                #end
                rulesSatisfied = true
              end
            end
          end
        end
      end

      # Clean up helpers, which cache many things
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
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
