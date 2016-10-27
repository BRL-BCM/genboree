require 'brl/genboree/kb/questions/docBuildHelper'
require 'brl/genboree/kb/validators/answerValidator'
require 'brl/genboree/kb/validators/questionValidator'

module BRL ; module Genboree ; module KB ; module Questions


  # This class uses a pair of questionnaire and answer document to 
  # make a genboree KB document
  # The new document is saved to the underlying collection (the one owned by the questionnaire)
  class QuestAndAnswersToDoc 
        
    attr_accessor :questAndAnsErrors
    attr_accessor :isAnswerValid
    attr_accessor :isQuestionValid

    # all the property paths in the questDoc
    def initialize(mongoKbDb, dataCollName, ansDoc)
      @ansDoc = ansDoc
      @mgKb = mongoKbDb
      @collectionName = dataCollName
      @questAndAnsErrors = []
      @isAnswerValid = false
      @isQuestionValid = false
    end 

    def getDocFromAnswers()
      anValidator = BRL::Genboree::KB::Validators::AnswerValidator.new(@mgKb, @collectionName)
      # 1. Check if the answer document id valid
      @isAnswerValid = anValidator.validate(@ansDoc)
      if(@isAnswerValid)
        # 2. Check if the quest document id valid. Not quite necessary but can fetch some useful information
        docBuilt = nil
        qsValidator = BRL::Genboree::KB::Validators::QuestionValidator.new(@mgKb, @collectionName)
        questDoc = anValidator.questDoc
        @isQuestionValid = qsValidator.validate(questDoc)

        if(@isQuestionValid)
          # 3. Get the paths and values for the docBuilder in place
          # keys are full paths - root+propPath
          qsPaths = qsValidator.questPaths
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "qsPaths::: #{qsPaths.inspect} ")

          # keys are answer paths. Values are answers for each property
          answerPaths = anValidator.answerPaths
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "answerPaths::: #{answerPaths.inspect} ")
          # get the path elements from the fullPath. Used for sorting
          answerPathElems = {}
          answerPaths.each_key {|path|
            #answerPathElems[path] = qsPaths[path].split(".")
            answerPathElems[path] = qsPaths[path].gsub(/\\./, "\v").split(".").collect() {|yy| yy.gsub(/\v/, '.').strip}
          }
        
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "answePathElms::: #{answerPathElems.inspect} ")
          # sort the paths in the increasing order of the size of the elements 
          elmsSorted = answerPathElems.sort{ |a1,a2| a2[1].size <=> a1[1].size }.reverse
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "sorted::: #{elmsSorted.inspect} ")
          # Make the paths and values for building doc

          pathsAndValues = []
          elmsSorted.each {|elm|
            pathsAndValues << {:path => elm.last, :value => answerPaths[elm.first]}
          }
          # The following section is purely for template-based document generation 
          # Will be handled separately in the next version of this code
          # get the main template(the one which has the root to the document identifier)
          # question Validator has already that information
          mainTemplate  = qsValidator.mainTemplate
          # get the template doc
        
          templatesHelper = @mgKb.templatesHelper()
          dataHelper = @mgKb.dataCollectionHelper(@collectionName) rescue nil
          identifier = dataHelper.getIdentifierName()
          cursor = templatesHelper.coll.find( { "id.value" => mainTemplate[:template] }  )
          # Should be just one, if matched
          if(cursor and cursor.is_a?(Mongo::Cursor) and cursor.count == 1)
            cursor.rewind!
            templateDoc = BRL::Genboree::KB::KbDoc.new(cursor.first)
            docBuildTm = {}
            docBuildTm[identifier] = templateDoc.getPropVal('id.template')
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "docBuildTm ::: #{docBuildTm.inspect} ")
            db = BRL::Genboree::KB::Questions::DocBuildHelper.new(@mgKb, @collectionName, docBuildTm)
            # Build the document 
            pathsAndValues.each{ |pathAndVal|
              doc = db.add(pathAndVal)
              unless(doc)
                @questAndAnsErrors << "DOC_BUILD_ERROR: #{db.buildErrors}"
              end
            }
            if(@questAndAnsErrors.empty?)   
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOCBUILT::: #{db.root.inspect} ")
              #save and validate the doc
              # Follows the kbDoc rest/resource 
              docBuilt = db.root  
              docKb = BRL::Genboree::KB::KbDoc.new(docBuilt)
              docName = docKb.getPropVal("#{mainTemplate[:root]}")
              existingDoc = dataHelper.getByIdentifier(docName, { :doOutCast => true, :castToStrOK => true })
              if(existingDoc)
                docBuilt['_id'] = existingDoc['_id']
                objId = dataHelper.save(docBuilt, @mgKb.conn.defaultAuthInfo[:user], :save => true)
              else
                objId = dataHelper.save(docBuilt, @mgKb.conn.defaultAuthInfo[:user], :save => true)
              end
              if(objId.is_a?(BSON::ObjectId))
                docBuilt.delete("_id")
              elsif(objId.is_a?(BRL::Genboree::KB::KbError))
                @questAndAnsErrors  << "DOC_REJECTED: your document was rejected because validation failed. Validation complained that: #{objId.message}"
              else
                @questAndAnsErrors << "SAVE_FAILED: Tried to save your document, but the save unexpectedly failed (returned #{objId.inspect} rather than what was expected). Possible configuration problem or bug."
              end
            end 
          else
            @questAndAnsErrors << "NO_TEMPLATE: Failed to find the template #{mainTemplate[:template]}"
          end 
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "path And Values ::: #{pathsAndValues.inspect} ")
        else
          @questAndAnsErrors << "BAD_QUEST_DOC: validation of the questionnaire failed #{qsValidator.validationErrors}"
          # handle error
        end
     else
       @questAndAnsErrors << "BAD_ANS_DOC: validation of the answer document failed #{anValidator.validationErrors}"
     end
     docBuilt = @questAndAnsErrors.empty? ? docBuilt : nil
     return docBuilt
    end


  end
end; end; end; end
