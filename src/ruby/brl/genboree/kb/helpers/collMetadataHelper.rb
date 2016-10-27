#!/bin/env ruby

require 'brl/genboree/kb/helpers/abstractHelper'

module BRL ; module Genboree ; module KB ; module Helpers
  # This class assists with the metadata for each collection.
  # @note Every collection in the GenboreeKB MongoDB database must have a
  #   metadata document in the @kbColl.metadata@ collection.
  class CollMetadataHelper < AbstractHelper
    # @return [String] The name of the core GenboreeKB collection the helper assists with.
    KB_CORE_COLLECTION_NAME = "kbColl.metadata"
    # @return [Array<Hash>] An array of MongoDB index config hashes; each has has key @:spec@ and @:opts@
    #   the indices for the metadata documents in this collection.
    KB_CORE_INDICES =
    [
      # Index each metadata doc by its "name", which will match the name of a data collection.
      {
        :spec => 'name.value',
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
        "internal"  => { "value" => true },
        "model"     => { "value" => nil, "items" =>
        [
          {
            "name"        => "name",
            "description" => "The name of the collection this metadata is about.",
            "identifier"  => true,
            "properties"  =>
            [
              {
                "name"        => "internal",
                "description" => "A flag indicating whether the collection is for internal KB usage or for user data.",
                "domain"      => "boolean",
                "default"     => false
              },
              {
                "name"        => "description",
                "description" => "A description of the collection this metadata is about."
              },
              {
                "name"        => "status",
                "description" => "The current status of the collection.",
                "domain"      => "enum(created,frozen,deleted)",
                "required"    => true,
                "properties"    =>
                [
                  {
                    "name"        => "user",
                    "description" => "The Genboree user name who put the collection into this state.",
                    "required"    => true
                  },
                  {
                    "name"        => "date",
                    "description" => "The timestamps when the collection status was last changed.",
                    "domain"      => "timestamp",
                    "required"    => true
                  }
                ]
              },
              {
                "name"        => "versions",
                "description" => "The name of the versioning collection for this collection."
              },
              {
                "name"        => "revisions",
                "description" => "The name of the revisioning collection for this collection."
              },
              {
                "name"        => "labels",
                "domain"      => "[valueless]",
                "description" => "Singular and plural labels to use for the collection.",
                "properties"  =>
                [
                  {
                    "name" => "plural",
                    "description" => "Label to use for plural entities in the collection."
                  },
                  {
                    "name" => "singular",
                    "description" => "Label to use for sigular entity in the collection."
                  }
                ]
              },
              {
                "name"        => "tools",
                "domain"      => "[valueless]",
                "description" => "List of tools associated with the collection. Can be at collection level or doc level",
                "properties"  =>
                [
                  {
                    "name" => "collection",
                    "description" => "List of Collection level tools.",
                    "items" => [
                      {
                        "name" => "tool",
                        "properties" => [
                          {
                            "name" => "shortLabel"  
                          },
                          {
                            "name" => "longLabel"
                          },
                          {
                            "name" => "toolIdStr"
                          },
                          {
                            "name" => "description"
                          }
                        ]
                      }
                      
                    ]
                  },
                  {
                    "name" => "doc",
                    "description" => "List of Document level tools.",
                    "items" => [
                      {
                        "name" => "tool",
                        "properties" => [
                          {
                            "name" => "shortLabel"  
                          },
                          {
                            "name" => "longLabel"
                          },
                          {
                            "name" => "toolIdStr"
                          },
                          {
                            "name" => "description"
                          }
                        ]
                      }
                    ]
                  }
                ]
              },
              {
                "name"        => "counters",
                "domain"      => "[valueless]",
                "description" => "A set of counter types, each with a list of counters of that type",
                "properties"  => [
                  {
                    "name" => "autoID",
                    "description" => "A list of counters for autoID domains",
                    "items" => [
                      "name" => "propPath",
                      "properties" => [
                        {
                          "name" => "count",
                          "domain" => "posInt"
                        }
                      ]
                    ]
                  }
                ]
              }
            ]
          }
        ]}
      }
    }}
    
    # @!attribute [rw] pluralLabel
    #   @return [String]  
    attr_accessor :pluralLabel
    
    # @!attribute [rw] singularLabel
    #   @return [String] 
    attr_accessor :singularLabel

    # Create new instance of this helper.
    # @param [MongoKbDatabase] kbDatabase The KB database object this helper is assisting.
    # @param [String] collName The name of the document collection this helper uses.
    def initialize(kbDatabase, collName=self.class::KB_CORE_COLLECTION_NAME)
      super(kbDatabase, collName)
      unless(collName.is_a?(Mongo::Collection))
        # Avoid lazy create of a collection
        # - can't use getCollection() based methods here, as appropriate for other helpers
        #   because database may not exist yet, but we need a working kbColl.metadata collection
        #   to support creation and those getCollection() calls ets.
        if(@kbDatabase.db and @kbDatabase.db.collections_info(collName).count == 1)
          @coll = @kbDatabase.db[collName]
        end
      end
      # Set default collection labels
      @pluralLabel = "Documents"
      @singularLabel = "Document"
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

    # Get the metadata document for a collection of interest.
    # @param [String] collName The name of a collection of interest.
    # @param [Boolean] forceRefresh If @true@, then rather than getting the document about the collection of
    #   interest from cache (it was cached when previously asked for), get it fresh from the database.
    # @return [KbDoc] the metadata document for the collection of interest.
    def metadataForCollection(dataCollName, forceRefresh=false)
      return self.docForCollection(dataCollName, "name.value", forceRefresh)
    end

    # Get the {Mongo::Collection} containing the version documents for a collection of interest.
    # @param [String] dataCollName The name of a collection of interest.
    # @return [Mongo::Collection] the versions collection for the collection of interest.
    def versionsCollectionForCollection(dataCollName)
      return historyCollectionForCollection(dataCollName, :versions)
    end

    # Get the {Mongo::Collection} containing the revision documents for a collection of interest.
    # @param [String] collName The name of a collection of interest.
    # @return [Mongo::Collection] the revisions collection for the collection of interest.
    def revisionsCollectionForCollection(dataCollName)
      return historyCollectionForCollection(dataCollName, :revisions)
    end

    # Get the {Mongo::Collection} containing history documents for a collection of interest.
    # @param [String] dataCollName The name of a collection of interest.
    # @param [Symbol] historyType The type of history document you are intersted in for
    #   the collection of interest: @:versions@ or @:revisions@
    # @return [Mongo::Collection] the history collection for the collection of interest.
    # @raise [KbError] there is no such data colleciton @dataCollName@ or @historyType@ collection available for it.
    def historyCollectionForCollection(dataCollName, historyType)
      retVal = nil
      if(historyType == :versions)
        collName = VersionsHelper.historyCollName(dataCollName)
      elsif(historyType == :revisions)
        collName = RevisionsHelper.historyCollName(dataCollName)
      else
         raise KbError, "ERROR: there is no #{historyType.inspect} type of collection in GenboreeKB databases."
      end
       # Avoid lazy create of a collection
      if(@kbDatabase.db.collections_info(collName).count == 1)
        retVal = @kbDatabase.db[collName]
      else
        raise KbError, "ERROR: there is no collection named #{collName.inspect}, which you are asking for."
      end
      return retVal
    end

    # Insert an appropriate metadata document for a collection. Generally
    #   done only once when the collection is created using this framework.
    # @param [String] docCollName The name of the collection of interest.
    # @param [String] author The Genboree username of the author. For core collections, this will
    #   be the name of the user with authentication access to the MongoDB (i.e. not a Genboree user)
    # @param [Boolean] cacheMetadataDoc Flag indicating whether to cache the metadata
    #   doc for later fast retrieval. Because rarely/never changes, no reason why not.
    # @param [Hash] opts Optional hash with additional parameters 
    # @return [BSON::ObjectId] The ObjectId for the saved metadata document.
    def insertForCollection(docCollName, author, cacheMetadataDoc=true, opts={})
      @singularLabel = ( opts.key?('singularLabel') ? opts['singularLabel'] : @singularLabel )
      @pluralLabel = ( opts.key?('pluralLabel') ? opts['pluralLabel'] : @pluralLabel )
      doc = docTemplate(docCollName, author)
      if(@kbDatabase.class::KB_CORE_COLLECTIONS.include?(docCollName))
        doc.setPropVal('name.internal', true)
      end
      # Save directly into the kbColl.metadata collection. There is no history handling
      # for collection metadata documents so no need to go through the usual route of self#save().
      docObjId = self.coll.save( doc.to_serializable() )
      # Cache the new doc for subsequent get requests.
      insertedDoc = @kbDatabase.docByRef(docObjId, @coll.name)
      @docForCollectionCache[docCollName]["name"] = insertedDoc if(cacheMetadataDoc)
      return docObjId
    end

    # Get a document template suitable for the collection this helper assists with.
    # @note The template should be filled in with sensible and convenient default
    #   values, but the calling code will have to fill in appropriate values to
    #   make it match the collection's model and possibily other constraints.
    # @param [String] collName The name of the data collection of interest. May
    #   be used to fill in key fields for collections that track info about other collections
    #   like @kbModels@ and @kbColl.metadata@.
    # @param [String] author The Genboree username of the author. For core collections, this will
    #   be the name of the user with authentication access to the MongoDB (i.e. not a Genboree user)
    # @param [Array, nil] params Additional parameters, if any, that can help fill out
    #   the template. For example, the model document for the collection of interest.
    # @return [KbDoc] the document template, partly filled in.
    def docTemplate(docCollName, author, *params)
      retVal =
      {
        "name"        => { "value" => docCollName, "properties" =>
        {
          "internal"    => false,
          "description" => { "value" => "This is the metadata doc for the #{docCollName.inspect} collection." },
          "status"      => { "value" => "created", "properties" =>
          {
            "user"    => { "value" => author },
            "date"    => { "value" => Time.now() }
          }},
          "labels"      => { "properties" => {
            "plural" => { "value" => @pluralLabel },
            "singular" => { "value" => @singularLabel }
          }}
        }}
      }
      retVal = BRL::Genboree::KB::KbDoc.new(retVal)
      # The kbColl.metadata collection itself (the one this Helper helps with)
      # has no versioning/revisioning collections.
      unless(MongoKbDatabase::KB_HISTORYLESS_CORE_COLLECTIONS.include?(docCollName))
        retVal.setPropVal( 'name.revisions', RevisionsHelper.historyCollName(docCollName) )
        retVal.setPropVal( 'name.versions', VersionsHelper.historyCollName(docCollName) )
      end
      return retVal
    end

    # -- Counters -- {{
    # Initialize the counters section of a user collection's metadata document
    # @param [String] collName the collection to add counters for
    # @return [NilClass, TrueClass] if true, operation successful; otherwise it was not
    # @todo possibly move this to be only part of a migration
    # @note will remove previously existing counters
    def initCounters(collName)
      rv = nil
      begin
        rv = @coll.find_and_modify({
          :query => {
            "name.value" => collName
          },
          :update => { "$set" => { "name.properties.counters" => { } } }
        })
        rv = true
      rescue Mongo::MongoDBError => err
        $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", "@coll.find_and_modify operation failed to add counters for collection #{collName.inspect}\n#{err.type}:#{err.message}\n#{err.backtrace.join("\n")}")
        rv = nil
      end
      return rv
    end

    # Replace "." with "\e" the "ESC" character
    # @todo enforce users not providing property paths with the ESC character in them
    def escapePropPath(propPath)
      propPath.gsub(".", "\e")
    end

    # Inverse of escapePropPath
    # @see escapePropPath
    def unescapePropPath(propPath)
      propPath.gsub("\e", ".")
    end

    # For the purpose of counters (and perhaps other unique properties), a property
    #   path referring to an index of an item list is generalized to instead refer
    #   to any item in an item list
    # @note we simply drop any array indexes so that we arrive at an equivalent
    #   general path regardess of whether or not the input @propPath@ is a
    #   model path or a doc path -- this only works because models may not
    #   specify both "properties" and "items" for a single property
    def generalizePropPath(propPath)
      propTokens = propPath.split(".")
      itemListRegex = /^\[\d*\]$/
      outTokens = []
      propTokens.each { |propToken|
        matchData = itemListRegex.match(propToken)
        if(!matchData)
          outTokens.push(propToken)
        end
      }
      return outTokens.join(".")
    end

    # Get a Mongo propery path for a counter in the metadata document for a collection given by
    #   a BRL property path @propPath@
    def getCountPath(propPath)
      genPropPath = generalizePropPath(propPath)
      escPropPath = escapePropPath(genPropPath)
      mongoCountPath = "name.properties.counters.properties.autoID.properties.#{escPropPath}.value"
      return mongoCountPath
    end

    # Get the current value for a counter in the metadata document for a collection @collName@
    #   and a BRL property path @propPath@
    # @return [Integer, NilClass] the value of the counter or nil if an error occurred
    def getCounter(collName, propPath)
      rv = nil
      mongoCountPath = getCountPath(propPath)
      begin
        opts = { :fields => [mongoCountPath] }
        mdDoc = @coll.find_one({
          "name.value" => collName
        }, opts)
        if(mdDoc.nil?)
          $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", "Could not find metadata document for collection #{collName.inspect} in Mongo database #{@kbDatabase.db.name.inspect}")
        else
          rv = mdDoc.getNestedAttr(mongoCountPath).to_i # nil if counter not found, to_i to 0
        end
      rescue Mongo::MongoDBError => err
        $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", "find operation failed. #{err.class}: #{err.message}\n#{err.backtrace.join("\n")}")
        rv = nil
      end
      return rv
    end

    # An atomic update/increment to a single counter
    # @param [String] collName the name of the data collection to update the counter for
    # @param [String] propPath the BRL propPath specifying which counter should be updated
    # @param [Integer] amount the magnitude of the counter increase
    # @return [NilClass, Integer] the previous value for the counter or nil if a failure occurs
    def updateCounter(collName, propPath, amount=1)
      # @todo remove these and use a future mongo path -> prop path
      genPropPath = generalizePropPath(propPath)
      escPropPath = escapePropPath(genPropPath)
      mongoCountPath = getCountPath(propPath)

      rv = nil
      begin
        rv = @coll.find_and_modify({ 
          :query => {
            "name.value" => collName
          },
          :update => { "$inc" => { mongoCountPath => amount }},
          :upsert => true
        })
        if(rv.nil?)
          # then collection doesnt exist or path doesnt exist
          $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", "Unable to update counter for propPath=#{propPath.inspect} in collection=#{collName.inspect} because the collection does not exist")
        else
          # then rv has the value of the found document before the update
          mdDoc = BRL::Genboree::KB::KbDoc.new(rv)
          counterVal = mdDoc.getPropVal("name.counters.autoID.#{escPropPath}") rescue nil
          rv = counterVal.nil? ? 0 : counterVal
        end
      rescue Mongo::MongoDBError => err
        $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", "find_and_modify operation failed. #{err.class}: #{err.message}\n#{err.backtrace.join("\n")}")
        rv = nil
      end
      return rv
    end

    # An atomic setting of a single counter
    # @param [Integer] counterVal the new value of the counter
    # @see updateCounter
    # @todo code reuse with updateCounter -- only query changes
    def setCounter(collName, propPath, counterVal)
      # @todo remove these and use a future mongo path -> prop path
      genPropPath = generalizePropPath(propPath)
      escPropPath = escapePropPath(genPropPath)
      mongoCountPath = getCountPath(propPath)

      rv = nil
      begin
        rv = @coll.find_and_modify({
          :query => {
            "name.value" => collName
          },
          :update => { "$set" => { mongoCountPath => counterVal } },
          :upsert => true
        })
        if(rv.nil?)
          # then collection doesnt exist or path doesnt exist
          $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", "Unable to update counter for propPath=#{propPath.inspect} in collection=#{collName.inspect} because the collection does not exist")
        else
          # then rv has the value of the found document before the update
          mdDoc = BRL::Genboree::KB::KbDoc.new(rv)
          counterVal = mdDoc.getPropVal("name.counters.autoID.#{escPropPath}") rescue nil
          rv = counterVal.nil? ? 0 : counterVal
        end
      rescue Mongo::MongoDBError => err
        $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", "find_and_modify operation failed. #{err.class}: #{err.message}\n#{err.backtrace.join("\n")}")
        rv = nil
      end
      return rv
    end

    # Sets counter to the max of the provided counter value and the one in the database already
    # @see setCounter
    # @todo code reuse?
    def setCounterToMax(collName, propPath, counterVal)
      # @todo remove these and use a future mongo path -> prop path
      genPropPath = generalizePropPath(propPath)
      escPropPath = escapePropPath(genPropPath)
      mongoCountPath = getCountPath(propPath)

      rv = nil
      begin
        rv = @coll.find_and_modify({
          :query => {
            "name.value" => collName
          },
          :update => { "$max" => { mongoCountPath => counterVal } },
          :upsert => true
        })
        if(rv.nil?)
          # then collection doesnt exist or path doesnt exist
          $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", "Unable to update counter for propPath=#{propPath.inspect} in collection=#{collName.inspect} because the collection does not exist")
        else
          # then rv has the value of the found document before the update
          mdDoc = BRL::Genboree::KB::KbDoc.new(rv)
          counterVal = mdDoc.getPropVal("name.counters.autoID.#{escPropPath}") rescue nil
          rv = counterVal.nil? ? 0 : counterVal
        end
      rescue Mongo::MongoDBError => err
        $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", "find_and_modify operation failed. #{err.class}: #{err.message}\n#{err.backtrace.join("\n")}")
        rv = nil
      end
      return rv
    end

    # }} -- End Counters --
  end # class CollMetadataHelper
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers
