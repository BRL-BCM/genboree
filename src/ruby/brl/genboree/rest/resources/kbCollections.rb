#!/usr/bin/env ruby
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/kbDocEntity'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  # KbCollections - exposes information about the collections within within a GenboreKB knowledgebase
  # (currently just the names of the kbs within the group).
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::KbDocEntityList
  # * BRL::Genboree::REST::Data::KbDocEntity
  class KbCollections < BRL::REST::Resources::GenboreeResource

    # @return [Hash{Symbol=>Object}] Map of what http methods this resource supports ( @{ :get => true, :put => false }@, etc } ).
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'kbCollections'

    # @api RestAPI INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    #   cleanup that might save memory and aid GC. Their version should call {#super}
    #   so any parent {#cleanup} will be done also.
    # @return [nil]
    def cleanup()
      super()
      @groupId = @groupName = @groupDesc = nil
      @mongoKbDb = @mongoDbrcRec = @kbId = @kbName = @kbDbName = nil
    end

    # @api RestAPI INTERFACE. return a {Regexp} that will match a correctly formed URI for this service
    #   The pattern will be applied against the URI's _path_.
    # @returns [Regexp]
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/colls$}
    end

    # @api RestAPI return integer from 1 to 10 that indicates whether the regexp/service is
    #   highly specific and should be examined early on, or whether it is more generic and
    #   other services should be matched for first.
    # @return [Fixnum] The priority, from 1 t o 10.
    def self.priority()
      return 5
    end

    # Perform common set up needed by all requests. Extract needed information,
    #   set up access to parent group/database/etc resource info, etc.
    # @return [Symbol] a {Symbol} corresponding to a standard HTTP response code [official English text, not the number]
    #   indicating success/ok (@:OK@), some other kind of success, or some kind of failure.
    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @kbName = Rack::Utils.unescape(@uriMatchData[2])
        @collType = ( @nvPairs['type'] ? @nvPairs['type'].to_sym : :data )
        # This function will set @groupId if it exists, return value is :OK or :'Not Found'
        initStatus = initGroupAndKb()
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        # @todo if public or subscriber, can get info
        if(READ_ALLOWED_ROLES[@groupAccessStr])
          if(@collType == :data or @collType == :internal or @collType == :all)
            # Prep response respresentation
            bodyData = BRL::Genboree::REST::Data::KbDocEntityList.new(false)
            if(@detailed)
              # Get collections in @kbName
              colls = @mongoKbDb.collections(@collType, :metadata)
              colls.sort { |aa,bb|
                xx = aa.getPropVal('name')
                yy = bb.getPropVal('name')
                retVal = (xx.downcase <=> yy.downcase)
                retVal = (xx <=> yy) if(retVal == 0)
                retVal
              }
              colls.each { |coll|
                doc = BRL::Genboree::KB::KbDoc.new(coll)
                entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
                bodyData << entity
              }
            else # just the list of collections names
              # Get collections in @kbName
              colls = @mongoKbDb.collections(@collType, :names)
              colls.sort { |aa,bb| retVal = (aa.downcase <=> bb.downcase) ; retVal = (aa <=> bb) if(retVal == 0) ; retVal }
              colls.each { |coll|
                doc = BRL::Genboree::KB::KbDoc.new( { "text" => { "value" => coll } } )
                entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
                bodyData << entity
              }
            end
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Gathered data to send:\n\n#{JSON.pretty_generate(bodyData)}\n\n")
            @statusName = configResponse(bodyData)
            colls.clear() if(colls)
          else
            @statusName = :'Bad Request'
            @statusMsg = "BAD_REQUEST: No such collection type #{@nvPairs['type'].inspect}."
          end
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def put()
      # @todo No payload (use @kbName)
      # @todo Error if already exists
      # @todo Must have permission.
    end

    def delete()
      # @todo No payload
      # @todo Must have permission
    end
  end # class KbCollections < BRL::REST::Resources::GenboreeResource
end ; end ; end # module BRL ; module REST ; module Resources
