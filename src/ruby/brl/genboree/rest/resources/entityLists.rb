#!/usr/bin/env ruby
require 'erubis'
require 'uri'
require 'open-uri'
require 'brl/util/util'
require 'brl/genboree/abstract/resources/entityList'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class EntityLists < BRL::REST::Resources::GenboreeResource
    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }
    UNLOCKABLE = true

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
    end

    # INTERFACE: return a +Regexp+ that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] +Regexp+:
    def self.pattern()
      # Look for one of these patterns:
      #     /REST/v1/grp/{grp}/db/{db}/{type}/entityLists   (all the lists of a certain type in the database)
      # OR  /REST/v1/grp/{grp}/db/{db}/entityLists/{aspect} (get info about the various types entityLists in database)
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/(?:(?:([^/\?]+)/entityLists)|(?:entityLists/([^/\?]+)))$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 9         # Want to match early on, before other more generic patterns
    end

    def initOperation()
      @statusName = super()
      if(@statusName == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        # Only 1 of the following available
        @entityType = (@uriMatchData[3] ? Rack::Utils.unescape(@uriMatchData[3]) : nil)
        @entityListAspect = (@uriMatchData[4] ? Rack::Utils.unescape(@uriMatchData[4]) : nil)
      end
      return @statusName
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      @statusName = initOperation()
      if(@statusName == :OK)
        @statusName = initGroupAndDatabase()
        if(@statusName == :OK)
          respEntity = nil
          # Which of 2 cases are we handling?
          if(@entityType) # 1. asked for entityLists of a specific type in the database
            tableName = Abstraction::EntityList::ENTITY_TYPE_TO_ENTITYLIST_TABLE_NAME[@entityType]
            if(tableName)
              begin
                # Get distinct name records for appropriate entity type
                listNameRecs = @dbu.selectResourceListNames(tableName)
                listNameRecs.sort { |aa, bb|
                  aa['name'].downcase <=> bb['name'].downcase
                }
                # Prepare a TextEntityList response object
                refBase = "/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/#{Rack::Utils.escape(@entityType)}/entityList"
                respEntity = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
                # Add each list name to the TextEntityList
                listNameRecs.each { |listNameRow|
                  listName = listNameRow['name']
                  entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, listName)
                  entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(listName)}")
                  respEntity << entity
                }
              rescue => err
                msg = "FATAL: server encountered an error getting the names of #{@entityType.inspect}-type resource lists in database #{@dbName.inspect} in user group #{@groupName.inspect}"
                BRL::Genboree::GenboreeUtil.logError(msg, err)
                @apiError = BRL::Genboree::GenboreeError.new(@statusName, msg, err)
              end
            else
              @statusName = :'Not Found'
              @statusMsg = "NO_ENTITY_TYPE: The entity type #{@entityType.inspect} is the plural form of a known entity type and thus will have no entity lists associated with it. Perhaps it is not spelled correctly or is not in the plural form?"
            end
          else  # 2. asked something about all the entityLists in database (e.g. the types of lists present or something)
            if(@entityListAspect == 'types')  # asking about the types of entityLists in the database
              begin
                onlyNonEmpty = !@detailed
                listTypes = Abstraction::EntityList.getEntityListTypes(@dbu, !@detailed)
                # Prepare a TextEntityList response object
                refBase = "/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/#{Rack::Utils.escape(@entityType)}/entityList"
                respEntity = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
                # Add each list name to the TextEntityList
                listTypes.each { |listType|
                  entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, listType)
                  entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(listType)}")
                  respEntity << entity
                }
              rescue => err
                msg = "FATAL: server encountered an error getting the types of resource lists in database #{@dbName.inspect} in user group #{@groupName.inspect}"
                BRL::Genboree::GenboreeUtil.logError(msg, err)
                @apiError = BRL::Genboree::GenboreeError.new(@statusName, msg, err)
              end
            end
          end
          @statusName = configResponse(respEntity) if(respEntity)
        end
      end
      # Update status info if there was an error along the way:
      (@statusName, @statusMsg = @apiError.type, @apiError.message) if(!@apiError.nil?)
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end # def get()
  end # class EntityLists < BRL::REST::Resources::GenboreeResource
end ; end ; end # module BRL ; module REST ; module Resources
