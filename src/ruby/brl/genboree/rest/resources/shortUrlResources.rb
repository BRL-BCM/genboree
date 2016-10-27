#!/usr/bin/env ruby
require 'fileutils'
require 'erubis'
require 'uri'
require 'open-uri'
require 'brl/util/util'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/abstract/resources/textDigest'
require 'brl/genboree/rest/data/urlEntity'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class ShortUrlResources < BRL::REST::Resources::GenboreeResource
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
      return %r{^/REST/#{VER_STR}/shortUrls}
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
        entity = parseRequestBodyForEntity(['UrlEntity'])
        unless(entity.nil? or entity == :'Unsupported Media Type')
          # First, is URL valid?
          if(!entity.validUrl?)
            @statusName = :'Precondition Failed'
            @statusMsg = "NOT_VALID_URL: The content whose digested value is '#{@digest}' is not a valid URL. That is not allowed for /shortUrl/ resources. Failed URL validating check."
            $stderr.puts "NOT_VALID_URL: The content whose digested value is '#{@digest}' is not a valid URL. That is not allowed for /shortUrl/ resources. Failed URL validating check for #{url.inspect}. Error: #{iuerr.message}. Backtrace:\n#{iuerr.backtrace.join("\n")}"
          elsif(!entity.isAbsoluteUrl?)
            @statusName = :'Precondition Failed'
            @statusMsg = "NOT_ABSOLUTE_URL: The content you are trying to store and digest seems to indicate a relative URL (or cannot be parsed an absolute URL). That is not allowed for /shortUrl/ resources. MUST be an absolute URL."
            $stderr.puts "NOT_ABSOLUTE_URL: The content you are trying to store and digest seems to indicate a relative URL (or cannot be parsed an absolute URL). That is not allowed for /shortUrl/ resources. MUST be an absolute URL."
          else # URL Ok it seems
            url = entity.url
            # generate unique digest and update/insert into table
            digest = Abstraction::TextDigest.createUniqueDigest(@dbu, url)
            # configure response (UrlEntity with a Short Url in "url" field)
            shortUrl = makeRefBase("/REST/v1/shortUrl/#{Rack::Utils.escape(digest)}")
            respEntity = BRL::Genboree::REST::Data::UrlEntity.new(@connect, shortUrl)
            configResponse(respEntity)
          end
        else
          @statusName = :'Unsupported Media Type'
          @statusMsg = 'BAD_REPRESENTATION: The payload of the request is not supported by this resource and method. Please supply a UrlEntity reprentation.'
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class
end ; end ; end # module BRL ; module REST ; module Resources
