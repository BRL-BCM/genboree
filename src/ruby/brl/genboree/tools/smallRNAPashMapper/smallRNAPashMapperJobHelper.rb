require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/tools/workbenchJobHelper"
require "brl/db/dbrc"
require 'uri'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class SmallRNAPashMapperJobHelper < WorkbenchJobHelper

    TOOL_ID = 'smallRNAPashMapper'


    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "smallRNApashMapWrapper.rb"
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

    # Casts certain args to the tool to integer
    # Also converts /files url to db if required
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      # Convert files/ to db (if required)
      output = workbenchJobObj.outputs[0]
      workbenchJobObj.outputs[0] = @dbApiHelper.extractPureUri(output)
      uploadRes = workbenchJobObj.settings['uploadResults']
      workbenchJobObj.settings['uploadResults'] = uploadRes ? true : false
      workbenchJobObj.settings['targetGenomeVersion'] = @dbApiHelper.dbVersion(output, @hostAuthMap).downcase
      workbenchJobObj.settings['kWeight'] = workbenchJobObj.settings['kWeight'].to_i
      workbenchJobObj.settings['maxMappings'] = workbenchJobObj.settings['maxMappings'].to_i
      workbenchJobObj.settings['diagonals'] = workbenchJobObj.settings['diagonals'].to_i
      workbenchJobObj.settings['gap'] = workbenchJobObj.settings['gap'].to_i
      workbenchJobObj.settings['topPercent'] = workbenchJobObj.settings['topPercent'].to_i
      workbenchJobObj.settings['kSpan'] = workbenchJobObj.settings['kSpan'].to_i
      workbenchJobObj.settings['sampleName'] = CGI.escape(workbenchJobObj.settings['sampleName'])
      workbenchJobObj.settings['wigTrackName'] = "#{CGI.escape(workbenchJobObj.settings['lffType'])}%3A#{CGI.escape(workbenchJobObj.settings['lffSubType'])}"
      genbConf = BRL::Genboree::GenboreeConfig.load()
      dbVer = workbenchJobObj.settings['targetGenomeVersion']
      # Make an API call the get the gbkey for the ROi db:
      pashGroup = @genbConf.pashMapperTrackListGroupUri
      uri = URI.parse(pashGroup)
      host = uri.host
      rsrcPath = uri.path
      apiKey = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @genbConf.dbrcFile)
      # Query directly for gbKey to obtain it for non public dbs with public gbKeys
      apiCaller = ApiCaller.new(host, "#{uri.path}/db/smallRNAanalysis_#{dbVer}/gbKey", @hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?) then
        apiCaller.parseRespBody
        workbenchJobObj.settings['roiGbKey'] = apiCaller.apiDataObj["text"]
      else
        $stderr.debugPuts(__FILE__, __method__, "ERROR","#{Time.now} Unable to retrieve gbKey for #{uri.path}/db/smallRNAanalysis_#{dbVer}")
      end

      workbenchJobObj.settings['targetGenome'] = "#{genbConf.targetGenomeDirForSmallRNA}/#{dbVer}/#{dbVer}.fa"
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
