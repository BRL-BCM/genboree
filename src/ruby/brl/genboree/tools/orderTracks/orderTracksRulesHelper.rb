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
  class OrderTracksRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      inputs = wbJobEntity.inputs
      if(rulesSatisfied)
        userId = wbJobEntity.context['userId']
        # All databases must have a gbKey
        orderHash = {}
        trkHash = {}
        input = wbJobEntity.inputs[0]
        # Prep some settings for the UI
        if(rulesSatisfied)
          dbUri = @dbApiHelper.extractPureUri(input)
          dbUriObj = URI.parse(dbUri)
          apiCaller = WrapperApiCaller.new(dbUriObj.host, "#{dbUriObj.path}/trks/defaultOrder?", userId)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          trkHash = JSON.parse(apiCaller.respBody())['data']['hash']
          apiCaller.setRsrcPath("#{dbUriObj.path}/trks/order?")
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          resp = JSON.parse(apiCaller.respBody())['data']['hash']
          if(resp)
            resp.each_key { |key|
              trkHash[key] = resp[key] if(!resp[key].nil?) 
            }
            unorderedTrks = {}
            trkHash.each_key { |trk|
              if(trkHash[trk])
                orderHash[trkHash[trk]] = trk  
              else
                unorderedTrks[trk] = nil
              end
            }
            gridRecs = []
            idx = 0
            if(!unorderedTrks.empty?)
              sortedOrdTrks = unorderedTrks.keys.sort
              # Within, the unordered list, place the user tracks first
              apiCaller.setRsrcPath("#{dbUriObj.path}/trks?userTracksOnly=true")
              apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias)
              apiCaller.get()
              resp = JSON.parse(apiCaller.respBody)['data']
              usrTrks = {}
              resp.each { |trkObj|
                usrTrks[trkObj['text']] = nil  
              }
              sortedOrdTrks.each { |trk|
                if(usrTrks.key?(trk))
                  gridRecs << [idx+1, CGI.escape(trk)]
                  idx += 1
                end
              }
              # If there are additional tracks remaining in the unordered list, they are template tracks, add them next
              if(idx < unorderedTrks.keys.size)
                apiCaller.setRsrcPath("#{dbUriObj.path}/trks?templateTracksOnly=true")
                apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias)
                apiCaller.get()
                resp = JSON.parse(apiCaller.respBody)['data']
                tmplTrks = {}
                resp.each { |trkObj|
                  tmplTrks[trkObj['text']] = nil  
                }
                sortedOrdTrks.each { |trk|
                  if(tmplTrks.key?(trk))
                    gridRecs << [idx+1, CGI.escape(trk)]
                    idx += 1
                  end
                }
              end
            end
            sortedOrderHashKeys = orderHash.keys.sort
            cc = sortedOrderHashKeys[0]
            if(sortedOrderHashKeys[0] == 1 or idx == 0)
              sortedOrderHashKeys.each { |key|
                gridRecs << [idx+cc, CGI.escape(orderHash[key])]
                cc += 1
              }
            else
              if(sortedOrderHashKeys[0] > idx)
                subVal = (sortedOrderHashKeys[0] - idx) - 1
                sortedOrderHashKeys.each { |key|
                  gridRecs << [cc-subVal, CGI.escape(orderHash[key])]
                  cc += 1
                }
              else
                addVal = (idx - sortedOrderHashKeys[0]) + 1
                sortedOrderHashKeys.each { |key|
                  gridRecs << [cc+addVal, CGI.escape(orderHash[key])]
                  cc += 1
                }
              end
            end
            wbJobEntity.settings['gridRecs'] = gridRecs.to_json
            wbJobEntity.settings['showSetDefBtn'] = ( !testUserPermissions(wbJobEntity.inputs, 'o') ? false : true )
          else
            wbJobEntity.settings['noTrks'] = true 
          end
          # ------------------------------------------------------------------
          # CHECK SETTINGS
          # ------------------------------------------------------------------
          if(sectionsToSatisfy.include?(:settings))
            # Check :settings together with info from :outputs :
            unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
              raise ArgumentError, "Cannot validate" 
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
