require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'uri'

module BRL ; module Genboree ; module Tools
  class LimmaJobHelper < WorkbenchJobHelper

    # Must be defined in subclass. DO NOT USE CLASS VARIABLES WITH INHERITANCE.
    # CAN USE "class level instance variables" HOWEVER. THERE IS ONLY ONE (1)
    # CLASS VARIABLE, EVEN IF INHERITED (i.e. not separate storage, shared storage...many bugs.)
    #@@commandName = 'wrapperSearchSignalSim.rb'

    TOOL_ID = 'limma'


    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "limmaWrapper.rb"
    end

    def preCmds()
      return [ "module swap jdk/1.6" ]
    end

    def buildCmd(useCluster=false)
      cmd = ''
      commandName = self.class.commandName
      raise NoMethodError.new("FATAL INTERNAL ERROR: Must have a commandName class instance variable in child class or buildCmd() should be overridden by child class if parent/default executionCallback is used.") if(commandName.nil?)
      if(useCluster)
        cmd = "#{commandName} -j ./#{@genbConf.gbJobJSONFile} "
      else
        cmd = "#{commandName} -j #{@workbenchJobObj.context['scratchDir']}/#{@genbConf.gbJobJSONFile} > #{@workbenchJobObj.context['scratchDir']}/#{commandName}.out 2> #{@workbenchJobObj.context['scratchDir']}/#{commandName}.err"
      end
      return cmd
    end

    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      workbenchJobObj = super(workbenchJobObj)
      output = workbenchJobObj.outputs[0]
      group = @grpApiHelper.extractName(output)
      db = @dbApiHelper.extractName(output)
      analysisName = workbenchJobObj.settings['analysisName']
      uri = URI.parse(output)
      metaCols = workbenchJobObj.settings['metaColumns']
      newMetaCols = []
      metaCols.each { |col|
        newMetaCols << CGI.unescape(col)  
      }
      workbenchJobObj.settings['metaColumns'] = newMetaCols
      metaDataCols = workbenchJobObj.settings['metaDataColumns']
      newMetaDataCols = []
      metaDataCols.each { |col|
        newMetaDataCols << CGI.unescape(col)  
      }
      workbenchJobObj.settings['metaDataColumns'] = newMetaDataCols
      workbenchJobObj.settings['metadataFile'] = workbenchJobObj.inputs[0]
      # Remove the metadata file from the inputs list since we added it to the settings
      workbenchJobObj.inputs = [workbenchJobObj.inputs[1]]
      @jobFileCopyUriPaths << "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/LIMMA/#{CGI.escape(analysisName)}/jobFile.json/data?"
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
