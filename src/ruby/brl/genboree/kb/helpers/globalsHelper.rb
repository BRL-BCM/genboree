#!/bin/env ruby

require 'brl/genboree/kb/helpers/abstractHelper'

module BRL ; module Genboree ; module KB ; module Helpers
  # This class assists with the database-wide globals document. Contains
  #   useful global counters for examples.
  class GlobalsHelper < AbstractHelper
    # @return [String] The name of the core GenboreeKB collection the helper assists with.
    KB_CORE_COLLECTION_NAME = "kbGlobals"
    # @return [Array<Hash>] An array of MongoDB index config hashes; each has has key @:spec@ and @:opts@
    #   the indices for the metadata documents in this collection.
    KB_CORE_INDICES =
    [
      # Index each global counter by its name
      {
        :spec => 'counters.items.name.value',
        :opts => { :unique => true, :background => true }
      }
    ]
    # @return [Hash] A model document or model template which can be used to place an appropriate
    #    model document into the @kbModels@ collection when the database (or this helper's collection)
    #    is first created.
    KB_MODEL =
    {
      "name"  => { "value" => KB_CORE_COLLECTION_NAME, "properties" =>
      {
        "internal" => { "value" => true },
        "model" => { "value" => "", "items" =>
        [
          {
            "name"        => "counters",
            "description" => "List of global counters. Can be incremented with the 'incGlobalCoubnter()' stored procedure.",
            "required"    => true,
            "default"     => nil,
            "unique"      => true,
            "items"  =>
            [
              {
                "name"        => "name",
                "decription"  => "The name of this counter.",
              },
              {
                "name"        => "count",
                "description" => "The value of the counter.",
                "domain"      => "posInt",
                "default"     => 0
              }
            ]
          }
        ]}
      }}
    }
    # @return [Hash, nil] Abstract placeholder for a constant ALL sub-classes MAY provide.
    #   If appropriate, provides an initial document to insert into the core collection
    #   when it is FIRST created.
    KB_INIT_DOC =
    {
      "counters" => { "value" => "", "items" =>
      [
        {
          "name"  => { "value" => "versionNum" },
          "count" => { "value" => 0 }
        },
        {
          "name"  => { "value" => "revisionNum" },
          "count" => { "value" => 0 }
        }
      ]}
    }

    # Get the model doc template for the collection this helper assists with.
    # @todo change this from returning KB_MODEL constant
    #   in the respective sub-class, but rather have them loaded from
    #   some .yml files. Maybe cached like the SingletonJSONCache, etc.
    # @param [nil, Object] params Provide any parameters as individual arguments. Generally none are
    #   needed, except for some sub-classes that override this method and need some info.
    # @return [KbDoc] A suitable model template for the collection this helper assists with.
    def self.getModelTemplate(*params)
      return BRL::Genboree::KB::KbDoc.new(self::KB_MODEL)
    end

    # Create new instance of this helper.
    # @param [MongoKbDatabase] kbDatabase The KB database object this helper is assisting.
    # @param [String] collName The name of the document collection this helper uses.
    def initialize(kbDatabase, collName="kbGlobals")
      super(kbDatabase, collName)
      unless(collName.is_a?(Mongo::Collection))
        @coll = @kbDatabase.globalsCollection() rescue nil
      end
    end

    # Get the list of global counter names.
    # @note The global counter names are presumed to be statically determined...i.e. by @KB_INIT_DOC@ and
    #   {#docTemplate} of this class. Making new ones dynamically at runtime is counterindicated and not
    #   supported (especially since it leads to mess as devs make counters and things willy-nilly without
    #   design thought). Thus, this method checks for known counter names in the @KB_INIT_DOC@ constant.
    # @return [Array] the list of global counters names.
    def counterNames()
      return KB_INIT_DOC["counters"]["items"].collect { |counter| counter["name"]["value"] }
    end

    # Get the current value of a global counter. Does not increment the counter.
    # @note This method uses the @"getGlobalCounter"@ stored procedure, defined in the
    #   the MongoDB database when it was created by the GenboreeKB framework.
    # @param [String] counterName The name of the global counter to get the value for.
    # @return [Fixnum] the value of the counter.
    def globalCounterValue(counterName)
      raise KbError, "ERROR: There is no global counter #{counterName.inspect}." unless(counterNames.include?(counterName))
      return @kbDatabase.callStoredProcedure("getGlobalCounter", true, counterName)
    end

    # Increment a global counter and return the new values.
    # @note This method uses the @"incGlobalCounter"@ stored procedure, defined in the
    #   the MongoDB database when it was created by the GenboreeKB framework.
    # @param [String] counterName The name of the global counter to increment.
    # @return [Fixnum] the new value of the counter.
    def incGlobalCounter(counterName)
      raise KbError, "ERROR: There is no global counter #{counterName.inspect}." unless(counterNames.include?(counterName))
      return @kbDatabase.callStoredProcedure("incGlobalCounter", true, counterName)
    end
    
    # Increment a global counter by the provided value and return the new count.
    # @note This method uses the @"incGlobalCounterByN"@ stored procedure, defined in the
    #   the MongoDB database when it was created by the GenboreeKB framework.
    # @param [String] counterName The name of the global counter to increment.
    # @param [Integer] nn positive number by which you want to increment by
    # @return [Fixnum] the new value of the counter.
    def incGlobalCounterByN(counterName, nn)
      raise KbError, "ERROR: There is no global counter #{counterName.inspect}." unless(counterNames.include?(counterName))
      raise KbError, "ERROR: Cannot incrment count by #{nn.inspect}. MUST be > 0." if(nn <= 0)
      return @kbDatabase.callStoredProcedure("incGlobalCounterByN", true, counterName, nn)
    end

    # Get a document template suitable for the collection this helper assists with.
    # @note The template should be filled in with sensible and convenient default
    #   values, but the calling code will have to fill in appropriate values to
    #   make it match the collection's model and possibily other constraints.
    # @param [String] collName The name of the data collection of interest. May
    #   be used to fill in key fields for collections that track info about other collections
    #   like @kbModels@ and @kbColl.metadata@.
    # @param [Hash, nil] Additional parameters, if any, that can help fill out
    #   the template. For example, the model document for the collection of interest.
    # @return [KbDocF] the document template, partly filled in.
    def docTemplate(*params)
      retVal =
      {
        "counters"  => { "value" => "", "items" =>
        [
          {
            "name"  => { "value" => "versionNum" },
            "count" => { "value" => 0 }
          },
          {
            "name"  => { "value" => "revisionNum" },
            "count" => { "value" => 0 }
          }
        ]}
      }
      return BRL::Genboree::KB::KbDoc.new(retVal)
    end
  end # class GlobalsHelper
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers
