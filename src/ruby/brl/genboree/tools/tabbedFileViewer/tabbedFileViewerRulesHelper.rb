require 'uri'
require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/rest/resources/databaseFile'

module BRL ; module Genboree ; module Tools

  class TabbedFileViewerRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'tabbedFileViewer'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied and wbJobEntity.context['mode'] != 'upload')
        filePath = wbJobEntity.context['file']

        # Currently we only support DatabaseFiles
        # TODO: Is this right? How would we handle any file? (project files...)
        if(!filePath.nil?() and !filePath.empty?())
          # We need to make sure that our passed file exists and is readable
          if(File.file?(filePath) and File.readable?(filePath))
            rulesSatisfied = true
          else
            rulesSatisfied = false

            # Set our error message
            if(!File.file?(filePath))
              wbJobEntity.context['wbErrorMsg'] = 'The file you are trying to view could not be found. Please contact your genboree administrator for assistance.'
            else
              wbJobEntity.context['wbErrorMsg'] = 'The file you are trying to view could not be read. Please contact your genboree administrator for assistance.'
            end
          end
        else
          wbJobEntity.context['wbErrorMsg'] = 'Currently only Database Files are supported. Please selected a file from a database in the Workbench.'
          rulesSatisfied = false
        end
      end

      return rulesSatisfied
    end
  end
end; end; end
