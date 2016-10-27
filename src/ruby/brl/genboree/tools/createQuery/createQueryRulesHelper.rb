require 'uri'
require 'brl/genboree/tools/workbenchRulesHelper'

module BRL ; module Genboree ; module Tools

  class CreateQueryRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'createQuery'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        template = wbJobEntity.inputs[0]

        unless(template.nil?())
          # Template provided so we have to make sure its queryable, if no template, that is acceptable
          if(self.class.isQueryable?(URI.parse(template).path()))
            rulesSatisfied = true
          else
            # Either we could not find the resource for the provided template or our template is not queryable, err out
            rulesSatisfied = false

            # Set our error message
            wbJobEntity.context['wbErrorName'] = 'Incompatible Template'
            wbJobEntity.context['wbErrorMsg'] = 'The Template that was specified cannot be queried on. Please specify a different template to use.'
          end
        end
      end

      return rulesSatisfied
    end

    #############################################################################
    # This helper method takes an API URI (/REST/....) and will check to see if
    # the underlying resource is queryable. This takes a special action when
    # checking a Track resource, it will assume the user is intending to perfom
    # a query action against a TrackAnnos resource instead.
    #
    # NOTE: This method is made a static class so that the applyQueryRulesHelper
    # can call it also. The logic to check if either the template (create) or the
    # target (apply) is queryable is the same. So we use this static method to
    # improve code reuse (and keep the number of future changes to a minimum)
    #############################################################################
    def self.isQueryable?(rsrcUri)
      rsrc = nil
      priority = 0

      if(rsrcUri.match(BRL::REST::Resources::Track.pattern()))
        # Special case, we assume that if a user specified Track, they meant TrackAnnos
        rsrc = BRL::REST::Resources::TrackAnnos
      else
        # Now check all our resources to see if our template matches any
        BRL::REST::Resources.constants.each{ |constName|
          const = BRL::REST::Resources.const_get(constName.to_sym)
          if(const.pattern().match(rsrcUri))
            if(const.priority > priority)
              priority = const.priority
              rsrc = const
            end
          end
        }
      end

      return (!rsrc.nil?() && rsrc.queryable?())
    end
  end
end; end; end
