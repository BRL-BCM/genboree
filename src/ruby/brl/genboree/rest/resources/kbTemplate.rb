#!/usr/bin/env ruby
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/kb/validators/templateValidator'
require 'brl/genboree/kb/helpers/templatesHelper'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  # KbTemplate - exposes the template (using the id of a template) for a collection within a GenboreKB knowledgebase
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::KbDocEntityList
  # * BRL::Genboree::REST::Data::KbDocEntity
  class KbTemplate < BRL::REST::Resources::GenboreeResource

    # @return [Hash{Symbol=>Object}] Map of what http methods this resource supports ( @{ :get => true, :put => false }@, etc } ).
    HTTP_METHODS = { :get => true, :put => true }
    RSRC_TYPE = 'kbTemplate'
    SUPPORTED_ASPECTS = { "doc" => true, "propPathsValue" => true }
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
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/template/([^/\?]+)(?:$|/([^/\?]+)$)$}
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
        @templateId = Rack::Utils.unescape(@uriMatchData[4])
        @aspect = (@uriMatchData[5].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[5])
        # This function will set @groupId if it exists, return value is :OK or :'Not Found'
        initStatus = initGroupAndKb()
        if(initStatus == :OK)
          if @aspect and !SUPPORTED_ASPECTS.key?(@aspect)
            initStatus = :"Bad Request"
            @statusName = :"Bad Request"
            @statusMsg = "NOT_SUPPORTED: You have requested for an unsupported apsect: #{@aspect.inspect}. Supported aspectes include: #{SUPPORTED_ASPECTS.keys.join(",")}"
          end
        end
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    def get()
      begin
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
              @modelsHelper = @mongoKbDb.modelsHelper()
              cursor = templatesHelper.coll.find( { "id.value" => @templateId }  )
              templateDoc = nil
              # Should be just one, if matched
              cursor.each {|dd|
                templateDoc = BRL::Genboree::KB::KbDoc.new(dd)
              }
              if(templateDoc and !templateDoc.empty?)
                templateDocId = templateDoc['_id'].deep_clone
                templateDoc.delete("_id")
                bodyData = nil
                if(!@aspect)
                  bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, templateDoc)
                  bodyData.metadata = templatesHelper.getMetadata(templateDocId, "kbTemplates")
                else
                  if(@aspect == 'propPathsValue')
                    payload = parseRequestBodyForEntity('TextEntityList')
                    payloadArray = payload.array
                    propPaths = []
                    payloadArray.each {|obj|
                      propPaths.push(obj.text)
                    }
                    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "propPaths: \n#{propPaths.inspect}")
                    if(payload.nil?)
                      @statusName = :'Bad Request'
                      @statusMsg = "BAD_REQUEST: No payload provided. You need to provide a list (Text Entity) of one or more valid property paths."
                    elsif(payload == :'Unsupported Media Type')
                      @statusName = :'Unsupported Media Type'
                      @statusMsg = "The payload you provided is not valid. You need to provide a list (Text Entity) of one or more valid property paths."
                    else
                      propPathToValueHash = send(@aspect.to_sym, templateDoc, propPaths)
                      bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, propPathToValueHash)
                      bodyData.metadata = templatesHelper.getMetadata(templateDocId, "kbTemplates")
                    end
                  else
                    bodyData = send(@aspect.to_sym, templateDoc)  
                  end
                end
                @statusName = configResponse(bodyData)
              else
                @statusName = :'Not Found'
                @statusMsg = "NO_TEMPLATE: there is no template: #{@templateId} for collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect}, most likely because there is no valid collection #{@collName.inspect} (check spelling/case, etc)."
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
        # Only admins have the authority to create/add templates for now.
        if(@groupAccessStr and @groupAccessStr == 'o')
          # Get templatesHelper
          templatesHelper = @mongoKbDb.templatesHelper()
          payload = parseRequestBodyForEntity('KbDocEntity')
          if(payload.nil?)
            @statusName = :'Bad Request'
            @statusMsg = "BAD_REQUEST: No payload provided. The GenboreeKB template document cannot be created without a valid payload document."
          elsif(payload == :'Unsupported Media Type')
            @statusName = :'Unsupported Media Type'
            @statusMsg = "BAD_MODEL_DOC: the GenboreeKB template doc you provided in the payload is not valid. Either the document is empty or doesn't follow the property-based document structure. This is not allowed."
          else
            payloadTemplateDoc = BRL::Genboree::KB::KbDoc.new(payload.doc)
            collMetadataHelper = @mongoKbDb.collMetadataHelper()
            coll = collMetadataHelper.metadataForCollection(@collName)
            if(coll and !coll.empty?)
              validator = BRL::Genboree::KB::Validators::TemplateValidator.new(@mongoKbDb)
              if(!validator.validate(payloadTemplateDoc))
                if( validator.respond_to?(:buildErrorMsgs) )
                  errors = validator.buildErrorMsgs()
                else
                  errors = validator.validationErrors
                end
                @statusName = :"Unsupported Media Type"
                @statusMsg = "BAD_DOC: The template document you provided does not match the GenboreeKB specifications:\n\n#{errors.join("\n")}"
              else
                if(@templateId != payloadTemplateDoc.getPropVal('id'))
                  @statusName = :"Unsupported Media Type"
                  @statusName = "BAD_DOC: template id from payload must match the template id provided in the URL."
                else
                  begin
                    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Passed Validation...")
                    templateDoc = nil
                    cursor = templatesHelper.coll.find( { 'id.value' => @templateId } )
                    cursor.each {|dd|
                      templateDoc = dd  
                    }
                    # There is a template with this id already. Update it with the new payload.
                    if(templateDoc and !templateDoc.empty?)
                      payloadTemplateDoc['_id'] = templateDoc["_id"]
                      workingRevisionMatched = true
                      if(@workingRevision)
                        workingRevisionMatched = templatesHelper.matchWorkingRevisionWithCurrentRevision(@workingRevision, templateDoc["_id"], "kbTemplates")
                      end
                      if(workingRevisionMatched)
                        templatesHelper.save(payloadTemplateDoc, @gbLogin)
                        bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, payloadTemplateDoc)
                        configResponse(bodyData)
                        @statusName = :'Moved Permanently'
                        @statusMsg = "UPDATED_TEMPLATE_DOC: The template document with the id: #{@templateId.inspect} for the collection: #{@collName} was updated."
                      else
                        @statusName = :"Conflict"
                        @statusMsg = " WORKING_COPY_OUT_OF_DATE: Your working copy of the document is out-of-date. The document has been changed since you last retrieved it. To prevent loss of new content or the saving of deleted content, your document change has been rejected."
                      end
                    else # No such template
                      templatesHelper.save(payloadTemplateDoc, @gbLogin)
                      bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, payloadTemplateDoc)
                      configResponse(bodyData)
                      @statusName = :'Created'
                      @statusMsg = "NEW_TEMPLATE_CREATED: Your new template document was created."
                    end
                  rescue => err
                    @statusName = :"Internal Server Error"
                    @statusMsg = :"ERROR: #{err}"
                  end
                end
              end
            else
              @statusName = :'Not Found'
              @statusMsg = "NO_COLL: there is no document collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect}."
            end
          end
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation. Only group admins have the authority to create and update models. This is because updating collection models is highly dangerous and can lead to document-model mismatch if not done properly."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def delete()
      # @todo No payload
      # @todo Must have permission
    end
    
    
    def doc(templateDoc)
      return templateDoc.getPropVal('id.template')
    end
    
    def propPathsValue(templateDoc, propPaths)
      # Extract the actual document first
      modelKbDoc = BRL::Genboree::KB::KbDoc.new(@modelsHelper.modelForCollection(@collName))
      modelDoc = modelKbDoc.getPropVal('name.model')
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "modelDoc: \n#{JSON.pretty_generate(modelDoc)}")
      rootProp = templateDoc.getPropVal('id.root')
      identProp = modelDoc['name']
      actualTmplDoc = nil
      if(rootProp == '' or rootProp == identProp)
        actualTmplDoc = { identProp => templateDoc.getPropVal('id.template') }
      else
        actualTmplDoc = { rootProp.split(".").last => templateDoc.getPropVal('id.template') }
      end
      propPaths = [propPaths] if(!propPaths.is_a?(Array))
      propSel = BRL::Genboree::KB::PropSelector.new(actualTmplDoc)
      propHash = {}
      propPaths.each {|propPath|
        if(propPath =~ /\]$/)
          begin
            propItems = propSel.getMultiPropItems(@propPath)
          rescue => err
            raise BRL::Genboree::GenboreeError.new(:"Bad Request", err.message)
          end
          raise BRL::Genboree::GenboreeError.new(:"Not Found", "The property at the specifed path: #{propPath} was not found in the template")  if(propItems.nil?)
          propVal = ( propItems[0].key?('value') ? propItems[0]['value'] : nil  )
          propHash[propPath] = propVal
        else
          begin
            paths = propSel.getMultiPropPaths(propPath)
            raise BRL::Genboree::GenboreeError.new(:"Not Found", "The property at the specifed path: #{propPath} was not found in the template")  if(paths.nil? or paths.empty?)
            kbDoc = BRL::Genboree::KB::KbDoc.new(actualTmplDoc)
            elems = kbDoc.parsePath(paths[0])
            parent = kbDoc.findParent(elems)
            propValObj = kbDoc.useParentForGetPropField(parent, elems)
            propVal = propValObj.key?('value') ? propValObj['value'] : nil
            propHash[propPath] = propVal
          rescue => err
            raise BRL::Genboree::GenboreeError.new(:"Bad Request", err.message)
          end
        end
      }
      return propHash
    end
    
    
  end # class KbModel < BRL::REST::Resources::GenboreeResource
end ; end ; end # module BRL ; module REST ; module Resources
