#!/bin/env ruby

require 'brl/genboree/kb/helpers/abstractHelper'
require 'brl/genboree/kb/propSelector'

module BRL ; module Genboree ; module KB ; module Helpers
  # This class assists with the document queries for the various collections.
  class QueriesHelper < AbstractHelper
    MEMOIZED_INSTANCE_METHODS = [ ] # In addition to those from parent class, which we'll rememoize, especially since we override 1+ of the parent methods!!

    # @return [String] The name of the core GenboreeKB collection the helper assists with.
    KB_CORE_COLLECTION_NAME = 'kbQueries'
    # @return [Array<Hash>] An array of MongoDB index config hashes; each has has key @:spec@ and @:opts@
    #   the indices for the query documents in the views collection.
    KB_CORE_INDICES =
    [
      # Index each query doc by its "name".
      {
        :spec => 'Query.value',
        :opts => { :unique => true, :background => true }
      }
    ]
    IMPLICIT_QUERIES_DEFS = { "Document Id" => {} , "Indexed Properties" => {} }
    # @return [Hash] A model document or model template which can be used to place an appropriate
    #    model document into the @kbModels@ collection when the database (or this helper's collection)
    #    is first created.
    KB_MODEL =
    {
      "name" => { "value" => "Query Model - #{KB_CORE_COLLECTION_NAME}", "properties" =>
      {
        "internal"  => { "value" => true },
        "model"     => { "value" =>
          {
            "name"        => "Query",
            "required"    => true,
            "domain"      => "string",
            "description" => "An ID for this query document. It will live in the kbQueries collection. The ID is the unique name for this document in that collection.",
            "unique"      => true,
            "identifier"  => true,
            "properties"  =>
            [
              {
                "name"        => "Description",
                "domain"      => "string",
                "description" => "Description about the specific query. Name of the specific query for instance."
              },
              {
                "name"        => "Query Configurations",
                "fixed"       => true,
                "category"    => true,
                "domain"      => "[valueless]",
                "description" => "Configuration for the query. Each element in this list represents either a simple or compound statements. Simple statements with comparative operators and compound statements with simple statements and logical operators.",
                "items"=> [
                            {
                              "name"        => "Query Config",
                              "domain"      => "regexp(^QC[0-9]+$)",
                              "description" => "Unique string describing the query configuration.",
                              "unique"      => true,
                              "identifier"  => true,
                              "properties"  =>
                              [
                                {
                                  "name"       =>"Left Operand",
                                  "required"   => true,
                                  "domain"     => "enum(propPath, Query Config)",
                                  "description" => "Is either a property path or a query configuration. A property path in case when the right operand is either a prperty path or literal.",
                                 "properties" =>
                                 [
                                   {
                                     "name"        => "Value",
                                     "domain"      => "string",
                                     "description" => "This field is required when the  \"Left Operand\" is a propPath"
                                   },
                                   {
                                     "name"        => "Query Config ID",
                                     "domain"      => "regexp(^QC[0-9]+$)",
                                     "description" => "This field is required when the \"Left Operand\" is a \"Query Congfig\"."
                                   }
                                 ]
                                },
                                {
                                  "name"       => "Right Operand",
                                  "required"   => true,
                                  "domain"     => "enum(propPath, literal, Query Config)",
                                  "description" => "Is either a property path, a literal or a query config",
                                  "properties" =>
                                  [
                                    {
                                      "name"        => "Value",
                                      "domain"      => "string",
                                      "description" => "This field is required when the  \"Left Operand\" is a propPath or a literal."
                                    },
                                    {
                                      "name"        => "Query Config ID",
                                      "domain"      => "regexp(^QC[0-9]+$)",
                                      "description" => "This field is required when the \"Left Operand\" is a \"Query Congfig\"."
                                    }
                                  ] 
                                },
                                {
                                  "name"        => "Operator",
                                  #"domain"      => "enum(and, or, >, <, =, <=, >=, !=, exact, keyword, full, prefix, !prefix, in, !in, between)",
                                  "domain"      => "enum(and, or, >, <, =, <=, >=, !=, exact, keyword, full, prefix, in)",
                                  "description" => "Comparative or logical operators, is conditional to the Left and Right Operand values.",
                                  "required" => true
                                }
                              ]
                            }
                          ]
              }
             ]
          }}
        }
     }}
    
    # Required for getting identifier property name
    attr_accessor :modelsHelper
    
    # Create new instance of this helper.
    # @param [MongoKbDatabase] kbDatabase The KB database object this helper is assisting.
    # @param [String] collName The name of the document collection this helper uses.
    def initialize(kbDatabase, collName=self.class::KB_CORE_COLLECTION_NAME)
      super(kbDatabase, collName)
      unless(collName.is_a?(Mongo::Collection))
        @coll = @kbDatabase.queriesCollection() rescue nil
      end
      @modelsHelper = nil
    end
    
    # Returns the @matchProps to kbDocs resource
    # Not required for the 'Document Id' query since that is in-built into the kbDocs resource
    # @param [String] queryName Name of the query
    # @param [String] coll Name of the collection we are working with
    # @return [String] retVal String of comma separated values indicating the properties to include in the query
    def getMatchProps(queryName, coll=nil)
      retVal = nil
      if(queryName == 'Indexed Properties')
        modelDoc = @modelsHelper.modelForCollection(coll)
        model = modelDoc['name']['properties']['model']['value']
        matchProps = @modelsHelper.getPropPathsForFieldAndValue(model, 'index', true)
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "matchProps:\n#{matchProps.inspect}")
        retVal = matchProps.join(",")
      else # @todo Query the monogodb to get the query contents
        raise "Not Implemented" 
      end
      return retVal
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

    # OVERRIDE because .versions & .revisions collections have no explicit model doc, can't properly look it up. But we can get a model
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

    # Get a document template suitable for the collection this helper asists with.
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
      # @todo flesh out the template document for queries
      retVal =
      {
        "name"        => { "value" => "", "properties" => {} }
      }
      return retVal
    end

    # Returns the query document with a new values for a given a list of property paths and property values.
    # Property paths and the property values must be of the same size
    # @param [Hash] queryDoc values of this query document are replaced
    # @param [Array<String>] propertyPaths list of property paths, values of these paths are to be replaced
    # @param [Array<String>] propertyValues list of property values that are to be added
    # @return [Hash] newQueryDoc the new query document with the replaced values
    # @raise [ArgumentError] if @propertyPaths@ and @propertyValues@ are not {Array} and also if their sizes are not equal
    def makeNewQueryDoc(queryDoc, propertyPaths, propertyValues)
      # get the propertyPaths and propertyValues into a hash structure
      # Check that both the arguments are of the same size. This is
      # checked already in API, but check if this method is to be used
      # independant of API
      newQueryDoc = nil
      if(propertyPaths.is_a?(Array) and propertyValues.is_a?(Array))
        if(propertyPaths.size == propertyValues.size)
          ind = 0;
          tmphash = Hash.new{|hh, kk| hh[kk] = []}
          operandTypes = {:propPath => 'propPath', :literal => 'literal', :'Query Config' => 'Query Config'}
          pathsTobeChanged = propertyPaths.inject(tmphash){|hh, kk|
            # must be a string to be inserted to a queryDoc 'literal' field
            hh[kk] << propertyValues[ind].to_s;
            ind += 1;
            hh;
          }
          newQueryDoc = Marshal.load(Marshal.dump(queryDoc))
          # $stderr.puts "PathsToBeChanged: #{pathsTobeChanged.inspect}"
          # Get the query items
          ps = BRL::Genboree::KB::PropSelector.new(newQueryDoc)
          queryItems = ps.getMultiPropItems("<>.Query Configurations") rescue nil
          # Query items are not empty, if empty will be prompted before at the validation stage. see preValidate()
          queryItems.each{|qitem|
             leftOpType = qitem['Query Config']['properties']['Left Operand']['value']
             rightOpType = qitem['Query Config']['properties']['Right Operand']['value']
             leftOpValue = qitem['Query Config']['properties']['Left Operand']['properties']['Value']['value'] rescue nil
             rightOpValue = qitem['Query Config']['properties']['Right Operand']['properties']['Value']['value'] rescue nil
             if(leftOpType == operandTypes[:propPath] and rightOpType == operandTypes[:literal])
               if(pathsTobeChanged.key?(leftOpValue) and !pathsTobeChanged[leftOpValue].empty?)
                 qitem['Query Config']['properties']['Right Operand']['properties']['Value']['value'] = pathsTobeChanged[leftOpValue].first
                 #remove the value from the hash to match the index
                 pathsTobeChanged[leftOpValue].shift
               end
             end
          }
        else
          raise ArgumentError, "Arguments propertyPaths and propValues are not of the same size: #{propertyPaths.size}  #{propertyValues.size}"
        end
      else
        raise ArgumentError, "Arguments propertyPaths and propValues are not arrays: #{propertyPaths.class},  #{propertyValues.class} respectively.."
      end
      return newQueryDoc
    end

    # Get the version of a document from version collection this helper class assists with
    # @param [String] docID document identifier (from root property; aka unique doc name)
    # @param [String] ver version of interest - HEAD|CURR|PREV.
    # @return [Fixnum] version of the document
    # @raise [ArgumentError] if @docID@ is not found in the collection
    def getDocVersion(docID, ver=:head)
      dbRef = dbRefFromRootPropVal( docID ) # various AbstractHelpers have this ; for VersionHelper and RevisionHelper is is focused on the DbRef of the DATA DOCUMENT not the version record ; fast
      # @note: MUST use a proper BSON::DBRef with VersionsHelper for versioning of UNMODELED collections
      #   (such as internal collections like kbTransforms etc)
      vh = @kbDatabase.versionsHelper(KB_CORE_COLLECTION_NAME)
      versionDoc = vh.getVersionDoc( ver, dbRef, fields=nil )
      return versionDoc
    end

    # ----------------------------------------------------------------
    # MEMOIZE now-defined methods
    # . We override some of the parent methods here, so seems like have to re-memoize.
    # . We do this by adding our memoized methods to the list from AbstractHelper
    # ----------------------------------------------------------------
    (self::MEMOIZED_INSTANCE_METHODS + BRL::Genboree::KB::Helpers::AbstractHelper::MEMOIZED_INSTANCE_METHODS).each { |meth| memoize meth }
  end # class QueriesHelper
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers
