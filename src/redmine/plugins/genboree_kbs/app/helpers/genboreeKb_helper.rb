require 'em-http-request'
require 'brl/util/util'
require 'brl/db/dbrc'
require 'plugins/genboree_kbs/app/helpers/host_auth_map_helper'
require 'plugins/genboree_kbs/app/helpers/multi_part_data_extractor'
require 'plugins/genboree_kbs/app/helpers/db_connect'
require 'plugins/genboree_kbs/app/helpers/em_helpers'

module GenboreeKbHelper
  
  BOUNDARY_EXTRACTOR = /boundary\s*=\s*([^; \t\n]+)/
  
  def getUserInfo(gbKbHost)
    gbAuthHost = getGbAuthHostName()
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "gbAuthHost: #{gbAuthHost.inspect}")
    dbconn = getDbConn(gbAuthHost)
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "dbconn: #{dbconn.inspect}")
    login = User.current.login
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "login: #{login.inspect}")
    retVal = dbconn.getUserByName(login)
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "retVal: #{retVal.inspect}")
    @project = Project.find(params['project_id'])
    #$stderr.puts "@project: #{@project.inspect}\n login: #{login.inspect}\n retVal: #{retVal.inspect}"
    if(!retVal.nil? and !retVal.empty? and User.current.member_of?(@project))
      userInfo = GenboreeKbHelper::HostAuthMapHelper.getHostAuthMapForUserAndHostName(retVal, gbKbHost, gbAuthHost, dbconn)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "userInfo: #{userInfo.inspect}")
      retVal = userInfo
    else
      if(@project.is_public == true)
        retVal = [:anon, :anon]
      else
        retVal =  [ nil, nil ]
      end
    end
    return retVal
  end

  # Host name of the Genboree instance providing authorization service
  # for this Redmine.
  def getGbAuthHostName()
    retVal = nil
    gbAuthSrcs = AuthSourceGenboree.where( :name => "Genboree" )
    if(gbAuthSrcs and !gbAuthSrcs.empty?)
      gbAuthSrc = gbAuthSrcs.first
      retVal = gbAuthSrc.host
    end
    return retVal
  end

  def getDbConn(gbAuthHost=nil)
    gbAuthHost = getGbAuthHostName() unless(gbAuthHost)
    dbKey = "DB:#{gbAuthHost}"
    $stderr.puts "dbKey: #{dbKey.inspect}"
    dbconn = GenboreeKbHelper::DbConnect.new(dbKey)
    return dbconn
  end

  def getHost()
    @project = Project.find(params['project_id'])
    @genboreeKb = GenboreeKb.find_by_project_id(@project)
    return @genboreeKb.gbHost
  end

  def getGroup()
    @project = Project.find(params['project_id'])
    @genboreeKb = GenboreeKb.find_by_project_id(@project)
    return @genboreeKb.gbGroup.strip
  end

  # ------------------------------------------------------------------
  # API Helpers
  # ------------------------------------------------------------------
  def apiGet(rsrcPath, fieldMap={}, jsonResp=true, gbHost=nil, payload=nil)
    $stderr.debugPuts(__FILE__, __method__, '!!!!! DEPRECATED - BLOCKING API CALL !!!!!', " - This and the calling code needs to be refactored to non-blocking/async call")
    # Maintain & return a hash of useful fields. We'll pass the needed onces (like :status, :location, etc) to Rails methods as needed.
    retVal = { :respObj => nil, :status => 500 }
    @respObj = nil
    # Get typical generic info
    @project = Project.find(params['project_id'])
    @genboreeKb = GenboreeKb.find_by_project_id(@project)
    if(@genboreeKb)
      @gbGroup = @genboreeKb.gbGroup.strip
      @gbHost = gbHost ? gbHost : @genboreeKb.gbHost.strip
      # Add standard field info to fieldMap IFF not provided
      fieldMap[:grp]  = @gbGroup unless(fieldMap[:grp].to_s =~ /\S/)
      fieldMap[:kb]   = @genboreeKb.name.strip unless(fieldMap[:kb].to_s =~ /\S/)
      login, pass = getUserInfo(@gbHost)
      if(login and pass)
        # Make call, using fieldMap
        apiCaller = nil
        uri = nil
        if(login == :anon)
          apiCaller = ApiCaller.new(@gbHost, rsrcPath)
          uri = apiCaller.makeFullApiUri(fieldMap, false)
        else
          apiCaller = ApiCaller.new(@gbHost, rsrcPath, login, pass)
          uri = apiCaller.makeFullApiUri(fieldMap)
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "About to get doc")
        if(payload.nil?)
          apiCaller.get( fieldMap )
        else
          apiCaller.get(fieldMap, payload.to_json)
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Got doc.")
        # Parse response
        parseOk = apiCaller.parseRespBody() rescue nil
        unless(apiCaller.succeeded? and parseOk)
          @respObj =
          {
            'data'    => nil,
            'status'  => ( parseOk ? apiCaller.apiStatusObj : { 'statusCode' => apiCaller.httpResponse.message, 'msg' => apiCaller.httpResponse.message } )
          }
          @httpResponse = @respObj['status']['msg']
        else
          if(jsonResp)
            
            @respObj = apiCaller.apiRespObj
            @httpResponse = @respObj['status']['msg'] ?  @respObj['status']['msg'] : ""
            @relatedJobIds = @respObj['status']['relatedJobIds']
          else
            @respObj = apiCaller.respBody
            @httpResponse = ""
          end
        end
        retVal[:respObj]  = @respObj
        retVal[:status]   = apiCaller.httpResponse.code.to_i
      else
        if(User.current.member_of?(@project))
          @httpResponse = "ERROR: Current Redmine user does not seem to be registered with Genboree. Are they a locally-registered Redmine user? That is NOT supported, ONLY Genboree users are supported. Or perhaps the session has timed out."
          @gbGroup = @gbHost = ""
        else
          @httpResponse = "ERROR: Current Redmine user is not a member of the private Redmine project containg this GenboreeKB. "
          @gbGroup = @gbHost = ""
        end
      end
    else
      @httpResponse = "ERROR: No GenboreeKB configured & associated with this Redmine Project. Speak to a project admin to have it [re]set-up."
    end
    retVal[:msg] = @httpResponse
    return retVal
  end
  
  def asyncGet(env, rsrcPath, fieldMap={}, wrapInData=false, gbHost=nil)
    # Get typical generic info
    @project = Project.find(params['project_id'])
    @genboreeKb = GenboreeKb.find_by_project_id(@project)
    @gbGroup = @genboreeKb.gbGroup.strip
    @gbHost = gbHost ? gbHost : @genboreeKb.gbHost.strip
    # Add standard field info to fieldMap IFF not provided
    fieldMap[:grp]  = @gbGroup unless(fieldMap[:grp].to_s =~ /\S/)
    fieldMap[:kb]   = @genboreeKb.name.strip unless(fieldMap[:kb].to_s =~ /\S/)
    login, pass = getUserInfo(@gbHost)
    $stderr.puts "API GET:\n  rsrcPath: #{rsrcPath.inspect}"
    $stderr.puts "API GET:\n  fieldMap: #{fieldMap.inspect}"
    apiCaller = ApiCaller.new(@gbHost, rsrcPath)
    uri = nil
    if(login == :anon)
      apiCaller = ApiCaller.new(@gbHost, rsrcPath)
      uri = apiCaller.makeFullApiUri(fieldMap, false)
    else
      apiCaller = ApiCaller.new(@gbHost, rsrcPath, login, pass)
      uri = apiCaller.makeFullApiUri(fieldMap)
    end
    asyncHeader = {}
    asyncHeader['Content-Type'] = "text/plain"
    asyncResp = GenboreeKbHelper::EMHTTPAsyncResp.new(env, 200, asyncHeader, uri)
    asyncResp.wrapInData = wrapInData
    asyncResp.collateResponse = true
    EM.next_tick do
      asyncResp.start()
    end
    throw :async
  end
  
  def asyncPut(env, rsrcPath, fieldMap={}, gbHost=nil)
    # Get typical generic info
    @project = Project.find(params['project_id'])
    @genboreeKb = GenboreeKb.find_by_project_id(@project)
    @gbGroup = @genboreeKb.gbGroup.strip
    @gbHost = gbHost ? gbHost : @genboreeKb.gbHost.strip
    # Add standard field info to fieldMap IFF not provided
    fieldMap[:grp]  = @gbGroup unless(fieldMap[:grp].to_s =~ /\S/)
    fieldMap[:kb]   = @genboreeKb.name.strip unless(fieldMap[:kb].to_s =~ /\S/)
    login, pass = getUserInfo(@gbHost)
    $stderr.puts "API GET:\n  rsrcPath: #{rsrcPath.inspect}"
    $stderr.puts "API GET:\n  fieldMap: #{fieldMap.inspect}"
    apiCaller = ApiCaller.new(@gbHost, rsrcPath)
    uri = nil
    if(login == :anon)
      apiCaller = ApiCaller.new(@gbHost, rsrcPath)
      uri = apiCaller.makeFullApiUri(fieldMap, false)
    else
      apiCaller = ApiCaller.new(@gbHost, rsrcPath, login, pass)
      uri = apiCaller.makeFullApiUri(fieldMap)
    end
    asyncHeader = {}
    asyncHeader['Content-Type'] = "text/plain"
    asyncResp = GenboreeKbHelper::EMHTTPAsyncResp.new(env, 200, asyncHeader, uri)
    asyncResp.collateResponse = true
    EM.next_tick do
      asyncResp.start('put')
    end
    throw :async
  end

  def apiPut(rsrcPath, payload, fieldMap={})
    # Maintain & return a hash of useful fields. We'll pass the needed onces (like :status, :location, etc) to Rails methods as needed.
    retVal = { :respObj => '', :status => 500 }
    @respObj = nil
    # Get typical generic info
    @project = Project.find(params['project_id'])
    @genboreeKb = GenboreeKb.find_by_project_id(@project)
    if(@genboreeKb)
      @gbGroup = @genboreeKb.gbGroup.strip
      @gbHost = @genboreeKb.gbHost.strip
      # Add standard field info to fieldMap IFF not provided
      fieldMap[:grp]  = @gbGroup unless(fieldMap[:grp].to_s =~ /\S/)
      fieldMap[:kb]   = @genboreeKb.name.strip unless(fieldMap[:kb].to_s =~ /\S/)
      login, pass = getUserInfo(@gbHost)
      if(login and pass)
        # Make call, using fieldMap
        $stderr.puts "API PUT:\n  rsrcPath: #{rsrcPath.inspect}"
        $stderr.puts "API PUT:\n  fieldMap: #{fieldMap.inspect}"
        apiCaller = ApiCaller.new(@gbHost, rsrcPath, login, pass)
        apiCaller.put( fieldMap, payload )
        # Parse response
        parseOk = apiCaller.parseRespBody() rescue nil
        # Expose response
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "API PUT SUCCESS? #{apiCaller.succeeded?.inspect} (hr: #{apiCaller.httpResponse}) ; resp body:\n\n#{apiCaller.respBody}")
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
          @relatedJobIds = @respObj['status']['relatedJobIds']
        end
        #@respObj['data'] = {}
        retVal[:respObj]  = @respObj
        retVal[:status]   = apiCaller.httpResponse.code.to_i == 201 ? 200 : apiCaller.httpResponse.code.to_i # 201 causes the respond_to method to slow down considerably
      else
        @httpResponse = "ERROR: Current Redmine user does not seem to be registered with Genboree. Are they a locally-registered Redmine user? That is NOT supported, ONLY Genboree users are supported. Or perhaps the session has timed out."
        @gbGroup = @gbHost = ""
      end
    else
      @httpResponse = "ERROR: No GenboreeKB configured & associated with this Redmine Project. Speak to a project admin to have it [re]set-up."
    end
    retVal[:msg] = @httpResponse
    return retVal
  end

  def getApiCaller(rsrcPath, fieldMap={})
    retVal = { :respObj => "Error encountered while constructing the Api Caller", :status => 500 }
    # Get typical generic info
    @project = Project.find(params['project_id'])
    @genboreeKb = GenboreeKb.find_by_project_id(@project)
    if(@genboreeKb)
      @gbGroup = @genboreeKb.gbGroup.strip
      @gbHost = @genboreeKb.gbHost.strip
      # Add standard field info to fieldMap IFF not provided
      fieldMap[:grp]  = @gbGroup unless(fieldMap[:grp].to_s =~ /\S/)
      fieldMap[:kb]   = @genboreeKb.name.strip unless(fieldMap[:kb].to_s =~ /\S/)
      login, pass = getUserInfo(@gbHost)
      if(login and pass)
        $stderr.puts "API GET:\n  rsrcPath: #{rsrcPath.inspect}"
        $stderr.puts "API GET:\n  fieldMap: #{fieldMap.inspect}"
        if(login == :anon)
          retVal = ApiCaller.new(@gbHost, rsrcPath)
        else
          retVal = ApiCaller.new(@gbHost, rsrcPath, login, pass)
        end
      end
    end
    return retVal
  end
  
  def returnFullApiUrl(rsrcPath, fieldMap)
    retVal = nil
    # Get typical generic info
    @project = Project.find(params['project_id'])
    @genboreeKb = GenboreeKb.find_by_project_id(@project)
    @gbGroup = @genboreeKb.gbGroup.strip
    @gbHost =  @genboreeKb.gbHost.strip
    # Add standard field info to fieldMap IFF not provided
    fieldMap[:grp]  = @gbGroup unless(fieldMap[:grp].to_s =~ /\S/)
    fieldMap[:kb]   = @genboreeKb.name.strip unless(fieldMap[:kb].to_s =~ /\S/)
    login, pass = getUserInfo(@gbHost)
    apiCaller = nil
    if(login == :anon)
      apiCaller = ApiCaller.new(@gbHost, rsrcPath)
      retVal = apiCaller.makeFullApiUri(fieldMap, false)
    else
      apiCaller = ApiCaller.new(@gbHost, rsrcPath, login, pass)
      retVal = apiCaller.makeFullApiUri(fieldMap)
    end
    return retVal
  end

  def apiDelete(rsrcPath, fieldMap={})
    # Maintain & return a hash of useful fields. We'll pass the needed onces (like :status, :location, etc) to Rails methods as needed.
    retVal = { :respObj => '', :status => 500 }
    @respObj = nil
    # Get typical generic info
    @project = Project.find(params['project_id'])
    @genboreeKb = GenboreeKb.find_by_project_id(@project)
    if(@genboreeKb)
      @gbGroup = @genboreeKb.gbGroup.strip
      @gbHost = @genboreeKb.gbHost.strip
      # Add standard field info to fieldMap IFF not provided
      fieldMap[:grp]  = @gbGroup unless(fieldMap[:grp].to_s =~ /\S/)
      fieldMap[:kb]   = @genboreeKb.name.strip unless(fieldMap[:kb].to_s =~ /\S/)
      login, pass = getUserInfo(@gbHost)
      if(login and pass)
        # Make call, using fieldMap
        $stderr.puts "API DELETE:\n  rsrcPath: #{rsrcPath.inspect}"
        $stderr.puts "API DELETE:\n  fieldMap: #{fieldMap.inspect}"
        apiCaller = ApiCaller.new(@gbHost, rsrcPath, login, pass)
        apiCaller.delete( fieldMap )
        # Parse response
        parseOk = apiCaller.parseRespBody() rescue nil
        # Expose response
