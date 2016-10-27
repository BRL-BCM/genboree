require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/classApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/trackEntityListApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class EpigenomicSliceRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'epigenomicSlice'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        outputs = wbJobEntity.outputs
        inputs = wbJobEntity.inputs
        userId = wbJobEntity.context['userId']
        # Check 1: Version matching
        unless(checkDbVersions(inputs + outputs, skipNonDbUris=true)) # Failed
          wbJobEntity.context['wbErrorMsg'] = "The database version of one or more inputs does not match the version of the target database."
        else
          rulesSatisfied = true
          if(!sectionsToSatisfy.include?(:settings))
            trkHash = {}
            trkApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new()
            trkListApiHelper = BRL::Genboree::REST::Helpers::TrackEntityListApiUriHelper.new()
            dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
            classApiHelper = BRL::Genboree::REST::Helpers::ClassApiUriHelper.new()
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
                  $stderr.puts "host: #{uri.host.inspect}\trcscUri: #{rcscUri.inspect}"
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
                elsif(dbApiHelper.extractType(input) == "db") # For db
                  dbUri = dbApiHelper.extractPureUri(input)
                  uri = dbUri.dup()
                  uri = URI.parse(uri)
                  rcscUri = uri.path.chomp("?")
                  rcscUri << "/trks?connect=false"
                  $stderr.puts "host: #{uri.host.inspect}\trcscUri: #{rcscUri.inspect}"
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
          else
            wbJobEntity.inputs = []
            multiSelectInputList = wbJobEntity.settings['multiSelectInputList']
            multiSelectInputList.each { |inputUri|
              wbJobEntity.inputs << inputUri
            }
          end
          if(wbJobEntity.inputs.length < 1)
            wbJobEntity.context['wbErrorMsg'] = "This tool requires atleast 1 ROI track in addition to 1 or more score tracks. The score tracks can be individually selected or can come from a database, a class or a tracklist."
            rulesSatisfied = false
          end
        end
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(rulesSatisfied and sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end
          rulesSatisfied = false
          output = wbJobEntity.outputs[0]
          uri = URI.parse(output)
          host = uri.host
          rcscUri = uri.path
          rcscUri = rcscUri.chomp("?")
          analysisName = CGI.escape(wbJobEntity.settings['analysisName'])
          rcscUri << "/file/EpigenomeSlice/#{analysisName}/jobFile.json?"
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{analysisName.inspect} has already been launched before. Please select a different analysis name."
          else
            settings = wbJobEntity.settings
            # Check 1: If ROI track is Hdhv?
            wrongInput = false
            roiTrack = wbJobEntity.settings['roiTrack']
            wrongInput = true if(roiTrack.nil? or roiTrack.empty? or @trkApiHelper.isHdhv?(wbJobEntity.settings['roiTrack'], @hostAuthMap))
            if(wrongInput)
              wbJobEntity.context['wbErrorMsg'] = "Invalid Input: ROI Track not selected or is a high density track. "
            else
              naPercentage = wbJobEntity.settings['naPercentage']
            if(wbJobEntity.settings['naGroup'] == "custom" and (naPercentage.nil? or naPercentage.empty? or !naPercentage.to_s.valid?(:float) or naPercentage.to_f < 0) ) then
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Percentage value MUST be a positive number."
            elsif(wbJobEntity.settings['replaceNAValue'].nil? or wbJobEntity.settings['replaceNAValue'].empty? or !wbJobEntity.settings['replaceNAValue'].to_s.valid?(:float))
                wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: No Data Value MUST be a number."
              else
              rulesSatisfied = true
            end
            end
          end
        end
      end
      return rulesSatisfied
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
