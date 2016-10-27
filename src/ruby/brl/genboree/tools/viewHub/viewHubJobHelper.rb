require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'uri'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require 'brl/genboree/abstract/resources/user'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/apiCaller'
module BRL ; module Genboree ; module Tools
  class ViewHubJobHelper < WorkbenchJobHelper

    TOOL_ID = 'viewHub'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end


    def runInProcess()
      begin 
        success = true
        hubUnlock = @workbenchJobObj.settings['hubUnlock']
        hubUri = @workbenchJobObj.inputs.first
        hubLink = "#{hubUri.chomp('?')}/hub.txt"
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "hubLink: #{hubLink}")
        unless(hubUnlock)
          # Unlock the hub
          grpUri = @grpApiHelper.extractPureUri(hubUri)
          grpObj = URI.parse(grpUri)
          apiCaller = ApiCaller.new(grpObj.host, "#{grpObj.path}/unlockedResources?", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          payload = {"public" => true, "url" => hubUri.chomp('?')}
          apiCaller.put({}, [payload].to_json)
          if(!apiCaller.succeeded?)
            errMsg = "ApiCaller put request failed, at the hub resource #{hubUri}. Check: #{apiCaller.respBody.inspect}"
            success = false
            @workbenchJobObj.context['wbErrorMsg'] = errMsg
          end
        end
      
        settings = @workbenchJobObj.settings
        baseWidget = settings['baseWidget']
        filterLink = false
        selectedGenomes = Hash.new { |hh, kk| hh[kk] = [] }
        settings.each_key { |key|
          if(key =~ /^#{baseWidget}/)
            if(settings[key] and settings[key] == 'on')
              genome = key.split("|")[1]
              ucscUrl = "http://genome.ucsc.edu/cgi-bin/hgTracks?db=#{genome}&hubUrl=#{CGI.escape(hubLink)}"
              selectedGenomes[genome] << ucscUrl
              # Before adding the WashU URL check for the types - vcfTabix and BigBed
              # Do not show the link if these track types are there in the hub
              # datahub_ucsc has currenty partial support, i.e no support for vcfTabix and bigBed
              # And the hublinks with these track types fail to load.
              # So filter the link, show only ucsc in this case
              hubObj = URI.parse(hubUri)
              apiCaller = ApiCaller.new(hubObj.host, "#{hubObj.path}?detailed=true", @hostAuthMap)
              apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              apiCaller.get()
              if(apiCaller.succeeded?)
          
               hubData = apiCaller.parseRespBody['data']
               hubData['genomes'].each{|gen|
                  if(gen['genome'] == genome)
                    gen['tracks'].each { |trk|
                      if(trk['type'] == 'vcfTabix' or trk['type'] == 'bigBed')
                        filterLink = true
                        break
                      end
                    }
                  end
                }
                washUrl = "http://epigenomegateway.wustl.edu/browser/?genome=#{genome}&datahub_ucsc=#{hubLink}" if(!filterLink)
                selectedGenomes[genome] << washUrl if(!filterLink)
              else
                errMsg = "ApiCaller get request failed, at the hub resource #{hubUri}. Check: #{apiCaller.respBody.inspect}"
                success = false
                @workbenchJobObj.context['wbErrorMsg'] = errMsg
              end
            end
          end
        }
 
        @workbenchJobObj.settings['apiUrl'] = selectedGenomes
      rescue => err
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = "#{err.message}"
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
      end
      return success
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
