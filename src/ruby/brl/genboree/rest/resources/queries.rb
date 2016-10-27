#!/usr/bin/env ruby
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/queryEntity'
require 'brl/genboree/abstract/resources/query'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Queries - exposes information about the saved tabular queries for
  # a group / database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::QueryEntityList
  # * BRL::Genboree::REST::Data::TextEntityList
  class Queries < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      # variables exposed from call to initGroupAndDatabase() Helper
      @databaseName = @groupName = @groupId = @groupDesc = @groupAccessStr = @refseqRow = @refSeqId = nil
      # remove variables created by this class
      @dbName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trks</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/queries | /REST/v1/grp/{grp}/db/{db}/queries/{query}/ownedBy | /REST/v1/grp/{grp}/db/{db}/queries/{query}/ownedBy/{usr} URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/queries(?:$|/(ownedBy)(?:$|/([^/\?]+)$))}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      # Higher priority than grp/{grp}/db/{db}/annos
      return 8
    end

    # Helper method to determine if a user is in the group supplied by the URL.
    def verifyUser(userName)
      retVal = false
      # Get group id and user id first
      groupRows = @dbu.selectGroupByName(@groupName)
      groupId = groupRows.first['groupId']
      userRows = @dbu.getUserByName(userName)
      if(userRows.length == 1)
        userId = userRows.first['userId']
        retVal = BRL::Genboree::GenboreeDBHelper.checkUserAllowed(userId, groupId,'r',@dbu)
      else
        retVal = false
      end
      return retVal
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @ownedBy = (@uriMatchData[3].nil?)? false : true
        @queriesOwner = (@uriMatchData[4].nil? == false)? Rack::Utils.unescape(@uriMatchData[4]) : nil
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK and !@ownedBy)
          refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/query")

          # Get a list of all queries for this db/group
          if(@groupAccessStr == 'o')
            queryRows = @dbu.selectAllQueries()
            unless(queryRows.nil?)
              queryRows.sort! { |left, right| left['name'].downcase <=> right['name'].downcase }
            end
          else
            rows = @dbu.getUserByName(@gbLogin)
            userId = (rows.length == 1)? rows.first['userId'] : nil
            
            queryRows = @dbu.getSharedAndPrivateQueries(userId)
            unless(queryRows.nil?)
              queryRows.sort! { |left, right| left['name'].downcase <=> right['name'].downcase }
            end
          end

          if(@detailed)
            # Process the "detailed" list response
            bodyData = BRL::Genboree::REST::Data::QueryEntityList.new(@connect)
            unless(queryRows.nil?)
              queryRows.each { |row|
                if(row['user_id']==-1)
                  shared = true
                  user = nil
                else
                  shared = false
                  user = row['user_id']
                end

                entity = BRL::Genboree::REST::Data::QueryEntity.new(@connect, row['name'], row['description'], row['query'], shared, user)
                entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
                bodyData << entity
              }
            end
          else
            # Process the undetailed (names only) list response
            bodyData = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
            unless(queryRows.nil?)
              queryRows.each { |row|
                entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, row['name'])
                entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
                bodyData << entity
              }
            end
          end
          @statusName = configResponse(bodyData)
          queryRows.clear() unless (queryRows.nil?)
        elsif(@ownedBy)
          entity = parseRequestBodyForEntity(['PartialUserEntity', 'DetailedUserEntity', 'DetailedGroupEntity', 'RefEntity'])
          
          if(entity == :'Unsupported Media Type')
            @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "This url cannot accept the media type you have provided.")
          elsif(entity.nil? and !@queriesOwner)
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "EMPTY PAYLOAD: This url requires a payload Partial/DetailedUserEntity, DetailedGroupEntity, or RefEntity.")
          elsif(entity and @queriesOwner)
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "Cannot provide a payload to this url.")
          elsif(entity and @queriesOwner.nil?)
            #process an entity
            isGroup = false
            isUser = false
            request = nil
            if(entity.resourceType == :Ref)
              # Process ref entity url: remove the ?, strip the http://,
              # then remove the host name so that what's left
              # is a proper url for pattern matching
              url = entity.url.chomp("?")
              url = url[url.index('//')+2,url.length]
              url = url[url.index('/'),url.length]
              groupUrl = BRL::REST::Resources::Group.pattern().match(url)
              userUrl = BRL::REST::Resources::User.pattern().match(url)
              if(!userUrl.nil?)
                request = (userUrl[2].nil?)? userUrl[3] : userUrl[2]
              elsif(!groupUrl.nil?)
                request = groupUrl[3]
              end
              if(!groupUrl and !userUrl)
                @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "This url can only accept Group and User urls in Ref Entities.")
              elsif(groupUrl)
                if(request != @groupName)
                  @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "This url can only be used to access queries in the group #{@groupName.inspect}.")
                else
                  # process
                  isGroup = true
                end
              elsif(userUrl)
                if(request != @gbLogin)
                  if(@groupAccessStr != 'o')
                    @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "You do not have access to other users' queries.")
                  else
                    # process
                    isUser = true
                  end
                else
                  if(!verifyUser(request))
                    @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "The user #{request.inspect} does not exist in #{@groupName.inspect}.") 
                  else
                    #process
                    isUser = true
                  end
                end
              end
            elsif(entity.resourceType == :GrpDetailed)
              # process a group entity
              request = entity.name
              if(request != @groupName)
                @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "This url can only be used to access queries in the group #{@groupName.inspect}.")
              else
                # process
                isGroup = true
              end
            elsif(entity.resourceType == :UsrDetailed or entity.resourceType == :UsrPartial)
              # process a user entity
              request = entity.login
              
              if(request != @gbLogin)
                if(@groupAccessStr != 'o')
                  @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "You do not have access to other users' queries.")
                else
                  # process
                  isUser = true
                end
              else
                if(!verifyUser(request))
                  @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "The user #{request.inspect} does not exist in #{@groupName.inspect}.")
                else
                  #process
                  isUser = true
                end
              end
            else
              # unsupported entity type
              @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "Incorrect entity type provided as payload for this url.")      
            end
            if(isUser)
              #userInGroup = BRL::Genboree::GenboreeDBHelper.checkUserAllowed(, @groupId,'r',@dbu)
              # Get the userid
              userRows = @dbu.getUserByName(request)
              if(userRows.length != 1)
                @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "The user id supplied in the entity is not a valid user id.")
              else
                userId = userRows.first['userId']
                refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/query")

                queryRows = @dbu.getQueriesByOwner(userId)
                queryRows.sort! { |left, right| left['name'].downcase <=> right['name'].downcase }
                if(@detailed)
                  # Process the "detailed" list response
                  bodyData = BRL::Genboree::REST::Data::QueryEntityList.new(@connect)
                  queryRows.each { |row|
                    entity = BRL::Genboree::REST::Data::QueryEntity.new(@connect, row['name'], row['description'], row['query'], false, row['user_id'])
                    entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
                    bodyData << entity
                  }
                  else
                    # Process the undetailed (names only) list response
                    bodyData = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
                    queryRows.each { |row|
                      entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, row['name'])
                      entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
                      bodyData << entity
                  }
                end
                @statusName = configResponse(bodyData)
                queryRows.clear() unless (queryRows.nil?)
              end 
            elsif(isGroup)
              refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/query")

              # Get a list of all shared queries for this db/group
              queryRows = @dbu.getSharedQueries()
              queryRows.sort! { |left, right| left['name'].downcase <=> right['name'].downcase }
              
              if(@detailed)
                # Process the "detailed" list response
                bodyData = BRL::Genboree::REST::Data::QueryEntityList.new(@connect)
                queryRows.each { |row|
                  if(row['user_id']==-1)
                    shared = true
                    user = nil
                  else
                    shared = false
                    user = row['user_id']
                  end

                  entity = BRL::Genboree::REST::Data::QueryEntity.new(@connect, row['name'], row['description'], row['query'], shared, user)
                  entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
                  bodyData << entity
                }
              else
                # Process the undetailed (names only) list response
                bodyData = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
                queryRows.each { |row|
                  entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, row['name'])
                  entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
                  bodyData << entity
                }
              end
              @statusName = configResponse(bodyData)
              queryRows.clear() unless (queryRows.nil?)
            end
             
          elsif(@queriesOwner)
          # Do a dumb check of whether user has access to the queries they want
            if((@groupAccessStr == 'o' or @gbLogin == @queriesOwner) and verifyUser(@queriesOwner) )
              # Get the userid
              userRows = @dbu.getUserByName(@queriesOwner)
              userId = userRows.first['userId']
              refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/query")
               
              queryRows = @dbu.getQueriesByOwner(userId)
              queryRows.sort! { |left, right| left['name'].downcase <=> right['name'].downcase }
              if(@detailed)
                # Process the "detailed" list response
                bodyData = BRL::Genboree::REST::Data::QueryEntityList.new(@connect)
                queryRows.each { |row|
                  entity = BRL::Genboree::REST::Data::QueryEntity.new(@connect, row['name'], row['description'], row['query'], false, row['user_id'])
                  entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
                  bodyData << entity
                }
                else
                  # Process the undetailed (names only) list response
                  bodyData = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
                  queryRows.each { |row|
                    entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, row['name'])
                    entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
                    bodyData << entity
                }
              end
              @statusName = configResponse(bodyData)
              queryRows.clear() unless (queryRows.nil?)

            elsif(!(@groupAccessStr == 'o' or @gbLogin == @queriesOwner) and verifyUser(@queriesOwner))
              # No access
              @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "You don't have access to other users queries.")
            else
              # Admin asked for a user that doesn't exist
              @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "The user #{@queriesOwner} does not exist in the group #{@groupName}.")
                         
            end
          end
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. NOTE: The put() request must
    # include a payload of a QueryEntity or it will be rejected as a
    # [+Bad Request+] by this resource.
    # [+returns+] Rack::Response instance
    def put()
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @dbName = Rack::Utils.unescape(@uriMatchData[2])
      @queriesOwner = (@uriMatchData[4].nil? == false)? Rack::Utils.unescape(@uriMatchData[4]) : nil
      @ownedBy = (@queriesOwner.nil? == false)? true : false
      initStatus = initOperation()
      initStatus = initGroupAndDatabase() if(initStatus == :OK)
      if(initStatus == :OK)
        # Check permission for inserts (must be author/admin of a group)
        if(@groupAccessStr == 'r')
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to create queries in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        else
          # Get the entity from the HTTP request
          entity = parseRequestBodyForEntity('QueryEntity')
          if(entity.nil?)
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request',"This URL must have payload of a QueryEntity.")
          elsif(entity == :'Unsupported Media Type')
            @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type QueryEntity")
          elsif(entity.resourceType == :Query)
            # Make sure there are no name conflicts first
            if(BRL::Genboree::Abstract::Resources::Query.queryExists(@dbu, entity.name))
              @apiError = BRL::Genboree::GenboreeError.new(:'Conflict', "DUPLICATE_NAME: There is already a query in the database #{@dbName.inspect} called #{entity.name.inspect}")
            else
              # Insert the query
              invalidPut = false
              userId = -1
              if(@ownedBy and @queriesOwner)
                if(@groupAccessStr == 'o' or @gbLogin == @queriesOwner )
                  rows = @dbu.getUserByName(@queriesOwner)
                  userId = (rows.length == 1)? rows.first['userId'] : nil
                else
                  invalidPut = true
                end
              elsif(@ownedBy)
                @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "This URL cannot be used to insert queries.")
              end
              if(!invalidPut)
                rowsInserted = @dbu.insertQuery(entity.name, entity.description, entity.query, userId)
                if(rowsInserted == 1)
                  # Get the newly created query to return
                  newQuery = fetchQuery(entity.name)
                  newQuery.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/query/#{Rack::Utils.escape(newQuery.name)}"))
                  newQuery.setStatus(:'Created', "The query #{entity.name.inspect} was successfully created in the database #{@dbName.inspect}")
                  @statusName = configResponse(newQuery, :'Created')
                else
                  @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create query #{entity.name.inspect} in the database #{@dbName.inspect}")
                end
              else
                @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "You don't have access to assign queries to the user #{@queriesOwner}.")
              end
            end
          end
        end
      end

      # Respond with an error if appropriate
      @resp = representError() if(@statusName != :OK)
      return @resp
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
  end # class Queries
end ; end ; end # module BRL ; module REST ; module Resources
