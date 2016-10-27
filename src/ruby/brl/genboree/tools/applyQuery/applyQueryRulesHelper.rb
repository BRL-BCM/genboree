require 'uri'
require 'brl/genboree/tools/createQuery/createQueryRulesHelper'
require 'brl/genboree/tools/workbenchRulesHelper'

module BRL ; module Genboree ; module Tools

  class ApplyQueryRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'applyQuery'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        target = nil
        # First, determine which input is our target
        wbJobEntity.inputs.each{ |input|
          if(!BRL::REST::Resources::Query.pattern().match(URI.parse(input).path))
            target = input
          end
        }

        unless(target.nil?())
          if(CreateQueryRulesHelper.isQueryable?(URI.parse(target).path()))
            rulesSatisfied = true
          else
            # Either we could not find the resource for the provided template or our template is not queryable, err out
            rulesSatisfied = false

            # Set our error message
            wbJobEntity.context['wbErrorName'] = 'Nonqueryable Target'
            wbJobEntity.context['wbErrorMsg'] = 'The query target provided is not currently queryable. Please specify a different query target.'
          end
        else
          # We should always have a target (client rules should ensure this), but just in case
          rulesSatisfied = false
          wbJobEntity.context['wbErrorName'] = 'Target Missing'
          wbJobEntity.context['wbErrorMsg'] = 'No query target was found! Please specify a target to query against.'
        end
      end

      return rulesSatisfied
    end
  end
end; end; end
