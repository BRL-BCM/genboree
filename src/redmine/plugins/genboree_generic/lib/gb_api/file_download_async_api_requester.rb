require 'brl/rest/apiCaller'
require 'brl/dataStructure/cache' # for BRL::DataStructure::LimitedCache

module GbApi

  # This convenience sub-class of {SimpleAsyncApiRequester} will employ its
  #   OWN {#respCallback} and will spool the response body into memory (see #rawRespBody)
  #   and will parse the response body as JSON.
  # You need only register your {#bodyFinish} method and make use of the convenience
  #   accessors and methods to get at the parsed data, etc.
  class FileDownloadAsyncApiRequester < SimpleAsyncApiRequester

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
    # @return mime type of the file to be downloaded. If not set, will use default 'application/octet-stream'
    attr_accessor :mimeType
    
    # @return [Hash] What action to take depending on the mime type of the file: default is add Content-Disposition and send file as attachment. 
    TYPE_TO_ACTION_RECOMMENDATION_HASH = {
      "application/pdf" => :displayInBrowser
    }
    # @return [Array] WHat are the actions you can perform based on the file mime type
    RECOMMENDED_ACTIONS = [:displayInBrowser, :attachment]
    
    # @return [Boolean] Do you want to override the recommended action for your mime type 
    attr_accessor :overideRecAction
    
    # @return [Boolean] WHich one of two RECOMMENDED_ACTIONS do you want enforced
    attr_accessor :forceAction
    
    # Constructor
    def initialize(rackEnv, targetHost, rmProject, rmUser=User.current)
      super(rackEnv, targetHost, rmProject, rmUser)
      @doParse = true
      @respBody = @respStatus = @respHeaders = nil
      @rawRespBody = ''
      @mimeType="application/octet-stream"
      @overideRecAction = false
      @forceAction = :attachment
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
      @respBody = [""]
      # Register a respCallback that does appropriate things
      respCallback { |array|
        # Save the status and headers
        @respStatus = array[0]
        @respHeaders = array[1]
        @respHeaders["CONTENT_TYPE"] = @mimeType
        action = ( TYPE_TO_ACTION_RECOMMENDATION_HASH.key?(@mimeType) ? TYPE_TO_ACTION_RECOMMENDATION_HASH[@mimeType] : :attachment )
        if(@overideRecAction)
          action = @forceAction
        end
        if(action == :attachment)
          fileName = CGI.unescape(File.basename(rsrcPath.chomp("?").gsub(/\/data$/, "")))    
          @respHeaders['Content-disposition'] = "attachment; fileName=#{fileName.makeSafeStr(:ultra)}"
        end
        # Accumulate resp body in string
        if(array[2].respond_to?(:each))
          @respBody = array[2]
          sendToClient(@respStatus, @respHeaders, array[2])
        else
          msg = "[#{@railsRequestId.inspect}] Unexpected: 3rd element of Rack-type response array didn't contain an each-able object. Contained a #{array[2].class} ."
          $stderr.debugPuts(__FILE__, __method__, 'ERROR', msg)
          sendToClient(500, @respHeaders, JSON.generate({"status" => { "msg" => msg, "statusCode" => 500}}) )
        end
      }
      # Register a bodyFinish callback the will attempt parsing if asked AND
      #   which will still cal the dev's bodyCallback
      bodyFinish {
        @respBody.succeed
      }
      # Call parent method to make it happen
      super(httpMethod, rsrcPath, fieldMap, payload)
    end
  end
end
