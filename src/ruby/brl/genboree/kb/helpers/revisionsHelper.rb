#!/bin/env ruby

require 'brl/genboree/kb/helpers/abstractHelper'
require 'brl/genboree/kb/propSelector'

module BRL ; module Genboree ; module KB ; module Helpers
  # This class assists with managing the revisioning documents of any collection.
  # @note Unlike other {AbstractHelper} sub-classes, the name of the underlying
  #   collection is NOT known ahead of time. It is named after the doc collection
  #   the revisioning is being done for. That collection name is determined dynamically
  #   when you instantiate this class.
  class RevisionsHelper < AbstractHelper

    # @return [String] The name of the core GenboreeKB collection the helper assists with.
    KB_CORE_COLLECTION_NAME = "{docColl}.revisions"
    # @return [Array<Hash>] An array of MongoDB index config hashes; each has has key @:spec@ and @:opts@
    #   the indices for the metadata documents in this collection.
    KB_CORE_INDICES =
    [
      # Index each revisions doc by its "revisionNum". Will want max revisionNum overall quickly.
      {
        :spec => 'revisionNum.value',
        :opts => { :unique => true, :background => true }
      },
      # Index each revisions doc by the docRef so we can find the revision for a given doc quickly.
      # - We want the LATEST revision first and fast, so put a DESCENDING index on the revisionNum column following docRef
      {
        :spec => [ [ 'docRef.value', Mongo::ASCENDING ], [ 'revisionNum.value', Mongo::DESCENDING ] ],
        :opts => { :unique => true, :background => true }
      },
      # Index each revisions doc by the docRef and subDocPath, to help find revisions for particular fields in a doc
      # - Prefix searching on the subDocPath should pull up changes at a certain level and below
      {
        :spec => [ [ 'docRef.value', Mongo::ASCENDING ], [ 'subDocPath.value', Mongo::ASCENDING ] ],
        :opts => { :unique => false, :background => true }
      },
      # Index the timestamp of the revision so we can answer queries about the use of the collection over time
      {
        :spec => "revisionNum.properties.timestamp.value",
        :opts => { :background => true }
      },
      # Index the previous version so we can answer queries about the number of creations
      {
        :spec => [["revisionNum.properties.prevVersion.value", Mongo::ASCENDING], ["revisionNum.properties.timestamp.value", Mongo::DESCENDING]],
        :opts => { :background => true }
      },
      # Index the deletion field so we can answer queries about the number of deletions
      {
        :spec => [["revisionNum.properties.deletion.value", Mongo::ASCENDING], ["revisionNum.properties.timestamp.value", Mongo::DESCENDING]],
        :opts => { :background => true }
      },
      # Index the subDocPath for queries on how a particular field was edited
      {
        :spec => "revisionNum.properties.subDocPath.value",
        :opts => { :background => true }
      }
    ]
    attr_accessor :incTimeCount
    # @return [Hash] A model document or model template which can be used to place an appropriate
    #    model document into the @kbModels@ collection when the database (or this helper's collection)
    #    is first created.
    KB_MODEL =
    {
      "name"        => { "value" => "Revision Model - #{KB_CORE_COLLECTION_NAME}", "properties" =>
      {
        "internal"  => { "value" => true },
        "model"     => { "value" => "", "items" =>
        [
          {
            "name"        => "revisionNum",
            "description" => "Unique revision number in the .revisions collection. Auto-increment best.",
            "domain"      => "posInt",
            "identifier"  => true,
            "properties"  =>
            [
              {
                "name"	      => "docRef",
                "description"	=> "A DBRef to the actual document, in its respective collection, for which this is a revisioning record. Thus, always points to the latest/current/head revision of the document. If this revision is a document deletion, this will be null.",
                "domain"	    => "dbRef",
                "required"	  => true,
                "index"	      => true,
              },
              {
                "name"	      => "prevRevision",
                "description"	=> "The revisionNum of the previous revision for the document. If it is the first/original revision, this will be 0.",
                "domain"	    => "posInt",
                "required"	  => true,
                "index"       => true
              },
              {
                "name"        => "subDocPath",
                "description" => "A path in the model to the sub-document or field which is changed in this revision. Relative to the document root, and must begin at the document root '/'. Indicate whole document change by providing the document root-path '/'.",
                "domain"      => "regexp(^/)",
                "required"    => true,
                "index"       => true
              },
              {
                "name"	      => "author",
                "description"	=> "Username/login of the user who modified the document to make this revision.",
                "required"	  => true
              },
              {
                "name"	      => "timestamp",
                "description"	=> "The timestamp of this revision.",
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
                "description"	=> "A label for this revision. Optional and ill specified. Bit like a special tag.",
                "index"	      => true
              },
              {
                "name"	      => "comment",
                "description"	=> "Free form optional comment text from user about this revision."
              },
              {
                "name"	      => "tags",
                "description"	=> "A list of single-word keywords/tags associated with this revision.",
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
                "description"	=> "The value of the field (atomic or a sub-document) present at path for this revision.",
                "required"	  => true,
                "domain"	    => "various"
              }
            ]
          }
        ]}
      }}
    }

    # Get the model doc template for the collection this helper assists with.
    # @todo change this from returning KB_MODEL constant
    #   in the respective sub-class, but rather have them loaded from
    #   some .yml files. Maybe cached like the SingletonJSONCache, etc.
    # @param [String] docCollName The name of the data collection this revisioning model template will
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
      return KB_CORE_COLLECTION_NAME.gsub(/\{docColl\}/, docCollName)
    end

    # Create new instance of this helper.
    # @param [MongoKbDatabase] kbDatabase The KB database object this helper is assisting.
    # @param [String] docCollName The name of the document collection that is being revisioned.
    #   It will be used to determine to correct name of the revisioning collection.
    def initialize(kbDatabase, docCollName)
      super(kbDatabase, docCollName)
      unless(docCollName.is_a?(Mongo::Collection))
        @coll = @kbDatabase.getCollection(docCollName, :revisions)
      end
    end

    # Returns the current revision number from the global counter.
    # @return [Fixnum] The current revision number.
    def currentRevisionNum()
      globalsHelper = @kbDatabase.globalsHelper()
      return globalsHelper.globalCounterValue("revisionNum")
    end

    # Generates and returns the next revision number from the global counter. i.e.
    #   increments and returns the revision number global counter.
    # @return [Fixnum] The next revision number.
    def nextRevisionNum()
      globalsHelper = @kbDatabase.globalsHelper()
      return globalsHelper.incGlobalCounter("revisionNum")
    end
    
    # Generates and returns the revision number incermented by the specified value from the global counter. i.e.
    #   increments and returns the revision number global counter.
    # @param [Integer] nn positive number by which you want to increment by
    # @return [Fixnum] The next revision number.
    def incRevisionNumByN(nn)
      globalsHelper = @kbDatabase.globalsHelper()
      return globalsHelper.incGlobalCounterByN("revisionNum", nn)
    end

    # Gets the latest/current revisioning doc for a document of interest.
    # @todo Move this to a HistoryHelper abstract parent class of VersionsHelper and RevisionsHelper. Generic.
    # @overload currentRevision(docId)
    #   Use a reference to the document to get its current revisioning record. Preferred.
    #   @param [BSON::DBRef] docId The reference pointing to the data document.
    # @overload currentRevision(docId, docCollName)
    #   Use an object that can be interpretted as a {BSON::ObjectId} by {BSON::ObjectId.interpret}
    #     as the ObjectId within the collection named in @docCollName@.
    #   @param (see BSON::ObjectId.interpret)
    #   @param [String] docCollName The name of the data collection.
    # @return [KbDoc] the latest/current revisioning doc for the document of interest.
    def currentRevision(docId, docCollName=nil)
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
      docCount = @kbDatabase.db[historyCollName].find({ 'revisionNum.properties.docRef.value' => docRef }, { :sort => [ 'revisionNum.value', Mongo::DESCENDING ], :limit => 1 }).count(false)
      retVal = nil
      if(docCount.to_i > 0)
        historyDoc = @kbDatabase.db[historyCollName].find_one({ 'revisionNum.properties.docRef.value' => docRef }, { :sort => [ 'revisionNum.value', Mongo::DESCENDING ], :limit => 1 })
        retVal =   BRL::Genboree::KB::KbDoc.new(historyDoc)
      end
      return retVal
    end
    
    def getMaxRevisionForDocs(docRefs, docCollName=nil)
      disabled = true # This blocks the worker on large downloads! Can't cursor through all 100,000, 1 million, 10+ million docs and interrogate each one! Can't even cursor through each one anyway.
      if( disabled )
        retVal = -1
      else
        queryDoc = { "revisionNum.properties.docRef.value" => { "$in" => docRefs } }
        opts = { :sort => ['revisionNum.value', Mongo::DESCENDING], :limit => 1 }
        retVal = nil
        cursor = nil
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Running query: #{queryDoc.inspect}\nopts: #{opts.inspect}")
        if(docCollName)
          historyCollName = self.class::historyCollName(docCollName)
          cursor = @kbDatabase.db[historyCollName].find(queryDoc, opts)
        else
          cursor = @coll.find(queryDoc, opts)
        end
        cursor.each { |doc|
          kbDoc = BRL::Genboree::KB::KbDoc.new(doc)
          retVal = kbDoc.getPropVal('revisionNum').to_i
        }
      end
      return retVal
    end
    
    # Checks existence of a user document by the identifier value of the actual document stored in the 'content' field
    # @Param [String] identProp
    # @param [String] docName
    # @param [String] docCollName
    # @return [KbDoc] the revision doc associated with versionNum for the document of interest.
    def exists?(identProp, docName, docCollName)
      historyCollName = self.class::historyCollName(docCollName)
      queryDoc = {
        "revisionNum.properties.content.value.#{identProp}.value" => docName,
      }
      retVal = nil
      opts = { :sort => ['revisionNum.value', Mongo::DESCENDING], :limit => 1 }
      docCount = @kbDatabase.db[historyCollName].find(queryDoc, opts).count(false)
      if(docCount.to_i > 0)
        historyDoc = @kbDatabase.db[historyCollName].find_one(queryDoc, opts)
        retVal = BRL::Genboree::KB::KbDoc.new(historyDoc)
      end
      return retVal
    end
    
    def getRevisionDocsForSubDoc(docRef, queryPropPaths, sortOpt, extraOpts={}, docCollName=nil)
      orList = []
      queryPropPaths.each {|qp|
        orList.push({ "revisionNum.properties.subDocPath.value" => qp })  
      }
      opts = { :sort => ['revisionNum.value', sortOpt] }
      if(extraOpts.key?(:limit))
        opts[:limit] = extraOpts[:limit].to_i
      end
      qdoc = { 'revisionNum.properties.docRef.value' => docRef, "$or" => orList }
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Running query: #{qdoc.inspect}\nopts: #{opts.inspect}\n\n#{@coll}\n#{@coll.inspect}")
      cursor = nil
      if(docCollName)
        historyCollName = self.class::historyCollName(docCollName)
        cursor = @kbDatabase.db[historyCollName].find(qdoc, opts)
      else
        cursor = @coll.find(qdoc, opts)
      end
      return cursor
    end
    
    # Gets the current revision number for a doc or subdoc
    # @param [BSON::DBRef] docId The reference pointing to the data document.
    # @param [String] propPath
    # @return [Integer] revision number
    def getRevisionNumForDocOrSubDoc(docRef, propPath=nil)
      revNum = nil
      if(propPath.nil?) # Get revision for the entire document
        revDoc = currentRevision(docRef)
        revKbDoc = BRL::Genboree::KB::KbDoc.new(revDoc)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "revKbDoc: #{JSON.pretty_generate(revKbDoc)}")
        revNum = revKbDoc.getPropVal('revisionNum')
      else # Get revision for the specific subdoc inside the document
        propsPathsToSelectorMap = getPropPathsForRevQuery(propPath)
        queryPropPaths = propsPathsToSelectorMap.keys
        revDocs = getRevisionDocsForSubDoc(docRef, queryPropPaths, Mongo::DESCENDING)
        # Loop over (DESC) revision docs and find the first one which has the sub doc of interest. That will be our revision number
        # The revision docs here contain prop paths that include the prop path of interest AND any parent prop that might have the prop path of interest
        revDocs.each {|doc|
          doc.delete("_id") if(doc.key?("_id"))
          kbDoc = BRL::Genboree::KB::KbDoc.new(doc)
          if(kbDoc.getPropVal('revisionNum.deletion'))
            revNum = kbDoc.getPropVal('revisionNum')
            break
          else
            subDocPath = kbDoc.getPropVal('revisionNum.subDocPath')
            if(subDocPath != "/#{propPath}")
              contentDoc = getContentDocForPropPath(kbDoc, subDocPath, propsPathsToSelectorMap)
              next if(contentDoc.nil?)
              revNum = kbDoc.getPropVal('revisionNum')
              break
            else
              revNum = kbDoc.getPropVal('revisionNum')
              break
            end
          end
        }
      end
      return revNum.to_i
    end

    
    # Gets the content doc for the property of interest (@propPath)
    def getContentDocForPropPath(kbDoc, subDocPath, propsPathsToSelectorMap)
      contentDoc = nil
      selectorPath = propsPathsToSelectorMap[subDocPath]
      spCmps = selectorPath.split(".")
      ps = nil
      pathToProp = nil
      if(subDocPath == "/")
        ps = BRL::Genboree::KB::PropSelector.new(kbDoc.getPropVal('revisionNum.content'))
        pathToProp = spCmps[0..spCmps.size-1].join(".")
      else
        ps = BRL::Genboree::KB::PropSelector.new({spCmps[0] => kbDoc.getPropVal('revisionNum.content')})
        pathToProp = spCmps[1..spCmps.size-1].join(".")
      end
      begin
        contentObj = ps.getMultiObj(pathToProp)[0]
        if( pathToProp =~ /\}$/ )
          itemIdentifier = spCmps[spCmps.size-2]
          contentDoc = contentObj[itemIdentifier]  
        else
          propOfInterest = spCmps[spCmps.size-1]
          contentDoc = contentObj[propOfInterest]  
        end
      rescue => err
        # Nothing to do. Property of interest doesnt exist in the parent prop. Most likely the property of interest was added later on to the parent and we are seeing a revision of the parent prior to adding the property of interest
      end
      return contentDoc
    end
    
    
    # Constructs the object to be used in the query to extract all revision documents that can have the property indicated by @propPath
    #   which includes all the parent properties leading to the property of interest
    # The keys of the hash are the prop paths and the values will be used for extracting the prop of interest from the returning subdoc
    # @param [String] propPath property path extracted from the request
    # @return [Hash]
    def getPropPathsForRevQuery(propPath)
      retVal = {}
      propPathCmps = propPath.split(".")
      propPathLength = propPathCmps.size
      processIdx = propPathLength - 1
      propPathCmps.size.times { |ii|
        cmp = propPathCmps[processIdx]
        pp = "/#{propPathCmps[0..processIdx].join(".")}"
        if(cmp =~ /\{/)
          retVal[pp] = "#{propPathCmps[processIdx..propPathLength].join(".")}"
          processIdx -= 3
        else
          retVal[pp] = "#{propPathCmps[processIdx..propPathLength].join(".")}"
          processIdx -= 1
        end
        break if(processIdx == 0)
      }
      retVal['/'] = propPath
      return retVal
    end
    
    # Gets a particular revisioning doc for a document of interest.
    # @todo Move this to a HistoryHelper abstract parent class of RevisionsHelper and RevisionsHelper. Generic.
    # @overload currentRevision(revisionNum, docId)
    #   Use a reference to the document to get its current revisioning record. Preferred.
    #   @param [Fixnum] revisionNum The revision number
    #   @param [BSON::DBRef] docId The reference pointing to the data document.
    # @overload currentRevision(revisionNum, docId, docCollName)
    #   Use an object that can be interpretted as a {BSON::ObjectId} by {BSON::ObjectId.interpret}
    #     as the ObjectId within the collection named in @docCollName@. Ideally an actual
    #     {BSON::ObjectId} object already, like what is returned in the @"_id"@ field by Mongo.
    #     But some auto-casting from other objects to {BSON::ObjectId} are supported (typically to
    #     cast special ID {String}, like hex string returned by {BSON::ObjectId.to_s} during JSON serialization
    #     and similar.)
    #   @param [Fixnum] revisionNum The revision number
    #   @param (see BSON::ObjectId.interpret)
    #   @param [String] docCollName The name of the data collection.
    # @return [KbDoc] the revisioning doc associated with revisionNum for the document of interest.
    def getRevision(revisionNum, docId, docCollName=nil)
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
        'revisionNum.properties.docRef.value' => docRef,
        'revisionNum.value' => revisionNum
      }
      retVal = nil
      docCount = @kbDatabase.db[historyCollName].find(queryDoc, { :limit => 1 }).count(false)
      if(docCount.to_i > 0)
        historyDoc = @kbDatabase.db[historyCollName].find_one(queryDoc, { :limit => 1 })
        retVal = BRL::Genboree::KB::KbDoc.new(historyDoc)
      end
      return retVal
    end

    # Gets ALL revisioning docs for a document of interest.
    # @todo Move this to a HistoryHelper abstract parent class of VersionsHelper and RevisionsHelper. Generic.
    # @overload allRevisions(docId)
    #   Use a reference to the document to get its revisioning records. Preferred.
    #   @param [BSON::DBRef] docId The reference pointing to the data document.
    # @overload allRevisions(docId, docCollName)
    #   Use an object that can be interpretted as a {BSON::ObjectId} by {BSON::ObjectId.interpret}
    #     as the ObjectId within the collection named in @docCollName@.
    #   @param (see BSON::ObjectId.interpret)
    #   @param [String] docCollName The name of the data collection.
    # @return [Array<KbDoc>] all the revisioning record for doc of interest. Should automatically
    #   be from newest->oldest due to the multi-field index with the descending index on @revisionNum@.
    def allRevisions(docId, docCollName=nil)
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
      cursor = @kbDatabase.db[historyCollName].find( { 'revisionNum.properties.docRef.value' => docRef } )
      resultSet = Array.new(cursor.count)
      idx = 0
      cursor.each { |doc|
        resultSet[idx] = BRL::Genboree::KB::KbDoc.new(doc)
        idx += 1
      }
      cursor.close() unless(cursor.closed?)
      return resultSet
    end

    # Given a data collection name and the new revision of a document, create the appropriate
    #  revision record in the corresponding revisioning collection.
    # @param [String] docCollName The name of the data collection where the @newDoc@ has been
    #   saved.
    # @param [BSON::DBRef,BSON::ObjectId,String,Hash] docId A reference to the document in @docCollName@
    #   which has been changed in this revision. Ideally a {BSON::DBRef}, but also supported is anything
    #   that can be converted to a {BSON::ObjectId} via {BSON::ObjectId#interpret}.
    # @param [String] subDocPath A path, rooted at @/@ indicating the field that changed. The root path
    #   itself (@"/"@) indicates the WHOLE document has changed. If a property name has an actual "/"
    #   or %[:xdigit:]{2,2} sequence in it, URL escape that part (i.e. to %2F, %25 etc).
    #   URL escaping all property names when building the path is reasonable.
    # @param [Object] newValue The new content stored at @subDocPath@ in this revision.
    # @param [String] author The Genboree username of the author.
    # @param [Hash] opts An optional hash containing the names of revisioning record fields
    #   mapped to values. Used for overriding the defaults provided by {#docTemplate}. Things like
    #   @"deletion"@, @"comment"@, @"label"@ which are normally nil, empty, or false, etc.
    # @return [BSON::ObjectId] of the saved revisioning document.
    # @raise [ArgumentError] when there is no revisioning collection for @docCollName@, no metadata document
    #   available for @docCollName@, or @newDoc@ doesn't have a @"_id"@ key.
    def createNewHistory(docCollName, docId, subDocPath, newValue, author, opts={})
      retVal = nil
      # newDoc has _id? (hopefully because it has been upserted already)
      if(subDocPath =~ /^\//)
        # Get the docRef for the document.
        if(docId.is_a?(BSON::DBRef))
          docRef = docId
        else
          docRef = BSON::DBRef.new(docCollName, BSON::ObjectId.interpret(docId))
        end
        # Save the revisionDoc directly into the revisions collection
        revisionsCollName = RevisionsHelper.historyCollName(docCollName)
        # Build the base revision doc, to which we'll add the content
        revisionDoc = buildBaseHistoryDoc(docCollName, docRef, subDocPath, author, opts)
        # Note that unlike revisions, we aim to keep only what portion of the document changed,
        # rather than a whole redundant copy! Of course, if the "whole" document changed via the root-path '/'.
        revisionDoc.setPropVal("revisionNum.content", newValue)
        retVal = @kbDatabase.db[revisionsCollName].save( revisionDoc.to_serializable() )
      else
        raise ArgumentError, "ERROR: Your subDocPath (#{subDocPath.inspect} doesn't appear to be a path-like string rooted at the document root '/'."
      end
      return retVal
    end

    # Given a data collection name, create a revision record indicating a document deletion.
    # @param [String] docCollName The name of the data collection from which the doc has been deleted.
    # @param [BSON::DBRef,BSON::ObjectId] docId A reference to the doc deleted or an
    #   identifier which can be interpretted as a {BSON::ObjectId}. If a {BSON::DBRef}, the
    #   @namespace@ property must match @docCollName@.
    # @param [String] author The Genboree username of the author doing the deletion
    # @param [Hash] opts An optional hash containing the names of revisioning record fields
    #   mapped to values. Used for overriding the defaults provided by {#docTemplate}. Things like
    #   @"comment"@, @"label"@ which are normally nil, empty, or false, etc. Note that @opts["deletion"]@
    #   will be forcibly set to @true@.
    # @return [BSON::ObjectId] of the saved revisioning document.
    # @raise [ArgumentError] when @docId@ is a {BSON::DBRef} whose @namespace@ doesn't match @docCollName@.
    def createDeletionHistory(docCollName, docId, subDocPath, author, opts={})
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
      # Save the revisionDoc directly into the revisions collection
      revisionsCollName = RevisionsHelper.historyCollName(docCollName)
      # Build the base vervision doc, to which we'll add the content
      revisionDoc = buildBaseHistoryDoc(docCollName, docRef, subDocPath, author, opts)
      # Note that this is a deletion, so content is nil.
      revisionDoc.setPropVal("revisionNum.content", {})
      retVal = @kbDatabase.db[revisionsCollName].save( revisionDoc.to_serializable() )
      return retVal
    end

    # Given a data collection name, a reference to the doc being changed, the author of the change
    #   and any special options, build the base revision doc nearly suitable for saving. The @"content"@
    #   key of the revision doc will not be filled in, and must be done by the calling code.
    # @param [String] docCollName The name of the data collection where the @newDoc@ has been
    #   saved.
    # @param [BSON::DBRef] docRef The reference pointing to to the data document being changed.
    # @param [String] author The Genboree username of the author.
    # @param [Hash] opts An optional hash containing the names of revisioning record fields
    #   mapped to values. Used for overriding the defaults provided by {#docTemplate}. Things like
    #   @"deletion"@, @"comment"@, @"label"@ which are normally nil, empty, or false, etc.
    # @return [Hash] the base revsion doc
    # @raise [ArgumentError] when there is no revisioning collection for @docCollName@ or no metadata document
    #   available for @docCollName@.
    def buildBaseHistoryDoc(docCollName, docRef, subDocPath, author, opts)
      revisionDoc = nil
      # Need the metadata document for docCollName
      collMetadataHelper = @kbDatabase.collMetadataHelper()
      docCollMetadata = collMetadataHelper.metadataForCollection(docCollName)
      if(docCollMetadata)
        if(docCollMetadata.getPropVal( "name.revisions" ))
          #   a. Get current revision document, if any, or make new from template
          revisionDoc = ( currentRevision(docRef) or docTemplate() )
          #   b. Increment and get revision counter, use in new revision document
          newRevisionNum = nextRevisionNum()
          prevRevisionNum = revisionDoc.getPropVal( "revisionNum" )
          #   c. Fill in rest of template with prev revision info and whatnot
          revisionDoc.delete("_id")
          revisionDoc.setPropVal("revisionNum", newRevisionNum)
          revisionDoc.setPropVal("revisionNum.prevRevision", prevRevisionNum)
          revisionDoc.setPropVal("revisionNum.docRef", docRef) unless(revisionDoc.getPropVal("revisionNum.docRef"))
          revisionDoc.setPropVal("revisionNum.timestamp", Time.now)
          revisionDoc.setPropVal("revisionNum.author", author)
          revisionDoc.setPropVal("revisionNum.subDocPath", subDocPath)
          #     (stuff from opts)
          revisionDoc.setPropVal("revisionNum.label", opts["label"]) if(opts["label"])
          revisionDoc.setPropVal("revisionNum.comment", opts["comment"]) if(opts["comment"])
          revisionDoc.setPropVal("revisionNum.deletion", (opts["deletion"] or false))
          revisionDoc.setPropVal("revisionNum.tags", (opts["tags"] or [ ]))
        else
          raise ArgumentError, "ERROR: There is no revisions collection for #{docCollName.inspect} collection. Cannot create a revision document for it! Maybe it's a core collection which has no revisioning (some don't) or it was created OUTSIDE the GenboreKB framework, probably without using our Ruby library infrastructure & support classes."
        end
      else
        raise ArgumentError, "ERROR: There is no metadata document in kbColl.metadata for the #{docCollName.inspect} collection. It seems to have been created OUTSIDE the GenboreeKB framework, probably without using our Ruby library infrastructure & support classes."
      end
      return revisionDoc
    end

    # Get a document template suitable for the collection this helper assists with.
    # @note The template should be filled in with sensible and convenient default
    #   values, but the calling code will have to fill in appropriate values to
    #   make it match the collection's model and possibily other constraints.
    # @param [nil, Object] Additional parameters, if any, that can help fill out
    #   the template. For example, the model document for the collection of interest.
    # @return [Hash] the document template, partly filled in.
    def docTemplate(collName=nil, modelDoc=nil)
      retVal =
      {
        "revisionNum"  => { "value" => 0, "properties" =>
        {
          "docRef"      => { "value" => nil },
          "prevRevision" => { "value" => 0 },
          "subDocPath"  => { "value" => "/" },
          "author"      => { "value" => nil },
          "timestamp"   => { "value" => Time.now },
          "deletion"    => { "value" => false },
          "label"       => { "value" => nil },
          "comment"     => { "value" => nil },
          "tags"        => { "value" => nil, "items" => [ ] },
          "content"     => { "value" => nil }
        }}
      }
      return BRL::Genboree::KB::KbDoc.new(retVal)
    end

    # Helper method used by AbstractHelper to prepare a document for bulk inserting
    # @param [BSON::DBRef] docRef The reference pointing to the document.
    # @param [Object] doc The new content to fill in the version doc
    # @param [String] author The Genboree username of the author.
    # @param [Hash] docRefToCurrRevMap A mapping of docRefs to their current revision number
    # @param [Hash] opts An optional hash containing the names of versioning record fields
    #   mapped to values. Used for overriding the defaults provided by {#docTemplate}. Things like
    # @return [Hash, KbDoc] revisionDoc The new revision doc to insert for the provided user doc.
    def prepareDocForBulkOperation(docRef, doc, author, docRefToCurrRevMap, opts={})
      raise "opts Hash does not have :count key. Cannot add revisionNum." if(!opts.key?(:count))
      revisionDoc = docTemplate()
      currNum = docRefToCurrRevMap[docRef]
      if(!currNum.nil?)
        revisionDoc.setPropVal("revisionNum.prevRevision", currNum)
      end
      tt = Time.now
      revisionDoc.setPropVal("revisionNum", opts[:count])
      revisionDoc.setPropVal("revisionNum.docRef", docRef)
      revisionDoc.setPropVal("revisionNum.timestamp", Time.now)
      revisionDoc.setPropVal("revisionNum.author", author)
      #     (stuff from opts)
      revisionDoc.setPropVal("revisionNum.label", opts["label"]) if(opts["label"])
      revisionDoc.setPropVal("revisionNum.comment", opts["comment"]) if(opts["comment"])
      revisionDoc.setPropVal("revisionNum.deletion", (opts["deletion"] or false))
      revisionDoc.setPropVal("revisionNum.tags", (opts["tags"] or [ ]))
      revisionDoc.setPropVal('revisionNum.content', doc)
      return revisionDoc
    end
    
    def getDocRefsToCurrRevisionMap(docRefs, collName)
      docRefsToRev = {}
      docObjIdsToDocRefs = {}
      docRefs.each {|docRef|
        docRefsToRev[docRef] = nil
        docObjIdsToDocRefs[docRef.object_id] = docRef
      }
      cursor = @kbDatabase.db[collName].aggregate( [ { "$match" =>  { "revisionNum.properties.docRef.value" => { "$in" => docRefs  }  }  }, {  "$group" => { "_id" => "$revisionNum.properties.docRef.value", "maxVer" => { "$max" => "$revisionNum.value" } }  }   ], :cursor => { "batchSize" => 100 }  )
      cursor.each {|doc|
        docRef = docObjIdsToDocRefs[doc['_id'].object_id]
        docRefsToRev[docRef] = doc["maxVer"].to_i
      }
      return docRefsToRev
    end
    
    # @todo Method to put new {data}.revisions document in kbModels (just a copy)
  end # class ModelsHelper
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers
