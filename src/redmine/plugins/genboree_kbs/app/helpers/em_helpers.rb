require 'em-http-request'
require 'brl/util/util'
require 'plugins/genboree_kbs/app/helpers/multi_part_data_extractor'

module GenboreeKbHelper
  
  class EMHTTPStreamer
    
    attr_accessor :body, :http, :url, :callback, :headers
    
    def initialize(url=nil, body=nil)
      @url = url
      @body = body
      @http = nil
    end
    
    def initEMHttpRequest()
      @http = EventMachine::HttpRequest.new(@url, :connect_timeout => 10, :inactivity_timeout => 60).get
      @http.callback {
        if(@body.collateResponse)
          resp = @http.response
          if(@body.wrapInData)
            parsedResp = JSON.parse(resp)
            @body.body_callback.call( { "data" => parsedResp }.to_json )
          else
            @body.body_callback.call(resp)
          end
        end
        @body.succeed
        $stderr.debugPuts(__FILE__, __method__,  "GET-COMPLETE", "url: #{@url}" )
      }
      @http.headers { |headerHash|
        respStatus = @http.response_header.status.to_i
        if(respStatus >= 200 and respStatus < 400)
          @callback.call([respStatus, @headers, @body])
        else
          responseMess = ( ( @http.response and !@http.response.empty?) ? @http.response : "Unknown Error")
          @body.responseMessage = responseMess
          @body.call_dequeue = false
          @callback.call([respStatus, @headers, @body])
        end
      }
      @http.errback { $stderr.debugPuts(__FILE__, __method__, "GET-FAILED", "url: #{@url}\n\n#{@http.response.inspect}" ) }
    end
  end
  
  
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
    #    in every subsequent tick
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
          # This is analogous to getting a chunk of the response in a separate EM tick. 
          http.stream { |chunk|
            @body_callback.call(chunk)
          }
        end
      end
  end
  
  class ErrorStreamer
    
    def initialize(error)
      @error = error
    end
    def each
      yield @error
    end
  end
  
  
  # Main Wrapper class for doing deferred/async requests
  class EMHTTPAsyncResp
    

    attr_reader :headers, :callback, :status, :fullApiUrl
    attr_accessor :uploadFilePath, :kb, :coll, :grp, :host, :db, :genbFilePath, :format, :apiCaller
    attr_accessor :formBoundary, :wrapInData, :collateResponse

    # Creates a instance and yields it to the block given
    # returns the async marker
    def self.perform(*args, &block)
      new(*args, &block).finish
    end

    def initialize(env, status, headers, fullApiUrl=nil)
      @callback = env['async.callback']
      @close = env['async.close']
      @body = GenboreeKbHelper::EMHTTPDeferrableBody.new
      @streamer = GenboreeKbHelper::EMHTTPStreamer.new
      @streamer.url = fullApiUrl
      @streamer.body = @body
      @streamer.callback = @callback
      @streamer.headers = headers
      @fullApiUrl = fullApiUrl
      @formBoundary = nil
      @body.streamer = @streamer
      @outFileName = nil
      @uploadFilePath = nil
      @collateResponse = false
      @status = status
      @headers = headers
      @headers_sent = false
      @wrapInData = false
      @done = false
      if block_given?
        yield self
      end
    end

    def send_headers
      return if @headers_sent
      @callback.call [@status, @headers, @body]
      @headers_sent = true
    end
    
    # Main Wrapper method
    def start(reqType='get', submitTool=true)
      begin
        if(reqType == 'get')
          @body.wrapInData = @wrapInData
          @body.collateResponse = @collateResponse
          # We will not send headers blindly. We will check the response coming from Genboree and then send appropriate headers
          @streamer.initEMHttpRequest()
          $stderr.debugPuts(__FILE__, __method__, "GET-START", "url: #{@streamer.url}" )
        else # put. Currently only used for uploading files. Need to update it so that it can do regular PUTs
          # send headers and close response AND THEN start uploading file to genboree
          @body.call_dequeue = false
          @submitTool = submitTool
          # Send response back to client. (202/Accepted). 
          send_headers
          done
          callback {
            deEncodeMultPartMime()
          }
        end
      rescue Exception => err
        $stderr.debugPuts(__FILE__, __method__, "****ERROR****", err )
        @status = 200
        # Something went wrong. Construct an error message that we can send back to the user in the downloaded file.
        message = "FATAL ERROR: #{err.message}\n\nTRACE:\n#{err.backtrace.join("\n")}\n\nPlease contact the Genboree team with the information above."
        @body = ErrorStreamer.new(message)
        send_headers
      end
    end
    
    
    def deEncodeMultPartMime()
      fh = File.open(@uploadFilePath)
      @outFileName = "#{File.dirname(@uploadFilePath)}/#{File.basename(@uploadFilePath)}.file.#{rand(10_000)}.#{Time.now.to_f}.extracted"
      args = {
        :boundary => @formBoundary,
        :formDataName => "file",
        :outFileName => @outFileName,
        :callbkObj => self
      }
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Initializing MultiPartDataExtractor" )
      extractor = MultiPartDataExtractor.new(fh, args)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "calling notify_readable" )
      EM.next_tick { extractor.notify_readable }
    end
    
    def uploadFile()
      $stderr.debugPuts(__FILE__, __method__, "UPLOAD-START", "url: #{@fullApiUrl}" )
      http = EventMachine::HttpRequest.new(@fullApiUrl, :connect_timeout => 60, :inactivity_timeout => 600).put :file => @outFileName
      http.callback { |chunk|
        respStatus = http.response_header.status.to_i
        if(respStatus >= 200 and respStatus < 400)
          $stderr.debugPuts(__FILE__, __method__, "UPLOAD-COMPLETE", "url: #{@fullApiUrl}" )
          scheduleKbBulkUploader(http.response) if(@submitTool)
        else
          responseMess = ( ( http.response and !http.response.empty?) ? http.response : "Unknown Error")
          $stderr.debugPuts(__FILE__, __method__, "UPLOAD-FAILED", "url: #{@fullApiUrl}\nResponse: #{responseMess}" )
        end
        removeFile()
      }
      http.errback {
        $stderr.debugPuts(__FILE__, __method__, "UPLOAD-FAILED", "url: #{@fullApiUrl}\nResponse: #{http.response}" )
        removeFile()
      }
    end
    
    def removeFile()
      $stderr.debugPuts(__FILE__, __method__, "CLEANUP", "Removing files: #{@uploadFilePath} and #{@outFileName}" )
      `rm -f #{@uploadFilePath} #{@outFileName}`
    end
    
    # Schedules a "KB Bulk Upload" job after the file has finished uploading
    #   - Scans response to see if the file was uploaded immediately or as a deferred upload job.
    #   - If relatedJobId is present in the response, the file was accepted as a deferred upload job and we will submit a conditional job.
    def scheduleKbBulkUploader(response)
      respObj = JSON.parse(response)
      rsrcPath = "/REST/v1/genboree/tool/kbBulkUpload/job"
      inputUrl = "http://#{@host}/REST/v1/grp/#{CGI.escape(@grp)}/db/#{CGI.escape(@db)}/file/#{@genbFilePath}"
      outputUrl = "http://#{@host}/REST/v1/grp/#{CGI.escape(@grp)}/kb/#{CGI.escape(@kb)}/coll/#{CGI.escape(@coll)}?"
      jobConf = {
        "inputs" => [ inputUrl ],
        "outputs" => [ outputUrl ],
        "context" => {},
        "settings" => { "format" => @format }
      }
      # Upload was accepted as a deferred job due to the size of the file. We will submit a conditional job
      if(respObj['status'].key?('relatedJobIds') and !respObj['status']['relatedJobIds'].empty?)
        fileUploadJobId = respObj['status']['relatedJobIds'][0]
        jobConf['preconditionSet'] =  {
          "willNeverMatch"=> false,
          "numMet"=> 0,
          "someExpired"=> false,
          "count"=> 0,
          "preconditions"=> [
            {
              "type" => "job",
              "expires" => (Time.now + Time::WEEK_SECS).to_s,
              "condition"=> {
                "dependencyJobUrl" =>
                  "http://#{host}/REST/v1/job/#{fileUploadJobId}",
                "acceptableStatuses" =>
                {
                  "killed"=>true,
                  "failed"=>true,
                  "completed"=>true,
                  "partialSuccess"=>true,
                  "canceled"=>true
                }
              }
            }
          ]
        }
      end
      @apiCaller.setRsrcPath(rsrcPath)
      @apiCaller.put({}, jobConf.to_json)
      if(!@apiCaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "JOB SUBMISSION FAILURE", apiCaller.respBody.inspect )
      else
        $stderr.debugPuts(__FILE__, __method__, "JOB ACCEPTED", apiCaller.respBody.inspect )
      end
    end

    # Tell Thin the response is complete and the connection can be closed.
    def done
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