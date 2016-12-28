require 'brl/rest/apiCaller'
module GbApi
 
  # Api requester that performs sync requests. Currenlty only put request implemented 
  class SyncApiRequester 
    def initialize(targetHost, rmProject, rmUser=User.current)
      @reqHost = targetHost
      @redmineProject = rmProject
      @redmineUser = rmUser
      @respObj = nil
    end
  
    # Makes a put request to a given resource path
    # @param [String] rsrcPath resource path
    # @param [String] payload is json string
    # @param [Hash] fieldMap keys mapping to the fields in the rsrcPath
    # @return [Hash] retVal the response object containing :respObj and :status as keys
    def apiPut(rsrcPath, payload, fieldMap={})
      retVal = { :respObj => '', :status => 500}
      # Add standard field info to fieldMap IFF not provided
      gbAuthHelper = GbApi::GbAuthHelper.new()
      login, pass = gbAuthHelper.authPairForUserAndHostInProjContext(@redmineProject, @reqHost, @redmineUser)
      if(login and pass)
        apiCaller = BRL::REST::ApiCaller.new(@reqHost, rsrcPath, login, pass)
        apiCaller.put( fieldMap, payload )
        # Parse response
        parseOk = apiCaller.parseRespBody() rescue nil
        # Expose response
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "API PUT SUCCESS? #{apiCaller.succeeded?.inspect} (hr: #{apiCaller.httpResponse}) ; resp body:\n\n#{apiCaller.respBody}")
        unless(apiCaller.succeeded? and parseOk)
          @respObj =
          {
            'data'    => nil,
            'status'  => ( parseOk ? apiCaller.apiStatusObj : { 'statusCode' => apiCaller.httpResponse.message, 'msg' => apiCaller.httpResponse.message } )
          }
          @httpResponse = @respObj['status']['msg']
        else
          @respObj = apiCaller.apiRespObj
          @httpResponse = @respObj['status']['msg']
        end
        retVal[:respObj]  = @respObj
        retVal[:status]   = apiCaller.httpResponse.code.to_i == 201 ? 200 : apiCaller.httpResponse.code.to_i # 201 causes the respond_to method to slow down considerably
      else
        retVal[:respObj] = {'data' => nil, 'status' => {'statusCode' => 400, 'msg' => 'ERROR: Current Redmine user does not seem to be registered with Genboree. Are they a locally-registered Redmine user? That is NOT supported, ONLY Genboree users are supported. Or perhaps the session has timed out.'}}
        retVal[:status] = 400
      end
      return retVal
    end

 end
end
