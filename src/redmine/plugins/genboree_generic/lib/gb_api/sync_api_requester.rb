require 'brl/rest/apiCaller'
module GbApi
 
  # Api requester that performs sync requests.
  # - WHY ARE YOU DOING sync REQUESTS? Should have good / clear reasoning.
  class SyncApiRequester
    attr_reader :lastUri, :respObj, :httpResponse
    attr_accessor :redmineUser, :redmineProject, :gbAuthHelper
    attr_accessor :reqHost

    def initialize( rackEnv, targetHost, rmProject, rmUser=rackEnv[:currRmUser])
      @rackEnv = rackEnv
      @reqHost = targetHost
      @redmineProject = rmProject
      @redmineUser = rmUser
      @respObj = nil
      @lastUri = nil
      @gbAuthHelper = nil
    end

    # Makes a GET request to a given resource path
    # @note WHY ARE YOU DOING sync REQUESTS? Should have good / clear reasoning.
    # @param [String] rsrcPath resource path
    # @param [Hash] fieldMap keys mapping to the fields in the rsrcPath
    # @return [Hash] retVal the response object containing :respObj and :status as keys
    def apiGet(rsrcPath, fieldMap={}, opts={ :parseJson => true, :unwrap => true } )
      #$stderr.debugPuts(__FILE__, __method__, 'TIME', "Time 4A")
      retVal = { :data => nil, :status => 500, :err => nil }
      # Add standard field info to fieldMap IFF not provided
      @gbAuthHelper = GbApi::GbAuthHelper.new( @rackEnv ) unless( @gbAuthHelper )
      if(@redmineProject.nil?)
        login, pass = @gbAuthHelper.authPairForUserAndHost(@reqHost, @redmineUser)
      else
        login, pass = @gbAuthHelper.authPairForUserAndHostInProjContext(@redmineProject, @reqHost, @redmineUser)
      end
      if(login and pass)
        apiCaller = BRL::REST::ApiCaller.new(@reqHost, rsrcPath, login, pass)

        #$stderr.debugPuts(__FILE__, __method__, 'TIME', "Time 4A.1")
        apiCaller.get( fieldMap )
        #$stderr.debugPuts(__FILE__, __method__, 'TIME', "Time 4A.2")
        @lastUri = apiCaller.fullApiUri
        if( opts[:parseJson] )
          # Parse response
          #$stderr.debugPuts(__FILE__, __method__, 'TIME', "Time 4B")
          parseOk = apiCaller.parseRespBody() rescue nil

          #$stderr.debugPuts(__FILE__, __method__, 'TIME', "Time 4C")
          if( parseOk and !parseOk.is_a?(Exception) )
            if( opts[:unwrap] )
              # Dig out 'data' and 'status' components for presenting
              retVal[:data] = apiCaller.apiDataObj
              retVal[:status] = apiCaller.apiStatusObj
            else
              # Present whole parsed payload in :data and determine :status ourselves
              retVal[:data] = apiCaller.apiRespObj
              retVal[:status] = apiCaller.httpResponse.code.to_i
            end
          else # parse asked and failed
            retVal[:err] = parseOk
          end
        else # no parsing asked
          # Present whole payload in :data as-is  and determine :status ourselves
          retVal[:data] = apiCaller.respBody
          retVal[:status] = apiCaller.httpResponse.code.to_i
        end

        @respObj = retVal
        @httpResponse = apiCaller.httpResponse
      else
        retVal[:data] = { 'data' => nil, 'status' => {'statusCode' => 400, 'msg' => 'ERROR: Current Redmine user does not seem to be registered with Genboree. Are they a locally-registered Redmine user? That is NOT supported, ONLY Genboree users are supported. Or perhaps the session has timed out.' } }
        retVal[:status] = 400
      end

      #$stderr.debugPuts(__FILE__, __method__, 'TIME', "Time 4D")
      return retVal
    end

    # Makes a put request to a given resource path
    # @note WHY ARE YOU DOING sync REQUESTS? Should have good / clear reasoning.
    # @param [String] rsrcPath resource path
    # @param [String] payload is json string
    # @param [Hash] fieldMap keys mapping to the fields in the rsrcPath
    # @return [Hash] retVal the response object containing :respObj and :status as keys
    def apiPut(rsrcPath, payload, fieldMap={})
      retVal = { :respObj => '', :status => 500}
      # Add standard field info to fieldMap IFF not provided
      @gbAuthHelper = GbApi::GbAuthHelper.new( @rackEnv ) unless( @gbAuthHelper )
      if(@redmineProject.nil?)
       login, pass = @gbAuthHelper.authPairForUserAndHost(@reqHost, @redmineUser)
      else
        login, pass = @gbAuthHelper.authPairForUserAndHostInProjContext(@redmineProject, @reqHost, @redmineUser)
      end
      if(login and pass)
        apiCaller = BRL::REST::ApiCaller.new(@reqHost, rsrcPath, login, pass)
        apiCaller.put( fieldMap, payload )
        # Parse response
        parseOk = apiCaller.parseRespBody() rescue nil
        # Expose response
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
