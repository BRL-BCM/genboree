require 'uri'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/rest/helpers/apiUriHelper'
require 'brl/genboree/rest/data/roleEntity'
require 'brl/genboree/rest/apiCaller'
require 'brl/cache/helpers/dnsCacheHelper'
require 'brl/cache/helpers/domainAliasCacheHelper'

module BRL ; module Genboree ; module REST ; module Helpers
  class GroupApiUriHelper < ApiUriHelper

    include BRL::Cache::Helpers::DomainAliasCacheHelper::CacheClassMethods
    include BRL::Cache::Helpers::DNSCacheHelper::CacheClassMethods
    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------
    # Each resource specific API Uri Helper subclass should redefine this:
    NAME_EXTRACTOR_REGEXP = %r{^(?:http://[^/]+)?/REST/v\d+/grp/([^/\?]+)}
    EXTRACT_SELF_URI = %r{^(.+?/grp/[^/\?]+)}     # To get just this resource's portion of the URL, with any suffix stripped off
    ID_COLUMN_NAME = 'groupId'


    # Does user have access to grp?
    # - Old implementation uses DbUtil and thus can only answer for usergroups
    #   in the local Genboree instance.
    # - This has be re-implemented to work across multiple Genboree instances
    #   via API.
    # [+uri+] A Genboree API URI, mentioning group. (if no grp element, this method will return false...)
    # [+userId+] Id of the user in the local Genboree instance.
    # [+accessCodes+] An Array of access codes (r, w, o), any one of which is sufficent for access.
    # [+hostAuthMap+] Optional. An already-filled Hash of canonical address of hostName to 3-column Array record with login & password & hostType
    #                 (:internal | :external) for that host. If not provided, it will have to be retrieved, so it can
    #                 save time to provide this if it is available (often is).
    def accessibleByUser?(uri, userId, accessCodes, hostAuthMap=nil)
      retVal = nil
      roleEntity = userPermHash = nil
      if(uri and userId and accessCodes)
        accessCodes = accessCodes.map { |xx| xx.to_s }
        userId = userId.to_i
        # First, try from cache. Cache value at :accessCodes is a Hash keyed by userId
        # pointing to a Hash of permissions/accessCodes (r, w, o) whose values are true or false.
        userPermHashes = getCacheEntry(uri, :accessCodes)
        userPermHash = (userPermHashes.nil? ? nil : userPermHashes[userId])
        unless(userPermHash) # not in cache for this user + host + uri, we have to get manually
          # 1. Need hostAuthMap for this user from the local Genboree instance, so we can do ApiCaller stuff
          hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, userId) unless(hostAuthMap)
          # 2.a Get host in uri
          host = extractHost(uri)
          if(host)
            # 2.b Get group resource path from uri
            rsrcPath = extractPath(uri)
            if(rsrcPath)
              # 2.c Build path for in group role
              # - path
              rolePath = "#{rsrcPath}/usr/{loginForHost}/role"
              # - gbKey?
              urisGbKey = extractGbKey(uri)
              if(urisGbKey)
                rolePath = "#{rolePath}?gbKey=#{urisGbKey}"
              end
              apiCaller = BRL::Genboree::REST::ApiCaller.new(host, rolePath, hostAuthMap)
              apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              # 2.d Get login for the Genboree host in URI
              authRec = Abstraction::User.getAuthRecForUserAtHost(host, hostAuthMap, @genbConf)
              login = (authRec.nil? ? nil : authRec[0])
              if(login)
                # 3. Do API call
                httpResp = apiCaller.get( { :loginForHost => login } )
                if(apiCaller.succeeded?)
                  # 4. Parse result
                  begin
                    resp = apiCaller.parseRespBody()
                    roleEntity = BRL::Genboree::REST::Data::RoleEntity.from_json(apiCaller.apiDataObj)
                    userPermHash = Abstraction::User::PERMISSIONS_TO_ROLES[roleEntity.role]
                  rescue => err
                    $stderr.debugPuts(__FILE__, __method__, "ERROR", "Parsing role response for user #{login.inspect} at Genboree host #{host.inspect} raised exception.\nMessage: #{err.message}\nBacktrace:\n#{err.backtrace.join("\n")}")
                  end
                else
                  $stderr.debugPuts(__FILE__, __method__, "NOTE", "Could not get role for user #{login.inspect} at Genboree host #{host.inspect}. Received a #{httpResp.class}. Resp Body:\n#{apiCaller.respBody rescue nil}\n\n")
                end
              else
                $stderr.debugPuts(__FILE__, __method__, "NOTE", "Could not get authRec using hostMap. Host: #{host.inspect} ; hostAuthMap: #{hostAuthMap.inspect} ; genbConf: #{@genbConf.inspect}. Received a #{httpResp.class}. Resp Body:\n#{apiCaller.respBody.inspect rescue nil}\n\n")
              end
            end
          end
          # Save the permissions hash we found, if any, into the cache
          if(userPermHash)
            userPermHashes = setCacheEntry(uri, :accessCodes, {}) if(userPermHashes.nil?)
            userPermHashes[userId] = userPermHash
          end
        end
        # Check user's access to grp
        if(userPermHash)
          accessCodes.each { |code|
            retVal = userPermHash[code]
            break if(retVal)
          }
        end
      end
      return retVal
    end

    # Does user have access to ALL groups?
    #
    # [+uri+] A Genboree API URI, mentioning group. (if no grp element, this method will return false...)
    # [+userId+] Id of the user in the local Genboree instance.
    # [+accessCodes+] An Array of access codes (r, w, o), any one of which is sufficent for access.
    # [+hostAuthMap+] Optional. An already-filled Hash of canonical address of hostName to 3-column Array record with login & password & hostType
    #                 (:internal | :external) for that host. If not provided, it will have to be retrieved, so it can
    #                 save time to provide this if it is available (often is).
    def allAccessibleByUser?(uris, userId, accessCodes, hostAuthMap=nil)
      retVal = true
      if(uris and userId and accessCodes)
        hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, userId) unless(hostAuthMap)
        uris.each { |uri|
          unless(accessibleByUser?(uri, userId, accessCodes, hostAuthMap))
            retVal = false
            break
          end
        }
      end
      return retVal
    end

    # Which uris does the user have/not have access to?
    def whichAccessibleToUser(uris, userId, accessCode, hostAuthMap=nil)
      uri2Access = {}
      uris.each{|uri|
        access = accessibleByUser?(uri, userId, [accessCode], hostAuthMap)
        uri2Access[uri] = access
      }
      return uri2Access
    end

    # ------------------------------------------------------------------
    # Feedback helpers
    # ------------------------------------------------------------------
    # Get group => canAccess [boolean] Hash from URIs
    def accessibleGroupsHash(uris, userId, accessCodes)
      accessibleGroupsHash = {}
      if(uris and userId and accessCodes)
        uris.each { |uri|
          # Group name
          name = extractName(uri)
          # Store whether accessible
          accessibleGroupsHash[name] = accessibleByUser?(uri, userId, accessCodes)
        }
      end
      return accessibleGroupsHash
    end

    # @todo BAD! Needs to be replaced, because it requires access via the superuser
    #   accounts at external genboree hosts! Bad! REPLACE with a version that asks if
    #   (a) the gbKey IN the provided uri is available (return that gbKey or nil, say)
    #   (b) the gbKey--which is not provided--is publicly available and what is it please (return retrieved gbKey or nil)
    def getGbKey(uri)
      retVal = nil
      uriObj = URI.parse(uri)
      uriPath = uriObj.path
      host = extractHost(uri)
      grpPath = extractPath(uri)
      if(host and grpPath)
        apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "#{grpPath}/unlockedResources?", @superuserApiDbrc.user, @superuserApiDbrc.password)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody)['data']
        gbKey = nil
        matchLength = -1
        resp.each { |rsrc|
          rsrcUrl = rsrc['url']
          rsrcUrlObj = URI.parse(rsrcUrl)
          sameHost = addressesMatch?(rsrcUrlObj.host, host)
          if(sameHost and uriPath =~ /^(#{rsrcUrlObj.path}).*/) # We want the key for the longest matching one
            if($1.size > matchLength)
              matchLength = $1.size
              gbKey = rsrc['key']
            end
          end
        }
      end
      return gbKey
    end

    # get gbKeys for the uri (if unlocked) and its higher level containers/parents (if they are unlocked)
    # @todo BAD! Needs to be replaced to support external genboree hosts without using superuser
    def getGbKeys(uri)
      retVal = []
      uriObj = URI.parse(uri)
      uriPath = uriObj.path
      host = extractHost(uri)
      grpPath = extractPath(uri)
      if(host and grpPath)
        apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "#{grpPath}/unlockedResources?", @superuserApiDbrc.user, @superuserApiDbrc.password)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody)['data']
        resp.each { |rsrc|
          rsrcUrl = rsrc['url']
          rsrcUrlObj = URI.parse(rsrcUrl)
          sameHost = addressesMatch?(rsrcUrlObj.host, host)
          # append slash to prevent prefix matching of myDb, myDb1, myDb11, ...
          # otherwise gbKey for myDb11 would provide access to myDb
          if(sameHost and (uriPath + "/") =~ /^(#{rsrcUrlObj.path + "/"}).*/)
              retVal << rsrc['key']
          end
        }
      end
      return retVal
    end

     # Is the URL accessible due to its gbKey parameter?
    # - Intended to be used with an ALREADY extracted gbKey
    # - However, if not available and gbKey param is nil, it will try to extract one
    #   from the query string of the URI.
    # [+uri+] The uri String to check for gbKey based access
    # [+reqMethod+] (Optional; default=:get). One of :get, :head, :options, :put, :post, :delete (only first 3 can be done via gbKey)
    # [+gbKey+] (Optional; default=nil, i.e. extract from uri)
    # [+returns+] Either :OK or :Unauthorized. Regardless, @lastStatusMsg will be set to a useful message.
    def gbKeyAccess(uri, reqMethod=:get, gbKey=nil)
      retVal = :Unauthorized
      @lastStatusMsg = "BAD_API_URL: The requested resource cannot be accessed via '#{reqMethod.to_s}' using the gbKey provided.\n  gbKey provided: #{gbKey.inspect}\n  URI: #{uri}"
      if(reqMethod == :get or reqMethod == :head or reqMethod == :options)
        # Parse uri
        uriObj = URI.parse(uri)
        rsrcPath = uriObj.path
        queryString = uriObj.query
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "reqMethod=#{reqMethod.inspect} ; gbKey=#{gbKey.inspect} ; uri: #{uri.inspect} ; rsrcPath = #{rsrcPath.inspect}")
        # Do we have enough to go on?
        if(!rsrcPath.nil? and !rsrcPath.empty?)
          # Find a gbKey value if one to check was not provided as a param
          if(!gbKey)
            if(queryString and queryString =~ /gbKey=([^&#]+)/) # then try to get one from the uri's query string
              gbKey = $1.to_s.strip
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "GB_KEY: found in query string: #{gbKey.inspect}")
            else # try to get ANY public key that covers use for this resource???????
              gbKey = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.getAnyPublicKey(@dbu, rsrcPath)
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "GB_KEY: tried to find discoverable public key, found: #{gbKey.inspect}")
            end
          end
          # Use getGbKey() to get gbKey for uri based on database records
          # IF no getGbKey:
          #   retVal = :'Bad Request'
          #   @lastStatusMsg = "BAD_API_URL: No gbKey available for checking access."
          # IF getGbKey but doesn't match gbKey
          #   retVal = :Unauthorized
          #   @lasStatusMsg = "BAD_KEY: The gbKey provided does not match this resource."
          # else have and match
          #   retVal = :OK
          #  @lastStatusMsg = "OK"
          # return retVal
          extractedGbKeys = getGbKeys(uri)
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "GB_KEY: extractedGbKeys => #{extractedGbKeys.inspect}")
          if(extractedGbKeys.nil? or extractedGbKeys.empty?)
            retVal = :'Bad Request'
            @lastStatusMsg = "BAD_API_URL: No gbKey available for checking access."
          elsif(!extractedGbKeys.nil? and !extractedGbKeys.empty? and !extractedGbKeys.include?(gbKey))
            retVal = :Unauthorized
            @lastStatusMsg = "BAD_KEY: The gbKey provided does not match this resource."
          else
            retVal = :OK
            @lastStatusMsg = "OK"
          end
        end
      end
      return retVal
    end

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
    # Get appropriate database entity table row (genboreegroup row)
    def tableRow(uri)
      row = nil
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "uri.host: #{URI.parse(uri).host}\n@genbConf.machineName: #{@genbConf.machineName}\n@genbConf.machineNameAlias: #{@genbConf.machineNameAlias}")
      if(uri)
        # First, try from cache
        row = getCacheEntry(uri, :tableRow)
        if(row.nil?)
          # If not cached, try to retrieve it
          #
          # Get name of group
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "no cached row...")
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "machineName: #{@genbConf.machineName.inspect}; machineNameAlias: #{@genbConf.machineNameAlias.inspect}; @dbu.dbrcKey: #{@dbu.dbrcKey.inspect}; uri: #{uri.inspect}")
          #if(addressesMatch?(URI.parse(uri).host, @genbConf.machineName) or addressesMatch?(URI.parse(uri).host, @genbConf.machineNameAlias) or addressesMatch?(URI.parse(uri).host, @dbu.dbrcKey.split(":")[1]) )

          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "  --> URI.parse(uri).host: #{URI.parse(uri).host.inspect} ; @genbConf.machineName: #{@genbConf.machineName.inspect} ; addressesMatch: #{addressesMatch?(URI.parse(uri).host, @genbConf.machineName).inspect}")
          if(addressesMatch?(URI.parse(uri).host, @genbConf.machineName))
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "roi and score track on same host...")
            name = extractName(uri)
            if(name)
              # Get genboreegroup rows
              rows = @dbu.selectGroupByName(name)
              if(rows and !rows.empty?)
                row = rows.first
                # Cache table row
                setCacheEntry(uri, :tableRow, row)
              end
            end
          end
        end
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "returning row: #{row.inspect}")
      return row
    end
  end # class GroupApiUriHelper < ApiUriHelper
end ; end ; end ; end # module BRL ; module Genboree ; module REST ; module Helpers
