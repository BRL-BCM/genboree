#!/bin/env ruby
require 'brl/genboree/kb/helpers/abstractHelper'

module BRL ; module Genboree ; module KB ; module Helpers

  class TransformsHelper < AbstractHelper
    MEMOIZED_INSTANCE_METHODS = [ ] # In addition to those from parent class, which we'll rememoize, especially since we override 1+ of the parent methods!!

    # @return [String] The name of the core GenboreeKB collection the helper assists with.
    KB_CORE_COLLECTION_NAME = "kbTransforms"

    # @return [Array<Hash>] An array of MongoDB index config hashes; each has has key @:spec@ and @:opts@
    # Index each transform document in the kbTransforms collection
    # Indexed by the name of the document
    KB_CORE_INDICES =
    [
      {
        :spec => 'Transformation.value',
        :opts => { :unique => true, :background => true }
      }
    ]
    
    # @return [Hash] Template of the model document that will be placed in @kbModel@ collection
    # when a database is first created.
    KB_MODEL = 
    {
      "name"=> {
        "value"=> "Transformation Model - #{KB_CORE_COLLECTION_NAME}",
        "properties"=> {
          "internal"=> { "value"=> true },
          "model"=> {
            "value"=> {
              "required"=> true,
              "name"=> "Transformation",
              "domain"=> "string",
              "description"=> "An ID for this transformation document. It will live in the, um, kbTransformations collection. The ID is the unique name for this document in that collection.",
              "unique"=> true,
              "identifier"=> true,
              "properties"=> [
              { 
                "name"=> "Description",
                "domain"=> "string",
                "description"=> "Description of what this transformation does."
              },
              {
                "required"=> true,
                "name"=> "Scope",
                "domain"=> "enum(doc, coll)",
                "description"=> "What level does this transformation operate at? Single document [eg summarize/transform a doc], whole collection of documents [e.g. summarize/transform multiple relevant/matching docs]"
              },
              {
                "required"=> true,
                "name"=> "Type",
                "domain"=> "enum(partitioning)",
                "description"=> "What kind of transformation is this? Keyword that will indicate what properties need to be looked for within Transformation.Output.Data.",
                "properties"=> [
                {
                  "required"=> true,
                  "name"=> "Subject",
                  "domain"=> "enum(prop, doc)",
                  "description"=> "What is the subject of this type of transformation? e.g. parititioning properties? partitioning documents?"
                }]
              },
              {
                "required"=> true,
                "fixed"=> true,
                "name"=> "Output",
                "category"=> true,
                "domain"=> "[valueless]",
                "description"=> "Info and rules for transforming the Scope objects into the output",
                "properties"=> [
                {
                  "fixed"=> true,
                  "name"=> "Contexts",
                  "items"=> [
                  {
                    "name"=> "Context",
                    "domain"=> "string",
                    "description"=> "Describe this bit of context. Often description of property with the context value/info can help. Short/punchy is good, as it can be nice \"label\" or something.",
                    "unique"=> true,
                    "identifier"=> true,
                    "properties"=> [
                    {
                      "name"=> "Prop",
                      "domain"=> "string",
                      "description"=> "PROPERTY PATH / PROPERTY SELECTOR. Where can the context info be found in the document.",
                      "required" => true,
                      "properties"=> [
                      {
                         "required" => false,
                         "name" => "Join",
                         "domain" => "boolean",
                         "description" => "The propery 'Prop' is a join. In case of cross collection this property is set to 'true' and represents a single or muliple document join. Absence or  'false' value for this property means that the property selector path of 'Prop' points to the source collection and requires no cross collection join. ",
                         "properties" => [
                          {
                           "required" => true,
                           "name" => "JoinConfigurations",
                           "category"=> true,
                           "fixed" => true,
                           "domain"=> "[valueless]",
                           "description"=> "Configuration for collection(s) join. First element in this itemlist represents the initial join between the source document and a target collection.  The size and order of this itemlist represents the sequential joins.",
                           "items" => [
                            {
                              "name" => "JoinConfig",
                              "domain" => "string",
                              "identifier" => true,
                              "description" => "",
                              "properties" => [
                                {
                                  "name" => "Join Type",
                                  "required" => true,
                                  "enum" => "(search, url)",
                                  "description" => "Property describing the nature of the cross collection join. 'search' (default) - records retrieved via a collection join directly from the values in the 'Match Values'. 'url' when the match value is url. Currently supports cross collection. Cross kb and cross host is deferred."
                                },
                                {
                                  "name" => "Coll Name",
                                  "required" => true,
                                  "enum" => "string",
                                  "description" => "Name of the collection for the respective join."
                                },
                                
                                {
                                  "name" => "Match Values",
                                  "required" => true,
                                  "enum" => "string",
                                  "description" => "PROPERTY PATH/ PROPERTY SELECTOR. These are the values for the respective join. Note that the first element in this item list is a join between the source collection and a target collection, hence this property path must point to the source document."
                                },
                                {
                                  "name" => "Match Prop",
                                  "required" => false,
                                  "enum" => "string",
                                  "description" => "PROPERTY PATH/ PROPERTY SELECTOR. This is the property of the target document. Is conditionaly dependent on the 'Join Type'. Is required if the 'Join Type' is 'search'."
                                },
                                {
                                  "name" => "Match Mode",
                                  "required" => false,
                                  "domain" => "enum(exact, keyword)",
                                  "default" => "exact",
                                  "description" => "Search parameter, exact or keyword search. Is conditionaly dependent on the 'Join Type'. Is required if the 'Join Type' is 'search'."
                                },
                                {
                                  "name" => "Cardinality",
                                  "required" => true,
                                  "domain" => "enum(1,N)",
                                  "description" => "Cardinality of the results. One (1) or more (N)."
                                }
                              ]
                            }
                           ]
                          }
                         ]
                      },  
                      {
                          "required"=> true,
                          "name"=> "PropField",
                          "domain"=> "enum(value, properties, items, propNames, valueObj)",
                          "description"=> "What property field should the Prop property stand for? 'values', 'items' , or 'properties'. 'propNames' gets the list of property names matching the prop selector path of 'Prop'"
                      },
                      {
                        "name"=> "Rank",
                        "domain"=> "int",
                        "required" => true,
                        "description"=> "What's the Rank / importance of this context? May want to display same-rank contexts together (same line, same list, etc) and may want emphasize low-rank contexts more than high-rank ones."
                      },
                      {  "name" => "Type",
                         "domain" => "enum(list, set)",
                         "description" => "List ouputs the context property as a list and set gives the unique elements on the retrun value.",
                         "default" => "list"
                      }]
                    }]
                  }],
                  "category"=> true,
                  "domain"=> "[valueless]",
                  "description"=> "If any, indicate what property/properties have useful context info. e.g. Useful info about the doc (pathogenic/benign? gene? varient? there are properties where this useful context info can be found...and presented along with the transformation."
                },
                {
                  "required"=> true,
                  "fixed"=> true,
                  "name"=> "Data",
                  "category"=> true,
                  "domain"=> "[valueless]",
                  "description"=> "Info for creating the actual output data.",
                  "properties"=> [
                  {
                    "required"=> true,
                    "name"=> "Structure",
                    "default"=> "nestedList",
                    "domain"=> "enum(nestedHash, nestedList)",
                    "description"=> "What is the structure of the output data for this transformation? Keyword that will indicate what to look for and how to interpret Transformation.Output.Data"
                  },
                  {
                    "fixed"=> true,
                    "name"=> "Aggregation",
                    "required" => true,
                    "domain"=> "[valueless]",
                     "description"=> "Info about how to aggregate multiple leaf/final values together, if relevant for Transformation.Type?",
                     "properties"=> [
                     {
                       "required"=> true,
                       "name"=> "Operation",
                       "domain"=> "enum(count, list, countMap, average, sum)",
                       "description"=> "How to do the aggregation of leaf/final values? Count them? List [all unique] values? Map unique values to counts?"
                       },
                       {
                          "required"=> true,
                          "name"=> "Subject",
                          "domain"=> "string",
                          "description"=> "PROPERTY SELECTOR. Indicate what are the properties is being partitioned and counted (or whatever)",
                          "properties"=> [
                          {
                            "required"=> true,
                            "name"=> "Type",
                            "domain"=> "enum(int, float, text, list, map)",
                            "description"=> "What is the structure of the output leaf values following aggregation? Keyword indicating things like=> int [like a count], float [like a calculation], text, list [of props, of values], map [of props to counts, of values to count]"
                          },
                          {
                            "name" => "Index Subject",
                            "domain" => "boolean",
                            "default" => true,
                            "description" => "Index subject values in the doc with the partitions",
                            "properties" => [
                             {
                               "name" => "Prop",
                               "domain" => "string",
                               "description" => "Index subject wrp to the values of this prop. The number of items must match the subjects size."
                             }
                            ]
                          }]
                        }]
                  },
                  {
                    "required"=> true,
                    "fixed"=> true,
                    "name"=> "Partitioning Rules",
                    "items"=> [
                    {
                      "name"=> "Partitioning Rule",
                      "domain"=> "string",
                      "description"=> "PROPERTY SELECTOR. provide a selection rule for the properties above .Aggregation.Subject which can be used to partition/categorize the various .Aggregation.Subjects; OR indicate a providerule for property VALUES of .Aggregation.Subject or one of its sub-properties that can be used to partition/categorize the various .Aggregation.Subjects.",
                      "unique"=> true,
                      "identifier"=> true,
                      "properties"=> [
                      {
                          "required" => false,
                          "name" => "Join",
                          "domain" => "boolean",
                          "description" => "The propery 'Prop' is a join. In case of cross collection this property is set to 'true' and represents a single or muliple document join. Absence or  'false' value for this property means that the property selector path of 'Prop' points to the source collection and requires no cross collection join. ",
                          "properties" => [
                          {
                            "required" => true,
                            "name" => "JoinConfigurations",
                            "category"=> true,
                            "fixed" => true,
                            "domain"=> "[valueless]",
                            "description"=> "Configuration for collection(s) join. First element in this itemlist represents the initial join between the source document and a target collection.  The size and order of this itemlist represents the sequential joins.",
                            "items" => [
                            {
                              "name" => "JoinConfig",
                              "domain" => "string",
                              "identifier" => true,
                              "description" => "",
                              "properties" => [
                                {
                                  "name" => "Join Type",
                                  "required" => true,
                                  "enum" => "(search, url, to, from)",
                                  "description" => "Property describing the nature of the cross collection join. 'search' (default) - records retrieved via a collection join directly from the values in the 'Match Values'. 'url' when the match value is url. Currently supports cross collection. Cross kb and cross host is deferred."
                                },
                                {
                                  "name" => "Coll Name",
                                  "required" => true,
                                  "enum" => "string",
                                  "description" => "Name of the collection for the respective join."
                                },
                                {
                                  "name" => "Target Coll Name",
                                  "enum" => "string",
                                  "description" => "Name of the target collection for the respective join."
                                },            
                                {
                                  "name" => "Match Values",
                                  "enum" => "string",
                                  "description" => "PROPERTY PATH/ PROPERTY SELECTOR. These are the values for the respective join. Note that the first element in this item list is a join between the source collection and a target collection, hence this property path must point to the source document."
                                },
                                {
                                  "name" => "Match Prop",
                                  "required" => false,
                                  "enum" => "string",
                                  "description" => "PROPERTY PATH/ PROPERTY SELECTOR. This is the property of the source document. Is conditionaly dependent on the 'Join Type'. Is required if the 'Join Type' is 'search'."
                                },
                                {
                                  "name" => "Match Mode",
                                  "required" => false,
                                  "domain" => "enum(exact, keyword)",
                                  "default" => "exact",
                                  "description" => "Search parameter, exact or keyword search. Is conditionaly dependent on the 'Join Type'. Is required if the 'Join Type' is 'search'."
                                },
                                {
                                  "name" => "Cardinality",
                                  "required" => true,
                                  "domain" => "enum(1,N)",
                                  "description" => "Cardinality of the results. One (1) or more (N)."
                                }
                              ]
                            }
                           ]
                          }
                         ]
                      },                          
                      {
                          "name"=> "Rank",
                          "domain"=> "int",
                          "description"=> "What's the Rank or order for this partitioning? Done in order of increasing Rank."
                      },
                      {
                        "required"=> true,
                        "name"=> "PropField",
                        "domain"=> "enum(value, properties, items, propNames, valueObj)",
                        "description"=> "What property field should the Prop property stand for? 'values', 'items' , or 'properties'. 'propNames' gets the list of property names matching the prop selector path of 'Prop'"
                      }]
                    }],
                    "domain"=> "[valueless]",
                    "description"=> "Because this is a \"partitioning\" Transformation.Type, it needs to have the Transformation.Output.Data.Partitioning Rules sub-document, describing the various partitioning to do. (This may not be present for other Types of transformations...they would have their own relevant sub-document at some other sibling property)"
                  },
                  {
                    "fixed"=> true,
                    "name"=> "Special Value Rules",
                    "items"=> [
                    {
                      "name"=> "Special Value Rule",
                      "domain"=> "string",
                      "description"=> "ID for the rule.",
                      "identifier"=> true,
                      "properties"=> [
                      {
                          "name"=> "Type",
                          "domain"=> "enum(partitioning, value)",
                          "description"=> "What kind of special rule is it? For example, a partition combination or a specific leaf value in the output (like 0 or something).",
                          "properties"=> [
                          {
                            "name"=> "Partition Rule",
                            "domain"=> "string",
                            "description"=> "For partitioning based rules, provide the MATERIALIZED PATH for the nested partitions that will locate a special [leaf] value in the *transformed document's data* (not in the input doc!) . E.g. {partKey1}.{partKey2}.{partK3}. http=>//docs.mongodb.org/manual/tutorial/model-tree-structures-with-materialized-paths/"
                          },
                          {
                            "name" => "Partition Value",
                            "domain" => "string",
                            "descrpition" => "If Type is \"value\" then this property should be present and must have a value to be matched.",
                            "properties" => [
                            {
                              "name" => "Condition",
                              "domain" => "regexp(^[<,>,=]=)",
                              "required" => true,
                              "description" => "This condition is applied to match the \"Partition Value\" to the transformed output."
                            }]
                          }]
                      },
                      {
                        "name"=> "Special",
                        "domain"=> "enum(invalid, important)",
                        "description"=> "Why is it special? Choose most appropriate from controlled vocabulary."
                      }]
                    }],
                    "domain"=> "[valueless]",
                    "description"=> "A list of rules for identifying special values in the output.Such as partition combinations that are key/important or partition combination that are invalid [but might be present if schema cannot prevent them]"
                  }]
                },
                {
                  "fixed"=> true,
                  "name"=> "Special Data",
                  "category"=> true,
                  "domain"=> "[valueless]",
                  "description"=> "Special data types for the main output. Definitions for metadata, special columns/rows, cell value type, etc.",
                  "properties"=> [
                  {
                    "fixed"=> true,
                    "name"=> "Required Partitions",
                    "items"=> [
                    {
                      "name"=> "Partition",
                      "domain"=> "string",
                      "description"=> "Partition name?",
                      "identifier"=> true,
                      "properties"=> [
                      {
                        "name"=> "Partition Names",
                        "domain"=> "string",
                        "description"=> "Coma separated exact partition names in the order desired to appear in the transformed output.",
                        "required" => true
                      },
                      {
                        "name" => "Rank",
                        "domain" => "int",
                        "required" => true,
                        "description" => "Rank of the partition. Ranks that are not included in the paritioning rules will not appear in the transformed output. Otherwise this rank should match the ranks given in the paritioning rules."
                      }]
                    }],
                    "category"=> true,
                    "domain"=> "[valueless]",
                    "description" => "Itemlist of set of partition names that will allow the exact order and the required names to appear on the transformed output."
                  },
                  
                 {
                    "name"=> "Metadata Subject",
                    "domain"=> "boolean",
                    "required" => false,
                    "description" => "List of subjects aggregated will be added as metadata to the cell."
                 },
                 {
                    "fixed"=> true,
                    "name"=> "Metadata Match Subject",
                    "items"=> [
                    {
                      "name"=> "Context",
                      "domain"=> "string",
                      "description"=> "Describe this bit of context. Often description of property with the context value/info can help. Short/punchy is good, as it can be nice label or something.",
                      "identifier"=> true,
                      "properties"=> [
                      {
                        "name"=> "Prop",
                        "domain"=> "string",
                        "description"=> "Property path selector whose values are to be added as metadata to the corresponding cell.",
                        "required" => true,
                        "properties" => [
                        {
                          "required"=> true,
                          "name"=> "PropField",
                          "domain"=> "enum(value, properties, items, propNames, valueObj)",
                          "description"=> "What property field should the Prop property stand for? 'values', 'items' , or 'properties'. 'propNames' gets the list of property names matching the prop selector path of 'Prop'"
                       }]
                      }]
                    }],
                    "category"=> true,
                    "domain"=> "[valueless]",
                    "description" => "Itemlist of set of partition names that will allow the exact order and the required names to appear on the transformed output."
                  },
                  {
                    "fixed"=> true,
                    "name"=> "Cell Value Conversion",
                    "domain"=> "enum(col, row)",
                    "default" => "col",
                    "description"=> "Change the value in each cell of the main output",
                    "properties"=> [
                    {
                      "required"=> true,
                      "name"=> "Operation",
                      "domain"=> "enum(percentage)",
                      "description"=> "Get the percentage of each cell value."
                    },
                    {
                      "name"=> "Type",
                      "default"=> "float",
                      "domain"=> "enum(float, int)"
                    }]
                  },
                  {
                    "fixed"=> true,
                    "name"=> "Metadata",
                    "domain"=> "[valueless]",
                    "description"=> "Metadata that goes with each partition",
                    "items"=> [
                    {
                      "name"=> "Context",
                      "domain"=> "string",
                      "description"=> "Describe this bit of context. Often description of property with the context value/info can help. Short/punchy is good, as it can be nice \"label\" or something.",
                      "unique"=> true,
                      "identifier"=> true,
                      "properties"=> [
                      {
                        "required"=> true,
                        "name"=> "Prop",
                        "domain"=> "string",
                        "description"=> "PROPERTY PATH / PROPERTY SELECTOR. Where can the context info be found in the document.",
                        "properties"=> [
                        {
                          "required" => false,
                          "name" => "Join",
                          "domain" => "boolean",
                          "description" => "The propery 'Prop' is a join. In case of cross collection this property is set to 'true' and represents a single or muliple document join. Absence or  'false' value for this property means that the property selector path of 'Prop' points to the source collection and requires no cross collection join. ",
                          "properties" => [
                          {
                            "required" => true,
                            "name" => "JoinConfigurations",
                            "category"=> true,
                            "fixed" => true,
                            "domain"=> "[valueless]",
                            "description"=> "Configuration for collection(s) join. First element in this itemlist represents the initial join between the source document and a target collection.  The size and order of this itemlist represents the sequential joins.",
                            "items" => [
                            {
                              "name" => "JoinConfig",
                              "domain" => "string",
                              "identifier" => true,
                              "description" => "",
                              "properties" => [
                                {
                                  "name" => "Join Type",
                                  "required" => true,
                                  "enum" => "(search, url)",
                                  "description" => "Property describing the nature of the cross collection join. 'search' (default) - records retrieved via a collection join directly from the values in the 'Match Values'. 'url' when the match value is url. Currently supports cross collection. Cross kb and cross host is deferred."
                                },
                                {
                                  "name" => "Coll Name",
                                  "required" => true,
                                  "enum" => "string",
                                  "description" => "Name of the collection for the respective join."
                                },
                                
                                {
                                  "name" => "Match Values",
                                  "required" => true,
                                  "enum" => "string",
                                  "description" => "PROPERTY PATH/ PROPERTY SELECTOR. These are the values for the respective join. Note that the first element in this item list is a join between the source collection and a target collection, hence this property path must point to the source document."
                                },
                                {
                                  "name" => "Match Prop",
                                  "required" => false,
                                  "enum" => "string",
                                  "description" => "PROPERTY PATH/ PROPERTY SELECTOR. This is the property of the target document. Is conditionaly dependent on the 'Join Type'. Is required if the 'Join Type' is 'search'."
                                },
                                {
                                  "name" => "Match Mode",
                                  "required" => false,
                                  "domain" => "enum(exact, keyword)",
                                  "default" => "exact",
                                  "description" => "Search parameter, exact or keyword search. Is conditionaly dependent on the 'Join Type'. Is required if the 'Join Type' is 'search'."
                                },
                                {
                                  "name" => "Cardinality",
                                  "required" => true,
                                  "domain" => "enum(1,N)",
                                  "description" => "Cardinality of the results. One (1) or more (N)."
                                }
                              ]
                            }
                           ]
                          }
                         ]
                      },
                        {
                          "required"=> true,
                          "name"=> "PropField",
                          "domain"=> "enum(value, properties, items, propNames, valueObj)",
                          "description"=> "What property field should the Prop property stand for? 'values', 'items' , or 'properties'. 'propNames' gets the list of property names matching the prop selector path of 'Prop'"
                        }]
                      },
                      {
                        "name"=> "Type",
                        "domain"=> "enum(list, text)",
                        "default" => "list"
                      },
                      {
                        "required"=> true,
                        "name"=> "Partition Rule",
                        "domain"=> "enum(kbDoc, transformedDoc)",
                        "description"=> "Where does the metadata value belongs to in the transformed document? It can either be an exact dot separated path to the transformed document (transformedDoc) or a property selector path representing one of the partitions (kbDoc). In case of the latter the corresponding 'Rank' property should be present with the exact rank as given in the partition rules.",
                        "properties" => [
                          {
                            "name" => "Rule",
                            "domain" => "string",
                            "required" => true,
                            "description" => "Either a property selector path representing partitions of the transformed document, or exact path to the transformed document.",
                            "properties" => [
                            {
                              "name"=> "PropField",
                              "required" => true,
                              "domain"=> "enum(value, properties, items, propNames, valueObj)",
                              "default" => "value",
                              "description"=> "What property field should the Prop property stand for? 'values', 'items' , or 'properties'. 'propNames' gets the list of property names matching the prop selector path of 'Prop'"
                            },
                            {
                            "name" => "Rank",
                            "domain" => "int",
                            "description" => "Must be present if the value of 'Partition Rule' is 'kbDoc'. The rank corresponds to the rank of the partiton as given in the 'Partioning Rules'"
                            }]
                          },
                          {
                            "name" => "Match Index",
                            "domain" => "boolean",
                            "required" => true,
                            "description" => "Match the values of the metadata to the values of the partition rule, index-based. When this is set to false, all the elements obtained from the metadata will be treated as a single element and matched to each element of the Partition Rule"
                          }
                        ]
                      }]
                    }] 
                  },
                 {
                   "name"=> "Rows",
                   "domain"=> "[valueless]",
                   "category" => true,
                   "fixed" => true,
                   "items"=> [
                  {
                    "required"=> true,
                    "name"=> "Label",
                    "domain"=> "string",
                    "description"=> "Title for the special row.",
                    "unique"=> true,
                    "identifier"=> true,
                    "properties"=> [
                    {
                      "required"=> true,
                      "name"=> "Operation",
                      "domain"=> "enum(sum, average, max, min, count)",
                      "description"=> "What is the operation? -  sum, average, max or minof the corresponding row values.",
                      "properties" => [
                        {
                          "name" => "Type",
                          "domain" => "enum(int, float, string)",
                          "required" => true,
                          "description" => "Type for the operation return values."
                        }
                      ]
                    },
                    { "name" => "Position",
                      "default" => "first",
                      "domain" => "enum(first,last)",
                      "description" => "Positioning of the special row/colums. First or last."
                    }]
                  }]
                  },
                  {
                    "name"=> "Columns",
                    "domain"=> "[valueless]",
                    "category" => true,
                    "fixed" => true,
                    "items"=> [
                    {
                      "required"=> true,
                      "name"=> "Label",
                      "domain"=> "string",
                      "description"=> "Title for the special row.",
                      "unique"=> true,
                      "identifier"=> true,
                      "properties"=> [
                      {
                        "required"=> true,
                        "name"=> "Operation",
                        "domain"=> "enum(sum, average, max, min, count)",
                        "description"=> "What is the operation? -  sum, average, max or minof the corresponding row values.",
                        "properties" => [
                          {
                            "name" => "Type",
                            "domain" => "enum(int, float, string)",
                            "required" => true,
                            "description" => "Type for the operation return values."
                          }
                        ]
                      },
                      { "name" => "Position",
                        "default" => "first",
                        "domain" => "enum(first,last)",
                        "description" => "Positioning of the special row/colums. First or last."
                      }]
                    }]
                  }]
                }]
             }]
            }
          }
        }
      }
    }
      
    # Create new instance of this helper.
    # @param [MongoKbDatabase] kbDatabase The KB database object this helper is assisting.
    # @param [String] collName The name of the document collection this helper uses.
    def initialize(kbDatabase, collName=self.class::KB_CORE_COLLECTION_NAME)
      super(kbDatabase, collName)
      unless(collName.is_a?(Mongo::Collection))
        @coll = @kbDatabase.transformsCollection() rescue nil
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@coll: #{@coll.inspect}")
    end
   
    # Get the model doc template for the collection this helper assists with.
    # @todo change this from returning KB_MODEL constant
    #   in the respective sub-class, but rather have them loaded from
    #   some .yml files. Maybe cached like the SingletonJSONCache, etc.
    # @param [nil, Object] params Provide any parameters as individual arguments. Generally none are
    #   needed, except for some sub-classes that override this method and need some info.
    # @return [Hash] A suitable model template for the collection this helper assists with.
    def self.getModelTemplate(*params)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "modelTemplate: #{self::KB_MODEL}")
      return self::KB_MODEL
    end

    # OVERRIDE because .versions & .revisions collections have no explicit model doc. But we can get a model
    #   from this class via self.class.getModelTemplate.
    def getIdentifierName( collName=@coll.name )
      modelsHelper = getModelsHelper()
      if( collName == @coll.name )
        if( !@idPropName.is_a?(String) or @idPropName.empty? )
          # Ask modelsHelper for the name of the identifier (root) property for this object's collection
          #   (kept in @idPropName but won't be valid for other collections we might need the name from [for example
          #   the root prop of the DATA collection which working in a version/revision helper class]).
          @idPropName = modelsHelper.getRootProp( self.class.getModelTemplate(nil) )
        end
        idPropName = @idPropName
      else # some other collection than ours ; must be a real collection that has actual model doc, not .versions or .revisions
        idPropName = super( collName )
      end
      return idPropName
    end
    alias_method( :getRootProp, :getIdentifierName )

    # Get the version of a document from version collection this helper class assists with
    # @param [String] docID document identifier (from root property; aka unique doc name)
    # @param [String] ver version of interest - PREV|CURR|HEAD 
    # @param [Hash] opts with name-value pair where name is the metadata prop of the version doc
    #   of interest.
    # @return [Fixnum] version of the document
    # @raise [ArgumentError] if @docID@ is not found in the collection
    def getDocVersion(docID, ver=:head)
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "KB_CORE_COLLECTION_NAME: #{KB_CORE_COLLECTION_NAME.inspect} ; docID arg: #{docID.inspect} ; ver arg: #{ver.inspect}")
      dbRef = dbRefFromRootPropVal( docID ) # various AbstractHelpers have this ; for VersionHelper and RevisionHelper is is focused on the DbRef of the DATA DOCUMENT not the version record ; fast
      # @note: MUST use a proper BSON::DBRef with VersionsHelper for versioning of UNMODELED collections
      #   (such as internal collections like kbTransforms etc)
      vh = @kbDatabase.versionsHelper(KB_CORE_COLLECTION_NAME)
      versionDoc = vh.getVersionDoc( ver, dbRef, fields=nil )
      return versionDoc
    end

    # Get a document template suitable for the collection this helper assists with.
    # @abstract Sub-classes MUST override this.
    # @note The template should be filled in with sensible and convenient default
    #   values, but the calling code will have to fill in appropriate values to
    #   make it match the collection's model and possibily other constraints.
    # @param [String] collName The name of the data collection of interest. May
    #   be used to fill in key fields for collections that track info about other collections
    #   like @kbModels@ and @kbColl.metadata@.
    # @param [Hash, nil] params Additional parameters, if any, that can help fill out
    #   the template. For example, the model document for the collection of interest.
    # @return [KbDoc] the document template, partly filled in.
    # @raise [NotImplementedError] if the sub-class has not implemented this method as it was supposed to.
    def docTemplate(collName, *params)
      retVal =
      {
        "Transformation"=> {
          "value"=> "",
          "properties"=> {
            "Output"=> {
              "value"=> "",
              "properties"=> {
                "Data"=> {
                  "value"=> "",
                  "properties"=> {
                    "Special Value Rules"=> {
                      "items"=> [
                        {
                          "Special Value Rule"=> {
                            "value"=> "",
                            "properties"=> {
                              "Type"=> {
                                "value"=> "",
                                "properties"=> {
                                  "Partition Rule"=> {
                                    "value"=> ""
                                  }
                                }
                              }
                            }
                          }
                        }
                      ],
                      "value"=> ""
                    },
                    "Aggregation"=> {
                      "value"=> "",
                      "properties"=> {
                        "Operation"=> {
                          "value"=> ""
                        },
                        "Subject"=> {
                          "value"=> "",
                          "properties"=> {
                            "Type"=> {
                              "value"=> ""
                            }
                          }
                        }
                      }
                    },
                    "Partitioning Rules"=> {
                      "items"=> [
                        {
                          "Partitioning Rule"=> {
                            "value"=> "",
                            "properties"=> {
                              "Rank"=> {
                                "value"=> nil
                              }
                            }
                          }
                        }
                      ],
                      "value"=> ""
                    },
                    "Structure"=> {
                      "value"=> ""
                    }
                  }
                },
                "Contexts"=> {
                  "items"=> [
                    {
                      "Context"=> {
                        "value"=> "",
                        "properties"=> {
                          "Prop"=> {
                            "value"=> "",
                            "properties"=> {
                              "Rank"=> {
                                "value"=> nil
                              }
                            }
                          }
                        }
                      }
                    }
                  ],
                  "value"=> ""
                }
              }
            },      
            "Scope"=> {
              "value"=> ""
            },
            "Type"=> {
              "value"=> "",
              "properties"=> {
                "Subject"=> {
                  "value"=> ""
                }
              }
            }
          } 
        }
      }
      return retVal
    end

    # ----------------------------------------------------------------
    # MEMOIZE now-defined methods
    # . We override some of the parent methods here, so seems like have to re-memoize.
    # . We do this by adding our memoized methods to the list from AbstractHelper
    # ----------------------------------------------------------------
    (self::MEMOIZED_INSTANCE_METHODS + BRL::Genboree::KB::Helpers::AbstractHelper::MEMOIZED_INSTANCE_METHODS).each { |meth| memoize meth }
  end # TransformsHelper
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers
