#!/usr/bin/env ruby
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/abstract/resources/database'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  # DbBrowserCache - Delete the browser cache for a specific database.
  #
  # Data representation classes used:
  # * _none_, gets and delivers raw LFF text directly.
  class DbBrowserCache < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :delete => true }

    # INTERFACE: return a +Regexp+ that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/browserCache$</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/browserCache$}     # Look for /REST/v1/grp/{grp}/db/annos URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 7          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      initStatus = super
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        # This function will set @groupId and @refSeqId if it exist, return value is :OK or :'Not Found'
        initStatus = initGroupAndDatabase()
      end
      return initStatus
    end

    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        if(@groupAccessStr == 'o')
          BRL::Genboree::Abstract::Resources::Database.clearBrowserCacheById(@dbu, @refSeqId)
          entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
          entity.setStatus(:OK, "The browser cache has been deleted.")
          @statusName = configResponse(entity)
        else
          @statusName, @statusMsg = :'Forbidden', "You do not have adequate permissions to perform this request.  You must be administrator of the group."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp 
    end
    
  end # class DbAnnos
end ; end ; end # module BRL ; module REST ; module Resources