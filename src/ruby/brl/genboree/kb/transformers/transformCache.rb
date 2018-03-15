require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/dbUtil'
require 'brl/genboree/kb/validators/transformCacheValidator'
require 'brl/genboree/kb/helpers/transformCacheHelper'
require 'brl/genboree/kb/helpers/transformsHelper'
require 'brl/genboree/kb/stats/collStats'

module BRL ; module Genboree ; module KB ; module Transformers
  # Class for transforming a Genboree KB document(s) to a transformed document.
  # Transformed document in this context is a JSON which is not
  # property oriented.
  # Is instantiated with a Hash (a genboreKB document that represents the
  # transformation rules defined by the model described in TransformsHelper),
  #  It will also respond to the methods that are added below.
  # @example Instantiation
  #   tr1 = Transformer.new(aHash)

  class TransformCache
  
    # regular expressions for doc and docs cache keys
    CACHE_KEY_DOCS = %r{^([^/\?]+)/docs\|([^/\?]+)\|(?:HTML|SMALLHTML|JSON)$} 
    CACHE_KEY_DOC = %r{^([^/\?]+)/doc/([^/\?]+)\|([^/\?]+)\|(?:HTML|SMALLHTML|JSON)$}
    
    # Messages 
    attr_accessor :cachedMessages
    attr_accessor :transformationName
    attr_accessor :format
    attr_accessor :sourceColl
 
    def initialize(mongoKbDb)
      @mongoKbDb = mongoKbDb
      @trCh = mongoKbDb.transformCacheHelper
      @trChValidator = BRL::Genboree::KB::Validators::TransformCacheValidator.new()
      @cachedMessages = [] # for dev purposes
      @crossmdb = nil
    end

    # check the current params against the cached Doc and return doc
    def getCachedOutput(cacheKey, assoColls)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "CacheKey #{cacheKey.inspect}")
      output = nil
      allCollinSync = true
      extracolls = {}
      assoColls.each{|col| extracolls[col] = true }
      @sourceColl, sourceDoc, @transformationName, @format = getParamsFromKey(cacheKey)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "CacheKey #{cacheKey.inspect}")
      # check if the cache already exists?
      mgcursor = @trCh.coll.find({'TransformCache.value' => CGI.unescape(cacheKey)})
      cachedDoc = nil
      mgcursor.each{|dd| cachedDoc = dd }
      if(cachedDoc and !cachedDoc.empty?)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "CachedDoc#{cachedDoc.inspect}")
        if(cachedDoc['TransformCache']['properties']['TransformVersion']['value'] == getVersion(BRL::Genboree::KB::Helpers::TransformsHelper::KB_CORE_COLLECTION_NAME, @transformationName))
          st = BRL::Genboree::KB::Stats::CollStats.new(@mongoKbDb, @sourceColl)
          srcCollEditTime = st.lastEditTime
          if(cachedDoc['TransformCache']['properties']['SourceCollEditTime']['value'] == srcCollEditTime)
            if(cachedDoc['TransformCache']['properties'].key?('CollEditTimes') and cachedDoc['TransformCache']['properties']['CollEditTimes']['items'].size > 0)
              cachedDoc['TransformCache']['properties']['CollEditTimes']['items'].each{|item|
                if(extracolls.key?(item['Coll']['value']) and allCollinSync)
                  coll = item['Coll']['value']
                  extracolls.delete(coll)
                  st = BRL::Genboree::KB::Stats::CollStats.new(@mongoKbDb, coll)
                  editTime = st.lastEditTime
                  if(editTime != item['Coll']['properties']['EditTime']['value'])
                    allCollinSync = false
                    break
                  end
                else
                  allCollinSync = false
                  break
                end
              }
            end
            if(allCollinSync and extracolls.keys.size > 0)
                allCollinSync = false
            end
            if(allCollinSync)
              if(sourceDoc.nil?)
                output = cachedDoc['TransformCache']['properties']['Output']['value']
              elsif(sourceDoc and  cachedDoc['TransformCache']['properties']['SourceDocVersion']['value'] == getVersion(@sourceColl, sourceDoc))
                #TO DO if all the associated collection edititems
                output = cachedDoc['TransformCache']['properties']['Output']['value']
              else
                @cachedMessages << "Source Doc Version failed to match. Cache - #{cachedDoc['TransformCache']['properties']['SourceDocVersion']['value']} :: Current - #{getVersion(@sourceColl, sourceDoc)}"
                output = nil
              end
            else
              output = nil
              @cachedMessages << "CollEditTimes property in the cached output failed to match the associated collections edit times - #{assoColls.inspect}"
            end
          else
            @cachedMessages << "Source Coll Edit time not current"
            output = nil
          end
        else
          @cachedMessages << "Transform Version failed to match"
          output = nil
        end
      else
        @cachedMessages << "NO_DOC: No document with the identifier - #{CGI.unescape(cacheKey)} in the kbTransforms.cache collection"
        output = nil
      end
      return output
    end

    def updateCache(cacheKey, output, associatedColls)
      associatedColls = associatedColls.uniq
      # get the params
      @sourceColl, sourceDoc, @transformationName, @format = getParamsFromKey(cacheKey)
      # check if the cache already exists?
      mgcursor = @trCh.coll.find({'TransformCache.value' => CGI.unescape(cacheKey)})
      cachedDoc = nil
      updatedDoc = nil
      srcCollEditTime = nil
      mgcursor.each{|dd| cachedDoc = dd }
      if(cachedDoc and !cachedDoc.empty?)
        updatedDoc = cachedDoc
      else
        updatedDoc = @trCh.docTemplate()
      end
        # doc identifier with the cacheKey
        updatedDoc['TransformCache']['value'] = CGI.unescape(cacheKey)
        # update the  doc with new versions, editTimes and output
        
        updatedDoc['TransformCache']['properties']['TransformVersion']['value'] = getVersion(BRL::Genboree::KB::Helpers::TransformsHelper::KB_CORE_COLLECTION_NAME, @transformationName)
        # source coll edit time
        st = BRL::Genboree::KB::Stats::CollStats.new(@mongoKbDb, @sourceColl)
        srcCollEditTime = st.lastEditTime
        updatedDoc['TransformCache']['properties']['SourceCollEditTime']['value'] = srcCollEditTime
        # check for CollEditTimes
        if(associatedColls.empty?)
          if(updatedDoc['TransformCache']['properties'].key?('CollEditTimes'))
            updatedDoc['TransformCache']['properties'].delete('CollEditTimes')
          end
        else
          updatedDoc['TransformCache']['properties']['CollEditTimes'] = {'items' => []}
          associatedColls.each{|col|
            st = BRL::Genboree::KB::Stats::CollStats.new(@mongoKbDb, col)
            editTime = st.lastEditTime
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Edittime for #{col.inspect} :: #{editTime.inspect}")
            if(editTime) # nil when the coll is empty
              obj =   {"Coll" =>  {"properties" => { "EditTime"=> {"value"=> editTime }},"value"=> col }}
              updatedDoc['TransformCache']['properties']['CollEditTimes']['items'] << obj
            end
          }
        end
        # sourceDoc Version
        if(sourceDoc)
         updatedDoc['TransformCache']['properties']['SourceDocVersion'] = {"value" => getVersion(@sourceColl, sourceDoc)}
        end
        # output
        if(@format == 'JSON')
          updatedDoc['TransformCache']['properties']['Output']['value'] = output.to_json
        else
          updatedDoc['TransformCache']['properties']['Output']['value'] = output
        end

        # to do: get the edit times of all the collections of the transformation rules

        # validate before saving
        isValid = @trChValidator.validate(updatedDoc)
        if(isValid)
          #save
          objId = nil
          objId = @trCh.save(updatedDoc, @mongoKbDb.conn.defaultAuthInfo[:user])
          unless(objId.is_a?(BSON::ObjectId))
            raise "SAVE_ERROR: Failed to save the document to the transform Cache collection"
          else
              
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "SAved!!!!i")
          end
        else
          if( @trChValidator.respond_to?(:buildErrorMsgs) )
            errors = @trChValidator.buildErrorMsgs()
          else
            errors = @trChValidator.validationErrors
          end
          raise "INVALID_CACHE_DOC: Cached doc failed validation against the model:\n#{errors.join("\n")}"
        end
      return updatedDoc
    end


    def getParamsFromKey(cacheKey)
      sourceColl = nil
      sourceDoc = nil
      transformationName = nil
      trName = nil
      format = nil
      if(cacheKey =~ CACHE_KEY_DOCS)
        ckeysplit = cacheKey.split("|")
        format = ckeysplit.last
        transformationName = ckeysplit[-2]
        trName = checkForTransformationUrl(transformationName)
        sources = ckeysplit.first.split("/")
        sourceColl = sources.first
        sourceDoc = nil
      elsif(cacheKey =~ CACHE_KEY_DOC)
        ckeysplit = cacheKey.split("|")
        format = ckeysplit.last
        transformationName = ckeysplit[-2]
        trName = checkForTransformationUrl(transformationName)
        sources = ckeysplit.first.split("/")
        sourceColl = sources.first
        sourceDoc = sources[2]
      else
        raise ArgumentError, "CACHE_KEY_ERROR: #{cacheKey} not a valid key. Key must follow either #{CACHE_KEY_DOCS} or #{CACHE_KEY_DOC}" 
      end
      return sourceColl, sourceDoc, transformationName, format
    end

    def getVersion(collName, docID)
      version = nil
      docIdObj = nil
      dbRef = nil
      versionList  = []
      versionDoc = nil
      if(collName == BRL::Genboree::KB::Helpers::TransformsHelper::KB_CORE_COLLECTION_NAME)
        identProp = 'Transformation'
        # check if the transformation docID id an ID or url
        trName = checkForTransformationUrl(docID)
        if(@crossmdb)
          vh = @crossmdb.versionsHelper(collName)
          doc = vh.exists?(identProp, trName, collName)
        else
          vh = @mongoKbDb.versionsHelper(collName)
          doc = vh.exists?(identProp, docID, collName)
        end
      else
        dataCollHelper = @mongoKbDb.dataCollectionHelper(collName) rescue nil
        if(dataCollHelper)
          identProp = dataCollHelper.getIdentifierName()
        else
          raise ArgumentError, "NO_COLL: No collection #{collName} under the KB - #{@mongoKbDb.name}"
        end
        vh = @mongoKbDb.versionsHelper(collName)
        doc = vh.exists?(identProp, docID, collName)
      end
      unless(doc)
        raise ArgumentError, "NO_DOC: there is not document with the identifier #{docID} in the collection #{collName}" 
      end
      docIdObj = doc.getPropVal('versionNum.content')['_id']
      dbRef = BSON::DBRef.new(collName, docIdObj)
      versionList = vh.allVersions(dbRef)
      versionDoc = BRL::Genboree::KB::KbDoc.new(versionList.last)
      version = versionDoc.getPropVal('versionNum')
      version = version.to_i if(version) 
      return version
    end

    def checkForTransformationUrl(trID) 
     trName = nil
     trUrl = URI.parse(CGI.unescape(trID)) rescue nil
     if(trUrl and trUrl.scheme)
        trPath = trUrl.path
        trHost = trUrl.host
        patt = %r{^/REST/v1/grp/([^/\?]+)/kb/([^/\?]+)/(?:trRulesDoc|transform)/([^/\?]+)$}
        if(trHost and trPath =~ patt)
          pathsplit = trPath.split("/")
          grp = CGI.unescape(pathsplit[4])
          kb = CGI.unescape(pathsplit[6])
          trName = CGI.unescape(pathsplit[8])
          dbu = BRL::Genboree::DBUtil.new("DB:#{trHost}", nil, nil)
          dbrc = BRL::DB::DBRC.new()
          mongoDbrcRec = dbrc.getRecordByHost(trHost, :nosql)
          dbRecs = dbu.selectKbByNameAndGroupName(kb, grp)
          if(dbRecs.empty?)
            raise "NO Record in the databases for a KB by the grp - #{grp} and kb = #{kb}"
          else
            mongoDbName = dbRecs[0]['databaseName']
          end
          @crossmdb = BRL::Genboree::KB::MongoKbDatabase.new(mongoDbName, mongoDbrcRec[:driver], { :user => mongoDbrcRec[:user], :pass => mongoDbrcRec[:password] } )
          if(!(@crossmdb.db.class == Mongo::DB))
            raise "MDB: #{@crossmdb.name.inspect} is not a valid KB database or does not exist."
          end
        else
          raise "TRANSFORMATION_ERROR: Invalid URL representation for transformation #{docID}"
        end
      else # not a url
        trName = trID
      end
     return trName
    end
  end
end; end; end; end;

