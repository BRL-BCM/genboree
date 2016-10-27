#!/usr/bin/env ruby
require 'brl/sql/binning'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/trackImporterInfoEntity'
require 'brl/genboree/rest/data/detailedTrackImporterInfoEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # TrackImporterInfoRecord - exposes track importer info for a particular info record
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::TrackImporterInfoEntityList
  # * BRL::Genboree::REST::Data::DetailedTrackImporterInfoEntityList
  class TrackImporterInfoRecord < BRL::REST::Resources::GenboreeResource
    # Convenience access to abstract resource classes
    Abstract = BRL::Genboree::Abstract::Resources
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }

    # INTERFACE: return a Regexp that will match a correctly formed URI for this service
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/resources/importer/build/([^/\?]+)/src/([^/\?]+)/trk/([^/\?]+)</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/resources/importer/build/([^/\?]+)/src/([^/\?]+)/trk/([^/\?]+)}      # Look for /REST/v1/resources/build/{build}/{src}/trk/#{trkKey} URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/service is
    # highly specific and should be examined early on, or whether it is more generic and
    # other services should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 4          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        @build = Rack::Utils.unescape(@uriMatchData[1])
        @src = Rack::Utils.unescape(@uriMatchData[2])
        @trkKey = Rack::Utils.unescape(@uriMatchData[3])
        setResponse()
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def setResponse(statusName=:OK, statusMsg='')
      begin
        # Load and parse the track importer file
        importInfo = Abstract::TrackImporterInfo.new(@build, @genbConf)
        if(@detailed)
          infoRec = importInfo.getImporterInfoRecord(@trkKey, :importerInfo)
          entity = BRL::Genboree::REST::Data::DetailedTrackImporterInfoEntity.new(false, infoRec)
        else
          infoRec = importInfo.getImporterInfoRecord(@trkKey, :mappingInfo)
          entity = BRL::Genboree::REST::Data::TrackImporterInfoEntity.new(false, infoRec)
        end
        @statusName = configResponse(entity)
      rescue => err # likely File not found error; either recommended.list or the main info file is missing (both required)
        @statusName = :'Not Found'
        @statusMsg = "NO_IMPORT_TRACKS: There are no tracks configured for import for assembly version '#{@build}'."
      end
      return @statusName
    end
  end # class TrackImporterInfo
end ; end ; end # module BRL ; module REST ; module Resources
