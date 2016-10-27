#!/usr/bin/env ruby
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/queryEntity'
require 'brl/genboree/rest/data/entity'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # QueryFilter - applies and returns the response for the specified query
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::QueryEntity
  class QueryFilter < BRL::REST::Resources::GenboreeResource

    # INTERFACE: Map of what http methods this resource supports
    # ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'queryFilter'

    # Static Block
    # This resource requires special setup -- It must ensure that all of the
    # potential subclasses of BRL::Genboree::REST::Data::Builders::Builder have
    # already been loaded (all files in the Builders module/directory) in order
    # to support automatic discovery of resources.  This is done in this static
    # block to ensure it is performed only once.
    # @todo DELETE THIS
    # ---------------------------
    # ARJ: this builder class file discovery is handled by genboreeResource, which is
    #   required above. Should not redo here (and there is no redo-protection here, which is bad
    #   as written it will be run every time it is required...a waste of disk I/O as we search for files...)
    #begin
    #  $LOAD_PATH.each { |topLevel|
    #    rsrcFiles = Dir["#{topLevel}/brl/genboree/rest/data/builders/*.rb"]
    #    rsrcFiles.each { |rsrcFile|
    #      begin
    #        require rsrcFile
    #      rescue => err # just log error and try more files
    #        BRL::Genboree::GenboreeUtil.logError("ERROR: brl/genboree/rest/resources/queryFilter => failed to require file '#{rsrcFile.inspect}'.", err)
    #      end
    #    }
    #  }
    #  $stderr.debugPuts(__FILE__, __method__, "LOAD", "registered builder classes")
    #rescue => err
    #  BRL::Genboree::GenboreeUtil.logError("ERROR: brl/genboree/rest/resources/queryFilter => uncaught error during static block", err)
    #end

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      # variables exposed from call to initGroupAndDatabase() Helper
      @databaseName = @groupName = @groupId = @groupDesc = @groupAccessStr = @refseqRow = @refSeqId = nil
      # remove variables created by this class
      @userId = @dbName = @queryName = @apiError = @resource = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^(/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/.+)/query(?:$|/([^/\?]+)$)</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/.*/query (for RefEntity payloads)
      #       OR /REST/v1/grp/{grp}/db/{db}/.*/query/{query} URIs
      return %r{^(/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/.+)/query(?:$|/([^/\?]+)$)}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      # We want the query filter to have the lowest possible priority so that it
      # doesn't mistakingly grab URLs that should be designated to other resources
      # (ex] entities with name "query", or AVPs with attribute "query").
      return 7
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
        query = BRL::Genboree::REST::Data::QueryEntity.new(@connect, queryRow['name'], queryRow['description'], queryRow['query'], queryRow['user_id'])
      end

      # Clean up
      rows.clear() unless(rows.nil?)

      return query
    end

    # Overridden to meet our needs for matching resource list type.
    def initOperation()
      initStatus = super
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[2])
        @dbName = Rack::Utils.unescape(@uriMatchData[3])
        @queryName = (!@uriMatchData[4].nil?)? Rack::Utils.unescape(@uriMatchData[4]) : nil
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK )
          # Check for a matching query
          entity = parseRequestBodyForEntity('RefEntity')
          if(BRL::Genboree::Abstract::Resources::Query.queryExists(@dbu, @queryName)==false)
            if(entity.nil?)
              initStatus = @statusName = :'Not Found'
              @statusMsg = "NO_QUERY: The query #{@queryName.inspect} referenced in the API URL doesn't exist."
            end
          end

          # Now check what resource we will be using
          @resource = nil
          BRL::Genboree::REST::Data::Builders.constants.each { |constName|
            # Retrieve the Constant object
            const = BRL::Genboree::REST::Data::Builders.const_get(constName.to_sym)
            # The Constant object must be a Class and that Class must inherit
            # [ultimately] from BRL::REST::Resources::Resource
            next unless(const.is_a?(Class) and const.ancestors.include?(BRL::Genboree::REST::Data::Builders::Builder))

            # Test this resource using pattern() to determine if it can handle
            # this request or not.
            next if(const.pattern().nil?)
            @resource = const.new(@uriMatchData[1]) if(const.pattern().match(@uriMatchData[1]))
          }
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
        entity = nil
        #entity = parseRequestBodyAllFormats('RefEntity')
        entity = parseRequestBodyForEntity('RefEntity')

        refAccess = false
        if(!entity.nil? and (entity == :'Unsupported Media Type' or entity.resourceType != :Ref))
          if(@responseFormat.nil?)
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "Payload provided must be in the format specified by the URL.  To receive a response in different format than the payload, set responseFormat=[desired format].")
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_PAYLOAD: Payloads at this url must be RefEntities.")
          end
        elsif(entity and entity.resourceType == :Ref)
          oldDbName = @dbu.dataDbName
          # Process ref entity url: remove the ?, strip the http://,
          # then remove the host name so that what's left
          # is a proper url for pattern matching
          if(entity.url.index("http://")==0)
            url = entity.url.chomp("?")
            url = url[url.index('//')+2,url.length]
            url = url[url.index('/'),url.length]
          else
            url = entity.url.chomp("?")
          end
          queryUrl = BRL::REST::Resources::Query.pattern().match(url)
          if(queryUrl)
            urlGroupName = Rack::Utils.unescape(queryUrl[1])
            urlDBName = Rack::Utils.unescape(queryUrl[2])
            urlQueryName = Rack::Utils.unescape(queryUrl[3])
            dbRow = @dbu.selectRefseqByName(urlDBName)
            if(dbRow.length > 0)
              db = dbRow.first['databaseName']
              @dbu.setNewDataDb(db)
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "The Database #{dbName} specified in the url does not exist.")
            end
            genboreegroupRows = @dbu.selectGroupByName(urlGroupName)
            urlGroupId = genboreegroupRows.first['groupId']
            groupAccessStrRow = @dbu.getAccessByUserIdAndGroupId(@userId, urlGroupId)
            urlGroupAccessStr = ((groupAccessStrRow.nil? or groupAccessStrRow.empty?) ? nil : groupAccessStrRow['userGroupAccess'] )
            if(BRL::Genboree::Abstract::Resources::Query.queryExists(@dbu, urlQueryName))
              query = @dbu.getQueryByName(urlQueryName).first
              if(urlGroupAccessStr != 'o')
                if(query['user_id'] == -1 || query['user_id'] == @userId)
                  refAccess = true
                else
                  @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "You do not have access to this query.")
                end
              else
                refAccess = true
              end
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Not Found',"The query #{urlQueryName.inspect} specified in the RefEntity does not exist.")
            end
            @dbu.setNewDataDb(oldDbName)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "RefEntities must supply a query resource as their url.")
          end

        else
          query = @dbu.getQueryByName(@queryName).first
        end
        if(@apiError.nil? and (@groupAccessStr == 'o' || @userId == query['user_id'] || query['user_id'] == -1 || refAccess ))
          # This user has access to this query, so apply it to the appropriate resource

          # Use the @resource to apply the query
          # - response will be either chunked or String (from XxxBuilder.applyQuery())
          if(@resource.nil?)
            # URI was caught by our "pattern" but none of the subclasses that
            # we loaded have a proper way to handle this...
            @apiError = BRL::Genboree::GenboreeError.new(:'Not Implemented', "BAD_URL_OR_NOT_IMPLEMENTED: You have supplied a URL that was captured by the query filter but either has not yet been implemented, or does not refer to a valid resource list.")
          else
            # Run the query through the Builder class identified in initOperation()
            format = (!@responseFormat.nil?) ? @responseFormat : @repFormat
            layout = (!@layout.nil?) ? @layout : nil
            response = @resource.applyQuery(query['query'], @dbu, @refSeqId, @userId, @detailed, format, layout)
            if(response.is_a?(EntityList))
              configResponse(response)
            else
              # We must properly configure the response here
              # The returned builder object should be able to specify its own
              # content type correctly (via Builder.content_type() )
              if(response.error)
                # Error occurred, return error status
                @apiError = response.error
              else
                @resp.status = HTTP_STATUS_NAMES[:OK]
                @resp['Content-Type'] = response.content_type()
                @resp.body = response
              end
            end
          end
        elsif(@apiError.nil?)
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden',"ACCESS_DENIED: You don't have access to this query.")
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class QueryFilter
end ; end ; end # module BRL ; module REST ; module Resources
