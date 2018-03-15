require 'brl/genboree/kb/transformers/transformer'
require 'brl/genboree/kb/transformers/docToPropTransformer'
require 'brl/genboree/kb/transformers/transformedDocHelper'
require 'brl/genboree/kb/transformers/crossCollectionHelper'
require 'brl/genboree/kb/lookupSupport/kbDocLinks.rb'


include BRL::Genboree::KB::Transformers


module BRL ; module Genboree ; module KB ; module Transformers
  # class that transforms a collection, transforms all the docs in the collection
  # Note - Selective document(s) transformation not implemented in this version
  # Makes use of the kbDocLinks library to get the links and performs the direct
  # joins ONLY to get the property values of non-links.
  class CollToDocTransformWithkbDocLinks < Transformer
    
    SUPPORTED_OPERATIONS = {:count => nil}
     
    attr_accessor :transformationStatus
    attr_accessor :mongoKbDb
    attr_accessor :sourceColl
    # subject property mentioned in the transformation rules doc
    attr_accessor :subjectProp
    # An array of document ids either given and if not all the docs in the collection
    attr_accessor :docsTobeTransformed

    # Hash of subjects (value of the subject prop) linked to each document id
    attr_accessor :subjects
    attr_accessor :subjectsProp
    
    # Hash of partition values of each documents wrp to the partition rank
    # partitionValues[{rank}][{docID}] = []
    attr_accessor :partitionValues
    
    # Array of list of partitions in the order of the rank
    # Rank determines the partition order
    attr_accessor :allDocsPartitions

    # Transformed template doc on which the actual transformed doc is build
    attr_accessor :transformedTemplate
   
    # Hash with partition1.partition2 wrp to docIds and respective values as subject
    # Derived from merging document ids, subjects and partitions 
    attr_accessor :docsPartitionsToSubHash

    # Transformed Doc
    attr_accessor :transformedDoc
 
    # Transformed doc is build on this template
    attr_accessor :transformedTemplate  

    # DocToPropTranformer instance 
    attr_accessor :docToPropTrans

    # Hash containing partiton values for each subject
    # Available if indexSubjectsWithPartitions is true
    attr_accessor :subjectsToPartitionValues
    
    # @param [Hash] trRulesDoc the transformation rules document
    # @param [Object] mongoKbDb a BRL::Genboree::KB::MongoKbDatabase instance
    def initialize(trRulesDoc, mongoKbDb)
      super(trRulesDoc, mongoKbDb)
      if(@scope == 'coll' and @subject == 'doc')
        @sourceColl = nil
        @transformationErrors = []
        @transformationStatus = true
        # subjects[docId] = subjectValue
        @subjectVal = nil
        @subjects = {}
        @partitionValues = {}
        @subjectsToPartitionValues = {}
        @docsTobeTransformed = []
        @crossHelper = BRL::Genboree::KB::Transformers::CrossCollectionHelper.new(mongoKbDb)
        @docToPropTrans = BRL::Genboree::KB::Transformers::DocToPropTransformer.new(trRulesDoc, mongoKbDb)
        @allDocsPartitions = []
        @transformedTemplate = {}
        @docsPartitionsToSubHash = Hash.new{|hh, kk| hh[kk] = Hash.new{|hh,kk| hh[kk] = []} }
        @nonPartitionable = Hash.new{|hh, kk| hh[kk] = []}
        @subjectsProp = {}
        @partionable = true
      else
        raise ArgumentError, "INVALID_SCOPE_SUBJECT: Invalid scope #{@scope.inspect} and subject #{@subject.inspect} for the class CollToDocTransformer. This class supports transformation of the scope 'coll' and subject 'doc'"
      end
      # get subject
      checkOperationAndGetSubject() 
      # categorize partitions
    end
   
   # The entire documents in the collection are transformed in this method.
   # Unlike the BRL::Genboree::KB::Transformer::CollToDocTransformer#transformKbDocs() 
   # this method iterates through the partition rules rather than each document in the collection
   # Also uses the kbDocLinks table to get the linked document ids.
   # @param [String] sourceColl name of the collection of interest
   # @return [Boolean] transformationStatus true if the transformation is successful
   def doTransform(sourceColl)
     @docsTobeTransformed = []
     dataHelper = @mongoKbDb.dataCollectionHelper(sourceColl.strip) rescue nil
     unless(dataHelper)
       @transformationErrors << "COLL_NOT_FOUND: It appears to be no data collection #{sourceColl.inspect} in the GenboreeKB - #{@mongoKbDb.name}, (check spelling/case, etc)."
       @transformationStatus = false
     else
       @sourceColl = sourceColl
       docCursor = dataHelper.coll.find()
       totalDocs = docCursor.count
       if(totalDocs == 0)
           @transformationErrors << "DOCS_NOT_FOUND: No documents found in the collection #{@sourceColl.inspect} in the GenboreeKB - #{@mongoKbDb.name}. Transformation cannot proceed on an empty collection."
           @transformationStatus = false
       else
         docCursor.rewind!
         docCursor.each{ |doc|
           begin
           psDoc = BRL::Genboree::KB::PropSelector.new(doc)
           docID = psDoc.getMultiPropValues('<>').first
           @docsTobeTransformed << docID
           #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC ID: #{docID.inspect}")
           subjectValue = getPropForPropField(@subjectProp, 'value', psDoc, false)
           subjectPropvalue  = getPropForPropField(@indexSubjectsProp, 'value', psDoc, false) if(@indexSubjectsWithPartitions)
           @subjects[docID] = subjectValue.compact              
           @subjectsProp[docID] = subjectPropvalue if(@indexSubjectsWithPartitions)
           rescue => err
             @transformationStatus = false
             @transformationErrors << "SUBJECTVALUE_ERROR: Error in retrieving subject value from the document - #{docID.inspect}. #{err.message}"
             break
           end
          # get the non-joins partition rule values, if any
          unless(@partitionRules["NonJoins"].empty?) 
            @partitionRules["NonJoins"].each{|rule|
               #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "rule: #{rule.inspect}")
              begin
                partValue = getPropForPropField(rule["prop"], rule["field"], psDoc, false)
                 #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "partValue: #{partValue.inspect}")
                if(@partitionValues.key?(rule["rank"]))
                  @partitionValues[rule["rank"]][docID] = partValue.compact
                  if(@indexSubjectsWithPartitions)
                    @subjects[docID].inject(@subjectsToPartitionValues[rule["rank"]]){|hh, kk| 
                      if(hh.key?(kk))
                        hh[kk] << partValue.compact ; 
                      else
                        hh[kk] = partValue.compact ;
                      end
                      hh[kk].flatten!; hh;  
                    }
                  end
                else
                  @partitionValues[rule["rank"]] = {}
                  @partitionValues[rule["rank"]][docID] = partValue.compact
                  @subjectsToPartitionValues[rule["rank"]] = {}
                  if(@indexSubjectsWithPartitions)
                    @subjects[docID].inject(@subjectsToPartitionValues[rule["rank"]]){|hh, kk|
                      if(hh.key?(kk))
                        hh[kk] << partValue.compact ;
                      else
                        hh[kk] = partValue.compact ;
                      end
                      hh[kk].flatten!; hh;
                    }
                  end
                end
              rescue => err
                @transformationStatus = false
                @transformationErrors << "PartitionValue_ERROR: Error in retrieving partition value for the prop - #{rule["prop"]} from the document - #{docID.inspect}. #{err.message}"
                break
              end
            }
          end
         }
         getJoinPartitions() if(@transformationStatus)
         # To Do: check whether all the documents/docIds links are present in each partition
         if(@transformationStatus)
           if(@partionable)
             getAllPartitions()
             @transformedTemplate = getallPartitionsandTemplate()
             if(@indexSubjectsWithPartitions)
              mergePartitionsWithIndexedSubjects()
             else
               mergePartitionsWithSubjectsAndDocs()
             end
             doOp()
             if(@transformationStatus)
               @transformedDoc = @transformedTemplate
               @transformedDoc['nonPartionableDocs'] = @nonPartitionable 
             else
               @transformedTemplate = {}
             end
           else
             @transformedTemplate = getallPartitionsandTemplate(true) 
             @transformedTemplate['nonPartionableDocs'] = @subjects
             @transformedDoc = @transformedTemplate
           end
         end
       end # if totalDocs > 0
     end # dataHelper
     return @transformationStatus
   end

   # Gets the partitions from the partitioning rules that has
   # join configurations / linked properties involved 
   def getJoinPartitions()
      # get the partitions from each of the join spec
      @partitionRules["Joins"].each {|join|
        #  hash that links each linked subdoc to source doc
        finalLinksToSourceDoc = Hash.new{|hh,kk| hh[kk] = []}
        # rank
        ps = BRL::Genboree::KB::PropSelector.new(join)
        # final rule to be applied to the last set of docs in the join config
        rule = ps.getMultiPropValues('<>').first
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "rule: #{rule.inspect}")
        rank = ps.getMultiPropValues('<>.Rank').first
        unless(@partitionValues.key?(rank))
          @partitionValues[rank] = {}
          @subjectsToPartitionValues[rank] = {}
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "hash: #{@subjectsToPartitionValues[rank].inspect}")
          @docsTobeTransformed.each{|srcDoc| @partitionValues[rank][srcDoc] = []}
        end
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "rank: #{rank.inspect}")
        joinConfs = ps.getMultiPropItems('<>.Join.JoinConfigurations')
        # Must be present but is an optional property
        tgtCollNames = ps.getMultiPropValues('<>.Join.JoinConfigurations.[].<>.Target Coll Name') rescue nil
        collNames = ps.getMultiPropValues('<>.Join.JoinConfigurations.[].<>.Coll Name') rescue nil
        joinTypes = ps.getMultiPropValues('<>.Join.JoinConfigurations.[].<>.Join Type') rescue nil
        tgtCollNames = tgtCollNames.compact unless(tgtCollNames.nil?)
        collNames = collNames.compact unless(collNames.nil?)
        joinTypes = joinTypes.compact unless(joinTypes.nil?)
        # TO DO exceptions
        if(joinTypes.last == "from")
          lastCollName = collNames.last
        else
          lastCollName = tgtCollNames.last
        end
        srcDocIds = Marshal.load(Marshal.dump(@docsTobeTransformed))
        joinErr = ""
        # TO DO docLinks.nil?
        begin
          docLinks, subToPartitions = @crossHelper.doJoinsUsingKbDocLinks(joinConfs, srcDocIds, @indexSubjectsWithPartitions, @subjectsProp)
        rescue => err
          joinErr = "JOIN_ERROR failed - Details: #{err}"
          @transformationErrors << "JOIN_ERROR: Failed to get document links for the partitioning rule #{rule} with the rank - #{rank}. Details: #{joinErr}"
          @transformationStatus = false
        end
        if(docLinks.nil? or docLinks.empty?)
          @partionable = false
          break
        else
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", " subToPartitions: #{ subToPartitions.inspect}")
          docLinks.each_key{|docid|
            docLinks[docid].each {|linkedDoc| finalLinksToSourceDoc[linkedDoc] << docid }
          }
          dataHelper = @mongoKbDb.dataCollectionHelper(lastCollName.strip) rescue nil
         unless(dataHelper)
           @transformationErrors << "COLL_NOT_FOUND: It appears to be no data collection #{lastCollName.inspect} in the GenboreeKB - #{@mongoKbDb.name}, (check spelling/case, etc)."
           @transformationStatus = false
           break
         else
           modelsHelper = @mongoKbDb.modelsHelper()
         end
         # To do handle exceptions
         #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "cur:docLinks.values.flatten #{docLinks.values.flatten}\n lastCollName: #{lastCollName.inspect}")
         cur = @crossHelper.getDocCursor(dataHelper, modelsHelper, docLinks.values.flatten, nil, "exact", lastCollName)
         #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "cur: #{cur.count}")
         cur.rewind!
         cur.each {|cdoc|
           psdoc = BRL::Genboree::KB::PropSelector.new(cdoc)
           docname = psdoc.getMultiPropValues('<>').first
           #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "docname: #{docname.inspect} - #{docname}")
           val = psdoc.getMultiPropValues(rule) rescue nil
           #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "val: #{val.inspect} - #{psdoc.getMultiPropValues('<>').first}") if(val.nil? or val.empty?)
           finalLinksToSourceDoc[docname].each{|srcDoc| 
             if(val)
               @partitionValues[rank][srcDoc] << val.compact
               @partitionValues[rank][srcDoc] = @partitionValues[rank][srcDoc].flatten
               @partitionValues[rank][srcDoc] = @partitionValues[rank][srcDoc].uniq
             end
           }
           #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "val: #{val.inspect} - #{@subjectsToPartitionValues.inspect}") if(val.nil? or val.empty?)
           #
           if(val and @indexSubjectsWithPartitions)
             subToPartitions[docname].inject(@subjectsToPartitionValues[rank]){|hh, kk| hh[kk] = val.compact; hh;}
           end
         }
        end
         #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@subjectsToPartitionValues[rank]: #{@subjectsToPartitionValues[rank].inspect}")
        }
     end
   # get all the partitions from both the join and non-join partition rules
   def getAllPartitions()
     @partitionValues.sort.each {|partition|
       requiredParts = getRequiredPartitions()
       part = []
       part = requiredParts[partition.first] if(requiredParts.key?(partition.first))
       part << partition.last.values
       part.flatten!
       part.uniq!
       @allDocsPartitions << part     
     }  
   end
  # Merges partitions with subjects for each document
  def mergePartitionsWithSubjectsAndDocs()
    ranks = @partitionValues.keys.sort()
    
    docsTobeTransformed.each {|doc|
      parts = @partitionValues[ranks[0]][doc]
      unless(parts.empty?)
        ranks[1..ranks.size].each{|rank|
          if(@partitionValues[rank][doc].empty?)
            @nonPartitionable[doc] = @subjects[doc]
            parts = []
            break
          else
           parts = addParts(parts, @partitionValues[rank][doc])
          end
        }
        parts.each {|part| @docsPartitionsToSubHash[part][doc] = @subjects[doc] }
      else
       @nonPartitionable[doc] = @subjects[doc]
      end
    }
  end

  # Merges partitions with subjects wrp to a index property.
  # Index property can be usually same as the subject. usually!
  def mergePartitionsWithIndexedSubjects()
    ranks = @partitionValues.keys.sort()

    docsTobeTransformed.each {|doc|
      subs = @subjectsProp[doc]
      subs.each_with_index{|val, index|
        parts = @subjectsToPartitionValues[ranks[0]][val] rescue nil
        if(!parts.nil? and !parts.empty?)
          ranks[1..ranks.size].each{|rank|
            if(@subjectsToPartitionValues[rank][val].nil? or @subjectsToPartitionValues[rank][val].empty?)
              @nonPartitionable[doc] << @subjects[doc][index]
              parts = []
              break
            else
              parts = addParts(parts, @subjectsToPartitionValues[rank][val])
            end
          }
          parts.each{|part| @docsPartitionsToSubHash[part][doc] << @subjects[doc][index] }
      else
       @nonPartitionable[doc] << @subjects[doc][index]
      end
     }
    }
  end




  # Performs transformation opreration on the aggregated partitions and subject values
    # @return [Boolean] opsuccess operation successful
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

   def checkOperationAndGetSubject()
     operation = @kbDocument.getPropVal('Transformation.Output.Data.Aggregation.Operation') rescue nil
     if(SUPPORTED_OPERATIONS.key?(operation.to_sym)) # controlled by the model, still check
        # get the subject
        @subjectProp = @kbDocument.getPropVal('Transformation.Output.Data.Aggregation.Subject') rescue nil
        unless(@subjectProp)
          @transformationStatus = false
          @transformationErrors << "INVALID_SUBJECT_VALUE:  #{@subjectProp.inspect} is not permitted for the Transformation to proceed for the property - 'Transformation.Output.Data.Aggregation.Subject'."
        raise ArgumentError, "INVALID_SUBJECT_VALUE:  #{@subjectProp.inspect} is not permitted for the Transformation to proceed for the property - 'Transformation.Output.Data.Aggregation.Subject'."
        end
      else
        @transformationStatus = false
        @transformationErrors << "INVALID_OPERATION: Operation #{operation} is either not supported or implemented."
        raise ArgumentError, "INVALID_OPERATION: Operation #{operation} is either not supported or implemented."
      end
   end

  # Gets the template for the transformation from all the partition names obtained after the collection is transformed.
   # Merges the partitions with required partitions if any.
   # @return [Hash] transformedTemplate template of the transformed document
   def getallPartitionsandTemplate(getEmpty=false)

      transformedTemplate = {}
      transformedTemplate = getTemplate()
      if(getEmpty)
        transformedTemplate['Data'] = []
      else
        transformedTemplate['Data'] = @docToPropTrans.getDataTemplate(@allDocsPartitions)
      end
    return transformedTemplate
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


   def addParts(keys, parts)
    tmp = []
    keys.each{|key|
     parts.each{|part|
       tmp << "#{key}.#{part}"
     }
   }
   return tmp
  end

  end
end ; end ; end ;  end ## module BRL ; module Genboree ; module KB ; module Transformers

