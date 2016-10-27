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
  class PublishDbJobHelper < WorkbenchJobHelper

    TOOL_ID = 'publishDb'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      begin
        dbRecs = @dbApiHelper.tableRow(@workbenchJobObj.outputs[0])
        refSeqId = dbRecs['refSeqId']
        statusMsg = ''
        if(@dbu.isRefseqPublic(refSeqId)) # Retract
          @dbu.retractDatabase(refSeqId)
          statusMsg = "The database has been successfully retracted."
        else # Publish
          @dbu.publishDatabase(refSeqId)
          statusMsg = "The database has been been successfully published."
        end
        @workbenchJobObj.context['wbStatusMsg'] = statusMsg
      rescue => err
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = "INTERNAL SERVER ERROR: Could not publish database. Error: #{err.message}"
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
