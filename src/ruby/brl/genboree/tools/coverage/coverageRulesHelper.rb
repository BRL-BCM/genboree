require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'

module BRL ; module Genboree ; module Tools
  class CoverageRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'coverage'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        userId = wbJobEntity.context['userId']
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
            unless(@dbApiHelper.dbsVersionsMatch?(inputs + outputs))
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
              # CHECK 3: Do all input tracks have annotations?
              if(@trkApiHelper.anyEmpty?(inputs))
                # FAILED: has some empty tracks
                wbJobEntity.context['wbErrorName'] = 'Empty Inputs'
                wbJobEntity.context['wbErrorMsg'] =
                {
                  :msg => 'Some input tracks are empty and thus cannot be processed.',
                  :type => :emptyTrks,
                  :info => @trkApiHelper.trackEmptyHash(inputs)
                }
              else # OK: no empty tracks
                # CHECK 4: Ensure inputs[2], ROI track is not HDHV
                if(@trkApiHelper.isHdhv?(inputs[0], @hostAuthMap))
                  wbJobEntity.context['wbErrorName'] = 'Track Of Interest is a score-based track.'
                  wbJobEntity.context['wbErrorMsg'] = "The track selected for coverage computation is a score-based track but should be annotation-based track such as Gene:RefSeq. "
                else
                  rulesSatisfied = true
                end
              end
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
              rulesSatisfied = true
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
        unless(@trkApiHelper.empty?(outTrkUri))
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
