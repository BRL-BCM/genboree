require 'brl/rest/apiCaller'
require 'brl/dataStructure/cache' # for BRL::DataStructure::LimitedCache

module GbApi
  # Use this class to make GB API requests. Register your own callback code via
  #   {#respCallback} to get at the response.
  # @note By default, when you first use get(), put(), etc, EventMachine/Rack/Thin will be AUTOMATICALLY
  #   told that the incoming request is going to be handled async. After all, if part of your handling is
  #   async then ALL of it is async (or broken). It does this by a "throw :async" and means this is the LAST
  #   thing your controller action should have; NO MORE CODE after using get(), put() etc.
  # @note HOWEVER, perhaps your code ends up doing SEVERAL such async API requests by virtue of your
  #   respCallback code having follow-up {SimpleAsyncApiRequester#get} calls and its callback having yet
  #   another, etc. For ones after the first, you DON'T want to "throw :async" obviously, right? Eventmachine
  #   already knows the incoming request is async...so disable via: notifyWebServer = false
  class SimpleAsyncApiRequester
    include GbMixin::AsyncRenderHelper

    # Set up size-limited global cache of request_id => serverNotified, to avoid notifying web server
    #   more than once that the request is being handled async (double throw :async can crash thin worker).
    # - A "Class Instance" variable used like this ApiCaller.cache. Better than class @@variables.
    # - Access is not thread-friendly so some mutex's etc are used
    # - Cache is generic, use keys to access the actual thing you want out of the cache
    class << self
      # Create class instance variables
      attr_accessor :reqStatusCache, :reqStatusCacheLock
      # Limited-sized cache for last 100,000 requests. When space needed, oldest-accessed one is removed.
      SimpleAsyncApiRequester.reqStatusCache  = BRL::DataStructure::LimitedCache.new(100_000)
      SimpleAsyncApiRequester.reqStatusCacheLock   = Mutex.new

      # Request ID notified class methods
      # @return [Symbol,nil] The status of a 'action_dispatch.request_id' request id. If an unknown request
      #   then nil; if started but not yet notified of async (via throw :async) then :notNotified ; if
      #   request has been notified that request will be async then :notified ; if request connection has
      #   been closed (by thin, probably because we did a sendToClient/renderToClient took too long) then :closed
      def reqStatus(reqId)
        retVal = :notNotified
        SimpleAsyncApiRequester.reqStatusCacheLock.synchronize {
          retVal = SimpleAsyncApiRequester.reqStatusCache.getObject(reqId)
        }
        return retVal
      end
      
      def setReqStatus(reqId, status)
        retVal = status
        SimpleAsyncApiRequester.reqStatusCacheLock.synchronize {
          retVal = SimpleAsyncApiRequester.reqStatusCache.cacheObject(reqId, status)
        }
        return retVal
      end
    end

    DEFAULT_SCHEME = :https

    # @return [boolean] GENERALLY DON'T NEED TO SET THIS. Internal tracking and heuristics will
    #   AUTOMATICALLY arrange to notify your web server that the incoming request is going to be
    #   handled async. Basically it means that the first time you do a request using this class,
    #   it will "throw :async" to your web server; all subsequent requests using this class (even
    #   via different instances!) will not re-throw async. It ALSO means that you don't have to
    #   worry about when to notify/not-notify, since it's all automatic. However, if you have some
    #   special case and want to force it off even for the first request or something, you can set
    #   this to false prior to calling get/put/delete/etc.
    attr_accessor :notifyWebServer
    # @return [Hash] Any special request headers to use when making the GB API call. Almost NEVER needed.
    attr_accessor :reqHeaders
    # @return [boolean] Default: false. Whether using this class to access a NON-Genboree server (yahoo.com or something).
    #   Despite being GB API focused this class can also make requests against NON-Genboree web sites. This flag
    #   will turn off some of the Genboree-specific things like getting user's GB auth info for the target host,
    #   and adding gbToken params to the URL.
    attr_accessor :nonGbApiTargetHost
    # @return [Symbol] The scheme/protocol to use. By default will be @:https@.
    attr_accessor :scheme
    # @return [String] The complete URL String of the GB API call; includes schemeand all auth tokens, etc.
    attr_reader :fullApiUrl
    # @return [Proc] The callback called to notify that body streaming is done. This
    #   is an important callback since it's the only way to properly do something AFTER
    #   you've each-ed over the body chunks (which is done via event loop remember, NOT
    #   like regular each() after which you do some other code!). In some sense, this
    #   is ~required. This is just handed off to the body streaming class.
    attr_reader :bodyFinish

    # CONSTRUCTOR.
    # @param [Hash] rackEnv The Rack env hash.
    # @param [String] targetHost The target Genboree host we're making an API call to
    # @param [Project, nil] rmProject The Redmine Project model instance for the Project in whose
    #   context the iss being done; or nil if there is no relevant Project context. Used to do the
    #   right thing for Projects which are flagged as 'public'.
    # @param [User] rmUser The Redmine User model instance for the Redmine User who is making the
    #   API request. Generally the @@currRmUser@ from the Controller is always used, unless some special
    #   shim user is being employed for certain situations.
    def initialize(rackEnv, targetHost, rmProject, rmUser=rackEnv[:currRmUser])
      #$stderr.puts "env key check in #{__method__}:\n\n#{rackEnv.keys.join("\n")}\n\n"
      #$stderr.puts "rmUser is:\n\n#{rmUser.inspect}\n\n"
      # Save key Rack callbacks, info, etc
      initRackEnv( rackEnv )
      @scheme = DEFAULT_SCHEME
      @gbHost = targetHost
      @rmProject = rmProject
      @rmUser = rmUser
      @notifyWebServer = true
      @nonGbApiTargetHost = false
      @fullApiUrl = nil
      @reqHeaders = {}
      @respCallback     = @rackEnv['async.callback']
      @gbAuthHelper = GbApi::GbAuthHelper.new( rackEnv )
      #$stderr.debugPuts(__FILE__, __method__, '>>>>>> DEBUG', "[#{@railsRequestId.inspect}] #{self.class} initialized. Auth helper says GB auth host is #{@gbAuthHelper.gbAuthHost.inspect} ;\n\nREQUEST ID: #{@rackEnv['action_dispatch.request_id'].inspect}\n\n")
    end

    # Register your callback code in order to process the API response. If no respCallback
    #   is registered, the response will go as-is back to the browser (i.e. directly via
    #   @rackEnv['async.callback'])
    # @param [nil,Proc] blk OPTIONAL. Generally you provide a code block and do not supply an argument. If
    #   you supply an argument it's assumed to be a {Proc} object (your callback). If you provide
    #   both, that's an error, but your code block will be used as the callback. If nil is given
    #   (and no code block obviously) then the default Rack callback is used directly.
    #   Your callback will be provided the standard Rack triple response Array:
    #   [ respStatusFixnum, respHeadersHash, eachableBodyObject ].
    def respCallback(blk=nil)
      if(block_given?)
        @respCallback = Proc.new # This will convert block argument to saveable, callable Proc.
      elsif(blk.is_a?(Proc))
        @respCallback = blk
      else
        @respCallback = @rackEnv['async.callback']
      end

      #$tderr.debugPuts(__FILE__, __method__, '>>>>>> DEBUG', "[#{@railsRequestId.inspect}] Registered your callback. Saved correctly? #{!@respCallback.nil?}")
      self
    end

    # The callback called to notify that body streaming is done. This
    #   is an important callback since it's the only way to properly do something AFTER
    #   you've each-ed over the body chunks (which is done via event loop remember, NOT
    #   like regular each() after which you do some other code!).
    # @param [Proc, nil] OPTIONAL. Generally you provide a code block and do not supply an argument. If
    #   you supply an argument it's assumed to be a {Proc} object (your callback). If you provide
    #   both, that's an error, but your code block will be used as the callback. If nil is given
    #   (and no code block obviously) then the default Rack callback is used directly.
    #   Your callback will be provided the standard Rack triple response Array:
    #   [ respStatusFixnum, respHeadersHash, eachableBodyObject ].
    def bodyFinish(blk=nil)
      if(block_given?)
        @bodyFinish = Proc.new # This will convert block argument to saveable, callable Proc.
      elsif(blk.is_a?(Proc))
        @bodyFinish = blk
      else
        @bodyFinish = nil
      end
      self
    end

    # Make a GET request to a GB API path.
    # @param [String] rsrcPath A URI Template resource path string. Will be filled in correctly
    #   from your @fieldMap@.
    # @param [Hash<Symbol,Object>] fieldMap Usual map of Symbols, which are fields in your URI Template
    #   string (@rsrcPath@), to values for that field.
    # @param [String, nil] OPTIONAL. The request payload, if any.
    # @return NONE! Async! "Returns" are done via callbacks!
    def get(rsrcPath, fieldMap, payload=nil)
      doRequest(:get, rsrcPath, fieldMap, payload)
    end

    # Make a PUT request to a GB API path.
    # @param (see #get)
    # @return NONE! Async! "Returns" are done via callbacks!
    def put(rsrcPath, fieldMap, payload=nil)
      doRequest(:put, rsrcPath, fieldMap, payload)
    end

    # Make a DELETE request to a GB API path.
    # @param (see #get)
    # @return NONE! Async! "Returns" are done via callbacks!
    def delete(rsrcPath, fieldMap, payload=nil)
      doRequest(:delete, rsrcPath, fieldMap, payload)
    end

    # Make a HEAD request to a GB API path.
    # @param (see #get)
    # @return NONE! Async! "Returns" are done via callbacks!
    def head(rsrcPath, fieldMap, payload=nil)
      doRequest(:head, rsrcPath, fieldMap, payload)
    end

    # Make a OPTIONS request to a GB API path.
    # @param (see #get)
    # @return NONE! Async! "Returns" are done via callbacks!
    def options(rsrcPath, fieldMap, payload=nil)
      doRequest(:options, rsrcPath, fieldMap, payload)
    end

    # Make a POST request to a GB API path.
    # @param (see #get)
    # @return NONE! Async! "Returns" are done via callbacks!
    def post(rsrcPath, fieldMap, payload=nil)
      doRequest(:post, rsrcPath, fieldMap, payload)
    end

    # ----------------------------------------------------------------
    # PRIVATE
    # ----------------------------------------------------------------
    private

    # Make request to GB API server, ultimately via {EmHttpRequestWrapper} instance.
    # @param [Symbol] httpMethod Which http method we are doing, as a lowercase {Symbol}.
    # @param [String] rsrcPath The resource path plus any query-string parameters; should be a URL template
    #   which will be filled in correctly via @fieldMap@ and proper escaping via {BRL::REST::ApiCaller}
    #   (i.e. you should not be escaping things, you should be writing URI Templates.)
    # @param [String,nil] payload OPTIONAL. The request payload, if any.
    def doRequest(httpMethod, rsrcPath, fieldMap, payload=nil)
      # @todo Only if @railsRequestId not already closed. If it is, we will not do anything at all here.

      # @todo Should register a close-callback here, first. This will set the status of @railsRequestId to :closed.

      #stderr.debugPuts(__FILE__, __method__, '>>>>>> DEBUG', "[#{@railsRequestId.inspect}] Setting up a #{httpMethod.inspect} http request.")
      # Authentication info
      if(@nonGbApiTargetHost) # NON-Genboree target...will work just fine but need to skip some GB-specific stuff
        login = pass = nil
      else # GB API target, as intended
        if(@rmProject.nil?) # Not in project context
          authPair = @gbAuthHelper.authPairForUserAndHost(@gbHost, @rmUser)
        else # project context (check for anonymous access to public project as a fallback etc)
          authPair = @gbAuthHelper.authPairForUserAndHostInProjContext(@rmProject, @gbHost, @rmUser)
        end
        #$stderr.debugPuts(__FILE__, __method__, '>>>>>> DEBUG', "[#{@railsRequestId.inspect}] Have auth info for user: #{authPair[0].inspect} with a password? #{ (authPair[1].nil? ? 'nil' : (authPair[1] == :anon ? :anon : true)) }")
        login, pass = authPair
      end

      # Make the URL. Use base ApiCaller class to help (but NOT to do the request)
      if(@nonGbApiTargetHost)
        apiCaller = BRL::REST::ApiCaller.new(@gbHost, rsrcPath)
        apiCaller.setScheme(@scheme)
        @fullApiUrl = apiCaller.fillApiUriTemplate(fieldMap)
      else # is GB API target as intended
        if(login == :anon) # Try public access to Genboree resource
          apiCaller = BRL::REST::ApiCaller.new(@gbHost, rsrcPath)
          apiCaller.setScheme(@scheme)
          @fullApiUrl = apiCaller.makeFullApiUri(fieldMap, false)
        else # Try user-based access to Genboree resource (or possibly nil/nil failing access because not a public project or login unknown to Genboree)
          apiCaller = BRL::REST::ApiCaller.new(@gbHost, rsrcPath, login, pass)
          apiCaller.setScheme(@scheme)
          @fullApiUrl = apiCaller.makeFullApiUri(fieldMap)
        end
      end
      #$stderr.debugPuts(__FILE__, __method__, '>>>>>> DEBUG', "[#{@railsRequestId.inspect}] Constructed full api url: #{@fullApiUrl.inspect}")

      # Set up request
      initRequest(payload)

      # Start the async request on the next available event loop iteration.
      EM.next_tick {
        start(httpMethod)
      }

      # Notify web server the incoming request is being handle async, if appropriate to do so.
      #   Should be safe NOT to do this if request is already closed for some reason (??)
      notifyAsync()
    end

    def notifyAsync()
      # First, only attempt do this if dev didn't indicate otherwise:
      if(@notifyWebServer)
        # VERY VERY bad to throw more than once (say for 2nd async API call). KILLS WEB SERVER.
        #   So we employ a global cache of request ids => notified to help protect from notifying more than once.
        #   And to automate notify decision completely.
        reqStatus = self.class.reqStatus(@railsRequestId)
        if( reqStatus != :notified ) # @todo shouldn't do this if connection is :closed either, when that is added
          #$stderr.debugPuts(__FILE__, __method__, '>>>>> DEBUG', "[#{@railsRequestId.inspect}]  !!!!!! NOTIFY WEB SERVER via throw :async !!!!!!")
          self.class.setReqStatus(@railsRequestId, :notified)
          #$stderr.debugPuts(__FILE__, __method__, '>>>>> DEBUG', "[#{@railsRequestId.inspect}] (recorded notify)")
          # To add in some more safety: this instance will only notify once by default. So if reused and forget to set notifyWebServer, it's ok.
          @notifyWebServer = false
          throw :async
        end
      end
    end

    # Begin the actual request, via the EM request wrapper.
    # @param (see #doRequest)
    def start(httpMethod, payload=nil)
      begin
        @emHttpRequestWrapper.doRequest(httpMethod)
      rescue Exception => err
        $stderr.debugPuts(__FILE__, __method__, "****GB_API ERROR****", "[#{@railsRequestId.inspect}] Error making genboree api call.\n    Error Class: #{err.class}\n    Error Message: #{err.message.inspect}\n    Error Trace:\n#{err.backtrace.join("\n")}" )
        @status = (@errRespStatus or 500)
        # Something went wrong. Construct an error message that we can send back to the user in the downloaded file.
        message = "FATAL ERROR: #{err.message}\n\nTRACE:\n#{err.backtrace.join("\n")}\n\nPlease contact the Genboree team with the information above."
        # Need a deferrable body that can be properly used to each-over to send back error payload.
        @body = DeferrableErrorBody.new(message)
      end
    end

    # Initialize an object which will do the actual aysync request with help of EM, and which
    #   will allow the deferrable body object to read chunks of response asynchronously for
    #   presentation to the callback.
    #
    def initRequest(payload=nil)
      @emHttpRequestWrapper             = GbApi::EmHttpRequestWrapper.new(@fullApiUrl, payload)
      @emHttpRequestWrapper.reqHeaders  = @reqHeaders
      @emHttpRequestWrapper.respCallback(@respCallback)
      @emHttpRequestWrapper.bodyFinish(@bodyFinish)
      @emHttpRequestWrapper.railsRequestId = @railsRequestId # optional, for tracking
      #$stderr.debugPuts(__FILE__, __method__, '>>>>>> DEBUG', "[#{@railsRequestId.inspect}] Configured an EM HTTP Request wrapper/helper object.")
    end
  end
end
