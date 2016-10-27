require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class EpigenomicsHeatmapRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'epigenomicsHeatmap'


    def customToolChecks(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      dbrcFile = File.expand_path(ENV['DBRC_FILE'])
      user = @superuserApiDbrc.user
      pass = @superuserApiDbrc.password
      rulesSatisfied = false
      ##Checking db and proj irrespective of their order
      if(wbJobEntity.outputs[0] !~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
        output = wbJobEntity.outputs[1]
      else
        output = wbJobEntity.outputs[0]
      end
      numTracksOK = true
      roiTrack = nil
      entityListCount = 0
      wbJobEntity.inputs.each{ |input|
        if(input =~ /entityList/) then
          entityListCount += 1
          inputUri = URI.parse(input)
          apiCaller = ApiCaller.new(inputUri.host, inputUri.path, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          apiCaller.parseRespBody
          if(apiCaller.apiDataObj.length <=1 )
            wbJobEntity.context['wbErrorMsg'] = "At least 2 tracks should be present in each list for this tool"
            numTracksOK = false
          end
        else # ROI track is the only non entity list reosurce allowed for this tool
          roiTrack = input
        end
      }
      inputs = wbJobEntity.inputs
      outputs = wbJobEntity.outputs
      if(numTracksOK)
        unless(checkDbVersions(inputs + outputs, skipNonDbUris=true)) # Failed
          wbJobEntity.context['wbErrorMsg'] = "Database version of one or more input(s) does not match version of target database."
        else
          rulesSatisfied = true
        end
      end
      if(rulesSatisfied and sectionsToSatisfy.include?(:settings))
        rulesSatisfied = false
        uri = URI.parse(output)
        host = uri.host
        rcscUri = uri.path
        rcscUri = rcscUri.chomp("?")
        analysisName = CGI.escape(wbJobEntity.settings['analysisName'])
        rcscUri << "/file/EpigenomicExpHeatmap/#{analysisName}/jobFile.json?"
        apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        if(apiCaller.succeeded?) # Failed: job dir already exists
          wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{analysisName.inspect} has already been launched before. Please select a different analysis name."
        else
          # Check 2: Key Size must be a float b/w 0 and 1
          settings = wbJobEntity.settings
          if(settings["distfun"] == "passThrough" and entityListCount != 1) then
            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT. Dist function \"Leave data matrix unchanged\" (passThrough) is only valid for self-comparisons"
          else
            # Check 3: Is replaceNAValue a number (float), if provided?
            replaceNAValue = settings['replaceNAValue']
            if(replaceNAValue.nil? or replaceNAValue.empty? or !replaceNAValue.to_s.valid?(:float))
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: No Data Value MUST be a number."
            else
              # Check 4: If ROI track is Hdhv?
              wrongInput = false
              if(roiTrack)
                if(@trkApiHelper.isHdhv?(roiTrack, @hostAuthMap))
                  wbJobEntity.context['wbErrorMsg'] = "Invalid Input: ROI Track is a high density track. "
                else
                  rulesSatisfied = true
                end
              else
                rulesSatisfied = true
              end
            end
          end
        end
      end
      return rulesSatisfied
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
