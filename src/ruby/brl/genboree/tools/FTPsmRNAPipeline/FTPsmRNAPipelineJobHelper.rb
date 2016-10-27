require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class FTPsmRNAPipelineJobHelper < WorkbenchJobHelper

    TOOL_ID = 'FTPsmRNAPipeline'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "FTPsmRNAPipelineWrapper.rb"
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
        "module load smallRNAPipeline/2.0_prod"
      ]
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
