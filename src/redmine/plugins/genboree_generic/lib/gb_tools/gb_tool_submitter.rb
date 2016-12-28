module GbTools
 # a simple class to submit Genboree tool jobs
  class GbToolSubmitter 
    def initialize(jobHost, rmProject)
      @jobHost = jobHost
      @redminePrj = rmProject
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
        syncReq = GbApi::SyncApiRequester.new(@jobHost, @redminePrj)
        submitResp = syncReq.apiPut(rsrcPath, JSON.generate(jobConf), fieldMap)
      return submitResp
    end
    

  end
end
