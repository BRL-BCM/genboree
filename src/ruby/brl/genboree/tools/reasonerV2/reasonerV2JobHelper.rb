require 'brl/genboree/tools/reasoner/reasonerJobHelper'

module BRL; module Genboree; module Tools
  class ReasonerV2JobHelper < ReasonerJobHelper
    # @see parent
    TOOL_ID = "reasonerV2"
    MODULE_VERSION = "2.0"

    # override runInProcess
    # @todo would like to put @apiCaller setup in initialize but user authentication hasnt happened at that stage:
    #   it happens with executionCallback is called from the toolJob resource, which in turn executes this function
    def runInProcess()
      success = false
      @apiCaller = BRL::Genboree::REST::WrapperApiCaller.new("", "", @userId) 
      begin
        rulesDocUrl = @workbenchJobObj.settings["rulesDoc"]
        rulesDoc = getRulesDoc(rulesDocUrl, @apiCaller)

        # use first input of each type (if there are multiple inputs of the same type)
        type2Input = classifyInputs(@workbenchJobObj.inputs)
  
        # apply kb transform to kb doc 
        transformDoc = transformDocument(type2Input[:kbDoc], type2Input[:kbTransform], @apiCaller)
  
        # with the transform and rules docs, extract the data necessary for Reasoner
        # build guildlines tsv string
        # @todo reasoner2 needs evidence and meta from guidelines
        guidelines, metaRules = parseGuidelines(rulesDoc)
        guidelinesTsv = self.class.hashToCsv(guidelines, "\t")
        metaRulesTsv = self.class.hashToCsv(metaRules, "\t")
  
        evidence = parseEvidence(guidelines, transformDoc)
        evidenceCsv = formatEvidence(evidence)
  
        # run Reasoner
        # @todo what if module load part fails? pray
        guidelinesTsv.gsub!("\t", "\\t")
        guidelinesTsv.gsub!("\n", "\\n")
        metaRulesTsv.gsub!("\t", "\\t")
        metaRulesTsv.gsub!("\n", "\\n")
        cmd = @reasonerCmdPrefix + " \"#{guidelinesTsv}\" " + " \"#{metaRulesTsv}\" " + " \"#{evidenceCsv}\" "
        cmdStatus, stdout, stderr = BRL::Util::popen4Wrapper(cmd)

        if(cmdStatus.exitstatus == 0)
          reasonerHash = JSON.parse(stdout)
          reasonerKbDoc = BRL::Genboree::KB::KbDoc.new(reasonerHash)
          status = reasonerKbDoc.getPropVal("Reasoner output.Status")
          if(status == "ok")
            success = true
          elsif(status == "error")
            success = false
          else
            success = false
          end
          @workbenchJobObj.results = reasonerKbDoc
        else
          raise ReasonerJobError.new("Execution of #{CMD_NAME} failed. #{@adminMsg}", :"Internal Server Error")
        end
      rescue => err
        logAndPrepareError(err)
        success = false
      end
      return success
    end

    # Override parse guidelines to extract guidelines and meta guidelines
    # @param [Hash] rulesDoc @see parent
    # @return [Array] 2-tuple with
    #   [0] the guidelines @see parent
    #   [1] the metaRules 
    # @see ReasonerV2 README.txt for details
    alias :parseGuidelines_old :parseGuidelines unless(method_defined?(:parseGuidelines_old))
    def parseGuidelinesAndMeta(rulesDoc)
      guidelines = parseGuidelines_old(rulesDoc)
      metaRules = { :header => ["Matched", "Keyword"], :data => {} }
      metaRulesPath = "<>.MetaRules.[].MetaRule"
      metaKeywordsPath = "<>.MetaRules.[].MetaRule.KeyWord"
      rulesPropSelector = BRL::Genboree::KB::PropSelector.new(rulesDoc)
      metaRuleNames = rulesPropSelector.getMultiPropValues(metaRulesPath)
      metaRuleKeywords = rulesPropSelector.getMultiPropValues(metaKeywordsPath)
      raise ReasonerJobError.new("Each meta rule in the rules document does not have an associated keyword") if(metaRuleNames.size != metaRuleKeywords.size)
      metaRuleNames.each_index { |ii|
        metaRuleName = metaRuleNames[ii] 
        metaRuleKeyword = metaRuleKeywords[ii]
        datum = { "Matched" => metaRuleName, "Keyword" => metaRuleKeyword }
        metaRules[:data][datum["Matched"]] = datum
      }
      return guidelines, metaRules
    end
    alias :parseGuidelines :parseGuidelinesAndMeta

  end
end; end; end
