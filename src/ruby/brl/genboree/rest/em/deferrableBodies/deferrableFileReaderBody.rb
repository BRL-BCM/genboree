require 'brl/genboree/rest/em/deferrableBodies/abstractDeferrableBody'

module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies
  class DeferrableFileReaderBody < AbstractDeferrableBody

    # @return [IO] The path to the file we're reading from. Must support IO#read(bytes)
    attr_accessor :path
    # @return [Boolean] Boolean that tells us whether we are deleting file after processing it (used for temp files when transferring files to user via FTP Storage Helper)
    attr_accessor :deleteFile
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
      @deleteFile = (opts[:deleteFile] or false)
      raise ArgumentError, "ERROR: Not a valid file path: #{@path.inspect}" unless(@path.is_a?(String) and File.exist?(@path))
      @offset = 0
      $stderr.debugPuts(__FILE__, __method__, "DEBUG-#{self.object_id}", "Initialized deferrable file body for #{@path.inspect}\n  - chunkSize: #{@chunkSize.inspect}\n  - offset and total sent: #{@offset.inspect} , #{@totalBytesSent.inspect}")
    end

    # AUGMENT. Include a super() call
    # Immediately (synchronously, this tick) perform finish/clean-up (i/o & memory clean up). Generally immediate, not async.
    def finish()
      super()
      File.delete(@path) if(@deleteFile)
      @path = nil
      return
    end

    # IMPLEMENT.
    # Get next chunk of actual data to send.
    def getData()
      chunk = IO.read(@path, @chunkSize, @offset)
      if(chunk)
        @offset += chunk.size
      end
      return chunk
    end
  end
end ; end ; end ; end ; end # module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies
