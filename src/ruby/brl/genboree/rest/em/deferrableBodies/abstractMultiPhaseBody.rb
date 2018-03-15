module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies ; class AbstractMultiPhaseBody < AbstractDeferrableBody ; end ; end ; end ; end ; end ; end

require 'eventmachine'
require 'brl/genboree/rest/em/deferrableBodies/abstractDeferrableBody'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/producers/nestedTabbedModelProducer'
require 'brl/genboree/kb/producers/nestedTabbedDocProducer'
require 'brl/genboree/kb/producers/fullPathTabbedModelProducer'
require 'brl/genboree/kb/producers/fullPathTabbedDocProducer'
require 'brl/genboree/kb/helpers/viewsHelper'
require 'brl/genboree/rest/resources/kbViews'

module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies
  class AbstractMultiPhaseBody < AbstractDeferrableBody
    # What states are there to streaming the data?
    #   * MUST have no-arg methods corresponding to exactly these.
    #     - No-arg, and must return a String (the chunk) even if '' is most appropriate when finishing up or something.
    #   * Processing will automatically begin in your FIRST state in this array.
    #   * SPECIAL: There is ALWAYS :finish state, corresponding to AbstractDeferrableBody#finish.
    #     - You're supposed to implement that (with super() call) to close handles and help free memory!
    #     - You can list it here for completeness/documentation or now
    STATES = [ :preData, :getData, :postData, :finish ] # Example/typical-template

    # @return [Array<Symbol>] Array of events fired. Add via addListener(event, listenerProc). Really just here to document:
    #   * :sentChunk => call after a chunk is actively sent or passibly yielded up the chain; can be called MANY times
    #   * :finish => called after class's finish() ; the last event fired
    attr_reader :events

    # AUGMENT. Include a super(opts) call.
    def initialize(opts)
      super(opts)
      # Do we have methods for all the STATES, and do they look correct?
      self.class::STATES.each { |state|
        if(state.is_a?(Symbol))
          if(self.respond_to?(state))
            stateArity = self.method(state).arity
            unless(stateArity == 0)
              raise NotImplementedError, "ERROR: The implementation of the #{state.inspect} state method has arity of #{stateArity.inspect} but must be a no-arg method (arity==0)."
            end
          else
            raise NotImplementedError, "ERROR: #{self.class}::STATES lists the #{state.inspect} state but there is NO corresponding #{self.class}##{state} method implemented!"
          end
        else
          raise NotImplementedError, "ERROR: #{self.class}::STATES must be Symbols. But contains #{state.inspect} which is not a Symbol."
        end
      }
      # Start off in the first state.
      @prevState = @state = self.class::STATES.first
    end

    # AUGMENT. Implement but include a super() call.
    # Close ALL file handles and other resources, and assign nil to major pointer to aid garbage collections.
    #   * Best to call super() when implementing this.
    def finish()
      super()
      @prevState = @state = nil
      return
    end

    # EXAMPLE.
    # STATE: :preData - Phase 1, Pre data spooling set-up.
    #   * Use this to do any set-up or send out any header-row/open-wrapper type text etc.
    #   * Don't set up IO handles in initialize() since calling code may set some post-instantiation
    #     config via the accessors. Do it here.
    #   * MUST ensure proper state-transition happens by setting @state to next state when ready.
    #     Generally this is called once and then does a @state=:data to go to data sending phase.
    #   * Don't just "raise" errors without calling scheduleFinish() first to clean up after yourself.
    # @return [String] Chunk of data. Typically some column header or wrapper-open text.
    def preData()
      raise NotImplementedError, "ERROR: Sub-classes must implement #{__method__}."
    end # def preData()

    # EXAMPLE.
    # STATE: :getData - Phase 2, spool out the doc data
    #   * MUST ensure proper state-transitions happen by setting @state to next state when ready.
    #     Generally when run out of actual data lines to send (so many times @state will be set to :data
    #     while there is still data to send, so we stay in this state). Then after all data gone out,
    #     you would effet a state transition via @state=:postData
    #   * Don't just "raise" errors without calling scheduleFinish() first to clean up after yourself.
    # @return [String] Chunk of bytes to send out. Not too big for memory, not too long to generate (short ticks!), etc.
    def getData()
      raise NotImplementedError, "ERROR: Sub-classes must implement #{__method__}."
    end # def getData()

    # EXAMPLE.
    # STATE: :postData - Phase 3, post data spooling.
    #   * MUST ensure proper state-transitions happen by setting @state to next state when ready.
    #     Generally this will be :finish to schedule clean up.
    #   * Don't just "raise" errors without calling scheduleFinish() first to clean up after yourself.
    # @return [String] Chunk of bytes to send out. Typically some footer text, close-wrapper, or even empty string if not applicable.
    def postData()
      raise NotImplementedError, "ERROR: Sub-classes must implement #{__method__}."
    end

    # OVERRIDE. (Only if needed)
    # State-dispatcher. Override if you have more methods than pre, data, post, and final clean-up/finish.
    # Overrride this if you have more states than just a simple getData() can handle.
    def nextChunk()
      chunk = nil
      # State transition:
      #if(@state == :finish) # special
      #  chunk = nil
      #  scheduleFinish()
      #elsif(@state.is_a?(Symbol))
      if(@state.is_a?(Symbol))
        begin
          if(@prevState != @state)
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Transitioning from #{@prevState.inspect} to #{@state.inspect}." )
            @prevState = @state
          end

          # If we are engaging the throttle, arrange for nextChunk() to return special Symbol :throttleEngaged,
          #   else call the sub-class's method (whose name matches the @state Symbol) as normal.
          # * We cannot return nil or false, since that will tell doYield() that the sub-class has no more
          #   data to send. So instead it will look for this special Symbol and avoid the yield call entirely this
          #   round.
          # * We could return an empty chunk for an empty yield, but we've seen that cause problems on some machines/implementations when
          #   yielded. And why not avoid such things and the yield altogether?
          if( throttle )
            chunk = :throttleEngaged
          else
            chunk = self.send(@state)
          end
        rescue Exception => err
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Protected vs exception within EM loop. Exception details:\n  - Class: #{err.class}\n  - Message: #{err.message}\n  - Backtrace:\n#{err.backtrace.join("\n")}")
          scheduleFinish()
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "FATAL! Bad state #{@state.inspect}")
        raise "ERROR: Bad state #{@state.inspect}!"
      end
      return chunk
    end
  end
end ; end ; end ; end ; end
