require 'brl/genboree/kb/helpers/abstractHelper'

module BRL; module Genboree; module KB; module Helpers
class QuestionsHelper < AbstractHelper
  # INTERFACE; @see AbstractHelper
  KB_CORE_COLLECTION_NAME = "kbQuestionnaires"
  KB_CORE_INDICES = [
    # index by name of Questionnaire
    {
      :spec => 'Questionnaire.value',
      :opts => { :unique => true, :background => true }
    }
  ]


   # Model for the Questionnaire Collection
   KB_MODEL = {
    "name"=> {
      "value"=> "Questionnaire Model - #{KB_CORE_COLLECTION_NAME}",
      "properties"=> {
        "internal"=> {
          "value"=> true
        },
        "model"=> {
          "value"=> {
            "domain"=> "string",
            "unique"=> true,
            "description"=> "An ID for this questionnaire document. It will live in the, kbQuestionnaire collection. The ID is the unique name for this document in that collection.",
            "required"=> true,
            "name"=> "Questionnaire",
            "identifier"=> true,
            "properties"=> [
              {
                "domain"=> "string",
                "description"=> "Name of the collection for which this questionnaire is applicable.",
                "required"=> true,
                "name"=> "Coll"
              },
              {
                "fixed"=> true,
                "items"=> [
                  {
                    "domain"=> "regexp(SEC[0-9]+)",
                    "unique"=> true,
                    "description"=> "A section corresponding to a set of questionnaires",
                    "name"=> "SectionID",
                    "identifier"=> true,
                    "properties"=> [
                      {
                        "domain"=> "string",
                        "description"=> "Text or comment that goes with this section",
                        "name"=> "Text"
                      },
                      {
                        "domain"=> "enum(addItem, editItem, modifyProp)",
                        "description"=> "Task type - edit or add item, or modify a property",
                        "name"=> "Type"
                      },
                      {
                        "domain"=> "string",
                        "description"=> "Dot separated property path that is the root of the template/doc for which the questionnaire is applicable",
                        "name"=> "Root"
                      },
                      {
                        "domain"=> "string",
                        "description"=> "Name of the template this section refers to. Optional, must be present if the questionnaire uses a template and has 'root' property given.",
                        "name"=> "Template"
                      },
                      {
                        "fixed"=> true,
                        "items"=> [
                          {
                            "domain"=> "regexp(QUE[0-9]+)",
                            "unique"=> true,
                            "description"=> "Name of the question.",
                            "name"=> "QuestionID",
                            "identifier"=> true,
                            "properties"=> [
                              {
                                "domain"=> "string",
                                "description"=> "The actual question itself. This question is directly related to the property path that is to be modified.",
                                "required"=> true,
                                "name"=> "Question",
                                "properties"=> [
                                  {
                                    "name" => "Default",
                                    "description" => "Default value for the Question. If present, this will be used as the answer.",
                                    "domain" => "string"
                                  },
                                  {
                                    "domain"=> "string",
                                    "description"=> "Property path in the document that is to be modified",
                                    "required"=> true,
                                    "name"=> "PropPath",
                                    "properties"=> [
                                      {
                                        "domain"=> "string",
                                        "description"=> "Property domain definition this questionnaire uses. Must be a subset of the original domain definition.",
                                        "required"=> true,
                                        "name"=> "Domain",
                                        "properties"=> [
                                          {
                                            "domain"=> "string",
                                            "description"=> "Additional information of the domain provided to the user.",
                                            "name"=> "Domain Info"
                                          }
                                        ]
                                      }
                                    ]
                                  }
                                ]
                              }
                            ]
                          }
                        ],
                        "domain"=> "[valueless]",
                        "name"=> "Questions",
                        "category"=> true
                      }
                    ]
                  }
                ],
                "domain"=> "[valueless]",
                "description"=> "List of sections. Each section is a set of questionnaires, say for a specific task.",
                "name"=> "Sections",
                "category"=> true
              }
            ]
          }
        }
      }
    }
  }

  def initialize(kbDatabase, collName=KB_CORE_COLLECTION_NAME)
    super(kbDatabase, collName)
    unless(collName.is_a?(Mongo::Collection))
      @coll = @kbDatabase.questionsCollection() rescue nil
    end
  end

end
end; end; end; end
