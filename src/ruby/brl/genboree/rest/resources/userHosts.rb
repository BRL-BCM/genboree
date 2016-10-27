#!/usr/bin/env ruby

require 'brl/cache/helpers/dnsCacheHelper'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/hostRecordEntity'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # UserHosts - To get a list of hosts the user has access to. No access info, just host domain names.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::TextEntityList
  class UserHosts < BRL::REST::Resources::GenboreeResource
    # ------------------------------------------------------------------
    # MIXINS - bring in some generic useful methods used here and elsewhere
    # . Mainly for having self.class.canonicalAddress() functionality
    # ------------------------------------------------------------------
    include BRL::Cache::Helpers::DNSCacheHelper

    # INTERFACE: Map of what http methods this resource supports
    #   ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false).
    HTTP_METHODS = { :get => true, :put => false, :delete => false }

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
      return %r{^/REST/#{VER_STR}/usr/([^/\?]+)/hosts$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 8
    end

    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @rsrcUserName = Rack::Utils.unescape(@uriMatchData[1])
        # Need to check appropriateness of this request
        # - First, does user in resource path exist?
        users = @dbu.getUserByName(@rsrcUserName)
        unless(users.nil? or users.empty?)
          @rsrcUserId = users.first["userId"]
          # Next, does user doing request match user in request URL
          if(@rsrcUserId == @userId)
            initStatus == :OK
          else  # User doing request != user mentioned in resource path
            initStatus = @statusName = :'Forbidden'
            @statusMsg = "NOT_YOU: You can only see host access records for your own account."
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
        # User has access to this [local] host...which also should be first in the list...
        hostsForUser = [ @rsrcHost ]
        # And maybe some external Genboree hosts...
        hostAccessRows = @dbu.getExternalHostsByUserId(@userId)
        unless(hostAccessRows.nil? or hostAccessRows.empty?)
          # Go through external hosts in sorted order to make nice list
          hostAccessRows.sort { |aa, bb| aa['host'].downcase <=> bb['host'].downcase }.each { |row|
            hostsForUser << row['host']
          }
        end
        # Have hosts, prep response entity
        entitiesArray = []
        hostsForUser.each { |host|
          entitiesArray << BRL::Genboree::REST::Data::TextEntity.new(false, host)
        }
        entity = BRL::Genboree::REST::Data::TextEntityList.new(false, entitiesArray)
        @statusName = configResponse(entity)
        entitiesArray.clear()
        hostAccessRows.clear()
        hostsForUser.clear()
        hostAccessRows = hostsForUser = entitiesArray = nil
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class UserHosts
end ; end ; end # module BRL ; module REST ; module Resources
