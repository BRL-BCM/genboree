require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/classApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class SetUrlDescRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      inputs = wbJobEntity.inputs
      # The user should have write access to all inputs
      if(rulesSatisfied)
        userId = wbJobEntity.context['userId']
        if(!@dbApiHelper.allAccessibleByUser?(inputs, userId, CAN_WRITE_CODES))
          # FAILED: doesn't have write access to source database
          wbJobEntity.context['wbErrorMsg'] =
          {
            :msg => "Access Denied: You don't have permission to write to all the source databases.",
            :type => :writeableDbs,
            :info => @dbApiHelper.accessibleDatabasesHash(inputs, userId, CAN_WRITE_CODES)
          }
        else
          # Check that all tracks are coming from the same database
          trkHash = {}
          previousDb = nil
          allDbsSame = true
          inputs.each { |input|
            if(!previousDb.nil?)
              if(@dbApiHelper.extractPureUri(input) != previousDb)
                allDbsSame = false
                break
              end
            end
            previousDb = @dbApiHelper.extractPureUri(input)
          }
          unless(allDbsSame)
            wbJobEntity.context['wbErrorMsg'] = "All input tracks MUST come from the same database. "
            rulesSatisfied = false
          end
          if(rulesSatisfied)
            # Get the url, desc and labels for all tracks
            targetDbUriObj = URI.parse(previousDb)
            apiCaller = ApiCaller.new(targetDbUriObj.host, "#{targetDbUriObj.path}/trks/urlDescLabel?", @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            resp = JSON.parse(apiCaller.respBody)['data']['hash']
            inputs.each { |input|
              if(@trkApiHelper.extractName(input)) # For tracks
                trkName = @trkApiHelper.extractName(input)
                trkHash[trkName] = resp[trkName]
              elsif(classApiHelper.extractName(input)) # For class
                className = classApiHelper.extractName(input)
                dbUri = dbApiHelper.extractPureUri(input)
                uri = dbUri.dup()
                uri = URI.parse(uri)
                rcscUri = uri.path.chomp("?")
                rcscUri << "/trks?connect=false&class=#{CGI.escape(className)}"
                # Get all tracks for this class
                apiCaller = WrapperApiCaller.new(uri.host, rcscUri, userId)
                apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
                apiCaller.get()
                retVal = JSON.parse(apiCaller.respBody())
                tracks = retVal['data']
                #$stderr.puts "tracks: #{tracks.inspect}"
                tracks.each { |track|
                  trkName = track['text']
                  trkHash[trkName] = resp[trkName]
                }
              else # For dbs
                trkHash = resp
              end
            }
            if(trkHash.empty?)
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: There are no tracks in your selected list of inputs."
              rulesSatisfied = false
            else
              wbJobEntity.settings['trkHash'] = trkHash
            end
          end
        end
        if(sectionsToSatisfy.include?(:settings))
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
      else # No Warnings
        warningsExist = false
      end
      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
