require 'brl/util/util'
require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class RandomForestTrackRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        errorMsg = ""
        versionsMatch = true
        dbVer = nil
        dbHash = {}
        attributes = {}
        trkHash = {}
        # Loop over all dbs check if all them have the same genome version
        # Also construct a hash of attributes per db
        inputs.each { |input|
          dbUri = @dbApiHelper.extractPureUri(input)
          if(@trkApiHelper.extractName(input))
            trkHash[input] = true
            if(!dbHash.key?(dbUri))
              dbUriObj = URI.parse(dbUri)
              apiCaller = ApiCaller.new(dbUriObj.host, "#{dbUriObj.path}/trks/attributes/map?", @hostAuthMap)
              apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              apiCaller.get()
              resp = apiCaller.parseRespBody['data']
              dbHash[dbUri] = resp.dup()
            end
          else # Track entity list
            elUriObj = URI.parse(input)
            apiCaller = ApiCaller.new(elUriObj.host, elUriObj.path, @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias)
            apiCaller.get()
            resp = apiCaller.parseRespBody['data']
            resp.each { |urlHash|
              trkHash[urlHash['url']] = true
              elDburi = @dbApiHelper.extractPureUri(urlHash['url'])
              if(!dbHash.key?(elDburi))
                dbUriObj = URI.parse(elDburi)
                apiCaller = ApiCaller.new(dbUriObj.host, "#{dbUriObj.path}/trks/attributes/map?", @hostAuthMap)
                apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
                apiCaller.get()
                resp = apiCaller.parseRespBody['data']
                dbHash[elDburi] = resp.dup()
              end
            }
          end
          if(dbVer.nil?)
            dbVer = @dbApiHelper.dbVersion(dbUri, @hostAuthMap)
          else
            if(@dbApiHelper.dbVersion(dbUri, @hostAuthMap) != dbVer)
              errorMsg = "INVALID_INPUTS: All inputs must come from the same genome assembly."
              versionsMatch = false
              break
            end
          end
        }
        outputs.each { |output|
          if(@dbApiHelper.extractName(output))
            if(@dbApiHelper.dbVersion(output, @hostAuthMap) != dbVer)
              errorMsg = "INVALID_INPUTS: All inputs/outputs must come from the same genome assembly."
              versionsMatch = false
            end
          end
        }
        if(!versionsMatch)
          wbJobEntity.context['wbErrorMsg'] = errorMsg
          rulesSatisfied = false
        else
          # Get the list of ROI tracks. This will presented to the user always (if repo db for genome assembly of interest is found)
          roiList = []
          roiRepo = "#{@genbConf.roiRepositoryGrp}#{dbVer}"
          uriObj = URI.parse(roiRepo)
          apiCaller = ApiCaller.new(uriObj.host, "#{uriObj.path}/trks/attributes/map", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?)
            resp = apiCaller.parseRespBody['data']
            resp.each_key { |trk|
              attrMap = resp[trk]
              if(attrMap.key?('gbROITrack') and attrMap['gbROITrack'] == 'true')
                roiList << trk
              end
            }
          else
            # No such db exists. Cannot present user with roi list.
          end
          # Make a list of attributes for the input tracks
          #$stderr.puts("dbHash: #{dbHash.inspect}")
          trkHash.each_key { |trkUri|
            trkAttrMap = dbHash[@dbApiHelper.extractPureUri(trkUri)]
            if(!trkAttrMap.nil? and !trkAttrMap.empty?)
              if(trkAttrMap.key?(@trkApiHelper.extractName(trkUri)))
                attrs = trkAttrMap[@trkApiHelper.extractName(trkUri)].keys
                attrs.each { |attr|
                  attributes[attr] = true
                }
              end
            end
          }
          if(attributes.empty?)
            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: No Attributes found for selected tracks."
            rulesSatisfied = false
          else
            if(trkHash.keys.size < 2)
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: You need a minimum of 2 tracks to run this tool."
              rulesSatisfied = false
            else
              wbJobEntity.settings['userRoi'] = trkHash.keys
              wbJobEntity.settings['attributesList'] = attributes
              wbJobEntity.settings['roiList'] = roiList
              wbJobEntity.settings['dbVer'] = dbVer
              wbJobEntity.settings['trkHash'] = trkHash
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
          else
            # Cutoff and Min Value Count should be integers
            cutoff = String.new(wbJobEntity.settings['cutoff'].strip)
            minValueCount = String.new(wbJobEntity.settings['minValueCount'].strip)
            if(!cutoff.valid?(:int) or !minValueCount.valid?(:int))
              rulesSatisfied = false
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Cutoff and Min Value Count need to be integer values."
            else
              # At least one of the attributes selected must belong to a track other than the roi track
              attributes = wbJobEntity.settings['attributes']
              if(attributes.empty?)
                rulesSatisfied = false
                wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: No Attributes selected. Please select at least one attribute."
              else
                userRoiTrk = wbJobEntity.settings['userRoiTrk']
                attrSatisfied = false
                if(userRoiTrk and !userRoiTrk.empty?)
                  trkAttrMap = dbHash[@dbApiHelper.extractPureUri(userRoiTrk)]
                  if(trkAttrMap and !trkAttrMap.empty?)
                    attrMap = trkAttrMap[@trkApiHelper.extractName(userRoiTrk)]
                    if(attrMap and !attrMap.empty?)
                      attributes.each { |attribute|
                        if(!attrMap.key?(attribute))
                          attrSatisfied = true
                          break
                        end
                      }
                    else
                      attrSatisfied = true
                    end
                  else
                    attrSatisfied = true
                  end
                else
                  attrSatisfied = true
                end
                unless(attrSatisfied)
                  rulesSatisfied = false
                  wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: All of the selected attributes belong to the ROI track. Please select at least one attribute that does not belong to the ROI track."
                else
                  # Must select at least one roi trk or fixed resolution
                  if(!wbJobEntity.settings['repoRoiTrk'] and !wbJobEntity.settings['userRoiTrk'] and !wbJobEntity.settings['fixedResolution'])
                    rulesSatisfied = false
                    wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: You must select either a ROI track or a Fixed Resolution."
                  else
                    if(wbJobEntity.settings['userRoiTrk'])
                      if(@trkApiHelper.isHdhv?(wbJobEntity.settings['userRoiTrk'], @hostAuthMap))
                        rulesSatisfied = false
                        wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The ROI Track cannot be a High Density Score Track. Please consult the Genboree team."
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
      inputs = wbJobEntity.inputs
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else # No warnings for now
        warningsExist = false
      end
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
