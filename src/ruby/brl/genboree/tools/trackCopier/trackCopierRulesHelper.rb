require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/classApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class TrackCopierRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'trackCopier'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        rulesSatisfied = false
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        userId = wbJobEntity.context['userId']
        unless(checkDbVersions(inputs + outputs, skipNonDbUris=true)) # Failed
          wbJobEntity.context['wbErrorMsg'] = "Database version of one or more input track does not match output database."
        else
          rulesSatisfied = true
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
          # Check 2: If the user checked the 'Move Tracks' box the user must have write access to all the source dbs
          deleteTracks = wbJobEntity.settings['deleteSourceTracksRadio']
          haveAccess = true
          if(deleteTracks == 'move')
            inputs.each { |input|
              if(!@dbApiHelper.accessibleByUser?(@dbApiHelper.extractPureUri(input), userId, CAN_WRITE_CODES))
                # FAILED: doesn't have write access to source database
                wbJobEntity.context['wbErrorMsg'] =
                {
                  :msg => "Access Denied: You don't have permission to write to all the source databases.",
                  :type => :writeableDbs,
                  :info => @dbApiHelper.accessibleDatabasesHash(inputs, userId, CAN_WRITE_CODES)
                }
                haveAccess = false
                break
              end
            }
          end
          if(haveAccess)
            rulesSatisfied = true
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
        # CHECK 1: does the output db already have any of the input tracks
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        outputUri = URI.parse(wbJobEntity.outputs[0].chomp("?"))
        genbConf = BRL::Genboree::GenboreeConfig.load()
        warnings = false
        dbVers = []
        trkList = {}
        dupList = {}
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        @user = @superuserApiDbrc.user
        @pass = @superuserApiDbrc.password
        multiSelectInputList = wbJobEntity.settings['multiSelectInputList']
        multiSelectInputList.each { |inputUri|
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "uri => #{inputUri.inspect}")
          trkUri = ApiCaller.applyDomainAliases(inputUri)
          trkName = "#{@trkApiHelper.lffType(trkUri)}:#{@trkApiHelper.lffSubtype(trkUri)}"
          if(dupList.has_key?(trkName))
            dupList[trkName] = dupList[trkName] += 1
          else
            dupList[trkName] = 1
          end
          trkList[trkUri] = nil
        }
        trkPresentList = []
        trkList.each_key { |trk|
          track = "#{@trkApiHelper.lffType(trk)}:#{@trkApiHelper.lffSubtype(trk)}"
          checkUri = outputs[0].chomp("?")
          checkUri << "/trk/#{CGI.escape(track)}?"
          if(@trkApiHelper.exists?(checkUri, @hostAuthMap))
            warnings = true
            trkPresentList.push(CGI.escapeHTML(track))
          end
        }
        if(warnings)
          errorMsg = "The following tracks are already present in the target database:"
          errorMsg << "<ul>"
          trkPresentList.each { |trk|
            errorMsg << "<li>#{trk}</li>"
          }
          errorMsg << "</ul>  "
          wbJobEntity.context['wbErrorMsg'] = errorMsg
          wbJobEntity.context['wbErrorMsgHasHtml'] = true
        else
          # Check 2: Do any of the input tracks have the same name?
          dupTracks = false
          dupList.each_key { |trk|
            if(dupList[trk] > 1)
              dupTracks = trk
              break
            end
          }
          if(dupTracks)
            warningMessage = "You are copying MULTIPLE tracks that will have the name: "
            warningMessage << "#{dupTracks}. "
            warningMessage << "This will end up combining all the data together in a single track.
                              Unless deliberate, this is usually confusing and may not give you sensible results.
                              Are you sure you want to proceed?"
            wbJobEntity.context['wbErrorMsg'] = warningMessage
          else
            # if moving display a warning msg
            if(wbJobEntity.settings['deleteSourceTracksRadio'] == 'move')
              wbJobEntity.context['wbErrorMsg'] = "Moving track(s) involves permanently deleting them from the source database."             
            else  
              warningsExist = false
            end
          end
        end
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
