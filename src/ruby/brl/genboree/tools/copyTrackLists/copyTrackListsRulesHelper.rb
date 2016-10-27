require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class CopyTrackListsRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'copyTrackLists'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      inputs = wbJobEntity.inputs
      outputs = wbJobEntity.outputs
      if(rulesSatisfied)
        rulesSatisfied = false
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        userId = wbJobEntity.context['userId']
        unless(checkDbVersions(inputs + outputs, skipNonDbUris=true)) # Failed
          wbJobEntity.context['wbErrorMsg'] = "Database version of one or more input track entity lists does not match output database."
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
                  :msg => "Access Denied: You don't have permission to write to all the source databases (Required for move).",
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
      inputs = wbJobEntity.inputs
      outputs = wbJobEntity.outputs
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else
        # Check if there are duplicates (track entity lists with the same base name)
        # Check if some of the input entity lists are already present in the target
        uri = URI.parse(outputs[0])
        host = uri.host
        rsrcPath = uri.path
        apiKey = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @genbConf.dbrcFile)
        @user = apiKey.user
        @password = apiKey.password
        userId = wbJobEntity.context['userId']
        dupList = {}
        warnings = false
        trkPresentList = []
        multiSelectInputList = wbJobEntity.settings['multiSelectInputList']
        multiSelectInputList.each { |inputUri|
          trkEntityList = @trackEntityListApiHelper.extractName(inputUri)
          if(dupList.has_key?(trkEntityList))
            dupList[trkEntityList] = dupList[trkEntityList] += 1
          else
            dupList[trkEntityList] = 1
          end
          apiCaller = WrapperApiCaller.new(host, "#{rsrcPath}/trks/entityList/#{CGI.escape(trkEntityList)}?", userId)
          $stderr.puts("rsrcPath: #{rsrcPath}/trks/entityList/#{CGI.escape(trkEntityList)}?")
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          resp = JSON.parse(apiCaller.respBody)['data']
          if(!resp.empty?)
            warnings = true
            trkPresentList.push(trkEntityList)
          end
        }
        if(warnings)
          errorMsg = "The following track entity list(s) are already present in the target database:"
          errorMsg << "<ul>"
          trkPresentList.each { |trk|
            errorMsg << "<li>#{trk}</li>"
          }
          errorMsg << "</ul>  "
          wbJobEntity.context['wbErrorMsg'] = errorMsg
          wbJobEntity.context['wbErrorMsgHasHtml'] = true
        else
          # Check 2: Do any of the input track entity lists have the same name?
          dupTracks = false
          dupList.each_key { |trk|
            if(dupList[trk] > 1)
              dupTracks = trk
              break
            end
          }
          if(dupTracks)
            warningMessage = "You are copying MULTIPLE track entity lists with the same base name: "
            warningMessage << "#{dupTracks}. "
            warningMessage << "This will end up combining all the data together in a single track entity list.
                              Are you sure you want to proceed?"
            wbJobEntity.context['wbErrorMsg'] = warningMessage
          else
            warningsExist = false
          end
        end
      end
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
