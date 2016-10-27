#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/abstract/resources/textDigest'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class Digest < BRL::REST::Resources::GenboreeResource
    Abstraction = BRL::Genboree::Abstract::Resources

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
    end

    # INTERFACE: return a +Regexp+ that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] +Regexp+:
    def self.pattern()
      return %r{^/REST/#{VER_STR}/digest/([^/\?]+)}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 3          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      @statusName = super()
      if(@statusName == :OK)
        @digest = Rack::Utils.unescape(@uriMatchData[1])
      end
      return @statusName
    end

    # Process a GET operation on this resource. Depending on @repFormat, either:
    # - returns a simple UrlEntity for the url matching this digest
    # - OR returns the actual contents of the URL matching this digest
    #
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        # Try to get URL for this digest
        content = Abstraction::TextDigest.getTextByDigest(@dbu, @digest)
        # If there is one, then does it look like a url?
        if(content)
          @resp = setResponse(content)
        else # nothing stored for that digest
          @statusName = :'Not Found'
          @statusMsg = "NO_SHORT_URL: The digest value '#{@digest}' has not been used to store any URL."
        end
      end
      # If something else wasn't right along the way, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def setResponse(content)
      entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, content)
      entity.setStatus(@statusName, @statusMsg)
      @statusName = configResponse(entity, @statusName)
      return @resp
    end
  end # class
end ; end ; end # module BRL ; module REST ; module Resources
