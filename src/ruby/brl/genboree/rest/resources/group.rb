#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/groupEntity'
require 'brl/genboree/genboreeDBHelper'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Group - exposes information about s specific user group.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::DetailedGroupEntity
  # * BRL::Genboree::REST::Data::DetailedGroupEntityWithChildren
  class Group < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true, :head => true }
    UNLOCKABLE = false
    RSRC_TYPE = 'group'

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @rsrcUserName = @rsrcUserId = @groupId = @groupName = @bodyGroupName = @bodyGroupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this service
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^(?:(?:/REST/#{VER_STR}/usr/([^/\?]+)/grp/([^/\?]+))|(?:/REST/#{VER_STR}/grp/([^/\?]+)))$</tt>
    def self.pattern()
      return %r{^(?:(?:/REST/#{VER_STR}/usr/([^/\?]+)/grp/([^/\?]+))|(?:/REST/#{VER_STR}/grp/([^/\?]+)))$} # Look for /REST/v1/usr/{usr}/grp/{grp} or /REST/v1/grp/{grp} URIs
    end

    def self.getPath(groupName)
      path = "/REST/#{VER_STR}/grp/#{Rack::Utils.escape(groupName)}"
      return path
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
    # [+returns+] The status codo to indicate any errors (as set in @statusName)
    def initOperation()
      initStatus = super
      if(initStatus == :OK)
        # Extract resource path data, depending on which type of path got us here
        compactUriMatches = @uriMatchData.captures.compact
        # Which resource path did we match?
        if(compactUriMatches.size == 2) # then /REST/v1/usr/{usr}/grp/{grp}
          @rsrcUserName = Rack::Utils.unescape(@uriMatchData[1])
          @groupName = Rack::Utils.unescape(@uriMatchData[2])
          # validate {usr}, since we have it (gbLogin == {usr}, etc)
          initStatus = initUser()
        else # 1 fields, /REST/v1/grp/{grp} (this is the 3rd capture group in the RE)
          @rsrcUserName = nil
          @groupName = Rack::Utils.unescape(@uriMatchData[3])
          initStatus = :OK
        end
      end
      @statusName = initStatus
    end

    # [+returns+] The <tt>#statusName</tt>.
    def checkResource()
      return initGroup()
    end
    
    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initOperation()
      if(@statusName == :OK)
        # Init group and do verifications
        @statusName = initGroup()
        if(@statusName == :OK)
          setResponse(@groupName, :OK)
        end
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
      initStatus = initOperation()
      # group initialization determines whether this should be an update or insert based on the status
      # @groupId is set in initGroup but is nil if the group doesn't exist
      if(@statusName == :OK)
        setGroupInfoFromReq()
        @statusName = initGroup() # Sets @groupId, and sets status to :OK or :Not Found
        if(@statusName == :OK)
          if(@groupId.to_i > 0 and !@bodyGroupName.empty?) # resource exists and payload is ok so update
            @statusName = self.updateGroupToDb()
            @statusMsg = "UPDATED: Group #{@groupName.inspect} successfully." if(@statusName == :OK)
          end
        elsif(@statusName == :'Not Found')
          if(self.readAllReqBody() == '' or @bodyGroupName == @groupName) # group doesn't exist, create a new group
            # This condition allows group to be created with no request body, but if there is a request body the group names must be the same
            @statusName = self.addGroupToDb()
            @statusMsg = "CREATED: Group #{@groupName.inspect} successfully." if(@statusName == :OK)
          end
        else
          @statusName = :"Unsupported Media Type"
          @statusMsg = "Either bad representation was provided and is not parsable or URI group name does not match request body group name."
        end
        if(@statusName == :OK)
          self.setResponse(@groupName, :Created)
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Processes a DELETE operation on this resource
    # The method will only remove the db record for the group and return to the client
    # The contents of the group will be removed as a background process since it can take several seconds
    # depending on how big the group is and how many databases it has
    # [+returns+] <tt>Rack::Response</tt> instance
    def delete()
      initStatus = initOperation()
      # group initialization determines whether this should be an update or insert based on the status
      # @groupId is set in initGroup but is nil if the group doesn't exist
      if(@statusName == :OK)
        @statusName = initGroup() # Sets @groupId, and sets status to :OK or :Not Found
        @statusName = self.checkAccess(@groupName) if(@statusName == :OK)
        $stderr.puts("@statusName: #{@statusName.inspect}; groupId: #{@groupId.inspect}")
        if(@statusName == :OK)
          begin
            rowsDeleted = @dbu.deleteGroupByGroupId(@groupId)
            grpDeleteCmd = "deleteGroupContents.rb #{@groupId}"
            escGrpDeleteCmd = CGI.escape(grpDeleteCmd)
            `genbTaskWrapper.rb --cmd=#{escGrpDeleteCmd} -o /dev/null -e /dev/null`
          rescue => err
            @statusName = :'Internal Server Error'
            @statusMsg = "A problem was encountered while deleting group: #{@groupName}. The group may require manual cleanup."
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error: #{err.message}\nBacktrace: #{err.backtrace.join("\n")}")
          end
        elsif(@statusName == :'Not Found')
          initStatus = @statusName = :'Not Found'
          @statusMsg = "NO_GRP: There is no group: #{@groupName.inspect} to delete."
        else
          # No Op
        end
        if(@statusName == :OK)
          self.setResponse(@groupName, :OK)
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    #------------------------------------------------------------------
    # HELPERS
    #------------------------------------------------------------------

    # Helper: Sets up the response for this resource
    # [+groupName+]   Name of the group.
    # [+statusName+]  Current status code for the response.
    # [+statusMsg+]   [optional; default=nil] Current status message for the response, if any.
    def setResponse(groupName, statusName, statusMsg=nil)
      refBase = makeRefBase("/REST/#{VER_STR}/grp")
      ref = "#{refBase}/#{Rack::Utils.escape(groupName)}"
      groupRow = @dbu.selectGroupByName(groupName)
      grpName = ''
      desc = ''
      if(!groupRow.nil? and !groupRow.empty?)
        grpName = groupRow.first['groupName']
        desc = groupRow.first['description']
      else # When deleting group, groupRow will be empty
        grpName = groupName
        desc = ""
      end
      # @detailed either provides some description of the depth of children to include or true/false
      if(@detailed == "immediates")
        # then just give a list of the child names for each type
        # @todo because it is included here this level of detail will be returned in the PUT response
        #   but that does not mean that these entities will be created, which is perhaps unclear
        # because #initGroup is called, we have at least a @dbu and a @groupId
        isPublic = dbRecs = prjRecs = kbRecs = hubRecs = redminePrjRecs =  nil
        if(@groupAccessStr == 'p')
          dbRecs = @dbu.selectPublicUnlockedRefseqsByGroupId(@groupId)
          prjRecs = kbRecs = hubRecs = redminePrjRecs = [] # @todo public unlock for these resources not currently supported
          isPublic = true
        else
          dbRecs = @dbu.selectRefseqsByGroupId(@groupId)
          prjRecs = @dbu.selectProjectsByGroupId(@groupId)
          kbRecs = @dbu.selectKbsByGroupId(@groupId)
          hubRecs = @dbu.selectHubsByGroupId(@groupId)
          redminePrjRecs = @dbu.selectRedminePrjsByGroupId(@groupId)
          isPublic = false
        end
        children = BRL::Genboree::REST::Data::DetailedGroupEntityWithChildren::DEFAULT_CHILDREN
        children[:dbs] = String.ignoreCaseSort(dbRecs.collect{|xx| xx['refseqName']})
        children[:kbs] = String.ignoreCaseSort(kbRecs.collect{|xx| xx['name']})
        children[:prjs] = String.ignoreCaseSort(prjRecs.collect{|xx| xx['name']})
        children[:hubs] = String.ignoreCaseSort(hubRecs.collect{|xx| xx['name']})
        children[:redminePrjs] = String.ignoreCaseSort(redminePrjRecs.collect{|xx| xx['project_id']})
        entity = BRL::Genboree::REST::Data::DetailedGroupEntityWithChildren.new(@connect, grpName, desc, children, isPublic)
      else
        # regardless of true/false, give a detailed group entity
        entity = BRL::Genboree::REST::Data::DetailedGroupEntity.new(@connect, grpName, desc)
      end

      entity.makeRefsHash(ref)
      @statusMsg = statusMsg unless(statusMsg.nil?)
      entity.setStatus(statusName, @statusMsg)
      @statusName = configResponse(entity, statusName)
      # Set Location header
      @resp['Location'] = ref
    end

    # Helper: Reads the request body and sets @bodyGroupName and @bodyGroupDesc
    # If the payload is empty, the instance vars will be empty strings and @statusName is :'Unsupported Media Type'
    # [+returns+] The current @statusName.
    def setGroupInfoFromReq()
      if(self.readAllReqBody() != '')
        groupEntity = BRL::Genboree::REST::Data::DetailedGroupEntity.deserialize(self.readAllReqBody(), @repFormat)
        if(groupEntity != :'Unsupported Media Type')
          # Get new name from the GroupEntity in the body
          @bodyGroupName = groupEntity.name
          @bodyGroupDesc = groupEntity.description
        end
      end
      if(self.readAllReqBody() == '' or groupEntity == :'Unsupported Media Type')
        @bodyGroupName = ''
        @bodyGroupDesc = ''
        @statusName = :'Unsupported Media Type'
        @statusMsg = "BAD_REP: Either bad format indicated (#{@repFormat.inspect}) or a bad representation was provided and is not parsable. Beginning of representation:\n#{self.readAllReqBody().inspect[0,1000]}"
      end
      return @statusName
    end

    # Helper: This method will update a group.
    # Requires that @groupName, @groupId are set to get the group
    # and @bodyGroupName or @bodyGroupDesc for the update values.
    # [+returns+] A +Symbol+ indicating success (:OK) or failure.
    def updateGroupToDb()
      retVal = :OK
      # First, check the user's access
      retVal = self.checkAccess(@groupName)
      if(retVal == :OK)
        if(@groupId > 0)
          # Update the name ensuring a group with the same name doesn't already exist
          groupRows = @dbu.selectGroupByName(@bodyGroupName)
          if(!groupRows.empty? and groupRows.first['groupId'] == @groupId)
            # do nothing because the name hasn't changed
          elsif(groupRows.empty?)
            # The name hasn't been used so update group
            rowsChanged = @dbu.updateGroupNameById(@groupId, @bodyGroupName)
            if(rowsChanged.nil? or rowsChanged < 1)
              retVal = :'Internal Server Error'
            else
              @groupName = @bodyGroupName
            end
          else
            retVal = :Conflict
            @statusMsg = "ALREADY_EXISTS: Cannot rename #{@groupName.inspect} to #{@bodyGroupName} because a group with that name already exists."
          end
          if(@bodyGroupDesc)
            @dbu.updateGroupDescriptionById(@groupId, @bodyGroupDesc)
          end
        else
          retVal = :'Not Found'
          @statusMsg = "NO_GROUP: There is no group #{@groupName.inspect} (or perhaps isn't encoded correctly?)"
        end
      end
      return retVal
    end

    # Helper: Supports the creation of groups.
    # [+returns+] Status of group creation (:OK, :Conflict if already exists, or :'Internal Server Error' if DB op failed.)
    def addGroupToDb()
      retVal = :OK
      # Make sure the group doesn't already exist
      existingGroups = @dbu.selectGroupByName(@groupName)
      if(existingGroups.empty? or existingGroups.nil?)
        rowsChanged = @dbu.insertGroup(@groupName, @bodyGroupDesc)
        retVal = :'Internal Server Error' if(rowsChanged.nil? or rowsChanged < 1)
      else
        retVal = :Conflict
      end
      if(retVal == :OK) # If we didn't encounter a problem with the group then add the user as Administrator
        groupRows = @dbu.selectGroupByName(@groupName)
        @groupId = groupRows.first['groupId']
        rowsChanged = @dbu.insertUserIntoGroupById(@userId, @groupId, 'o')
        retVal = :'Internal Server Error' if(rowsChanged.nil? or rowsChanged < 1)
      end
      return retVal
    end

    # Helper: Checks that user has permission to alter a group specified by groupName.
    # [+groupName+] Group name in which to check for user (their id is in @userId) permission.
    # [+returns+]   :OK if they do, :Forbidden otherwise.
    def checkAccess(groupName)
      retVal = :OK
      authorizedAccessLevel = 'o'
      groupRows = @dbu.selectGroupByName(groupName)
      unless(groupRows.nil? or groupRows.empty?)
        groupId = groupRows.first['groupId']
        userAllowedToEdit = BRL::Genboree::GenboreeDBHelper.checkUserAllowed(@userId, groupId, authorizedAccessLevel, @dbu)
        retVal = :Forbidden unless(userAllowedToEdit)
      end
      return retVal
    end
  end # class Group
end ; end ; end # module BRL ; module REST ; module Resources
