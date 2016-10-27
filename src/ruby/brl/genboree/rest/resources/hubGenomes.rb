require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/hubEntity'
require 'brl/genboree/abstract/resources/hub'
require 'brl/genboree/rest/data/countEntity'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class HubGenomes < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::Hub
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }
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
      # look for hub/{hub_name}/genomes
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/hub/([^/\?]+)/genomes(?:$|/([^/\?]+)$)}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # @return [Fixnum] priority  the priority, from 1 to 10.
    def self.priority()
      # more priority than hubAspect
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
        @hubGenomesAspect = (@uriMatchData[3].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[3])
        if(!@hubGenomesAspect.nil? and !SUPPORTED_ASPECTS.key?(@hubGenomesAspect))
          @statusName = initStatus = :"Bad Request"
          @statusMsg = "The request URI does not indicate an exposed aspect of the hub genomes "\
                       "resource. Supported aspects: #{SUPPORTED_ASPECTS.keys().join(", ")}."
        end
        # Provides: @groupId, @groupDesc, @groupAccessStr
        # Sets @statusName, @statusMsg; poor @statusName caught by get, put, etc.
        initStatus = initGroup() if(initStatus == :OK)
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

        # get hubGenomes in the hub, if any exist
        hubId = hubRecs.first['id']
        hubGenomeRecs = @dbu.selectHubGenomesByHubId(hubId)

        if(@hubGenomesAspect.nil?)
          # finally, with all validations passed, provide access to hub genomes
          hubGenomeEntityList = BRL::Genboree::REST::Data::HubGenomeEntityList.from_json(hubGenomeRecs)
          @statusName = :OK
          @statusMsg = :OK
          hubGenomeEntityList.setStatus(@statusName, @statusMsg)
          @statusName = configResponse(hubGenomeEntityList) #sets @resp
        else
          if(@hubGenomesAspect == "count")
            count = (hubGenomeRecs.nil? ? 0 : hubGenomeRecs.length)
            countEntity = BRL::Genboree::REST::Data::CountEntity.new(@connect, count)
            @statusName = :OK
            @statusMsg = :OK
            countEntity.setStatus(@statusName, @statusMsg)
            @statusName = configResponse(countEntity) #sets @resp
          else
            if(SUPPORTED_ASPECTS.key?(@hubGenomesAspect))
              @statusName = :"Internal Server Error"
              @statusMsg = "A developer for this resource added the aspect #{@hubGenomesAspect} to the list of supported aspects "\
                "but didn't implement support for it!"
              err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
              raise err
            else
              # if here, validation in initOperation for supported aspects failed, give the same response though 
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Resource failed validation of aspects in #initOperation")
              @statusName = :"Bad Request"
              @statusMsg = "The request URI does not indicate an exposed aspect of the hub genomes "\
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
