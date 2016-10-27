#!/usr/bin/env ruby
require 'erubis'
require 'uri'
require 'open-uri'
require 'brl/util/util'
require 'brl/genboree/abstract/resources/entityList'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/urlEntity'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class CoreEntityList < BRL::REST::Resources::GenboreeResource
    Abstraction = BRL::Genboree::Abstract::Resources

    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true }

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
      # Look for /REST/v1/grp/{grp}/db/{db}/{type}/entityList/{entityListName}
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/([^/\?]+)/entityList/([^/\?]+)}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 9          # Want to match early on, before other more generic patterns
    end

    def initOperation()
      @statusName = super()
      if(@statusName == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @entityType = Rack::Utils.unescape(@uriMatchData[3])
        @entityListName = Rack::Utils.unescape(@uriMatchData[4])
      end
      return @statusName
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK)
          tableName = Abstraction::EntityList::ENTITY_TYPE_TO_ENTITYLIST_TABLE_NAME[@entityType]
          if(tableName)
            begin
              # Get the records for @entityListName
              resourceListRecs = @dbu.selectResourceListUrlsByNames(tableName, @entityListName)
              # Prepare a UrlEntityList response object
              respEntity = BRL::Genboree::REST::Data::UrlEntityList.new(@connect)
              resourceListRecs.each { |rec|
                # (the individual urls are not addressable currently)
                entity = BRL::Genboree::REST::Data::UrlEntity.new(false, rec['url'])
                respEntity << entity
              }
              @statusName = configResponse(respEntity)
            rescue => err
              msg = "FATAL: server encountered an error getting the urls in the #{@entityType.inspect}-type resource list named #{@entityListName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}"
              BRL::Genboree::GenboreeUtil.logError(msg, err)
              @apiError = BRL::Genboree::GenboreeError.new(@statusName, msg, err)
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_ENTITY_TYPE: The entity type #{@entityType.inspect} is the plural form of a known entity type and thus will have no entity lists associated with it. Perhaps it is not spelled correctly or is not in the plural form?"
          end
        end
      end
      # Update status info if there was an error along the way:
      (@statusName, @statusMsg = @apiError.type, @apiError.message) if(!@apiError.nil?)
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def put()
      initStatus = initOperation()
      if(initStatus == :OK)
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK)
          tableName = Abstraction::EntityList::ENTITY_TYPE_TO_ENTITYLIST_TABLE_NAME[@entityType]
          if(tableName)
            begin
              # Parse the payload for a UrlEntity or UrlEntity
              payloadEntity = parseRequestBodyAllFormats(['UrlEntityList', 'UrlEntity', 'TextEntity'], @repFormat)
              if(payloadEntity.is_a?(UrlEntity) or payloadEntity.is_a?(UrlEntityList))
                if(payloadEntity.is_a?(UrlEntity))
                  urls = [ payloadEntity.url ]
                else # must be a UrlEntityList
                  # extract all the urls
                  urls = payloadEntity.map { |entity| entity.url }
                end
                # Add the urls to the list
                numAdded = @dbu.insertResourceListUrls(tableName, @entityListName, urls)
                if(numAdded and numAdded >= 0)
                  diff = (urls.size - numAdded)
                  entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
                  entity.setStatus(:OK, "ADDED: #{numAdded} entity URLs were added to the #{@entityType.inspect}-type entity list named #{@entityListName.inspect}. #{"The remaining #{diff} URL#{"s" if(diff != 1)} appear#{"s" if(diff == 1)} to already be in the list, based on the first 500 characters of the URL." if(numAdded != urls.size)}")
                  @statusName = configResponse(entity)
                else # negative or nil or something?
                  raise "ERROR: Somehow #{numAdded} records were inserted. Expected 0+. ??"
                end
              elsif(payloadEntity.is_a?(TextEntity))
                newListName = payloadEntity.text
                # Use this new name to rename the existing entity list
                @dbu.renameResourceList(tableName, @entityListName, newListName)
                entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
                entity.setStatus(:OK, "RENAMED: The entity list was renamed to #{newListName.inspect}")
                @statusName = configResponse(entity)
              else # couldn't parse
                @statusName = :'Unsupported Media Type'
                @statusMsg = "BAD_PAYLOAD: Either the payload is empty or does not appear to be either a UrlEntity or UrlEntityList representation. Entity lists must contain at least 1 entity URI; empty lists are not allowed. Provide the URI(s) using a UrlEntity or UrlEntityList payload."
              end
            rescue => err
              msg = "FATAL: server encountered an error adding the urls to the #{@entityType.inspect}-type resource list named #{@entityListName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}"
              BRL::Genboree::GenboreeUtil.logError(msg, err)
              @apiError = BRL::Genboree::GenboreeError.new(@statusName, msg, err)
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_ENTITY_TYPE: The entity type #{@entityType.inspect} is the plural form of a known entity type and thus will have no entity lists associated with it. Perhaps it is not spelled correctly or is not in the plural form?"
          end
        end
      end
      # Update status info if there was an error along the way:
      (@statusName, @statusMsg = @apiError.type, @apiError.message) if(!@apiError.nil?)
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource.
    # [+returns+] - Rack::Response instance
    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK)
          tableName = Abstraction::EntityList::ENTITY_TYPE_TO_ENTITYLIST_TABLE_NAME[@entityType]
          if(tableName)
            begin
              reqBody = self.readAllReqBody()
              if(reqBody.nil? or reqBody.empty?)
                # - 1. No payload, delete the whole entity list
                numDeleted = @dbu.deleteResourceListsByNames(tableName, @entityListName)
                if(numDeleted and numDeleted >= 0)
                  entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
                  entity.setStatus(:OK, "DELETED: the entity list named #{@entityListName.inspect} was deleted.")
                  @statusName = configResponse(entity)
                else # negative or nil or something?
                  raise "ERROR: Somehow #{numDeleted} records were deleted. Expected 0+. ??"
                end
              else
                # - 2. Have payload. Either a UrlEntityList or just one UrlEntity. Parse and delete.
                payloadEntity = parseRequestBodyAllFormats(['UrlEntity', 'UrlEntityList'], @repFormat)
                unless(payloadEntity == :'Unsupported Media Type')
                  if(payloadEntity.is_a?(UrlEntity))
                    urls = [ payloadEntity.url ]
                  else # must be a UrlEntityList
                  # extract all the urls
                  urls = payloadEntity.map { |entity| entity.url }
                  end
                  # Remove the urls from the list
                  numDeleted = @dbu.deleteResourceListUrls(tableName, @entityListName, urls)
                  if(numDeleted and numDeleted >= 0)
                    diff = (urls.size - numDeleted)
                    entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
                    entity.setStatus(:OK, "DELETED: #{numDeleted} entity url#{(urls.size > 1 ? 's' : '')} were deleted from the entity list named #{@entityListName.inspect}. #{"The remaining #{diff} URL#{"s" if(diff != 1)} appear#{"s" if(diff == 1)} NOT to be in the list anyway, based on the first 500 characters of the URL." if(numDeleted != urls.size)}")
                    @statusName = configResponse(entity)
                  else # negative or nil or something?
                    raise "ERROR: Somehow #{numDeleted} records were deleted. Expected 0+. ??"
                  end
                else # couldn't parse
                  @statusName = :'Unsupported Media Type'
                  @statusMsg = "BAD_PAYLOAD: The payload does not appear to be either a UrlEntity or UrlEntityList representation. If a payload is provided, it needs to be one of those so we can remove the appropriate url(s) from the entity list. If you want to delete the whole entity list, do NOT provide a payload."
                end
              end
            rescue => err
              msg = "FATAL: server encountered an error deleting the urls from the #{@entityType.inspect}-type resource list named #{@entityListName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}."
              BRL::Genboree::GenboreeUtil.logError(msg, err)
              @apiError = BRL::Genboree::GenboreeError.new(@statusName, msg, err)
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_ENTITY_TYPE: The entity type #{@entityType.inspect} is the plural form of a known entity type and thus will have no entity lists associated with it. Perhaps it is not spelled correctly or is not in the plural form?"
          end
        end
      end
      # Update status info if there was an error along the way:
      (@statusName, @statusMsg = @apiError.type, @apiError.message) if(!@apiError.nil?)
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class
end ; end ; end # module BRL ; module REST ; module Resources
