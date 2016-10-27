#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/abstract/resources/entityList'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/entityAttributeMapEntity'
require 'brl/genboree/rest/data/textEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # CoreEntityAttributeMap - Generic resource for handled almost all maps of attribute-value pairs keyed by entity name
  #
  # Note: currently, these entities have a DEDICATED Resource Class (with higher priority) and don't use this class:
  #   - Tracks
  #
  # Note: There MUST be an instantiable Abstraction class available that implements the updateAttributes(attributeList)
  # method (must be FAST).
  #   - Register this class in the ENTITY_TYPE_TO_ABSTRACTION_CLASS Hash of brl/genboree/abstract/resources/entityList.rb
  #   - It will be found and instantiated automatically based on the incoming URL.
  #
  # Data representation classes used:
  class CoreEntityAttributeMap < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }

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
      return %r{^/REST/v1/grp/([^/\?]+)/(?:(?:attributes/)|([^/\?]+)/([^/\?]+)/attributes/)([^/\?]+)$}     # Look for /REST/v1/grp/{grp}/db/{db}/{entity}/attributes/map URIs
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
      return 8  # This is a pretty dedicated and specific URL, process it before any generic aspect type patterns
    end

    def initOperation()
      initStatus = super()
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      if(@uriMatchData[2] and @uriMatchData[3]) # then have a sub-group path element (db or prj), not just grp
        @entityType = Rack::Utils.unescape(@uriMatchData[2])
        @subGrpElemName = Rack::Utils.unescape(@uriMatchData[3])
      else
        @entityType = 'grp'
      end
      @aspect = Rack::Utils.unescape(@uriMatchData[4])
      @attributeList = @nvPairs['attributeList']
      @minNumAttributes = @nvPairs['minNumAttributes'].to_i
      @mapType = @nvPairs['mapType'] ? @nvPairs['mapType'] : 'full'
      if(@aspect == 'map')
        unless(@attributeList.nil?)
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
      if(Abstraction::EntityList::ENTITY_TYPE_TO_TABLE_NAME.key?(@entityType))
        @entityTableName = Abstraction::EntityList::ENTITY_TYPE_TO_TABLE_NAME[@entityType]
        if(initStatus == :OK)
          if(@entityType == 'grp')
            @statusName = initGroup()
          elsif(@entityType == 'db')
            @dbName = @databaseName = @subGrpElemName
            @statusName = initGroupAndDatabase()
          elsif(@entityType == 'prj')
            @statusName = initGroupAndProject()
            @projName = @projectName = @subGrpElemName
          else
            @statusName = :'Not Implemented'
            @statusMsg = "NOT_IMPLEMENTED: currently there is no support for attribute maps for #{@entityType.inspect}. Did you construct the URL correctly?"
          end
          if(@statusName == :OK)
            # Get the appropriate abstraction class
            abstractEntityClass = Abstraction::EntityList::ENTITY_TYPE_TO_ABSTRACTION_CLASS[@entityType]
            if(abstractEntityClass)
              # Instantiate the class
              if(@entityType == 'grp')
                entityObj = abstractEntityClass.new(@dbu, @groupId, @userId, {}, @connect)
              elsif(@entityType == 'db')
                entityObj = abstractEntityClass.new(@dbu, @refSeqId, @userId, {}, @connect)
              elsif(@entityType == 'prj')
                entityObj = abstractEntityClass.new(@projName, @groupId, @genbConf, @dbu, @userId)
              end
              if(entityObj.respond_to?(:updateAttributes))
                # Get it to retrieve track attribute info for the tracks
                entityObj.updateAttributes(@attributeList, @mapType, @aspect) # attributeList will be ingnored if @mapType = 'attrValues'
                # Use the attributes to create an EntityAttributeMapEntity
                entity = nil
                if(@aspect == 'map')
                  bodyData = {}
                  attrCount = 0
                  entityObj.attributesHash.each_key { |entityName|  # Should only be 1 key and it should same as entityObj.entityName...
                    if(@minNumAttributes.nil? or entityObj.attributesHash[entityName].size >= @minNumAttributes)
                      bodyData[entityName] = entityObj.attributesHash[entityName]
                      attrCount += 1
                    end
                  }
                  # Were there enough desired attributes for the entity? If not and min = 0, set to empty.
                  if(attrCount == 0 and @minNumAttributes and @minNumAttributes <= 0)
                    bodyData[entityObj.entityName] = {}
                  end
                  # Prep response
                  entity = BRL::Genboree::REST::Data::EntityAttributeMapEntity.new(@connect, bodyData)
                  # Config response
                  @statusName = configResponse(entity)
                elsif(@aspect == 'names')
                  entity = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
                  entityObj.attributesHash.each_key { |attrName|
                    entity << BRL::Genboree::REST::Data::TextEntity.new(false, attrName)
                  }
                  # Config response
                  @statusName = configResponse(entity)
                elsif(@aspect == 'values')
                  entity = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
                  entityObj.attributesHash.each_key { |attrValue|
                    entity << BRL::Genboree::REST::Data::TextEntity.new(false, attrValue)
                  }
                  # Config response
                  @statusName = configResponse(entity)
                else
                  initStatus = @statusName = :'Bad Request'
                  @statusMsg = "BAD_REQUEST: Unknown aspect: #{@aspect.inspect} requested."
                end
              else
                @statusName = :'Internal Server Error'
                @statusMsg = "FATAL: The support class for entity type #{@entityType.inspect} does not implement the required method 'updateAttributes()'."
              end
            else
              @statusName = :'Internal Server Error'
              @statusMsg = "FATAL: The support class for entity type #{@entityType.inspect} is missing."
            end
          else
            @statusName = :'Internal Server Error'
            @statusMsg = "FATAL: Could not identify the type of entity you are making the attributes request for. Likely cause: malformed/invalid URL path."
          end
        end
      else
        @statusName = :'Not Found'
        @statusMsg = "NO_ENTITY_TYPE: Cannot get attributes map for unknown entity type #{@entityType.inspect}."
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class CoreTrackAttributeMap
end ; end ; end # module BRL ; module REST ; module Resources
