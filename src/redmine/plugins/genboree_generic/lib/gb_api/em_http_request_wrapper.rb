
# @todo In Progress. Needs cleanup, renaming, sensible-ization

module GbApi

  # This class wraps the EM::HttpRequest calling that does the actual async call for us.
  class EmHttpRequestWrapper
    DEFAULT_TIMEOUTS = {
      :connect_timeout => 10,
      :inactivity_timeout => 60
    }
    DEFAULT_REQ_OPTIONS = {
      :redirects  => 5,
      :keepalive  => false,
      :body       => nil,
      :head       => { "Connection" => "close" }
    }

    # @return [String] The full request url.
    attr_accessor :url
    # @return [String] The request payload to send when making the request. Default is nil (don't send a payload)
    attr_accessor :payload

    # @return [Hash] Additional request headers used when making the raw http request.
    attr_accessor :reqHeaders
    # @return [Hash] Timeout settings. Available in case need to tweak them.
    attr_accessor :timeouts
    # @return [boolean] Whether to use keepalive or not when making the request. Default is false.
    attr_accessor :keepalive
    # @return [Fixnum] How many levels of redirection (e.g. 3xx responses) to follow before quiting. Default is 5.
    attr_accessor :redirects
    # @return [String,nil] Infrastructure code should set this to the Rails 'action_dispatch.request_id' uniq request
    #   id value to facilitate request tracking in the logs. If not set it will be nil.
    attr_accessor :railsRequestId
    # @return [Proc] The callback to register with the raw http request object. Set via {#respCallback}.
    attr_reader :respCallback
    # @return [Hash] The raw response headers.
    attr_reader :respHeaders
    # @return [Proc] The callback called to notify that body streaming is done. This
    #   is an important callback since it's the only way to properly do something AFTER
    #   you've each-ed over the body chunks (which is done via event loop remember, NOT
    #   like regular each() after which you do some other code!). In some sense, this
    #   is ~required. This is just handed off to the body streaming class.
    attr_reader :bodyFinish

    # CONSTRUCTOR.
    # @param [String] url The full request url.
    # @param [String,nil] payload The request payload, if any. 
    def initialize(url, payload=nil)
      @url = url
      @payload = payload
      @reqHeaders = {}
      @timeouts = DEFAULT_TIMEOUTS.deep_clone
      @reqOptions = DEFAULT_REQ_OPTIONS.deep_clone
      @keepalive = @redirects = nil
      @respCallback = @bodyFinish = @railsRequestId = nil
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

    # Make actual http request via {EM::HttpRequest}.
    # @param [Symbol] httpMethod The http request as a lower case {Symbol}. Will be used with
    #   {EM::HttpRequest#send} to automatically call the correct underlying method.
    def doRequest(httpMethod = :get)
      # Create raw http request object
      # - compose http options
      httpOptions = @timeouts
      # - compose req options
      @reqOptions[:redirects] = @redirects if(@redirects)
      @reqOptions[:keepalive] = @keepalive if(@keepalive)
      # - request headers
      @reqOptions[:head] = @reqOptions[:head].merge(@reqHeaders)
      # - request payload
      @reqOptions[:body] = @payload if(@payload)
      $stderr.debugPuts(__FILE__, __method__, '>>>>>> DEBUG', "[#{@railsRequestId.inspect}] EM Http wrapper doing #{httpMethod.inspect} calkk using these httpOptions:    #{httpOptions.inspect}    and these request options:    #{@reqOptions.inspect[0,256]}#{'...' if(@reqOptions.inspect.size > 256)}\n\n")

      # MAKE REQUEST
      # * NOTE: *Cannot* use both EM:HttpRequest#callback AND EM::HttpRequest#headers + EM::HttpRequest#stream approach.
      #     The callback method precludes use of headers() and/or stream(). For best results, always use
      #     headers() + stream() for full control and proper body streaming via event loop.
      # * NOTE: You can, and always should, register an EM::HttpRequest#errback code block. It is usable with either
      #     streaming or non-streaming approaches. It is NOT related to HTTP error responses, but more fundamental
      #     connection errors like bad domain, unreachable / unresponsive host & port, etc.
      emHttp = EventMachine::HttpRequest.new(@url, httpOptions).send(httpMethod, @reqOptions)
      # Create an each-able body object that knows how to use EM Http Request to stream chunks using event loop.
      # * Dev's callback will receive this object i nthe Rack-type triple and when they each over the body,
      #   EM will read a chunk in a loop iteration, give them the chunk, and schedule the next chunk reading for a future loop iteration.
      respBody = EmHttpRequestStreamedBody.new(emHttp)
      # Register callback so can be notified that non-blocking streaming of body to dev's each() is done (so they can do follow-up code)
      respBody.finish(@bodyFinish)
      respBody.railsRequestId = @railsRequestId # see if can help track request logging
      # Register a headers callback, which EM will call when it parses the raw HTTP response header
      #   but before any body data is read/processed. We use this to:
      # * Save the response headers hash.
      # * Call the dev's callback function with the Rack-type triple.
      emHttp.headers { |headersHash|
        begin
          # Save the headers for the Rack-type response triple
          @respHeaders = headersHash
          #$stderr.debugPuts(__FILE__, __method__, '>>>>>> DEBUG', "[#{@railsRequestId.inspect}] INTERNAL HEADERS CALLBACK. Handed these http response headers:\n\n#{@respHeaders.inspect}\n\nINTERNAL HEADERS CALLBACK. Http status appears to be #{emHttp.response_header.status.inspect}...NOW CALL dev's CALLBACK CODE WITH THE TRIPLE...")
          @respCallback.call( [ emHttp.response_header.status, @respHeaders, respBody ] )
        rescue Exception => err
          $stderr.debugPuts(__FILE__, __method__, 'EXCEPTION - NEXT_TICK', "[#{@railsRequestId.inspect}] Exception raised and caught (to protect web server) in headers callback. Most likely dev's @respCallback threw an error. Details:\n    - Error Class: #{err.class}\n    - Error Message: #{err.message.inspect}\n    - Error Trace:\n#{err.backtrace.join("\n")}")
        end
      }

      # Register an error callback, only called when socket connection fails completely or there is DNS error, etc.
      #   NOT called when there is an HTTP "error" response (that's a regular callback)
      emHttp.errback {
        begin
          $stderr.debugPuts(__FILE__, __method__, "GB API REQUEST FAILED", "[#{@railsRequestId.inspect}] EM::HttpRequest error message: #{emHttp.error.inspect rescue nil} ;  URL: #{@url.inspect}\n    - HTTP METHOD: #{httpMethod.inspect}\n    HTTP RESPONSE:\n\n#{@emHttp.response.inspect}\n\n" )
          @respCallback.call( [ 500, { 'x-gb-api-fatal' => 'Bad Genboree domain or could not connect to Genboree API server.'}, ''] )
        rescue Exception => err
          $stderr.debugPuts(__FILE__, __method__, 'EXCEPTION - NEXT_TICK', "[#{@railsRequestId.inspect}] Exception raised and caught (to protect web server) when each-ing over response body. CASE 1: Most likely the chunk callback handed to each() threw an error. Details:\n    - Error Class: #{err.class}\n    - Error Message: #{err.message.inspect}\n    - Error Trace:\n#{err.backtrace.join("\n")}")
        end
      }
    end
  end
end