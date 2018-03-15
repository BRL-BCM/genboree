require 'brl/rest/apiCaller'
require 'brl/dataStructure/cache' # for BRL::DataStructure::LimitedCache

module GbApi

  # This convenience sub-class of {SimpleAsyncApiRequester} will employ its
  #   OWN {#respCallback} and will spool the response body into memory (see #rawRespBody)
  #   and will parse the response body as JSON.
  # You need only register your {#bodyFinish} method and make use of the convenience
  #   accessors and methods to get at the parsed data, etc.
  class JsonAsyncApiRequester < SimpleAsyncApiRequester

    # @return [boolean] Should the body be read and parsed as JSON? If true,
    #   {#respBody} will have the parsed response payload or an Exception
    #   (usually a JSON::ParseError). If false, {#respBody} will have the
    #   raw response payload string. Default true.
    attr_accessor :doParse
    # @return [Fixnum] The response status
    attr_reader :respStatus
    # @return [Hash] The response headers
    attr_reader :respHeaders
    # @return [Object,Exception,String] The parsed json object or the raw response string.
    #   (see #doParse). Will have exception if asked to parse, but parsing raises Exception.
    attr_reader :respBody
    # @return [String] The raw response payload as a String
    attr_reader :rawRespBody

    def initialize(rackEnv, targetHost, rmProject, rmUser=rackEnv[:currRmUser] )
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Did we get an rmUser out of the rackEnv param?\n\nrmUser: #{rmUser.inspect}\n\nrackEnv[:currRmuser]: #{rackEnv[:currRmUser].inspect}\n\n")
      super(rackEnv, targetHost, rmProject, rmUser)
      @doParse = true
      @respBody = @respStatus = @respHeaders = nil
      @rawRespBody = ''
    end

    # Get the GB API 'data' object, if available.
    # @return [Object,Exception,nil] If response parsing was done but raised an exception,
    #   this will return that exception. If parsing was turned off OR the rsrcPath had the
    #   gbEnvelope=no parameter, this is useless and will return nil. Else should have a standard
    #   GB API wrapped response with 'data' and 'status' keys...this will return whatever is at the 'data' key.
    def apiDataObj()
      return apiEnvelopeSection('data')
    end

    # Get the GB API 'status' object, if available.
    # @return [Object,Exception,nil] If response parsing was done but raised an exception,
    #   this will return that exception. If parsing was turned off OR the rsrcPath had the
    #   gbEnvelope=no parameter, this is useless and will return nil. Else should have a standard
    #   GB API wrapped response with 'data' and 'status' keys...this will return whatever is at the 'status' key.
    def apiStatusObj()
      return apiEnvelopeSection('status')
    end

    private

    # Initialize an object which will do the actual aysync request with help of EM, and which
    #   will allow the deferrable body object to read chunks of response asynchronously for
    #   presentation to the callback.
    #
    def initRequest(payload=nil)
      @respBody = @respStatus = @respHeaders = nil
      @rawRespBody = ''
      super(payload)
      #$stderr.debugPuts(__FILE__, __method__, '>>>>>> DEBUG', "[#{@railsRequestId.inspect}] Configured an EM HTTP Request wrapper/helper object.")
    end

    # We've taken this private; it is public in the parent class. It is called internally only and will accumulate the raw
    #   body payload string and will attempt JSON parsing if asked.
    def respCallback(&blk)
      super(blk)
    end

    def apiEnvelopeSection(section)
      retVal = nil
      if(@respBody.is_a?(Exception))
        retVal = respBody
      elsif(@respBody.is_a?(Hash))
        retVal = @respBody[section]
      else # respBody is raw String (e.g. no parsing requested) or is not a gbEnveloped (turned off maybe?)
        retVal = nil
      end
      return retVal
    end

    def doRequest(httpMethod, rsrcPath, fieldMap, payload=nil)
      @rawRespBody = ''
      @respBody = nil
      # Register a respCallback that does appropriate things
      respCallback { |array|
        # Save the status and headers
        @respStatus = array[0]
        @respHeaders = array[1]
        # Accumulate resp body in string
        if(array[2].respond_to?(:each))
          array[2].each { |chunk|
            @rawRespBody << chunk
          }
        else
          $stderr.debugPuts(__FILE__, __method__, 'ERROR', "[#{@railsRequestId.inspect}] Unexpected: 3rd element of Rack-type response array didn't contain an each-able object. Contained a #{array[2].class} .")
        end
      }
      # Register a bodyFinish callback the will attempt parsing if asked AND
      #   which will still cal the dev's bodyCallback
      @devBodyFinish = @bodyFinish
      bodyFinish {
        # Do json parsing if asked
        if(@doParse and @rawRespBody and @rawRespBody.is_a?(String) and @rawRespBody =~ /\S/)
          begin
            @respBody = JSON.parse(@rawRespBody)
          rescue Exception => err
            @respBody = err
          end
        end
        # Call dev-registered bodyFinish
        @devBodyFinish.call() if(@devBodyFinish.is_a?(Proc))
      }
      # Call parent method to make it happen
      super(httpMethod, rsrcPath, fieldMap, payload)
    end
  end
end
