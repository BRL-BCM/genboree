require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/hubGenomeEntity'
require 'brl/genboree/abstract/resources/hub'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class HubGenome < BRL::REST::Resources::GenboreeResource
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
      # look for hub/{hub_name}/genome/{genome_name}
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/hub/([^/\?]+)/genome/([^/\?]+)$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # @return [Fixnum] priority  the priority, from 1 to 10.
    def self.priority()
      # higher than hubAspect but less than genomeAspect
      return 8
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
        # Provides: @groupId, @groupDesc, @groupAccessStr
        # Sets @statusName, @statusMsg; poor @statusName caught by get, put, etc.
        initStatus = initGroup()
      end
      return initStatus
    end

    # retrieve an existing hub
    # @todo TODO code reuse with hub and hubTrack resources
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

        # finally, with all validations passed, provide access to hubGenome
        hubGenomeRec = hubGenomeRecs.first
        hubGenomeEntity = BRL::Genboree::REST::Data::HubGenomeEntity.from_json(hubGenomeRec)
        @statusName = :OK
        @statusMsg = :OK
        hubGenomeEntity.setStatus(@statusName, @statusMsg)
        @statusName = configResponse(hubGenomeEntity) #sets @resp

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

        # try to parse payload into a HubGenomeEntity
        entity = parseRequestBodyForEntity("HubGenomeEntity")
        if(entity.is_a?(BRL::Genboree::GenboreeError) or entity == :"Unsupported Media Type" or 
           entity.nil?) 
          # then we were unable to parse for the entity
          @statusName = :"Unsupported Media Type"
          @statusMsg = "Unable to process the payload as a hub genome. Please provide a payload "\
                       "with the following fields: "\
                       "#{BRL::Genboree::REST::Data::HubGenomeEntity::SIMPLE_FIELD_NAMES.join(", ")}."
          raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        end

        # check if the provided hub genome name matches the resource path
        unless(entity.genome == @hubGenomeName)
          @statusName = :"Bad Request"
          @statusMsg = "The hub genome name you provided in the payload does not match the "\
                       "hub genome name specified in the resource path."
          raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        end

        # verify that the desired hub is present
        hubRecs = @dbu.selectHubByNameAndGroupName(@hubName, @groupName)
        if(hubRecs.empty? or hubRecs.nil?)
          @statusName = :"Not Found"
          @statusMsg = "The hub #{@hubName} was not found in the group #{@groupName}"
          err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          raise err
        end

        # then all validations have passed, insert/update the hubs genomes
        hubId = hubRecs.first['id']
        hubGenomeRecs = @dbu.selectHubGenomeByGenomeAndHubId(@hubGenomeName, hubId)
        if(hubGenomeRecs.nil? or hubGenomeRecs.empty?)
          if(hubRecs.nil?)
            # we still proceeded with insert, but an unforseen error occurred in the db 
            # select, log it
            msg = "Database access with @dbu.selectHubGenomeByGenomeAndHubId returned "\
                  "nil -- there may be an error in the track hub tables"
            $stderr.debugPuts(__FILE__, __method__, "DB_ERROR", msg)
          end
          # insert hub genome
          numHubGenomesInserted = @dbu.insertHubGenome(hubId, entity.genome, entity.description, 
                                                       entity.organism, entity.defaultPos, 
                                                       entity.orderKey)
          @statusName = :OK
          @statusMsg = "#{numHubGenomesInserted} hub genome(s) inserted"
        else
          # then hub already exists, update it
          hubId = hubRecs.first['id']
          cols2vals = {
            "hub_id" => hubId,
            "genome" => entity.genome,
            "description" => entity.description,
            "organism" => entity.organism,
            "defaultPos" => entity.defaultPos,
            "orderKey" => entity.orderKey
          }
          numHubGenomesUpdated = @dbu.updateHubGenomeById(id, cols2vals)
          @statusName = :OK
          @statusMsg = "#{numHubGenomesUpdated} hub genome(s) updated"
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

        # delete the hub genome
        hubId = hubRecs.first['id']
        numHubGenomesDeleted = @dbu.deleteHubGenomeByNameAndHubId(@hubGenomeName, hubId)
        @statusName = :OK
        @statusMsg = "#{numHubGenomesDeleted} hub genome(s) deleted!"
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
