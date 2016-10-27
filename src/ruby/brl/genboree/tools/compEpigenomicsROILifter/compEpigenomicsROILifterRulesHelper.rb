require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class CompEpigenomicsROILifterRulesHelper < WorkbenchRulesHelper
    TOOL_LABEL = :hidden
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        outputs = wbJobEntity.outputs
        inputs = wbJobEntity.inputs
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        # Check 1: does user have write permission to the first db?
        userId = wbJobEntity.context['userId']
        # Check 3: The db version of one of the outputs MUST match the db version of the input track
        inputDbVer = @dbApiHelper.dbVersion(inputs[0])
        # Get db versions for both targets
        targetVer = []
        outputs.each { |db|
          targetVer.push(@dbApiHelper.dbVersion(db))
        }
        match = false
        targetVer.each { |version|
          if(version == inputDbVer)
            match = true
            break
          end
        }
        # Failed
        if(!match)
          wbJobEntity.context['wbErrorMsg'] = "The database version of one the target databases MUST match the database version of the input track."
        else
          # Check 4: Both targets should not have the same db version
          if(targetVer[0] == targetVer[1]) # failed
            wbJobEntity.context['wbErrorMsg'] = "The database versions of both target databases cannot be the same."
          else
            rulesSatisfied = true
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
          genbConf = BRL::Genboree::GenboreeConfig.load()
          dbrcFile = File.expand_path(ENV['DBRC_FILE'])
          user = @superuserApiDbrc.user
          pass = @superuserApiDbrc.password
          rulesSatisfied = false
          # Check 1: The dir for job name should not exist in the targets
          jobDirExists = false
          studyName = CGI.escape(wbJobEntity.settings['studyName'])
          jobName = CGI.escape(wbJobEntity.settings['jobName'])
          parentDir = CGI.escape("Comparative Epigenomics")
          outputs.each { |output|
            uri = URI.parse(output)
            host = uri.host
            rcscUri = uri.path
            rcscUri = rcscUri.chomp("?")
            rcscUri << "/file/#{parentDir}/#{studyName}/ROI-Lifter/#{jobName}/jobFile.json?"
            apiCaller = ApiCaller.new(host, rcscUri, user, pass)
            apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            if(apiCaller.succeeded?) # Failed: job dir already exists
              wbJobEntity.context['wbErrorMsg'] = "A job with the job name: #{jobName} has already been launched before for the study: #{studyName} for the target database: #{@dbApiHelper.extractName(output)}. Please select a different job name."
              jobDirExists = true
              break
            end
          }
          if(!jobDirExists)
            # Check 2 : Are we overwriting the input resource ?
            overwritingInputRcsc = false
            outputs.each { |output|
              outputTrack = CGI.escape("#{wbJobEntity.settings['lffType']}:#{wbJobEntity.settings['lffSubType']}")
              if(inputs[0].chomp("?") == "#{output.chomp("?")}/trk/#{outputTrack}")
                overwritingInputRcsc = true
                break
              end
            }
            if(overwritingInputRcsc)
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: You cannot overwrite the input track. Please select another track name."
            else
              rulesSatisfied = true
            end
          end
        end
      end
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

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
        trackExists = false
        # Get track name
        outTrackType = wbJobEntity.settings['lffType'].to_s.strip
        outTrackSubType = wbJobEntity.settings['lffSubType'].to_s.strip
        outTrkName = "#{outTrackType}:#{outTrackSubType}"
        wbJobEntity.outputs.each { |outputDbUri|
          outputDbName = @dbApiHelper.extractName(outputDbUri)
          # Make output track uri
          outTrkUri = "#{@dbApiHelper.extractPureUri(outputDbUri)}/trk/#{CGI.escape(outTrkName)}"
          # CHECK: Does a non-empty output track with the same name already exist in the destination database?
          uploadFile = wbJobEntity.settings['uploadFile'] ? true : false
          if(!@trkApiHelper.empty?(outTrkUri) and uploadFile)
            # WARNING: output track exists and is not empty
            trackExists = true
          end
        }
        if(trackExists)
          wbJobEntity.context['wbErrorMsg'] = "The track: '#{outTrkName}' already exists in the output database(s). The output of this job will be appended to existing data in the track."
        else
          warningsExist = false
        end
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
