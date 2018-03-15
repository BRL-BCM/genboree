#!/usr/bin/env ruby
# Predeclare class
module BRL ; module Genboree ; module REST ; class ApiCaller ; end ; end ; end ; end

# Requires
require 'timeout'
require 'stringio'
require 'uri'
require 'cgi'
require 'digest/sha1'
require 'resolv'
require 'net/http'
require 'net/https'
require 'json'
require 'rack'
require 'brl/util/util'
require 'brl/genboree/abstract/resources/user'
require 'brl/rackups/thin/genboreeRESTRackup.rb'
require 'brl/cache/helpers/domainAliasCacheHelper'
require 'brl/cache/helpers/dnsCacheHelper'

module BRL #:nodoc:
module Genboree #:nodoc:
module REST #:nodoc:

  class SpecialApiCallerConnTimeout < Timeout::Error ; end

  # == Overview
  # This class assists with some of the routine and mundane tasks required in
  # making {Genboree API}[http://www.genboree.org/java-bin/showHelp.jsp?topic=restAPIOverview]
  # calls. It will construct the appropriate full URL (including required auth params)
  # and compute the authentication parameters for the API based on login
  # information you provide and will wrap the API request
  # such that HTTP error responses are captured and available for inspection.
  # Some convenience functions for getting back the standard API status info or
  # just the data section are provided (<em>currently only available for JSON
  # representations</em>); these are very convenient.
  #
  # There are provisions for _reusing_ a URL pattern and saved information (such as
  # authentication information) so you only have to set it once and then provide
  # bind variable values when you call <tt>#get</tt>, <tt>#put</tt>, or <tt>#delete</tt>. You do this by
  # providing a _URI_ _Template_ ({read more}[http://blog.welldesignedurls.org/2007/01/03/about-uri-templates/])
  # when instantiating the class. That way you can use the URL template over
  # and over with different (dynamically bound) values...typically to access
  # different resources of the same type. Plus +ApiCaller+ will take care of
  # <tt>CGI.escaping</tt> the variable values if you use it this way.
  #
  # == Notes
  # The <tt>#get</tt>, <tt>#put</tt>, and <tt>#delete</tt> methods of this class correspond to the
  # HTTP Methods. Currently, <tt>#put</tt> should only be used for 'small' payloads although 'small'
  # is really a function of your available RAM...we've been using small as a
  # <100MB data representation.
  #
  # <em>Do NOT put passwords in scripts or as arguments on the command line. They can be seen
  # by everybody. Similarly, using passwords within IRB is not wise. Use an approach like
  # DBRC which uses a config file that must be owned and viewable only by you to contain
  # passwords [similar to SSH's restrictions on private key files].</em>
  #
  # == Example usage:
  #
  # === E.g. No URL Template
  #   require 'brl/genboree/rest/apiCaller'
  #   apiCaller = BRL::Genboree::REST::ApiCaller.new('genboree.org', '/REST/v1/grp/ARJ')
  #   apiCaller.setLoginInfo('myLogin', 'myPass')
  #   apiCaller.get()
  #   if(apiCaller.succeeded?)
  #     puts apiCaller.parseRespBody().inspect()
  #   else
  #     puts apiCaller.error.inspect()
  #   end
  #
  # === E.g. URL Template (reused in a loop)
  #   require 'brl/genboree/rest/apiCaller'
  #   group = 'myGroup'
  #   dbList = ['db1', 'db2', 'rhesus db']
  #   apiCaller = BRL::Genboree::REST::ApiCaller.new(
  #                 'proline.brl.bcm.tmc.edu',
  #                 '/REST/v1/grp/{grp}/db/{db}',
  #                 true)
  #   apiCaller.setLoginInfo('myLogin', 'myPass')
  #   dbList.each { |dbName|
  #     httpResp = apiCaller.get( { 'grp' => group, 'db' => dbName })
  #     # [do something with result of this db resource request]
  #   }
  class ApiCaller
    # ------------------------------------------------------------------
    # MIX-INS
    #------------------------------------------------------------------

    # Uses the global domain alias cache and methods
    include BRL::Cache::Helpers::DomainAliasCacheHelper
    include BRL::Cache::Helpers::DNSCacheHelper

    # ------------------------------------------------------------------
    # CLASS INSTANCE VARIABLES
    # ------------------------------------------------------------------

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
    # The open-connection timeout specifically for HTTPS. Since we try HTTPS first, need to establish quickly whether it is supported or not.
    attr_accessor :maxOpenTimeout
    # An instance of a subclass of +HTTPResponse+ instance returned in the last completed API request.
    attr_accessor :httpResponse 
    # Boolean to decide whether we immediately skip HTTPS (and move onto trying HTTP) or not 
    attr_accessor :skipHttps
    # The entire response as a Ruby Object (+Hash+), following successful parsing via a call to <tt>#parseRespBody</tt>.
    attr_accessor :apiRespObj
    # The 'status' part of the response as a Ruby Object (+Hash+), following successful parsing via a call to <tt>#parseRespBody</tt>.
    attr_accessor :apiStatusObj
    # The 'data' part of the response as a Ruby Object (+Hash+ or +Array+), following successful parsing via a call to <tt>#parseRespBody</tt>.
    attr_accessor :apiDataObj
    # The Content-Type (mime type as a String) to set in the HTTP Request header. By default this is Net/HTTP's default: 'application/x-www-form-urlencoded'
    attr_accessor :reqContentType
    # Flag indicating whether we are making an internal API call or just a regular remote API call. For using ApiCaller to implement API calls.
    attr_accessor :isInternalApiCall
    attr_accessor :internalRespBody
    # Dup'd copy of the rackEnv when doing an internal request so can simulate a handled http call correctly
    attr_accessor :internalRequestEnv
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
    # All the HTTP response codes as numbers:
    HTTP_STATUS_CODES = Rack::Utils::HTTP_STATUS_CODES
    HTTP_STATUS_NAMES = {}
    # A map of each number to an official human readable name:
    HTTP_STATUS_CODES.each { |kk, vv| HTTP_STATUS_NAMES[vv.to_sym] = kk }
    # Max size of payload buffer when trying to do parseRespBody(). Mainly protection against MASSIVE
    #  non-JSON payloads being blindly processed with parseRespBody().
    MAX_JSON_BUFFER = 100 * 1024 * 1024

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
        :maxTimeoutRetry  => 10,
        :maxOpenTimeout   => 5
      },
      :serverEmbedded =>  # Live web server, can't wait around too long for remote Genboree hosts...
      {
        :httpTimeout      => 60,
        :sleepBase        => 0.5,
        :maxTimeoutRetry  => 5,
        :maxOpenTimeout   => 3
      }
    }

    # TODO: add Hash of host => auth records to be used for auth info. Update setHost, setLogin, etc. Use domain_alias_file if available...

    # CONSTRUCTOR. Create an object you can use to make the Genboree API call.
    # Sets the <tt>#apiUri</tt> attribute based on the +host+ and +rsrcPath+ arguments.
    #
    # [+host+]      The host to which the request will be made.
    # [+rsrcPath+]  The resource path to which to send the request. Essentially
    #               the 'Resource Path (rsrcPath)' mentioned in the {Genboree API
    #               Help pages}[http://www.genboree.org/java-bin/showHelp.jsp?topic=restAPIOverview],
    #               together with any resource-specific paramters.
    #               Recommended to end with a '?' followed by any resource-specific
    #               parameters. No API authentication tokens allowed; those will
    #               be added automatically.
    #
    #               Can also be a _URI_ _Template_
    #               ({read more}[http://blog.welldesignedurls.org/2007/01/03/about-uri-templates/])
    #               in which case you will provide a +Hash+ of template variable names
    #               to values later when you make the API request via <tt>#get</tt> or
    #               <tt>#put</tt> or <tt>#delete</tt>. The
    #               Genboree API Help}[http://www.genboree.org/java-bin/RhesusMacaque/showHelp.jsp?topic=restAPIOverview]
    #               actually displays _URI_ _Templates_ to communicate the general
    #               pattern of a resource path; so you pretty much copy-and-paste (!)
    #               ApiCaller will take care of CGI.escaping the variable values
    #               if you use it this way. See the Example usage section.
    # [+login+]     [optional; default=nil] EITHER: a String which is the Genboree login which you will be useing for authentication.
    #               OR a Hash mapping the canonical address of host names to 3-column Arrays records with the login & password & hostType (:internal or :external)
    #               in the three columns (a hostAuthMap).
    #               If the Hash is provided, the appropriate login + password will be used depending on the host being contacted (even if you
    #               change the host via setHost()).
    #               * Set via #setLoginInfo
    # [+pass+]      [optional; default=nil] If login is a hostAuthMap Hash, then this should be nil. If login is a String with the login to use then
    #               this is a String with the matching password for the Genboree login. Note that the
    #               password you provide here will _not_ be stored directly in this
    #               object, only a salted digest will be stored in memory associated
    #               with this object. We recommend you _never_ hard-code passwords
    #               in any of your code and _never_ type them on the command line
    #               when running your programs. (Others can easily see them in these
    #               cases.)
    #               * Set via #setLoginInfo
    # [+returns+]   Instance of +ApiCaller+
    def initialize(host, rsrcPath, login=nil, pass=nil)
      @host = @origHost = @http = @rsrcPath = @apiUri = @fullApiUrl = nil
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
      @internalRespBody = nil
      @isInternalApiCall = false
      # Set http timeouts & request reattempt config based on ApiCaller.usageContext
      # - If no one has set the ApiCaller.usageContext class instance variable, then it's the usual standalone scenario
      # - Also use this if set to some unknown key
      ApiCaller.usageContext = :standalone if(!defined?(ApiCaller.usageContext) or !REATTEMPT_SETTINGS.key?(ApiCaller.usageContext))
      # - Regardless, now use ApiCaller.usageContext to get settings and initialize instance variables
      reattemptSettings = REATTEMPT_SETTINGS[ApiCaller.usageContext]
      @httpTimeout      = reattemptSettings[:httpTimeout]
      @sleepBase        = reattemptSettings[:sleepBase]
      @maxTimeoutRetry  = reattemptSettings[:maxTimeoutRetry]
      @maxOpenTimeout   = reattemptSettings[:maxOpenTimeout]
      # By default, we do NOT skip HTTPS
      @skipHttps = false
    end

    # CLEANUP. Important to call this if you are reading through the response in chunks
    # yourself using #read_body() (say for a large download) rather than using methods
    # that will grab the whole response into memory and then maybe parse it for you, etc.
    # This will ensure the current Net::HTTP instance @http is closed.
    def cleanup()
      unless(@http.nil?)
        @http.finish rescue nil
      end
      if(@internalRequestEnv.is_a?(Hash))
        @internalRequestEnv.clear()
      end
      @internalRequestEnv = @httpResponse = @http = nil
    end

    # INIT. Set up an internal Api request (api call from within an api call handler on the server)
    # The env MUST be a Rack-compliant env hash. Preferrably (only) via Rack::Request#env (e.g. req.env).
    # It will be duplicated and then selectively altered.
    # [+env+]  The Rack-compliant env hash or empty Hash if code not being run in web-server process.
    #          - NOTE: if env['HTTP_HOST'] != @host, then the call is not actually internal after all. i.e.
    #            the API handler on host X is making an "internal" call to API on host Y. This method is
    #            smart enough to notice this and will NOT do an internal call. It will do an external call.
    #            The checking is done by IP address so genboree.org and www.genboree.org will match.
    # [+domainAlias+] [optional] Provide an alternative (e.g. private internal domain name) domain name
    #                 for the CALLING API handler (i.e. an alias name for env['HTTP_HOST']). This allows
    #                 say valine.brl.bcmd.bcm.edu to be provided for genboree.org and they will match even
    #                 though the IPs are different.
    # [+returns+]  true if an internal call will be made, false otherwise
    def initInternalRequest(env, domainAlias=nil)
      raise ArgumentError, "BUG: the 'env' parameter cannot be nil. If calling this method outside a web-server process, you can provide EMPTY hash to indicate you have no valid Rack-env" if(env.nil?)
      # Have we been given sufficent info in env to set up internal request?
      if(!env.empty? and env['HTTP_HOST'])
        # Is this really a internal request (i.e. to same machine?) or is the request
        # going out to a different API server machine?
        # - We'll use so-called "canonical address" to do this check, which has the benefit of being globally cached.
        # - We'll check the domain alias as well, for internally-equivalent IPs
        hostIpStr = self.class.canonicalAddress(@host)
        httpHostCanonical = self.class.canonicalAddress(env['HTTP_HOST'])
        domainAliasCanonical = (domainAlias ? self.class.canonicalAddress(domainAlias) : nil)
        if( (httpHostCanonical == hostIpStr) or                          # This server is same as host being contacted. Internal call.
            (!domainAlias.nil? and (domainAliasCanonical == hostIpStr))  # Host to contact is an alias of this server. Internal call.
          ) # then really is internal call
          # Clean out stuff from previous request, etc
          self.cleanup()
          # Set up env for internal call
          @internalRequestEnv = env.dup
          @isInternalApiCall = true
        elsif(domainAliases = self.class.getDomainAliases()) # Have domain alias file with entries
          # Check entries in domain alias file
          domainAliases.each_key { |key|
            val = domainAliases[key]
            keyCanonical = self.class.canonicalAddress(key)
            valCanonical = self.class.canonicalAddress(val)
            if((httpHostCanonical == keyCanonical) or (httpHostCanonical == valCanonical))  # then this server is either known machine or its alias
              if((hostIpStr == keyCanonical) or (hostIpStr == valCanonical))                # then host to contact is this server or its alias
                 # then really is internal call
                # Clean out stuff from previous request, etc
                self.cleanup()
                # Set up env for internal call
                @internalRequestEnv = env.dup
                @isInternalApiCall = true
                # No need to search more
                break
              end
            end
          }
        else
          # No, actually to an API call to a different machine.
          @isInternalApiCall = false
        end
      else # Empty env hash...no Rack-env available / outside web-server process, not internal
        @isInternalApiCall = false
      end
      return @isInternalApiCall
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
      @apiUri = "http://#{@host}#{@rsrcPath}"
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

    # Set the authentication information prior to making the request.
    # NOTE: <em>Do NOT put passwords in scripts or as arguments on the command line._ _They can be seen
    # by everybody. Similarly, using passwords within IRB is not wise._ _Use an approach like
    # DBRC which uses a config file that must be owned and viewable only by you to contain
    # passwords [similar to SSH's restrictions on private key files].</em>
    # [+login+]   EITHER: a String which is the Genboree login which you will be useing for authentication.
    #             OR a Hash mapping the canonical addresses of host names to 3-column Arrays records with the login & password & hostType (:internal or :external)
    #             in the three columns (a hostAuthMap).
    #             If the Hash is provided, the appropriate login + password will be used depending on the host being contacted (even if you
    #             change the host via setHost()).
    # [+pass+]    [optional; default=nil] If login is a hostAuthMap Hash, then this should be nil. If login is a String with the login to use then
    #             this is a String with the matching password for the Genboree login.
    #             Note that the
    #             password you provide here will _not_ be stored directly in this
    #             object, only a salted digest will be stored in memory associated
    #             with this object. We recommend you _never_ hard-code passwords
    #             in any of your code and _never_ type them on the command line
    #             when running your programs. (Others can easily see them in these
    #             cases.)
    # [+returns+] _nothing_
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
      retVal = true
      if(
          (@isInternalApiCall and @internalApiCallOK.nil?) or # then internal call result not set yet
          (!@isInternalApiCall)                               # then standard call
        )
        retVal =  ( !@httpResponse.nil? and
                    @error.nil? and
                    @httpResponse.is_a?(::Net::HTTPResponse) and
                    !@httpResponse.is_a?(::Net::HTTPClientError) and
                    !@httpResponse.is_a?(::Net::HTTPServerError)
                  )
      else # internal call and internal api call ok flag is already set
        retVal = @internalApiCallOK
      end
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
    # @todo this method's interface is not respected in the vast majority of BRL code:
    #   we idiomatically check apiCaller.succeeded? and then access its respBody without error checking
    #   but this sometimes returns an error or nil (not the expected string) which is quite scary:
    #   it should probably just raise an error instead (but since I am more fond of doing so than
    #   others seem to be I respectfully leave this note instead :D )
    def respBody(&block)
      retVal = nil
      begin
        if(@isInternalApiCall)
          if(block_given? && @internalRespBody)
            while(chunk = @internalRespBody.read(8192))
              yield block
            end
          else
            if(@internalRespBody.respond_to?(:read))
              retVal = @internalRespBody.read()
            elsif(@internalRespBody.respond_to?(:each))
              retVal = ""
              @internalRespBody.each { |chunk|
                retVal << chunk
              }
            else
              retVal = nil
              raise "Unable to access contents of @internalRespBody because it does not respond to :read or :each: #{@internalRespBody.class}"
            end
          end
          if(@internalRespBody.respond_to?(:rewind))
            @internalRespBody.rewind
          else
            $stderr.debugPuts(__FILE__, __method__, "WARNING", "Cannot rewind @internalRespBody, future access to #respBody may produce unexpected results (e.g. empty respBody)!")
          end
        else # not internal call
          if(@httpResponse)
            if(block_given?)
              @httpResponse.read_body(&block)
            else
              retVal = @httpResponse.read_body()
            end
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
    # @return [Hash, StandardError] A Ruby object. Typically a {Hash} corresponding
    #   the the structured representation or a +String+ for things like
    #   raw tab-delimited text (e.g. <tt>:LFF</tt>. Returns +nil+ or a
    #   Ruby {StandardError} instance if cannot parse the response body
    #   (e.g. maybe there isn't one, request failed, etc); the {StandardError}
    #   object returned in this case may provide insight into what went wrong.
    def parseRespBody(format=:JSON)
      retVal = nil
      begin
        if(@httpResponse)
          if(format == :LFF)
            retVal = (@isInternalApiCall ? @internalRespBody : @httpResponse.body)
          elsif(format == :JSON)
            bodyObj = (@isInternalApiCall ? @internalRespBody : @httpResponse.body)
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "bodyObj is a #{bodyObj.class}")
            # If @httpResponse.body not a String, probably a temp file or read adapter [because payload huge]
            # * In this case we need to:
            #   a. Try to read a pretty big amount in memory, so as to aggressively suck in any huge JSON strings
            #      that triggered the net adapter issue due to sheer size or something [like a missing Content-Length header]
            #   b. But stop at some ceiling in case it's not JSON or is 20GB or something we can't put in RAM and can't parse/use
            # Also, good to try to get the content-type header value if there's a problem

            # Should be able to suck in payload content using read_body whether body is String or some read adapter
            payloadBuff = ''
            if(bodyObj.respond_to?(:read_body)) # probably HTTPResponse object ; read safely
              bodyObj.read_body() { |chunk|
                payloadBuff += chunk
                break if(payloadBuff.size > MAX_JSON_BUFFER)
              }
            elsif(bodyObj.respond_to?(:read)) # probably IO object ; maybe StringIO from internal call or something
              while(chunk = bodyObj.read(MAX_UNCHUNKED_SIZE))
                if(chunk.nil? or chunk.empty?)
                  break
                else
                  payloadBuff += chunk
                  break if(payloadBuff.size > MAX_JSON_BUFFER)
                end
              end
            elsif(bodyObj.respond_to?(:each) and !bodyObj.is_a?(String)) # BAD, not intended; probably Array, which should be lines [with terminal \n] or chunks
              bodyObj.each() { |chunk|
                payloadBuff += chunk
                break if(payloadBuff.size > MAX_JSON_BUFFER)
              }
            else # probably it's String and didn't come through internall call [which won't return String]
              payloadBuff = bodyObj[0, MAX_JSON_BUFFER]
            end
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "payloadBuff size: #{payloadBuff.size}")
            # Try to parse
            retVal = JSON.parse(payloadBuff)
            payloadBuff = nil
          else
            raise ArgumentError.new("ERROR: the format #{format.inspect} is not supported")
          end
          # regardless of format try to rewind @internalRespBody for future calls
          # (many internal requests have StringIO data)
          if(@isInternalApiCall)
            if(@internalRespBody.respond_to?(:rewind))
              @internalRespBody.rewind
            else
              $stderr.debugPuts(__FILE__, __method__, "WARNING", "Cannot rewind @internalRespBody, future access to #respBody may produce unexpected results (e.g. empty respBody)!")
            end
          end
        end
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error rescued from parseRespBody method: #{err.inspect}")
        errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Backtrace: #{errBacktrace}")
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
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Done. Returning a #{retVal.class}")
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
    def makeFullApiUri(varMap=nil)
      retVal = fillApiUriTemplate(varMap, true)
      return addAuthParams(retVal)
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
      skipHttps = @skipHttps
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

      if(@isInternalApiCall) # Then DO NOT do HTTP connection. Call correct rest/resource class's get/put/delete/post/head method directly.
        @fullApiUri = makeFullApiUri(varMap)
        retVal = doInternalRequest(method, payload, &block)
      else
        # Use Net::Http to submit...save response and such...use a timeout as best possible
        httpClass = METHOD2HTTPCLASS[method]
        terr = err = resp = nil
        begin
          # Must fill in the template to make valid URI. Don't add auth info yet, we may be changing the scheme.
          filledApiUri = fillApiUriTemplate(varMap, true)
          filledApiUriObj = URI.parse(filledApiUri)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Filled URI Template: #{filledApiUriObj.inspect}\n    - Based on AUTO-determined @apiUri: #{@apiUri.inspect}")

          # Init an HTTP session (we will have to close it)
          connectionAttempt = sleepTime = 0
          gotConn = false
          maxTimeoutRetry = (block_given? ? 1 : @maxTimeoutRetry) # Attempt the request only once if 'chunked' downloading is requested
          while(connectionAttempt < maxTimeoutRetry and !gotConn)
            sleepTime = (@sleepBase * connectionAttempt**2)
            # Feedback only if we'll be sleeping before a REATTEMPT:
            $stderr.debugPuts(__FILE__, __method__, "SLEEP", "Going to sleep for #{sleepTime.inspect} seconds") if(sleepTime > 0)
            sleep(sleepTime)
            # Feedback only for attempts AFTER the first try:
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Attempting API HTTP/S connection # #{connectionAttempt + 1} of maximum #{maxTimeoutRetry.inspect} attempts") if(connectionAttempt > 0)
            terr = err = resp = nil
            begin
              self.cleanup()

              # Try HTTPS *first*, if supported by remote Genboree.
              # - This is expected to fail immediately if HTTPS is not supported (or if server down etc).
              begin # inner begin-rescue to try HTTPS with HTTP fallback
                if(skipHttps)
                  $stderr.debugPuts(__FILE__, __method__, "WARNING", "NO! Previous attempt heuristics indicates skip HTTPS due to niche problems. Will now raise error to trigger HTTPS fallback...")
                  raise "SKIPPING HTTPS variant"
                else

                  # FIRST: create a "full api url" using https version:

                  # Keep around the filled object based on the orginal state when setting up the 'https' version.
                  httpsFilledUrlObj = filledApiUriObj.dup
                  httpsFilledUrlObj.scheme = 'https'
                  # Get the https URL string BEFORE manually setting port.
                  # - Manually setting port also changes the to_s output!
                  # - Currently the port has been automatically determined by the original *scheme* in @apiUri. Might be 80 or 443.
                  # - So we will need to manually set it to 443 (to make sure correct port is used) but not before we
                  #   get the URL string that doesn't include the port [just like you'd expect] so we can use that for gbToken computation
                  #   . Server will assume plain http and https URLs do NOT have explicit port 80 and 443!!!!
                  httpsFilledUrl = httpsFilledUrlObj.to_s
                  #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "     -> Filled HTTPS template: #{httpsFilledUrl.inspect}")
                  # Now need to addAuthParams to this https url string (note that string won't have :80 or :443 for standard ports, as we want)
                  fullHttpsUrl = addAuthParams(httpsFilledUrl)
                  @fullApiUri = fullHttpsUrl
                  #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "     -> Full HTTPS url (w/auth): #{fullHttpsUrl.inspect}")

                  # SECOND: Setup our actual Net::HTTP and request objects using this full https api url:

                  httpsFullUriObj = URI.parse(fullHttpsUrl)
                  req = httpClass.new(httpsFullUriObj.request_uri)
                  contentType = getContentType
                  req.set_content_type(contentType)

                  @http = ::Net::HTTP.new(httpsFullUriObj.host, httpsFullUriObj.port)
                  @http.use_ssl = true
                  # Ensure we're not going to error out if:
                  # - cert expired
                  # - cert self-signed
                  # - cert for slightly different host
                  # - cert doesn't have all info fields filled in
                  @http.verify_mode = OpenSSL::SSL::VERIFY_NONE  #=> 0
                  # In some cases, hangs for network-timeout when not available (DoS avoidance).
                  # - So we need to give up if can't make initial connection quickly
                  @http.open_timeout = @maxOpenTimeout
                  @http.read_timeout = @httpTimeout
                  @http.ssl_timeout = @httpTimeout
                  #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "###### 1st: trying HTTPS. Final URI and timeout info used: #{httpsFullUriObj.inspect} ;    ######    open_timeout: #{@http.open_timeout.inspect} ; read_timeout: #{@http.read_timeout.inspect} ; ssl_timeout: #{@http.ssl_timeout.inspect}")
                  # To protect against a particular Ruby implementation bug when connecting via HTTPS that succeeds to a
                  #   firewall/termination point BUT for which the upstream server doesn't respond with any content (e.g. BCM firewall
                  #   with SSL certs & valid connection, but without OUR nginx actually responding to https traffic on 443...BCM firewall
                  #   hangs for 10 mins), we have our our own custom Timeout here to notice this situation. The open/read timeouts will
                  #   fail us in this case, so we need this to help us (a) interrupt the connection [else will hang for 10 mins] and (b)
                  #   trigger fallback to HTTP. Luckily the Exception that is raised is already expected & handled by our rescue
                  #   that does the fallback when https fails, yay.
                  timeoutStatus = Timeout::timeout(@maxOpenTimeout, SpecialApiCallerConnTimeout) {
                    @http.start
                    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "     -> HTTPS connection SUCCESS ; Conn 'started'? #{@http.started?.inspect}")
                  }
                end
              rescue StandardError, Timeout::Error => httpsConnErr
                $stderr.debugPuts(__FILE__, __method__, "DEBUG", "HTTPS conn FAILED.")

                # This is ~OK and expected. DOES NOT count as an attempt. Rather, HTTPS doesn't seem to be supported [currently].
                # Continue with usual HTTP approach.
                #$stderr.debugPuts(__FILE__, __method__, "STATUS", "NO HTTPS: HTTPS connection to #{httpsFullUriObj.to_s.inspect} failed, possibly as expected. This is 'expected' when the remote Genboree doesn't actually support HTTPS, but we gave it a shot anyway. If you think this is an error and HTTPS should work, here is some exception info:\n  Error class: #{httpsConnErr.class}\n  Error message: #{httpsConnErr.message}")
                self.cleanup()

                # FIRST: create a "full api url" using oringinal/non-https version:

                # Now need to addAuthParams to the original/non-https url string
                fullHttpUrl = addAuthParams(filledApiUri)
                @fullApiUri = fullHttpUrl
                httpFullUriObj = URI.parse(fullHttpUrl)
                # SECOND: Setup our actual Net::HTTP and request objects using this full original/non-https api url:

                req = httpClass.new(httpFullUriObj.request_uri)
                # Set the content type
                contentType = getContentType()
                req.set_content_type(contentType)
                @http = ::Net::HTTP.new(httpFullUriObj.host, httpFullUriObj.port)
                @http.open_timeout = @maxOpenTimeout
                @http.read_timeout = @httpTimeout
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "###### 2nd: Trying fallback via HTTP. Final URI and timeout info used: #{httpsFullUriObj.inspect} ;    ######    open_timeout: #{@http.open_timeout.inspect} ; read_timeout: #{@http.read_timeout.inspect}")

                @http.start
                $stderr.debugPuts(__FILE__, __method__, "DEBUG", "     -> HTTP connection SUCCESS [fallback]; Conn 'started'? #{@http.started?.inspect}")
              rescue Exception => bigError
                $stderr.debugPuts(__FILE__, __method__, "ERROR", "UNexpected HTTP/S connection exception was: #{bigError.class.inspect} ; msg: #{bigError.message.inspect}")
              ensure # should have usable @http regardless of HTTPS or HTTP setup
                #$stderr.debugPuts(__FILE__, __method__, "STATUS", "Decided on #{(@http and @http.port == 443) ? '*** HTTPS ***' : '*** HTTP ***'}")
                unless(@http.nil?)
                  if(@http.started?)
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
                    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "###### open_timeout: #{@http.open_timeout.inspect} ; read_timeout: #{@http.read_timeout.inspect} ; ssl_timeout: #{@http.ssl_timeout.inspect}")
                    @http.request(req) { |resp|
                      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "###### open_timeout: #{@http.open_timeout.inspect} ; read_timeout: #{@http.read_timeout.inspect} ; ssl_timeout: #{@http.ssl_timeout.inspect}")
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
                  end
                end
              end
            rescue Timeout::Error => terr
              $stderr.puts "WARNING: Timeout::Error thrown while doing socket open/read stuff. #{terr.inspect} (message: #{terr.message})"
            rescue => connErr
              err = connErr
              $stderr.puts "ERROR: making the request threw an error. Won't retry [although maybe we should have].\n  Error Message: #{err.message}\n  Error Backtrace:\n" + err.backtrace.join("\n")
              break # Or should we allow this one to try again???
            end
            connectionAttempt += 1
          end
        rescue => err
          $stderr.puts "ERROR: making the request threw an error.\n  Error Message: #{err.message}\n  Error Backtrace:\n" + err.backtrace.join("\n")
        end
        # Capture response if any and error if any.
        @error = (terr or err)
        retVal = @httpResponse
      end
      # Return whatever HTTPResponse we got, if any
      return retVal
    end

    # Do a internal Api request using pretty much the same environment (http headers, etc)
    # that is being used by the calling Api request handler on the server.
    # [+method+]  The HTTP method for the request, as a downcase +Symbol+
    # [+payload+] The body of the request, as a +String+. Must already be in proper representation
    #             (e.g. already in JSON format or LFF, as is appropriate for the resource and method).
    #             Should ideally be something that is rack.input compatible by the Rack SPEC (but
    #             String will be turned into StringIO automatically); generally this is some kind of
    #             IO-like object that responds to read, each, seek and such.
    # [+returns+] The response body. This is NEVER a String. It will be an object that responds to each()
    #             usually some kind of I/O like thing (could be StringIO) or maybe an Array of Strings if
    #             inefficient code is doing that.
    def doInternalRequest(method, payload=nil, &block)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", " ------------------> INTERNAL CALL **BEING DONE** <------------------- ")
      @internalApiCallOK = nil  # nil means "not set yet; false means failed; true means success
      if(payload.is_a?(String))
        payload = StringIO.new(payload)
      elsif(payload.nil? or payload.empty?)
        payload = StringIO.new()
      end
      # 1. Set up an appropriate environment for the Rack::Request to use, based on the Api call we want to make.
      fullUri = URI.parse(@fullApiUri)
      @internalRequestEnv['HTTP_HOST'] = @internalRequestEnv['SERVER_NAME'] = fullUri.host
      @internalRequestEnv['REQUEST_PATH'] = @internalRequestEnv['PATH_INFO'] = fullUri.path
      @internalRequestEnv['REQUEST_URI'] = "#{fullUri.path}?#{fullUri.query}"
      @internalRequestEnv['REQUEST_METHOD'] = method.to_s.upcase
      @internalRequestEnv['QUERY_STRING'] = fullUri.query
      @internalRequestEnv['rack.input'] = payload
      @internalRequestEnv['genboree.internalReq'] = true
      # 2. Instantiate the "app" class....from the rackup file the Api server uses
      app = GenboreeRESTRackup.new(["brl/rest/resources", "brl/genboree/rest/resources"])
      # 3. Do request via app.call() with the special env we preppped
      # - this returns the standard 3-column array expected by Rack: [respCode, headersHash, respObject]
      # - we want to return the respObject.body, but with a standard IO interface (support each() at least)
      #   although even an Array of Strings as the body will work ok (because Array#each)
      respArray = app.call(@internalRequestEnv)
      # Fake up appropriate HTTPResponse class
      respCode = respArray[0]
      respClass = ::Net::HTTPResponse::CODE_TO_OBJ[respCode.to_s] # specific response class to create
      @httpResponse = respClass.new(1.1, respCode, HTTP_STATUS_NAMES[respCode])    # create fake response instance
      if(block_given?) # For chunked downloading
        respBody = respArray[2].body
        if(respBody.respond_to?(:each))
          respBody.each { |chunk|
            yield chunk
          }
        end
        @internalRespBody = @httpResponse
      else # we'll return the body obj itself
        @internalRespBody = respArray[2].body
        @internalRespBody = StringIO.new(@internalRespBody) if(@internalRespBody.is_a?(String)) # wrap String bodies as StringIO
        @internalApiCallOK = self.succeeded?
      end
      return @internalRespBody
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
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Used these to produce client side token and complete the URI:\n    - apiUri: #{apiUri.inspect}\n    - gbTime: #{gbTime.inspect}\n    - GIVING token: #{gbToken.inspect}\n    - AND FULL URL: #{@fullApiUri.inspect}")
      elsif(@haveGbKey) # have gbKey, so we're all set
        @fullApiUri = apiUri
      end
      return @fullApiUri
    end
  end
end
end
end # module BRL ; module Genboree ; module REST
