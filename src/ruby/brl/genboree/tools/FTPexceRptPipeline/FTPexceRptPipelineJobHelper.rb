require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class FTPexceRptPipelineJobHelper < WorkbenchJobHelper

    TOOL_ID = 'FTPexceRptPipeline'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "FTPexceRptPipelineWrapper.rb"
    end

    # INTERFACE METHOD. Returns an Array of commands that should be run very early in
    # the tool pipeline. These will be executed directly from the pbs file.
    # - They will run after the scratch dir is made and the job file sync'd over.
    # - Therefore suitable for global module load/swap commands that may set/change
    #   key env-variables (which will then need fixing)
    #
    # These are added to Job#preCommands at/near the top.
    #
    # Example, say you need to swap in a new jdk and thus want the $SITE_JARS updated
    # correctly depending on the environment. Return this:
    #
    #   [
    #     "module swap jdk/1.6"
    #   ]
    def preCmds()
      return [
        "module load exceRptPipeline/4_prod"
      ]
    end

    def postCmds()
      return ["fileApiTransfer.rb #{@userId} ./jobFile.json #{CGI.escape(@jobFileCopyUriPaths)}"]
    end

    # Casts certain args to the tool to integer
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      output = workbenchJobObj.outputs[0]
      group = @grpApiHelper.extractName(output)
      db = @dbApiHelper.extractName(output)
      analysisName = workbenchJobObj.settings['analysisName']
      uri = URI.parse(output)
      # Get the tool version of FTPexceRptPipeline from toolConf
      @toolVersion = @toolConf.getSetting('info', 'version')
      workbenchJobObj.settings['toolVersion'] = @toolVersion
      # This currently doesn't work, since we don't yet have virtualFTPArea in our workbenchJobObj's settings - we grab that from the manifest file while running the wrapper!
      remoteStorageArea = workbenchJobObj.settings['remoteStorageArea']
      @jobFileCopyUriPaths << "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/#{remoteStorageArea}/exceRptPipeline_v#{@toolVersion}/#{CGI.escape(analysisName)}/jobFile.json/data?"
      return workbenchJobObj
    end
  end
 
end ; end ; end # module BRL ; module Genboree ; module Tools
