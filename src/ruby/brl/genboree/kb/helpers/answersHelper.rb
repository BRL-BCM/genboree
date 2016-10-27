require 'brl/genboree/kb/helpers/abstractHelper'
require 'brl/genboree/kb/validators/docValidator'

module BRL; module Genboree; module KB; module Helpers
class AnswersHelper < AbstractHelper

  attr_accessor :validatorErrors
  attr_accessor :lastContNeeded
  # INTERFACE; @see AbstractHelper
  KB_CORE_COLLECTION_NAME = "kbAnswers"
  KB_CORE_INDICES = [
    # index by name of Questionnaire
    {
      :spec => 'Answer.value',
      :opts => { :unique => true, :background => true }
    }
  ]


  # Model for the kbAnswers Collection
  # Model document that gets entered into the @kbModels@ collection when the database (or this helper's collection)
  # is first created.
  KB_MODEL = {
    "name"=> {
      "value"=> "Answer Model - #{KB_CORE_COLLECTION_NAME}",
      "properties"=> {
        "model"=> {
          "value"=> {
            "domain"=> "autoID(A, uniqNum, N)",
            "required"=> true,
            "description"=> "An ID for this answer document.",
            "identifier"=> true,
            "name"=> "Answer",
            "unique"=> true,
            "properties"=> [
            {
              "domain"=> "string",
              "required"=> true,
              "description"=> "Name of the questionnaire document for which the answers are applicable. Points to the ID of a specific questionnaire documnt",
              "name"=> "Questionnaire"
            },
            {
              "domain"=> "[valueless]",
              "fixed"=> true,
              "items"=> [
                {
                  "domain"=> "regexp(SEC[0-9]+)",
                  "index"=> true,
                  "description"=> "A section corresponding to a set of answers. Points to a specific section of the questionnaire.",
                  "identifier"=> true,
                  "name"=> "SectionID",
                  "unique"=> true,
                  "properties"=> [
                    {
                      "domain"=> "[valueless]",
                      "fixed"=> true,
                      "items"=> [
                        {
                          "domain"=> "regexp(QUE[0-9]+)",
                          "index"=> true,
                          "description"=> "ID of the question from the questionnaire.",
                          "identifier"=> true,
                          "name"=> "QuestionID",
                          "unique"=> true,
                          "properties"=> [
                            {
                              "domain"=> "string",
                              "required"=> true,
                              "description"=> "Property path in the document that is to be modified",
                              "name"=> "PropPath",
                              "properties"=> [
                                {
                                  "domain"=> "string",
                                  "description"=> "Value for the property path",
                                  "name"=> "PropValue"
                                },
                                {
                                  "domain"=> "[valueless]",
				  "fixed"=> true,
                                  "items"=> [
                                    {
                                      "domain"=> "string",
                                      "index"=> true,
                                      "identifier"=> true,
                                      "name"=> "ItemValue",
                                      "unique"=> true,
                                      "properties"=> [
                                        {
                                          "domain"=> "string",
                                          "description"=> "Value of the property under an item list",
                                          "name"=> "Value"
                                        }
                                      ]
                                    }
                                  ],
                                  "description"=> "List of values when the property path is an item list",
                                  "name"=> "ItemValues",
                                  "category"=> true
                                }
                              ]
                            }
                          ]
                        }
                      ],
                      "name"=> "Answers",
                      "category"=> true
                    }
                  ]
                }
              ],
              "description"=> "List of sections. Each section is in sync with the corrsponding questionnaire, say for a specific task.",
              "name"=> "Sections",
              "category"=> true
            }]
          }
        },
          "internal"=> {
          "value"=> true
        }
      }
    }
  }
 
   


  def initialize(kbDatabase, collName=KB_CORE_COLLECTION_NAME)
    super(kbDatabase, collName)
    unless(collName.is_a?(Mongo::Collection))
      @coll = @kbDatabase.answersCollection() rescue nil
    end
    @validatorErrors = nil
    @lastContNeeded = nil
  end

  # Save a doc to the collection this helper instance uses & assists with. Will also save
  #   history records as well, unless {#coll} for this helper is one of the core collections
  #   which doesn't track history (like @kbColl.metadata@ and @kbGlobals@).
  # @note If the @doc@ contains @_id@ field, then the document is updated. Else a new one is created.
  # @see Mongo::Collection#save
  # @param [Hash] doc The document to save.
  # @param [String] author The Genboree user name who is saving the document.
  # @param [Hash] opts Options hash containing directives for special operations.
  #   [Boolean] :save whether or not the save should be committed to the database;
  #     :save => false results in validation and content generation
  # @return [BSON::ObjectId, KbError] The ObjectId for the saved document or a mocked
  #   ObjectId if :save => false
  # @note doc will be modified with the BSON::ObjectId in the key _id only if the document is saved
  def save(doc, author, opts={})
    retVal = nil
    validationErrStr = nil
    doSave = !(opts.key?(:save) and opts[:save] == false)
    # First, the doc MUST match the model for this collection
    # - do first pass validation, which will notice if we need to generate content
    # - if actually saving, this pass will cast/normalize values in the input doc
    firstValidation = valid?(doc, true, true, { :castValues => true, :allowDupItems => true }) # do casting always, even if not saving
    if(firstValidation == :CONTENT_NEEDED) # this is advisory; may turn out that content generators fine nothing to add
      # - do content generation
      generator = BRL::Genboree::KB::ContentGenerators::Generator.new(@lastContNeeded, doc, @coll.name, @kbDatabase)
      contentStatus = generator.addContentToDoc()
      if(contentStatus)
        # - do second pass validation, in which missing content is not allowed (and in which we ignore the advisory :CONTENT_NEEDED result)
        # - no cast/normalize is done in this pass ; done above and content generation by our code should not need cast/normalize at this point
        secondValidation = valid?(doc, false, true)
        if(secondValidation)
          # Are we doing the actual save? Or just a no-op save run?
          if(doSave)
            retVal = super(doc, author)
          else
            retVal = BSON::ObjectId.new()
          end
        else # not valid, even after adding content
          if(@validatorErrors.is_a?(Array))
            validationErrStr = "  - #{@validatorErrors.join("\n  - ")}"
          else
            validationErrStr = "  - [[ No detailed validation error messages available ; likely a code bug or crash in validation or content-generation code ]]"
          end
        end
      else # fatal problem adding content
        validationErrStr = "  - Problem generating needed content for this doc!\n  - #{gen.generationErrors.join("\n  - ")}"
      end
    elsif(firstValidation == true)
      # Since we allowed dup item ids in the first pass, we need to do another round of validation this time with the default settings.
      secondValidation = valid?(doc, false, true)
      if(secondValidation)
        # Are we doing the actual save? Or just a no-op save run?
        if(doSave)
          retVal = super(doc, author)
        else
          retVal = BSON::ObjectId.new()
        end
      else # not valid, even after adding content
        if(@validatorErrors.is_a?(Array))
          validationErrStr = "  - #{@validatorErrors.join("\n  - ")}"
        else
          validationErrStr = "  - [[ No detailed validation error messages available ; likely a code bug or crash in validation or content-generation code ]]"
        end
      end
    else # not valid even before adding content
      if(@validatorErrors.is_a?(Array))
        validationErrStr = "  - #{@validatorErrors.join("\n  - ")}"
      else
        validationErrStr = "  - [[ No detailed validation error messages available ; likely a code bug or crash in validation or content-generation code ]]"
      end
    end
    retVal = KbError.new("ERROR: the document does not match the data model schema for the #{@coll.name} collection! Specifically:\n#{validationErrStr}") if(validationErrStr)
    return retVal
  end

  def valid?(doc, missingContentOk=false, restoreMongo_idKey=false, opts={ :castValues => false, :allowDupItems => false })
      castValues = opts[:castValues]
      docValidator = BRL::Genboree::KB::Validators::DocValidator.new(@kbDatabase, @coll.name)
      docValidator.missingContentOk = missingContentOk
      docValidator.castValues = castValues # could also pass into validateDoc() below ; this is cleaner
      docValidator.allowDupItems = !!opts[:allowDupItems]
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@coll.name: #{@coll.name.inspect} ; @dataCollName: #{docValidator.dataCollName.inspect}")
      ansModelObj = BRL::Genboree::KB::KbDoc.new(KB_MODEL)
      valid = docValidator.validateDoc(doc, ansModelObj, restoreMongo_idKey)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@model:\n\n#{JSON.pretty_generate(docValidator.model)}\n\n")
      if(valid == true)
        retVal = true
      elsif(valid == :CONTENT_NEEDED)
        @lastContNeeded = docValidator.contentNeeded
        retVal = :CONTENT_NEEDED
      else
        @validatorErrors = docValidator.validationErrors.dup
        retVal = false
      end
      return retVal
    end
  

end
end; end; end; end
