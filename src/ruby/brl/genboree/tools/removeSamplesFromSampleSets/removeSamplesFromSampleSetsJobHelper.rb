require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'uri'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/dbUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class RemoveSamplesFromSampleSetsJobHelper < WorkbenchJobHelper

    TOOL_ID = 'removeSamplesFromSampleSets'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      settings = @workbenchJobObj.settings
      dbFileRsrc = @workbenchJobObj.inputs.first
      outputs = @workbenchJobObj.outputs
      error = ''
      fileOk = true
      @isFile = false
      @apiDbrc = @superuserApiDbrc
      if(dbFileRsrc =~ BRL::Genboree::REST::Helpers::FileApiUriHelper::NAME_EXTRACTOR_REGEXP)
        # Need to extract group, db and file names from uri
        @isFile = true
        fileName = @fileApiHelper.extractName(dbFileRsrc)
        fileName = @fileApiHelper.extractName(dbFileRsrc)
        dbName = @fileApiHelper.dbApiUriHelper.extractName(dbFileRsrc)
        grpName = @fileApiHelper.dbApiUriHelper.grpApiUriHelper.extractName(dbFileRsrc)
        @uri = URI.parse(dbFileRsrc)
        @fileRcscUri = "/REST/v1/grp/#{CGI.escape(grpName)}/db/#{CGI.escape(dbName)}/file/#{CGI.escape(fileName)}/data?" # Always uploaded to 'Raw Data Files' folder
      end
      cleanJobObj(@workbenchJobObj) # Add samples to sample set
      return success
    end

    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      inputs = workbenchJobObj.inputs
      outputs = workbenchJobObj.outputs
      @sampleSetUri = "#{outputs[0].chomp("?")}"
      outputUri = URI.parse(@sampleSetUri)
      if(@isFile) # if inputs is a file (dragged or uploaded)
        apiCaller = ApiCaller.new(@uri.host, @fileRcscUri, @hostAuthMap)
        retVal = ""
        # Making internal API call
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        resp = apiCaller.get()
        if(apiCaller.succeeded?)
          retVal = apiCaller.respBody
          retIO = StringIO.new(retVal)
          # collect sample names.
          sampleNames = []
          retIO.each_line { |line|
            line.strip!
            next if(line.nil? or line.empty? or line =~ /^\s*$/)
            sampleNames.push({'name' => line, 'type' => '', 'biomaterialState' => '', 'biomaterialProvider' => '', 'biomaterialSource' => '', 'state' => 0, 'avpHash' => {}})
          }
          retIO.close()
          payload = {'data' => sampleNames}
          $stderr.puts "payload: #{payload.inspect}"
          # Insert the samples
          apiCaller = ApiCaller.new(outputUri.host, "#{outputUri.path}/samples?", @hostAuthMap)
          $stderr.puts "host: #{outputUri.host}\turi: #{outputUri.path}/samples?"
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.delete({}, payload.to_json)
          if(!apiCaller.succeeded?)
            wue = BRL::Genboree::Tools::WorkbenchUIError.new(':BAD_REQUEST', apiCaller.respBody.inspect)
            raise wue
          end
        else
          wue = BRL::Genboree::Tools::WorkbenchUIError.new(':BAD_REQUEST', apiCaller.respBody.inspect)
          raise wue
        end
      else # if inputs are sample(s) or sampleSet(s)
        # First make a payload
        sampleEntityList = []
        inputs.each { |input|
          if(input =~ BRL::Genboree::REST::Helpers::SampleApiUriHelper::NAME_EXTRACTOR_REGEXP) # sample
            uri = URI.parse(input)
            rcscUri = uri.path.chomp("?")
            apiCaller = ApiCaller.new(uri.host, "#{rcscUri}?detailed=true&format=json", @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            if(apiCaller.succeeded?)
              retVal = JSON.parse(apiCaller.respBody)
              sampleEntityList.push(retVal['data'])
            else
              wue = BRL::Genboree::Tools::WorkbenchUIError.new(':BAD_REQUEST', apiCaller.respBody.inspect)
              raise wue
            end
          else # sample set
            uri = URI.parse(input)
            rcscUri = uri.path.chomp("?")
            apiCaller = ApiCaller.new(uri.host, "#{rcscUri}?detailed=true", @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            if(apiCaller.succeeded?)
              retVal = JSON.parse(apiCaller.respBody)
              data = retVal['data']
              data.each_key { |key|
                if(key == 'sampleList')
                  data[key]['data'].each { |sampleEntity|
                    sampleEntityList.push(sampleEntity)
                  }
                  break
                end
              }
            else
              wue = BRL::Genboree::Tools::WorkbenchUIError.new(':BAD_REQUEST', apiCaller.respBody.inspect)
              raise wue
            end
          end
        }
        # Insert the samples
        apiCaller = ApiCaller.new(outputUri.host, "#{outputUri.path}/samples?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        payload = {'data' => sampleEntityList}
        apiCaller.delete({}, payload.to_json)
        if(!apiCaller.succeeded?)
          wue = BRL::Genboree::Tools::WorkbenchUIError.new(':BAD_REQUEST', apiCaller.respBody.inspect)
          raise wue
        end
      end
      return workbenchJobObj
    end


  end
end ; end ; end # module BRL ; module Genboree ; module Tools
