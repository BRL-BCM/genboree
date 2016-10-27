require 'em-http-request'
module GenboreeKbHelper
  class OrigDeferrableBody
   
    include EventMachine::Deferrable
    
    
    def initialize
      @queue = []
    end
    
    def call(body)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "in call()")
      @queue << body
      schedule_dequeue
    end
   
    def each(&blk)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "in each() of DeferrableBody")
      @body_callback = blk
      schedule_dequeue
    end
    
    

    private
      def schedule_dequeue
        $stderr.debugPuts(__FILE__, __method__, "YIELD", "entered schedule_dequeue(). Queue.size: #{@queue.size}" )
        $stderr.debugPuts(__FILE__, __method__, "YIELD", "@body_callback: #{@body_callback.inspect}" )
        return unless @body_callback
        EM.next_tick do
          #next unless body = @queue.shift
          body = @queue.shift
          if body
            $stderr.debugPuts(__FILE__, __method__, "NEXT_TICK", "Got body. Class: #{body.class}. Size: #{body.size}" )
            body.each do |chunk|
              $stderr.debugPuts(__FILE__, __method__, "YIELD", "calling block with chunk.size: #{chunk}." )
              @body_callback.call(chunk)
              #EM.next_tick do
              #  self.succeed
              #end
            end
            $stderr.debugPuts(__FILE__, __method__, "YIELD", "current queue size: #{@queue.size}" )
            schedule_dequeue unless @queue.empty?
          else
            $stderr.debugPuts(__FILE__, __method__, "NEXT_TICK", "Body is nil. Class: #{body.class.inspect}" )
            next
          end
        end
      end
  end
  
  
  
  

  class DeferrableBody
   
    include EventMachine::Deferrable
    attr_accessor :streamer
    
    def initialize
      @streamer = nil
    end
    
    def setStreamer(streamer)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Setting streamer object")
      @streamer = streamer
    end
   
    def each(&blk)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "in each() of DeferrableBody")
      @body_callback = blk
      schedule_dequeue
    end
    
    

    private
      def schedule_dequeue
        return unless @body_callback
        EM.next_tick do
          chunk = @streamer.getChunk()
          if chunk # We have valid data to send out
            #$stderr.debugPuts(__FILE__, __method__, "YIELD", "calling block with chunk.size: #{chunk}." )
            @body_callback.call(chunk)
            schedule_dequeue 
          else # We are done. Call succeed 
            $stderr.debugPuts(__FILE__, __method__, "NEXT_TICK", "All data sent. Closing stream and calling succeed on self." )
            @streamer.closeStream()
            self.succeed
            next
          end
        end
      end
  end
  
  
  class AsyncResp
    

    attr_reader :headers, :callback
    attr_accessor :status

    # Creates a instance and yields it to the block given
    # returns the async marker
    def self.perform(*args, &block)
      new(*args, &block).finish
    end

    def initialize(env, status=200, headers={})
      @callback = env['async.callback']
      @close = env['async.close']
      @body = GenboreeKbHelper::DeferrableBody.new
      @streamer = GenboreeKbHelper::Streamer.new
      @status = status
      @headers = headers
      @headers_sent = false
      @done = false
      if block_given?
        yield self
      end
    end

    def send_headers
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "entering send_headers()." )
      return if @headers_sent
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "sending header." )
      @callback.call [@status, @headers, @body]
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "header sent." )
      @headers_sent = true
    end

    def write()
      @streamer.fileHandle = File.open("/usr/local/brl/home/genbadmin/large.txt")
      @body.setStreamer(@streamer)
      send_headers
    end
    
   
    
    

    # Tell Thin the response is complete and the connection can be closed.
    def done
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "entered done()" )
      return if done?
      send_headers
      
      EM.next_tick { $stderr.debugPuts(__FILE__, __method__, "NEXT_TICK", "calling succeed" ); @body.succeed }
      @done = true
    end

    # Tells if the response has already been completed
    def done?
      @done
    end

    # Specify a block to be executed when the response is done
    #
    # Calling this method before the response has completed will cause the
    # callback block to be stored on an internal list.
    # If you call this method after the response is done, the block will
    # be executed immediately.
    #
    def callback &block
      @close.callback(&block)
      self
    end

    # Cancels an outstanding callback to &block if any. Undoes the action of #callback.
    #
    def cancel_callback block
      @close.cancel_callback(block)
    end

    
  end
end