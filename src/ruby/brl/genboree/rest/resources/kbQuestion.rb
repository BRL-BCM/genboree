require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/kb/validators/questionValidator'


module BRL; module REST; module Resources

# Operations for a set of questionnaires
class KbQuestion < GenboreeResource
  HTTP_METHODS = {:get => true, :put => true, :delete => true}
  RSRC_TYPE = 'kbQuestion'

  def cleanup()
    super()
    @groupName = @kbName = @collName = nil
  end

  def self.pattern()
    return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/quest/([^/\?]+)$}
  end

  def self.priority()
    return 6 
  end

  def initOperation()
    initStatus = super()
    if(initStatus == :OK)
      @groupName  = Rack::Utils.unescape(@uriMatchData[1])
      @kbName     = Rack::Utils.unescape(@uriMatchData[2])
      @collName   = Rack::Utils.unescape(@uriMatchData[3])
      @questId    = Rack::Utils.unescape(@uriMatchData[4])
      initStatus = initQuestion() # sets @mongoKbDb and @mongoQh
    end
    return initStatus
  end

  # Process a GET operation on this resource.
  # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
  #   or containing correct error information.
  def get()
    initStatus = initOperation()
    if(initStatus == :OK)
      questCollName = BRL::Genboree::KB::Helpers::QuestionsHelper::KB_CORE_COLLECTION_NAME
      unless(@mongoQh.coll.nil?)
        if(READ_ALLOWED_ROLES[@groupAccessStr])
          dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
          questHelper = @mongoKbDb.questionsHelper()
          if(dataHelper)
            entity = nil
            mgCursor = @mongoQh.coll.find({ "Questionnaire.value" =>  @questId })
            if(mgCursor and mgCursor.is_a?(Mongo::Cursor) and mgCursor.count == 1)
                mgCursor.rewind! # resets the cursor to its unevaluated state
                doc = BRL::Genboree::KB::KbDoc.new(mgCursor.first)
                qdocId = doc['_id']
                if(doc.getPropVal('Questionnaire.Coll') == @collName)
                  entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
                  entity.metadata = questHelper.getMetadata(qdocId, questCollName)
                  @statusName = configResponse(entity)
                else
                  @statusName = :'Not Found'
                  @statusMsg = "NO_QUESTIONNAIRE_DOCUMENT: There is no questionnaire document, #{@questId.inspect} for the collection - #{@collName} under #{@kbName} KB."
                end
              else 
                @statusName = :'Not Found'
                @statusMsg = "NO_QUESTIONNAIRE_DOCUMENT: There is no questionnaire document, #{@questId.inspect} for the collection - #{@collName} under #{@kbName} KB."
              end
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_COLL: can't get questionnaire document named #{@questId.inspect} because appears to be no data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
          end
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation."
        end
      else
        @statusName = :'Not Found'
        @statusMsg = "NO_QUESTIONNAIRE_COLL: can not get questionnaire document named #{@questId.inspect} because appears to be no internal collection #{questCollName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} . #{questCollName} is a GenboreeKB internal collection and absence of this collection means that the #{@kbName.inspect} is an outdated GenboreeKB."
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
      questCollName = BRL::Genboree::KB::Helpers::QuestionsHelper::KB_CORE_COLLECTION_NAME
      unless(@mongoQh.coll.nil?)
        if(WRITE_ALLOWED_ROLES[@groupAccessStr])
          dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
          if(dataHelper)
            payload = parseRequestBodyForEntity('KbDocEntity')
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Payload: #{payload.inspect}")
            if(payload.nil? or (payload.is_a?(BRL::Genboree::REST::Data::KbDocEntity) and payload.doc and payload.doc.empty?))
              @statusName = :'Not Implemented'
              @statusMsg = "EMPTY_DOC: The questionnaire document is empty."
            elsif(payload == :'Unsupported Media Type')
              @statusName = :'Unsupported Media Type'
              @statusMsg = "BAD_QUESTIONNAIRE_DOC: The questionnaire document is not valid. Either the document is empty or does not follow the property based document structure. This is not allowed."
            else
              begin
                # Try to validate the payload against the model document
                validator = BRL::Genboree::KB::Validators::QuestionValidator.new(@mongoKbDb, @collName)
                questDoc = payload.doc
                isValid = validator.validate(questDoc)
                if(isValid)
                  questHelper = @mongoKbDb.questionsHelper()
                  kbDocQuest = BRL::Genboree::KB::KbDoc.new(questDoc)
                  if(kbDocQuest.getPropVal('Questionnaire') != @questId)
                    @statusName = :"Bad Request"
                    @statusMsg = "BAD_REQUEST: Name of the questionnaire document in the payload does not match the name of the questionnaire provided in the resource path (URL)."
                  else
                    cursor = @mongoQh.coll.find({ 'Questionnaire.value' => @questId })
                    qDoc = nil
                    cursor.each {|dd|
                      qDoc = dd
                    }
                    # For an existing questionnaire
                    if(qDoc and !qDoc.empty?)
                      questDoc['_id'] = qDoc["_id"]
                      workingRevisionMatched = true
                      if(@workingRevision)
                        workingRevisionMatched = questHelper.matchWorkingRevisionWithCurrentRevision(@workingRevision, qdoc["_id"], questCollName)
                      end
                      if(workingRevisionMatched)
                        @mongoQh.save(questDoc, @gbLogin)
                        bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, questDoc)
                        configResponse(bodyData)
                        @statusName = :'Moved Permanently'
                        @statusMsg = "UPDATED_QUESTIONNAIRE: The questionnaire with the id: #{@questId.inspect} was updated."
                      else
                        @statusName = :"Conflict"
                        @statusMsg = " WORKING_COPY_OUT_OF_DATE: Your working copy of the document is out-of-date. The document has been changed since you last retrieved it. To prevent loss of new content or the saving of deleted content, your document change has been rejected."                        
                      end
                    else # New questionnaire
                      @mongoQh.save(questDoc, @gbLogin)
                      bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, questDoc)
                      configResponse(bodyData)
                      @statusName = :'Created'
                      @statusMsg = "NEW_QUESTIONNAIRE_CREATED: Your new questionnaire document was created."
                    end
                  end
                else
                  if( validator.respond_to?(:buildErrorMsgs) )
                    errors = validator.buildErrorMsgs()
                  else
                    errors = validator.validationErrors
                  end
                  @statusName = :"Bad Request"
                  @statusMsg = "BAD_QUESTIONNAIRE_DOC: The questionnaire document does not follow the specification of the questionnaire model or is invalid. Details : #{errors.join("\n")}"
                end
              rescue => err
                @statusName = :'Internal Server Error'
                @statusMsg = "INTERNAL_SERVER_ERROR: #{err}"
                $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
              end
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_COLL: can't put questionnaire document named #{@questId.inspect} because appears to be no data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
          end
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation."
        end
      else
        @statusName = :'Not Found'
        @statusMsg = "NO_QUESTIONNAIRE_COLL: can not get questionnaire document named #{@questId.inspect} because appears to be no internal collection #{questCollName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} . #{questCollName} is a GenboreeKB internal collection and absence of this collection means that the #{@kbName.inspect} is an outdated GenboreeKB."
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
      questCollName = BRL::Genboree::KB::Helpers::QuestionsHelper::KB_CORE_COLLECTION_NAME
      unless(@mongoQh.coll.nil?)
        if(WRITE_ALLOWED_ROLES[@groupAccessStr])
          dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
          if(dataHelper)
            begin
              entity = nil
              mgCursor = @mongoQh.coll.find({ "Questionnaire.value" => @questId })
              if(mgCursor and mgCursor.is_a?(Mongo::Cursor))
                if(mgCursor.count == 1)
                  mgCursor.rewind!
                  origDoc = mgCursor.first
                  doc = BRL::Genboree::KB::KbDoc.new(origDoc.deep_clone)
                  if(doc.getPropVal('Questionnaire.Coll') == @collName)
                    entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
                    workingRevisionMatched = true
                    if(@workingRevision)
                      workingRevisionMatched = @mongoQh.matchWorkingRevisionWithCurrentRevision(@workingRevision, origDoc["_id"], questCollName)
                    end
                    if(workingRevisionMatched)
                      @mongoQh.coll.remove( { "Questionnaire.value" => @questId } )
                      @statusMsg = "DELETED: The questionnaire document: #{@questId} was deleted from the database."
                      @statusName = :OK
                      configResponse(entity)
                    else
                      @statusName = :"Conflict"
                      @statusMsg = " WORKING_COPY_OUT_OF_DATE: Your working copy of the document is out-of-date. The document has been changed since you last retrieved it. To prevent loss of new content or the saving of deleted content, your document change has been rejected."                        
                    end
                  else
                    @statusName = :'Not Found'
                    @statusMsg = "NO_QUESTIONNAIRE_DOCUMENT: There is no questionnaire document, #{@questId.inspect} for the collection - #{@collName} under #{@kbName} KB."
                  end
                else
                  @statusName = :'Not Found'
                  @statusMsg = "NO_QUESTIONNAIRE_DOCUMENT: There is no questionnaire document, #{@questId.inspect} for the collection - #{@collName} under #{@kbName} KB."
                end
              else
                @statusName = :'Internal Server Error'
                @statusMsg = "DEL_QUESTIONNAIRE_DOC_FAILED: Deletion of the questionnaire document, #{@questId.inspect} failed. Check: #{err}"
              end
            rescue => err
              @statusName = :'Internal Server Error'
              @statusMsg = "INTERNAL_SERVER_ERROR: #{err}"
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_COLL:  There appears to be no data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
          end
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation."
        end
      else
       @statusName = :'Not Found'
       @statusMsg = "NO_QUESTIONNAIRE_COLL: can not get questionnaire document named #{@questId.inspect} because appears to be no internal collection #{questCollName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} . #{questCollName} is a GenboreeKB internal collection and absence of this collection means that the #{@kbName.inspect} is an outdated GenboreeKB."
      end
    end
    # If something wasn't right, represent as error
    @resp = representError() if(@statusName != :OK)
    return @resp
  end



end
end; end; end
