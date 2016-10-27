require 'json/stream'
require 'brl/util/util' # for memory info

# @note classes in this file were designed for a specific and inflexible (as it is implemented) purpose:
#   retrieve JSON objects from a file/io assumed to contain an array of objects or a single object, using
#   low memory, where the objects retrieved are just those belonging to the array (in the first case),
#   or the object in the file itself (in the latter case). That is, no child object are yielded.
#   For example, the array
#     [{"id"=>{"value"=>0}}, {"id"=>{"value"=>1}}, {"id"=>{"value"=>2}}]
#   will yield 
#     {"id"=>{"value"=>0}}
#   but not 
#     {"value"=>0}
#   etc. We will call such objects "top-level" objects here.
module BRL; module Util
  class BufferedJsonReader
    CHUNK_SIZE = 131072 # 128 * 1024

    # [Object] An IO object, must respond to :read
    attr_accessor :ioObj
    # [Integer] A configurable buffer size for reading from the IO object
    attr_accessor :chunkSize
    # [Integer] maximum memory to consume before yielding documents
    def maxMemory
      @parser.maxMemory * 1024
    end
    def maxMemory=(bytes)
      @parser.maxMemory = bytes
    end
    # Synchronize attempts with MyParser -- MyParser sets memory limit and we try to comply 
    #   here by adjusting the number of yielded objects; we first try to yield n_objects as
    #   requested in self.each(n_objects), then if an error occurs we notice how many objects
    #   we succeeded in yielding, m_objects, and try to yield that number. For any future errors
    #   that occur, we take a percent of m_objects and try that number. Finally, we try only 1
    #   object. Here we set the (attempts - 3) thresholds aka the "percent(s) of m_objects"
    attr_reader :attempts
    def attempts=(attempts)
      # @todo perhaps once BRL::Util::getMemUsagekB decreases we then increase maxObjs instead of
      # only descreasing as we do here in @objPercents
      @attempts = attempts
      enum = (1.0/attempts...1).step(1.0/attempts)
      @objPercents = enum.map{|xx| 1 - xx}
      @currEnumIdx = -1
      return attempts
    end

    def initialize(ioObj, opts={})
      raise ArgumentError.new("The provided ioObj must respond to read") unless(ioObj.respond_to?(:read))
      defaultOpts = {
        :chunkSize => CHUNK_SIZE
      }
      opts = defaultOpts.merge(opts)
      @ioObj = ioObj
      @chunkSize = opts[:chunkSize]
      @parser = JSON::Stream::MyParser.new()
      self.attempts=(@parser.attempts)
      @builder = JSON::Stream::MyBuilder.new(@parser)
    end

    # Yield JSON objects in uniform chunks
    # @param [Integer] maxObjs
    # @return [Integer] number of objects yielded
    # @raise JSON::Stream::MemoryError if an object could not be parsed under the alloted memory
    # @raise JSON::Stream::ParserError if ioObj has malformed JSON -- error messages contain 
    #   explanation of which character was expected and at what position in the stream
    def each(maxObjs=0, maxBytes=nil)
      retVal = nil
      if(maxObjs == 0)
        retVal = self.eachObj { |obj| yield obj; obj = nil }
      else
        retVal = self.eachObjs(maxObjs, maxBytes) { |objs| yield objs; objs.clear }
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Finished yielding #{retVal} objects with requested max chunk size #{maxObjs}")
      return retVal
    end

    # --------------------------------------------------
    # HELPER METHODS (PRIVATE)
    # --------------------------------------------------

    # Yield parsable JSON strings found in file
    # @note it is implied the file contains precisely an array of JSON objects
    # @todo ignore @attempts? maybe should just raise one error?
    def eachObj
      retVal = self.eachObjs(1) { |objArray| yield objArray[0] }
    end

    # Yield Array of size maxObjs of JSON objects found in ioObj
    # @param [Integer] maxObjs the maximum number of objects to yield
    # @param [NilClass, Integer] maxBytes an alternative upper limit to maxObjs; if
    #   serialized size of objects exceeds maxBytes then they are yielded even if
    #   the maxObjs limit has not yet been met
    # @return [Integer] the number of objects yielded
    def eachObjs(maxObjs=1, maxBytes=nil)
      raise ArgumentError.new("Number of objects to yield at a time must be greater than 0") unless(maxObjs > 0)
      retVal = 0
      maxBytes = (1.0/0.0) if(maxBytes.nil?)
      remainObjs = []
      self.eachChunk { |chunk|
        begin
          @parser.<<(chunk) { |objs|
            if(!remainObjs.empty?)
              # then yield the remaining documents from the last append first
              objs = remainObjs.dup() + objs
              remainObjs.clear()
            end
            while(objs.size > maxObjs)
              yieldObjs = objs[0...maxObjs]
              retVal += yieldObjs.size
              objs = objs[yieldObjs.size..-1]
              objs = [] if(objs.nil?) # enforce desired behavior for range slicing of array (when out of bounds)
              yield yieldObjs
              @parser.resetObjInfo(objs.size)
            end
            if(@parser.objInfo[:objsBytes] >= maxBytes)
              # this secondary yield condition also reports why we are yielding
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Exceeded serialized byte limit, yielding #{objs.size} objects")
              retVal += objs.size
              yield objs
              objs.clear()
              @parser.resetObjInfo(objs.size)
            end
            remainObjs += objs.dup()
            objs.clear()
          }
        rescue ::JSON::Stream::SoftMemoryError => err
          # then attempt to build maxObjs objects requires too much memory
          # yield what n < maxObjs we have and continue trying on n + 1
          # reduce attempted number of maximum documents to yield as a conservative measure
          if(@currEnumIdx == -1)
            maxObjs = remainObjs.size
            @objValues = @objPercents.map{|xx| (maxObjs * xx).to_i }
          else
            maxObjs = @objValues[@currEnumIdx] rescue nil
            maxObjs = 1 if(maxObjs.nil? or maxObjs < 1)
          end
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Exceeded soft memory limit: err=#{err.inspect}, new attempted object chunk size: #{maxObjs.inspect}")
          @currEnumIdx += 1
          retVal += remainObjs.size
          yield remainObjs
          remainObjs.clear()
        end
      }
      if(!remainObjs.empty?)
        retVal += remainObjs.size
        yield remainObjs
        remainObjs = nil
      end
      return retVal
    end

    # Yield chunks of CHUNK_SIZE bytes from file
    # @return [Fixnum] bytes yielded
    def eachChunk
      bytes = 0
      @ioObj.rewind()
      buffer = @ioObj.read(@chunkSize)
      while(!buffer.nil?)
        yield buffer
        bytes += buffer.size
        buffer = @ioObj.read(@chunkSize)
      end
      return bytes
    end

  end
