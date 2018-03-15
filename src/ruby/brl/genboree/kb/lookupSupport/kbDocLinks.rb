
require 'brl/genboree/dbUtil'
require 'brl/genboree/kb/validators/docValidator.rb'

module BRL ; module Genboree ; module KB ; module LookupSupport
  # Infrastructure class for managing and employing the kbDocLinks records for a specific collection.
  class KbDocLinks

    # ----------------------------------------------------------------
    # Accessors
    # ----------------------------------------------------------------

    # @return [String] The collection name where the kbDocs can be found (the "source" collection FROM which links go out to target docs)
    attr_accessor :collName
    # @return [String] The name of the KB (not the mongo database, the user's name for the kb).
    attr_accessor :kbName
    # @return [BRL::Genboree::KB::MongoKbDatabase] The specific mongo database (i.e. already hooked up to work with kb). Can use
    #   methods to get helper objects and stuff to get the model and work with the collection.
    attr_accessor :mdb
    # @return [BRL::Genboree::DBUtil] A hooked up dbu object which can be used to do queries against main genboree mysql database
    #   (e.g. for kbs table) and against specific user-database backing the KB
    attr_accessor :dbu
    # @return [String] The name of the Genboree user database backing/linked to the kb
    attr_accessor :gbDbName
    # @return [BRL::Genboree::KB::Helpers::ModelsHelper]
    attr_accessor :modelsHelper
    # @return [BRL::Genboree::KB::KbDoc] The model for the collection.
    attr_accessor :model
    # @return [Hash<String,String>] A list of prop paths which have been identified as doc links. The keys are
    #   mapped to target collection name
    attr_accessor :docLinkProps

    # CONSTRUCTOR. Create an instance that will help use manage kbDocLinks for a specific collection within a given KB.
    # @param [String] collName The name of the collection
    # @param [BRL::Genboree::KB::MongoKbDatabase] mdb specific mongo database
    #   methods to get helper objects and stuff to get the model and work with the collection.
    def initialize(collName, mdb, justCreateTable=false, host=nil)
      @collName = collName
      @mdb = mdb
      @modelsHelper = nil
      @model = nil
      @docLinkProps = nil

      # Create @dbu and use it to get the @gbDName (i.e the 'refseqName' value from the main kbs table)
      genbConf = BRL::Genboree::GenboreeConfig.load()
      dbKey = host.nil? ? genbConf.dbrcKey : "DB:#{host}"
      @dbu = BRL::Genboree::DBUtil.new(dbKey, nil, nil)
      kbRecs = @dbu.selectKbByRawDatabaseName(@mdb.name)
      
      @gbDName = kbRecs[0]['refseqName'] rescue nil
      raise ArgumentError, "ERROR: Failed to locate a database corresponding to the mongo KB #{@mdb.name}. This is not allowed and KB document link update cannot proceed without a valid database. Need manual inspection to resolve this. " if(@gbDName.nil? or @gbDName !~ /\S/)
      dbRecs = @dbu.selectDatabaseByName(@gbDName)
      databaseName = dbRecs[0]['databaseName']
      # databaseName
      @dbu.setNewDataDb(databaseName)      
 
      # create table
      raise ArgumentError, "ERROR_CREATE_TABLE: Failed to create kbDocsLink Table for the collection - #{@collName}" if(createTable().nil?)

      # skip the links property retrieval if interested only in creating table
      # when a fresh collection is created these steps can be skipped
      unless(justCreateTable)
        @modelsHelper = @mdb.modelsHelper()
        modelDoc = modelsHelper.modelForCollection(@collName)
        raise ArgumentError, "ERROR: Failed to locate model for the collection #{@collName} for the database #{@mdb.name}. Probably the collection name is not accurate, check spelling, cases, etc." unless(modelDoc)
        @model = modelsHelper.modelFromModelDoc(modelDoc)

        # Examine the model and find all the prop paths that are doc links
        @docLinkProps = docLinkProps()
      end

    end

    # Create the appropriate kbDocLinks table for @@collName@.
    # @return [nil, Fixnum] retVal nil if creation failed and 0 if it already exists or newly created
    def createTable()
      return @dbu.kbDocLinks_createTable(@collName)
    end

    # ----------------------------------------------------------------
    # SELECTING RELEVANT LINK RECORDS
    # ----------------------------------------------------------------

    # Get the raw kbDocLinks table rows for a set of SOURCE kbDocs, optionally restricted to
    #   as set of relevant srcProps. i.e. Find info about links FROM these source docs (which are in @@collName@).
    #   Of generic/iteration use.
    # @param [Array<BRL::Genboree::KB::KbDoc>, Array<Hash>] kbDocs An Array of either actual KbDoc objects,
    #   or an array of unwrapped Hashes, or an array of doc ids (or a mix, ugh). These docs in @collName@ for which we
    #   want to see FROM link info.
    # @param [Array<String>] srcProps Optional. Restrict the results to records involving a set of specific
    #   srcProps of interest; i.e. certain kinds of links via certain properties, not via any property.
    # @return [Array<Array>] The result set rows, possibly empty.
    def tableRowsForSrcDocs(kbDocs, srcProps=nil)
      srcDocIds = extractRootDocIds(kbDocs)
      return @dbu.selectKbDocLinksBySrcDocIds(@collName, srcDocIds, srcProps)
    
    end
   

    # Get the raw kbDocLinks table rows for a set of TARGET kbDocs from some other
    #   specified target collection, optionally restructed to a set of relevant
    #   srcProps. i.e. Find info about links TO these target docs BY docs in @@collName@,
    #   optionally via specific srcProps.
    # @note *Probably* @tgtColl@ is not same as @@collName@, but it could be
    #   if there are records in kbDocLinks table for @@collName@ that point to other
    #   docs in @@collName@--i.e. links for which tgtColl is @@collName@).
    # @param [Array<BRL::Genboree::KB::KbDoc>, Array<Hash>, Array<String>] kbDocs An Array of either actual KbDoc objects,
    #   or an array of unwrapped Hashes, or an array of doc ids (or a mix, ugh). These target docs in @tgtColl@ TO which
    #   we're interested in seeing links BY docs in @collName@.
    #   @param [String] tgtColl target collection name
    # @param [Array<String>] srcProps Optional. Restrict the results to records involving a set of specific
    #   srcProps of interest; i.e. interested in certain kinds of links TO the target docs via certain properties,
    #   not via any property.
    # @return [Array<Array>] The result set rows, possibly empty.
    def tableRowsForTgtDocs(kbDocs, tgtColl, srcProps=nil)
      tgtDocIds = extractRootDocIds(kbDocs)
      return @dbu.selectKbDocLinksByTgtDocIdsAndColl(@collName, tgtDocIds, tgtColl, srcProps)
    end


    # Upsert from KbDocs. Given actual KbDoc objects (or unwrapped Hashes),
    #   determine the doc links within each and upsert kbDocLinks rows.
    # @param [Array<BRL::Genboree::KB::KbDoc>,Array<Hash>]
    # @return [Fixnum] The number of rows upserted into table
    def upsertFromKbDocs(kbDocs)
      # Accumulate kbDocLinks rows.
      #   @todo review this extraction code
      upsertRows = []  # srcProps which have values lead to upsert rows
      deletionPairs = [] # need to track srcDocIds for srcProps when there is NOT [no longer] a value!
      deletionRecs = []
      numRowsUpserted = 0
      kbDocs.each { |doc|
        srcDocId = nil
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "#{doc.keys.inspect}") 
        # Good to get rid of these mongo ids as doc will also be called by PropSelector
        # KbDoc class fails to delete :_id - probable bug there
        doc.delete("_id")
        doc.delete(:_id)
        @docLinkProps.each_key { |srcProp|
          tgtColl = @docLinkProps[srcProp]
          # differentiate the itemlist property paths from the rest
          if(@modelsHelper.withinItemsList(srcProp, @collName))
            psDoc = BRL::Genboree::KB::PropSelector.new(doc)
            srcDocId = psDoc.getMultiPropValues("<>").first
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "srcProp #{srcProp.inspect}") 
            tgtDocUrlValues = getUrlValuesFromItemListProps(srcProp, psDoc)
            tgtDocUrlValues.each {|tgtDocUrlValue|
              tgtDocId = getIdFromUrlValue(tgtDocUrlValue, tgtColl)
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Value Error: Insertion skipped ITEM LIST PROP- Failed to validate the property (#{srcProp.inspect}) value #{tgtDocUrlValue.inspect} with the tgtColl in the object type - #{tgtColl.inspect}. Validation returned - #{tgtDocId.inspect}") unless(tgtDocId)
              upsertRows << [ srcDocId, srcProp, tgtColl, tgtDocId ] if(tgtDocId and tgtDocId =~ /\S/)
            }
           # all the previously entered itemlist props to be deleted
           # is to be added fresh from upsert Rows - applicable only for the itemlist
          else
            kbDoc = doc.is_a?(BRL::Genboree::KB::KbDoc) ? doc : BRL::Genboree::KB::KbDoc.new(doc)
            srcDocId = kbDoc.getRootPropVal()
            tgtDocUrlValue = kbDoc.getPropVal(srcProp) rescue nil
            unless(tgtDocUrlValue.nil?) # skip if the prop has no value in the doc - optional?
              # tgtDocId is not the actual ID is a link, is a labelUrl, url, etc.
              # Get the actual docid
              tgtDocId = getIdFromUrlValue(tgtDocUrlValue, tgtColl)
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Value Error: Insertion skipped - Failed to validate the property (#{srcProp.inspect}) value #{tgtDocUrlValue.inspect} with the tgtColl in the object type - #{tgtColl.inspect}. Validation returned - #{tgtDocId.inspect}") unless(tgtDocId)
              if(tgtDocId and tgtDocId =~ /\S/) # if false returned from the getIdFromUrlValue or empty
                upsertRows << [ srcDocId, srcProp, tgtColl, tgtDocId ]
                # Old tgtDocIds associated with this prop to be deleted
                # The incoming values may be new.
              end
            end
          end
        }
        # all the previously entered itemlist props to be deleted
        # good to delete all the recs corresponding to a source doc id rather than deleting recs wrp to
        # srcdocids and srcProps - must account of obsolete src props, which will be missed
        # if deleted with the second approach (srcdocids and srcProps)
        deletionRecs << srcDocId
      }
      rowsdeleted = deleteBySrcDocIds(deletionRecs) unless(deletionRecs.empty?)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "rowsdeleted#{rowsdeleted.inspect}") 
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "UpsertRows.first ------------------- #{upsertRows.first.inspect}") 
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "UpsertRows.size-----------#{upsertRows.size()}") 
      numRowsUpserted = upsertRawRows(upsertRows)
      return numRowsUpserted
    end

    # Upsert raw table rows to kbDocLinks table. Motivated by upsertFromKbDocs() above, but exposed
    #   as a method for other methods & code.
    # @param [Array<Array>] rows The raw rows to upsert. Ideally 5 column with nil in the first column.
    #   However, if only 4 columns a nil first column (id) will be added for you. Rows with other than
    #   4 or 5 columns are not supported.
    # @return [Fixnum] The number of upserted rows.
    def upsertRawRows(upsertRows)
      return @dbu.upsertKbDocLinksRawRows(@collName, upsertRows)
    end

    # ----------------------------------------------------------------
    # DELETE LINK RECORDS
    # ----------------------------------------------------------------

    # Delete kbDocLinks rows by pairs of srcDocId and srcProp.  Motivated by upsertFromKbDocs() above, but exposed
    #   as a method for other methods & code.
    # @param [Array<Array<String,String>>] srcInfoPairs. An array of tuples. The first value in the tuple is
    #   a srcDocId while the second value in the tuple is a srcProp path. The tuple thus specifies a record to be
    #   removed. Different srcDocIds in the pairs list may be removing records for different srcProps. For example:
    #   Doc A is no longer linked to a target via some.prop.path.1 ; Doc B is no longer linked to a target via
    #   some.prop.path 1 and ALSO no longer linked to a target via via some.other.path.2
    # @return [Fixnum] The number of deleted records.
    def deleteBySrcInfoPairs(srcInfoPairs)
      return @dbu.deleteKbDocLinksBySrcInfoPairs(@collName, srcInfoPairs)
    end

    # Delete all the links in the table matching a set of source doc ids
    # @param [Array<String>] srcDocIds list of source doc ids
    # @return [Fixnum] number of records deleted
    def deleteBySrcDocIds(srcDocIds)
      return @dbu.deleteKbDocLinksBySrcDocIds(@collName, srcDocIds)
    end

    # Deletes all the links from the table for a specific document
    # Useful when a document is deleted
    # @param [String] srcDocId source document id of the document that is to be deleted
    # @param [String] srcProp source property
    # @param [String] tgtColl name of the target collection
    # @return [Fixnum] number of rows deleted
    def deleteBySrcDocId(srcDocId, srcProp=nil, tgtColl=nil)
      return @dbu.deleteKbDocLinksBySrcDocId(@collName, srcDocId)
    end


    # Delete the records for kbDocs.
    # @param [Array<BRL::Genboree::KB::KbDoc>, Array<Hash>, Array<String>] kbDocs An Array of either actual KbDoc objects,
    #   or an array of unwrapped Hashes, or an array of doc ids (or a mix, ugh). These docs for which we will delete kbDocLinks rows.
    # @return [Fixnum] The number of records deleted.
    def deleteForKbDocs(kbDocs)
      srcDocsIds = extractRootDocIds(kbDocs)
      return @dbu.deleteKbDocLinksBySrcDocIds(@collName, srcDocsIds)
    end

    # ----------------------------------------------------------------
    # Public Helpers - mainly used internally, but public since may be useful outside this class
    # ----------------------------------------------------------------

    # Discover the properties in the model which are doc links.
    # @return [Hash<String,String>] Each property path that is a doc link is mapped to
    #   the TARGET collection name extracted from the Object Type column of the model.
    def docLinkProps()
      unless(@docLinkProps) # if already have this info, just return it ; else examine model to discover it
        @docLinkProps = {}
        @modelsHelper.eachPropDef(@model, @model["name"], {:format=>:model}) {|obj|
          domain = obj[:propDef]['domain'] ? obj[:propDef]['domain'] : "String"
          objType = obj[:propDef]['Object Type'] 
          subRelToObj = obj[:propDef]['Subject Relation to Object']
          # look for certain domains - labelUrl/labelUrl()
          if((domain == 'url' or domain =~ /^labelUrl.*$/ or domain == 'selfUrl') and subRelToObj != 'isSelf' and objType =~ /^([^:]+):(.+)$/)
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "PropPath: #{obj[:propPath]} \n\n Domain : #{domain.inspect} \n\n subRelToObj : #{subRelToObj.inspect} \n propDef : #{obj[:propDef].inspect} Object Type : #{objType.inspect}")
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "#{$2.inspect}") 
            @docLinkProps[obj[:propPath]] = $2.strip
          end
        }
      end
      return @docLinkProps
    end

    # Examine a set of KbDocs (or unwrapped Hashes) and extract the root doc ids of each, returning
    #   the list of doc ids.
    # @param [Array<BRL::Genboree::KB::KbDoc>, Array<Hash>, Array<String>] The array of KbDocs to examine.
    #   If Hashes are encountered they are presumed to be unwrapped KbDocs. If a String is encountered,
    #   it's assumed to already be a doc id; thus it's same to call this method even when you already have
    #   a list of doc ids and you don't 100% understand your code's flow (you just are wasting a very little time).
    # @return [Array<String>] The list of extracted doc ids.
    def extractRootDocIds(kbDocs)
      docIds = kbDocs.deep_clone
      # We need srcDocIds to have the ids, not actual docs. So extract doc id if needed:
      docIds.map! { |doc|
        if(doc.is_a?(BRL::Genboree::KB::KbDoc))
          doc.getRootPropVal()
        elsif(doc.is_a?(Hash))
          BRL::Genboree::KB::KbDoc.new(doc).getRootPropVal()
        else # better be the doc id as a string
          doc.to_s
        end
      }
      return docIds
    end

    # Get the doc id from the url after validating it with the tgtColl in the resp object type
    # @param [String] urlValue the property value
    # @param [String] tgtColl target collection name 
    # @return [String, Boolean] retVal document ID from the URL, false if validation fails
    def getIdFromUrlValue(urlValue, tgtColl)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "urlValue - tgtColl #{urlValue.inspect} - #{tgtColl.inspect}") 
      return BRL::Genboree::KB::Validators::DocValidator::validateObjectTypeToPropValue(urlValue, nil, @mdb, tgtColl, true)
    end

    # return the src document property value for an itemlist property using propSel
    # @param [String] srcProp source property which is the model path
    # @param [BRL::Genboree::Kb::PropSelector] psDoc the document from which the values are to be extracted
    # @return [Array<String>] tgtUrlValues property values
    def getUrlValuesFromItemListProps(srcProp, psDoc)
      tgtUrlValues = []
      propSelPath = @modelsHelper.modelPathToPropSelPath(srcProp, @model)      
      tgtUrlValues = psDoc.getMultiPropValues(propSelPath) rescue nil      
      tgtUrlValues = tgtUrlValues.nil? ? [] : tgtUrlValues.compact
      return tgtUrlValues
    end


  end # class KbDocLinks
end ; end ; end ; end
