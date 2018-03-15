#!/bin/env ruby

require 'brl/genboree/kb/helpers/abstractHelper'

module BRL ; module Genboree ; module KB ; module Helpers
  # This class assists with managing the versioning documents of any collection.
  # @note Unlike other {AbstractHelper} sub-classes, the name of the underlying
  #   collection is NOT known ahead of time. It is named after the doc collection
  #   the versioning is being done for. That collection name is determined dynamically
  #   when you instantiate this class.
  class VersionsHelper < AbstractHelper
    MEMOIZED_INSTANCE_METHODS = [
      :getDataCollRootProp
    ]
    # @return [String] The name of the core GenboreeKB collection the helper assists with.
    KB_CORE_COLLECTION_NAME = "{docColl}.versions"
    # @return [Array<Hash>] An array of MongoDB index config hashes; each has has key @:spec@ and @:opts@
    attr_accessor :incTimeCount
    # @return [String] The name of the data/doc collection whose version this instance helps with. NOT
    #   the same as @coll.name which the collection which contains the version records.
    attr_reader :dataCollName

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
        :spec => [ [ 'versionNum.properties.docRef.value', Mongo::ASCENDING ], [ 'versionNum.value', Mongo::DESCENDING ] ],
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
        :opts => { :background => true, :unique => true }
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

    PREDEFINED_VERS = [ :curr, :head, :prev ]
    CORE_DOC_PROPS = [ 'versionNum.value', 'versionNum.properties.docRef.value', 'versionNum.properties.prevVersion.value', 'versionNum.properties.author.value', 'versionNum.properties.timestamp.value', 'versionNum.properties.deletion.value', 'versionNum.properties.label.value', 'versionNum.properties.comment.value', 'versionNum.properties.tags.value' ]

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
      tt = Time.now
      super(kbDatabase, docCollName)
      @dataCollName = ( docCollName.is_a?(Mongo::Collection) ? docCollName.name : docCollName )
      unless(docCollName.is_a?(Mongo::Collection))
        @coll = @kbDatabase.getCollection(docCollName, :versions)
      end
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Instantiated with mongo db support from #{kbDatabase.class}:#{kbDatabase.object_id}, for coll argument #{docCollName.inspect} ; @dataCollName = #{@dataCollName.inspect} ; @coll.name = #{@coll.name.inspect rescue '[NONE!]'} ; in #{Time.now.to_f - tt.to_f} sec " )
    end

    # Returns the current version number from the global counter.
    # @return [Fixnum] The current version number.
    def currentVersionNum()
      globalsHelper = @kbDatabase.globalsHelper()
      return globalsHelper.globalCounterValue('versionNum')
    end

    # Generates and returns the next version number from the global counter. i.e.
    #   increments and returns the version number global counter.
    # @return [Fixnum] The next version number.
    def nextVersionNum()
      globalsHelper = @kbDatabase.globalsHelper()
      return globalsHelper.incGlobalCounter('versionNum')
    end
    
    # Generates and returns the version number incermented by the specified value from the global counter. i.e.
    #   increments and returns the version number global counter.
    # @param [Integer] nn positive number by which you want to increment by
    # @return [Fixnum] The next version number.
    def incVersionNumByN(nn)
      globalsHelper = @kbDatabase.globalsHelper()
      return globalsHelper.incGlobalCounterByN('versionNum', nn)
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
          @idPropName = modelsHelper.getRootProp( self.class.getModelTemplate(@dataCollName) )
        end
        idPropName = @idPropName
      else # some other collection than ours ; must be a real collection that has actual model doc, not .versions or .revisions
        idPropName = super( collName )
      end
      return idPropName
    end
    alias_method( :getRootProp, :getIdentifierName )

    def getDataCollRootProp()
      return getRootProp( @dataCollName )
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
    def currentVersion(docId, docCollName=@dataCollName, opts={})
      # If docId is already a BSON::DBRef, we will ignore docCollName (not needed) and use directly with getCurrVersionDoc()
      if( docId.is_a?(BSON::DBRef) )
        docRef = docId
      elsif( docId and docCollName == @dataCollName )
        docId = BSON::ObjectId.interpret(docId)
        docRef = BSON::DBRef.new(docCollName, docId)
      else
        # Must have both docId which needs to be some kind of doc _id value AND docCollName
        raise ArgumentError, "ERROR: method called incorrectly. Either provide JUST a BSON::DBRef or BOTH a docId type object + the appropriate collection name. It's an error to use this instance--created to help with versioning of #{@dataCollName.inspect}--to get version records from some OTHER collection; use a separate VersionHelper instance for that."
      end

      return getCurrVersionDoc( docRef, opts[:fields] )

      # OLD. Now uses getCurrVersionDoc()
      # if(docId.is_a?(BSON::DBRef) and docCollName.nil?)
      #   docRef = docId
      #   docCollName = docRef.namespace
      # elsif(docId and docCollName) # need to construct a docRef
      #   docId = BSON::ObjectId.interpret(docId)
      #   docRef = BSON::DBRef.new(docCollName, docId)
      # else
      #   raise ArgumentError, "ERROR: method called incorrectly. Either provide JUST a BSON::DBRef or BOTH a docId type object + the appropriate collection name."
      # end
      # historyCollName = self.class::historyCollName(docCollName)
      # historyDoc = @kbDatabase.db[historyCollName].find_one({ 'versionNum.properties.docRef.value' => docRef }, { :sort => [ 'versionNum.value', Mongo::DESCENDING ], :limit => 1 })
      # return historyDoc
    end

    # OVERRIDDEN. Because we need to use @dataCollName not @coll.name
    def dbRefFromRootPropVal( docName, unused=nil )
      return super( docName, @dataCollName )
    end

    # @param [BSON:DBRef, String] docNameOrDbRef Either the unique documewnt id (root prop val) for the DATA document you want
    #   version info about, or the DATA document's BSON::DBRef. The latter is best, of course, especially if you got it for
    #   REUSE in multple calls.
    # @param [Array,nil] fields List of MONGO fields--not KbDoc prop paths--that you only want from the version rec.
    # @return [BRL::Genboree::KB::KbDoc, nil]
    def getCurrVersionDoc( docNameOrDbRef, fields=nil )
      # Prevent loss of full general/parent field output due to presence of a more specific field (mongo 2.x bug)
      fields = reduceProjectionFields( fields )
      if( docNameOrDbRef.is_a?( BSON::DBRef ) )
        dbRef = docNameOrDbRef
      else # is doc "name" (aka doc ID...root property value)
        dbRef = dbRefFromRootPropVal( docNameOrDbRef )
      end

      queryDoc = {
        'versionNum.properties.docRef.value' => dbRef
      }
      qopts = { :sort => ['versionNum.value', Mongo::DESCENDING], :limit => 1 }
      qopts[:fields] = fields if( fields )
      historyDoc = @coll.find_one( queryDoc, qopts )
      return ( historyDoc ? BRL::Genboree::KB::KbDoc.new( historyDoc ) : historyDoc )
    end

    # @param [BSON:DBRef, String] docNameOrDbRef Either the unique documewnt id (root prop val) for the DATA document you want
    #   version info about, or the DATA document's BSON::DBRef. The latter is best, of course, especially if you got it for
    #   REUSE in multple calls.
    # @return [Numeric]
    def getCurrVersionNum( docNameOrDbRef )
      if( docNameOrDbRef.is_a?( BSON::DBRef ) )
        dbRef = docNameOrDbRef
      else # is doc "name" (aka doc ID...root property value)
        dbRef = dbRefFromRootPropVal( docNameOrDbRef )
      end

      # Make sure to use getCurrVersionDoc with just the field needed. Faster.
      # Make sure to use getCurrVersionDoc with just the field needed. Faster.
      # * Best practice is min # fields.
      # * Consider that the "content" field can be a massive data doc, so even for this 1 ver record, it's smart
      historyDoc = getCurrVersionDoc( docNameOrDbRef, 'versionNum.value' )

      return ( historyDoc ? historyDoc.getRootPropVal : historyDoc )
    end

    # @todo We would LIKE to employ versionNum.prevVersion but it is NOT being correctly maintained.
    #   When fixed, update the implementation below to get the current doc and follow prevVersion?
    # @param [BSON:DBRef, String] docNameOrDbRef Either the unique documewnt id (root prop val) for the DATA document you want
    #   version info about, or the DATA document's BSON::DBRef. The latter is best, of course, especially if you got it for
    #   REUSE in multple calls.
    # @param [Array,nil] fields List of MONGO fields--not KbDoc prop paths--that you only want from the version rec.
    # @return [BRL::Genboree::KB::KbDoc, nil]
    def getPrevVersionDoc( docNameOrDbRef, fields=nil )
      # Prevent loss of full general/parent field output due to presence of a more specific field (mongo 2.x bug)
      fields = reduceProjectionFields( fields )
      if( docNameOrDbRef.is_a?( BSON::DBRef ) )
        dbRef = docNameOrDbRef
      else # is doc "name" (aka doc ID...root property value)
        dbRef = dbRefFromRootPropVal( docNameOrDbRef )
      end

      queryDoc = {
        'versionNum.properties.docRef.value' => dbRef
      }
      qopts = { :sort => ['versionNum.value', Mongo::DESCENDING], :limit => 2 }
      qopts[:fields] = fields if( fields )
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "queryDoc: #{queryDoc.inspect} ; qopts: #{qopts.inspect}")
      historyDocCursor = @coll.find( queryDoc, qopts )
      retVal = nil
      if( historyDocCursor )
        1.times { |ii| historyDocCursor.next }
        retVal = historyDocCursor.next
      end
      return ( retVal ? BRL::Genboree::KB::KbDoc.new(retVal) : nil )
    end

    # @todo We would LIKE to employ versionNum.prevVersion but it is NOT being correctly maintained.
    #   When fixed, update the implementation below to get the current doc and simply return the prevVersion?
    # @param [BSON:DBRef, String] docNameOrDbRef Either the unique documewnt id (root prop val) for the DATA document you want
    #   version info about, or the DATA document's BSON::DBRef. The latter is best, of course, especially if you got it for
    #   REUSE in multple calls.
    # @return [Numeric, nil]
    def getPrevVersionNum( docNameOrDbRef )
      if( docNameOrDbRef.is_a?( BSON::DBRef ) )
        dbRef = docNameOrDbRef
      else # is doc "name" (aka doc ID...root property value)
        dbRef = dbRefFromRootPropVal( docNameOrDbRef )
      end

      # Make sure to use getCurrVersionDoc with just the field needed. Faster.
      # * Best practice is min # fields.
      # * Consider that the "content" field can be a massive data doc, so even for this 1 ver record, it's smart
      historyDoc = getPrevVersionDoc( docNameOrDbRef, 'versionNum.value' )

      return ( historyDoc ? historyDoc.getRootPropVal : historyDoc )
    end

    # Convenience method. In addititon to numeric versions also knows about string/symbol ones like
    #   'CURR' or 'HEAD' or :prev. Useful in API handlers and similar code.
    # @param [Symbol, String, Numeric] version A known version Symbol, or a corresponding String, or a specific version number.
    # @param [BSON::DBRef] dbRef The doc ref for the DATA document. Good to work with that, especially with versions. You can
    #   get it for your DATA document via the doc's root prop value (doc ID) from this Helper class via dbRefFromRootPropVal()
    #   and then reuse it in many methods like this one!
    # @param [Array,nil] fields List of MONGO fields--not KbDoc prop paths--that you only want from the version rec.
    # @return [BRL::Genboree::KB::KbDoc, nil]
    def getVersionDoc( version, dbRef, fields=nil )
      # Prevent loss of full general/parent field output due to presence of a more specific field (mongo 2.x bug)
      fields = reduceProjectionFields( fields )
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "version: #{version.inspect} ; fields arg: #{fields.inspect}")
      # Prevent loss of full general/parent field output due to presence of a more specific field (mongo 2.x bug)
      fields = reduceProjectionFields( fields )
      tt = Time.now
      versionDoc = nil
      unless( version.is_a?(Symbol) or version.is_a?(Numeric) )
        version = version.to_s.strip.downcase
        version = version.to_sym unless(version.empty?)
      end

      if( version.is_a?(Symbol) ) # Should be a symbol of some kind now unless problem converting
        if( PREDEFINED_VERS.include?( version) )
          if( version == :prev )
            versionDoc = getPrevVersionDoc( dbRef, fields )
          else # ( @version == 'CURR' or @version == 'HEAD' )
            versionDoc = getCurrVersionDoc( dbRef, fields )
          end
        else
          raise ArgumentError, "ERROR: version Symbol #{version.isnpect} is not one of the supported predefined version Symbols (#{PREDEFINED_VERS.inspect})."
        end
      else # specific version doc number, not special keyword
        qopts = { :fields => fields }
        $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "qopts, including fields: #{qopts.inspect} ")
        versionDoc = getVersion( version, dbRef, nil, qopts )
      end

      $stderr.debugPuts(__FILE__, __method__, 'TIME', "got specifically #{version.inspect} versionDoc record (or only desiredFields of the record) as a #{versionDoc.class} in #{Time.now.to_f - tt.to_f} ; has these prop paths:\n\t#{versionDoc.allPaths.inspect rescue '[FAIL]'}\n\n") ; tt = Time.now

      return versionDoc
    end

    # Convenience method. In addititon to numeric versions also knows about string/symbol ones like
    #   'CURR' or 'HEAD' or :prev. Useful in API handles and similar code
    # @param [Symbol, String, Numeric] version A known version Symbol, or a corresponding String, or
    #   a specific version number (um, why call this method if you already have the number?)
    # @param [BSON::DBRef] dbRef The doc ref for the DATA document. Good to work with that, especially with versions. You can
    #   get it for your DATA document via the doc's root prop value (doc ID) from this Helper class via dbRefFromRootPropVal()
    #   and then reuse it in many methods like this one!
    # @return [Numeric, nil]
    def getVersionNum( version, dbRef )
      tt = Time.now
      versionNum = nil
      unless( version.is_a?(Symbol) or version.is_a?(Numeric) )
        version = version.to_s.strip.downcase
        version = version.to_sym unless(version.empty?)
      end

      if( version.is_a?(Symbol) ) # Should be a symbol of some kind now unless problem converting
        if( PREDEFINED_VERS.include?( version) )
          if( version == :prev )
            versionNum = getPrevVersionNum( dbRef )
          else # ( @version == 'CURR' or @version == 'HEAD' )
            versionNum = getCurrVersionNum( dbRef )
          end
        else
          raise ArgumentError, "ERROR: version Symbol #{version.inspect} is not one of the supported predefined version Symbols (#{PREDEFINED_VERS.inspect})."
        end
      else # specific version doc number, not special keyword...wth? why asking if you already have one?
        versionNum = version.to_s.to_i
      end

      $stderr.debugPuts(__FILE__, __method__, 'TIME', "got specifically #{version.inspect} versionNum (or only desiredFields of the record) - #{Time.now.to_f - tt.to_f}") ; tt = Time.now

      return versionNum
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
    # @return [KbDoc, nil] the versioning doc associated with versionNum for the document of interest.
    def getVersion(versionNum, docId, docCollName=@dataCollName, opts={})
      fields = opts[:fields]
      # Prevent loss of full general/parent field output due to presence of a more specific field (mongo 2.x bug)
      fields = reduceProjectionFields( fields )
      if(docId.is_a?(BSON::DBRef) and docCollName.nil?) # Already have dbRef. Get collection name out of it.
        docRef = docId
      elsif(docId and docCollName == @dataCollName ) # need to construct a docRef
        docId = BSON::ObjectId.interpret(docId)
        docRef = BSON::DBRef.new(docCollName, docId)
      else
        raise ArgumentError, "ERROR: method called incorrectly. Either provide JUST a BSON::DBRef or BOTH a docId type object + the appropriate collection name. It's an error to use this instance--created to help with versioning of #{@dataCollName.inspect}--to get version records from some OTHER collection; use a separate VersionHelper instance for that."
      end
      queryDoc = {
        'versionNum.properties.docRef.value' => docRef,
        'versionNum.value' => versionNum
      }
      # Why 2 queries?
      qopts = { :limit => 1 }
      qopts[:fields] = fields if( fields )
      historyDoc = @coll.find_one(queryDoc, qopts)
      return ( historyDoc ? BRL::Genboree::KB::KbDoc.new(historyDoc) : historyDoc )
    end

    # Checks existence of a user document by the identifier value of the actual document stored in the 'content' field.
    # @todo This is stupid, why does exists?() return a DOC and not true|false like name indicates? Encourages bad dev
    # @todo Also there is too much unneeded info provided that could be looked up fast: indentProp, docCollName
    # @todo Probably delete this method.
    #   practices like using this to get a version doc of interest, which we've seen some lazy devs do! The implementation
    #   appears to be a slow version of getCurrVersionDoc().
    # @Param [String] identProp Not needed in faster version.
    # @param [String] docName
    # @param [String] docCollName
    # @return [KbDoc] the versioning doc associated with versionNum for the document of interest.
    def exists?(identProp, docName, docCollName)
      raise "DEPRECATED. This method was implemented in a ridiculous way, and also was NOT returning true/false as expected by the ?, which led to developers abusing it to [very slowly, 14 secs in some cases] get the current version record. No more."
    end

    # Gets the count for all version docs for a document of interest
    #   @param (see BSON::ObjectId.interpret)
    #   @param [String] docCollName The name of the data collection.
    #   @param [Hash{Symbol,Object}] opts Additional options.
    #     @option opts [Fixnum] :minDocVersion Only count version that are greater than or equal to this version.
    # @return [Fixnum] Number of version docs for the doc
    def versionCount(docId, docCollName=@dataCollName, opts={})
      minDocVersion = opts[:minDocVersion]
      if(docId.is_a?(BSON::DBRef) and docCollName.nil?)
        docRef = docId
        docCollName = docRef.namespace
      elsif(docId and docCollName == @dataCollName) # need to construct a docRef
        docId = BSON::ObjectId.interpret(docId)
        docRef = BSON::DBRef.new(docCollName, docId)
      else
        raise ArgumentError, "ERROR: method called incorrectly. Either provide JUST a BSON::DBRef or BOTH a docId type object + the appropriate collection name. It's an error to use this instance--created to help with versioning of #{@dataCollName.inspect}--to get version records from some OTHER collection; use a separate VersionHelper instance for that."
      end
      # Build selector
      selector = { 'versionNum.properties.docRef.value' => docRef }
      if(minDocVersion)
        selector['versionNum.value'] = { '$gte' => minDocVersion.to_i }
      end
      docCount = @coll.find( selector ).count(false)
      return docCount.to_i
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
    # @param [Hash] opts An optional hash containing search options such as :limit and :skip
    # @return [Array<KbDoc>] all the versioning records for doc of interest. Should automatically
    #   be from newest->oldest due to the multi-field index with the descending index on @versionNum@.
    def allVersions(docId, docCollName=@dataCollName, opts={})
      if(docId.is_a?(BSON::DBRef) and docCollName.nil?)
        docRef = docId
        docCollName = docRef.namespace
      elsif(docId and docCollName == @dataCollName) # need to construct a docRef
        docId = BSON::ObjectId.interpret(docId)
        docRef = BSON::DBRef.new(docCollName, docId)
      else
        raise ArgumentError, "ERROR: method called incorrectly. Either provide JUST a BSON::DBRef or BOTH a docId type object + the appropriate collection name. It's an error to use this instance--created to help with versioning of #{@dataCollName.inspect}--to get version records from some OTHER collection; use a separate VersionHelper instance for that."
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "docRef:\n\n#{docRef.inspect}")
      cursor = @coll.find({'versionNum.properties.docRef.value' => docRef}, opts)
      resultSet = []
      cursor.each { |doc|
        resultSet << BRL::Genboree::KB::KbDoc.new(doc)
      }
      cursor.close() unless(cursor.closed?)
      return resultSet
    end

    # @note No dataCollName arg since this method (all methods) should work ONLY on the specific
    #   @dataCollName or the appropriate versions collecton. Kept in other methds for backwards compatibility.
    def allVersionsByRootPropVal( docID, opts={} )
      dbRef = dbRefFromRootPropVal( docID )
      return allVersions( dbRef, @dataCollName, opts )
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
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "BASE VERSION DOC created:\n\n#{JSON.pretty_generate(versionDoc) rescue '[failed]'}")
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
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "BASE VERSION DOC created:\n\n#{JSON.pretty_generate(versionDoc) rescue '[failed]'}")
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
          $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "curr version num for docRef #{docRef.inspect}: #{getCurrVersionNum(docRef).inspect}")
          versionDoc = ( getCurrVersionDoc(docRef) or docTemplate() )
          #   b. Increment and get version counter, use in new version document
          newVersionNum = nextVersionNum()
          # @todo Is this working correctly? Each new history doc should be linked to the prior one.
          prevVersionNum = versionDoc.getPropVal('versionNum')
          #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "newVersionNum will be #{newVersionNum.inspect} ; prev version num based on retreived/constructed versionDoc: #{prevVersionNum.inspect}")
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
      # Possibly bug resulting in wrong prevVersionNum? dunno. Let's get it dynamically, it's pretty fast now for a DBRef.
      #currNum = docRefToCurrVerMap[docRef]
      currNum = getCurrVersionNum( docRef )
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
    
    def getDocRefsToCurrVersionMap(docRefs, collName=@coll.name)
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

    # ----------------------------------------------------------------
    # MEMOIZE now-defined methods
    # . We override some of the parent methods here, so seems like have to re-memoize.
    # . We do this by adding our memoized methods to the list from AbstractHelper
    # ----------------------------------------------------------------
    (self::MEMOIZED_INSTANCE_METHODS + BRL::Genboree::KB::Helpers::AbstractHelper::MEMOIZED_INSTANCE_METHODS).each { |meth| memoize meth }
  end # class VersionsHelper
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers
