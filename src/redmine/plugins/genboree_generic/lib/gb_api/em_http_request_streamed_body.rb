
# @todo In Progress. Needs cleanup, renaming, sensible-ization

module GbApi

  # A simple body-streaming / each-able class, for use with {EmHttpRequestWrapper}.
  #   When something calls #each, it will save the each-ing code block and arrange
  #   for the {EM::HttpRequest} object to stream body chunks to it.
  class EmHttpRequestStreamedBody
    include EventMachine::Deferrable

    # @return [EventMachine::HttpRequest] The responding http request.
    attr_accessor :http
    # @return [String,nil] Infrastructure code should set this to the Rails 'action_dispatch.request_id' uniq request
    #   id value to facilitate request tracking in the logs. If not set it will be nil.
    attr_accessor :railsRequestId
    # @return [Proc] The callback called to notify that body streaming is done. This
    #   is an important callback since it's the only way to properly do something AFTER
    #   you've each-ed over the body chunks (which is done via event loop remember, NOT
    #   like regular each() after which you do some other code!). In some sense, this
    #   is ~required.
    attr_reader :finish
    # @return [boolean] (Default: false) Is this EM::Deferrable going to be handed to Rack as an async response body? i.e.
    #   because the payload can be large (or slow) and we don't want to block the WRITING of payload data to the
    #   client? By default, this object is a request payload you're planning on reading from in your code (async) and
    #   will not be the body handed to Rack. But if you want to hand it to Rack as a pass-through (e.g. maybe it's a
    #   raw file download from Genboree or external site) and not block as large/slow data is written to the client
    #   set this to true. This tells the object that we want to properly hook it up to Rack for streamed WRITE [to client]
    #   as well.
    #   * This will cause it to call appropriate EM::Deferrable#set_deferred_status once everything has been
    #     sent to the client, so Rack can properly shutdown the request connection.
    #   * When an EM::Deferrable like GbApi::EmHttpRequestStreamedBody is used as the body WRITTEN to the
    #     client, this connection shutdown is deferred into the future rather than happening when control
    #     returns to where Rack called body.each() the first time. When the writing is async as well, control
    #     returns to where Rack called body.each() MULTIPLE times and it only properly finishes the request
    #     when the body's set_deferred_status flag is set. Else it keeps the write connection open for future EM
    #     loops to continue writing payload day just like we want. So we need something that makes sure Rack
    #     knows when the write [to client] connection should be closed right?
    attr_accessor :useAsRespPayload

    # CONSTRUCTOR.
    # @param [EM::HttpRequest] http The eventmachine http request object.
    def initialize(http)
      @http = http
      @finish = @railsRequestId = nil
      @sawHttpFinished = false
      @useAsRespPayload = false
    end

    # The callback called to notify that body streaming is done. This
    #   is an important callback since it's the only way to properly do something AFTER
    #   you've each-ed over the body chunks (which is done via event loop remember, NOT
    #   like regular each() after which you do some other code!).
    # @param [Proc, nil] OPTIONAL. Generally you provide a code block and do not supply an argument. If
    #   you supply an argument it's assumed to be a {Proc} object (your callback). If you provide
    #   both, that's an error, but your code block will be used as the callback. If nil is given
    #   (and no code block obviously) then the default Rack callback is used directly. There are
    #   no args to your callback; the response has gone out and been shutdown by this time; can use
    #   this for resource cleanup or logging.
    def finish(blk=nil)
      if(block_given?)
        @finish = Proc.new # This will convert block argument to saveable, callable Proc.
      elsif(blk.is_a?(Proc))
        @finish = blk
      else
        @finish = nil
      end
      self
    end

    # Begin iterating over the chunks of the body. When dev callback code begins iterating
    #   over the body chunks, their code block is handed to http.stream which will take
    #   care of calling it as it reads chunks over the wire.
    # @param [Proc] blk The code block or {Proc} object to be called for each body chunk.
    def each(&blk)
      # Save the code-block/Proc trying to each over.
      @chunkCallback = blk
      # Initiate async streaming of chunks to that Proc via EM::HttpRequest#stream
      @http.stream { |chunk|
        begin
          #$stderr.debugPuts(__FILE__, __method__, '>>>>>> DEBUG', "[#{@railsRequestId.inspect}] HANDING OFF CHUNK of #{chunk.size} BYTES\n@http:\n#{@http.inspect}") if(@http.req.uri.host =~ /reg\.genome/)
          @chunkCallback.call(chunk)
        rescue Exception => err
          $stderr.debugPuts(__FILE__, __method__, 'EXCEPTION - NEXT_TICK', "[#{@railsRequestId.inspect}] Exception raised and caught (to protect web server) when each-ing over response body. CASE 1: Most likely the chunk callback handed to each() threw an error. Details:\n    - Error Class: #{err.class}\n    - Error Message: #{err.message.inspect}\n    - Error Trace:\n#{err.backtrace.join("\n")}")
          self.fail if( @useAsRespPayload )
        end
      }
      # Registering 'callback' is vital for the em internal variables to be updated properly. It seems that in cases where we only use stream with no callback block, the internal callback is not called before the next_tick which was defined above (inside @http.stream) 100% of the time. In such cases, the code inside next_tick does not work as http.finished? has not yet been updated properly. Explicitely registering a callback fixes this problem as the internal method hooked to this callback seems to update the http.finished? before block code is executed. This leads to the fact that we probably don't require the next_tick loop above. 
      @http.callback { |hh|
        #$stderr.debugPuts(__FILE__, __method__, '>>>>>> DEBUG', "[#{@railsRequestId.inspect}] hh.inspct: #{hh.inspect}")
        begin
          if(!@sawHttpFinished and hh.finished?)
            @sawHttpFinished = true
            if(@finish.is_a?(Proc)) # Have we got a finish callback for notification/flow purposes?
              @finish.call()
            end
            #$stderr.debugPuts(__FILE__, __method__, '>>>>>> DEBUG', "[#{@railsRequestId.inspect}] Calling succeed.\n*************************")  
            self.succeed if( @useAsRespPayload )
          end
        rescue => err
          $stderr.debugPuts(__FILE__, __method__, 'EXCEPTION - NEXT_TICK', "[#{@railsRequestId.inspect}] Exception raised and caught (to protect web server) when each-ing over response body. CASE 2: Most likely dev's bodyFinish callback threw an error. Details:\n    - Error Class: #{err.class}\n    - Error Message: #{err.message.inspect}\n    - Error Trace:\n#{err.backtrace.join("\n")}")
            self.fail if( @useAsRespPayload )
        end
      }
      
    end

    # ----------------------------------------------------------------
    # PRIVATE
    # ----------------------------------------------------------------
    private
  end
end
