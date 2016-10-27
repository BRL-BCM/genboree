require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/kb/questions/questAndAnswersToDoc'

module BRL; module REST; module Resources

# Operations for Answers
class KbAnswer < GenboreeResource
  HTTP_METHODS = {:get => true, :put => true, :delete => true}
  RSRC_TYPE = 'kbAnswer'

  def cleanup()
    super()
    @groupName = @kbName = @collName = nil
  end

  def self.pattern()
    return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/quest/([^/\?]+)/answer/([^/\?]+|\s*)$}
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
      @answerId   = Rack::Utils.unescape(@uriMatchData[5])
      initStatus = initAnswer() # sets @mongoKbDb and @mongoAn
    end
    return initStatus
  end

  # Process a PUT operation on this resource.
  # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
  #   or containing correct error information.
  def put()
    initStatus = initOperation()
    if(initStatus == :OK)
      answerCollName = BRL::Genboree::KB::Helpers::AnswersHelper::KB_CORE_COLLECTION_NAME
      if(!@mongoAn.coll.nil?)
        if(WRITE_ALLOWED_ROLES[@groupAccessStr])
          dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
          if(dataHelper)
            identifier = dataHelper.getIdentifierName()
            payload = parseRequestBodyForEntity('KbDocEntity')
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Payload: #{payload.inspect}")
            if(payload.nil? or (payload.is_a?(BRL::Genboree::REST::Data::KbDocEntity) and payload.doc and payload.doc.empty?))
              @statusName = :'Not Implemented'
              @statusMsg = "EMPTY_DOC: The answer document is empty."
            elsif(payload == :'Unsupported Media Type')
              @statusName = :'Unsupported Media Type'
              @statusMsg = "BAD_ANSWER_DOC: The questionnaire document is not valid. Either the document is empty or does not follow the property based document structure. This is not allowed."
            else
              begin
                # Try to validate the payload against the model document
                answerDoc = payload.doc
                kbDocAnswer = BRL::Genboree::KB::KbDoc.new(answerDoc)
                if(kbDocAnswer.getPropVal('Answer').strip() == @answerId)
                  questDocName = kbDocAnswer.getPropVal('Answer.Questionnaire')
                  # Check the questionnaire ownership
                  # 1. questionnaire in the answer document is same as the one in the URL
                  if(questDocName.strip() == @questId)
                    # 2. Questionnaire is in fact already present
                    mgCursor = @mongoQh.coll.find({ "Questionnaire.value" =>  @questId })
                    if(mgCursor and mgCursor.is_a?(Mongo::Cursor))
                      mgCursor.rewind! # resets the cursor to its unevaluated state
                      doc = BRL::Genboree::KB::KbDoc.new(mgCursor.first)
                       # The questionnaire is owned by the right collection
                      if(doc.getPropVal('Questionnaire.Coll') == @collName)
                        questNAnsToDoc = BRL::Genboree::KB::Questions::QuestAndAnswersToDoc.new(@mongoKbDb, @collName, answerDoc)
                        newDataDoc = questNAnsToDoc.getDocFromAnswers()
                        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC NAME ::::::: #{newDataDoc.inspect}")
                        if(newDataDoc)
                          # Passed all the validation and the document saved in the user collection    
                          #  Save the answer document
                          cursor = @mongoAn.coll.find({ 'Answer.value' => @answerId })
                          anDoc = nil
                          cursor.each {|dd|
                            anDoc = dd
                          }
                          if(anDoc and !anDoc.empty?)
                            answerDoc['_id'] = anDoc["_id"]
                            @mongoAn.save(answerDoc, @gbLogin)
                          else
                            @mongoAn.save(answerDoc, @gbLogin)
                          end
                         
                          # save the new document generated
                          kbDataDoc = BRL::Genboree::KB::KbDoc.new(newDataDoc)
                          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC KB ::::::: #{kbDataDoc.inspect}")
                          if(@detailed)
                            entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, kbDataDoc)
                          else
                            entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, { "text" => { "value" => kbDataDoc.getPropVal(identifier)} })
                          end
                          @statusName = configResponse(entity)
                        else
                          @statusName = :"Bad Request"
                          @statusMsg = "DOC_BUILD_ERROR: Failed to build data document for the collection #{@collName} using the answer document #{@answerId}. Check: #{questNAnsToDoc.questAndAnsErrors}"
                        end
                      else
                        @statusName = :'Not Found'
                        @statusMsg = "BAD_REQUEST: Questionnaire -#{@questId}, is not owned by the collection #{@collName}. Collection name #{doc.getPropVal('Questionnaire.Coll')}, in the questionnaire document do not match the collection name in the URL." 
                      end
                    else
                      @statusName = :"Bad Request"
                      @statusMsg = "NO_QUESTIONNAIRE: can't put answer document named #{@answerId.inspect} because appears to be no questionnaire - #{@questId} in the collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
                    end
                  else
                    @statusName = :"Bad Request"
                    @statusMsg = "BAD_REQUEST: Name of the questionnaire in the answer document of the  payload does not match the name of the questionnaire in the resource path (URL)."
                  end
                else
                  @statusName = :"Bad Request"
                  @statusMsg = "BAD_REQUEST: Name of the answer document in the payload does not match the name of the answer document provided in the resource path (URL)."
                end
              rescue => err
                @statusName = :'Internal Server Error'
                @statusMsg = "INTERNAL_SERVER_ERROR: Failed to generate data document. Unknown Error.#{err}"
                $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
              end
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_COLL: can't put answer document named #{@answerId.inspect} because appears to be no data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
          end
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation."
        end
      else
        @statusName = :'Not Found'
        @statusMsg = "NO_ANSWER_COLL: can not put answer document named #{@answerId.inspect} because appears to be no internal collection #{answerCollName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} . #{answerCollName} is a GenboreeKB internal collection and absence of this collection means that the #{@kbName.inspect} is an outdated GenboreeKB."
      end
    end
    # If something wasn't right, represent as error
    @resp = representError() if(@statusName != :OK)
    return @resp
  end


  # Process a GET operation on this resource.
  # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
  #   or containing correct error information.
  def get()
    initStatus = initOperation()
    if(initStatus == :OK)
      answerCollName = BRL::Genboree::KB::Helpers::AnswersHelper::KB_CORE_COLLECTION_NAME
      unless(@mongoAn.coll.nil?)
        if(READ_ALLOWED_ROLES[@groupAccessStr])
          dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
          if(dataHelper)
            entity = nil
            qtCursor = @mongoQh.coll.find({ "Questionnaire.value" =>  @questId })
            if(qtCursor and qtCursor.is_a?(Mongo::Cursor) and qtCursor.count == 1)
              mgCursor = @mongoAn.coll.find({ "Answer.value" =>  @answerId })
              if(mgCursor and mgCursor.is_a?(Mongo::Cursor) and mgCursor.count == 1)
                mgCursor.rewind! # resets the cursor to its unevaluated state
                doc = BRL::Genboree::KB::KbDoc.new(mgCursor.first)
                if(doc.getPropVal('Answer.Questionnaire') == @questId)
                  entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
                  @statusName = configResponse(entity)
                else
                  @statusName = :'Not Found'
                  @statusMsg = "NO_ANSWER_DOCUMENT: There is no answer document - #{@answerId} for the questionnaire, #{@questId.inspect} for the collection - #{@collName} under #{@kbName} KB."
                end
              else 
                @statusName = :'Not Found'
                @statusMsg = "NO_ANSWER_DOCUMENT: There is no answer document - #{@answerId} for the questionnaire, #{@questId.inspect} for the collection - #{@collName} under #{@kbName} KB."
              end
            else
              @statusName = :'Not Found'
              @statusMsg = "NO_QUESTIONNAIRE_DOCUMENT: There is no questionnaire - #{@questId} for the collection - #{@collName} under #{@kbName} KB."
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_COLL: can't get answer document named #{@answerId.inspect} because appears to be no data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
          end
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation."
        end
      else
        @statusName = :'Not Found'
        @statusMsg = "NO_QUESTIONNAIRE_COLL: can not get questionnaire document named #{@answerId.inspect} because appears to be no internal collection #{answerCollName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} . #{answerCollName} is a GenboreeKB internal collection and absence of this collection means that the #{@kbName.inspect} is an outdated GenboreeKB."
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
      answerCollName = BRL::Genboree::KB::Helpers::AnswersHelper::KB_CORE_COLLECTION_NAME
      unless(@mongoAn.coll.nil?)
        if(WRITE_ALLOWED_ROLES[@groupAccessStr])
          dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
          if(dataHelper)
            qtCursor = @mongoQh.coll.find({ "Questionnaire.value" =>  @questId })
            if(qtCursor and qtCursor.is_a?(Mongo::Cursor) and qtCursor.count == 1)       
              begin
                entity = nil
                mgCursor = @mongoAn.coll.find({ "Answer.value" => @answerId })
                if(mgCursor and mgCursor.is_a?(Mongo::Cursor))
                  if(mgCursor.count == 1)
                    mgCursor.rewind!
                    doc = BRL::Genboree::KB::KbDoc.new(mgCursor.first)
                    if(doc.getPropVal('Answer.Questionnaire') == @questId)
                      entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
                      @mongoAn.coll.remove( { "Answer.value" => @answerId } )
                      @statusMsg = "DELETED: The answer document: #{@answerId} was deleted from the database."
                      @statusName = :OK
                      configResponse(entity)
                    else
                      @statusName = :'Not Found'
                      @statusMsg = "NO_ANSWER_DOCUMENT: There is no answer document, #{@answerId.inspect} for the questionnaire #{@questId}in the collection - #{@collName} under #{@kbName} KB."
                    end
                  else
                    @statusName = :'Not Found'
                    @statusMsg = "NO_ANSWER_DOCUMENT: There is no answer document, #{@answerId.inspect} for the collection - #{@collName} under #{@kbName} KB."
                  end
                else
                  @statusName = :'Internal Server Error'
                  @statusMsg = "DEL_ANSWER_FAILED: Deletion of the answer document, #{@answerId.inspect} failed. Check: #{err}"
                end
              rescue => err
                @statusName = :'Internal Server Error'
                @statusMsg = "INTERNAL_SERVER_ERROR: #{err}"
              end
            else
              @statusName = :'Not Found'
              @statusMsg = "NO_QUESTIONNAIRE_DOCUMENT: There is no questionnaire - #{@questId} for the collection - #{@collName} under #{@kbName} KB."
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
       @statusMsg = "NO_ANSWER_COLL: can not delete answer document named #{@answerId.inspect} because appears to be no internal collection #{answerCollName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} . #{answerCollName} is a GenboreeKB internal collection and absence of this collection means that the #{@kbName.inspect} is an outdated GenboreeKB."
      end
    end
    # If something wasn't right, represent as error
    @resp = representError() if(@statusName != :OK)
    return @resp
  end





end
end; end; end
