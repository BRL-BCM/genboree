require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'uri'
module BRL ; module Genboree ; module Tools
  class QiimeJobHelper < WorkbenchJobHelper

    TOOL_ID = 'qiime'


    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "qiimeWrapper.rb"
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

    def postCmds()
      return ["fileApiTransfer.rb #{@userId} ./jobFile.json #{CGI.escape(@jobFileCopyUriPaths)}"]
    end

    # Casts certain args to the tool to integer
    # Also converts /files url to db if required
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      workbenchJobObj = super(workbenchJobObj)
      gpHelperObj = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new()
      dbHelperObj = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
      outputs = workbenchJobObj.outputs
      group = gpHelperObj.extractName(outputs[0]) # Group can be determined from both db and project Uri

      # We need to check which output is the db, since QIIME additionally takes a project as output
      db = nil
      uri = nil
      outputs.each { |output|
        if(output =~ BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP)
          db = dbHelperObj.extractName(output)
          uri = URI.parse(output)
          break
        end
      }
      studyName = CGI.escape(workbenchJobObj.settings['studyName'])
      jobName = CGI.escape(workbenchJobObj.settings['jobName'])
      workbenchJobObj.settings['removeChimeras'] = workbenchJobObj.settings['removeChimeras'] ? true : false
      @jobFileCopyUriPaths << "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/MicrobiomeWorkBench/#{studyName}/QIIME/#{jobName}/jobFile.json/data?"
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
