require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/hubEntity'
require 'brl/genboree/rest/data/hubGenomeEntity'
require 'brl/genboree/rest/data/hubTrackEntity'
require 'brl/genboree/abstract/resources/hub'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class Hub < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::Hub
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true, :head => true }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # @return nil
    def cleanup()
      super()
    end

    # @return [Regexp] match a correctly formed URI for this resource
    def self.pattern()
      # look for hub/{hub_name}
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/hub/([^/\?]+)$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # @return [Fixnum] priority  the priority, from 1 to 10.
    def self.priority()
      return 6
    end

    # validate authorization to connect to resource via parent and
    # perform common operations regardless of the http request method
    # @return [Symbol] initStatus  an HTTP status code name
    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @hubName = Rack::Utils.unescape(@uriMatchData[2])
        # Provides: @groupId, @groupDesc, @groupAccessStr
        # Sets @statusName, @statusMsg; poor @statusName caught by get, put, etc.
        initStatus = initGroup()
      end
      return initStatus
    end

    # retrieve an existing hub
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

        # finally, with all validations passed, provide access to hub
        hubRec = hubRecs.first
        if(@detailed == true)
          # then respond hub, hubGenomes, hubTracks info
          fullHubs = hubRecordsToFullEntityList(hubRecs, @dbu)
          hubFullEntity = BRL::Genboree::REST::Data::HubFullEntity.from_json(fullHubs.first)
          @statusName = :OK
          @statusMsg = :OK
          hubFullEntity.setStatus(@statusName, @statusMsg)
          @statusName = configResponse(hubFullEntity) #sets @resp
        else
          # then respond with just the hub summary information
          hubEntity = BRL::Genboree::REST::Data::HubEntity.new(true, hubRec['name'], 
            hubRec['shortLabel'], hubRec['longLabel'], hubRec['email'], hubRec['public'])
          @statusName = :OK
          @statusMsg = :OK
          hubEntity.setStatus(@statusName, @statusMsg)
          @statusName = configResponse(hubEntity) #sets @resp
        end

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

    def head()
      begin
        # get the response from get(), performing its same validations
        @resp = get()
        if((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
          # then we need to remove the body from the response according to the http
          # requirements of the HEAD request, headers should be identical between
          # get and head
          @resp.body = []
        end
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
    
    # create a new hub or update existing hub by performing delete then insert operations
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

        # try to parse payload into a HubEntity or a HubFullEntity
        if(@detailed == true)
          entity = parseRequestBodyForEntity("HubFullEntity")
        else
          entity = parseRequestBodyForEntity("HubEntity")
        end
        if(entity.is_a?(BRL::Genboree::GenboreeError) or entity == :"Unsupported Media Type" or 
           entity.nil?) 
          # then we were unable to parse for the entity
          @statusName = :"Unsupported Media Type"
          @statusMsg = "Unable to process the payload as a hub. Please provide a payload "\
                       "with the following fields: "\
                       "#{BRL::Genboree::REST::Data::HubEntity::SIMPLE_FIELD_NAMES.join(", ")}."
          raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        end

        # check if the provided hub name matches the resource path
        unless(entity.name == @hubName)
          @statusName = :"Bad Request"
          @statusMsg = "The hub name you provided in the payload does not match the "\
                       "hub name specified in the resource path."
          raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        end

        # before performing any inserts in the detailed = true case,
        # make sure we can parse the entities nested in the hub
        if(@detailed == true)
          hubGenomes = BRL::Genboree::REST::Data::HubFullGenomeEntityList.from_json(entity.genomes)
          if(hubGenomes.is_a?(BRL::Genboree::GenboreeError) or 
             hubGenomes == :"Unsupported Media Type" or hubGenomes.nil?) 
            # then we were unable to parse for the entity
            @statusName = :"Unsupported Media Type"
            @statusMsg = "We successfully processed the hub in your payload, but were unable to "\
              "process its child genomes. Please provide a payload with the following fields "\
              "(e.g. nested under the hub's \"genomes\" key): "\
              "#{BRL::Genboree::REST::Data::HubFullGenomeEntity::SIMPLE_FIELD_NAMES.join(", ")}."
            raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          end

          # and that we can parse the entities nested under genomes
          genomeToTracks = {}
          hubGenomes.each{|hubGenomeEntity|
            hubTracks = BRL::Genboree::REST::Data::HubTrackEntityList.from_json(hubGenomeEntity.tracks)
            if(hubTracks.is_a?(BRL::Genboree::GenboreeError) or 
               hubTracks == :"Unsupported Media Type" or hubTracks.nil?) 
              # then we were unable to parse for the entity
              @statusName = :"Unsupported Media Type"
              @statusMsg = "We successfully processed the genome(s) in your payload, but were "\
                "unable to process the child tracks. Please provide a payload with the following "\
                "fields (e.g. nested under the genome key \"tracks\"): "\
                "#{BRL::Genboree::REST::Data::HubFullGenomeEntity::SIMPLE_FIELD_NAMES.join(", ")}."
              raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
            end

            # if no error then parsing went ok
            genomeToTracks[hubGenomeEntity.genome] = hubTracks
          }
        end

        # then all validations have passed, insert/update the hubs
        hubRecs = @dbu.selectHubByNameAndGroupName(@hubName, @groupName)
        if(hubRecs.nil? or hubRecs.empty?)
          if(hubRecs.nil?)
            # we still proceeded with insert, but an unforseen error occurred in the db 
            # select, log it
            msg = "Database access with @dbu.selectHubByHubNameAndGroupName returned "\
                  "nil -- there may be an error in the track hub tables"
            $stderr.debugPuts(__FILE__, __method__, "DB_ERROR", msg)
          end
          # insert hub
          numHubsInserted = @dbu.insertHub(@groupId, entity.name, entity.shortLabel, 
                                           entity.longLabel, entity.email, entity.public)
          numHubsInserted = (numHubsInserted.nil? ? 0 : numHubsInserted)
          hubId = @dbu.lastInsertId
          @statusName = :OK
          @statusMsg = "#{numHubsInserted} hub(s) inserted"
        else
          # then hub already exists, update it
          hubId = hubRecs.first['id']
          entityHash = JSON.parse(entity.to_json())['data']
          entityHash.delete("genomes")
          numHubsUpdated = @dbu.updateHubById(hubId, entityHash)
          numHubsUpdated = (numHubsUpdated.nil? ? 0 : numHubsUpdated)
          @statusName = :OK
          @statusMsg = "#{numHubsUpdated} hub(s) updated"
        end

        # if we have a HubFullEntity aka @detailed = true then insert genomes and tracks
        # which have already been validated
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "@detailed=#{@detailed.inspect}")
        if(@detailed == true)
          # insert the hubGenomes
          numGenomesInOrUp = 0
          genomeToId = {} # map entity.genome to its id in the hubGenomes db
          hubGenomes.each{|hubGenomeEntity| 
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "hubGenomes=#{hubGenomes.inspect}")
            hubGenomeRecs = @dbu.selectHubGenomeByGenomeAndHubId(hubGenomeEntity.genome, hubId)
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "hubGenomeRecs=#{hubGenomeRecs.inspect}")
            if(hubGenomeRecs.nil? or hubGenomeRecs.empty?)
              # then the hubGenome doesnt already exist in the database
              if(hubGenomeRecs.nil?)
                # then proceed with insert but log database error
                msg = "Database access with @dbu.selectHubGenomeByGenomeAndHubId returned "\
                      "nil -- there may be an error in the track hub tables"
                $stderr.debugPuts(__FILE__, __method__, "DB_ERROR", msg)
              end
              # insert hubGenome
              numHubGenomesInserted = @dbu.insertHubGenome(hubId, hubGenomeEntity.genome, 
                hubGenomeEntity.description, hubGenomeEntity.organism, 
                hubGenomeEntity.defaultPos, hubGenomeEntity.orderKey)
              numHubGenomesInserted = (numHubGenomesInserted.nil? ? 0 : numHubGenomesInserted)
              hubGenomeId = @dbu.lastInsertId
              numGenomesInOrUp += numHubGenomesInserted
            else
              # then the hubGenome already exists, update it
              hubGenomeId = hubGenomeRecs.first['id']
              hubGenomeHash = JSON.parse(hubGenomeEntity.to_json())['data']
              hubGenomeHash.delete("tracks")
              numHubGenomesUpdated = @dbu.updateHubGenomeById(hubGenomeId, hubGenomeHash)
              numHubGenomesUpdated = (numHubGenomesUpdated.nil? ? 0 : numHubGenomesUpdated)
              numGenomesInOrUp += numHubGenomesUpdated
            end
            genomeToId[hubGenomeEntity.genome] = hubGenomeId
          }
          @statusName = :OK
          @statusMsg << "; #{numGenomesInOrUp} hub genome(s) inserted/updated"

          # insert the hubTracks
          numTracksInOrUp = 0
          hubGenomes.each{|hubGenomeEntity|
            genomeId = genomeToId[hubGenomeEntity.genome]
            hubTracks = genomeToTracks[hubGenomeEntity.genome]
            hubTracks.each{|hubTrackEntity|
              hubTrackRecs = @dbu.selectHubTrackByTrackAndHubGenomeId(hubTrackEntity.trkKey, genomeId)
              if(hubTrackRecs.nil? or hubTrackRecs.empty?)
                # then the hubTrack doesnt already exist in the database
                if(hubTrackRecs.nil?)
                  # then proceed with insert but log database error
                  msg = "Database access with @dbu.selectHubTrackByTrackAndHubGenomeId returned "\
                        "nil -- there may be an error in the track hub tables"
                  $stderr.debugPuts(__FILE__, __method__, "DB_ERROR", msg)
                end
                # insert hubTrack
                numHubTracksInserted = @dbu.insertHubTrack(genomeId, hubTrackEntity.trkKey, 
                  hubTrackEntity.type, hubTrackEntity.trkUrl, hubTrackEntity.shortLabel, 
                  hubTrackEntity.longLabel, hubTrackEntity.dataUrl, hubTrackEntity.parent_id, 
                  hubTrackEntity.aggTrack)
                numHubTracksInserted = (numHubTracksInserted.nil? ? 0 : numHubTracksInserted)
                numTracksInOrUp += numHubTracksInserted
              else
                # then the hubTrack already exists, update it
                hubTrackId = hubTrackRecs.first['id']
                hubTrackEntityHash = JSON.parse(hubTrackEntity.to_json)['data']
                numHubTracksUpdated = @dbu.updateHubTrackById(hubTrackId, hubTrackEntityHash)
                numHubTracksUpdated = (numHubTracksUpdated.nil? ? 0 : numHubTracksUpdated)
                numTracksInOrUp += numHubTracksUpdated
              end
            }
          }
          @statusName = :OK
          @statusMsg << "; #{numTracksInOrUp} hub track(s) inserted/updated"
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

        # verify that the desired hub is present
        hubRecs = @dbu.selectHubByNameAndGroupName(@hubName, @groupName)
        if(hubRecs.empty? or hubRecs.nil?)
          @statusName = :"Not Found"
          @statusMsg = "The hub #{@hubName} was not found in the group #{@groupName}"
          err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          raise err
        end
        
        # get hub and child ids
        hubId = hubRecs.first['id']
        hubGenomeIds = []
        hubTrackIds = []
        hubGenomeRecs = @dbu.selectHubGenomesByHubId(hubId)
        unless(hubGenomeRecs.nil? or hubGenomeRecs.empty?)
          hubGenomeIds = hubGenomeRecs.collect{|rec| rec['id']}
          hubTrackRecs = @dbu.selectHubTracksByHubGenomeIds(hubGenomeIds)
          unless(hubTrackRecs.nil? or hubTrackRecs.empty?)
            hubTrackIds = hubTrackRecs.collect{|rec| rec['id']}
          end
        end

        # delete the hubTracks
        numHubTracksDeleted = 0
        unless(hubTrackIds.empty?)
          numHubTracksDeleted = @dbu.deleteHubTracksByIds(hubTrackIds)
          if(numHubTracksDeleted.nil?)
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "something went wrong while deleting hub tracks with the following ids: #{hubTrackIds.join(", ")}!")
            numHubTracksDeleted = 0
          end
        end
        
        # delete the hubGenomes
        numHubGenomesDeleted = 0
        unless(hubGenomeIds.empty?)
          numHubGenomesDeleted = @dbu.deleteHubGenomesByIds(hubGenomeIds)
          if(numHubGenomesDeleted.nil?)
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "something went wrong while deleting hub genomes with the following ids: #{hubGenomeIds.join(", ")}!")
            numHubGenomesDeleted = 0
          end
        end

        # delete the hub
        numHubsDeleted = 0
        numHubsDeleted = @dbu.deleteHubById(hubId)
        if(numHubsDeleted.nil?)
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "something went wrong while deleting the hub with the following id: #{hubId}!")
          numHubsDeleted = 0
        end
        @statusName = :OK
        @statusMsg = "#{numHubsDeleted} hub(s) deleted, #{numHubGenomesDeleted} hub genome(s) deleted, and #{numHubTracksDeleted} hub tracks deleted!"
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
