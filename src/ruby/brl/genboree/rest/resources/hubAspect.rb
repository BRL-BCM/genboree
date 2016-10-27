require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/hubEntity'
require 'brl/genboree/abstract/resources/hub'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class HubAspect < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::Hub
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :head => true }

    SUPPORTED_ASPECTS = { "hub.txt" => true, "genomes.txt" => true }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # @return nil
    def cleanup()
      super()
    end

    # @return [Regexp] match a correctly formed URI for this resource
    def self.pattern()
      # look for /hub/{hub_name}/aspect
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/hub/([^/\?]+)/([^/\?]+)$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # @return priority [Fixnum] the priority, from 1 to 10.
    def self.priority()
      # higher priority than hub, but less than hub genome
      return 7
    end

    # validate authorization to connect to resource via parent and
    # perform common operations regardless of the http request method
    # @return [Symbol] initStatus  an HTTP status code name
    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @hubName = Rack::Utils.unescape(@uriMatchData[2])
        @hubAspect = Rack::Utils.unescape(@uriMatchData[3])
        # Provides: @groupId, @groupDesc, @groupAccessStr
        # Sets @statusName, @statusMsg; poor @statusName caught by get, put, etc.
        initStatus = initGroup()

        # prepare error message to be handled by reqMethod: get, head, etc.
        unless(SUPPORTED_ASPECTS.key?(@hubAspect))
          @statusName = initStatus = :"Bad Request"
          @statusMsg = "The request URI does not indicate an exposed aspect of the hub "\
                       "resource. Supported aspects: #{SUPPORTED_ASPECTS.keys().join(", ")}."
        end
      end
      return initStatus
    end

    # @todo TODO ALL of this is shared with the hub get except for overriding the reqFormat
    # to be UCSC_HUB
    def get()
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

        if(@hubAspect == "hub.txt")
          # finally, with all validations passed, provide access to hub.txt, which
          # is the UCSC_HUB representation of a hub, regardless of the responseFormat provided
          # in the query string 
          @responseFormat = :UCSC_HUB
          hubEntity = BRL::Genboree::REST::Data::HubEntity.from_json(hubRecs.first)
          @statusName = :OK
          @statusMsg = :OK
          hubEntity.setStatus(@statusName, @statusMsg)
          @statusName = configResponse(hubEntity) #sets @resp

        elsif(@hubAspect == "genomes.txt")
          # or, provide access to genomes.txt, which is the UCSC_HUB representation of
          # a hubGenomeEntityList aka an alias for the /hub/{hub}/genomes resource with
          # a particular response format
          @responseFormat = :UCSC_HUB
          # hub genomes simply accesses @uriMatchData via [] and unescapes [1] and [2]
          mockMatchData = [nil, Rack::Utils.escape(@groupName), Rack::Utils.escape(@hubName)]
          hubGenomesResource = BRL::REST::Resources::HubGenomes.new(@req, @resp, mockMatchData)
          hubGenomesResource.responseFormat = @responseFormat
          @resp = hubGenomesResource.get()
          @statusName = hubGenomesResource.statusName
          @statusMsg = hubGenomesResource.statusMsg

        else
          @statusName = :"Internal Server Error"
          @statusMsg = "An editor of the code for this resource added the aspect "\
                       "#{@hubAspect} to the list of supported aspects without providing "\
                       "support for it!"
          err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          raise err
        end

        # add additional headers expected by UCSC, if needed
        # these headers were needed for and copied from trackBigBed
        #@resp['Content-Type'] = 'application/octet-stream'
        #@resp['Accept-Ranges'] = 'bytes'
        #@resp.status = HTTP_STATUS_NAMES[:'Partial Content']
        #@resp['Content-Length'] = File.size(fileNameFull).to_s
        #@resp['Last-Modified'] = File.mtime(fileNameFull).strftime("%a, %d %b %Y %H:%M:%S %Z")

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

    # From get, remove response body and set more header in addition to the standard ones
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
  end
end ; end; end
