require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class UcscBrowserJobHelper < WorkbenchJobHelper

    TOOL_ID = 'ucscBrowser'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end


    def runInProcess()
      success = true
      settings = @workbenchJobObj.settings
      baseWidget = settings['baseWidget']
      dbUrlHash = Hash.new { |hh,kk|
        hh[kk] = []
      }
      settings.each_key { |key|
        if(key =~ /^#{baseWidget}/)
          if(settings[key] and settings[key] == 'on')
            ext = ( key.split("|")[2] == 'bigWig' ? '_bwuc' : '_bbuc' )
            trkUri = key.split("|")[1]
            trkName = CGI.escape(@trkApiHelper.extractName(trkUri))
            dbUri = @dbApiHelper.extractPureUri(trkUri)
            dbUrlHash[dbUri] << "#{trkName}#{ext}"
          end
        end
      }
      apiUrl = ""
      # Create 'apiUrl' that will be used to create the final URL to give to UCSC
      dbCount = 0
      dbUrlHash.each_key { |dbUri|
        if(dbCount == 0)
          apiUrl << "#{dbUri.chomp('?')}/trks?gbKey=#{settings["gbKey_#{dbUri}"]}&format=ucsc_browser&ucscTracks=#{dbUrlHash[dbUri].join(',')}&ucscSafe=on"
        else
          apiUrl << ",#{CGI.escape("#{dbUri.chomp('?')}?gbKey=#{settings["gbKey_#{dbUri}"]}&ucscTracks=#{CGI.escape(dbUrlHash[dbUri].join(','))}&ucscSafe=on")}"
        end
        dbCount += 1
      }
      @workbenchJobObj.settings['apiUrl'] = apiUrl
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
