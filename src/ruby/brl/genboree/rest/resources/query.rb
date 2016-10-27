#!/usr/bin/env ruby
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/queryEntity'
require 'brl/genboree/abstract/resources/query'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Query - exposes information about a saved tabular query
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::QueryEntity
  class Query < BRL::REST::Resources::GenboreeResource
    
    # INTERFACE: Map of what http methods this resource supports 
    # ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true } 

    # Accepted Entity Types for PUT
    ENTITY_TYPES = [ 'TextEntity', 'PartialUserEntity', 'DetailedUserEntity', 'DetailedGroupEntity', 'RefEntity' ]
    
    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      # variables exposed from call to initGroupAndDatabase() Helper
      @databaseName = @groupName = @groupId = @groupDesc = @groupAccessStr = @refseqRow = @refSeqId = nil
      # remove variables created by this class
      @dbName = @queryName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/query/([^/\?]+)</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/query/{query} | /REST/v1/grp/{grp}/db/{db}/query/{query}/ownedBy/{usr} URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/query/([^/\?]+)(?:$|/(ownedBy)(?:$|/([^/\?]+)$))}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      # Higher priority than grp/{grp}/db/{db}/annos
      return 8
    end

    # Helper method to fetch a query from the DB.
    # [+name+] The name of the desired saved query.
    # [+returns+] QueryEntity or +nil+ if no query exists by that name.
    def fetchQuery(name)
      query = nil
      
      # Query the DB
      rows = @dbu.getQueryByName(name)

      # Create this query
      unless(rows.nil? or rows.empty?)
        queryRow = rows.first
        if(queryRow['user_id']==-1)
          shared = true
          user = nil
        else
          shared = false
          user = queryRow['user_id']
        end 
        query = BRL::Genboree::REST::Data::QueryEntity.new(@connect, queryRow['name'], queryRow['description'], queryRow['query'], shared, user)
      end

      # Clean up
      rows.clear() unless(rows.nil?)

      return query
    end

    def initOperation()
      initStatus = super
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @queryName = Rack::Utils.unescape(@uriMatchData[3])
        @ownedBy = (@uriMatchData[4].nil?)? false : true
        @queryOwner = (@uriMatchData[5].nil?)? nil : Rack::Utils.unescape(@uriMatchData[5])
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK )
          unless(BRL::Genboree::Abstract::Resources::Query.queryExists(@dbu, @queryName))
            initStatus = @statusName = :'Not Found'
            @statusMsg = "NO_QUERY: The query #{@queryName.inspect} referenced in the API URL doesn't exist."
          end
        end
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # [+returns+] Rack::Response instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        # Get this query
        if(@ownedBy and @queryOwner)
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', 'BAD_REQUEST: The GET operation is not supported by this url.')
        elsif(@ownedBy and !@queryOwner)
          refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/queries/ownedBy")
          ownerName = BRL::Genboree::Abstract::Resources::Query.fetchQueryOwner(@dbu,@queryName)
          owner = BRL::Genboree::REST::Data::TextEntity.new(@connect, ownerName)
          ownerId = owner.text
          rows = @dbu.getUserByName(@gbLogin)
          requester = (rows.length == 1)? rows.first['userId'] : nil
 
          if(@groupAccessStr != 'o')
            if(ownerId == requester || ownerId == "Shared")
              if(ownerId != "Shared" && @detailed)
                userRow = @dbu.getUserByUserId(owner.text)
                userName = userRow.first['name']
                owner.makeRefsHash("#{refBase}/#{Rack::Utils.escape(userName)}")
              end
              @statusName = configResponse(owner)
            elsif(@groupAccess == 'r' || ownerId != requester)
              @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', 'You do not have access to this query.')
            end
          else  
            if(ownerId != "Shared" && @detailed)
              userRow = @dbu.getUserByUserId(owner.text)
              userName = userRow.first['name']
              owner.makeRefsHash("#{refBase}/#{Rack::Utils.escape(userName)}")
            end
            @statusName = configResponse(owner)
          end
        elsif(!@ownedBy)
          refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/query")
          query = fetchQuery(@queryName)
          rows = @dbu.getUserByName(@gbLogin)
          requester = (rows.length == 1)? rows.first['userId'] : nil

          if(@groupAccessStr != 'o')
            if(!query.shared and requester != query.userId)
              @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', 'You do not have access to this query.')
            elsif(requester == query.userId || query.shared)
              # Configure the response
              if(@detailed)
                query.makeRefsHash("#{refBase}/#{Rack::Utils.escape(query.name)}")
              end
              @statusName = configResponse(query)
            end
          else
            # Configure the response
            if(@detailed)
              query.makeRefsHash("#{refBase}/#{Rack::Utils.escape(query.name)}")
            end
            @statusName = configResponse(query)
          end
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
    
    # Process a PUT operation on this resource.
    # [+returns+] Rack::Response instance
    def put()
      initStatus = initOperation()

      # Check permission for inserts (must be author/admin of a group)
      if(@groupAccessStr == 'r')
        initStatus = @statusName = :'Forbidden'
        @statusMsg = "You do not have access to create querys in database #{@dbName.inspect} in user group #{@groupName.inspect}"
      else
        if(@ownedBy and @queryOwner)
        # handle query/{query}/ownedBy/{usr}
          if(@groupAccessStr == 'o')
          # User is admin, can change ownership
            rows = @dbu.getUserByName(@queryOwner)
            newOwner = (rows.length == 1)? rows.first['userId'] : nil
            userInGroup = BRL::Genboree::GenboreeDBHelper.checkUserAllowed(newOwner, @groupId,'r',@dbu)
            $stderr.puts "Testing if user #{@queryOwner}, #{newOwner} is in group." 
            if(!userInGroup)
              # Specified a non-existent user
              @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "The user #{@queryOwner} does not exist in the group #{@groupName.inspect}.")
            else
              # Update query with new owner
              row = @dbu.getQueryByName(@queryName)
              query = row.first
              secondRow = @dbu.getUserByName(@queryOwner)
              oldOwner = secondRow.first['userId']
              rowsUpdated = @dbu.updateQuery(query['id'],query['name'],query['description'],query['query'],newOwner)
              if((rowsUpdated == 1 and newOwner != oldOwner) || (newOwner == oldOwner))
                # Success: newOwner == oldOwner covers the possibility that the user was trying to provide a different owner that was in fact the same as the current owner,
                # which is a legal PUT, but will result in rowsUpdated = 0
                changedQuery = fetchQuery(@queryName)
                changedQuery.setStatus(:OK, "The query #{@queryName.inspect} has been successfully updated with new owner #{@queryOwner.inspect}.")
                changedQuery.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/query/#{Rack::Utils.escape(changedQuery.name)}"))
                @statusName = configResponse(changedQuery)
              else
                # DB error
                @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to update query #{@queryName.inspect} in the database #{@dbName.inspect}")
              end
            end
          else
          # No one else can change ownership
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', 'Only Group admins can change ownership through this URL.')
          end
        elsif(@ownedBy)
        # handle query/{query}/ownedBy
          if(@groupAccessStr =='o')
            # No need to check ownership, admin can perform a put here
            # First check what type of entity was put
            entity = ''
            entity = parseRequestBodyForEntity(ENTITY_TYPES)
            if(entity == :'Unsupported Media Type')
              @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_PAYLOAD: The payload is not an accepted Entity type.")
            elsif(entity.nil?)
              @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', 'BAD_REQUEST: This URL requires a payload.')
            else
              invalidGroup = false
              newOwnerText = ''
              if(entity.resourceType == :Txt)
                # Process a Text entity
                rows = @dbu.getUserByName(userName)
                newOwner = (rows.length == 1)? rows.first['userId'] : nil
                newOwnerText = entity.text   
              elsif(entity.resourceType == :UsrDetailed or entity.resourceType == :UsrPartial)
                # Process a User entity
                rows = @dbu.getUserByName(userName)
                newOwner = (rows.length == 1)? rows.first['userId'] : nil
                newOwnerText = entity.login
              elsif(entity.resourceType == :GrpDetailed)
                # Process a Group entity
                if(entity.name == @groupName)
                  newOwner = -1
                  newOwnerText = @groupName
                else
                  invalidGroup = true
                end
              elsif(entity.resourceType == :Ref)
                # Process ref entity url: remove the ?, strip the http://,
                # then remove the host name so that what's left 
                # is a proper url for pattern matching
                url = entity.url.chomp("?")
                url = url[url.index('//')+2,url.length]
                url = url[url.index('/'),url.length]
                
                groupUrl = BRL::REST::Resources::Group.pattern().match(url)
                userUrl = BRL::REST::Resources::User.pattern().match(url)
                if(groupUrl)
                  group = groupUrl[3]
                  if(group != @groupName)
                    invalidGroup = true
                  else
                    newOwner = -1
                    newOwnerText = @groupName
                  end
                elsif(userUrl)
                  userName = userUrl[3]
                  rows = @dbu.getUserByName(userName)
                  newOwner = (rows.length == 1)? rows.first['userId'] : nil
                  newOwnerText = userName
                end
              end
              if(!invalidGroup and !newOwner.nil?)
                # Update query with new owner
                row = @dbu.getQueryByName(@queryName)
                query = row.first
                oldOwner = query['user_id']
                rowsUpdated = @dbu.updateQuery(query['id'],query['name'],query['description'],query['query'],newOwner)
                if(rowsUpdated == 1 and newOwner != oldOwner)
                  # Success
                  changedQuery = fetchQuery(@queryName)
                  if(entity.resourceType != :GrpDetailed)
                    changedQuery.setStatus(:OK, "The query #{@queryName.inspect} has been successfully updated with new owner #{newOwnerText.inspect}.")
                  else
                    changedQuery.setStatus(:OK, "The query #{@queryName.inspect} has been successfully shared with the group #{newOwnerText.inspect}.")
                  end
                  changedQuery.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/query/#{Rack::Utils.escape(changedQuery.name)}"))
                  @statusName = configResponse(changedQuery)
                elsif(newOwner == oldOwner)
                  changedQuery = fetchQuery(@queryName)
                  changedQuery.setStatus(:OK, "The query #{@queryName.inspect} has been successfully updated with new owner #{newOwnerText.inspect}.")
                  changedQuery.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/query/#{Rack::Utils.escape(changedQuery.name)}"))
                  @statusName = configResponse(changedQuery)
                end
              elsif(invalidGroup)
                @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request','BAD REQUEST: This URL cannot be used to change group ownership.')
              elsif(newOwner.nil?)
                @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "The user #{@queryOwner} does not exist in the group #{@groupName.inspect}.")

              else
                # DB error
                @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to update query #{@queryName.inspect} in the database #{@dbName.inspect}")
              end
            end  
          else
            # Get the query to check ownership
            row = @dbu.getQueryByName(@queryName)
            query = row.first
            rows = @dbu.getUserByName(userName)
            requester = (rows.length == 1)? rows.first['userId'] : nil

            if(query['user_id'] == requester) 
              # If put is made by owner who is not an admin, must be of type group entity to share (can't change ownership to a different user)
              entity = parseRequestBodyForEntity(['DetailedGroupEntity','RefEntity'])
              if(entity == :'Unsupported Media Type' || entity.nil?)
                @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_PAYLOAD: The payload supplied must be a DetailedGroupEntity or a RefEntity.")
              elsif(entity.resourceType == :Ref)
                # Process ref entity url: remove the ?, strip the http://,
                # then remove the host name so that what's left 
                # is a proper url for pattern matching
                url = entity.url.chomp("?")
                url = url[url.index('//')+2,url.length]
                url = url[url.index('/'),url.length]
                
                groupUrl = BRL::REST::Resources::Group.pattern().match(url)
                if(!groupUrl)
                  @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request',"RefEntity must contain a URL that references a group.")
                else
                  group = groupUrl[3]
                  if(group != @groupName)
                    @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: This URL can only be used to share queries and cannot be used to move a query to a different group.")
                  else
                    rowsUpdated = @dbu.updateQuery(query['id'],query['name'],query['description'],query['query'],-1)
                    if(rowsUpdated == 1)
                      # Success
                      changedQuery = fetchQuery(@queryName)
                      changedQuery.setStatus(:'Moved Permanently', "The query #{@queryName.inspect} has been successfully updated and shared with the group #{@groupName.inspect}.")
                      changedQuery.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/query/#{Rack::Utils.escape(changedQuery.name)}"))
                      @statusName = configResponse(changedQuery)
                    else
                      @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to update query #{@queryName.inspect} in the database #{@dbName.inspect}")
                    end
                  end
                end
              elsif(entity.resourceType == :GrpDetailed && entity.name != @groupName)
                @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: This URL can only be used to share queries and cannot be used to move a query to a different group.")
              else
                rowsUpdated = @dbu.updateQuery(query['id'],query['name'],query['description'],query['query'],-1)
                if(rowsUpdated == 1)
                  # Success
                  changedQuery = fetchQuery(@queryName)
                  changedQuery.setStatus(:'Moved Permanently', "The query #{@queryName.inspect} has been successfully updated and shared with the group #{@groupName.inspect}.")
                  changedQuery.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/query/#{Rack::Utils.escape(changedQuery.name)}")) 
                  @statusName = configResponse(changedQuery)
                else
                  # DB error
                  @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to update query #{@queryName.inspect} in the database #{@dbName.inspect}")
                end
              end
            elsif(query['user_id'] != requester)
              @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "NO_ACCESS: You do not have access to share this query.")
            end
          end
        else
          # Handle query/{query}
          # Get the entity from the HTTP request
          entity = parseRequestBodyForEntity('QueryEntity')
          if(entity == :'Unsupported Media Type')
            @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_PAYLOAD: The payload is not of type QueryEntity")
          elsif(entity.nil? and initStatus == :'OK')
            # Cannot update a query with a nil entity
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "EMPTY_PAYLOAD_ON_UPDATE: You must supply a payload when performing an update")
          elsif(entity.nil? and initStatus == :'Not Found')
            # Insert a query with default values
            rows = @dbu.getUserByName(@gbLogin)
            userId = (rows.length == 1)? rows.first['userId'] : nil
            
            rowsInserted = @dbu.insertQuery(@queryName, "", "", userId)
            if(rowsInserted == 1)
              newQuery = fetchQuery(@queryName)
              newQuery.setStatus(:Created, "The query #{@queryName.inspect} was successfully created in the database #{@dbName.inspect}")
              @statusName = configResponse(newQuery, :Created)
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create query #{@queryName.inspect} in the database #{@dbName.inspect}")
            end
          elsif(entity != nil and entity.name != @queryName and BRL::Genboree::Abstract::Resources::Query.queryExists(@dbu, entity.name))
            # Name Conflict - don't try insert (when :'Not Found') or update (when :OK)
            @apiError = BRL::Genboree::GenboreeError.new(:'Conflict', "DUPLICATE_NAME: There is already a query in the database #{@dbName.inspect} called #{entity.name.inspect}")
          elsif(entity != nil and initStatus == :'Not Found')
            # (at this point we are certain that the name will not conflict)
            # Check to make sure @queryName and entity.name from request are both the same
            if(entity.name == @queryName)
              # Insert the query
             
              if(entity.shared)
                userId = -1
              elsif(!entity.shared)
                if(!entity.userId.nil?)
                  userInGroup = BRL::Genboree::GenboreeDBHelper.checkUserAllowed(entity.userId, @groupId,'r',@dbu)
                  if(!userInGroup)
                    @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "The user id supplied in the entity is not a valid user id.")
                    invalid = true
                  else
                    userId = entity.userId
                  end
                else
                  rows = @dbu.getUserByName(@gbLogin)
                  userId = (rows.length == 1)? rows.first['userId'] : nil
                end
              end

              if(!invalid)
                rowsInserted = @dbu.insertQuery(entity.name, entity.description, entity.query, userId )
                if(rowsInserted == 1)
                  newQuery = fetchQuery(@queryName)
                  newQuery.setStatus(:Created, "The query #{@queryName.inspect} was successfully created in the database #{@dbName.inspect}")
                  @statusName = configResponse(newQuery, :Created)
                else
                  @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create query #{@queryName.inspect} in the database #{@dbName.inspect}")
                end
              end
            else
              # @queryName and entity.name are not the same, don't insert
              @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: You cannot use this URL to insert a query of a different name")
            end
          elsif(entity != nil and initStatus == :OK)
            # Query exists, so update it

            queryRow = @dbu.getQueryByName(@queryName)
            queryId = queryRow.first['id']
            query = queryRow.first
            
            rows = @dbu.getUserByName(@gbLogin)
            requester = (rows.length == 1)? rows.first['userId'] : nil
             
            if(@groupAccessStr =='o' || requester.to_i == query['user_id'].to_i)
              if(@groupAccessStr == 'o')
                # Check if entity was previously shared
                if(query['user_id']==-1)
                  # If entity.userId != -1 unshare query, else keep it shared
                  if(entity.userId != -1 and !entity.userId.nil?)
                    userInGroup = BRL::Genboree::GenboreeDBHelper.checkUserAllowed(entity.userId, @groupId,'r',@dbu)
                    if(!userInGroup)
                      @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "The user id supplied in the entity is not a valid user id.")
                    else
                      newUserId = entity.userId
                    end
                  else
                    newUserId = -1
                  end
                elsif(query['user_id'] != -1 && entity.shared)
                  # Attempting to share query
                  newUserId = -1
                elsif(query['user_id'] != -1 && entity.userId != query['user_id'])
                  userInGroup = BRL::Genboree::GenboreeDBHelper.checkUserAllowed(entity.userId, @groupId,'r',@dbu)
                  if(!userInGroup)
                    @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "The user id supplied in the entity is not a valid user id.")
                  else
                    newUserId = entity.userId
                  end                 
                end
              elsif(requester == query['user_id'])
                if(!entity.shared)
                  if(query['user_id'] == -1)
                    @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden',"Only admins have the ability to un-share a query.")
                  elsif(entity.userId != query['user_id'])
                    @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "You cannot change ownership of this query.")
                  elsif(entity.userId == query['user_id'])
                    newUserId = entity.userId
                  end
                elsif(entity.shared)
                  newUserId = -1
                end
              else
                @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden',"You do not have access to modify this query.")
              end
              
              unless(@apiError)
                rowsUpdated = @dbu.updateQuery(queryId, entity.name, entity.description, entity.query, newUserId)
              end

              if(entity.name == query['name'] && entity.description == query['description'] && entity.query == query['query'] && newUserId.to_i == query['user_id'].to_i && rowsUpdated != 1)
                valid = true
              end
              
              if(@apiError.nil? && (rowsUpdated == 1 || valid))
                if(entity.name == @queryName)
                  changedQuery = fetchQuery(@queryName)
                  changedQuery.setStatus(:OK, "The query #{@queryName.inspect} has been successfully updated")
                  changedQuery.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/query/#{Rack::Utils.escape(changedQuery.name)}"))
                  @statusName = configResponse(changedQuery)
                else
                  renamedQuery = fetchQuery(entity.name)
                  renamedQuery.setStatus(:'Moved Permanently', "The query #{@queryName.inspect} has been renamed to #{entity.name.inspect}")
                  renamedQuery.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/query/#{Rack::Utils.escape(renamedQuery.name)}"))
                  @statusName = configResponse(renamedQuery, :'Moved Permanently')
                end
              elsif(@apiError.nil?)
                @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to update query #{@queryName.inspect} in the database #{@dbName.inspect}")
              end
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden',"You do not have access to update this query.")
            end
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to PUT to this resource")
          end
        end
      end

      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
    
    # Process a DELETE operation on this resource.
    # [+returns+] Rack::Response instance
    def delete()
      initStatus = initOperation()
         
      if(initStatus == :OK and !(@queryOwner || @ownedBy))
        queryRows = @dbu.getQueryByName(@queryName)
        queryRow = queryRows.first
        
        if(@groupAccessStr == 'r'  )
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to delete queries in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        elsif(@groupAccessStr == 'o' || @userId == queryRow['user_id'])
          
          queryId = queryRow['id']
          numRows = @dbu.deleteQueryById(queryId)
          if(numRows == 1 and queryRow)
            entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
            entity.setStatus(:OK, "The query #{@queryName.inspect} was successfully deleted from the database #{@dbName.inspect}")
            @statusName = configResponse(entity)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem deleting the query #{@queryName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}")
          end
        elsif(@userId != queryRow['user_id'])
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden',"You do not have access to delete the query #{@queryName.inspect}.")
        end
      elsif(initStatus == :'Not Found')
        @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "The query #{@queryName.inspect} was not found in the database #{@dbName.inspect}.")
      elsif(@ownedBy)
        @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "This URL cannot be used to delete.")
      end

      # If something wasn't right, represent as error    
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class Query
end ; end ; end # module BRL ; module REST ; module Resources
