require 'time'
require 'date'
require 'uri'
require 'sha1'
require 'json'
require 'brl/util/util'
require 'brl/extensions/units'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/kb/validators/docValidator'
require 'brl/genboree/kb/helpers/templatesHelper'

module BRL ; module Genboree ; module KB ; module Validators
  class TemplateValidator < DocValidator

    def initialize(kbDatabase=nil, dataCollName=nil)
      super(kbDatabase, dataCollName)
      @templateModelObj = BRL::Genboree::KB::KbDoc.new(BRL::Genboree::KB::Helpers::TemplatesHelper::KB_MODEL)
    end

    # Validates the user's template document against the collection's model document.
    # @param [Hash] doc A hash object representing the template document. 
    # @return [Boolean] retVal true for successful validation, false otherwise
    def validate(doc)
      retVal = false
      templKbDoc = BRL::Genboree::KB::KbDoc.new(doc)
      # First validate the entire template document including the metadata part
      retVal = validateDoc(templKbDoc, @templateModelObj)
      # If things look good so far, validate the actual template against the collection model
      if(retVal)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Template Metadata passed validation...")
        modelValidatorObj = @modelValidator.dup()
        clear()
        @modelValidator = modelValidatorObj
        @validationErrors = []
        @validationWarnings = []
        @validationMessages = []
        @contentNeeded = {}
        @needsCastingPropPaths = []
        # - get ModelsHelper to aid us in getting the model
        raise "ERROR: TemplatesHelper needs to be instantiated with a valid kbDatabase object to perform validation. This is required to get the model document of the collection to which this template will belong." unless(@kbDatabase)
        modelsHelper = @kbDatabase.modelsHelper()
        coll = templKbDoc.getPropVal('id.coll')
        modelKbDoc = modelsHelper.modelForCollection(coll)
        if(modelKbDoc.is_a?(BRL::Genboree::KB::KbDoc))
          model = modelKbDoc.getPropVal('name.model') rescue nil
          if(model.nil?)
            @validationErrors << "ERROR: The model parameter is a full BRL::Genboree::KB::KbDoc document, but does not have a valid 'model' sub-property where the actual model data can be found."
            retVal = false
          end
          template = templKbDoc.getPropVal('id.template') # Should contain the 'value object' of the specified root property.
          rootProp = templKbDoc.getPropVal('id.root')
          propDef = nil
          if(rootProp == '')
            propDef = model
          else
            propDef = modelsHelper.findPropDef(rootProp, model)
          end
          if(propDef)
            retVal = validateTemplDoc(template, propDef, rootProp)
          else
            #raise "ERROR: Could not find prop: #{rootProp} in the model document of the collection."
            @validationErrors << "ERROR: Could not find prop: #{rootProp} in the model document of the collection."
            retVal = false
          end
        else # probably nil because failed
          raise "ERROR: could not retrieve a model doc from the #{coll.inspect} collection within the #{@kbDatabase.name.inspect} GenboreeKB. Either the collection was created outside the Genboree framework, the model was deleted, or perhaps there is a spelling mistake (names are case-sensitive)?"
        end
      end
      return retVal
    end
    
    # Validate template doc against the collection's model
    # @param [BRL::Genboree::KB::KbDoc] doc the template document to validate against a model. This document is actually the value object of the root property specified for the template.
    # @param [BRL::Genboree::KB::KbDoc, String] model the model (propDef) to use to validate against the model
    # @param [String] propPath
    # @raise [RuntimeError] if modelDocOrCollName is a String and the associated model could not be retrieved
    def validateTemplDoc(doc, model, propPath)
      @allowDupItems = true # We do not want to check against the database or anything for dup items since this document isn't really going into the data collection.
      @missingContentOk = true # We don't care if there's missing content. We will not be using the Content Generation framework.
      if(propPath == '')
        @model = model
        #$stderr.debugPuts(__FILE__, __method__, "STATUS", "model:\n\n#{JSON.pretty_generate(model)}\n\ndoc:\n\n#{JSON.pretty_generate(doc)}")
        validateRootProperty({ model['name'] => doc }) # Defined in the parent class
      else
        pathEls =[]
        propPath.split(".").each {|prop|
          pathEls << prop  
        }
        propName = propPath.split(".").last
        if(doc.key?('items'))
          validateItems(propName, doc, model, pathEls)
        elsif(doc.key?('properties'))
          validateProperties(propName, doc, model, pathEls)
        else
          validateProperty(propName, doc, model, pathEls)
        end
      end
      @validationMessages << "DOC\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'} (#{@validationErrors.size})"
      if(!@validationErrors.empty?)
        retVal = false
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Template document passed validation...")        
        retVal = true
      end
    end
  
    def validateRootProperty(prop)
      # pathElems is an Array with the current elements of the property path
      # - a _copy_ gets passed forward as we recursively evaluate the model
      #   . a copy so we don't have to pop elements off the end when finishing a recursive call
      # - used to keep track of exactly what property in the model is being assessed
      pathElems = []
      if(prop.acts_as?(Hash) and !prop.empty?)
        # IFF there is more than one root-level key, we'll see if we can
        # fix the situation due a likely/known cause: if we've been given a raw,
        # uncleaned MongoDB doc, see about removing any '_id' or :_id key.
        # - we only do this if there is more than one root key, which may allow the official
        #   root node to actually BE _id (interesting)
        if(prop.size > 1)
          idVal = prop.delete('_id')
          idVal = prop.delete(:_id) if(prop.size > 1)
          @lastIdKey = idVal
        end
        # Should just be 1 key at this point...the root property name
        if(prop.size == 1)
          # Does it match the root property name?
          name = prop.keys.first
          begin
            if(name == @model['name'])
              autoContentDomain = @modelValidator.getDomainField(@model, :autoContent)
              rootDomain = @modelValidator.getDomainField(@model, :rootDomain)
              # Check certain root-specific things in the value-object for the root
              propValObj = prop[name]
              value = (propValObj.acts_as?(Hash) ? propValObj['value'] : nil)
              # Root value must either be something, or an auto-content domain that is also ok for the root property.
              if(propValObj and ( (!value.nil? and value.to_s =~ /\S/) or (autoContentDomain and rootDomain) ))
                # Check value of identifier vs domain
                pathElems << name
                validInfo = @modelValidator.validVsDomain(value, @model, pathElems, { :castValue => @castValues, :needsCastCheck => @needsCastCheck })
                if(validInfo.nil?) # check returned nil (something is wrong in the propDef) & details already recorded in @validationErrors of the modelValidator
                  @validationErrors.push( *@modelValidator.validationErrors )
                elsif(validInfo[:result] == :INVALID) # doc error, doesn't match domain
                  @validationErrors << "ERROR: the value (#{value.inspect}) for the identifier property #{name.inspect} doesn't match the domain/type information specified in the document model; it is not acceptable."
                else # fine so far
                  # But parsing value could indicate we need to generate some content or some other complex instruction/return object.
                  result = validInfo[:result]
                  if(result == :CONTENT_NEEDED or result == :CONTENT_MISSING)
                    @contentNeeded[validInfo[:pathElems].join('.')] = validInfo
                    if(result == :CONTENT_MISSING and !@missingContentOk)
                      @validationErrors << "ERROR: The root property has missing content that the validation call indicates should have been filled in by now."
                    end
                  end
  
                  # Should we modify the input doc to have the casted/normalized value? Required for saving to database.
                  if(@castValues)
                    # Yes. Then the appropriate normalized value is in validInfo[:castValue]
                    propValObj['value'] = validInfo[:castValue]
                  end
  
                  # Are we tracking needsCasting?
                  if(@needsCastCheck and validInfo[:needsCasting])
                    @needsCastingPropPaths << pathElems.join('.')
                  end
  
                  @docId = value
                  unless(prop.key?('items'))
                    # Make sure root prop does not have anything besides properties or value
                    propValObj.each_key { |propKey|
                      if(propKey == 'properties' or propKey == 'value')
                        # We are fine
                      else
                        @validationErrors << "ERROR: The root property of a document can only have 'properties' or 'value' as keys and nothing else. You have: #{propKey}"
                        break
                      end
                    }
                    # Root-specific stuff looks good so far.
                    @haveIdentifier = true
                    # At this point we should be able to validate the 'properties' under the root (if any).
                    validateProperties(name, propValObj, @model, pathElems.dup)
                  else
                    @validationErrors << "ERROR: the root property cannot itself have a sub-items list. This is not allowed in the model, and thus also not allowed in docs purporting to follow the model."
                  end
                end
              else
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Root prop of this template has no value field!! But it should be fine.")
                rootOk = true
                propValObj.each_key { |propKey|
                  if(propKey == 'properties' or propKey == 'value')
                    # We are fine.
                  else
                    @validationErrors << "ERROR: The root property of a document can only have 'properties' or 'value' as keys and nothing else. You have: #{propKey}"
                    rootOk = false
                    break
                  end
                }
                if(!rootOk)
                   @validationErrors << "ERROR: The root property of a document can only have 'properties' or 'value' as keys and nothing else. You have: #{propKey}."
                else
                  # At this point we should be able to validate the 'properties' under the root (if any).
                  validateProperties(name, propValObj, @model, pathElems.dup)
                end
              end
            else
              @validationErrors << "ERROR: the root property is not named #{@model['name'].inspect}, which it should be."
            end
          rescue => err
            $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "exception while validating doc vs its model! Exception when processing #{name.inspect} (current property path: #{name.inspect})")
            raise err # reraise...should be caught elsewhere
          end
        else
          @validationErrors << "ERROR: the root property is missing, or there is more than 1 root property. GenboreeKB docs are singly-rooted and this root-level document identifier property is required."
        end
      else # prop arg no good?
        if(@validationErrors.empty?) # then it's not some KbDoc problem we've already handled...it's something else
          @validationErrors << "ERROR: the doc is not a filled-in Hash-like object. It's either empty or nil."
        end
      end
      @validationMessages << "#{' '*(pathElems.size)}ROOT #{name.inspect}\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'} (#{@validationErrors.size})"
      return @validationErrors
    end
    
    # Validate sub-properties for a sub-document
    # @param [String] propName the name of the property that we are validating, mostly used for informative messages
    # @param [Hash] propValObj the sub-document whose properties we are validating, critically with key 'properties' pointing to
    #   sub-properties that are to be validated by this method
    # @param [Hash] propDef the property definition (from the model for this collection) for the property with the name propName
    # @param [Array<String>] pathElems array of path components from e.g. propPath.split(".") from the root property to this property,
    #   mostly for informational purposes
    # @return [Array<String>] set of validation errors explaining what went wrong
    def validateProperties(propName, propValObj, propDef, pathElems)
      begin
        # Any sub-props in the document, if any:
        subProps = propValObj['properties']
        # Definitions of sub-props from model, if any:
        subPropDefs = propDef['properties']
        # Find any required ones that are missing
        missingSubProps = [ ]
        #$stderr.puts "Validating properties for #{pathElems.join('.')} ; have #{subProps.size rescue 0} of #{subPropDefs.size rescue 0} sub-properties here"
        if(subPropDefs.acts_as?(Array))
          subPropDefs.each { |subPropDef|
            if(subPropDef.acts_as?(Hash))
              subPropName = subPropDef['name']
              # Is this a required sub-property?
              if(subPropDef['required'])
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "REQ'D SUB-PROP: #{subPropName.inspect}\n\t\tDEF=> #{subPropDef.inspect} (#{subProps.key?(subPropName)})\n\t\tSUB-PROPS=> #{subProps.inspect}")
                missingSubProps << subPropName if(!subPropName.nil? and subPropName =~ /\S/ and (subProps.nil? or !subProps.key?(subPropName)))
              end
              # Regardless, if we do have this sub-prop, validate it.
              if(subProps.acts_as?(Hash))
                if(subProps.key?(subPropName))
                  propValObj = subProps[subPropName]
                  validateProperty(subPropName, propValObj, subPropDef, pathElems.dup)
                  unless(@validationErrors.empty?)
                    break
                  end
                end
              end
            end
          }
        end
        # Did we notice any missing sub-props?
        if(!missingSubProps.empty?)
          @validationErrors << "ERROR: there are some missing required sub-properties under the #{ (pathElems.is_a?(Array) and !pathElems.empty?) ? pathElems.join('.').inspect : propName.inspect } property. Specifically, the model says the following sub-properties are required, but they are not present in the doc: #{missingSubProps.sort.map { |xx| xx.inspect }.join(', ')}"
        else
          # Need to look for UNKNOWN sub-props that are not in the model (only checked known ones so far)
          if(subProps)
            if(subProps.acts_as?(Hash)) # Get definitions of sub-properties of propName
              # If there are no properties defined for propName, then the doc can't have them!
              if(subPropDefs.acts_as?(Array))
                # . any unknown properties?
                unknownProps = []
                knownProps = @modelValidator.knownPropsMap(subPropDefs, false)
                subProps.each_key { |subPropName|
                  unknownProps << subPropName unless(knownProps.key?(subPropName))
                }
                unless(unknownProps.empty?)
                  @validationErrors << "ERROR: there are some unknown/undefined sub-properties in the document under the #{ (pathElems.is_a?(Array) and !pathElems.empty?) ? pathElems.join('.').inspect : propName.inspect } property. Specifically, the sub-properties #{unknownProps.sort{|aa,bb| aa.inspect <=> bb.inspect }.map{|xx| xx.inspect }.join(', ')} are not defined in the model and thus are not allowed."
                end
              else
                @validationErrors << "ERROR: there appear to be sub-properties for the #{ (pathElems.is_a?(Array) and !pathElems.empty?) ? pathElems.join('.').inspect : propName.inspect } property in your document, because its value object has the 'properties' field, BUT the model does not define any sub-properties under #{ (pathElems.is_a?(Array) and !pathElems.empty?) ? pathElems.join('.').inspect : propName.inspect }. #{"Instead, it appears to support a homogenous LIST of sub-items under this property; those would need to appear under the 'items' field not under the 'properties' field. " if(propDef and propDef['items'])}"
              end
            else
              @validationErrors << "ERROR: there appear to be sub-properties for the #{ (pathElems.is_a?(Array) and !pathElems.empty?) ? pathElems.join('.').inspect : propName.inspect } property in your document because its value object has the 'properties' field, BUT the value stored at that field is not a hash/map-like object as required. If there are no sub-properties, do not provide null/nil nor an empty hash/map; instead simple remove the 'properties' field altogether."
            end
          end
        end
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "exception while validating doc vs model! Exception when processing property path: #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}")
        raise err # reraise...should be caught elsewhere
      end
      @validationMessages << "#{' '*(pathElems.size)}SUB-PROPS OF #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'} (#{@validationErrors.size})"
      return @validationErrors
    end
  
    # @see #validateProperties
    def validateItems(propName, propValObj, propDef, pathElems)
      begin
        if(propValObj.acts_as?(Hash) and propValObj.key?('items'))
          subProps = propValObj['items']
          # Template doc can only define one template item
          if(subProps.size == 1)
            if(subProps.acts_as?(Array)) # Get definitions of sub-properties of propName
              subPropDefs = propDef['items']
                #$stderr.puts "Validating items for #{pathElems.join('.')} ; have #{subProps.size rescue 0} of #{subPropDefs.size rescue 0} sub-items here"
              # If there are no items defined for propName, then the doc can't have them!
              if(subPropDefs.acts_as?(Array) or subPropDefs.size != 1)
                subPropDef = subPropDefs.first
                subPropName = subPropDef['name']
                # Check items overall
                # . all items are hashes?
                nonHashItemIdxs = []
                # . all items are singlely rooted (after cleanup)
                nonSingleRootedIdxs = []
                # . all items have the correct root-level key
                wrongKeys = []
                subProps.each_index { |ii|
                  subProp = subProps[ii]
                  if(subProp.acts_as?(Hash))
                    # IFF there is more than one root-level key for the item, we'll see if we can
                    # fix the situation due a likely/known cause: if we've been given a raw,
                    # uncleaned MongoDB doc, see about removing any '_id' or :_id key.
                    # - we only do this if there is more than one root key, which may allow the official
                    #   root node to actually BE _id (interesting)
                    # - much less likely to have _id here than at top-level of the document, but just in case
                    if(subProp.size > 1)
                      subProp.delete('_id')
                      subProp.delete(:_id)
                    end
                    if(subProp.size == 1)
                      unless(subProp.key?(subPropName))
                        wrongKeys << subProp.keys.first
                      end
                    else
                      nonSingleRootedIdxs << ii
                    end
                  else
                    nonHashItemIdxs << ii
                  end
                }
                if(nonHashItemIdxs.empty?)
                  if(nonSingleRootedIdxs.empty?)
                    if(wrongKeys.empty?)
                      # Arrange unique and identifier reset (scoped to items list)
                      origUniqueProps = @uniqueProps
                      @uniqueProps = { :scope => :items, :props => Hash.new{|hh, kk| hh[kk] = {} }}
                      origHaveIdentifier = @haveIdentifier
                      @haveIdentifier = false
                      # Check each item in the items list
                      itemIdx = 0
                      subProps.each { |subProp|
                        propValObj = subProp[subPropName]
                        itemPathElems = pathElems.dup.push("[#{itemIdx}]")
                        validateProperty(subPropName, propValObj, subPropDef, itemPathElems)
                        unless(@validationErrors.empty?)
                          break
                        end
                        itemIdx += 1
                      }
                      @uniqueProps = origUniqueProps
                      @haveIdentifier = origHaveIdentifier
                    else
                      @validationErrors << "ERROR: there are some sub-items under #{ (pathElems.is_a?(Array) and !pathElems.empty?) ? pathElems.join('.').inspect : propName.inspect } property in your document which do not use #{subPropName.inspect} as their top-level key. The incorrect keys seen are: #{wrongKeys.sort.join(', ')}"
                    end
                  else
                    @validationErrors << "ERROR: there are some sub-items under #{ (pathElems.is_a?(Array) and !pathElems.empty?) ? pathElems.join('.').inspect : propName.inspect } property in your document which are not singly-rooted. Each sub-item is like a miniture document and must be singlely-rooted, as your model indicates. The sub-items at indices #{nonHashItemIdxs.join(', ')} do not appear to be singly rooted and have a variety of top-level keys."
                  end
                else
                  @validationErrors << "ERROR: there are some sub-items under #{ (pathElems.is_a?(Array) and !pathElems.empty?) ? pathElems.join('.').inspect : propName.inspect } property in your document which are not hashes/objects. The sub-items at indices #{nonHashItemIdxs.join(', ')} do not appear to be correctly represented."
                end
              else
                @validationErrors << "ERROR: there appear to be sub-items for the #{ (pathElems.is_a?(Array) and !pathElems.empty?) ? pathElems.join('.').inspect : propName.inspect } property in your document, because its value object has the 'items' field, BUT the model does not define any sub-items under #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}. #{"Instead, it appears to support a variety of unique sub-properties under this property; those would need to appear under the 'properties' field not under the 'items' field. " if(propDef and propDef['properties'])}"
              end
            else
              @validationErrors << "ERROR: there appear to be sub-items listed under the #{ (pathElems.is_a?(Array) and !pathElems.empty?) ? pathElems.join('.').inspect : propName.inspect } property in your document because its value object has the 'items' field, BUT the value stored at that field is not an array/list-like object as required. If there are no sub-items, do not provide null/nil nor an empty array/list; instead simply remove the 'items' field altogether."
            end
          else
            @validationErrors << "ERROR: there is more than sub-item defined under #{ (pathElems.is_a?(Array) and !pathElems.empty?) ? pathElems.join('.').inspect : propName.inspect } property in your document. A template item list can only define one item."
          end
        end
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "exception while validating doc vs model! Exception when processing property path: #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}")
        raise err # reraise...should be caught elsewhere
      end
      @validationMessages << "#{' '*(pathElems.size)}ITEMS LIST OF #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'} (#{@validationErrors.size})"
      return @validationErrors
    end
  
    # @see #validateProperties
    # @sets @contentNeeded if property has content to be generated by content generation framework
    def validateProperty(propName, propValObj, propDef, pathElems)
      #$stderr.puts "Validating property #{propName.inspect} of #{pathElems.join('.')} ; propValObj = #{propValObj.inspect}"
      if(propValObj)
        if(propValObj.acts_as?(Hash))
          pathElems << propName
          # Check either 'properties' or 'items', not both
          unless(propValObj.key?('properties') and propValObj.key?('items'))
            # Check value if value object has the value field. It may not. That's fine for template docs.
            if(propValObj.key?('value'))
              value = propValObj['value']
              domainStr = BRL::Genboree::KB::Validators::ModelValidator::FIELDS['domain'][:extractVal].call(propDef, nil)
              # . if fixed, then value must be missing or must match model
              if(domainStr != "[valueless]")
                if(propDef['fixed'])
                  defaultVal = @modelValidator.getDefaultValue(propDef, pathElems)
                  unless(defaultVal.nil?)
                    unless(value == defaultVal)
                      @validationErrors << "ERROR: the property #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property is tagged as having a fixed/static/unmodifiable value; that value is determined by the document model. However, the document has a different value for this property (#{value.inspect}). If this property is present in the document, its value MUST be #{defaultVal.inspect}."
                    end
                  else # problem with default value in model ; get errors from @modelValidator
                    @validationErrors.push( *@modelValidator.validationErrors )
                  end
                end
                # . if unique, must not have seen this so far (resets under items lists)
                if(@validationErrors.empty? and (propDef['unique'] or propDef['identifier']) and !@allowDupItems)
                  unless(checkUnique(value, pathElems)) # this method knows whether to talk to MongoDB for collection-wide unique or just check current scope
                    @validationErrors << "ERROR: the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property is tagged as having to be unique. But its value #{value.inspect} has been seen for this property already. For unique properties somewhere under an items list, the property must uniquely identify that item in the list; no other item in the list can have the same value for this property. For unique properties outside/above-any items list, no other *document* in the collection can have the same value for the property; i.e. the property is unique in the whole collections is sort of like another kind of identifier!"
                  end
                end
              else
                unless(value.nil? or value !~ /\S/)
                  @validationErrors << "ERROR: the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property is tagged as being [valueless]. Yes it still has value: #{value.inspect}"
                end
              end
              # . matches domain?
              if(@validationErrors.empty?)
                validInfo = @modelValidator.validVsDomain(value, propDef, pathElems, { :castValue => @castValues, :needsCastCheck => @needsCastCheck })
                if(validInfo.nil?) # check returned nil (something is wrong in the propDef) & details already recorded in @validationErrors of the modelValidator
                  @validationErrors.push( *@modelValidator.validationErrors )
                elsif(validInfo[:result] == :INVALID) # doc error, doesn't match domain
                  @validationErrors << "ERROR: the value (#{value.inspect}) for the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property doesn't match the domain/type information specified in the document model (#{propDef['domain'] ? propDef['domain'].inspect : @modelValidator.class::FIELDS['domain'][:default]}); it is not acceptable."
                else # fine so far
                  # But parsing value could indicate we need to generate some content or some other complex instruction/return object.
                  result = validInfo[:result]
                  if(result == :CONTENT_NEEDED or result == :CONTENT_MISSING)
                    # Spike in scope Symbol for convenience
                    validInfo[:scope] = @uniqueProps[:scope]
                    @contentNeeded[validInfo[:pathElems].join('.')] = validInfo
                    if(result == :CONTENT_MISSING and !@missingContentOk)
                      @validationErrors << "ERROR: The root property has missing content that the validation call indicates should have been filled in by now."
                    end
                  end
                  # Should we modify the input doc to have the casted/normalized value? Required for saving to database.
                  if(@castValues)
                    # Yes. Then the appropriate normalized value is in validInfo[:castValue] because of how we called validVsDomain()
                    propValObj['value'] = validInfo[:castValue]
                  end
                  # If domain of current property is "numItems" and our model for that property has an items array, then we continue.
                  if(@modelValidator.getDomainField(propDef, :type) == "numItems" and propDef.key?('items'))
                    # If propValObj doesn't have an items array, then the number of items currently associated with that property is 0.
                    unless(propValObj['items'])
                      propValObj['value'] = 0
                    # Otherwise, we just count the total number of items present in the items array and make that number the value of this property.
                    # Note that if the items array is 0, this will make the value 0 (since .size of an empty array is 0).
                    else
                      propValObj['value'] = propValObj['items'].size
                    end
                  end
                  # Are we tracking needsCasting?
                  if(@needsCastCheck and validInfo[:needsCasting])
                    @needsCastingPropPaths << pathElems.join('.')
                  end
                end
              end
              # Recurse, depending which kind of sub-elements it has (won't have both).
              # - Either doc or model has sub-properties? Check model because some may be REQUIRED but missing.
              if(propValObj.key?('properties') or propDef.key?('properties'))
                validateProperties(propName, propValObj, propDef, pathElems.dup)
              elsif(propValObj.key?('items')) # Only check if DOC has; item lists can inherently be empty so don't care about model at this time.
                validateItems(propName, propValObj, propDef, pathElems.dup)
              else # Make sure it doesn't have any thing other than properties or items or value
                propValObj.each_key {|propKey|
                  if(!SUPPORTED_PROP_KEYS.key?(propKey))
                    @validationErrors << "ERROR: The value object for the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} contains something other than the 'properties', 'items' or 'value' fields. This is not allowed."
                    break
                  end
                }
              end
            end
          else
            @validationErrors << "ERROR: The value object for the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property contains both the 'properties' and 'items' fields. A property can have EITHER sub-properties or a homogenous list of sub-items, not both."
          end
        else
          @validationErrors << "ERROR: the value object associated with the key '#{propName.inspect} (i.e. for the  #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property) must be a hash/map-like object which makes use of the standard keys/fields: 'value', and either 'properties' or 'items'. In the document however, the value object appears to be a '#{propValObj.class}', which is not correct."
        end
      end
      @validationMessages << "#{' '*(pathElems.size)}PROP #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'} (#{@validationErrors.size})"
      return @validationErrors
    end # def validateProperty(propDef, pathElems, namesHash)
  
  end
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Validators
