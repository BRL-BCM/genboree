module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies ; class AbstractDeferrableBody ; end ; end ; end ; end ; end ; end

require 'ostruct'
require 'time'
require 'eventmachine'
require 'brl/util/util'
require 'brl/util/linux/iostat'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/em/events/eventNotifier'

module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies
  class AbstractDeferrableBody
    include EventMachine::Deferrable
    include BRL::Genboree::REST::EM::Events::EventNotifier

    # @return [Fixnum] Default chunk size
    DEF_CHUNK_SIZE = 128 * 1024
    THROTTLE_TYPE = ( BRL::Genboree::GenboreeConfig.load().throttleType.to_sym rescue :scaledBySize ) # The default unless specified
    THROTTLE_CONFS = {
      :fixedBySize  => {
        :bytesPerSec => (8.5 * 1024 * 1024),
        :window => 10.0,
        :pause => 0.050 }, # 50ms (< 50ms allows too much variation, including higher than desired bytes/sec; even 50 will have some)
      :scaledBySize => {
        :window => 10.0,  # 10sec
        :pause  => 0.050, # 50ms (< 50ms allows too much variation, including higher than desired bytes/sec; even 50 will have some)
        :sizeScaling => [
          { :size => (    500*1024*1024), :bytesPerSec => (50.0*1024*1024) }, # Under 0.5GB: Full speed (50MB/sec)
          { :size => ( 2*1024*1024*1024), :bytesPerSec => ( 8.5*1024*1024) }, # Under 2.0GB: Just under ~actual full speed @ 8.5MB/sec
          { :size => ( 5*1024*1024*1024), :bytesPerSec => ( 6.0*1024*1024) }, # Under 5.0GB: Some reduction @ 6.5MB/sec
          { :size => (10*1024*1024*1024), :bytesPerSec => ( 3.5*1024*1024) }  # Over 5.0GB: High reduction @ 2.5MB/sec (last entry is terminal speed)
        ]
      },
      :fixedByDiskIO => {
        :window => 10.0,  # 10sec
        :pause  => 0.050, # 50ms (< 50ms allows too much variation, including higher than desired bytes/sec; even 50 will have some)
        :diskIO => {
          :readBytesPerSec => ( BRL::Genboree::GenboreeConfig.load().throttleReadBytesPerSec.to_f rescue (180*1024*1024) ),
          :wrtnBytesPerSec => ( BRL::Genboree::GenboreeConfig.load().throttleWrtnBytesPerSec.to_f rescue ( 80*1024*1024) ),
          :bothBytesPerSec => ( BRL::Genboree::GenboreeConfig.load().throttleBothBytesPerSec.to_f rescue (180*1024*1024) )
        },
        :sizeScaling => [ # nil for no size scaling in addition to the disk activity throttling; more aggressive than sizeScaling alone (disk I/O throttling *should* handle all the throttling)
          { :size => ( 5*1024*1024*1024), :bytesPerSec => (50.0*1024*1024) }, # Under 2.0GB: Full speed (50MB/sec)
          { :size => (10*1024*1024*1024), :bytesPerSec => ( 7.5*1024*1024) }, # Under 10.0GB: Slight reduction @ 7.5MB/sec
          { :size => (20*1024*1024*1024), :bytesPerSec => ( 6.5*1024*1024) }  # Over 10.0GB: More reduction reduction @ 6.5MB/sec (last entry is terminal speed)
        ]
      }
    }

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
    # @return [Boolean] Flag which indicates whether deferrable body is finished or not
    attr_reader :isFinished

    # AUGMENT. Include a super(opts) call.
    def initialize(opts)
      @events             = [ :finish, :sentChunk ]
      @doYield            = ( opts[:yield] or false )
      @chunkSize          = (opts[:chunkSize] or self.class::DEF_CHUNK_SIZE)
      @totalBytesSent     = 0
      @throttlingLookback = OpenStruct.new( :time => nil, :sent => @totalBytesSent )
      @throttleRec        = OpenStruct.new( :time => nil, :block => false )
      @throttleType       = ( opts[:throttleType].is_a?(Symbol) ? opts[:throttleType] : self.class::THROTTLE_TYPE)
      @throttleConf       = ( opts[:throttleConf] ? opts[:throttleConf] : self.class::THROTTLE_CONFS[@throttleType] )
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "@throttleType:\n#{@throttleType.inspect}\n\n@throttleConf:\n#{JSON.pretty_generate(@throttleConf)}\n\n")
      if( @throttleType == :fixedByDiskIO )
        # Create Iostat with default cmd memoization and reuse enabled (we won't be monitoring, just need instant counter info)
        @iostat = BRL::Util::Linux::IOStat.new()
      else
        @iostat = nil
      end
      @prevSizeScaleConf = nil
      @listeners         = Hash.new { |hh, kk| hh[kk] = [] }
      @isFinished        = false
    end

    def throttle()
      # TEMP: on production only (odd throttle related mem leak)
      return false

      nowTime = Time.now.to_f
      engageThrottle = false

      # Check to see if we should remove a throttle "blockage" (i.e. a pause)
      if( @throttleRec.time and @throttleRec.block )
        if( nowTime > @throttleRec.time ) # We were
          @throttleRec.time = nil
          @throttleRec.block = false
          #$stderr.puts "  RS"
        end
      end

      # Are we still throttling?
      if( @throttleRec.time and @throttleRec.block )
        engageThrottle = :dueToExistingBlock # yes, still on pause
      else # throttle not currently engaged
        # Is @throttleLookback still in the lookback window?
        if( @throttlingLookback.time and ( ( nowTime - @throttlingLookback.time ) > @throttleConf[:window] ) )
          @throttlingLookback.time = nil # no longer in window, so start a new window
        end

        if( @throttlingLookback.time.nil? ) # Going to start a new window; not currently throttling
          engageThrottle = false
        else # Not starting new window, consider current window
          # As long as average bytes/sec during the lookback window is ok, no need for throttle
          # -  may not be exactly throttleConf[:window], which is our target, due to when EM iteration gets to us
          exactWindowLen = ( nowTime - @throttlingLookback.time )

          # First, disk I/O check if doing that.
          if( @throttleType == :fixedByDiskIO )
            # Clear @iostat memoization cache. Only cache for calls within a given throttle() call.
            # . @iostat is shared by all chunks handled by this request. Only made once per request.
            @iostat.clear()
            # How many bytes read, wrtn, both up to now?
            currBytesRead = @iostat.diskTotalBytesByActivity( :read )
            currBytesWrtn = @iostat.diskTotalBytesByActivity( :wrtn )
            currBytesBoth = ( currBytesRead + currBytesWrtn )
            # How many bytes read, wrtn, both at beginning of window?
            startBytesRead = @throttlingLookback.totalReadBytes
            startBytesWrtn = @throttlingLookback.totalWrtnBytes
            startBytesBoth = ( startBytesRead + startBytesWrtn )
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "TOTAL BYTES BY ACTIVITY:\n\tCurr => R: #{currBytesRead.commify} ; W: #{currBytesWrtn.commify} ; B: #{currBytesBoth.commify}\n\tStrt => R: #{startBytesRead.commify} ; W: #{startBytesWrtn.commify} ; B: #{startBytesBoth.commify}")
            if( startBytesBoth ) # Not nil, so have enough info to throttle by disk I/O
              # First, try to check disk I/O based throttling
              diskIOConf = @throttleConf[:diskIO]
              diskIOReadPerSec = diskIOConf[:readBytesPerSec]
              diskIOWrtnPerSec = diskIOConf[:wrtnBytesPerSec]
              diskIOBothPerSec = diskIOConf[:bothBytesPerSec]

              avgBytesReadPerSec = ( ( currBytesRead - startBytesRead ) / exactWindowLen )
              avgBytesWrtnPerSec = ( ( currBytesWrtn - startBytesWrtn ) / exactWindowLen )
              avgBytesBothPerSec = ( ( currBytesBoth - startBytesBoth ) / exactWindowLen )

              #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "TOTAL BYTES ACTIVITY AVGS (#{exactWindowLen.inspect}):\n\tAvrg => R: #{avgBytesReadPerSec.commify} ; W: #{avgBytesWrtnPerSec.commify} ; B: #{avgBytesBothPerSec.commify}")
              #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "LIMIT BYTES ACTIVITY AVGS:\n\tAvrg => R: #{diskIOConf[:readBytesPerSec].commify} ; W: #{diskIOConf[:wrtnBytesPerSec].commify} ; B: #{diskIOConf[:bothBytesPerSec].commify}\n\tTHROTTLE? #{( ( diskIOConf[:readBytesPerSec] and avgBytesReadPerSec > diskIOConf[:readBytesPerSec] ) or                  ( diskIOConf[:wrtnBytesPerSec] and avgBytesWrtnPerSec > diskIOConf[:wrtnBytesPerSec] ) or                  ( diskIOConf[:bothBytesPerSec] and avgBytesBothPerSec > diskIOConf[:bothBytesPerSec] ) ).inspect}\n\n")

              if( ( diskIOReadPerSec and avgBytesReadPerSec > diskIOReadPerSec ) or
                  ( diskIOWrtnPerSec and avgBytesWrtnPerSec > diskIOWrtnPerSec ) or
                  ( diskIOBothPerSec and avgBytesBothPerSec > diskIOBothPerSec ) )
                engageThrottle = :dueToDiskIO
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "\tD - #{avgBytesReadPerSec.commify} & #{avgBytesWrtnPerSec.commify} & #{avgBytesBothPerSec.commify}")
                #$stderr.puts "\tIO"
              end
            end
          end

          # Next do any relevant throttling based on size of total bytes sent; unless we engaged the throttle due to
          #   disk I/O (for :fixedDiskIO checked above), we need to check size-based throttling regardless. Even for
          #   :fixedDiskIO, size based throttling can act as a fallback (unless completely disabled).
          unless( engageThrottle ) # Don't bother if already engaged throttle (would be due to :fixedDiskIO check)
            avgWindowBytesPerSec = ( ( @totalBytesSent - @throttlingLookback.sent ) / exactWindowLen )
            # Get specific size scaling, if relevant
            # . :fixedBySize won't have this field, which is fine
            # . :fixedByDiskIO may or may not have this field (default will have, but can be disabled by dev)
            # . Thus it's ok to be missing/nil. We'll even use that for flow-of-control.
            sizeScale = @throttleConf[:sizeScaling]
            sizeScaleConf = ( sizeScale ? pickSizeScaleConf( sizeScale ) : nil )
            if( ( ( @throttleType == :fixedBySize ) and (avgWindowBytesPerSec > @throttleConf[:bytesPerSec]) ) or
                ( ( @throttleType == :scaledBySize or @throttleType == :fixedByDiskIO ) and sizeScaleConf and (avgWindowBytesPerSec > sizeScaleConf[:bytesPerSec]) ) )
              # We are over bytes/sec throttle limit in our window.
              # - We will keep doing this until we have no more lookback records or we're back under @throttleBytes limit
              engageThrottle = :dueToSize
              #$stderr.puts "\tSZ"
            else
              # We're under the limit.
              #$stderr.puts "OK @ #{Time.now}"
              engageThrottle = false
            end
          end
        end
      end

      # Update throttle info based on whether throttle is engaged or not
      if( engageThrottle )
        if( engageThrottle == :dueToSize or engageThrottle == :dueToDiskIO )
          # Either start throttle due to disk I/O limit or due to size limit.
          # Regardless why, throttle by blocking until THROTTLE_PAUSE in the future.
          # * Place a blocking throttle record. It must be passed after the configured pause.
          @throttleRec.time = ( nowTime + @throttleConf[:pause] )
          @throttleRec.block = true
        else #throttle still engaged :dueToExistingBlock which we need to pass. Do nothing.
          #$stderr.puts "\tIO+"
        end
      else # not currently throttling
        # Are we to start a new lookback window?
        if( @throttlingLookback.time.nil? )
          @throttlingLookback.time = nowTime
          @throttlingLookback.sent = @totalBytesSent
          if( @throttleType == :fixedByDiskIO )
            @throttlingLookback.totalReadBytes = @iostat.diskTotalBytesByActivity( :read )
            @throttlingLookback.totalWrtnBytes = @iostat.diskTotalBytesByActivity( :wrtn )
          end
        # else # continue using the current @throttlingLookback info
        end
      end

      #$stderr.debugPuts(__FILE__, __method__, 'TIME', "----------------> THROTTLE CHECK in #{Time.now.to_f - nowTime} sec")
      return ( engageThrottle ? true : false )
    end

    # Which size-scaling conf to use depends on how much data has been sent so far (conf scaled by size).
    # * For the smallest files, there is no throttling usually since the bytes/window is bigger than code can do
    # * For larger files, they start fast but scale to lower rates as they progress because spooling to disk
    #   becomes more and more likely as code data production outpaces client's ability to accept the data.
    # * When scaling by disk I/O primarily, the size scaling throttle tends to be more permissive since it's only
    #   present as a slight back-up/fallback check and the disk I/O *ought* to be handling throttling decisions on its own.
    def pickSizeScaleConf( sizeScale )
      sizeScaleConf = nil
      if( sizeScale )
        sizeScaleConf = sizeScale.find { |conf| @totalBytesSent <= conf[:size] }
        sizeScaleConf ||= sizeScale.last # if bigger than the last, use it since it's the slowest
        if( @prevSizeScaleConf.nil? or ( @prevSizeScaleConf[:size] != sizeScaleConf[:size] ) )
          $stderr.puts "\tSwitch from #{@prevSizeScaleConf[:bytesPerSec].commify.inspect rescue '[NONE YET]'} bytes / sec to #{sizeScaleConf[:bytesPerSec].commify.inspect} bytes / sec because total bytes sent is now #{@totalBytesSent.commify.inspect}. Current conf:\n\t\t#{sizeScaleConf.inspect}" unless( @prevSizeScaleConf.nil? )
          @prevSizeScaleConf = sizeScaleConf
        end
      end
      return sizeScaleConf
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
      # If we are engaging the throttle, arrange for nextChunk() to return special Symbol :throttleEngaged,
      #   else call the sub-class's getData() to get the actual next chunk.
      # * We cannot return nil or false, since that will tell doYield() that the sub-class has no more
      #   data to send. So instead it will look for this special Symbol and avoid the yield call entirely this
      #   round.
      # * We could return an empty chunk for an empty yield, but we've seen that cause problems on some machines/implementations when
      #   yielded. And why not avoid such things and the yield altogether?
      if( throttle() )
        chunk = :throttleEngaged
      else
        chunk = getData()
      end
      return chunk
    end

    # ------------------------------------------------------------------
    # INFRASTRUCTURE. Shouldn't need to override these:
    # ------------------------------------------------------------------
    def each() # will have a block ... use Proc.new trick to save AND/OR yield
      if(@isFinished)
        raise "each() method is being called even though isFinished flag has been set. The state machine has already finished so it doesn't make sense to traverse additional chunks using each(). Additional call to each() is being done by: #{caller(0).join("\n")}" 
      end
      @sendCallback = Proc.new
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "<#{self.object_id}> Enter each() with block #{sendCallback.inspect}. Will #{@doYield ? 'NOT' : ''} be managing async ourselves via EM interaction.")

      if(@doYield) # arrange to do fiber / yield-chain way ; caller manages iteration and [hopefully] asynchronicity
        $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "About to start the doYield() loop for Yield-Chain mode")
        doYield { |chunk| yield chunk } # Respects the old yield-chain
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Done yielding chunks using Deferrable in Yield-Chain mode. Now transition to 'finish' state.")
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
      yieldedAtLeastOne = false
      # As long as nextChunk() is not the special Symbol :throttleEngaged--indicating there is no chunk to
      #   to send this round--we'll yield non-nil chunk to Rack. If chunk is nil, the sub-class has no more
      #   data to send and the while() loop will have stopped anyway.
      # * This will direct yield to thin/rack followed by finish-phase. Can't do a @sendCallback.call because Fiber will complain
      #  with a FiberError about " can't yield from root fiber"
      while( chunk = nextChunk() )
        if( chunk != :throttleEngaged )
          @totalBytesSent += chunk.size
          yield chunk # respect yield-chain
          yieldedAtLeastOne = true
          notify(:sentChunk)
        end
      end
      
      # NOTE: on *valine* only, if no chunk sent (first chunk is nil) or all chunks were empty string, *thin CRASHES*
      # with an error. We thus don't handle downloads using valine, only taurine. 
      # But, another hack is to ensure we sent at least 1 bytes (stupid for 0byte file):
      #
      ## Important to have sent at least 1 String chunk to Rack.
      ## If got back nil chunk the very first time, arrange to send a '' chunk.
      ##unless(yieldedAtLeastOne)
      #if(@totalBytesSent <= 0)
      #  $stderr.debugPuts(__FILE__, __method__, "DEBUG", "(Yield-chain mode) First chunk was nil and/or emtpy, may never have yielded a non-empty chunk. Protecting vs crash on valine by yielding ' '") 
      #  yield ' ' # respect yield-chain
      #end

      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "(Yield-chain mode) Done yielding chunks. @totalBytesSent = #{@totalBytesSent.inspect}. Deferrable class #{self.class.inspect} involvement is over.")
    end

    # Send out the chunks asynchronously
    def scheduleAsync()
      if(@sendCallback)
        # As long as nextChunk() is not the special Symbol :throttleEngaged--indicating there is no chunk to
        #   to send this round--we'll call the callback with the non-nil chunk and have EM schedule another async
        #   chunk sending. If chunk is nil, the sub-class has no more data to send and we'll schedule the finish state.
        chunk = nextChunk()
        if(chunk)
          if( chunk != :throttleEngaged ) # if it is, we'll not send anything, just schedule another async chunk sending call
            @totalBytesSent += chunk.size
            # Send the chunk using the @sendCallback function we saved when our each() was called
            @sendCallback.call(chunk)
            notify(:sentChunk)
          end
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
      @isFinished = true
      notify(:finish)
      # Arrange to call final infrastructure clear(); can only be done AFTER all :finish listeners are done
      addListener(:clear, Proc.new { |event, notifier| notifier.clear() })
      notify(:clear) # internal only
    rescue Exception => err
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Protected vs exception within EM loop. Exception details:\n  - Class: #{err.class}\n  - Message: #{err.message}\n  - Backtrace:\n#{err.backtrace.join("\n")}")
    end
  end # class AbstractDeferrableBody
end ; end ; end ; end ; end # module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies
