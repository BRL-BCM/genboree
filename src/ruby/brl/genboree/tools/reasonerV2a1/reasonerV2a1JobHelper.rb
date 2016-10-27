require 'brl/genboree/tools/reasonerV2/reasonerV2JobHelper'

module BRL; module Genboree; module Tools
  class ReasonerV2a1JobHelper < ReasonerV2JobHelper
    # @see parent
    TOOL_ID = "reasonerV2a1"
    MODULE_VERSION = "2.1"

    # Override parse guidelines to extract guidelines and meta guidelines
    # @see ReasonerV2JobHelper for its separate meta rules parsing
    # @see ReasonerV2 README.txt for details
    def parseGuidelinesAndMeta(rulesDoc)
      guidelines = parseGuidelines_old(rulesDoc)
      metaRules = { :header => ["FinalCallMetaRule", "NumberOfAssertions", "UniqueAssertions", "Inference", "Explanation"], :data => {} }
      rowIdField = metaRules[:header].first

      # Get each meta rule sub document for which we will base subsequent selections
      rulesPropSelector = BRL::Genboree::KB::PropSelector.new(rulesDoc)
      metaRulesPath = "<>.MetaRules.[].MetaRule"
      metaRulesDocs = rulesPropSelector.getMultiObj(metaRulesPath)

      # For each column in the header (except the first, whose values are just an enumeration 
      #   1, 2, ...) define a prop selector to get the associated value from the meta rule
      # If multiple values result from a selector they are to be joined on "," as a delimiter
      # Selectors are relative to meta rule sub documents
      # If NumberOfAssertions is 0, we expect to have no unique assertions
      fieldSelectors = [
        "<>.NumberOfAssertions",
        "<>.UniqueAssertions.[].UniqueAssertion",
        "<>.Inference",
        "<>.Explanation"
      ]
      ii = 1
      metaRulesDocs.map{|metaRulesDoc|
        rulesPropSelector = BRL::Genboree::KB::PropSelector.new(metaRulesDoc)
        selectedValues = fieldSelectors.map{|xx| rulesPropSelector.getMultiPropValues(xx).join(",") rescue ""}
        datum = {}
        datum[rowIdField] = ii
        metaRules[:header][1..-1].each_index{|jj|
          kk = metaRules[:header][1..-1][jj]
          datum[kk] = selectedValues[jj]
        }
        ii += 1
        metaRules[:data][datum[rowIdField]] = datum
      }

      return guidelines, metaRules
    end
    alias :parseGuidelines :parseGuidelinesAndMeta

  end
end; end; end
