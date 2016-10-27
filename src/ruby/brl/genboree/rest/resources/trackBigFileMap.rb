#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/trackAttributeMapEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # TrackBigFileMap - Map of track names to values for [currently two attributes ("bigWig" and "bigBed").
  # - Value will be either "none" or a time stamp when the big* file was last created.
  #
  # Data representation classes used:
  class TrackBigFileMap < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @refseqRow.clear() if(@refseqRow)
      @refseqRow = @dbName = @refSeqId = @groupId = @groupName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)/attribute/([^/\?]+)(?:/([^/\?]+))?</tt>
    def self.pattern()
      return %r{^/REST/v1/grp/([^/\?]+)/db/([^/\?]+)/trks/bigFiles/map$}     # Look for /REST/v1/grp/{grp}/db/{db}/trks/bigFiles/map URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    #
    # This class needs to be a higher priority than BRL::REST::Resources::Track
    # so that 'attribute' will be considered a resource and handled by this class as opposed to a track aspect
    #
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 9  # This is a pretty dedicated and specific URL, process it before any generic aspect type patterns
    end

    def initOperation()
      initStatus = super()
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @dbName = Rack::Utils.unescape(@uriMatchData[2])
      return initStatus
    end

    # Process a GET operation on this resource.
    # _returns_ - Rack::Response instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK) # It's ok to be forbidden at this point because that refers to the ability to put/delete to a grp/db resource
          # Get all the tracks in this user database (includes shared tracks) [that user has access to; superuser has access to everything]
          ftypesHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes_fast(@refSeqId, @userId, true, @dbu) # will also have dbRec.dbName & dbRec.ftypeid for the dbs (user, template) track is present in
          if(ftypesHash.nil? or ftypesHash.empty?)
            initStatus = @statusName = :'Not Found'
            @statusMsg = "NO_TRKS: There are no accessible tracks in database #{@dbName.inspect} in user group #{@groupName.inspect} (or perhaps isn't encoded correctly?)"
          else
            # if the 'class' url parameter is set filter for tracks mapped to this class
            if(@nvPairs['class'])
              ftypesHashByClass = {}
              # Lookup Hash for storing the ftypeIds linked to the class with the dbName as the key
              ftypeIdsForGclassHash = {}
              ftypesHash.each_key { |tname|
                ftypeHash = ftypesHash[tname]
                ftypeHash['dbNames'].each { |dbRec|
                  # If the value in the hash for the key dbName is nil then we haven't looked yet,
                  if(ftypeIdsForGclassHash[dbRec.dbName].nil?)
                    # Set the database
                    @dbu.setNewDataDb(dbRec.dbName)
                    # get the ftypeids that are mapped to the glclass
                    ftypeIdRows = @dbu.selectFtypeIdsByClass(@nvPairs['class'])
                    if(!ftypeIdRows.nil? and !ftypeIdRows.empty?)
                      ftypeIdsForGclassHash[dbRec.dbName] = ftypeIdRows.map {|nn| nn = nn.first }
                    else
                      ftypeIdsForGclassHash[dbRec.dbName] = []
                    end
                  end
                  if(!ftypeIdsForGclassHash[dbRec.dbName].index(dbRec.ftypeid).nil?)
                    ftypesHashByClass[tname] = ftypesHash[tname]
                  end
                }
              }
              ftypesHash = ftypesHashByClass
            end
            # Make Tracks Abstraction instance
            tracksObj = Abstraction::Tracks.new(@dbu, @refSeqId, ftypesHash, @userId, @connect)
            # Get it to retrieve bigFile info for the tracks
            tracksObj.updateBigFileInfo()
            # Use the bigFile info to create a TrackAttributeMapEntity with some dedicated attributes
            bodyData = Hash.new { |hh, kk| hh[kk] = {} }
            ftypesHash.each_key { |trackName|
              Abstraction::Tracks::UCSC_BIGFILE_TYPES.each { |bigFileType|
                bigFileHash = tracksObj.bigFileHash[trackName]
                if(bigFileHash and bigFileHash[bigFileType])
                  bodyData[trackName][bigFileType] = bigFileHash[bigFileType]
                else
                  bodyData[trackName][bigFileType] = 'none'
                end
              }
            }
            # Create attribute map entity
            entity = BRL::Genboree::REST::Data::EntityAttributeMapEntity.new(@connect, bodyData)
            # Config response
            @statusName = configResponse(entity)
          end
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class TrackBigFileMap
end ; end ; end # module BRL ; module REST ; module Resources
