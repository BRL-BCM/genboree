require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'uri'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class RenameTracksJobHelper < WorkbenchJobHelper

    TOOL_ID = 'renameTracks'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      trksToUpdate = @workbenchJobObj.settings['trksToUpdate']
      origTrkNames = @workbenchJobObj.settings['origTrkNames']
      updatedTrks = {}
      problemTrks = []
      nameMap = []
      refseqRec = @dbApiHelper.tableRow(@workbenchJobObj.inputs[0])
      dbUri = @dbApiHelper.extractPureUri(@workbenchJobObj.inputs[0])
      @dbu.setNewDataDb(refseqRec['databaseName'])
      trksToUpdate.each_key { |key|
        trk = trksToUpdate[key]
        fmethod = trk.split(':')[0]
        fsource = trk.split(':')[1]
        begin
          @dbu.updateFtypeById(key, fmethod, fsource)  
          updatedTrks[trk] = origTrkNames[key]
          nameMap << {'oldRefsUri' => "#{dbUri}/trk/#{CGI.escape(origTrkNames[key])}?", 'newName' => trksToUpdate[key]}
        rescue => err
          problemTrks << trk
        end
      }
      @workbenchJobObj.context['updatedTrks'] = updatedTrks
      @workbenchJobObj.context['problemTrks'] = problemTrks
      @workbenchJobObj.context['nameMap'] = nameMap
      return success
    end


  end
end ; end ; end # module BRL ; module Genboree ; module Tools
