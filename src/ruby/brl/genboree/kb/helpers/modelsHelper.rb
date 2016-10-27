#!/bin/env ruby

require 'brl/genboree/kb/helpers/abstractHelper'

module BRL ; module Genboree ; module KB ; module Helpers
  # This class assists with the document models for the various collections.
  # @note Every collection in the GenboreeKB MongoDB database must have a model
  #   document in the @kbModels@ collection. That model describes the kinds of documents
  #   that are allowed in the collection.
  class ModelsHelper < AbstractHelper
    # @return [String] the name of the core GenboreeKB collection the helper assists with.
    KB_CORE_COLLECTION_NAME = "kbModels"
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
      return self.docForCollection(collName, "name.value", forceRefresh)
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
      forceRefresh = ( opts.key?(:forceRefresh) ? opts[:forceRefresh] : false)
      # Get the model first
      model = getModel(collNameOrModel, opts)
      if(model)
        retVal = model["name"]
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
        if(@lastValidatorErrors.is_a?(Array))
          validationErrStr = "  - #{@lastValidatorErrors.join("\n  - ")}"
        else
          validationErrStr = "  - [[ No detailed error messages available ; likely a code bug or crash ]]"
        end
        retVal = KbError.new("ERROR: the model document is not a valid model schema and thus cannot be used! Specifically:\n#{validationErrStr}")
      end
      return retVal
    end

    def valid?(doc, restoreMongo_idKey=false)
      modelValidator = BRL::Genboree::KB::Validators::ModelValidator.new()
      modelOK = modelValidator.validateModel(doc)
      if(modelOK)
        retVal = true
      else
        @lastValidatorErrors = modelValidator.validationErrors.dup
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

    def getPropPathsForDomain(model, domainStr, opts={})
      return getPropPathsForFieldAndValue(model, 'domain', domainStr, opts)
    end

    # Returns an array of property paths that matched the provided value for the given field
    # @param [Hash] model The actual user model (the rootProp definition)
    # @param [String] field The name of the field
    # @param [String] value The value to match
    # @param [Hash] opts Options hash to enable less common behaviors.
    # @return [Array] An array of property paths
    def getPropPathsForFieldAndValue(model, field, value, opts={})
      @propPaths = []
      if(model.key?(field) and model[field] == value)
        @propPaths << model['name']
      end

      model['properties'].each {|prop|
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
      if(prop.key?(field) and prop[field] == value)
        @propPaths << "#{parent}.#{prop['name']}"
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
    # @param [String, Mongo::Collection, KbDoc, Hash] collOrModel The collection name, wrapped-model KbDoc, or
    #   even raw model. Will get you the actual model for this arg in the most efficient way. If
    #   you happen to pass in a KbDoc path (with .[idx] and such), it will be converted to model path form.
    def modelPath2DocPath(modelPath, collOrModel=@coll.name, opts={})
      valueField = opts[:valueField]
      forceRefresh = ( opts.key?(:forceRefresh) ? opts[:forceRefresh] : false)
      unless(valueField)
        valueField = 'value'
      end

      docPath = nil
      # Ensure that the modelPath is actually a model path and not a doc path.
      modelPath = KbDoc.docPath2ModelPath(modelPath)

      mpathParts = BRL::Genboree::KB::KbDoc.parsePath(modelPath)

      #mpathParts = modelPath.gsub(/\\\./, "\v").split(/\./).map { |xx| xx.gsub(/\v/, '.') }
      model = getModel(collOrModel, opts)

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
              raise KbError, "ERROR: the model for #{collOrModel.inspect} is invalid. The property 'name' field is missing for #{part.inspect} or one of its sibling properties."
            end
          }
          unless(foundPropForPart)
            raise KbError, "ERROR: the model path provided (#{modelPath.inspect}) does not fit the actual model for collection #{collOrModel.inspect}. There are some property names that are unknown in the model, are missing, or are not in the correct location in the path."
          end
        }
        if(foundPropForPart)
          docPath += ".#{valueField}"
        else #
          docPath = nil
        end
      else
        raise KbError, "ERROR: could not find a model for collection named #{collOrModel.inspect}. Has that collection been properly added using GenboreeKB functionality, is it spelled corretly, etc."
      end

      return docPath
    end

    alias_method :modelPath2MongoPath, :modelPath2DocPath

    def modelPathToPropSelPath(modelPath, model)
      mongoPath = modelPath2MongoPath(modelPath, model)
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
      model = nil
      forceRefresh = ( opts.key?(:forceRefresh) ? opts[:forceRefresh] : false)
      modelDoc = opts[:modelDoc]
      # Have we been handed in some modelDoc along with collName or are we reloading the model from the database?
      unless(modelDoc or forceRefresh)
        # If collNameOrModel is a Hash (not coll name string) then IT has priority over whatever we found in opts
        if(collOrModel.is_a?(Hash))
          modelDoc = collOrModel
        end
        # Either still don't have the modelDoc or we're supposed to refressh regardless of what was passed in, are we supposed to refresh?
        if(!modelDoc or forceRefresh)
          collName = ( collOrModel.is_a?(Mongo::Collection) ? collOrModel.name : collOrModel )
          modelDoc = modelForCollection(collName, forceRefresh)
        end
      end

      # Try to get the actual model out. We may have been handed the actual model in collNameOrModel
      #   or in opts[:modelDoc] as part of some uniform processing or something. If so, we'll return that;
      #   else we should have a wrapped-model KbDoc and we'll dig the actual model out of that.
      if(modelDoc)
        model = modelDoc.getPropVal('name.model') rescue nil
        unless(model) # then modelDoc is ALREADY the actual model, not the model wrapped in a KbDoc
          model = modelDoc
        end
      end

      return model
    end

  end # class ModelsHelper
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers
