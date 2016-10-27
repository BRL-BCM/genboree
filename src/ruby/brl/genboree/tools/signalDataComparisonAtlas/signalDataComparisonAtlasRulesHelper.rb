require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'

module BRL ; module Genboree ; module Tools
  class SignalDataComparisonAtlasRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'signalDataComparisonAtlas'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      userId = wbJobEntity.context['userId']
      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false

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
          inputDbVersion = @dbApiHelper.dbVersion(wbJobEntity.inputs.first, @hostAuthMap).downcase
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
              # Check 3: at least one atlas track MUST be selected
              atlasTracks = wbJobEntity.settings['epiAtlasScrTracks']
              if(atlasTracks.nil? or atlasTracks.empty?) # Failed
                wbJobEntity.context['wbErrorMsg'] = "No Atlas Score Track selected."
              else
                # Check 4: The first track MUST be a score track (true even if an ROI track has been dragged)
                inputs = wbJobEntity.inputs
                # All Correct
                # Check 4: If 1 input, we need to have some resolution: either fixed or custom
                inputs = wbJobEntity.inputs
                regionsPresent = true
                if(inputs.size == 1)
                  customRes = wbJobEntity.settings['customResolution']
                  fixedRes = wbJobEntity.settings['fixedResolution']
                  roiTrack = wbJobEntity.settings['roiTrack']
                  if(customRes !~ /^\d+$/ and fixedRes != "high" and fixedRes != "medium" and fixedRes != "low" and (roiTrack.nil? or roiTrack.empty?))
                    regionsPresent = false
                  end
                end
                if(!regionsPresent)
                  wbJobEntity.context['wbErrorMsg'] = "Invalid Input: No Window or Regions of Interest selected. Please select either a window size or one of Regions of Interest (ROI) tracks to run the tool.  "
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
                      # ROI track should not be high density
                      roiTrkOK = true
                      if(inputs.size == 2)
                        roiTrack = wbJobEntity.settings['roiTrack']
                        roiTrkOK = false if(@trkApiHelper.isHdhv?(roiTrack, @hostAuthMap))
                      end
                      unless(roiTrkOK)
                        wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The Regions-of-Interest track cannot be a high density track. Please select another track." 
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
        uploadFile = wbJobEntity.settings['uploadFile']
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
