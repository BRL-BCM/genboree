#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/trackAttributeMapEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # TrackAttributeMap - Map of attribute-value pairs keyed by track name
  #
  # Data representation classes used:
  class TrackAttributeMap < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }
    # Labels, etc, for building more generic strings that are copy-paste-bug free
    RSRC_STRS = { :type => 'trks' }
    ENTITY_TYPE = 'ftypes' # Tracks actually
    MAP_TYPES = {"full" => true, "attrNames" => true, "attrValues" => true}
    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @refseqRow.clear() if(@refseqRow)
      @refseqRow = @entityName = @dbName = @refSeqId = @groupId = @groupName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)/attribute/([^/\?]+)(?:/([^/\?]+))?</tt>
    def self.pattern()
      return %r{^/REST/v1/grp/([^/\?]+)/db/([^/\?]+)/#{self::RSRC_STRS[:type]}/attributes/([^/\?]+)$}     # Look for /REST/v1/grp/{grp}/db/{db}/trks/attributes/map URIs
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
      @aspect = Rack::Utils.unescape(@uriMatchData[3])
      @attributeList = @nvPairs['attributeList']
      @minNumAttributes = @nvPairs['minNumAttributes'].to_i
      @mapType = @nvPairs['mapType'] ? @nvPairs['mapType'] : 'full'
      unless(@attributeList.nil?)
        if(@attrNamesOnly)
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "BAD_REQUEST: 'attrNamesOnly' cannot be provided with 'attributesList'."
        else
          @attributeList = @attributeList.split(/,/)
          @attributeList = nil if(@attributeList.empty?) # handle param with no value case
        end
      end
      if(!MAP_TYPES.has_key?(@mapType))
        initStatus = @statusName = :'Bad Request'
        @statusMsg = "BAD_REQUEST: Unknown mapType: #{@mapType.inspect}."
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # _returns_ - Rack::Response instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK) # It's ok to be fobidden at this point because that refers to the ability to put/delete to a grp/db resource
          # Get all the tracks in this user database (includes shared tracks) [that user has access to; superuser has access to everything]
          ftypesHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes_fast(@refSeqId, @userId, true, @dbu) # will also have dbRec.dbName & dbRec.ftypeid for the dbs (user, template) track is present in
          if(ftypesHash.nil? or ftypesHash.empty?)
            initStatus = @statusName = :'Not Found'
            @statusMsg = "NO_TRKS: There are no tracks #{@entityName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect} (or perhaps isn't encoded correctly?)"
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
                      ftypeIdsForGclassHash[dbRec.dbName] = ftypeIdRows.map { |nn| nn = nn.first }
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
            # Get tracks abstraction
            tracksObj = BRL::Genboree::Abstract::Resources::Tracks.new(@dbu, @refSeqId, ftypesHash, @userId, @connect)
            # Get it to retrieve track attribute info for the tracks
            tracksObj.updateAttributes(@attributeList, @mapType, @aspect) # attributeList will be ingnored if @mapType = 'attrValues'
            # Use the attributes to create a TrackAttributeMapEntity
            if(@aspect == 'map')
              bodyData = {}
              ftypesHash.each_key { |trackName|
                if(tracksObj.attributesHash.key?(trackName))
                  if(@minNumAttributes.nil? or tracksObj.attributesHash[trackName].size >= @minNumAttributes)
                    bodyData[trackName] = tracksObj.attributesHash[trackName]
                  end
                else
                  bodyData[trackName] = {} if(@minNumAttributes <= 0)
                end
              }
              entity = BRL::Genboree::REST::Data::TrackAttributeMapEntity.new(@connect, bodyData)
              # Config response
              @statusName = configResponse(entity)
            elsif(@aspect == 'names')
              entity = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
              tracksObj.attributesHash.each_key { |attrName|
                entity << BRL::Genboree::REST::Data::TextEntity.new(false, attrName)
              }
              # Config response
              @statusName = configResponse(entity)
            elsif(@aspect == 'values')
              entity = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
              tracksObj.attributesHash.each_key { |attrValue|
                entity << BRL::Genboree::REST::Data::TextEntity.new(false, attrValue)
              }
              # Config response
              @statusName = configResponse(entity)
            else
              initStatus = @statusName = :'Bad Request'
              @statusMsg = "BAD_REQUEST: Unknown aspect: #{@aspect.inspect} requested."
            end
          end
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class TrackAttributeMap
end ; end ; end # module BRL ; module REST ; module Resources
