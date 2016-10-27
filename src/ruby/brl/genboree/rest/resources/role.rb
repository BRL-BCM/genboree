#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/abstract/resources/role'
require 'brl/genboree/rest/data/roleEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Role - exposes information about the permission (well, role) of a user within a group.
  # @note @@gbLogin@ must be an _administrator_ of the group to access this resource, UNLESS
  #   @@gbLogin@ is requesting information about their own access role (@gbLogin == @rsrcUserName)
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::ProjectLinkEntityList
  class Role < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    UNLOCKABLE = false

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @rsrcUserName = @rsrcUserId = @groupId = @groupName = @rsrcUserRoleName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this service
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^(?:(?:/REST/#{VER_STR}/grp/([^/\?]+)/usr/([^/\?]+)/role))$</tt>
    def self.pattern()
      return %r{^(?:(?:/REST/#{VER_STR}/grp/([^/\?]+)/usr/([^/\?]+)/role))$} # Look for /REST/v1/grp/{grp}/usr/{usr}/role
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/service is
    # highly specific and should be examined early on, or whether it is more generic and
    # other services should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 3          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    # OVERRIDE: Do extra initialization to extract instance vars from uri:
    # - @groupName
    # - @rsrcUserName
    # - @rsrcUserId
    # [+returns+] The status codo to indicate any errors (as set in @statusName)
    def initOperation()
      initStatus = super
      # initialize useful instance vars for the resource
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @rsrcUserName = Rack::Utils.unescape(@uriMatchData[2])
        initStatus = initGroup()
        if(initStatus == :OK)
          if(@groupAccessStr == 'o' or @rsrcUserName == @gbLogin or @groupAccessStr == 'p' or @groupAccessStr == 'r')
            userRows = @dbu.getUserByName(@rsrcUserName)
            unless(userRows.nil? or userRows.empty?)
              @rsrcUserId = userRows.first['userId']
            else
              initStatus = :'Not Found'
              @statusMsg = "NO_USR: The specified user: '#{@rsrcUserName}' could not be found"
            end
          else
            initStatus = :Forbidden
            @statusMsg = "FORBIDDEN: You do not have permission to access that resource."
          end
        end
      end
      @statusName = initStatus
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initOperation()
      if(@statusName == :OK)
        if (@rsrcUserName == @gbLogin or @groupAccessStr == 'p')
          # Allow users to query for their own access mode - and, there could be public db's available
          @rsrcUserRoleName = BRL::Genboree::Abstract::Resources::Role.roleFromAccess(@groupAccessStr)
        else
          @rsrcUserRoleName = BRL::Genboree::Abstract::Resources::Role.getRoleByUserIdAndGroupId(@dbu, @rsrcUserId, @groupId)
        end
        setResponse()
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource.
    # The request body must exist for an update operation
    # However a group can be created with or without the body
    # [+returns+] <tt>Rack::Response</tt> instance
    def put()
      initOperation()
      if(@statusName == :OK)
        @rsrcUserRoleName, @rsrcUserPermissionBits = BRL::REST::Resources::Role.rsrcUserRoleFromReq(self.readAllReqBody(), @repFormat)
        if (@rsrcUserRoleName == :'Unsupported Media Type')
          @statusName = :'Unsupported Media Type'
          @statusMsg = "BAD_REP: Either bad format indicated (#{@repFormat.inspect}) or a bad representation was provided and is not parsable. Beginning of representation:\n#{self.readAllReqBody().inspect[0,1000]}"
        elsif(@statusName == :OK)
          # This method will insert or update accordingly
          @statusName = BRL::Genboree::Abstract::Resources::Role.addUserGroupAccessToDb(@dbu, @rsrcUserId, @groupId, @rsrcUserRoleName, @rsrcUserPermissionBits)
          if(@statusName == :OK)
            self.setResponse(:OK, "Added role:'#{@rsrcUserRoleName}' for user:'#{@rsrcUserName}' and group:'#{@groupName}'")
          end
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def delete()
      initOperation()
      if(@statusName == :OK)
      	@rsrcUserRoleName = BRL::Genboree::Abstract::Resources::Role.getRoleByUserIdAndGroupId(@dbu, @rsrcUserId, @groupId)
        if(@rsrcUserRoleName.nil?)
          @statusName = :'Not Found'
          @statusMsg = "NOT_FOUND: The user is not a member of that group."
        else
          @statusName = BRL::Genboree::Abstract::Resources::Role.deleteUserGroupAccessFromDb(@dbu, @rsrcUserId, @groupId)
          if(@statusName == :OK)
            entity = BRL::Genboree::REST::Data::RefsEntity.new(@connect)
            entity.setStatus(:OK, "DELETED: User:'#{@rsrcUserName}' from group:'#{@groupName}' successfully deleted.")
            @statusName = configResponse(entity)
          end
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    #------------------------------------------------------------------
    # HELPERS
    #------------------------------------------------------------------

    # Helper: This method is used to get the Role Name from a Role Entity in the body of the request
    # This method is a class method because it is also used by the User resource
    # If the body isn't included, @rsrcUserRoleName is set to the default, 'subscriber'
    #
    # [+reqBody+] Should be self.readAllReqBody
    # [+repFormat+] Should be @repFormat
    # [+returns+] Role name
    def self.rsrcUserRoleFromReq(reqBody, repFormat)
      # if access level isn't defined, use default.  A bodyless put creates a subscriber
      role = 'subscriber'
      if(reqBody != '')
        # get the request body, should be RoleEntity
        roleEntity = BRL::Genboree::REST::Data::RoleEntity.deserialize(reqBody, repFormat)
        if(roleEntity != :'Unsupported Media Type')
          # get the role that was defined in the payload
          role = roleEntity.role
          pb = roleEntity.permissionBits
        else
          role = :'Unsupported Media Type'
        end
      end
      return [role, pb]
    end

    # Helper: Sets up the response for this resource
    # [+statusName+]  [optional; default=:OK] Current status code for the response.
    # [+statusMsg+]   [optional; default=nil] Current status message for the response, if any.
    def setResponse(statusName=:OK, statusMsg="OK")
      refBase = makeRefBase("/REST/#{VER_STR}/grp")
      ref = "#{refBase}/#{Rack::Utils.escape(@groupName)}/usr/#{Rack::Utils.escape(@rsrcUserName)}/role"
      entity = BRL::Genboree::REST::Data::RoleEntity.new(@connect, @rsrcUserRoleName)
      entity.makeRefsHash(ref)
      entity.setStatus(statusName, statusMsg)
      configResponse(entity, statusName)
      # Set Location header
      @resp['Location'] = ref
    end
  end # class Role
end ; end ; end # module BRL ; module REST ; module Resources
