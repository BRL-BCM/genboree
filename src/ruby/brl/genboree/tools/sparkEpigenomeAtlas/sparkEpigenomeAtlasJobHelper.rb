require 'json'
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/helpers/databaseApiUriHelper'

module BRL ; module Genboree ; module Tools
  class SparkEpigenomeAtlasJobHelper < WorkbenchJobHelper

    TOOL_ID = 'sparkEpigenomeAtlas'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "sparkWrapper.rb"
    end

    def preCmds()
      return [ "module swap jdk/1.6" ]
    end


    # Cleans the workbench job object
    # Can be overwritten for a specific tool by the child class
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      # Clean out and set up workbench [json] entity
      outputs = workbenchJobObj.outputs
      inputs = workbenchJobObj.inputs
      settings = workbenchJobObj.settings
      dbVersion = @dbApiHelper.dbVersion(outputs.first, @hostAuthMap)
      # Need add selected Atlas tracks to inputs.
      # - first, need base Uri for the tracks
      baseTrkUri = nil
      if(dbVersion == "hg18")
        baseTrkUri = @genbConf.sparkAtlasDbUri_hg18
      else # must be hg19 (only ones right now)
        baseTrkUri = @genbConf.sparkAtlasDbUri_hg19
      end
      # Insert the epigenomics score tracks as part of inputs
      # It is important that we keep the ROI track/file as the 'last' entry in the input array
      # Set 'org' based on input data
      settings['org'] = dbVersion.to_s.downcase
      # Set the dataLabel (used internally for file names it says)
      settings['dataLabel'] = 'Spk'
      # Clean up binSize vs numBins
      if(settings['binSizeOrNum'] == 'useBinSize')
        settings['numBins'] = ""
      else # useNumBins
        settings['binSize'] = ""
      end
      settings.delete('binSizeOrNum')
      # Set numClusters as "k", which Spark expects
      settings['k'] = settings['numClusters']
      settings.delete('numClusters')
      # Clean up unused 'labelOnly' spacer widgets
      settings.delete('labelOnly')
      # Clean up color settings and config properly
      colLabel = []
      if(inputs.size > 1)
        settings.keys.each { |key|
          next unless(key =~ /^colLabel_(\d+)$/)
          colIdx = $1.to_i
          colLabel[colIdx] = settings[key]
        }
        settings.delete_if { |key, val| (key =~ /^colLabel_/ or key =~ /^clusterQueue/) }
        settings['colLabel'] = colLabel
      else # no user inputs, just set it up for the upcoming atlas tracks below
        settings['colLabel'] = []
      end
      # - second, need to add each selected Atlas track to the inputs array
      # - at same time, add a color setting to colLabel
      settings['epiAtlasScrTracks'].each { |escTrk|
        trkUri = "#{baseTrkUri}/trk/#{escTrk}"
        inputs.unshift(trkUri)
        settings['colLabel'].unshift('blue')
      }
      # - finally, clean up
      settings.delete('epiAtlasScrTracks')
      settings.delete('clusterQueue')
      $stderr.puts "-" * 80
      $stderr.puts "FINAL JSON, AFTER CLEANUP & MODS"
      $stderr.puts JSON.pretty_generate(workbenchJobObj)
      $stderr.puts "-" * 80
      return workbenchJobObj
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
