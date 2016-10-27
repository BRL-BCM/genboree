require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'uri'

module BRL ; module Genboree ; module Tools
  class NewickToTrackListJobHelper < WorkbenchJobHelper

    # Must be defined in subclass. DO NOT USE CLASS VARIABLES WITH INHERITANCE.
    # CAN USE "class level instance variables" HOWEVER. THERE IS ONLY ONE (1)
    # CLASS VARIABLE, EVEN IF INHERITED (i.e. not separate storage, shared storage...many bugs.)
    #@@commandName = 'wrapperSearchSignalSim.rb'

    TOOL_ID = 'newickToTrackList'



    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def createTrackList(dbUri,listName,listTracks,apiCaller)
      dbHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new
      apiCaller.setHost(dbHelper.extractHost(dbUri))
      rsrcPath = "#{dbHelper.extractPath(dbUri)}/trks/entityList/#{listName}"
      gbKey = dbHelper.extractGbKey(dbUri)
      rsrcPath << "?gbKey=#{gbKey}" if (gbKey)
      apiCaller.setRsrcPath(rsrcPath)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      payload = {"data" =>  listTracks}
      apiCaller.put(payload.to_json)
      result = {:success => apiCaller.succeeded?,:msg => apiCaller.respBody}
      return result
    end


    def runInProcess()
      newickFileInput = @workbenchJobObj.inputs.first
      apiCaller = WrapperApiCaller.new("","",@userId)
      result = BRL::Genboree::Graphics::NewickTrackListHelper.getTrackMapFile(newickFileInput,apiCaller)
      if(result[:success]) then
        @trackMapFile = result[:uri]
        result = BRL::Genboree::Graphics::NewickTrackListHelper.getTrackMapHash(@trackMapFile,apiCaller)
        # Check 8: Do all selected leaves have a mapping in the trackmap file?
        if(result[:success]) then
          nameMap = result[:trackMaps][:nameMap]
          uriMap = result[:trackMaps][:uriMap]
          result = BRL::Genboree::Graphics::NewickTrackListHelper.getNewickTree(newickFileInput,apiCaller,true) #only leaves
          if(result[:success]) then
            selectUrlList = []
            restUrlList = []
            treeLeaves = result[:leaves]
            treeLeaves.each {|leaf|
              
              if(@workbenchJobObj.settings["selectedLeaves"].member?(leaf))
                selectUrlList << {"url" => uriMap[nameMap[leaf]]}
              else
                restUrlList << {"url" => uriMap[nameMap[leaf]]}
              end
            }
            result = createTrackList(@workbenchJobObj.outputs.first,@workbenchJobObj.settings["selectListName"],selectUrlList,apiCaller)
            if(result[:success]) then
              result = createTrackList(@workbenchJobObj.outputs.first,@workbenchJobObj.settings["restListName"],restUrlList,apiCaller)
              @workbenchJobObj.context['response'] = "Tracklists created successfully!"
            end
          end
        end
      end
      if(!result[:success]) then
        @workbenchJobObj.context['wbErrorMsg'] = "Error creating trackLists\n#{result[:msg]}"
      end
      return result[:success]
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
