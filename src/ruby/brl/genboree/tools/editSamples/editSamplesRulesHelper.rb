require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'cgi'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class EditSamplesRulesHelper < WorkbenchRulesHelper
    # Prepare editable table in workbench dialog
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      userId = wbJobEntity.context['userId']
      inputs = wbJobEntity.inputs
      if(inputs.nil? or inputs.empty?)
        wbJobEntity.settings['noSamples'] = true
      end
      # flexible inputs with expandSampleContainers
      sampleUriArray = @sampleApiHelper.expandSampleContainers(inputs, userId)
      if(rulesSatisfied)
        # preprocess sample names and sample attributes
        dbSamplesMap = {}
        sampleNameDataMap = {}
        attributesHash = {}
        sampleUriArray.each{ |input|
          # scan each input for its db and do a GET on the db to minimize number of API calls
          dbUri = @dbApiHelper.extractPureUri(input)
          if(dbSamplesMap[dbUri].nil?)
            dbSamplesMap[dbUri] = []
          end
          dbSamplesMap[dbUri] << @sampleApiHelper.extractName(input)
        }
        # check permissions
        permission = testUserPermissions(dbSamplesMap.keys(), 'w')
        unless(permission)
          rulesSatisfied = false
          wbJobEntity.context['wbErrorMsg'] = "NO PERMISSION: You need write level access edit these samples."
        end
        # continue only if we have permission for all dbUris
        if(rulesSatisfied)
          dbSamplesMap.each_key{ |dbUri|
            # perform those gets
            dbUriObj = URI.parse(dbUri)
            apiCaller = WrapperApiCaller.new(dbUriObj.host, "#{dbUriObj.path}/samples?detailed=true", userId)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            if(apiCaller.succeeded?)
              dbSamplesArray = apiCaller.parseRespBody()['data']
              dbSamplesArray.each{ |sampleData|
                name = sampleData['name']
                # restrict samples retrieved from GET to those in the input
                next unless(dbSamplesMap[dbUri].index(name))
                # make name data map to construct table after rows and columns have been sorted
                sampleNameDataMap[name] = sampleData
                # make note of unique columns to sort them
                avpHash = sampleData['avpHash']
                avpHash.each_key { |attribute|
                  attributesHash[attribute] = true
                }
              }
              # add core sample attribute fields to attributesHash for sorting
              attributesHash['type'] = true
              attributesHash['biomaterialState'] = true
              attributesHash['biomaterialProvider'] = true
              attributesHash['biomaterialSource'] = true
            end
          }
          # sort columns alphabetically by attribute name (but name comes first)
          unsortedAttributeArray = attributesHash.keys()
          sortedAttributeArray = unsortedAttributeArray.sort(){ |aa, bb|
            cmp = (aa.downcase() <=> bb.downcase())
            if(cmp != 0)
              aa.downcase() <=> bb.downcase()
            else
              aa <=> bb
            end
          }
          # sort rows alphabetically by sampleName
          unsortedNamesArray = sampleNameDataMap.keys()
          sortedNamesArray = unsortedNamesArray.sort(){ |aa, bb|
            cmp = (aa.downcase() <=> bb.downcase())
            if(cmp != 0)
              aa.downcase() <=> bb.downcase()
            else
              aa <=> bb
            end
          }
          # construct gridFields Array for UI
          gridFields = []
          gridFields << 'name'
          sortedAttributeArray.each{ |attribute|
            gridFields << CGI.escape(attribute)
          }
          # construct gridRecs Array of Arrays for UI
          idx = 0
          gridRecs = []
          gridRowUriMap = []
          sortedNamesArray.each{ |sampleName|
            gridRec = []
            sampleData = sampleNameDataMap[sampleName]
            # make note of uri for sample to commit changes made in editable ui
            gridRowUriMap[idx] = sampleData['refs'][BRL::Genboree::REST::Data::BioSampleEntity::REFS_KEY]
            # extend usual avpHash to include special sample attributes
            avpHash = sampleData['avpHash'].dup()
            avpHash['type'] = sampleData['type']
            avpHash['biomaterialState'] = sampleData['biomaterialState']
            avpHash['biomaterialProvider'] = sampleData['biomaterialProvider']
            avpHash['biomaterialSource'] = sampleData['biomaterialSource']
            # use sorted attributes to construct gridRec
            gridRec << CGI.escape(sampleData['name']) # name is first attribute
            sortedAttributeArray.each{ |attribute|
              sampleValueForAttribute = (avpHash[attribute].nil? ? '' : avpHash[attribute])
              gridRec << CGI.escape(sampleValueForAttribute)
            }
            idx += 1
            gridRecs << gridRec
          }
          wbJobEntity.settings['gridFields'] = gridFields.to_json
          wbJobEntity.settings['gridRecs'] = gridRecs.to_json
          wbJobEntity.settings['gridRowUriMap'] = gridRowUriMap.to_json
          wbJobEntity.settings['sampleNameDataMap'] = sampleNameDataMap
        end
      end
      # ------------------------------------------------------------------
      # CHECK SETTINGS
      # ------------------------------------------------------------------
      if(sectionsToSatisfy.include?(:settings))
        # Check :settings together with info from :inputs :
        unless( sectionsToSatisfy.include?(:inputs) )
          raise ArgumentError, "Cannot validate"
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
      @sampleApiHelper.clear() if(!sampleApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