$stderr.debugPuts(__FILE__, __method__, "DEBUG", "API DELETE SUCCESS? #{apiCaller.succeeded?.inspect} (hr: #{apiCaller.httpResponse}) ; resp body:\n\n#{apiCaller.respBody}")
        unless(apiCaller.succeeded? and parseOk)
          @respObj =
          {
            'data'    => nil,
            'status'  => ( parseOk ? apiCaller.apiStatusObj : { 'statusCode' => apiCaller.httpResponse.message, 'msg' => apiCaller.httpResponse.message } )
          }
          @httpResponse = @respObj['status']['msg']
        else
          @respObj = apiCaller.apiRespObj
          #@respObj['data'] = {}
          @httpResponse = @respObj['status']['msg']
        end
        retVal[:respObj]  = @respObj
        retVal[:status]   = apiCaller.httpResponse.code.to_i
      else
        @httpResponse = "ERROR: Current Redmine user does not seem to be registered with Genboree. Are they a locally-registered Redmine user? That is NOT supported, ONLY Genboree users are supported. Or perhaps the session has timed out."
        @gbGroup = @gbHost = ""
      end
    else
      @httpResponse = "ERROR: No GenboreeKB configured & associated with this Redmine Project. Speak to a project admin to have it [re]set-up."
    end
    retVal[:msg] = @httpResponse
    return retVal
  end


  
  
  
end
