require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class ArrayDataImporterRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'arrayDataImporter'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        outputs = wbJobEntity.outputs
        if(!canonicalAddressesMatch?(URI.parse(wbJobEntity.outputs[0]).host, [@genbConf.machineName, @genbConf.machineNameAlias]))
          wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: This tool cannot be used across multiple hosts."
        else
          # ------------------------------------------------------------------
          # Check Inputs/Outputs
          # ------------------------------------------------------------------
          # Check 1: does user have write permission to the db?
          userId = wbJobEntity.context['userId']
          # Check 1: Is this a database version we have 1+ known array definitions for?
          outputDbVer = @dbApiHelper.dbVersion(outputs[0])
          dbVer = outputDbVer.downcase
          # Make an API call to see if there are any 'gbArrayROITrack' tagged tracks in the reference ROI database
          arrayDataRepoDb = "#{@genbConf.arrayDataDbUri}#{dbVer}"
          dbUriObj = URI.parse(arrayDataRepoDb)
          apiCaller = WrapperApiCaller.new(dbUriObj.host, "#{dbUriObj.path}/trks/attributes/map?", userId)
          apiCaller.get()
          gotROI = false
          if(!apiCaller.succeeded?)
            # Try downcasing the dbver and try again
            arrayDataRepoDb = "#{@genbConf.arrayDataDbUri}#{dbVer.downcase}"
            dbUriObj = URI.parse(arrayDataRepoDb)
            apiCaller = WrapperApiCaller.new(dbUriObj.host, "#{dbUriObj.path}/trks/attributes/map?", userId)
            apiCaller.get()
            if(!apiCaller.succeeded?)
              # No-op
            else
              resp = apiCaller.parseRespBody['data']
              # If we come across 'gbArrayROITrack' = true, we are fine
              resp.each_key { |trkName|
                attrMap = resp[trkName]
                attrMap.each_key { |attrName|
                  if(attrName == 'gbArrayROITrack' and attrMap[attrName] == 'true')
                    gotROI = true
                    break
                  end
                }
              }
            end
          else
            resp = apiCaller.parseRespBody['data']
            # If we come across 'gbArrayROITrack' = true, we are fine
            resp.each_key { |trkName|
              attrMap = resp[trkName]
              attrMap.each_key { |attrName|
                if(attrName == 'gbArrayROITrack' and attrMap[attrName] == 'true')
                  gotROI = true
                  break
                end
              }
            }
          end
          unless(gotROI)
            # FAILED: we don't have an array repository database for that genome assembly
            wbJobEntity.context['wbErrorMsg'] =
            {
              :msg => "We don't have any known arrays defined for the '#{outputDbVer}' genome assembly. If you know of one or more arrays for this genome, and have the names and probe coordinates, please contact a <a href='mailto:genboree_admin@genboree.org'>Genboree Admin</a> with the information so they can help you add it to our array repository.",
              :type => :noDefinedArray,
              :info => { 'Your genome version:' => outputDbVer }
            }
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
           # Check 1: roiTrack must have a value
           roiTrack = wbJobEntity.settings['roiTrack']
           if(roiTrack.nil? or roiTrack.empty?)
              wbJobEntity.context['wbErrorMsg'] = "Incorrect Settings: You must select one of the ROI Tracks to launch the job."
           else
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
      else # No warnings for now
        warningsExist = false
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
