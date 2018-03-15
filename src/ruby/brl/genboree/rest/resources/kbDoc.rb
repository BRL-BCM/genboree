#!/usr/bin/env ruby
require 'uri'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/gbHighChart'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/kb/transformers/docToPropTransformer'
require 'brl/genboree/rest/resources/kbDocs' # for shared constants
require 'brl/genboree/rest/helpers/apiCacheHelper'
require 'brl/genboree/kb/lookupSupport/kbDocLinks.rb'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  # KbDoc - exposes a document in a user data collection within a GenboreKB knowledgebase
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::KbDocEntityList
  # * BRL::Genboree::REST::Data::KbDocEntity
  class KbDoc < BRL::REST::Resources::GenboreeResource

    # @return [Hash{Symbol=>Object}] Map of what http methods this resource supports ( @{ :get => true, :put => false }@, etc } ).
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    RSRC_TYPE = 'kbDoc'
    MAX_BYTES = KbDocs::MAX_BYTES

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
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/doc/([^/\?]+|\s*)$}
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
        @collName   = Rack::Utils.unescape(@uriMatchData[3]).to_s.strip
        @docName    = Rack::Utils.unescape(@uriMatchData[4]).to_s.strip
        # This function will set @groupId if it exists, return value is :OK or :'Not Found'
        initStatus = initGroupAndKb(checkAccess=false) # access is explicitly checked in individual http methods
        @transformationName = @nvPairs['transform'].to_s.strip
        @transformationName = nil unless(@transformationName =~ /\S/)
        @showHisto = @nvPairs.key?('showHisto') ? @nvPairs['showHisto'] : false
        @type = (@nvPairs['type'] =~ /\S/) ? @nvPairs['type'].to_s.strip.downcase() : nil
        @scale = (@nvPairs['scale'] =~ /\S/) ? @nvPairs['scale'].to_s.strip.downcase() : 'linear'
        @versionNum = @nvPairs['versionNum'] ? @nvPairs['versionNum'].to_s.strip.to_f : false
        @revisionNum = @nvPairs['revisionNum'] ? @nvPairs['revisionNum'].to_s.strip.to_f : false
        @save = (@nvPairs['save'] =~ /\S/ ? @nvPairs['save'].to_s.to_bool : true)
        @onClick = (@nvPairs['onClick'] == 'true') ? true : false
        formats = []
        BRL::Genboree::REST::Data::KbDocEntity::FORMATS.each {|format|
          formats.push(format.to_s.downcase)
        }
        if(@reqMethod.to_s.upcase == "PUT" and @repFormat == :TABBED_PROP_PATH)
          initStatus = @statusName = :"Not Implemented"
          suppFormats = formats - ['tabbed_prop_path']
          @statusMsg = "Supported formats include: #{suppFormats.join(",")}"
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
        unless(@transformationName.nil?)
          @resp = transform()
        else
          @groupName = Rack::Utils.unescape(@uriMatchData[1])
          # @todo if public or subscriber, can get info
          if(READ_ALLOWED_ROLES[@groupAccessStr])
            # Get dataCollectionHelper to aid us
            dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
            modelHelper = @mongoKbDb.modelsHelper()
            idPropName = dataHelper.getIdentifierName()
            if(dataHelper)
              begin
                modelDoc = modelHelper.modelForCollection(@collName)
                model = modelDoc.getPropVal('name.model')
                docNameValidation = docNameCast(@docName, model, dataHelper)
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC NAME cast results: #{docNameValidation.inspect}")
                if(docNameValidation and docNameValidation[:result] == :VALID) # looks compatible and has now been casted appropriately
                  @docName = docNameValidation[:castValue] # use casted value
                  #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC NAME NOW: #{@docName.inspect}")
                  doc = dataHelper.getByIdentifier(@docName, { :doOutCast => true, :castToStrOK => true })
                  if(doc)
                    docId = doc["_id"]
                    dbRef = BSON::DBRef.new(@collName, docId)
                    if(!@versionNum and !@revisionNum) # Neither version nor revision specified. Get the latest
                      bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
                      bodyData.model = modelHelper.modelForCollection(@collName)
                      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "bodyData.model:\n#{bodyData.model.inspect}")
                      if(bodyData.model)
                        bodyData.metadata = dataHelper.getMetadata(dbRef)
                        @statusName = configResponse(bodyData)
                      else
                        @statusName = :'Not Found'
                        @statusMsg  = "NO_MODEL: can't get document named #{@docName.inspect} because there does not appear to be a valid model available for data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
                        $stderr.puts "ERROR: #{@statusMsg}\n    - bodyData.model:\n\n#{bodyData.model.inspect}\n\n    - modelHelper:\n\n#{modelHelper.inspect}\n\n"
                      end
                    elsif(@versionNum) # Get the specific version of the document
                      versionsHelper = @mongoKbDb.versionsHelper(@collName) rescue nil
                      if(versionsHelper.nil?)
                        @statusName = :"Internal Server Error"
                        @statusMsg = "Failed to access versions collection for data collection #{@collName}"
                      end
                      # get specified version of the document
                      versionDoc = versionsHelper.getVersion(@versionNum, dbRef)
                      if(versionDoc.nil?)
                        @statusName = :"Not Found"
                        @statusMsg = "Requested version #{@versionNum} for the document #{@docName} does not exist."
                      else
                        doc = versionDoc.getPropVal('versionNum.content')
                        doc = dataHelper.transformIntoModelOrder(doc, { :doOutCast => true, :castToStrOK => true })
                        bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
                        bodyData.model = modelHelper.modelForCollection(@collName)
                        if(bodyData.model)
                          #bodyData.metadata = dataHelper.getMetadata(dbRef)
                          @statusName = configResponse(bodyData)
                        else
                          @statusName = :'Not Found'
                          @statusMsg  = "NO_MODEL: can't get document named #{@docName.inspect} because there does not appear to be a valid model available for data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
                          $stderr.puts "ERROR: #{@statusMsg}\n    - bodyData.model:\n\n#{bodyData.model.inspect}\n\n    - modelHelper:\n\n#{modelHelper.inspect}\n\n"
                        end
                      end
                    else # Get the specific revision of the document
                      revisionsHelper = @mongoKbDb.revisionsHelper(@collName) rescue nil
                      if(revisionsHelper.nil?)
                        @statusName = :"Internal Server Error"
                        @statusMsg = "Failed to access versions collection for data collection #{@collName}"
                      end
                      # get specified revision of the document
                      revisionDoc = revisionsHelper.getRevision(@revisionNum, dbRef)
                      if(revisionDoc.nil?)
                        @statusName = :"Not Found"
                        @statusMsg = "Requested revision #{@revisionNum} for the document #{@docName} does not exist."
                      else
                        doc = revisionDoc.getPropVal('revisionNum.content')
                        doc = dataHelper.transformIntoModelOrder(doc, { :doOutCast => true, :castToStrOK => true })
                        bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
                        bodyData.model = modelHelper.modelForCollection(@collName)
                        if(bodyData.model)
                          @statusName = configResponse(bodyData)
                        else
                          @statusName = :'Not Found'
                          @statusMsg  = "NO_MODEL: can't get document named #{@docName.inspect} because there does not appear to be a valid model available for data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
                          $stderr.puts "ERROR: #{@statusMsg}\n    - bodyData.model:\n\n#{bodyData.model.inspect}\n\n    - modelHelper:\n\n#{modelHelper.inspect}\n\n"
                        end
                      end
                    end
                  else
                    @statusName = :'Not Found'
                    @statusMsg = "NO_DOC: there is no document with the identifier #{@docName.inspect} in the #{@collName.inspect} collection in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc; also consider if it has been deleted)."
                  end
                else
                  @statusName = :'Bad Request'
                  @statusMsg = "INVALID_DOCID: The docID #{@docName.inspect} is not valid according to the collection model: it is incompatible with the domain of the document identifier property."
                end
              rescue => err
                @statusName = :'Not Found'
                @statusMsg = "NO_MODEL: can't get document named #{@docName.inspect} because there does not appear to be a valid model available for data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
                $stderr.puts "ERROR: #{@statusMsg}\n    - ERROR CLASS: #{err.class}\n    - ERROR MSG: #{err.message}\n    - ERROR TRACE:\n#{err.backtrace.join("\n")}"
              end
            else
              @statusName = :'Not Found'
              @statusMsg = "NO_COLL: can't get document named #{@docName.inspect} because appears to be no data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
            end
          else
            @statusName = :Forbidden
            @statusMsg = "You do not have sufficient permissions to perform this operation."
          end
        end
      end #if(initStatus)
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end


    # @todo make this method more robust. need to handle other categories of domains.
    def getIdentPropVal(modelHelper, model, idPropName, docName)
      retVal = nil
      propDef = modelHelper.findPropDef(idPropName, model)
      propDomain = ( propDef ? (propDef['domain'] or 'string') : 'string' )
      if(propDomain == 'string')
        retVal = docName
      elsif(propDomain =~ /int/i)
        retVal = docName.to_i
      elsif(propDomain =~ /float/i)
        retVal = docName.to_f
      else
        retVal = docName
      end
      return retVal
    end


    # Performs transformation operation on this resource.
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    def transform()
      transformDocAndVersion = nil
      docAndVersion = nil
      # get the transformation doc and the head version number
      transformDocAndVersion = getTransformationDocAndVersionNum()
      if(transformDocAndVersion and @statusName == :OK)
        # get the source doc and its version mumber
        docAndVersion = getDocAndVersionNum()    
        if(docAndVersion and @statusName == :OK)
          apiCacheHelper = BRL::Genboree::REST::Helpers::ApiCacheHelper.new(@rsrcPath, @nvPairs)
          apiCacheRec = nil
          apiCacheContent = nil
          begin
            apiCacheRec = apiCacheHelper.getapiCache(docAndVersion["versionNum"], {"transformVersion" => transformDocAndVersion["versionNum"]})
          rescue => err
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "API_CACHE_GET_ERROR - #{err.message}")
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "API_CACHE_GET_ERROR - #{err.backtrace}")
          end
          if(apiCacheRec and !apiCacheRec.empty?)
            # has cache rec, get it
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "CACHE rec found")
            apiCacheContent = apiCacheRec.first["content"]
            if(@repFormat == :HTML or @repFormat == :SMALLHTML)
              @resp.body = apiCacheContent
              @resp['Content-Type'] = 'text/html'
              @resp.status = HTTP_STATUS_NAMES[:OK]
            else
              bodyData = BRL::Genboree::REST::Data::RawDataEntity.new(@connect, JSON(apiCacheContent))
              @statusName = configResponse(bodyData)
            end
          else
            # do the transformation from the library and cache the rec
            begin
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", " No CACHE - Transforming fresh")
              tr = BRL::Genboree::KB::Transformers::DocToPropTransformer.new(transformDocAndVersion["doc"], @mongoKbDb)
              transformed = tr.transformKbDoc(docAndVersion["doc"], @collName)
              if(transformed)
                if(@repFormat == :HTML or @repFormat == :SMALLHTML)
                  begin
                    bodyData = tr.getHtmlFromJsonOut(tr.transformedDoc, @repFormat, {:onClick => @onClick, :showHisto => @showHisto})
                    apiCon = bodyData
                  rescue => err
                    @statusName = :'Internal Server Error'
                    @statusMsg = "GRID_ERROR: Failed to retrieve grid table for the transformation rules doc #{@transformationName}"
                  end
                  # add the rec to cache
                  @resp.body = bodyData
                  @resp['Content-Type'] = 'text/html'
                  @resp.status = HTTP_STATUS_NAMES[:OK]
                else # default format JSON
                  bodyData = BRL::Genboree::REST::Data::RawDataEntity.new(@connect, tr.transformedDoc)
                  apiCon = tr.transformedDoc.to_json
                  @statusName = configResponse(bodyData)
                end
                if( apiCon.size < @genbConf.apiCacheMaxBytes.to_i )
                  begin
                    insertSuccess = apiCacheHelper.putapiCache(apiCon, docAndVersion["versionNum"], {"transformVersion" => transformDocAndVersion["versionNum"]})
                  rescue =>  err
                    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "API_CACHE_PUT_ERROR - #{err.message} \n #{err.backtrace}")
                  end
                end
              else
                @statusName = :"Internal Server Error"
                @statusMsg = "Failed to transform the Genboree KB document '#{@docName.inspect}' with the transformation Rules document '#{@transformationName}'. #{tr.transformationErrors.inspect}"
              end
            rescue => err
              @statusName = :"Bad Request"
              @statusMsg = "Failed to transform the Genboree KB document '#{@docName.inspect}' with the transformation Rules document '#{@transformationName}'. Rules Document invalid? #{err.message}\n."
            end
         end

        end
      end
      return @resp
    end

    # Process a PUT operation on this resource: upload or modify a kbDoc
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    # @todo remove arrow anti-pattern by raising BRL::Genboree::GenboreeError
    # @note the following query string parameters modify this method:
    #   [Boolean] @save whether or not to commit the put to the database; default: true
    def put()
      begin
        initStatus = initOperation()
        if(initStatus == :OK)
          @groupName = Rack::Utils.unescape(@uriMatchData[1])
          # @todo if public or subscriber, can get info
          if(WRITE_ALLOWED_ROLES[@groupAccessStr] or (READ_ALLOWED_ROLES[@groupAccessStr] and !@save))
            # Get dataCollectionHelper to aid us
            if(@req.env['CONTENT_LENGTH'] and (@req.env['CONTENT_LENGTH'].to_i > MAX_BYTES))
              @statusName = :"Bad Request"
              @statusMsg = "Refusing to process request because the payload exceeds byte limits: payload byte limit is #{MAX_BYTES}"
              raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
            end
            dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
            modelHelper = @mongoKbDb.modelsHelper()
            idPropName = dataHelper.getIdentifierName()
            if(dataHelper)
              begin
                modelDoc = modelHelper.modelForCollection(@collName)
                model = modelDoc.getPropVal('name.model')
                # Parse the request payload (if any)
                payload = parseRequestBodyForEntity('KbDocEntity', { :docType => @nvPairs['docType']})
                if(payload.nil? or (payload.is_a?(BRL::Genboree::REST::Data::KbDocEntity) and payload.doc and payload.doc.empty?)) # empty payload
                  docNameValidation = docNameCast(@docName, model, dataHelper)
                  if(docNameValidation and docNameValidation[:result] == :VALID) # looks compatible and has now been casted appropriately
                    @docName = docNameValidation[:castValue] # use casted value
                    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC NAME NOW: #{@docName.inspect}")
                    # Get existing doc--ok to use ID from path here
                    reqDoc = dataHelper.getByIdentifier(@docName, { :doOutCast => true, :castToStrOK => true }) # Just checking, no casting opts needed
                    if(reqDoc)
                      # - doc name cannot already exist (can't wipe the doc contents via payload-less request)
                      @statusName = :'Bad Request'
                      @statusMsg = "DOC_EXISTS: the GenboreeKB doc #{@docName.inspect} already exists and you have not provided replacement content in your request. An empty payload CANNOT be used to delete or 'clear' a document's content. If you want to delete an existing document, use HTTP 'DELETE' not 'PUT'; if you want to change the content for the document, provide that content. The only time an empty payload is permitted is when creating a NEW document, which will be initialized with appropriate defaults in required fields."
                    else # doc doesn't exist, create a new one using model
                      # - initial doc must be created from model and fill in REQUIRED properties with DEFAULTS
                      doc = dataHelper.docTemplate(@docName)
                      objId = dataHelper.save(doc, @gbLogin, :save => @save)
                      if(objId.is_a?(BSON::ObjectId))
                        bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
                        @statusName = configResponse(bodyData)
                      elsif(objId.is_a?(BRL::Genboree::KB::KbError))
                        @statusName = :'Not Acceptable'
                        @statusMsg  = "DOC_REJECTED: your document was rejected because validation failed. Validation complained that: #{objId.message}"
                      else
                        @statusName = :'Internal Server Error'
                        @statusMsg = "SAVE_FAILED: Tried to save your document, but the save unexpectedly failed (returned #{objId.inspect} rather than what was expected). Possible configuration problem or bug."
                        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to save a new [default init] data doc. Saving #{@docName.inspect} in data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} returned #{objId.inspect} rather than a BSON::ObjectId. Attempted to save this doc:\n\n#{doc.inspect}\n\n")
                      end
                    end
                  else
                    @statusName = :'Bad Request'
                    @statusMsg = "INVALID_DOCID: The docID #{@docName.inspect} is not valid according to the collection model: it is incompatible with the domain of the document identifier property."
                  end
                elsif(payload == :'Unsupported Media Type') # not correct payload content
                  @statusName = :'Unsupported Media Type'
                  @statusMsg = "BAD_DOC: the GenboreeKB doc you provided in the payload is not valid. Either the document is empty or doesn't follow the property-based document structure. This is not allowed."
                else # payload present
                  # Get payload doc
                  payloadDoc = BRL::Genboree::KB::KbDoc.new(payload.doc) rescue nil
                  if(payloadDoc)
                    # Clean the doc provided a bit by doing a strip on the keys (property names} and the contents of value fields)
                    payloadDoc = dataHelper.cleanDoc(payloadDoc)
                    idPropName = dataHelper.getIdentifierName()
                    payloadDocName = payloadDoc.getPropVal(idPropName)
                    if(payloadDocName)
                      # Try get existing doc (one in the rsrcPath)--ok to use ID from path here to get it because
                      #   it's ALWAYS the path for the existing doc (if present).
                      modelDoc = modelHelper.modelForCollection(@collName)
                      model = modelDoc.getPropVal('name.model')
                      docNameValidation = docNameCast(@docName, model, dataHelper)
                      if(docNameValidation and docNameValidation[:result] != :INVALID) # looks compatible and has now been casted appropriately
                        @docName = docNameValidation[:castValue] # use casted value
                        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC NAME NOW: #{@docName.inspect}")
                        existingDoc = false
                        if(@docName != :CONTENT_MISSING) # Skip for Auto-Id
                          existingDoc = dataHelper.getByIdentifier(@docName, { :doOutCast => true, :castToStrOK => true }) # just checking, no casting opts needed
                        end
                        if(existingDoc) # then updating existing doc
                          # Because _may_ be renaming as part of updating doc, we will go through the internal "_id" field:
                          # - set "_id" in the replacement doc to the "_id" from the existing doc...thus it will update
                          payloadDoc['_id'] = existingDoc['_id']
                          # Make sure working revision (if provided) matches the current revision of the document
                          workingRevisionMatched = true
                          if(@workingRevision)
                            workingRevisionMatched = dataHelper.matchWorkingRevisionWithCurrentRevision(@workingRevision, payloadDoc['_id'], @collName)
                          end
                          if(workingRevisionMatched)
                            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "FIND: before doing validation")
                            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "EXISTING DOC: #{puts JSON.pretty_generate(payloadDoc)}")
                            objId = dataHelper.save(payloadDoc, @gbLogin, :save => @save)
                            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "FIND: after doing validation")
                            if(objId.is_a?(BSON::ObjectId))
                              # Doc updated successfuly - add the links to the kbDocLinks table
                              begin
                                kbDocLinks = BRL::Genboree::KB::LookupSupport::KbDocLinks.new(@collName, @mongoKbDb)
                                upsertedRecs = kbDocLinks.upsertFromKbDocs( [payloadDoc] )
                                $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Inserted #{upsertedRecs} from the doc #{payloadDocName}")
                              rescue => err
                                $stderr.debugPuts(__FILE__, __method__, "KbDocLinksTable_CREATE_ERROR", "Failed to create kbDocLinks table - #{err}")
                              end
                              bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, payloadDoc)
                              bodyData.metadata = getDocMetadata(dataHelper)
                              bodyData.model = modelHelper.modelForCollection(@collName)
                              # $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Gathered data to send:\n\n#{JSON.pretty_generate(bodyData)}\n\n")
                              configResponse(bodyData)
                              @statusName = ( (payloadDocName and payloadDocName == @docName) ? :OK : :'Moved Permanently' )
                              @statusMsg = "UPDATED_DOC: your existing document #{@docName.inspect} was updated #{payloadDocName == @docName ? '.' : " and was renamed to #{payloadDocName.inspect}"}."
                            elsif(objId.is_a?(BRL::Genboree::KB::KbError))
                              @statusName = :'Not Acceptable'
                              @statusMsg  = "DOC_REJECTED: your document was rejected because validation failed. Validation complained that: #{objId.message}"
                            else
                              @statusName = :'Internal Server Error'
                              @statusMsg = "SAVE_FAILED: Tried to save your document, but the save unexpectedly failed (returned #{objId.inspect} rather than what was expected). Possible configuration problem or bug."
                              $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to save a new [default init] data doc. Saving #{@docName.inspect} in data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} returned #{objId.inspect} rather than a BSON::ObjectId. Attempted to save this doc:\n\n#{payloadDoc.inspect}\n\n")
                            end
                          else
                            @statusName = :"Conflict"
                            @statusMsg = " WORKING_COPY_OUT_OF_DATE: Your working copy of the document is out-of-date. The document has been changed since you last retrieved it. To prevent loss of new content or the saving of deleted content, your document change has been rejected."
                          end
                        else # then adding new doc
                          # - doc name in path must match doc name in payload (after casting both values)
                          payloadDocNameValidation = docNameCast(payloadDocName, model, dataHelper)
                          if(payloadDocNameValidation and payloadDocNameValidation[:result] != :INVALID) # looks compatible and has now been casted appropriately
                            payloadDocName = payloadDocNameValidation[:castValue]
                            if(payloadDocName and payloadDocName == @docName)
                              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "FIND: before doing validation")
                              objId = dataHelper.save(payloadDoc, @gbLogin, :save => @save)

                              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "FIND after doing validation")
                              if(objId.is_a?(BSON::ObjectId))
                                # Successfuly saved - add links to kbDocLinks table
                                begin
                                  kbDocLinks = BRL::Genboree::KB::LookupSupport::KbDocLinks.new(@collName, @mongoKbDb)
                                  upsertedRecs = kbDocLinks.upsertFromKbDocs( [payloadDoc] )
                                  $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Inserted #{upsertedRecs} records to the kbDocLinks Table from the doc #{payloadDocName}")
                                rescue => err
                                  $stderr.debugPuts(__FILE__, __method__, "KbDocLinksTable_CREATE_ERROR", "Failed to create kbDocLinks table - #{err}")
                                end
                                @docName = payloadDoc.getPropVal(idPropName)
                                bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, payloadDoc)
                                bodyData.metadata = getDocMetadata(dataHelper)
                                bodyData.model = modelHelper.modelForCollection(@collName)
                                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Gathered data to send:\n\n#{JSON.pretty_generate(bodyData)}\n\n")
                                configResponse(bodyData)
                                @statusName = :'Created'
                                @statusMsg = "NEW_DOC: your new document #{@docName.inspect} was saved."
                              elsif(objId.is_a?(BRL::Genboree::KB::KbError))
                                @statusName = :'Not Acceptable'
                                @statusMsg  = "DOC_REJECTED: your document was rejected because validation failed. Validation complained that: #{objId.message}"
                              else
                                @statusName = :'Internal Server Error'
                                @statusMsg = "SAVE_FAILED: Tried to save your document, but the save unexpectedly failed (returned #{objId.inspect} rather than what was expected). Possible configuration problem or bug."
                                $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to save a new [default init] data doc. Saving #{@docName.inspect} in data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} returned #{objId.inspect} rather than a BSON::ObjectId. Attempted to save this doc:\n\n#{payloadDoc.inspect}\n\n")
                              end
                            else
                              @statusName = :'Bad Request'
                              @statusMsg = "BAD_DOC: the value for the required top-level property #{idPropName.inspect} in your new document does not match the name of the new document that appears in your resource path (#{@docName.inspect}). They must agree when making new documents, to avoid mistakes and unintentional data corruption."
                            end
                          else
                            @statusName = :'Bad Request'
                            @statusMsg = "INVALID_DOCID: The docID in payload #{payloadDocName.inspect} is not valid according to the collection model: it is incompatible with the domain of the document identifier property."
                          end
                        end
                      else
                        @statusName = :'Bad Request'
                        @statusMsg = "INVALID_DOCID: The docID #{@docName.inspect} is not valid according to the collection model: it is incompatible with the domain of the document identifier property."
                      end
                    else
                      @statusName = :'Not Acceptable'
                      @statusMsg = "BAD_DOC: the updated or new document content you provided for #{@docName.inspect} does not have a value for the required top-level property #{idPropName.inspect}. That identifier must be present."
                    end # if(payloadDocName)
                  else
                    @statusName = :'Unsupported Media Type'
                    @statusMsg = "BAD_DOC: the GenboreeKB doc you provided in the payload is not a valid property-based document. Cannot proceed."
                  end
                end # if(payloadDoc)
              rescue => err
                @statusName = :'Internal Server Error'
                @statusMsg = "ERROR: can't put document named #{@docName.inspect} in the collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} because of an error. Specific error: #{err.message.inspect}"
                $stderr.puts "ERROR: #{@statusMsg}\n    - ERROR CLASS: #{err.class}\n    - ERROR MSG: #{err.message}\n    - ERROR TRACE:\n#{err.backtrace.join("\n")}"
              end
            else
              @statusName = :'Not Found'
              @statusMsg = "NO_COLL: can't put a document named #{@docName.inspect} because there appears to be no data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
            end # if(dataHelper)
          else
            @statusName = :Forbidden
            @statusMsg = "You do not have sufficient permissions to perform this operation."
          end # if(WRITE_ALLOWED_ROLES[@groupAccessStr])
        end # if(initStatus == :OK)
      rescue => err
        logAndPrepareError(err)
      end
      # If something wasn't right, represent as error
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end

    def delete()
      #$stderr.debugPuts(__FILE__, __method__, ">>>HERE", "uriMatchData: #{@uriMatchData.inspect}")
      initStatus = initOperation()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        # @todo if public or subscriber, can get info
        if(WRITE_ALLOWED_ROLES[@groupAccessStr])
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@collName: #{@collName.inspect}")
          # Get dataCollectionHelper to aid us
          dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
          modelHelper = @mongoKbDb.modelsHelper()
          idPropName = dataHelper.getIdentifierName()
          if(dataHelper)
            # Get existing doc--ok to use ID from path here
            modelDoc = modelHelper.modelForCollection(@collName)
            model = modelDoc.getPropVal('name.model')
            docNameValidation = docNameCast(@docName, model, dataHelper)
            if(docNameValidation and docNameValidation[:result] == :VALID) # looks compatible and has now been casted appropriately
              @docName = docNameValidation[:castValue] # use casted value
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC NAME NOW: #{@docName.inspect}")
              reqDoc = dataHelper.getByIdentifier(@docName, { :doOutCast => true, :castToStrOK => true }) # just checking, no casting opts needed
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Doc to delete: #{reqDoc ? reqDoc['_id'].inspect : reqDoc.inspect}")
              if(reqDoc and reqDoc['_id'])
                begin
                  # Make sure working revision (if provided) matches the current revision of the document
                  workingRevisionMatched = true
                  if(@workingRevision)
                    workingRevisionMatched = dataHelper.matchWorkingRevisionWithCurrentRevision(@workingRevision, reqDoc['_id'], @collName)
                  end
                  if(workingRevisionMatched)
                    delResult = dataHelper.deleteDoc(reqDoc['_id'], @gbLogin)
                    # Remove the respective records - all the records where the src doc id is 
                    begin
                      kbDocLinks = BRL::Genboree::KB::LookupSupport::KbDocLinks.new(@collName, @mongoKbDb)
                      deletedRecs = kbDocLinks.deleteBySrcDocId(@docName)
                      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Deleted #{deletedRecs} records from the kbDocLinks Table from the doc #{@docName}")
                    rescue => err
                      $stderr.debugPuts(__FILE__, __method__, "KbDocLinksTable_CREATE_ERROR", "Failed to create kbDocLinks table - #{err}")
                    end
                    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Del result: #{delResult.inspect}")
                    bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, reqDoc)
                    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Gathered data to send:\n\n#{JSON.pretty_generate(bodyData)}\n\n")
                    @statusName = :OK
                    @statusMsg = "DELETED: The document named #{@docName.inspect} from collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} has been deleted."
                    configResponse(bodyData)
                  else
                    @statusName = :"Conflict"
                    @statusMsg = " WORKING_COPY_OUT_OF_DATE: Your working copy of the document is out-of-date. The document has been changed since you last retrieved it. To prevent loss of new content or the saving of deleted content, your document change has been rejected."
                  end
                rescue => err
                  @statusName = :'Internal Server Error'
                  @statusMsg = "DEL_FAILED: Tried to delete the document named #{@docName.inspect} from collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} but the delete operation failed. Possible bug or collection corruption."
                  $stderr.puts "ERROR: #{@statusMsg}\n    - ERROR CLASS: #{err.class}\n    - ERROR MSG: #{err.message}\n    - ERROR TRACE:\n#{err.backtrace.join("\n")}"
                end
              else # no such doc
                @statusName = :'Not Found'
                @statusMsg = "NO_COLL: can't delete document named #{@docName.inspect} because there is no document with that name in collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
              end
            else
              @statusName = :'Bad Request'
              @statusMsg = "INVALID_DOCID: The docID #{@docName.inspect} is not valid according to the collection model: it is incompatible with the domain of the document identifier property."
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_COLL: can't delete document named #{@docName.inspect} because appears to be no data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
          end # if(dataHelper)
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation."
        end # if(WRITE_ALLOWED_ROLES[@groupAccessStr])
      end # if(initStatus == :OK)
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
    
    # Helper methods
    def getDocMetadata(dataHelper)
      doc = dataHelper.getByIdentifier(@docName, { :doOutCast => true, :castToStrOK => true })
      docId = doc["_id"]
      dbRef = BSON::DBRef.new(@collName, docId)
      return dataHelper.getMetadata(dbRef)
    end

    # @todo - should this move to DataCollectionHelper?? Doc it have access to modelhelper etc for the collection? YES!
    def docNameCast(docName, model, dataHelper)
      docNameValidation = nil
      idPropName = dataHelper.getIdentifierName()
      # Empty payload is fine to create a NEW doc. Cannot already exist though!
      # Need to cast @docName to match model
      mv = dataHelper.modelValidator(false, false)
      docNameValidation = mv.validVsDomain(docName, model, [ idPropName ], { :castValue => true })
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC NAME cast results: #{docNameValidation.inspect}")
      return docNameValidation
    end


    ###
    # Transformation related HELPER methods
    ###
    
    def getDocAndVersionNum()
      retVal = {}
      # get the doc first
      host = @genbConf.machineName
      apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(host, @rsrcPath, @userId)
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      resp = apiCaller.parseRespBody
      if(apiCaller.succeeded?)
          retVal["doc"] = apiCaller.apiDataObj
      else
        retVal = nil
        @statusName = apiCaller.apiStatusObj['statusCode'].to_sym
        @statusMsg = apiCaller.apiStatusObj['msg']
      end      

      # get the version of the doc now
      if(@statusName == :OK)
        path = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}/ver/HEAD?versionNumOnly=true"
        apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(host, path, @userId)
        apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get({:doc => @docName, :coll => @collName, :kb => @kbName, :grp => @groupName})
        resp = apiCaller.parseRespBody
        if(apiCaller.succeeded?)
          retVal["versionNum"] = apiCaller.apiDataObj["number"] 
        else
          retVal = nil
          @statusName = apiCaller.apiStatusObj['statusCode'].to_sym
          @statusMsg = apiCaller.apiStatusObj['msg']
        end
      end
      return retVal
    end
     
    

    # Get the transformation rules document and the version number 
    # @return [Hash] retVal hash of transformation document and the version number
    def getTransformationDocAndVersionNum()
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Getting transformation document . . . . . . ")
      retVal = {}
      versionDoc = nil
      trUrlValid = true
      path = nil
      # Could be a transformation url
      trUrl = URI.parse(@transformationName) rescue nil
      if(trUrl and trUrl.scheme)
        trPath = trUrl.path
        trHost = trUrl.host
        patt = KbTransform.pattern()
        if(trHost and trPath =~ patt)
          apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(trHost, trPath, @userId)
        else
          trUrlValid = false
        end
      else # is a document ID
        host = @genbConf.machineName
        path = "/REST/v1/grp/#{CGI.escape(@groupName)}/kb/#{CGI.escape(@kbName)}/trRulesDoc/#{CGI.escape(@transformationName.strip())}"
        apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(host, path, @userId)
      end
      if(trUrlValid)
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Transformation document path --------#{apiCaller.rsrcPath.inspect}")
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = apiCaller.parseRespBody
        if(apiCaller.succeeded?)
          retVal["doc"] = apiCaller.apiDataObj
        else
          retVal = nil
          @statusName = apiCaller.apiStatusObj['statusCode'].to_sym
          @statusMsg = apiCaller.apiStatusObj['msg']
        end
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "@statusName - #{@statusName.inspect}")
        if(@statusName == :OK)
          trvPath = nil
          trvHost = nil
          # get the version
          if(path)
            trvPath = path
            trvHost = host 
          else
            trvPath = trPath
            trvHost = trHost
          end
            apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(trvHost, "#{trvPath}/ver/HEAD?versionNumOnly=true", @userId)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            resp = apiCaller.parseRespBody
            if(apiCaller.succeeded?)
              retVal["versionNum"] = apiCaller.apiDataObj["number"]
            else
              retVal = nil
              @statusName = apiCaller.apiStatusObj['statusCode'].to_sym
              @sctatusMsg = apiCaller.apiStatusObj['msg']
            end
         end 
      else
        retVal = nil
        @statusName = :"Bad Request"
        @statusMsg = "INVALID_TRANSFORMATION_URL: The URL #{@transformationName.inspect} is invalid. It either has no valid host or a valid trRulesDoc resource path."
      end
      return retVal
    end


  end # class KbDoc < BRL::REST::Resources::GenboreeResource
end ; end ; end # module BRL ; module REST ; module Resources
