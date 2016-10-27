require 'brl/genboree/rest/em/deferrableBodies/abstractMultiPhaseBody'

module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies

  # Generic deferrable based on a delegate that has an "each()".
  #   The pattern seen here--wrap a delegate which implements each--is actually very close to what is
  #   used in some of the more targetted sub-classes of AbstractDeferrableBody. It could be used for all/most,
  #   as long as calling code set up the delegate object. If the delegate object is an io-like object, you
  #   run the risk of leaving the handle open if there's a problem (compare this to how DeferrableFileReaderBody
  #   is implemented). Also there may be superior and EM-supported ways that you miss--like reading a remote URL
  #   via EM library methods rather than via a delegate io handle [which is how this is currently used unfortunately].
  class DeferrableDelegateBody < AbstractMultiPhaseBody
    # What states are there to streaming the data?
    #   * MUST have no-arg methods corresponding to exactly these.
    #     - No-arg, and must return a String (the chunk) even if '' is most appropriate when finishing up or something.
    #   * Processing will automatically begin in your FIRST  state in this array.
    #   * SPECIAL: There is ALWAYS :finish state, corresponding to AbstractDeferrableBody#finish.
    #     - You're supposed to implement that (with super() call) to close handles and help free memory!
    #     - You can list it here for completeness/documentation or now
    STATES = [ :getData, :finish ]

    # @return [Array<Symbol>] Array of events fired. Add via addListener(event, listenerProc). Really just here to document:
    #   * :sentChunk => called after a chunk is actively sent or passibly yielded up the chain; can be called MANY times
    #   * :getData   => called when all data has been sent
    #   * :finish => called after class's finish() ; the last event fired
    attr_reader :events

    # @return [Object] The delegate, which supports an each() method.
    attr_accessor :deleg


    # AUGMENT. Include a super(opts) call.
    def initialize(opts)
      super(opts)
      @events += [ :getData ]
      @deleg = opts[:delegate]
      @chunkSize = 8 * 1024
      raise ArgumentError, "ERROR: Not a valid delegate object supporting each() method: #{@deleg.inspect}" unless(@deleg.respond_to?(:each))
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "STATES: #{self.class::STATES.inspect} ; initial state: #{@state.inspect}")
    end

    # AUGMENT. Include a super() call.
    # Immediately (synchronously, this tick) perform finish/clean-up (i/o & memory clean up). Generally immediate, not async.
    # * Close file handles etc!
    # * Help/allow GC by setting key pointer variables (especially to complex objects) to nil (GC is mark-and-sweep)!
    def finish()
      super()
      if(@deleg.respond_to?(:close))
        @deleg.close() rescue nil
      end
      @deleg = nil
      return
    end

    # IMPLEMENT.
    # Get next chunk of actual data to send.
    def getData()
      chunk = nil # need this to tell when each no longer gives data (perhaps in future tick)
      @deleg.each { |part|
        if(chunk)
          chunk << part
        else
          chunk = part
        end
        if(chunk.size >= @chunkSize)
          break
        end
      }

      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "chunk size: #{chunk.size rescue nil} (@state = #{@state.inspect})")

      # If we're still in the send-data phase (no limit reached etc), then did the last cursor.next()
      # end with an actual mongo doc (so there still be more) or with nil (no more docs in cursor)?
      if(chunk and @state == :getData)
        # Send out current chunk.
        # Keep spooling more docs next tick
        @state = :getData
      else # chunk is nil or we're done for another reason
        chunk = ''
        # Send out current chunk.
        # Enter post spooling phase.
        @state = :finish
        notify(:getData)
      end
      return chunk
    end
  end
end ; end ; end ; end ; end
