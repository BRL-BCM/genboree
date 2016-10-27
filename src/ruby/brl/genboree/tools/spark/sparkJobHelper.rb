require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class SparkJobHelper < WorkbenchJobHelper

    TOOL_ID = 'spark'


    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "sparkWrapper.rb"
    end

    # INTERFACE METHOD. Returns an Array of commands that should be run very early in
    # the tool pipeline. These will be executed directly from the pbs file.
    # - They will run after the scratch dir is made and the job file sync'd over.
    # - Therefore suitable for global module load/swap commands that may set/change
    #   key env-variables (which will then need fixing)

    # Example, say you need to swap in a new jdk and thus want the $SITE_JARS updated
    # correctly depending on the environment. Return this:
    #
    #   [
    #     "module swap jdk/1.6"
    #   ]
    def preCmds()
      return [ "module swap jdk/1.6" ]
    end

    # Cleans the workbench job object
    # Can be overwritten for a specific tool by the child class
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      super(workbenchJobObj)
      # Clean out and set up workbench [json] entity
      inputs = workbenchJobObj.inputs
      outputs = workbenchJobObj.outputs
      settings = workbenchJobObj.settings
      # Remove the roi track from the inputs if it's there (shouldn't be, but just in case)
      roiTrack = settings['roiTrack']
      roiTrackUri = URI.parse(roiTrack)
      inputs.delete_if { |xx|
        delVal = false
        xxUri = URI.parse(xx)
        if(roiTrackUri.equivalent?(xxUri))
          delVal = true
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Found roiTrack in inputs array. Should not be there, as Javascript should have removed it already (bug?). Removing #{roiTrack.inspect}")
        end
        delVal
      }
      dbVersion = @dbApiHelper.dbVersion(outputs.first, @hostAuthMap)
      # Sort the @inputs so the indices used to set the colors match the indicies
      # in the @inputs Array
      schwartzMap = {}
      inputs.sort! { |aa, bb|
        aaKey = schwartzMap[aa]
        bbKey = schwartzMap[bb]
        unless(aaKey) # then we need to make to sort key for URL aa the first time
          aaKey = (@trkApiHelper.extractName(aa) || File.basename(aa).split('?').first).downcase
          # save key for 2nd 3rd 4th...Nth comparison
          schwartzMap[aa] = aaKey
        end
        unless(bbKey) # then we need to make to sort key for URL aa the first time
          bbKey = (@trkApiHelper.extractName(bb) || File.basename(bb).split('?').first).downcase
          # save key for 2nd 3rd 4th...Nth comparison
          schwartzMap[bb] = bbKey
        end
        aaKey <=> bbKey
      }
      schwartzMap.clear()
      # Set 'org' based on input data
      settings['org'] = dbVersion.to_s.downcase
      # Set the dataLabel (used internally for file names it says)
      settings['dataLabel'] = 'Spk'
      # Set numClusters as "k", which Spark expects
      settings['k'] = settings['numClusters']
      settings.delete('numClusters')
      # Clean up unused 'labelOnly' spacer widgets
      settings.delete('labelOnly')
      # Clean up color settings and config properly
      unless(settings['colLabels'] and !settings['colLabels'].empty?) # only if we don't have the appropriate colLabels array in settings (e.g. from UI)
        colLabel = []
        settings.keys.each { |key|
          next unless(key =~ /^colLabel_(\d+)$/)
          colIdx = $1.to_i
          colLabel[colIdx] = settings[key]
        }
        settings.delete_if { |key, val| (key =~ /^colLabel_/) }
        settings['colLabels'] = colLabel
      end
      return workbenchJobObj
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
