require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/classApiUriHelper'
require 'brl/genboree/rest/apiCaller'

module BRL ; module Genboree ; module Tools
  class SignalSimilaritySearchRulesHelper < WorkbenchRulesHelper
    RESULTS_FILES_BASE = "signalSimilarity"

    TOOL_ID = 'signalSimilaritySearch'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

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
          end
          inputs = wbJobEntity.inputs
          outputs = wbJobEntity.outputs
          # CHECK 1: Are there any duplicate tracks in inputs?
          if(@trkApiHelper.hasDups?(wbJobEntity.inputs))
            # FAILED: has some dups.
            wbJobEntity.context['wbErrorMsg'] = "Some tracks are in the inputs multiple times."
          else # OK: no track dups
            # CHECK 2: track & databases are ALL version-compatible (empty version matches any non-empty in this call)
            unless(checkDbVersions(inputs + outputs))
              # FAILED: No, some versions didn't match
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
              userId = wbJobEntity.context['userId']
              # ALL OK
              # Replace any class URIs with track URIs
              inputs = wbJobEntity.inputs
              trkList = []
              dbrcFile = File.expand_path(ENV['DBRC_FILE'])
              genbConf = BRL::Genboree::GenboreeConfig.load()
              user = @superuserApiDbrc.user
              pass = @superuserApiDbrc.password
              roiTrack = nil
              scoreTracks = []
              nonHDTrk = 0
              hdTrks = 0
              classHasHDTrks = true
              numTrks = 0
              inputs.each { |input|
                if(input =~ BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP) # For tracks
                  trkList << input
                else # For class
                  className = @classApiHelper.extractName(input)
                  dbUri = @dbApiHelper.extractPureUri(input)
                  uri = dbUri.dup()
                  uri = URI.parse(uri)
                  rcscUri = uri.path.chomp("?")
                  rcscUri << "/trks?connect=false&class=#{CGI.escape(className)}&detailed=true"
                  apiCaller = ApiCaller.new(uri.host, rcscUri, @hostAuthMap)
                  apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
                  apiCaller.get()
                  resp = apiCaller.respBody()
                  retVal = JSON.parse(resp)
                  tracks = retVal['data']
                  tracks.each { |track|
                    trkList << "#{dbUri.chomp("?")}/trk/#{CGI.escape(track['name'])}?"
                  }
                end
              }
              if(trkList.size < 2)
                wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: You need a minimum of two tracks (query and target) to run this tool."
              else
                wbJobEntity.settings['trkList'] = trkList
                rulesSatisfied = true
              end
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
          inputs = wbJobEntity.inputs

          # CHECK 1: Does the analysis name already exist as a signalSimilarity/ sub-dir in output database?
          analysisName = wbJobEntity.settings['analysisName']
          outputDbUri = wbJobEntity.outputs.first
          escAnalysisName = analysisName.split(/\//).map{|xx| CGI.escape(xx) }.join('/')
          filesRoot = @fileApiHelper.filesDirForDb(wbJobEntity.outputs.first)
          analysisSubDir = "#{filesRoot}/#{RESULTS_FILES_BASE}/#{escAnalysisName}"
          if(File.exists?(analysisSubDir))
            # FAILED: experiment name exists
            wbJobEntity.context['wbErrorMsg'] =
            {
              :msg => "There is already a Signal Similarity Search analysis called '#{analysisName}' in the output database '#{@dbApiHelper.extractName(wbJobEntity.outputs.first)}'. Please pick a different name for your analysis.",
              :type => :analysisNameExists
            }
          else # OK: analysis name unique in database
            resolutionPresent = true
            haveRoiTrk = ( wbJobEntity.settings['roiTrack'] ? true : false )
            if(!haveRoiTrk)
              customRes = wbJobEntity.settings['customResolution']
              fixedRes = wbJobEntity.settings['fixedResolution']
              if(customRes !~ /^\d+$/ and fixedRes != "high" and fixedRes != "medium" and fixedRes != "low")
                resolutionPresent = false
              end
            end
            if(!resolutionPresent)
              wbJobEntity.context['wbErrorMsg'] = "Invalid Input: No Resolution selected. Please select one of the fixed resolutions or enter an integer custom resolution. "
            else
              # Custom resolution cannot be larger than 20_000_000 or smaller than 0
              correctRes = true
              correctRes = false if(!customRes.nil? and !customRes.empty? and (customRes !~ /^\d+$/ or ( customRes =~ /^\d+$/ and (customRes.to_i > 20_000_000 or customRes.to_i <= 0))))
              if(!correctRes)
                wbJobEntity.context['wbErrorMsg'] = "Invalid Input: Custom Resolution is either invalid or too large. Please select an integer resolution smaller or equal to 20_000_000 and larger than 0. "
              else
                # Make sure folder with analysisName does not already exist
                analysisName = CGI.escape(wbJobEntity.settings['analysisName'])
                dbUri = @dbApiHelper.extractPureUri(outputDbUri)
                uri = URI.parse(dbUri)
                host = uri.host
                rcscUri = uri.path.chomp("?")
                genbConf = BRL::Genboree::GenboreeConfig.load()
                apiDbrc = @superuserApiDbrc
                rcscUri << "/file/Signal%20Search/#{analysisName}/summary.txt?"
                apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
                retVal = ""
                # Making internal API call
                apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
                resp = apiCaller.get()
                if(apiCaller.succeeded?) # Failed. Should not have existed
                  wbJobEntity.context['wbErrorMsg'] = "Invalid Input: A folder for the analysis name: #{analysisName.inspect} already exists for this database. Please select some other analysis name."
                else
                  # The user has to select a query track
                  if(!wbJobEntity.settings['queryTrack'])
                    wbJobEntity.context['wbErrorMsg'] = "NO_QUERY: You must select a query track to launch this tool."
                  else
                    # ROI and Query cannot be same
                    roiAndQDiff = true
                    if(haveRoiTrk)
                      if(wbJobEntity.settings['roiTrack'] == wbJobEntity.settings['queryTrack'])
                        roiAndQDiff = false
                      end
                    end
                    unless(roiAndQDiff)
                      wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The Regions-of-Interest track and Query track cannot be same."                      
                    else
                      # ROI cannot be high density
                      if(haveRoiTrk and @trkApiHelper.isHdhv?(wbJobEntity.settings['roiTrack'], @hostAuthMap))
                        wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The Regions-of-Interest track cannot be a high density track. Please select another track."
                      else
                        scoreTracks = []
                        trkList = wbJobEntity.settings['trkList']
                        if(haveRoiTrk) # Remove ROI track from scoreTracks
                          roitrack = wbJobEntity.settings['roiTrack'].chomp('?')
                          trkList.each {|trkUri|
                            scoreTracks << trkUri if(trkUri.chomp('?') != roiTrack)  
                          }
                        else
                          trkList.each {|trkUri|
                            scoreTracks << trkUri 
                          }
                        end
                        wbJobEntity.settings['scoreTracks'] = scoreTracks
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
        warningsExist = false
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

      return warningsExist
    end
  end
end ; end end # module BRL ; module Genboree ; module Tools
