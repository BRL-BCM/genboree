require 'brl/genboree/kb/propSelector'
require 'brl/genboree/kb/validators/transformValidator'
require 'brl/genboree/kb/helpers/transformsHelper'
require 'brl/genboree/gridViewer'

module BRL ; module Genboree ; module KB ; module Transformers
  # Class for transforming a Genboree KB document(s) to a transformed document.
  # Transformed document in this context is a JSON which is not
  # property oriented.
  # Is instantiated with a Hash (a genboreKB document that represents the
  # transformation rules defined by the model described in TransformsHelper),
  #  It will also respond to the methods that are added below.
  # @example Instantiation
  #   tr1 = Transformer.new(aHash)

  class Transformer
    
    SUPPORTED_SCOPES = {"coll"=>"doc", "doc"=>"prop"}

    CACHE_MAX_BYTES = 15 * 1024 * 1024 #<16MB
   
    # The transformation rules document 
    attr_accessor :trRulesDoc
    # BRL::Genboree::KB::MongoKbDatabase
    attr_accessor :mongoKbDb

    # Array of errors encountered during transformation
    attr_accessor :transformationErrors

    # Messages or warnings associated with the transformation
    attr_accessor :transformationMessages

    # Scope of the transformation. For a document to be transformed the 
    # scope is a document and the subject is a set of properties.
    # But when all the documents in a collection are transformed, the
    # scope is a collection and the subject is a document
    attr_accessor :scope

    # see above
    attr_accessor :subject

    # type of the partition, currently only partitioning type supported
    attr_accessor :transformationType

    # kbDoc instance of the rules document
    attr_accessor :kbDocument

    # propSelector instance of the rules document
    attr_accessor :propSel 
   
    # Hash of all the property selector paths and its values from the rules document
    attr_accessor :allPropSelPathsHash

    # Hash of all the property selector paths from the cross collections, if any 
    attr_accessor :allCrossCollPropSel

    # list of all the collections that are associated with the transformation rules document
    attr_accessor :associatedColls
    
    # Hash of partition rules
    attr_accessor :partitionRules
    

    # Index subjects with partitions- by default this is set to true.
    attr_accessor :indexSubjectsWithPartitions
  
    # CONSTRUCTOR. 
    # @param [Hash] trRulesDoc the transformation rules document
    # @raise [ArgumentError] if @trRulesDoc@ is not a valid transformation rules document
    def initialize(trRulesDoc, mongoKbDb=nil)
      @trRulesDoc = trRulesDoc
      @mongoKbDb = mongoKbDb
      @partitionRules = {}
      @partitionRules["NonJoins"] = []
      @partitionRules["Joins"] = []
      @indexSubjectsWithPartitions = nil
      # preValidation of the transformation rules document
      preValidationPassed = preValidate()
      raise ArgumentError, "TRANSFORMATION_RULES_DOC_ERROR: Transformation failed the prevalidation step.\n #{@transformationErrors.join("\n")}" unless(preValidationPassed)
    end
 
    # Prevalidation of a transformation rules document
    # Prevalidation comprises of three steps of validation as follows
    # 1. Validate against the transformation model as defined in the kbTransforms collection.
    # 2. Validate the scope and subject of the transformation rules document. Uses SUPPORTED_SCOPES.
    # 3. Validate the properties that point to various property selector paths - 
    # both required and optional for the transformation rules doc to be valid.
    # @return [Boolean] isValid indicating whether the transformation rules document
    # passed all the three steps of validation mentioned above.
    def preValidate()
      @transformationErrors = Array.new()
      @transformationMessages = Array.new()
      @scope = nil
      @subject = nil
      @transformationType = nil
      @associatedColls = []
      # cannot be an array
      raise ArgumentError, "INVALID_TRANSFORMATION_RULES_DOC: Transformation Rules Document is not a {Hash}." unless(@trRulesDoc.acts_as?(Hash))
      @kbDocument = BRL::Genboree::KB::KbDoc.new(@trRulesDoc)
      @propSel = BRL::Genboree::KB::PropSelector.new(@trRulesDoc)
      
      isValid = true
      #1. First validate the document against the 'kbTransforms' collection model
      trValidator = BRL::Genboree::KB::Validators::TransformValidator.new()
      isValid = trValidator.validate(@trRulesDoc)
      if(isValid)
        #2. Check for the scope and subject association
        # These are all required properties
        @scope = @kbDocument.getPropVal('Transformation.Scope')
        @subject = @kbDocument.getPropVal('Transformation.Type.Subject')
        @transformationType = @kbDocument.getPropVal('Transformation.Type')
        if(SUPPORTED_SCOPES[scope] == subject)
          mongokbDbChecked = true
          #3. Validate the transformation rules (property selector paths) that point to the source document
          if(@scope == 'coll')
            mongokbDbChecked = false unless(@mongoKbDb.instance_of?(BRL::Genboree::KB::MongoKbDatabase))
          end
          if(mongokbDbChecked)
            trRulesValid = trRulesValidate()
            unless(trRulesValid)
              isValid = false
              @transformationErrors << "TR_RULES_ERROR: Encountered error in transformation rules validation.\n"
            end
          else
            @transformationErrors << "MONGO_KB_MISSING: Invalid mongoKb instance: #{@mongoKbDb.class} for the scope 'coll'. The transformer must be instantiated with a rules document and a mongoKbDatabase instance of the class BRL::Genboree::KB::MongoKbDatabase. "
            isValid = false
          end
        else
          isValid = false
          @transformationErrors << "INVALID_SCOPE_SUBJECT: Scope (#{scope}) and subject (#{subject}) property values in the transformation do not match the supported scope for a transformation. Supported scope and subject domains are #{SUPPORTED_SCOPES.inspect}\n"
        end
      else
        isValid = false
        @transformationErrors << "INVALID_DOC: The input document failed vaildation against the transformation model.\n #{trValidator.validationErrors}\n"
      end
      return isValid
    end
    
    # Validates the transformation rules document by confirming the validity of
    # each of the properties that points to a property selector that accesses a source KB document.
    # These property selector paths should not be empty
    # @param [Hash] trDoc transformation rules document that is to be validated
    # @return [Boolean] trRulesValid indicating whether the document passed the validation
    def trRulesValidate(trDoc=nil)
      trDoc = trDoc.nil? ? @trRulesDoc : trDoc
      raise ArgumentError, "No Transformation Rules Document Found. " if(trDoc.nil?)
      @allPropSelPathsHash = {}
      @allPropSelPathsHash[:required] = {}
      @allPropSelPathsHash[:optional] = {}
      @allCrossCollPropSel = {}
      trRulesValid = true

      #1.a from DATA
      # required property - subject@indexSubjectsProp
      prop = @kbDocument.getPropVal('Transformation.Output.Data.Aggregation.Subject') rescue nil
      @indexSubjectsWithPartitions = @kbDocument.getPropVal('Transformation.Output.Data.Aggregation.Subject.Index Subject') rescue nil
      @indexSubjectsWithPartitions = @indexSubjectsWithPartitions.nil? ? true : @indexSubjectsWithPartitions
      @indexSubjectsProp = @kbDocument.getPropVal('Transformation.Output.Data.Aggregation.Subject.Index Subject.Prop') rescue nil
      @indexSubjectsProp = prop if(@indexSubjectsWithPartitions and @indexSubjectsProp.nil?)
   
      if(prop =~ /\S/)
        @allPropSelPathsHash[:required][prop] ='valueObj'
      else
        @transformationErrors << "Transformation RULE_INVALID: Transformation rule for the property selector 'Transformation.Output.Data.Aggregation.Subject' is '#{prop.inspect}'. Transformation cannot proceed without a valid entry for 'Transformation.Output.Data.Aggregation.Subject'."
        trRulesValid = false
      end
      #1.b From DATA: Partition Rules is an item list
      # Partition rules can point to the property path that is across collections
      # Look for 'Join' property associated with each rules.
      if(trRulesValid)
        partitionsObj = @propSel.getMultiPropItems('Transformation.Output.Data.Partitioning Rules.[]') rescue nil
        if(partitionsObj and !partitionsObj.empty?)
          partitionsObj.each{|item|
            prop = item['Partitioning Rule']['value']
            propField = item['Partitioning Rule']['properties']['PropField']['value']
            rank = item['Partitioning Rule']['properties']['Rank']['value'] rescue nil
            join = item['Partitioning Rule']['properties']['Join']['value'] rescue nil
            if(prop =~ /\S/)
             unless(join)
               @allPropSelPathsHash[:required][prop] = propField
               # get the non join rules with their prop, field and rank
               @partitionRules["NonJoins"] << {"prop" => prop, "field" => propField, "rank" => rank}
             else
              # get the associated colls from the join configuration
              jnItem = BRL::Genboree::KB::PropSelector.new(item)
              @partitionRules["Joins"] << item
              joinItObjs = jnItem.getMultiPropItems('<>.Join.JoinConfigurations.[]') rescue nil
              joinItObjs.each{|jnItem|
                @associatedColls << jnItem['JoinConfig']['properties']['Coll Name']['value']
              }
              @allCrossCollPropSel[prop] = propField
             end
            else
              @transformationErrors << "TR_RULE_INVALID: Transformation rule for the property selector 'Transformation.Output.Data.Partitioning Rules.[].Partitioning Rule' is #{prop.inspect}. Transformation cannot proceed without a valid transformation rule.}"
              trRulesValid = false
              break
            end
          }
        else
          @transformationErrors << "TR_RULE_INVALID: Transformation rule for the property selector 'Transformation.Output.Data.Partitioning Rules.[]' is #{partitionsObj.inspect}. This itemlist must have atleast one item for the transformation to proceed. #{@propSel.messages}"
          trRulesValid = false
        end
      end
    
      # Now get the optional transformation rules
      #2. From CONTEXTS and SPECIAL DATA
      optional = ['Transformation.Output.Contexts.[]', 'Transformation.Output.Special Data.Metadata.[]', '<>.Output.Special Data.Metadata Match Subject.[]']
      optional.each{|option|
        obj = @propSel.getMultiPropItems(option) rescue nil
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "obj: #{obj.inspect}")
        if(obj and !obj.empty?)
         obj.each{|item|
           ps = BRL::Genboree::KB::PropSelector.new(item)
           prop = ps.getMultiPropValues('<>.Prop').first rescue nil
           propField = ps.getMultiPropValues('<>.Prop.PropField').first rescue nil
           join = ps.getMultiPropValues('<>.Prop.Join').first rescue nil
           if(prop =~ /\S/)
              unless(join)
              @allPropSelPathsHash[:optional][prop] = propField 
              else
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "JOIN: #{join.inspect}")
                @allCrossCollPropSel[prop] = propField
                joinItemObjs = ps.getMultiPropItems('<>.Prop.Join.JoinConfigurations.[]') rescue nil
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "obj: #{joinItemObjs.inspect}")
                joinItemObjs.each{|jnItem|
                matchProps = jnItem['JoinConfig']['properties']['Match Prop']['value']
                matchValues = jnItem['JoinConfig']['properties']['Match Values']['value']
                @associatedColls << jnItem['JoinConfig']['properties']['Coll Name']['value']
                if(matchProps !~ /\S/ or matchValues !~ /\S/)
                  @transformationErrors << "TR_RULE_INVALID: 'Match Prop': #{matchProps.inspect} or 'Match Values': #{matchValues.inspect} fields are empty or invalid for the property selector path #{option.inspect} in the transformation rules document."
                    trRulesValid = false
                    break
                end
              }
              end
           else
              @transformationErros << "TR_RULE_INVALID: Transformation rule for the property selector '#{option}.<>.Prop' is #{prop.inspect}. Transformation cannot proceed without a valid transformation rule.}"
              trRulesValid = false
              break
           end
         }
        else
         @transformationMessages << "MISSING_OPTONAL_RULES: The transformation rule '#{option.inspect}' is empty or missing. Transformation is proceeding without any of these rules.\n"
        end # ok to be empty or nil as these are optional.
        }
        if(@scope == 'doc')
          unless(@allCrossCollPropSel.empty?)
            trRulesValid = false
            @transformationErrors << "INVALID_RULES_DOC: Cross collection join configurations found for the following properties #{@allCrossCollPropSel.keys.inspect}. However, the scope of the transformation is #{@scope}. Scope must be 'coll' for the transformation to proceed with the cross collection join congifurations."
          end
        end
      return trRulesValid
    end
    
    # Validates the transformation rules against the source/data KB document
    # If at least one of the property selector paths fail to retrieve a valid
    # object from the source document, the validation is declared invalid.
    # @param [Hash] sourceDoc the source or data document that is to be transformed
    # @param [Hash] allPropSelPathsHash hash object with all the property selector paths
    # as the name of the keys and the values the respective property field.
    # For example, {'A.B.<>' => 'value' , '<>.B.C.D.[]' => 'items'}
    # @return [Boolean] valid is true if all the selectors successfully access the document.
    def validateTrRulesVsSrcDoc(sourceDoc, allPropSelPathsHash=nil)
      valid = true
      allPropSelPathsHash = allPropSelPathsHash.nil? ? @allPropSelPathsHash : allPropSelPathsHash
      allPropSelPathsHash.each_key{ |propKey|
        allPropSelPathsHash[propKey].each_key{|propSelPath|
          retValues = []
          begin
            retValues = getPropForPropField(propSelPath, allPropSelPathsHash[propKey][propSelPath], sourceDoc, false)
          rescue => err
           # Error only if the prop path is required for transformation
            if(propKey == :required)
              valid = false
              @transformationErrors << "INVALID_RULE_OR_SOURCEDOC: Error in accessing the property pointed by the transformation rule selector - '#{propSelPath.inspect}'. Either an invalid source document or the selector is invalid.\n #{err.message}"
              break
            # else move on with a message
            else
              @transformationMessages << "PROP_NOT_FOUND: No property pointed by the transformation rule selector - '#{propSelPath.inspect}'. This is an optional property and hence transformation moves forward..\n #{err.message}"
            end
          end
          if(propKey == :required and retValues.empty?)
            @transformationErrors << "EMPTY_RET_VALUE: The return value for the property path '#{prop}' for the propField '#{propField}' is empty (#{retVal.inspect}). No valid entry in the source document???. This is a required property for the transformation."
            valid = false
            break
          end
        }
      }
      return valid
    end
    
    # Gets the respective objects from a document using the methods of
    # PropSelector Class.
    # @param [String] prop a property selector supported by the PropSelector
    # @param [String] propField the return value objects from the source document is defined by
    # this parameter. Supported values are :
    # value - list of values
    # properties - list of properties
    # items - list of items
    # propNames - list of property names the path points to
    # valueObj - list of objects
    # paths - list of paths representing a complex property selector
    # @param [Hash] sourceDoc the hash object from which the properties are to be retrieved
    # @param [Boolean] unique removes the redundant values from the return object
    # @param [String] delimiter for the paths
    # @return [Array] retVal list of @propField@
    # @raise [ArgumentError] if the @sourceDoc@ is nil and  @retVal@ is empty
    # @note do not catch or raise the error from the propSelector methods as that is raised elsewhere.
    def getPropForPropField(prop, propField, sourceDoc=nil, unique=false, sep='.', stepsUp=0)
      sourceDoc = sourceDoc.nil? ? @sourceKbDoc : sourceDoc
      raise ArgumentError, "NO_SOURCE_KB_DOC: Source KB document to fetch property value '#{propField}' for the property '#{prop}'." if(sourceDoc.nil?)
      psDoc = BRL::Genboree::KB::PropSelector.new(sourceDoc)
      retVal = Array.new()
      if(propField == 'value')
        retVal = psDoc.getMultiPropValues(prop, unique)
      elsif(propField == 'properties')
        retVal = psDoc.getMultiPropProperties(prop, unique, sep)
      elsif(propField == 'items')
        retVal = psDoc.getMultiPropItems(prop, unique, sep)
      elsif(propField == 'propNames')
        retVal = psDoc.getMultiPropNames(prop, unique, sep)
      elsif(propField == 'valueObj')
        retVal = psDoc.getMultiObj(prop, sep, stepsUp)
      elsif(propField == 'paths')
        retVal = psDoc.getMultiPropPaths(prop, sep)
      else
        # propFields are controlled by the domain enum in the model. So theoretically should be handled by the model validator
       # and never reach here. But still!!
       raise "INVALID FIELD: PropField property supports - value/items/properties/propNames/valueObj. Entered property field '#{propField.inspect}' is not valid."
      end
      retVal.compact!
      #if(retVal.empty?)
        #raise ArgumentError, "EMPTY_RET_VALUE: The return value for the property path '#{prop}' for the propField '#{propField}' is empty (#{retVal.inspect}). No valid entry in the source document???."
      #end
      return retVal
    end
    
    
    # Gets template for the transformed document.
    # @return [Hash] template    
    def getTemplate()
      template = {}
      template['Contexts'] = {}
      template['Data'] = []
      # is a required property
      dataStruct = @kbDocument.getPropVal('Transformation.Output.Data.Structure') rescue nil
      template['Data'] = {} unless dataStruct == "nestedList"
      template['Special Value Rules'] = {}
      #template['Special Data Types'] = {}
      return template
    end

    # Gets required partitions that are to be merged to the original partitions obtained from the transformation
    # @return [Hash] requiredPartitions with name as the rank and the value the partition names
    def getRequiredPartitions()
      requiredPartitions = {}
      reqdPartObjs =  @propSel.getMultiPropItems('<>.Output.Special Data.Required Partitions.[]') rescue nil
      if(reqdPartObjs and !reqdPartObjs.empty?)
        reqdPartObjs.each{|obj|
          ps = BRL::Genboree::KB::PropSelector.new(obj)
          partNames = ps.getMultiPropValues('<>.Partition Names').first rescue nil
          rank = ps.getMultiPropValues('<>.Rank').first.to_i rescue nil
          if(partNames =~ /\S/ and rank.is_a?(Integer))
            requiredPartitions[rank] = partNames.split(",")
          else
            @transformationStatus = false
            @transformationErrors << "INVALID_PROP_VALUE: Invalid values for 'Partition Names' - #{partNames.inspect} or 'Rank' '#{rank.inspect}'. Transformation cannot proceed with invalid entries for required partition properties."
            requiredPartitions = {}
            break
          end
        }
      else
        @transformationMessages << "REQD_PARTITIONS_NOT_FOUND: No required partition keys found. The transformed output will follow the order and keys strictly from the 'Partitioning Rules''."
      end
      return requiredPartitions
    end

    # Merges the required partitions to the original partition from the transformation
    # @param [Hash] reqdParts containing the rank as the name and an Array of partition names as the value
      # @see method getRequiredPartitions
    # @param [Hash] partitionHash the original partition hash obtained from the transformation
      # @see getPartitions
    # @return [Array<Array>] mergedPartitions both the required and original partitions merged
    def mergeReqdPartitions(reqdParts, partitionHash)
      mergedPartitions = []
      unless(reqdParts.empty?)
        reqdParts.each_key{|partitionRank|
          newPar = []
          # No merging if the rank in the required partition fail to match the ones from the partitioning rules
          if(partitionHash.key?(partitionRank))
            newPar = reqdParts[partitionRank] << partitionHash[partitionRank]
            newPar.flatten!
            newPar.uniq!
            partitionHash[partitionRank] = newPar
          else
             @transformationMessages << "REQD_PART_NOT_FOUND: Required partition with the rank #{partitionRank} is not found in the Partitioning Rules. Failed to merge it with a corresponding partition."
          end
        }
        partitionHash.keys.sort.each{|ran|
          mergedPartitions << partitionHash[ran]
        }
      end
      return mergedPartitions
    end

    def getHtmlFromJsonOut(output, format, opts={})
      table = nil
      begin
        onClick = opts.key?(:onClick) ? opts[:onClick] : nil
        showHisto = opts.key?(:showHisto) ? opts[:showHisto] : nil
        grid = BRL::Genboree::GridViewer.new(output)
        table = grid.getTable(format.to_sym, onClick, showHisto)
     rescue => err
        @transformationStatus = false
        @transformationErrors << "HTML_TABLE_ERROR: #{err}"
     end
     return table     
    end




    ## HELPER
    def delimEsc(str, delim)
      return str.gsub(delim, "\\#{delim}")
    end    
  end
end ; end ; end ;  end ## module BRL ; module Genboree ; module KB ; module Transformers