end; end

# Extend JSON::Stream to yield objects as they are parsed and clear them from memory after yielding
module JSON; module Stream
  class MyBuilder < Builder

    def initialize(parser)
      super(parser)
      @parser = parser
      @objs = parser.objs if(parser.is_a?(MyParser))
      @objInfo = parser.objInfo
      raise ArgumentError.new("Builder could not coordinate @objs, @objInfo with Parser") if(@objs.nil? or @objInfo.nil?)
    end

    # Extend (decorate) JSON::Stream::Builder's end_object with detection of top-level objects:
    #   after (any) object is finished parsing, it is removed from the stack and added to its parent
    #   (e.g. as an element in an array). Thus for top-level objects we can check if the only stack
    #   element is an array and schedule its elements to be yielded and cleared from that array
    def end_object
      ret = super()
      if(@stack.size == 1 and @stack[-1].is_a?(Array))
        obj = @stack[-1][-1]
        @objs << obj
        @objInfo[:nObjs] += 1
        @objInfo[:lastObjPositions].push(@parser.pos)
        @stack[-1].clear
      end
      return ret
    end
  end

  class MyParser < Parser
    BUF_SIZE = BRL::Util::BufferedJsonReader::CHUNK_SIZE
    # array of top level objects as they are parsed
    attr_accessor :objs
    # information about the serialized size of the parsed objects
    attr_reader :objInfo
    # with @step, specify number of soft memory limits; a higher number allows for a 
    #   closer-to-maximum number of objects yielded at once
    attr_accessor :attempts
    # with @attempts, specify size of soft memory limits; 
    attr_accessor :step
    # Specify maximum size of a "top-level" object
    attr_reader :maxMemory
    # current buffer position (for entire io stream, not just chunk)
    attr_reader :pos
    def maxMemory=(bytes)
      @maxMemory = bytes / 1024.0
      @memorySteps = []
      (@attempts-1).downto(1) { |ii|
        @memorySteps << @maxMemory * (1 - ii * @step)
      }
      @lowerMaxMemoryIdx = 0
      @currentMax = @memorySteps[@lowerMaxMemoryIdx]
      return bytes
    end

    def initialize(*args)
      defaultOpts = {
        :attempts => 5,
        :step => 0.05,
        :maxMemory => 2684354560 # 2.5 GiB in bytes
      }
      opts = {}
      if(args.first.respond_to?(:key?) and args.first.key?(:constructor))
        opts = args.first
        constructor = args.first[:constructor]
      else
        constructor = args
      end
      ret = super(*constructor)
      opts = defaultOpts.merge(opts)
      @objs = []
      @objInfo = { 
        :nObjs => 0, # number of top-level objects finished since last call to resetObjInfo
        :objsBytes => 0, # number of bytes used for those objects
        :lastObjPositions => [], # the byte index from the io object where the last top-level object was finished
        :totalBytes => 0 # the total number of bytes read from the io object, updated with each call to resetObjInfo
      }
      @attempts = opts[:attempts]
      @step = opts[:step]
      self.maxMemory=(opts[:maxMemory])
      return ret
    end

    # Try to parse JSON as it is streamed in while paying attention to memory use
    # @raise JSON::Stream::SoftMemoryError to the caller to notify when a soft memory limit is 
    #   exceeded so it can try to adjust behavior accordingly; @attempts and @step
    #   control these soft memory limits
    # @raise JSON::Stream::MemoryError to finally give up parsing because memory has 
    #   exceed set hard limit
    def <<(data)
      ret = super(data)
      @objInfo[:objsBytes] += data.size
      @objInfo[:totalBytes] += data.size
      if(BRL::Util::MemoryInfo.getMemUsagekB > @currentMax) # both in KiB
        oldMax = @currentMax
        msg = "Could not finish parsing \"top-level\" object because it "\
              "requires more memory than the alloted #{oldMax * 1024} bytes"
        @lowerMaxMemoryIdx += 1
        if(@lowerMaxMemoryIdx >= @memorySteps.size)
          raise MemoryError.new(msg)
        else
          @currentMax = @memorySteps[@lowerMaxMemoryIdx]
          raise SoftMemoryError.new(msg)
        end
      end
      if block_given? 
        yield @objs
        @objs.clear
      end
      return ret
    end

    # Called by client after yielding objects in order to more accurately reflect current 
    #   serialized size of top-level objects
    # @param [Integer] nObjs the number of top-level objects that have been yielded and whose size information
    #   can be forgotten
    def resetObjInfo(nObjs)
      @objInfo[:nObjs] = 0
      lastPos = nil
      if(@objInfo[:lastObjPositions].size >= nObjs)
        lastPos = @objInfo[:lastObjPositions][nObjs - 1]
      else
        # then nObjs is probably 0
        lastPos = 0
      end
      @objInfo[:objsBytes] = @objInfo[:totalBytes] - lastPos
      @objInfo[:lastObjPositions] = @objInfo[:lastObjPositions][nObjs..-1]
      @objInfo[:lastObjPositions] = [] if(@objInfo[:lastObjPositions].nil?)
      return nil
    end
  end

  class SoftMemoryError < RuntimeError
  end
  
  class MemoryError < RuntimeError
  end
end ; end
