#!/usr/bin/env ruby
require 'fileutils'
require 'brl/util/util'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/unlockedRefEntity'
require 'brl/genboree/abstract/resources/unlockedGroupResource'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  # GrpUnlockedResources
  class GbKeyEntityAspect < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
    end

    # INTERFACE: return a +Regexp+ that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/annos$</tt>
    def self.pattern()
      return %r{^(/REST/#{VER_STR}(?:/[^/\?]+)+)/gbKey$}     # Look for /REST/v1/grp/{grp}/unlockedResources URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 9          # We need to match this entity-wide but very specific aspect before other aspect-matchers get a chance
    end

    def initOperation()
      @statusName = super()
      @resourceUriStr= @uriMatchData[1]
      return @statusName
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      gbKeyStr = nil
      initStatus = initOperation()
      # If something wasn't right, represent as error
      if(initStatus == :OK)
        # Use @resourceUriStr to try to get an unlockedGroupResources row.
        rows = @dbu.selectUnlockedResourcesByUri(@resourceUriStr)
        # If no result rows, there is no key. Not Found.
        if(rows.nil? or rows.empty?)
          @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "NO_GBKEY: There is no gbKey for the resource at #{@resourceUriStr.inspect}.", nil, false)
        else
          row = rows.first  # The can only be 1 gbKey per resource path (enforced by a unique table index)
          # If row, give key right away if public=true
          if(row['public'] or @isSuperuser)
            gbKeyStr = row['unlockKey']
          else
            # Else if public=false, we need to try to check group membership
            grpApiUriHelper = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@dbu, @genbConf, {:rackEnv => @rackEnv})
            grpUri = grpApiUriHelper.extractPureUri(@resourceUriStr, false)
            if(grpUri.nil?)
              @apiError = BRL::Genboree::GenboreeError.new(:Forbidden, "NO_ACCESS: You are not permitted to access the gbKey for #{@resourceUriStr.inspect}.", nil, false)
            else
              # It's a group. If member of group, then return gbKey. Else forbidden.
              @groupName = grpApiUriHelper.extractName(grpUri)
              initStatus = initGroup()
              if(initStatus == :OK and @groupAccessStr and @groupAccessStr != 'p')
                gbKeyStr = row['unlockKey']
              else
                @apiError = BRL::Genboree::GenboreeError.new(:Forbidden, "NO_ACCESS: You are not permitted to access the gbKey for #{@resourceUriStr.inspect}.", nil, false)
              end
            end
          end
        end
      end
      # Did we get an @apiError or can we present the gbKey?
      unless(@apiError or gbKeyStr.nil?)
        entity = BRL::Genboree::REST::Data::TextEntity.new(false, gbKeyStr)
        @statusName = configResponse(entity)
      end
      @resp = representError() if(@apiError or @statusName != :OK)
      return @resp
    end
  end # class GbKeyEntityAspect
end ; end ; end # module BRL ; module REST ; module Resources
