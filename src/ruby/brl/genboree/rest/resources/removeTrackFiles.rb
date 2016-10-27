#!/usr/bin/env ruby

require 'brl/util/util'
require 'brl/genboree/graphics/cytobandDrawer'
require 'brl/genboree/liveLFFDownload'
require 'brl/genboree/tabularDownloader'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/annotationEntity'
require 'brl/genboree/abstract/resources/bedFile'
require 'brl/genboree/abstract/resources/gffFile'
require 'brl/genboree/abstract/resources/wigFile'
require 'brl/genboree/abstract/resources/lffFile'
require 'brl/genboree/abstract/resources/tabularLayout'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Dedicated resource for removing track-related file like bin and big* files.
  # Will nuke ALL bin files and big* files for a track
  # Requires ftypeid as a parameter since this is called AFTER deleting the track from the ftype table and
  # we have no way of knowing the ftypeid of the track
  # Data representation classes used:
  # * _none_, gets and delivers raw LFF text directly.
  class RemoveTrackFiles < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports
    # ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :delete => true }

    # TEMPLATE_URI: Constant to provide an example URI
    # for requesting this resource through the API
    TEMPLATE_URI = "/REST/v1/grp/{grp}/db/{db}/trk/{trk}/removeTrackFiles$"

    RESOURCE_DISPLAY_NAME ="Remove Track Files"
    def initialize(req, resp, uriMatchData)
      super(req, resp, uriMatchData)
    end
    
    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @refseqRow.clear() if(@refseqRow)
      @ftypeRow.clear() if(@ftypeRow)
      @ftypeRow = @refseqRow = @aspect = @dbName = @refSeqId = @groupId = @groupName = @groupDesc = nil
      # Track related data
      @ftypeHash = @trackName = @tracks = nil
      # Layout related data
      @layout = @layoutName = nil
    end
    
    def initOperation()
      initStatus = super()
      # Init the resource instance vars
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @dbName = Rack::Utils.unescape(@uriMatchData[2])
      @trackName = Rack::Utils.unescape(@uriMatchData[3]).strip unless(@uriMatchData[3].nil?)
      # Init and check group & database exist and are accessible
      initStatus = initGroupAndDatabase()
      return initStatus
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)/removeTrackFiles$</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)/removeTrackFiles$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 9          # Allow more specific URI handlers involving tracks etc within the database to match first
    end
    
    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def delete()
      initOperation()
      prepResponse() if(@statusName == :OK)
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
    
    def prepResponse()
      if(@nvPairs['ftypeid'])
        ftypeid = @nvPairs['ftypeid']
        ftypeRecs = @dbu.selectFtypeByTrackName(@trackName)
        `rm -f #{@genbConf.ridSequencesDir.chomp("/")}/#{@refSeqId}/#{CGI.escape(@trackName)}.*bin`
        `rm -rf #{@genbConf.gbAnnoDataFilesDir.chomp("/")}/grp/#{@groupId}/db/#{@refSeqId}/trk/#{ftypeid}`
        entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, 'Deleted')
        @statusName = configResponse(entity)
      else
        @statusName = :'Bad Request'
        @statusMsg = "Bad Request: You need to provide the ftypeid of the track you want to delete the files for."
      end
    end
    
    
    
  end
end; end ;end