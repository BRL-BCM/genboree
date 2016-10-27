#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/tabularLayoutEntity'
require 'brl/genboree/abstract/resources/tabularLayout'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # TabularLayouts - exposes information about the saved tabular layouts for
  # a group / database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::TabularLayoutEntityList
  # * BRL::Genboree::REST::Data::TextEntityList
  class TabularLayouts < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true }
    # An array to translate from the database version of the groupMode (0,1,2)
    # to the English strings ("", "terse", "verbose")
    GROUP_MODES = [ "", "terse", "verbose" ]

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
      # Look for /REST/v1/grp/{grp}/db/{db}/annos/layouts URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/annos/layouts$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      # Higher priority than grp/{grp}/db/{db}/annos
      return 8
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK)
          refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/annos/layout")

          # Get a list of all layouts for this db/group
          layoutRows = @dbu.selectAllLayouts()
          layoutRows.sort! { |left, right| left['name'].downcase <=> right['name'].downcase }

          if(@detailed)
            # Process the "detailed" list response
            bodyData = BRL::Genboree::REST::Data::TabularLayoutEntityList.new(@connect)
            layoutRows.each { |row|
              entity = BRL::Genboree::REST::Data::TabularLayoutEntity.new(@connect, row['name'], row['description'], row['userId'], row['createDate'], row['lastModDate'], row['columns'], row['sort'], GROUP_MODES[row['groupMode'].to_i])
              entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
              bodyData << entity
            }
          else
            # Process the undetailed (names only) list response
            bodyData = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
            layoutRows.each { |row|
              entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, row['name'])
              entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
              bodyData << entity
            }
          end
          @statusName = configResponse(bodyData)
          layoutRows.clear() unless (layoutRows.nil?)
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. NOTE: The put() request must
    # include a payload of a TabularLayoutEntity or it will be rejected as a
    # [+Bad Request+] by this resource.
    # [+returns+] Rack::Response instance
    def put()
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @dbName = Rack::Utils.unescape(@uriMatchData[2])
      initStatus = initOperation()
      initStatus = initGroupAndDatabase() if(initStatus == :OK)
      if(initStatus == :OK)
        # Check permission for inserts (must be author/admin of a group)
        if(@groupAccessStr == 'r')
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to create layouts in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        else
          # Get the entity from the HTTP request
          entity = parseRequestBodyForEntity('TabularLayoutEntity')
          if(entity.nil?)
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: To call PUT on this resource, the payload cannot be empty")
          elsif(entity == :'Unsupported Media Type')
            @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type TabularLayoutEntity")
          else
            # Make sure there are no name conflicts first
            if(BRL::Genboree::Abstract::Resources::TabularLayout.layoutNameExists(@dbu, entity.name))
              @apiError = BRL::Genboree::GenboreeError.new(:'Conflict', "DUPLICATE_NAME: There is already a layout in the database #{@dbName.inspect} called #{entity.name.inspect}")
            else
              # Insert the layout
              rowsInserted = @dbu.insertLayout(entity.name, entity.description, @userId, entity.columns, entity.sort, entity.groupMode)
              if(rowsInserted == 1)
                # Get the newly created layout to return
                newLayout = fetchLayout(entity.name)
                newLayout.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/annos/layout/#{Rack::Utils.escape(newLayout.name)}"))
                newLayout.setStatus(:'Created', "The layout #{entity.name.inspect} was successfully created in the database #{@dbName.inspect}")
                @statusName = configResponse(newLayout, :'Created')
              else
                @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create layout #{entity.name.inspect} in the database #{@dbName.inspect}")
              end
            end
          end
        end
      end

      # Respond with an error if appropriate
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Helper method to fetch a layout from the DB.
    # [+name+] The name of the desired saved layout.
    # [+returns+] TabularLayoutEntity or +nil+ if no layout exists by that name.
    def fetchLayout(name)
      layout = nil

      # Query the DB
      rows = @dbu.getLayoutByName(name)

      # Create this layout
      unless(rows.nil? or rows.empty?)
        layoutRow = rows.first
        layout = BRL::Genboree::REST::Data::TabularLayoutEntity.new(@connect, layoutRow['name'], layoutRow['description'], layoutRow['userId'], layoutRow['createDate'], layoutRow['lastModDate'], layoutRow['columns'], layoutRow['sort'], GROUP_MODES[layoutRow['groupMode'].to_i])
      end

      # Clean up
      rows.clear() unless(rows.nil?)

      return layout
    end
  end # class TabularLayouts
end ; end ; end # module BRL ; module REST ; module Resources
