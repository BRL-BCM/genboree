#!/bin/env ruby
require 'brl/genboree/kb/helpers/abstractHelper'


module BRL ; module Genboree ; module KB ; module Helpers

  class TransformCacheHelper < AbstractHelper

    # @return [String] The name of the core GenboreeKB collection the helper assists with.
    KB_CORE_COLLECTION_NAME = "kbTransforms.cache"

    # @return [Array<Hash>] An array of MongoDB index config hashes; each has has key @:spec@ and @:opts@
    # Index each transform document in the kbTransforms collection
    # Indexed by the name of the document
    KB_CORE_INDICES =
    [
      {
        :spec => 'TransformCache.value',
        :opts => { :unique => true, :background => true }
      }
    ]
    
    # @return [Hash] Template of the model document that will be placed in @kbModel@ collection
    # when a database is first created.
    KB_MODEL = {
    "name"=> {
     "value"=> "TransformCache Model - #{KB_CORE_COLLECTION_NAME}",
     "properties"=> {
      "internal"=> {
        "value"=> true
      },
      "model"=> {
        "value"=> {
          "unique"=> true,
          "required"=> true,
          "index"=> true,
          "domain"=> "string",
          "name"=> "TransformCache",
          "properties"=> [
            {
              "required"=> true,
              "domain"=> "posInt",
              "name"=> "TransformVersion",
              "description"=> "Version of the transformation rules document"
            },
            {
              "domain"=> "posInt",
              "name"=> "SourceDocVersion",
              "description"=> "Version of the source document if the transformation is for a document"
            },
            {
              "domain"=> "timestamp",
              "name"=> "SourceCollEditTime",
              "description"=> "Last Edit time of the collection that is being transformed if the transformation scope is collection"
            },
            {
              "domain"=> "[valueless]",
              "name"=> "CollEditTimes",
              "items"=> [
                {
                  "unique"=> true,
                  "index"=> true,
                  "domain"=> "string",
                  "name"=> "Coll",
                  "properties"=> [
                    {
                      "required"=> true,
                      "domain"=> "timestamp",
                      "name"=> "EditTime",
                      "description"=> "Last Edit time of the collection"
                    }
                  ],
                  "description"=> "Name of the collection",
                  "identifier"=> true
                }
              ],
              "category"=> true,
              "description"=> "List of all the associated collections used by the transformation",
              "fixed"=> true
            },
            {
              "required"=> true,
              "domain"=> "string",
              "name"=> "Output",
              "description"=> "Transformed output (JSON or HTML according to {fomat}"
            }
          ],
          "description"=> "{coll}/docs|{transformDoc}|{format} OR {coll}/doc/{doc}|{transformDoc}|{format}",
          "identifier"=> true
        }
      }
    }
  }
} 
    # Create new instance of this helper.
    # @param [MongoKbDatabase] kbDatabase The KB database object this helper is assisting.
    # @param [String] collName The name of the document collection this helper uses.
    def initialize(kbDatabase, collName="kbTransforms.cache")
      super(kbDatabase, collName)
      unless(collName.is_a?(Mongo::Collection))
        @coll = @kbDatabase.transformCacheCollection() rescue nil
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
    def docTemplate(*params)
      retVal = {"TransformCache"=> 
                 {
                   "value" => "",
                   "properties"=> 
                 {
                   "TransformVersion"=>{"value"=>1}, 
                   "Output"=>{"value"=>""}, 
                   "SourceCollEditTime"=>{"value"=>""}
                 }, 
               }
           }
      return retVal
    end
     
  end # TransformCacheHelper
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers
