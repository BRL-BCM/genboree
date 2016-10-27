require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/user'
require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class EpigenomeAtlasSimilaritySearchJobHelper < WorkbenchJobHelper
    # Must be defined in subclass. DO NOT USE CLASS VARIABLES WITH INHERITANCE.
    # CAN USE "class level instance variables" HOWEVER. THERE IS ONLY ONE (1)
    # CLASS VARIABLE, EVEN IF INHERITED (i.e. not separate storage, shared storage...many bugs.)
    #@@commandName = 'wrapperSearchAtlasSim.rb'

    TOOL_ID = 'epigenomeAtlasSimilaritySearch'


    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "correlationWrapper.rb"
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
    
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      workbenchJobObj = super(workbenchJobObj)
      workbenchJobObj.context['dbrcKey'] = @genbConf.dbrckey
      workbenchJobObj.settings['removeNoDataRegions'] =  workbenchJobObj.settings['removeNoDataRegions'] ? true : false
      # Clean out and set up workbench [json] entity
      outputs = workbenchJobObj.outputs
      inputs = workbenchJobObj.inputs
      workbenchJobObj.settings['useGenboreeRoiScores'] = inputs.size == 2 ? true : false
      settings = workbenchJobObj.settings
      @dbu = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil, nil)
      @userId = workbenchJobObj.context['userId']
      @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @userId)
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
      # Insert the epigenomics score tracks as part of inputs
      # It is important that we keep the ROI track/file as the 'last' entry in the input array
      scoreTracks = []
      settings['epiAtlasScrTracks'].each { |escTrk|
        trkUri = "#{baseTrkUri}/trk/#{escTrk}"
        newInputs.push(trkUri)
        scoreTracks.push(trkUri)
      }
      workbenchJobObj.settings['scoreTracks'] = scoreTracks
      if(inputs.size == 2)
        newInputs.push(inputs[1])
        # The track 'other' than the ROI track will be the query track
        roiTrack = workbenchJobObj.settings['roiTrack']
        inputs.each { |input|
          if(input.chomp('?') != roiTrack.chomp('?'))
            workbenchJobObj.settings['queryTrack'] = input
          end
        }
      else
        roiTrack = workbenchJobObj.settings['roiTrack']
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
