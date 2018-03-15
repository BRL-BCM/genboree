#!/usr/bin/env ruby
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/rest/resources/kbDocs'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/kb/validators/queryValidator'
require 'brl/genboree/kb/helpers/queriesHelper'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  class KbQuery < BRL::REST::Resources::GenboreeResource
    # @return [Hash{Symbol=>Object}] Map of what http methods this resource supports ( @{ :get => true, :put => false }@, etc } ).
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    RSRC_TYPE = 'kbQuery'
    
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
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/query/([^/\?]+)$}
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
        @queryName     = Rack::Utils.unescape(@uriMatchData[3]).to_s.strip
        @collName = BRL::Genboree::KB::Helpers::QueriesHelper::KB_CORE_COLLECTION_NAME
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
        collName = BRL::Genboree::KB::Helpers::QueriesHelper::KB_CORE_COLLECTION_NAME
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        queriesHelper = @mongoKbDb.queriesHelper()
        unless(queriesHelper.coll.nil?)
          if(READ_ALLOWED_ROLES[@groupAccessStr])
            entity = nil
            begin
              queryCursor = queriesHelper.coll.find({ "Query.value" => @queryName})
              if(queryCursor and queryCursor.is_a?(Mongo::Cursor) and queryCursor.count > 0) # Should be just one
                queryCursor.rewind!
                queryCursor.each { |doc|
                  doc = BRL::Genboree::KB::KbDoc.new( doc )
                  queryDocId = doc['_id']
                  entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)  
                  entity.metadata = queriesHelper.getMetadata(queryDocId, "kbQueries")
                }
                @statusName = configResponse(entity) 
              else
                # Check to see if query is one of the 'implicit' queries
                if(BRL::Genboree::KB::Helpers::QueriesHelper::IMPLICIT_QUERIES_DEFS.key?(@queryName))
                  doc = BRL::Genboree::KB::KbDoc.new( { "text" => { "value" => @queryName } } )
                  entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
                  @statusName = configResponse(entity) if(!entity.nil?)
                else
                  @statusName = :'Not Found'
                  @statusMsg = "NO_QUERY: There is no query #{@queryName.inspect} under #{@kbName} KB."
                end
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
          @statusMsg = "NO_QUERIES_COLL: can't get queries document named #{@queryName.inspect} because appears to be no collection #{collName.inspect} in the #{@kbName.inspect} GenboreeKB, within group #{@groupName.inspect} . #{collName} is a GenboreeKB internal collection and absence of this collection means that the #{@kbName.inspect} is an outdated GenboreeKB."
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
        collName = BRL::Genboree::KB::Helpers::QueriesHelper::KB_CORE_COLLECTION_NAME
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        queriesHelper = @mongoKbDb.queriesHelper()
        unless(queriesHelper.coll.nil?)
          if(WRITE_ALLOWED_ROLES[@groupAccessStr])
            payload = parseRequestBodyForEntity('KbDocEntity')
            if(payload.nil? or (payload.is_a?(BRL::Genboree::REST::Data::KbDocEntity) and payload.doc and payload.doc.empty?))
              @statusName = :'Not Implemented'
              @statusMsg = "Creating empty queries is not supported currently."
            elsif(payload == :'Unsupported Media Type')
              @statusName = :'Unsupported Media Type'
              @statusMsg = "BAD_QUERY: The query document is not valid. Either the document is empty or does not follow the property based document structure. This is not allowed."
            else
              begin
                # Try to validate the payload against the model document for queries
                validator = BRL::Genboree::KB::Validators::QueryValidator.new()
                queryDoc = payload.doc
                isValid = validator.validate(queryDoc)
                if(isValid)
                  # Make sure the name of the query in the payload matches the name in the URL
                  kbDocQuery = BRL::Genboree::KB::KbDoc.new(queryDoc)
                  if(kbDocQuery.getPropVal('Query') != @queryName)
                    @statusName = :"Bad Request"
                    @statusMsg = "BAD_REQUEST: The name of the query in the payload does not match the name of the query provided in the resource path (URL)."
                  else
                    # Updating one of the 'implicit queries' is not allowed
                    if(!BRL::Genboree::KB::Helpers::QueriesHelper::IMPLICIT_QUERIES_DEFS.key?(@queryName)) 
                      cursor = queriesHelper.coll.find({ 'Query.value' => @queryName })
                      qDoc = nil
                      cursor.each {|dd|
                        qDoc = dd
                      }
                      # Existing query document
                      if(qDoc and !qDoc.empty?)
                        queryDoc['_id'] = qDoc["_id"]
                        workingRevisionMatched = true
                        if(@workingRevision)
                          workingRevisionMatched = queriesHelper.matchWorkingRevisionWithCurrentRevision(@workingRevision, qdoc["_id"], collName)
                        end
                        if(workingRevisionMatched)
                          queriesHelper.save(queryDoc, @gbLogin)
                          bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, queryDoc)
                          configResponse(bodyData)
                          @statusName = :'Moved Permanently'
                          @statusMsg = "UPDATED_QUERY_DOC: The query document with the id: #{@queryName.inspect} was updated."
                        else
                          @statusName = :"Conflict"
                          @statusMsg = " WORKING_COPY_OUT_OF_DATE: Your working copy of the document is out-of-date. The document has been changed since you last retrieved it. To prevent loss of new content or the saving of deleted content, your document change has been rejected."
                        end
                      else # New query document
                        queriesHelper.save(queryDoc, @gbLogin)
                        bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, queryDoc)
                        configResponse(bodyData)
                        @statusName = :'Created'
                        @statusMsg = "NEW_QUERY_CREATED: Your new query document was created."
                      end
                    else
                      @statusName = :Forbidden
                      @statusMsg = "#{@queryName} is one of the 'implicit' queries. You are not allowed to update it."
                    end      
                  end
                else
                  if( validator.respond_to?(:buildErrorMsgs) )
                    errors = validator.buildErrorMsgs()
                  else
                    errors = validator.validationErrors
                  end
                  @statusName = :'Unsupported Media Type'
                  @statusMsg = "BAD_QUERY: The query document does not follow the specification of the query model:\n\n#{errors.join("\n")}"
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
          @statusMsg = "NO_QUERIES_COLL: can't get queries document named #{@queryName.inspect} because appears to be no collection #{collName.inspect} in the #{@kbName.inspect} GenboreeKB, within group #{@groupName.inspect} . #{collName} is a GenboreeKB internal collection and absence of this collection means that the #{@kbName.inspect} is an outdated GenboreeKB."
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
        collName = BRL::Genboree::KB::Helpers::QueriesHelper::KB_CORE_COLLECTION_NAME
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        queriesHelper = @mongoKbDb.queriesHelper()
        unless(queriesHelper.coll.nil?)
          if(WRITE_ALLOWED_ROLES[@groupAccessStr])
            begin
              entity = nil
              queriesCursor = queriesHelper.coll.find({ "Query.value" => @queryName})
              if(queriesCursor and queriesCursor.is_a?(Mongo::Cursor) and queriesCursor.count > 0) # Should be just one
                queriesCursor.rewind!
                qdocId = nil
                queriesCursor.each { |doc|
                  doc = BRL::Genboree::KB::KbDoc.new( doc )
                  qDocId = doc['_id']
                  entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
                }
                workingRevisionMatched = true
                if(@workingRevision)
                  workingRevisionMatched = queriesHelper.matchWorkingRevisionWithCurrentRevision(@workingRevision, qDocId, collName)
                end
                if(workingRevisionMatched)
                  queriesHelper.coll.remove( { "Query.value" => @queryName} )
                  @statusMsg = "DELETED: The query: #{@queryName} was deleted from the database."
                  @statusName = :OK
                  configResponse(entity)
                else
                  @statusName = :"Conflict"
                  @statusMsg = " WORKING_COPY_OUT_OF_DATE: Your working copy of the document is out-of-date. The document has been changed since you last retrieved it. To prevent loss of new content or the saving of deleted content, your document change has been rejected."
                end
              else
                # Check to see if query is one of the 'implicit' queries
                if(BRL::Genboree::KB::Helpers::QueriesHelper::IMPLICIT_QUERIES_DEFS.key?(@queryName))           
                  @statusName = :Forbidden
                  @statusMsg = "#{@queryName} is one of the 'implicit' queries. You are not allowed to delete it."
                else
                  @statusName = :'Not Found'
                  @statusMsg = "NO_QUERY: There is no query #{@queryName.inspect} under #{@kbName} KB."
                end
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
          @statusMsg = "NO_QUERIES_COLL: can't get queries document named #{@queryName.inspect} because appears to be no collection #{collName.inspect} in the #{@kbName.inspect} GenboreeKB, within group #{@groupName.inspect} . #{collName} is a GenboreeKB internal collection and absence of this collection means that the #{@kbName.inspect} is an outdated GenboreeKB."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
    
  end # class KbQuery
end ; end ; end # module BRL ; module REST ; module Resources
