#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/bioSampleEntity'
require 'brl/genboree/rest/data/countEntity'
require 'brl/genboree/abstract/resources/bioSample'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # BioSamplesAspect - exposes information about samples.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::CountEntity
  class BioSamplesAspect < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::BioSample
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }
    
    # Supported Aspects:
    SUPPORTED_ASPECTS = { 'count' => true }
    RSRC_TYPE = 'sampleAspect'
    
    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      # variables exposed from call to initGroupAndDatabase() Helper
      @dbName = @groupName = @groupId = @groupDesc = @groupAccessStr = @refseqRow = @refSeqId = nil
    end
    
    # INTERFACE: return a Regexp that will match a correctly formed URI for this service
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/samples</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/samples/([^/\?]+)$} # Look for /REST/v1/grp/{grp}/db/{db}/samples URIs
    end
    
    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 8 # less than entityLists
    end

    def initOperation()
      initStatus = super()
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @dbName = Rack::Utils.unescape(@uriMatchData[2])
      @aspect = (@uriMatchData[3].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[3])
      if(@aspect.nil? or !SUPPORTED_ASPECTS.has_key?(@aspect))
        initStatus = @statusName = :'Bad Request'
        @statusMsg = "ERROR: Samples request URI doesn't indicate an exposed resource or is otherwise incorrect."
      end
      if(initStatus == :OK)
        initStatus = initGroupAndDatabase()
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        if(@aspect == 'count')
	  samplesCount = @dbu.countBioSamples()
	  if(samplesCount.empty?)
	    initStatus = @statusName = :'Not Found'
	    @statusMsg = "ERROR: Query on the database #{@dbName.inspect} in user group #{@groupName.inspect} failed."
	  end
      	  entity = BRL::Genboree::REST::Data::CountEntity.new(@connect, samplesCount[0][0])
      	  @statusName = configResponse(entity)
        end
      else
        @statusName = initStatus
      end
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
 
  end # class BioSamplesAspect
end ; end ; end # module BRL ; module REST ; module Resources
