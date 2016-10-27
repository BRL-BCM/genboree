require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class MicrobiomeResultUploaderJobHelper < WorkbenchJobHelper

    TOOL_ID = 'microbiomeResultUploader'


    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "microbiomeResultUploaderWrapper.rb"
    end

    # TODO: The job helper needs to use the user's selection for the annotation type and their
    # selection for the metric type to lookup to correct probe track in database indicated by
    # @genbConf.microbiomeResultUploaderDbUri
    # - one easy way to do this is with trks/attributes/map api call and specify the two attributes of
    #   interest (mbwAnnotationType, mbwMetricType) and a min number of records of 2. Then just iterate until you
    #   find the track that has these two attributes set to the values the user selected.

    # TODO: The job helper COULD take this opportunity to ensure the Output target database has ALL the
    # special entrypoints mentieoned in @genbConf.microbiomeResultUploaderDbUri database. If it doesn't,
    # it could add the missing ones now just before job submission. This way the job doesn't have to worry about it...
    # - note that the output db could have 1 special entrypoint but not a new [future but likely] one....


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
      # Get the gbKey for the database with the ROI track
      arrayDb = "#{@genbConf.microbiomeResultUploaderDbUri}"
      workbenchJobObj.settings['arrayDb'] = arrayDb
      host = URI.parse(arrayDb).host
      rsrcPath = URI.parse(arrayDb).path
      apiKey = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @genbConf.dbrcFile)
      apiCaller = ApiCaller.new(host, rsrcPath, @hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      resp = JSON.parse(apiCaller.respBody)['data']
      workbenchJobObj.settings['roiGbKey'] = resp['gbKey']
      # We need to pass on the 'ROI' track based on what the user selected as 'Annotation Type' and 'Metric Type'
      avpMap = workbenchJobObj.settings['avpMap']
      annoType = workbenchJobObj.settings['annoType']
      metricType = workbenchJobObj.settings['metricType']
      roiTrk = nil
      avpMap.each_key { |trk|
        annoTypeSatisfied = false
        metricTypeSatisfied = false
        avpMap[trk].each_key { |attr|
          value = avpMap[trk][attr]
          if(value == annoType or value == metricType)
            if(attr == 'mbwAnnotationType')
              annoTypeSatisfied = true
            elsif(attr == 'mbwMetricType')
              metricTypeSatisfied = true
            else
              # Skip
            end
          end
        }
        if(annoTypeSatisfied and metricTypeSatisfied)
          roiTrk = trk
          break
        end
      }
      workbenchJobObj.settings['ROI'] = "#{@genbConf.microbiomeResultUploaderDbUri}/trk/#{CGI.escape(roiTrk)}"
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
