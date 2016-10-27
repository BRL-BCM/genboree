require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackEntityListApiUriHelper'

require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class GeneElementDataSliceRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'geneElementDataSlice'


    def customToolChecks(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      dbrcFile = File.expand_path(ENV['DBRC_FILE'])
      user = @superuserApiDbrc.user
      pass = @superuserApiDbrc.password
      trkApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new()
      trkListApiHelper = BRL::Genboree::REST::Helpers::TrackEntityListApiUriHelper.new()
      dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
      classApiHelper = BRL::Genboree::REST::Helpers::ClassApiUriHelper.new()
      fileApiHelper = BRL::Genboree::REST::Helpers::FileApiUriHelper.new()
      rulesSatisfied = false
      output = wbJobEntity.outputs[0]
      uri = URI.parse(output)
      host = uri.host
      rcscUri = uri.path
      rcscUri = rcscUri.chomp("?")
      analysisName = CGI.escape(wbJobEntity.settings['analysisName'])
      rcscUri << "/file/GeneElementDataSlice/#{analysisName}/jobFile.json?"
      apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?) # Failed: job dir already exists
        wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{analysisName.inspect} has already been launched before. Please select a different analysis name."
      else
        # Check 2: Version matching
        urisToCheck = []
        wbJobEntity.inputs.each{|input| urisToCheck << input unless(BRL::Genboree::REST::Helpers::FileApiUriHelper.new().extractName(input)) }
        urisToCheck += wbJobEntity.outputs
        # TODO: remove the file one, it just has the list of gene names (and may come from a different database and/or assembly)
        if(checkDbVersions(urisToCheck, true)) # Failed
          rulesSatisfied = true
          if(!sectionsToSatisfy.include?(:settings))
            trkHash = {}
            fileInput = nil
            wbJobEntity.inputs.each{|input|
              if(rulesSatisfied) then
                if(input =~ BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP) # For tracks
                  trkHash[input] = true
                elsif(input =~ BRL::Genboree::REST::Helpers::ClassApiUriHelper::NAME_EXTRACTOR_REGEXP) # For class
                  className = classApiHelper.extractName(input)
                  dbUri = dbApiHelper.extractPureUri(input)
                  uri = dbUri.dup()
                  uri = URI.parse(uri)
                  rcscUri = uri.path.chomp("?")
                  rcscUri << "/trks?connect=false&class=#{CGI.escape(className)}"
                  # Get all tracks for this class
                  apiCaller = ApiCaller.new(uri.host, rcscUri, @hostAuthMap)
                  apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
                  apiCaller.get()
                  if(!apiCaller.succeeded?)
                    wbJobEntity.context['wbErrorMsg'] = "Apicaller failed to get tracks for class #{className}"
                    rulesSatisfied = false
                  else
                    resp = apiCaller.respBody()
                    retVal = JSON.parse(resp)
                    tracks = retVal['data']
                    tracks.each { |track|
                      trkUri = "#{dbUri.chomp("?")}/trk/#{CGI.escape(track['text'])}?"
                      trkHash[trkUri] = true
                    }
                  end
                elsif(input =~ BRL::Genboree::REST::Helpers::TrackEntityListApiUriHelper::NAME_EXTRACTOR_REGEXP) # trackList
                  uri = URI.parse(input)
                  rcscUri = uri.path
                  apiCaller = ApiCaller.new(uri.host, rcscUri, @hostAuthMap)
                  apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
                  apiCaller.get()
                  if(!apiCaller.succeeded?)
                    wbJobEntity.context['wbErrorMsg'] = "ApiCaller failed to get tracks from tracklist: #{trkListApiHelper.extractName(input)}"
                    rulesSatisfied = false
                  else
                    resp = apiCaller.respBody()
                    retVal = JSON.parse(resp)
                    tracks = retVal['data']
                    tracks.each { |track|
                      trkHash[track["url"]] = true
                    }
                  end
                elsif(fileApiHelper.extractName(input))
                  fileInput = input
                elsif(dbApiHelper.extractType(input) == "db" ) # For db
                  dbUri = dbApiHelper.extractPureUri(input)
                  uri = dbUri.dup()
                  uri = URI.parse(uri)
                  rcscUri = uri.path.chomp("?")
                  rcscUri << "/trks?connect=false"
                  apiCaller = ApiCaller.new(uri.host, rcscUri, @hostAuthMap)
                  apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
                  apiCaller.get()
                  if(!apiCaller.succeeded?)
                    wbJobEntity.context['wbErrorMsg'] = "ApiCaller failed to get tracks from database: #{dbApiHelper.extractName(input)}"
                    rulesSatisfied = false
                  else
                    resp = apiCaller.respBody()
                    retVal = JSON.parse(resp)
                    tracks = retVal['data']
                    tracks.each { |track|
                      trkUri = "#{dbUri.chomp("?")}/trk/#{CGI.escape(track['text'])}?"
                      trkHash[trkUri] = true
                    }
                  end
                end
              end
            }
            wbJobEntity.inputs = trkHash.keys
            if(fileInput) then wbJobEntity.inputs << fileInput else rulesSatisfied = false end
          else
            multiSelectInputList = wbJobEntity.settings['multiSelectInputList']
            fileInput = nil
            wbJobEntity.inputs.each{|input|
              if(fileApiHelper.extractName(input)) then fileInput = input end
            }
            wbJobEntity.inputs = multiSelectInputList
            if(fileInput) then wbJobEntity.inputs << fileInput else rulesSatisfied = false end
          end
        else
          wbJobEntity.context['wbErrorMsg'] = "The database version of one or more inputs does not match the version of the target database."
          rulesSatisfied = false
        end
      end
      return rulesSatisfied
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
