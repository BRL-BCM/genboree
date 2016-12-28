require 'mysql2'
require 'brl/util/util'
require 'brl/db/dbrc'
require 'brl/cache/helpers/domainAliasCacheHelper'
require 'brl/cache/helpers/dnsCacheHelper'
require 'em-http-request'


module GenboreeKbHelper

  def getUserInfo(gbKbHost)
    #dbKey = (gbHost == '10.15.5.109' ? "DB:10.15.5.109" : "DB:taurine.brl.bcmd.bcm.edu")
    gbAuthHost = getGbAuthHostName()
    dbconn = getDbConn(gbAuthHost)
    login = User.current.login
    retVal = dbconn.getUserByName(login)
    @project = Project.find(params['project_id'])
    #$stderr.puts "@project: #{@project.inspect}\n login: #{login.inspect}\n retVal: #{retVal.inspect}"
    if(!retVal.nil? and !retVal.empty? and User.current.member_of?(@project))
      userInfo = GenboreeKbHelper::HostAuthMapHelper.getHostAuthMapForUserAndHostName(retVal, gbKbHost, gbAuthHost, dbconn)
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
  def apiGet(rsrcPath, fieldMap={}, jsonResp=true, gbHost=nil)
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
      $stderr.puts "login: #{login.inspect}"
      if(login and pass)
        # Make call, using fieldMap
        $stderr.puts "API GET:\n  rsrcPath: #{rsrcPath.inspect}"
        $stderr.puts "API GET:\n  fieldMap: #{fieldMap.inspect}"
        apiCaller = nil
        if(login == :anon)
          apiCaller = ApiCaller.new(@gbHost, rsrcPath)
        else
          apiCaller = ApiCaller.new(@gbHost, rsrcPath, login, pass)
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "About to get doc")
        apiCaller.get( fieldMap )
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Got doc.")
        # Parse response
        parseOk = apiCaller.parseRespBody() rescue nil
        # Expose response
