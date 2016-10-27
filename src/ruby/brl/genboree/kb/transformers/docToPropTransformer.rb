require 'brl/genboree/kb/transformers/transformer'
require 'brl/genboree/kb/transformers/transformedDocHelper'
require 'brl/genboree/kb/transformers/crossCollectionHelper'
require 'brl/genboree/kb/validators/docValidator'
require 'brl/genboree/kb/transformers/transformCache'
include BRL::Genboree::KB::Transformers


module BRL ; module Genboree ; module KB ; module Transformers
  class DocToPropTransformer < Transformer
    SUPPORTED_OPERATIONS = {:count => nil, :list => nil, :sum => nil, :average => nil}
     
    attr_accessor :transformationStatus
    attr_accessor :allPathsSorted
    attr_accessor :transformedHash
    attr_accessor :nodesEscaped
    attr_accessor :partitionsSorted
    attr_accessor :transformedDoc
    attr_accessor :transformedTemplate
    attr_accessor :mongoKbDb
    attr_accessor :partitionsRankHash
    attr_accessor :crossCollHelper
    attr_accessor :crossErrors
    
    # @param [Hash] trRulesDoc the transformation rules document
    # @param [Object] mongoKbDb a BRL::Genboree::KB::MongoKbDatabase instance
    def initialize(trRulesDoc, mongoKbDb=nil)
      super(trRulesDoc, mongoKbDb)
      @transformedDoc = {}
      @transformedTemplate = {}
      @sourceDocColl = nil
      @crossCollHelper = BRL::Genboree::KB::Transformers::CrossCollectionHelper.new(mongoKbDb)
      @crossErrors = []
    end

    # Transform kbDoc by using the cached document, if present or current
    # else does the transformation from the scratch
    # @param [String] cacheKey Unique string that identifies the cached document
    #   This string follows the pattern {coll}/doc/{doc}|{transformationName}|{format}
    #   where format is either JSON or HTML
    # @param [String] sourceDataDoc Identifier of the doc of interest
    # @param [Hash<Symbol, boolean>] opts Options that are required when the format is not json
    # @return [boolean] @transformationStatus Transformation status
    def transformKbDocUsingCache(cacheKey, sourceDataDoc, opts={})
      # check if cache exits - doc is returned only if the cached doc versions and other parameters
      # are in sync with the current respective states
      # if so use that as the transformedDoc
      # else transform fresh and update 
      @transformationStatus = true
      begin
        trCache = BRL::Genboree::KB::Transformers::TransformCache.new(@mongoKbDb)
        cachedOutput = trCache.getCachedOutput(cacheKey , @associatedColls)
        if(cachedOutput)
          @transformedDoc = (trCache.format == "JSON") ? JSON(cachedOutput) : cachedOutput  
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Found cached output")
        
        else
          transformKbDoc(sourceDataDoc, trCache.sourceColl)
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
  
    # Transforms a genboreeKB document and the transformed output is
    # saved as the instance variable @transformedDoc.
    # Transformation includes the following steps;
    # 1. Gets the partitions
    # 2. Aggregates the partitions based on the subject partition rule
    # 3. Gets the 'Contexts' information, if any.
    # 4. Gets the 'Special Value Rules', if any.
    # 5. Add metadata and special data type to the transformed doc if any.
    # @param [Hash] sourceKbDoc the source data document that is to be transformed
    # @param [Hash, String] sourceKbDocModel the model for the source document
    # @return [Boolean] transformationStatus is true if transformation of the document
    # is completed without any failures.
    # @note Validation of @sourceKbDoc@ against @sourceKbDocModel@ is skipped and
    # transformation proceeds with a message. Recommended to use a model in all instances
    def transformKbDoc(sourceKbDoc, sourceColl, sourceKbDocModel=nil)
      @sourceKbDoc = sourceKbDoc
      @sourceDocColl = sourceColl
      @transformationStatus = true
      validator = BRL::Genboree::KB::Validators::DocValidator.new()
      
      #1.a Validate source document against the model.
      unless(sourceKbDocModel.nil?) #validate sourceDoc with the model
        @transformationStatus = validator.validateDoc(@sourceKbDoc, sourceKbDocModel)
      else
        @transformationMessages << "No source model detected. Transformation of the source GenboreeKB document is done without validating it against the model."
      end
    
      if(@transformationStatus)
        #1.b validate the transformation rules against the source data document.
        # Method implemented in parent class
        rulesVsSrcDocValid = validateTrRulesVsSrcDoc(@sourceKbDoc)
        if(rulesVsSrcDocValid)
          # 2. Get the scope and subject for the transformation rules doc
          # This class supports scope-subject: doc-prop.
          # 3. Verify the transformation type
          if(@transformationType == "partitioning")
            @transformedTemplate = getTemplate()
            # 4. Get Data template. Fill the 'Data' Object
            getPartitions(@sourceKbDoc)
            if(!@partitionsSorted.empty? and @transformationErrors.empty?)
              reqdParts = getRequiredPartitions()
              unless(reqdParts.empty?) 
                mergedParts = mergeReqdPartitions(reqdParts, @partitionsRankHash) 
                dataTemplate = getDataTemplate(mergedParts)
              else
                dataTemplate = getDataTemplate(@partitionsSorted)
              end
              @transformedTemplate['Data'] = dataTemplate if(@transformationErrors.empty?)
              # 5. Aggregate
              @aggregatedHash = aggregateDoc() 
              if(@transformationErrors.empty?)
                operationOnAggregatedHash(@aggregatedHash)
                # 6. Get the optional fields of the transformed output - Contexts, Special Values, Special Data
                # 6.a Contexts
                if(@transformationErrors.empty?)
                  contextsValue = getContexts()
                  if(@transformationErrors.empty?)
                    @transformedTemplate['Contexts'] = contextsValue
                    #6 b. Get special rules, if any. 
                    specialRulesValue = getSpecialRules()
                    if(@transformationErrors.empty?)
                      @transformedTemplate['Special Value Rules'] = specialRulesValue
                      #6.c get special Data type - metadata, additional rows or/and columns
                      getSpecialDataType()
                      if(@transformationErrors.empty?)
                        @transformedDoc = @transformedTemplate
                      else
                        @transformationStatus = false
                        @transformationErrors << "ERROR_SPECIAL_DATA_TYPES: Encountered error while getting 'Special Data Types' information for the transformation."
                      end
                    else
                      @transformationStatus = false
                      @transformationErrors << "ERROR_SPECIAL_RULES: Encountered error while getting 'Special Rules' information for the transformation."
                    end
                  else
                    @transformationStatus = false
                    @transformationErrors << "ERROR_CONTEXTS: Encountered error while getting 'CONTEXTS' information for the transformation."
                  end
                else
                  @transformationStatus = false
                  @transformationErrors << "ERROR_AGGREGATION_OPERATION: Encountered error on operation of the aggregated transformed output."
                end
              else
                @transformationStatus = false
                @transformationErrors << "ERROR_AGGREGATION: Encountered error at the aggregation step of the transformation."
              end
            else
              @transformationStatus = false
              @transformationErrors << "ERROR_PARTITION: Encountered error while fetching partitions for the transformation."
            end
          else
            @transformationStatus = false
            @transformationErrors << "INVALID_TRANSFORMATION_TYPE: Transformation for the type '#{@transformationType}' is not recognized or supported."
          end
        else
          @transformationStatus = false
          @transformationErrors << "INVALID_RULE_OR_SOURCEDOC: Failed validation of the source document against the transformation rules (property selector paths)."
        end
      else
        @transformationStatus = false
        @transformationErrors << "INVALID_DOC: Validation of the source document against the model failed. #{validator.validationErrors}"
      end
      return @transformationStatus
    end

    
    
    # Gets partitions for transformation from the 'Partitioning Rules'.
    # Each of these partitions are sorted with its respective 'Rank'
    # Partitions from the Output.Data of the rules document are
    # merged with the ones matched and mentioned in Output.Special Data.Required Partitions, if any.
    # This imposes the order and additional partition names than the ones
    # obtained from the 'Partitioning Rules'.
    # @param [Hash] sourceDoc the Genboree KB data document that is to be transformed.
    # @param [String] sourceCollName the Genboree KB collection name  of the source document. 
    # @return [Array<Array>] partitionsSorted partitions sorted with 'Rank'
    def getPartitions(sourceDoc, sourceCollName=nil)
      # array to store all the expanded paths for each rule
      # These paths are used to determine the relation between each partition and
      # the subject rule of the aggregation. See method: aggregateDoc
      allPaths = Array.new()
      @allPathsSorted = Array.new() # used for aggreation of a single document
      @partitionsRankHash = Hash.new{ |hh, kk| hh[kk] = [] }
      allPathsRankHash = {}
      @partitionsSorted = Array.new()
      ranks = Array.new()

      # REQUIRED property
      partitionsObj = @propSel.getMultiPropItems('Transformation.Output.Data.Partitioning Rules.[]')
      unless(partitionsObj.empty?)
        mess = []
        partitionsObj.each{|partItem|
          partitionRule = partItem['Partitioning Rule']['value'] rescue nil
          propfield =  partItem['Partitioning Rule']['properties']['PropField']['value']
          partitionJoin = partItem['Partitioning Rule']['properties']['Join']['value'] rescue nil
          rank = partItem['Partitioning Rule']['properties']['Rank']['value'] #required property
          if(partitionJoin) # Get the Join configurations for doing the mongo query
            partitionJoinConfs = partItem['Partitioning Rule']['properties']['Join']['properties']['JoinConfigurations']['items'] rescue nil
          end
          if(partitionRule =~ /\S/)
            begin
              unless(partitionJoin) # No cross collection 
                partition = getPropForPropField(partitionRule, propfield, sourceDoc, true)
                partition.compact!
                tmpHash = {}
                paths = getPropForPropField(partitionRule, 'paths', sourceDoc)
                paths.each {|path| tmpHash[path] = getPropForPropField(path, propfield, sourceDoc).first}

                if(allPathsRankHash.key?(rank))
                  allPathsRankHash[rank] = allPathsRankHash[rank].merge(tmpHash)
                else
                  allPathsRankHash[rank] = tmpHash
                end
              else # do the joins
                partition = []
                  begin
                    docs, mess = @crossCollHelper.doJoinsIndexFirstJoin(sourceDoc, partitionJoinConfs, sourceCollName)
                  rescue => err
                    @crossErrors << "JOIN_ERROR : #{err.message}"
                  end
                  begin
                    docs.each{|docIndexed|
                      valuesInd = []
                      docIndexed.each{|doc|
                        parVal = getPropForPropField(partitionRule, propfield, doc) rescue nil
                        valuesInd << parVal if(parVal)
                      }
                      # do not want redundant values 
                      valuesInd = valuesInd.flatten
                      valuesInd.uniq!
                      partition << valuesInd
                    }
                  rescue => err
                    @transformationErrors << "PARTITION_FAILED: Failed to get partitions for the partition Rule - #{partitionRule.inspect}."
                    @transformationErrors << err.message
                    @transformationStatus = false
                    @partitionsSorted = []
                    break
                  end
              end
              if(partition.empty?) # cannot be empty as transformation need partition for each rank to proceed . DANGER!!
                @transformationErrors << "PARTITION_EMPTY: Value for the Partitioning Rule: #{partitionRule} is not valid - #{partition.inspect}. Transformation cannot proceed without a valid partition."
                @transformationErrors << mess.inspect unless(mess.empty?)
                @transformationStatus = false
                @partitionsSorted = []
                break
              else # move on 
               
                rank = partItem['Partitioning Rule']['properties']['Rank']['value'] #required property
                partition.each{|part| @partitionsRankHash[rank] << part}
                #partitionsRankHash[rank].flatten!
                ranks << rank.to_i
              end
            rescue => err
              @transformationErrors << err.message
              @transformationStatus = false
              @partitionsSorted = []
              break
            end
          else
            @transformationErrors << "INVALID_PROP_VALUE: Value for the field: 'Partition Rule' is empty??. Check '#{partitionRule.inspect}'." 
            @transformationStatus = false
            @partitionsSorted = []
            break
          end
        }
      else
        @transformationErrors << "ERROR: The Transformation Rules document does not have any items under the path: 'Transformation.Output.Data.Partitioning Rules.[]'. Transformation cannot proceed without valid partitioning rules. #{@propSel.messages.join("\n")}"
        @transformationStatus = false
        @partitionsSorted = []
      end
      
      # sort the partitions with respect to the rank
      # Same rank for more than one partition not allowed.
      if(@transformationErrors.empty? and @partitionsRankHash.keys)
          @partitionsRankHash.keys.sort.each{|ran|
            @partitionsSorted << @partitionsRankHash[ran]
            @allPathsSorted << allPathsRankHash[ran] unless(allPathsRankHash.empty?)
          }
      end
      return @partitionsSorted
    end

    # Gets the 'Contexts' field of the transformation rules and 
    # transforms it to the template from the source Doc.
    # @param [Hash] sourceDoc the Genboree KB data document that is to be transformed
    # @return [Hash] contextOutput the context values for the 'Contexts'
    # @note that @contextOuput@ is empty when the 'Contexts' item list is empty or undefined.
    # It is an optional property for the transformation.
    # @raise [ArgumentError] if a valid source document is missing, or the property selector paths in
    # the 'Contexts' fields are not accessible or invalid.
     def getContexts(sourceDoc=nil)
      contextOutput = {}
      contextString = ""
      contextProp = ""
      contextRank = ""
      contextPropField = ""
      sourceDoc = sourceDoc.nil? ? @sourceKbDoc : sourceDoc
      raise ArgumentError, "NO_SOURCE_KB_DOC: Source KB document missing for fetching partitions." if(sourceDoc.nil?)

      # get the Context sub document first
      # could be nil as the "Contexts" property is not a required property
      contexts = @kbDocument.getPropItems('Transformation.Output.Contexts') rescue nil
        if(contexts and !contexts.empty?)
          contexts.each { |itemObj|
            # get all the four required values for each item in the item list "Contexts"
            contextString = itemObj['Context']['value'] rescue nil
            @transformationErrors << "EMPTY_FIELD: Value for the field 'Context' is empty or invalid." unless(contextString =~ /\S/)
            contextProp = itemObj['Context']['properties']['Prop']['value'] rescue nil
            @transformationErrors << "EMPTY_FIELD: Value for the field 'Prop' is empty or invalid." unless(contextProp =~ /\S/)

            contextJoin = itemObj['Context']['properties']['Prop']['properties']['Join']['value'] rescue nil
            if(contextJoin) # Get the Join configurations for doing the mongo query
              contextJoinConfs = itemObj['Context']['properties']['Prop']['properties']['Join']['properties']['JoinConfigurations']['items'] rescue nil
            end
            contextRank = itemObj["Context"]["properties"]["Prop"]["properties"]["Rank"]["value"] rescue nil
            @transformationErrors << "EMPTY_FIELD: Value for the field 'Rank' is not an integer." unless(contextRank.is_a?(Integer))

            contextPropField = itemObj["Context"]["properties"]["Prop"]["properties"]["PropField"]["value"]
            contextType = itemObj["Context"]["properties"]["Prop"]["properties"]["Type"]["value"] rescue nil
            contextType = (contextType == 'set') ? true : false # unique argument for the propselector methods

            if(@transformationErrors.empty?)
              contextValue = []
              unless(contextJoin)
                begin
                  contextValue = getPropForPropField(contextProp, contextPropField, sourceDoc, contextType)
                rescue => err
                  # rescue error as warnings
                  # If the context prop is valid or the return value is empty just note and move on
                  @transformationMessages << "CONTEXT: #{err.message}"
                end
              else
                begin
                  docs, mess = @crossCollHelper.doJoins(sourceDoc, contextJoinConfs, @sourceDocColl)
                rescue => err
                  @transformationErrors << err.message
                  @transformationStatus = false
                  contextOutput = {}
                  break
                end
                @transformationMessages << "NOT_FOUND: No documents found for the join query #{contextProp}. #{mess.inspect}" unless(mess.empty?)
                docs.each{|doc|
                  confVal = getPropForPropField(contextProp, contextPropField, doc, contextType) rescue nil
                  contextValue << confVal if(confVal)
                }
                contextValue.flatten!
                contextValue = contextValue.uniq if(contextType)
              end
              contextOutput[contextString.strip] = {}
              contextOutput[contextString.strip]['Rank'] = contextRank
              contextOutput[contextString.strip]['value'] = contextValue
            else
              @transformationErrors << "Error while fetching 'Contexts' information from the transformation rules document."
              @transformationStatus = false
              contextOutput = {}
              break
            end
          }
        else
          # no Contexts subdocument for the given transformation document
          # move on
          @transformationMessages << "NO_CONTEXTS: Contexts field is absent or empty for the input transformation rules document."
          contextOutput = {}
        end
      return contextOutput
    end    
    
    # Gets the data template from the partitions.
    # @param [Array<Array>] partitions the data tree value for the transformed output before aggregation
    # @return [Array<Hash>] dataOutput the Data object for the transformation template
    def getDataTemplate(partitions)
      dataOutput = []
   
      # if required paritions are set to true merge it with @partitionsRankHash
      @transformedHash = {} # used later for special rules.
      @nodesEscaped = {} # escaped paths /nodes
      unless(partitions.empty? and @transformationErrors.empty?)
        #2. make the Data template.
        partitions.first.each{|node|
          tmpHash = {}
          @transformedHash[node] = ""
          @nodesEscaped[node] = delimEsc(node, ".")
          tmpHash['name'] = node
          if(partitions.size == 1)
            tmpHash['cell'] = []
          else
            tmpHash['data'] = []
          end
          dataOutput << tmpHash
        }
        tmp = Marshal.load(Marshal.dump(partitions.first))
        tmpescaped = tmp.map{|xx| delimEsc(xx, ".")}
        # For each additional partition build the data tree.
        partitions[1..partitions.length].each{ |partition|
          if(partitions.index(partition) == partitions.size-1)
            dataOutput = addNode(dataOutput, partition, true)
          else
            dataOutput = addNode(dataOutput, partition, false)
          end
          tmp, tmpescaped = getKeys(tmp, partition, ".", tmpescaped)
          tmp.each_with_index{|key, inn| 
            @transformedHash[key] = ""
            @nodesEscaped[key] = tmpescaped[inn]
          }
        }
      else
        @transformationErrors << "PARTITION_ERROR: Partitions are #{partitions.inspect}. Transformation cannot proceed without valid partitions."
        @transformationStatus = false
        break
      end
      return dataOutput
    end
    
    # Performs aggregation on the subject rule against the partition rules
    # @param [Hash] sourceDoc the Genboree KB data document that is to be transformed
    # @param [Array<Hash>] allPaths where each of the rules in the partitions are expanded
    # and individual paths are connected to its value object by key-value pair in the hash.
    # Each element of @allPaths@ are in the order of the 'Rank' of the partition.
    # example allPaths = [{'A.B' => 'Benign', 'A.C' => 'Pathogenic' }, {'A.B.Z' => 'PE'}]
    # @return [Hash] aggregatedPathsHash hash of aggregated '.' separated paths to the transformed document
    # with the values being the list of objects corresponding to the path.
    # example aggregatedPathsHash = {'Benign.PE' => ['obj1', 'obj2'], 'Pathogenic.PE' => ['obj0']}
    def aggregateDoc(sourceDoc=nil, allPaths=nil, sep=".")
      @valueObjID = {}
      @subjectHash = {}
      aggObjPaths = Array.new()
      @aggregateObjToPartitions = Array.new()
      valueObj = {}
      lastelm = nil
      aggregatedPathsHash = Hash.new{ |hh, kk| hh[kk] = {'subjectVals' => []} }
      sourceDoc = sourceDoc.nil? ? @sourceKbDoc : sourceDoc
      raise ArgumentError, "NO_SOURCE_KB_DOC: Source KB document missing for fetching partitions." if(sourceDoc.nil?)
      allPaths = allPaths.nil? ? @allPathsSorted : allPaths
      raise ArgumentError, "ALL_PATHS is invalid and aggregation cannot proceed." if(allPaths.nil?)
      #. get the operation
      operation = @kbDocument.getPropVal('Transformation.Output.Data.Aggregation.Operation') rescue nil
      if(SUPPORTED_OPERATIONS.key?(operation.to_sym))
        # get the subject and its propField
        # MATCH and handle the type TO DO
    
        subject = @kbDocument.getPropVal('Transformation.Output.Data.Aggregation.Subject') rescue nil
        if(subject =~ /\S/)
          lastelm = subject.split(sep).last
          #expand the subject rule and get the value Obj for each individual path.
          begin
            aggObjPaths = getPropForPropField(subject, 'paths', sourceDoc)
            stepsUp = 0
            aggObjPaths.each{|path|
              stepsUp = 1 if(lastelm =~ BRL::Genboree::KB::PropSelector::PROP_BY_VALUE_SYNTAX)
              valOb =  getPropForPropField(path, 'valueObj', sourceDoc, false, ".", stepsUp).first
              @valueObjID[valOb.object_id] = valOb
              @subjectHash[path] = valOb.object_id
            }
          rescue => err
            @transformationErrors << err.message
            @transformationStatus = false
          end
        else
          @transformationErrors << "EMPTY_VALUE_FIELD: Empty value for the property name \"Subject\". Transformation cannot proceed without a valid subject for aggregation."
          @transformationStatus = false
        end
        # We have the subject hash.
        # Now determine the relation of each of the partition rules
        # to the subject rule: ancestor, same or descendant
        # Iteration is in the ascending order of partition and that is determined by @allPaths. See method: getPartitions.
        if(@transformationErrors.empty? and !allPaths.empty?)
          allPaths.each{|part|
            relation = nil
            steps = nil
            tmpHash = {}
            # check the relation
            # get any path of the partition, as all the paths in a single partition MUST be of the same level.
            partitionPaths = part.keys
            subjectPaths = @subjectHash.keys
            relation, steps = getRelation(subjectPaths.first, partitionPaths.first)
            if(relation == 1) # subject path is a ancestor
              partitionPaths.each{|partPath|
                matchString = partPath.split('.')
                matchString = matchString[0..(matchString.length-1) - steps].join('.') # should be a delim variable
                if(@subjectHash.key?(matchString))
                  tmpHash[@subjectHash[matchString]] = part[partPath]
                end
              }
            elsif(relation == -1) # first path is a subproperty to the second
              @subjectHash.each_key{|subpath|
                matchString = subpath.split('.')
                matchString = matchString[0..(matchString.length-1) - steps].join('.')
                tmpHash[@subjectHash[subpath]] = part[matchString]
              }
            else # same node/level
              @subjectHash.each_key{|subpath|
              if(part.key?(subpath)) 
                tmpHash[@subjectHash[subpath]] = part[subpath]
              else # just same level, not the same node
               newpath = subpath.split(".")
               newpath.pop
               part.each_key{|key|
                 newkey = key.split(".")
                 newkey.pop
                 if(newkey.join(".") == newpath.join("."))
                   tmpHash[@subjectHash[subpath]] = part[key]
             
                 end
               }
              end
              }
            end
            @aggregateObjToPartitions << tmpHash
          }
             
          # Once we have aggregateObjToPartitions, then get the aggregatedPathsHash
          @aggregateObjToPartitions.first.each_key{|key| valueObj[key] = nil}
          valueObj.keys.each{|objKey|
            value = []
            # Follows the order of partition.
            # Number of partitions == aggregateObjToPartitions.size
            # elements of aggregateObjToPartitions corresponds to the respective partition
            @aggregateObjToPartitions.each_with_index {|partition, ind|
              value << partition[objKey] #caution. make sure all the partitions have the key
            }
            aggregatedPath = value.join('.')
            #aggregatedPathsHash[aggregatedPath] << ObjectSpace._id2ref(objKey)
            aggregatedPathsHash[aggregatedPath]['subjectVals'] << @valueObjID[objKey]
          }
        else
          @transformationErrors << "Failed to locate partition rules paths. @allPaths is missing."
          @transformationStatus = false
        end
      else
        @transformationErrors << "NOT SUPPORTED: Operation: '#{operation}' is not implemented."
        @transformationStatus = false
      end
      return aggregatedPathsHash
    end
    
    # Performs respective operation on the 'aggHash' to generate
    # the final value of each leaf nodes.
    # @param [Hash] aggHash returned from the method aggregateDoc
    # @param [Hash] transformedDoc the document template that is to be transformed 
    def operationOnAggregatedHash(aggHash, transformedDoc=nil)
      # Operations are checked for supported operations at this point
      # See method aggregateDoc
      transformedDoc = transformedDoc.nil? ? @transformedTemplate : transformedDoc
      type = @kbDocument.getPropVal('Transformation.Output.Data.Aggregation.Subject.Type') rescue nil
      # Ignoring type for the time being
      operation = @kbDocument.getPropVal('Transformation.Output.Data.Aggregation.Operation')
      aggHash.each_key{|path|

        value = doOperation(aggHash, path, operation)
        if(@transformationStatus)
          if(type == 'int' and value.is_a?(Array))
            value = value.first.to_i # Not sure!!
          elsif (type == 'int')
            value = value.to_i
          end
          valueToAdd = {'value' => value}
          unless(value.nil?)
            @transformedHash[path] = value
            retVal = TransformedDocHelper.addFieldToPath(transformedDoc, @nodesEscaped[path], valueToAdd, true, {:addKey => "cell"})
            unless(retVal == :added)
              @transformationErrors << "TRANSFORMED_DOC_ERROR: Failed to add value to the path '#{path}' of the tansformedDoc."
              @transformationStatus = false
              break
            end
          else
            @transformationErrors << "TRANSFORMED_DOC_ERROR: Value for the transformed data path '#{path.inspect}' is invalid: #{value.inspect}."
            @transformationStatus = false
            break
          end
        end
      }
    end
     
     
    # Performs the aggregation operation on a specfic 'path'
    # which is a key name of the 'aggHash'
    # @param [Hash] aggHash returned from the method aggregateDoc
    # @param [String] path mongo style dot seperated path pointing to a node in the
    # transformed document template
    # @param [String] operation specific opeartion that is to be performed.
    # Supported operations are 'count' and list
    # @return [Integer, Array] retVal value of the corresponding leaf node
    #   is an integer when @operation@ is 'count'
    #   else is a list of values.
    # @todo operation 'countMap', 'sum' and 'average' to be implemented
    def doOperation(aggHash, path, operation)
      retVal = nil
      if(operation.to_sym == :count)
        retVal = aggHash[path]['subjectVals'].length
      elsif(operation.to_sym == :list) # list all the values
        #retVal = aggHash[path]
        retVal = []
        aggHash[path]['subjectVals'].each{|obj|
          if(obj.is_a?(Hash))
            ps = BRL::Genboree::KB::PropSelector.new(obj)
            retVal << ps.getMultiPropValues('<>')
          else # get the value
            retVal << obj
          end
        }
        retVal.flatten!
      elsif(operation.to_sym == :sum or operation.to_sym == :average)
        retVal = 0
        aggHash[path]['subjectVals'].each{|obj|
          if(obj.is_a?(Hash))
            ps = BRL::Genboree::KB::PropSelector.new(obj)
            val = ps.getMultiPropValues('<>')
          else # get the value
            val = obj
          end
          # Note, the properties with domain definitions as int is still a string  in the
          # document. This is not the right way to check for integer or float values 
          if(val.to_i == 0 and val != "0" )
            @transformationErrors << "INVALID_VALUR_TO_SUM: The value #{val} is not an integer and cannot be summed."
            @transformationStatus = false
            break
          else
            retVal += val.to_i
          end
        }
        retVal = (retVal.to_f/(aggHash[path]['subjectVals'].length)).to_i if(operation.to_sym == :average)
      end
      return retVal
    end
     
    # Given two paths - mongo style paths usually separated by '.',
    # this method determines the relation of the second path in respect to the first path.
    # @param [String] path1 Path to the property of a kbDoc
    # @param [String] path2 Path to the property of a kbDoc
    # @param [String] sep The path element separator
    # @return [Integer] retVal 0, 1, -1 for being the paths at the same level, path1 an ancestor
    # and path1 being a descendant
    # @retrun [Integer] retVal Depth that is between the two paths
    def getRelation(path1, path2, sep=".")
      retVal = nil
      depth = nil
      unless(path1.split(sep).empty? and path2.split(sep).empty?)
        if(path1.split(sep).length == path2.split(sep).length) # same level
          retVal = 0
          depth = 0
        elsif(path1.split(sep).length > path2.split(sep).length) # path1 is an ancestor (may or may not be immediate) of path2
          retVal = -1
          depth = path1.split(sep).length - path2.split(sep).length
        else
          retVal = 1 # path1 is a descendant of path2
          depth = path2.split(sep).length - path1.split(sep).length
        end
      else
        @transformationErrors = "Invalid Paths:  '#{path1}'  and/or '#{path2}'. Failed to determine the relation of the paths."
        raise @transformationErrors
      end
        if(retVal.nil? or depth.nil?)
          @transformationErrors = "Invalid relation: '#{retVal}' or level '#{depth}' for the paths: '#{path1}' and '#{path2}'."
          raise @transformationErrors
        end
      return retVal, depth
    end
    
    def addNode(data, children, leaf=false)
      data.each{ |level|
        if(level['data'].empty?)
          children.each{ |child|
            unless(leaf)
              level['data'] << {'name' => child, "data" => []}
            else
              level['data'] << {'name' => child, "cell" => {"value" => nil}}
            end
          }
        else
          addNode(level['data'], children, leaf)
        end
      }
 
    return data
    end
    
    # Generates the special rules
    # @param [Hash] transformedHash Hash with key names
    #   corresponding to each of the nodes in the transformed document and values are the
    #   corresponding value of the path
    # @param [Hash] sourceDoc the Genboree KB data document that is to be transformed
    # @return [Hash] specialRulesOutput Hash where key names are the paths and
    #   values the respective special value type as defined in the rules document.
    def getSpecialRules(transformedHash=nil, sourceDoc=nil)
      sourceDoc = sourceDoc.nil? ? @sourceKbDoc : sourceDoc
      raise ArgumentError, "NO_SOURCE_KB_DOC: Source KB document missing for fetching partitions." if(sourceDoc.nil?)
      transformedHash = transformedHash.nil? ? @transformedHash : transformedHash
      raise ArgumentError, "TRANSFORMED_HASH is invalid and special values detetection cannot proceed." if(transformedHash.nil?)
      specialRulesOutput = {}
      specialRules = @propSel.getMultiPropItems('Transformation.Output.Data.Special Value Rules.[]') rescue nil
      if(specialRules and !specialRules.empty?)
        specialRules.each{|ruleItem|
          # First get the type.
          # There is a conditional association between "Type" and ("Partition Rule" or ("Partition Value" and "Condition"))

          #ps = BRL::Genboree::KB::PropSelector.new(ruleItem)
          #special = ps.getMultiPropValues('<>.Special').first rescue nil

          # More efficient to get the values directly from the list than
          # instantiating the prop selector each time???
          special = ruleItem['Special Value Rule']['properties']['Special']['value']
          type = ruleItem['Special Value Rule']['properties']['Type']['value']
          rule = ruleItem['Special Value Rule']['properties']['Type']['properties']['Partition Rule']['value'] rescue nil
          value = ruleItem['Special Value Rule']['properties']['Type']['properties']['Partition Value']['value'] rescue nil
          #condition = ruleItem['Special Value Rule']['properties']['Type']['properties']['Partition Value']['properties']['Condition']
          if(type == 'partitioning')
            if(rule =~ /\S/)
              if(@transformedHash.key?(rule))
                specialRulesOutput[rule] = {"value" => special}
              else
                @transformationMessages << "No Valid partition Rule '#{rule.inspect}' found on the transformed output. This rule is therefore ignored as a special value rule."
              end
            else
              @transformationStatus = false
              @transformationErrors = "INVALID_SPECIAL_VALUE: Type of special rule is '#{type}'. There MUST be a valid partitioning rule with this type. Partition rule is #{rule.inspect}. A valid partition or dot separated combination of the partitions must be provided. Transformation cannot proceed without a valid combination of 'paritioning' and 'Partition Rule'. "
              specialRulesOutput = {}
              break
            end
          elsif(type == 'value')
            if(value =~ /\S/)
              @transformedHash.each_key{|key|
                #TO DO : use conditions. Now the value string has to be an exact match.
                # TO DO: handle types 
                specialRulesOutput[key] = {"value" => special} if(value == @transformedHash[key].to_s)
              }
            else
              @transformationStatus = false
              @transformationErrors = "INVALID_SPECIAL_VALUE: Type of special rule is '#{type}'. There MUST be a valid partitioning value with this type. Partition value is #{rule.inspect}. Transformation cannot proceed without a valid combination of 'paritioning' and 'Partition Value'. "
              specialRulesOutput = {}
              break
            end
          end
        }
      else
        @transformationMessages << "SPECIAL_VALUE_RULES_NOT_FOUND: No special value rules found for the transformation rules document. The transformed output has no entries for this key - ''Special Value Rules''."
      end
      return specialRulesOutput
    end
    
   

    
    # Gets the special data and adds it to the respective node of the
    # @transformedDoc@
    # @param [Hash] transformedDoc The document that is transformed
    # @param [Hash] sourceDoc the Genboree KB data document that is to be transformed
    def getSpecialDataType(transformedDoc=nil, sourceDoc=nil)
      sourceDoc = sourceDoc.nil? ? @sourceKbDoc : sourceDoc
      raise ArgumentError, "NO_SOURCE_KB_DOC: Source KB document missing for fetching partitions." if(sourceDoc.nil?)
      transformedDoc = transformedDoc.nil? ? @transformedTemplate : transformedDoc
      raise ArgumentError, "TRANSFORMED_HASH is invalid and special values detetection cannot proceed." if(transformedHash.nil?)
      # First add the metadata info, if any to a specific node in the transformed document.
      # Note: these are not required properties
      addMetadata(transformedDoc, sourceDoc)
      #Now, move on to special data types - rows (or/and) column.
      # This would return the new type - 'row' or 'col' from the TransformedDocHelper.
      #1. Start with columns if any
      if(@transformationStatus)
        cols = getColORRow('<>.Output.Special Data.Columns.[]', 'col', transformedDoc)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "COLS: #{cols.inspect}")
        rows = getColORRow('<>.Output.Special Data.Rows.[]', 'row', transformedDoc)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "ROWS: #{rows.inspect}")
        convertCellValues(sourceDoc, transformedDoc) if(@transformationErrors.empty?)
        if(cols.empty? and rows.empty?)
          @transformationMessages << "SPECIAL_DATA_TYPE: No additional columns and rows to be added to the transformed document."
        else
          if(@transformationErrors.empty?)
            @transformationMessages << "SPECIAL_DATA_TYPE: Additional #{cols.size} column(s) to be added to the transformed document." unless(cols.empty?)
            @transformationMessages << "SPECIAL_DATA_TYPE: Additional #{rows.size} row(s) to be added to the transformed document." unless(rows.empty?)
            insColsOrRowsToTransformedDoc(cols, rows, transformedDoc)
          end
        end
      end
      # Add metadata with respect to the subject (values in the leaf node of the aggregation)
      # This works as:
      # Gets the value of the property selector from 'Prop' that is a subtree of
      # the subject value of the aggregation , see aggregateDoc().
      # The value of that prop is added to the cell path (key of the aggregated Doc Hash) of the transformedDoc
      # along with the 'Context' Ex: cell => {'value' => 23, 'metadata' => {'value' => ['Tag:Tag01', 'Tag:Tag02', 'File:File01 File02', 'File:Fil
      # eA1 FileA2 FileA3']}}
      metadataSubject(transformedDoc, @aggregatedHash) if(@transformationStatus)
      metadataMatchSubject(transformedDoc, @aggregatedHash) if(@transformationStatus)
    end


    # Adds metadata with respect to the subject value object of the aggregation
    # @param [Hash] transformedDoc The document that is transformed
    # @param [Hash] aggHash the aggregated hash where names are the paths of the
    #   transformed document and each path has sub documents /subject objects 
    #   from each of the unique aggregation of the partitions
    def metadataSubject(transformedDoc, aggHash)
    # First get the metadata subject information, is optional
    metaSubObjs =  @propSel.getMultiPropValues('<>.Output.Special Data.Metadata Subject').first rescue nil
      if(metaSubObjs) 
         label = 'subjects'
         aggHash.each_key{|path|
           subdocs = aggHash[path]['subjectVals']
           retVal = TransformedDocHelper.addFieldToPath(transformedDoc, @nodesEscaped[path], subdocs, false, {:addKey => "cell", :otherKey => "metadata", :metKey => label})
           unless(retVal == :added)
             @transformationErrors << "TRANSFORMED_DOC_ERROR: Failed to add value - #{valueToAdd.inspect} to the path '#{rule.inspect}' of the tansformedDoc. Return Status of TransformedDocHelper : #{retVal.inspect}."
             @transformationStatus = false
             break
           end
         }
       end
    end


    # Adds metadata with respect to the subject value object of the aggregation
    # @param [Hash] transformedDoc The document that is transformed
    # @param [Hash] aggHash the aggregated hash where names are the paths of the
    #   transformed document and each path has sub documents /subject objects
    #   from each of the unique aggregation of the partitions
    def metadataMatchSubject(transformedDoc, aggHash)
      # First get the metadata subject information, is optional
      metaSubObjs =  @propSel.getMultiPropItems('<>.Output.Special Data.Metadata Match Subject.[]') rescue nil
      subject = @kbDocument.getPropVal('Transformation.Output.Data.Aggregation.Subject') rescue nil
      subjectPaths = getPropForPropField(subject, 'paths', @sourceKbDoc)  
      if(metaSubObjs and !metaSubObjs.empty?)
         metaSubObjs.each {|metItem|
           label = metItem['Context']['value']
           # removing white space, safe for gridView later on
           label = label.gsub(/\s+/, '')
           prop = metItem['Context']['properties']['Prop']['value'] rescue nil
           propfield = metItem['Context']['properties']['Prop']['properties']['PropField']['value'] rescue nil
           relation = getRelation(subjectPaths.first, prop)
           # subject is sub property to the metadata path 
           if(relation.first < 0)
            begin 
              vaObjID = {}
              # expand the given property to get all the paths
              metaPropPaths = getPropForPropField(prop, 'paths', @sourceKbDoc)       
              metaHash = {}
              # get the respective value object for each path from the source doc
              metaPropPaths.each{|propPath|
               metaHash[propPath] = getPropForPropField(propPath, propfield, @sourceKbDoc).first
              }
              # get the value obj id associated with the subject  
              @subjectHash.each_key{|subpath|
                matchString = subpath.split('.')
                matchString = matchString[0..(matchString.length-1) - relation[1]].join('.')
                vaObjID[@subjectHash[subpath]] = metaHash[matchString]
              }
              # Get the property path to the transformed document for inserting the value
              vaObjID.each_key{|vaKey|
                path = []
                @aggregateObjToPartitions.each {|part| 
                  path << part[vaKey]
                  
                 }
                valueToAdd = [vaObjID[vaKey]]
                
                retVal = TransformedDocHelper.addFieldToPath(transformedDoc, @nodesEscaped[path.join(".")], valueToAdd, false, {:addKey => "cell", :otherKey => "metadata", :metKey => label})
                unless(retVal == :added)
                   @transformationErrors << "TRANSFORMED_DOC_ERROR: Failed to add value - #{valueToAdd.inspect} to the path '#{path.inspect}' of the tansformedDoc. Return Status of TransformedDocHelper : #{retVal.inspect}."
                   @transformationStatus = false
                   break
                end
              }

           rescue => err
             @transformationErrors << "META_SUB_ERR : Failed to get/add metadata for the property #{prop}"
             @transformationErrors << "#{err.message}"
             @transformationStatus = false
           end 
         else
           begin
             subSize = subjectPaths.first.split(".").size()-1
              #get the subtree prop path
             newProp = prop.split(".")[subSize..(subSize+relation.last)].join(".")
             aggHash.each_key{|path|
               subdocs = aggHash[path]['subjectVals']
               subdocs.each {|doc|
                 metadata = [nil]
                 begin
                   metadata = getPropForPropField(newProp, propfield, doc)
                 rescue => err
                    #Not an error as this is just optional for the transformation
                   @transformationMessages << "NO_METADATA: Metadata not found for #{path.inspect}. #{err.message}"
                 end
                 valueToAdd = metadata.flatten
                 retVal = TransformedDocHelper.addFieldToPath(transformedDoc, @nodesEscaped[path], valueToAdd, false, {:addKey => "cell", :otherKey => "metadata", :metKey => label})
                 unless(retVal == :added)
                   @transformationErrors << "TRANSFORMED_DOC_ERROR: Failed to add value - #{valueToAdd.inspect} to the path '#{path.inspect}' of the tansformedDoc. Return Status of TransformedDocHelper : #{retVal.inspect}."
                   @transformationStatus = false
                   break
                 end
                }
             }
           rescue => err
             @transformationErrors << "META_SUB_ERR : #{err.message}"
             @transformationStatus = false
             break
           end

         end
       }
      else
      end
    end
    
    # Extracts metadata and inserts it to the transformed document
    # @param [Hash] transformedDoc The transformed document where the values are converted
    # @param [Hash] sourceDoc The source document that is to be transformed
    def addMetadata(transformedDoc, sourceDoc)
       metadataObjs = @propSel.getMultiPropItems('<>.Output.Special Data.Metadata.[]') rescue nil
      if(metadataObjs and !metadataObjs.empty?)
      metadataObjs.each{|obj|
        contextString = obj['Context']['value']
        contextString = contextString.gsub(/\s+/, '')
        prop = obj['Context']['properties']['Prop']['value']
        propField = obj['Context']['properties']['Prop']['properties']['PropField']['value']
        metaJoin = obj['Context']['properties']['Prop']['properties']['Join']['value'] rescue nil
        if(metaJoin) # Get the Join configurations for doing the mongo query
          metaJoinConfs = obj['Context']['properties']['Prop']['properties']['Join']['properties']['JoinConfigurations']['items'] rescue nil
        end
        ruleType = obj['Context']['properties']['Partition Rule']['value']
        rule = obj['Context']['properties']['Partition Rule']['properties']['Rule']['value']
        ruleField = obj['Context']['properties']['Partition Rule']['properties']['Rule']['properties']['PropField']['value'] rescue nil
        ruleRank = obj['Context']['properties']['Partition Rule']['properties']['Rule']['properties']['Rank']['value'] rescue nil
        matchIndex = obj['Context']['properties']['Partition Rule']['properties']['Match Index']['value']
        if(prop =~ /\S/)
          begin
            unless(metaJoin)
              metadataValue = getPropForPropField(prop, propField, sourceDoc)
            else
              metadataValue = []
              if(matchIndex)
                docs, mess = @crossCollHelper.doJoinsIndexFirstJoin(sourceDoc, metaJoinConfs, @sourceDocColl)
                @transformationMessages << "NOT_FOUND: No documents found for the join query for METADATA EXTRACTION: #{prop}. #{mess.inspect}" unless(mess.empty?)
                docs.each{|docIndexed|
                  valuesInd = []
                  docIndexed.each{|doc|
                    metVal = getPropForPropField(prop, propField, doc) rescue nil
                    valuesInd << metVal if(metVal)
                  }
                  valuesInd = valuesInd.flatten
                  metadataValue << valuesInd.uniq
                }
              else
                docs, mess = @crossCollHelper.doJoins(sourceDoc, metaJoinConfs, @sourceDocColl)
                @transformationMessages << "NOT_FOUND: No documents found for the join query for METADATA EXTRACTION: #{prop}. #{mess.inspect}" unless(mess.empty?)
                docs.each{|doc|
                  metVal = getPropForPropField(prop, propField, doc) rescue nil
                  metadataValue  << metVal if(metVal)
                }
                metadataValue.flatten!
                metadataValue.uniq!
              end
            end
          rescue => err
              @transformationStatus = false
              @transformationErrors << "ERROR_METADATA: #{err.message}."
              break
          end
          
          # Now insert this to the exact node in the transformed Doc
          # This is dictated by the "ruleType"
          if(ruleType == 'kbDoc') # rule is a property selector path
            if(rule =~ /\S/)
              begin
                # Force the ruleField to be 'value' if nil
                ruleField = ruleField.nil? ? 'value' : ruleField
                paths = getPropForPropField(rule, ruleField, sourceDoc, true)
              rescue => err
                @transformationStatus = false
                @transformationErrors << "ERROR_METADATA: #{err.message}."
                break
              end
              keys = []
              esc = []
              if(ruleRank > 1)
                keys = @partitionsSorted.first.dup
                @partitionsSorted[1..ruleRank-2].each{|partition| keys , esc = getKeys(keys, partition) }
                fullPaths = []
                keys.each{|key|
                  paths.each_with_index{|partialPath, ind|
                    fullPath = "#{key}.#{partialPath}"
                    fullPaths << fullPath
                  }
                }
              elsif(ruleRank == 1)
                keys = []
                fullPaths = paths
              else
                @transformationStatus = false
                @transformationErrors << "INVALID_RULERANK: Rank for the property 'Rule' is invalid :#{ruleRank.inspect}. Partiton Rule type is #{ruleType} anf for this type a valid rank must be provided. Transformation failed to proceed. "
                break
              end
              if(matchIndex and metadataValue.length != paths.length)
                @transformationStatus = false
                @transformationErrors << "INVALID_ELMS: MatchIndex is true and hence for the metadata insertion to proceed the number (#{metadataValue.length}) of metadataValues for the Prop #{prop.inspect} MUST BE EQUAL to the number (#{paths.length}) of paths
          pointing to the transformed document."
                break
              else
                valueToAdd = metadataValue
              end
              if(@transformationStatus)
              fullPaths.each{ |fullPath|
                lastKey = @nodesEscaped[fullPath].gsub(/\\\./, "\v").split('.').map{ |xx| xx.gsub(/\v/, '.') }.last
                ind = paths.index(lastKey)
                if(matchIndex)
                  if(metadataValue[ind].is_a?(Array))
                    valueToAdd = metadataValue[ind]
                    else
                      valueToAdd = metadataValue[ind]
                    end
                  end
                  retVal = TransformedDocHelper.addFieldToPath(transformedDoc, @nodesEscaped[fullPath], valueToAdd, true, {:addKey => "metadata", :metKey => contextString})
                  unless(retVal == :added)
                    @transformationErrors << "TRANSFORMED_DOC_ERROR: Failed to add value - #{valueToAdd.inspect} to the path '#{fullPath.inspect}' of the tansformedDoc. Return Status of TransformedDocHelper : #{retVal.inspect}"
                    @transformationStatus = false
                    break
                  end
                }
              end
            else
              @transformationStatus = false
              @transformationErrors << "INVALID_RULE_VALUE: Invalid value for 'Rule' '#{rule.inspect}'. Transformation cannot proceed with invalid entries for metadata properties."
              break
            end
            
          elsif(ruleType == 'transformedDoc')# exact path to the transformed document
            if(rule =~ /\S/)
              metadataValue = metadataValue.flatten
              valueToAdd = metadataValue
              retVal = TransformedDocHelper.addFieldToPath(transformedDoc, @nodesEscaped[rule], valueToAdd, true, {:addKey => "metadata", :metKey => contextString})
              unless(retVal == :added)
                @transformationErrors << "TRANSFORMED_DOC_ERROR: Failed to add value - #{valueToAdd.inspect} to the path '#{rule.inspect}' of the tansformedDoc. Return Status of TransformedDocHelper : #{retVal.inspect}."
                @transformationStatus = false
                break
              end
            else
              @transformationStatus = false
              @transformationErrors << "INVALID_RULE_VALUE: Invalid value for 'Rule' '#{rule.inspect}'. Transformation cannot proceed with invalid entries for metadata properties."
              break
            end
          end
        else
          @transformationStatus = false
          @transformationErrors << "INVALID_PROP_VALUE: Invalid value for 'Prop' '#{prop.inspect}'. Transformation cannot proceed with invalid entries for metadata properties."
          break
        end 
      }
      else
      @transformationMessages << "METADATA_NOTFOUND: Transformation proceeded without any metadata information for the transformed output as the metadata property fields are either empty or completely absent."
      end
    end

    
    # Get the additional row or column node to be inserted to the
    # transformed document
    # @param[String] path The property path for columns or rows
    # @param [Hash] transformedDoc The document that is transformed
    def getColORRow(path, dataType='col', transformedDoc=nil)
      transformedDoc = transformedDoc.nil? ? @transformedTemplate : transformedDoc
      raise ArgumentError, "TRANSFORMED_HASH is invalid and special values detetection cannot proceed." if(transformedHash.nil?)
      colOrRows = []
      colOrRowObjs = @propSel.getMultiPropItems(path) rescue nil
      if(colOrRowObjs and !colOrRowObjs.empty?)
        colOrRowObjs.each{|colOrRowObj|
          ps = BRL::Genboree::KB::PropSelector.new(colOrRowObj)
          label = ps.getMultiPropValues('<>').first rescue nil # required
          if(label =~ /\S/)
            operation = ps.getMultiPropValues('<>.Operation').first
            type = ps.getMultiPropValues('<>.Operation.Type').first
            position = ps.getMultiPropValues('<>.Position').first rescue nil
            position = (position == 'last') ? position : 'first'
            transformedCp = Marshal.load(Marshal.dump(transformedDoc))
            retVal = TransformedDocHelper.getNewDataTypeFromTree(transformedCp, dataType, 0, {:operationKey=> operation})
            if(retVal.is_a?(Array) and !retVal.empty?)
              #note: not using type here. REVISIT.
              colOrRowNode = []
              if(dataType == 'col')
                dataNode = Marshal.load(Marshal.dump(transformedDoc['Data'][0]))
                colOrRowNode = TransformedDocHelper.getColNode(dataNode, label, retVal)
                if(colOrRowNode.is_a?(Hash) and !colOrRowNode.empty?)
                  colOrRows << {position => colOrRowNode}
                else
                  @transformationStatus = false
                  @transformationErrors << "COL_ERROR: Failed to get the dataType 'col' from the tansformedDoc. Retval: #{colOrRowNode.inspect}"
                  break
                end
            else
              colOrRowNode = TransformedDocHelper.getRowNode(label, retVal)
              unless(colOrRowNode.empty?)
                #colOrRowNode is an array of hashes in this case
                colOrRows << {position => colOrRowNode}
              else
                @transformationStatus = false
                @transformationErrors << "ROW_ERROR: Failed to get the dataType 'row' from the tansformedDoc. Retval: #{colOrRowNode.inspect}"
                break
              end
            end
          else
            @transformationStatus = false
            @transformationErrors << "TRANSFORMED_DOC_ERROR: Failed to get the dataType 'col' from the tansformedDoc. Retval: #{retVal.inspect}"
            break
          end
        else
          @transformationStatus = false
          @transformationErrors << "COL_LABEL_EMPTY: Transformation cannot proceed with an empty '#{label.inspect}' for the additional column."
          break
        end
      }
      else
        @transformationMessages << "SPECIAL_DATA_COLorROW_NOT_FOUND: No properties for special Data types - '#{type.inspect}'"
      end
       return colOrRows
    end
    
    # Insert columns or rows into the transformed document
    # @param [Array<Hash>] cols Each additional column
    # @param [Array<Hash>] rows Each additional column
    # @param [Hash] transformedDoc The document that is transformed
    def insColsOrRowsToTransformedDoc(cols, rows, transformedDoc)
      #1. First insert the additional rows to transformedDoc
      unless(rows.empty?)
        esc = []
        #get keys in order till the last but one level of the dataTree
        keys = @partitionsSorted.first.dup
        @partitionsSorted[1..@partitionsSorted.length-2].each{|partition|
          keys, esc  = getKeys(keys, partition)
        }
        rows.each{|rowHash|
          app = true
          if(rowHash[rowHash.keys.first].size != keys.size)
            @transformationStatus = false
            @transformationErrors << "ERROR_INSERT_ROW: Number of RowValues #{rowHash[rowHash.keys.first].size} failed to match the keys of the transformedDoc - #{keys.size}. Transformation cannot proceed."
            break
          else
            app = false if(rowHash.keys.first == 'first')
            keys.each_with_index{|path, ii|
              retVal = TransformedDocHelper.addFieldToPath(transformedDoc, @nodesEscaped[path], rowHash[rowHash.keys.first][ii], app, {:addKey => "data"})
              unless(retVal == :added)
                @transformationStatus = false
                @transformationErrors <<  "ROW_INSERT_FAILED: Failed to insert '#{rowHash[rowHash.keys.first][ii]}' to the transformed Doc to the node #{path.inspect} "
                break
              end
            }
            if(@transformationStatus)
              #2. Insert the additional rows to additional columns
              begin
                unless(cols.empty?)
                  cols.each{|column|
                    column[column.keys.first] = addAgain(column[column.keys.first], {"name" => rowHash[rowHash.keys.first][0]['name'], "cell" => {"value" => nil} } , app)
                  }
                end
              rescue => err
                @transformationStatus = false
                @transformationErrors <<  "ROW_INSERT_TO_ADDITIONAL_COL_FAILED: Failed to insert '#{rowHash[rowHash.keys.first][ii]}' to the transformed Doc to the node #{path.inspect}. #{err.message} "
                break
              end
            end
          end
        }

      end
      #3. Insert the additional columns to the transformedDoc.
      if(!cols.empty? and @transformationStatus)
        cols.each{|column|
          if(column.keys.first == 'first')
            transformedDoc['Data'].unshift(column[column.keys.first])
          else
            transformedDoc['Data'] << column[column.keys.first]
          end
        }
      end
    end
   

    # Converts the cell values to percentage of the rows/columns
    # Only one cell conversion is allowed, i.e either with respect to the 
    # sum of row values or column values as defined by the property value -
    # 'Transformation.Output.Special Data.Cell Value Conversion'.
    # @param [Hash] sourceDoc The source document that is to be transformed
    # @param [Hash] transformedDoc The transformed document where the values are converted
    def convertCellValues(sourceDoc, transformedDoc)
      convertType = @propSel.getMultiPropValues('Transformation.Output.Special Data.Cell Value Conversion').first rescue nil
      if(convertType)
        operation = @propSel.getMultiPropValues('Transformation.Output.Special Data.Cell Value Conversion.Operation').first
        type = @propSel.getMultiPropValues('Transformation.Output.Special Data.Cell Value Conversion.Type').first
        transformedDocCp = Marshal.load(Marshal.dump(transformedDoc))
        newValues = TransformedDocHelper.getNewDataTypeFromTree(transformedDocCp, convertType, 0, {:operationKey => 'percentage'} )
        if(operation == 'percentage')
          if(convertType == 'col')
            esc = []
            keys = @partitionsSorted.first.dup
            @partitionsSorted[1..@partitionsSorted.length-2].each{|partition|
               keys, esc = getKeys(keys, partition)
            }
            leafNodeNames = @partitionsSorted.last
            if(newValues.is_a?(Array) and !newValues.empty?)
              newValues.each_with_index{|newValue, jj|
                newValue.each_with_index {|val, ii|
                  path = keys[ii] + ".#{leafNodeNames[jj]}"
                  val = '%0.2f' % val if(type == 'float')
                  val = (type == 'int') ? val.to_i : val.to_f
                  valueToAdd = {"value" => val}
                  retVal = TransformedDocHelper.addFieldToPath(transformedDoc, @nodesEscaped[path], valueToAdd, false, {:addKey => "cell"})
                  if(retVal != :added)
                    @transformationErrors << "CELL_VALUE_CONVERSION_ERROR: Failed to add value #{val.inspect} to the path - #{path.inspect} to the transformed document."
                    @transformationStatus << false
                  end
                }
              }
            else
              @transformationErrors << "CELL_VALUE_CONVERSION_ERROR: Encountered error while fetching #{convertType.inspect} from the transformed document."
              @transformationStatus << false
            end
          end
        else
          @transformationErrors << "Operation - #{operation} detected for CELL VALUE CONVERSION. This is not supported. "
          @transformationStatus = false
        end
      else
        @transformationMessages << "NO_CELL_CONVERSION: No properties found for Transformation.Output.Special Data.Cell Value Conversion and the transformation is proceeding without any conversions." 
      end
    end
    
    
    
   # HELPER METHODS 
   def getKeys(tmp, part, sep=".", escaped=nil)
      retVal = []
      retEsc = []
      tmp.each_with_index{|tm, inn|
        s = tm.dup
          part.each{|ii|
            newKey = s + sep + ii
            esc = escaped[inn] + sep + delimEsc(ii, sep) if(escaped and !escaped.empty?)
            retVal << newKey
            retEsc << esc if(escaped and !escaped.empty?)
          }
      }
      return retVal, retEsc
    end

    def addAgain(hash, add, app=true)
      if(hash.key?('data'))
        if(hash['data'][0].key?('cell'))
          if(app)
            hash['data'] << add
          else
            hash['data'].unshift(add)
          end
      
        else
          addAgain(hash['data'][0], add, app)
        end
      end
      return hash
    end
    

    
    
  end

end ; end ; end ;  end ## module BRL ; module Genboree ; module KB ; module Transformers
