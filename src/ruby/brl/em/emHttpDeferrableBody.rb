require 'em-http-request'
module BRL; module EM
  
  # Class used for constructing async responses
  # An instance of this class is passed as the 3rd arg in the triplet handed over to thin [async.callback.call()]
  # The EventMachine library then calls each() after sending out the headers.
  class EMHTTPDeferrableBody
   
    include EventMachine::Deferrable
    attr_accessor :streamer, :call_dequeue, :collateResponse, :responseMessage
    attr_accessor :wrapInData, :body_callback
    
    attr_accessor :callSucceedAfterYieldingResponseMessage
    
    def initialize()
      @streamer = nil
      @call_dequeue = true
      @collateResponse = false
      @responseMessage = "{ 'success' :true }"
      @callSucceedAfterYieldingResponseMessage = false
    end
    
    # This method is VERY tricky to understand but is key to understand how we use the EMHTTPDeferrableBody class to generate async responses.
    # The call to ENV['async.callback'].call initiates the response cascade and EM calls this each().
    # The block passed to this method is saved as an instance variable and is called by "us" whenever we are ready to send data out back to client.
    # Normally you would want each call to this block be in a separate tick so that the entire response is non-blocking and
    #    the server serving this particular response is free to serve other requests while generating a "chunk" of *this* response
    #    in every subsequent tick.
    def each(&blk)
      @body_callback = blk
      if(@call_dequeue)
        schedule_dequeue 
      else
        @body_callback.call(@responseMessage) # If you already have the response ready
        if(@callSucceedAfterYieldingResponseMessage)
          self.succeed
        end
      end
    end

    private
      def schedule_dequeue
        return unless @body_callback
        unless(@collateResponse) # Streamed response, downloading file, etc
          http = @streamer.http
          # em http client (http.stream) will ensure that we get the response from the remote server in a non blocking fashion.
          # This is analogous to getting a chunk of the response in a separate EM tick which is probably what EM does behind the scenes.
          http.stream { |chunk|
            @body_callback.call(chunk)
          }
        end
      end
  end
   
end; end
