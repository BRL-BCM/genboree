require 'time'
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
  class JobSummaryRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'jobSummary'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      #rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      rulesSatisfied = true
      if(rulesSatisfied)
        # Make a map of tool titles and ids
        toolMap = {}
        GenboreeRESTRackup.tools.each { |toolInfo|
          toolConf = toolInfo[:conf].conf
          label = toolConf['ui']['label']
          toolType = toolConf['info']['toolType']
          altToolTypes = toolConf['info']['altToolTypes']
          includeToolInMap = false
          # include tools with a label and those that are not utility jobs
          if(label != '[NOT SET]')
            if(toolType !~ /utility/i)
              includeToolInMap = true
            else
              # some tools change dynamically from utility type to other types, include these tools as well
              unless(altToolTypes.empty?)
                includeToolInMap = true
              end
            end
          end
          toolMap[label] = toolInfo[:conf].toolIdStr if(includeToolInMap)
          #$stderr.puts "label: #{label.inspect}; toolInfo[:conf].toolIdStr: #{toolInfo[:conf].toolIdStr.inspect}"
        }
        wbJobEntity.settings['toolMap'] = toolMap
      end

      # ------------------------------------------------------------------
      # CHECK SETTINGS
      # ------------------------------------------------------------------

      if(sectionsToSatisfy.include?(:settings))
        rulesSatisfied = false
        # Check 1: At least one tool should be selected
        settings = wbJobEntity.settings
        tools = settings['tools']
        if(tools.nil? or tools.empty?)
          wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: You must select at least one tool to generate a Job Summary report."
          rulesSatisfied = false
        else
          # Check 2: Start Date cannot be bigger than End date
          startDate = settings['dateField_startDate']
          endDate = settings['dateField_endDate']
          dateSatisfied = true
          if(!startDate.nil? and !endDate.nil? and !startDate.empty? and !endDate.empty? and startDate != 'YYYY/MM/DD' and endDate != 'YYYY/MM/DD')
            dateSatisfied = false if(Time.parse(startDate).to_f > Time.parse(endDate).to_f)
          end
          unless(dateSatisfied)
            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Start Date cannot be after End Date."
          else
            rulesSatisfied = true
          end
        end
      end
      #$stderr.puts("rulesSatisfied: #{rulesSatisfied.inspect}")
      return rulesSatisfied
    end

    # It's a good idea to catch any potential errors now instead of relying on the job to do validation because,
    # the job may get queued and the user wouldn't be notified  for an unnecessarily long time that they have something minor wrong with their inputs.
    #
    # [+returns+] boolean
    def warningsExist?(wbJobEntity)
      warningsExist = true
      inputs = wbJobEntity.inputs
      outputs = wbJobEntity.outputs
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
