require 'uri'
require 'json'
require 'brl/util/util'
require "brl/db/dbrc"
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/helpers/fileApiUriHelper'

module BRL ; module Genboree ; module Tools
  class ChromHMMLearnModelJobHelper < WorkbenchJobHelper

    TOOL_ID = 'chromHMMLearnModel'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "chromHMMLearnModelWrapper.rb"
    end

    def preCmds()
      return [ "module load ChromHMM/1.1" ]
    end
    def postCmds()
      return ["fileApiTransfer.rb #{@userId} ./jobFile.json #{CGI.escape(@jobFileCopyUriPaths)}"]
    end

    # [+returns+] string: the command
    def buildCmd(useCluster=true)
      cmd = ''
      commandName = self.class.commandName
      $stderr.puts "commandName: #{commandName.inspect}"
      raise NoMethodError.new("FATAL INTERNAL ERROR: Must have a commandName class instance variable in child class or buildCmd() should be overridden by child class if parent/default executionCallback is used.") if(commandName.nil?)
      if(useCluster)
        cmd = "#{commandName} -j ./#{@genbConf.gbJobJSONFile} "
      else
        msg = "ERROR: The #{TOOL_NAME} cluster analysis tool requires a cluster to run."
        $stderr.puts msg
        @workbenchJobObj = workbenchJobObj
        # Add errors to the context so they can be display to user
        @workbenchJobObj.context['wbErrorName'] = :'Internal Server Error'
        @workbenchJobObj.context['wbErrorMsg'] = msg
        #success = false
      end
      return cmd
    end

    # Casts certain args to the tool to integer
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      if(workbenchJobObj.outputs[0] !~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
          outputDb = workbenchJobObj.outputs[1]
      else
        outputDb = workbenchJobObj.outputs[0]
      end
      #workbenchJobObj.settings['assembly'] = @dbApiHelper.dbVersion(outputDb, @hostAuthMap).downcase
      group = @grpApiHelper.extractName(outputDb)
      db = @dbApiHelper.extractName(outputDb)
      uri = URI.parse(outputDb)
      analysisName = workbenchJobObj.settings['analysisName']
      @jobFileCopyUriPaths << "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/ChromHMM%20-%20LearnModel%20-%20Results/#{CGI.escape(analysisName)}/jobFile.json/data?"
      return workbenchJobObj
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
