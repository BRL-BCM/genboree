#!/usr/bin/env ruby
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/kb/stats/collStats'
require 'brl/genboree/kb/lookupSupport/kbDocLinks.rb'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  # KbCollection - exposes information about a collection within within a GenboreKB knowledgebase
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::KbDocEntityList
  # * BRL::Genboree::REST::Data::KbDocEntity
  class KbCollection < BRL::REST::Resources::GenboreeResource

    # @return [Hash{Symbol=>Object}] Map of what http methods this resource supports ( @{ :get => true, :put => false }@, etc } ).
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    RSRC_TYPE = 'kbCollection'
    SUPPORTED_ASPECTS = ['labels', 'name', 'singularLabel', 'pluralLabel', 'tools', 'stats']
    # @api RestAPI INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    #   cleanup that might save memory and aid GC. Their version should call {#super}
    #   so any parent {#cleanup} will be done also.
    # @return [nil]
    def cleanup()
      super()
      @groupId = @groupName = @groupDesc = nil
      @mongoKbDb = @mongoDbrcRec = @kbId = @kbName = @kbDbName = nil
    end

    # @api RestAPI INTERFACE. return a {Regexp} that will match a correctly formed URI for this service
    #   The pattern will be applied against the URI's _path_.
    # @returns [Regexp]
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)(?:/([^/\?]+))?}
    end

    # @api RestAPI return integer from 1 to 10 that indicates whether the regexp/service is
    #   highly specific and should be examined early on, or whether it is more generic and
    #   other services should be matched for first.
    # @return [Fixnum] The priority, from 1 t o 10.
    def self.priority()
      return 5
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
        @aspect = (@uriMatchData[4].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[4])
        if(@aspect and !SUPPORTED_ASPECTS.include?(@aspect))
          initStatus = @statusName = :"Bad Request"
          @statusMsg = "BAD_REQUEST: Unsupported aspect provided. Supported aspects include: #{SUPPORTED_ASPECTS.join(", ")}"
        else
          # This function will set @groupId if it exists, return value is :OK or :'Not Found'
          initStatus = initGroupAndKb()
          @unsafeForceCollDeletion = (@nvPairs['unsafeForceCollDeletion'].to_s =~ /^(?:yes|true)$/i ? true : false)
          @unsafeForceCollRename = (@nvPairs['unsafeForceCollRename'].to_s =~ /^(?:yes|true)$/i ? true : false)
        end
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    def get()
      begin 
        initStatus = initOperation() # @set @mongoKbDb
        raise BRL::Genboree::GenboreeError.new(initStatus, @statusMsg) unless((200..299).include?(HTTP_STATUS_NAMES[initStatus]))

        if(@aspect.nil?)
          # Get collMetadataHelper
          collMetadataHelper = @mongoKbDb.collMetadataHelper()
          coll = collMetadataHelper.metadataForCollection(@collName)
          if(coll and !coll.empty?)
            bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, coll)
            @statusName = configResponse(bodyData)
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_COLL: there is no document collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect}."
          end
        elsif(@aspect == "stats")
          # sets @resp via configResponse
          getStats()
        else
          raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "Sorry! We indicated support for collection aspect #{@aspect.inspect} but forgot to implement it.")
        end
      rescue => err
        logAndPrepareError(err)
      end
      # If something wasn't right, represent as error
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end

    # Get list of statistic names that can be requested
    def getStats()
      rawDataEntity = BRL::Genboree::REST::Data::RawDataEntity.new(@connect, BRL::Genboree::KB::Stats::CollStats::STAT_DESCRIPTIONS)
      configResponse(rawDataEntity)
    end

    # Process a PUT operation on this resource.
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    def put()
      initStatus = initOperation()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        # Only admins have the authority to create/add  models and minipulate collections for now.
        if(@groupAccessStr and @groupAccessStr == 'o')
          # Get collMetadataHelper
          collMetadataHelper = @mongoKbDb.collMetadataHelper()
          coll = collMetadataHelper.metadataForCollection(@collName)
          if(coll and !coll.empty?)
            if(@aspect.nil?)
              @statusName = :'Bad Request'
              @statusMsg = "ALREADY_EXISTS: A collection with the name: #{@collName} already exists. You can only update labels of an existing collection which requires a property oriented payload/document."
            else
              payload = parseRequestBodyForEntity('KbDocEntity')
              if(payload.nil?)
                @statusName = :'Bad Request'
                @statusMsg = "BAD_REQUEST: No payload provided. You need to provide a property oriented document or text entity with the new collections name."
              elsif(payload == :'Unsupported Media Type')
                @statusName = :"Unsupported Media Type"
                @statusMsg = "BAD_PAYLOAD: The payload you provided does not seem to be a property oriented document."
              else
                begin
                  @statusName = :OK
                  payloadDoc = BRL::Genboree::KB::KbDoc.new(payload.doc)
                  # Check if the document has the 'labels' field. The earlier representation of the metadata document did not have this field.
                  if(!coll['name']['properties'].key?('labels'))
                    coll['name']['properties']['labels'] = { 'properties' => { 'singular' => { "value" => '' }, "plural" => { "value" => '' } } }
                  end
                  if(@aspect == 'labels')
                    if(!payloadDoc.getPropVal('singular') or !payloadDoc.getPropVal('plural'))
                      @statusName = :"Unsupported Media Type"
                      @statusMsg = "BAD_PAYLOAD: Payload must be of the structure: { 'singular': { 'value': '' }, 'plural': { 'value': ''} }"
                    else
                      svalue = payloadDoc.getPropVal('singular')
                      pvalue = payloadDoc.getPropVal('plural')
                      coll.setPropVal('name.labels.singular', svalue)
                      coll.setPropVal('name.labels.plural', pvalue)
                    end
                  elsif(@aspect == 'pluralLabel')
                    if(!payloadDoc.getPropVal('text') and !payloadDoc.getPropVal('plural'))
                      @statusName = :"Unsupported Media Type"
                      @statusMsg = "BAD_PAYLOAD: Payload must be of the structure: { 'text': { 'value': '' } } or { 'plural': { 'value': '' } } "
                    else
                      if(payloadDoc.getPropVal('text'))
                        coll.setPropVal('name.labels.plural', payloadDoc.getPropVal('text'))
                      else
                        coll.setPropVal('name.labels.plural', payloadDoc.getPropVal('plural'))
                      end
                    end
                  elsif(@aspect == 'singularLabel')
                    if(!payloadDoc.getPropVal('text') and !payloadDoc.getPropVal('singular'))
                      @statusName = :"Unsupported Media Type"
                      @statusMsg = "BAD_PAYLOAD: Payload must be of the structure: { 'text': { 'value': '' } } or { 'singular': { 'value': '' } }"
                    else
                      if(payloadDoc.getPropVal('text'))
                        coll.setPropVal('name.labels.singular', payloadDoc.getPropVal('text'))
                      else
                        coll.setPropVal('name.labels.singular', payloadDoc.getPropVal('singular'))
                      end
                    end
                  elsif(@aspect == 'tools')
                    # @todo: needs to be more robust
                    # Also should allow just collection level tools or doc level tools.
                    if(!coll['name']['properties'].key?('tools'))
                      coll['name']['properties']['tools'] = {}
                    end
                    coll['name']['properties']['tools'] = payloadDoc['tools']
                  elsif(@aspect == 'name')
                    # @todo implement
                    if(@unsafeForceCollRename)
                      if(!payloadDoc.getPropVal('text') and !payloadDoc.getPropVal('name'))
                        @statusName = :"Unsupported Media Type"
                        @statusMsg = "BAD_PAYLOAD: Payload must be of the structure: { 'text': { 'value': '' } } or { 'name': { 'value': '' } } "
                      else
                        if(payloadDoc.getPropVal('text'))
                          newName = payloadDoc.getPropVal('text')
                        else
                          newName = payloadDoc.getPropVal('name')
                        end

                        if( newName != @collName )
                          if( newName.size > 0 and newName.size <= 22 )
                            result = self.renameCollection(newName)
                            if(result)
                              @statusName = :'Moved Permanently'
                              @statusMsg = "COLL_RENAMED: The #{@collName.inspect} collection was renamed to #{newName.inspect}."
                              bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, {} )
                              bodyData.setStatus(@statusName, @statusMsg)
                              configResponse(bodyData, @statusName)
                            end
                          else
                            @statusName = :'Bad Request'
                            @statusMsg = "NAME_TOO_LONG: The new collection name of #{newName.inspect} is too long. Restrictions within the underlying storage engine mean excessively long collection names are not allowed. Try to be more succinct; 22 or fewer characters ."
                          end
                        else
                          @statusName = :'Bad Request'
                          @statusMsg = "NAMES_SAME: The new collection name of #{newName.inspect} is the same as the current collection name #{@collName.inspect}. There is no renaming to do."
                        end
                      end
                    else
                      @statusName = :'Bad Request'
                      @statusMsg = "BAD_REQUEST: Renaming a document collection is a very risky, multi-step, non-atomic, and potentially VERY LONG running operation (on large collections, especially ones with lots of historical edits). It's unwise to use the API to do this on a very large live collection, where it may block when it goes to update existing history documents for the collection. Renaming will trivially rename the collection and its history collections, but will also necessarily update the collection metadata document, the model document, and fix the namespace in ALL history records. Finally, renaming may INVALIDATE your existing document content: relative URL-domained properties that mention the old collection name in their value; you would be responsible for addressing those broken inter-doc links. Because of all this non-atomic and possibly blocking activity, and the impact on existing data & history content, additional parameters are required to perform a collection rename via the API."
                    end
                  end

                  # If aspect was metadata related only, have standard response
                  if( @statusName == :OK and ['labels', 'pluralLabel', 'singularLabel', 'tools'].include?(@aspect) )
                    collMetadataHelper.save(coll, @gbLogin)
                    coll = collMetadataHelper.metadataForCollection(@collName)
                    bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, coll)
                    @statusName = :'Moved Permanently'
                    @statusMsg = "UPDATED_COLL_LABEL: The metadata for collection #{@collName.inspect} was modified. Collection metadata for the updated collection available in payload."
                    configResponse(bodyData, :'Moved Permanently')
                  end
                rescue => err
                  @statusName = :"Internal Server Error"
                  @statusMsg = "INTERNAL_SERVER_ERROR:\n#{err.message}"
                  $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
                end
              end
            end
          elsif(!@aspect.nil?)
            @statusName = :'Bad Request'
            @statusMsg = "BAD_REQUEST: The collection #{@collName} does not exist. Please create this collection first with a model document payload."
          else
            modelsHelper = @mongoKbDb.modelsHelper()
            if(@repFormat == :TABBED_PROP_NESTING or @repFormat == :JSON)
              payload = parseRequestBodyForEntity('KbDocEntity', { :docType => "model"})
              if(payload.nil?)
                @statusName = :'Bad Request'
                @statusMsg = "BAD_REQUEST: No payload provided. You need to provide a GenboreeKB model document to create a new collection with."
              elsif(payload == :'Unsupported Media Type')
                @statusName = :'Unsupported Media Type'
                @statusMsg = "BAD_MODEL_DOC: the GenboreeKB model doc you provided in the payload is not valid. Either the document is empty or doesn't follow the property-based document structure. This is not allowed."
              else
                payloadModelDoc = payload.doc
                if(!modelsHelper.valid?(payloadModelDoc))
                  @statusName = :"Unsupported Media Type"
                  @statusMsg = "BAD_MODEL_DOC: The model you provided does not match the GenboreeKB specifications:\n\n#{modelsHelper.lastValidatorErrors.join("\n")}"
                else
                  modelKbDoc = modelsHelper.docTemplate(@collName)
                  modelKbDoc.setPropVal('name.model', payloadModelDoc)
                  begin
                    opts = {}
                    opts['singularLabel'] = (@nvPairs.key?('singularLabel') ? @nvPairs['singularLabel'] : "Document" )
                    opts['pluralLabel'] = (@nvPairs.key?('pluralLabel') ? @nvPairs['pluralLabel'] : "Documents" )
                    status = @mongoKbDb.createUserCollection(@collName, @gbLogin, modelKbDoc, opts)
                    # create the kbDocLinks Table for the collection
                    begin
                      kbDocLinks = BRL::Genboree::KB::LookupSupport::KbDocLinks.new(@collName, @mongoKbDb, true)
                    rescue => err
                      $stderr.debugPuts(__FILE__, __method__, "KbDocLinksTable_CREATE_ERROR", "Failed to create kbDocLinks table - #{err}")
                    end
                    if(status)
                      bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, payloadModelDoc)
                      configResponse(bodyData)
                      @statusName = :'Created'
                      @statusMsg = "NEW_DOC_MODEL: your new collection #{@collName} was created with the provided model document."
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
            else
              @statusName = :'Bad Request'
              @statusMsg = "BAD_REQUEST: This format is currently not supported for uploading model documents. Use format=tabbed_prop_nesting or format=json"
            end
          end
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation. Only group admins have the authority to create and update models. This is because updating collection models is highly dangerous and can lead to document-model mismatch if not done properly."
        end
      end
      # If something wasn't right, represent as error

      @resp = representError() if(@statusName != :OK or @statusName != :'Moved Permanently')
      return @resp
    end

    def delete()
      initStatus = initOperation() # @set @mongoKbDb
      if(initStatus == :OK)
        if(@aspect.nil?)
          if(@unsafeForceCollDeletion)
            # Only admins have the authority to create/add  models and minipulate collections for now.
            if(@groupAccessStr and @groupAccessStr == 'o')
              begin
                collMetadataHelper = @mongoKbDb.collMetadataHelper()
                collMeta = collMetadataHelper.metadataForCollection(@collName)
                if(collMeta)
                  dataCollHelper = @mongoKbDb.dataCollectionHelper( @collName )
                  result = dataCollHelper.dropCollection( @gbLogin )
                  if(result)
                    @statusName = :OK
                    @statusMsg = "OK: Deleted collection #{@collName.inspect}"
                    bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, collMeta)
                    @statusName = configResponse(bodyData)
                  else
                    @statusName = :'Not Found'
                    @statusMsg = "NO_COLL: The collection #{@collName.inspect} does not appear to exist or its metadata is corrupt. Cannot delete."
                  end
                else
                  @statusName = :'Not Found'
                  @statusMsg = "NO_COLL: The collection #{@collName.inspect} does not appear to exist or its metadata is corrupt. Cannot delete."
                end
              rescue => err
                @statusName = :'Internal Server Error'
                @statusMsg = "INTERNAL_SERVER_ERROR: A key operation unexpectedly failed during the proper deletion of the collection #{@collName.inspect}. Very likely that a PARTIAL deletion has occurred and that the collection is thus corrupt. The error was a #{err.class} whose message was #{err.message.inspect}. Contact adminstrators for help, including this message and exactly what group/kb you were working on, and the current date/time; futher details have been logged."
              end
            else
              @statusName = :Forbidden
              @statusMsg = "You do not have sufficient permissions to perform this operation. Because it results in complete data loss, including modification history, only group admins have the authority to destroy collections and all their contents."
            end
          else
            @statusName = :'Bad Request'
            @statusMsg = "BAD_REQUEST: Completely deleting a document collection results in complete and IRRETREIVABLE DATA LOSS, including all history information and the collection model in addition to actual document data. Are you sure you want to do this? Have you grabbed the model and other information for future reference? Because this is dangerous and irretreivable, additional parameters are required."
          end
        else
          @statusName = :'Bad Request'
          @statusMsg = "BAD_REQUEST: Delete is not supported for the #{@aspect.inspect} aspect of collections."
          @statusMsg = "BAD_REQUEST: Delete is not supported for the #{@aspect.inspect} aspect of collections."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end

    # ----------------------------------------------------------------
    # Helpers
    # ----------------------------------------------------------------

    def renameCollection(newName)
      retVal = false
      # Check newName arg
      if(newName and newName =~ /\S/)
        # Attempt rename
        begin
          # Get collMetadata (is collection real?)
          collMetadataHelper = @mongoKbDb.collMetadataHelper()
          collMeta = collMetadataHelper.metadataForCollection(@collName)
          if(collMeta)
            dataCollHelper = @mongoKbDb.dataCollectionHelper( @collName )
            result = dataCollHelper.renameCollection( newName, @gbLogin )
            if(result)
              retVal = result
            else
              @statusName = :'Not Found'
              @statusMsg = "NO_COLL: The collection #{@collName.inspect} does not appear to exist or its metadata is corrupt. Cannot delete."
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_COLL: The collection #{@collName.inspect} does not appear to exist or its metadata is corrupt. Cannot rename."
          end
        rescue => err
          @statusName = :'Internal Server Error'
          @statusMsg = "ERROR: A key operation failed, mostly likely due to user error violating a collection name restriction: The error was a #{err.class} whose message was #{err.message.inspect}. Alternatively, a system task has unexpectedly failed and it's very likely that a PARTIAL renaming has occurred, and that the collection and its support docs are thus corrupt. Contact adminstrators for help, including this message and exactly what group/kb  you were working on, and the current date/time; futher details have been logged."
        end
      else
        @statusName = :'Bad Request'
        @statusMsg = "BAD_REQUEST: You have not supplied an appropriate payload for the 'name' aspect of the #{@collName.inspect} collection. Cannot rename"
      end
      return retVal
    end
  end # class KbCollection < BRL::REST::Resources::GenboreeResource
end ; end ; end # module BRL ; module REST ; module Resources
