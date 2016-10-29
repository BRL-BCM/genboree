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
    SUPPORTED_ASPECTS = { 'put' => { 'value' => true }, 'get' => { 'value' => true }, 'delete'=> {} }
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
      # Optional Parameter for performing a no-op put/delete
      @save     = ( ( @nvPairs['save'] and @nvPairs['save'] == 'false' ) ? false : true  )
      # @todo: test and enable the save=false option
      raise BRL::Genboree::GenboreeError.new(:"Bad Request", "save=false option is currently unsupported.") if(!@save)
      # Optional supporting parameter for @save
      @validate = ( ( @nvPairs['validate'] and @nvPairs['validate'] == 'false' ) ? false : true )
      raise BRL::Genboree::GenboreeError.new(:"Bad Request", "validate cannot be set to false if save=true.") if(@save and !@validate)
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
      dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "@propPath: #{@propPath.inspect}")
      docNameValidation = docNameCast(@docName, model, dataHelper)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC NAME cast results: #{docNameValidation.inspect}")
      if(docNameValidation and docNameValidation[:result] == :VALID) # looks compatible and has now been casted appropriately
        @docName = docNameValidation[:castValue] # use casted value
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC NAME NOW: #{@docName.inspect}")
        @doc = dataHelper.getByIdentifier(@docName, { :doOutCast => true, :castToStrOK => true })
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
        rescue => err
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

    # @todo: implement PUT properly. This method is only partly done.
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
                propSel = BRL::Genboree::KB::PropSelector.new(kbDoc)
                begin
                  paths = propSel.getMultiPropPaths(@propPath)
                  $stderr.debugPuts(__FILE__, __method__, "DEBUG", "paths: #{paths.inspect}")
                  subsPropPath = nil
                  if(paths.empty?)
                    # Trying to put a new item using {}
                    raise BRL::Genboree::GenboreeError.new(:"Bad Request", "Cannot create property within an item which does not exist.") if(@propPath !~ /\}$/)
                    elems = @propPath.split(".")
                    subsPropPath = "#{elems[0..elems.size-4].join(".")}.[LAST]"
                    paths = propSel.getMultiPropPaths(subsPropPath)
                  end
                  elems = kbDoc.parsePath(paths[0])
                  parent = kbDoc.findParent(elems)
                rescue => err
                  raise BRL::Genboree::GenboreeError.new(:"Bad Request", err.message)
                end
                respPayload = {}
                dv = BRL::Genboree::KB::Validators::DocValidator.new()
                pathEls = []
                dv.validationErrors = []
                dv.validationMessages = []
                dv.uniqueProps = { :scope => :collection, :props => Hash.new{|hh, kk| hh[kk] = {} }}
                if(payloadDoc)
                  dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
                  respPayload = {}
                  subdoc = nil
                  @propDef = @mh.findPropDef(@propPath.gsub(/\.\{([^\.])*\}/, ''), @modelDoc)
                  # Looks like an item
                  if(@propPath =~ /\]$/)
                    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@propDef: #{@propDef.inspect}")
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
                    # Check if parent has the items field, add it if it doesn't
                    # At this point, we don't care if this property really supports 'items' or not. Downstream validation will make sure user is not trying something which is not allowed.
                    parent['items'] = [] unless(parent.key?('items'))
                    idx = parent['items'].size if(extractedIdx == 'LAST')
                    if(idx >= parent['items'].size)
                      # Entire sub doc provided as payload
                      unless(@aspect)
                        parent['items'].push(payloadDoc)
                      else
                        # @todo move this block into a function for better aspect handling
                        if(@aspect == 'value')
                          parent['items'].push( { @propDef['items'][0]['name'] => payloadDoc } )
                        end
                      end
                      idx = parent['items'].size - 1
                    else
                      unless(@aspect)
                        parent['items'][idx] = payloadDoc 
                      else
                        if(@aspect == 'value')
                          parent['items'][idx][itemRootProp]['value'] = payloadDoc['value']
                        end
                      end
                    end
                    itemValue = payloadDoc['value']
                    #@propPath.gsub!(ITEM_MATCH, ".[].#{itemRootProp}.{\"#{itemValue}\"}")
                    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "@propPath: #{@propPath.inspect}")
                    if(!@save)
                      dv.validateProperty(propName, parent, @propDef, pathEls)
                      if(!dv.contentNeeded.empty?)
                        generator = BRL::Genboree::KB::ContentGenerators::Generator.new(dv.contentNeeded, kbDoc, @collName, @mongoKbDb)
                        contentStatus = generator.addContentToDoc()
                      end
                    end
                    respPayload = parent['items'][idx]
                  elsif(@propPath =~ /\}$/)
                    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "@propPath: #{@propPath}")
                    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "subsPropPath: #{subsPropPath.inspect}")
                    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "elems: #{elems.inspect}")
                    if(subsPropPath.nil?)
                      itemIdx = elems[elems.size-2] 
                      parent[itemIdx][@propDef['name']] = payloadDoc
                    else
                      parent['items'] = [] unless(parent.key?('items'))
                      parent['items'].push( { @propDef['name'] => payloadDoc } )
                    end
                  else # Not an item, regular property
                    @mh = @mongoKbDb.modelsHelper()
                    @modelDoc = @mh.modelForCollection(@collName)
                    propName = @propPath.split(".").last
                    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "parent: #{parent.inspect}")
                    parent['properties'] = {} unless(parent.key?('properties'))
                    unless(@aspect)
                      parent['properties'][propName] = payloadDoc
                    else
                      if(@aspect == 'value')
                        if(parent['properties'].key?(propName))
                          parent['properties'][propName]['value'] = payloadDoc['value']
                        else
                          parent['properties'][propName] = payloadDoc
                        end
                      end
                    end
                    if(!@save)
                      dv.validateProperty(propName, payloadDoc, @propDef, pathEls)
                      if(!dv.contentNeeded.empty?)
                        generator = BRL::Genboree::KB::ContentGenerators::Generator.new(dv.contentNeeded, kbDoc, @collName, @mongoKbDb)
                        contentStatus = generator.addContentToDoc()
                      end
                    end
                    respPayload = payloadDoc
                  end
                  if(@save) # This is an actual save operation. Not a no-op
                    objId = dataHelper.save(kbDoc, @gbLogin, {:subDocPath => @propPath, :newValue => payloadDoc})
                    if(objId.is_a?(BSON::ObjectId))
                      # We are fine.
                    elsif(objId.is_a?(BRL::Genboree::KB::KbError))
                      raise BRL::Genboree::GenboreeError.new(:"Bad Request", "DOC_REJECTED: your put operation was rejected because validation after putting the subdoc failed. Validation complained that: #{objId.message}")
                    else
                      raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "SAVE_FAILED: Tried to save your document, but the save unexpectedly failed (returned #{objId.inspect} rather than what was expected). Possible configuration problem or bug.")
                    end
                  else # This is a no-op operation. Just validate the doc if validate=true
                    if(@validate)
                      $stderr.debugPuts(__FILE__, __method__, "STATUS", "validating doc after adding subdoc...")
                      valid = dataHelper.valid?(kbDoc, false, true)
                      if(!valid)
                        if(dataHelper.lastValidatorErrors.is_a?(Array))
                          validationErrStr = "  - #{dataHelper.lastValidatorErrors.join("\n  - ")}"
                        else
                          validationErrStr = "  - [[ No detailed validation error messages available ; likely a code bug or crash in validation or content-generation code ]]"
                        end
                        raise BRL::Genboree::GenboreeError.new(:"Bad Request", "DOC_REJECTED: your PUT operation was rejected because validation of the document after adding the subdoc failed. Validator complained that: #{validationErrStr}")
                        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Validator complained that: #{validationErrStr}")
                      else
                        $stderr.debugPuts(__FILE__, __method__, "STATUS", "validation complete.")
                      end
                    end
                  end
                  bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, respPayload)
                  configResponse(bodyData)
                else
                  @statusName = :'Unsupported Media Type'
                  @statusMsg = "BAD_DOC: the GenboreeKB doc you provided in the payload is not a valid property-based document."
                end
              end # if(payloadDoc)
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
        begin
          paths = propSel.getMultiPropPaths(@propPath)
          elems = kbDoc.parsePath(paths[0])
          parent = kbDoc.findParent(elems)
        rescue => err
          raise BRL::Genboree::GenboreeError.new(:"Bad Request", err.message)
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
          @mh = @mongoKbDb.modelsHelper()
          @modelDoc = @mh.modelForCollection(@collName)
          if(@propDef.key?('required') and @propDef['required'] == true and @validate)
            raise BRL::Genboree::GenboreeError.new(:"Bad Request", "The property indicated by the path #{@propPath} is tagged as required. You cannot delete it.")
          end
          propName = @propPath.split(".").last
          respPayload = parent['properties'][propName]
          parent['properties'].delete(propName)
        end
        if(@save) # This is an actual delete operation. Not a no-op
          #objId = dataHelper.save(kbDoc, @gbLogin)
          objId = dataHelper.save(kbDoc, @gbLogin, {:subDocPath => @propPath, :newValue => {}, :deleteProp => true})
          if(objId.is_a?(BSON::ObjectId))
            bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, respPayload )
            @statusName = :OK
            @statusMsg = "DELETED_SUBDOC: The subdoc at path #{@propPath} was deleted."
            configResponse(bodyData)
          elsif(objId.is_a?(BRL::Genboree::KB::KbError))
            raise BRL::Genboree::GenboreeError.new(:"Bad Request", "DOC_REJECTED: your delete operation was rejected because validation after deleting the subdoc failed. Validation complained that: #{objId.message}")
          else
            raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "SAVE_FAILED: Tried to save your document, but the save unexpectedly failed (returned #{objId.inspect} rather than what was expected). Possible configuration problem or bug.")
          end
        else # This is a no-op operation. Just validate the doc if validate=true. 
          if(@validate)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "validating doc after removing sub doc...")
            valid = dataHelper.valid?(kbDoc, false, true)
            if(!valid)
              if(dataHelper.lastValidatorErrors.is_a?(Array))
                validationErrStr = "  - #{dataHelper.lastValidatorErrors.join("\n  - ")}"
              else
                validationErrStr = "  - [[ No detailed validation error messages available ; likely a code bug or crash in validation or content-generation code ]]"
              end
              raise BRL::Genboree::GenboreeError.new(:"Bad Request", "DELETE_REJECTED: your delete operation was rejected because validation of the document after deleting the subdoc failed. Validator complained that: #{validationErrStr}")
              $stderr.debugPuts(__FILE__, __method__, "ERROR", "Validator complained that: #{validationErrStr}")
            else
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "validation complete.")
            end
          end
          bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, respPayload)
          @statusName = :OK
          @statusMsg = "NO_SAVE_SUCCESS: The sub document at #{@propPath} can be successfully deleted. Use save=true for performing a real DELETE operation."
          configResponse(bodyData)
        end
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