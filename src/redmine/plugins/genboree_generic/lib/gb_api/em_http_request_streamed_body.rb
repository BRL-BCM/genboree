
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

    # CONSTRUCTOR.
    # @param [EM::HttpRequest] http The eventmachine http request object.
    def initialize(http)
      @http = http
      @finish = @railsRequestId = nil
      @sawHttpFinished = false
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
      #$stderr.debugPuts(__FILE__, __method__, '>>>>>> DEBUG', "[#{@railsRequestId.inspect}] Body each() called. We have the code that will receive the chunks: [ #{@chunkCallback.inspect} ]")
      # Initiate async streaming of chunks to that Proc via EM::HttpRequest#stream
      @http.stream { |chunk|
        begin
          #$stderr.debugPuts(__FILE__, __method__, '>>>>>> DEBUG', "[#{@railsRequestId.inspect}] HANDING OFF CHUNK of #{chunk.size} BYTES")
          @chunkCallback.call(chunk)
          # This may be last chunk (state goes from :body => :finished, but only after the current stream
          # code block is done). Because it will only do that after this stream code block, we'll arrange
          # to check if we're all done in the next available event loop iteration:
          EM.next_tick {
            begin
              # Notify that we're all done streaming body...to make follow-up code happen etc.
              # Of course we must only call it once, keeping in mind it's being put on the event stack
              #   ones for each body chunk and may be run much later...at which point @http is finished for ALL of them!
              if(!@sawHttpFinished and @http.finished?)
                @sawHttpFinished = true
                if(@finish.is_a?(Proc)) # Have we got a finish callback for notification/flow purposes?
                  @finish.call()
                end
              end
            rescue Exception => err
              $stderr.debugPuts(__FILE__, __method__, 'EXCEPTION - NEXT_TICK', "[#{@railsRequestId.inspect}] Exception raised and caught (to protect web server) when each-ing over response body. CASE 2: Most likely dev's bodyFinish callback threw an error. Details:\n    - Error Class: #{err.class}\n    - Error Message: #{err.message.inspect}\n    - Error Trace:\n#{err.backtrace.join("\n")}")
            end
          }
        rescue Exception => err
          $stderr.debugPuts(__FILE__, __method__, 'EXCEPTION - NEXT_TICK', "[#{@railsRequestId.inspect}] Exception raised and caught (to protect web server) when each-ing over response body. CASE 1: Most likely the chunk callback handed to each() threw an error. Details:\n    - Error Class: #{err.class}\n    - Error Message: #{err.message.inspect}\n    - Error Trace:\n#{err.backtrace.join("\n")}")
        end
      }
    end

    # ----------------------------------------------------------------
    # PRIVATE
    # ----------------------------------------------------------------
    private

  end
end