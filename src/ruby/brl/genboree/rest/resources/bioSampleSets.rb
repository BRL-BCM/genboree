#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/tabularLayoutEntity'
require 'brl/genboree/rest/data/bioSampleSetEntity'
require 'brl/genboree/abstract/resources/bioSampleSet'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # BioSampleSets - exposes information about the saves tabular layouts for
  # a group / database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::BioSampleSetEntity
  # * BRL::Genboree::REST::Data::BioSampleSetEntityList
  # * BRL::Genboree::REST::Data::TextEntity
  # * BRL::Genboree::REST::Data::TextEntityList
  class BioSampleSets < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::BioSampleSet

    # INTERFACE: Map of what http methods this resource supports
    #   ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true }

    # TEMPLATE_URI: Constant to provide an example URI
    # for requesting this resource through the API
    TEMPLATE_URI = "/REST/v1/grp/{grp}/db/{db}/sampleSets"
    RESOURCE_DISPLAY_NAME = "SampleSets"
    RSRC_STRS = { :type => 'sampleSet', :label => 'sample set', :capital => 'Sample Set', :pluralType => 'sampleSets', :pluralLabel => 'sample sets', :pluralCap => 'Sample Sets' }
    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      # variables exposed from call to initGroupAndDatabase() Helper
      @dbName = @groupName = @groupId = @groupDesc = @groupAccessStr = @refseqRow = @refSeqId = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trks</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/bioSampleSets$ URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/(?:bioS|s)ampleSets$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      # Higher priority than grp/{grp}/db/{db}/
      return 4
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        # If format is tabbed, then that ALWAYS implies detailed in the response
        # (doesn't have to be explicitly set)
        @detailed = true if(@repFormat == :TABBED)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK)
          refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/sampleSet")
          # Get a list of all layouts for this db/group
          bioSampleSetRows = @dbu.selectAllBioSampleSets()
          bioSampleSetRows.sort! { |left, right| left['name'].downcase <=> right['name'].downcase }
          bodyData = BRL::Genboree::REST::Data::BioSampleSetEntityList.new(@connect)
          bioSampleSetRows.each { |row|
            entity = BRL::Genboree::REST::Data::BioSampleSetEntity.new(@connect, row['name'], row['state'], getAvpHash(@dbu, row['id']))
            entity.detailed = @detailed
            entity.dbu = @dbu
            entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
            entity.bioSampleRefBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/bioSample")
            bodyData << entity
          }
          @statusName = configResponse(bodyData)
          bioSampleSetRows.clear() unless (bioSampleSetRows.nil?)
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class BioSampleSets
end ; end ; end # module BRL ; module REST ; module Resources
