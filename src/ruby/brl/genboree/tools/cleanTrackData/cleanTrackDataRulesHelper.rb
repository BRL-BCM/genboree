require 'uri'
require 'brl/genboree/tools/workbenchRulesHelper'

module BRL ; module Genboree ; module Tools
  class CleanTrackDataRulesHelper < WorkbenchRulesHelper

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      # @todo Check that the database mentioned in the outputs is a local database, not remote!

      # Nothing more to check. As long as user has write permission on database in the outputs
      # (which is checked by super()) we can run this clean up on their behalf. Probably following
      # an LFF upload or something.

      return rulesSatisfied
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
