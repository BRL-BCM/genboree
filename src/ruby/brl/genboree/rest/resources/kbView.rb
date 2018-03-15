#!/usr/bin/env ruby
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/rest/resources/kbDocs'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/kb/validators/viewValidator'
require 'brl/genboree/kb/helpers/viewsHelper'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  class KbView < BRL::REST::Resources::GenboreeResource
    # @return [Hash{Symbol=>Object}] Map of what http methods this resource supports ( @{ :get => true, :put => false }@, etc } ).
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    RSRC_TYPE = 'kbView'
    SUPPORTED_APSECTS = {
      'label' => nil,
      'labels' => nil
    }
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
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/view/([^/\?]+)(?:$|/([^/\?]+)$)}
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
        @viewName   = Rack::Utils.unescape(@uriMatchData[3]).to_s.strip
        @aspect     = (@uriMatchData[4].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[4]).to_s.strip
        @collName = "kbViews"
        initStatus = initGroupAndKb()
        if(initStatus == :OK)
          if(@aspect and !SUPPORTED_APSECTS.key?(@aspect))
            @statusName = :"Bad Request"
            initStatus = :"Bad Request"
            @statusMsg = "BAD_REQUEST: Unsupported aspect: #{@aspect.inspect}. Supported aspects include: #{SUPPORTED_APSECTS.keys.join(",")}"
          end
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
        viewsHelper = @mongoKbDb.viewsHelper()
        if(READ_ALLOWED_ROLES[@groupAccessStr])
          entity = nil
          begin
            viewsCursor = viewsHelper.coll.find({ "name.value" => @viewName})
            if(viewsCursor and viewsCursor.is_a?(Mongo::Cursor) and viewsCursor.count > 0) # Should be just one
              viewsCursor.rewind!
              viewsCursor.each { |doc|
                doc = BRL::Genboree::KB::KbDoc.new( doc )
                viewDocId = doc['_id']
                entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)  
                entity.metadata = viewsHelper.getMetadata(viewDocId, "kbViews")
              }
              @statusName = configResponse(entity) 
            else
              # Check to see if view is one of the 'implicit' views
              if(BRL::Genboree::KB::Helpers::ViewsHelper::IMPLICIT_VIEWS_DEFS.key?(@viewName))
                templDoc = viewsHelper.getImplicitView(@viewName)
                doc = BRL::Genboree::KB::KbDoc.new( templDoc )
                entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
                @statusName = configResponse(entity) if(!entity.nil?)
              else
                @statusName = :'Not Found'
                @statusMsg = "NO_VIEW: There is no view #{@viewName.inspect} under #{@kbName} KB."
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
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        viewsHelper = @mongoKbDb.viewsHelper()
        if(WRITE_ALLOWED_ROLES[@groupAccessStr])
          payload = parseRequestBodyForEntity('KbDocEntity')
          # Empty payload. Create an empty view
          if(payload.nil? or (payload.is_a?(BRL::Genboree::REST::Data::KbDocEntity) and payload.doc and payload.doc.empty?))
            # @todo implement empty view creation
            @statusName = :'Not Implemented'
            @statusMsg = "Creating empty views is not supported currently."
          elsif(payload == :'Unsupported Media Type')
            @statusName = :'Unsupported Media Type'
            @statusMsg = "BAD_VIEW: The view document is not valid. Either the document is empty or does not follow the property based document structure. This is not allowed."
          else
            begin
              unless(@aspect)
                # Try to validate the payload against the model document for views
                validator = BRL::Genboree::KB::Validators::ViewValidator.new()
                viewDoc = payload.doc
                isValid = validator.validate(viewDoc)
                if(isValid)
                  errorStr = viewsHelper.postValidationCheck(payload.doc)
                  if(errorStr.empty?)                  
                    # Make sure the name of the view in the payload matches the name in the URL
                    kbDocView = BRL::Genboree::KB::KbDoc.new(viewDoc)
                    if(kbDocView.getPropVal('name') != @viewName)
                      @statusName = :"Bad Request"
                      @statusMsg = "BAD_REQUEST: The name of the view in the payload does not match the name of the view provided in the resource path (URL)."
                    else
                      # Updating one of the 'implicit views' is not allowed
                      if(!BRL::Genboree::KB::Helpers::ViewsHelper::IMPLICIT_VIEWS_DEFS.key?(@viewName)) 
                        cursor = viewsHelper.coll.find({ 'name.value' => @viewName })
                        exists = ( ( cursor and cursor.is_a?(Mongo::Cursor) and cursor.count > 0 ) ? true : false  )
                        if(exists)
                          workingRevisionMatched = true
                          qDoc = nil
                          cursor.each {|dd|
                            qDoc = dd
                          }
                          if(@workingRevision)
                            workingRevisionMatched = viewsHelper.matchWorkingRevisionWithCurrentRevision(@workingRevision, qdoc["_id"], "kbViews")
                          end
                          if(workingRevisionMatched)
                            uploadStatus = viewsHelper.bulkUpsert('name', { @viewName => viewDoc }, @gbLogin) # This will work even for a single document
                            raise uploadStatus if(uploadStatus != :OK)
                            @statusName = ( exists ? :'Moved Permanently' : :'Created' )
                            @statusMsg = "The view document was inserted/updated."
                          else
                            @statusName = :"Conflict"
                            @statusMsg = " WORKING_COPY_OUT_OF_DATE: Your working copy of the document is out-of-date. The document has been changed since you last retrieved it. To prevent loss of new content or the saving of deleted content, your document change has been rejected."
                          end
                        else
                          uploadStatus = viewsHelper.bulkUpsert('name', { @viewName => viewDoc }, @gbLogin) # This will work even for a single document
                          raise uploadStatus if(uploadStatus != :OK)
                          @statusName = ( exists ? :'Moved Permanently' : :'Created' )
                          @statusMsg = "The view document was inserted/updated."
                        end
                      else
                        @statusName = :Forbidden
                        @statusMsg = "#{@viewName} is one of the 'implicit' views. You are not allowed to update it."
                      end
                    end
                  else
                    @statusName = :'Unsupported Media Type'
                    @statusMsg = "BAD_VIEW: The view document does not follow the specification of the view model:\n\n#{errorStr}"
                  end
                else
                  if( validator.respond_to?(:buildErrorMsgs) )
                    errors = validator.buildErrorMsgs()
                  else
                    errors = validator.validationErrors
                  end
                  @statusName = :'Unsupported Media Type'
                  @statusMsg = "BAD_VIEW: The view document does not follow the specification of the view model:\n\n#{errors.join("\n")}"
                end
              else
                if(@aspect == 'label' or @aspect == 'labels')
                  # Updating one of the 'implicit views' is not allowed
                  if(!BRL::Genboree::KB::Helpers::ViewsHelper::IMPLICIT_VIEWS_DEFS.key?(@viewName)) 
                    # For updating just the labels, the view should already be present
                    viewsCursor = viewsHelper.coll.find({ "name.value" => @viewName})
                    if(viewsCursor and viewsCursor.is_a?(Mongo::Cursor) and viewsCursor.count > 0) # Should be just one
                      viewsCursor.rewind!
                      viewDoc = nil
                      viewsCursor.each { |doc|
                        viewDoc = BRL::Genboree::KB::KbDoc.new( doc )
                      }
                      viewPropsList = viewDoc.getPropItems('name.viewProps')
                      viewProps = {}
                      viewPropsList.each {|propObj|
                        propObjKbDoc = BRL::Genboree::KB::KbDoc.new( propObj )
                        currLabel = propObjKbDoc.getPropVal('prop.label') 
                        viewProps[propObjKbDoc.getPropVal('prop')] =  ( currLabel ? currLabel : nil )
                      }
                      payloadKbDoc = BRL::Genboree::KB::KbDoc.new(payload.doc)
                      propList = payloadKbDoc.getPropItems('viewProps')
                      if(propList.nil? or !propList.is_a?(Array))
                        @statusName = :"Unsupported Media Type"
                        @statusMsg = "Unsupported Media Type: The provided payload does not have the 'viewProps' property or does not have the 'items' field under viewProps with the list of properties for which to set the labels for."
                      else
                        payloadProps = {}
                        # Create a hash structure to map property names to their new representation.
                        propList.each {|propObj|
                          payloadProps[propObj['prop']['value']] = propObj
                        }
                        # Iterate over each prop and extract the labels
                        # Map the labels to the property using the viewProps hash
                        allPropsOK = true
                        propNotFound = []
                        payloadProps.each_key {|prop|
                          if(!viewProps.key?(prop))
                            allPropsOK = false
                            propNotFound.push(prop)
                          else
                            propObj = payloadProps[prop]
                            propKbDoc = BRL::Genboree::KB::KbDoc.new( propObj )
                            label = propKbDoc.getPropVal('prop.label')
                            viewProps[prop] = label
                          end
                        }
                        unless(allPropsOK)
                          @statusName = :"Not Found"
                          @statusMsg = "NOT_FOUND: The following properties have not been defined in the view: #{propNotFound.join(",")}. The view was not updated."
                        else
                          # If everything looks good so far, loop over the list (we need to maintain the order of the properties in the view)
                          #    of properties and set the labels provided in the payload using the viewProps hash populated above.
                          viewPropsList.each { |propObj|
                            propObjKbDoc =  BRL::Genboree::KB::KbDoc.new( propObj )
                            newLabel = viewProps[propObjKbDoc.getPropVal('prop')]
                            if(newLabel)
                              propObjKbDoc.setPropProperties('prop', { 'label' => { 'value' => newLabel } } )  
                            end
                          }
                          uploadStatus = viewsHelper.bulkUpsert('name', { @viewName => viewDoc }, @gbLogin) # This will work even for a single document
                          raise uploadStatus if(uploadStatus != :OK)
                          @statusName = :'Moved Permanently'
                          @statusMsg = "The view document was updated."
                        end
                      end
                    else
                      @statusName = :'Not Found'
                      @statusMsg = "NO_VIEW: There is no view #{@viewName.inspect} under #{@kbName} KB."
                    end
                  else
                    @statusName = :Forbidden
                    @statusMsg = "#{@viewName} is one of the 'implicit' views. You are not allowed to update it."
                  end
                end
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
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        if(WRITE_ALLOWED_ROLES[@groupAccessStr])
          begin
            entity = nil
            viewsHelper = @mongoKbDb.viewsHelper()
            viewsCursor = viewsHelper.coll.find({ "name.value" => @viewName})
            if(viewsCursor and viewsCursor.is_a?(Mongo::Cursor) and viewsCursor.count > 0) # Should be just one
              viewsCursor.rewind!
              vDocId = nil
              viewsCursor.each { |doc|
                doc = BRL::Genboree::KB::KbDoc.new( doc )
                vDocId = doc['_id']
                entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
              }
              workingRevisionMatched = true
              if(@workingRevision)
                workingRevisionMatched = viewsHelper.matchWorkingRevisionWithCurrentRevision(@workingRevision, vDocId, "kbViews")
              end
              if(workingRevisionMatched)
                viewsHelper.coll.remove( { "name.value" => @viewName} )
                @statusMsg = "DELETED: The view: #{@viewName} was deleted from the database."
                @statusName = :OK
                configResponse(entity)
              else
                @statusName = :"Conflict"
                @statusMsg = " WORKING_COPY_OUT_OF_DATE: Your working copy of the document is out-of-date. The document has been changed since you last retrieved it. To prevent loss of new content or the saving of deleted content, your document change has been rejected."
              end
            else
              # Check to see if view is one of the 'implicit' views
              if(BRL::Genboree::KB::Helpers::ViewsHelper::IMPLICIT_VIEWS_DEFS.key?(@viewName))           
                @statusName = :Forbidden
                @statusMsg = "#{@viewName} is one of the 'implicit' views. You are not allowed to delete it."
              else
                @statusName = :'Not Found'
                @statusMsg = "NO_VIEW: There is no view #{@viewName.inspect} under #{@kbName} KB."
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
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
    
  end # class KbView
end ; end ; end # module BRL ; module REST ; module Resources
