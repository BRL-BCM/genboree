require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class LimmaSignalComparisonRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'limmaSignalComparison'


    def customToolChecks(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      inputs = wbJobEntity.inputs
      outputs = wbJobEntity.outputs
      unless(checkDbVersions(inputs + outputs, skipNonDbUris=true)) # Failed
        wbJobEntity.context['wbErrorMsg'] = "Database version of one or more input(s) does not match version of target database."
        rulesSatisfied = false
      end
      if(rulesSatisfied and sectionsToSatisfy.include?(:settings))
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        user = @superuserApiDbrc.user
        pass = @superuserApiDbrc.password
        rulesSatisfied = false
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        output = wbJobEntity.outputs[0]
        uri = URI.parse(output)
        host = uri.host
        rcscUri = uri.path
        rcscUri = rcscUri.chomp("?")
        analysisName = CGI.escape(wbJobEntity.settings['analysisName'])
        rcscUri << "/file/EpigenomeCompLimma/#{analysisName}/jobFile.json?"
        apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        if(apiCaller.succeeded?) # Failed: job dir already exists
          wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{analysisName.inspect} has already been launched before. Please select a different analysis name."
        else
          # Check 2: minPval must be a float b/w 0 and 1
          settings = wbJobEntity.settings
          minPval = settings['minPval']
          if(minPval.nil? or minPval.empty? or !minPval.to_s.valid?(:float) or minPval.to_f > 1 or minPval.to_f < 0)
            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Minimum P Value MUST be a floating point number between 0 and 1."
          else
            # Check 3: minAdjPval must be a float b/w 0 and 1
            minAdjPval = settings['minAdjPval']
            if(minAdjPval.nil? or minAdjPval.empty? or !minAdjPval.to_s.valid?(:float) or minAdjPval.to_f > 1 or minAdjPval.to_f < 0)
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Minimum Adjusted P Value MUST be a floating point number between 0 and 1."
            else
              # Check 4: minFoldChange must be float
              minFoldChange = settings['minFoldChange']
              if(minFoldChange.nil? or minFoldChange.empty? or !minFoldChange.to_s.valid?(:float) or minFoldChange.to_f < 0)
                wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Minimum Fold Change MUST be a positive floating or integer value."
              else
                ## Check 5: minAveExp must be float
                #minAveExp = settings['minAveExp']
                #if(minAveExp.nil? or minAveExp.empty? or !minAveExp.to_s.valid?(:float) or minAveExp.to_f < 0)
                #  wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Minimum Average Exp MUST be a positive floating or integer value."
                #else
                # Check 6: minBval must be a float
                # minBval = settings['minBval']
                # if(minBval.nil? or minBval.empty? or !minBval.to_s.valid?(:float))
                #   wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Minimum B Value MUST be a floating or integer value."
                # else
                # Check 7: multiplier must be an integer and > 0
                multiplier = settings['multiplier']
                if(multiplier.nil? or multiplier.empty? or !multiplier.to_s.valid?(:float) or multiplier.to_f < 0)
                  wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Multiplier value MUST be a positive number."
                else
                  # Check 8: If ROI track is Hdhv?
                  roiTrack = nil
                  inputs.each {|input| if(input =~ BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP) then
                    roiTrack = input
                  end
                }
                if(roiTrack.nil?) then
                  wbJobEntity.context['wbErrorMsg'] = "Invalid Input: No ROI Track provided."
                else
                  if(@trkApiHelper.isHdhv?(roiTrack, @hostAuthMap))
                    wbJobEntity.context['wbErrorMsg'] = "Invalid Input: ROI Track is a high density track. "
                  else
                    naPercentage = settings['naPercentage']
                    if(settings['naGroup'] == "custom" and (naPercentage.nil? or naPercentage.empty? or !naPercentage.to_s.valid?(:float) or naPercentage.to_f < 0)) then
                      wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Percentage value MUST be a positive number"
                    else
                      replaceNAValue = settings['replaceNAValue']
                      if(replaceNAValue.nil? or replaceNAValue.empty? or !replaceNAValue.to_s.valid?(:float))
                        wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: No Data Value MUST be a number."
                      else
                        uploadTrack = settings['uploadTrack']
                        trackType = settings['lffType']
                        trackSubType = settings['lffSubType']
                        trackClass = settings['trackClass']
                        if(uploadTrack and ((trackType.nil? or trackType.empty?) or (trackSubType.nil? or trackSubType.empty?) or (trackClass.nil? or trackClass.empty?))) then
                          wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: To upload results as a track, the type, subtype and class of the result track must be specified. One or more of these values is missing."
                        else
                          rulesSatisfied = true
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
    return rulesSatisfied
  end
end
end ; end; end # module BRL ; module Genboree ; module Tools
