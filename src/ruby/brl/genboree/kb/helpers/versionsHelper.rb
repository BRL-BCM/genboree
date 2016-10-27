#!/bin/env ruby

require 'brl/genboree/kb/helpers/abstractHelper'

module BRL ; module Genboree ; module KB ; module Helpers
  # This class assists with managing the versioning documents of any collection.
  # @note Unlike other {AbstractHelper} sub-classes, the name of the underlying
  #   collection is NOT known ahead of time. It is named after the doc collection
  #   the versioning is being done for. That collection name is determined dynamically
  #   when you instantiate this class.
  class VersionsHelper < AbstractHelper
    # @return [String] The name of the core GenboreeKB collection the helper assists with.
    KB_CORE_COLLECTION_NAME = "{docColl}.versions"
    # @return [Array<Hash>] An array of MongoDB index config hashes; each has has key @:spec@ and @:opts@
    attr_accessor :incTimeCount
    #   the indices for the metadata documents in this collection.
    KB_CORE_INDICES =
    [
      # Index each versions doc by its "versionNum". Will want max versionNum overall quickly.
      {
        :spec => 'versionNum.value',
        :opts => { :unique => true, :background => true }
      },
      # Index each versions doc by the docRef so we can find the revision for a given doc quickly.
      {
        :spec => [ [ 'docRef.value', Mongo::ASCENDING ], [ 'versionNum.value', Mongo::DESCENDING ] ],
        :opts => { :unique => true, :background => true }
      },
      # Index the timestamp of the version so we can answer queries about the use of the collection over time
      {
        :spec => "versionNum.properties.timestamp.value",
        :opts => { :background => true }
      },
      # Index the previous version so we can answer queries about the number of creations
      {
        :spec => [["versionNum.properties.prevVersion.value", Mongo::ASCENDING], ["versionNum.properties.timestamp.value", Mongo::DESCENDING]],
        :opts => { :background => true }
      },
      # Index the deletion field so we can answer queries about the number of deletions
      {
        :spec => [["versionNum.properties.deletion.value", Mongo::ASCENDING], ["versionNum.properties.timestamp.value", Mongo::DESCENDING]],
        :opts => { :background => true }
      }
    ]
    # @return [Hash] A model document or model template which can be used to place an appropriate
    #    model document into the @kbModels@ collection when the database (or this helper's collection)
    #    is first created.
    KB_MODEL =
    {
      "name"        => { "value" => "Version Model - #{KB_CORE_COLLECTION_NAME}", "properties" =>
      {
        "internal" => { "value" => true },
        "model" => { "value" => {
            "name"        => "versionNum",
            "description" => "Unique version number in the .versions collection. Auto-increment best.",
            "domain"      => "posInt",
            "identifier"  => true,
            "properties"  =>
            [
              {
                "name"	      => "docRef",
                "description"	=> "A DBRef to the actual document, in its respective collection, for which this is a versioning record. Thus, always points to the latest/current/head version of the document. If this version is a document deletion, this will be null.",
                "domain"	    => "dbRef",
                "required"	  => true,
                "index"	      => true,
              },
              {
                "name"	      => "prevVersion",
                "description"	=> "The versionNum of the previous version for the document. If it is the first/original version, this will be 0.",
                "domain"	    => "posInt",
                "required"	  => true,
                "index"       => true
              },
              {
                "name"	      => "author",
                "description"	=> "Username/login of the user who modified the document to make this version.",
                "required"	  => true
              },
              {
                "name"	      => "timestamp",
                "description"	=> "The timestamp of this version.",
                "domain"	    => "timestamp",
                "required"	  => true
              },
              {
                "name"	      => "deletion",
                "description"	=> "Flag indicating whether the change in content here is a document deletion or not. If so, dbRef will be null.",
                "domain"	    => "boolean",
                "default"	    => false
              },
              {
                "name"	      => "label",
                "description"	=> "A label for this version. Optional and ill specified. Bit like a special tag.",
                "index"	      => true
              },
              {
                "name"	      => "comment",
                "description"	=> "Free form optional comment text from user about this version."
              },
              {
                "name"	      => "tags",
                "description"	=> "A list of single-word keywords/tags associated with this version.",
                "default"	    => "",
                "index"	      => true,
                "items"	      =>
                [
                  {
                    "name"  => "tag"
                  }
                ]
              },
              {
                "name"	      => "content",
                "description"	=> "The full document at this version. The document must have a corresponding model in the kbModels collection.",
                "required"	  => true,
                "domain"	    => "modeledDocument"
              }
            ]
          }
        }

      }}
    }

    # Get the model doc template for the collection this helper assists with.
    # @todo change this from returning KB_MODEL constant
    #   in the respective sub-class, but rather have them loaded from
    #   some .yml files. Maybe cached like the SingletonJSONCache, etc.
    # @param [String] docCollName The name of the data collection this versioning model template will
    #   be for.
    # @param [nil, Object] params Provide any parameters as individual arguments. Generally none are
    #   needed, except for some sub-classes that override this method and need some info.
    # @return [KbDoc] A suitable model template for the collection this helper assists with.
    def self.getModelTemplate(docCollName, *params)
      # Need a deep_clone, else we'll be changing the hashes within KB_MODELS constant
      model = self::KB_MODEL.deep_clone()
      (model["name"] = model["name"].gsub(/\{docColl\}/, docCollName)) if(params and !params.empty?)
      return BRL::Genboree::KB::KbDoc.new(model)
    end

    # Construct the history collection name for the data document collection @docCollName@. Just
    #   returns the appropriate name; collection may or may not exist.
    # @note Not a substitute for consulting the metadata document for @docCollName@ and getting the
    #   history collection info from that.
    # @param [String] docCollName The name of the data document collection you want the history collection for.
    # @return [String] the appropriate name for the history collection.
    def self.historyCollName(docCollName)
      return self::KB_CORE_COLLECTION_NAME.gsub(/\{docColl\}/, docCollName)
    end

    # Create new instance of this helper.
    # @param [MongoKbDatabase] kbDatabase The KB database object this helper is assisting.
    # @param [String] docCollName The name of the document collection that is being versioned.
    #   It will be used to determine to correct name of the versioning collection.
    def initialize(kbDatabase, docCollName)
      super(kbDatabase, docCollName)
      unless(docCollName.is_a?(Mongo::Collection))
        @coll = @kbDatabase.getCollection(docCollName, :versions)
      end
    end

    # Returns the current version number from the global counter.
    # @return [Fixnum] The current version number.
    def currentVersionNum()
      globalsHelper = @kbDatabase.globalsHelper()
      return globalsHelper.globalCounterValue("versionNum")
    end

    # Generates and returns the next version number from the global counter. i.e.
    #   increments and returns the version number global counter.
    # @return [Fixnum] The next version number.
    def nextVersionNum()
      globalsHelper = @kbDatabase.globalsHelper()
      return globalsHelper.incGlobalCounter("versionNum")
    end
    
    # Generates and returns the version number incermented by the specified value from the global counter. i.e.
    #   increments and returns the version number global counter.
    # @param [Integer] nn positive number by which you want to increment by
    # @return [Fixnum] The next version number.
    def incVersionNumByN(nn)
      globalsHelper = @kbDatabase.globalsHelper()
      return globalsHelper.incGlobalCounterByN("versionNum", nn)
    end

    # Gets the latest/current versioning doc for a document of interest.
    # @todo Move this to a HistoryHelper abstract parent class of VersionsHelper and RevisionsHelper. Generic.
    # @overload currentVersion(docId)
    #   Use a reference to the document to get its current versioning record. Preferred.
    #   @param [BSON::DBRef] docId The reference pointing to the data document.
    # @overload currentVersion(docId, docCollName)
    #   Use an object that can be interpretted as a {BSON::ObjectId} by {BSON::ObjectId.interpret}
    #     as the ObjectId within the collection named in @docCollName@. Ideally an actual
    #     {BSON::ObjectId} object already, like what is returned in the @"_id"@ field by Mongo.
    #     But some auto-casting from other objects to {BSON::ObjectId} are supported (typically to
    #     cast special ID {String}, like hex string returned by {BSON::ObjectId.to_s} during JSON serialization
    #     and similar.)
    #   @param (see BSON::ObjectId.interpret)
    #   @param [String] docCollName The name of the data collection.
    # @return [KbDoc] the latest/current versioning doc for the document of interest.
    def currentVersion(docId, docCollName=nil)
      if(docId.is_a?(BSON::DBRef) and docCollName.nil?)
        docRef = docId
        docCollName = docRef.namespace
      elsif(docId and docCollName) # need to construct a docRef
        docId = BSON::ObjectId.interpret(docId)
        docRef = BSON::DBRef.new(docCollName, docId)
      else
        raise ArgumentError, "ERROR: method called incorrectly. Either provide JUST a BSON::DBRef or BOTH a docId type object + the appropriate collection name."
      end
      historyCollName = self.class::historyCollName(docCollName)
      docCount = @kbDatabase.db[historyCollName].find({ 'versionNum.properties.docRef.value' => docRef }, { :sort => [ 'versionNum.value', Mongo::DESCENDING ], :limit => 1 }).count(false)
      retVal = nil
      if(docCount.to_i > 0)
        historyDoc = @kbDatabase.db[historyCollName].find_one({ 'versionNum.properties.docRef.value' => docRef })
        retVal = BRL::Genboree::KB::KbDoc.new(historyDoc)
      end
      return retVal
    end
    
    # Filters the latest version docs for a list of docIds based on a given cutoff time
    # @param [Hash] bsonObjId2DocId Hash mapping {BSON::ObjectId} ids of documents to their document identifier values
    # @param [Time] cutoff Documents equal to OR newer will be kept in the returning list
    # @param [String] docCollName The name of the data collection
    # @param [String] docIdentifierPropName The name of the document identifier for this collection
    # @param [Hash] opts Options hash
    # @return [Array] List of filtered docIds
    def filterDocListBasedOnTimeStamp(bsonObjId2DocId, cutoffTime, docCollName, docIdentifierPropName, opts={})
      bsonIds = bsonObjId2DocId.keys
      docRefs = []
      bsonIds.each { |id|
        docRef = BSON::DBRef.new(docCollName, id)
        docRefs << docRef
      }
      historyCollName = self.class::historyCollName(docCollName)
      cursor = @kbDatabase.db[historyCollName].aggregate( [ { "$match" =>  { "versionNum.properties.docRef.value" => { "$in" => docRefs }  }  }, {  "$group" => { "_id" => "$versionNum.properties.docRef.value", "timestamp" => { "$max" => "$versionNum.properties.timestamp.value" } } } ], :cursor => { "batchSize" => 100 }  )
      retVal = []
      coffTime = Time.parse(cutoffTime.to_s)
      includeCutoffTime = opts[:includeCutoffTime]
      cursor.each { |doc|
        if(includeCutoffTime)
          if(doc['timestamp'] >= coffTime )
            retVal << bsonObjId2DocId[doc['_id'].object_id]
          end
        else
          if(doc['timestamp'] > coffTime )
            retVal << bsonObjId2DocId[doc['_id'].object_id]
          end
        end
      }
      return retVal
    end
    
    # Filters the version docs for all the documents in a collection based on a cutoff time
    # @param [Time] cutoff Documents equal to OR newwer will be kept in the returning list
    # @param [String] docCollName The name of the data collection
    # @param [String] docIdentifierPropName The name of the document identifier for this collection
    # @param [Hash] opts Options hash
    # @return [Array] List of filtered docIds
    def filterAllDocsBasedOnTimeStamp(cutoffTime, docCollName, docIdentifierPropName, opts={})
      historyCollName = self.class::historyCollName(docCollName)
      retVal = []
      coffTime = Time.parse(cutoffTime.to_s)
      includeCutoffTime = opts[:includeCutoffTime]
      cursor = @kbDatabase.db[historyCollName].aggregate( [ { "$match" =>  { }  }, {  "$group" => { "_id" => "$versionNum.properties.docRef.value", "timestamp" => { "$max" => "$versionNum.properties.timestamp.value" }, "docId" => { "$first" => "$versionNum.properties.content.value.#{docIdentifierPropName}.value" } }  } ], :cursor => { "batchSize" => 100 }  )
      cursor.each { |doc|
        if(includeCutoffTime)
          if(doc['timestamp'] >= coffTime )
            retVal << doc['docId']
          end
        else
          if(doc['timestamp'] > coffTime )
            retVal << doc['docId']
          end
        end
      }
      return retVal
    end
    

    # Gets a particular versioning doc for a document of interest.
    # @todo Move this to a HistoryHelper abstract parent class of VersionsHelper and RevisionsHelper. Generic.
    # @overload currentVersion(versionNum, docId)
    #   Use a reference to the document to get its current versioning record. Preferred.
    #   @param [Fixnum] versionNum The version number
    #   @param [BSON::DBRef] docId The reference pointing to the data document.
    # @overload currentVersion(versionNum, docId, docCollName)
    #   Use an object that can be interpretted as a {BSON::ObjectId} by {BSON::ObjectId.interpret}
    #     as the ObjectId within the collection named in @docCollName@. Ideally an actual
    #     {BSON::ObjectId} object already, like what is returned in the @"_id"@ field by Mongo.
    #     But some auto-casting from other objects to {BSON::ObjectId} are supported (typically to
    #     cast special ID {String}, like hex string returned by {BSON::ObjectId.to_s} during JSON serialization
    #     and similar.)
    #   @param [Fixnum] versionNum The version number
    #   @param (see BSON::ObjectId.interpret)
    #   @param [String] docCollName The name of the data collection.
    # @return [KbDoc] the versioning doc associated with versionNum for the document of interest.
    def getVersion(versionNum, docId, docCollName=nil)
      if(docId.is_a?(BSON::DBRef) and docCollName.nil?)
        docRef = docId
        docCollName = docRef.namespace
      elsif(docId and docCollName) # need to construct a docRef
        docId = BSON::ObjectId.interpret(docId)
        docRef = BSON::DBRef.new(docCollName, docId)
      else
        raise ArgumentError, "ERROR: method called incorrectly. Either provide JUST a BSON::DBRef or BOTH a docId type object + the appropriate collection name."
      end
      historyCollName = self.class::historyCollName(docCollName)
      queryDoc = {
        'versionNum.properties.docRef.value' => docRef,
        'versionNum.value' => versionNum
      }
      retVal = nil
      docCount = @kbDatabase.db[historyCollName].find(queryDoc, { :limit => 1 }).count(false)
      if(docCount.to_i > 0)
        historyDoc = @kbDatabase.db[historyCollName].find_one(queryDoc, { :limit => 1 })
        retVal = BRL::Genboree::KB::KbDoc.new(historyDoc)
      end
      return retVal
    end

    # Checks existence of a user document by the identifier value of the actual document stored in the 'content' field
    # @Param [String]
    # @param [String] docName
    # @param [String] docCollName
    # @return [KbDoc] the versioning doc associated with versionNum for the document of interest.
    def exists?(identProp, docName, docCollName)
      historyCollName = self.class::historyCollName(docCollName)
      queryDoc = {
        "versionNum.properties.content.value.#{identProp}.value" => docName,
      }
      retVal = nil
      docCount = @kbDatabase.db[historyCollName].find(queryDoc, { :limit => 1 }).count(false)
      if(docCount.to_i > 0)
        historyDoc = @kbDatabase.db[historyCollName].find_one(queryDoc, { :limit => 1 })
        retVal = BRL::Genboree::KB::KbDoc.new(historyDoc)
      end
      return retVal
    end

    # Gets ALL versioning docs for a document of interest.
    # @todo Move this to a HistoryHelper abstract parent class of VersionsHelper and RevisionsHelper. Generic.
    # @overload allVersions(docId)
    #   Use a reference to the document to get its versioning records. Preferred.
    #   @param [BSON::DBRef] docId The reference pointing to to the data document.
    # @overload allVersions(docId, docCollName)
    #   Use an object that can be interpretted as a {BSON::ObjectId} by {BSON::ObjectId.interpret}
    #     as the ObjectId within the collection named in @docCollName@. Ideally an actual
    #     {BSON::ObjectId} object already, like what is returned in the @"_id"@ field by Mongo.
    #     But some auto-casting from other objects to {BSON::ObjectId} are supported (typically to
    #     cast special ID {String}, like hex string returned by {BSON::ObjectId.to_s} during JSON serialization
    #     and similar.)
    #   @param (see BSON::ObjectId.interpret)
    #   @param [String] docCollName The name of the data collection.
    # @return [Array<KbDoc>] all the versioning records for doc of interest. Should automatically
    #   be from newest->oldest due to the multi-field index with the descending index on @versionNum@.
    def allVersions(docId, docCollName=nil)
      if(docId.is_a?(BSON::DBRef) and docCollName.nil?)
        docRef = docId
        docCollName = docRef.namespace
      elsif(docId and docCollName) # need to construct a docRef
        docId = BSON::ObjectId.interpret(docId)
        docRef = BSON::DBRef.new(docCollName, docId)
      else
        raise ArgumentError, "ERROR: method called incorrectly. Either provide JUST a BSON::DBRef or BOTH a docId type object + the appropriate collection name."
      end
      historyCollName = self.class::historyCollName(docCollName)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "docRef:\n\n#{docRef.inspect}")
      cursor = @kbDatabase.db[historyCollName].find('versionNum.properties.docRef.value' => docRef)
      resultSet = Array.new(cursor.count)

      idx = 0
      cursor.each { |doc|
        resultSet[idx] = BRL::Genboree::KB::KbDoc.new(doc)
        idx += 1
      }
      cursor.close() unless(cursor.closed?)
      return resultSet
    end

    # Given a data collection name and the new version of a document, create the appropriate
    #  version record in the corresponding versioning collection.
    # @param [String] docCollName The name of the data collection where the @newDoc@ has been
    #   saved.
    # @param [Hash, KbDoc] newDoc The actual and entire new version of the data document, as returned by
    #   MongoDB. i.e. will have the @_id@ field and everything. Probably a {BSON::OrderedHash}.
    # @param [String] author The Genboree username of the author.
    # @param [Hash] opts An optional hash containing the names of versioning record fields
    #   mapped to values. Used for overriding the defaults provided by {#docTemplate}. Things like
    #   @"deletion"@, @"comment"@, @"label"@ which are normally nil, empty, or false, etc.
    # @return [BSON::ObjectId] of the saved versioning document.
    # @raise [ArgumentError] when @newDoc@ doesn't have a @"_id"@ key.
    def createNewHistory(docCollName, newDoc, author, opts={})
      retVal = nil
      # newDoc has _id? (hopefully because it has been upserted already)
      unless(newDoc["_id"].nil?)
        # Save the versionDoc directly into the versions collection
        versionsCollName = VersionsHelper.historyCollName(docCollName)
        # Get the docRef for the document. Use newDoc since we know at least it is there,
        docRef = BSON::DBRef.new(docCollName, newDoc["_id"])
        # Build the base version doc, to which we'll add the content
        versionDoc = buildBaseHistoryDoc(docCollName, docRef, author, opts)
        # Note that we very deliberately are keeping a FULL REDUNDANT COPY (SNAPSHOT)
        #   of THIS VERSION of the DOCUMENT. A DBRef to the head revision would be VERY WRONG here.
        versionDoc.setPropVal('versionNum.content', newDoc)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "versionDoc class: #{versionDoc.class} ; acts_as?(Hash): #{versionDoc.acts_as?(Hash)} ; content:\n\n#{versionDoc.inspect}\n\n")
        retVal = @kbDatabase.db[versionsCollName].save( versionDoc.to_serializable() )
      else
        raise ArgumentError, "ERROR: Your newDoc doesn't have an '_id' field and value. This doc should have already been saved to #{docCollName.inspect} collection by this point. This method will not save your doc in #{docCollName.inspect}, it only creates a new version record for the already inserted document."
      end
      return retVal
    end

    # Given a data collection name, create a version record indicating a document deletion.
    # @param [String] docCollName The name of the data collection where the @newDoc@ has been
    #   saved.
    # @param [BSON::DBRef,BSON::ObjectId] docId A reference to the doc being deleted or an
    #   identifier which can be interpretted as a {BSON::ObjectId}. If a {BSON::DBRef}, the
    #   @namespace@ property must match @docCollName@.
    # @param [String] author The Genboree username of the author doing the deletion
    # @param [Hash] opts An optional hash containing the names of versioning record fields
    #   mapped to values. Used for overriding the defaults provided by {#docTemplate}. Things like
    #   @"comment"@, @"label"@ which are normally nil, empty, or false, etc. Note that @opts["deletion"]@
    #   will be forcibly set to @true@.
    # @return [BSON::ObjectId] of the saved versioning document.
    # @raise [ArgumentError] when @docId@ is a {BSON::DBRef} whose @namespace@ doesn't match @docCollName@.
    def createDeletionHistory(docCollName, docId, author, opts={})
      retVal = nil
      if(docId.is_a?(BSON::DBRef))
        if(docId.namespace == docCollName)
          docRef = docId
        else
          raise ArgumentError, "ERROR: The namespace #{docId.namespace.inspect} from the BSON::DBRef provided via docId doesn't match the docCollName argument. This suggests a bug or flaw in program flow."
        end
      else # something we can interpret as a BSON::ObjectId
        docRef = BSON::DBRef.new(docCollName, BSON::ObjectId.interpret(docId))
      end
      # Indicate this is a deletion
      opts["deletion"] = true
      # Save the versionDoc directly into the versions collection
      versionsCollName = VersionsHelper.historyCollName(docCollName)
      # Build the base version doc, to which we'll add the content
      versionDoc = buildBaseHistoryDoc(docCollName, docRef, author, opts)
      # Note that this is a deletion, so content is nil.
      versionDoc.setPropVal('versionNum.content', {})
      retVal = @kbDatabase.db[versionsCollName].save( versionDoc.to_serializable() )
      return retVal
    end

    # Given a data collection name, a reference to the doc being changed, the author of the change
    #   and any special options, build the base version doc nearly suitable for saving. The @"content"@
    #   key of the version doc will not be filled in, and must be done by the calling code.
    # @param [String] docCollName The name of the data collection from which the doc has been removed.
    # @param [BSON::DBRef] docRef The reference pointing to the [now deleted] document.
    # @param [String] author The Genboree username of the author.
    # @param [Hash] opts An optional hash containing the names of versioning record fields
    #   mapped to values. Used for overriding the defaults provided by {#docTemplate}. Things like
    #   @"deletion"@, @"comment"@, @"label"@ which are normally nil, empty, or false, etc.
    # @return [KbDoc] the base version doc
    # @raise [ArgumentError] when there is no versioning collection for @docCollName@ or no metadata document
    #   available for @docCollName@.
    def buildBaseHistoryDoc(docCollName, docRef, author, opts)
      versionDoc = nil
      # Need the metadata document for docCollName
      collMetadataHelper = @kbDatabase.collMetadataHelper()
      docCollMetadata = collMetadataHelper.metadataForCollection(docCollName)
      if(docCollMetadata)
        if(docCollMetadata.getPropVal( "name.versions" ))
          #   a. Get current version document, if any, or make new from template
          versionDoc = ( currentVersion(docRef) or docTemplate() )
          #   b. Increment and get version counter, use in new version document
          newVersionNum = nextVersionNum()
          prevVersionNum = versionDoc.getPropVal("versionNum")
          #   c. Fill in rest of template with prev version info and whatnot
          versionDoc.delete("_id")
          versionDoc.setPropVal("versionNum", newVersionNum)
          versionDoc.setPropVal("versionNum.prevVersion", prevVersionNum)
          versionDoc.setPropVal("versionNum.docRef", docRef) unless(versionDoc.getPropVal("versionNum.docRef"))
          versionDoc.setPropVal("versionNum.timestamp", Time.now)
          versionDoc.setPropVal("versionNum.author", author)
          #     (stuff from opts)
          versionDoc.setPropVal("versionNum.label", opts["label"]) if(opts["label"])
          versionDoc.setPropVal("versionNum.comment", opts["comment"]) if(opts["comment"])
          versionDoc.setPropVal("versionNum.deletion", (opts["deletion"] or false))
          versionDoc.setPropVal("versionNum.tags", (opts["tags"] or [ ]))
        else
          raise ArgumentError, "ERROR: There is no versions collection for #{docCollName.inspect} collection. Cannot create a version document for it! Maybe it's a core collection which has no versioning (some don't) or it was created OUTSIDE the GenboreKB framework, probably without using our Ruby library infrastructure & support classes."
        end
      else
        raise ArgumentError, "ERROR: There is no metadata document in kbColl.metadata for the #{docCollName.inspect} collection. It seems to have been created OUTSIDE the GenboreeKB framework, probably without using our Ruby library infrastructure & support classes."
      end
      return versionDoc
    end

    # Get a document template suitable for the collection this helper assists with.
    # @note The template should be filled in with sensible and convenient default
    #   values, but the calling code will have to fill in appropriate values to
    #   make it match the collection's model and possibily other constraints.
    # @param [nil, Object] Additional parameters, if any, that can help fill out
    #   the template. For example, the model document for the collection of interest.
    # @return [Hash] the document template, partly filled in.
    def docTemplate(*params)
      retVal =
      {
        "versionNum"  => { "value" => 0, "properties" =>
        {
          "docRef"      => { "value" => nil },
          "prevVersion" => { "value" => 0 },
          "author"      => { "value" => nil },
          "timestamp"   => { "value" => Time.now },
          "deletion"    => { "value" => false },
          "label"       => { "value" => nil },
          "comment"     => { "value" => nil },
          "tags"        => { "value" => nil, "items" => [ ] },
          "content"     => { "value" => nil }
        }}
      }
      retVal =  BRL::Genboree::KB::KbDoc.new(retVal)
      return retVal
    end
    
    # Helper method used by AbstractHelper to prepare a document for bulk inserting
    # @param [BSON::DBRef] docRef The reference pointing to the document.
    # @param [Object] doc The new content to fill in the version doc
    # @param [String] author The Genboree username of the author.
    # @param [Hash] docRefToCurrVerMap A mapping of docRefs to their current version number
    # @param [Hash] opts An optional hash containing the names of versioning record fields
    #   mapped to values. Used for overriding the defaults provided by {#docTemplate}. Things like
    # @return [Hash, KbDoc] versionDoc The new version doc to insert for the provided user doc.
    def prepareDocForBulkOperation(docRef, doc, author, docRefToCurrVerMap, opts={})
      raise "opts Hash does not have :count key. Cannot add versionNum." if(!opts.key?(:count))
      versionDoc = docTemplate()
      currNum = docRefToCurrVerMap[docRef]
      if(!currNum.nil?)
        versionDoc.setPropVal("versionNum.prevVersion", currNum)
      end
      tt = Time.now
      versionDoc.setPropVal("versionNum", opts[:count])
      versionDoc.setPropVal("versionNum.docRef", docRef)
      versionDoc.setPropVal("versionNum.timestamp", Time.now)
      versionDoc.setPropVal("versionNum.author", author)
      #     (stuff from opts)
      versionDoc.setPropVal("versionNum.label", opts["label"]) if(opts["label"])
      versionDoc.setPropVal("versionNum.comment", opts["comment"]) if(opts["comment"])
      versionDoc.setPropVal("versionNum.deletion", (opts["deletion"] or false))
      versionDoc.setPropVal("versionNum.tags", (opts["tags"] or [ ]))
      versionDoc.setPropVal('versionNum.content', doc)
      return versionDoc
    end
    
    def getDocRefsToCurrVersionMap(docRefs, collName)
      docRefsToVer = {}
      docObjIdsToDocRefs = {}
      docRefs.each {|docRef|
        docRefsToVer[docRef] = nil
        docObjIdsToDocRefs[docRef.object_id] = docRef
      }
      cursor = @kbDatabase.db[collName].aggregate( [ { "$match" =>  { "versionNum.properties.docRef.value" => { "$in" => docRefs }  }  }, {  "$group" => { "_id" => "$versionNum.properties.docRef.value", "maxVer" => { "$max" => "$versionNum.value" } }  }   ], :cursor => { "batchSize" => 100 }  )
      cursor.each {|doc|
        docRef = docObjIdsToDocRefs[doc['_id'].object_id]
        docRefsToVer[docRef] = doc["maxVer"].to_i
      }
      return docRefsToVer
    end

    # @todo Method to put new {data}.versions document in kbModels (just a copy)
  end # class VersionsHelper
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers
