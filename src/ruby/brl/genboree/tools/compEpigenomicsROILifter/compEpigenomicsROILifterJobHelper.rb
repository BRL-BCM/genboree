require 'uri'
require 'json'
require 'brl/util/util'
require "brl/db/dbrc"
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class CompEpigenomicsROILifterJobHelper < WorkbenchJobHelper
    TOOL_NAME = 'ROI-Lifter'
    TOOL_LABEL = :hidden
    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "#{@genbConf.toolScriptPrefix}roiLifterWrapper.rb"
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

    def postCmds()
      return ["fileApiTransfer.rb #{@userId} ./jobFile.json #{CGI.escape(@jobFileCopyUriPaths)}"]
    end
    
    # Casts certain args to the tool to integer
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      outputs = workbenchJobObj.outputs
      multiple = workbenchJobObj.settings['multiple']
      workbenchJobObj.settings['multiple'] = multiple ? true : false
      studyName = CGI.escape(workbenchJobObj.settings['studyName'])
      jobName = CGI.escape(workbenchJobObj.settings['jobName'])
      parentDir = CGI.escape("Comparative Epigenomics")
      roiTrackVer = @dbApiHelper.dbVersion(workbenchJobObj.inputs[0])
      outputs.each {|output|
        if(@dbApiHelper.dbVersion(output) == roiTrackVer)
          workbenchJobObj.settings['srcVer'] = @dbApiHelper.dbVersion(output)
          workbenchJobObj.settings['srcDb'] = output
        else
          workbenchJobObj.settings['destVer'] = @dbApiHelper.dbVersion(output)
          workbenchJobObj.settings['destDb'] = output
        end
        group = @grpApiHelper.extractName(output)
        db = @dbApiHelper.extractName(output)
        uri = URI.parse(output)
        @jobFileCopyUriPaths << "http://#{uri.host}/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/#{parentDir}/#{studyName}/ROI-Lifter/#{jobName}/jobFile.json/data?"
      }
      return workbenchJobObj
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
