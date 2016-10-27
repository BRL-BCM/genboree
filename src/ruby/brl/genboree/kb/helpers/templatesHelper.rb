#!/bin/env ruby
require 'brl/genboree/kb/helpers/abstractHelper'

module BRL ; module Genboree ; module KB ; module Helpers
  # This class assists with the document templates for the various collections.
  # @note Templates should be validated against the model for a collection.
  class TemplatesHelper < AbstractHelper
    # @return [String] The name of the core GenboreeKB collection the helper assists with.
    KB_CORE_COLLECTION_NAME = "kbTemplates"
    # @return [Array<Hash>] An array of MongoDB index config hashes; each has has key @:spec@ and @:opts@
    #   the indices for the template documents in the kbTemplates collection.
    KB_CORE_INDICES =
    [
      # Index each template doc by its "name".
      {
        :spec => 'id.value',
        :opts => { :unique => true, :background => true }
      }
    ]
    # @return [Hash] A model document or model template which can be used to place an appropriate
    #    model document into the @kbModels@ collection when the database (or this helper's collection)
    #    is first created.
    KB_MODEL =
    {
      "name"        => { "value" => KB_CORE_COLLECTION_NAME, "properties" =>
      {
        "description" => { "value" => "The model for collection templates." },
        "internal" => { "value" => true },
        "model" => { "value" => {
            "name"        => "id",
            "description" => "The indentifier of the template.",
            "identifier"  => true,
            "properties"  =>
            [
              {
                "name"        => "description",
                "description" => "A description of the template doc."
              },
              {
                "name"        => "root",
                "description" => "The path to the root property for this template. (Dot delimited)",
                "default"     => "" # empty string indicates the root (identifier) property of the document is the root prop of the template
              },
              {
                "name"        => "internal",
                "description" => "A flag indicating whether the template is for internal KB usage or for user data.",
                "domain"      => "boolean",
                "default"     => false
              },
              {
                "name"        => "coll",
                "description" => "The name of the collection this template belongs to.",
                "required"    => true
              },
              {
                "name"        => "label",
                "description" => "A custom label for this template"
              },
              {
                "name"        => "template",
                "description" => "The actual template document for the collection. This document should be based off of the model document of the collection.",
                "domain"      => "dataModelSchema"
              }
            ]
          }
        } 
      }}
    }
    
    attr_accessor :lastValidatorErrors

    # Create new instance of this helper.
    # @param [MongoKbDatabase] kbDatabase The KB database object this helper is assisting.
    # @param [String] collName The name of the document collection this helper uses.
    def initialize(kbDatabase, collName="kbTemplates")
      super(kbDatabase, collName)
      unless(collName.is_a?(Mongo::Collection))
        @coll = @kbDatabase.templatesCollection() rescue nil
      end
    end

    # Get the model doc template for the collection this helper assists with.
    # @todo change this from returning KB_MODEL constant
    #   in the respective sub-class, but rather have them loaded from
    #   some .yml files. Maybe cached like the SingletonJSONCache, etc.
    # @param [nil, Object] params Provide any parameters as individual arguments. Generally none are
    #   needed, except for some sub-classes that override this method and need some info.
    # @return [Hash] A suitable model template for the collection this helper assists with.
    def self.getModelTemplate(*params)
      return self::KB_MODEL
    end
    
    

    # Get a document template suitable for the collection this helper assists with.
    # @note The template should be filled in with sensible and convenient default
    #   values, but the calling code will have to fill in appropriate values to
    #   make it match the collection's model and possibily other constraints.
    # @param [String] collName The name of the data collection of interest. May
    #   be used to fill in key fields for collections that track info about other collections
    #   like @kbModels@ and @kbColl.metadata@.
    # @param [Hash, nil] params Additional parameters, if any, that can help fill out
    #   the template. For example, the model document for the collection of interest.
    # @return [Hash] the document template, partly filled in.
    def docTemplate(collName, *params)
      retVal =
      {
        "id"        => { "value" => "", "properties" =>
        {
          "description" => { "value" => "" },
          "internal"    => { "value" => false },
          "template"    => { "value" => nil },
          "coll"        => { "value" => collName },
          "root"        => { "value" => "" },
          "label"        => { "value" => "" }
        }}
      }
      return BRL::Genboree::KB::KbDoc.new(retVal)
    end
    
    
    
  end # class ViewsHelper
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers
