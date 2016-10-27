require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
load 'brl/genboree/graphics/newickTrackListHelper.rb'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class NewickToTrackListRulesHelper < WorkbenchRulesHelper
    TOOL_LABEL = 'Convert Newick Tree to Track Lists'
    TOOL_ID = 'newickToTrackList'
    TOOL_TYPE = 'Utility'
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      
      $stderr.debugPuts(__FILE__,__method__,"here",sectionsToSatisfy.inspect)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        outputs = wbJobEntity.outputs
        inputs = wbJobEntity.inputs
        userId = wbJobEntity.context['userId']
        # Check 1: Version matching
        unless(checkDbVersions(inputs + outputs, skipNonDbUris=true)) # Failed
          wbJobEntity.context['wbErrorMsg'] = "The database version of one or more inputs does not match the version of the target database."          
        else
          rulesSatisfied = true
            newickFileInput = wbJobEntity.inputs.first
            apiCaller = ApiCaller.new("", "", @hostAuthMap)
            result = BRL::Genboree::Graphics::NewickTrackListHelper.getTrackMapFile(newickFileInput,apiCaller)
            if(result[:success]) then
              trackMapFile = result[:uri]
              result = BRL::Genboree::Graphics::NewickTrackListHelper.getTrackMapHash(trackMapFile,apiCaller)
              if(result[:success]) then
                wbJobEntity.inputs << result[:trackMaps][:nameMap]
                wbJobEntity.inputs << result[:trackMaps][:uriMap]
                result = BRL::Genboree::Graphics::NewickTrackListHelper.getNewickTree(newickFileInput,apiCaller)
                if(result[:success]) then
                  wbJobEntity.inputs << result[:newick]
                end
              end
            end
            if(!result[:success])
              wbJobEntity.context['wbErrorMsg'] = result[:msg]
              rulesSatisfied = false
            end
        end
      end
      return rulesSatisfied
    end
  end
  
end ; end; end # module BRL ; module Genboree ; module Tools
