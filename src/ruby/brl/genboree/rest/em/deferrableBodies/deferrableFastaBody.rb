require 'brl/genboree/seqRetriever'
require 'brl/genboree/rest/em/deferrableBodies/abstractMultiPhaseBody'

module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies
  class DeferrableFastaBody < AbstractMultiPhaseBody

    attr_accessor :groupName, :dbName, :chromNames, :from, :to, :chromName
    attr_accessor :doAllUpper, :doAllLower, :doRevCompl

    # @return [Array<Symbol>] Array of events fired. Add via addListener(event, listenerProc). Really just here to document:
    #   * :sentChunk => called after a chunk is actively sent or passibly yielded up the chain; can be called MANY times
    #   * :preData => called after the preData setup phase is done
    #   * :getData => called after the data sending phase is done
    #   * :postData => called after the postData phase is done
    #   * :finish => called after class's finish() ; the last event fired
    attr_reader :events

    # AUGMENT. Include a super(opts) call.
    def initialize(opts={})
      super(opts) # Initialize inherited infrastructure
      @events += [ :preData, :postData, :getData ]

      # Our stuff:
      @groupName = opts[:groupName]
      @dbName = opts[:dbName]
      @chromNames = opts[:chromNames]
      # these will define the actual retrieval
      unless(@chromNames.is_a?(Array) or @chromNames.nil?)
        @chromNames = [ @chromNames ]
      end
      @from = (opts[:from].nil? ? nil : opts[:from].to_i)
      @to = (opts[:to].nil? ? nil : opts[:to].to_i)
      @doAllUpper = opts[:doAllUpper]
      @doAllLower = opts[:doAllLower]
      @doRevCompl = opts[:doRevCompl]

      # We arrange for an appropriate Enumerable::Enumerator that will be used to
      # give us data chunks via a pre-existing yield-chain oriented implementation
      @dataEnumerator = nil

    end

    # AUGMENT. (Implement but use a super())
    # Close ALL file handles and other resources, and assign nil to major pointer to aid garbage collections.
    #   * Best to call super() when implementing this.
    def finish()
      super()
      @dataEnumerator = @chromNames = nil
      return
    end

    # IMPLEMENT.
    # STATE: :preData - Phase 1, Pre data spooling set-up.
    #   * Use this to do any set-up or send out any header-row/open-wrapper type text etc.
    #   * Don't set up IO handles in initialize() since calling code may set some post-instantiation
    #     config via the accessors. Do it here.
    #   * MUST ensure proper state-transition happens by setting @state to next state when ready.
    #     Generally this is called once and then does a @state=:getData to go to data sending phase.
    #   * Don't just "raise" errors without calling scheduleFinish() first to clean up after yourself.
    # @return [String] Chunk of data. Typically some column header or wrapper-open text.
    def preData()
      chunk = ''
      # setup the seqRetriever with these required fields
      @seqRetriever = BRL::Genboree::SeqRetriever.new()
      @seqRetriever.chunkSize = @chunkSize
      @seqRetriever.setupUserDb(@groupName, @dbName)
      # set these options in the seqRetriever now -- enforce boolean here or thin may crash
      @seqRetriever.doAllUpper = !!@doAllUpper
      @seqRetriever.doAllLower = !!@doAllLower
      @seqRetriever.doRevCompl = !!@doRevCompl
      if(@chromNames.is_a?(Array) and @chromNames.size == 1) # then can pay attention to @from and @to
        # Set from/to as requested
        @seqRetriever.from = @from
        @seqRetriever.to = @to
      end
        # ALL execution flows should set next @state:
      @state = :getData
      notify(:preData)

      return chunk
    end # def preData()

    # IMPLEMENT.
    # STATE: :getData - Phase 2, spool out the doc data
    #   * MUST ensure proper state-transitions happen by setting @state to next state when ready.
    #     Generally when run out of actual data lines to send (so many times @state will be set to :getData
    #     while there is still data to send, so we stay in this state). Then after all data gone out,
    #     you would effet a state transition via @state=:postData
    #   * Don't just "raise" errors without calling scheduleFinish() first to clean up after yourself.
    # @return [String] Chunk of bytes to send out. Not too big for memory, not too long to generate (short ticks!), etc.
    def getData()
      chunk = ''
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "<#{self.object_id}> @dataEnumerator: #{@dataEnumerator.inspect}")
      ## Because pre-existing streaming implementation used extensive yield-chain oriented approach,
      ## we are leveraging an Enumerator object that uses that yield-oriented class's methods. We just
      ## ask this Enumerator for the "next" chunk...which is same as asking for the thing it next wants to yield.
      #chunk = @dataEnumerator.next() rescue nil # Rescued at end of iteration and get the StopIteration exception
      #
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "<#{self.object_id}> post-next(), chunk size: #{chunk.size}")
      if(@chromNames.nil?)
        chunk = @seqRetriever.nextFastaSeqForGenome()
      elsif(@chromNames.size > 1) # @chromNames is Array of 2+ chromosome names
        chunk = @seqRetriever.nextFastaSeqForChrs(@chromNames)
      else # @chromNames is Array of 1 chrom names
        chunk = @seqRetriever.nextFastaSeqForChrs(@chromNames)
      end

      if(chunk)
        @state = :getData
      else # chunk nil, done
        @state = :postData
        notify(:getData)
      end

      return chunk
    end # def getData()

    # IMPLEMENT.
    # STATE: :postData - Phase 3, post data spooling.
    #   * MUST ensure proper state-transitions happen by setting @state to next state when ready.
    #     Generally this will be :finish to schedule clean up.
    #   * Don't just "raise" errors without calling scheduleFinish() first to clean up after yourself.
    # @return [String] Chunk of bytes to send out. Typically some footer text, close-wrapper, or even empty string if not applicable.
    def postData()
      @state = :finish
      notify(:postData)
      return '' # No post-data footer or anything to send
    end
  end
end ; end ; end ; end ; end
