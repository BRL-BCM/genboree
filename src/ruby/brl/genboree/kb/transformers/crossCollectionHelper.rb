#!/usr/bin/env ruby
require 'cgi'
require 'brl/genboree/kb/propSelector'
require 'brl/genboree/kb/lookupSupport/kbDocLinks'

module BRL; module Genboree; module KB; module Transformers
        
  # Helper class for cross collection query
  class CrossCollectionHelper

    def initialize(mongoKbDb)
      @crossmdb = mongoKbDb
    end


   def getLinksFromSrcDocIdsAndSrcProps(srcCollName, srcDocIds, srcProps, returnHash=true, returnArray=false)
    retVal = nil
    tableRows = [] 
    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "srcCollName: #{srcCollName.inspect} \n srcDocIds #{srcDocIds.inspect}\n srcProps: #{srcProps.inspect}")
    kb = BRL::Genboree::KB::LookupSupport::KbDocLinks.new(srcCollName, @crossmdb)
    tableRows = kb.tableRowsForSrcDocs(srcDocIds, srcProps)
    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "srcCollName: #{srcCollName.inspect} \n srcDocIds #{srcDocIds.inspect}\n srcProps: #{srcProps.inspect}")
    # retrun as a hash -> key:srcDocId, value:tgetDocIds
    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "tableRows: #{tableRows.inspect}")
    if(returnHash and !tableRows.empty?)
      retVal = Hash.new{ |hh, kk| hh[kk] = [] }
      tableRows.each { |row| retVal[row["srcDocId"]] << row["tgtDocId"] }
    elsif(returnArray and !tableRows.empty?) 
      retVal = []
      tableRows.each { |row| retVal << row["tgtDocId"] } 
    end 
    return retVal
   end

   # tableRowsForTgtDocs
   def getLinksFromTgtDocIdsAndSrcProps(srcCollName, tgtCollName, tgtDocIds, srcProps, returnHash=true, returnArray=false)
     retVal = nil
     tableRows = []
     kb = BRL::Genboree::KB::LookupSupport::KbDocLinks.new(srcCollName, @crossmdb)
     tableRows = kb.tableRowsForTgtDocs(tgtDocIds, tgtCollName, srcProps)
    if(returnHash and !tableRows.empty?)
      retVal = Hash.new{ |hh, kk| hh[kk] = [] }
      tableRows.each { |row| retVal[row["srcDocId"]] << row["tgtDocId"] }
    elsif(returnArray and !tableRows.empty?)
      retVal = []
      tableRows.each { |row| retVal << row["tgtDocId"] }
    end
    return retVal
   end

   def doJoinsUsingKbDocLinks(joinConfs, docIds, indexSubjects=false, subjects={})
     retVal = nil
     sourceDocTosubDocLinks = {}
     subjectsToPartitions = {}
     # Get the subjects -> subjects for the first round
     subjects.values.flatten.inject(subjectsToPartitions) {|hh, kk| hh[kk] = kk ; hh ; }if(!subjects.empty? and indexSubjects)
     #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "subjectsToPartitions ::: #{subjectsToPartitions.inspect}")
     joinConfs.each_with_index{|joinConf, ind|
       unless(docIds.empty?)
         # get the source collection name to link to the kbDoclinks table
         # manage for items with more than one join
         # srcColl, tgtColl, joinType, srcProps
         srcCollName, tgtCollName, joinType, srcProps =  getConfSpecsForLinksTable(joinConf)
         #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "srcColl: #{srcCollName.inspect} \n srcProp #{srcProps.inspect}")
         #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "docIds: #{docIds.inspect}")
         if(joinType == "from")
           #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "srcColl: #{srcCollName.inspect} \n tgtCollName: #{tgtCollName.inspect} \n joinType : #{joinType.inspect} \n srcProp #{srcProps.inspect}")
           docLinks = getLinksFromTgtDocIdsAndSrcProps(srcCollName, tgtCollName, docIds, srcProps)
         else
           #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "srcColl: #{srcCollName.inspect} \n tgtCollName: #{tgtCollName.inspect} \n joinType : #{joinType.inspect} \n srcProp #{srcProps.inspect}")
           docLinks = getLinksFromSrcDocIdsAndSrcProps(srcCollName, docIds, srcProps)
         end
         #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "docLinks - #{docLinks.inspect}")
         if(docLinks.nil? or docLinks.empty?)
           retVal = [{}, {}]
           break
         else
           # get the docLinks connect to the first join document ids
           if(ind == 0)
             subjectsToPartitionsTmp = Hash.new {|hh, kk| hh[kk] = []}
             #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "ind-> #{ind}")
             if(joinType == "from")
               subjectsToPartitionsTmp = Hash.new {|hh, kk| hh[kk] = []}
               docIds.inject(sourceDocTosubDocLinks) {|hh, kk| hh[kk] = []; hh; }
               sourceDocTosubDocLinks.each_key{|docid|
                 docLinks.keys.each{|key|
                   if(docLinks[key].include?(docid))
                     sourceDocTosubDocLinks[docid] << key
                     subjectsToPartitionsTmp[key] << docLinks[key]
                     subjectsToPartitionsTmp[key].flatten!
                   end
                 }             
               }
             else
               subjects.values.flatten.inject(subjectsToPartitionsTmp) {|hh, kk| hh[kk] = kk ; hh ; }if(!subjects.empty? and indexSubjects)
               sourceDocTosubDocLinks = docLinks
             end
              
             retVal = sourceDocTosubDocLinks, subjectsToPartitionsTmp
             docIds = docLinks.values.flatten if(docLinks)
           else
             # make connections from the source doc ids to the subdoc links
             # Analysis->Biosamples-> Experiments
             # Which Experiments belong to which Analysis doc
             # Used for connecting subjects from the source doc to the partition values in the main lib
             tmp = Hash.new{|hh, kk| hh[kk] = []}
             subjectsToPartitionsTmp = Hash.new {|hh, kk| hh[kk] = []}
             #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "sublinks found")
             if(joinType == "from")
               sourceDocTosubDocLinks.each_key{|docid|
                 docLinks.keys.each{|key|
                   values = sourceDocTosubDocLinks[docid]
                   #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "KEY: #{key.inspect}")
                   values.each {|val|
                     if(docLinks[key].include?(val))
                       tmp[docid] << key
                       subjectsToPartitionsTmp[key] << docLinks[key]
                       subjectsToPartitionsTmp[key].flatten!
                       #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "BREAK!!!!!!!!!!!!!!!!!!!")
                       break
                     end
                  }
                 }
               }
             #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "source to sublinks retreived: #{tmp.inspect}")
             else
               docLinks.keys.each{|key|
                 sourceDocTosubDocLinks.each_key{|docid|
                   if(sourceDocTosubDocLinks[docid].include?(key))
                     tmp[docid] << docLinks[key]
                     tmp[docid] = tmp[docid].flatten
                     tmp[docid] = tmp[docid].uniq

                     # get the subject relation to partition docs
                     docLinks[key].inject(subjectsToPartitionsTmp) {|hh, kk| hh[kk] << subjectsToPartitions[key] ; hh[kk].flatten!; hh;} if(!subjects.empty? and indexSubjects)
                   end
                 }
               }
             $stderr.debugPuts(__FILE__, __method__, "DEBUG", "source to sublinks retreived: #{tmp.inspect}")
             end
             sourceDocTosubDocLinks = tmp
             subjectsToPartitions = subjectsToPartitionsTmp
             retVal = tmp, subjectsToPartitions
           end
           docIds = sourceDocTosubDocLinks.values.flatten if(docLinks)
         end
       else
         # no source docs to get links for
         retVal = nil
         break
       end
     } 
     #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "retVal: #{retVal.inspect}")
     return retVal
   end


    
    # Gets document records after querying and joining of two collections'.
    # Query is performed always on a source and a target collection.
    # @param [Hash] sourceDoc the Genboree KB data document and is the 'source' for every first join.
    # @param [Hash] joinConfs join configurations for each of the sequential joins
    # @param [String] sourceCollName name of the source collection
    # @return [Array<Array>] retVal document records returned after the final query. 
    # @return [Array<Array>] messages list of messages for the query where no records were found.
    # @note The records returned from this method are not'indexed'.
    def doJoins(sourceDoc, joinConfs, sourceCollName)
      documents = Array.new()
      messages = Array.new()
      unless(joinConfs.empty?)
        joinConfs.each_with_index{|joinConf, ind|
          matchValues = Array.new()
          checkedMatchValues = Array.new()
          if(ind == 0)
            # The initial query is between the source document and a target document
            # This has to be separated from the rest of the joins.
            # Get the initial set of 'matchValues' for the query
            ps = BRL::Genboree::KB::PropSelector.new(sourceDoc)
            vals = joinConf['JoinConfig']['properties']['Match Values']['value']
            raise ArgumentError, "EMPTY_FIELD: Value for the field 'Match Values' is empty or invalid." unless(vals =~ /\S/)
            matchValues = ps.getMultiPropValues(vals) rescue nil
            if(matchValues)
              begin
                checkedMatchValues = checkMatchValuesBeforeMatch(matchValues, vals, sourceDoc, sourceCollName)
              rescue => err
                raise "Error in getting domain definition for the Match Values, for the property path - #{vals.inspect} from the join configuration. Details - #{err.message}"
              end
            else
              checkedMatchValues = []
            end
          else
            # for the subsequent joins the 'matchValues' are retrieved from the returned documents of the previous query
            vals = joinConf['JoinConfig']['properties']['Match Values']['value']
            documents.each{|doc| matchValues << doc.getMultiPropValues(vals) }
            matchValues.flatten!
            matchValues.uniq!
            if(matchValues)
              begin
                checkedMatchValues = checkMatchValuesBeforeMatch(matchValues, vals, sourceDoc, sourceCollName)
              rescue => err
                raise "Error in getting domain definition for the Match Values, for the property path - #{vals.inspect} from the join configuration. Details - #{err.message}"
              end
            else
              checkedMatchValues = []
            end
          end
          # get all the query parameters from the join config object
          joinType, dataHelper, modelsHelper, matchProp, mode, collName, cardinality = getConfProps(joinConf)
          if(joinType == 'search' or joinType.nil?)
            docCursor = getDocCursor(dataHelper, modelsHelper, checkedMatchValues, matchProp, mode, collName)
          else
            docCursor = getDocCursorFromUrl(dataHelper, modelsHelper, checkedMatchValues, matchProp, collName)
          end
          if(cardinality == '1') # Check the number of the records
            raise "Error: Cardinality for the join is 1 and is not equal to the number of documents from the mongo query ( #{docCursor.count}). For the collection #{collName} for match values #{checkedMatchValues.inspect} and match properties #{matchProp.inspect}." unless(docCursor.count == 1)
          end
          if(docCursor.count == 0)
            messages << "No records found for the query on the collection #{collName} :: for the match values #{checkedMatchValues.inspect} and properties #{matchProp.inspect}."
            documents = []
            break
          else
            documents = []
            docCursor.each{|doc|
              doc.delete("_id")
              documents << BRL::Genboree::KB::PropSelector.new(doc)
            }
          end
        }
      else
        raise ArgumentError, "JOINCONF_ERROR: No configurations found for the query operation. #{joinConfs.inspect}"
      end
      return documents, messages
    end


    # Gets document records after querying and joining of two collections'.
    # Query is performed always on a source and a target collection.
    # @param [Hash] sourceDoc the Genboree KB data document and is the 'source' for every first join.
    # @param [Hash] joinConfs join configurations for each of the sequential joins
    # @param [String] sourceCollName name of the source collection
    # @return [Array<Array>] retVal document records returned after the final query.
    # @return [Array<Array>] messages list of messages for the query where no records were found.
    # @note The records returned from this method are 'indexed'. Records from the first list of retVal corresponds
    # to the first 'matchValue' of the very first join.
    def doJoinsIndexFirstJoin(sourceDoc, joinConfs, sourceCollName)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Getting a new set of partitions . . . . . . . ")
      documents = Array.new()
      docIndexed = Array.new()
      messages = Array.new()
      joinIndex = BSON::OrderedHash.new 
      joinIndTmp = BSON::OrderedHash.new
      lookUpbyId = {}
      collName = nil 
      unless(joinConfs.empty?)
        joinConfs.each_with_index{|joinConf, ind|
          matchValues = Array.new()
          if(ind == 0)
            # The initial query is between the source document and a target document
            # This has to be separated from the rest of the joins.
            # Get the initial set of 'matchValues' for the query
            matchValues = Array.new()
            ps = BRL::Genboree::KB::PropSelector.new(sourceDoc)
            vals = joinConf['JoinConfig']['properties']['Match Values']['value']
            raise ArgumentError, "EMPTY_FIELD: Value for the field 'Match Values' is empty or invalid." unless(vals =~ /\S/)
            matchValues = ps.getMultiPropValues(vals) rescue nil
            begin
              checkedMatchValues = checkMatchValuesBeforeMatch(matchValues, vals, sourceDoc, sourceCollName)
            rescue => err
              raise "Error in getting domain definition for the Match Values, for the property path - #{vals.inspect} from the join configuration. Details - #{err.message}"
            end        
            checkedMatchValues.each{ |match|
              lookUpbyId[match] = [match]
              joinIndTmp[match] = []
            }
          else
            lookUpbyId = {}
            # for the subsequent joins the 'matchValues' are retrieved from the returned documents of the previous query
            vals = joinConf['JoinConfig']['properties']['Match Values']['value']
            documents.each{|doc| matchValues << doc.getMultiPropValues(vals) }
            matchValues.flatten!
            matchValues.uniq!
            begin
              checkedMatchValues = checkMatchValuesBeforeMatch(matchValues, vals, documents.first, collName)
            rescue => err
              raise "Error in getting domain definition for the Match Values, for the property path - #{vals.inspect} from the join configuration. Details - #{err.message}"
            end
            joinIndTmp.each_key{|jjkey|
              joinIndTmp[jjkey].each{|docu|
                ids = docu.getMultiPropValues(vals)
                ids.flatten!
                ids.uniq!
                begin
                  ids = checkMatchValuesBeforeMatch(ids, vals, docu, collName)
                rescue => err
                  raise "Error in getting domain definition for the Match Values, for the property path - #{vals.inspect} from the join configuration. Details - #{err.message}"
                end
                ids.each{|ide|
                  if(lookUpbyId.key?(ide))
                    lookUpbyId[ide] << jjkey
                    lookUpbyId[ide] = lookUpbyId[ide].uniq
                  else
                    lookUpbyId[ide] = [jjkey]
                  end 
                }
              }
             # remove the previous docs
             joinIndTmp[jjkey] = []
            }
          end
          # get all the query parameters from the join config object
          joinType, dataHelper, modelsHelper, matchProp, mode, collName, cardinality = getConfProps(joinConf)
          if(joinType == 'search' or joinType.nil?)
            docCursor = getDocCursor(dataHelper, modelsHelper, checkedMatchValues, matchProp, mode, collName)
          else
            docCursor = getDocCursorFromUrl(dataHelper, modelsHelper, checkedMatchValues, matchProp, collName)
          end
          if(cardinality == '1') # Check the number of the records
            raise "Error: Cardinality for the join is 1 and is not equal to the number of documents from the mongo query ( #{docCursor.count}). For the collection #{collName} for match values #{checkedMatchValues.inspect} and match properties #{matchProp.inspect}." unless(docCursor.count == 1)
          end
          if(docCursor.count == 0)
            messages << "No records found for the query on the collection #{collName} :: for the match values #{checkedMatchValues.inspect} and properties #{matchProp.inspect}."
            documents = []
            break
          else
            documents = []
            docCursor.each{|doc|
              docps = BRL::Genboree::KB::PropSelector.new(doc)
              docps.delete("_id")
              matchedvalues = []
              matchedvalues = docps.getMultiPropValues(matchProp) rescue nil
              begin
                matchedvalues = checkMatchValuesBeforeMatch(matchedvalues, matchProp, doc, collName)
              rescue => err
                raise "Error in getting domain definition for the Match Values, for the property path - #{matchProp.inspect} from the join configuration. Details - #{err.message}"
              end
              unless(matchedvalues.empty?)
                matchedvalues = matchedvalues.compact
                matchedvalues = matchedvalues.uniq
                matchedvalues.each{|mvv|
                  if(lookUpbyId.key?(mvv))
                    lookUpbyId[mvv].each{|jkey| joinIndTmp[jkey] << docps }
                  end
                 }
              end
              documents << docps
            }
          end
        }
      else
        raise ArgumentError, "JOINCONF_ERROR: No configurations found for the query operation. #{joinConfs.inspect}"
      end
     final = joinIndTmp.values 
     return joinIndTmp.values, messages
    end




    
    # Extracts all the parameters from  a single join configuration object.
    # @param [Hash] joinConf object for a single cross collection query
    # @return [String] joinType type of search 
    # @return [Object] dataHelper instance of class BRL::Genboree::KB::Helpers::DataCollectionHelper
    # @return [Object] modelsHelper instance of class BRL::Genboree::KB::Helpers::ModelsHelper
    # @return [String] matchProp property selector for the query
    # @return [String] mode search criteria for the query
    # @return [String] collName name of the collection
    # @return [String] cardinality size of the records returned after each query
    # @raise [ArgumentError] if @collName@ is empty.
    def getConfProps(joinConf)
      #joinName = joinConf['JoinConfig']['value']
      joinType = joinConf['JoinConfig']['properties']['Join Type']['value'] rescue nil# required
      matchProp = joinConf['JoinConfig']['properties']['Match Prop']['value'] rescue nil
      mode = joinConf['JoinConfig']['properties']['Match Mode']['value'] rescue nil
      collName = joinConf['JoinConfig']['properties']['Coll Name']['value']
      cardinality = joinConf['JoinConfig']['properties']['Cardinality']['value']
      dataHelper = @crossmdb.dataCollectionHelper(collName.strip) rescue nil
      unless(dataHelper)
        raise "NO_COLL: It appears to be no data collection #{collName.inspect} in the GenboreeKB - #{@crossmdb.name}, (check spelling/case, etc)."
      end
      modelsHelper = @crossmdb.modelsHelper()
      return joinType, dataHelper, modelsHelper, matchProp, mode, collName, cardinality
    end
    


    # return source collection and source properties from a join configuration item
    # @param [Hash] joinConf join configuration specs as properties and values
    # @return [Array<String, String, String, Array<String>>] retVal array of source collection name, target collection name, join type (to/from) and list of source props
    def getConfSpecsForLinksTable(joinConf)
      retVal = []
      srcProps = []
      srcColl = joinConf['JoinConfig']['properties']['Coll Name']['value'] rescue nil
      tgtColl = joinConf['JoinConfig']['properties']['Target Coll Name']['value'] rescue nil
      joinType = joinConf['JoinConfig']['properties']['Join Type']['value'] rescue nil

      # get the source properties as comma separated. Changing to an item list structure needs
      # the model to be changed, not quite ideal at this point, so allowing comma separated lists of properties
      propStr = joinConf['JoinConfig']['properties']['Match Prop']['value'] rescue nil
      raise ArgumentError, "Invalid join configuration specs - Coll Name: #{srcColl.inspect}, Target Coll Name: #{tgtColl.inspect}, Join Type: #{joinType.inspect}, Match Prop: #{propStr.inspect}" if(srcColl.nil? or tgtColl.nil? or joinType.nil? or propStr.nil?)
      srcProps = propStr.gsub(/\\,/, "\v").split(/,/).map { |xx| xx.gsub(/\v/, ',').strip} unless(propStr.nil?)
      retVal = [srcColl, tgtColl, joinType, srcProps]
      return retVal
    end
    
    # @param [Object] dataHelper instance of class BRL::Genboree::KB::Helpers::DataCollectionHelper
    # @param [Object] modelsHelper instance of class BRL::Genboree::KB::Helpers::ModelsHelper
    # @param [Array] matchValues values
    # @param [String] matchProp property selector for the query
    # @param [String] matchMode search criteria for the query
    # @param [String] collName name of the collection
    # @return [Object] docCursor a Mongo::Cursor 
    def getDocCursor(dataHelper, modelsHelper, matchValues, matchProp, matchMode, collName)
      docCursor = nil
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Getting doc Cursor #{matchValues.inspect}")
      idPropName = dataHelper.getIdentifierName()
      if(matchValues)
        modelDoc = modelsHelper.modelForCollection(collName)
        model = modelDoc.getPropVal('name.model')
        idValuePath = modelsHelper.modelPath2DocPath(idPropName, collName)
        if(matchProp.nil?) # then no property specified to look in ; assume doc identifier
          docPath = idValuePath
          propDef = modelsHelper.findPropDef(docPath, model)
          propDomain = ( propDef ? (propDef['domain'] or 'string') : 'string' )
          matchprops = { idValuePath => propDomain }
        else # have list of props, or just one, to look in depending on scenario
          matchprops = convertPropPaths( (matchProp), modelsHelper, model, collName )
        end
        # Collect info needed for doing mongo query
        outputProps = nil
        sortInfo = { idValuePath => :asc }
        criteria = {
           :mode => matchMode.to_sym,
           :prop => matchprops,
           :vals => matchValues
        }
        docCursor = dataHelper.cursorBySimplePropValsMatch(criteria, outputProps, sortInfo)
      else 
        docCursor = dataHelper.allDocs(:cursor)
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Getting doc Cursor #{docCursor.inspect}")
      return docCursor
    end
    
    def convertPropPaths(matchProp, modelsHelper, model, collName)
      retVal = {}
      matchProp = [ matchProp ] unless(matchProp.acts_as?(Array))
      matchProp.each { |path|
        propDomain = 'string'
        path = path.gsub(/(.\[.*\])/, "")
        docPath = modelsHelper.modelPath2DocPath(path, collName)
        propDef = modelsHelper.findPropDef(path, model)
        if(propDef)
          propDomain = (propDef['domain'] or 'string')
        end
        retVal[docPath] = propDomain
      }
      return retVal
    end
    
   
    # @param [Object] dataHelper instance of class BRL::Genboree::KB::Helpers::DataCollectionHelper
    # @param [Object] modelsHelper instance of class BRL::Genboree::KB::Helpers::ModelsHelper
    # @param [Array] docUrls list of URLs
    # @param [String] matchProp property selector for the query
    # @param [String] matchMode search criteria for the query
    # @param [String] collName name of the collection
    # @return [Object] docCursor a Mongo::Cursor 
    def getDocCursorFromUrl(dataHelper, modelsHelper, docUrls, matchProp, collName )
      docCursor = nil
      matchprop = nil
      matchValues = Array.new()
      docUrls.each{|docUrl|
        docUrlSp = docUrl.split('/')
        if(docUrl =~ /^doc/)
          # doc/{docID}
          docID = CGI.unescape(docUrlSp[1]).to_s.strip rescue nil
          raise "INVALID_URL: Given url #{docUrl.inspect} should point to a document. Failed to retrieve document ID (#{docID.inspect}) from the url. Correct url is of the form 'doc/{docID}' " if(docID.nil?)
          # collName is the collection relative to this url
        elsif(docUrl =~ /^coll/)
          # coll/{collName}/doc/{docID}
          collectionName = CGI.unescape(docUrlSp[1]).to_s.strip rescue nil
          docID = CGI.unescape(docUrlSp[3]).to_s.strip rescue nil
          if(collectionName and docID)
            # Check if the collection name from the url is the same from the transformation join config
            # If not get the new dataHelper, also make sure that match prop matches the identifier property of the
            # new collection.
            unless(collName == collectionName)
              dataHelper = @crossmdb.dataCollectionHelper(collectionName.strip) rescue nil
              modelsHelper = @crossmdb.modelsHelper()
              collName = collectionName
              raise "NO_COLL: It appears to be no data collection #{collectionName.inspect} in the GenboreeKB - #{@crossmdb.name}, (check spelling/case, etc). " unless(dataHelper)
              idname = dataHelper.getIdentifierName()
              matchProp = nil if(!matchProp.nil? and matchProp.split(".").first != idname)
            end
          else
            raise "INVALID_URL: Given url #{docUrl.inspect} should point to a document in a collection. Failed to retrieve collection name (#{collectionName.inspect}) or document ID (#{docID.inspect}) from the url. Correct url is of the form 'coll/{collName}/doc/{docID}' "
          end
        elsif(docUrl =~ /^kb/)
          #/kb/{kbName}/coll/{collName}/doc/{docID}
          # Implementation deferred.
          raise "NOT_IMPLEMENTED: Cross mongoKb data retrieval not currently supported."
        elsif (docUrlSp[1] == "kb")
          #check if it is a host url
          # {host}/kb/{kbName}/coll/{collName}/doc/{docID}
          raise "NOT_IMPLEMENTED: Cross host mongoKb data retrieval not currently supported."
        else
          # raise Error
          raise "INVALID_URL: URL: #{docUrl.inspect} is an invalid url."
        end
        matchValues << docID
      }
      docCursor = getDocCursor(dataHelper, modelsHelper, matchValues, matchProp, 'exact', collName)
      return docCursor
    end



    def checkMatchValuesBeforeMatch(matchValues, propPath, sourceDoc, collName, modelsHelper=nil)
      retVal = nil
      # need to get the kbDoc equivalent path from the propesel path
      # to get the propdomain def
      ps = BRL::Genboree::KB::PropSelector.new(sourceDoc)
      allPaths = ps.getMultiPropPaths(propPath, ".")
      
      # get one single path
      docPath = allPaths.first.gsub(/(.\[.*\])/, "")
      modelsHelper = @crossmdb.modelsHelper() unless(modelsHelper)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "docPath #{docPath.inspect}")
      propDomain = getPropDef(docPath, modelsHelper, collName)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "propDomain #{propDomain.inspect}")
      if(propDomain =~ /^labelUrl/)
        retVal = []
        matchValues.each{|mValue| retVal << mValue.split("|").first }
      else
        retVal = matchValues
      end
      return retVal
    end

    # return the domain definition of a property in the kbDoc
    def getPropDef(propPath, modelsHelper, collName)
      retVal = nil
      modelDoc = modelsHelper.modelForCollection(collName)
      model = modelDoc.getPropVal('name.model')
      propDef = modelsHelper.findPropDef(propPath, model)
      retVal = ( propDef ? (propDef['domain'] or 'string') : 'string' )
      return retVal 
    end

  end
end; end; end; end
