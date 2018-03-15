#!/usr/bin/env ruby
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/rest/resources/kbDocs'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/kb/validators/transformValidator'
require 'brl/genboree/kb/helpers/transformsHelper'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  class KbTransform < BRL::REST::Resources::GenboreeResource
    # @return [Hash{Symbol=>Object}] Map of what http methods this resource supports ( @{ :get => true, :put => false }@, etc } ).
    HTTP_METHODS = {:get => true, :put => true, :delete => true}
    RSRC_TYPE = 'kbTransform'
    
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
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/(?:trRulesDoc|transform)/([^/\?]+)$}
    end

    # @api RestAPI return integer from 1 to 10 that indicates whether the regexp/service is
    #   highly specific and should be examined early on, or whether it is more generic and
    #   other services should be matched for first.
    # @return [Fixnum] The priority, from 1 to 10.
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
        @groupName              = Rack::Utils.unescape(@uriMatchData[1]).to_s.strip
        @kbName                 = Rack::Utils.unescape(@uriMatchData[2]).to_s.strip
        @transformationName     = Rack::Utils.unescape(@uriMatchData[3]).to_s.strip
        @collName = BRL::Genboree::KB::Helpers::TransformsHelper::KB_CORE_COLLECTION_NAME
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
        collName = BRL::Genboree::KB::Helpers::TransformsHelper::KB_CORE_COLLECTION_NAME
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        transformsHelper = @mongoKbDb.transformsHelper()
        unless(transformsHelper.coll.nil?)
          if(READ_ALLOWED_ROLES[@groupAccessStr])
            entity = nil
            begin
              mgCursor = transformsHelper.coll.find({ "Transformation.value" =>  @transformationName })
              if(mgCursor and mgCursor.is_a?(Mongo::Cursor))
                if(mgCursor.count == 1) # should always be one
                  mgCursor.rewind! # resets the cursor to its unevaluated state
                  doc = BRL::Genboree::KB::KbDoc.new(mgCursor.first)
                  transDocId = doc['_id']
                  entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
                  entity.metadata = transformsHelper.getMetadata(transDocId, collName)
                  @statusName = configResponse(entity)
                else # cursor size should be zero
                  @statusName = :'Not Found'
                  @statusMsg = "NO_TRANSFORMATION_DOCUMENT: There is no transformation document, #{@transformationName.inspect} under #{@kbName} KB."
                end
              else
                @statusName = :'Internal Server Error'
                @statusMsg = "INTERNAL_SERVER_ERROR: #{err}"
              end
            rescue => err
              @statusName = :'Internal Server Error'
              @statusMsg = "INTERNAL_SERVER_ERROR: #{err}"
              $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
            end
          else
            @statusName = :Forbidden
            @statusMsg = "You do not have sufficient permissions to perform this operation."
          end
        else
          @statusName = :'Not Found'
          @statusMsg = "NO_TRANSFORMATION_COLL: can't get transformation rules document named #{@transformationName.inspect} because appears to be no data collection #{collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} . #{collName} is a GenboreeKB internal collection and absence of this collection means that the #{@kbName.inspect} is an outdated GenboreeKB."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    
    
    # Process a PUT operation on this resource.
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    def put()
      initStatus = initOperation()
      if(initStatus == :OK)
        collName = BRL::Genboree::KB::Helpers::TransformsHelper::KB_CORE_COLLECTION_NAME
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        transformsHelper = @mongoKbDb.transformsHelper()
        unless(transformsHelper.coll.nil?)
          if(WRITE_ALLOWED_ROLES[@groupAccessStr])
            payload = parseRequestBodyForEntity('KbDocEntity')
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Payload: #{payload.inspect}")
            if(payload.nil? or (payload.is_a?(BRL::Genboree::REST::Data::KbDocEntity) and payload.doc and payload.doc.empty?))
              @statusName = :'Not Implemented'
              @statusMsg = "EMPTY_DOC: The transformation document is empty."
            elsif(payload == :'Unsupported Media Type')
              @statusName = :'Unsupported Media Type'
              @statusMsg = "BAD_TRANSFORMATION_DOC: The transformation document is not valid. Either the document is empty or does not follow the property based document structure. This is not allowed."
            else
              begin
                # Try to validate the payload against the model document 
                validator = BRL::Genboree::KB::Validators::TransformValidator.new()
                transformationDoc = payload.doc
                isValid = validator.validate(transformationDoc)
                if(isValid)
                  kbDocTransform = BRL::Genboree::KB::KbDoc.new(transformationDoc)
                  if(kbDocTransform.getPropVal('Transformation') != @transformationName)
                    @statusName = :"Bad Request"
                    @statusMsg = "BAD_REQUEST: Name of the transformation document in the payload does not match the name of the transformation provided in the resource path (URL)."
                  else
                    cursor = transformsHelper.coll.find({ 'Transformation.value' => @transformationName })
                    transformDoc = nil
                    cursor.each {|dd|
                      transformDoc = dd
                    }
                    if(transformDoc and !transformDoc.empty?)
                      transformationDoc['_id'] = transformDoc["_id"]
                      workingRevisionMatched = true
                      if(@workingRevision)
                        workingRevisionMatched = transformsHelper.matchWorkingRevisionWithCurrentRevision(@workingRevision, transformDoc["_id"], collName)
                      end
                      if(workingRevisionMatched)
                        transformsHelper.save(transformationDoc, @gbLogin)
                        bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, transformationDoc)
                        configResponse(bodyData)
                        @statusName = :'Moved Permanently'
                        @statusMsg = "UPDATED_TRANSFORMATION_DOC: The transformation document with the id: #{@transformationName.inspect}  was updated."
                      else
                        @statusName = :"Conflict"
                        @statusMsg = " WORKING_COPY_OUT_OF_DATE: Your working copy of the document is out-of-date. The document has been changed since you last retrieved it. To prevent loss of new content or the saving of deleted content, your document change has been rejected."                        
                      end
                    else
                      transformsHelper.save(transformationDoc, @gbLogin)
                      bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, transformationDoc)
                      configResponse(bodyData)
                      @statusName = :'Created'
                      @statusMsg = "NEW_TRANSFORMATION_DOC_CREATED: Your new transformation document document was created."
                    end
                  end
                else
                  if( validator.respond_to?(:buildErrorMsgs) )
                    errors = validator.buildErrorMsgs()
                  else
                    errors = validator.validationErrors
                  end
                  @statusName = :'Unsupported Media Type'
                  @statusMsg = "BAD_TRASFORMATION_DOC: The transformation document does not follow the specification of the transformation model:\n\n#{errors.join("\n")}"
                end
              rescue => err
                @statusName = :'Internal Server Error'
                @statusMsg = "INTERNAL_SERVER_ERROR: #{err}"
                $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
              end
            end
          else
            @statusName = :Forbidden
            @statusMsg = "You do not have sufficient permissions to perform this operation."
          end
        else
          @statusName = :'Not Found'
          @statusMsg = "NO_TRANSFORMATION_COLL: can't put transformation rules document named #{@transformationName.inspect} because appears to be no data collection #{collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} . #{collName} is a GenboreeKB internal collection and absence of this collection means that the #{@kbName.inspect} is an outdated GenboreeKB."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
    
    # Process a DELETE operation on this resource.
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        collName = BRL::Genboree::KB::Helpers::TransformsHelper::KB_CORE_COLLECTION_NAME
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        transformsHelper = @mongoKbDb.transformsHelper()
        unless(transformsHelper.coll.nil?)
          if(WRITE_ALLOWED_ROLES[@groupAccessStr])
            begin
              entity = nil
              mgCursor = transformsHelper.coll.find({ "Transformation.value" => @transformationName })
              if(mgCursor and mgCursor.is_a?(Mongo::Cursor))
                if(mgCursor.count == 1)
                  mgCursor.rewind!
                  origDoc = mgCursor.first
                  doc = BRL::Genboree::KB::KbDoc.new(origDoc.deep_clone)
                  workingRevisionMatched = true
                  if(@workingRevision)
                    workingRevisionMatched = transformsHelper.matchWorkingRevisionWithCurrentRevision(@workingRevision, origDoc["_id"], collName)
                  end
                  if(workingRevisionMatched)
                    entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
                    transformsHelper.coll.remove( { "Transformation.value" => @transformationName } )
                    @statusMsg = "DELETED: The transformation document: #{@transformationName} was deleted from the database."
                    @statusName = :OK
                    configResponse(entity)
                  else
                    @statusName = :"Conflict"
                    @statusMsg = " WORKING_COPY_OUT_OF_DATE: Your working copy of the document is out-of-date. The document has been changed since you last retrieved it. To prevent loss of new content or the saving of deleted content, your document change has been rejected."                        
                  end
                else
                  @statusName = :'Not Found'
                  @statusMsg = "NO_TRANSFORMATION_DOCUMENT: There is no transformation document #{@transformationName.inspect} under #{@kbName} KB."
                end
              else
                @statusName = :'Internal Server Error'
                @statusMsg = "DEL_TRANFORMATION_DOC_FAILED: Deletion of the transformation document, #{@transformationName.inspect} failed. Check: #{err}"
              end
            rescue => err
              @statusName = :'Internal Server Error'
              @statusMsg = "INTERNAL_SERVER_ERROR: #{err}"
            end
          else
            @statusName = :Forbidden
            @statusMsg = "You do not have sufficient permissions to perform this operation."
          end
        else
         @statusName = :'Not Found'
         @statusMsg = "NO_TRANSFORMATION_COLL: can't delete transformation rules document named #{@transformationName.inspect} because appears to be no data collection #{collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} . #{collName} is a GenboreeKB internal collection and absence of this collection means that the #{@kbName.inspect} is an outdated GenboreeKB."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
       
  end # class KbTransform
end ; end ; end # module BRL ; module REST ; module Resources
