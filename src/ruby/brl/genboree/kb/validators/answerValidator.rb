require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/propSelector'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/kb/helpers/answersHelper'
require 'brl/genboree/kb/validators/questionValidator'


module BRL ; module Genboree ; module KB ; module Validators
class AnswerValidator < DocValidator
  
  # Property paths to their values
  # Paths with addItem has the hash values in an array
  attr_accessor :answerPaths
  attr_accessor :questDoc
  attr_accessor :qv

  def initialize(kbDatabase, dataCollName)
    super(kbDatabase, dataCollName)
    ansModel = BRL::Genboree::KB::Helpers::AnswersHelper::KB_MODEL
    @answerModelObj = BRL::Genboree::KB::KbDoc.new(ansModel)
    @questDoc = {}
    @qv = nil
  end

  # Validates the answer document against the transformation model defined in the AnswerHelper class
  # @param [Hash] answerDoc A hash representing the view payload
  # @return [Boolean] retVal
  def validate(ansDoc)
    @validationErrors = []
    @anH = @kbDatabase.answersHelper
    retVal = false
    # generates an answer document after validation and content generation
    objId = @anH.save(ansDoc, @kbDatabase.conn.defaultAuthInfo[:user], :save => false) 
    if(objId.is_a?(BSON::ObjectId))
      isValid = true
    elsif(objId.is_a?(BRL::Genboree::KB::KbError))
      isValid = false
      @validationErrors  << "DOC_REJECTED: your document was rejected because validation failed. Validation complained that: #{objId.message}"
    end
    if(isValid)
      validateAnsDoc(ansDoc)    
      validateAnsVsQuest(ansDoc) if(@validationErrors.empty?) 
    end
    retVal = @validationErrors.empty? ? true : false
    return retVal
  end

  def validateAnsDoc(ansDoc)
   anDoc = BRL::Genboree::KB::KbDoc.new(ansDoc)
   sections = anDoc.getPropItems('Answer.Sections')
   if(sections and !sections.empty?)
   # Make sure that for each of the answer there is a value for PropValue or value for ItemValues
   sections.each{|section|
     secKb = BRL::Genboree::KB::KbDoc.new(section)
     answers = secKb.getPropItems('SectionID')
     if(answers and !answer.empty?)
     answers.each{|answer|
       ansKb = BRL::Genboree::KB::KbDoc.new(answer)
       path = ansKb.getPropVal
       propVal = ansKb.getPropVal('QuestionID.PropPath.PropValue') 
       itemValues = ansKb.getPropItems('QuestionID.PropPath.ItemValues')
       unless(propVal and itemValues)
         @validationErrors << "BAD_DOC : Value not found for the property path #{ansKb.getPropVal('QuestionID.PropPath')}. Either QuestionID.PropPath.PropValue or QuestionID.PropPath.itemValues must be present for the answer document to be valid."
       end
     }
     end 
   } 
   end

  end

  def validateAnsVsQuest(ansDoc)

    anDoc = BRL::Genboree::KB::KbDoc.new(ansDoc)
    answerName = anDoc.getPropVal('Answer')
    questName = anDoc.getPropVal('Answer.Questionnaire')     

    # 1. get the questionnaire document
    questHelper = @kbDatabase.questionsHelper    
    cursor = questHelper.coll.find({ "Questionnaire.value" => questName})
    if(cursor and cursor.is_a?(Mongo::Cursor) and cursor.count == 1)
      cursor.rewind!
      @questDoc = cursor.first
      questKbDoc = BRL::Genboree::KB::KbDoc.new(@questDoc)
      questPsDoc = BRL::Genboree::KB::PropSelector.new(@questDoc)
    
      @qv = BRL::Genboree::KB::Validators::QuestionValidator.new(@kbDatabase, @dataCollName)
      @isQuestionValid = @qv.validate(@questDoc) 
 
      #2. collection names in sync 
      questColl = questKbDoc.getPropVal('Questionnaire.Coll')
      if(@isQuestionValid)
        # Hash with all the property paths (validated against the questionnaire with the values (answers).
        @answerPaths = {}

        # Traverse the answer document and vaidate the sectionID, questionID and the propPaths w.r.p to the questionnaire
        # Along the way get the answers in the @answerPaths
        sections = anDoc.getPropItems('Answer.Sections') rescue nil
        if(sections and !sections.empty?)
          sectionValid = true
          sections.each{|section|
            if(sectionValid)
              secID = section['SectionID']['value']
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "SECID::: #{secID.inspect} ")
              # 3. get the task type for that sectionID from the questDoc
              tasktype = questPsDoc.getMultiPropValues("<>.Sections.[].SectionID.{\"#{secID}\"}.Type").first.strip rescue nil
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "TASK type::: #{tasktype.inspect} ")
              if(tasktype) #3
                psSec = BRL::Genboree::KB::PropSelector.new(section)
                answers = psSec.getMultiPropItems('<>.Answers') rescue nil
                if(answers and !answers.empty?)
                  answersValid = true
                  answers.each{|answer|
                    if(answersValid)
                      queID = answer['QuestionID']['value'].strip() 
                      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "queID::: #{queID.inspect} ")
                      ansPath = answer['QuestionID']['properties']['PropPath']['value'] rescue nil
                      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "ansPath::: #{ansPath.inspect} ")
                      #4. Validate that he question id to the path and the answer path to the questionnaire
                      # Note: all the paths in the questionnaire are validated against the model
                      # So check the answer paths agaisnt the questionnaire paths
                      questPath = questPsDoc.getMultiPropValues("<>.Sections.[].SectionID.{\"#{secID}\"}.Questions.[].QuestionID.{\"#{queID}\"}.Question.PropPath").first rescue nil
                      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "questPath::: #{questPath.inspect} ")
                      if(questPath and (ansPath == questPath))
                        if(tasktype == "modifyProp") # get the PropValue
                          propValue = answer['QuestionID']['properties']['PropPath']['properties']['PropValue']['value'] rescue nil
                          if(propValue)
                            @answerPaths[ansPath] = propValue.strip()
                          else
                            answersValid = false
                            @validationErrors << "PROPVALUE_ERROR: Failed to get the value for the property path #{ansPath} from the answer doc. Tasktype for this section #{secID} is modifyProp and value for the property PropValue MUST be present."
                            break
                          end
                        elsif(tasktype == "addItem")
                          items = answer['QuestionID']['properties']['PropPath']['properties']['ItemValues']['items'] rescue nil
                          if(items)
                            itemValues = items.collect() {|item| item['ItemValue']['properties']['Value']['value']  }
                            @answerPaths[ansPath] = itemValues # array for add item
                          else
                            answersValid = false
                            @validationErrors << "ITEM_VALUE_ERROR: No item values found for the task type #{tasktype.inspect} for the property path #{ansPath}"
                            break
                          end
                        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@answersPath::: #{@answersPath.inspect} ")
                        else #any other task item then is an error for the first version
                          answersValid = false
                          @validationErrors << "TASKTYPE_ERROR: TaskType #{tasktype} not implemented/supported."
                        end
                      else
                        answersValid = false
                        @validationErrors << "INVALID PATH: Path in the questionnaire document #{questPath.inspect} for the questionID #{queID.inspect} failed to match the answer path - #{ansPath}. Either QuestionID is missing in the questionnaire?  Check spelling, case, etc of the answerPath - #{ansPath}"
                        break
                      end
                    else
                      break
                    end
                  }
                else
                  sectionValid = false
                  @validationErrors << "NO_ANSWERS: No answers found for the section #{secID} in the answer document. Invalid answer document."
                  break
                end
              
              else
                sectionValid = false
                @validationErrors << "NO_SECTION: No section with sectionID #{secID} found in the questionnaire #{questName}"
                break
              end
            else
              break
            end
          }
          if(sectionValid and (@qv.questPaths.keys.size > @answerPaths.keys.size))
           @qv.questPaths.each_key{|qPath|
             unless(@answerPaths.key?(qPath))
               @validationErrors << "ANSWER_MISSING:  No answer for the path - #{qPath}. All the questions MUST be answered and leaving a question is not allowed."
             end
           }
          end
        else
          @validationErrors << "NO_SECTIONS: No sections in the answer document #{answerName} for the collection"
        end
      else
        @validationErrors << "BAD_DOC: Validation of the questionnaire - #{questName} failed. Details : #{@qv.validationErrors}"
      end
    else
      @validationErrors << "NO_QUESTIONNAIRE: No questionnaire = #{questName.inspect} found in the collection #{@dataCollName}."
    end
  end
end
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Validators
