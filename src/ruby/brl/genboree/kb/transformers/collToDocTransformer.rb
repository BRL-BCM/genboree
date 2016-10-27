require 'brl/genboree/kb/transformers/transformer'
require 'brl/genboree/kb/transformers/docToPropTransformer'
require 'brl/genboree/kb/transformers/transformedDocHelper'
require 'brl/genboree/kb/transformers/crossCollectionHelper'
require 'brl/genboree/kb/validators/docValidator'
require 'brl/genboree/kb/transformers/transformCache'

include BRL::Genboree::KB::Transformers


module BRL ; module Genboree ; module KB ; module Transformers
  # class that transforms a collection - all the documents in the collection
  class CollToDocTransformer < Transformer
    
    SUPPORTED_OPERATIONS = {:count => nil}
     
    attr_accessor :transformationStatus
    attr_accessor :mongoKbDb
    attr_accessor :sourceColl
    attr_accessor :transformedDoc
    attr_accessor :docsPartitionsToSubHash
    attr_accessor :allDocsPartitions
    attr_accessor :transformedTemplate   
    attr_accessor :transformedDocIds
    attr_accessor :docToPropTrans
    
    # @param [Hash] trRulesDoc the transformation rules document
    # @param [Object] mongoKbDb a BRL::Genboree::KB::MongoKbDatabase instance
    def initialize(trRulesDoc, mongoKbDb)
      super(trRulesDoc, mongoKbDb)
      if(@scope == 'coll' and @subject == 'doc')
        @transformedDoc = {}
        @transformedTemplate = {}
        @transformedDocIds = Array.new()
        @sourceColl = nil
      else
        raise ArgumentError, "INVALID_SCOPE_SUBJECT: Invalid scope #{@scope.inspect} and subject #{@subject.inspect} for the class CollToDocTransformer. This class supports transformation of the scope 'coll' and subject 'doc'"
      end
    end

    # Transform kbDocs by using the cached document, if present or current
    # else does the transformation from the scratch
    # @param [String] cacheKey Unique string that identifies the cached document
    #   This string follows the pattern {coll}/docs|{transformationName}|{format}
    #   where format is either JSON or HTML
    # @param [String] sourceDataColl Name of the collection of interest    
    # @param [Hash<Symbol, boolean>] opts Options that are required when the format is not json
    # @return [boolean] @transformationStatus Transformation status     
    def transformKbDocsUsingCache(cacheKey, sourceDataColl, opts={})
      # check if cache exits - doc is returned only if the cached doc versions and other parameters
      # are in sync with the current respective states
      # if so use that as the transformedDoc
      # else transform fresh and update
      @transformationStatus = true
      begin
        trCache = BRL::Genboree::KB::Transformers::TransformCache.new(@mongoKbDb)
        cachedOutput = trCache.getCachedOutput(cacheKey, @associatedColls)
        if(cachedOutput)
          @transformedDoc = (trCache.format == "JSON") ? JSON(cachedOutput) : cachedOutput
        else
          transformKbDocs(sourceDataColl)
          if(trCache.format == "JSON")
            trCache.updateCache(cacheKey, @transformedDoc, @associatedColls) if(@transformationStatus) if(@transformedDoc.to_json.size < CACHE_MAX_BYTES)
          else
            table = getHtmlFromJsonOut(@transformedDoc, trCache.format, opts)
            trCache.updateCache(cacheKey, table, @associatedColls) if(@transformationStatus) if(table.size < CACHE_MAX_BYTES)
            @transformedDoc = table
          end
        end
      rescue => err
        @transformationStatus = false
        @transformationErrors = err
      end
     return @transformationStatus
    end


    # Transforms all documents in a collection
    # @param [String] sourceColl name of the collection that is to be transformed
    # @return [Boolean] transformationStatus true when the transformation is successful
    def transformKbDocs(sourceColl)
      @sourceColl = sourceColl
      @transformationStatus = true
      @docsPartitionsToSubHash = Hash.new{ |hh, kk| hh[kk] = {} }
      @docsPartitionsToSubIndHash = Hash.new{ |hh, kk| hh[kk] = {} }
      @allDocsPartitions = Array.new()
      @allDocsRankPartitionsHash = Hash.new{ |hh,kk| hh[kk] = []}
      @nonPartitionable = {}
      # Get the subject and aggregation operation information from the transformation rules document.
      operation = @kbDocument.getPropVal('Transformation.Output.Data.Aggregation.Operation') rescue nil
      if(SUPPORTED_OPERATIONS.key?(operation.to_sym)) # controlled by the model, still check
        # get the subject
        subject = @kbDocument.getPropVal('Transformation.Output.Data.Aggregation.Subject') rescue nil
      else
        @transformationErrors << "INVALID_OPERATION: Operation #{operation} is either not supported or implemented."
        @transformationStatus = false
      end
      
      if(@transformationStatus)
        dataHelper = @mongoKbDb.dataCollectionHelper(sourceColl.strip) rescue nil
        unless(dataHelper)
          @transformationErrors << "COLL_NOT_FOUND: It appears to be no data collection #{sourceColl.inspect} in the GenboreeKB - #{@mongoKbDb.name}, (check spelling/case, etc)."
          @transformationStatus = false
        else
          docCursor = dataHelper.coll.find() # REVIST may not be the right way to access if the document numbers are much larger.
          totalDocs = docCursor.count
          if(totalDocs == 0)
            @transformationErrors << "DOCS_NOT_FOUND: No documents found in the collection #{@sourceColl.inspect} in the GenboreeKB - #{@mongoKbDb.name}. Transformation cannot proceed on an empty collection."
            @transformationStatus = false
          else
            @docToPropTrans = BRL::Genboree::KB::Transformers::DocToPropTransformer.new(@trRulesDoc, @mongoKbDb)
            count = 0
            docCursor.each{ |doc|
              begin
                psDoc = BRL::Genboree::KB::PropSelector.new(doc)
                docID = psDoc.getMultiPropValues('<>').first
                $stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC ID: #{docID.inspect}")
                subjectValue = getPropForPropField(subject, 'value', psDoc, false)
                subjectValue.compact!
              rescue => err
                @transformationStatus = false
                @transformationErrors << "SUBJECTVALUE_ERROR: Error in retrieving subject value from the document - #{docID.inspect}. #{err.message}"
                break
              end
              # Get the partitions of the document 
              partitions = @docToPropTrans.getPartitions(psDoc, @sourceColl)
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Partitions: #{partitions.inspect}")
              if(@docToPropTrans.crossErrors.empty?)
                if(!partitions.empty? and @docToPropTrans.transformationErrors.empty?)
                  # collect the subject value for each of the partition paths - part1.part2
                  mergePartitionsWrpSubject(subjectValue, docID, partitions)
                  if(@transformationStatus)
                    transformedDocIds << docID
                    @docToPropTrans.partitionsRankHash.each_key{|rank| 
                      @allDocsRankPartitionsHash[rank] << @docToPropTrans.partitionsRankHash[rank]
                   }
                 end
                else
                  #@nonPartitionable[docID] = @docToPropTrans.transformationErrors.inspect
                end
              else
                @transformationErrors << @docToPropTrans.crossErrors
                @transformationStatus = false
                break
              end
            }

            if(@transformationStatus)
              # get all the partitions from all the partitionable documents
              # Partitions are recorded with respect to the rank
              @allDocsRankPartitionsHash.keys.sort.each{|rank|
                @allDocsRankPartitionsHash[rank].flatten!
                @allDocsRankPartitionsHash[rank].uniq!
                @allDocsPartitions << @allDocsRankPartitionsHash[rank]
              }
              unless(@allDocsPartitions.empty?)
                  # get the template for the transformed document
                  # if no documents in the collection are successfully transformed, just return an empty ("Data" attribute is empty)
                  if(@docsPartitionsToSubHash.empty?)
                    @transformedTemplate = getallPartitionsandTemplate(true)
                  else
                    @transformedTemplate = getallPartitionsandTemplate()
                  end
                unless(@transformedTemplate.empty?)
                  # Do the operation and enter the metadata to the 'cell' object of the transformed Doc
                  # Also add subjects to the 'cell' metadata
                  # Do the operation only if there are valid entries in @docsPartitionsToSubHash
                  unless(@docsPartitionsToSubHash.empty?)
                    doOp()
                    if(@transformationStatus and @transformationErrors.empty?)
                      @transformedDoc = @transformedTemplate
                      @transformedDoc['nonPartionableDocs'] = @nonPartitionable
                    else
                      @transformationErrors << "AGGREGATION_DOCS_FAILED: Failed to aggregate the paritioned documents."
                      @transformationStatus = false
                    end
                 else 
                   @transformedDoc = @transformedTemplate
                   @transformedDoc['nonPartionableDocs'] = @nonPartitionable
                 end
                end
              else
                @transformationErrors << "FAILED_DOCS_PARTITIONS: Failed to get partitions for the collection - #{@sourceColl}. "
                @transformationStatus = false
                @transformationErros << "All the documents failed paritioning or are non partitionable. See Details: #{@nonPartitionable.inspect}" if(!@nonPartitionable.empty? and (@nonPartitionable.keys.size < @nonPartitionable.keys.size()))
              end
            end
          end
        end
      end
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "END: ::::::::")
      return @transformationStatus
    end

   
   # Gets the template for the transformation from all the partition names obtained after the collection is transformed.
   # Merges the partitions with required partitions if any.
   # @return [Hash] transformedTemplate template of the transformed document
   def getallPartitionsandTemplate(getEmpty=false)
      # Are there any required partitions
      # If yes, merge now and then get the template
      requiredParts = getRequiredPartitions()
      unless(requiredParts.empty?)
        mergedParts = mergeReqdPartitions(requiredParts, @allDocsRankPartitionsHash)
        @allDocsPartitions = mergedParts
      end

      transformedTemplate = {}
      transformedTemplate = getTemplate()
      if(getEmpty)
        transformedTemplate['Data'] = []
      else
        transformedTemplate['Data'] = @docToPropTrans.getDataTemplate(@allDocsPartitions)
      end
    return transformedTemplate 
   end

 
    # Performs transformation opreration on the aggregated partitions and subject values
    # @return [Hash] @transformedtemplate transformed document 
    def doOp()
      valueAdded = true
      docIdsAdded = true
      subjectsAdded = true
      opSuccess = true
      # First make the dataTree, template for the transformed document
      operation = @kbDocument.getPropVal('Transformation.Output.Data.Aggregation.Operation') rescue nil
      if(operation.to_sym == :count)
      @docsPartitionsToSubHash.each_key{ |path|
        value = 0
        subjects = []
        docIds = []
        inds = []
        @docsPartitionsToSubHash[path].each_key{|documentID|
         value = value + @docsPartitionsToSubHash[path][documentID].size()
         subjects << @docsPartitionsToSubHash[path][documentID]
         #inds << @docsPartitionsToSubIndHash[path]["#{documentID}IND"]
        }
        valueToAdd = {"value" => value}
        valueAdded = addObjToTransformedDoc(path, valueToAdd, {:addKey => "cell"})
       if(valueAdded)
         docIds = @docsPartitionsToSubHash[path].keys()
         label = "docIds"
         docIdsAdded = addObjToTransformedDoc(path, docIds, {:addKey => "cell", :otherKey => "metadata", :metKey => label})
         if(docIdsAdded)
           label = 'subjects'
           subjectsAdded = addObjToTransformedDoc(path, subjects, {:addKey => "cell", :otherKey => "metadata", :metKey => label})
           break unless(subjectsAdded)
         else
           break
         end
       else
         break
       end 
      }
      end
        opSuccess = @transformationStatus
      return opSuccess 
    end


   # HELPER METHOD
   # Method to add value to a path of the transformed document
   # The return object is recorded and a valid success object is returned
   # @param [String] path a "." separated path pointing to the the object of the data tree
   # @param [Hash] objvalue the value that is to be added
   # @param [Hash] obj the options the TransformedDocHelper class method requires. 
     # The exact name/key of the path where the value is to be inserted
   # return [Boolean] @transformationStatus true if insert is successful
   def addObjToTransformedDoc(path, objvalue, obj)
     begin
       retVal = TransformedDocHelper.addFieldToPath(@transformedTemplate, @docToPropTrans.nodesEscaped[path], objvalue, false, obj)
       unless(retVal == :added)
         @transformationErrors << "TRANSFORMED_DOC_ERROR: Failed to add value - #{objvalue} to the path '#{path.inspect}' of the tansformedDoc. Return Status of TransformedDocHelper : #{retVal.inspect}."
         @transformationStatus = false
       end
     rescue => err
       @transformationErrors << "TRANSFORMED_DOC_ERROR: Failed to add value - #{objvalue} to the path '#{path.inspect}' of the tansformedDoc. Return Status of TransformedDocHelper : #{retVal.inspect}. Details: #{err.message}"
       @transformationStatus = false
     end
     return @transformationStatus
   end

   # Method that adds the subject value to the partition path
   # This is used to get just the required information (subject, etc) after each document transformation
   # The return object of this method is used for the final operation 
   # @param [Array] subject list of subject values
   # @param [String] docID the identifier of a document
   # @param [Array<Array>] list of partitionNames  
   def mergePartitionsWrpSubject(subject, docID, partitions)
      begin
      tmpHash = Hash.new{ |hh, kk| hh[kk] = [] }
      tmpIndex = Hash.new{ |hh, kk| hh[kk] = [] }
      newpartitions = []
      key = []
      partitions.each{|part|
        if(part.size == 1 and part.size != subject.size)
          newpart = Array.new(subject.size) {|ii|
            if(part[0].is_a?(Array))
              ii = part[0]
            else
              ii = [part[0]]
            end
         }
         newpartitions << newpart
        else
         if(part[0].is_a?(Array))
           newpartitions << part
        else
           newpartitions << [part]
         end
      end
   }
      numpartitions = partitions.size
      subject.compact!
      missed = []
      subject.each_with_index{|sub, ind|
        key = []
        (0..numpartitions-1).each{|par|
          unless(newpartitions[par][ind].empty?)
            if(par == 0)
              key = []
              #key = "#{newpartitions[par][ind]}"
              newpartitions[par][ind].each {|ke|
                next if(ke !~ /\S/)
                key << "#{ke}"
              }
            else
              #key << ".#{newpartitions[par][ind]}"
              tmp = []
              key.each{|kk|
                newpartitions[par][ind].each{|nex|
                next if(nex !~ /\S/)
                tmp << "#{kk}.#{nex}"
                }
              }
              key = Marshal.load(Marshal.dump(tmp))
            end
          else
            missed << sub
            key = []
           break
          end
        }
        key.each{|ke| tmpHash[ke] << sub }
      }
      
      tmpHash.each_key{|tkey| @docsPartitionsToSubHash[tkey][docID] = tmpHash[tkey]}
      @nonPartitionable[docID] = missed unless(missed.empty?)
      rescue => err
        @transformationErrors << "PARTITIONS_SUBJECT_MERGE_ERROR: Details: #{err.message}"
       @transformationStatus = false

      end
    end
  
  
  end
end ; end ; end ;  end ## module BRL ; module Genboree ; module KB ; module Transformers

