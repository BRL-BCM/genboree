#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # TabularLayoutAttributes - exposes information about the attributes
  # of a saved tabular layout
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::TextEntity
  class TabularLayoutAttributes < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources
    
    # INTERFACE: Map of what http methods this resource supports 
    # ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = {:get => true, :put => true} 
    # An array to translate from the database version of the groupMode (0,1,2)
    # to the English strings ("", "terse", "verbose")
    GROUP_MODES = ["", "terse", "verbose"]

    #  An array containing which attributes are read only. Check this in the 'put'
    #  method.
    READ_ONLY_ATTRIBUTES = ["created", "modified", "userId"]
    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      # variables exposed from call to initGroupAndDatabase() Helper
      @databaseName = @groupName = @groupId = @groupDesc = @groupAccessStr = @refseqRow = @refSeqId = nil
      # remove variables created by this class
      @dbName = @layoutName = @layoutAttr = @layoutId = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/layout/([^/\?]+)</tt>
    def self.pattern()
       # Look for /REST/v1/grp/{grp}/db/{db}/layout/{layout}/attribute/{attribute} URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/annos/layout/([^/\?]+)/attribute/([^/\?]+)$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      # Higher priority than grp/{grp}/db/{db}/annos/layout/{layout}
      return 9
    end

    def initOperation()
      initStatus = super
       
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @layoutName = Rack::Utils.unescape(@uriMatchData[3])
        @layoutAttr = Rack::Utils.unescape(@uriMatchData[4])
        @layoutId = nil
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK)
          rows = @dbu.getLayoutByName(@layoutName)
          if(rows.nil? or rows.empty?)
            initStatus = @statusName = :'Not Found'
            @statusMsg = "NO_LAYOUT: The layout '#{@layoutName}' referenced in the API URL doesn't exist"
          else
            layoutRow = rows.first
            @layoutId = layoutRow['id']
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
        # Get the specified attribute from the appropriate layout
        attribute = nil
        rows = @dbu.getLayoutByName(@layoutName)
        layoutRow = rows.first

        # Create appropriate response
        if(@layoutAttr == 'groupMode')
          attribute = BRL::Genboree::REST::Data::TextEntity.new(@connect, GROUP_MODES[layoutRow['groupMode'].to_i])
        else
          attribute = BRL::Genboree::REST::Data::TextEntity.new(@connect, layoutRow[@layoutAttr])
        end

        # Configure the response
        @statusName = configResponse(attribute)
        rows.clear() unless(rows.nil?)
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
        @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to modify layouts in database #{@dbName.inspect} in user group #{@groupName.inspect}")
      # Check for write permission on the attribute
      elsif(READ_ONLY_ATTRIBUTES.include?(@layoutAttr))
        @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "The attribute #{@layoutAttr} you are trying to modify is read-only.")
      else
        # Get the entity from the HTTP request for the next two cases
        entity = parseRequestBodyForEntity('TextEntity')
        if(entity.nil?)
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: You must include a TextEntity payload for PUT operations on this resource")
        elsif(entity == :'Unsupported Media Type')
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type TextEntity")
        else
          # Perform an update on this attribute
          if(@layoutAttr == 'name')
            # If the attribute being modified is the layout's name, check its uniqueness
            nameUniqueness = @dbu.getLayoutByName(entity.text)
            unless(nameUniqueness.empty?)
              @apiError = BRL::Genboree::GenboreeError.new(:'Conflict', "The layout name #{entity.text} you have specified conflicts with an existing layout in the database.")
            end
          end

          # Get the unmodified layout for the original value.
          # This will provide for more accurate feedback after the update.
          rows = @dbu.getLayoutByName(@layoutName)
          layoutRow = rows.first
          # Initialize values for update to nil
          layoutName = description = columns = sort = groupMode = nil
          # Set the appropriate value
          if(@layoutAttr == 'name')
            layoutName = entity.text 
          elsif(@layoutAttr == 'description')
            description = entity.text
          elsif(@layoutAttr == 'columns')
            columns = entity.text
          elsif(@layoutAttr == 'sort')
            sort = entity.text
          elsif(@layoutAttr == 'groupMode')
            groupMode = entity.text
          end

          # Check status again after name uniqueness check. Update the layout
          if(@statusName == :OK)
            rowsUpdated = @dbu.updateLayout(@layoutId, layoutName, description, columns, sort, groupMode)
            if(rowsUpdated == 1)
              respBody = BRL::Genboree::REST::Data::TextEntity.new(@connect, entity.text)
              if(@layoutAttr == 'name')
                @statusMsg = "The layout #{@layoutName} was successfully renamed to #{entity.text}."
                @statusName = :'Moved Permanently'
                respBody.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/annos/layout/#{Rack::Utils.escape(entity.text)}"))
              else
                @statusMsg = "The layout attribute '#{@layoutAttr}' was successfully modified in the layout '#{@layoutName}' from '#{layoutRow[@layoutAttr]}' to '#{entity.text}'"
              end
              respBody.setStatus(@statusName, @statusMsg)
              configResponse(respBody, @statusName)
            else
              @apiCaller = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to modify the layout '#{@layoutName}' in the database '#{@dbName.inspect}'")
            end
          end
        end
      end

      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end 
  end # class TabularLayoutAttributes
end ; end ; end # module BRL ; module REST ; module Resources
