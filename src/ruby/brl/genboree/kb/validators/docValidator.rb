require 'time'
require 'date'
require 'uri'
require 'sha1'
require 'json'
require 'brl/util/util'
require 'brl/extensions/units'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/kb/validators/modelValidator'

module BRL ; module Genboree ; module KB ; module Validators
  class DocValidator

  attr_accessor :docId
  attr_accessor :model
  attr_accessor :dataCollName
  attr_accessor :kbDatabase
  attr_accessor :modelValidator
  attr_accessor :validationErrors
  attr_accessor :validationWarnings
  attr_accessor :validationMessages
  attr_accessor :lastIdKey
  attr_accessor :modelCache
  attr_accessor :disableCache
  # @return [Hash<String, Hash>] mapping a property path to a context Hash with information for the content generation framework
  #   the context Hash (from e.g. BRL::Genboree::KB::Validators::ModelValidator#validVsDomain) contains the following keys
  #   :result, :pathElems, :propDef, :domainRec, :parsedDomain, :scope
  attr_accessor :contentNeeded
  attr_accessor :missingContentOk
  attr_accessor :uniqueProps
  # @return [boolean] Should validation skip uniqueness check for items lists as in the case of a first validation with an item list of autoID domain properties.  @false@ by default.
  attr_accessor :allowDupItems
  # @return [boolean] Should validation also cast/normalize values in the source doc? @false@ by default.
  attr_accessor :castValues
  # @return [boolean] Should validation also check whether each value needs casting/normalization prior to save, etc. @false@ by default
  #   This will also enabling the optional tracking of property paths in the doc that need casting/normalization.
  attr_accessor :needsCastCheck
  # @return [Array<String>] If @@needsCastCheck@ is @true@, this will have a list of property paths in the doc whose values need casting.
  #   By default this list is EMPTY and the @needsCastCheck@ is not done (to save unnecessary overhead)
  attr_accessor :needsCastingPropPaths
  # @return [boolean] Should we relax validation of the root property? Example: validating a sub-doc extracted from full KbDoc using KbDoc#getSubDoc
  #   against its model extracted from the model using ModelsHelper#findPropDef. In this case, the sub-doc root is almost certainly not going to
  #   meet many of the special criteria for doc roots.
  attr_accessor :relaxedRootValidation

  SUPPORTED_PROP_KEYS = { 'properties' => nil, 'items' => nil, 'value' => nil }

  def initialize(kbDatabase=nil, dataCollName=nil)
    if(kbDatabase.nil? or (kbDatabase.is_a?(BRL::Genboree::KB::MongoKbDatabase) and kbDatabase.name.to_s =~ /\S/ and kbDatabase.db.is_a?(Mongo::DB)))
      @kbDatabase = kbDatabase
    else
      raise ArgumentError, "ERROR: if provided the kbDatabase arg must be a properly connected/active instance of BRL::Genboree::KB::MongoKbDatabase."
    end
    @dataCollName = dataCollName
    @modelValidator = BRL::Genboree::KB::Validators::ModelValidator.new()
    # Config/behavior flags
    @allowDupItems = false
    @castValues = false
    @disableCache = false
    @missingContentOk = false
    # Tracking variables
    @modelCache = {}
    @contentNeeded = {}
    @needsCastingPropPaths = []
    @lastIdKey = @docId = nil
    @relaxedRootValidation = false
  end

  def clear()
    @validationErrors.clear() rescue nil
    @validationWarnings.clear() rescue nil
    @validationMessages.clear() rescue nil
    @modelCache.clear() rescue nil
    @contentNeeded.clear() rescue nil
    @needsCastingPropPaths.clear() rescue nil
    @model = @modelValidator = @validationErrors = @validationWarnings = @validationMessages = @lastIdKey = nil
    @docId = @contentNeeded = @needsCastingPropPaths = nil
    @modelCache = {}
    @contentNeeded = {}
    @needsCastingPropPaths = []
    return
  end

  # Validate a document against a model
  # @param [BRL::Genboree::KB::KbDoc] doc the document to validate against a model
  # @param [BRL::Genboree::KB::KbDoc, String] modelDocOrCollName the model to use to validate against the model
  #   or the name of the collection to retrieve the model for; if providing a collection name, this class
  #   must be initialized with handles to Mongo so the model can be retrieved
  # @param [Boolean] restoreMongo_idKey if true, leave any Mongo "_id" fields intact within the doc;
  #   otherwise, remove them
  # @param [Hash] opts Additional args {Hash}. Keys:
  #   :castValues => Should validation cast/normalize the values in the doc according to the model domains? Required for saving into Mongo! Default is false.
  # @return [Boolean, Symbol] true/false indicates valid or invalid;
  #   :CONTENT_NEEDED means that the document is valid except for missing values where the model indicates a
  #     known content-generation domain
  # @raise [RuntimeError] if modelDocOrCollName is a String and the associated model could not be retrieved
  def validateDoc(doc, modelDocOrCollName=@dataCollName, restoreMongo_idKey=false, opts={ :castValues => @castValues, :needsCastCheck => @needsCastCheck, :allowDupItems => @allowDupItems })
    @modelValidator.relaxedRootValidation = @relaxedRootValidation
    usingCachedModel = false
    @docId = @lastIdKey = nil
    @allowDupItems = opts[:allowDupItems]
    @castValues = opts[:castValues]
    @needsCastCheck = opts[:needsCastCheck]
    @validationErrors = []
    @validationWarnings = []
    @validationMessages = []
    @contentNeeded = {}
    @needsCastingPropPaths = []
    # Set flag indicating we've seen the "identifier"
    # - this will only get reset when entering an "items" list and restored when finished with it
    # - the doc identifier is the id amongst the set of documents and properties within an items
    #   list can have an identifier for id'ing an item amongst the set of items
    @haveIdentifier = false
    @uniqueProps = { :scope => :collection, :props => Hash.new{|hh, kk| hh[kk] = {} }}
    # Check model cache (to avoid repeatedly validating the same model doc)
    if((modelDocOrCollName.is_a?(String) and @modelCache.key?(modelDocOrCollName)) and !@disableCache)
      model = @modelCache[modelDocOrCollName]
      usingCachedModel = true
    elsif((modelDocOrCollName.acts_as?(Hash) and @modelCache.key?(modelDocOrCollName.object_id)) and !@disableCache)
      model = @modelCache[modelDocOrCollName.object_id]
      usingCachedModel = true
    else # cache disabled, or no corresponding model cached yet
      if(modelDocOrCollName.is_a?(String)) # name of a collection
        @dataCollName = modelDocOrCollName
        # - must have a @kbDatabase to work with then!
        if(@kbDatabase.is_a?(BRL::Genboree::KB::MongoKbDatabase))
          if(@kbDatabase.name.to_s =~ /\S/ and @kbDatabase.db.is_a?(Mongo::DB))
            pingResult = @kbDatabase.db.connection.ping
            if(pingResult.is_a?(BSON::OrderedHash) and pingResult['ok'] == 1.0)
              # - get ModelsHelper to aid us in getting the model
              modelsHelper = @kbDatabase.modelsHelper()
              modelKbDoc = modelsHelper.modelForCollection(@dataCollName)
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "modelKbDoc.class: #{modelKbDoc.class.inspect} ; with content:\n\n#{JSON.pretty_generate(modelKbDoc)}\n\n")
              if(modelKbDoc.is_a?(BRL::Genboree::KB::KbDoc))
                model = modelKbDoc.getPropVal('name.model') rescue nil
                usingCachedModel = false # at least, not cached yet ; needs to be validated
                if(model.nil?)
                  @validationErrors << "ERROR: The model parameter is a full BRL::Genboree::KB::KbDoc document, but does not have a valid 'model' sub-property where the actual model data can be found."
                end
              else # probably nil because failed
                raise "ERROR: could not retrieve a model doc from the #{@dataCollName.inspect} collection within the #{@kbDatabase.name.inspect} GenboreeKB. Either the collection was created outside the Genboree framework, the model was deleted, or perhaps there is a spelling mistake (names are case-sensitive)?"
              end
            else
              raise "ERROR: the MongoKbDatabase object at DocValidator#kbDatabase is the correct kind of object and is setup correctly, but the Mongo server it points to cannot be reached. Perhaps it is down, or the host/port info is wrong, or the authorization credentials are wrong. Host: #{@kbDatabase.db.connection.host.inspect} ; port: #{@kbDatabase.db.connection.port.inspect} ; ping result:\n#{@kbDatabase.db.connection.ping.inspect}\n\n"
            end
          else
            raise "ERROR: the MongoKbDatabase object at DocValidator#kbDatabase is the correct kind of object but appears to not be setup or connected correctly. One or more of these are inappropriate: database name: #{@kbDatabase.name.inspect} ; driver class: #{@kbDatabase.db.class}"
          end
        else
          raise "ERROR: you have provided #{__method__}() with a collection name, but you did not initialize this object with connected BRL::Genboree::KB::MongoKbDatabase instance, nor did you add one after initialization. Can't query the collection without a database object!"
        end
      elsif(modelDocOrCollName.is_a?(BRL::Genboree::KB::KbDoc))
        model = modelDocOrCollName.getPropVal('name.model') rescue nil
        usingCachedModel = false # at least, not cached yet ; needs to be validated
        if(model.nil?)
          # No such property name.model. Assume modelDoc IS the model data structure, converted to a KbDoc but not actually property oriented:
          model = modelDocOrCollName
        end
      else # hash-like object which IS the model
        model = modelDocOrCollName
        usingCachedModel = false # at least, not cached yet ; needs to be validated
      end
    end

    # At this point, we should have the actual model, or we have @validationErrors (or we raised and didn't get here)
    if(@validationErrors.empty?)
      # Does the model look valid?
      @model = model
      if(usingCachedModel)
        modelDocValid = true
      else # not using cached model ... either don't have in cache yet or caching disabled
        # regardless, need to validate the model
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@model.class: #{@model.class.inspect} with content:\n\n#{JSON.pretty_generate(@model)}\n\n")
        modelDocValid = @modelValidator.validateModel(@model)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Validating model with object_id: #{model.object_id}")
        if(modelDocValid and !@disableCache)
          if(modelDocOrCollName.is_a?(String))
            @modelCache[modelDocOrCollName] = @model
          else # Hash or hash like
            @modelCache[modelDocOrCollName.object_id] = @model
          end
        end
      end

      unless(modelDocValid)
        @validationErrors << "ERROR: The modelDoc parameter doesn't appear to contain or refer to a valid document model schema. Validation of the model reported this error:\n  . #{@modelValidator.validationErrors.join("\n  .")}"
      else
        # Start examining the doc
        if(doc)
          if( !doc.is_a?(BRL::Genboree::KB::KbDoc) and doc.acts_as?(Hash) )
            doc = BRL::Genboree::KB::KbDoc.new(doc)
          end
          validateRootProperty(doc)
          # Are we supposed to restore any mongo '_id' key we saw (if we did actually see one)
          if(restoreMongo_idKey and @lastIdKey)
            doc['_id'] = @lastIdKey
          end
        end
      end
    end
    @validationMessages << "DOC\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'} (#{@validationErrors.size})"
    if(@validationErrors.empty?)
      if(@contentNeeded.empty?)
        retVal = true
      else # there is content that may need to be filled in
        retVal = :CONTENT_NEEDED
      end
    else # there are errors
      retVal = false
    end
  end

  # Validate multiple documents against a model
  # @see validateDoc
  #   [Hash] :invalid - map invalid document id to error
  #   [Hash] :error - map document id to an error (could not validate or invalidate document)
  #   [Array] :CONTENT_NEEDED - documents requiring content generation
  # @todo does this retVal representation increase memory use or just use pointers?
  #   most likely latter but should be verified!
  # @todo how long does it take to make a hash key out of a kbDoc? use index instead?
  # @todo prefer uniformity of keys?
  # @todo Review how :CONTENT_NEEDED return value from validateDoc() will be handled.
  #   Note that new opts Hash gives some ability to affect this, but the handling of docStatus
  #   results in :CONTENT_NEEDED == add doc to invalid list. Is that right, always? Review.
  # @note deprecated - use dataCollectionHelper with save=false
  def validateDocs(docs, modelDocOrCollName=@dataCollName, restoreMongo_idKey=false, opts={ :castValues => @castValues, :needsCastCheck => @needsCastCheck })
    raise "ERROR: don't use #{__method__} until reviewing various calling and return scenarios where validateDoc() returns :CONTENT_NEEEDED"
    retVal = Hash.new { |hh, kk| hh[kk] = [] }
    retVal[:valid] = []
    retVal[:invalid] = {}
    retVal[:error] = {}
    docs.each_index { |ii|
      doc = docs[ii]
      docStatus = nil
      begin
        # 3 return values: true, false, :CONTENT_NEEDED
        docStatus = validateDoc(doc, modelDocOrCollName, restoreMongo_idKey, opts)
      rescue => err
        docStatus = err
      end
      if(docStatus == true)
        retVal[:valid].push(doc)
      elsif(docStatus == false)
        id = doc.getRootPropVal()
        retVal[:invalid][id] = @validationErrors.first
      elsif(docStatus.is_a?(Exception))
        retVal[:error].push[doc] = docStatus
      else # docStatus is nil, probably model propDef is messed up ; OR possibly :CONTENT_NEEDED was returned from validateDoc() ?
        id = doc.getRootPropVal()
        retVal[:invalid][id] = @validationErrors.first
      end
      @validationErrors.clear()
    }
    return retVal
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
            if(propValObj and ( (!value.nil? and value.to_s =~ /\S/) or (autoContentDomain and rootDomain) ) or @relaxedRootValidation)
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
                else
                  # Perform extra domain-specific validation
                  domainStr = @modelValidator.getDomainStr(@model)
                  validationErrors = validVsDomainAndColl(value, domainStr, pathElems)
                  @validationErrors += validationErrors
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
                if(!prop.key?('items') or @relaxedRootValidation)
                  # Make sure root prop does not have anything besides properties or value
                  propValObj.each_key { |propKey|
                    if(propKey == 'properties' or propKey == 'value' or @relaxedRootValidation)
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
              @validationErrors << "ERROR: the root property has no value or the value is empty. This is not allowed for the document identifier."
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
          # Check value
          value = propValObj['value']
          domainStr = BRL::Genboree::KB::Validators::ModelValidator::FIELDS['domain'][:extractVal].call(propDef, "string")
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
              # Check the Object type spec here:
              # Add to validationWarnings array if failed.
              if(propDef.key?('Object Type'))
                objTypeValid = false
                objTypeValid = validateObjectTypeToPropValue(value, propDef)
                @validationWarnings << "WARNING: the value (#{value.inspect}) for the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property doesn't match the Object Type information specified in the document model (#{ BRL::Genboree::KB::Validators::ModelValidator::FIELDS["Object Type"][:extractVal].call(propDef, nil)}); it is not acceptable." unless(objTypeValid)
              end              
              #But parsing value could indicate we need to generate some content or some other complex instruction/return object.
              result = validInfo[:result]
              if(result == :CONTENT_NEEDED or result == :CONTENT_MISSING)
                # Spike in scope Symbol for convenience
                validInfo[:scope] = @uniqueProps[:scope]
                @contentNeeded[validInfo[:pathElems].join('.')] = validInfo
                if(result == :CONTENT_MISSING and !@missingContentOk)
                  @validationErrors << "ERROR: The root property has missing content that the validation call indicates should have been filled in by now."
                end
              else
                # Perform extra domain-specific validation
                validationErrors = validVsDomainAndColl(value, domainStr, pathElems)
                @validationErrors += validationErrors
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

  # @todo Implement collection-wide uniqueness checking as well
  def checkUnique(value, pathElems, seenUniqProps=@uniqueProps)
    retVal = false
    scope = seenUniqProps[:scope] rescue nil
    props = seenUniqProps[:props] rescue nil
    if(seenUniqProps.acts_as?(Hash) and props and props.acts_as?(Hash) and scope and (scope == :collection or scope == :items))
      if(scope == :items)
        # Check @uniqueProps to see if we've encountered this value for this property within
        # the current items scope.
        listIndex = pathElems.rindex { |xx| xx =~ /\[\d+\]/ }
        propPath = pathElems[0...listIndex].join('.')
        unless(props.key?(propPath) and props[propPath].key?(value))
          retVal = true
          props[propPath][value] = nil # mark as seen
        else
          retVal = false
        end
      else # scope must be :collection
        propPath = pathElems.join('.')
        if(@kbDatabase.is_a?(BRL::Genboree::KB::MongoKbDatabase))
          if(@dataCollName.is_a?(String) and @dataCollName =~ /\S/)
            # @todo Do a search using propPath to find any docs that already have value for this property
            # - need a dataCollectionHelper
            dataHelper = @kbDatabase.dataCollectionHelper(@dataCollName)
            propUnique = dataHelper.hasUniqueValue?(@docId, propPath, value)
            if(propUnique)
              retVal = true
              seenUniqProps[propPath] = value # mark as seen
            else
              retVal = false
            end
          else
            raise "ERROR: we have a MongoKbDatabase object available for checking uniqueness vs the actual collection, but DocValidator#docCollName doesn't contain a String with the name of the collection, so we can't do this. Instead it contains #{@docCollName.inspect}. If you are doing full document validations, including validating unique property values against the collection of documents, you need both the MongoKbDatabase object AND a valid collection name; if you are trying to do only a local validation (vs a local model file or model structure), do not provide a MongoKbDatabase argument when initializing this validator."
          end
        else # Not really meaningful without checking actual collection ; check seenUniqProps [should be useless check]
          unless(seenUniqProps.key?(propPath) and seenUniqProps[propPath] == value)
            retVal = true
            seenUniqProps[propPath] = value # mark as seen
          end
        end
      end
    else 
      raise "ERROR: the seenUniqProps argument must be a Hash with both the :scope and :props keys; valid scopes are :collection & :items, while :props maps to a Hash of unique properties already seen + the value seen."
    end
    return retVal
  end

  # Custom validation for the autoID domain increment uniqMode: require that the numeric
  #   part of the id is less than the value stored in the counter (in collection metadata document)
  # @param [String] value the value from a data document associated with the autoID increment domain
  # @param [String] propPath the BRL property path that the value is associated with
  # @param [Hash] pdom the parsed domain from
  #   BRL::Genboree::KB::Validators::ModelValidator::DOMAINS[{domain}][:parseDomain]
  # @param [String] dataCollName the name of the data collection that the @propPath@ applies to
  # @param [BRL::Genboree::KB::MongoKbDatabase] kbDatabase the object used to query for the counter
  # @return [Hash]
  #   :ok [Boolean] true if value is ok
  #   :msg [String] error message if ok is false
  #   :warnings [Array<String>] empty if everything went as expected, else 1+ warning strings
  def self.isIncrementOk(value, propPath, pdom, dataCollName, kbDatabase)
    rv = { :ok => false, :msg => "Internal Server Error", :warnings => [] }
    extractFailMsg = "Could not extract numeric portion from increment id #{value.inspect}; this may be caused by an error in specifying the domain for this property"

    if(dataCollName and kbDatabase) # these may be nil in stand-alone mode (i.e. just have model & doc, not fully integrated with mongo and a collection)
      # get the current value of the counter associated with this increment id
      mdh = kbDatabase.collMetadataHelper()
      counter = mdh.getCounter(dataCollName, propPath)
      if(counter.nil?)
        dbName = kbDatabase.db.name rescue nil
        rv[:msg] = "Could not retrieve the current value of the counter for #{propPath.inspect} in collection #{dataCollName.inspect} in database #{dbName.inspect}"
        $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", rv[:msg])
      else
        matchData = pdom[:uniqModeMatcher].match(value)
        if(matchData)
          if($1.nil?)
            rv[:msg] = extractFailMsg
          else
            intPart = $1.to_i
            if(intPart <= counter)
              rv[:ok] = true
              rv[:msg] = "ok"
            else
              rv[:msg] = "The property value #{value.inspect} has a numeric part in excess of the last reserved AutoID for this property #{counter.inspect}"
            end
          end
        else
          rv[:msg] = extractFailMsg
        end
      end
    else # in stand-alone mode (no mongo connect, no collection info; just model and doc)
      # Do basic format validation only
      matchData = pdom[:uniqModeMatcher].match(value)
      if($1.nil?)
        rv[:msg] = extractFailMsg
      else
        rv[:ok] = true
        rv[:msg] = "ok"
        rv[:warnings] << "WARNING: Document validated in stand-alone mode. Could not verify increment counter properties vs actual collection-specific counter values, since in stand-alone validation mode there is no Mongo & no collection info."
      end
    end
    return rv
  end

  def isIncrementOk(value, propPath, pdom, dataCollName=@dataCollName, kbDatabase=@kbDatabase)
    self.class.isIncrementOk(value, propPath, pdom, dataCollName, kbDatabase)
  end

  # Perform extra domain specific validation that requires information from the database
  #   (unlike BRL::Genboree::KB::Validators::ModelValidator#validVsDomain)
  # @param [Object] value the value we are validating
  # @param [String] domainStr the domain to validate the value against
  # @param [Array<String>] pathElems tokenized BRL propPath
  # @param [BRL::Genboree::KB::Validators::ModelValidator] modelValidator object to help with validation
  # @param [String] dataCollName the name of the data collection in @kbDatabase@
  # @param [BRL::Genboree::KB::MongoKbDatabase] kbDatabase object to help query the database for extra validation
  # @return [Array<String>] validationErrors -- empty if @value@ is valid vs @domainStr@
  def self.validVsDomainAndColl(value, domainStr, pathElems, modelValidator, dataCollName, kbDatabase)
    rv = []
    # Determine if this domain is an autoID increment domain that needs special validation
    unless(value == :CONTENT_MISSING or value == :CONTENT_NEEDED or value == "")
      # then we are not in a first pass content validation step
      domainRec = modelValidator.getDomainRec(domainStr)
      if(domainRec.nil?)
        $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", "Could not validate value #{value.inspect} of #{pathElems.join(".")} against the domain #{domainStr.inspect} because no associated domain record could be found; we assume that this domain does not require any special validation against the collection and proceed.")
      else
        pdom = domainRec[:parseDomain].call(domainStr)
        propPath = pathElems.join(".")
        isIncrement = (pdom.is_a?(Hash) and (pdom[:uniqMode] == "increment"))
        if(isIncrement)
          okObj = isIncrementOk(value, propPath, pdom, dataCollName, kbDatabase)
          unless(okObj[:ok])
            rv << "ERROR: the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property has an AutoID increment domain that failed validation: #{okObj[:msg]} "
          end
        end
      end
    end
    return rv
  end
  def validVsDomainAndColl(value, domainStr, pathElems, modelValidator=@modelValidator, dataCollName=@dataCollName, kbDatabase=@kbDatabase)
    self.class.validVsDomainAndColl(value, domainStr, pathElems, modelValidator, dataCollName, kbDatabase)
  end

  # Using a flattened model, select only the autoID domains with the increment uniqMode
  #   and retrieve their associated regexp (like the one used in validation) that can be
  #   used to extract the generated portion from their IDs
  # @see BRL::Genboree::KB::Helpers::ModelsHelper.flattenModel
  # @param [Hash] pathToDefMap map of model's property path to its property definition
  # @param [BRL::Genboree::KB::Validators::ModelValidator] object needed to retrieve domain record
  # @return [Hash] map of autoID increment property path to its associated regexp
  # @todo class method for getDomainRec then dont need modelValidator instance
  # @todo split the "select" function from the "map"?
  def self.mapAutoIdIncPathToMatcher(pathToDefMap, modelValidator)
    rv = {}
    uniqMode = "increment"
    pathToDefMap.each_key { |propPath|
      propDef = pathToDefMap[propPath]
      domainStr = propDef["domain"]
      domainRec = modelValidator.getDomainRec(domainStr)
      domainRec = modelValidator.getDomainRec("string") if(domainRec.nil?)

      re = nil
      if(domainRec[:type] == "autoID")
        pdom = domainRec[:parseDomain].call(domainStr)
        if(pdom[:uniqMode] == uniqMode)
          re = BRL::Genboree::KB::Validators::ModelValidator.composeAutoIdRegexp(pdom)
        end
      elsif(domainRec[:type] == "autoIDTemplate")
        pdom = domainRec[:parseDomain].call(domainStr)
        if(pdom[:uniqMode] == uniqMode)
          re = BRL::Genboree::KB::Validators::ModelValidator.composeAutoIdTemplateRegexp!(pdom)
        end
      end
      unless(re.nil?)
        # then this propDef is one of the autoID types
        rv[propPath] = re
      end
    }
    return rv
  end
  def mapAutoIdIncPathToMatcher(pathToDefMap, modelValidator=@modelValidator)
    self.class.mapAutoIdIncPathToMatcher(pathToDefMap, modelValidator)
  end

  # With a map of autoID increment property paths to their associated regexp and the added
  #   requirement that property paths are "propSel" paths (and not model property paths),
  #   compose a new map of property path to the maximum incremental generated id
  #   for that property in a data document (or nil if the value for that property is invalid)
  # @param [Hash] pathToMatcherMap as in return value of mapAutoIdIncPathToMatcher
  # @param [Hash] dataDoc a document for a user/data collection (not an internal collection)
  # @return [Hash] map of property path to max increment generated portion for that property
  #   or property path to nil if the generated portion could not be extracted/max'd
  # @see mapAutoIdIncPathToMatcher
  # @todo very similar to Util.validateAutoId
  # @todo this work will be repeated again in document validation
  # @todo distinguish between 2 types of failures?
  def self.mapAutoIdPathToMaxInDoc(pathToMatcherMap, dataDoc)
    rv = {}
    propSelector = BRL::Genboree::KB::PropSelector.new(dataDoc)
    pathToMatcherMap.each_key { |propPath|
      autoIdGenMatcher = pathToMatcherMap[propPath]
      values = propSelector.getMultiPropValues(propPath) rescue nil
      if(values.nil?)
        rv[propPath] = nil
      else
        anyFail = false
        valueGenParts = values.map { |value|
          matchData = autoIdGenMatcher.match(value)
          if(matchData)
            $1.to_i
          else
            anyFail = true
            break
          end
        }
        if(anyFail)
          rv[propPath] = nil
        else
          rv[propPath] = valueGenParts.max
        end
      end
    }
    return rv
  end

  # Get the maximum value for a generated autoID from a set of documents on a "best effort" basis:
  #   that is, if two documents are valid and one is invalid we will return the max of the valid two
  #   rather than error out
  # @note if all are invalid {propPath} => 0
  # @see mapAutoIdPathToMaxInDoc
  def self.mapAutoIdPathToMaxInDocs(pathToMatcherMap, dataDocs)
    globalPropToMax = Hash.new { |hh, kk| hh[kk] = 0 }
    dataDocs.each { |doc|
      autoIdPropToMax = mapAutoIdPathToMaxInDoc(pathToMatcherMap, doc)
      autoIdPropToMax.each_key { |propPath|
        localMax = autoIdPropToMax[propPath]
        globalMax = globalPropToMax[propPath]
        globalPropToMax[propPath] = [localMax.to_i, globalMax].max
      }
    }
    return globalPropToMax
  end

  # Checks if the value of the property with an 'Object Type' spec is in sync with 
  # the collection name given in the Object Type. It also checks if the specified collection
  # does actually exists if the mongoKbDatabase instance is available within the class
  # @param [String] value of the property of interest
  # @param [Hash,nil] propDef the property definition from the model that will be used to validate the value
  #   mostly for its 'domain' key for lookup in DOMAINS. Can be nil if tgtColl is present
  # @param [BRL::Genboree::KB::MongoKbDatabase, nil] mdb class instance of BRL::Genboree::KB::MongoKbDatabase. Optional and 
  #  will be used to check the presence of the collection name if present
  # @param [String] tgtColl the target collection collection given in the Object Type, is useful when the tgtColl
  #   is already known, can skip to extract it from the propDef  
  # @param [Boolean] returnDocId true will return the doc id from the link if validation is a success
  def self.validateObjectTypeToPropValue(value, propDef=nil, mdb=nil, tgtColl=nil, returnDocId=false)
    retVal = false
    unless(tgtColl)
      objectType = BRL::Genboree::KB::Validators::ModelValidator::FIELDS['Object Type'][:extractVal].call(propDef, nil)      
      tgtColl = $2 if(objectType and objectType =~ /^([^:]+):(.+)$/)
    end
      # must be a doc resource path as well as the coll must match the one in the Object Type value
      retVal = true if(tgtColl and value =~ /^(.*)coll\/([^\/\?]+)\/doc\/([^\/\?]+)(?:$|\/([^\/\?]+)$)/ and CGI.unescape($2) == tgtColl)
      # CAUTION! the collection names are a match, but there is no validation done here to check if the collection name mentioned actually exists or not.
      # So check that if a mongoKbDatabase instance is available, instead skip that step
      if(retVal and mdb)
        retVal = mdb.collections.include?(tgtColl)
      end
      retVal = CGI.unescape($3) if(retVal and returnDocId)
    return retVal
  end

  # check object type spec with the property value
  # @todo use mdb or not?
  def validateObjectTypeToPropValue(value, propDef, mdb=nil, tgtColl=nil, returnDocId=false)
    return self.class.validateObjectTypeToPropValue(value, propDef, mdb, tgtColl, returnDocId)
  end

end
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Validators
