#!/bin/env ruby
require 'json'
require 'yaml'
require 'uri'
require 'cgi'
require 'brl/extensions/bson' # BEFORE require 'mongo' or require 'bson'!
require 'mongo'
require 'bson'
require 'brl/util/util'
require 'brl/noSQL/mongoDb/mongoDbConnection'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/helpers/abstractHelper'
require 'brl/genboree/kb/helpers/collMetadataHelper'
require 'brl/genboree/kb/helpers/globalsHelper'
require 'brl/genboree/kb/helpers/modelsHelper'
require 'brl/genboree/kb/helpers/viewsHelper'
require 'brl/genboree/kb/helpers/versionsHelper'
require 'brl/genboree/kb/helpers/revisionsHelper'
require 'brl/genboree/kb/helpers/dataCollectionHelper'
require 'brl/genboree/kb/helpers/queriesHelper'
require 'brl/genboree/kb/helpers/transformsHelper'
require 'brl/genboree/kb/helpers/kbHelper'
require 'brl/genboree/kb/helpers/questionsHelper'
require 'brl/genboree/kb/helpers/templatesHelper'
require 'brl/genboree/kb/helpers/answersHelper'

module BRL ; module Genboree ; module KB
  # Exception class for errors relating to assumptions about the GenboreeKB
  #   and how MongoDB collections/documents are being used to implement it.
  class KbError < StandardError ; end

  # A class representing a specific GenboreeKB user database, backed by a MongoDB with
  #   certain key/core collections, assumptions concerning availability of data model documents,
  #   global counters, collection metadata documents, etc.
  class MongoKbDatabase
    include Mongo
    include BRL::Genboree::KB::Helpers

    # @return [Array] MongoDB roles that the db-access user should have in any newly created GenboreeKB DB
    KB_DB_ROLES = [ "readWriteAnyDatabase", "userAdminAnyDatabase", "dbAdminAnyDatabase", "clusterAdmin" ]
    # @return [Array] the core GenboreeKB collections used internally. Some/many will have versioning/revisioning
    #   collections as well. This is also the collection-creation order, since some should be created before others!
    KB_CORE_COLLECTIONS = [ "kbColl.metadata", "kbGlobals", "kbModels", "kbViews", "kbTransforms", "kbQueries", QuestionsHelper::KB_CORE_COLLECTION_NAME, TemplatesHelper::KB_CORE_COLLECTION_NAME, AnswersHelper::KB_CORE_COLLECTION_NAME]
    # @return [Array<String>] the list of core collections which have no history collections.
    KB_HISTORYLESS_CORE_COLLECTIONS = [ 'kbColl.metadata', 'kbGlobals']
    # @return [Hash] core collections mapped to a sub-class of {AbstractHelper}
    KB_CORE_COLLECTION2HELPER_CLASS =
    {
      "kbColl.metadata"         => CollMetadataHelper,
      "kbGlobals"               => GlobalsHelper,
      "kbModels"                => ModelsHelper,
      "kbModels.versions"       => VersionsHelper,
      "kbModels.revisions"      => RevisionsHelper,
      "kbViews"                 => ViewsHelper,
      "kbQueries"               => QueriesHelper,
      "kbQueries.versions"      => VersionsHelper,
      "kbQueries.revisions"     => RevisionsHelper,
      "kbViews.versions"        => VersionsHelper,
      "kbViews.revisions"       => RevisionsHelper,
      "kbTransforms"            => TransformsHelper,
      "kbTransforms.versions"   => VersionsHelper,
      "kbTransforms.revisions"  => RevisionsHelper,
      QuestionsHelper::KB_CORE_COLLECTION_NAME => QuestionsHelper,
      "#{QuestionsHelper::KB_CORE_COLLECTION_NAME}.versions" => VersionsHelper,
      "#{QuestionsHelper::KB_CORE_COLLECTION_NAME}.revisions" => RevisionsHelper,
      TemplatesHelper::KB_CORE_COLLECTION_NAME => TemplatesHelper,
      "#{TemplatesHelper::KB_CORE_COLLECTION_NAME}.versions" => VersionsHelper,
      "#{TemplatesHelper::KB_CORE_COLLECTION_NAME}.revisions" => RevisionsHelper,
      AnswersHelper::KB_CORE_COLLECTION_NAME => AnswersHelper,
      "#{AnswersHelper::KB_CORE_COLLECTION_NAME}.versions" => VersionsHelper,
      "#{AnswersHelper::KB_CORE_COLLECTION_NAME}.revisions" => RevisionsHelper
    }

    # @todo Move this to a .json or .yml file and load it (SingletonCache probably)
    # @todo These take the GLOBAL *write* lock, because they are run via db.eval(). NO other read nor write
    #   operations can happen on the whole mongo instance when such functions are called. MUST BE SHORT. But
    #   also, it's not really needed for "getGlobalCounter()", only for "incGlobalCounter()" (where it is
    #   VITAL). Probably should arrange  for the db.eval() call which use these to specify the nolock:true
    #   option for getGlobalCounter() ; see http://docs.mongodb.org/manual/reference/method/db.eval/#db.eval )
    # @return [Hash] server-side stored procedures mapped to MongoDB Javascript function text for
    #   all stored procedures that should be added to the @system.js@ collections of every new GenboreeKB DB.
    KB_DB_STORED_PROCEDURES =
    {
      "incGlobalCounter" => %q@
        function (counterName)
        {
          var retVal = null ;
          var doc = db.kbGlobals.findAndModify(
          {
            "query"   : { "counters.items" : { "$elemMatch" : { "name.value" : counterName }}},
            "update"  : { "$inc" : { "counters.items.$.count.value" : 1 } },
            "new"     : true
          }) ;
          if(doc) {
            var docItems = doc["counters"]["items"] ;
            for(var ii=0 ; ii < docItems.length; ii++) {
              var docItem = docItems[ii] ;
              if(docItem["name"]["value"] == counterName) {
                retVal = docItem["count"]["value"] ;
                break ;
              }
            }
          }
          return retVal ;
        }
      @,
      "incGlobalCounterByN" => %q@
        function (counterName, n)
        {
          var retVal = null ;
          var doc = db.kbGlobals.findAndModify(
          {
            "query"   : { "counters.items" : { "$elemMatch" : { "name.value" : counterName }}},
            "update"  : { "$inc" : { "counters.items.$.count.value" : n } },
            "new"     : true
          }) ;
          if(doc) {
            var docItems = doc["counters"]["items"] ;
            for(var ii=0 ; ii < docItems.length; ii++) {
              var docItem = docItems[ii] ;
              if(docItem["name"]["value"] == counterName) {
                retVal = docItem["count"]["value"] ;
                break ;
              }
            }
          }
          return retVal ;
        }
      @,
      "getGlobalCounter" => %q@
        function (counterName)
        {
          var doc = db.kbGlobals.findOne( { "counters.items" : { "$elemMatch" : { "name.value" : counterName }}}, { "counters.items.$" :  1 } ) ;

          return (doc ? doc["counters"]["items"][0]["count"]["value"] : null) ;
        }
      @
    }

    # @!attribute [rw] conn
    #   @return [BRL::NoSQL::MongoDbConnnection] an instance used to manage the MongoDB connection(s).
    attr_accessor :conn
    # @!attribute [r] name
    #   @return [String] the name of the MongoDB databse this instance is for
    attr_reader   :name
    # @!attribute [r] db
    #   @return [Mongo::DB] the {Mongo::DB} database object this instance uses
    attr_reader   :db
    # @!attribute [r] storedProcedures
    #   @return [Hash] of the server-side stored procedures found by actually querying the database.
    attr_reader   :storedProcedures
    # @!attribute [r] coll2helper
    #   @return [Hash] of collection names to actual instances of {AbstractHelper} sub-classes
    attr_reader   :coll2helper

    # This method constructs a unique MongoDB name for a MongoDB backing a GenboreeKB within a Group
    #   on a given Genboree host/instance. Very important that this name be unique, especially since
    #   1 MongoDB instance could server multiple Genboree hosts (e.g. dev & prod perhaps). Unlike the
    #   MySQL naming approach, the approach this method encourages is ~self-documenting but still unique.
    #   i.e. a safe version of @{hostName}-{groupName}-{kbName}@.
    # @note The string returned is something suitable for the INTERNAL-ONLY mongo database name. It is not
    #   exposed to users and nor do changes in the host, group, kbName have to be reflected here. The
    #   heuristic used here to generate a possible name should NOT be relied on as a convention for
    #   determining the actual internal mongo db name backing a {grp}/kb/{kb}. We have a "kbs" MySQL table
    #   in the main Genboree database which has the _actual_ mongo KB name in use; that should be queried
    #   rather than blindly relying on this heuristic. (This is just a convenience method to make a
    #   probably-reasonable name.)
    # @note The name will be TRUNCATED TO 60 CHARS. The limit for database names in mongo appears to be
    #   64 characters. This allows the calling code to change the name slightly to make it unique, check
    #   if name already exists--which it should do anyway--and then modify slightly only if necessary.
    def self.constructMongoDbName(gbHostName, gbGrpName, gbKbName)
      retVal = "#{gbHostName.makeSafeStr(:ultra)}-#{gbGrpName.makeSafeStr(:ultra)}-#{gbKbName.makeSafeStr(:ultra)}"
      # MongoDBs can't have '.' in them either
      return retVal.gsub(/\./, '_')[0,60]
    end

    # CONSTRUCTOR.
    # @note Use a good rule for creating unique @dbNames@. Keep in mind that everyone will want one
    #   called @test@. A good rule for @dbName@s backing GenboreeKBs is to use the user's group +
    #   kbName like this (which will be unique, even if 1 MongoDB is backing multiple Genboree
    #   instances): @{hostName}-{groupName}-{kbName}@. It will be safely made safe. Use the canonical
    #   host name for your instance (e.g. @@genbConf.machineName@ or in the API framework @@localHostName@)
    # @note {MongoKbDatabase.constructMongoDbName} can make the MongoDB in this standard way. Use it.
    # @param [String] dbName The name of the MongoDB database this instance is for. May not exist yet
    #   (i.e. to be created by this instance, later). If it exists it MUST have been created by {#create}!
    #   The value will be subjected to our {String#makeSafeStr} method, although if it is already safe
    #   using the same @:ultra@ (default) mode, then this will bean indepotent operation (so that is fine).
    # @param [String] connStr A MongoDB connection URI or DSN string containing info about host, port,
    #   options, and default credentials (for URIs only).
    # @param [Hash] defaultAuthInfo Containing default db-access user credentials. MUST be credentials for a
    #   MongoDB ~superuser/admin who, when authorized against the special MongoDB "admin" database will get
    #   multi-role, multi-database, and cluster admin roles (i.e. *AnyDatabase and clusterAdmin roles). This user
    #   will be added to any newly created databases with these same roles.
    # @option defaultAuthInfo [String] :user The name of the db-access user.
    # @option defaultAuthInfo [String] :pass The password for the @:user@. DO NOT HARDCODE IN YOUR SCRIPTS/CODE!
    # @raise [ArgumentError] if there doesn't appear to be appropriate db-access credentials provided.
    def initialize(dbName, connStr, defaultAuthInfo=nil)
      #$stderr.debugPuts(__FILE__, __method__, "TIME", "    START: instantiation" )
      @conn = BRL::NoSQL::MongoDb::MongoDbConnection.getInstance(connStr, defaultAuthInfo)
      #$stderr.debugPuts(__FILE__, __method__, "TIME", "    __after__ new MongoDbConnection" )
      raise ArgumentError, "ERROR: neither your connStr nor the defaultAuthInfo parameter seem to have provided default authentification information. This info is required and needs to be a user who--when authenticated against the special MongoDB database 'admin'--has most/all of the '*AnyDatabase' roles and the 'clusterAdmin' roles. Otherwise, KB management CANNOT be done via this class. (@conn.defaultAuthInfo: #{@conn.defaultAuthInfo.inspect}" unless(@conn.defaultAuthInfo.is_a?(Hash) and !@conn.defaultAuthInfo.empty? and @conn.defaultAuthInfo.key?(:user) and @conn.defaultAuthInfo.key?(:pass))
      @name = dbName.makeSafeStr(:ultra)
      # Authenticate first against "admin" database using defaultAuthInfo
      # - this will get us our multi-role, multi-database, and cluster-admin  type privileges
      # - key to have these priviledges for making new dbs, adding & running stored procedures, managing user
      #   access, and many other key cluster/engine level admin tasks.
      # - "admin" is a well-known/special mongodb database where clusterAdmin
      # - using @conn.db() with the optional authInfo parameter, rather than Mongo:DB.new() ensures authentication will happen (unless it already has...
      #   why do it repeatedly?) and the KB MongoDB user is good to go for database creation, user management,
      #   adding/running stored procedures, and other cluster-wide role stuff.
      adminAddAuthOk = @conn.addAuth("admin", @conn.defaultAuthInfo)
      adminDb = @conn.db("admin")
      #$stderr.debugPuts(__FILE__, __method__, "TIME", "    __after__ auth against 'admin'" )

      # Avoid lazy creation of datbases without going through create()
      # - Also take opportunity to find names of any stored procedures
      @db = nil
      @storedProcedures = {}
      if(@conn.client.database_names.include?(@name))
        @db = @conn.db(@name)
        discoverStoredProcedures()
      end
      #$stderr.debugPuts(__FILE__, __method__, "TIME", "    __after__ discover stored procedures" )
      # Key helpers
      @coll2helper                    = {}
      # Metadata helper needed first! Used by others to get info about themselves.
      @coll2helper['kbColl.metadata'] = BRL::Genboree::KB::Helpers::CollMetadataHelper.new(self)
      @coll2helper['kbModels']        = BRL::Genboree::KB::Helpers::ModelsHelper.new(self)
      @coll2helper['kbGlobals']       = BRL::Genboree::KB::Helpers::GlobalsHelper.new(self)
      @coll2helper['kbViews']         = BRL::Genboree::KB::Helpers::ViewsHelper.new(self)
      @coll2helper['kbQueries']       = BRL::Genboree::KB::Helpers::QueriesHelper.new(self)
      @coll2helper['kbTransforms']    = BRL::Genboree::KB::Helpers::TransformsHelper.new(self)
      @coll2helper[QuestionsHelper::KB_CORE_COLLECTION_NAME] = QuestionsHelper.new(self)
      @coll2helper[TemplatesHelper::KB_CORE_COLLECTION_NAME] = TemplatesHelper.new(self)
      @coll2helper[AnswersHelper::KB_CORE_COLLECTION_NAME] = AnswersHelper.new(self)
      #$stderr.debugPuts(__FILE__, __method__, "TIME", "    END: instantiation (connection, auth, find stored procs, init helpers)" )
    end

    # Method to help aid in the clean up, garbage collection, and resource release.
    #   Especially important as the helper objects have circular references back to
    #   this object.
    # Be a dear, call {#clear}
    def clear()
      # Clear helpers
      clearHelpers()
      @db = @name = @conn = nil
    end

    # Return the appropriate sub class of BRL::Genboree:KB::Helpers::AbstractHelper
    #   based on collName
    # @param [String] collName the name of the data collection or internal collection
    # @return [BRL::Genboree:KB::Helpers::AbstractHelper] helper
    def getHelper(collName)
      rv = nil
      if(@coll2helper.key?(collName))
        # then collection is internal
        rv = @coll2helper[collName]
      else
        # then collection is a data collection
        begin
          rv = dataCollectionHelper(collName)
        rescue KbError => err
          $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", "#{err.class}:#{err.message}\n#{err.backtrace.join("\n")}")
          rv = nil
        end
      end
      return rv
    end

    # Convenience method for getting the {ModelsHelper} instance we're using.
    # @return [ModelsHelper] the models helper instance we're using
    def modelsHelper()
      return collectionHelper(ModelsHelper::KB_CORE_COLLECTION_NAME)
    end

    # Convenience method for getting the {GlobalsHelper} instance we're using.
    # @return [GlobalsHelper] the globals helper instance we're using
    def globalsHelper()
      return collectionHelper(GlobalsHelper::KB_CORE_COLLECTION_NAME)
    end

    # Convenience method for getting the {CollMetadataHelper} instance we're using.
    # @return [CollMetadataHelper] the collection metadata helper instance we're using
    def collMetadataHelper()
      return collectionHelper(CollMetadataHelper::KB_CORE_COLLECTION_NAME)
    end

    # Convenience method for getting the {ViewsHelper} instance we're using.
    # @return [ViewsHelper] the collection metadata helper instance we're using
    def viewsHelper()
      return collectionHelper(ViewsHelper::KB_CORE_COLLECTION_NAME)
    end

    # Convenience method for getting the {QueriesHelper} instance we're using.
    # @return [QueriesHelper] the collection metadata helper instance we're using
    def queriesHelper()
      return collectionHelper(QueriesHelper::KB_CORE_COLLECTION_NAME)
    end

    # Convenience method for getting the {TransformsHelper} instance we're using.
    # @return [TransformsHelper] the collection metadata helper instance we're using
    def transformsHelper()
      return collectionHelper(TransformsHelper::KB_CORE_COLLECTION_NAME)
    end

    # @see transformsHelper
    def questionsHelper()
      return collectionHelper(QuestionsHelper::KB_CORE_COLLECTION_NAME)
    end
   
    # @see transformsHelper
    def answersHelper()
      return collectionHelper(AnswersHelper::KB_CORE_COLLECTION_NAME)
    end
    
    # Convenience method for getting the {TemplatesHelper} instance we're using.
    # @return [TemplatesHelper] the collection metadata helper instance we're using
    def templatesHelper()
      return collectionHelper(TemplatesHelper::KB_CORE_COLLECTION_NAME)
    end

    def dataCollectionHelper(docCollName)
      if(@db.collection_names.include?(docCollName))
        unless(KB_CORE_COLLECTION2HELPER_CLASS.include?(docCollName))
          helper = @coll2helper[docCollName]
          unless(helper)
            # Then we don't have a helper for this collection yet. Make it.
            helper = DataCollectionHelper.new(self, docCollName)
            @coll2helper[helper.coll.name] = helper
          end
        else
          raise KbError, "ERROR: #{docCollName.inspect} is a core collection name, not a data collection." unless(KB_CORE_COLLECTION2HELPER_CLASS.key?(docCollName))
        end
      else
        raise KbError, "ERROR: #{docCollName.inspect} is not a collection in the #{@db.name} database."
      end
      return helper
    end

    # Convenience method for getting the specific versions helper instance
    #   for a core collection of interest.
    # @param [String] docCollName The name od the data document collection you
    #   want the corresponding versions helper for.
    # @return [VersionsHelper] the helper you want.
    def versionsHelper(docCollName)
      return historyHelper(docCollName, :versions)
    end

    # Convenience method for getting the specific revisions helper instance
    #   for a core collection of interest.
    # @param [String] docCollName The name od the core collection you
    #   want the corresponding revisions helper for.
    # @return [RevisionsHelper] the helper you want.
    def revisionsHelper(docCollName)
      return historyHelper(docCollName, :revisions)
    end

    # Convenience method for getting the specific history helper instance
    #   for a collection of interest.
    # @param [String] docCollName The name od the collection you
    #   want the corresponding revisions helper for.
    # @param [Symbol] historyType The type of history helper you are intersted in for
    #   the collection of interest: @:versions@ or @:revisions@
    # @return [RevisionsHelper] the helper you want.
    def historyHelper(docCollName, historyType)
      raise KbError, "ERROR: The core collection #{docCollName.inspect} does not have a #{historyType} collection." if(self.class::KB_HISTORYLESS_CORE_COLLECTIONS.include?(docCollName))
      if(historyType == :versions)
        historyCollName = VersionsHelper.historyCollName(docCollName)
      elsif(historyType == :revisions)
        historyCollName = RevisionsHelper.historyCollName(docCollName)
      else
        raise KbError, "ERROR: there is no #{historyType.inspect} type of collection in GenboreeKB databases."
      end
      helper =  collectionHelper(historyCollName)
      unless(helper)
        # Then we don't have a helper for this collection's history yet. Make it.
        helper = (historyType == :revisions ? RevisionsHelper.new(self, docCollName) : VersionsHelper.new(self, docCollName))
        @coll2helper[helper.coll.name] = helper
      end
      return helper
    end

    # Get the core collection {AbstractHelper} sub-class object we're using to
    #   help us with @collName@
    # @param [String] collName The core collection name you want the helper instance for. Must
    #   be a core collection name, such as those found in {KB_CORE_COLLECTION2HELPER_CLASS}.
    # @return [AbstractHelper] the helper instance for @collName@.
    def collectionHelper(collName)
      return @coll2helper[collName]
    end

    # Get the set of collections in the database, either as an array of names or
    #   collection metadata docs.
    # @note While this is mainly geared toward the list of data collections--with
    #   user data docs in them--it is possible to get the internally-managed collection
    #   list instead (collections used internally and having their own metadata + ancillary
    #   support collections [like history]) or even ALL the collections direct from MongoDB.
    # @note If you ask for @:all@ collections, you cannot get @:metadata@ docs because some
    #   ancillary/support collections do not have metadata and only exist to support internal & user
    #   data collections managed by the GenboreeKB system.
    # @param [Symbol] type Indicate the type of collection you want in the list: @:data@,
    #   @:internal@, or @:all@. Default is @:data@--the list of user data doc collecitons--as this is
    #   the most common request via API & UIs.
    # @param [Symbol] provide Indiicate what info you want in the collections list: just the collection
    #   @:names@ or the full collection @:metadata@ docs.
    # @param [Array<String>, Array<Hash>] the set of collections requested.
    def collections(type=:data, provide=:names)
      colls = []
      if(type == :data or type == :internal or type == :all)
        if(provide == :names or provide == :metadata)
          unless(type == :all and provide == :metadata)
            if(type == :all)
              colls = @db.collection_names
            else # managed collections, either :internal or not (i.e. :data)
              # Get all managed collections from collMetadataHelper
              collHelper = collMetadataHelper()
              docs = collHelper.allDocs(:docList)
              # Remove irrelevant records
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Requested type: #{type.inspect}")
              unless(type == :all)
                docs.delete_if { |doc|
                  #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "#{doc.getPropVal('name').inspect} => #{doc.getPropVal('name.internal')}")
                  ( (type == :data and doc.getPropVal('name.internal')) or (type == :internal and !doc.getPropVal('name.internal')) )
                }
              end
              # Gather requested info
              if(provide == :names)
                docs.each { |doc|
                  name = doc.getPropVal('name')
                  if(name.nil?)
                    raise "FATAL ERROR: Some how a collection metadata document does not have the top-level 'name' property!. Corrupt KB? Metadata doc follows:\n\n#{doc.inspect}\n\n"
                  else
                    colls << name
                  end
                }
              else # provide == :metadata
                docs.each { |doc|
                  colls << doc
                }
              end
            end
          else
            raise ArgumentError, "ERROR: cannot provide metadata for 'all' collections, only the collection names."
          end
        else
          raise ArgumentError, "ERROR: cannot provide #{provide.inspect} information about collecitons. Must be either :names or :metadata"
        end
      else
        raise ArgumentError, "ERROR: cannot select #{type.inspect} type collection list. Must be either :data, :internal, or :all."
      end
      return colls
    end

    # Convenience method for getting a {Mongo::Collection} instance for the collection where the globals doc is kept.
    # @return [Mongo::Collection] for the collection containing the globals doc.
    def globalsCollection()
      return getCollection(GlobalsHelper::KB_CORE_COLLECTION_NAME)
    end

    # Convenience method for getting a {Mongo::Collection} instance for the collection where collection metadata
    #   docs are kept.
    # @return [Mongo::Collection] for the collection containing the collection metadata docs
    def collMetadataCollection()
      return getCollection(CollMetadataHelper::KB_CORE_COLLECTION_NAME)
    end

    # Convenience method for getting a {Mongo::Collection} instance for the collection where the model docs are kept.
    # @return [Mongo::Collection] for the collection containing the document models
    def modelsCollection()
      return getCollection(ModelsHelper::KB_CORE_COLLECTION_NAME)
    end

    # Convenience method for getting a {Mongo::Collection} instance for the collection where the view docs are kept.
    # @return [Mongo::Collection] for the collection containing the document views
    def viewsCollection()
      return getCollection(ViewsHelper::KB_CORE_COLLECTION_NAME)
    end
    
    # Convenience method for getting a {Mongo::Collection} instance for the collection where the template docs are kept.
    # @return [Mongo::Collection] for the collection containing the document template
    def templatesCollection()
      return getCollection(TemplatesHelper::KB_CORE_COLLECTION_NAME)
    end

    # Convenience method for getting a {Mongo::Collection} instance for the collection where the transformation docs are kept.
    # @return [Mongo::Collection] for the collection containing the document transformations
    def transformsCollection()
      return getCollection(TransformsHelper::KB_CORE_COLLECTION_NAME)
    end

    # @see transformsCollection
    def questionsCollection()
      return getCollection(QuestionsHelper::KB_CORE_COLLECTION_NAME)
    end

    # Convenience method for getting a {Mongo::Collection} instance for the collection where the queries docs are kept.
    # @return [Mongo::Collection] for the collection containing the document queries
    def queriesCollection()
      return getCollection(QueriesHelper::KB_CORE_COLLECTION_NAME)
    end

    # Convenience method for getting a {Mongo::Collection} instance for the collection where the answer docs are kept.
    # @return [Mongo::Collection] for the collection containing the answer documents
    def answersCollection()
      return getCollection(AnswersHelper::KB_CORE_COLLECTION_NAME)
    end
   
    # Convenience method for getting a {Mongo::Collection} instance for the collection where the view docs are kept.
    # @param [String] dataCollName The name of data doc collection.
    # @param [Symbol] history The type of history collection you want, as a {Symbol}: @:versions@ or @:revisions@
    # @return [Mongo::Collection] for the collection containing the history docs.
    def historyCollection(dataCollName, historyType)
      return getCollection(dataCollName, historyType)
    end

    def dataCollection(dataCollName)
      return getCollection(dataCollName)
    end

    # Get a {Mongo::Collection} instance using a data collection name and optional type. By providing
    #  a type, you can specify that you want the @:revisions@ or @:versions@ collection for the data
    #  collection rather than the data collection itself.
    # @note To get GenboreeKb core collections, use one of the dedicated methods rather than hacking things
    #   to call this method: {#globalsCollection}, {#collMetadataCollection}, {#modelsCollection}, {#viewsCollection}, {#historyCollection;}
    # @note To avoid bugs and KB corruption (!) you should use this to get GenboreeKB collections rather
    #   than getting them directly from the {#db} object. This method will avoid any possibility of lazy-creation
    #   of the collection (even virtual within the driver), which is MongoDB Ruby driver default.
    # @param [String] dataCollName The name of a data collection or a {Symbol}. Should not be
    #   a versioning or revisioning collection; use @collType@ to indicate you want those.
    # @param [Symbol, nil] historyType Either @nil@ when you want the data collection itself or a {Symbol}
    #   indicating that you actually want the appropriate versioning/revisioning collection: @:versions@, @:revisions@
    # @return [Mongo::Collection, nil] the appropriate collection object or @nil@ indicating there is nothing
    #   matching what you asked for.
    # @raise [KbError] if there is no @dataCollName@ collection or there is no metadata document for it.
    def getCollection(dataCollName, historyType=nil)
      retVal = nil
      # Get metadata doc for dataCollName
      collMetadataHelper = collMetadataHelper()
      metadataDoc = collMetadataHelper.metadataForCollection(dataCollName)
      if(metadataDoc)
        if(historyType)
          retVal = collMetadataHelper.historyCollectionForCollection(dataCollName, historyType)
        else
          collName = dataCollName
          # Avoid lazy create of a collection
          if(@db.collections_info(collName).count == 1)
            retVal = @db[collName]
          else
            raise KbError, "ERROR: there is no collection named #{collName.inspect} which you are asking for."
          end
        end
      else
        raise KbError, "ERROR: There is no collection metadata doc for #{dataCollName.inspect}. It does not appear to be a valid GenboreeKB collection."
      end
      return retVal
    end

    # Gets the latest/current versioning doc for a document of interest.
    # @overload currentVersion(docRef)
    #   Use a reference to the document to get it.
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
    # @return [KbDoc] the document of interest.
    def docByRef(docRef, docCollName=nil)
      if(docCollName.nil?)
        docCollName = docRef.namespace
      else # need to construct a docRef
        docId = BSON::ObjectId.interpret(docRef)
        docRef = BSON::DBRef.new(docCollName, docId)
      end
      doc = @db.dereference(docRef)
      return KbDoc.new(doc)
    end

    def docsByRefs(docRefs, docCollName=nil)
      retVal = []
      docRefs.each{|docRef|
        retVal << docByRef(docRef, docCollName)
      }
      return retVal
    end

    # Create a new GenboreeKB MongoDB database with the name in {#name}. This will
    #   create the db, add the db-access user to the db with aggressive *AnyDatabase
    #   roles, initialize core collections, including versioning and revisioning collections
    #   for the core collections (!), populate 'kbModels' with model documents for the
    #   core collections, populate the @kbGlobals@ doc with initial global values, etc.
    # After calling this, {#db} will now have a valid {Mongo::DB} instance for the new database.
    # @return [Boolean] indicated if all the steps appeared to be completed successfully.
    # @raise [KbError] if there is already a database for {#name} or if adding the db-access
    #   user failed for some reason
    def create()
      retVal = false
      # Databse exists? error
      if(@conn.client.database_names.include?(@name) or !@db.nil?)
        raise KbError, "ERROR: there is already a database called #{@name.inspect}. Cannot create twice."
      else
        # Create new database and add user
        systemUser = @conn.defaultAuthInfo[:user]
        systemPass = @conn.defaultAuthInfo[:pass]
        @db = @conn.createDb(@name, systemUser, systemPass)
        # Add user auth info to this database
        raise KbError, "ERROR: Failed to add admin user to the new database." unless(@db)
        # Save stored procedures
        KB_DB_STORED_PROCEDURES.each_key { |procName|
          @db.add_stored_function(procName, KB_DB_STORED_PROCEDURES[procName])
        }
        discoverStoredProcedures(true)
        # CREATE COLLECTIONS. Actively add core collections and any associated versioning/revisioning collections.
        KB_CORE_COLLECTIONS.each { |collName|
          # Make the collection, with indices, etc.
          makeCoreCollection(collName)
          # Create the history collections for collName, if appropriate, with help of info from collMetadataHelper.
          metadataTemplate = collMetadataHelper().docTemplate(collName, @conn.defaultAuthInfo[:user])
          versionsCollName = metadataTemplate.getPropVal("name.versions")
          revisionsCollName = metadataTemplate.getPropVal("name.revisions")
          makeCoreCollection(versionsCollName)  if(versionsCollName)
          makeCoreCollection(revisionsCollName) if(revisionsCollName)
          # If this collection has an initialization doc (most don't, except specially handled model docs)
          # then save it to the collection.
          helper = collectionHelper(collName)
          if(helper.class::KB_INIT_DOC)
            # Save this directly into the collection (which bypasses proper history handling...generally avoid except
            # when setting things up and whatnot). After setup we want to use the AbstractHelper#save() method which
            # will do both the actual document save on the collection but will also arrange to save history records as well.
            helper.coll.save( helper.class::KB_INIT_DOC.to_serializable() )
          end
        }
        # Now we have all the core collections, with indices and including any history collections.
        # Next, INSERT METADATA DOCS for each collection.
        collMetadataHelper = collMetadataHelper()
        KB_CORE_COLLECTIONS.each { |collName|
          metadataDocObjId = collMetadataHelper.insertForCollection(collName, systemUser)
        }
        # Now we have the core collections and metadata documents for them in the kbColl.metadata collection.
        # Next, INSERT MODEL DOCS for each collection.
        modelsHelper = modelsHelper()
        KB_CORE_COLLECTIONS.each { |collName|
          helper = collectionHelper(collName)
          # Having an existing model doc for a collection we're trying to create is NOT CORRECT at this point. So
          # we hope this returns nil.
          collModelDoc = modelsHelper.modelForCollection(collName, false)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "**MODEL** for #{collName.inspect} (#{collModelDoc.class.inspect} ; #{collModelDoc.nil?}):\n\n#{collModelDoc.inspect}\n\n")
          if(collModelDoc.nil?)
            # Get model template for this collection
            modelTemplate = helper.class.getModelTemplate(collName)
            # Change or fill in anything (RARE!)
            collModelDoc = modelTemplate
          else
            raise KbError, "ERROR: there is already a model doc available for the collection #{collName.inspect}. Somehow it was already created or was created outside the GenboreeKB infrastructure. Regardless, cannot proceed."
          end
          # Insert the collection's model doc
          modelObjId = modelsHelper.insertForCollection(collModelDoc, systemUser)
        }
        retVal = true
      end
      return retVal
    end

    # @todo enforce upper limit on docCollName -- Mongo wants a namespace of form "{db name}.{coll name}" 
    #   and it cannot exceed 120 characters (120 is ok). Note that this also means any collections to
    #   be associated with this docColl must also meet this limit. For example, see e.g. 
    #   Helpers::RevisionsHelper::KB_CORE_COLLECTION_NAME and do not hard code ".revisions"
    def createUserCollection(docCollName, author, modelDoc, opts={})
      # Validate model. Keep model validator instance around to ask questions about what it noticed during validation.
      modelValidator = BRL::Genboree::KB::Validators::ModelValidator.new()
      modelOK = modelValidator.validateModel(modelDoc)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "modelOK: #{modelOK.inspect} ; These properties need indices:\n#{JSON.pretty_generate(modelValidator.indexedDocLevelProps)}\n\n")
      unless(modelOK)
        raise ArgumentError, "ERROR: modelDoc does not appear to be a valid data model schema document! Errors:\n#{modelValidator.validationErrors.join("\n")}"
      else
        # Check if the collection already exists...can't create twice
        if(@db.collection_names.include?(docCollName))
          raise KbError, "ERROR: there is already a collection called #{docCollName.inspect} in the knowledgebase. Cannot create twice."
        else
          # Having an existing model doc for a collection we're trying to create is NOT CORRECT at this point (collection doesn't exist so niether should the model...). So
          # we hope this returns nil.
          collModelDoc = modelsHelper.modelForCollection(docCollName)
          if(collModelDoc)
            raise KbError, "ERROR: there is already a model doc available for the collection #{docCollName.inspect}, even though there is no actual collection with that name. Corrupt GenboreeKB. It was already created or was created outside the GenboreeKB infrastructure. Regardless, cannot proceed."
          else # good, no model either, proceed
            # modelDoc may be BRL::Genboree::KB::KbDoc instance, already filled in OR may just be the model itself
            if(modelDoc.is_a?(BRL::Genboree::KB::KbDoc))
              # 'name' property should match docCollName arg in this case
              unless(modelDoc.getPropVal('name') != docCollName)
                # we need the contents of the 'model' sub-property...cannot be empty
                theModel = modelDoc.getPropVal('name.model')
                unless(theModel.acts_as?(Hash) and !theModel.empty?)
                  raise ArgumentError, "ERROR: Tried to get the 'name.model' property from the modelDoc argument but either it is missing/nil or is not an appropriate model schema value."
                end
              else
                raise ArgumentError, "ERROR: The 'name' field in modelDoc (#{modelDoc.getPropVal('name').inspect}) does not match the name of the document collection you are creating (#{docCollName.inspect}). Do you have the correct modelDoc? Is it constructed correctly?"
              end
            else # assume modelDoc is a Hash-like object that IS the model
              if(modelDoc.acts_as?(Hash) and !modelDoc.empty?)
                theModel = modelDoc
              else
                raise ArgumentError, "ERROR: The model provided via the modelDoc argument is either empty or is not a hash-like object containing the model schema."
              end
            end
          end
        end
      end
      # MAKE COLLECTION
      coll = @db.create_collection(docCollName)
      # Create helper instance
      # - by providing the actualy Mongo::Collection object rather than the collection name
      #   to helper constructor, we tell it to use this collection rather than trying to properly
      #   ask the infrastructure for the collection [which may not yet be available...we're creating!]
      helper = DataCollectionHelper.new(self, coll)
      # We already have a ModelsValidator object that's been run on the collection model.
      #   Provide our DataCollectionHelper with that, in case it wants to ask questions about what
      #   the validator noticed about the model. This is NOT required and DataCollectionHelper can
      #   make its own ModelsValidator if needed and re-validate a retrieved model...but why waste time
      #   redoing all that? This is a performance option.
      helper.modelValidator = modelValidator

      if(@coll2helper.key?(docCollName))
        @coll2helper[docCollName].clear()
        @coll2helper.delete(docCollName)
      end
      @coll2helper[docCollName] = helper
      # Make HISTORY COLLECTIONS with help of info from collMetadataHelper
      collMetadataHelper = collMetadataHelper()
      # Insert METADATA doc for new collection
      metadataDocObjId = collMetadataHelper.insertForCollection(docCollName, author, true, opts)
      # Get metadata record inserted (as a check, and to use to make history collections.
      metadataTemplate = collMetadataHelper.docTemplate(docCollName, author)
      makeCoreCollection(metadataTemplate.getPropVal("name.versions"), VersionsHelper)
      makeCoreCollection(metadataTemplate.getPropVal("name.revisions"), RevisionsHelper)
      # Now we have the collection, the associated history collections for internal use, and a metadata document
      # Next, INSERT MODEL DOCS for the collection.
      modelsHelper = modelsHelper()
      model = modelsHelper.docTemplate(docCollName)
      # Override certain modelDoc fields where indicated
      model.setPropVal('name.internal', false)
      model.setPropVal('name.model', theModel)
      modelObjId = modelsHelper.insertForCollection(model, author)
      # Add USER COLLECTION INDICES - need model doc saves
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Collection created up to create indices step. About to create indices...")
      indexingResults = helper.createIndices()
      failedIndices = indexingResults[:failedIndices]
      if(failedIndices and !failedIndices.empty?)
        # Log info about failed indices but try to let the collection creation proceed. Ouch.
        $stderr.debugPuts(__FILE__, __method__, "FAILURE", "!!!! Failed to create one or more USER COLLECTION indices !!!!")
        details = ""
        failedIndices.each { |failureRec|
          details += "  - create_index() return value: #{failureRec[:result].inspect}\n"
          details += "  - failed index config: #{failureRec[:idxConf].inspect}\n"
          err = failureRec[:err]
          details += "  - exception raised (if any): #{err.inspect}\n  - backtrace:\n#{err.backtrace.join("\n")}\n\n"
        }
        $stderr.debugPuts(__FILE__, __method__, "FAILURE", "!!!! Index creation failure details: !!!!\n#{details}" )
      else
        # noop ; unless want debug
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>>>>> SUCCESS <<<<<<<< created user collection indices via new createIndices() code")
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Result of user-collection index creation: #{indicesCreateOk.inspect}. Index info for #{docCollName.inspect}:\n\n#{JSON.pretty_generate(@db.index_information(docCollName))}" )
      # Return true (not the collection, want to encourage going through framework for the most part, not direct ops)
      return true
    end

    # Drops/destroys the mongo datatbase in {#db}. Not only does the drop database but also removes internal auth
    #   info for the database from the driver and from the connection object, etc. This is not done automatically.
    # @note DANGER DANGER!! It is very rare you want to use this. It will completely destroy the actual MongoDB database
    #   which you will not be able to recover. Probably not how to handle providing "delete KB" functionality for the user
    #   (rather, some offline process that does a data dump and then the actual drop() probably).
    # @note This {MongoKbDatabase} instance will be pretty useless after this, as it will not longer be linked to a database.
    #   The {#clear} method will be called at the end, to get rid of internal helpers and things linked to the dropped database.
    # @return [Hash] the drop result document from MongoDB. The @"ok"@ field should equal @1.0@. Auth info and
    #   clearing internal properties are ONLY done if the drop appeared successful. by not clearing out internal
    #   properties in the failure case, it may allow you to provide feedback and examine why a given drop failed, etc.
    # @raise [KbError] if the the database in {#name} doesn't exist yet or if @@db.name@ not same as {#name} (very bad!)
    def drop()
      if(@db and @db.name == @name)
        # Drop database
        dropResult = @conn.client.drop_database(@db.name)
        if(dropResult and dropResult["ok"] == 1)
          # Remove auth info
          @conn.removeAuth(@db.name)
          # Destroy various helpers and properties connected to this dropped database
          self.clear()
        end
      else
        raise KbError, "ERROR: Can't drop a database that hasn't been created yet. The database #{@name.inspect} doesn't exist and thus there is no @db object to use to drop the database. Or WORSE, it appears that @name does not match @db.name...serious bug and mismatch in infrastructure code or you managed to change one/both of these properties inappropriately (only changeable/managed by this class)."
      end
      return dropResult
    end

    # ------------------------------------------------------------------
    # INTERNAL METHODS - mainly for use by this class and the framework, rarely by outside classes
    # ------------------------------------------------------------------

    # INTERNAL METHOD. Poll the MongoDB database for its set of stored-procedures. Mainly
    #   to keep track of the names of available ones.
    # @param [Boolean] forceRefresh Flag used to force polling of the MongoDB database
    #   rather than relying on any cached results from previous calls.
    # @return [Hash] mapping stored-procedure names to {BSON::Code}.
    def discoverStoredProcedures(forceRefresh=false)
      if(@storedProcedures.nil? or @storedProcedures.empty? or forceRefresh)
        @storedProcedures = {}
        systemJsColl = @db["system.js"]
        #$stderr.debugPuts(__FILE__, __method__, "TIME", "      -- __before__ cursor iter" )
        systemJsColl.find() { |cur|
          cur.each { |doc|
            @storedProcedures[doc["_id"]] = doc["value"]
          }
        }
        #$stderr.debugPuts(__FILE__, __method__, "TIME", "      -- __after__ cursor iter" )
      end
      return @storedProcedures
    end

    # INTERNAL METHOD. Call a stored procedure available on the server side.
    #   The stored procedure must be on that exists in the database.
    # @param [String] procName The name of the stored procedure
    # @param [Boolean] nolock Whether or not nolock=true should be used when using
    #   eval() to call the server-side procedure. WHEN IN DOUBT USE false. This is the default,
    #   meaning eval() will trigger a global write lock and prevent all other read/write operations
    #   while the eval() is running. SAFE. CONCURRENT. But perhaps unnecessary, since it does NOT affect
    #   locking done by operations in the procedure (e.g. document being written will be write locked while being
    #   changed so no reads nor writes can happen on it; during reads, other read operations can happen but not
    #   writes). Often the global write lock is EXCESSIVE (especially at HIGH performance cost but can be useful if you want all operations in the
    #   procedure done without interruption/interfence from other concurrent operations. If you just have 1 db operation in the
    #   procedure you probably don't need the global lock (default) and can set @nolock@ to @true@. BE CAREFUL.
    # @param [Array] params The parameters to hand off to the stored procedure.
    #   MUST make valid Javascript method argument list when joined with @inspect@
    #   and ', '!
    # @return [Object, nil] The return value of the function or @nil@ if the function
    #   failed or returns null
    # @raise [ArgumentError] if @procName@ is not a known stored procedure in the database.
    def callStoredProcedure(procName, nolock, *params)
      retVal = nil
      if(@storedProcedures and @storedProcedures.key?(procName))
        evalStr = "#{procName}(#{params.map { |xx| xx.inspect }.join(", ")})"
        retVal = @db.eval(evalStr, :nolock=>nolock)
      else
        raise ArgumentError, "ERROR: there is no stored procedure #{procName.inspect} in the #{@name.inspect} database."
      end
      return retVal
    end

    # INTERNAL METHOD. Create a core collection, create indices. Used when first creating core
    #   collections when making a new database. This method will also update the set of
    #   helpers kept in {coll2helper}, to help ensure they have valid and up-to-date collections.
    # @note DO NOT use this to create user data collections!
    # @param [String] collName The name of the core collection to create.
    # @param [AbstractHelper] helperClass A sub-class of {AbstractHelper} matching the core collection.
    #   Optional. By default, this is determined automatically.
    # @return [Mongo::Collection] a collection object for the new core collection.
    def makeCoreCollection(collName, helperClass=KB_CORE_COLLECTION2HELPER_CLASS[collName])
      # 1. Create doc collection itself
      coll = @db.create_collection(collName)
      # 2. Create helper instance
      # - by providing the actualy Mongo::Collection object rather than the collection name
      #   to helper constructor, we tell it to use this collection rather than trying to properly
      #   ask the infrastructure for the collection [which may not yet be available...we're creating!]
      helper = helperClass.new(self, coll)
      if(@coll2helper.key?(collName))
        @coll2helper[collName].clear()
        @coll2helper.delete(collName)
      end
      @coll2helper[collName] = helper
      # 3. Create indices for doc collection
      indexingResults = helper.createIndices()
      failedIndices = indexingResults[:failedIndices]
      if(failedIndices and !failedIndices.empty?)
        # Log info about failed indices but try to let the collection creation proceed. Ouch.
        $stderr.debugPuts(__FILE__, __method__, "FAILURE", "!!!! Failed to create one or more CORE COLLECTION indices !!!!")
        details = ""
        failedIndices.each { |failureRec|
          details += "  - KB::Helper class creating index(es): #{failureRec[:helperClass].inspect}\n"
          details += "  - Helper instance's @coll class: #{failureRec[:collClass].inspect}\n"
          details += "  - Helper instance's @coll.name: #{failureRec[:collName].inspect}\n"
          details += "  - Helper's create_index() return value: #{failureRec[:result].inspect}\n"
          details += "  - The failed index config: #{failureRec[:idxConf].inspect}\n"
          details += "  - Exception raised (if any): #{failureRec[:err].inspect}\n\n"
          details += "  - Exception Backtrace:\n#{failureRec[:err].backtrace.join("\n")}" if(failureRec[:err])
        }
        $stderr.debugPuts(__FILE__, __method__, "FAILURE", "!!!! Index creation failure details: !!!!\n#{details}" )
      else
        # noop unless want debug
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>>>>> SUCCESS <<<<<<<< created core collection indices for #{collName.inspect} via new createIndices() code")
      end
      return coll
    end

    # Clears the helper instance variables
    def clearHelpers()
      @coll2helper.each_key { |collName|
        @coll2helper[collName].clear rescue false
      }
      @coll2helper.clear() rescue false
      @modelsHelper = @collMetadataHelper = @coll2helper = nil
    end
  end # class MongoKbDatabase
end ; end ; end # module BRL ; module Genboree ; module KB
