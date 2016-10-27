require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class ComparativeSignalSimilaritySearchJobHelper < WorkbenchJobHelper
    TOOL_LABEL = :hidden
    # Must be defined in subclass. DO NOT USE CLASS VARIABLES WITH INHERITANCE.
    # CAN USE "class level instance variables" HOWEVER. THERE IS ONLY ONE (1)
    # CLASS VARIABLE, EVEN IF INHERITED (i.e. not separate storage, shared storage...many bugs.)
    #@@commandName = 'wrapperSearchSignalSim.rb'

    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "#{@genbConf.toolScriptPrefix}signalSimilaritySearchCompEpigenomicsWrapper.rb"
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

    def postCmds()
      return ["fileApiTransfer.rb #{@userId} ./jobFile.json #{CGI.escape(@jobFileCopyUriPaths)}"]
    end
    
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      workbenchJobObj = super(workbenchJobObj)
      workbenchJobObj.settings['removeNoDataRegions'] =  workbenchJobObj.settings['removeNoDataRegions'] ? true : false
      workbenchJobObj.settings['quantileNormalized'] =  workbenchJobObj.settings['quantileNormalized'] ? true : false
      # Add 'dependent' and 'indepenedent' dbs to settings
      analysisName = workbenchJobObj.settings['analysisName']
      outputs = workbenchJobObj.outputs
      inputs = workbenchJobObj.inputs
      studyName = CGI.escape(workbenchJobObj.settings['studyName'])
      analysisName = CGI.escape(workbenchJobObj.settings['analysisName'])
      parentDir = CGI.escape("Comparative Epigenomics")
      outputs.each { |output|
        if(@dbApiHelper.dbVersion(output) == @dbApiHelper.dbVersion(inputs[0])) # inputs[0] is always 'dependent'
          workbenchJobObj.settings['dependentDb'] = output
          # Create a folder for this tool named by the analysisName under the Files/ area of thw workbench
          uri = URI.parse(output)
          group = @grpApiHelper.extractName(output)
          db = @dbApiHelper.extractName(output)
          @jobFileCopyUriPaths << "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/#{parentDir}/#{studyName}/Signal-Search/#{analysisName}/jobFile.json/data?"
        elsif(@dbApiHelper.dbVersion(output) == @dbApiHelper.dbVersion(inputs[2])) # inputs[2] is always 'independent'
          workbenchJobObj.settings['independentDb'] = output
        end
      }
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
