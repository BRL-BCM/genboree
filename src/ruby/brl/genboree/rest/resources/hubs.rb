require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/hubEntity'
require 'brl/genboree/rest/data/hubGenomeEntity'
require 'brl/genboree/rest/data/hubTrackEntity'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/countEntity'
require 'brl/genboree/abstract/resources/hub'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class Hubs < BRL::REST::Resources::GenboreeResource
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
      # look for hubs or hubs/{aspect}
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/hubs(?:$|/([^/\?]+)$)}
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
    # @return [Symbol] initStatus an HTTP status code name
    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @hubsAspect = (@uriMatchData[2].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[2])
        if(!@hubsAspect.nil? and !SUPPORTED_ASPECTS.key?(@hubsAspect))
          @statusName = initStatus = :"Bad Request"
          @statusMsg = "The request URI does not indicate an exposed aspect of the hubs "\
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

        # get whatever hubs are present, if any
        hubRecs = @dbu.selectHubsByGroupName(@groupName)

        if(@hubsAspect.nil?)
          # finally, with all validations passed, provide access to hubs
          if(@detailed == true and @repFormat != "hubSummary")
            # then respond hub, hubGenomes, hubTracks info
            fullHubs = hubRecordsToFullEntityList(hubRecs, @dbu)
            hubFullEntityList = BRL::Genboree::REST::Data::HubFullEntityList.from_json(fullHubs)
            @statusName = :OK
            @statusMsg = :OK
            hubFullEntityList.setStatus(@statusName, @statusMsg)
            @statusName = configResponse(hubFullEntityList) #sets @resp
          # TODO @repFormat = JSON but return only hub level information (not genome, tracks)
  #        elsif(@detailed == true and ???)
  #          # then respond with just the hub summary information
  #          hubEntityList = BRL::Genboree::REST::Data::HubEntityList.from_json(hubRecs)
  #          @statusName = :OK
  #          @statusMsg = :OK
  #          hubEntityList.setStatus(@statusName, @statusMsg)
  #          @statusName = configResponse(hubEntityList) #sets @resp
          else
            # then respond with just a list of hub names
            textEntityArray = hubRecs.collect{|hub| {"text" => hub['name']}}
            textEntityList = BRL::Genboree::REST::Data::TextEntityList.from_json(textEntityArray)
            @statusName = :OK
            @statusMsg = :OK
            textEntityList.setStatus(@statusName, @statusMsg)
            @statusName = configResponse(textEntityList) #sets @resp
          end
        else
          if(@hubsAspect == "count")
            count = (hubRecs.nil? ? 0 : hubRecs.length)
            countEntity = BRL::Genboree::REST::Data::CountEntity.new(@connect, count)
            @statusName = :OK
            @statusMsg = :OK
            countEntity.setStatus(@statusName, @statusMsg)
            @statusName = configResponse(countEntity) #sets @resp
          else
            if(SUPPORTED_ASPECTS.key?(@hubsAspect))
              @statusName = :"Internal Server Error"
              @statusMsg = "A developer for this resource added the aspect #{@hubsAspect} to the list of supported aspects "\
                "but didn't implement support for it!"
              err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
              raise err
            else
              # if here, validation in initOperation for supported aspects failed, give the same response though 
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Resource failed validation of aspects in #initOperation")
              @statusName = :"Bad Request"
              @statusMsg = "The request URI does not indicate an exposed aspect of the hubs "\
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
  end
end ; end; end
