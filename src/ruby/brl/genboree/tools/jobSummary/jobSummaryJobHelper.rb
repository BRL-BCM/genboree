require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'uri'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class JobSummaryJobHelper < WorkbenchJobHelper

    TOOL_ID = 'jobSummary'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      settings = @workbenchJobObj.settings
      tools = settings['tools']
      toolMap = settings['toolMap']
      startDate = settings['dateField_startDate']
      endDate = settings['dateField_endDate']
      sortOrder = settings['sortOrder']
      grouping = settings['grouping']
      rsrcPath = "/REST/v1/jobs?detailed=summary"
      toolString = tools.join(',')
      toolCount = 0
      rsrcPath << "&toolIdStrs=#{toolString}"
      @workbenchJobObj.settings['toolIdStr'] = toolString
      submitDateRange = ''
      submitDateRange << CGI.escape(startDate) if(startDate and !startDate.empty? and startDate != 'YYYY/MM/DD')
      submitDateRange << ','
      
      submitDateRange << CGI.escape( endDate + " 23:59:59" ) if(endDate and !endDate.empty? and endDate != 'YYYY/MM/DD')
      @workbenchJobObj.settings['entryDateRange'] = submitDateRange
      rsrcPath << "&entryDateRange=#{submitDateRange}" if(submitDateRange != ',')
      if(grouping !~ /none/i)
        rsrcPath << "&sortByCols=#{grouping},entryDate"
      else
        rsrcPath << "&sortByCols=entryDate"
      end
      rsrcPath << "&sortBy=#{sortOrder}"
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "JOBS [summary] RSRCPATH: #{rsrcPath.inspect}")
      apiCaller = WrapperApiCaller.new(@genbConf.machineName, rsrcPath, @userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      apiCaller.parseRespBody()
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "JOBS [summary] RESPBODY: \n\n#{apiCaller.respBody}\n\n")
      if(!apiCaller.succeeded?)
        @workbenchJobObj.context['wbErrorMsg'] = apiCaller.apiStatusObj['msg']
        success = false
      else
        @workbenchJobObj.results = apiCaller.apiDataObj
        @workbenchJobObj.settings['summaryResponse'] = apiCaller.apiDataObj.to_json
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
