require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require "brl/genboree/helpers/sniffer"
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class MrfQuantifierRulesHelper < WorkbenchRulesHelper
    
    TOOL_ID = 'mrfQuantifier'
# INTERFACE METHOD. Avoid overriding if possible. It should be unnecessary, especially given
# customToolChecks().
#
# Before overriding, consider adding your extra checks GENERICALLY using
# the approach of customToolChecks(): an optional method whose default implementation returns
# true, but which some tools can implement for some specific type of ~common checking.
#
# NOTE NOTE: there is an analogous JAVASCRIPT version of this function in
# htdocs/javaScripts/workbench/rules.js called toolsSatisfiedInfo(). Fixes
# here and there should be kept in sync as appropriate when bugs or speedups are addressed.
#
# This default should always be called first thing (via super()) and the return value checked,
# even if overriding this method in a subclass because it will:
# (a) validate the sections against the simple rules file for the tool.
# (b) check user has write ability on all outputs
# (c) check user has read ability on all inputs
#
# When overriding, you first do retVal=super() so the code belove is checked. If the super()
# call succeeds, your then do your additional checks and validations.
#
# OVERRIDE REASON: We DON'T want the non-existent rules file checked, nor the user's permissions checked, etc.
#   The tool takes some custom inputs and outputs, so those permission things will crash anyway
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      return true
    end
  end
end; end; end
