require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class SampleCentricLimmaRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'sampleCentricLimma'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        $stderr.puts "here #{Time.now} #{@hostAuthMap.inspect}"
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
          # Check 2: If only tracks have been dragged (no track entity lists), we MUST have at least 4 tracks (not including the ROI track)
          tracks = false
          trackCount = 0
          dbIndex = 0
          index = 0
          entityLists = false
          inputs.each { |input|
            if(@trkApiHelper.extractName(input))
              tracks = true
              trackCount += 1
            elsif(@trackEntityListApiHelper.extractName(input))
              entityLists = true
            else
              dbIndex = index
            end
            index += 1
          }
          if(!entityLists and trackCount < 5)
            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: A minimum of 5 tracks (including the ROI track as the last input) must be dragged for the tool to run. "
          else
            # Finally, make an API call to get all the sample attributes from the database dragged in inputs
            attributes = {}
            targetUri = URI.parse(inputs[dbIndex])
            host = targetUri.host
            rsrcPath = targetUri.path
            apiCaller = ApiCaller.new(host, "#{rsrcPath}/samples/attributes/map?", @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            if(apiCaller.succeeded?)
              resp = JSON.parse(apiCaller.respBody)['data']
       	      if(resp.respond_to?(:each_key))
                resp.each_key { |sample|
                avpHash = resp[sample]
                  avpHash.each_key { |key|
                    attributes[key] = nil
                  }
                }
              end
            end
            if(attributes.empty?)
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: Your database either has no samples or no valid sample metadata on which to run LIMMA."
            else
              wbJobEntity.settings['attributes'] = attributes.keys
              rulesSatisfied = true
            end
          end
        end
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end

          rulesSatisfied = false
          # Check 1: Does the job dir already exist?
          dbrcFile = File.expand_path(ENV['DBRC_FILE'])
          user = @superuserApiDbrc.user
          pass = @superuserApiDbrc.password
          output = nil
          outputs.each { |target|
            if(@dbApiHelper.extractName(target))
              output = target
            end
          }
          uri = URI.parse(output)
          host = uri.host
          rcscUri = uri.path
          rcscUri = rcscUri.chomp("?")
          analysisName = CGI.escape(wbJobEntity.settings['analysisName'])
          rcscUri << "/file/EpigenomeCompLIMMA/#{analysisName}/jobFile.json?"
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
                  #  # Check 6: minBval must be a float
                  #  minBval = settings['minBval']
                  #  if(minBval.nil? or minBval.empty? or !minBval.to_s.valid?(:float))
                  #    wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Minimum B Value MUST be a floating or integer value."
                  #  else
                      # Check 7: multiplier must be an integer and > 0
                      multiplier = settings['multiplier']
                      if(multiplier.nil? or multiplier.empty? or !multiplier.to_s.valid?(:float) or multiplier.to_f < 0)
                        wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Multiplier value MUST be a positive integer value."
                      else
                         naPercentage = settings['naPercentage']
                    if(settings['naGroup'] == "custom" and (naPercentage.nil? or naPercentage.empty? or !naPercentage.to_s.valid?(:float) or naPercentage.to_f < 0)) then
                      wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Percentage value MUST be a positive number"
                    else
                      replaceNAValue = settings['replaceNAValue']
                      if(replaceNAValue.nil? or replaceNAValue.empty? or !replaceNAValue.to_s.valid?(:float))
                        wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: No Data Value MUST be a number."
                      else
                        # Check 8: at least one of the sample attributes must be selected
                        attributesForLimma = wbJobEntity.settings['attributesForLimma']
                        if(attributesForLimma.nil? or attributesForLimma.empty?)
                          wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: You must select at least one of the sample attributes to launch the tool. "
                        else
                          # Check 9: ROI track must be set
                          roiTrack = wbJobEntity.settings['roiTrack']
                          if(roiTrack.nil? or roiTrack.empty?)
                            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: No Regions of Interest selected. "
                          else
                            # Check 10: ROI track must NOT be a hdhv track
                            if(@trkApiHelper.isHdhv?(roiTrack, @hostAuthMap))
                              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Regions of Interest (ROI) track cannot be a high density score track."
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
      end
      return rulesSatisfied
    end

    # It's a good idea to catch any potential errors now instead of relying on the job to do validation because,
    # the job may get queued and the user wouldn't be notified  for an unnecessarily long time that they have something minor wrong with their inputs.
    #
    # [+returns+] boolean
    def warningsExist?(wbJobEntity)
      warningsExist = true
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else # Look for warnings
        # no warnings for now
        warningsExist = false
      end

      # Clean up helpers, which cache many things
      @fileApiHelper.clear() if(!@fileApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
