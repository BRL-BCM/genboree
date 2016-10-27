require 'time'
require 'date'
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/genboree/kb/kbDoc'
require 'brl/extensions/bson'

module BRL ; module Genboree ; module KB ; module Validators
  class DocBuilder < ModelValidator

  attr_accessor :buildErrors
  attr_accessor :buildWarnings
  attr_accessor :buildMessages
  attr_accessor :lastBuiltDoc
  attr_accessor :docId

  def clear()
    super()
    @buildErrors.clear() rescue nil
    @buildWarnings.clear() rescue nil
    @buildMessages.clear() rescue nil
    @lastBuiltDoc = @docId = nil
  end

  def buildDoc(docId, modelDoc)
    @buildErrors = []
    @buildWarnings=  []
    @buildMessages = []
    # Does docId look ok to use as identifier?
    if(docId and docId.to_s =~ /\S/)
      # Is this a property-based modelDoc or the actual model data?
      if(modelDoc.is_a?(BRL::Genboree::KB::KbDoc))
        model = modelDoc['name']['properties']['model']['value'] rescue nil
        if(model.nil?)
          @buildErrors << "ERROR: The model parameter is a full BRL::Genboree::KB::KbDoc document, but does not have a valid 'model' sub-property where the actual model data can be found."
        end
      else
        model = modelDoc
      end
      modelOk = self.validateModel(modelDoc)
      if(modelOk)
        # Start examining the model
        if(@buildErrors.empty?)
          # Initialize the doc
          @lastBuiltDoc = {}
          buildRootProperty(docId, model)
        end
      else
        # model doc is no good, errors are in @validationErrors
        @buildErrors.push( *self.validationErrors )
      end
    else
      @buildErrors << "ERROR: Cannot build a new document whose identifier is #{docId.inspect}. That is not a valid document identifier value."
    end
    @buildMessages << "DOC\t=>\t#{@buildErrors.empty? ? 'OK' : 'INVALID'} (#{@buildErrors.size})"
    return (@buildErrors.empty? ? false : @lastBuiltDoc)
  end

  def buildRootProperty(docId, propDef)
    # pathElems is an Array with the current elements of the property path
    # - a _copy_ gets passed forward as we recursively evaluate the model
    #   . a copy so we don't have to pop elements off the end when finishing a recurive call
    # - used to keep track of exactly what property in the model is being assessed
    pathElems = []
    name = FIELDS['name'][:extractVal].call(propDef, nil)
    pathElems << name
    begin
      identifier = FIELDS['identifier'][:extractVal].call(propDef, nil)
      validInfo = self.validVsDomain(docId, propDef, [ name ])
      if(validInfo.nil?)# check returned nil (something is wrong in the propDef) & details aalready recorded in @validationErrors of the modelValidator
        @buildErrors.push( *self.validationErrors )
      elsif(validInfo[:result] != :VALID) # doc error, doesn't match domain
        @buildErrors << "ERROR: the value (#{docId.inspect}) for the identifier property #{name.inspect} doesn't match the domain/type information specified in the document model; it is not acceptable."
      else # fine so far
        @docId = docId
        @lastBuiltDoc[name] = propValObj = { 'value' => @docId }
        unless(propDef.key?('items'))
          # Root-specific stuff looks good so far.
          @haveIdentifier = true
          # At this point we should be able to build the 'properties' under the root (if any).
          buildProperties(propValObj, propDef['properties'], pathElems.dup)
        else
          @buildErrors << "ERROR: the root property cannot itself have a sub-items list. This is not allowed in the model, and thus also not allowed in docs purporting to follow the model."
        end
      end
    rescue => err
      $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "exception while validating model! Exception when processing #{name.inspect} (current property path: #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'})")
        raise err # reraise...should be caught elsewhere
    end
    @buildMessages << "PROP #{name.inspect}\t=>\t#{@buildErrors.empty? ? 'OK' : 'INVALID'} (#{@buildErrors.size})"
    return @buildErrors
  end

  def buildProperties(propValObj, propertiesDef, pathElems)
    begin
      if(propertiesDef and propertiesDef.acts_as?(Array) and !propertiesDef.empty?)
        propValObj['properties'] = propHash = {}
        propertiesDef.each { |propDef|
          @buildErrors = buildProperty(propHash, propDef, pathElems.dup)
        }
        propValObj.delete('properties') if(propValObj['properties'].empty?)
      end
    rescue => err
      $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "exception while building default doc from model! Exception when processing property path: #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}")
      raise err # reraise...should be caught elsewhere
    end
    @buildMessages << "#{' '*(pathElems.size)}SUB-PROPS OF #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}\t=>\t#{@buildErrors.empty? ? 'OK' : 'INVALID'} (#{@buildErrors.size})"
    return @buildErrors
  end

  def buildItems(propValObj, itemsDef, pathElems)
    begin
      if(itemsDef and itemsDef.acts_as?(Array) and !items.empty?)
        propValObj['items'] = itemsArray = []
        @buildErrors = buildProperty(itemsArray, itemsDef.first, pathElems.dup)
        propValObj.delete('items') if(propValObj['items'].empty?)
      end
    rescue => err
      $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "exception while building default doc from model! Exception when processing property path: #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'})")
      raise err # reraise...should be caught elsewhere
    end
    @buildMessages << "#{' '*(pathElems.size)}ITEMS LIST OF #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}\t=>\t#{@buildErrors.empty? ? 'OK' : 'INVALID'} (#{@buildErrors.size})"
    return @buildErrors
  end

  def buildProperty(propSet, propDef, pathElems)
    name = FIELDS['name'][:extractVal].call(propDef, nil)
    begin
      pathElems << name
      required = propDef['required']
      if(required)
        # Get appropriate default
        default = propDef['default']
        unless(default.nil?)
          # Set this required property to the default
          if(propSet.acts_as?(Hash))
            propSet[name] = propValObj = { 'value' => default }
          else # propSet.acts_as?(Array)
            propValObj = { 'value' => default }
            propSet << { name => propValObj }
          end
          # Build any required sub-props of this required prop
          if(propDef.key?('properties'))
            buildProperties(propValObj, propDef['properties'], pathElems.dup)
          elsif(propDef.key?('items'))
            buildItems(propValObj, propDef['items'], pathElems.dup)
          end
        else # default not provided for this default property ; CAN ONLY COME FROM USER
          # CANNOT PROCEED
          @buildErrors << "ERROR: the model provides no valid default for the required property #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}, indicating that it CANNOT be automatically assigned. The submitting user or software MUST provide a valid value for this required property."
        end
      end
    rescue => err
      $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "exception while validating model! Exception when processing property #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}")
      raise err # reraise...should be caught elsewhere
    end
    @buildMessages << "#{' '*(pathElems.size)}PROP #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}\t=>\t#{@buildErrors.empty? ? 'OK' : 'INVALID'} (#{@buildErrors.size})"
    return @buildErrors
  end # buildProperty(propSet, propDef, pathElems)
end
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Validators
