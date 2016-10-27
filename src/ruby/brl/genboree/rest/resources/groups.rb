#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/groupEntity'
require 'brl/genboree/abstract/resources/group'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Groups - exposes information about specific user databases.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::DetailedGroupEntityList
  # * BRL::Genboree::REST::Data::DetailedGroupEntity
  # * BRL::Genboree::REST::Data::TextEntityList
  # * BRL::Genboree::REST::Data::TextEntity
  class Groups < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }
    UNLOCKABLE = true

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @rsrcUserName = @rsrcUserId = @includePublicContent = @requireUnlockedPublicDBs = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this service
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/usr/([^/\?]+)/grps$</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/usr/([^/\?]+)/grps$}                 # Look for /REST/v1/usr/{usr}/grps URIs
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
        @rsrcUserName = Rack::Utils.unescape(@uriMatchData[1])
        initStatus = initUser()   # populates @rsrcUserId
        if(initStatus == :OK)
          @includePublicContent = (@nvPairs['includePublicContent'] =~ /true/i or @nvPairs['includePublicContent'] =~ /yes/i)
          @requireUnlockedPublicDBs = (@nvPairs['requireUnlockedPublicDBs'] =~ /true/i or @nvPairs['requireUnlockedPublicDBs'] =~ /yes/i)
          # Get groups for user (via @rsrcUserId):
          grpRows = getGroups()
          # Transform group records to return data
          refBase = makeRefBase("/REST/#{VER_STR}/grp")
          if(@detailed) # want list of detailed group info
            bodyData = BRL::Genboree::REST::Data::DetailedGroupEntityList.new(@connect)
            grpRows.each { |row|
              grpName = row['groupName']
              entity = BRL::Genboree::REST::Data::DetailedGroupEntity.new(@connect, grpName, row['description'])
              # connect entity to more detailed info
              entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(grpName)}")
              bodyData << entity
            }
          else # want simple list of group names
            bodyData = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
            grpRows.each { |row|
              grpName = row['groupName']
              entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, grpName)
              # connect entity to more detailed info
              entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(grpName)}")
              bodyData << entity
            }
          end
          @statusName = configResponse(bodyData)
          grpRows.clear() if(grpRows)
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def getGroups()
      retVal = nil
      if(@gbLogin) # then get group list normally
        retVal = BRL::Genboree::Abstract::Resources::Group.getGroupListForUser(@dbu, @userId, @includePublicContent, @requireUnlockedPublicDBs)
        retVal.sort! {|aa,bb| aa['groupName'].downcase <=> bb['groupName'].downcase }
      else # an access using a gbKey; return ONLY unlocked groups (i.e. those matching gbKey)
        # Get all entities matching gbKey
        unlockedRsrcs = @dbu.selectUnlockedResourcesByKey(@gbKey.to_s)
        unlockedRsrcs.delete_if { |grpRsrc|
        }
        # Construct fake grpRows from what's left
        retVal = []
        unlockedRsrcs.each { |grpRsrc|
          if(grpRsrc['resourceUri'] =~ %r{^/REST/#{VER_STR}/grp/([^/\?]+)$})
            groupName = CGI.unescape($1)
            groupId = grpRsrc['group_id']
            grpRows = @dbu.selectGroupById(groupId)
            retVal << grpRows.first if(grpRows and !grpRows.empty?)
          end
        }
      end
      return retVal
    end
  end # class Groups
end ; end ; end # module BRL ; module REST ; module Resources
