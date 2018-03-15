#!/bin/env ruby
require 'json'
require 'yaml'
require 'uri'
require 'cgi'
require 'memoist'
require 'brl/extensions/bson' # BEFORE require 'mongo' or require 'bson'!
require 'mongo'
require 'socket'
require 'brl/util/util'
require 'brl/noSQL/mongoDb/mongoDbConnection'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/validators/modelValidator'


module BRL ; module Genboree ; module KB ; module Helpers
  # @abstract An abstract parent class for specific helper sub-classes. Implements
  #   some core functionality, some constants, and some accessors all sub-classes
  #   will have (and may override).
  class AbstractHelper
    extend Memoist
    MEMOIZED_INSTANCE_METHODS = [
      :getIdentifierName,
      :getRootProp
    ]
    # @return [String] Abstract placeholder for a constant ALL sub-classes MUST provide.
    #   The name of the core GenboreeKB collection the helper assists with.
    KB_CORE_COLLECTION_NAME = nil
    # @return [Array<Hash>] Abstract placeholder for a constant ALL sub-classes MUST provide.
    #   An array of MongoDB index config hashes; each has has key @:spec@ and @:opts@
    KB_CORE_INDICES = nil
    # @return [Hash] Abstract placeholder for a constant ALL sub-classes MUST provide.
    #    A model document or model template which can be used to place an appropriate
    #    model document into the @kbModels@ collection when the database (or collection)
    #    is first created.
    KB_MODEL = nil
    # @return [Hash, nil] Abstract placeholder for a constant ALL sub-classes MAY provide.
    #   If appropriate, provides an initial document to insert into the core collection
    #   when it is FIRST created.
    KB_INIT_DOC = nil
    # @return [Fixnum] max size for batch queries
    MAX_BATCH = 1000
    # @return [String] the delimiter used by mongo for joining collection and index to form a namespace
    COLL_IDX_DELIM = ".$"
    # @return [String] the delimiter used by mongo for joining database and collection to form a namespace
    DB_COLL_DELIM = "."
    # @return [Fixnum] limit on {db.name}.{coll.name} (inclusive limit)
    MAX_COLL_NS_SIZE = 120
    # @return [Fixnum] limit on {db.name}.{coll.name}.${index name} (inclusive limit)
    MAX_IDX_NS_SIZE = 127
    # @return [Fixnum] even in the worst case, we can use this  # chars avail for index name
    MIN_IDX_SIZE = MAX_IDX_NS_SIZE - MAX_COLL_NS_SIZE - COLL_IDX_DELIM.size

    # @!attribute [r] kbDatabase
    #   @return [MongoKbDatabase] the KB database instance this helper is providing assistance for.
    attr_reader :kbDatabase
    # @!attribute [r] coll
    #   @return [Mongo::Collection] the KB collection this helper uses and is helping with.
    attr_reader :coll
    # @!attribute [r] docForCollectionCache
    #   @return [Hash{String=>Hash}] this instance's cache of documents reltated to other collections
    #     (possibly its own too) which it has been asked to retrieve using a particular field.
    attr_reader :docForCollectionCache
    # @!attribute [rw] queryBatchSize
    #   @return [Fixnum] the batch size to use during @find()@ type queries. Default is supposedly
    #     @100@ in the ruby driver and @0@ supposedly lets the database server decide. We set to
    #     @0@ by default, but this can changed for custom use. Generally little effect and 'tweaking'
    #     is useless.
    attr_accessor :queryBatchSize

    # Get the model doc template for the collection this helper assists with.
    # @todo change this from returning KB_MODEL constant
    #   in the respective sub-class, but rather have them loaded from
    #   some .yml files. Maybe cached like the SingletonJSONCache, etc.
    # @param [nil, Object] params Provide any parameters as individual arguments. Generally none are
    #   needed, except for some sub-classes that override this method and need some info.
    # @return [KbDoc] A suitable model template, as {KbDoc} wrapping a {Hash}, for the collection this helper assists with.
    def self.getModelTemplate(*params)
      return BRL::Genboree::KB::KbDoc.new(self::KB_MODEL)
    end

    # Create new instance of this helper.
    # @param [MongoKbDatabase] kbDatabase The KB database object this helper is assisting.
    # @param [String] collName The name of the document collection this helper uses.
    def initialize(kbDatabase, collName=self.class::KB_CORE_COLLECTION_NAME)
      @kbDatabase = kbDatabase
      if(collName.is_a?(Mongo::Collection))
        # Then we are probably in the middle of creating the collection and have been
        # provided the actual collection object to be used in this helper. This
        # is not the usual way this method is called (should be a collection name String).
        @coll = collName
      else
        @coll = nil
      end
      @docForCollectionCache = Hash.new { |hh, storageCollName| hh[storageCollName] = {} }
      @queryBatchSize = 0
    end

    # In our version of mongo, when your :fields=>[] or :fields=>{} output projection info contains BOTH
    #   general/parent fields AND specific embedded/subordinate fields, the specific fields MASK/HIDE the general
    #   ones, so you don't get what you expect. i.e. :fields=>['versionNum', 'versionNum.properties.timestamp']
    #   only returns a doc with the 'versionNum.properties.timestamp' subdoc due to this masking bug.
    # A solution is to remove fields for which there is already a more general/parent field being asked for, since
    #   that general/parent field will include the specific one as well.
    # @note This is an O(N^2) processes that uses string matching, but it should be ok when the NUMBER OF FIELDS INVOLVED
    #   IS SMALL.
    # @note At first blush, this bug appears to be fixed in Mongo 3.x
    # @note Since specifying a :fields=>[] or :fields=>{} means "only give me a doc with the special _id prop", this
    #   method also does you the favor of returning nil if your fields argument is empty (i.e. you forgot to deal with
    #   this nuance).
    # @params [Array, Hash] fields The Array of output field Strings or Hash of field String=>Numeric.
    # @return [Array, Hash, nil]
    def self.reduceProjectionFields( fields )
      if( ( fields.is_a?(Array) or fields.is_a?(Hash) ) and !fields.empty? )
        if( fields.is_a?(Array) )
          newFields = []
          fields = fields.sort
          fields.each { |field|
            field = field.to_s
            unless( newFields.any? { |xx| field.start_with?(xx) } )
              newFields << field
            end
          }
        else # Hash
          newFields = {}
          newFieldsNames = []
          fields.keys.sort.each { |field|
            unless( newFieldsNames.any? { |xx| field.start_with?(xx) } )
              newFields[field] = fields[field]
              newFieldsNames << field
            end
          }
        end
      else
        newFields = nil
      end
      return newFields
    end

    # @see AbstractHelper.reduceProjectionFields
    def reduceProjectionFields( fields )
      return self.class.reduceProjectionFields( fields )
    end

    # Method to help aid in the clean up, garbage collection, and resource release.
    # Be a dear, call {#clear}
    def clear()
      @docForCollectionCache.clear() rescue nil
      @docForCollectionCache = nil
      @kbDatabase = @coll = nil
    end

    # Name of KB prop that acts as the single-rooted unique doc identifier.
    def getIdentifierName( collName=@coll.name )
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "here...")
      modelsHelper = getModelsHelper()
      if( collName == @coll.name )
        if( !@idPropName.is_a?(String) or @idPropName.empty? )
        # Ask modelsHelper for the name of the identifier (root) property for this object's collection
        #   (kept in @idPropName but won't be valid for other collections we might need the name from [for example
        #   the root prop of the DATA collection which working in a version/revision helper class]).
        @idPropName = modelsHelper.getRootProp( collName )
        end
        idPropName = @idPropName
      else # some other collection than ours ; must be a real collection that has actual model doc, not .versions or .revisions
        idPropName = modelsHelper.getRootProp( collName )
      end
      return idPropName
    end
    alias_method( :getRootProp, :getIdentifierName )

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

    def docByRef( dbRef )
      return @kbDatabase.docByRef( dbRef )
    end

    # Matches the current revision of a document/subdocument with the working revision provided in the request
    # @param [Integer] workingRevision
    # @overload currentRevision(docId)
    #   Use a reference to the document to get its current revisioning record. Preferred.
    #   @param [BSON::DBRef] docId The reference pointing to the data document.
    # @overload currentRevision(docId, docCollName)
    #   Use an object that can be interpretted as a {BSON::ObjectId} by {BSON::ObjectId.interpret}
    #     as the ObjectId within the collection named in @docCollName@.
    #   @param (see BSON::ObjectId.interpret)
    #   @param [String] docCollName The name of the data collection.
    # @param [String] propPath
    # @return [Boolean] TRUE if working revision matches the current revision. FALSE otherwise
    def matchWorkingRevisionWithCurrentRevision(workingRevision, docId, docCollName, propPath=nil)
      retVal = false
      revNum = nil
      if(docId.is_a?(BSON::DBRef) and docCollName.nil?)
        docRef = docId
        docCollName = docRef.namespace
      elsif(docId and docCollName) # need to construct a docRef
        docId = BSON::ObjectId.interpret(docId)
        docRef = BSON::DBRef.new(docCollName, docId)
      else
        raise ArgumentError, "ERROR: method called incorrectly. Either provide JUST a BSON::DBRef or BOTH a docId type object + the appropriate collection name."
      end
      # Add revision if collection maintains it's history
      unless(MongoKbDatabase::KB_HISTORYLESS_CORE_COLLECTIONS.include?(@coll.name))
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "collection has history")
        revisionsHelper = @kbDatabase.revisionsHelper(@coll.name)
        revNum = revisionsHelper.getRevisionNumForDocOrSubDoc(docRef, propPath)
        if(workingRevision == revNum)
          retVal = true
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "collection does not have history")
        raise "INCORRECT_USE: Cannot use this method on documents which reside in collections that do not maintain history (version/revision)."
      end
      return retVal
    end
    
    # Returns metadata hash to be added to the API response object.
    # @overload getMetadata(docId)
    #   Use a reference to the document to get its current revisioning record. Preferred.
    #   @param [BSON::DBRef, Array] docIds or docId The reference(s) pointing to the data document. 
    # @overload getMetadata(docId, docCollName)
    #   Use an object that can be interpretted as a {BSON::ObjectId} by {BSON::ObjectId.interpret}
    #     as the ObjectId within the collection named in @docCollName@.
    #   @param (see BSON::ObjectId.interpret)
    #   @param [String] docCollName The name of the data collection.
    # @param [String] propPath
    # @return [Hash] metadata
    def getMetadata(docIds, docCollName=nil, propPath=nil)
      metadata = {}
      docRefs = []
      if(!docIds.is_a?(Array))
        docId = docIds
        if(docId.is_a?(BSON::DBRef) and docCollName.nil?)
          docRef = docId
          docCollName = docRef.namespace
        elsif(docId and docCollName) # need to construct a docRef
          docId = BSON::ObjectId.interpret(docId)
          docRef = BSON::DBRef.new(docCollName, docId)
        else
          raise ArgumentError, "ERROR: method called incorrectly. Either provide JUST a BSON::DBRef or BOTH a docId type object + the appropriate collection name."
        end
        docRefs << docRef
      else
        docIds.each { |did|
          if(docCollName)
            docRefs << BSON::DBRef.new(docCollName, did)
          else
            docRefs << docId
          end
        }
      end
      # Add revision if collection maintains it's history
      # For a single document, add the current revision. For a list of docs, add the maximum revision.
      # Currently, propPath is only support for single doc.
      unless(MongoKbDatabase::KB_HISTORYLESS_CORE_COLLECTIONS.include?(@coll.name))
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "collection has history")
        revisionsHelper = @kbDatabase.revisionsHelper(@coll.name)
        if(docRefs.size == 1)
          metadata["revision"] = revisionsHelper.getRevisionNumForDocOrSubDoc(docRefs[0], propPath=nil)
        else
          metadata["revision"] = revisionsHelper.getMaxRevisionForDocs(docRefs)
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "collection does not have history")
      end
      return metadata
    end
    
    
    # Save a doc to the collection this helper instance uses & assists with. Will also save
    #   history records as well, unless {#coll} for this helper is one of the core collections
    #   which doesn't track history (like @kbColl.metadata@ and @kbGlobals@).
    # @note If the @doc@ contains @_id@ field, then the document is updated. Else a new one is created.
    # @see Mongo::Collection#save
    # @param [Hash, KbDoc] doc The document to save.
    # @param [String] author The Genboree user name who is saving the document.
    # @param [Hash] opts Options hash containing directives for special operations.
    # @return [BSON::ObjectId] The ObjectId for the saved document.
    def save(doc, author, opts={})
      # Save the actual document
      docObjId = @coll.save( doc.to_serializable() )
      # Arrange for any appropriate history record handling
      unless(MongoKbDatabase::KB_HISTORYLESS_CORE_COLLECTIONS.include?(@coll.name))
        # Retrieve the actual saved doc
        savedDoc = @kbDatabase.docByRef(docObjId, @coll.name)
        versionsHelper = @kbDatabase.versionsHelper(@coll.name)
        revisionsHelper = @kbDatabase.revisionsHelper(@coll.name)
        versionObjId  = versionsHelper.createNewHistory(@coll.name, savedDoc, author)
        revisionObjId = revisionsHelper.createNewHistory(@coll.name, docObjId, "/", savedDoc, author)
      end
      return docObjId
    end

    # Essentially used to replace the subDocPath for paths ending with [] to have {"identifier"} when saving sub documents
    # This is important since indices for item lists cannot be used reliably for lookups as they can change.
    # @param [Hash] opts
    # @return [String] The updated/correct subDocPath which will be saved in mongoDB
    def setSubdocPath(opts)
      retVal = nil
      if(opts.key?(:subDocPath))
        subDocPath = opts[:subDocPath]
        if(subDocPath =~ /\]$/)
          rootProp = nil
          identifierVal = nil
          if(opts.key?(:newValue))
            valueDoc = opts[:newValue]
            rootProp = valueDoc.keys[0]
            identifierVal = valueDoc[rootProp]['value']
          else
            rootProp = opts[:itemIdentifierProp]
            identifierVal = opts[:itemIdentifierPropValue]
          end
          subDocPath.gsub!(/\[\S+\]$/, "[].#{rootProp}.{\"#{identifierVal}\"}")
          # Change the value doc object as well
          opts[:newValue] = valueDoc[rootProp] if(opts.key?(:newValue))
        end
        retVal = "/#{subDocPath}"
      else
        retVal = "/"
      end
      return retVal 
    end

    # Drop this collection
    def dropCollection()
      $stderr.debugPuts(__FILE__, __method__, 'STATUS', "About to mongo-drop collection: #{@coll.name.inspect}")
      result = @coll.drop()
    end

    def distinctValsForProp(propPath, model, aggOperation = :count)
      # Need as a mongo path
      modelsHelper = @kbDatabase.modelsHelper()
      modelPath = KbDoc.docPath2ModelPath(propPath)
      mongoPath = modelsHelper.modelPath2MongoPath(modelPath, model)
      pipeline = [
        {
          '$group' =>
            {
              '_id' => "$#{mongoPath}"
            }
        }
      ]
      # Add in the agg operation.
      # - These are done straight forward and all same way
      if( [:avg, :sum, :max, :min].include?(aggOperation) )
        pipeline.first['$group'][aggOperation.to_s] = { "$#{aggOperation}" => "$#{mongoPath}" }
      else # assume aggOperation == :count
        # - count is done via sum of static value of 1 for each doc
        pipeline.first['$group']['count'] = { '$sum' => 1 }
      end

      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Agg Pipeline:\n\n#{JSON.pretty_generate(pipeline)}\n\n")
      resultSet = @coll.aggregate(pipeline)
      if(resultSet and !resultSet.empty?)
        resultSet.each { |result|
          result['value'] = result['_id']
          result.delete('_id')
        }
      end
      return resultSet
    end

    # Perform a bulk update/insert (upsert) on a collection. Also save history records as well.
    # @param [String] identProp The identifier property name
    # @param [BSON::OrderedHash] id2Doc { identPropValue => new_or_existing_doc } ;
    #   order of id2Doc.each_key matters for any error response
    # @return [:OK, Array, Exception] :OK if all upsert ok,
    #   Array of err.result['writeErrors'] if write error occurs which contains a Hash with keys
    #     "index" - associated with order of inputs (id2Doc.each_key)
    #     "code" - Mongo error code that can be looked up
    #     "errmsg" - error message,
    #   Exception if we could not get writeErrors (some other type of mongo error), which will have #message set
    # @note bulk.execute runs as "best effort" to upsert docs, but if any write error occurs, the function
    #   raises an error
    # @todo call doc.to_serializable
    # @todo there may be a bug in the 2.6 MongoDB Ruby driver, bulk upserts do not modify objects in place
    #   as noted in the MongoDB shell documentation http://docs.mongodb.org/manual/reference/method/Bulk.find.upsert/
    def bulkUpsert(identProp, id2Doc, author, opts={})
      $stderr.debugPuts(__FILE__, __method__, "TIME", "    START - bulk upsert of #{id2Doc ? id2Doc.size : -1} docs")
      status = :OK
      bulk = @coll.initialize_unordered_bulk_op.upsert
      bulkStatus = err = nil
      # id2Doc = forceWriteError(identProp, id2Doc)
      begin
        id2Doc.each_key { |identVal|
          doc = id2Doc[identVal]
          bulk.find( "#{identProp}.value" => identVal ).replace_one( doc.to_serializable() )
        }
        $stderr.debugPuts(__FILE__, __method__, "TIME", "    DONE - init bulk op and marked all docs needing REPLACEMENT (vs new doc, which is default)")
        bulkStatus = bulk.execute
        $stderr.debugPuts(__FILE__, __method__, "TIME", "    DONE - actual 'execute' method on the bulk operation object")
      rescue Exception::Mongo::OperationFailure => err
        # subclasses: BulkWriteError, ExectionTimeout, InvalidNonce, InvalidSignature, WriteConcernError
        # http://api.mongodb.org/ruby/current/Mongo/OperationFailure.html
        begin
          status = err.result['writeErrors']
        rescue => execHandlingErr
          $stderr.debugPuts(__FILE__, __method__, "MONGODB_ERROR", "Class: #{err.class} Message: #{err.message} ; trace:\n#{err.backtrace.join("\n")}\n")
          status = err
        end
      ensure
        begin
          # then we should add documents to the history collections
          unless(MongoKbDatabase::KB_HISTORYLESS_CORE_COLLECTIONS.include?(@coll.name))
            $stderr.debugPuts(__FILE__, __method__, "TIME", "    START - find failed docs upserts and create version/revision recs")
            errIds = []
            if(bulkStatus.nil?)
              # then an error occurred during bulk.execute , determine which documents, if any,
              # were successfully inserted so that we may make a version/revision for each of them
              if(err.is_a?(Exception::Mongo::BulkWriteError))
                keys = id2Doc.keys()
                errIndexes = err.result['writeErrors'].collect { |hh| hh['index'] }
                errKeys = errIndexes.map{ |ii| keys[ii] }
                errKeys.each { |key|
                  errIds.push(key)
                }
              # elsif(err.is_a?( ... ))
              else
                raise "Unhandled bulk operation error #{err.class}"
              end
            end
            $stderr.debugPuts(__FILE__, __method__, "TIME", "    DONE - found docs which had upsert errors")
            docIds = id2Doc.keys - errIds
            docRecs = docsFromCollectionByFieldAndValues(docIds, "#{identProp}.value")
            versionsHelper = @kbDatabase.versionsHelper(@coll.name)
            revisionsHelper = @kbDatabase.revisionsHelper(@coll.name)
            # Initialize bulk operators for both revisions and versions collections associated with the user collection we are working with.
            # -- First use the aggregation pipeline to get the current version and revision numbers for all the docs that were successfully inserted
            # -- Next, using the map (docRef -> current version number), build the list of docs (version/revision) that need to be inserted
            # -- This list will be inserted again as a bulk insert to minimize IO on the mongoDB side.
            $stderr.debugPuts(__FILE__, __method__, "TIME", "    START - Creating bulk insert command for version/revision docs.")
            versionBulkOperator = versionsHelper.coll.initialize_unordered_bulk_op
            revisionBulkOperator = revisionsHelper.coll.initialize_unordered_bulk_op
            docCollName = @coll.name
            docRefs = {}
            docRecs.each {|docRec|
              docRefs[BSON::DBRef.new(docCollName, docRec["_id"])] = docRec
            }
            # Build the map for docRefs -> current version/revision number
            docRefToCurrVerMap = versionsHelper.getDocRefsToCurrVersionMap(docRefs.keys, VersionsHelper.historyCollName(docCollName))
            docRefToCurrRevMap = revisionsHelper.getDocRefsToCurrRevisionMap(docRefs.keys, RevisionsHelper.historyCollName(docCollName))
            # Reserve the version/revision counters for this batch of docs
            batchSize = docRecs.size
            lastVerCount = versionsHelper.incVersionNumByN(batchSize)
            lastRevCount = revisionsHelper.incRevisionNumByN(batchSize)
            verStartCount = ( lastVerCount.to_i - batchSize ) + 1
            revStartCount = ( lastRevCount.to_i - batchSize ) + 1
            # Build the bulk insert command
            docRefs.each_key { |docRef|
              docRec = docRefs[docRef]
              mongoId = docRec['_id']
              versionDoc = versionsHelper.prepareDocForBulkOperation(docRef, docRec, author, docRefToCurrVerMap, { :count => verStartCount })
              revisionDoc = revisionsHelper.prepareDocForBulkOperation(docRef, docRec, author, docRefToCurrRevMap, { :count => revStartCount })
              versionBulkOperator.insert(versionDoc.to_serializable)
              revisionBulkOperator.insert(revisionDoc.to_serializable)
              id = docRec.getRootPropVal()
              docRec['_id'] = mongoId
              id2Doc[id] = docRec
              verStartCount += 1
              revStartCount += 1
            }
            # Execute the bulk insert
            $stderr.debugPuts(__FILE__, __method__, "TIME", "    DONE - created bulk insert command for version/revision docs.")
            versionBulkOperator.execute()
            revisionBulkOperator.execute()
            $stderr.debugPuts(__FILE__, __method__, "TIME", "    DONE - bulk insert of version/revision docs for #{docRecs.size.inspect} docs.")
          end
        rescue => err
          $stderr.debugPuts(__FILE__, __method__, "MONGODB_ERROR", "Could not create version or revision documents")
          $stderr.debugPuts(__FILE__, __method__, "MONGODB_ERROR", "Class: #{err.class} Message: #{err.message} ; trace:\n#{err.backtrace.join("\n")}\n")
        end
      end
      $stderr.debugPuts(__FILE__, __method__, "TIME", "    END - bulk upsert of #{id2Doc ? id2Doc.size : -1} docs")
      return status
    end

    # As long as docHash contains 2 existing documents we can force a write error to test the API
    #   by modifying two of the documents in docHash to refer to the same Mongo _id
    #   (causing a duplicate key error)
    # @see bulkUpsert
    def forceWriteError(identProp, docHash)
      docRecs = docsFromCollectionByFieldAndValues(docHash.collect{|kk, vv| kk}, "#{identProp}.value")
      if(docRecs.size >= 2)
        docRecs[1]['_id'] = docRecs[0]['_id']
        docHash[docRecs[0].getPropVal(identProp)] = docRecs[0]
        docHash[docRecs[1].getPropVal(identProp)] = docRecs[1]
      end
      return docHash
    end

    # Retrieve all docs in this Helper's collection.
    # @todo This should support incoming skip/limit to support pagination.
    # @note If there may be 1000's of documents (e.g. for user data collections and any
    #   history-related collections), then probably should ask for @:cursor@ rather than
    #   the default of @:docList@. That way you can iterate over the {Mongo::Cursor} without
    #   sucking all the docs into RAM. If you know there will only be a few docs (e.g. most
    #   NON-HISTORY internal collections) then the default of :docList is appropriate.
    # @note If you ask for @:cursor@ _you should CLOSE THE cursor when done_ (via {Mongo::Cursor#close})
    # @param [Symbol] provide Either @:docList@ if you want an {Array} of docs or @:cursor@ if you want a
    #   {Mongo::Cursor} (which you will close).
    # @return [Array<Hash>,Mongo::Cursor] either the set of docs (Hashes) or a cursor you can iterator over.
    # @raise [ArgumentError] if @provide@ is not one of the supported Symbols.
    def allDocs(provide=:docList, outputProps=nil, sortInfo=nil, extraOpts={})
      retVal = nil
      opts = buildFindOptions(outputProps, sortInfo, extraOpts)
      if(provide == :docList)
        retVal = []
        @coll.find( {}, opts ) { |cur|
          cur.each { |doc|
            retVal << BRL::Genboree::KB::KbDoc.new(doc)
          }
        }
      elsif(provide == :cursor)
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "opts: #{opts.inspect}")
        retVal = @coll.find( {}, opts )
      else
        raise ArgumentError, "ERROR: the provide parameter must be one of @:docList@ or @:cursor@, not #{provide.inspect}."
      end
      return retVal
    end

    # Get the BRL root property identifier for a set of documents (rather than the Mongo _id)
    # @param [Object] docs must be some iterator over a set of documents e.g.
    #   an array of documents, a Mongo::Cursor, etc.
    # @return [Array<Object>] list of root identifier property objects whose "type" matches
    #   that defined in the model for the collection that this helper assists with
    #   specifically it is a type that the ruby mongo driver can map from one of
    #   mongo's native types which vary according to KB_MODEL e.g. a field with
    #   domain "date" will be represented in ruby as a Time object
    def getDocIds(docs, limit=nil)
      rv = []
      limit = (limit.nil? ? 1.0/0.0 : limit.to_i)
      ii = 0
      docs.each{|doc|
        kbDoc = BRL::Genboree::KB::KbDoc.new(doc)
        rv << kbDoc.getPropVal(self.class::KB_MODEL["name"])
        ii += 1
        if(ii >= limit)
          break
        end
      }
      return rv
    end

    # Prepare a cursor over just the (nested) document IDs of the collection
    #   the helper assists with
    # @param [Hash] query an optional query configuration to limit the documents
    #   that the cursor sends
    # @return [Mongo::Cursor] an open cursor object ready to stream projected documents
    #   should be closed via rv.close when finished
    # @see getDocIds
    def prepDocIdCur(query={})
      rv = nil
      opts = {:fields => {"_id" => 0, "#{self.class::KB_MODEL["name"]}.value" => 1}}
      rv = @coll.find(query, opts)
    end

    # Get a subset of documents from this collection ordered by the index of the root
    #   identifier property
    # @param [Object] startAt an object that matches the domain for the root identifier
    #   property given in KB_MODEL (which is assumed to be indexed)
    # @param [Integer, NilClass] limit a limit to the number of documents retrieved or
    #   nil if no limit is desired
    def getDocSubset(startAt=nil, limit=nil)
      rv = []
      query = {}
      opts = {:fields => {"_id" => 0}} # exclude _id from results
      unless(startAt.nil?)
        query = {"#{self.class::KB_MODEL["name"]}.value" => { "$gte" => startAt } }
      end
      unless(limit.nil?)
        opts.merge!({:limit => limit.to_i})
      end
      rv = @coll.find(query, opts).collect
      return rv
    end

    # Create a {BSON::DBRef} object for a document in this helper's collection.
    # @param [Hash, KbDoc] doc A document from MongoDB (supposedly from this helper's collection!).
    #   Assumed to have a valid @_id@ field. Which it will, because it came from MongoDB right?
    # @option doc [BSON::ObjectId] "_id" The Mongo @_id@ for the document. Will be a {BSON::ObjectId}
    #   if actual doc inserted and returned by Mongo.
    # @return [BSON::DBRef] the reference to the document
    def docDbRef(doc)
      return BSON::DBRef.new(@coll.name, doc["_id"])
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
    # @param [Array<Hash>] indices The index configs to create.
    # @return [Hash<Symbol, Hash>] Categorized results of creating each index. Key @:idxConf@ has success index configs, @:failedIndices@
    #   has failed indices and further information in its @Hash@ value. Further information for failed indices: @:idxConf@ the index config
    #   that failed, @:result@ the result of calling @create_index()@, @:err@ any Exception that was raised (if any) during creation.
    def createIndices(indices=self.class::KB_CORE_INDICES)
      retVal = { :okIndices => [], :failedIndices => [] }
      indices = indices.deep_clone
      err = nil
      idxNsPrefix = [@kbDatabase.db.name, @coll.name].join(DB_COLL_DELIM)
      maxIdxNameSize = MAX_IDX_NS_SIZE - idxNsPrefix.size - COLL_IDX_DELIM.size
      indices.each { |index|
        # Need to make an index of safe length because mongo will create non-compliant index names _by default_ (!???)
        unless(index[:opts].key?(:name))
          idxName = nil
          if(index[:spec].is_a?(Array))
            # {1stPropPath}#{2ndPropPath}...
            idxName = "#{index[:spec].map{|xx| xx[0].makeSafeStr}.join("#")}"
          else
            # propPath}
            idxName = "#{index[:spec].makeSafeStr}"
          end
          if(idxName.length > maxIdxNameSize)
            idxName = idxName[0, maxIdxNameSize - MIN_IDX_SIZE] # "" in worst case
            idxName += "#{idxName.generateUniqueString.xorDigest(MIN_IDX_SIZE)}"
          end
          index[:opts][:name] = idxName
        end

        begin
          indexResult = @coll.create_index(index[:spec], index[:opts])
        rescue => err
          indexResult = false
        ensure
          if(indexResult)
            retVal[:okIndices] << { :idxConf => index }
          else
            retVal[:failedIndices] << { :helperClass => self.class, :collClass => @coll.class, :collName => (@coll.respond_to?(:name) ? @coll.name : "N/A - see :collClass)"), :idxConf => index, :result => indexResult, :err => err }
          end
        end
      }
      return retVal
    end

    # Drop indexes based on the fields they are indexed on
    # @param [Array<Array<String>>] idxKeysLists list of indexes to drop where an index is specified by
    #   an array of its indexed fields e.g. [["docRef.value", "versionNum.value"]] will drop all
    #   indices whose key fields are precisely "docRef.value" AND "versionNum.value" (there may be many
    #   based on the sort orders)
    # @return [Hash] partitioning of index dropping result into two lists keyed by:
    #   [Array] :okIndices subset of idxKeysLists that successfully had indices dropped
    #   [Array] :failedIndices mapping of item from idxKeysLists to error message indicating why
    #     the index could not be dropped
    def dropIndicesByKeys(idxKeysLists)
      retVal = { :okIndices => [], :failedIndices => [] }
      idxKeysToName = {}
      idxInfo = @coll.index_information
      idxInfo.each_key { |idxName|
        idxKeysToName[idxInfo[idxName]["key"].keys] = idxName # ordered because of BSON::OrderedHash
      }

      idxKeysLists.each { |idxKeys|
        idxName = idxKeysToName.delete(idxKeys)
        if(idxName.nil?)
          retVal[:failedIndices].push({idxKeys => "There is no index with these keys"})
        else
          begin
            idxResult = @coll.drop_index(idxName) # raises Mongo::MongoDBError
            retVal[:okIndices].push(idxKeys)
          rescue Mongo::MongoDBError => err
            retVal[:failedIndices].push({idxKeys => err.message})
          end
        end
      }
      return retVal
    end

    # Given a collection of interest, get the appropriate document from this helper's collection for it.
    #  e.g. Get the model doc for a collection of interest, or get the collection metadata doc for a
    #  collection of interest.
    # @param [String] collName The name of the collection of interest for which you want a document for.
    # @param [String] field The name of the field to use to find the appropriate document about the collection.
    # @param [Boolean] forceRefresh If @true@, then rather than getting the document about the collection of
    #   interest from cache (it was cached when previously asked for), get it fresh from the database.
    # @return [KbDoc, nil] the document for the collection of interest or @nil@ if no document concerning
    #   the collection of interest was found.
    # @raise [RuntimeError] if the @@coll@ property is @nil@. This is only OK if you're in the middle of creating
    #   a database and its collections; otherwise, it's the sign of a bug.
    def docForCollection(collName, field="name.value", forceRefresh=false)
      #$stderr.debugPuts(__FILE__, __method__, "DBEUG", "@coll.class: #{@coll.class} ; @coll.name: #{@coll.name.inspect rescue 'N/A'} collName: #{collName.inspect} ; field: #{field.inspect}\n         - @docForCollectionCache.class: #{@docForCollectionCache.class}\n         - @docForCollectionCache.keys:\n         #{@docForCollectionCache.keys.join("\n")}")
      if(@coll)
        if(forceRefresh or !@docForCollectionCache.key?(collName) or !@docForCollectionCache[collName].key?(field) or !@docForCollectionCache[collName][field])
          doc = docFromCollectionByFieldAndValue(collName, field, @coll)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "       >>> doc.class: #{doc.class}")
          @docForCollectionCache[collName][field] = doc
        else
          doc = @docForCollectionCache[collName][field]
        end
      else
        raise RuntimeError, "ERROR: this helper object was not created with a viable @coll property. Either the underlying collection doesn't exist yet and you're in the middle of creating the databsae or an unknown collection name was provided to the helper's constructor (oops)."
      end
      return doc
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
      raise NotImplementedError, "ERROR: this method should be implemented in #{self.class} to return a template or starter #{collName.inspect} doc which can be fleshed out--or in some cases used as-is."
    end

    # Create a {BSON::DBRef} object for a document in this helper's collection, from its unique KB doc identifier.
    #   DBRef objects are useful
    #   because some methods want them anyway (this is fastest way to get at matching version record, rather than
    #   digging into the versionNum.content.{something} value...which won't be indexed), but ALSO they have the _id
    #   field value in case you have methods that need that value for lookups (or if you want to do efficient
    #   lookups using _id). So getting one of these for a given doc is very very useful, permits very very efficient
    #   lookups, and should be very fast to get [because so useful]
    # @note This is specific to this helper's collection. If a data doc collection, it will be a document identifier value
    #   (a.k.a. the doc name) whereas if it's a version/revision helper it will be a version [or revision] NUMBER
    #   because that's the unique identifier for version doc records.
    # @param [String] docName The value of the KbDoc "identifier" or root field. What that field is will be looked up
    #   if not already cached.
    # @return [BSON::DBRef] The reference to the document. The collection name is available via dbRef.namespace while
    #   the _id value is avialble via dbRef.object_id or dbRef.object_id.to_s if you really must (generally you don't)
    def dbRefFromRootPropVal( docName, collName=@coll.name )
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "docName: #{docName.inspect} ; collName: #{collName.inspect}")
      idPropName = getIdentifierName( collName ) # default is for @coll.name which is NOT what we want here (it would be versions collection)
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "idPropName: #{idPropName.inspect}")
      # Specifically gets only the internal mongo _id field value.
      return dbRefFromCollectionByUniqueFieldAndValue( docName, "#{idPropName}.value", collName )
    end
    alias_method( :dbRefByIdentifier, :dbRefFromRootPropVal )

    # ------------------------------------------------------------------
    # INTERNAL METHODS - mainly for use by this class and the framework, rarely outside this framework
    # ------------------------------------------------------------------

    # Utility method for finding a document from (usually) the helper's collection
    #   using a field and value. By default matches against the @_id@ field, so it's
    #   useful for getting docs by their @_id@. But other simple fields are possible.
    # @note If you have a {BSON::DBRef} and want the actual document referenced, it's more
    #   efficient to use @MongoKbDatabase.db.dereference@ (see #Mongo::DB#dereference) rather
    #   than hacking things so you can use this method.
    # @param [Object, BSON::ObjectId] value The value to match in @field@. If @field@ is
    #   @"_id"@ this should be a {BSON::ObjectId}.
    # @param [String] field The field to match @value@ against.
    # @return [KbDoc, nil] the doc requested or @nil@ if not found.
    def docFromCollectionByFieldAndValue(value, field='_id', coll=@coll)
      retVal = nil
      if(field == '_id')
        # Try to convert value into BSON::ObjectId (noop if already is one, like normally the case)
        valueAsObjId = BSON::ObjectId.interpret(value)
        # If coll is same as this object's @coll, then we can just use Mongo::DB#defeference
        if(coll.name == @coll.name)
          retVal = @kbDatabase.docByRef(valueAsObjId, @coll.name)
        else # some other coll, but using _id (odd, but ok; maybe version/revision coll) and a value which should match
          retVal = coll.find_one(field => value)
        end
      else
        retVal = coll.find_one(field => value)
      end
      return (retVal.nil? ? retVal : BRL::Genboree::KB::KbDoc.new(retVal))
    end

    # Utility method for quickly getting the _id value for a doc using some unique field and value combo.
    #   Generally, used to get the _id value via {rootProp}.value. Using the _id value or
    #   a DbRef for subsequent lookups greatly speeds things up compared to other lookups and
    #   is invaluable when wanting to quickly locate and work with version/revision records
    #   (since you avoid digging into versionNum.content.{rootProp} just to make matches...and
    #   nothing in content is indexed since don't know {rootProp} ahead of time).
    # @note If you already have a {BSON::DBRef} and want the actual document referenced, it's more
    #   efficient to use @MongoKbDatabase.db.dereference@ (see #Mongo::DB#dereference) rather
    #   than hacking things so you can use this method.
    # @note You should consider using {#dbRefFromCollectionByUniqueFieldAndValue} INSTEAD. It will
    #   give you a nice BSON::DBRef object that can be used very efficiently in some methods and
    #   gives you a good way to search versionNum.dbRef and revisionNum.dbRef. AND that BSON::DBRef
    #   object has this _id value embedded within! Just use BSON::DBRef#object_id['_id'].to_s to get it.
    # @param [String] value The value to match in @field@.
    # @param [String] field The field to match @value@ against. Fields is a MONGO doc path,
    #   not a model path, so will already have .value or whatever. In most cases this parameter
    #   will be "{rootProp}.value" to support looking up by value.
    # @return [BSON::ObjectId] The _id field value for the matching doc or @nil@ if not found.
    def docIdFromCollectionByUniqueFieldAndValue(value, field, coll=@coll)
      if( coll.is_a?(String) )
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "coll arg: #{coll.inspect}")
        coll = @kbDatabase.getCollection( coll )
      end
      retVal = coll.find_one( { field => value }, { :fields => [ '_id' ] } )
      return ( retVal.is_a?(Hash) ? retVal['_id'] : retVal )
    end

    # Utility method for quickly getting a BSON::DBRef object for a doc using some unique field and value combo,
    #   generally the {rootProp}.value plus the document identifier/name. Using the _id value or
    #   a DbRef for subsequent lookups greatly speeds things up compared to other lookups and
    #   is invaluable when wanting to quickly locate and work with version/revision records
    #   (since you avoid digging into versionNum.content.{rootProp} just to make matches...and
    #   nothing in content is indexed since don't know {rootProp} ahead of time).
    # @param [String] value The value to match in @field@.
    # @param [String] field The field to match @value@ against. Fields is a MONGO doc path,
    #   not a model path, so will already have .value or whatever. In most cases this parameter
    #   will be "{rootProp}.value" to support looking up by value.
    # @param [String, Mongo::Collection] coll The collection to get the doc DBRef for
    # @return [BSON::DBRef] The DBRef object for the doc, containing the collection name, the _id value, and
    #   also usable as-is to lookup matching version/revision records.
    def dbRefFromCollectionByUniqueFieldAndValue(value, field, coll=@coll)
      tt = Time.now
      if( coll.is_a?(String) )
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "coll arg: #{coll.inspect}")
        coll = @kbDatabase.getCollection( coll )
      end
      retVal = coll.find_one( { field => value }, { :fields => [ '_id' ] } )
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "retVal: #{retVal.inspect}")
      retVal = ( retVal.is_a?(Hash) ? BSON::DBRef.new( coll.name, retVal['_id'] ) : retVal )

      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Done for => value arg: #{value.inspect} ; field: #{field.inspect} ; coll class: #{coll.class} ; DBRef retVal: #{retVal.inspect} in #{Time.now.to_f - tt.to_f} sec")
      return retVal
    end

    # Utility method for finding all documents whose specified field value matches one
    #   of a set of values
    # @param [Array] values the set of values that @field@ should match
    # @param [String] field the field to query on
    # @param [Object] coll the collection handle to use to perform the query
    # @return [NilClass, Array<BRL::Genboree::KB::KbDoc>] query results or nil if failure
    def docsFromCollectionByFieldAndValues(values, field="_id", coll=@coll)
      retVal = nil
      if(values.size > MAX_BATCH)
        $stderr.debugPuts(__FILE__, __method__, "WARNING", "batch size #{values.size.inspect} exceeds #{MAX_BATCH} limit")
        values = values[0...MAX_BATCH]
      end
      if(field == "_id" and coll.name == @coll.name)
        valuesAsObjIds = values.map{|xx| BSON::ObjectId.interpret(xx)}
        retVal = @kbDatabase.docsByRefs(valuesAsObjIds, @coll.name)
      else
        query = { field => {"$in" => values }}
        retVal = []
        coll.find(query){|cursor| cursor.each{|xx| retVal << xx } }
        retVal.map!{|xx| (BRL::Genboree::KB::KbDoc.new(xx))}
      end
      return retVal
    end

    # Convenience method. Get cursor for ALL DOCS, but only provide the properties listed in @outputProps@ in the output. Thus
    #   each record returned will only have values for the properties listed in @outputProps@. If empty or nil
    #   this is the same as getting a cursor for the complete content of all the docs.
    # @param [Array<String>] outputProps List of what properties to output/project. If @nil@ then whole doc is output.
    #   If they don't look like they are *mongo paths* (which would have ".properties" and/or ".items" since that's)
    #   how doc is stored in mongo), then will attempt to convert the paths to mongo paths automatically.
    # @param [Hash<String,Symbol>] sortInfo OPTIONAL. Hash of property paths to sort on mapped to @:asc@ or @:desc@
    # @param [Hash] extraOpts OPTIONAL. Containing any extra options like @:limit@, @:skip@ for example. See http://api.mongodb.com/ruby/1.10.1/Mongo/Collection.html#aggregate-instance_method
    # return [Mongo::Cursor] A Mongo cursor which can be used to go over the docs in the result set.
    def cursorForOutputProps(outputProps, sortInfo=nil, extraOpts={})
      return cursorByComplexQuery( {}, outputProps, sortInfo, extraOpts )
    end

    # Search using pairs of props=val equality conditions. i.e. match each prop to a specific value. Conditions will be joined
    #  via the conjection/disjunction giving in @criteriaInfo[:logicOp]@. A given property can only appear once; p1=v1,p2=v2,p2=v3 is not
    #  currently supported by this implementation.
    # @param [Hash] queryInfo The query/selector Hash. See http://api.mongodb.com/ruby/1.10.1/Mongo/Collection.html#aggregate-instance_method
    # @param [Array<String>] outputProps List of what properties to output/project. If @nil@ then whole doc is output.
    # @param [Hash] sortInfo Property to sort on  mapped to @:asc@ or @:desc@
    # @param [Hash] extraOpts Containing any extra options like @:limit@, @:skip@ for example.
    # return [Mongo::Cursor] A Mongo cursor which can be used to go over the docs in the result set.
    # @raise ArgumentError When number of props from @criteriaInfo[:props]@ doesn't match number of values from @criteriaInfo[:vals]@
    # @todo Merge with cursorBySimplePropValsMatch perhaps? Or just use this instead? Much of code is same, just
    #   needs a bit more flexibility to properly arrange up p=v1|v2|v3 VS p1=v1|p2=v2|p3=v3
    def cursorByComplexQuery(queryInfo, outputProps=nil, sortInfo=nil, extraOpts={})
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "\n  queryInfo: #{queryInfo.inspect}\n  outputProps: #{outputProps.inspect}\n  sortInfo: #{sortInfo.inspect}")
      retVal = nil
      opts = {}
      # Build fields doc, if needed
      if(outputProps.acts_as?(Array) and !outputProps.empty?)
        opts[:fields] = outputProps
      end
      # Build sort doc, if needed
      if(sortInfo.acts_as?(Hash) and !sortInfo.empty?)
        sortList = opts[:sort] = [ ]
        sortInfo.each_key { |prop|
          sortList << [ prop, sortInfo[prop].to_sym ]
        }
      end
      # Add other opts, if any
      if(extraOpts.is_a?(Hash) and !extraOpts.empty?)
        eoLimit = extraOpts[:limit]
        opts[:limit] = eoLimit.to_i if(eoLimit and eoLimit.to_i > 0)
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "\n  opts:\n    #{opts.inspect}")
      # Perform query using query doc, now that we have it
      retVal = @coll.find(queryInfo, opts)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "\n  cursor (count = #{retVal.count}):\n    #{retVal.inspect}")
      return retVal
    end

    # Search using pairs of props=val equality conditions. i.e. match each prop to a specific value. Conditions will be joined
    #  via the conjection/disjunction giving in @criteriaInfo[:logicOp]@. A given property can only appear once; p1=v1,p2=v2,p2=v3 is not
    #  currently supported by this implementation.
    # @param [Hash] criteriaInfo The match criteria.
    # @option criteriaInfo [Symbol] :mode How to do text matching: :full, :exact, :prefix, :keyword
    # @option criteriaInfo [Symbol] :logicOp How to join the conditions: :and, :or
    # @option criteriaInfo [Array<Hash>] :props For each prop to be queried, a 1-key {Hash} with the Mongo-doc path mapped to the domain from the model. Same length as @:vals@
    # @option criteriaInfo [Array<String] :vals The corresponding values for each property.
    # @param [Array<String>] outputProps List of what properties to output/project. If @nil@ then whole doc is output.
    # @param [Hash] sortInfo Property to sort on  mapped to @:asc@ or @:desc@
    # @param [Hash] extraOpts Containing any extra options like @:limit@, @:skip@ for example.
    # return [Mongo::Cursor] A Mongo cursor which can be used to go over the docs in the result set.
    # @raise ArgumentError When number of props from @criteriaInfo[:props]@ doesn't match number of values from @criteriaInfo[:vals]@
    # @todo Merge with cursorBySimplePropValsMatch perhaps? Or just use this instead? Much of code is same, just
    #   needs a bit more flexibility to properly arrange up p=v1|v2|v3 VS p1=v1|p2=v2|p3=v3
    def cursorBySimplePropsValMatch(criteriaInfo, outputProps=nil, sortInfo=nil, extraOpts={})
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "\n  criteriaInfo:\n    #{criteriaInfo.inspect}\n  outputProps:\n    #{outputProps.inspect}\n  sortInfo:\n    #{sortInfo.inspect}\n\n")
      retVal = nil
      logicOp = "$#{( criteriaInfo[:logicOp] || :or)}"
      mode = ( criteriaInfo[:mode] || :full )
      val = criteriaInfo[:val]
      if(val)
        criteriaProps = criteriaInfo[:props]
        if(criteriaProps and !criteriaProps.empty?)
          # Build query doc, if able
          queryDoc = { logicOp => [ ] }
          querySet = queryDoc[logicOp]
          criteriaProps.each_key { |prop|
            propDomain = (criteriaProps[prop] or 'string')
            # If string-type domain, can do prefix, keyword, etc, as specified by mode
            domainDefs = BRL::Genboree::KB::Validators::ModelValidator::DOMAINS
            domainInfo = domainDefs.find { |re, rec| propDomain =~ re }
            searchCategory = 'string'
            if(domainInfo.is_a?(Array) and domainInfo.size == 2)
              searchCategory = domainInfo.last[:searchCategory]
            end
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "searchCategory: #{searchCategory.inspect} ; domainInfo:\n\n#{domainInfo.inspect}\n\n")
            if(searchCategory == 'string')
              if(mode == :exact)
                querySet << { prop => val.to_s }
              elsif(mode == :full)
                querySet << { prop => /^#{Regexp.escape(val)}$/i }
              elsif(mode == :keyword)
                querySet << { prop => /#{Regexp.escape(val)}/i }
              else # :prefix
                querySet << { prop => /^#{Regexp.escape(val)}/i }
              end
            elsif(searchCategory == /^boolean$/)
              if(val.to_s =~ /^(?:true|yes|1)$/i)
                querySet << { prop => true }
              else
                querySet << { prop => false }
              end
            elsif(searchCategory == 'int')
              querySet << { prop => val.to_f.round }
            elsif(searchCategory == 'float')
              querySet << { prop => val.to_f }
            else # searchCategory empty; not defined.
              querySet << { prop => val }
            end
          }
          opts = buildFindOptions(outputProps, sortInfo, extraOpts)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "QUERY MONGO VIA:\n  queryDoc:\n    #{queryDoc.inspect}\n  opts:\n    #{opts.inspect}\n\n")
          # Perform query using query doc, now that we have it
          retVal = @coll.find(queryDoc, opts)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "QUERY FOUND #{retVal.count} docs (total matching; not subject to any limit)")
        end
      end
      return retVal
    end

    # Search using pairs of props=val equality conditions. i.e. match each prop to a specific value. Conditions will be joined
    #  via the conjection/disjunction giving in @criteriaInfo[:logicOp]@. A given property can only appear once; p1=v1,p2=v2,p2=v3 is not
    #  currently supported by this implementation.
    # @param [Hash] criteriaInfo The match criteria.
    # @option criteriaInfo [Symbol] :mode How to do text matching: :full, :exact, :prefix, :keyword
    # @option criteriaInfo [Symbol] :logicOp How to join the conditions: :and, :or
    # @option criteriaInfo [Array<Hash>] :props For each prop to be queried, a 1-key {Hash} with the Mongo-doc path mapped to the domain from the model. Same length as @:vals@
    # @option criteriaInfo [Array<String] :vals The corresponding values for each property.
    # @param [Array<String>] outputProps List of what properties to output/project. If @nil@ then whole doc is output.
    # @param [Hash] sortInfo Property to sort on  mapped to @:asc@ or @:desc@
    # @param [Hash] extraOpts Containing any extra options like @:limit@, @:skip@ for example.
    # return [Mongo::Cursor] A Mongo cursor which can be used to go over the docs in the result set.
    # @raise ArgumentError When number of props from @criteriaInfo[:props]@ doesn't match number of values from @criteriaInfo[:vals]@
    # @todo Merge with cursorBySimplePropValsMatch perhaps? Or just use this instead? Much of code is same, just
    #   needs a bit more flexibility to properly arrange up p=v1|v2|v3 VS p1=v1|p2=v2|p3=v3
    def cursorBySimplePropValsMatch(criteriaInfo, outputProps=nil, sortInfo=nil, extraOpts={})
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "\n  criteriaInfo:\n    #{criteriaInfo.inspect}\n  outputProps:\n    #{outputProps.inspect}\n  sortInfo:\n    #{sortInfo.inspect}\n\n")
      retVal = nil
      mode = ( criteriaInfo[:mode] || :full )
      vals = criteriaInfo[:vals]
      if(vals)
        criteriaProps = criteriaInfo[:prop]
        if(criteriaProps and !criteriaProps.empty?)
          prop = criteriaProps.keys.first
          propDomain = (criteriaProps[prop] or 'string')
          domainDefs = BRL::Genboree::KB::Validators::ModelValidator::DOMAINS
          domainInfo = domainDefs.find { |re, rec| propDomain =~ re }
          searchCategory = 'string'
          if(domainInfo.is_a?(Array) and domainInfo.size == 2)
            searchCategory = domainInfo.last[:searchCategory]
          end
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "searchCategory: #{searchCategory.inspect} ; domainInfo:\n\n#{domainInfo.inspect}\n\n")
          # Build query doc, if able
          queryDoc = { prop => { "$in" => [ ] } }
          inSet = queryDoc[prop]["$in"]
          vals.each { |val|
            # If string-type domain, can do prefix, keyword, etc, as specified by mode
            if(searchCategory == 'string')
              if(mode == :exact)
                inSet << val.to_s
              elsif(mode == :full)
                inSet << /^#{Regexp.escape(val)}$/i
              elsif(mode == :keyword)
                inSet << /#{Regexp.escape(val)}/i
              else # :prefix
                inSet << /^#{Regexp.escape(val)}/i
              end
            elsif(searchCategory == 'boolean')
              if(val.to_s =~ /^(?:true|yes|1)$/i)
                inSet << true
              else
                inSet << false
              end
            elsif(searchCategory == 'int')
              inSet << val.to_f.round
            elsif(searchCategory == 'float')
              inSet << val.to_f
            else #  catch-all; try exact match, but will be as String. Probably won't work.
              inSet << val
            end
          }
          opts = buildFindOptions(outputProps, sortInfo, extraOpts)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "QUERY MONGO VIA:\n  queryDoc:\n    #{queryDoc.inspect}\n  opts:\n    #{opts.inspect}\n\n")
          # Perform query using query doc, now that we have it
          retVal = @coll.find(queryDoc, opts)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "QUERY FOUND #{retVal.count} (total matching; not subject to any limit)")
        end
      end
      return retVal
    end

    # Search using pairs of props=val equality conditions. i.e. match each prop to a specific value. Conditions will be joined
    #  via the conjection/disjunction giving in @criteriaInfo[:logicOp]@. A given property can only appear once; p1=v1,p2=v2,p2=v3 is not
    #  currently supported by this implementation.
    # @param [Hash] criteriaInfo The match criteria.
    # @option criteriaInfo [Symbol] :mode How to do text matching: :full, :exact, :prefix, :keyword
    # @option criteriaInfo [Symbol] :logicOp How to join the conditions: :and, :or
    # @option criteriaInfo [Array<Hash>] :props For each prop to be queried, a 1-key {Hash} with the Mongo-doc path mapped to the domain from the model. Same length as @:vals@
    # @option criteriaInfo [Array<String] :vals The corresponding values for each property.
    # @param [Array<String>] outputProps List of what properties to output/project. If @nil@ then whole doc is output.
    # @param [Hash] sortInfo Property to sort on  mapped to @:asc@ or @:desc@
    # @param [Hash] extraOpts Containing any extra options like @:limit@, @:skip@ for example.
    # return [Mongo::Cursor] A Mongo cursor which can be used to go over the docs in the result set.
    # @raise ArgumentError When number of props from @criteriaInfo[:props]@ doesn't match number of values from @criteriaInfo[:vals]@
    # @todo Merge with cursorBySimplePropValsMatch perhaps? Or just use this instead? Much of code is same, just
    #   needs a bit more flexibility to properly arrange up p=v1|v2|v3 VS p1=v1|p2=v2|p3=v3
    def cursorBySimplePropsValsMatch(criteriaInfo, outputProps=nil, sortInfo=nil, extraOpts={})
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "\n  criteriaInfo:\n    #{criteriaInfo.inspect}\n  outputProps:\n    #{outputProps.inspect}\n  sortInfo:\n    #{sortInfo.inspect}\n\Object ancestors: #{Object.ancestors.inspect}")
      retVal = nil
      domainDefs = BRL::Genboree::KB::Validators::ModelValidator::DOMAINS # shorthand
      mode = ( criteriaInfo[:mode] || :full )
      logicOp = "$#{( criteriaInfo[:logicOp] || :or)}"
      vals = criteriaInfo[:vals]
      if(vals)
        criteriaProps = criteriaInfo[:props]
        # MUST have same number of props as vals
        if(vals.size == criteriaProps.size)
          queryDoc = { logicOp => [ ] } # We will :and or :or all query conditions
          querySet = queryDoc[logicOp]  # The array of query conditions
          # Add a condition for each prop:
          criteriaProps.each_index { |ii|
            propHash = criteriaProps[ii] # a 1-key Hash
            prop = propHash.keys.first
            propDomain = ( propHash.values.first or 'string' )
            # Get corresponding value
            val = vals[ii]
            # Determine serach type
            domainInfo = domainDefs.find { |re, rec| propDomain =~ re }
            searchCategory = 'string'
            if(domainInfo.is_a?(Array) and domainInfo.size == 2) # then there is some other non-default searchCategory for this domain
              searchCategory = domainInfo.last[:searchCategory]
            end
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "searchCategory: #{searchCategory.inspect} ; domainInfo:\n\n#{domainInfo.inspect}\n\n")
            # Add query condition for this prop to querySet Array.
            if(searchCategory == 'string')
              if(mode == :exact)
                querySet << { prop => val.to_s }
              elsif(mode == :full)
                querySet << { prop => /^#{Regexp.escape(val)}$/i }
              elsif(mode == :keyword)
                querySet << { prop => /#{Regexp.escape(val)}/i }
              else # :prefix
                querySet << { prop => /^#{Regexp.escape(val)}/i }
              end
            elsif(searchCategory == /^boolean$/)
              if(val.to_s =~ /^(?:true|yes|1)$/i)
                querySet << { prop => true }
              else
                querySet << { prop => false }
              end
            elsif(searchCategory == 'int')
              querySet << { prop => val.to_f.round }
            elsif(searchCategory == 'float')
              querySet << { prop => val.to_f }
            else # searchCategory empty; not defined.
              querySet << { prop => val }
            end
          }
          # Now have our Mongo query doc. Now need to arrange any other query options.
          opts = buildFindOptions(outputProps, sortInfo, extraOpts)
          # Now have our query doc AND our options doc.

          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "QUERY MONGO VIA:\n  queryDoc:\n    #{queryDoc.inspect}\n  opts:\n    #{opts.inspect}\n\n")
          # Perform query using query doc, now that we have it
          retVal = @coll.find(queryDoc, opts)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "QUERY FOUND #{retVal.count} docs (total matching; not subject to any limit)")
        else # |props| != |vals|
          raise ArgumentError, "ERROR: LIST SIZE MISMATCH: The number of properties (#{criteriaProps.size.inspect}) doesn't match the number of valies (#{vals.size.inspect})."
        end
      end
      return retVal
    end

    # Helper method to build options {Hash} for use with {Mongo::Collection#find}. Common to all the various @cursorBySimple*@ methods.
    # @param [Array<String>] outputProps List of what properties to output/project. If @nil@ then whole doc is output.
    # @param [Hash] sortInfo Property to sort on  mapped to @:asc@ or @:desc@
    # @param [Hash] extraOpts Containing any extra options like @:limit@, @:skip@ for example.
    # @return [Hash] The options you can use with {Mongo::Collection#find}
    def buildFindOptions(outputProps, sortInfo=nil, extraOpts=nil)
      opts = {}
      # Build output fields doc, if needed
      if(outputProps.acts_as?(Array) and !outputProps.empty?)
        opts[:fields] = outputProps
      end
      # Build sort doc, if needed
      if(sortInfo.acts_as?(Hash) and !sortInfo.empty?)
        sortList = opts[:sort] = [ ]
        sortInfo.each_key { |prop|
          sortList << [ prop, sortInfo[prop].to_sym ]
        }
      elsif(sortInfo.acts_as?(Array) and !sortInfo.empty?)
        sortList = opts[:sort] = [ ]
        sortInfo.each { |hash|
          hash.each {|kk, vv|
            sortList << [ kk, vv.to_sym ]
          }
        }
      end
      # Add other opts, if any
      if(extraOpts.is_a?(Hash) and !extraOpts.empty?)
        # limit
        eoLimit = extraOpts[:limit]
        opts[:limit] = eoLimit.to_i if(eoLimit and eoLimit.to_i > 0)
        # skip
        eoSkip = extraOpts[:skip]
        opts[:skip] = eoSkip.to_i if(eoSkip and eoSkip.to_i > 0)
      end
      return opts
    end

    # ----------------------------------------------------------------
    # MEMOIZE now-defined methods
    # ----------------------------------------------------------------
    MEMOIZED_INSTANCE_METHODS.each { |meth| memoize meth }
  end # class AbstractHelper
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers
