#!/usr/bin/env ruby
require 'stringio'
require 'uri'
require 'cgi'
require 'digest/sha1'
require 'resolv'
require 'net/http'
require 'json'
require 'rack'
require 'brl/util/util'
require 'brl/cache/helpers/domainAliasCacheHelper'
require 'brl/cache/helpers/dnsCacheHelper'

module BRL #:nodoc:
module REST #:nodoc:
  
  class ApiCaller
    
    # Uses the global domain alias cache and methods
    include BRL::Cache::Helpers::DomainAliasCacheHelper
    include BRL::Cache::Helpers::DNSCacheHelper
    
    # Set up class instance variables
    class << self
      # @return [Boolean] indicating whether class-level resources have been dynamically
      #   found and stored already or not. i.e. so they are done once per process.
      attr_accessor :resourcesLoaded
      # @return [Symbol] indicating how this ApiCaller is being used. In :standalone mode,
      #   request timeouts and reattempt sleep/max-counts are very large to try very hard to work
      #   around network delays, downtimes, or other temporary errors. In :serverEmbedded mode,
      #   these settings are much smaller because a user is waiting for a response and we're tying up
      #   a request handler waiting for http requests to complete.
      attr_accessor :usageContext
      ApiCaller.resourcesLoaded = false
      ApiCaller.usageContext = :standalone # This is the default. Can be changed [for whole process!] to :serverEmbedded
    end
    
    # ------------------------------------------------------------------
    # ATTRIBUTES/PROPERTIES
    # ------------------------------------------------------------------

    # @return [Symbol] The scheme/protocol to use.
    #   @todo This should be HTTPS by default! GB API uses HTTPS preferentially! However, for
    #     now we default to :http to avoid breaking assumptive code.
    attr_reader :scheme
    # The host name at which to make API request. Set via <tt>#setHost</tt>.
    attr_reader :host
    # The URI path component specifying the resource's identity. Can be a <em>URI Template</em>.
    attr_reader :rsrcPath
    # The Genboree login name to use for the API request.
    attr_reader :login
    # The result of computing the SHA1 digest of the login and password (part of computing the auth token).
    attr_reader :loginPassDigest
    # The base URI for the API request (host + rsrcPath); will be filled in and auth parameters added later.
    attr_reader :apiUri
    # The _full_ URI used in the last API request. Computed at the last moment before the request is made.
    attr_reader :fullApiUri
    # The +Exception+ thrown in the last API request if any. This is usually something serious. NOT for HTTP error response.
    attr_reader :error
    # The current Net::HTTP object.
    attr_reader :http

    # The current HTTP timeout to be used for requests, in seconds.
    attr_accessor :httpTimeout
    # An instnace of a subclass of +HTTPResponse+ instance returned in the last completed API request.
    attr_accessor :httpResponse
    # The entire response as a Ruby Object (+Hash+), following successful parsing via a call to <tt>#parseRespBody</tt>.
    attr_accessor :apiRespObj
    # The 'status' part of the response as a Ruby Object (+Hash+), following successful parsing via a call to <tt>#parseRespBody</tt>.
    attr_accessor :apiStatusObj
    # The 'data' part of the response as a Ruby Object (+Hash+ or +Array+), following successful parsing via a call to <tt>#parseRespBody</tt>.
    attr_accessor :apiDataObj
    # The Content-Type (mime type as a String) to set in the HTTP Request header. By default this is Net/HTTP's default: 'application/x-www-form-urlencoded'
    attr_accessor :reqContentType
    # Hash of host names mapped to better replacements/aliases.
    attr_accessor :domainAliases
    # Hash mapping the canonicalAddress of hosts to [ LOGIN, PASS ] to use for that host. Used AUTOMATICALLY if present, rather than login+pass provided to new() or via setLoginInfo()
    attr_accessor :hostAuthMap
    # Where we'll keep the original host used to create this object (in case we end up using an alias instead)
    # * if non-nil then we're using an alias and some special measure will be taken when constructing actual API url
    attr_accessor :origHost
    # base factor for computing sleep time
    attr_accessor :sleepBase
    # max number of attempts
    attr_accessor :maxTimeoutRetry

    #   @todo This should be HTTPS by default! GB API uses HTTPS preferentially! However, for
    #     now we default to :http to avoid breaking assumptive code.
    DEFAULT_SCHEME = :http
    # All the HTTP response codes as numbers:
    HTTP_STATUS_CODES = Rack::Utils::HTTP_STATUS_CODES
    HTTP_STATUS_NAMES = {}
    # A map of each number to an official human readable name:
    HTTP_STATUS_CODES.each { |kk, vv| HTTP_STATUS_NAMES[vv.to_sym] = kk }

    # Maximum size of an unchunked body. Sizes over this (if size is available)
    # will trigger chunked transfer encoding for uploads.
    MAX_UNCHUNKED_SIZE = 100 * 1024
    # Convenience mapping of HTTP methods (as downcase +Symbols+) to
    # particular <tt>Net::HTTP</tt> clases.
    METHOD2HTTPCLASS =  {
                          :get => ::Net::HTTP::Get,
                          :put => ::Net::HTTP::Put,
                          :delete => ::Net::HTTP::Delete,
                          :post => ::Net::HTTP::Post,
                          :options => ::Net::HTTP::Options,
                          :head => ::Net::HTTP::Head
                        }
    # @return [Hash] Of appropriate timeout and sleep/reattempt settings depending on usage.
    REATTEMPT_SETTINGS =
    {
      :standalone     =>  # Can afford to wait a long time, spanning downtimes/crap networks/etc. E.g. for cluster jobs
      {
        :httpTimeout      => 1800,
        :sleepBase        => 20,
        :maxTimeoutRetry  => 10
      },
      :serverEmbedded =>  # Live web server, can't wait around too long for remote Genboree hosts...
      {
        :httpTimeout      => 60,
        :sleepBase        => 0.5,
        :maxTimeoutRetry  => 5
      }
    }
    
    def initialize(host, rsrcPath, login=nil, pass=nil)
      @host = @origHost = @http = @rsrcPath = @apiUri = @fullApiUrl = nil
      @scheme = DEFAULT_SCHEME
      setHost(host)
      setRsrcPath(rsrcPath)
      if(login.is_a?(Hash))
        @hostAuthMap = setHostAuthMap(login)
      elsif(login and pass)
        setLoginInfo(login, pass)
        @hostAuthMap = nil
      else
        @login = @loginPassDigest = @hostAuthMap = nil
      end
      @httpResponse = @apiRespObj = @apiStatusObj = @apiDataObj = @reqContentType = nil
      # Set http timeouts & request reattempt config based on ApiCaller.usageContext
      # - If no one has set the ApiCaller.usageContext class instance variable, then it's the usual standalone scenario
      # - Also use this if set to some unknown key
      ApiCaller.usageContext = :standalone if(!defined?(ApiCaller.usageContext) or !REATTEMPT_SETTINGS.key?(ApiCaller.usageContext))
      # - Regardless, now use ApiCaller.usageContext to get settings and initialize instance variables
      reattemptSettings = REATTEMPT_SETTINGS[ApiCaller.usageContext]
      @httpTimeout      = reattemptSettings[:httpTimeout]
      @sleepBase        = reattemptSettings[:sleepBase]
      @maxTimeoutRetry  = reattemptSettings[:maxTimeoutRetry]
    end
    
    
    # Set a new rsrcPath to use, presumably to a different resource or that will
    # retrieve a different representation of the resource. Will update the internal
    # apiUri (the basis of the request url) with the new rsrcPath.
    # [+rsrcPath+]  The path to the resource on the server, plus any parameters that
    #               modify the response representation. Can be a _URI_ _Template_.
    # [+returns+]   The new rsrcPath.
    def setRsrcPath(rsrcPath)
      @rsrcPath = rsrcPath.strip
      @rsrcPath << '?' unless(@rsrcPath.include?('?'))
      # Update @apiUri with appropriate full uri
      @apiUri = "#{@scheme}://#{@host}#{@rsrcPath}"
      return @rsrcPath
    end

    # Set a new host to use. If there is a rsrcPath set, will update the internal
    # apiUri (the basis of the request url) with the new host.
    # [+host+]  The host where the resource is located
    # [+returns+]  The new host.
    def setHost(host)
      @host = host.strip
      setRsrcPath(@rsrcPath) unless(@rsrcPath.nil?)
      return @host
    end

    # Set a new scheme/protocol. If there is a rsrcPath set, will update the internal apiUri.
    # @param [Symbol] The new scheme, as a downcase symbol. Suggest using @:https@.
    # @return [Symbol] The new scheme.
    def setScheme(scheme)
      @scheme = scheme
      setRsrcPath(@rsrcPath) unless(@rsrcPath.nil?)
      return @scheme
    end

    def cleanup()
      unless(@http.nil?)
        @http.finish rescue nil
      end
    end
    
    def setContentType(contentType='application/x-www-form-urlencoded')
      @reqContentType = contentType
      return @reqContentType
    end

    def getContentType()
      setContentType() unless(@reqContentType)
      return @reqContentType
    end

    # Make an HTTP GET request to the resource at the API URI.
    # [+varMap+]  [optional; default=nil] If you are using a _URI_ _Template_, you must provide a +Hash+ of
    #             template variable names to +String+ values; the variables will
    #             be automatically substituted with the matching values, which +APICaller+
    #             will properly escape for you. The variable names (the keys) can be
    #             +Symbols+ or +Strings+, as you wish. If you use a _URI_ _Template_ and fail
    #             to provide a full and proper +varMap+ to fill in your template, then <tt>#error</tt> will
    #             almost certainly be a <tt>URI::InvalidURIError</tt> because templates are not
    #             valid URIs and the core URI class knows that.
    #             * _Required_ if using _URI_ _Templates_
    #             * <em> Default: +nil+ (not using _URI_ _Templates_) </em>
    # [+payload+] [optional; default=nil] Payload to send along in the request body; will attempt to send,
    #             some implementations of the HTTP protocol go against the RFC and disallow request bodies
    #             even when the protocol doesn't prohibit one (GET is the most common victim)
    # [+&block+]  [optional] If a code block is given, then when the request is performed, rather than
    #             simply return an HTTPResponse with the entire response body already read into memory,
    #             chunks of the response body will be yielded to the given code block as they become
    #             available on the socket. NOTE: do not call parseRespBody() or other instance methods
    #             that need to have the full response body available...it won't be, because it was
    #             streamed through your code block rather than the whole thing being put into memory!
    # [+returns+] An instance of an <tt>::Net::HTTPResponse</tt> subclass or +nil+ if failed during
    #             request. Note that server will communicate problems with your
    #             request via a 4xx or 5xx series HTTP response, which would produce
    #             an +HTTPClientError+ or +HTTPServerError+ instance respectively and
    #             which would be returned here. If you get a +nil+ return value, then
    #             almost certainly you should examine <tt>#error</tt> to see
    #             what the +Exception+ was.
    def get(varMap=nil, payload=nil, &block)
      return doRequest(:get, varMap, payload, &block)
    end

    # Make an HTTP HEAD request to the resource at the API URI.
    # [+varMap+]  [optional; default=nil] If you are using a _URI_ _Template_, you must provide a +Hash+ of
    #             template variable names to +String+ values; the variables will
    #             be automatically substituted with the matching values, which +APICaller+
    #             will properly escape for you. The variable names (the keys) can be
    #             +Symbols+ or +Strings+, as you wish. If you use a _URI_ _Template_ and fail
    #             to provide a full and proper +varMap+ to fill in your template, then <tt>#error</tt> will
    #             almost certainly be a <tt>URI::InvalidURIError</tt> because templates are not
    #             valid URIs and the core URI class knows that.
    #             * _Required_ if using _URI_ _Templates_
    #             * <em> Default: +nil+ (not using _URI_ _Templates_) </em>
    # [+payload+] [optional; default=nil] Payload to send along in the request body; will attempt to send,
    #             some implementations of the HTTP protocol go against the RFC and disallow request bodies
    #             even when the protocol doesn't prohibit one (GET is the most common victim)
    # [+&block+]  [optional] If a code block is given, then when the request is performed, rather than
    #             simply return an HTTPResponse with the entire response body already read into memory,
    #             chunks of the response body will be yielded to the given code block as they become
    #             available on the socket. NOTE: do not call parseRespBody() or other instance methods
    #             that need to have the full response body available...it won't be, because it was
    #             streamed through your code block rather than the whole thing being put into memory!
    # [+returns+] An instance of an <tt>::Net::HTTPResponse</tt> subclass or +nil+ if failed during
    #             request. Note that server will communicate problems with your
    #             request via a 4xx or 5xx series HTTP response, which would produce
    #             an +HTTPClientError+ or +HTTPServerError+ instance respectively and
    #             which would be returned here. If you get a +nil+ return value, then
    #             almost certainly you should examine <tt>#error</tt> to see
    #             what the +Exception+ was.
    def head(varMap=nil, payload=nil, &block)
      return doRequest(:head, varMap, payload, &block)
    end

    # Make an HTTP OPTIONS request to the resource at the API URI.
    # [+varMap+]  [optional; default=nil] If you are using a _URI_ _Template_, you must provide a +Hash+ of
    #             template variable names to +String+ values; the variables will
    #             be automatically substituted with the matching values, which +APICaller+
    #             will properly escape for you. The variable names (the keys) can be
    #             +Symbols+ or +Strings+, as you wish. If you use a _URI_ _Template_ and fail
    #             to provide a full and proper +varMap+ to fill in your template, then <tt>#error</tt> will
    #             almost certainly be a <tt>URI::InvalidURIError</tt> because templates are not
    #             valid URIs and the core URI class knows that.
    #             * _Required_ if using _URI_ _Templates_
    #             * <em> Default: +nil+ (not using _URI_ _Templates_) </em>
    # [+payload+] [optional; default=nil] Payload to send along in the request body; will attempt to send,
    #             some implementations of the HTTP protocol go against the RFC and disallow request bodies
    #             even when the protocol doesn't prohibit one (GET is the most common victim)
    # [+&block+]  [optional] If a code block is given, then when the request is performed, rather than
    #             simply return an HTTPResponse with the entire response body already read into memory,
    #             chunks of the response body will be yielded to the given code block as they become
    #             available on the socket. NOTE: do not call parseRespBody() or other instance methods
    #             that need to have the full response body available...it won't be, because it was
    #             streamed through your code block rather than the whole thing being put into memory!
    # [+returns+] An instance of an <tt>::Net::HTTPResponse</tt> subclass or +nil+ if failed during
    #             request. Note that server will communicate problems with your
    #             request via a 4xx or 5xx series HTTP response, which would produce
    #             an +HTTPClientError+ or +HTTPServerError+ instance respectively and
    #             which would be returned here. If you get a +nil+ return value, then
    #             almost certainly you should examine <tt>#error</tt> to see
    #             what the +Exception+ was.
    def options(varMap=nil, payload=nil, &block)
      return doRequest(:options, varMap, payload, &block)
    end

    # Make an HTTP PUT request to the resource at the API URI.
    # Currently, <tt>#put</tt> should only be used for 'small' payloads although 'small'
    # is really a function of your available RAM...we've been using small as a
    # 100MB data representation.
    # [+payload+] [optional; default=nil] The data representation, as a +String, that will form the body
    #             of the HTTP request, if such data is required.
    # [+varMap+]  [optional; default=nil] If you are using a _URI_ _Template_, you must provide a +Hash+ of
    #             template variable names to +String+ values; the variables will
    #             be automatically substituted with the matching values, which +APICaller+
    #             will properly escape for you. The variable names (the keys) can be +Symbols+
    #             or +Strings+, as you wish. If you use a _URI_ _Template_ and fail to provide
    #             a full and proper +varMap+ to fill in your template, then <tt>#error</tt> will
    #             almost certainly be a <tt>URI::InvalidURIError</tt> ; templates are not
    #             valid URIs and the core URI class knows that.
    #             * _Required_ if using _URI_ _Templates_
    #             * <em> Default: +nil+ (not using _URI_ _Templates_) </em>
    # [+&block+]  [optional] If a code block is given, then when the request is performed, rather than
    #             simply return an HTTPResponse with the entire response body already read into memory,
    #             chunks of the response body will be yielded to the given code block as they become
    #             available on the socket. NOTE: do not call parseRespBody() or other instance methods
    #             that need to have the full response body available...it won't be, because it was
    #             streamed through your code block rather than the whole thing being put into memory!
    # [+returns+] An instance of an <tt>::Net::HTTPResponse</tt> subclass or +nil+ if failed during
    #             request. Note that server will communicate problems with your
    #             request via a 4xx or 5xx series HTTP response, which would produce
    #             an +HTTPClientError+ or +HTTPServerError+ instance respectively and
    #             which would be returned here. If you get a +nil+ return value, then
    #             almost certainly you should examine <tt>#error</tt> to see
    #             what the +Exception+ was.
    def put(payload=nil, varMap=nil, &block)
      if(payload.is_a?(Hash) && !varMap.is_a?(Hash)) # then was called as put(varMap, payload) like some other methods are
        retVal = doRequest(:put, payload, varMap, &block)
      else # called as expected and as documented
        retVal = doRequest(:put, varMap, payload, &block)
      end
      return retVal
    end

    # Make an HTTP DELETE request to the resource at the API URI.
    # [+varMap+]  varMapIf you are using a _URI_ _Template_, you must provide a +Hash+ of
    #             template variable names to +String+ values; the variables will
    #             be automatically substituted with the matching values, which +APICaller+
    #             will properly escape for you. The variable names (the keys) can be +Symbols+
    #             or +Strings+, as you wish. If you use a _URI_ _Template_ and fail to provide
    #             a full and proper +varMap+ to fill in your template, then <tt>#error</tt> will
    #             almost certainly be a <tt>URI::InvalidURIError</tt> ; templates are not
    #             valid URIs and the core URI class knows that.
    #             * _Required_ if using _URI_ _Templates_
    #             * <em> Default: +nil+ (not using _URI_ _Templates_) </em>
    # [+&block+]  [optional] If a code block is given, then when the request is performed, rather than
    #             simply return an HTTPResponse with the entire response body already read into memory,
    #             chunks of the response body will be yielded to the given code block as they become
    #             available on the socket. NOTE: do not call parseRespBody() or other instance methods
    #             that need to have the full response body available...it won't be, because it was
    #             streamed through your code block rather than the whole thing being put into memory!
    # [+returns+] An instance of an <tt>::Net::HTTPResponse</tt> subclass or +nil+ if failed during
    #             request. Note that server will communicate problems with your
    #             request via a 4xx or 5xx series HTTP response, which would produce
    #             an +HTTPClientError+ or +HTTPServerError+ instance respectively and
    #             which would be returned here. If you get a +nil+ return value, then
    #             almost certainly you should examine <tt>#error</tt> to see
    #             what the +Exception+ was.
    def delete(varMap=nil, payload=nil, &block)
      return doRequest(:delete, varMap, payload, &block)
    end
    
    
    # Did the last API request succeed?
    # For success, ALL of the following must hold:
    # * A request must have been made previously.
    # * The request must not have thrown an exception.
    # * The request must have resulted in an <tt>::Net::HTTPResponse</tt> object of some kind.
    # * That response object CANNOT be an instance of ::Net::HTTPClientError</tt> nor of
    #   <tt>::Net::HTTPServerError</tt>, or of one of their subclasses. (This means that 1xx,
    #   2xx, and 3xx HTTP response codes are all types of "success")
    # [+returns+] true or false
    def succeeded?()
      retVal =  ( !@httpResponse.nil? and
                    @error.nil? and
                    @httpResponse.is_a?(::Net::HTTPResponse) and
                    !@httpResponse.is_a?(::Net::HTTPClientError) and
                    !@httpResponse.is_a?(::Net::HTTPServerError)
                )
      return retVal
    end

    # Did the last request fail?
    # For failure, ANY of the following must hold:
    # * A request has not been made yet.
    # * The request threw an exception.
    # * The request did not resulted in an <tt>::Net::HTTPResponse</tt> object of some kind.
    # * That response object is an instance of <tt>::Net::HTTPClientError</tt> or of
    #   <tt>::Net::HTTPServerError</tt>, or of one of their subclasses. (i.e. a 4xx
    #   or 5xx type HTTP error resulted)
    # [+returns+] true or false
    def failed?()
      return !succeeded?()
    end

    # Get the response body of the last request (if there was one and it worked).
    # This is the same as calling <tt>#httpResponse.body</tt>, so it's really just a convenience
    # although unlike that call it shouldn't _crash_ if there is no +httpResponse+ yet
    # (you detect this in return and can handle the issue)
    # [+block+]   [optional] If provided, then read only a chunk from the socket and yield to the code block.
    #             Otherwise, read the whole body and return it.
    # [+returns+] The http response's body [payload] as a +String+, or +nil+ if there
    #             is no +httpResponse+ (due to failure or no request done yet)
    def respBody(&block)
      retVal = nil
      begin
        if(@httpResponse)
          if(block_given?)
            @httpResponse.read_body(&block)
          else
            retVal = @httpResponse.read_body()
          end
        end
      rescue => err
        $stderr.puts "#{self.class}##{__method__}: ERROR! err => #{err.inspect}\n#{err.backtrace.join("\n")}"
        retVal = err
      end
      return retVal
    end

    # Tries to parse the response body of the last request and return the corresponding
    # Ruby object. Structured formats should produce Ruby data structures such as
    # Arrays of Hashes, Hashes, etc. Formats corresponding to unstructured text
    # (eg :LFF) will just return the raw <tt>#httpResponse.body</tt> +String+ as-is.
    #
    # Sets the <tt>#apiRespObj</tt> attribute, for reference elsewhere or repeated access.
    #
    # For convenient access, also sets the <tt>#apiDataObj</tt> and
    # <tt>#apiStatusObj</tt> attributes which are the data and status objects
    # in a structured response body (these are standard in all structured Genboree responses).
    #
    # This method will read the whole response body into memory (if it hasn't been already) prior
    # to parsing it.
    #
    # NOTE: if you think the response body is likely to be "large" (20MB+), as is
    # common for LFF), then you should AVOID THIS METHOD and make use of
    # <tt>#respBody</tt> ... by providing a code block to that method,
    # you will be given _segments_ of the body that are easy to manage. Look up
    # <tt>::Net::HTTPResponse#read_body</tt> for more info.
    #
    # TODO: make this method more intelligent. For example, if format not provided, this
    # method should _determine_ the format dynamically based on the +Content-Type+
    # header of the <tt>#httpResponse</tt>. The server is supposed to set that for each of
    # the possible representation formats.
    #
    # Currently, only :JSON and :LFF parsing are supported.
    #
    # [+format+]  [optional; default=:JSON] A constant (+Symbol+) corresponding to what format to treat the
    #             response body as; currently either :JSON or :LFF.
    # [+returns+] A Ruby object. Typically either an +Array+ or +Hash+ corresponding
    #             the the structured representation or a +String+ for things like
    #             raw tab-delimited text (e.g. <tt>:LFF</tt>. Returns +nil+ or a
    #             Ruby +Exception+ instance if cannot parse the response body
    #             (e.g. maybe there isn't one, request failed, etc); the +Exception+
    #             may provide insight into what went wrong.
    def parseRespBody(format=:JSON)
      retVal = nil
      begin
        if(@httpResponse)
          if(format == :LFF)
            retVal = @httpResponse.body
          elsif(format == :JSON)
            retVal = JSON.parse(@httpResponse.body)
          else
            raise ArgumentError.new("ERROR: the format #{format.inspect} is not supported")
          end
        end
      rescue => err
        retVal = err
      end
      @apiRespObj = retVal
      # Try to isolate the 'data' and 'status' parts of the response
      if(retVal.nil? or retVal.is_a?(Exception) or !retVal.is_a?(Hash))
        @apiDataObj = @apiStatusObj = nil
      else
        @apiDataObj = @apiRespObj['data']
        @apiStatusObj = @apiRespObj['status']
      end
      return retVal
    end

    # This method handles gateway timeout or server temporarily unavailable # errors
    # @return [Symbols,nil] @nil@ indicates no request was made or
    #   no timeout; the @Symbols :httpGatewayTimeout@ and
    #   @:httpServiceUnavailable@ indicate HTTPGatewayTimeOut error and
    #   504 HTTPServiceUnavailable error, respectively
    def lastTimeOut()
      retVal = nil
      if(@httpResponse)
        if(@httpResponse.is_a?(::Net::HTTPGatewayTimeOut))
          retVal = :httpGatewayTimeout
        elsif(@httpResponse.is_a?(::Net::HTTPServiceUnavailable))
          retVal = :httpServiceUnavailable
        end
      end
      return retVal
    end
    
    def setLoginInfo(login, pass=nil)
      retVal = true
      if(login.is_a?(Hash))
        @hostAuthMap = setHostAuthMap(login)
        @login = @loginPassDigest = nil
      elsif(login and pass)
        @login = login
        @loginPassDigest = SHA1.hexdigest("#{login}#{pass}")
        @hostAuthMap = nil
      else
        raise ArgumentError, "ERROR: must call #{__method__}() with either login and pass, or with a host->authRec map."
      end
      return retVal
    end
    
    # Returns new hostAuthMap with the passwords all changed to login-password digest instead
    def setHostAuthMap(hostAuthMap)
      @hostAuthMap = nil
      if(hostAuthMap.is_a?(Hash))
        @hostAuthMap = {}
        hostAuthMap.each_key { |canonicalAddress|
          authRec = hostAuthMap[canonicalAddress]
          login = authRec[0]
          newAuthRec = []
          newAuthRec[0] = login
          newAuthRec[1] = SHA1.hexdigest("#{login}#{authRec[1]}")
          @hostAuthMap[canonicalAddress] = newAuthRec
        }
      end
      return @hostAuthMap
    end
    
    # Convenience class method for doing host-alias replacement from this or other code
    def self.applyDomainAliases(url)
      retVal = url
      uri = URI.parse(url)
      domainAlias = self.getDomainAlias(uri.host)
      if(domainAlias) # then have an alias we should be using
        # Keep copy of original host dev used when making this ApiCaller request
        origHost = uri.host
        # Replace host with better alias
        uri.host = domainAlias
        # We'll try to add a useHost parameter to the uri, unless calling code already has that parameter [for some other purpose, probably]
        uri.query ||= ""
        queryParams = CGI.parse(uri.query)
        unless(queryParams.key?('useHost')) # then dev doesn't have their own useHost param
          # add useHost param containing original host used to instantiate this object
          escOrigHost = CGI.escape(origHost)
          uri.query += '&' unless(uri.query.empty? or uri.query[-1].ord == 38)
          uri.query += "useHost=#{escOrigHost}"
        end
        # Rebuild url now that any replacing is done
        retVal = uri.to_s
      end
      return retVal
    end

    # Returns the complete API URI including auth parameters and filling
    # in any template variables if possible. Useful for pasting into a web-browser
    # or double-checking what the +ApiCaller+ is going to use (+/-) for the URI when
    # you finally call <tt>#get</tt> or <tt>#put</tt> or <tt>#delete</tt>.
    # Typically you don't need this method and it's only used internally;
    # main use would be for debugging your code.
    #
    # This is always a valid URI because the auth tokens are recomputed everytime.
    # In contrast, the <tt>#fullApiUri</tt> attribute will contain the URI that
    # apiCaller _used_ to make the last request--and thus its auth token is invalid!
    #
    # [+varMap+]  [optional; default=nil] If you are using a _URI_ _Template_, you must provide a +Hash+ of
    #             template variable names to +String+ values; the variables will
    #             be automatically substituted with the matching values, which
    #             +APICaller+ will properly escape for you. The variable names (the keys)
    #             can be +Symbols+ or +Strings+, as you wish. If you use a _URI_ _Template_
    #             and fail to provide a full and proper +varMap+ to fill in your template,
    #             then <tt>#error</tt> will almost certainly be a <tt>URI::InvalidURIError</tt>;
    #             templates are not valid URIs and the core URI class knows that.
    #             * _Required_ if using _URL_ _Templates_
    #             * <em> Default: +nil+ (not using _URI_ _Templates_) </em>
    # [+returns+] The complete API URI the +ApiCaller+ could use to make the request.
    def makeFullApiUri(varMap=nil, addAuth=true)
      retVal = fillApiUriTemplate(varMap, true)
      return ( addAuth ?  addAuthParams(retVal) : retVal )
    end

    # Fill in the current API URI template with variables if needed. Used internally.
    # [+returns+] [optiona; default=nil] The map of template variable names to +String+ values.
    #             * _Required_ if using _URL_ _Templates_
    #             * <em> Default: +nil+ (not using _URI_ _Templates_) </em>
    # [+returns+] API URI with any template variables filled in, as a +String+.
    def fillApiUriTemplate(varMap=nil, applyAliases=false)
      filledApiUri = @apiUri.dup
      unless(varMap.nil? or varMap.empty?)
        varMap.each_key { |variable|
          varValue = varMap[variable]
          # Do any convenience preprossing for known types
          newVarValue = ''
          if(varValue.is_a?(Array))
            varValue.each_index { |ii|
              val = varValue[ii]
              newVarValue << CGI.escape(val)
              newVarValue << ',' unless(ii >= (varValue.size - 1))
            }
            varValue = newVarValue
          else
            varValue = CGI.escape(varValue)
          end
          # Note: the code below should allow users to use +Symbols+ or +Strings+
          # as their URL template variable names.
          filledApiUri.gsub!(%r@\{#{variable.to_s}\}@, varValue)
        }
      end
      # We should now have a valid URI in filledApiUri (everything minus authParams that go on end)
      # Apply any host aliases:
      filledApiUri = ApiCaller.applyDomainAliases(filledApiUri) if(applyAliases)
      return filledApiUri
    end

    # ########################################################################
    protected # METHODS
    # ########################################################################

    # Make HTTP request using appropriate class based on the method. Make use
    # of payload (representation) string if provided. If the URL is a template,
    # use varMap hash to fill in template variables. Used internally.
    # [+method+]  The HTTP method for the request, as a downcase +Symbol+
    # [+varMap+]  [optional; default=nil] The map of template variable names to +String+ values.
    #             * _Required_ if using _URL_ _Templates_
    #             * <em> Default: +nil+ (not using _URI_ _Templates_) </em>
    # [+payload+] The body of the request, as a +String+. Must already be in proper representation
    #             (e.g. already in JSON format or LFF, as is appropriate for the resource and method).
    # [+&block+]  [optional] If a code block is given, then when the request is performed, rather than
    #             simply return an HTTPResponse with the entire response body already read into memory,
    #             chunks of the response body will be yielded to the given code block as they become
    #             available on the socket. NOTE: do not call parseRespBody() or other instance methods
    #             that need to have the full response body available...it won't be, because it was
    #             streamed through your code block rather than the whole thing being put into memory!
    # [+returns+] An instance of an <tt>::Net::HTTPResponse</tt> subclass or +nil+ if failed during
    #             request. Note that server will communicate problems with your
    #             request via a 4xx or 5xx series HTTP response, which would produce
    #             an +HTTPClientError+ or +HTTPServerError+ instance respectively.
    #             NOTE: if this is an internal Api request (isInternalApiCall is true) then this will
    #             return the response body (the response payload) as a string.
    def doRequest(method, varMap=nil, payload=nil, &block)
      retVal = nil
      payload = "" unless(payload)
      # Clear out stuff related to previous request, if any
      @httpResponse = @apiRespObj = @apiStatusObj = @apiDataObj = nil
      # Check that our @rsrcPath looks appropriate
      unless(@rsrcPath =~ %r{^/REST/v[^/]+/}) # then the rsrcPath doesn't look like a Genboree API one
        raise "ERROR: The rsrcPath #{@rsrcPath.inspect} does not even resemble a valid Genboree REST API resource path. Maybe you forgot to set it or something?"
      end
      # First, is there a gbKey somewhere in the apiUri? If so, we shouldn't need login/pass info
      @haveGbKey = (@apiUri =~ /gbKey=[^&#]/)
      if((@login.nil? or @loginPassDigest.nil?) and !(@haveGbKey or @hostAuthMap.is_a?(Hash)))  # Missing auth info...set "empty" login & pass for "Public" sort of access
        setLoginInfo("", "")
        # raise ArgumentError.new("ERROR: You have not set any login and password to use, nor set any hostAuthMap to use, nor used a gbKey in URL, either when you created the ApiCaller object or by using setLoginInfo(). Thus, there is not enough information to process the API call.")
      end
      # Fill in URI Template variables, if any, and add auth info to end of URI
      @fullApiUri = makeFullApiUri(varMap)
      # Use Net::Http to submit...save response and such...use a timeout as best possible
      httpClass = METHOD2HTTPCLASS[method]
      terr = err = resp = nil
      begin
        urlObj = URI.parse(@fullApiUri)
        req = httpClass.new(urlObj.request_uri)
        # Set the content type
        contentType = getContentType()
        req.set_content_type(contentType)
        # Init an HTTP session (we will have to close it)
        connectionAttempt = sleepTime = 0
        gotConn = false
        maxTimeoutRetry = (block_given? ? 1 : @maxTimeoutRetry) # Attempt the request only once if 'chunked' downloading is requested
        while(connectionAttempt < maxTimeoutRetry and !gotConn)
          # Feedback only for attempts AFTER the first try:
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Attempting API HTTP connection # #{connectionAttempt + 1}") if(connectionAttempt > 0)
          terr = err = resp = nil
          begin
            self.cleanup()
            @http = ::Net::HTTP.start(urlObj.host, urlObj.port)
            @http.read_timeout = @httpTimeout
            if(payload) # Then prep body appropriately
              if(payload.is_a?(IO))
                payload.rewind() if(payload.respond_to?(:rewind) and connectionAttempt > 0)
                req.body_stream = payload
                # We need a Content-Length for body_stream if can't do chunking approach above!
                if(payload.respond_to?(:size))
                  req['Content-Length'] = payload.size()
                elsif(payload.is_a?(File))
                  req['Content-Length'] = File.size(payload)
                else
                  raise ArgumentError, "ERROR: the payload is some kind of IO but doesn't respond to size(). Because current nginx doesn't support chunked encoding, a valid Content-Length is required for all request body objects."
                end
              elsif(payload.is_a?(String))
                req.body = payload
              else # try to_s to convert payload object to String body content
                req.body = payload.to_s
              end
              # body or body_stream now set; can do request
            end
            sleepTime = (@sleepBase * connectionAttempt**2)
            # Feedback only if we'll be sleeping before a REATTEMPT:
            $stderr.debugPuts(__FILE__, __method__, "SLEEP", "Going to sleep for #{sleepTime.inspect} seconds") if(sleepTime > 0)
            sleep(sleepTime)
            @http.request(req) { |resp|
              @httpResponse = resp
              if(lastTimeOut.nil?) # regular http response of some kind
                # Feedback only if we [finally] got a connection during a REATTEMPT:
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Request completed.") if(connectionAttempt > 1)
                if(block_given?) # then user want to stream each response chunk through their code block (big download?)
                  @httpResponse.read_body(&block)
                end
                gotConn = true
              else
                terr = @httpResponse
                $stderr.debugPuts(__FILE__, __method__, "WARNING", "Service temporarily unavailable or Timeout thrown by gateway/proxy server we are talking to. i.e. Http response was a #{terr.class}.")
              end
            }
          rescue Timeout::Error => terr
            $stderr.puts "WARNING: Timeout::Error thrown. #{terr.inspect} (message: #{terr.message})"
          rescue => connErr
            err = connErr
            $stderr.puts "ERROR: making the request threw an error.\n  Error Message: #{err.message}\n  Error Backtrace:\n" + err.backtrace.join("\n")
            break
          end
          connectionAttempt += 1
        end
      rescue => err
        $stderr.puts "ERROR: making the request threw an error.\n  Error Message: #{err.message}\n  Error Backtrace:\n" + err.backtrace.join("\n")
      end
      # Capture response if any and error if any.
      @error = (terr or err)
      retVal = @httpResponse
      # Return whatever HTTPResponse we got, if any
      return retVal
    end
    
    # TODO: MOVE TO WRAPPERAPICALLER or similar. This is VERY GENBOREE SPECIFIC.
    # - clean ApiCaller should not use Abstraction classes, etc.
    # Append the 3 required Genboree authentication parameters to the end of the
    # resource URI. Used internally.
    # [+apiUri+]  The partial API URI to add the auth paramters to.
    # [+returns+] The completely filled in URI, ready to use. Also saved in <tt>#fullApiUri</tt>
    def addAuthParams(apiUri)
      authRec = login = loginPassDigest = nil
      apiUri.strip!
      apiUri << "?" unless(apiUri.include?('?'))
      if(@hostAuthMap.is_a?(Hash) or (@login and @loginPassDigest)) # have auth info to use
        if(@hostAuthMap.is_a?(Hash)) # then have host auth Hash, use it!
          authRec = Abstraction::User.getAuthRecForUserAtHost(@host, @hostAuthMap)
          # If have authRec, use it, else missing auth info for @host
          if(authRec and authRec[0] and authRec[1])
            login = authRec[0]
            loginPassDigest = authRec[1]
          else # user has no entry for this host, fall back to gbKey or even straight public access
            # Either we have a gbKey in the URL (so fine, as is) or we don't (hope the resources is public)
            # Regardless, leave url as-is
            @fullApiUri = apiUri
          end
        else # must have @login and @loginPassDigest instead
          login = @login
          loginPassDigest = @loginPassDigest
        end
        # Now have login and loginPassDigest to use:
        gbTime = Time.now.to_i.to_s
        gbToken = SHA1.hexdigest("#{apiUri}#{loginPassDigest}#{gbTime}")
        @fullApiUri = "#{apiUri}&gbLogin=#{CGI.escape(login)}&gbTime=#{CGI.escape(gbTime)}&gbToken=#{CGI.escape(gbToken)}"
      elsif(@haveGbKey) # have gbKey, so we're all set
        @fullApiUri = apiUri
      else # we have no valid login info available nor a gbkey, just leave things alone
        @fullApiUri = apiUri
      end
      return @fullApiUri
    end
    
  end
  
end; end