#$stderr.debugPuts(__FILE__, __method__, "DEBUG", "API GET SUCCESS? #{apiCaller.succeeded?.inspect} (hr: #{apiCaller.httpResponse}) ; resp body:\n\n#{apiCaller.respBody}")
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

  class KbApiCaller

  end

  class HostAuthMapHelper
    include BRL::Cache::Helpers::DomainAliasCacheHelper
    include BRL::Cache::Helpers::DNSCacheHelper

    # Get user auth for Genboree hosting the GenboreeKB data
    def self.getHostAuthMapForUserAndHostName(localUserRecs, gbKbHost, gbAuthHost, dbconn)
      retVal = {}
      userInfo = [nil, nil]
      localUserRec = localUserRecs.first
      userId = localUserRec['userId']
      # Is gbKbHost same as genboree auth host backing Redmine?
      canonGbAuthHost = self.canonicalAddress(gbAuthHost)
      canonGbAuthHostAlias = self.getDomainAlias(canonGbAuthHost, :canonicalIps)
      gbKbHostCanonical = self.canonicalAddress(gbKbHost)
      gbKbHostCanonicalAlias = self.getDomainAlias(gbKbHostCanonical, :canonicalIps)
      if( (canonGbAuthHost == gbKbHostCanonical) or
          (canonGbAuthHost == gbKbHostCanonicalAlias) or
          (canonGbAuthHostAlias == gbKbHostCanonical) or
          (canonGbAuthHostAlias == gbKbHostCanonicalAlias))
        userInfo[0] = localUserRec['name']
        userInfo[1] = localUserRec['password']
      else # Must be remote ... need query external host access
        externalHostAccessRecs = dbconn.getAllExternalHostInfoByUserId(userId)
        externalHostAccessRecs.each { |rec|
          remoteHost = rec['host']
          canonicalAddress = self.canonicalAddress(remoteHost)
          # Do we know of an *alias* for this remote host?
          canonicalAlias = self.getDomainAlias(canonicalAddress, :canonicalIps)
          if( (canonicalAddress == gbKbHostCanonical) or
              (canonicalAddress == gbKbHostCanonicalAlias) or
              (canonicalAlias == gbKbHostCanonical) or
              (canonicalAlias == gbKbHostCanonicalAlias))
            userInfo[0] = rec['login']
            userInfo[1] = rec['password']
            break
          end
        }
      end
      return userInfo
    end
  end
  
  
  
  
  class EMHTTPStreamer
    
    attr_accessor :body, :http, :url
    
    def initialize(url=nil, body=nil)
      @url = url
      @body = body
      @http = nil
    end
    
    def initEMHttpRequest()
      @http = EventMachine::HttpRequest.new(@url, :connect_timeout => 10, :inactivity_timeout => 60).get
      @http.callback {
        @body.succeed
        $stderr.debugPuts(__FILE__, __method__,  "DOWNLOAD-COMPLETE", "url: #{@url}" )
      }
      @http.errback { $stderr.debugPuts(__FILE__, __method__, "DOWNLOAD-FAILED", "url: #{@url}\n\n#{@http.error.inspect}" ) }
    end
  end
  
  
  class EMHTTPDeferrableBody
   
    include EventMachine::Deferrable
    attr_accessor :streamer, :call_dequeue
    
    def initialize
      @streamer = nil
      @call_dequeue = true
    end
    
   
    def each(&blk)
      @body_callback = blk
      if(@call_dequeue)
        schedule_dequeue 
      else
        @body_callback.call("{ 'success' :true }") # This response object is required by ExtJS to perceive the upload as a success
      end
    end

    private
      def schedule_dequeue
        return unless @body_callback
        http = @streamer.http
        http.stream { |chunk|
          @body_callback.call(chunk)
        }
      end
  end
  
  
  
  
  class EMHTTPAsyncResp
    

    attr_reader :headers, :callback, :status
    attr_accessor :uploadFilePath, :kb, :coll, :grp, :host, :db, :genbFilePath, :format, :apiCaller

    # Creates a instance and yields it to the block given
    # returns the async marker
    def self.perform(*args, &block)
      new(*args, &block).finish
    end

    def initialize(env, status, headers, fullApiUrl)
      @callback = env['async.callback']
      @close = env['async.close']
      @body = GenboreeKbHelper::EMHTTPDeferrableBody.new
      @streamer = GenboreeKbHelper::EMHTTPStreamer.new
      @streamer.url = fullApiUrl
      @streamer.body = @body
      @fullApiUrl = fullApiUrl
      @body.streamer = @streamer
      @uploadFilePath = nil
      @status = status
      @headers = headers
      @headers_sent = false
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
    def start(reqType='download', submitTool=true)
      if reqType == 'download'
        @streamer.initEMHttpRequest()
        $stderr.debugPuts(__FILE__, __method__, "DOWNLOAD-START", "url: #{@streamer.url}" )
        send_headers
      else # upload
        # send headers and close response AND THEN start uploading file to genboree
        @body.call_dequeue = false
        send_headers
        done
        callback {
          uploadFile(submitTool)
        }
      end
    end
    
    def uploadFile(submitTool)
      $stderr.debugPuts(__FILE__, __method__, "UPLOAD-START", "url: #{@fullApiUrl}" )
      http = EventMachine::HttpRequest.new(@fullApiUrl, :connect_timeout => 10, :inactivity_timeout => 60).put :file => @uploadFilePath
      http.callback { |chunk|
        $stderr.debugPuts(__FILE__, __method__, "UPLOAD-COMPLETE", "url: #{@fullApiUrl}" )
        scheduleKbBulkUploader(http.response) if(submitTool)
      }
      http.errback { $stderr.debugPuts(__FILE__, __method__, "UPLOAD-FAILED", "url: #{@fullApiUrl}\nResponse: #{http.response}" ) }
    end
    
    # Schedules a "KB Bulk Upload" job after the file has finished uploading
    #   - Scans response to see if the file was uploaded immediately or as a deferred upload job.
    #   - If relatedJobId is present in the response, the file was accepted as a deferred upload job and we will submit a conditional job.
    def scheduleKbBulkUploader(response)
      respObj = JSON.parse(response)
      rsrcPath = "/REST/v1/genboree/tool/kbBulkUpload/job"
      inputUrl = "http://#{@host}/REST/v1/grp/#{CGI.escape(@grp)}/db/#{CGI.escape(@db)}/file/#{@genbFilePath}?"
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
  
  
  

  class DbConnect
    MAX_RETRIES = 5
    attr_accessor :dbrc

    def initialize(dbrcKey)
      dbrcFile = ENV['DBRC_FILE'].dup
      @dbrc = BRL::DB::DBRC.new(dbrcFile.untaint, dbrcKey)
      @dbrc.user = @dbrc.user.dup.untaint
      @dbrc.password = @dbrc.password.dup.untaint
    end

    def getMysql2Client()
      maxRetries = MAX_RETRIES
      driver = @dbrc.driver
      driverFields = driver.dup.split(/:/)
      thirdField = driverFields[2]
      client = nil
      dbName = nil
      # Get params for making client.
      socket = host = nil
      if(thirdField =~ /host\s*=\s*([^ \t\n:;]+)/)
        host = $1
      elsif(thirdField =~ /socket\s*=\s*([^ \t\n:;]+)/)
        socket = $1
      elsif(driverFields.size >= 4) #  old-style driver string
        host = driverFields[3]
      else
        raise "ERROR: #{driver.inspect} does not appear to be correct. Should be either a 3-field driver string, which host or socket parameter in the 3rd field OR an old-style 4-field driver string with the host in the 4th field."
      end
      if(thirdField =~ /database\s*=\s*([^ \t\n:;]+)/)
        dbName = $1
      else
        dbName = thirdField
      end
      # Try to create client which will establish connection to mysql server
      lastConnErr = nil # The last Exception thrown during the creation attempt.
      connRetries = 0
      loop {
        if(connRetries < MAX_RETRIES)
          connRetries += 1
          begin
            if(host)
              client = Mysql2::Client.new(:host => host, :username => @dbrc.user, :password => @dbrc.password, :database => dbName)
            else
              client = Mysql2::Client.new(:socket => socket, :username => @dbrc.user, :password => @dbrc.password, :database => dbName)
            end
          rescue Exception => lastConnErr
            # Slightly variable progressive sleep.
            sleepTime = ((connRetries / 2.0) + 0.4 + rand())
            # 1-line log msg about this failure
            $stderr.puts "WARNING", "Attempt ##{connRetries} DB connect to #{host ? host.inspect : socket.inspect} failed. Will retry in #{'%.2f' % sleepTime} secs. Maximum total attempts: #{maxRetries}. Exception class and message: #{lastConnErr.class} (#{lastConnErr.message.inspect})."
            sleep(sleepTime)
          end
        else  # Tried many times and still cannot connect. Big problem...
          msg = "ALL #{connRetries} attempts failed to establish DB connection to #{host ? host.inspect : socket.inspect}. Was using these params: maxRetries = #{maxRetries.inspect}, host = #{host.inspect}, socket = #{socket.inspect}, username = #{@dbrc.user.inspect}, database = #{dbName.inspect}, driver = #{driver.inspect}, driverFields = #{driverFields.inspect}, thirdField = #{thirdField.inspect}.\n    Last Attempt's Exception Class: #{lastConnErr ? lastConnErr.class : '[NONE?]'}\n    Last Attempt's Exception Msg: #{lastConnErr ? lastConnErr.message.inspect : '[NONE?]'}\n    Last Attempts's Exception Backtrace:\n#{lastConnErr ? lastConnErr.backtrace.join("\n") : '[NONE?]'}\n\n"
          $stderr.puts "FATAL:\n\n#{msg}"
          raise Exception, msg
        end
        break if(client)
      }
      return client
    end

    def getAllExternalHostInfoByUserId(userId)
      sql = "select * from externalHostAccess where userId = #{userId}"
      client = nil
      retVal = nil
      begin
        client = getMysql2Client()
        recs = client.query(sql)
        retVal = recs.entries
      rescue => err
        $stderr.puts err
      ensure
        client.close
      end
      return retVal
    end

    def getUserByName(name)
      sql = "select * from genboreeuser where name = '#{Mysql2::Client.escape(name)}'"
      client = nil
      retVal = nil
      begin
        client = getMysql2Client()
        recs = client.query(sql)
        retVal = recs.entries
      rescue => err
        $stderr.puts err
      ensure
        client.close
      end
      return retVal
    end

    def getAllUsers()
      sql = "select * from genboreeuser "
      client = nil
      retVal = nil
      begin
        client = getMysql2Client()
        recs = client.query(sql)
        retVal = recs.entries
      rescue => err
        $stderr.puts err
      ensure
        client.close
      end
      return retVal
    end
  end
  
  
  ############# Reference (Defunct) classes###################
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
  
  class Streamer
    
    attr_accessor :fileHandle, :body, :apiCaller, :fieldMap
    
    def initialize(apiCaller=nil, fieldMap=nil)
      @apiCaller = apiCaller
      @fieldMap = fieldMap
      @url = "http://www.google.com"
    end
    
    def getChunk()
      return @fileHandle.read(1024)
    end
    
    def closeStream()
      @fileHandle.close()
    end

  end
  
end
