require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/hubGenomeEntity'
require 'brl/genboree/abstract/resources/hub'
require 'brl/genboree/rest/resources/hubTrack'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class HubTracks < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::Hub
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    SUPPORTED_ASPECTS = { "count" => true }

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
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/hub/([^/\?]+)/genome/([^/\?]+)/trks(?:$|/([^/\?]+)$)}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # @return [Fixnum] priority  the priority, from 1 to 10.
    def self.priority()
      # higher than hubGenomeAspect
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
        @hubTracksAspect = (@uriMatchData[4].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[4])
        if(!@hubTracksAspect.nil? and !SUPPORTED_ASPECTS.key?(@hubTracksAspect))
          @statusName = initStatus = :"Bad Request"
          @statusMsg = "The request URI does not indicate an exposed aspect of the hub tracks "\
                       "resource. Supported aspects: #{SUPPORTED_ASPECTS.keys().join(", ")}."
        end
        # Provides: @groupId, @groupDesc, @groupAccessStr
        # Sets @statusName, @statusMsg; poor @statusName caught by get, put, etc.
        initStatus = initGroup() if(initStatus == :OK)
      end
      return initStatus
    end

    # retrieve existing hub tracks belonging to the hub genome
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

        # finally, with all validations passed, provide access to hubTracks
        hubGenomeId = hubGenomeRecs.first['id']
        hubTrackRecs = @dbu.selectHubTracksByHubGenomeId(hubGenomeId)

        if(@hubTracksAspect.nil?)
          # process database overrides of trackMetaData if applicable
          hubTrackArray = BRL::REST::Resources::HubTrack::getTracksWithMetaData(hubTrackRecs, userId, @rackEnv, @genbConf)
          if(hubTrackArray.nil? or hubTrackArray.empty?)
            # hubTrackRecs arent empty since no prior error, something went wrong in getting the meta data
            $stderr.debugPuts(__FILE__, __method__, "DEBUG" "unable to retrieve meta data for hubTrackRecs=#{hubTrackRecs.inspect}, using database info")
            entity = BRL::Genboree::REST::Data::HubTrackEntityList.from_json(hubTrackRecs)
          else
            entity = BRL::Genboree::REST::Data::HubTrackEntityList.new(@connect, hubTrackArray)
          end
  
          # construct the response
          @statusName = :OK
          @statusMsg = :OK
          entity.setStatus(@statusName, @statusMsg)
          @statusName = configResponse(entity) #sets @resp
        else
          if(@hubTracksAspect == "count")
            count = (hubTrackRecs.nil? ? 0 : hubTrackRecs.length)
            countEntity = BRL::Genboree::REST::Data::CountEntity.new(@connect, count)
            @statusName = :OK
            @statusMsg = :OK
            countEntity.setStatus(@statusName, @statusMsg)
            @statusName = configResponse(countEntity) #sets @resp
          else
            if(SUPPORTED_ASPECTS.key?(@hubTracksAspect))
              @statusName = :"Internal Server Error"
              @statusMsg = "A developer for this resource added the aspect #{@hubTracksAspect} to the list of supported aspects "\
                "but didn't implement support for it!"
              err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
              raise err
            else
              # if here, validation in initOperation for supported aspects failed, give the same response though 
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Resource failed validation of aspects in #initOperation")
              @statusName = :"Bad Request"
              @statusMsg = "The request URI does not indicate an exposed aspect of the hub tracks "\
                           "resource. Supported aspects: #{SUPPORTED_ASPECTS.keys().join(", ")}."
              err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
              raise err
            end
          end
        end

      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = err.type
          @statusMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace.join("\n"))
          @statusName = :"Internal Server Error"
          @statusMsg = err.message
        end
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end

    # add new or update existing hub tracks to the hub genome
    def put()
      begin
        # validate auth tokens
        @statusName = initOperation()
        if(@statusName != :OK)
          defaultMsg = "Unable to authorize access to this resource"
          @statusMsg = (@statusMsg.nil? or @statusMsg.empty? ? defaultMsg : @statusMsg) 
          err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          raise err
        end

        # validate group write access
        unless(WRITE_ALLOWED_ROLES.key?(@groupAccessStr))
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
        hubGenomeId = hubGenomeRecs.first['id']

        # support a put from hubTrackEntityList
        hubTrackEntityList = parseRequestBodyForEntity("HubTrackEntityList")
        if(hubTrackEntityList.is_a?(BRL::Genboree::REST::Data::HubTrackEntityList))
          # TODO generating a trkKey like this means that API users may create two hub tracks with the same
          # trkUrl but different trkKeys (by separate puts to /trks or /trk/{trk})
 
          # identify new tracks that should be inserted, and previously existing tracks that should be updated
          # TODO maybe we want to use a SQL query that selects multiple trkKeys
          trackId2Entity = {}
          tracksToInsert = []
          hubTrackEntityList.each{|hubTrackEntity|
            hubTrackRecs = @dbu.selectHubTrackByTrackAndHubGenomeId(hubTrackEntity.trkKey, hubGenomeId)
            # check for database error
            if(hubTrackRecs.nil?)
              err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", 
                "Database error occured while selecting hub track identified by #{hubTrackEntity.trkKey}")
              raise err
            end
            
            # identify which tracks can be safely inserted and which ones need to be updated
            # tracks in payload with specified trkKeys will be updated
            # tracks in payload with generated trkKeys will be inserted with a new trkKey
            if(hubTrackRecs.empty?)
              tracksToInsert.push(hubTrackEntity)
            elsif(!hubTrackRecs.empty? and hubTrackEntity.generatedKey)
              # TODO very probably 2 generated trkKeys will have no collisions but not necessarily.. could cause errors 
              # where in some cases a new record should be added when instead an existing one is updated
              hubTrackEntity.trkKey = hubTrackEntity.generateTrkKey()
              tracksToInsert.push(hubTrackEntity)
            else
              # not generated and existing records
              trackId2Entity[hubTrackRecs.first['id']] = hubTrackEntity
            end
          }
  
          # insert hub tracks not previously in db
          tableData = []
          # order of hubTrackEntity fields in the database method (except for hubGenome_id which comes first, but
          # is not a part of the hubTrackEntity representation)
          tableFieldOrder = [ "trkKey", "type", "parent_id", "aggTrack", "trkUrl", "dataUrl", "shortLabel", "longLabel" ]
          tracksToInsert.each{|hubTrackEntity|
            hubTrackData = hubTrackEntity.getFormatableDataStruct()['data']
            rowData = []
            rowData.push(hubGenomeId)
            tableFieldOrder.each{|field|
              rowData.push(hubTrackData[field])
            }
            tableData.push(rowData)
          }
          numTracksInserted = 0 
          unless(tableData.empty?)
            numTracksInserted = @dbu.insertHubTracks(tableData, tableData.length)

            # look for database errors
            if(numTracksInserted.nil?)
              err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", 
                "A database error occurred while inserting new tracks into your hub")
              raise err
            end
          end
  
          # update hub tracks previously in db
          totalTracksUpdated = 0
          trackId2Entity.each_key{|id|
            hubTrackEntity = trackId2Entity[id]
            # dont need to worry about hubGenomeId because the select was made with that id (it couldnt be updated)
            cols2vals = hubTrackEntity.getFormatableDataStruct()['data']
            numTracksUpdated = @dbu.updateHubTrackById(id, cols2vals)
            if(numTracksUpdated.nil?)
              err = BRL::Genboree::GenboreeError.new(:"Internal Server Error",
                "Database error occured while updating hub track identified by #{hubTrackEntity.trkKey}")
              raise err
            else
              totalTracksUpdated += numTracksUpdated
            end
          }
  
          # count all tracks inserted or updated
          numTracksInOrUp = totalTracksUpdated + numTracksInserted

        else
          # currently other representations are not supported
          raise BRL::Genboree::GenboreeError.new(:"Unsupported Media Type", 
            "The payload could not be processed as a HubTrackEntityList, which is currently the only representation "\
            "supported by this resource")
        end

        # if no errors then set @resp
        @statusName = :OK
        @statusMsg = "#{numTracksInOrUp} hub track(s) inserted/updated!"
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

    # remove all hub tracks belonging to the hub genome
    def delete()
      begin
        # validate auth tokens
        @statusName = initOperation()
        if(@statusName != :OK)
          defaultMsg = "Unable to authorize access to this resource"
          @statusMsg = (@statusMsg.nil? or @statusMsg.empty? ? defaultMsg : @statusMsg) 
          err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          raise err
        end

        # validate group write access
        unless(WRITE_ALLOWED_ROLES.key?(@groupAccessStr))
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
        hubGenomeId = hubGenomeRecs.first['id']

        # delete the hub tracks
        numTracksDeleted = @dbu.deleteAllHubTracksByHubGenomeId(hubGenomeId)

        # verify that hub tracks 
        if(numTracksDeleted.nil?)
          err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", 
            "Encountered database error while trying to delete your hub tracks")
          raise err
        end

        # if no errors then set @resp
        @statusName = :OK
        @statusMsg = "#{numTracksDeleted} hub track(s) deleted!"
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

  end
end ; end; end
