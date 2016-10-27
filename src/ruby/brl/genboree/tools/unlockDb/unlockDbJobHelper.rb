require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'uri'
require 'brl/genboree/abstract/resources/unlockedGroupResource'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class UnlockDbJobHelper < WorkbenchJobHelper

    TOOL_ID = 'unlockDb'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      gbKey = @workbenchJobObj.settings['gbKey']
      output = @workbenchJobObj.outputs[0]
      groupRecs = @dbu.selectGroupByName(@grpApiHelper.extractName(output))
      groupId = groupRecs.first['groupId']
      dbRecs = @dbu.selectRefseqByNameAndGroupId(@dbApiHelper.extractName(output), groupId)
      refSeqId = dbRecs.first['refSeqId']
      begin
        if(!gbKey.nil? and !gbKey.empty?)
          # Delete the current one
          BRL::Genboree::Abstract::Resources::UnlockedGroupResource.lockDatabaseById(@dbu, groupId, refSeqId)
          @workbenchJobObj.context['wbStatusMsg'] = "The gbKey has been deleted and the database is locked again."
        else
          BRL::Genboree::Abstract::Resources::UnlockedGroupResource.unlockDatabaseById(@dbu, groupId, refSeqId)
          gbKey = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.getKeyForDatabaseById(@dbu, groupId, refSeqId)
          @workbenchJobObj.context['wbStatusMsg'] = "The database has been unlocked. The gbKey is #{gbKey}"
        end
      rescue => err
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = "INTERNAL SERVER ERROR:\n#{err.message}"
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
