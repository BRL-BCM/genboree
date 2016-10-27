module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies ; class AbstractDeferrableBody ; end ; end ; end ; end ; end ; end

require 'eventmachine'
require 'brl/util/util'
require 'brl/genboree/rest/em/events/eventNotifier'

module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies
  class AbstractDeferrableBody
    include EventMachine::Deferrable
    include BRL::Genboree::REST::EM::Events::EventNotifier

    # @return [Fixnum] Default chunk size
    DEF_CHUNK_SIZE = 128 * 1024

    # @return [Proc] Used to store and access the Proc/block that Thin/Rack/EM infrastructure
    #   hands the each() method
    attr_accessor :sendCallback
    # @return [Fixnum] The chunk size to read and send off. Sub-classes decide how/if to make use of this.
    attr_accessor :chunkSize
    # @return [Fixnum] The number of bytes sent out. Computed here for you automatically, from chunks obtained from sub-class
    #   methods.
    attr_accessor :totalBytesSent
    # @return [Array<Symbol>] Array of events fired. Add via addListener(event, listenerProc). Really just here to document:
    #   * :sentChunk => call after a chunk is actively sent or passibly yielded up the chain; can be called MANY times
    #   * :finish => called after class's finish() ; the last event fired
    attr_reader :events

    # AUGMENT. Include a super(opts) call.
    def initialize(opts)
      @events = [ :finish, :sentChunk ]
      @doYield = ( opts[:yield] or false )
      @chunkSize = (opts[:chunkSize] or self.class::DEF_CHUNK_SIZE)
      @totalBytesSent = 0
      @listeners = Hash.new { |hh, kk| hh[kk] = [] }
    end

    # AUGMENT. Include a super() call.
    # Immediately (synchronously, this tick) perform finish/clean-up (i/o & memory clean up). Generally immediate, not async.
    # * Close file handles etc!
    # * Help/allow GC by setting key pointer variables (especially to complex objects) to nil (GC is mark-and-sweep)!
    def finish()
      return
    end

    # IMPLEMENT.
    # Get next chunk of actual data to send.
    def getData()
      raise NotImplementedError, "ERROR: Sub-classes must implement #{__method__}."
    end

    # OVERRIDE. But only if needed.
    # Overrride this if you have more states than just a simple one-state getData() can handle.
    def nextChunk()
      return getData()
    end

    # ------------------------------------------------------------------
    # INFRASTRUCTURE. Shouldn't need to override these:
    # ------------------------------------------------------------------
    def each() # will have a block ... use Proc.new trick to save AND/OR yield
      @sendCallback = Proc.new
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "<#{self.object_id}> Enter each() with block #{sendCallback.inspect}. Will #{@doYield ? 'NOT' : ''} be managing async ourselves via EM interaction.")

      if(@doYield) # arrange to do fiber / yield-chain way ; caller manages iteration and [hopefully] asynchronicity
        doYield { |chunk| yield chunk } # Respects the old yield-chain
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "(Yield-chain mode) Transition to 'finish' state.")
        scheduleFinish()
      else # use newer EM way ; no yield-chain, just call chunk-sending callback when should
        # We arrange iteration & manage asynchronicity
        scheduleAsync()
      end
    end

    # Final infrastructure clean up. Certain things cannot be cleared up in finish as they
    #   may still be needed by listeners of the :finish event.
    def clear()
      @sendCallback = @totalBytesSent = 0
      clearListeners()
    end

    private

    def doYield
      # Direct yield to thin/rack followed by finish-phase. Can't do a @sendCallback.call because Fiber will complain
      #  with a FiberError about " can't yield from root fiber"
      while(chunk = nextChunk())
        @totalBytesSent += chunk.size
        if(chunk)
	  yield chunk # respect yield-chain
          notify(:sentChunk)
        else # nil chunk? whaaaat...see the while() condition, can't get here
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "(Yield-chain mode) !!!!!!! WTH? !!!!!!!! Got here with a nil chunk? How, given the while() condition?")
        end
      end
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "(Yield-chain mode) Done yielding chunks. @totalBytesSent = #{@totalBytesSent.inspect}. Deferrable class #{self.class.inspect} involvement is over.")
    end

    # Send out the chunks asynchronously
    def scheduleAsync()
      if(@sendCallback)
        chunk = nextChunk()
        if(chunk)
          @totalBytesSent += chunk.size
          # Send the chunk using the @sendCallback function we saved when our each() was called
          @sendCallback.call(chunk)
          notify(:sentChunk)
          # Schedule next chunk
          ::EM.next_tick {
            scheduleAsync()
          }
        else # EOD
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "All done. Sent #{@totalBytesSent.commify} bytes of #{@path.inspect}. Now finish up.")
          scheduleFinish()
        end
      end
      return
    rescue => err
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Protected vs exception within EM loop. Exception details:\n  - Class: #{err.class}\n  - Message: #{err.message}\n  - Backtrace:\n#{err.backtrace.join("\n")}")
    end

    def scheduleFinish()
      finish()
      notify(:finish)
      # Arrange to call final infrastructure clear(); can only be done AFTER all :finish listeners are done
      addListener(:clear, Proc.new { |event, notifier| notifier.clear() })
      notify(:clear) # internal only
    rescue Exception => err
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Protected vs exception within EM loop. Exception details:\n  - Class: #{err.class}\n  - Message: #{err.message}\n  - Backtrace:\n#{err.backtrace.join("\n")}")
    end
  end # class AbstractDeferrableBody
end ; end ; end ; end ; end # module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies
