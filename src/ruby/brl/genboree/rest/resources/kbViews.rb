#!/usr/bin/env ruby
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/kb/helpers/viewsHelper'


#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  class KbViews < BRL::REST::Resources::GenboreeResource
    # @return [Hash{Symbol=>Object}] Map of what http methods this resource supports ( @{ :get => true, :put => false }@, etc } ).
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'kbViews'
    
    # @api RestAPI INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    #   cleanup that might save memory and aid GC. Their version should call {#super}
    #   so any parent {#cleanup} will be done also.
    # @return [nil]
    def cleanup()
      super()
      @groupId = @groupName = @groupDesc = nil
      @mongoKbDb = @mongoDbrcRec = @kbId = @kbName = @kbDbName = @collName = @docName = nil
    end

    # @api RestAPI INTERFACE. return a {Regexp} that will match a correctly formed URI for this service
    #   The pattern will be applied against the URI's _path_.
    # @returns [Regexp]
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/views$}
    end

    # @api RestAPI return integer from 1 to 10 that indicates whether the regexp/service is
    #   highly specific and should be examined early on, or whether it is more generic and
    #   other services should be matched for first.
    # @return [Fixnum] The priority, from 1 t o 10.
    def self.priority()
      return 7
    end

    # Perform common set up needed by all requests. Extract needed information,
    #   set up access to parent group/database/etc resource info, etc.
    # @return [Symbol] a {Symbol} corresponding to a standard HTTP response code [official English text, not the number]
    #   indicating success/ok (@:OK@), some other kind of success, or some kind of failure.
    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName  = Rack::Utils.unescape(@uriMatchData[1]).to_s.strip
        @kbName     = Rack::Utils.unescape(@uriMatchData[2]).to_s.strip
        initStatus = initGroupAndKb()
        @type = @nvPairs.key?('type') ? @nvPairs['type'] : nil
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
        viewsHelper = @mongoKbDb.viewsHelper()
        if(READ_ALLOWED_ROLES[@groupAccessStr])
          bodyData = BRL::Genboree::REST::Data::KbDocEntityList.new(@connect)
          BRL::Genboree::KB::Helpers::ViewsHelper::IMPLICIT_VIEWS_DEFS.each_key { |view|
            doc = nil
            if(@detailed)
              doc = viewsHelper.getImplicitView(view)                    
            else
              doc = BRL::Genboree::KB::KbDoc.new( { "text" => { "value" => view } } )
            end
            entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
            bodyData << entity
          }
          viewsHelper = @mongoKbDb.viewsHelper()
          selector = {}
          if(@type and @type == 'flat')
            selector['name.properties.type.value'] = 'flat'
          end
          viewsCursor = viewsHelper.coll.find(selector)
          docs = []
          docIds = []
          if(viewsCursor and viewsCursor.is_a?(Mongo::Cursor) and viewsCursor.count > 0)
            viewsCursor.rewind!
            viewsCursor.each {|doc|
              docs << BRL::Genboree::KB::KbDoc.new(doc)
              docIds << doc['_id']
            }
            docs.sort { |aa,bb|
              xx = aa.getPropVal('name')
              yy = bb.getPropVal('name')
              retVal = (xx.downcase <=> yy.downcase)
              retVal = (xx <=> yy) if(retVal == 0)
              retVal
            }
          end
          docs.each {|doc|
            if(@detailed)
              entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
            else
              entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, { "text" => { "value" => doc.getPropVal('name')} })
            end
            bodyData << entity
          }
          if(!docIds.empty?)
            bodyData.metadata = viewsHelper.getMetadata(docIds, "kbViews")
          end
          @statusName = configResponse(bodyData)
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class KbViews
end ; end ; end # module BRL ; module REST ; module Resources
