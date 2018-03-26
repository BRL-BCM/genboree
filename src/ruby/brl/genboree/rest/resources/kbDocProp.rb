#!/usr/bin/env ruby
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/resources/kbCollection'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/kb/contentGenerators/generator'
require 'brl/genboree/kb/contentGenerators/autoIdGenerator'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/propSelector'
module BRL; module REST; module Resources

  class KbDocProp < BRL::REST::Resources::GenboreeResource
    HTTP_METHODS = { :get => true, :delete => true, :put => true }
    RSRC_TYPE = 'kbDocProp'
    ITEM_MATCH = /\.\[\s*(FIRST|LAST|\d+)\s*\](?:$|\.((?!\.).)*$)/
    SUPPORTED_ASPECTS = { 'put' => { }, 'get' => { 'value' => true }, 'delete'=> {} }
    REJECTION_SET_REG_EXPS = [ /\[\s*\d+\s*,/,  /\.</, /\{\s*\}/]

    def cleanup()
      super()
    end

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/doc/([^/\?]+)/prop/([^/\?]+)(?:$|/([^/\?]+)$)}
    end

    def self.priority()
      return 6
    end

    def initOperation()
      # check class parent validators
      initStatus = super()
      raise BRL::Genboree::GenboreeError.new(initStatus, "Unable to initialize access to resource") unless(200..299).include?(HTTP_STATUS_NAMES[initStatus])
      @groupName  = Rack::Utils.unescape(@uriMatchData[1])
      @kbName     = Rack::Utils.unescape(@uriMatchData[2])
      @collName   = Rack::Utils.unescape(@uriMatchData[3])
      @docName    = Rack::Utils.unescape(@uriMatchData[4])
      @propPath   = Rack::Utils.unescape(@uriMatchData[5])
      raise BRL::Genboree::GenboreeError.new(:"Bad Request", "property path cannot be nil or empty. Please provide a valid property path") if(@propPath.nil? or @propPath == "")
      # Look for limit/skip/count when retrieving items under item lists
      @limit = @nvPairs.key?("limit") ? @nvPairs["limit"].to_i : nil
      @skip = @nvPairs.key?("skip") ? @nvPairs["skip"].to_i : nil
      @count = @nvPairs.key?("count") ? @nvPairs["count"].to_i : nil
      raise BRL::Genboree::GenboreeError.new(:"Bad Request", "Please provide either skip and limit or only count") if(!@limit.nil? and !@skip.nil? and !@count.nil?)
      
      # Optional Parameter for performing a no-op put/delete
      @save     = ( ( @nvPairs['save'] and @nvPairs['save'] == 'false' ) ? false : true  )
      # @todo: test and enable the save=false option
      raise BRL::Genboree::GenboreeError.new(:"Bad Request", "save=false option is currently unsupported.") if(!@save)
      # Optional supporting parameter for @save
      @validate = ( ( @nvPairs['validate'] and @nvPairs['validate'] == 'false' ) ? false : true )
      raise BRL::Genboree::GenboreeError.new(:"Bad Request", "validate cannot be set to false if save=true.") if(@save and !@validate)
      raise BRL::Genboree::GenboreeError.new(:"Bad Request", "Both validate and save cannot be set to false.") if(!@save and !@validate)
      @aspect = nil
      if(@uriMatchData[6])
        @aspect = Rack::Utils::unescape(@uriMatchData[6])
        unless(SUPPORTED_ASPECTS[@reqMethod.to_s.downcase].key?(@aspect))
          raise BRL::Genboree::GenboreeError.new(:"Bad Request", "This aspect is not supported for #{@reqMethod.to_s.upcase}")
        end
      end
      initStatus  = initGroupAndKb()
      raise BRL::Genboree::GenboreeError.new(initStatus, "Unable to initialize access to resource") unless(200..299).include?(HTTP_STATUS_NAMES[initStatus])
      if(matchRejectionSet?(@propPath))
        raise BRL::Genboree::GenboreeError.new(:"Bad Request", "property path cannot contain: empty curly/square braces, square braces with multiple values or '<'. If you are trying to access an item or a property under an item, use square braces with a single number[idx] or curly braces with a value {value} to indicate the index/value  of the item you are interested in.")
      end
      # validate path against model for this collection
      @mh = @mongoKbDb.modelsHelper()
      @modelDoc = @mh.modelForCollection(@collName)
      raise BRL::Genboree::GenboreeError.new(:"Not Found", "Model document not found for this collection.") unless(@modelDoc)
      model = @modelDoc.getPropVal('name.model')
      @model = model
      dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
      @dataHelper = dataHelper
      @revisionsHelper = @mongoKbDb.revisionsHelper(@collName) rescue nil
      @identifierProp = dataHelper.getIdentifierName()
      docNameValidation = docNameCast(@docName, model, dataHelper)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC NAME cast results: #{docNameValidation.inspect}")
      if(docNameValidation and docNameValidation[:result] == :VALID) # looks compatible and has now been casted appropriately
        @docName = docNameValidation[:castValue] # use casted value
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC NAME NOW: #{@docName.inspect}")
        @doc = nil
        # If retrieving only specific items in a list, get everything but the list for setting up @doc
        if(@count or (@skip and @limit))
          modelPathEls = []
          @propPathEls = @propPath.split(".")
          @propPathEls.each { |el|
            if(el !~ /\[/ and el !~ /\{/)
              modelPathEls << el
            end
          }
          mongoPath = @mh.modelPath2DocPath(modelPathEls.join("."), @collName)
          mongoPath.gsub!(/value$/, "items")
          cc = dataHelper.coll.find({"#{@identifierProp}.value" => @docName}, {:fields => { mongoPath => 0 } })
          cc.each { |dd|
            dd.delete("_id")
            @doc = dd  
          }
        else
          @doc = dataHelper.getByIdentifier(@docName, { :doOutCast => true, :castToStrOK => true })
        end
        unless(@doc)
          raise BRL::Genboree::GenboreeError.new(:"Not Found", "The document #{@docName} was not found in the collection #{@collName}")
        end
      else
        @statusName = :'Bad Request'
        @statusMsg = "INVALID_DOCID: The docID #{@docName.inspect} is not valid according to the collection model: it is incompatible with the domain of the document identifier property."
      end
      return initStatus
    end

    def get()
      begin
        initStatus = initOperation() # error if not ok
        propHash = {}
        propSel = BRL::Genboree::KB::PropSelector.new(@doc)
        entity = nil
        begin
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "beginning get()\n@doc: #{JSON.pretty_generate(@doc)}")
          # For skip and limit or count, get specific items under a list
          # Only works for properties that are an item list
          if((@skip and @limit) or @count)
            propPath = propSel.getMultiPropPaths(@propPath)[0]
            
            raise BRL::Genboree::GenboreeError.new(:"Bad Request", "Property path #{@propPath} could not be found in doc #{@docName}. Please check the property path you provided.") if(propPath.nil?)
            opts = {
              :count => @count,
              :skip => @skip,
              :limit => @limit
            }
            retVal = @dataHelper.sliceSubDocItemList(propPath, @docName, opts)
            # Extract the 'items' from the returned object since this resource returns the value object pointed to by the property path
            # To extract the items from the returned object, change the index of all item lists leading to the final list to be 0 since the query has sliced all the item lists preceeding the final one and kept only the one parent item
            newPropPath = propPath.gsub(/\[\d+\]/, "[0]")
            retVal.delete("_id")
            propSel2 = BRL::Genboree::KB::PropSelector.new(retVal)
            items = propSel2.getMultiPropItems(newPropPath)
            payloadDoc = { "items" => items}
            entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, payloadDoc)
          else
            propObj = propSel.getMultiObj(@propPath)
            if(@propPath =~ /\]$/)
              unless(@aspect)
                entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, propObj[0])
              else
                if(@aspect == 'value')
                  itemRootProp = propObj[0].keys[0]
                  entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, { "value" => propObj[0][itemRootProp]['value'] })
                end
              end
            else
              valueObj = propObj[0][propObj[0].keys[0]]
              unless(@aspect)
                entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, valueObj)
              else
                if(@aspect == 'value')
                  entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, { "value" => valueObj['value'] })
                end
              end
            end
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "setting md")
          end
          docRef = @dataHelper.getDocRefFromDocName(@model['name'], @docName)
          metadata = @dataHelper.getMetadata(docRef, nil, @propPath)
          entity.setMetadata(metadata)
        rescue => err
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace.join("\n"))
          raise BRL::Genboree::GenboreeError.new(:"Bad Request", err.message)
        end
        @statusName = configResponse(entity)
      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = err.type
          @statusMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace.join("\n"))
          @statusName = :"Internal Server Error"
          @statusMsg = err.message
        end
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end

    # Process a PUT operation on this resource.
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    def put()
      initStatus = initOperation()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        # @todo if public or subscriber, can get info
        if(WRITE_ALLOWED_ROLES[@groupAccessStr])
          # Get dataCollectionHelper to aid us
          dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
          if(dataHelper)
            begin
              payload = parseRequestBodyForEntity('KbDocEntity', { :docType => "data"})
              if(payload.nil?)
                @statusName = :'Bad Request'
                @statusMsg = "NO_PAYLOAD: You need to provide a property oriented document to update a property."
              elsif(payload == :'Unsupported Media Type') # not correct payload content
                @statusName = :'Unsupported Media Type'
                @statusMsg = "BAD_DOC: the GenboreeKB doc you provided in the payload is not valid. Either the document is empty or doesn't follow the property-based document structure. This is not allowed."
              else # payload present
                # Get payload doc
                payloadDoc = BRL::Genboree::KB::KbDoc.new(payload.doc) rescue nil
                kbDoc = BRL::Genboree::KB::KbDoc.new(@doc)
                originalKbDoc = kbDoc.deep_clone
                propSel = BRL::Genboree::KB::PropSelector.new(kbDoc)
                begin
                  paths = propSel.getMultiPropPaths(@propPath)
                  $stderr.debugPuts(__FILE__, __method__, "DEBUG", "paths extracted from propSelector: #{paths.inspect}")
                  subsPropPath = nil
                  # Path doesn't yet exist in the current document. 
                  if(paths.empty?)
                    # Trying to put a new item using {}. Anything else is forbidden
                    raise BRL::Genboree::GenboreeError.new(:"Bad Request", "Cannot create property within an item which does not exist.") if(@propPath !~ /\}$/)
                    pathElements = @propPath.split(".")
                    subsPropPath = "#{pathElements[0..pathElements.size-4].join(".")}.[LAST]"
                    paths = propSel.getMultiPropPaths(subsPropPath)
                  else # Path exists in the current document. 
                    # If workingRevision is provided, match is against the current revision of the subdoc
                    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Going to match revision number since path exists in doc...")
                    workingRevisionMatched = true
                    workingRevisionMatched = dataHelper.matchWorkingRevisionWithCurrentRevision(@workingRevision, @doc['_id'], @collName, @propPath) if(@workingRevision)
                    unless(workingRevisionMatched)
                      raise BRL::Genboree::GenboreeError.new(:"Conflict", " WORKING_COPY_OUT_OF_DATE: Your working copy of the document is out-of-date. The document has been changed since you last retrieved it. To prevent loss of new content or the saving of deleted content, your document change has been rejected.")
                    end
                  end
                  pathElements = kbDoc.parsePath(paths[0])
                  parentProp = kbDoc.findParent(pathElements)
                rescue => err
                  if(err.is_a?(BRL::Genboree::GenboreeError))
                    raise BRL::Genboree::GenboreeError.new(err.type.to_sym, err.message)
                  else
                    raise BRL::Genboree::GenboreeError.new(:"Bad Request", err.message)
                  end
                end
                respPayload = {}
                pathEls = []
                if(payloadDoc)
                  dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
                  respPayload = {}
                  subdoc = nil
                  @propDef = @mh.findPropDef(@propPath.gsub(/\.\{([^\.])*\}/, ''), @modelDoc)
                  # We will now update the document with the updated property and perform a validation to ensure
                  # @propPath ends with an ']' which means an item is being inserted/replaced using index
                  if(@propPath =~ /\]$/)
                    itemInsertion = true
                    itemRootProp = @propDef['items'][0]['name']
                    propItems = propSel.getMultiPropItems(@propPath)
                    @propPath =~ ITEM_MATCH
                    extractedIdx = $1
                    idx = 0
                    if(extractedIdx =~ /\d+/)
                      idx = extractedIdx.to_i
                    elsif(extractedIdx == 'FIRST')
                      idx = 0
                    elsif(extractedIdx == 'LAST')
                      # Nothing to do
                    else
                      raise BRL::Genboree::GenboreeError.new(:"Bad Request", "The index: #{extractedIdx} is not supported.")
                    end
                    unless(parentProp.key?('items'))
                      parentProp['items'] = [] 
                      addItemsPropToParent = true  
                    end
                    idx = parentProp['items'].size if(extractedIdx == 'LAST')
                    if(idx >= parentProp['items'].size)
                      newItem = true
                      parentProp['items'].push(payloadDoc)
                      idx = parentProp['items'].size - 1
                    else
                      parentProp['items'][idx] = payloadDoc 
                    end
                    itemValue = payloadDoc['value']
                    respPayload = parentProp['items'][idx]
                  elsif(@propPath =~ /\}$/) # Also an item but being accessed using identifier and not index. 
                    itemInsertion = true
                    if(subsPropPath.nil?)
                      itemIdx = pathElements[pathElements.size-2] 
                      parentProp[itemIdx][@propDef['name']] = payloadDoc
                    else
                      unless(parentProp.key?('items'))
                        parentProp['items'] = [] 
                        addItemsPropToParent = true  
                      end
                      parentProp['items'].push( { @propDef['name'] => payloadDoc } )
                      newItem = true
                    end
                    respPayload = payloadDoc
                  else # Regular property or the "items" array of a list
                    @mh = @mongoKbDb.modelsHelper()
                    @modelDoc = @mh.modelForCollection(@collName)
                    propName = @propPath.split(".").last
                    if(parentProp.is_a?(Hash))
                      unless(parentProp.key?('properties'))
                        parentProp['properties'] = {} 
                        addPropertiesPropToParent = true ;
                      end
                      parentProp['properties'][propName] = payloadDoc
                    else # parentProp is an array object (items)
                      # Extract index
                      itemInsertion = true
                      idx = pathElements[pathElements.size-2]
                      if(idx >= parentProp.size)
                        newItem = true
                        parentProp.push({ pathElements[pathElements.size-1 ] => payloadDoc})
                      else
                        parentProp[idx] = { pathElements[pathElements.size-1 ] => payloadDoc}
                      end
                    end
                    respPayload = payloadDoc
                  end
                  # Do a fake save just for validation
                  # @todo Wow, ugh. This ends up revalidating the WHOLE DOC, even while we change just a piece.
                  # @todo DocValidator can validate sub-doc vs sub-doc model (i.e. the tree at and below a given propDef from the model)
                  #   In fact, that is how DocValidator WORKS internally!
                  #   Perhaps a few little extra checks to make sure the sub-doc--which in most cases will have relaxed root validation
                  #   since actual sub-docs are not at the root level--but this could be implemented, and then avoid cost of revalidating everything.
                  objId = dataHelper.save(kbDoc, @gbLogin, {:save => false})
                  if(objId.is_a?(BSON::ObjectId))
                    if(@save)
                      payloadDocClone = payloadDoc.deep_clone
                      objId = dataHelper.saveSubDoc(@docName, @gbLogin, @propPath, payloadDocClone, { })
                    end
                  elsif(objId.is_a?(BRL::Genboree::KB::KbError))
                    raise BRL::Genboree::GenboreeError.new(:"Bad Request", "DOC_REJECTED: your put operation was rejected because validation after putting the subdoc failed. Validation complained that: #{objId.message}")
                  else
                    raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "SAVE_FAILED: Tried to save your document, but the save unexpectedly failed (returned #{objId.inspect} rather than what was expected). Possible configuration problem or bug.")
                  end
                  bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, respPayload)
                  configResponse(bodyData)
                else
                  @statusName = :'Unsupported Media Type'
                  @statusMsg = "BAD_DOC: the GenboreeKB doc you provided in the payload is not a valid property-based document."
                end
              end # if(payloadDoc)
            rescue => err
              $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
              $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace.join("\n"))
              if(err.is_a?(BRL::Genboree::GenboreeError))
                @statusName = err.type
                @statusMsg = err.message
              else
                @statusName = :"Internal Server Error"
                @statusMsg = err.message
              end
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
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end


    # Process a DELETE operation on this resource.
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    def delete
      begin
        initStatus = initOperation() # error if not ok
        propHash = {}
        dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
        kbDoc = BRL::Genboree::KB::KbDoc.new(@doc)
        propSel = BRL::Genboree::KB::PropSelector.new(kbDoc)
        paths = nil
        begin
          paths = propSel.getMultiPropPaths(@propPath)
          elems = kbDoc.parsePath(paths[0])
          parent = kbDoc.findParent(elems)
        rescue => err
          $stderr.debugPuts(__FILE__, __method__, "ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "ERROR-TRACE", err.backtrace.join("\n"))
          raise BRL::Genboree::GenboreeError.new(:"Bad Request", err.message)
        end
        if(paths and !paths.empty? and @workingRevision)
          # If workingRevision is provided, match is against the current revision of the subdoc
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Going to match revision number since @workingRevision has been provided...")
          workingRevisionMatched = true
          workingRevisionMatched = dataHelper.matchWorkingRevisionWithCurrentRevision(@workingRevision, @doc['_id'], @collName, @propPath) 
          unless(workingRevisionMatched)
            raise BRL::Genboree::GenboreeError.new(:"Conflict", " WORKING_COPY_OUT_OF_DATE: Your working copy of the document is out-of-date. The document has been changed since you last retrieved it. To prevent loss of new content or the saving of deleted content, your document change has been rejected.")
          end
        end
        respPayload = {}
        @propDef = @mh.findPropDef(@propPath.gsub(/\.\{([^\.])*\}/, ''), @modelDoc)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "parent: #{parent.inspect}")
        # For an item under an item list
        if(@propPath =~ /\]$/)
          @propPath =~ ITEM_MATCH
          extractedIdx = $1
          idx = 0
          if(extractedIdx =~ /\d+/)
            idx = extractedIdx.to_i
          elsif(extractedIdx == 'FIRST')
            idx = 0
          elsif(extractedIdx == 'LAST')
            # Nothing to do
          else
            raise BRL::Genboree::GenboreeError.new(:"Bad Request", "The index: #{extractedIdx} is not supported.")
          end
          deleted = false
          idx = ( parent['items'].size - 1 ) if(extractedIdx == 'LAST')
          deleted = parent['items'].delete_at(idx)
          unless(deleted)
            raise BRL::Genboree::GenboreeError.new(:"Not Found", "There is no item at index: #{extractedIdx} for property path: #{@propPath} in the document #{@docName}")
          else
            respPayload = deleted
          end
        elsif(@propPath =~ /\}$/)
          itemIdx = elems[elems.size-2]
          deleted = parent.delete_at(itemIdx)
          respPayload = deleted
        else # Regular property (non-item)
          if(parent.is_a?(Hash))
            if(@propDef.key?('required') and @propDef['required'] == true and @validate)
              raise BRL::Genboree::GenboreeError.new(:"Bad Request", "The property indicated by the path #{@propPath} is tagged as required. You cannot delete it.")
            end
            propName = @propPath.split(".").last
            respPayload = parent['properties'][propName]
            parent['properties'].delete(propName)
          else
            idx = elems[elems.size-2]
            deleted = parent.delete_at(idx)
            unless(deleted)
              raise BRL::Genboree::GenboreeError.new(:"Not Found", "There is no item at index: #{idx} for property path: #{@propPath} in the document #{@docName}")
            else
              respPayload = deleted
            end
          end
        end
        # Do validation.
        objId = dataHelper.save(kbDoc, @gbLogin, {:save => false})
        if(objId.is_a?(BSON::ObjectId))
          if(@save) # Validation successful, do real delete
            objId = dataHelper.deleteSubDoc(@docName, @gbLogin, @propPath)
            @statusMsg = "SUCCESS: The sub document at #{@propPath} has been successfully deleted."
          else
            @statusMsg = "NO_SAVE_SUCCESS: The sub document at #{@propPath} can be successfully deleted. Use save=true for performing a real DELETE operation."
          end
        elsif(objId.is_a?(BRL::Genboree::KB::KbError))
          raise BRL::Genboree::GenboreeError.new(:"Bad Request", "DOC_REJECTED: your delete operation was rejected because validation after deleting the subdoc failed. Validation complained that: #{objId.message}")
        else
          raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "SAVE_FAILED: Tried to save your document, but the save unexpectedly failed (returned #{objId.inspect} rather than what was expected). Possible configuration problem or bug.")
        end
        @statusName = :OK
        bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, respPayload, true, @statusName, @statusMsg)
        configResponse(bodyData)
      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = err.type
          @statusMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace.join("\n"))
          @statusName = :"Internal Server Error"
          @statusMsg = err.message
        end
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp

    end

    def matchRejectionSet?(prop)
      retVal = false
      REJECTION_SET_REG_EXPS.each { |regExp|
        if(prop =~ regExp)
          retVal = true
          break
        end
      }
      return retVal
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
  
  end

  
end; end; end
