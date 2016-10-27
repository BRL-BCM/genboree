require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'uri'

module BRL ; module Genboree ; module Tools
  class EpigenomicsHeatmapJobHelper < WorkbenchJobHelper

    TOOL_ID = 'epigenomicsHeatmap'



    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "wrapperEpigenomeHeatMap.rb"
    end

    def buildCmdPrefix(useCluster=false)
      cmdPrefix = ""
      return cmdPrefix
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
        "module load graphlan",
        "module unload R",
        "module load R/2.15",
        "module load cairo",
        "export MAGICK_THREAD_LIMIT=2"  # MUST match :ppn above! Else takes over All-1 cores! Very bad if many running at once...
      ]
    end

    def cleanJobObj(workbenchJobObj)
      workbenchJobObj = super(workbenchJobObj)
      workbenchJobObj.settings['removeNoDataRegions'] =  workbenchJobObj.settings['removeNoDataRegions'] ? true : false
      # If there is only one entity list, duplicate it for a self comparison
      noOfList = 0
      listIndex = nil
      idx = 0
      inputs = workbenchJobObj.inputs
      inputs.each { |input|
        if(@trackEntityListApiHelper.extractName(input))
          noOfList += 1
          listIndex = idx
        end
        idx += 1
      }
      if(noOfList == 1)
        workbenchJobObj.inputs << workbenchJobObj.inputs[listIndex]
      end
      return workbenchJobObj
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
