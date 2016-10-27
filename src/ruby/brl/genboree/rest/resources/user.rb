#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/userEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # User - exposes information about a user.
  # - if <tt>{usr}</tt> is gbLogin, then full info is exposed
  # - if <tt>{usr}</tt> is accessed via group (i.e. by fellow member of group), then slightly less info is exposed
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::DetailedUserEntity
  # * BRL::Genboree::REST::Data::PartialUserEntity
  class User < BRL::REST::Resources::GenboreeResource
    # TODO: expose mechanism to get known host list for a given user. Include current host (genboreeuser table).
    # TODO: expose mechanism to get Host => auth records...must be very very limited to superuser only etc
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
      @rsrcUserName = @rsrcUserId = @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this service
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^(?:(?:/REST/#{VER_STR}/grp/([^/\?]+)/usr/([^/\?]+))|(?:/REST/#{VER_STR}/usr/([^/\?]+)))$</tt>
    def self.pattern()
      return %r{^(?:(?:/REST/#{VER_STR}/grp/([^/\?]+)/usr/([^/\?]+))|(?:/REST/#{VER_STR}/usr/([^/\?]+)))$} # Look for /REST/v1/grp/{grp}/usr/{usr} or /REST/v1/usr/{usr} URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/service is
    # highly specific and should be examined early on, or whether it is more generic and
    # other services should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 2          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    # OVERRIDE: Do extra initialization to extract instance vars from uri:
    # - @groupName
    # - @rsrcUserName
    # - @rsrcUserId (via @rsrcUserName)
    # [+returns+] The status codo to indicate any errors (as set in @statusName)
    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        # Extract resource path data, depending on which type of path got us here
        compactUriMatches = @uriMatchData.captures.compact
        # Which resource path did we match?
        if(compactUriMatches.size == 2) # then /REST/v1/grp/{grp}/usr/{usr}
          @rsrcUserName = Rack::Utils.unescape(@uriMatchData[2])
          @groupName = Rack::Utils.unescape(@uriMatchData[1])
          # Verify gbLogin user is member of group with sufficient status
          initStatus = initGroup()  # also sets @groupId
          # Must also verify that @rsrcUserName is a member of the group
          users = @dbu.getUserByName(@rsrcUserName)
          unless(users.nil? or users.empty?)
            @rsrcUserId = users.first["userId"]
          else
            initStatus = @statusName = :'Not Found'
            @statusMsg = "NO_USR: The user #{@rsrcUserName.inspect} referenced in the API URL doesn't exist (or perhaps isn't encoded correctly?)"
          end
        else # 1 fields, /REST/v1/usr/{usr} (this is the 3rd capture group in the RE)
          @rsrcUserName = Rack::Utils.unescape(@uriMatchData[3])
          @groupName = nil
          # Verify gbLogin user is allowed to access full user info
          initStatus = initUser()
        end
     end
     @statusName = initStatus
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        unless(@rsrcUserName == 'admin')
          # verify rsrsUserName is in the group (by getting their access level)
          unless(@groupName.nil?)
            groupAccessStrRow = @dbu.getAccessByUserIdAndGroupId(@rsrcUserId, @groupId)
            if(groupAccessStrRow.nil? or groupAccessStrRow.empty?)
              initStatus = @statusName = :'Not Found'
              @statusMsg = "NO_USR: The user #{@rsrcUserName.inspect} referenced in the API URL isn't a member of the group #{@groupName.inspect}."
            end
          end
          # If no problems (eg from user access, user exists and is in group, etc) so far, continue
          if(initStatus == :OK)
            self.setResponse()
          end
        else # Forbidden to access admin user
          initStatus = @statusName = :'Forbidden'
          @statusMsg = "FORBIDDEN: You do not have permission to access that resource."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource.
    # The request body must exist for an update operation
    # [+returns+] <tt>Rack::Response</tt> instance
    def put()
      initStatus = initOperation()
      if(@statusName == :OK and !@groupName.nil?) # Add user to group
        @rsrcUserRoleName, @rsrcUserPermissionBits = BRL::REST::Resources::Role.rsrcUserRoleFromReq(self.readAllReqBody, @repFormat)
        @statusName = :'Unsupported Media Type' if (@rsrcUserRoleName == :'Unsupported Media Type')
        if(@statusName == :OK)
          # This method will insert or update accordingly
          @statusName = Abstraction::Role.addUserGroupAccessToDb(@dbu, @rsrcUserId, @groupId, @rsrcUserRoleName, @rsrcUserPermissionBits)
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
        @rsrcUserRoleName = Abstraction::Role.getRoleByUserIdAndGroupId(@dbu, @rsrcUserId, @groupId)
        if(@rsrcUserRoleName.nil?)
          @statusName = :'Not Found'
          @statusMsg = "NOT_FOUND: The user is not a member of that group."
        else
          @statusName = Abstraction::Role.deleteUserGroupAccessFromDb(@dbu, @rsrcUserId, @groupId)
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

    # Helper: Sets up the response for this resource.
    # Requires that @groupName, @rsrcUserName and @rsrcUserRoleName are set.
    #
    # [+statusName+]  [optional; default=:OK] Current status code for the response.
    # [+statusMsg+]   [optional; default=nil] Current status message for the response, if any.
    def setResponse(statusName=:OK, statusMsg=nil)
      if(@groupName.nil?)
        ref = makeRefBase("/REST/#{VER_STR}/usr/#{Rack::Utils.escape(@rsrcUserName)}")
      else
        ref = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/usr/#{Rack::Utils.escape(@rsrcUserName)}")
      end
      usrRows = @dbu.getUserByName(@rsrcUserName)
      # If {usr} and gbLogin match, then get full info for rsrcUserName
      usrRow = usrRows.first
      if(@superuserApiDbrc.user == @gbLogin)
        entity = BRL::Genboree::REST::Data::FullUserEntity.new(@connect, usrRow['name'], usrRow['firstName'], usrRow['lastName'], usrRow['institution'], usrRow['phone'], usrRow['email'], usrRow['password'])
      elsif (@rsrcUserName == @gbLogin)
        entity = BRL::Genboree::REST::Data::DetailedUserEntity.new(@connect, usrRow['name'], usrRow['firstName'], usrRow['lastName'], usrRow['institution'], usrRow['phone'], usrRow['email'])
      else # else get partial info for rsrcUserName
        entity = BRL::Genboree::REST::Data::PartialUserEntity.new(@connect, usrRow['name'], usrRow['firstName'], usrRow['lastName'], usrRow['institution'], usrRow['email'])
      end
      entity.makeRefsHash(ref)
      entity.setStatus(statusName, statusMsg)
      configResponse(entity, statusName)
      # Set Location header
      @resp['Location'] = ref
    end
  end # class User
end ; end ; end # module BRL ; module REST ; module Resources
