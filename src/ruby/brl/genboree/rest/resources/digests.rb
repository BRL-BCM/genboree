#!/usr/bin/env ruby
require 'fileutils'
require 'erubis'
require 'uri'
require 'open-uri'
require 'brl/util/util'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/abstract/resources/textDigest'
require 'brl/genboree/rest/data/textEntity'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class Digests < BRL::REST::Resources::GenboreeResource
    Abstraction = BRL::Genboree::Abstract::Resources

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :put => true }

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
      return %r{^/REST/#{VER_STR}/digests}
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
      return @statusName
    end

    # Process a PUT operation on this resource.
    #
    # [+returns+] <tt>Rack::Response</tt> instance
    def put()
      initStatus = initOperation()
      if(initStatus == :OK)
        entity = parseRequestBodyForEntity(['TextEntity'])
        unless(entity.nil? or entity == :'Unsupported Media Type')
          content = entity.text
          # generate unique digest and update/insert into table
          digest = Abstraction::TextDigest.createUniqueDigest(@dbu, content)
          # configure response (UrlEntity with a Short Url in "url" field)
          url = makeRefBase("/REST/v1/digest/#{Rack::Utils.escape(digest)}")
          respEntity = BRL::Genboree::REST::Data::UrlEntity.new(@connect, url)
          configResponse(respEntity)
        else
          @statusName = :'Unsupported Media Type'
          @statusMsg = 'BAD_REPRESENTATION: The payload of the request is not supported by this resource and method. Please supply a TextEntity reprentation.'
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class
end ; end ; end # module BRL ; module REST ; module Resources
