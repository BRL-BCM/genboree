require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class SignalDataComparisonAtlasJobHelper < WorkbenchJobHelper

    TOOL_ID = 'signalDataComparisonAtlas'


    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "regressionWrapper.rb"
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

    def exports()
      return [
        "export CLASSPATH=$SITE_JARS/GDASServlet.jar:$SITE_JARS/servlet-api.jar:$SITE_JARS/mysql-connector-java.jar:$SITE_JARS/mail.jar"
      ]
    end

    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      workbenchJobObj = super(workbenchJobObj)
      workbenchJobObj.settings['removeNoDataRegions'] =  workbenchJobObj.settings['removeNoDataRegions'] ? true : false
      workbenchJobObj.settings['quantileNormalized'] =  workbenchJobObj.settings['quantileNormalized'] ? true : false
      workbenchJobObj.settings['uploadFile'] =  workbenchJobObj.settings['uploadFile'] ? true : false
      # Clean out and set up workbench [json] entity
      outputs = workbenchJobObj.outputs
      inputs = workbenchJobObj.inputs
      settings = workbenchJobObj.settings
      dbVersion = @dbApiHelper.dbVersion(outputs.first, @hostAuthMap)

      # Need to add selected Atlas tracks to inputs.
      baseTrkUri = nil
      if(dbVersion == "hg18")
        baseTrkUri = @genbConf.atlasSimilaritySearchDbUri_hg18
      else # must be hg19 (only ones right now)
        baseTrkUri = @genbConf.atlasSimilaritySearchDbUri_hg19
      end
      newInputs = []
      newInputs.push(inputs[0])
      settings['epiAtlasScrTracks'].each { |escTrk|
        trkUri = "#{baseTrkUri}/trk/#{escTrk}"
        newInputs.push(trkUri)
      }
      epiScoreTrk =  settings['epiAtlasScrTracks']
      yAxisTrk = "#{baseTrkUri}/trk/#{epiScoreTrk}"
      workbenchJobObj.settings['yAxisTrk'] = yAxisTrk
      if(inputs.size == 2)
        newInputs.push(inputs[1])
        # Set the X-axis track
        roiTrack = workbenchJobObj.settings['roiTrack']
        inputs.each { |input|
          if(input.chomp('?') != roiTrack)
            workbenchJobObj.settings['xAxisTrk'] = input
            break
          end
        }
      else
        roiTrack = workbenchJobObj.settings['roiTrack']
        workbenchJobObj.settings['xAxisTrk'] = inputs[0]
        if(!roiTrack.nil? and !roiTrack.empty?)
          baseROIUri = nil
          if(dbVersion == 'hg18')
            baseROIUri = @genbConf.roiRepository_hg18
          else
            baseROIUri = @genbConf.roiRepository_hg19
          end
          newInputs.push("#{baseROIUri}/trk/#{roiTrack}")
          workbenchJobObj.settings['roiTrack'] = "#{baseROIUri}/trk/#{roiTrack}"
        end
      end

      workbenchJobObj.inputs = newInputs

      # Set resolution
      customRes = workbenchJobObj.settings['customResolution']
      fixedRes = workbenchJobObj.settings['fixedResolution']
      resolution = nil
      if(!customRes.nil? and !customRes.empty?)
        resolution = customRes
      else
        resolution = fixedRes
      end
      workbenchJobObj.settings['resolution'] = resolution
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
