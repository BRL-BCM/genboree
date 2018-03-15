#!/usr/bin/env ruby
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/kb/helpers/templatesHelper'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::KbDocEntityList
  # * BRL::Genboree::REST::Data::KbDocEntity
  class KbTemplates < BRL::REST::Resources::GenboreeResource

    # @return [Hash{Symbol=>Object}] Map of what http methods this resource supports ( @{ :get => true }@, etc } ).
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'kbTemplates'
    SUPPORTED_ASPECTS = {  }
    # @api RestAPI INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    #   cleanup that might save memory and aid GC. Their version should call {#super}
    #   so any parent {#cleanup} will be done also.
    # @return [nil]
    def cleanup()
      super()
      @groupId = @groupName = @groupDesc = nil
      @mongoKbDb = @mongoDbrcRec = @kbId = @kbName = @kbDbName = @collName = nil
    end

    # @api RestAPI INTERFACE. return a {Regexp} that will match a correctly formed URI for this service
    #   The pattern will be applied against the URI's _path_.
    # @returns [Regexp]
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/templates$}
    end

    # @api RestAPI return integer from 1 to 10 that indicates whether the regexp/service is
    #   highly specific and should be examined early on, or whether it is more generic and
    #   other services should be matched for first.
    # @return [Fixnum] The priority, from 1 t o 10.
    def self.priority()
      return 6
    end

    # Perform common set up needed by all requests. Extract needed information,
    #   set up access to parent group/database/etc resource info, etc.
    # @return [Symbol] a {Symbol} corresponding to a standard HTTP response code [official English text, not the number]
    #   indicating success/ok (@:OK@), some other kind of success, or some kind of failure.
    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName  = Rack::Utils.unescape(@uriMatchData[1])
        @kbName     = Rack::Utils.unescape(@uriMatchData[2])
        @collName   = Rack::Utils.unescape(@uriMatchData[3])
        initStatus = initGroupAndKb()
        @docIdentAsRootOnly = false
        if(@nvPairs.key?('docIdentAsRootOnly') and @nvPairs['docIdentAsRootOnly'] =~ /^(?:true|yes)/i)
          @docIdentAsRootOnly = true       
        end
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
          collMetadataHelper = @mongoKbDb.collMetadataHelper()
          coll = collMetadataHelper.metadataForCollection(@collName)
          if(coll and !coll.empty?)
            # Get a modelsHelper to aid us
            templatesHelper = @mongoKbDb.templatesHelper()
            # Get all the template docs 
            cursor = templatesHelper.coll.find( {  } )
            bodyData = BRL::Genboree::REST::Data::KbDocEntityList.new(@connect)
            docFound = false
            docIds = []
            cursor.each {|dd|
              kbDoc = BRL::Genboree::KB::KbDoc.new(dd)
              next if(kbDoc.getPropVal('id.coll') != @collName)
              if(@docIdentAsRootOnly) # We only want templates whose 'root' has been set as the document identifer
                rootProp = kbDoc.getPropVal('id.root')
                next if(rootProp.split(".").size > 1)
              end
              docIds << dd['_id']
              if(@detailed)
                bodyData << BRL::Genboree::REST::Data::KbDocEntity.new(@connect, kbDoc)
              else
                bodyData << BRL::Genboree::REST::Data::KbDocEntity.new(@connect, { "text" => { "value" => kbDoc.getPropVal('id') } })
              end
              docFound = true
            }
            if(docFound)
              if(!docIds.empty?)
                metadata = templatesHelper.getMetadata(docIds, 'kbTemplates')
                bodyData.metadata = metadata
              end
              @statusName = configResponse(bodyData)
            else
              @statusName = :'Not Found'
              @statusMsg = "NO_TEMPLATES: There are no templates for this collection with the requested parameters."
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_COLL: there is no document collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect}."
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

    
    
    
    
    
    
  end # class KbModel < BRL::REST::Resources::GenboreeResource
end ; end ; end # module BRL ; module REST ; module Resources
