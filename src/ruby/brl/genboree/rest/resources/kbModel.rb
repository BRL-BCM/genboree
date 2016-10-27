#!/usr/bin/env ruby
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/kb/lookupSupport/kbDocLinks.rb'


module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  # KbModel - exposes the model for a collection within a GenboreKB knowledgebase
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::KbDocEntityList
  # * BRL::Genboree::REST::Data::KbDocEntity
  class KbModel < BRL::REST::Resources::GenboreeResource

    # @return [Hash{Symbol=>Object}] Map of what http methods this resource supports ( @{ :get => true, :put => false }@, etc } ).
    HTTP_METHODS = { :get => true, :put => true }
    RSRC_TYPE = 'kbModel'
    FORMATS = [ :JSON, :JSON_PRETTY, :TABBED_PROP_NESTING ]

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
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/model$}
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
        # This function will set @groupId if it exists, return value is :OK or :'Not Found'
        initStatus = initGroupAndKb()
        @versionNum = @nvPairs['versionNum'] ? @nvPairs['versionNum'].to_s.strip.to_f : false
        @unsafeForceModelUpdate = (@nvPairs['unsafeForceModelUpdate'].to_s =~ /^(?:yes|true)$/i ? true : false)
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
          # Get a modelsHelper to aid us
          modelsHelper = @mongoKbDb.modelsHelper()
          modelDoc = modelsHelper.modelForCollection(@collName)
          if(modelDoc and !modelDoc.empty?)
            if(!@versionNum)
              model = ( (repFormat == :JSON or repFormat == :JSON_PRETTY) ? modelDoc.getPropVal("name.model") : modelDoc)
              bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, model)
              @statusName = configResponse(bodyData)
            else # Requesting a specific version
              docId = modelDoc["_id"]
              versionsHelper = @mongoKbDb.versionsHelper('kbModels') rescue nil
              if(versionsHelper.nil?)
                @statusName = :"Internal Server Error"
                @statusMsg = "Failed to access versions collection for collection 'kbModels'"
              else
                dbRef = BSON::DBRef.new('kbModels', docId)
                # get specified version of the document
                versionDoc = versionsHelper.getVersion(@versionNum, dbRef)
                if(versionDoc.nil?)
                  @statusName = :"Not Found"
                  @statusMsg = "Requested version: #{@versionNum} for this model does not exist."
                else
                  modelDoc = versionDoc.getPropVal('versionNum.content')
                  modelDoc = BRL::Genboree::KB::KbDoc.new(modelDoc)
                  model = ( (repFormat == :JSON or repFormat == :JSON_PRETTY) ? modelDoc.getPropVal("name.model") : modelDoc)
                  bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, model)
                  @statusName = configResponse(bodyData)
                end
              end
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_MODEL: there is no model for collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect}, most likely because there is no valid collection #{@collName.inspect} (check spelling/case, etc)."
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
        # Only admins have the authority to create/add models for now.
        if(@groupAccessStr and @groupAccessStr == 'o')
          # Get collMetadataHelper
          collMetadataHelper = @mongoKbDb.collMetadataHelper()
          coll = collMetadataHelper.metadataForCollection(@collName)
          modelsHelper = @mongoKbDb.modelsHelper()
          if(!self.class::FORMATS.include?(@repFormat))
            @statusName = :'Bad Request'
            @statusMsg = "BAD_REQUEST: This format is currently not supported for uploading model documents. Use format=tabbed_prop_nesting or format=json"
          else
            payload = parseRequestBodyForEntity('KbDocEntity', { :docType => "model"})
            if(payload.nil?)
              @statusName = :'Bad Request'
              @statusMsg = "BAD_REQUEST: No payload provided. The GenboreeKB model document must minimally be a filled-in hash structure which at least defines a root-level property."
            elsif(payload == :'Unsupported Media Type')
              @statusName = :'Unsupported Media Type'
              @statusMsg = "BAD_MODEL_DOC: the GenboreeKB model doc you provided in the payload is not valid. Either the document is empty or doesn't follow the property-based document structure. This is not allowed."
            else
              payloadModelDoc = payload.doc
              if(!modelsHelper.valid?(payloadModelDoc))
                @statusName = :"Unsupported Media Type"
                @statusMsg = "BAD_MODEL_DOC: The model you provided does not match the GenboreeKB specifications:\n\n#{modelsHelper.lastValidatorErrors}"
              else
                modelDoc = modelsHelper.modelForCollection(@collName)
                # There is a model for this collection already
                # For now, we do not support this since it can make all the docs of a collection invalid if the model is not properly updated
                if(modelDoc and !modelDoc.empty?)
                  if(@unsafeForceModelUpdate)
                    modelDoc.setPropVal('name.model', payloadModelDoc)
                    modelsHelper.save(modelDoc, @gbLogin)
                    bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, payloadModelDoc)
                    configResponse(bodyData)
                    @statusName = :'Moved Permanently'
                    @statusMsg = "UPDATED_MODEL_DOC: The model document for the collection: #{@collName} was updated."
                  else
                    @statusName = :'Bad Request'
                    @statusMsg = "BAD_REQUEST: A model document for the collection #{@collName} already exists. Updating an exising model is currently not allowed since changing the model inappropriately can lead to all the documents in a collection becoming invalid."
                  end
                else # No model for this collection.
                  # Create the collection if it doesn't exist along with the new model
                  modelKbDoc = modelsHelper.docTemplate(@collName)
                  modelKbDoc.setPropVal('name.model', payloadModelDoc)
                  begin
                    status = nil
                    if(coll and !coll.empty?)
                      status = modelsHelper.save(modelKbDoc, @gbLogin)
                    else
                      opts = {}
                      opts['singularLabel'] = (@nvPairs.key?('singularLabel') ? @nvPairs['singularLabel'] : "Document" )
                      opts['pluralLabel'] = (@nvPairs.key?('pluralLabel') ? @nvPairs['pluralLabel'] : "Documents" )
                      status = @mongoKbDb.createUserCollection(@collName, @gbLogin, modelKbDoc, opts)
                      # create kbDocLinks Table
                      begin
                        kbDocLinks = BRL::Genboree::KB::LookupSupport::KbDocLinks.new(@collName, @mongoKbDb, true)
                      rescue => err
                        $stderr.debugPuts(__FILE__, __method__, "KbDocLinksTable_CREATE_ERROR", "Failed to create kbDocLinks table - #{err}")
                      end
                    end
                    if(status)
                      bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, payloadModelDoc)
                      configResponse(bodyData)
                      @statusName = :'Created'
                      @statusMsg = "NEW_DOC_MODEL: your new model document was saved."
                    else
                      @statusName = :"Internal Server Error"
                      @statusMsg = "INTERNAL_SERVER_ERROR: Could not save model. Unable to provide an explanation. Please contact the project administrator to resolve this issue."
                    end
                  rescue => err
                    @statusName = :"Internal Server Error"
                    @statusMsg = "INTERNAL_SERVER_ERROR:\n#{err.message}"
                    $stderr.debugPuts(__FILE__, __method__, "ERROR", err)
                  end
                end
              end
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
  end # class KbModel < BRL::REST::Resources::GenboreeResource
end ; end ; end # module BRL ; module REST ; module Resources
