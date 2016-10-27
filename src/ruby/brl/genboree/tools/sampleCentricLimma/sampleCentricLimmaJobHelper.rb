require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'uri'

module BRL ; module Genboree ; module Tools
  class SampleCentricLimmaJobHelper < WorkbenchJobHelper

    TOOL_ID = 'sampleCentricLimma'


    # Must be defined in subclass. DO NOT USE CLASS VARIABLES WITH INHERITANCE.
    # CAN USE "class level instance variables" HOWEVER. THERE IS ONLY ONE (1)
    # CLASS VARIABLE, EVEN IF INHERITED (i.e. not separate storage, shared storage...many bugs.)
    #@@commandName = 'wrapperSearchSignalSim.rb'

    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "wrapperSampleCentricLimma.rb"
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
      outputs = workbenchJobObj.outputs
      group = db = uri = nil
      outputs.each { |output|
        if(@dbApiHelper.extractName(output))
          group = @grpApiHelper.extractName(output)
          db = @dbApiHelper.extractName(output)
          uri = URI.parse(output)
        end
      }
      analysisName = workbenchJobObj.settings['analysisName']
      workbenchJobObj.settings['removeNoDataRegions'] = workbenchJobObj.settings['removeNoDataRegions'] ? true : false
      @jobFileCopyUriPaths << "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/EpigenomeCompLIMMA/#{CGI.escape(analysisName)}/jobFile.json/data?"
      $stderr.puts("wbErrorMsg: #{workbenchJobObj.context['wbErrorMsg'].inspect}")
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
