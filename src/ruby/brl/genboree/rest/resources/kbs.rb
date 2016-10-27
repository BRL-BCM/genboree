#!/usr/bin/env ruby
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/kbDocEntity'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  # KbCollections - exposes information about the knowledgebases within a group
  # (currently just the names of the kbs within the group).
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::KbDocEntityList
  # * BRL::Genboree::REST::Data::KbDocEntity
  class Kbs < BRL::REST::Resources::GenboreeResource
    # @return [Hash{Symbol=>Object}] Map of what http methods this resource supports ( @{ :get => true, :put => false }@, etc } ).
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'kbs'

    # @api RestAPI INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    #   cleanup that might save memory and aid GC. Their version should call {#super}
    #   so any parent {#cleanup} will be done also.
    # @return [nil]
    def cleanup()
      super()
      @groupId = @groupName = @groupDesc = nil
    end

    # @api RestAPI INTERFACE. return a {Regexp} that will match a correctly formed URI for this service
    #   The pattern will be applied against the URI's _path_.
    # @returns [Regexp]
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kbs}
    end

    # @api RestAPI return integer from 1 to 10 that indicates whether the regexp/service is
    #   highly specific and should be examined early on, or whether it is more generic and
    #   other services should be matched for first.
    # @return [Fixnum] The priority, from 1 t o 10.
    def self.priority()
      return 4
    end

    # Perform common set up needed by all requests. Extract needed information,
    #   set up access to parent group/database/etc resource info, etc.
    # @return [Symbol] a {Symbol} corresponding to a standard HTTP response code [official English text, not the number]
    #   indicating success/ok (@:OK@), some other kind of success, or some kind of failure.
    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        # This function will set @groupId if it exists, return value is :OK or :'Not Found'
        initStatus = initGroup()
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    def get()
      $stderr.debugPuts(__FILE__, __method__, ">>>HERE", "uriMatchData: #{@uriMatchData.inspect}")
      initStatus = initOperation()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        initStatus = initGroup()
        if(initStatus == :OK)
          # Get kbs in the group:
          if(@groupAccessStr == 'p')
            # Public type access. Include only the 'public unlocked' kbs?
            # - Can only see LIST of public AND unlocked kbs (not just public ones)
            # - Access to a known kb is allowed if it is just/only public though
            kbRows = @dbu.selectPublicUnlockedKbsByGroupId(@groupId)
            $stderr.debugPuts(__FILE__, __method__, "+++HERE", "found public-unlocked KBs in #{@groupName.inspect} (#{@groupId.inspect}):\n\n#{kbRows ? JSON.pretty_generate(kbRows) : "NO KB ROWS!"}\n\n")
          else
            # Regular user group database auth access
            kbRows = @dbu.selectKbsByGroupId(@groupId)
            $stderr.debugPuts(__FILE__, __method__, "+++HERE", "found private KBs in #{@groupName.inspect} (#{@groupId.inspect}):\n\n#{kbRows ? JSON.pretty_generate(kbRows) : "NO KB ROWS!"}\n\n")
          end
          kbRows ||= []

          # Sort by user's kb name
          kbRows.sort! {|aa,bb| retVal = (aa['name'].downcase <=> bb['name'].downcase) ; (retVal = (aa['name'] <=> bb['name'])) if(retVal == 0) ; retVal }
          # Prep response respresentation
          bodyData = BRL::Genboree::REST::Data::KbDocEntityList.new(false)
          kbRows.each { |row|
            kbName = row['name']
            # @todo Do we want ability to provide more detailed info about kbs? (@detailed=true)
            #   If so, need a detailed Kb entity of some kind as well as this simple name list

            # Simple list of kbs in the group
            doc = BRL::Genboree::KB::KbDoc.new()
            doc.setPropVal("text", kbName)
            entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
            bodyData << entity
          }
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Gathered data to send:\n\n#{JSON.pretty_generate(bodyData, { :max_nesting => 5000 })}\n\n")
          @statusName = configResponse(bodyData)
          kbRows.clear() if(kbRows)
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class Kbs < BRL::REST::Resources::GenboreeResource
end ; end ; end # module BRL ; module REST ; module Resources
