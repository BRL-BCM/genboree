module GbTools
 # a simple class to submit Genboree tool jobs
  class GbToolSubmitter 
    def initialize(env, jobHost, redminePrj)
      raise ArgumentError, "HOST_ERROR: The rack environment - cannot be #{env.class} (nil or empty)" if(env.nil? or env.empty?) 
      raise ArgumentError, "HOST_ERROR: The jobhost - #{jobHost.inspect} cannot be #{jobHost.class} (nil or empty)" if(jobHost.nil? or jobHost.empty?) 
      
      @apiReq = GbApi::JsonAsyncApiRequester.new(env, jobHost, redminePrj)   
    end

    # submits the tool to the tool job rest resource path
    # @return [Hash] submitResp containing the response and the status from the api requester
    # @param [String] toolIdStr id of the tool of interest ; required for the resource path 
    # @param [Hash] jobConf the job configuration containing inputs, outputs, settings, context fields
    # @todo apiPut to be replaced by the async request 
    def submit(toolIdStr, jobConf)
      submitResp = {:respObj => nil, :status => nil}
      rsrcPath = "/REST/v1/genboree/tool/{toolIdStr}/job"
      fieldMap  = {:toolIdStr => toolIdStr}
      @apiReq.bodyFinish {
        headers = @apiReq.respHeaders
        status = @apiReq.respStatus
        headers['Content-Type'] = "text/plain"
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG',  "@apiReq ------- #{@apiReq.respBody.inspect}")
        @apiReq.sendToClient(status, headers, JSON.generate(@apiReq.respBody))
      }
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG',  "rsrcPath ------- #{rsrcPath.inspect}")
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG',  "fieldMap------- #{fieldMap.inspect}")
      @apiReq.put(rsrcPath, fieldMap, jobConf.to_json)

    end
    

  end
end
