#!/bin/env ruby
require 'json'
require 'yaml'
require 'uri'
require 'cgi'
require 'brl/extensions/bson' # before 'mongo' and before 'bson'
require 'mongo'
require 'brl/util/util'
require 'brl/genboree/kb/kbDoc'
require 'brl/noSQL/mongoDb/mongoDbConnection'
require 'brl/genboree/kb/helpers/abstractHelper'
require 'brl/genboree/kb/validators/docValidator'
require 'brl/genboree/kb/contentGenerators/generator'

module BRL ; module Genboree ; module KB ; module Helpers

  class DataCollectionHelper < AbstractHelper
    ITEM_MATCH = /\.\[\s*(FIRST|LAST|\d+)\s*\](?:$|\.((?!\.).)*$)/
    attr_accessor :lastValidatorErrors
    # @return [ModelsValidator] If we already have a ModelsValidator object that's been run on the collection model.
    #   Provide our {DataCollectionHelper} object with that, in case it wants to ask questions about what
    #   the validator noticed about the model. This is NOT required and DataCollectionHelper can
    #   make its own ModelsValidator if needed and re-validate a retrieved model...but why waste time
    #   redoing all that? This is a performance option.
    attr_writer :modelValidator
    # @return [KbDoc] If we already have the relevant model available as a {KbDoc}--like what is returned by {ModelsHelper#modelForCollection}--
    #   then can provide to our {DataCollectionHelper} with it, so it doesn't have to waste time calling {ModelsHelper#modelForCollection}
    #   when it needs the model. Keep in mind it's not the raw model data structre but rather the {KbDoc} that wraps & stores it.
    attr_writer :modelKbDoc
    
    # Create new instance of this helper.
    # @param [MongoKbDatabase] kbDatabase The KB database object this helper is assisting.
    # @param [String] collName The name of the document collection this helper uses.
    def initialize(kbDatabase, collName)
      super(kbDatabase, collName)
      unless(collName.is_a?(Mongo::Collection))
        @coll = @kbDatabase.getCollection(collName)
      end
      # Invalidate this cache, as it won't be appropriate for data collections
      @docForCollectionCache = nil
      @lastValidatorErrors = nil
      @lastContentNeeded = nil
      @model = nil
      @modelValidator = nil
    end

    # Create the indices for this helper's collection. Takes an @Array@ of index config @Hash@es.
    #  Each index config has 2 keys: @:spec@ and @:opts@. The values for these keys are:
    #  * @:spec@ - An @Array@, with one 2-column Array per property in the index (more than one == a compound/multi-property index)
    #      The first column is the property path as a @String@. The second column is the index direction; @Mongo::ASCENDING@ or @Mongo::DESCENDING@.
    #  * @:opts@ - A @Hash@ with the index options. Such as @:unique=>true@ for a unique index constraint or the  @:background=true@ hint.
    # Example of a single index config:
    #  {
    #    :spec => [ [ 'docRef.value', Mongo::ASCENDING ], [ 'versionNum.value', Mongo::DESCENDING ] ],
    #    :opts => { :unique => true, :background => true }
    #  }
    #
    # @note Can ONLY be called once the collections is essentially all initialized, including
    #   model, version/revision, etc. This method will use that fact to do its job.
    # @param [nil, Array<Hash>] indices Additional, after-creation indices to create. Only provide if you have custom indices
    #   or special indexing. The default value of @nil@ will cause the default indices to be build on the root property value
    #   plus any other doc-level property indices indicated by the model.
    # @return [Hash<Symbol, Hash>] Categorized results of creating each index. Key @:idxConf@ has success index configs, @:failedIndices@
    #   has failed indices and further information in its @Hash@ value. Further information for failed indices: @:idxConf@ the index config
    #   that failed, @:result@ the result of calling @create_index()@, @:err@ any Exception that was raised (if any) during creation.
    def createIndices(indices=nil)
      if(indices.nil?) # then not asking to provide some new extra indices, but create all the initial ones for this collections
        idxConfs = []
        # Need the name of the root property. Its value will get a unique index no matter what.
        idPropName = self.getIdentifierName()
        # Make the unique index on idPropName's value. A known index on this collection
        idxConfs <<
          {
            :spec => [ [ "#{idPropName}.value", Mongo::ASCENDING ] ],
            :opts => { :name => "#{idPropName[0,20]}-#{idPropName.generateUniqueString.xorDigest(8)}", :unique => true, :background => true }
          }
        # Next, get a models helper. It can help find properties marked as "index=true"
        modelsHelper = getModelsHelper()

        # Get model KbDoc. Will give from object state or will dynamically retrieve if needed.
        modelDoc = modelKbDoc()

        # Get model validator that has been run on this collection's model.
        modelValidator = modelValidator()

        # Is model valid?
        if(modelValidator.validationErrors and !modelValidator.validationErrors.empty?)
          raise "ERROR: Model for user collection #{@coll.name} appears to be INVALID, even though it was retrieved from KB and [re]validated. How? Validation errors:\n\n#{modelValidator.validationErrors.join("\n")}\n\n"
        else
          # NOW: @modelValidator.indexedDocLevelProps is a Hash of doc-level prop paths needing indices
          # Make an index for each of these doc-level paths
          modelValidator.indexedDocLevelProps.each_key { |modelPath|
            # try to make a shorter name for the index, to avoid too-long namespace error
            lastPathElem = modelPath.gsub(/\\./, "\v").split('.').last.gsub(/\v/, '.')
            lastPathElem = lastPathElem[0, 20]
            idxName = "#{lastPathElem}-#{lastPathElem.generateUniqueString.xorDigest(8)}"
            # Need full (mongo) doc path to the value for this property
            fullDocPath = modelsHelper.modelPath2DocPath(modelPath, @coll.name, { :modelDoc => modelDoc, :valueField => 'value' } )
            unique = modelValidator.indexedDocLevelProps[modelPath][:unique]
            idxConf =
              {
                :spec => [ [ fullDocPath, Mongo::ASCENDING ] ],
                :opts => { :name => idxName, :unique => unique, :background => true, :sparse => true }
                
              }
            idxConfs << idxConf
          }
        end
      else
        idxConfs = indices
      end
      # Finally, actually add the indices.
      indexingResults = super(idxConfs)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Created doc-level indices indicated by model for user collection #{@coll.name.inspect}.")
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "    - Num. indices successfully created: #{indexingResults ? indexingResults[:okIndices].size : "0 - !!COMPLETE FAILURE!! - unexpected non-Hash return value"}")
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "    - Num. indices failed: #{indexingResults ? indexingResults[:failedIndices].size : "ALL FAILED - !!COMPLETE FAILURE!! - unexpectedly returned this non-Hash value:\n\n#{indexingResults.inspect}\n\n"}")
      return indexingResults
    end
    
    # Performs a targeted deletion/removal of a sub document inside a document using the mongo find_and_replace method
    # @param [String] docId The document to update. NOTE: It is assumed validation is already done on the "updated" document.
    # @param [Author] string
    # @param [String] subDocPath The path to the sub document which needs to be removed from the document
    # @param [Hash] opts options hash with various settings
    # @return [BSON::ObjectId, KbError] The ObjectId for the updated document
    def deleteSubDoc(docId, author, subDocPath, opts={})
      updatedDoc = nil
      doc = getByIdentifier(docId)
      doc.delete("_id")
      opts[:subDocPath] = subDocPath
      docObjId = nil
      identProp = getIdentifierName()
      kbd = BRL::Genboree::KB::KbDoc.new(doc)
      ps = BRL::Genboree::KB::PropSelector.new(doc)
      # Normalizes path to always have '[]' even if the original path had '{}'
      propSelectorPaths =  ps.getMultiPropPaths(subDocPath)
      psPath = nil
      subsPropPath = nil
      if(!propSelectorPaths.empty?)
        psPath = propSelectorPaths[0] 
      else
        pathElements = subDocPath.split(".")
        subsPropPath = "#{pathElements[0..pathElements.size-4].join(".")}.[LAST]"
        psPath = ps.getMultiPropPaths(subsPropPath)[0]
      end
      pathElements = kbd.parsePath(psPath)
      parentProp = kbd.findParent(pathElements)
      mh = @kbDatabase.modelsHelper()
      mongoPath = nil
      itemDeletion = false
      if(psPath =~ /\]/) # The path is under an item list
        itemIdentifier = nil
        itemDeletion = true if(subDocPath =~ /\}$/ or subDocPath =~ /\]$/ or parentProp.is_a?(Array))
        if(parentProp.is_a?(Array))
          subDocPathEls = subDocPath.split(".")
          itemIdentifier = subDocPathEls[subDocPathEls.size-1]
        end
        if(subDocPath =~ /\]$/)
          idx = 0
          subDocPath =~ ITEM_MATCH
          extractedIdx = $1
          if(extractedIdx == 'LAST')
            idx = parentProp['items'].size - 1
          elsif(extractedIdx == "FIRST")
            idx = 0
          else
            idx = extractedIdx.to_i
          end
        elsif(subDocPath =~ /\}$/)
          subDocPathEls = subDocPath.split(".")
          itemIdentifier = subDocPathEls[subDocPathEls.size-2]
        end
        nestedDelete = ( psPath.count("]") == 1 ? false : true  )
        # First collect the order of the indices from the path
        psPathEls = psPath.split(".")
        idxOrder = []
        psPathEls.each { |el|
          if(el =~ /\[\d/)
            idxOrder.push(el.gsub(/^\[/, "").gsub(/\]$/, ""))
          end
        }
        mongoPath = mh.modelPath2MongoPath(psPath, @coll.name)
        # Strip off the 'value' at the end.
        mongoPath.gsub!(/\.value$/, "")
        # Add in the indices
        mongoPath = addIndicesToMongoPath(mongoPath, idxOrder)
        # Deleting an entire item object
        if(itemDeletion)
          currentItemObj = ps.getMultiObj(subDocPath)
          itemIdentifier = currentItemObj[0].keys[0]
          identValue = currentItemObj[0][itemIdentifier]['value']
          opts[:itemIdentifierProp] = itemIdentifier
          opts[:itemIdentifierPropValue] = identValue
          if(mongoPath =~ /\.\d+\.#{itemIdentifier}$/)
            mongoPath.gsub!(/\.\d+\.#{itemIdentifier}$/, "")
          elsif(mongoPath =~ /\.\d+$/)
            mongoPath.gsub!(/\.\d+$/, ".items")
          elsif(mongoPath !~ /\.items$/)
            mongoPath << ".items"
          end
          queryDoc = { "query" => { "#{identProp}.value" => docId }, "update" => { "$pull" => { mongoPath =>  { "#{itemIdentifier}.value" => identValue }  } } }
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "query doc:\n\n#{queryDoc.inspect}")
          updatedDoc = @coll.find_and_modify(queryDoc)
        end
      end
      # Handles both cases where property to delete is buried inside of an item list and also where it is not.
      if(!itemDeletion) 
        mongoPath = mh.modelPath2MongoPath(psPath, @coll.name) if(psPath !~ /\]/)
        mongoPath.gsub!(/\.value$/, "") 
        queryDoc = { "query" => { "#{identProp}.value" => docId }, "update" => { "$unset" => { mongoPath =>  ""  } } }
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "query doc:\n\n#{queryDoc.inspect}")
        updatedDoc = @coll.find_and_modify(queryDoc)   
      end
      docObjId = updatedDoc['_id']
      subDocPath = setSubdocPath(opts)
      unless(MongoKbDatabase::KB_HISTORYLESS_CORE_COLLECTIONS.include?(@coll.name))
        # Retrieve the actual saved doc
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Updating revision/version document for subDocPath: #{subDocPath.inspect}")
        savedDoc = @kbDatabase.docByRef(docObjId, @coll.name)
        versionsHelper = @kbDatabase.versionsHelper(@coll.name)
        revisionsHelper = @kbDatabase.revisionsHelper(@coll.name)
        versionObjId  = versionsHelper.createNewHistory(@coll.name, savedDoc, author)
        revisionObjId = revisionsHelper.createDeletionHistory(@coll.name, docObjId, subDocPath, author)
      end
      return docObjId
    end
    
    # Performs a targeted save of a sub document inside a document using the mongo find_and_replace method
    # This approach ensures that concurrent updates to various sub documents inside of a single document do not result in bad read/writes
    # @param [String] docId The document to update. NOTE: It is assumed validation is already done on the "updated" document.
    # @param [Author] string
    # @param [String] subDocPath The path to the sub document which needs to be updated
    # @param [Hash] payloadDoc The value object document that the subDocPath points to
    # @param [Hash] opts options hash with various settings
    # @return [BSON::ObjectId, KbError] The ObjectId for the updated document
    def saveSubDoc(docId, author, subDocPath, payloadDoc, opts={})
      updatedDoc = nil
      doc = getByIdentifier(docId)
      doc.delete("_id")
      opts[:newValue] = payloadDoc
      opts[:subDocPath] = subDocPath
      docObjId = nil
      identProp = getIdentifierName()
      kbd = BRL::Genboree::KB::KbDoc.new(doc)
      ps = BRL::Genboree::KB::PropSelector.new(doc)
      # Normalizes path to always have '[]' even if the original path had '{}'
      propSelectorPaths =  ps.getMultiPropPaths(subDocPath)
      psPath = nil
      subsPropPath = nil
      if(!propSelectorPaths.empty?)
        psPath = propSelectorPaths[0] 
      else
        pathElements = subDocPath.split(".")
        subsPropPath = "#{pathElements[0..pathElements.size-4].join(".")}.[LAST]"
        psPath = ps.getMultiPropPaths(subsPropPath)[0]
      end
      pathElements = kbd.parsePath(psPath)
      parentProp = kbd.findParent(pathElements)
      mh = @kbDatabase.modelsHelper()
      mongoPath = nil
      itemInsertion = false
      if(psPath =~ /\]/) # The path is under an item list
        itemIdentifier = nil
        itemInsertion = true if(subDocPath =~ /\}$/ or subDocPath =~ /\]$/ or parentProp.is_a?(Array))
        if(parentProp.is_a?(Array))
          subDocPathEls = subDocPath.split(".")
          itemIdentifier = subDocPathEls[subDocPathEls.size-1]
        end
        newItem = false
        if(subDocPath =~ /\]$/)
          idx = 0
          subDocPath =~ ITEM_MATCH
          extractedIdx = $1
          if(extractedIdx == 'LAST')
            
          elsif(extractedIdx == "FIRST")
            idx = 0
          else
            idx = extractedIdx.to_i
          end
          idx = parentProp['items'].size if(extractedIdx == 'LAST')
          newItem = true if(idx >= parentProp['items'].size)
        elsif(subDocPath =~ /\}$/)
          newItem = true if(!subsPropPath.nil?)
          subDocPathEls = subDocPath.split(".")
          itemIdentifier = subDocPathEls[subDocPathEls.size-2]
        end
        nestedInsert = ( psPath.count("]") == 1 ? false : true  )
        # First collect the order of the indices from the path
        psPathEls = psPath.split(".")
        idxOrder = []
        psPathEls.each { |el|
          if(el =~ /\[\d/)
            idxOrder.push(el.gsub(/^\[/, "").gsub(/\]$/, ""))
          end
        }
        mongoPath = mh.modelPath2MongoPath(psPath, @coll.name)
        # Strip off the 'value' at the end.
        mongoPath.gsub!(/\.value$/, "")
        # Add in the indices
        mongoPath = addIndicesToMongoPath(mongoPath, idxOrder)
        # If we are adding/replacing a complete item object, we need to know if we are doing a push or replace.
        if(itemInsertion)
          # Normalize the path and payload document
          valueDoc = normalizePayloadDocForItemInsert(payloadDoc, itemIdentifier)
          if(newItem)
            propPathToUpdate = mongoPath.gsub(/\.\d+$/, ".items")
            queryDoc = { "query" => { "#{identProp}.value" => docId }, "update" => { "$push" => { propPathToUpdate =>  valueDoc } } }
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "query doc:\n\n#{queryDoc.inspect}")
            updatedDoc = @coll.find_and_modify(queryDoc)
          else
            if(nestedInsert) # Cannot use '$' operator for nested arrays :( We will have to rely on indices
              valueDoc = valueDoc[itemIdentifier] if(itemIdentifier)
              queryDoc = { "query" => { "#{identProp}.value" => docId }, "update" => { "$set" => { mongoPath =>  valueDoc    }  }}
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "query doc:\n\n#{queryDoc.inspect}")
              updatedDoc = @coll.find_and_modify(queryDoc)
            else # We can use the '$' operator to do dynamic lookup and replace the item by it's identifier
              itemIdentifier = valueDoc.keys[0]
              currentItemObj = ps.getMultiObj(subDocPath)
              identValue = currentItemObj[0][itemIdentifier]['value']
              propPathToFind = nil
              propPathToSet = nil
              if(mongoPath =~ /\.#{itemIdentifier}$/)
                propPathToFind = mongoPath.gsub(/\.\d+\.#{itemIdentifier}$/, ".#{itemIdentifier}.value")
                propPathToSet = mongoPath.gsub(/\.\d+\.#{itemIdentifier}$/, ".$")
              else
                propPathToFind = mongoPath.gsub(/\.\d+$/, ".items.#{itemIdentifier}.value")
                propPathToSet = mongoPath.gsub(/\.\d+$/, ".items.$")  
              end
              queryDoc = { "query" => { "#{identProp}.value" => docId, propPathToFind => identValue  }, "update" => { "$set" => { propPathToSet =>  valueDoc  } } }
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "query doc:\n\n#{queryDoc.inspect}")
              updatedDoc = @coll.find_and_modify(queryDoc)
            end
          end
        end
      end
      # Handles both cases where property to update is buried inside of an item list and also where it is not.
      if(!itemInsertion) 
        mongoPath = mh.modelPath2MongoPath(psPath, @coll.name) if(psPath !~ /\]/)
        valueDoc = payloadDoc
        mongoPath.gsub!(/\.value$/, "") 
        queryDoc = { "query" => { "#{identProp}.value" => docId }, "update" => { "$set" => { mongoPath =>  valueDoc  } } }
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "query doc:\n\n#{queryDoc.inspect}")
        updatedDoc = @coll.find_and_modify(queryDoc)   
      end
      docObjId = updatedDoc['_id']
      subDocPath = setSubdocPath(opts)
      unless(MongoKbDatabase::KB_HISTORYLESS_CORE_COLLECTIONS.include?(@coll.name))
        # Retrieve the actual saved doc
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Updating revision/version document for subDocPath: #{subDocPath.inspect}")
        savedDoc = @kbDatabase.docByRef(docObjId, @coll.name)
        versionsHelper = @kbDatabase.versionsHelper(@coll.name)
        revisionsHelper = @kbDatabase.revisionsHelper(@coll.name)
        versionObjId  = versionsHelper.createNewHistory(@coll.name, savedDoc, author)
        revisionObjId = revisionsHelper.createNewHistory(@coll.name, docObjId, subDocPath, opts[:newValue], author)
      end
      return docObjId
    end
    
    def normalizePayloadDocForItemInsert(payloadDoc, itemIdentifier)
      updatedPayloadDoc = nil
      if(payloadDoc.key?('properties') or payloadDoc.key?('value'))
        updatedPayloadDoc = { itemIdentifier => payloadDoc}
      else
        updatedPayloadDoc = payloadDoc
      end
      return updatedPayloadDoc
    end
    
    def addIndicesToMongoPath(mongoPath, idxOrder)
      mpEls = mongoPath.split(".")
      finalMongoPath = []
      mpEls.each { |el|
        finalMongoPath << el
        finalMongoPath << idxOrder.shift if(el == "items")
      }
      finalMongoPath << idxOrder.shift if(!idxOrder.empty?)
      return finalMongoPath.join(".")
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
        generator = BRL::Genboree::KB::ContentGenerators::Generator.new(@lastContentNeeded, doc, @coll.name, @kbDatabase)
        contentStatus = generator.addContentToDoc()
        if(contentStatus)
          # - do second pass validation, in which missing content is not allowed (and in which we ignore the advisory :CONTENT_NEEDED result)
          # - no cast/normalize is done in this pass ; done above and content generation by our code should not need cast/normalize at this point
          secondValidation = valid?(doc, false, true)
          if(secondValidation)
            # Are we doing the actual save? Or just a no-op save run?
            if(doSave)
              retVal = super(doc, author, opts)
            else
              retVal = BSON::ObjectId.new()
            end
          else # not valid, even after adding content
            if(@lastValidatorErrors.is_a?(Array))
              validationErrStr = "  - #{@lastValidatorErrors.join("\n  - ")}"
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
            retVal = super(doc, author, opts)
          else
            retVal = BSON::ObjectId.new()
          end
        else # not valid, even after adding content
          if(@lastValidatorErrors.is_a?(Array))
            validationErrStr = "  - #{@lastValidatorErrors.join("\n  - ")}"
          else
            validationErrStr = "  - [[ No detailed validation error messages available ; likely a code bug or crash in validation or content-generation code ]]"
          end
        end
      else # not valid even before adding content
        if(@lastValidatorErrors.is_a?(Array))
          validationErrStr = "  - #{@lastValidatorErrors.join("\n  - ")}"
        else
          validationErrStr = "  - [[ No detailed validation error messages available ; likely a code bug or crash in validation or content-generation code ]]"
        end
      end
      retVal = KbError.new("ERROR: the document does not match the data model schema for the #{@coll.name} collection! Specifically:\n#{validationErrStr}") if(validationErrStr)
      return retVal
    end

    # Save (validate, generate content for) multiple documents
    # @param [Array<BRL::Genboree::KB::KbDoc, delegators to KbDoc>] docs the documents to save
    # @param [String] author the genboree account committing the change
    # @param [Hash] opts options to pass through to save
    # @see save
    # @return [Hash]
    #   [Hash] :valid map doc index to valid document with content generated
    #   [Hash] :invalid map doc index to error
    # @todo this function is required in at least 2 places: kbDocs resource and kbBulkUpload tool;
    #   both should make use of it but only the latter does
    # @note docs will be modified in place with _id, as with #save
    def saveDocs(docs, author, opts={})
      retVal = { :valid => {}, :invalid => {} }
      save = ((opts.key?(:save) and (opts[:save] == false)) ? false : true)
      opts[:save] = false # overwrite because main commit will be done through bulkUpsert
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "docs:\n\n#{docs.inspect}")
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "docs.first:\n\n#{docs.first.inspect}")
      # docs must share same, existing rootProp
      # @todo if first document has bad root property name, no insert will be performed
      rootProp = BRL::Genboree::KB::KbDoc.new(docs.first).getRootProp()
      if(rootProp.nil?)
        raise KbError.new("ERROR: Could not get the root property for document index 0")
      end

      # map doc id to its document for bulkUpsert
      id2Doc = BSON::OrderedHash.new()
      validId2Index = {}
      docs.each_index { |ii|
        doc = docs[ii]
        begin
          doc = BRL::Genboree::KB::KbDoc.new(doc)

          # docs must share the same rootProp
          docRootProp = doc.getRootProp()
          if(rootProp != docRootProp)
            raise KbError.new("ERROR: document index at #{ii} with root property #{docRootProp} does not match previous documents' root property #{rootProp}")
          end
          docStatus = save(doc, author, opts)
          id = doc.getRootPropVal() # raise error if not property oriented
          if(id2Doc.key?(id))
            jj = validId2Index[id]
            raise KbError.new("ERROR: document at index #{ii} shares an identifier property value of #{id} with document at index #{jj}")
          end
          if(docStatus.is_a?(BSON::ObjectId))
            id2Doc[id] = doc
            validId2Index[id] = ii
            retVal[:valid][ii] = doc
          else
            retVal[:invalid][ii] = docStatus
          end
        rescue => err
          retVal[:invalid][ii] = err
        end
      }

      if(save)
        # perform bulk upsert
        upsertStatus = bulkUpsert(rootProp, id2Doc, author)
        if(upsertStatus == :OK or upsertStatus.is_a?(Array))
          # update valid documents with their inserted id
          # @todo retVal[:valid] is not a pointer to id2Doc?
          id2Doc.each_key { |id|
            ii = validId2Index[id]
            retVal[:valid][ii] = id2Doc[id]
          }
        else
          if(upsertStatus.is_a?(Array))
            # move any documents that passed validation but not upsertion to the invalid section
            # @todo instead of KbError some Mongo error class?
            upsertStatus.each { |errHash|
              id = id2Doc.keys()[errHash["index"]]
              ii = validId2Index[id]
              doc = retVal[:valid].delete(ii)
              # begin/rescue necessary to set err.backtrace
              begin
                raise KbError.new("#{errHash["code"]}: #{errHash["errmsg"]}")
              rescue => err
                retVal[:invalid][ii] = err
              end
            }
          elsif(upsertStatus.is_a?(Exception))
            raise upsertStatus
          else
            raise KbError.new("Unrecognized return value of bulkUpsert! Has interface changed?")
          end
        end
      end

      return retVal
    end

    def getByIdentifier(docName, opts={ :doOutCast => false, :castToStrOK => false})
      idPropName = getIdentifierName()
      # Use docFromCollectionByFieldAndValue to get the doc
      doc = docFromCollectionByFieldAndValue(docName, "#{idPropName}.value")
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "doc not nil or false? #{doc ? true : "FALSE!!"} ; opts =\n\n#{opts.inspect}\n\n")
      if(doc)
        doc = transformIntoModelOrder(doc, opts)
      end
      return doc
    end


    def getIdentifierName()
      # Ask modelsHelper for the name of the identifier (root) property for this collection
      modelsHelper = getModelsHelper()
      idPropName = modelsHelper.idPropNameForCollection(@coll.name)
      return idPropName
    end

    # Get a modelsHelper() to help answer questions for this collection's (or any collection's) model.
    # @return [BRL::Genboree::KB::Helpers::ModelsHelper, nil] A {ModelsHelper} object; most methods will need
    #   to be provided @@coll@ in order to answer questions about this user collection's model.
    def getModelsHelper()
      retVal = nil
      if(@kbDatabase)
        retVal = @kbDatabase.modelsHelper()
      end
      return retVal
    end

    # Get a model {KbDoc} for the collection this {DataCollectionHelper} is helping with.
    #   Will return one cached as part of object state--perhaps supplied by code calling/using this
    #   helper object or by code here during previous calls--or get & save one.
    # @param [Boolean] forceRefresh Indicates whether we can use the model cached by any @Helper@ objects
    #   in order to save much time. Generally leave this as false unless you have good reason.
    # @return [KbDoc] The model {KbDoc}. Not the raw model data structure but the doc that wraps & stores it.
    def modelKbDoc(forceRefresh=false)
      modelsHelper = getModelsHelper()
      # Have we got an appropraite model KbDoc available already?
      if(@modelKbDoc.is_a?(BRL::Genboree::KB::KbDoc))
        # Maybe. Double check it has what we expect.
        modelObj = @modelKbDoc.getPropVal("name.model")
        # If forceRefesh OR @modelKbDoc doesn't look right, regnerate
        unless(forceRefresh or (modelObj and !modelObj.empty?) )
          # Nope, not as expected. Get real model doc and keep that; will use cached version unless we're refreshing things
          @modelKbDoc = modelsHelper.modelForCollection(@coll.name, forceRefresh)
        end
      else
        # No we don't. Get one and keep it around. Get real model doc and keep that; will use cached version unless we're refreshing things
        @modelKbDoc = modelsHelper.modelForCollection(@coll.name, forceRefresh)
      end
      return @modelKbDoc
    end

    # Gets a {ModelValidator} object, generally/usefully one that has actually been RUN on
    #   this collection's model. Will return one cached as part of object state--ideally calling/using
    #   code has provided such a {ModelValidator} to this object via its {#modelValidator} accessor.
    #   But if not, one will be made, run, and saved now.
    # @param [Boolean] validateUponCreate Indicating whether or not the validatior should be run on the model for
    #   the collection or not IF a {ModelValidator} must be created on the fly. There's not much reason to set this to
    #   @false@ as that's the same as calling {ModelValidator#new} yourself.
    # @param [Boolean] forceRefresh Indicates whether we can use the model, model {KbDoc}, and validator cached by
    #   this object (or relevant @Helper@ objects) in order to save much time. Generally leave this as false unless
    #   you have good reason.
    # @return [ModelValidator] The {ModelValidator} with info it noticed about the model during validation.
    def modelValidator(validateUponCreate=true, forceRefresh=false)
      # Have we got an appropriate model validator that has been run on the appropriate model?
      # Or are we forced to recreate the validator (bah, wasteful).
      if(forceRefresh or !@modelValidator.is_a?(BRL::Genboree::KB::Validators::ModelValidator))
        # No, we don't. Make, run [below], and save one ourselves.
        @modelValidator = BRL::Genboree::KB::Validators::ModelValidator.new()
      end

      # Has the validator been run succuessfully on the relevant model?
      if( validateUponCreate and
          (@modelValidator.validationMessages.nil? or @modelValidator.validationMessages.empty?) and
          (@modelValidator.validationErrors.nil? or @modelValidator.validationErrors.empty?)
        )
        # Either hasn't been run or not successfully.
        # Get the actual model doc to run validator on. Will use cached or retrieve as needed.
        modelDoc = modelKbDoc(forceRefresh)
        # Run it
        @modelValidator.validateModel(modelDoc)
      end

      return @modelValidator
    end

    def transformIntoModelOrder(doc, opts={ :doOutCast => false, :castToStrOK => false })
      ordHash = BSON::OrderedHash.new()
      ordHash['_id'] = doc['_id'] if(doc.key?('_id'))
      modelsHelper = @kbDatabase.modelsHelper()
      modelDoc = modelsHelper.modelForCollection(@coll.name)
      if(modelDoc and !modelDoc.empty?)
        model = modelDoc.getPropVal('name.model')
        addPropsToOrderedHash(ordHash, doc, model, opts)
      end
      return ordHash
    end

    def addPropsToOrderedHash(ordHash, doc, model, opts={ :doOutCast => false, :castToStrOK => false })
      
      propName = model['name']
      if(doc.key?(propName))
        ordHash[propName] = BSON::OrderedHash.new()
        if(doc[propName].key?('value'))
          # set the value for prop in ordered version
          ordHash[propName]['value'] = doc[propName]['value']
          # outgoing casting?
          if(opts[:doOutCast])
            domain = model['domain']
            mv = modelValidator(false, false)
            domainRec = mv.getDomainRec(domain)
            if(domainRec and domainRec[:type] == 'date')
              outgoingCastProc = domainRec[:outCast]
              if(outgoingCastProc)
                ordHash[propName]['value'] = outgoingCastProc.call(ordHash[propName]['value'], opts[:castToStrOK])
              end
            elsif(domainRec and domainRec[:type] == 'time')
              outgoingCastProc = domainRec[:outCast]
              if(outgoingCastProc)
                ordHash[propName]['value'] = outgoingCastProc.call(ordHash[propName]['value'], opts[:castToStrOK])
              end
            elsif(domainRec and domainRec[:type] == 'measurement')
              parseDomainProc = domainRec[:parseDomain]
              parsedDomain = parseDomainProc.call(domain) rescue nil
              if(parsedDomain)
                outgoingCastProc = domainRec[:outCast]
                if(outgoingCastProc)
                  ordHash[propName]['value'] = outgoingCastProc.call(ordHash[propName]['value'], opts[:castToStrOK], parsedDomain)
                end
              end
            end
          end
        end
        if(model.key?('properties'))
          if(doc[propName].key?('properties'))
            ordHash[propName]['properties'] = BSON::OrderedHash.new()
            docProps = doc[propName]['properties']
            if(!docProps.empty?)
              modelProps = model['properties']
              modelProps.each {|propDef|
                addPropsToOrderedHash(ordHash[propName]['properties'], docProps, propDef, opts)
              }
            end
          end
        elsif(model.key?('items'))
          if(doc[propName].key?('items'))
            ordHash[propName]['items'] = []
            docItems = doc[propName]['items']
            if(!docItems.empty?)
              propDef = model['items'][0] # Item list must be singly rooted
              idx = 0
              docItems.each {|item|
                ordHash[propName]['items'].push(BSON::OrderedHash.new())
                addPropsToOrderedHash(ordHash[propName]['items'][idx], item, propDef, opts)
                idx += 1
              }
            end
          end
        end
      end
    end

    # @todo Implement this once VID is automatically added
    def getByVID(vid)
      # Parse vid
      # Use getByIdentifier on the doc name portion
    end

    # @todo Create new initial doc from the *model*, which will include the
    #   root identifier property set to docName and which will have any @required@
    #   fields filled in with default values.
    def docTemplate(docName, *params)
      raise ">>>> NOT IMPLEMENTED <<<< - making empty docs is not yet in place"
    end

    # Fully drop the whole collection. Will lose all data, all history, everything.
    # @param [String] author The Genboree user name who is deleting the collection
    #   and kbModel doc and kbColl.metadata doc. May want to consider some way to keep around version/revision
    #   collections to allso a "restore" (probably need the kbColl.metadata doc  too...would need to tag it as
    #   "deletect" so it doesn't come back in various lists [like mdb.collections or {kb}/colls API call])
    # @return [Boolean] Whether it succeeded or not ; generally errors will result in an Exception being raised. Currently the
    #   only time false is returned is when the collection doesn't appear to exist.
    # @raise [RuntimeExpeption] When an unexpected error happns during some phase of the deletion, usually after SOME
    #   tasks have succeed. Very bad, since likely have corrupted (partially deleting) KB w.r.t. this collection.
    def dropCollection(author, opts={ :fullScrub => true })
      $stderr.debugPuts(__FILE__, __method__, 'DROP COLL STATUS', "Begin drop of #{@coll.name.inspect} collection...")
      collName = @coll.name

      # Collection metadata helper
      collMetadataHelper = @kbDatabase.collMetadataHelper()
      # Get coll metadata document
      collMetadataDoc = collMetadataHelper.metadataForCollection(collName, true)
      if(collMetadataDoc)
        $stderr.debugPuts(__FILE__, __method__, 'DROP COLL STATUS', "Have coll metadata.")
        # Due to a long-standing collMetadata bug, 'name.internal' doesn't have a value object, just true|false
        # - Now fixed but must check both for backwards compatibility
        if( collMetadataDoc.getPropVal('name.internal') or (collMetadataDoc.getPropProperties('name')['internal'] == true) )
          raise "ERROR: You cannot delete internal collections like #{collName.inspect} !"
        end

        # Version helper
        versionsHelper = @kbDatabase.versionsHelper(collName)
        raise "ERROR: Could not get versionsHelper for apparently valid data collection #{collName.inspect}." unless(versionsHelper)
        # Revisions helper
        revisionsHelper = @kbDatabase.revisionsHelper(collName)
        raise "ERROR: Could not get revisionsHelper for apparently valid data collection #{collName.inspect}." unless(revisionsHelper)
        # Model helper
        modelsHelper = @kbDatabase.modelsHelper()
        raise "ERROR: Could not get modelsHelper." unless(modelsHelper)

        $stderr.debugPuts(__FILE__, __method__, 'DROP COLL STATUS', "Have versionsHelper, revisionsHelper, modelsHelper")

        # Remove model doc
        result = modelsHelper.deleteForCollection(collName, author)
        $stderr.debugPuts(__FILE__, __method__, 'DROP COLL STATUS', "Removing the model gave: #{result.inspect}")

        # Remove versions collection
        result = versionsHelper.dropCollection()
        $stderr.debugPuts(__FILE__, __method__, 'DROP COLL STATUS', "Dropping the versions collection gave: #{result.inspect}")
        # Remove revisions collection
        revisionsHelper.dropCollection()
        $stderr.debugPuts(__FILE__, __method__, 'DROP COLL STATUS', "Dropping the revisions collection gave: #{result.inspect}")
        # Remove collection metadata doc
        result = collMetadataHelper.deleteForCollection(collName, author)
        $stderr.debugPuts(__FILE__, __method__, 'DROP COLL STATUS', "Removing the collection metadata doc gave: #{result.inspect}")

        # Drop self
        result = @coll.drop()
        $stderr.debugPuts(__FILE__, __method__, 'DROP COLL STATUS', "Dropping self collection (#{@coll.name.inspect}) gave: #{result.inspect}")
        retVal = true
      else
        $stderr.debugPuts(__FILE__, __method__, 'ERROR', "No collection metadata for data collection named #{collName.inspect}. Is this a real collection or a mistake?")
        retVal = false
      end

      $stderr.debugPuts(__FILE__, __method__, 'DROP COLL STATUS', "Done drop of #{@coll.name.inspect} collection ; retVal will be #{retVal.inspect}")
      return retVal
    end

    # Rename a user data collection. Does it properly by not only renaming the collection, but also the
    #   versions/revisions collections, the kbModels record, the kbModels history records, and the kbColl.metadata record.
    # @param [String] newCollName The new name for the collection.
    # @param [String] author The Genboree user name who is renaming the collection
    # @return [Boolean] Whether it succeeded or not ; generally errors will result in an Exception being raised. Currently the
    #   only time false is returned is when the collection doesn't appear to exist.
    # @raise [RuntimeExpeption] When an unexpected error happns during some phase of the renaming, usually after SOME
    #   tasks have succeed. Very bad, since likely have corrupted (partially renamed) KB w.r.t. this collection.
    def renameCollection( newCollName, author, opts={} )
      $stderr.debugPuts(__FILE__, __method__, 'RENAME COLL STATUS', "Begin rename of #{@coll.name.inspect} collection...")
      if(newCollName and newCollName =~ /\S/)
        raise "ERROR: New collectiion name #{newCollName.inspect }is same as old one #{@coll.name.inspect}. Appears to be an error. Nothing to do." if( newCollName == @coll.name )
        raise "ERROR: New collection name #{newCollName.inspect} TOO LONG. No more than 22 chars." unless(newCollName.size <= 22)
        collName = @coll.name.dup
        # Collection metadata helper
        collMetadataHelper = @kbDatabase.collMetadataHelper()
        # Get current coll metadata document
        collMetadataDoc = collMetadataHelper.metadataForCollection(collName, true)
        if(collMetadataDoc)
          $stderr.debugPuts(__FILE__, __method__, 'RENAME COLL STATUS', "Have coll metadata.")

          # Due to a long-standing collMetadata bug, 'name.internal' doesn't have a value object, just true|false
          # - Now fixed but must check both for backwards compatibility
          if( collMetadataDoc.getPropVal('name.internal') or (collMetadataDoc.getPropProperties('name')['internal'] == true) )
            raise "ERROR: You cannot rename internal collections like #{collName.inspect} !"
          end

          # Version helper
          versionsHelper = @kbDatabase.versionsHelper(collName)
          raise "ERROR: Could not get versionsHelper for apparently valid data collection #{collName.inspect}." unless(versionsHelper)
          # Revisions helper
          revisionsHelper = @kbDatabase.revisionsHelper(collName)
          raise "ERROR: Could not get revisionsHelper for apparently valid data collection #{collName.inspect}." unless(revisionsHelper)
          # Model helper
          modelsHelper = @kbDatabase.modelsHelper()
          raise "ERROR: Could not get modelsHelper." unless(modelsHelper)

          $stderr.debugPuts(__FILE__, __method__, 'RENAME COLL STATUS', "Have versionsHelper, revisionsHelper, modelsHelper")

          # Rename actual collections
          # - Do this up front. Will raise Mongo::InvalidNSName for use if new collection name is bad, halting any furtehr ops.
          result = @coll.rename( newCollName )
          $stderr.debugPuts(__FILE__, __method__, 'RENAME COLL STATUS', "Renaming collection gave: #{result.inspect}")
          result = versionsHelper.coll.rename( versionsHelper.class.historyCollName( newCollName ) )
          $stderr.debugPuts(__FILE__, __method__, 'RENAME COLL STATUS', "Renaming version collection gave: #{result.inspect}")
          result = revisionsHelper.coll.rename( revisionsHelper.class.historyCollName( newCollName ) )
          $stderr.debugPuts(__FILE__, __method__, 'RENAME COLL STATUS', "Renaming revision collection gave: #{result.inspect}")

          # Update model doc for current model:
          # - name.value => new coll name
          result = modelsHelper.coll.update(
            # selector
            { 'name.value' => collName },
            # document edits
            {
              '$set' => { 'name.value' => newCollName }
            },
            # options
            { :multi => false, :upsert => false }
          )
          $stderr.debugPuts(__FILE__, __method__, 'RENAME COLL STATUS', "Updating collection name in relevant model doc gave: #{result.inspect}")

          # Update model revisions and versions docs to they indicate the new colelction
          # - versionNum.properties.content.value.name.value => new coll name
          modelVersionsHelper = @kbDatabase.versionsHelper( modelsHelper.coll.name )
          result = modelVersionsHelper.coll.update(
            # selector
            { 'versionNum.properties.content.value.name.value' => collName },
            # document edits
            {
              '$set' => { 'versionNum.properties.content.value.name.value' => newCollName }
            },
            # options
            { :multi => true, :upsert => false }
          )
          $stderr.debugPuts(__FILE__, __method__, 'RENAME COLL STATUS', "Updating collection name in relevant model version docs gave: #{result.inspect}")
          # - revisionNum.properties.content.value.name.value => new coll name
          modelRevisionsHelper = @kbDatabase.revisionsHelper( modelsHelper.coll.name )
          result = modelRevisionsHelper.coll.update(
            # selector
            { 'revisionNum.properties.content.value.name.value' => collName },
            # document edits
            {
              '$set' => { 'revisionNum.properties.content.value.name.value' => newCollName }
            },
            # options
            { :multi => true, :upsert => false }
          )
          $stderr.debugPuts(__FILE__, __method__, 'RENAME COLL STATUS', "Updating collection name in relevant model revision docs gave: #{result.inspect}")

          # Update kbColl.metadata
          # - name.value => new coll name
          # - name.properties.revisions.value => new coll name.revisions
          # - name.properties.versions.value => new coll name.versions
          result = collMetadataHelper.coll.update(
            # selector
            { 'name.value' => collName },
            # document edits
            {
              '$set' => {
                'name.value' => newCollName,
                'name.properties.versions.value' => versionsHelper.class.historyCollName( newCollName ),
                'name.properties.revisions.value' => revisionsHelper.class.historyCollName( newCollName )
              }
            },
            { :multi => false, :upsert => false }
          )
          $stderr.debugPuts(__FILE__, __method__, 'RENAME COLL STATUS', "Updating collection name in relevant collection metadata gave: #{result.inspect}")

          # Update renamed coll.versions and coll.revisions so old, out-of-date docRefs will point to correct document
          # - i.e. fix the namespace in the docRef value, which is a DBRef object ; namespace available via $ref "field"
          # . first, get a helper for the new collection (we are in a helper for the old collection)
          # Versions helper for renamed collection
          versionsHelper = @kbDatabase.versionsHelper( newCollName )
          raise "ERROR: could not get a versions helper for the renamed collection even after renamed from #{collName.inspect} to #{newCollName.inspect} supposedly completed!" unless(versionsHelper)
          result = versionsHelper.coll.update(
            # selector (all old version docs)
            { },
            # doc edits
            {
              '$set' => { 'versionNum.properties.docRef.value.$ref' => newCollName }
            },
            # options
            { :multi => true, :upsert => false}
          )
          $stderr.debugPuts(__FILE__, __method__, 'RENAME COLL STATUS', "Updating ALL existing version docs for the collection to change DBRef pointers gave: #{result.inspect}")
          # Revisions helper for renamed collection
          revisionsHelper = @kbDatabase.revisionsHelper( newCollName )
          raise "ERROR: could not get a versions helper for the renamed collection even after renamed from #{collName.inspect} to #{newCollName.inspect} supposedly completed!" unless(revisionsHelper)
          result = revisionsHelper.coll.update(
            # selector (all old revison docs)
            { },
            # doc edits
            {
              '$set' => { 'revisionNum.properties.docRef.value.$ref' => newCollName }
            },
            # options
            { :multi => true, :upsert => false}
          )
          $stderr.debugPuts(__FILE__, __method__, 'RENAME COLL STATUS', "Updating ALL existing revision docs for the collection to change DBRef pointers gave: #{result.inspect}")

          retVal = true
        else
          $stderr.debugPuts(__FILE__, __method__, 'ERROR', "No collection metadata for data collection named #{collName.inspect}. Is this a real collection or a mistake?")
          retVal = false
        end

      else
        raise "ERROR: The new name #{newCollName.inspect} is not a valid collection name."
      end

      $stderr.debugPuts(__FILE__, __method__, 'RENAME COLL STATUS', "Done rename of #{collName.inspect} collection to #{newCollName.inspect} ; retVal will be #{retVal.inspect}")
      return retVal
    end

    # Retrieve the set of distinct value and their doc counts for a particular prop path.
    # @param [String] propPath The property path (ideally a model path) for which to find distinct values for.
    #   The property must be indexed for performance reasons. Also it's not very sensible on 'unique' properties
    #   since the number of results will == the number of docs and all the counts will be 1. However for now
    #   we allow it on 'unique' properties since maybe you're using it to get those unique values or something.
    # @param [Hash,nil] model OPTIONAL. The actual model Hash to use as a guide. Not needed generally since this
    #   DataCollectionHelper object is already tied to a Collection and will automatically get the model.
    # @return [Array< Hash<String,Object> >] Will return an Array of Hash objects which havetwo keys: @"count"@ and @"value"@ .
    #   Note that the distinct value provided at @"value"@ key MAY be an @Array@. If so, that's because the property is
    #   under an items list and the Array is all the distinct values under the items list for all docs.
    # @raise KbError::StandardError If propPath is not an indexed property or if it doesn't appear to be in the model.
    def distinctValsForProp(propPath, model=nil, aggOperation = :count)
      # Assess propPath suitability
      modelPath = KbDoc.docPath2ModelPath(propPath)
      # - get model
      modelsHelper = getModelsHelper()
      if(model)
        # make sure actual model and not collName, Collection, model wrapped doc
        model = modelsHelper.getModel(model)
      else # no model, get it
        model = modelsHelper.getModel(@coll)
      end

      # - get propDef for propPath
      propDef = modelsHelper.findPropDef(modelPath, model, { :nonRecursive => true })

      # - suitable?
      if(propDef)
        #if(propDef['unique']) # Is it non unique?
        #  raise KbError, "The property #{propPath.inspect} is flagged as having unique values. Asking for distinct values of a property whose value is 'unique' is not sensible...every doc will have a unique value."
        if( !propDef['index'] ) # Is it indexed?
          raise KbError, "The property #{propPath.inspect} is not indexed. For performance reasons, distinct value retrieval is only supported on indexed properties."
        end
      else
        raise KbError, "Can't find property definition for #{propPath.inspect} in the model"
      end

      return super(modelPath, model, aggOperation)
    end

    def deleteDoc(docId, author)
      docId = BSON::ObjectId.interpret(docId)
      retVal = @coll.remove( { "_id" => docId } )
      if(retVal.is_a?(Hash) and retVal["ok"] == 1.0)
        if(retVal['n'] == 1)
          versionsHelper = @kbDatabase.versionsHelper(@coll.name)
          revisionsHelper = @kbDatabase.revisionsHelper(@coll.name)
          versionsHelper.createDeletionHistory(@coll.name, docId, author)
          revisionsHelper.createDeletionHistory(@coll.name, docId, "/", author)
        else
          raise KbError, "ERROR: failed to remove document from its collection using internal doc id #{docId.inspect}. The delete operation was successful (no errors) but did not delete any documents. Either: the document has already been deleted [by some other simultaneous request] or the doc id is invalid:\n#{docId.inspect}"
        end
      else
        raise KbError, "ERROR: failed to remove document from its collection using doc id #{docId.inspect}. Error from MongoDB:\n#{retVal.is_a?(Hash) ? JSON.pretty_generate(retVal) : retVal.inspect}"
      end
      return retVal
    end

    # @todo Performance. Is there a way to safely/sensibly use batch deletion AND
    #   create the history docs? or is it too risky in face of failure in the
    #   middle of the batches? Is batch removal even necessary to speed up?
    #   See commented code for how to delete massive list of docIds via fixed
    #   batches.
    def deleteDocs(docIds, author)
      docIds = [ docIds ] unless(docIds.is_a?(Array))
      docIds = docIds.map { |did| BSON::ObjectId.interpret(did) }
      # Need to see speed of this approach when lots to delete. But for now,
      # call our deleteDoc() method which handles history update too.
      docId = nil
      begin
        docIds.each { |docId|
          result = deleteDoc(docId, author)
        }
        retVal = true
      rescue KbError => err
        raise KbError, "ERROR: Deleting a set of docIds failed at #{docId.inspect}. Docs up to this have been deleted, but stopped here. Error from the delete was:\n\n#{err.message}"
      end
      ## We don't know how many are acutally in docIds. Maybe too many?
      ## Go through in slices?
      #retVal = false
      #offset = 0
      #while(offset < docIds.size)
      #  batch = docIds.slice(offset, 10_000)
      #  retVal = @coll.remove( { "_id" => { "$in" => batch }} )
      #  if(retVal == true)
      #    offset += 10_000
      #  else # Something bad happened! Error details in retVal (a Hash from driver)
      #    break
      #  end
      #end
      return retVal
    end

    def hasUniqueValue?(docId, field, value)
      retVal = false
      # Get the unique document ID for this model
      idPropName    = getIdentifierName()
      modelsHelper  = @kbDatabase.modelsHelper()
      docIdDocPath  = modelsHelper.modelPath2DocPath(idPropName, @coll.name)
      fieldPath     = modelsHelper.modelPath2DocPath(field, @coll.name)
      if(field == idPropName)
        # The document identifier must be unique by definition, so we won't even ask.
        retVal = true
      else
        # Doc identifier by docId has a unique value for field if there are NO OTHER documens with that value for that field
        queryInfo =
        {
          docIdDocPath  => { "$ne" => docId },
          fieldPath     => value
        }
        # Restrict result set to docs with just the 2 relevant fields (might be ~faster)
        outputProps = [ docIdDocPath, fieldPath ]
        # Get cursor
        cursor = cursorByComplexQuery(queryInfo, outputProps)
        retVal = (cursor.count() <= 0)
      end
      return retVal
    end

    def valid?(doc, missingContentOk=false, restoreMongo_idKey=false, opts={ :castValues => false, :allowDupItems => false })
      # Should we cast/normalize values to the domain as we validate? Required for actual save to database!!
      castValues = opts[:castValues]
      docValidator = BRL::Genboree::KB::Validators::DocValidator.new(@kbDatabase, @coll.name)
      docValidator.missingContentOk = missingContentOk
      docValidator.castValues = castValues # could also pass into validateDoc() below ; this is cleaner
      docValidator.allowDupItems = !!opts[:allowDupItems]
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@coll.name: #{@coll.name.inspect} ; @dataCollName: #{docValidator.dataCollName.inspect}")
      valid = docValidator.validateDoc(doc, @coll.name, restoreMongo_idKey)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@model:\n\n#{JSON.pretty_generate(docValidator.model)}\n\n")
      if(valid == true)
        retVal = true
      elsif(valid == :CONTENT_NEEDED)
        @lastContentNeeded = docValidator.contentNeeded
        retVal = :CONTENT_NEEDED
      else
        @lastValidatorErrors = docValidator.validationErrors.dup
        retVal = false
      end
      return retVal
    end

    # @todo For all the property keys and the "value" field contentss, do a strip on any that are strings
    def cleanDoc(doc)
      # Remove _id also, if present.
      doc.delete('_id') rescue nil
      return doc
    end



    # @todo implement this (needs proper support in revisions)
    def updateByPath()
    end

    # ------------------------------------------------------------------
    # INVALID METHODS - inherited from parent class but do not apply to user data collections
    # ------------------------------------------------------------------

    # Does not apply to user data collections, only to core collections.
    # @param [String] collName The name of the collection of interest for which you want a document for.
    # @param [String] field The name of the field to use to find the appropriate document about the collection.
    # @param [Boolean] forceRefresh If @true@, then rather than getting the document about the collection of
    #   interest from cache (it was cached when previously asked for), get it fresh from the database.
    # @return [Hash, nil] the document for the collection of interest or @nil@ if no document concerning
    #   the collection of interest was found.
    # @raise [KbError] if called.
    def docForCollection(collName, field="name", forceRefresh=false)
      return KbError, "ERROR: User data collections do not contain docs pertaining to other collections. Should not be calling this."
    end

    # Does not apply to user data collections, only to core collections
    # @note There is NO model template for non-core, user data collections! The model will
    #   not be fixed at compile time but rather provided by user at run time
    # @param [nil, Object] params Provide any parameters as individual arguments. Generally none are
    #   needed, except for some sub-classes that override this method and need some info.
    # @return [Hash] A suitable model template for the collection this helper assists with.
    def self.getModelTemplate(*params)
      return KbError, "ERROR: Unlike core collections, user data collections do not have model templates. Models are provided by users."
    end
  end # class ModelsHelper
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers
