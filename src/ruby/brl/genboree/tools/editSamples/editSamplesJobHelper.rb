require 'json'
require 'uri'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class EditSamplesJobHelper < WorkbenchJobHelper

    TOOL_ID = 'editSamples'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      begin
        # get settings from the RulesHelper and workbenchDialog.rhtml
        settings = @workbenchJobObj.settings
        btnType = settings['btnType']
        userId = settings['userId']
        sampleEditHash = settings['sampleEditHash']
        sampleAttributeRemoveHash = settings['sampleAttributeRemoveHash']
        sampleRowUriMap = settings['sampleRowUriMap']
        sampleNameDataMap = settings['sampleNameDataMap']
        errorMsg = ''
        if(btnType == 'Save')
          # prepare a PUT on each unique database to minimize API calls
          uniqueDbHash = {}
          sampleEditHash.each_key{ |sampleNum|
            sampleUri = sampleRowUriMap[sampleNum]
            dbUri = @dbApiHelper.extractPureUri(sampleUri)
            uniqueDbHash[dbUri] = {'data' => []}
          }
          # construct a payload by unique database
          sampleEditHash.each_key{ |sampleNum|
            sampleUri = sampleRowUriMap[sampleNum]
            dbUri = @dbApiHelper.extractPureUri(sampleUri)
            sampleName = @sampleApiHelper.extractName(sampleUri).chomp('?')
            sampleData = sampleNameDataMap[sampleName] # modify original sampleData
            # update special sample fields if they were edited (these cannot be deleted)
            # they are also not part of the optional avpHash because they are required sample attributes, delete them
            sampleType = sampleEditHash[sampleNum].delete('type') # type is a Ruby object -- use different name
            biomaterialSource = sampleEditHash[sampleNum].delete('biomaterialSource')
            biomaterialState = sampleEditHash[sampleNum].delete('biomaterialState')
            biomaterialProvider = sampleEditHash[sampleNum].delete('biomaterialProvider')
            unless(sampleType.nil?)
              sampleData['type'] = sampleType
            end
            unless(biomaterialSource.nil?)
              sampleData['biomaterialSource'] = biomaterialSource
            end
            unless(biomaterialState.nil?)
              sampleData['biomaterialState'] = biomaterialState
            end
            unless(biomaterialProvider.nil?)
              sampleData['biomaterialProvider'] = biomaterialProvider
            end
            # update the avpHash
            sampleData['avpHash'].merge!(sampleEditHash[sampleNum])
            # remove the attributes whose values were edited to the delete string, except for these special
            # attributes which cannot be deleted 
            deleteType = sampleAttributeRemoveHash[sampleNum].delete('type')
            deleteBiomaterialSource = sampleAttributeRemoveHash[sampleNum].delete('biomaterialSource')
            deleteBiomaterialState = sampleAttributeRemoveHash[sampleNum].delete('biomaterialState')
            deleteBiomaterialProvider = sampleAttributeRemoveHash[sampleNum].delete('biomaterialProvider')
            if(deleteType)
              sampleData['type'] = ''
            end
            if(deleteBiomaterialSource)
              sampleData['biomaterialSource'] = ''
            end
            if(deleteBiomaterialState)
              sampleData['biomaterialState'] = ''
            end
            if(deleteBiomaterialProvider)
              sampleData['biomaterialProvider'] = ''
            end
            sampleAttributeRemoveHash[sampleNum].each{ |attribute|
              sampleData['avpHash'].delete(attribute)
            }
            # add to existing payload for db
            uniqueDbHash[dbUri]['data'] << sampleData
          }
          # perform the puts
          uniqueDbHash.each_key{ |dbUri|
            payload = JSON(uniqueDbHash[dbUri])
            dbUriObj = URI.parse(dbUri)
            dbApiCaller = ApiCaller.new(dbUriObj.host, "#{dbUriObj.path.chomp('?')}/samples?importBehavior=replace", @hostAuthMap)
            dbApiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            dbApiCaller.put(payload)
            unless(dbApiCaller.succeeded?)
              # put error processing mimicking get error processing below
              success = false
              errorMsg << "Edit samples job failed to update database #{(dbUriObj.host + dbUriObj.path).inspect} whose samples were edited in the grid.\n"
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", errorMsg)
              @workbenchJobObj.context['wbErrorMsg'] = errorMsg
            end
          }
        end
      rescue => err
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = "#{err.message}"
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
