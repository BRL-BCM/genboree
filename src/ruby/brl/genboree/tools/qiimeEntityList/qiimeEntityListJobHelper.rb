require 'uri'
require 'json'
require 'brl/util/util'
require "brl/db/dbrc"
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'uri'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/helpers/fileApiUriHelper'

module BRL ; module Genboree ; module Tools
  class QiimeEntityListJobHelper < WorkbenchJobHelper

    TOOL_ID = 'qiimeEntityList'


    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "module load trackBasedQiime; epgQiimeWrapper.rb"
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
        success = false
      end
      return cmd
    end

    def cleanJobObj(workbenchJobObj)
      roiFound = false
      # Normalize inputs: remove ROI Track from input list (if there) and put it under settings
      newInputs = []
      workbenchJobObj.inputs.each { |input|
        if(@trkApiHelper.extractName(input))
          roiFound = true
          workbenchJobObj.settings['roiTrack'] = input
        else
          newInputs << input
        end
      }
      workbenchJobObj.inputs = newInputs
      # If ROI still not found, then it was not dragged by the user or fixed windows was selected
      if(!roiFound and workbenchJobObj.settings['roi'])
        if(workbenchJobObj.settings['roi'] == 'roiTrk')
          workbenchJobObj.settings['roiTrack'] = "#{@genbConf.roiRepositoryGrp}#{workbenchJobObj.settings['dbVer']}/trk/#{CGI.escape(workbenchJobObj.settings['roiTrack'])}?"
        else
          workbenchJobObj.settings.delete('roiTrack') if(workbenchJobObj.settings.key?('roiTrack'))
        end
      else
        # In this case where no roi track has been dragged and we did not have a roi track list for the genome assembly of interest,
        # 'fixedResolution' will automatically be selected.
      end
      workbenchJobObj.settings.delete('roiList') if(workbenchJobObj.settings.key?('roiList'))
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
