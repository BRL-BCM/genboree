require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/tools/workbenchJobHelper"
require 'uri'
module BRL ; module Genboree ; module Tools
  class SeqImportJobHelper < WorkbenchJobHelper

    TOOL_ID = 'seqImport'


    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "seqImporterWrapper.rb"
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


    # Casts certain args to the tool to integer
    # Also converts /files url to db if required
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      workbenchJobObj = super(workbenchJobObj)
      settings = workbenchJobObj.settings
      cutAtEnd = settings['cutAtEnd'] ? true : false
      blastDistalPrimer = settings['blastDistalPrimer'] ? true : false
      trimLowQualityRun = settings['trimLowQualityRun'] ? true : false
      removeNSequences = settings['removeNSequences'] ? true : false
      settings['cutAtEnd'] = cutAtEnd
      settings['blastDistalPrimer'] = blastDistalPrimer
      settings['trimLowQualityRun'] = trimLowQualityRun
      settings['removeNSequences'] = removeNSequences
      output = workbenchJobObj.outputs[0]
      group = @grpApiHelper.extractName(output)
      db = @dbApiHelper.extractName(output)
      sampleSetName = workbenchJobObj.settings['sampleSetName']
      uri = URI.parse(output)
      @jobFileCopyUriPaths << "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/MicrobiomeData/#{CGI.escape(sampleSetName)}/jobFile.json/data?"
      workbenchJobObj.settings = settings
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
