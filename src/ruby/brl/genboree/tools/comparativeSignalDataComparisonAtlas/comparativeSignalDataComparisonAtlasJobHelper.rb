require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/abstract/resources/jobFile'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'

module BRL ; module Genboree ; module Tools
  class ComparativeSignalDataComparisonAtlasJobHelper < WorkbenchJobHelper
    TOOL_LABEL = :hidden
    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "#{@genbConf.toolScriptPrefix}pairWiseSignalSearchCompEpigenomics.rb"
    end

   

    # This is where the command is defined
    #
    # WARNING: Be careful when building a command to be executed.
    # Any command line option values must be properly escaped.
    #
    # For example: someone submitted a var @settings['foo'] = ';rm -dfr /'
    # and then you build a command without escaping
    # "myCommand.rb -n #{foo}"  =>  myCommand.rb -n ;rm -dfr /
    # The correct way to do this is using CGI.escape()
    # "myCommand.rb -n #{CGI.escape(foo)}"  =>  myCommand.rb -n %3Brm%20-dfr%20%2F
    #
    # [+returns+] string: the command
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
      workbenchJobObj.settings['uploadFile'] =  workbenchJobObj.settings['uploadFile'] ? true : false
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
          @jobFileCopyUriPaths << "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/#{parentDir}/#{studyName}/Signal-Comparison/#{analysisName}/jobFile.json/data?"
        elsif(@dbApiHelper.dbVersion(output) == @dbApiHelper.dbVersion(inputs[2])) # inputs[2] is always 'independent'
          workbenchJobObj.settings['independentDb'] = output
          # Add the atlas track to the inputs
          epiAtlasScrTrack = workbenchJobObj.settings['epiAtlasScrTracks']
          baseTrkUri = nil
          if(@dbApiHelper.dbVersion(output).downcase == "hg18")
            baseTrkUri = @genbConf.atlasSimilaritySearchDbUri_hg18
          else # must be hg19 (only ones right now)
            baseTrkUri = @genbConf.atlasSimilaritySearchDbUri_hg19
          end
          inputs.push("#{baseTrkUri}/trk/#{epiAtlasScrTrack}?")
        end
      }
      workbenchJobObj.inputs = inputs
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
