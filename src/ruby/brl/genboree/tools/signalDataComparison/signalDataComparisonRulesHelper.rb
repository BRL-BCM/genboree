require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require "brl/db/dbrc"

module BRL ; module Genboree ; module Tools
  class SignalDataComparisonRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'signalDataComparison'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        outputs = wbJobEntity.outputs
        inputs = wbJobEntity.inputs
        
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        userId = wbJobEntity.context['userId']
        # ------------------------------------------------------------------
        # Check Inputs/Outpus
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:inputs) or sectionsToSatisfy.include?(:outputs))
          # Check :inputs & :outputs together:
          if( (sectionsToSatisfy.include?(:inputs) and !sectionsToSatisfy.include?(:outputs)) or
              (sectionsToSatisfy.include?(:outputs) and !sectionsToSatisfy.include?(:inputs)))
            raise ArgumentError, "Cannot validate just :inputs or just :outputs, only both together."
          else
            inputs = wbJobEntity.inputs
            outputs = wbJobEntity.outputs
          end

          # CHECK 1: Are there any duplicate tracks in inputs?
          if(@trkApiHelper.hasDups?(wbJobEntity.inputs))
            # FAILED: has some dups.
            wbJobEntity.context['wbErrorMsg'] = "Some tracks are in the inputs multiple times."
          else # OK: no track dups
            # CHECK 2: track & databases are ALL version-compatible
            unless(checkDbVersions(inputs + outputs))
              # FAILED: No, some versions didn't match
              wbJobEntity.context['wbErrorName'] = 'Genome Incompatibility'
              wbJobEntity.context['wbErrorMsg'] =
              {
                :msg => 'Some tracks are from a different genome assembly version than other tracks, or from the output database.',
                :type => :versions,
                :info =>
                {
                  :inputs =>  @trkApiHelper.dbVersionsHash(inputs),
                  :outputs => @dbApiHelper.dbVersionsHash(outputs)
                }
              }
            else # OK: versions
              rulesSatisfied = true
            end
          end
        end

        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) )
            raise ArgumentError, "Cannot validate just :settings without info provided in :outputs."
          end
          
          rulesSatisfied = false
          # CHECK 1: is the output track name syntactically acceptable?
          # Get track name
          outTrackType = wbJobEntity.settings['lffType'].to_s.strip
          outTrackSubType = wbJobEntity.settings['lffSubType'].to_s.strip
          outTrkName = "#{outTrackType}:#{outTrackSubType}"
          # Make track uri
          outputDbUri = wbJobEntity.outputs.first
          outTrkUri = "#{@dbApiHelper.extractPureUri(outputDbUri)}/trk/#{CGI.escape(outTrkName)}"
          # Is output track acceptably named?
          unless(@trkApiHelper.nameValid?(outTrkUri))
            # FAILED: track name is not valid
            wbJobEntity.context['wbErrorName'] = 'Invalid Output Track Name'
            wbJobEntity.context['wbErrorMsg'] =
            {
              :msg => "The output track name is not valid. Track names cannot contain tabs, newlines or colons; nor can they begin or end with whitespace.",
              :type => :invalidName,
              :info => {
                :entityType => 'track',
                :name => outTrkName
              }
            }
          else # OK: name valid
            # CHECK 2: Does user have write access to output track (if it already exists)?
            unless(@trkApiHelper.accessibleByUser?(outTrkUri, userId, CAN_WRITE_CODES))
              # FAILED: doesn't have write access to output track
              wbJobEntity.context['wbErrorName'] = 'Track Write Access Denied'
              wbJobEntity.context['wbErrorMsg'] =
              {
                :msg => "You don't have permission to write to the output track (which already exists).",
                :type => :writeableTrks,
                :info => @trkApiHelper.accessibleTracksHash(wbJobEntity.outputs, userId, CAN_WRITE_CODES)
              }
            else
              # Check 4: If 2 inputs, we need to have some resolution: either fixed or custom
              inputs = wbJobEntity.inputs
              resolutionPresent = true
              if(inputs.size == 2)
                customRes = wbJobEntity.settings['customResolution']
                fixedRes = wbJobEntity.settings['fixedResolution']
                if(customRes !~ /^\d+$/ and fixedRes != "high" and fixedRes != "medium" and fixedRes != "low")
                  resolutionPresent = false
                end
              end
              if(!resolutionPresent)
                wbJobEntity.context['wbErrorMsg'] = "Invalid Input: No Resolution selected. Please select one of the fixed resolutions or enter an positive integer custom resolution. "
              else
                # Check 5: custom resolution cannot be larger than 20_000_000 or smaller than 0
                correctRes = true
                correctRes = false if(!customRes.nil? and !customRes.empty? and (customRes !~ /^\d+$/ or ( customRes =~ /^\d+$/ and (customRes.to_i > 20_000_000 or customRes.to_i <= 0))))
                if(!correctRes)
                  wbJobEntity.context['wbErrorMsg'] = "Invalid Input: Custom Resolution is either invalid or too large. Please select an integer resolution smaller or equal to 20_000_000 and larger than 0. "
                else
                  # Check 6: make sure folder with analysisName does not already exist
                  analysisName = CGI.escape(wbJobEntity.settings['analysisName'])
                  dbUri = @dbApiHelper.extractPureUri(outputDbUri)
                  uri = URI.parse(dbUri)
                  host = uri.host
                  rcscUri = uri.path.chomp("?")
                  genbConf = BRL::Genboree::GenboreeConfig.load()
                  apiDbrc = @superuserApiDbrc
                  rcscUri << "/file/Signal%20Comparison/#{analysisName}/summary.txt?"
                  apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
                  retVal = ""
                  # Making internal API call
                  apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
                  resp = apiCaller.get()
                  if(apiCaller.succeeded?) # Failed. Should not have existed
                    wbJobEntity.context['wbErrorMsg'] = "Invalid Input: A folder for the analysis name: #{analysisName.inspect} already exists for this database. Please select some other analysis name."
                  else
                    # X and Y axes tracks should not be the same
                    xAxisTrk = wbJobEntity.settings['xAxisTrk']
                    yAxisTrk = wbJobEntity.settings['yAxisTrk']
                    if(xAxisTrk == yAxisTrk)
                      wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The X-axis and Y-axis tracks cannot be the same."
                    else
                      # If ROI dragged, it cannot be a high density track
                      roiTrack = wbJobEntity.settings['roiTrack']
                      if(roiTrack and @trkApiHelper.isHdhv?(roiTrack, @hostAuthMap))
                        wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The Regions-of-Interest track cannot be a high density track. Please select another track."  
                      else
                        # The regions of interest track cannot be the same as the X or Y axis tracks
                        if(roiTrack and ((roiTrack == xAxisTrk) or (roiTrack == yAxisTrk)) )
                          wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The Regions-of-Interest track MUST be different than the X or the Y axes tracks."
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
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        outputDbUri = wbJobEntity.outputs.first
        outputDbName = @dbApiHelper.extractName(outputDbUri)
        # Get track name
        outTrackType = wbJobEntity.settings['lffType'].to_s.strip
        outTrackSubType = wbJobEntity.settings['lffSubType'].to_s.strip
        outTrkName = "#{outTrackType}:#{outTrackSubType}"
        # Make output track uri
        outputDbUri = wbJobEntity.outputs.first
        outTrkUri = "#{@dbApiHelper.extractPureUri(outputDbUri)}/trk/#{CGI.escape(outTrkName)}"
        # CHECK: Does a non-empty output track with the same name already exist in the destination database?
        uploadFile = wbJobEntity.settings['uploadFile'] ? true : false
        if(!@trkApiHelper.empty?(outTrkUri) and uploadFile)
          # WARNING: output track exists and is not empty
          wbJobEntity.context['wbErrorMsg'] = "The track '#{outTrkName}' already exists in the output database '#{outputDbName}'. The output of this job will be appended to existing data in the track."
        else # OK: either output track doesn't exist or is empty.
          # ALL OK
          warningsExist = false
        end
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

      return warningsExist
    end
  end
end ; end end # module BRL ; module Genboree ; module Tools
