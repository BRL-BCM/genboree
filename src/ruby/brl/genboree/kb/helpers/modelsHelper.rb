#!/bin/env ruby
require 'memoist'
require 'brl/genboree/kb/helpers/abstractHelper'

module BRL ; module Genboree ; module KB ; module Helpers
  # This class assists with the document models for the various collections.
  # @note Every collection in the GenboreeKB MongoDB database must have a model
  #   document in the @kbModels@ collection. That model describes the kinds of documents
  #   that are allowed in the collection.
  class ModelsHelper < AbstractHelper
    extend Memoist

    MEMOIZED_INSTANCE_METHODS = [
      :idPropNameForCollection,
      :getRootProp,               # alias for idPropNameForCollection (nicer name)
      :getModelMemoized          # we need to support forceRefresh, so we don't memoize getModel() itself
    ]

    # @return [String] the name of the core GenboreeKB collection the helper assists with.
    KB_CORE_COLLECTION_NAME = 'kbModels'
    # @return [Array<Hash>] An array of MongoDB index config hashes; each has has key @:spec@ and @:opts@
    #   the indices for the model documents in the models collection.
    KB_CORE_INDICES =
    [
      # Index each model doc by its "name", which will match the name of a data collection.
      {
        :spec => 'name.value',
        :opts => { :unique => true, :background => true }
      }
    ]
    # @return [Hash] A model document or model template which can be used to place an appropriate
    #    model document into the @kbModels@ collection when the database (or this helper's collection)
    #    is first created. This model is recursive, as you can see from the mix of actual document values
    #    (see ~header fields) plus property definitions within "model".
    KB_MODEL =
    {
      "name"        => { "value" => KB_CORE_COLLECTION_NAME, "properties" =>
      {
        "description" => { "value" => "The model for collection models." },
        "internal" => { "value" => true },
        "model" => { "value" => "", "items" =>
        [
          {
            "name"        => "name",
            "description" => "The name of the data model. In most cases, must match the name of a MongoDB collection.",
            "identifier"  => true,
            "properties"  =>
            [
              {
                "name"        => "description",
                "description" => "A description of the data model; what it models, who it's for, etc."
              },
              {
                "name"        => "internal",
                "description" => "A flag indicating whether the model is for internal KB usage or for user data.",
                "domain"      => "boolean",
                "default"     => false
              },
              {
                "name"        => "model",
                "description" => "The actual data model schema.",
                "domain"      => "dataModelSchema",
                "default"     => nil
              }
            ]
          }
        ]}
      }}
    }

    attr_accessor :lastValidatorErrors

    # Create new instance of this helper.
    # @param [MongoKbDatabase] kbDatabase The KB database object this helper is assisting.
    # @param [String] collName The name of the document collection this helper uses.
    def initialize(kbDatabase, collName="kbModels")
      super(kbDatabase, collName)
      unless(collName.is_a?(Mongo::Collection))
        @coll = @kbDatabase.modelsCollection() rescue nil
      end
      @lastValidatorErrors = nil
    end

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

    # Get the model document for a collection of interest.
    # @param [String] collName The name of a collection of interest.
    # @param [Boolean] forceRefresh If @true@, then rather than getting the document about the collection of
    #   interest from cache (it was cached when previously asked for), get it fresh from the database.
    # @return [KbDoc] the model document for the collection of interest.
    def modelForCollection(collName, forceRefresh=true)
      return self.docForCollection(collName, 'name.value', forceRefresh)
    end

    # Get the root identifier property for a collection; if collName is provided, query database,
    #   if opts[:modelDoc] is provided, retrieve root identifier property name from modelDoc
    # @param [String, KbDoc, Hash] collNameOrModel The collection name, wrapped-model KbDoc, or
    #   even raw model. Will get you the actual model for this arg in the most efficient way.
    # @param [Hash] opts named parameters:
    #   :modelDoc [BRL::Genboree::KB::KbDoc] a "modelDoc" (not just "model"), @see modelDocFromModel
    # @return [String] the root identifier property
    # @todo make collName optional (it is not used if opts[:modelDoc] is provided)
    def idPropNameForCollection(collNameOrModel, opts={})
      retVal = nil
      # Get the model first
      model = getModel(collNameOrModel, opts)
      if(model)
        retVal = model['name']
      else
        raise KbError, "ERROR: there is no model for collection #{collNameOrModel.inspect}. Check that the collection is spelled correctly and was created via the GenboreeKB infrastructure."
      end
      return retVal
    end
    alias_method( :getRootProp, :idPropNameForCollection )

    # Insert a model doc for a collection. Generally
    #   done only once when the collection is created using this framework.
    # @param [Hash, KbDoc] modelDoc The document to insert. Insert creates new documents and
    #   will fail if the doc contains an @_id@ field that already exists in the collection
    # @param [String] author The Genboree user name who is saving the document.
    # @param [Boolean] cacheMetadataDoc Flag indicating whether to cache the metadata
    #   doc for later fast retrieval. Because rarely/never changes, no reason why not.
    # @return [BSON::ObjectId] The ObjectId for the saved metadata document.
    def insertForCollection(modelDoc, author, cacheModelDoc=true)
      docCollName = modelDoc["name"]
      docObjId = @coll.insert( modelDoc.to_serializable() )
      # Cache the new doc for subsequent get requests.
      insertedDoc = @kbDatabase.docByRef(docObjId, @coll.name)
      @docForCollectionCache[docCollName]["name"] = insertedDoc if(cacheModelDoc)
      # Note that the "author" for core collection models is the system/GenboreeKB user rather an actual user
      versionsHelper  = @kbDatabase.versionsHelper(@coll.name)
      revisionsHelper = @kbDatabase.revisionsHelper(@coll.name)
      authInfo = @kbDatabase.conn.auths[@kbDatabase.db.name]
      versionObjId  = versionsHelper.createNewHistory(@coll.name, insertedDoc, author)
      revisionObjId = revisionsHelper.createNewHistory(@coll.name, docObjId, "/", insertedDoc, author)
      return docObjId
    end

    # Save a model doc to the collection this helper instance uses & assists with. Will also save
    #   history records as well, unless {#coll} for this helper is one of the core collections
    #   which doesn't track history (like @kbColl.metadata@ and @kbGlobals@).
    # @note If the @doc@ contains @_id@ field, then the document is updated. Else a new one is created.
    # @see Mongo::Collection#save
    # @param [Hash] doc The document to save.
    # @param [String] author The Genboree user name who is saving the document.
    # @return [BSON::ObjectId, KbError] The ObjectId for the saved document.
    def save(doc, author)
      retVal = nil
      # First, the doc MUST match the model for this collection
      if(valid?(doc))
        retVal = super(doc, author)
      else # not valid
       if(@lastValidatorErrors.is_a?(Array)) # old approach -- array of errors, generally only 1 error in it!
          validationErrStr = @lastValidatorErrors.join("\n")
       else
         validationErrStr = "  - [[ No detailed error messages available ; likely a code bug or crash ]]"
       end
       retVal = KbError.new("ERROR: the model document is not a valid model schema and thus cannot be used! Specifically:\n\n#{validationErrStr}")
      end
      return retVal
    end

    # Delete the model document for a collection.
    # @param [String] docCollName The name of the collection of interest.
    # @param [String] author The Genboree user name who is deleting the model
    # @param [Hash<Symbol,Object>] opts Optional. Hash with additional parameters.
    # @return [Boolean] Indicating success or not.
    def deleteForCollection(docCollName, author, opts={})
      #$stderr.debugPuts(__FILE__, __method__, 'STATUS', "About to delete doc for collection #{docCollName.inspect} from this collection: #{@coll.name.inspect}")
      # Create selector
      selector = { 'name.value' => docCollName }
      # Collection metadata helper
      collMetadataHelper = @kbDatabase.collMetadataHelper()
      # Get coll metadata document
      collMetadataDoc = collMetadataHelper.metadataForCollection(docCollName, true)
      if(collMetadataDoc)
        raise "ERROR: You cannot delete the model for internal collections like #{docCollName.inspect} !" if(collMetadataDoc.getPropVal('name.internal'))

        # Retrieve doc first (need the _id)
        modelRec = self.coll.find_one( selector )
        raise "ERROR: Unexpectedly could not find model for collection #{docCollName.inspect} (using selector #{selector.inspect} )" unless(modelRec)
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG - DEL MODEL', "Got model doc. Has name #{modelRec['name']['value'].inspect} and _id #{modelRec['_id'].inspect}")
        docRef = BSON::DBRef.new(self.class::KB_CORE_COLLECTION_NAME, modelRec["_id"])
        # Do delete
        result = self.coll.remove( selector )
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Remove doc result:\n\n#{result.inspect}\n\n")
        if(result.is_a?(Hash) and result["ok"] == 1.0)
          if(result['n'] == 1)
            retVal = true
            @docForCollectionCache.delete(docCollName)
            # Record deletion in history for kbModels
            versionsHelper = @kbDatabase.versionsHelper(@coll.name)
            revisionsHelper = @kbDatabase.revisionsHelper(@coll.name)
            versionsHelper.createDeletionHistory(@coll.name, docRef, author)
            revisionsHelper.createDeletionHistory(@coll.name, docRef, "/", author)
          else
            $stderr.debugPuts(__FILE__, __method__, '!! FATAL !!', "The remove reports it succeeded but remove MORE THAN ONE (1) metadata document. This is bad, since only the document for collection #{docCollName.inspect} should have been deleted! Rather, #{result['n'].inspect} documents were deleted! More info:\n\n#{result.inspect}\n\n")
            retVal = false
          end
        else
          $stderr.debugPuts(__FILE__, __method__, 'ERROR', "Failed to remove the metadata document for collection #{docCollName.inspect}. Result code was #{result['ok'].inspect} rather than 1.0 and the number of affected docs was #{result['n'].inspect} rather than 1. More info:\n\n#{result.inspect}\n\n")
          retVal = false
        end
      end

      return retVal
    end

    def valid?(doc, restoreMongo_idKey=false)
      modelValidator = BRL::Genboree::KB::Validators::ModelValidator.new()
      modelOK = modelValidator.validateModel(doc)
      if(modelOK)
        retVal = true
      else
        # Ensure this is Array<String> even if newer hash-of-errors-keyed-by-propPath is available
        if( modelValidator.respond_to?(:buildErrorMsgs) )
          @lastValidatorErrors = modelValidator.buildErrorMsgs()
        else
          @lastValidatorErrors = modelValidator.validationErrors.dup
        end
        retVal = false
      end
      return retVal
    end

    # Check if @modelDoc@ appears to be a valid data model schema document
    # @param [Hash] modelDoc The document to check.
    # @return [Boolean] indicating where the document looks like a data model schema document or not.
    def self.valid?(modelDoc)
      modelValidator = BRL::Genboree::KB::Validators::ModelValidator.new()
      modelOK = modelValidator.validateModel(modelDoc)
      if(modelOK)
        retVal = true
      else
        retVal = false
      end
      return retVal
    end

    # A "model" are stored internally with some extra metadata called a "modelDoc"
    # @see modelFromModelDoc
    def modelDocFromModel(collName, model, opts={})
      modelDoc = docTemplate(collName)
      modelDoc.setPropVal('name.description', opts['description']) if(opts['description'])
      modelDoc.setPropVal('name.internal', opts['internal']) if(opts['internal'] == true or opts['internal'] == false)
      modelDoc.setPropVal('name.model', model)
      return modelDoc
    end

    # Get a "model" from a "modelDoc"
    # @raise ArgumentError unless @modelDoc@ is a Hash-like object
    # @see modelDocFromModel
    def modelFromModelDoc(modelDoc)
      modelDoc = BRL::Genboree::KB::KbDoc.new(modelDoc)
      modelDoc.getPropVal("name.model")
    end

    # @param [String] propPath the data document path to a property
    # @param [BRL::Genboree::KB::KbDoc] propDef a full model definition or a piece of one
    # @param [Hash] opts OPTIONAL. Any special options that influence how propDef is found or returned.
    # @return [BSON::OrderedHash, NilClass] the (model/submodel) definition of the property given by propPath
    #   or nil if the propDef cannot be found (bad propPath for this propDef model/submodel)
    def findPropDef(propPath, propDef, opts={})
      self.class.findPropDef(propPath, propDef, opts)
    end

    def self.findPropDef(propPath, propDef, opts={})
      #$stderr.puts '-' * 50
      # Generally come in with model property path.
      # - recursive calls will hand in array of current path elements we are examining
      if(propPath.is_a?(String))
        # Replace any '[FIRST|LAST|Index]' with empty string
        #propPath = propPath.gsub(/\.\[\s*(?:FIRST|LAST|\d+)?\s*\]/, "")
        propPath = KbDoc.docPath2ModelPath(propPath)
        pathElems = propPath.gsub(/\\./, "\v").split('.').map { |xx| xx.gsub(/\v/, '.') }
      else
        pathElems = propPath
      end
      # What property in the path are we looking for in propDef?
      nextPropName = pathElems.shift
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Looking for: #{nextPropName.inspect} ; (rest of path: #{pathElems.inspect})")
      # Look for nextPropName within propDef in the appropriate way
      if(propDef.acts_as?(Hash)) # likely either root property or a visit to a specific sub-property's definition
        # If propDef actually looks like a full model doc, as stored in mongoDB, extract the model itself (the root propDef)
        if(propDef.is_a?(BRL::Genboree::KB::KbDoc))
          putModel = propDef['name']['properties']['model']['value'] rescue nil
          propDef = putModel unless(putModel.nil?)
        end
        # Name of the property defined by propDef?
        propName = propDef['name']
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Current propDef for #{propName.inspect}")
        unless(propName and propName.to_s =~ /\S/)
          raise "ERROR: invalid property definition argument; has no 'name' field defining the name of the property being defined!"
        else # propName looks reasonable
          if(propName == nextPropName) # it matches...yay, we have the next relevant propDef
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Current propDef name MATCHES #{nextPropName.inspect}")
            if(pathElems.empty?) # and there are no more path elements to consider! this is the propDef we wanted!
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Which is the FINAL prop in the path. ALL DONE, this is the propDef we want!")
              retVal = propDef
            else # there are more sub-properties in the path...go find & examine the next sub-propDef
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Need to keep looking.")
              subPropDef = (propDef['properties'] or propDef['items'])
              if(subPropDef) # found sub-property definitions we can examine
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Current prop has sub-properties or sub-items #{subPropDef.class} in which to look for #{pathElems.inspect}")
                retVal = findPropDef(pathElems, subPropDef)
              else # there are no more (oh oh, not done but hit a dead end...)
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "NOT FOUND: Not done finding our prop, but have run out of sub-property definitions.")
                retVal = nil
              end
            end
          else # doesn't match, visiting this property was a waste (probably is the root and doesn't match path)
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "WASTE: why visit #{propName.inspect} when looking for #{nextPropName.inspect}")
            retVal = nil
          end
        end
      elsif(propDef.acts_as?(Array)) # either an array of sub-properties or an array of sub-items
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Looking in sub-properties or sub-items for #{nextPropName.inspect}. (#{propDef.size} sub-props/items to examine)")
        # Regardless, find the sub-propDef whose name field matches the property we're currently looking for
        subPropDef = propDef.find { |xx| xx['name'] == nextPropName }
        if(subPropDef) # Found it. Visit it.
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Candidate sub-propDef found while looking for #{nextPropName.inspect}. Visit it." )
          # Restore nextPropName back to front of pathElems, since we want to confirm subPropDef is the next definition we should examine
          retVal = findPropDef( pathElems.unshift(nextPropName), subPropDef)
        else # Not found
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Oh oh, looking for #{nextPropName.inspect} but can't find in sub-propDefs of this propDef.")
          retVal = nil
        end
      else
        raise "ERROR: the property definition appears to be invalid at the point where we look for #{nextPropName.inspect}. Property definitions should be either Hash-like objets or Array-like object. At this point in the model, the definition is a #{propDef.class}."
      end

      # @todo ARJ - New. Review.
      # Were we asked for the non-recursive propDef? Then prune it of 'properties' and 'items'
      if(retVal and opts[:nonRecursive])
        pruned = prunePropDef(retVal)
        retVal = pruned[:propDef]
      end

      return retVal
    end

    # Get the hints array for the propert at @propPath@
    # @param [String] propPath The model or propDef within which to find the property for which to get hints array
    # @param [Hash] propDef A full model definition or a piece of one (i.e. a propDef)
    # @param [Hash{Symbol, Object}] opts OPTIONAL. Any special options that influence how propDef is found or returned.
    # @return [Array<String>] The list of hints for the property at @propPath@
    def hints(propPath, model, opts={})
      self.class.hints(propPath, model, opts)
    end

    # @see #hints
    def self.hints(propPath, model, opts={})
      retVal = []
      # Get specific propDef object for propPath
      opts = opts.deep_clone
      opts[:nonRecursive] = true
      propDef = self.findPropDef(propPath, model, opts)
      # Get 'Hints' array
      hints = BRL::Genboree::KB::Validators::ModelValidator::FIELDS['Hints'][:extractVal].call(propDef, nil)
      retVal = hints if(hints.acts_as?(Array))
      return retVal
    end

    # Does the property in the model have ALL the indicated hints?
    # @param [Array<String>] hints The Array of hint strings, all of which must be present for the property at propPath
    # @param [String] propPath The model or propDef within which to find the property for which to test the hints
    # @param [Hash] propDef A full model or a piece of one
    # @param [Hash{Symbol, Object}] opts OPTIONAL. Any special options that influence how propDef is found or returned.
    # @return [Boolean] If the property at @propPath@ has all the listed hints.
    def hasHints?(hints, propPath, propDef, opts={})
      self.class.hasHints?(hints, propPath, propDef, opts)
    end

    # @see #hasHints?
    def self.hasHints?(hints, propPath, propDef, opts={})
      retVal = false
      # Get all the hints
      propHints = self.hints(propPath, propDef, opts)
      if(hints.acts_as?(Array) and propHints.acts_as?(Array))
        retVal = hints.all? { |hint|
          propHints.include?( hint.to_s.strip )
        }
      end
      return retVal
    end

    # Does the property in the model have the specific hint keyword?
    # @param [String] hint The hint String, which must be present for the property at propPath
    # @param [String] propPath The model or propDef within which to find the property for which to test for the hint
    # @param [Hash] propDef A full model or a piece of one
    # @param [Hash{Symbol, Object}] opts OPTIONAL. Any special options that influence how propDef is found or returned.
    # @return [Boolean] If the property at @propPath@ has all the listed hints.
    def hasHint?(hint, propPath, propDef, opts={})
      self.class.hasHint?(hint, propPath, propDef, opts)
    end

    # @see #hasHint?
    def self.hasHint?(hint, propPath, propDef, opts={})
      self.hasHints?( [ hint ], propPath, propDef, opts )
    end

    DOC_LINK_DOMAINS = [ /^url$/, /^labelUrl.*$/, /^selfUrl$/]
    GETDOCLINKPROPS_DEFAULT_OPTS = { :return => :paths, :validateTgtCollNames => false }
    # Get the properties that appear to be doc links.
    # @param [Hash] model The model or propDef within which to find properties that appear to be doc links.
    # @param [Hash{Symbol,Object}] opts Optional. Options hash which can influence what is returned or behavior.
    #   @option opts [Symbol] :return Default :paths. What to return, indicated as a Symbol. Supported: :paths, :propDefs, :prunedPropDefs
    #   @option opts [Boolean] :validateTgtCollNames Defalut false. Whether to validate the target collection name found in Object Type.
    #     Requires valid @kbDatabase (i.e. not in offline mode)
    # @return [Array<String>, Array<Hash>] The doc links properties either as prop paths or full/pruned propDefs
    def getDocLinkProps(model, opts=GETDOCLINKPROPS_DEFAULT_OPTS)
      retVal = []
      opts = GETDOCLINKPROPS_DEFAULT_OPTS.merge(opts)
      rootProp = getRootProp(model)
      # Scan the propdefs to find ones that have appropriate metadata
      eachPropDef(model, rootProp) { |propInfo|
        propDef = propInfo[:propDef]
        # Domain must be one of the link-appropriate ones.
        if(DOC_LINK_DOMAINS.any?() { |re| propDef['domain'] =~ re })
          propInfo[:propPath]
          # Can't be a link to self.
          if(propDef['Subject Relation to Object'].to_s.strip !~ /^isSelf$/i)
            # Must have a {ns}:{collName} Object Type
            if(propDef['Object Type'] =~ /^([^:]+):(.+)$/)
              namespace = $1
              tgtCollName = $2
              # Are we supposed to check KB to see if collName is valid? Better have a valid @kbDatabase
              if(opts[:validateTgtCollNames])
                tgtColls = @kbDatabase.collections(:data, :names)
                tgtCollOk = ( tgtColls.index(tgtCollName) ? true : false )
              else
                tgtCollOk = true
              end

              # Looks like this is doc link
              if(tgtCollOk)
                returnType = opts[:return]
                if(returnType == :paths)
                  retVal << propInfo[:propPath]
                elsif(returnType == :prunePropDefs)
                  prunedDef = propDef.deep_clone
                  prunedDef.delete('properties')
                  prunedDef.delete('items')
                  retVal << prunedDef
                else # full propDef
                  retVal << propDef
                end
              end
            end
          end
        end
      }
      return retVal
    end

    def getPropPathsForDomain(model, domainStr, opts={})
      return getPropPathsForFieldAndValue(model, 'domain', domainStr, opts)
    end

    PATHS_FOR_FIELD_AND_VALUE_DEFAULT_OPTS = { :operation => :equals }
    # Returns an array of property paths that matched the provided value for the given field
    # @param [Hash] model The actual user model (the rootProp definition)
    # @param [String] field The name of the field
    # @param [String] value The value to match
    # @param [Hash{Symbol,Object}] opts Options hash to enable less common behaviors.
    # @option opts [Symbol] :operation The operation to use when testing the @value@
    #   The default is :equals (i.e. ==). But :contains is also useful for testing
    #   fields with string values.
    # @return [Array] An array of property paths
    def getPropPathsForFieldAndValue(model, field, value, opts={})
      allOpts = PATHS_FOR_FIELD_AND_VALUE_DEFAULT_OPTS.merge( opts )
      op = allOpts[:operation]
      @propPaths = []
      if( model.key?(field) )
        if( ( op == :equals and model[field] == value ) or
            ( op == :contains and model[field] =~ /#{Regexp.escape(value)}/ ) )
          @propPaths << model['name']
        end
      end

      model['properties'].each { |prop|
        addPropPathsForFieldAndValue(prop, field, value,  model['name'], opts)
      }
      return @propPaths
    end

    # INTERNAL HELPER METHOD
    # Helper method for getPropPathsForFieldAndValue()
    # Recursively searches the children properties of the root property that match the given field and value
    # @param [Hash] prop The property definition
    # @param [String] field
    # @param [String] value
    # @param [String] parent A '.' delimited string indicating the ancestory of the property being examined
    # @param [Hash] opts Options hash to enable less common behaviors.
    def addPropPathsForFieldAndValue(prop, field, value, parent, opts={})
      allOpts = PATHS_FOR_FIELD_AND_VALUE_DEFAULT_OPTS.merge( opts )
      op = allOpts[:operation]
      if( prop.key?(field) )
        if( ( op == :equals and prop[field] == value ) or
            ( op == :contains and prop[field] =~ /#{Regexp.escape(value)}/ ) )
          @propPaths << "#{parent}.#{prop['name']}"
        end

      end
      if(prop['properties'])
        prop['properties'].each {|pp|
          addPropPathsForFieldAndValue(pp, field, value,  "#{parent}.#{prop['name']}", opts)
        }
      elsif(prop['items']) # Items must be singly-rooted
        rootProp = prop['items'][0]
        if(prop['items'] and opts[:selectorCompatible])
          currParent = "#{parent}.#{prop['name']}.[]"
        else
          currParent = "#{parent}.#{prop['name']}"
        end
        addPropPathsForFieldAndValue(rootProp, field, value,  currParent, opts)
      end
    end

    # Is the provided property path within an items list (under a property that has items)?
    # @param [String] propPath The property path in question. If it's not a model path (but rather a KbDoc path)
    #   that's ok it will be converted to a model path and then assessed.
    # @param [String, KbDoc, Hash] collNameOrModel The collection name, wrapped-model KbDoc, or
    #   even raw model. Will get you the actual model for this arg in the most efficient way.
    # @return [Boolean] Whether propPath is within--somewhere under--an items list.
    def withinItemsList(propPath, collNameOrModel, opts={})
      retVal = false
      modelPath = KbDoc.docPath2ModelPath(propPath)
      mongoDocPath = modelPath2MongoPath(modelPath, collNameOrModel, opts)
      elems =  mongoDocPath.gsub(/\\./, "\v").split('.')
      idx = elems.index('items')
      if(idx and (idx % 2 == 1))
        retVal = true
      else
        retVal = false
      end
      return retVal
    end

    # Get an array of all the property paths, in model order (depth-first), optionally starting
    #   not at the root property but somewhere within the model.
    # @param [String, KbDoc, Hash] collNameOrModel The collection name, wrapped-model KbDoc, or
    #   even raw model. Will get you the actual model for this arg in the most efficient way.
    # @param [String, nil] startingProp OPTIONAL. Rather than starting at the root property, start
    #   at this property and get the prop paths at or below it.
    # @return [Array<String>] The list of prop paths in depth-first model order.
    def allPropPaths(collNameOrModel, startingProp=nil, opts={})
      retVal = nil
      model = getModel(collNameOrModel)
      if(model)
        retVal = []
        if(startingProp) # then getting some internal/relative paths
          model = findPropDef(startingProp, model, opts)
        else # for whole model
          startingProp = getRootProp(model) unless(startingProp)
        end

        eachPropDef(model, startingProp, opts) { |propDef|
          retVal << propDef[:propPath]
        }
       end
      return retVal
    end

    # @note the "DocPath" referred to here is not the same as a document property path that
    #   is mentioned in other areas of the kb code base. This "DocPath" is intended for use with
    #   MongoDB (note the use of ".properties." and ".items." below to see this)
    # @param [String] modelPath Model path for property of interest. This won't have .[0]. or even .[].
    #   type path elements indicating a specific item.
    # @param [Hash] model The model Hash. Not model docuemnt that gets stored in the kbModels collection
    #   but rather the model component specifically (not a KbDoc). NOT collection name either. Actual model.
    def self.modelPath2DocPath(modelPath, model, opts={})
      valueField = opts[:valueField]
      forceRefresh = ( opts.key?(:forceRefresh) ? opts[:forceRefresh] : false)
      unless(valueField)
        valueField = 'value'
      end

      docPath = nil
      # Ensure that the modelPath is actually a model path and not a doc path.
      modelPath = KbDoc.docPath2ModelPath(modelPath)

      mpathParts = BRL::Genboree::KB::KbDoc.parsePath(modelPath)

      if(model and !model.empty?)
        docPath = ''
        currProps = [ model ]
        foundPropForPart = false # ensure this is available after ALL done as well
        mpathParts.each_index { |ii|
          part = mpathParts[ii]
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "part: #{part.inspect}")
          foundPropForPart = false # reset after looking for each part of the modelPath
          currProps.each { |currProp|
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "    currProp: #{currProp["name"].inspect}")
            # Get name of current property we're visiting
            name = currProp['name'] rescue nil
            if(name) # the property name field available
              if(currProp['name'] == part) # found the property matching this poing in the path
                foundPropForPart = true
                docPath += part
                unless(ii >= mpathParts.lastIndex) # then we have more of the modelPath to look for
                  properties = (currProp['properties'] || nil)
                  if(properties) # it has sub-properties ; look in them for the next part of the model path
                    docPath += '.properties.'
                    currProps = properties
                    break # done looking through the set of properties ; found the one ('part') we wanted
                  else # it may have sub-items if not sub-properties
                    items = (currProp['items'] || nil)
                    if(items) # it has sub-items ; look in them for the next part of the model path
                      docPath += '.items.'
                      currProps = items
                    else # has neither sub-properties nor sub-items ; cannot look further
                      currProps = []
                    end
                  end
                end
                break # done examining current set of properties ; found the one ('part') we wanted ; move on to next part of model path as appropriate
              # else visit next sibling property in currProp...may it matches 'part'
              end
            else # this property has no name? what?
              raise KbError, "ERROR: the model shown below is invalid. The property 'name' field is missing for #{part.inspect} or one of its sibling properties. Model:\n\n#{JSON.pretty_generate(model) rescue model.inspect}\n\n"
            end
          }
          unless(foundPropForPart)
            raise KbError, "ERROR: the model path provided (#{modelPath.inspect}) does not fit the actual model shown below. There are some property names that are unknown in the model, are missing, or are not in the correct location in the path. Model:\n\n#{JSON.pretty_generate(model) rescue model.inspect}\n\n"
          end
        }
        if(foundPropForPart)
          docPath += ".#{valueField}"
        else #
          docPath = nil
        end
      else
        raise KbError, "ERROR: the model provided is nil, empty, or otherwise invalid. If retrieved from a specific collection, has that collection been properly added using GenboreeKB functionality, is it spelled corretly, etc. Model argument:\n\n#{model.inspect}\n\n"
      end

      return docPath
    end

    # @see {ModelsHelper.modelPath2DocPath}
    def modelPath2DocPath(modelPath, collOrModel=@coll.name, opts={})
      model = getModel(collOrModel, opts)
      if( model and !model.empty? )
        retVal =  self.class.modelPath2DocPath( modelPath, model, opts )
      else
        retVal = nil
        raise KbError, "ERROR: the model retrieved is nil, empty, or otherwise invalid. If collOrModel argument is a model or model-doc (KbDoc containing the model + some metadata), the model content is invalid. If collOrModel is a collection name, then the model dynamically retrieved for it is invalid and need to check that its been properly added using GenboreeKB functionality, is it spelled corretly, etc. collOrModel argument:\n\n#{collOrModel.inspect}\n\n"
      end
      return retVal
    end
    alias_method :modelPath2MongoPath, :modelPath2DocPath

    def self.modelPathToPropSelPath(modelPath, model)
      mongoPath = self.modelPath2DocPath(modelPath, model)
      elems = mongoPath.gsub(/\\./, "\v").split('.')
      newElems = [ ]
      elems.each_index { |ii|
        if(ii % 2 == 1)
          if(elems[ii] == 'items')
            newElems << '[]'
          end
        else
          newElems << elems[ii]
        end
      }
      return newElems.join('.')
    end

    def modelPathToPropSelPath(modelPath, model)
      return self.class.modelPathToPropSelPath(modelPath, model)
    end

    # Flatten a model by mapping propPath to its propDef (and removing tree edges like properties and items)
    # @param [Hash] model
    # @param [Hash] opts named parameters
    #   [:model, :propSelector] :format the type of property path to use as keys in the map
    # @return [Hash] flattened model: a map of property path to its property definition
    # @note in addition to propDef we add whether a child is a "property" or an "item" of its parent in :relToParent
    def self.flattenModel(model, opts={})
      map = {}
      defaultOpts = {
        :format => :model
      }
      opts = defaultOpts.merge(opts)
      propPath = model["name"]
      eachPropDef(model, propPath, opts) { |flatObj|
        map[flatObj[:propPath]] = flatObj[:propDef]
      }
      return map
    end
    def flattenModel(model, opts={})
      self.class.flattenModel(model, opts)
    end

    # Yield hashes with keys :propDef and :propPath
    def self.eachPropDef(propDefTree, propPath, opts={}, &blk)
      rv = 0
      prunedObj = prunePropDef(propDefTree)
      yieldObj = { :propPath => propPath, :propDef => prunedObj[:propDef] }
      yield yieldObj
      prunedObj[:properties].each { |pptyPropDef|
        pptyPropPath = appendPropPath(propPath, pptyPropDef)
        pptyPropDef.merge!({:relToParent => "property"})
        eachPropDef(pptyPropDef, pptyPropPath, opts) { |flatObj|
          yield flatObj
        }
      }
      prunedObj[:items].each { |itemPropDef|
        if(opts[:format] == :propSelector)
          itemPropPath = appendItemPropPath(propPath, itemPropDef)
        else
          itemPropPath = appendPropPath(propPath, itemPropDef)
        end
        itemPropDef.merge!({:relToParent => "item"})
        eachPropDef(itemPropDef, itemPropPath, opts) { |flatObj|
          yield flatObj
        }
      }
      return rv
    end

    def eachPropDef(propDefTree, propPath, opts={}, &blk)
      self.class.eachPropDef(propDefTree, propPath, opts, &blk)
    end

    # Remove "properties" and "items" subtrees from the root @propDef@
    def self.prunePropDef(propDef)
      rv = { :propDef => {}, :properties => [], :items => [] }
      propDef = propDef.dup()
      if(propDef.key?("properties"))
        rv[:properties] = propDef.delete("properties")
      end
      if(propDef.key?("items"))
        rv[:items] = propDef.delete("items")
      end
      rv[:propDef] = propDef
      return rv
    end
    def prunePropDef(propDef)
      self.class.prunePropDef(propDef)
    end

    # Add the name from a propDef to a cumulative propPath
    def self.appendPropPath(propPath, propDef)
      return "#{propPath}.#{propDef["name"]}"
    end
    def appendPropPath(propPath, propDef)
      self.class.appendPropPath(propPath, propDef)
    end

    def self.appendItemPropPath(propPath, propDef)
      return "#{propPath}.[].#{propDef["name"]}"
    end
    def appendItemPropPath(propPath, propDef)
      self.class.appendItemPropPath(propPath, propDef)
    end

    # Visit each propDef along a propPath
    # @param [String] propDef property definition that property paths are relative to 
    #   (in general, the value of this parameter is probably just the model)
    # @param [String] propPath relative property path to the value of the propDef param
    # @yield [Hash] propDef for each property along the propPath
    def self.walkPropPath(propDef, propPath)
      flatPropDef = flattenModel(propDef)
      propPathElems = propPath.split(".")
      propPathElems.size.times { |ii|
        curPath = propPathElems[0..ii].join(".")
        rv = flatPropDef[curPath]
        if(rv.nil?)
          break
        else
          yield rv
        end
      }
      nil
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
        "name"        => { "value" => collName, "properties" =>
        {
          "description" => { "value" => "" },
          "internal"    => { "value" => false },
          "model"       => { "value" => nil }
        }}
      }
      return BRL::Genboree::KB::KbDoc.new(retVal)
    end

    # ----------------------------------------------------------------
    # INTERNAL HELPERS - mainly for internal use but possibly useful outside too
    # ----------------------------------------------------------------

    # Get the actual model for a collection name or for a wrapped-document; even if handed
    #   the actual model already due to uniform/safe processing, it will simply hand it back.
    #   Mainly geared toward internal use in this class (hence it looks for a wrapped-model
    #   in opts[:modelDoc] in case it's there), but very generically useful. Can even force
    #   a reload of the actual model from the mongo database.
    # @param [String, Mongo::Collection, KbDoc, Hash] collOrModel The collection name, Mongo::Collection
    #   object wrapped-model KbDoc, or even raw model. Will get you the actual model for this arg in the
    #   most efficient way.
    # @param [Hash] opts OPTIONAL. A Hash of options, the more generically useful of which is the
    #   @:forceRefresh@ flag which will cause this instance to retrieve the model again rather than
    #   use a previously retrieved model from RAM. Another options for internal use is @:modelDoc@
    #   which in some cases is used to save time within the code of this class.
    # @return [Hash,nil] A model object or nil if none found.
    def getModel(collOrModel, opts={})
      forceRefresh = ( opts.key?(:forceRefresh) ? opts[:forceRefresh] : false)
      #forceRefresh = true
      gmOpts = opts.merge( { :forceRefresh => forceRefresh } )
      if( forceRefresh ) # then call memoized version but with the special terminal "true" arg to "bypass memoized value and rememoize"
        model = getModelMemoized( collOrModel, gmOpts, true)
      else # call memoized version, using any cached values
        model = getModelMemoized( collOrModel, gmOpts )
      end
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "collOrModel is a: #{collOrModel.class} ; gmOpts: #{opts.inspect} ; model: #{model.class} with keys #{model.keys.inspect rescue '[NONE!]'}")
      return model
    end

    def getModelMemoized( collOrModel, opts ) # implicit/special "true" argument can be supplied to "bypass memoized value and rememoize"
      model = nil
      # If collOrModel is a hash, it's a model or model doc and takes priority over opts[:modelDoc]
      modelDoc = ( collOrModel.is_a?(Hash) ? collOrModel : opts[:modelDoc] )
      forceRefresh = ( opts[:forceRefresh] or false )
      raise ArgumentError, "ERROR: when calling getModel() you can't only provide the model or model record AND specify you want to 'forceRefresh'. Refresh from what? You gave the model or model record document without info about what collection it came from! Refresh only makes sense when providing the collection as a Mongo::Collection object or a String that is the collection name." if(forceRefresh and !collOrModel.is_a?(String) and !collOrModel.is_a?(Mongo::Collection))

      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "forceRefresh: #{forceRefresh.inspect} ; collOrModel is a: #{collOrModel.class} ; opts: #{opts.inspect} ; modelDoc: #{modelDoc.class} w/keys #{modelDoc.keys.inspect rescue '[NONE!]'}")

      if( collOrModel.is_a?( String ) )
        coll = collOrModel
        modelDoc = nil if( forceRefresh ) # wipe any given modelDoc if refreshing
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "collOrModel was String (coll name #{coll.inspect})")
      elsif( collOrModel.is_a?(Mongo::Collection) )
        coll = collOrModel.name
        modelDoc = nil if( forceRefresh ) # wipe any given modelDoc if refreshing
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "collOrModel was a Mongo::Collection ; got the coll name from it: #{coll.inspect}")
      else # collOrModel is a Hash of some kind...we have no collection to work from, just this model or model record
        coll = nil
        # wrap in KbDoc interface unless it's already one, see if it's actually a model record rather than model itself
        if( collOrModel.respond_to?( :getPropVal ) )
          collOrModelKbDoc = collOrModel
        else # wrap in KbDoc so can test it sensibly
          collOrModelKbDoc = BRL::Genboree::KB::KbDoc.new( collOrModel )
        end

        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "collOrModelKbDoc:\n\n#{JSON.pretty_generate( collOrModelKbDoc )}\n\n")

        tryAsModelRec = collOrModelKbDoc.getPropVal( 'name.model' )
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "looking at collOrModelKbDoc (a #{collOrModelKbDoc.class}) as a model record, we attempted to get the actual model out of the record: #{tryAsModelRec.class} w/keys #{tryAsModelRec.keys.inspect rescue '[NONE!]'}")
        if( tryAsModelRec and tryAsModelRec.respond_to?(:'key?') and tryAsModelRec.key?('identifier') ) # we did indeed extract the actual model
          modelDoc = collOrModelKbDoc
          model = tryAsModelRec
          #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "YES, tryAsModelRec was a MODEL RECORD ; modelDoc is now #{modelDoc.class} w/keys #{modelDoc.keys.inspect} and model is now #{model.class} w/keys #{model.keys.inspect}")
        else # we have the model itself and can't do forceRefresh because not enough info
          model = collOrModel
          modelDoc = nil
          #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "looks like collOrModel arg was the model itself: #{model.class} w/keys #{model.keys.inspect rescue '[NONE]'}")
        end
      end

      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "at this point => model: #{model.class} w/keys #{model.keys.inspect rescue '[NONE!]'} ; modelDoc: #{modelDoc.class} w/keys: #{modelDoc.keys.inspect rescue '[NONE!]'} and coll is #{coll.inspect}")

      # At this point we either have:
      # * A model, passed in as arg that is model record or model itself. In this case, don't need to do more.
      # * A model record from the options and a collection name to help deal with refresh. We'll get out the model itself unless refresh.
      # * A nil modelDoc but collection info so we can do a retrieve
      unless( model )
        if( modelDoc ) # try to get model from model record we now have [or were given]
          modelDoc = BRL::Genboree::KB::KbDoc.new( modelDoc ) unless( modelDoc.respond_to?(:getPropVal) )
          model = modelDoc.getPropVal( 'name.model' )
        end
        unless( model ) # still no model available or refreshing, must retrieve using coll
          #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "collName: #{coll.inspect}")
          modelDoc = modelForCollection(coll, forceRefresh)
          model = ( modelDoc ? modelDoc.getPropVal('name.model') : nil )
        end
      end

      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Returning model which is a #{model.inspect}.")
      return model
    end

    # ----------------------------------------------------------------
    # MEMOIZE now-defined methods
    # ----------------------------------------------------------------
    MEMOIZED_INSTANCE_METHODS.each { |meth| memoize meth }

  end # class ModelsHelper
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers
