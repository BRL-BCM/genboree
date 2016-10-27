#!/usr/bin/env ruby

require 'brl/cache/helpers/dnsCacheHelper'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/hostRecordEntity'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # UserHost - exposes information about user-host access info. Mainly for remote Genboree acccesses currently
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::HostRecordEntity
  class UserHost < BRL::REST::Resources::GenboreeResource
    # ------------------------------------------------------------------
    # MIXINS - bring in some generic useful methods used here and elsewhere
    # . Mainly for having self.class.canonicalAddress() functionality
    # ------------------------------------------------------------------
    include BRL::Cache::Helpers::DNSCacheHelper

    # INTERFACE: Map of what http methods this resource supports
    #   ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false).
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    RSRC_TYPE = 'userHost'

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      # remove variables created by this class, if any:
      @rsrcUserName = @rsrcHostName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/usr/{usr}/host/{host}</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/usr/([^/\?]+)/host/([^/\?]+)$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 7
    end

    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @rsrcUserName = Rack::Utils.unescape(@uriMatchData[1])
        @rsrcHostName = Rack::Utils.unescape(@uriMatchData[2])
        # Need to check appropriateness of this request
        # - First, does user in resource path exist?
        users = @dbu.getUserByName(@rsrcUserName)
        unless(users.nil? or users.empty?)
          @rsrcUserId = users.first["userId"]
          # If an internal superuser request, then go ahead. Else validate authorization for request:
          unless(@isSuperuser)
            # Next, does user doing request match user in request URL
            if(@rsrcUserId == @userId)
              initStatus == :OK
            else  # User doing request != user mentioned in resource path
              initStatus = @statusName = :'Forbidden'
              @statusMsg = "NOT_YOU: You cannot modify access records for other users."
            end
          end
        else # No such user as mentioned in resource path
          initStatus = @statusName = :'Not Found'
          @statusMsg = "NO_USR: The user #{@rsrcUserName.inspect} referenced in the API URL doesn't exist (or perhaps isn't encoded correctly?)"
        end
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        # Get host record from main genboree database for this user/host combo
        # OLD: #hostAccessRows = @dbu.getExternalHostInfoByHostAndUserId(@rsrcHostName, @rsrcUserId)
        rsrcUserHostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @rsrcUserId)
        rsrcUserAuthRec = Abstraction::User.getAuthRecForUserAtHost(@rsrcHostName, rsrcUserHostAuthMap, @genbConf)
        # If found host access row, prep resp body, else Not Found error
        unless(rsrcUserAuthRec.nil? or rsrcUserAuthRec.empty?)
          entity = BRL::Genboree::REST::Data::HostRecordEntity.new(false, @rsrcHostName, rsrcUserAuthRec[0], rsrcUserAuthRec[1])
          @statusName = configResponse(entity)
          rsrcUserAuthRec.clear()
          rsrcUserHostAuthMap.clear()
          rsrcUserAuthRec = rsrcUserHostAuthMap = nil
        else
          initStatus = @statusName = :'Not Found'
          @statusMsg = "NO_HOST_INFO: The user #{@rsrcUserName.inspect} does not have a valid host access record for #{@rsrcHostName.inspect}. Either that domain is no longer valid (not a resolvable domain), or the specific authentication record is corrupt."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. NOTE: The put() request must
    # include a payload of a HostRecordEntity or it will be rejected as a
    # [+Bad Request+] by this resource.
    # [+returns+] Rack::Response instance
    def put()
      initStatus = initOperation()
      if(initStatus == :OK)
        # Get payload HostRecordEntity from the HTTP request
        entity = parseRequestBodyForEntity('HostRecordEntity')
        if(entity == :'Unsupported Media Type')
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type HostRecordEntity")
        elsif(entity.nil? and initStatus == :'OK')
          # Cannot update with a nil entity
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "EMPTY_PAYLOAD_ON_UPDATE: You must supply a payload when performing an update")
        else
          # Do an insert-or-update operation to put the new/changed record.
          # - row count returned should be 0 (same data), 1 (new record), or 2 (old removed, new inserted) depending on the situation
          changedRows = @dbu.updateExternalHostInfoRecord(@userId, @rsrcHostName, entity.login, entity.token)
          if(changedRows and (changedRows >= 0 or changedRows <= 2))
            # Insert/update seems ok, no data in payload, just status:
            entity = BRL::Genboree::REST::Data::AbstractEntity.new(false)
            entity.setStatus(:OK, "The access information for host #{@rsrcHostName.inspect} was successfully #{changedRows == 1 ? 'added' : 'updated'} for user #{@rsrcUserName.inspect}.")
            @statusName = configResponse(entity)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem updating the access record for #{@rsrcHostName.inspect} and #{@rsrcUserName.inspect}. SQL says #{changedRows ? changedRows.inspect : 'no records' } were inserted or changed. Are you sure you provided a valid and real domain name?")
          end
        end
      end
      # Respond with an error if appropriate
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource.
    # [+returns+] Rack::Response instance
    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        # Do delete. Delete method takes care of "canonicalAddress" normalization for us...
        deletedRows = @dbu.deleteExternalHostInfoRecord(@userId, @rsrcHostName)
        # If delete didn't work, maybe IP of remote host changed, fallback on
        # trying exact host match
        if(deletedRows <= 0)
          deletedRows = @dbu.deleteExternalHostInfoRecord(@userId, @rsrcHostName, true)
        end
        # Dir the delete work by either canonical address or falling back on exact host match?
        if(deletedRows == 1)
          # Delete seems ok, no data in payload, just status:
          entity = BRL::Genboree::REST::Data::AbstractEntity.new(false)
          entity.setStatus(:OK, "The access information for host #{@rsrcHostName.inspect} was successfully deleted for user #{@rsrcUserName.inspect}.")
          @statusName = configResponse(entity)
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem deleting the access record for #{@rsrcHostName.inspect} and #{@rsrcUserName.inspect}. SQL says #{deletedRows.inspect} were deleted.")
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class UserHost
end ; end ; end # module BRL ; module REST ; module Resources
