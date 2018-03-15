#!/usr/bin/env ruby
require 'uri'
require 'rack'
require 'brl/util/util'
require 'brl/rest/apiCaller'
require 'brl/genboree/genboreeUtil'

module BRL  #:nodoc:
module REST #:nodoc:
  # Abstract Class for REST 'resource' classes. All such classes inherit
  # from this class and either use or override the method defaults here.
  # - Resource classes must inherit and implement this interface.
  # - This abstract class' #pattern will never match any request URI.
  class Resource
    #  Watch your scope for constants used in inherited methods (self.class::<CONSTANT> takes care of this)!

    # API version string. The API is versioned, so that incompatible changes need not break existing references.
    VER_STR = "v1"
    # Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc. } ).
    # Empty default means all are inherently false. Subclasses will override this, obviously.
    HTTP_METHODS = {}

    # The http request object (<tt>Rack::Request</tt> instance).
    attr_accessor :req
    # The http response object (<tt>Rack::Response</tt> instance).
    attr_accessor :resp
    # The http method (as a downcase symbol).
    attr_accessor :reqMethod
    # The +MatchData+ object resulting from matching #pattern against a URI.
    attr_accessor :uriMatchData
    # The portion of the URI corresponding the host name within the URI.
    # - Subclass can override this (GenboreeResource does, to allow the 'useHost' parameter functionality).
    attr_accessor :rsrcHost
    # The actual host used to make the incoming API request.
    # - Do not override.
    attr_accessor :reqHost
    # rackEnv.
    attr_accessor :rackEnv
    # Full parameters when some passed via POST (_special case_, not common)
    attr_accessor :combinedParams

    # CONSTRUCTOR.
    # [+req+]           <tt>Rack::Request</tt> instance
    # [+resp+]          <tt>Rack::Request</tt> instance (can be modified/used as template)
    # [+uriMatchData+]  +MatchData+ object resulting from matching the URI against #pattern
    def initialize(req, resp, uriMatchData)
      @req, @resp, @uriMatchData = req, resp, uriMatchData
      @combinedParams = nil
      uri = URI.parse(@req.url)
      @rsrcHost = @reqHost = uri.host
      @rackEnv = @req.env
      @reqMethod = extractRequestMethod() # get actual request method
    end

    # INTERFACE: Return a +Regexp+ that will match a correctly formed URI for this resource.
    # The pattern will be applied against a URI's _path_.
    # [+return+]  +Regexp+ instance that can match appropriate URIs.
    def self.pattern()
      return /$.^/      # bogus pattern, won't match; implementing class returns its pattern
    end

    # INTERFACE: Return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on (low value), or whether it is more generic and
    # other resources should be matched for first (high value).
    # [+returns+] Integer from 1 to 10.
    def self.priority()
      return 1          # from 1 to 10, low to high
    end

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call +super()+
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
    end

    # INTERFACE. List supported operations.
    # [+returns+] +Hash+ of supported HTTP request methods as symbols (:get, :delete, :head, etc) mapped to +true+
    def operations()
      return self.class::HTTP_METHODS
    end

    # INTERFACE: does this resource support the http request method?
    # [+method+]  HTTP method as downcase symbol
    # [+returns+] +true+ or +false+ indicating whether +method+ is supported or not
    def supports?(method)
      method = method.to_s.downcase.to_sym unless(method.is_a?(Symbol))
      return self.class::HTTP_METHODS.key?(method)
    end

    # INTERFACE: process an operation on this resource
    # [+returns+] <tt>Rack::Request</tt> instance
    def process()
      # BRL::Genboree::GenboreeUtil.logError("Class Processing: #{self.class} (#{@reqMethod}) [ for: #{@req.path_info} ]", nil)
      if(supports?(@reqMethod))
        retVal = self.send(@reqMethod)  # Call an instance method matching the reqMethod
        # With retVal in hand, cleanup resource (sub-classes will implement this cleanup method, adding their own clean up before calling super())
        self.cleanup()
      else
        retVal = notImplemented()
      end
      return retVal
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Request</tt> instance
    def get()
      return notImplemented()
    end

    # Process a PUT operation on this resource.
    # [+returns+] <tt>Rack::Request</tt> instance
    def put()
      return notImplemented()
    end

    # Process a DELETE operation on this resource.
    # [+returns+] <tt>Rack::Request</tt> instance
    def delete()
      return notImplemented()
    end

    # Process a POST operation on this resource.
    # [+returns+] <tt>Rack::Request</tt> instance
    def post()
      return notImplemented()
    end

    # Process a HEAD operation on this resource.
    # [+returns+] <tt>Rack::Request</tt> instance
    def head()
      return notImplemented()
    end

    # Process a OPTIONS operation on this resource.
    # [+returns+] <tt>Rack::Request</tt> instance
    def options()
      return notImplemented()
    end

    # Helpers & Constants

    # All the HTTP response codes as numbers:
    HTTP_STATUS_CODES = Rack::Utils::HTTP_STATUS_CODES
    # All the HTTP response codes by official human-readable name:
    HTTP_STATUS_NAMES = {}
    # A map of each number to an official human readable name:
    HTTP_STATUS_CODES.each { |kk, vv| HTTP_STATUS_NAMES[vv.to_sym] = kk }
    # Map of HTTP Response code categories to whether they indicate a "success" or not
    HTTP_RESP_CODE_TYPE_SUCCESSES = { :Informational => true, :Success => true, :Redirection => true, :'Client Error' => false, :'Server Error' => false }

    # Indicates the category/type for a given HTTP response code provided by name or number.
    #   HTTP response codes fall into categories: "Informational", "Success", "Redirection", "Client Error", "Server Error"
    # @param [Fixnum, Symbol, String] httpCode The HTTP response code for which to get the category. Either the
    #   numeric @Fixnum@ or the response code name, correctly capitalized, as a @Symbol@ or @String@.
    # @return [Symbol, nil] The category, which will be one of these @Symbols@: @:Informational@, @:Success@, @:Redirection@, @:'Client Error'@,
    #   @:'Server Error'@. If the response is not a known, supported HTTP standard response or is in a form that can't be used to
    #   determine the category, the return value is @nil@.
    def self.httpCodeType(httpCode)
    end

    # @see {Resource.httpCodeType}
    def httpCodeType(httpCode)
      return self.class.httpCodeType(httpCode)
    end

    # Is the HTTP response code a "success" type response code? (If not, then it is some kind of "error").
    #   Any Informational, Success, or Redirection type code is considered a "success".
    # @param [Fixnum, Symbol, String] httpCode The HTTP response code to examine. Either the
    #   numeric @Fixnum@ or the response code name, correctly capitalized, as a @Symbol@ or @String@.
    # @return [Boolean] True if the code is a 'success' type code, false otherwise.
    def self.successCode?(httpCode)
      return BRL::REST::ApiCaller.successCode?(httpCode)
    end

    # @see {Reource.successCode?}
    def successCode?(httpCode)
      return self.class.successCode?(httpCode)
    end

    # Extract HTTP method from <tt>Rack::Request</tt> method...look for "_method" param or X-HTTP-Method Override if POST
    # [+returns+] HTTP method as downcased symbol
    def extractRequestMethod()
      # Get request method
      incomingReqMethod = @req.request_method
      reqMethod = incomingReqMethod
      # If POST, check for _method or X-HTTP-Method-Override for overloaded post
      if(incomingReqMethod =~ /post/i)
        _methodValue = req['_method']
        _methodValue = req['apiMethod'] if(_methodValue.nil? or _methodValue.empty?) # then try for apiMethod (preferred)
        unless(_methodValue.nil? or _methodValue.empty?)
          reqMethod = _methodValue
        else
          methodOverride = req.env['X-HTTP-Method-Override']
          reqMethod = methodOverride unless(methodOverride.nil? or methodOverride.empty?)
        end
        if(incomingReqMethod =~ /post/i and reqMethod =~ /get/i and @req.body and @req.body.respond_to?(:size) and @req.body.size and @req.body.respond_to?(:read) and @req.body.respond_to?(:rewind)) # then probably need to parse post body for params (like from a form!)
          # First peek at post body...looks like params?
          bodyPartial = @req.body.read(1000)
          if(bodyPartial =~ /^\s*[^=]+=./) # then looks like post payload has query string params!
            @req.body.rewind
            @combinedParams = @req.params # combo of get query string params + post payload params
          end
        end
      end
      # Return as downcased symbol
      @reqMethod = reqMethod.downcase.to_sym
      return @reqMethod
    end

    # Construct the core part of a reference URI, including the protocol,
    # the host, the port [if needed] and the given path.
    # [+pathBase+]  The path of the resource
    # [+returns+]   A String with the appropriate host, port, etc, before the path.
    def makeRefBase(pathBase)
      retVal =  "#{@req.scheme}://#{@rsrcHost}"
      retVal << ":#{@req.port}" unless(@req.port == 80)
      retVal << pathBase
      return retVal
    end

    # Construct an HTTP Not Implemented or an HTTP Method Not Allowed response for
    # this resource.
    #
    # - If the resource has at least 1 method but not the one in the
    #   request, then that requested method is Not Allowed (but other ones are).
    # - If the resource has no methods, then it has Not been Implemented yet at all.
    # [+returns+] The updated @resp http response object with the appropriate HTTP
    #             response information
    def notImplemented()
      methods = self.class::HTTP_METHODS.keys
      if(methods.empty?)
        @resp.status = HTTP_STATUS_NAMES[:'Not Implemented']
      else
        @resp.status = HTTP_STATUS_NAMES[:'Method Not Allowed']
        allow = ''
        methods.each_index { |ii|
          allow << "#{method.upcase}"
          allow << ", " unless(ii >= (methods.size - 1))
        }
        @resp['Allow'] = allow
      end
      @resp['Content-Length'] = '0'
      @resp.body = []
      return @resp
    end
  end # class Resource
end ; end # module BRL ; module REST
