#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/tabularLayoutEntity'
require 'brl/genboree/abstract/resources/tabularLayout'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # TabularLayout - exposes information about a saved tabular layout
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::TabularLayoutEntity
  class TabularLayout < BRL::REST::Resources::GenboreeResource
    
    # INTERFACE: Map of what http methods this resource supports 
    # ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true } 
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
      @dbName = @layoutName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/layout/([^/\?]+)</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/annos/layout/{layout} URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/annos/layout/([^/\?]+)$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      # Higher priority than grp/{grp}/db/{db}/annos
      return 8
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

    def initOperation()
      initStatus = super
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @layoutName = Rack::Utils.unescape(@uriMatchData[3])
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK)
          unless(BRL::Genboree::Abstract::Resources::TabularLayout.layoutNameExists(@dbu, @layoutName))
            initStatus = @statusName = :'Not Found'
            @statusMsg = "NO_LAYOUT: The layout #{@layoutName.inspect} referenced in the API URL doesn't exist"
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
        # Get this layout
        layout = fetchLayout(@layoutName)

        # Configure the response
        @statusName = configResponse(layout)
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
        @statusMsg = "You do not have access to create layouts in database #{@dbName.inspect} in user group #{@groupName.inspect}"
      else
        # Get the entity from the HTTP request
        entity = parseRequestBodyForEntity('TabularLayoutEntity')
        if(entity == :'Unsupported Media Type')
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_PAYLOAD: The payload is not of type TabularLayoutEntity")
        elsif(entity.nil? and initStatus == :'OK')
          # Cannot update a layout with a nil entity
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "EMPTY_PAYLOAD_ON_UPDATE: You must supply a payload when performing an update")
        elsif(entity.nil? and initStatus == :'Not Found')
          # Insert a layout with default values
          rowsInserted = @dbu.insertLayout(@layoutName, "", @userId)
          if(rowsInserted == 1)
            newLayout = fetchLayout(@layoutName)
            newLayout.setStatus(:Created, "The layout #{@layoutName.inspect} was successfully created in the database #{@dbName.inspect}")
            @statusName = configResponse(newLayout, :Created)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create layout #{@layoutName.inspect} in the database #{@dbName.inspect}")
          end
        elsif(entity != nil and entity.name != @layoutName and BRL::Genboree::Abstract::Resources::TabularLayout.layoutNameExists(@dbu, entity.name))
          # Name Conflict - don't try insert (when :'Not Found') or update (when :OK)
          @apiError = BRL::Genboree::GenboreeError.new(:'Conflict', "DUPLICATE_NAME: There is already a layout in the database #{@dbName.inspect} called #{entity.name.inspect}")
        elsif(entity != nil and initStatus == :'Not Found')
          # (at this point we are certain that the name will not conflict)
          # Check to make sure @layoutName and entity.name from request are both the same
          if(entity.name == @layoutName)
            # Insert the layout
            rowsInserted = @dbu.insertLayout(entity.name, entity.description, @userId, entity.columns, entity.sort, entity.groupMode)
            if(rowsInserted == 1)
              newLayout = fetchLayout(@layoutName)
              newLayout.setStatus(:Created, "The layout #{@layoutName.inspect} was successfully created in the database #{@dbName.inspect}")
              @statusName = configResponse(newLayout, :Created)
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create layout #{@layoutName.inspect} in the database #{@dbName.inspect}")
            end
          else
            # @layoutName and entity.name are not the same, don't insert
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: You cannot use this URL to insert a layout of a different name")
          end
        elsif(entity != nil and initStatus == :OK)
          # Layout exists, so update it
          layoutRow = @dbu.getLayoutByName(@layoutName)
          layoutId = layoutRow.first['id']
          rowsUpdated = @dbu.updateLayout(layoutId, entity.name, entity.description, entity.columns, entity.sort, entity.groupMode)
          if(rowsUpdated == 1)
            if(entity.name == @layoutName)
              changedLayout = fetchLayout(@layoutName)
              changedLayout.setStatus(:OK, "The layout #{@layoutName.inspect} has been successfully updated")
              changedLayout.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/annos/layout/#{Rack::Utils.escape(changedLayout.name)}"))
              @statusName = configResponse(changedLayout)
            else
              renamedLayout = fetchLayout(entity.name)
              renamedLayout.setStatus(:'Moved Permanently', "The layout #{@layoutName.inspect} has been renamed to #{entity.name.inspect}")
              renamedLayout.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/annos/layout/#{Rack::Utils.escape(renamedLayout.name)}"))
              @statusName = configResponse(renamedLayout, :'Moved Permanently')
            end
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to update layout #{@layoutName.inspect} in the database #{@dbName.inspect}")
          end
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to PUT to this resource")
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
         
      if(initStatus == :OK)
        if(@groupAccessStr != 'o')
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to delete layouts in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        else
          # Find the layout to be deleted
          layoutRow = @dbu.getLayoutByName(@layoutName)
          layoutId = layoutRow.first['id']
          numRows = @dbu.deleteLayoutById(layoutId)
          if(numRows == 1)
            entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
            entity.setStatus(:OK, "The layout #{@layoutName.inspect} was successfully deleted from the database #{@dbName.inspect}")
            @statusName = configResponse(entity)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem deleting the layout #{@layoutName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}")
          end
        end
      end

      # If something wasn't right, represent as error    
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class TabularLayout
end ; end ; end # module BRL ; module REST ; module Resources
