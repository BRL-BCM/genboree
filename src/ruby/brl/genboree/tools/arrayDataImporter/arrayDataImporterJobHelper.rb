require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class ArrayDataImporterJobHelper < WorkbenchJobHelper

    TOOL_ID = 'arrayDataImporter'


    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "arrayDataImporterWrapper.rb"
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
      dbVer = @dbApiHelper.dbVersion(workbenchJobObj.outputs[0]).downcase
      arrayDb = "#{@genbConf.arrayDataDbUri}#{dbVer}"
      workbenchJobObj.settings['arrayDb'] = arrayDb
      host = URI.parse(arrayDb).host
      rsrcPath = URI.parse(arrayDb).path
      userId = workbenchJobObj.context['userId']
      apiKey = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @genbConf.dbrcFile)
      apiCaller = WrapperApiCaller.new(host, rsrcPath, userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      resp = JSON.parse(apiCaller.respBody)['data']
      workbenchJobObj.settings['roiGbKey'] = resp['gbKey']
      workbenchJobObj.settings['roiKey'] = genbConf.arrayDataROIKey
      workbenchJobObj.settings['refSeqId'] = @dbApiHelper.tableRow(workbenchJobObj.outputs[0])['refSeqId']
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
