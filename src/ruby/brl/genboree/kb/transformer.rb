require 'brl/genboree/kb/propSelector'
require 'brl/genboree/kb/validators/transformValidator'
require 'brl/genboree/kb/helpers/transformsHelper'

module BRL ; module Genboree ; module KB ; module Transformers
  # Class for transforming a Genboree KB document to a transformed document.
  # Transformed document in this context is a JSON which is not
  # property oriented.
  # Is instantiated with a Hash (a genboreKB document that represents the
  # transformation rules defined by the model described in TransformsHelper),
  #  It will also respond to the methods that are added below.
  # @example Instantiation
  #   tr1 = Transformer.new(aHash)

  class Transformer
    
    SUPPORTED_SCOPES = {"coll"=>"doc", "doc"=>"prop"}
    
    attr_accessor :trRulesDoc
    attr_accessor :mongoKbDb
    attr_accessor :transformationErrors
    attr_accessor :transformationMessages
    attr_accessor :scope
    attr_accessor :subject
    attr_accessor :transformationType
    # kbDoc instance of the rules document
    attr_accessor :kbDocument

    # propSelector instance of the rules document
    attr_accessor :propSel 
   
    # Hash of all the values of property selector paths from the rules document
    # Example, 'value' of 'Transformation.Output.Data.Aggregation.Subject' which could be
    # say, '<>.<>.Datum ID'. Then the corresponding key-value pair is
    # {'<>.<>.Datum ID' => 'valueObj'} 
    # Key names are the property selector paths of the Kb source document
    # {'<>.<>.Datum ID' => 'valueObj', '<>.Gene' => 'value', '<>.Conclusion.[]' => 'items'} ....
    attr_accessor :allPropSelPathsHash
    attr_accessor :allCrossCollPropSel    
    # CONSTRUCTOR. 
    # @param [Hash] trRulesDoc the transformation rules document
    # @raise [ArgumentError] if @trRulesDoc@ is not a valid transformation rules document
    def initialize(trRulesDoc, mongoKbDb=nil)
      @trRulesDoc = trRulesDoc
      @mongoKbDb = mongoKbDb
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
        # Ensure this is Array<String> even if newer hash-of-errors-keyed-by-propPath is available
        if( trValidator.respond_to?(:buildErrorMsgs) )
          validatorErrors = trValidator.buildErrorMsgs()
        else
          validatorErrors = modelValidator.validationErrors
        end

        isValid = false
        @transformationErrors << "INVALID_DOC: The input document failed vaildation against the transformation model.\n #{validatorErrors.join("\n")}\n"
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
      @allPropSelPathsHash['required'] = {}
      @allPropSelPathsHash['optional'] = {}
      @allCrossCollPropSel = {}
      trRulesValid = true

      #1.a from DATA
      # required property
      prop = @kbDocument.getPropVal('Transformation.Output.Data.Aggregation.Subject') rescue nil
      if(prop =~ /\S/)
        @allPropSelPathsHash['required'][prop] ='valueObj'
      else
        @transformationErrors << "Transformation RULE_INVALID: Transformation rule for the property selector 'Transformation.Output.Data.Aggregation.Subject' is '#{prop.inspect}'. Transformation cannot proceed without a valid entry for 'Transformation.Output.Data.Aggregation.Subject'."
        trRulesValid = false
      end
      #1.b From DATA: Partition Rules is an item list
      if(trRulesValid)
        partitionsObj = @propSel.getMultiPropItems('Transformation.Output.Data.Partitioning Rules.[]') rescue nil
        if(partitionsObj and !partitionsObj.empty?)
          partitionsObj.each{|item|
            prop = item['Partitioning Rule']['value']
            propField = item['Partitioning Rule']['properties']['PropField']['value']
            if(prop =~ /\S/)
	      @allPropSelPathsHash['required'][prop] = propField
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
      optional = ['Transformation.Output.Contexts.[]', 'Transformation.Output.Special Data.Metadata.[]']
      optional.each{|option|
        obj = @propSel.getMultiPropItems(option) rescue nil
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "obj: #{obj.inspect}")
        if(obj and !obj.empty?)
	  obj.each{|item|
	    ps = BRL::Genboree::KB::PropSelector.new(item)
	    prop = ps.getMultiPropValues('<>.Prop').first rescue nil
	    propField = ps.getMultiPropValues('<>.Prop.PropField').first rescue nil
            join = ps.getMultiPropValues('<>.Prop.Join').first rescue nil
	    if(prop =~ /\S/)
              unless(join)
		@allPropSelPathsHash['optional'][prop] = propField 
              else
		#$stderr.debugPuts(__FILE__, __method__, "DEBUG", "JOIN: #{join.inspect}")
                @allCrossCollPropSel[prop] = propField
                joinItemObjs = ps.getMultiPropItems('<>.Prop.Join.JoinConfigurations.[]') rescue nil
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "obj: #{joinItemObjs.inspect}")
                joinItemObjs.each{|jnItem|
		  matchProps = jnItem['JoinConfig']['properties']['Match Prop']['value']
		  matchValues = jnItem['JoinConfig']['properties']['Match Values']['value']
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
	retValues = []
	allPropSelPathsHash[propKey].each_key{|propSelPath|
	  begin
	    retValues = getPropForPropField(propSelPath, allPropSelPathsHash[propKey][propSelPath], sourceDoc, false)
	  rescue => err
	    valid = false
	    @transformationErrors << "INVALID_RULE_OR_SOURCEDOC: Error in accessing the property pointed by the transformation rule selector - '#{propSelPath.inspect}'. Either an invalid source document or the selector is invalid.\n #{err.message}"
	    break
	  end
	  if(propKey == 'required' and retValues.empty?)
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
    def getPropForPropField(prop, propField, sourceDoc=nil, unique=false, sep='.')
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
        retVal = psDoc.getMultiObj(prop, sep)
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
    
  end
end ; end ; end ;  end ## module BRL ; module Genboree ; module KB ; module Transformers
