
module GbApi

  # @todo Provide PAYLOAD

  # Main Wrapper class for doing deferred/async Genboree API requests.
  #   This is not intended to be used directly by plugin devs, rather indirectly
  #   via a wrapper/support class such as {SimpleAsyncApiRequester}. Making new
  #   such support classes (@todo such as one that supports file uploads), perhaps
  #   that inherit from {SimpleAsyncApiRequester}, is appropriate. Using this class
  #   directly is not.
  class EmAsyncHttpRequester
    DEFAULT_RESP_HEADERS = {
      'Content-Type' => 'text/plain'
    }

    attr_reader :rackEnv, :rackClose, :rackCallback
    # @return [Proc] The response callback registered for this object. Set via {#respCallback}.
    #   By default this is the same as {#rackCallback} which is the direct response callback Rack
    #   provides in the 'async.callback' key of the Rack env hash. The code will be handed a Rack-type
    #   response triple: [ statusFixnum, headersHash, eachableBody ]
    attr_reader :respCallback
    # @return [String] The complete URL String of the GB API call; includes scheme
    #   and all auth tokens, etc. It also can be @nil@ if it will be filled in post-instantiation.
    attr_accessor :fullApiUrl
    # @return [Hash] Extra/replacement request headers to use when making the GB API call.
    attr_accessor :reqHeaders

    # CONSTRUCTOR. Instantiate a requester class for doing async GB API calls.
    #   In addition to instantiation-time parameters, accessors are used to
    #   register response callbacks and to tweak things like headers.
    # @param [Hash] rackEnv The Rack environment of the original incoming request.
    #   Even if more requests are done, the original env of the incoming request
    #   must always be available; it has key info about the request and special items added by Rack.
    # @param [String,nil] fullApiUrl The complete URL String of the GB API call; includes scheme
    #   and all auth tokens, etc. It also can be @nil@ if it will be filled in post-instantiation.
    # @param [Hash] reqHeaders OPTIONAL. Extra/replacement request headers to use when making the GB API
    #   request. Generally not needed except for special cases.
    def initialize(rackEnv, fullApiUrl=nil, reqHeaders={})
      # Save key Rack callbacks, info, etc
      @rackEnv           = rackEnv
      @rackCallback      = rackEnv['async.callback']
      @rackClose         = rackEnv['async.close']
      # Request
      @reqHeaders        = reqHeaders
      @fullApiUrl        = fullApiUrl
      @status            = 500
      # Init other key variables
      @emHttpRequestWrapper = nil

      # Can be overridden via setters after instantiation if needed
      @respCallback      = @rackCallback
    end

    # Specify a block to be executed when the GB API response comes back. Note that
    #   depending on properties of this object that certain response headers may be
    #   spiked in or replaced (see {#respHeaders}) or even the status code changed
    #   (see {#errRespStatus} and {#overrideResponseStatus}).
    # @note Calling this method before the response has completed will cause the
    #   callback block to be stored on an internal list. (Says Eventmachine guys)
    # @note If you call this method after the response is done, the block will
    #   be executed immediately. (Says Eventmachine guys)
    # @param [Proc, nil] OPTIONAL. Generally you provide a code block and do not supply an argument. If
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

      # @todo I'm not sure we want or need this? Especially for arbitrary callback code?
      #   It may be we're registering a callback that gets called if Eventmachine is going to
      #   kill/close the request...say to ensure we clean up resources or something?
      @rackClose.callback(@respCallback)
      self
    end

    # ----------------------------------------------------------------
    # PRIVATE
    # ----------------------------------------------------------------
    private

    # Initialize an object which will do the actual aysync request with help of EM, and which
    #   will allow the deferrable body object to read chunks of response asynchronously for
    #   presentation to the callback.
    def initReqWrapper()
      @respHeaders                   = DEFAULT_RESP_HEADERS.merge(@respHeaders)
      @emHttpRequestWrapper          = GbApi::EMHTTPStreamer.new
      @emHttpRequestWrapper.url      = @fullApiUrl
      @emHttpRequestWrapper.reqHeaders  = @reqHeaders
      @emHttpRequestWrapper.respCallback(@respCallback)

    end

    # Begin the actual request, via the EM request wrapper.
    def start(reqType=:get)
      begin
        # Initialize the streamer and body JIT so as to pick up actual respHeaders and respCallback dev wants.
        initReqWrapper()
        # @todo Probably the various methods should have their own methods? Maybe not if they don't differ much & code
        #   for each is short.
        # @todo Only GET is supported in first version
        if(reqType == :get)
          @emHttpRequestWrapper.doRequest(reqType)
        elsif(reqType == :put or reqType != :get)
          # @todo Implement PUT, DELETE, OPTIONS, HEAD methods too!
          raise NotImplementedError, "ERROR: Need to add code for async GB API 'put' requests. Needs to support payload. A subclass should be added to handle file API uploads (see genboree_kbs/app/helpers/em_helper.rb which is similar to this code but does some file upload and async multipart mime extracting...non-generically, but close)"
        end
      rescue Exception => err
        $stderr.debugPuts(__FILE__, __method__, "****GB_API ERROR****", "Error making genboree api call.\n    Error Class: #{err.class}\n    Error Message: #{err.message.inspect}\n    Error Trace:\n#{err.backtrace.join("\n")}" )
        @status = (@errRespStatus or 500)
        # Something went wrong. Construct an error message that we can send back to the user in the downloaded file.
        message = "FATAL ERROR: #{err.message}\n\nTRACE:\n#{err.backtrace.join("\n")}\n\nPlease contact the Genboree team with the information above."
        # Need a deferrable body that can be properly used to each-over to send back error payload.
        @body = DeferrableErrorBody.new(message)
      end
    end
  end
end