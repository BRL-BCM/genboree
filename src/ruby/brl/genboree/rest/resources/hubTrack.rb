require 'cgi'
require 'uri'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/hubGenomeEntity'
require 'brl/genboree/rest/data/hubTrackEntity'
require 'brl/genboree/rest/resources/track'
require 'brl/genboree/abstract/resources/hub'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class HubTrack < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::Hub
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # @return nil
    def cleanup()
      super()
    end

    # @return [Regexp] match a correctly formed URI for this resource
    def self.pattern()
      # look for hub/{hub_name}/genome/{genome_name}/trk/{trk_name}
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/hub/([^/\?]+)/genome/([^/\?]+)/trk/([^/\?]+)$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # @return [Fixnum] priority  the priority, from 1 to 10.
    def self.priority()
      # higher than hubGenome
      return 10
    end

    # validate authorization to connect to resource via parent and
    # perform common operations regardless of the http request method
    # @return [Symbol] initStatus  an HTTP status code name
    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @hubName = Rack::Utils.unescape(@uriMatchData[2])
        @hubGenomeName = Rack::Utils::unescape(@uriMatchData[3])
        @hubTrackName = Rack::Utils::unescape(@uriMatchData[4])
        # Provides: @groupId, @groupDesc, @groupAccessStr
        # Sets @statusName, @statusMsg; poor @statusName caught by get, put, etc.
        initStatus = initGroup()
      end
      return initStatus
    end

    # retrieve an existing hub
    # @todo TODO code reuse with hub and hubGenome resources
    def get()
      begin
        # validate auth tokens
        @statusName = initOperation()
        if(@statusName != :OK)
          defaultMsg = "Unable to authorize access to this resource"
          @statusMsg = (@statusMsg.nil? or @statusMsg.empty? ? defaultMsg : @statusMsg) 
          err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          raise err
        end

        # validate group read access
        unless(READ_ALLOWED_ROLES.key?(@groupAccessStr))
          # message copied from BRL::Genboree::REST::Helpers#initGroup
          msg = "FORBIDDEN: The username provided does not have sufficient access or "\
                "permissions to operate on the resource."
          err = BRL::Genboree::GenboreeError.new(:"Forbidden", msg)
          raise err
        end

        # verify that the desired hub is present
        hubRecs = @dbu.selectHubByNameAndGroupName(@hubName, @groupName)
        if(hubRecs.empty? or hubRecs.nil?)
          @statusName = :"Not Found"
          @statusMsg = "The hub #{@hubName} was not found in the group #{@groupName}"
          err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          raise err
        end

        # verify that the desired hubGenome is present
        hubId = hubRecs.first['id']
        hubGenomeRecs = @dbu.selectHubGenomeByGenomeAndHubId(@hubGenomeName, hubId)
        if(hubGenomeRecs.empty? or hubGenomeRecs.nil?)
          @statusName = :"Not Found"
          @statusMsg = "The hub genome #{@hubGenomeName} was not found in the hub #{@hubName}"
          err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          raise err
        end

        # verify that the desired hubTrack is present
        hubGenomeId = hubGenomeRecs.first['id']
        hubTrackRecs = @dbu.selectHubTrackByTrackAndHubGenomeId(@hubTrackName, hubGenomeId)
        if(hubTrackRecs.empty? or hubTrackRecs.nil?)
          @statusName = :"Not Found"
          @statusMsg = "The hub track #{@hubTrackName} was not found in the hub genome "\
                       "#{@hubGenomeName}"
          err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          raise err
        end

        # finally, with all validations passed, provide access to hubTrack
        hubTrackRec = hubTrackRecs.first
        if(@repFormat == :UCSC_HUB)
          # process database overrides of trackMetaData if applicable
          # entities need not set trkUrl
          unless(hubTrackRec['trkUrl'].nil? or hubTrackRec['trkUrl'].empty?)
            trackMetaData = BRL::REST::Resources::HubTrack::getTrackMetaData(hubTrackRec['trkUrl'], @userId, @rackEnv, @genbConf)
            entity = BRL::REST::Resources::HubTrack::applyOverrides(hubTrackRec, trackMetaData)
          else
            entity = BRL::Genboree::REST::Data::HubTrackEntity.from_json(hubTrackRec)
          end
        else
          if(@detailed == false)
            entity = BRL::Genboree::REST::Data::UrlEntity.new(@connect, hubTrackRec['trkUrl'])
          else
            entity = BRL::Genboree::REST::Data::HubTrackEntity.from_json(hubTrackRec)
          end
        end

        # construct response
        @statusName = :OK
        @statusMsg = :OK
        entity.setStatus(@statusName, @statusMsg)
        @statusName = configResponse(entity) #sets @resp

      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = err.type
          @statusMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace)
          @statusName = :"Internal Server Error"
          @statusMsg = err.message
        end
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end
    
    # create a new hub track or update existing hub track by performing delete then insert operations
    # @todo TODO add support for different import behaviors as with samples
    def put()
      begin
        # validate authentication tokens
        status = initOperation()
        if(status != :OK)
          defaultMsg = "FORBIDDEN: The username provided does not have sufficient access or "\
                       "permissions to operate on the resource."
          @statusMsg = (@statusMsg.nil? or @statusMsg.empty? ? defaultMsg : @statusMsg) 
          err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          raise err
        end

        # validate write access
        unless(WRITE_ALLOWED_ROLES.key?(@groupAccessStr))
          # message copied from BRL::Genboree::REST::Helpers#initGroup
          msg = "FORBIDDEN: The username provided does not have sufficient access or "\
                "permissions to operate on the resource."
          err = BRL::Genboree::GenboreeError.new(:"Forbidden", msg)
          raise err
        end

        # try to parse payload into a HubTrackEntity or UrlEntity
        entity = parseRequestBodyForEntity("HubTrackEntity")
        if(entity.is_a?(BRL::Genboree::GenboreeError) or entity == :"Unsupported Media Type" or 
           entity.nil?) 
          # then we were unable to parse for the entity
          @statusName = :"Unsupported Media Type"
          @statusMsg = "Unable to process the payload as a hub track. Please provide a hub track payload "\
                       "with the following fields: "\
                       "#{::BRL::Genboree::REST::Data::HubTrackEntity::SIMPLE_FIELD_NAMES.join(", ")}."
          raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        end

        if(entity.is_a?(BRL::Genboree::REST::Data::HubTrackEntity))
          # check if the provided hub track name matches the resource path
          unless(entity.trkKey == @hubTrackName)
            @statusName = :"Bad Request"
            @statusMsg = "The hub track name you provided in the payload does not match the "\
                         "hub track name specified in the resource path."
            raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          end
        end

        # verify that the desired hub is present
        hubRecs = @dbu.selectHubByNameAndGroupName(@hubName, @groupName)
        if(hubRecs.empty? or hubRecs.nil?)
          @statusName = :"Not Found"
          @statusMsg = "The hub #{@hubName} was not found in the group #{@groupName}"
          err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          raise err
        end
        hubId = hubRecs.first['id']

        # verify that the desired hub genome is present
        hubGenomeRecs = @dbu.selectHubGenomeByGenomeAndHubId(@hubGenomeName, hubId)
        if(hubGenomeRecs.empty? or hubGenomeRecs.nil?)
          @statusName = :"Not Found"
          @statusMsg = "The hub genome #{@hubGenomeName} was not found in the hub #{@hubName}"
          err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          raise err
        end

        # then all validations have passed, insert/update the hub track
        hubGenomeId = hubGenomeRecs.first['id']
        hubTrackRecs = @dbu.selectHubTrackByTrackAndHubGenomeId(@hubTrackName, hubGenomeId)
        if(hubTrackRecs.nil? or hubTrackRecs.empty?)
          if(hubRecs.nil?)
            # we still proceeded with insert, but an unforseen error occurred in the db 
            # select, log it
            msg = "Database access with @dbu.selectHubTrackByTrackAndGenomeId returned "\
                  "nil -- there may be an error in the track hub tables"
            $stderr.debugPuts(__FILE__, __method__, "DB_ERROR", msg)
          end
          # insert hub track
          numHubTracksInserted = @dbu.insertHubTrack(hubGenomeId, entity.trkKey, entity.type, 
            entity.trkUrl, entity.shortLabel, entity.longLabel, entity.dataUrl, entity.parent_id,
            entity.aggTrack)
          @statusName = :OK
          @statusMsg = "#{numHubTracksInserted} hub track(s) inserted"

        else
          # then hub track already exists, update it
          # NOTE this means putting a url entity to this resource will erase any overrides
          hubTrackId = hubTrackRecs.first['id']
          cols2vals = {
            "hubGenome_id" => hubGenomeId,
            "trkKey" => entity.trkKey,
            "type" => entity.type,
            "parent_id" => entity.parent_id,
            "aggTrack" => entity.aggTrack,
            "trkUrl" => entity.trkUrl,
            "dataUrl" => entity.dataUrl,
            "shortLabel" => entity.shortLabel,
            "longLabel" => entity.longLabel
          }
          numHubTracksUpdated = @dbu.updateHubTrackById(hubTrackId, cols2vals)
          @statusName = :OK
          @statusMsg = "#{numHubTracksUpdated} hub track(s) updated"

        end
        entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
        entity.setStatus(@statusName, @statusMsg)
        configResponse(entity) # sets @resp

      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = err.type
          @statusMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace)
          @statusName = :"Internal Server Error"
          @statusMsg = err.message
        end
      end

      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end

    # delete an existing hub
    # @todo TODO add support for deleting children of hub as well
    def delete()
      begin

        # validate authorization tokens
        status = initOperation()
        if(status != :OK)
          defaultMsg = "FORBIDDEN: The username provided does not have sufficient access or "\
                       "permissions to operate on the resource."
          @statusMsg = (@statusMsg.nil? or @statusMsg.empty? ? defaultMsg : @statusMsg) 
          err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          raise err
        end
        
        # validate write access
        unless(WRITE_ALLOWED_ROLES.key?(@groupAccessStr))
          # message copied from BRL::Genboree::REST::Helpers#initGroup
          msg = "FORBIDDEN: The username provided does not have sufficient access or "\
                "permissions to operate on the resource."
          err = BRL::Genboree::GenboreeError.new(:"Forbidden", msg)
          raise err
        end

        # verify hub is present
        hubRecs = @dbu.selectHubByNameAndGroupName(@hubName, @groupName)
        if(hubRecs.empty? or hubRecs.nil?)
          @statusName = :"Not Found"
          @statusMsg = "The hub #{@hubName} was not found in the group #{@groupName}"
          err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          raise err
        end

        # verify that the desired hub genome is present
        hubGenomeRecs = @dbu.selectHubGenomeByGenomeAndHubId(@hubGenomeName, hubId)
        if(hubGenomeRecs.empty? or hubGenomeRecs.nil?)
          @statusName = :"Not Found"
          @statusMsg = "The hub genome #{@hubGenomeName} was not found in the hub #{@hubName}"
          err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          raise err
        end

        # delete the hub track
        hubGenomeId = hubGenomeRecs.first['id']
        numHubTracksDeleted = @dbu.deleteHubTrackByNameAndGenomeId(@hubTrackName, hubGenomeId)
        @statusName = :OK
        @statusMsg = "#{numHubTracksDeleted} hub track(s) deleted!"
        entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
        entity.setStatus(@statusName, @statusMsg)
        configResponse(entity) # sets @resp

      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = err.type
          @statusMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace)
          @statusName = :"Internal Server Error"
          @statusMsg = err.message
        end
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end

    # Get display settings stored in the track resouce given by trkUrl
    # @param [String] trkUrl the track to get display settings for
    # @param [Fixnum] userId the user to use to get the track display settings via API
    # @param [Hash] rackEnv Ruby Rack web server environment, accessible from resource handlers via @rackEnv
    # @param [BRL::Genboree::GenboreeConfig] genbConf Genboree Configuration object, accessible from resource handlers via @genbConf
    # @return [Hash<String, String>] trackMetaData
    def self.getTrackMetaData(trkUrl, userId, rackEnv=nil, genbConf=nil)
      trackMetaData = {}
      repFormat = :UCSC_HUB_TRACKDB
      # TRK_REGEXP creates back references for  host, group, db, trk
      matchData = BRL::Genboree::REST::Data::HubTrackEntity::TRK_REGEXP.match(trkUrl)
      unless(matchData)
        err = BRL::Genboree::GenboreeError.new(:"Internal Server Error",
          "Unable to get display settings for trkUrl=#{trkUrl.inspect} because it is not a valid Genboree track url")
        raise err
      end

      # trkUrl probably points to a track aspect but we want just the track path along with the query string (for gbKey)
      # trkUrl assumed to be a valid URL (grp, db, etc. components are already escaped)
      host, grp, db, trk = matchData[1], matchData[2], matchData[3], matchData[4]
      path = "/REST/#{VER_STR}/grp/#{grp}/db/#{db}/trk/#{trk}"
      gbKeyStr = ""
      uriObj = URI.parse(trkUrl)
      unless(uriObj.query.nil? or uriObj.query.empty?)
        # keep just the gbKey as other query string parameters may apply only to trk aspect and not trk
        queryHash = CGI.parse(uriObj.query)
        if(queryHash.key?("gbKey"))
          gbKeyStr << "gbKey=#{queryHash["gbKey"].first}" 
        end
      end
      if(gbKeyStr.empty? or gbKeyStr.nil?)
        path << "?format=#{repFormat.to_s}"
      else
        path << "?#{gbKeyStr}" # even if gbKeyStr empty this is valid
        path << "&format=#{repFormat.to_s}"
      end

      apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(host, path, userId)
      apiCaller.initInternalRequest(rackEnv, genbConf.machineNameAlias) if(rackEnv and genbConf)
      resp = apiCaller.get()

      # if request was successful, return non-empty trackMetaData
      if(apiCaller.succeeded?)
        stanzaDataArray = BRL::Genboree::REST::Data::HubTrackEntity.parseStanzaData(apiCaller.respBody)
        trackMetaData = stanzaDataArray.first
      end
      
      return trackMetaData
    end

    # Transform hubTrackRecs into hubTrackArray, adding display settings from the track rec trkUrl where possible
    # @param [Array<Hash>] hubTrackRecs the database records to construct hubTrackEntities for
    # @param [Fixnum] userId the user to use to get the track display settings via API
    # @param [Hash] rackEnv Ruby Rack web server environment, accessible from resource handlers via @rackEnv
    # @param [BRL::Genboree::GenboreeConfig] genbConf Genboree Configuration object, accessible from resource handlers via @genbConf
    # @return [Array<BRL::Genboree::REST::Data::HubTrackEntity>] hubTrackEntities with display settings populated when trkUrl is set
    # @note NOTE mutates hubTrackRecs by adding a :trk key to each rec with a trkUrl and
    #   returned array does not have the same order as the input hubTrackRecs
    def self.getTracksWithMetaData(hubTrackRecs, userId, rackEnv=nil, genbConf=nil)
      type2Suffix = {
        "bigWig" => "_bwuc",
        "bigBed" => "_bbuc"
      }

      # if applicable, map dbUris to trkUrls to minimize API calls to get track meta data
      # otherwise, begin constructing return value of hubTrackEntities
      hubTrackArray = []
      trkApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new()
      fileApiHelper = BRL::Genboree::REST::Helpers::FileApiUriHelper.new()
      dbUri2TrkDataArray = Hash.new(){|hh, kk| hh[kk] = []}
      dbUri2FileDataArray = Hash.new(){|hh, kk| hh[kk] = []}
      trkDataTemplate = {:trkName => nil, :index => nil, :trkWithSuffix => nil}
      fileDataTemplate = {:fileName => nil, :index => nil}
      dbUri2GbKey = {} # TODO 2+ urls with different gbKeys (but same database)
      hubTrackRecs.each_index{|ii|
        hubTrackRec = hubTrackRecs[ii]
        trkUrl = hubTrackRec['trkUrl']
        dataUrl = hubTrackRec['dataUrl']
        type = hubTrackRec['type']
        if(!trkUrl.nil? and !trkUrl.empty? and type2Suffix.key?(type) and (dataUrl.nil? or dataUrl.empty?))
          # then trkUrl is not overridden and we have data for it
          matchData = BRL::Genboree::REST::Data::HubTrackEntity::TRK_REGEXP.match(trkUrl)
          unless(matchData)
            err = BRL::Genboree::GenboreeError.new(:"Internal Server Error",
              "Unable to get display settings for trkUrl=#{trkUrl.inspect} because it is not a valid Genboree track url")
            raise err
          end
          
          # trkUrl probably points to a track aspect but we want just the track path along with the query string (for gbKey)
          # trkUrl assumed to be a valid URL (grp, db, etc. components are already escaped)
          host, grp, db, trk = matchData[1], matchData[2], matchData[3], matchData[4]
          dbUri = "http://#{host}/REST/#{VER_STR}/grp/#{grp}/db/#{db}"
          hubTrackRec[:trk] = trk
          hubTrackRec[:dbUri] = dbUri
          gbTrkName = "#{trk}#{type2Suffix[type]}"
          trkData = trkDataTemplate.dup()
          trkData[:trkName] = trk
          trkData[:trkWithSuffix] = gbTrkName
          trkData[:index] = ii

          dbUri2TrkDataArray[dbUri].push(trkData)

          # if any of the trkUrls have a gbKey be sure to use it
          uriObj = URI.parse(trkUrl)
          queryHash = Rack::Utils::parse_query(uriObj.query)
          if(queryHash.key?("gbKey"))
            dbUri2GbKey[dbUri] = queryHash["gbKey"]
          end
        elsif(!dataUrl.nil? and !dataUrl.empty?)
          # then trkUrl is overridden by dataUrl 
          matchData = BRL::Genboree::REST::Data::HubTrackEntity::FILE_REGEXP.match(dataUrl)
          unless(matchData)
            err = BRL::Genboree::GenboreeError.new(:"Internal Server Error",
              "Unable to get display settings for dataUrl=#{dataUrl.inspect} because it is not a valid Genboree file url")
            raise err
          end

          host, grp, db, file = matchData[1], matchData[2], matchData[3], matchData[4]
          dbUri = "http://#{host}/REST/#{VER_STR}/grp/#{grp}/db/#{db}"
          hubTrackRec[:file] = file
          hubTrackRec[:dbUri] = dbUri

          fileData = fileDataTemplate.dup()
          fileData[:fileName] = file
          fileData[:index] = ii
          dbUri2FileDataArray[dbUri].push(fileData)

          # if any of the dataUrls have a gbKey be sure to use it
          uriObj = URI.parse(dataUrl)
          queryHash = Rack::Utils::parse_query(uriObj.query)
          if(queryHash.key?("gbKey"))
            dbUri2GbKey[dbUri] = queryHash["gbKey"]
          end
        else
          # trkUrl or dataUrl must be set, try and create a HubTrackEntity
          # and leave error handling to that entity
          $stderr.debugPuts(__FILE__, __method__, "DB_ERROR", "trkUrl and dataUrl missing from hubTrackRec=#{hubTrackRec.inspect}")
        end
      }

      # with map created, construct url to get hub track attributes for bigWig and bigBed types
      format = "UCSC_HUB_TRACKDB"
      dbUri2TrkDataArray.each_key{|dbUri|
        queryComponents = []
        trkDataArray = dbUri2TrkDataArray[dbUri]
        trkNames = trkDataArray.collect{|trkDatum| trkDatum[:trkWithSuffix]}
        gbKey = dbUri2GbKey[dbUri]
        unless(gbKey.nil?)
          gbKeyQuery = "gbKey=#{gbKey}"
          queryComponents.push(gbKeyQuery)
        end

        # will always have at least 1 ucscTrack otherwise we wouldnt have key in dbUri2TrkDataArray map
        ucscTracks = trkNames.join(",")
        ucscTracksQuery = "ucscTracks=#{ucscTracks}"
        queryComponents.push(ucscTracksQuery)

        # format for UCSC stanza data
        formatQuery = "format=#{format}"
        queryComponents.push(formatQuery)

        uriObj = URI.parse(dbUri)
        pathAndQuery = "#{uriObj.path}/trks?#{queryComponents.join("&")}"
      
        apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(uriObj.host, pathAndQuery, userId)
        apiCaller.initInternalRequest(rackEnv, genbConf.machineNameAlias) if(rackEnv and genbConf)
        resp = apiCaller.get()
        respBody = apiCaller.respBody # NOTE this must be done before apiCaller.succeeded? statement?
        if(apiCaller.succeeded?)
          # now have a list of track meta data from trkUrl and a list of hubTrackRec information
          # associate metaData to hubTrackRec with help of trackApiUriHelper
          stanzaDataArray = BRL::Genboree::REST::Data::HubTrackEntity.parseStanzaData(respBody)
          trkDataArray.each{|trkData|
            hubTrackRec = hubTrackRecs[trkData[:index]]
            stanzaIndex = stanzaDataArray.index(){|stanzaData| trkApiHelper.extractPureUri(stanzaData[:bigDataUrl]) == trkApiHelper.extractPureUri(hubTrackRec['trkUrl'])}
            unless(stanzaIndex.nil?)
              stanzaData = stanzaDataArray[stanzaIndex]
              hubTrackRec[:metaData] = stanzaData
            else
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "unable to associate hub tracks to track meta data")
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "apiCaller.rsrcPath=#{apiCaller.rsrcPath.inspect}")
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "respBody=#{respBody.inspect}")
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "stanzaDataArray=#{stanzaDataArray.inspect}")
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "hubTrackRec=#{hubTrackRec.inspect}")
            end
          }
        else
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "failed to get track stanza data for host #{uriObj.host} and path #{pathAndQuery}")
        end
      }

      # similarly for dbUri2FileDataArray but easier b/c JSON and less URL options
      # TODO query string
      dbUri2FileDataArray.each_key{|dbUri|
        trkDataFileArray = dbUri2FileDataArray[dbUri] # data from hubTrackRecs
        fileNames = trkDataFileArray.collect{|hh| hh[:fileName]}
        fileNames = fileNames.to_set.to_a
        uriObj = URI.parse(dbUri)
        path = "#{uriObj.path}/files?fileList=#{fileNames.join(",")}"
        apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(uriObj.host, path, userId)
        apiCaller.initInternalRequest(rackEnv, genbConf.machineNameAlias) if(rackEnv and genbConf)
        resp = apiCaller.get()
        if(apiCaller.succeeded?)
          gbFileMetaArray = apiCaller.parseRespBody()['data'] # data from Genboree
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "gbFileMetaArray=#{gbFileMetaArray.inspect}")
          # now have a list of file meta data, associate it to our original hub track records
          trkDataFileArray.each{|fileData|
            hubTrackRec = hubTrackRecs[fileData[:index]]
            gbIndex = gbFileMetaArray.index(){|meta| meta["name"] == CGI.unescape(fileData[:fileName])}
            unless(gbIndex.nil?)
              hubTrackRec[:fileData] = gbFileMetaArray[gbIndex]
            end
          }
        end
      }

      # finally, with hubTrackRecs associated with the metaData from their trkUrl, construct hubTrackEntities with display settings
      hubTrackRecs.each_index{|ii|
        hubTrackRec = hubTrackRecs[ii]
        if(!hubTrackRec[:fileData].nil?)
          # then we have file data from dataUrl
          fileMetaData = hubTrackRec.delete(:fileData)
          description = fileMetaData['description']
          label = fileMetaData['label']

          matchData = BRL::Genboree::REST::Data::HubTrackEntity::FILE_REGEXP.match(hubTrackRec['dataUrl'])
          unless(matchData)
            err = BRL::Genboree::GenboreeError.new(:"Internal Server Error",
              "Unable to get url components for dataUrl=#{hubTrackRec['dataUrl'].inspect} because it is not a valid Genboree file url")
            raise err
          end
          host, grp, db, file = matchData[1], matchData[2], matchData[3], matchData[4]
          entity = BRL::Genboree::REST::Data::HubTrackEntity.from_json(hubTrackRec)
          
          # transform entity dataUrl to accomodate requests from UCSC (they dont support our /data aspect)
          fileDataUrl = "http://#{host}/REST/v1/grp/#{grp}/db/#{db}/fileData/#{file}"
          entity.dataUrl = fileDataUrl

          if(entity.longLabel.nil?)
            # then no db override for long label, use the one from the file
            # TODO cap the length at 80 char?
            labelStr = "FILE:#{file}, HOST:#{host}, GROUP:#{grp}, DATABASE:#{db}"
            entity.longLabel = labelStr
          end

          if(entity.shortLabel.nil?)
            # then no db override for short label, use the one from the file
            unless(label.nil?)
              entity.shortLabel = label
            end
          end
          hubTrackArray.push(entity)

        elsif(!hubTrackRec[:metaData].nil?)
          # then we have metadata from trkUrl
          trackMetaData = hubTrackRec.delete(:metaData)
          entity = BRL::REST::Resources::HubTrack::applyOverrides(hubTrackRec, trackMetaData)
          hubTrackArray.push(entity) unless(entity.nil?)
          # TODO callers should check if hubTrackArray is the length they expect
        else
          # something went wrong retrieving the meta data for the hubTrack
          # fill in what we can from the trkUrl or dataUrl
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "unable to get meta data for hubTrackRec=#{hubTrackRec.inspect}")
          if(!hubTrackRec['dataUrl'].nil?)
            fileName = fileApiHelper.extractName(hubTrackRec['dataUrl'])
            unless(fileName.nil?)
              hubTrackRec['shortLabel'] = CGI.unescape(fileName)
              hubTrackRec['longLabel'] = CGI.unescape(fileName)
            end
          elsif(!hubTrackRec['trkUrl'].nil?)
            trkName = trkApiHelper.extractName(hubTrackRec['trkUrl'])
            unless(trkName.nil?)
              hubTrackRec['shortLabel'] = CGI.unescape(trkName)
              hubTrackRec['longLabel'] = CGI.unescape(trkName)
            end
          end

          # also modify the trkUrl to include the type aspect so that the data is actually there
          unless(hubTrackRec['trkUrl'].nil?)
            uriObj = URI.parse(hubTrackRec['trkUrl'])
            gbKey = trkApiHelper.extractGbKey(hubTrackRec['trkUrl'])
            newTrkUrl = ""
            unless(hubTrackRec['type'].nil?)
              newTrkUrl = "#{uriObj.scheme}://#{uriObj.host}#{uriObj.path}/#{hubTrackRec['type']}"
            else
              $stderr.debugPuts("hubTrackRec=#{hubTrackRec.inspect} has a missing type -- are validators working properly? Defaulting to bigWig")
              newTrkUrl = "#{uriObj.scheme}://#{uriObj.host}#{uriObj.path}/bigWig"
            end
            newTrkUrl << "?gbKey=#{gbKey}" if(gbKey)
            hubTrackRec['trkUrl'] = newTrkUrl
          end
          entity = BRL::Genboree::REST::Data::HubTrackEntity.from_json(hubTrackRec)
          hubTrackArray.push(entity)
        end
      }
      
      return hubTrackArray
    end

    # process any overrides from the database that should be applied to the trackMetaData
    #   five key fields: trkKey, type, shortLabel, longLabel, bigDataUrl
    # @param [Hash] hubTrackRec record from database
    # @param [Hash] trackMetaData information from self.getTrackMetaData from trkUrl
    # @return [BRL::Genboree::REST::Data::HubTrackEntity]
    # @note NOTE since override only applies to hubTrackRecs with trkUrl set, it is assumed
    #   that the bigDataUrl in trackMetaData applies to trkUrl
    def self.applyOverrides(hubTrackRec, trackMetaData)
      retVal = nil
      begin
        # dont mutate inputs
        hubTrackHash = hubTrackRec.dup()
        trackMetaCopy = trackMetaData.dup()
  
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "hubTrackHash=#{hubTrackHash.inspect}")
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "trackMetaCopy=#{trackMetaCopy.inspect}")
  
        # short label may be automatically set by entity and stored in database
        shortLabel = trackMetaCopy.delete(:shortLabel)
        if(hubTrackHash['shortLabel'].nil? or hubTrackHash['shortLabel'].empty?)
          unless(shortLabel.nil? or shortLabel.empty?)
            hubTrackHash['shortLabel'] = shortLabel
          end
        end
  
        # long label
        longLabel = trackMetaCopy.delete(:longLabel)
        if(hubTrackHash['longLabel'].nil? or hubTrackHash['longLabel'].empty?)
          unless(longLabel.nil? or longLabel.empty?)
            hubTrackHash['longLabel'] = longLabel
          end
        end
  
        # type
        type = trackMetaCopy.delete(:type)
        if(hubTrackHash['type'].nil? or hubTrackHash['type'].empty?)
          unless(type.nil? or type.empty?)
            hubTrackHash['type'] = type
          end
        end
  
        # always use bigDataUrl from trackMetaData since
        # in db it is sufficient to have just a trk url without a proper aspect ("/bigWig" or "/bigBed")
        bigDataUrl = trackMetaCopy.delete(:bigDataUrl)
        unless(bigDataUrl.nil? or bigDataUrl.empty?)
          hubTrackHash['trkUrl'] = bigDataUrl
        end
  
        # keep trkKey from database
        trkKey = trackMetaCopy.delete(:track)
  
        # remaining fields are not part of hubTrackEntity constructor but are optional display settings
        hubTrackHash['displaySettings'] = trackMetaCopy
  
        retVal = BRL::Genboree::REST::Data::HubTrackEntity.from_json(hubTrackHash)
      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = err.type
          @statusMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace)
          @statusName = :"Internal Server Error"
          @statusMsg = err.message
        end
      end

      return retVal
    end
  end
end ; end; end
