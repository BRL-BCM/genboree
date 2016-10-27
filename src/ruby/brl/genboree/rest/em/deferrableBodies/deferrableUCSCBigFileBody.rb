require 'brl/genboree/rest/em/deferrableBodies/abstractDeferrableBody'

module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies
  class DeferrableUCSCBigFileBody < AbstractDeferrableBody
    # Default chunk size
    DEF_CHUNK_SIZE = 1 * 1024 * 1024
    MAX_SEND_UCSC = 8 * 1024 * 1024

    # @return [IO] The path to the file we're reading from. Must support IO#read(bytes)
    attr_accessor :path
    # @return [Fixnum] The REQUESTED offset in the file to start reading from
    attr_accessor :reqOffset
    # @return [Fixnum] The REQUESTED length in the file to read from
    attr_accessor :reqLength
    # @return [Fixnum] The current offset in the file
    attr_accessor :offset
    # @return [Array<Symbol>] Array of events fired. Add via addListener(event, listenerProc). Really just here to document:
    #   * :sentChunk => called after a chunk is actively sent or passibly yielded up the chain; can be called MANY times
    #   * :finish => called after class's finish() ; the last event fired
    attr_reader :events

    # AUGMENT. Include a super(opts) call.
    def initialize(opts)
      super(opts)
      @path = opts[:path]
      raise ArgumentError, "ERROR: Not a valid file path: #{@path.inspect}" unless(@path.is_a?(String) and File.exist?(@path))
      @isRangeReq = (!opts[:length].nil? or !opts[:offset].nil?)
      @reqLength = ( opts[:length] or File.size(@path) )
      @reqOffset = opts[:offset].to_i
      # We will start reading at the REQUESTED offset
      @offset = @reqOffset
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG-#{self.object_id}", "Initialized deferrable file body for #{@path.inspect}\n  - chunkSize: #{@chunkSize.inspect}\n  - length, offset, total sent: #{@reqLength.inspect} , #{@reqOffset.inspect} , #{@totalBytesSent.inspect}")
    end

    # AUGMENT. Include a super() call.
    # Immediately (synchronously, this tick) perform finish/clean-up (i/o & memory clean up). Generally immediate, not async.
    def finish()
      super()
      @path = nil
      return
    end

    # IMPLEMENT.
    # Get next chunk of actual data to send.
    def getData()
      # Do we need to read any more or are we all done?
      if(@isRangeReq and @totalBytesSent >= MAX_SEND_UCSC)
        # SHORT CIRCUIT UCSC request
        # - Have we sent the max to UCSC?
        # - Assuming UCSC never consumes more than 8MB (?) per request, stop sending data earlier than their request indicates.
        chunk = nil
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Hit MAX we send to UCSC.")
      elsif(@totalBytesSent >= @reqLength)
        # Sent exactly UCSC request
        chunk = nil
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Sent EXACT amount asked for to UCSC.")
      else # There is more to send
        # Cannot read more than @reqLength, so we need to read exactly the right amounts each time
        # - So read the minimum of: exactly what remains in request OR chunk size
        readLen = [ (@reqLength - @totalBytesSent), @chunkSize ].min
        chunk = IO.read(@path, readLen, @offset)
        if(chunk)
          @offset += chunk.size
        end
      end
      return chunk
    end
  end
end ; end ; end ; end ; end
