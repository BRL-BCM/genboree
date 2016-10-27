#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Users - exposes information about the set of users in a group.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::PartialUserEntityList
  # * BRL::Genboree::REST::Data::PartialUserEntity
  # * BRL::Genboree::REST::Data::TextEntityList
  # * BRL::Genboree::REST::Data::TextEntity
  class Users < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true }
    UNLOCKABLE = false

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this service
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/usrs$</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/usrs$}                 # Look for /REST/v1/grp/{grp}/usrs URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/service is
    # highly specific and should be examined early on, or whether it is more generic and
    # other services should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 3          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        # gbLogin must be in the group (sets @groupId also)
        initStatus = initGroup()
        if(initStatus == :OK)
          # Get users in group:
          usrRows = @dbu.getUsersByGroupId(@groupId)
          usrRows.sort! {|aa,bb| aa['name'].downcase <=> bb['name'].downcase }
          # Transform user records to return data
          refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/usr")
          if(@detailed) # want list of "detailed" user info (will be partial, since accessing for fellow group members)
            bodyData = BRL::Genboree::REST::Data::PartialUserEntityList.new(@connect)
            usrRows.each { |row|
              usrName = row['name']
              next if(usrName == 'admin')
              entity = BRL::Genboree::REST::Data::PartialUserEntity.new(@connect, usrName, row['firstName'], row['lastName'], row['institution'], row['email'])
              # connect entity to more detailed info
              entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(usrName)}")
              bodyData << entity
            }
          else # want simple list of user names
            bodyData = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
            usrRows.each { |row|
              usrName = row['name']
              next if(usrName == 'admin')
              entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, usrName)
              # connect entity to more detailed info
              entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(usrName)}")
              bodyData << entity
            }
          end
          @statusName = configResponse(bodyData)
          usrRows.clear() if(usrRows)
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
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        # gbLogin must be in the group (sets @groupId also)
        initStatus = initGroup()
        if(initStatus == :OK and @groupAccessStr == 'o')
          # Get the list of users from the body
          entity = BRL::Genboree::REST::Data::TextEntityList.deserialize(self.readAllReqBody(), @repFormat)
          if(entity != :'Unsupported Media Type')
            dataStruct = entity.getFormatableDataStruct()
            dataPart = dataStruct['data']
            userIds = Array.new
            #convert the array of users names to an array of ID's
            dataPart.each { |user|
              userRows = @dbu.getUserByName(user.text)
              unless(userRows.nil? or userRows.empty?)
                userIds.push(userRows.first["userId"])
              end
            }
            rowsChanged = @dbu.insertMultiUsersIntoGroupById(userIds, @groupId, 'r')
            initStatus = retVal = :FATAL if(rowsChanged.nil? or rowsChanged < 1)
          else
            @statusName = :'Unsupported Media Type'
            initStatus = @statusMsg = "BAD_REP: Either bad format indicated (#{@repFormat.inspect}) or a bad representation was provided and is not parsable. Beginning of representation:\n#{self.readAllReqBody().inspect[0,1000]}"
          end
        else
          @statusName = :'Forbidden'
          initStatus = @statusMsg = "Forbidden: Insuffient permission to perform this operation."
        end
        # Display updated status
        if (initStatus == :OK)
          refBase = makeRefBase("/REST/#{VER_STR}/grp")
          ref = "#{refBase}/#{Rack::Utils.escape(@groupName)}/usrs"
          entity = BRL::Genboree::REST::Data::DetailedGroupEntity.new(@connect, @groupName)
          entity.makeRefsHash(ref)
          entity.setStatus(:CREATED, "CREATED: User Group Access successfully for group: #{@groupName.inspect}.")
          @statusName = configResponse(entity, :'Created')
          @resp['Location'] = ref
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class Users
end ; end ; end # module BRL ; module REST ; module Resources
