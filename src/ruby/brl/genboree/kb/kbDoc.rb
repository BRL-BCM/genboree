require 'cgi'
require 'brl/util/util'
require 'brl/extensions/units'
require 'brl/extensions/object'
require 'brl/genboree/kb/propSelector'

module BRL ; module Genboree ; module KB

# When instantiated with a Hash or an Array object (the actual doc),
#   this will delegate methods to that object unless overridden below.
#   It will also respond to additional methods added below.
# A sort of "wrapper" around the actual doc object, which can be a Hash (most common) or maybe an Array
# @example Instantiation
#   kbDoc1 = KbDoc.new(aHash)
#   kbDoc2 = KbDoc.new(aArray)
class KbDoc < Hash

  DOC_INDEX_RE = /\.\[\s*(?:\d+|FIRST|LAST)?\s*\]/

  attr_accessor :opts
  attr_accessor :nilGetOnPathError

  # CONSTRUCTOR. Only delegate to {Hash} or {Array}
  # @param [Hash] obj An existing Hash with keys to have here
  # @param [Hash<Symbol,Object>] opts (Optional) An Symbol-keyed Hash of options that override default behavior.
  # @return [KbDoc]
  # @raise [ArgumentError] if @obj@ is not {Hash} or {Array} or soemthing that acts like these [through delegation]
  def initialize(obj=nil, opts={})
    super()
    unless(obj.nil?)
      if(obj.acts_as?(Hash))
        self.update(obj)
      else
        raise ArgumentError, "ERROR: Cannot use #{obj.class} objects to instantiate {KbDoc}; if provided, must be an existing {Hash} or something that acts like it."
      end
    end
    if(opts.is_a?(Hash))
      @opts = opts
      @nilGetOnPathError = ( @opts[:nilGetOnPathError] ? true : false )
    else
      raise ArgumentError, "ERROR: If provided the opts parameter must be a Symbol keyed Hash, not a #{opts.class}."
    end
  end

  # Get a {BRL::Genboree::KB::PropSelector} instance for this {KbDoc}.
  def propSelector()
    return BRL::Genboree::KB::PropSelector.new( self )
  end

  # Construct a trivial property-oriented document from a Hash
  # @param [Hash] obj the hash to transform
  # @param [String] id the new root identifier property for the object
  # @todo currently only supports almost flat Hash
  # @todo rename to more generic propDocFromObj?
  # @todo use recursion
  def self.propDocFromHash(obj, idName, idValue="[valueless]")
    retVal = {}
    propObj = {}
    if(obj.respond_to?(:each_key))
      obj.each_key { |kk|
        vv = obj[kk]
        if(vv.is_a?(Array))
          raise ArgumentError.new("Cannot transform nested Ruby hash into a property-oriented document")
        elsif(vv.is_a?(Hash))
          propObj[kk] = { "value" => kk, "properties" => {} }
          vv.each_key { |kk2|
            vv2 = vv[kk2]
            raise ArgumentError.new("Cannot transform nested Ruby hash into a property-oriented document") if(vv2.is_a?(Array) or vv2.is_a?(Hash))
            propObj[kk]["properties"][kk2] = { "value" => vv2 }
          }
        else
          propObj[kk] = { "value" => vv }
        end
      }
      retVal[idName] = {
        "value" => idValue,
        "properties" => propObj
      }
      retVal[idName]["properties"] = propObj
    else
      retVal[idName] = { "value" => obj }
    end

    return self.new(retVal)
  end

  # @see propDocFromHash
  def self.propDocsFromArray(obj, idName)
    rv = []
    obj.each { |item|
      rv.push({ idName => { "value" => item }})
    }
    return rv
  end

  def self.docPath2ModelPath(path)
    return path.gsub(DOC_INDEX_RE, '')
  end

  def docPath2ModelPath(path)
    return self.class.docPath2ModelPath(path)
  end

  # @todo Do faster and/or without the Producer?
  # @todo Fix bug: doesn't go into the "versionNum.content" doc correctly. Which sort of makes sense given the
  #   non-normal transition from version rec KbDoc to the data KbDoc at 'versionNum.content.value', but this is
  #   known domain type and maybe should work. Or it's a fundamental problem in KbDoc which won't go down into
  #   versionNum.content.value.value and versionNum.content.properties since they look "wrong". HOWEVER, this
  #   method could be written such that it will go down through all keys even if don't look like sensible KbDoc.
  def flattenDoc()
    require 'brl/genboree/kb/producers/fullPathTabbedDocProducer'
    producer = BRL::Genboree::KB::Producers::FullPathTabbedDocProducer.new({})
    flatStrs = producer.produce(self)
    # Remove header
    flatStrs.shift
    retVal = flatStrs.reduce({}) { |flatDoc, line| ff = line.split(/\t/) ; flatDoc[ff.first] = ff.last.autoCast() ; flatDoc }
    return retVal
  end

  def getMatchingPaths(regexp)
    # Flat version of doc (full path => value)
    flatDoc = self.flattenDoc()
    # Find keys (paths) matching the regexp
    matchingPaths = flatDoc.keys.reduce([]) { |mpaths, path| mpaths << path.strip if(path.strip =~ regexp) ; mpaths }
    return matchingPaths
  end

  def allPaths()
    return getMatchingPaths( /./ )
  end
  alias_method :allPropPaths, :allPaths

  def getRootProp()
    retVal = nil
    if(self.acts_as?(Hash))
      self.delete('_id')
      self.delete(:_id)
      retVal = self.keys.first
    end
    return retVal
  end

  def getRootPropVal()
    retVal = nil
    rootProp = getRootProp()
    if(rootProp)
      retVal = getPropVal(rootProp)
    end
    return retVal
  end

  # Does the indicated path exist in the doc?
  # @param [String] path The path to the property for which you want the value.
  # @param [String] sep The path element separator. If provided, usually '/' and with @cgiEscaped=true@
  # @param [Boolean] cgiEscaped Indicates whether the path elements are CGI escaped or not. Usually
  #   to be used with @sep='/'@
  # @return [Boolean] Whether indicated path is valid in the doc or not; basically follow the path down to
  #   the leaf property and then see if it has a Value Object or not. Else false.
  def exists?(path, sep='.', cgiEscaped=false)
    retVal = false
    # Temporarily set @nilGetOnPathError to true for path testing. Will restore when done
    origNilGetOnPathError = @nilGetOnPathError
    @nilGetOnPathError = true
    begin
      valObj = self.getPropValueObj(path, sep, cgiEscaped)
      retVal = true if(valObj)
    ensure
      @nilGetOnPathError = origNilGetOnPathError
    end

    return retVal
  end


  # Get the 'value' of a property using the "path" to the property in this document.
  # * The "path" is a series of propety names (used as keys in the Hash at each lel)
  #   or array indicies (in the form of @[N]@ where N is the 0-based index).
  # * It is assumed that the value object stored at the property indicated by @path@
  #   is present and the 'value' field there will be examined.
  # * By default the path string is  MongoDB style. (e.g. "path.to.item.[7].score"). But this does
  #   not allow for complex property names with "." itself or "[" or "]", etc. Generally only safe for
  #   internal documents and +unsafe+ for user documents. For user documents, URL escaped paths using
  #   "/" as the delimiter are best! i.e. use @sep='/' and @cgiEscaped=true@
  # @note Path components (property names and indices) _cannot_ have leading or trailing spaces.
  #   If present, they will be stripped off before being examined.
  # @param [String] path The path to the property for which you want the value.
  # @param [String] sep The path element separator. If provided, usually '/' and with @cgiEscaped=true@
  # @param [Boolean] cgiEscaped Indicates whether the path elements are CGI escaped or not. Usually
  #   to be used with @sep='/'@
  # @return [Object] the value stored at the property indicated by @path@ or @nil@ if the final property is not
  #   present or if @nil@ itself is stored there (bad practice; rather should not even HAVE the property).
  # @raise [ArgumentError] if the path does not appear to be valid in this document, and specifies
  #   properties that don't actually exist, or property-lists where there is actually a sub-properties Hash, etc.
  def getPropVal(path, sep='.', cgiEscaped=false)
    return getPropField('value', path, sep, cgiEscaped)
  end

  # Get the 'properties' Hash/sub-document of a property using the "path" to the property in this document.
  # * The "path" is a series of propety names (used as keys in the Hash at each lel)
  #   or array indicies (in the form of @[N]@ where N is the 0-based index).
  # * It is assumed that the value object stored at the property indicated by @path@
  #   is present and the 'properties' field there will be examined.
  # * By default the path string is  MongoDB style. (e.g. "path.to.item.[7].score"). But this does
  #   not allow for complex property names with "." itself or "[" or "]", etc. Generally only safe for
  #   internal documents and +unsafe+ for user documents. For user documents, URL escaped paths using
  #   "/" as the delimiter are best! i.e. use @sep='/' and @cgiEscaped=true@
  # @note Path components (property names and indices) _cannot_ have leading or trailing spaces.
  #   If present, they will be stripped off before being examined.
  # @param (see #getPropVal)
  # @return [Hash, nil] the 'properties' Hash/sub-document stored at the property indicated by @path@
  #   or if the final property isn't present.
  # @raise [ArgumentError] if the path does not appear to be valid in this document, and specifies
  #   properties that don't actually exist, or property-lists where there is actually a sub-properties Hash, etc.
  def getPropProperties(path, sep='.', cgiEscaped=false)
    return getPropField('properties', path, sep, cgiEscaped)
  end

  # Get the 'items' Array/property-list of a property using the "path" to the property in this document.
  # * The "path" is a series of propety names (used as keys in the Hash at each lel)
  #   or array indicies (in the form of @[N]@ where N is the 0-based index).
  # * It is assumed that the value object stored at the property indicated by @path@
  #   is present and the 'items' field there will be examined.
  # * By default the path string is  MongoDB style. (e.g. "path.to.item.[7].score"). But this does
  #   not allow for complex property names with "." itself or "[" or "]", etc. Generally only safe for
  #   internal documents and +unsafe+ for user documents. For user documents, URL escaped paths using
  #   "/" as the delimiter are best! i.e. use @sep='/' and @cgiEscaped=true@
  # @note Path components (property names and indices) _cannot_ have leading or trailing spaces.
  #   If present, they will be stripped off before being examined.
  # @param (see #getPropVal)
  # @return [Object, nil] the 'items' Array/property-list stored at the property indicated by @path@
  #   or if the final property isn't present.
  # @raise [ArgumentError] if the path does not appear to be valid in this document, and specifies
  #   properties that don't actually exist, or property-lists where there is actually a sub-properties Hash, etc.
  def getPropItems(path, sep='.', cgiEscaped=false)
    return getPropField('items', path, sep, cgiEscaped)
  end

  # Get the sub-doc at @path@ as if it were a single-rooted KbDoc. i.e. That property is the sole top-level key
  #   which points to its complete value object.
  # * The "path" is a series of propety names (used as keys in the Hash at each level)
  #   or array indicies (in the form of @[N]@ where N is the 0-based index).
  # * By default the path string is  MongoDB style. (e.g. "path.to.item.[7].score"). But this does
  #   not allow for complex property names with "." itself or "[" or "]", etc. Generally only safe for
  #   internal documents and +unsafe+ for user documents. For user documents, URL escaped paths using
  #   "/" as the delimiter are best! i.e. use @sep='/' and @cgiEscaped=true@
  # @note Path components (property names and indices) _cannot_ have leading or trailing spaces.
  #   If present, they will be stripped off before being examined.
  # @param (see #getPropVal)
  # @return [KbDoc] the single-rooted sub-doc beginning at path. The last path element in @path@ is the single property
  #   key of this KbDoc, pointing to the usual value-object Hash (or @nil@ if not present)
  # @raise [ArgumentError] if the path does not appear to be valid in this document, and specifies
  #   properties that don't actually exist, or property-lists where there is actually a sub-properties Hash, etc.
  def getSubDoc(path, sep='.', cgiEscaped=false)
    pathElems = parsePath(path, sep, cgiEscaped)
    subDocPropName = pathElems.last
    subDocValueObj = getPropValueObj(path, sep, cgiEscaped)
    return KbDoc.new({ subDocPropName => subDocValueObj })
  end

  # Get the full value-object Hash for the property at @path@. If present, will have 1 or more of the
  #   standard value-object Hash keys 'value', 'properties', 'items' and will be recursively inclusive. If
  #   not present will be @nil@.
  # * The "path" is a series of propety names (used as keys in the Hash at each level)
  #   or array indicies (in the form of @[N]@ where N is the 0-based index).
  # * By default the path string is  MongoDB style. (e.g. "path.to.item.[7].score"). But this does
  #   not allow for complex property names with "." itself or "[" or "]", etc. Generally only safe for
  #   internal documents and +unsafe+ for user documents. For user documents, URL escaped paths using
  #   "/" as the delimiter are best! i.e. use @sep='/' and @cgiEscaped=true@
  # @note Path components (property names and indices) _cannot_ have leading or trailing spaces.
  #   If present, they will be stripped off before being examined.
  # @param (see #getPropVal)
  # @return [Object, nil] the full value-object Hash stored at the property indicated by @path@
  #   or @nil@ if the property isn't present.
  # @raise [ArgumentError] if the path does not appear to be valid in this document, and specifies
  #   properties that don't actually exist, or property-lists where there is actually a sub-properties Hash, etc.
  def getPropValueObj(path, sep='.', cgiEscaped=false)
    return getPropField(:valueObj, path, sep, cgiEscaped)
  end

  # Set the 'value' of a property using the "path" to the property in this document.
  # Will automatically add the new final property if it is not present yet; but parent
  #   properties must already exist (will refuse to auto-add such properties because they
  #   would all have empty values...generally undesired)
  # * The "path" is a series of propety names (used as keys in the Hash at each lel)
  #   or array indicies (in the form of @[N]@ where N is the 0-based index).
  # * It is assumed that the value object stored at the property indicated by @path@
  #   is present and the 'value' field there will be examined.
  # * By default the path string is  MongoDB style. (e.g. "path.to.item.[7].score"). But this does
  #   not allow for complex property names with "." itself or "[" or "]", etc. Generally only safe for
  #   internal documents and +unsafe+ for user documents. For user documents, URL escaped paths using
  #   "/" as the delimiter are best! i.e. use @sep='/' and @cgiEscaped=true@
  # @note Path components (property names and indices) _cannot_ have leading or trailing spaces.
  #   If present, they will be stripped off before being examined.
  # @param [String] path The path to the property for which you want the value.
  # @param [Object] value The value to store in the property's 'value' field. _Cannot be @nil@; rather than
  #   storing @nil@, you should just not have the property in the document!
  # @param [String] sep The path element separator. If provided, usually '/' and with @cgiEscaped=true@
  # @param [Boolean] cgiEscaped Indicates whether the path elements are CGI escaped or not. Usually
  #   to be used with @sep='/'@
  # @return [Object, nil] the value stored at the property indicated by @path@
  # @raise [ArgumentError] if @value@ is @nil@, or if the path does not appear to be valid in this document, and specifies
  #   properties that don't actually exist, or property-lists where there is actually a sub-properties Hash, etc.
  def setPropVal(path, value, sep='.', cgiEscaped=false)
    # Sanity check on value
    if(value.nil?)
      raise ArgumentError, "ERROR: This method is for setting the value for a given property. However, value is @nil@ and this method doesn't permit such bad practices. If you want a @nil@ value, the correct approach is for the doc not to have the property at all."
    else
      retVal = setPropField('value', path, value, sep='.', cgiEscaped=false)
    end
    return retVal
  end

  # Set the 'properties' of a property using the "path" to the property in this document.
  # Will automatically add the new final property if it is not present yet; but parent
  #   properties must already exist (will refuse to auto-add such properties because they
  #   would all have empty values...generally undesired)
  # * The "path" is a series of propety names (used as keys in the Hash at each lel)
  #   or array indicies (in the form of @[N]@ where N is the 0-based index).
  # * It is assumed that the value object stored at the property indicated by @path@
  #   is present and the 'value' field there will be examined.
  # * By default the path string is  MongoDB style. (e.g. "path.to.item.[7].score"). But this does
  #   not allow for complex property names with "." itself or "[" or "]", etc. Generally only safe for
  #   internal documents and +unsafe+ for user documents. For user documents, URL escaped paths using
  #   "/" as the delimiter are best! i.e. use @sep='/' and @cgiEscaped=true@
  # @note Path components (property names and indices) _cannot_ have leading or trailing spaces.
  #   If present, they will be stripped off before being examined.
  # @param [Hash] props The properties Hash/sub-document to store in the property's 'properties' field.
  # @param (see #setPropVal)
  # @return [Object, nil] the properties Hash/sub-document stored at the property indicated by @path@
  # @raise [ArgumentError] if @props@ is not a Hash or Hash-like object, or if the path does not appear to be valid in this document, and specifies
  #   properties that don't actually exist, or property-lists where there is actually a sub-properties Hash, etc.
  def setPropProperties(path, props, sep='.', cgiEscaped=false)
    # Sanity check on props
    if(!props.acts_as?(Hash))
      raise ArgumentError, "ERROR: This method is for setting the items hash/map for a given property. Unfortunately, the 'props' argument is a #{items.class} and not a hash/map as expected."
    else
      retVal = setPropField('properties', path, props, sep='.', cgiEscaped=false)
    end
    return retVal
  end

  # Set the 'items' of a property using the "path" to the property in this document.
  # Will automatically add the new final property if it is not present yet; but parent
  #   properties must already exist (will refuse to auto-add such properties because they
  #   would all have empty values...generally undesired)
  # * The "path" is a series of propety names (used as keys in the Hash at each lel)
  #   or array indicies (in the form of @[N]@ where N is the 0-based index).
  # * It is assumed that the value object stored at the property indicated by @path@
  #   is present and the 'value' field there will be examined.
  # * By default the path string is  MongoDB style. (e.g. "path.to.item.[7].score"). But this does
  #   not allow for complex property names with "." itself or "[" or "]", etc. Generally only safe for
  #   internal documents and +unsafe+ for user documents. For user documents, URL escaped paths using
  #   "/" as the delimiter are best! i.e. use @sep='/' and @cgiEscaped=true@
  # @note Path components (property names and indices) _cannot_ have leading or trailing spaces.
  #   If present, they will be stripped off before being examined.
  # @param [Array] items The properties Array/property-list to store in the property's 'items' field.
  # @param (see #setPropVal)
  # @return [Object, nil] the properties Array/property-list stored at the property indicated by @path@
  # @raise [ArgumentError] if items is not an Array or Array-like object, or if the path does not appear to be valid in this document, and specifies
  #   properties that don't actually exist, or property-lists where there is actually a sub-properties Hash, etc.
  def setPropItems(path, items, sep='.', cgiEscaped=false)
    # Sanity check on items
    if(!items.acts_as?(Array))
      raise ArgumentError, "ERROR: This method is for setting the items array/list for a given property. Unfortunately, the 'items' argument is a #{items.class} and not an array/list as expected."
    else
      retVal = setPropField('items', path, items, sep='.', cgiEscaped=false)
    end
    return retVal
  end

  # Delete the 'value' field from the value object of a given property. Not set to nil, but remove the 'value' entry.
  # Useful for fixing up [valueless] properties during manipulation.
  # @param (see #getPropVal)
  # return [Hash, nil] the properties Hash/map for the deleted field or @nil@ if no such property
  #   or it didn't have 'value' field anyway
  def delPropValue(path, sep='.', cgiEscaped=false)
    return delPropField('value', path, sep, cgiEscaped)
  end

  # Delete the 'properties' field (entirely) from the value object of a given property.
  # @param (see #getPropVal)
  # return [Hash, nil] the properties Hash/map for the deleted field or @nil@ if no such property
  #   or it didn't have 'properties' field anyway
  def delPropProperties(path, sep='.', cgiEscaped=false)
    return delPropField('properties', path, sep, cgiEscaped)
  end

  # Delete the 'items' field (entirely) from the value object of a given property.
  # @param (see #getPropVal)
  # return [Hash, nil] the items Array/list for the deleted field or @nil@ if no such property
  #   or it didn't have 'items' field anyway
  def delPropItems(path, sep='.', cgiEscaped=false)
    return delPropField('items', path, sep, cgiEscaped)
  end

  # Delete a sub-property. Must be sub-property and not a property item within an items list.
  #   Removes the indicated property from its parent's 'properties' Hash/map.
  # @param (see #getPropVal)
  # @return [Hash, nil] the deleted sub-property's value object or nil if there was nothing to delete
  # @raise [ArgumentError] if path doesn't indicate a property to be removed, or if it indicates an item
  #   with the parent's 'items' list.
  def delProp(path, sep='.', cgiEscaped=false)
    retVal = nil
    # Parse path
    elems = parsePath(path, sep, cgiEscaped)
    if(elems.empty? or !elems.last.is_a?(String))
      raise ArgumentError, "ERROR: Cannot use #{path.inspect} as a path to the property you want to delete. Last path element must be a string with the name of the property you want to delete."
    end
    # Find parent container object
    begin
      parent = findParent(elems)
    rescue ArgumentError => aerr
      raise ArgumentError, "ERROR: #{aerr.message}"
    end
    # Do appropriate removal of sub-property from parent property
    if(parent == self) # Top-level is a bit different because there is no "properties" key involved.
      if(self.acts_as?(Hash))
        retVal = parent.delete(elems.last)
      else # self delegate object is Array
        raise ArgumentError, "ERROR: cannot use delProp() to remove property items from within a list. Just to remove sub-properties."
      end
    else # not self/top-level # not self/top-level
      # Now get the value of the final property in the path
      if(parent.acts_as?(Hash))
        if(parent['properties'])
          retVal = parent['properties'].delete(elems.last)
        end
      else # Array, i.e. items' value
        raise ArgumentError, "ERROR: cannot use delProp() to remove property items from within a list. Just to remove sub-properties."
      end
    end
    return retVal
  end

  # Adds a new item to the @:beginning@ or @:end@ of a property's 'items' property-list.
  # If the property does not yet have an 'items' Array, it will be added automatically.
  # @note Path components (property names and indices) _cannot_ have leading or trailing spaces.
  #   If present, they will be stripped off before being examined.
  # @param [String] path The path to the property to which you want to add a new sub-item.
  # @param [Hash] item The item to add. Must be a Hash or Hash-like object corresponding to
  #   a property (1 top-level key mapped to a value object Hash which uses the keys @'value'@,
  #   @'properties'@, @'items'@ appropriately)
  # @param (see #setPropVal)
  # @return [Hash] the item you wanted to add to the property's items list.
  # @raise [ArgumentError] if item is not a valid property (singly rooted Hash or Hash-like object whose value appears
  #   to be a valie property value Hash), or if the path does not appear to be valid in this document, and specifies
  #   properties that don't actually exist, or property-lists where there is actually a sub-properties Hash, etc.
  def addPropItem(path, item, pos=:end, sep='.', cgiEscaped=false)
    # Parse path
    elems = parsePath(path, sep, cgiEscaped)
    if( !elems.last.is_a?(String) and !elems.empty?)
      raise ArgumentError, "ERROR: Cannot use #{path.inspect} as a path to the property to which you want to add an item. Last path element must be a string with the name of the property you want to add an item to."
    elsif(pos != :end and pos != :beginning)
      raise ArgumentError, "ERROR: Cannot add item at position #{pos.inspect}. Invalid position. Must be either :end or :beginning to add the item to the end or front of the item list, respectively."
    elsif(!item.acts_as?(Hash) and item.size != 1 and item.first.last.acts_as?(Hash) and !(item.first.last.keys = [ 'value', 'properties', 'items']).empty?)
      raise ArgumentError, "ERROR: Cannot add item because it does not appear to be a valid property Hash (or Hash-like) object with a single top-level key mapped to a property value object which uses only the valid fields 'value', 'properties', 'items'."
    end
    # Find parent container object
    begin
      parent = findParent(elems)
    rescue ArgumentError => aerr
      raise ArgumentError, "ERROR: #{aerr.message}"
    end

    if(parent == self and parent.acts_as?(Array)) # Top-level being array list is special. Doesn't have 'items', it IS the array to add the item to.
      itemsArray = parent
    else # parent is a regular parent property...got dig through its 'items'
      # Get property value object containing the 'items' list we want to add to
      propHash = useParentForSetPropField(parent, elems, 'items')
      if(propHash['items']) # has 'items' field already
        itemsArray = propHash['items']
      else # needs 'items' field...if allowed
        if(propHash['properties'])
          raise ArgumentError, "ERROR: You are trying to add an item to a property that already has sub-properties. Cannot have both sub-properties and items."
        else
          itemsArray = propHash['items'] = []
        end
      end
    end
    # Add item to items array
    if(pos == :end)
      itemsArray.push(item)
    else # pos == :beginning
      itemsArray.unshift(item)
    end
    return item
  end

  # Recursive conversion from {KbDoc} which potentially contains other {KbDoc}s to a
  #   pure Ruby non-KbDoc based version suitable for picky converters like BSON that
  #   don't operate via behavior or duck-typing and which actually check the class
  #   when serializing (i.e. not even overriding {#is_a?} can help you because classes are
  #   specifically checked...probably in the C code of bson_ext).
  # @param [Object] obj The object to serialize. By default, this instance (@self@) but
  #   is called recursively.
  # @return [Hash, Array] the pure Ruby data structure, which ought to be serializable. Note
  #   BSON ONLY serialized hashes...
  def to_serializable(obj=self)
    if(obj.acts_as?(Hash))
      retVal = obj.to_hash
      retVal.each_key { |key| retVal[key] = to_serializable(retVal[key]) }
    elsif(obj.acts_as?(Array))
      retVal = obj.to_a
      retVal.each_index { |ii| retVal[ii] = to_serializable(retVal[ii]) }
    else # regular value, leave alone
      retVal = obj
    end
    return retVal
  end

  # @todo Consider adding a deletePropItem()
  # @todo Consider adding an insertPropItem() to splice in an item to the middle of a list

  # ------------------------------------------------------------------
  # HELPER METHODS
  # - mainly for use by public methods above
  # - but perhaps useful from the outside as well
  # ------------------------------------------------------------------

  # HELPER METHOD (possibly useful outside of this class). Parse a path string into Array of individual elements, casting any
  #   indices to Fixnum and removing any empty elements introducted by leading/trailing separators
  #   (e.g. /top/sub, top/sub/, top.sub.) or consecutive separators (e.g. top..sub) or by
  #   all-blank paths (e.g. top. .sub, top/   /sub).
  # @note Path components (property names and indices) _cannot_ have leading or trailing spaces.
  #   If present, they will be stripped off before being examined.
  # @param [String] path The path to the property for which you want the value.
  # @param [String] sep The path element separator. If provided, usually '/' and with @cgiEscaped=true@
  # @param [Boolean] cgiEscaped Indicates whether the path elements are CGI escaped or not. Usually
  #   to be used with @sep='/'@
  # @return [Array] of the components (properties) of the path.
  def self.parsePath(path, sep='.', cgiEscaped=false)
    # Get the keys from the path
    # Protect escaped . characters from split
    # - restore back as plain . in the items of the split list
    elems = path.gsub(/\\#{sep}/, "\v").split(/#{Regexp.escape(sep)}/).map { |xx| xx.gsub(/\v/, sep) }
    # Collapse any empty paths (e.g. from // or /foo/bar)
    elems.delete('')
    if(cgiEscaped)
      elems.map! { |xx| CGI.unescape(xx).strip }
    else
      elems.map! { |xx| xx.strip }
    end
    elems.map! { |xx| ( (xx =~ /^\[((?:\+|-)?\d+)\]$/) ? $1.to_i : xx ) }
    return elems
  end

  # Split a property path with an item list into three components
  # @param [String] propPath a data document style property path
  # @return [Hash] list components given by the symbols
  #   :pathToLastList [String] propPath before the last item list index
  #   :pathWithinList [String] propPath after the last item list index
  #   :index [Fixnum] the item list index
  def self.rsplitItems(propPath)
    retVal = {}
    idx = propPath.rindex(/(\.\[\d+\])/)
    idxStr = $1
    retVal[:pathToLastList] = (idx ? propPath[0, idx] : nil)
    retVal[:pathWithinList] = (idx ? propPath[idx + idxStr.size + 1, propPath.size] : nil)
    retVal[:index] = (idx ? idxStr.gsub(/\.\[\]/, "").to_i : nil)
    return retVal
  end

  def self.propNameEsc(propName)
    return propName.gsub(/\./, "\\.")
  end

  def propNameEsc(propName)
    return self.class.propNameEsc(propName)
  end

  # @see (KbDoc.parsePath)
  def parsePath(path, sep='.', cgiEscaped=false)
    return self.class.parsePath(path, sep, cgiEscaped)
  end

  # Transform a BRL propPath to a Mongo mongoPath
  # @param [String] propPath a path like "id.item list.[0].item id"
  # @param [Boolean] isValuePath if true, append .value to end of mongoPath
  # @return [String] mongoPath a path like "id.properties.item list.item.0.item id.value"
  def self.propPath2MongoPath(propPath, isValuePath=true)
    rv = nil
    delim = "."
    itemRegex = /^\[(\d+)\]$/ # anchored to avoid this as a component of a property name

    propElems = propPath.split(delim)
    mongoElems = [propElems[0]]
    prevIsItem = false
    propElems[1..-1].each { |propElem|
      if(itemRegex.match(propElem))
        # then this propElem is an item
        mongoElems += ["items", $1]
        prevIsItem = true
      else
        if(prevIsItem)
          # then propElem is root id in an items list
          mongoElems.push(propElem)
        else
          # then propElem is a property
          mongoElems += ["properties", propElem]
        end
        prevIsItem = false
      end
    }
    if(isValuePath)
      mongoElems.push("value")
    end
    rv = mongoElems.join(".")
    return rv
  end

  # ------------------------------------------------------------------
  # INTERNAL HELPER METHODS
  # - mainly for use within this class
  # - unlikely useful outside, but available
  # ------------------------------------------------------------------

  # INTERNAL HELPER METHOD. Find an appropriate 'parent' object in the document, which
  #   will be the parent of the final property in the path components Array provided.
  # @param [Array] elems The path components to consider.
  # @return [Object] A suitable parent object, generally used for getting/setting
  #   stuff in one of its specific sub-properties (the one indicated by the _final_
  #   path component)
  # @raise [ArgumentError] if the path indicates there should be an 'items' array but
  #   there is no array available at that point, or if the path indicates 'properties"
  #   should be available at that point but it is not, or if the path indicates more
  #   (deeper) structure than is actually available in the document.
  def findParent(elems)
    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "elems: #{elems.inspect}")
    curr = self
    unless(elems.empty?) # if empty, it's the root and we're done (esp. when top-level is Array)
      # Go through the elements in the path up to but NOT INCLUDING the final one we're after
      # - After the first, we need to look in the "properties" or "items" keys
      #   to get the next property collection
      elems.lastIndex.times { |ii|
        elem = elems[ii]
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "    +++ next elem: #{elem.inspect}")
        if(ii == (elems.lastIndex - 1))
          # We're at the next-to-last elem in the path (i.e. the parent of
          # the one to add). In that case, we're done traversing the doc structure.
          # Unlike grandparents, the parent need not have 'properties' or 'items' yet
          # because maybe we set the first sub-property or first item right now!
          if(curr.acts_as?(Hash))
            curr = curr[elem]
          else # Array...i.e. items' value
            curr
          end
        else
          if(curr.respond_to?(:'[]'))
            if(elem.is_a?(Fixnum)) # then it's an array index access and we better have an Array to look at currently
              unless(curr.acts_as?(Array))
                raise ArgumentError, "Path has an array index ('#{elem.inspect}') at a position where there is no array in the data structure."
              else
                valueObj = curr[elem]
              end
            else # then it's a regular string key
              unless(curr.acts_as?(Hash))
                raise ArgumentError, "Path has a property key/name ('#{elem.inspect}') at a position where there is no hash in the data structure."
              else
                valueObj = curr[elem]
              end
            end
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "    >>> valueObj: #{valueObj.inspect}")
            # If appropriate, follow either "properties" or "items" of the valueObj to get to the next level
            if(elem.is_a?(Fixnum)) # We have a full propHash, probably from an items list. Don't need to dig out next level since it IS the next level.
              curr = valueObj
            elsif(valueObj and valueObj.respond_to?(:'key?')) # Then have actual valueObj from a property not a full propHash (from items Array)
              # Can only have one or the other for sub-properties or sub-prop lists
              if(valueObj.key?('properties'))
                curr = valueObj['properties']
              elsif(valueObj.key?('items'))
                curr = valueObj['items']
              else # we have more path elements before we get to the parent of the one to add, but have neither 'properties' nor 'items' to go further
                raise ArgumentError, "PATH ERROR TYPE 1: Path #{elems ? elems.join('.') : elems.inspect} specifies a property that is further nested than the data structure. Can't add empty internal properties for you."
              end
            elsif(valueObj.nil?) # No such property
              curr = nil
            else
              raise "ERROR: neither is elem a Fixnum or does valueObj respond to key?()! Bug. elem: #{elem.inspect} ; valueObj: #{valueObj.inspect}"
            end
          else # have key but have reached an object where we can't use []!
            raise ArgumentError, "PATH ERROR TYPE 2: Path #{elems ? elems.join('.') : elems.inspect} specifies a property that is further nested than the data structure. Can't add empty internal properties for you."
          end
        end
      }
      unless(curr)
        raise ArgumentError, "PATH ERROR TYPE 1: Path #{elems ? elems.join('.') : elems.inspect} specifies a property that is further nested than the data structure. Can't automatically add empty internal properties for you."
      end
    end
    return curr
  end

  # INTERNAL HELPER METHOD. Get the value of one of the 3 fields allowed in a property's
  #   value object ('value', 'properties', 'items').
  # @param [String] field Name of the value object field to get. 'value', 'property', or 'items',
  #   or special Symbol :valueObj which returns whole value object hash
  # @param (see #getPropVal)
  # @return [Object, nil] the value at that field for the indicated property, if present.
  # @raise [ArgumentError] if last path component is not a property string, or if field
  #   is not one of the 3 accepted value object fields
  def getPropField(field, path, sep='.', cgiEscaped=false)
    retVal = nil
    unless(field == 'value' or field == 'properties' or field == 'items' or field == :valueObj)
      raise ArgumentError, "ERROR: Can only get valid property fields 'value', 'properties', and 'items'. #{field.inspect} is not valid."
    else
      # Parse path
      elems = parsePath(path, sep, cgiEscaped)
      # Sanity check
      unless(!elems.empty? and elems.last.is_a?(String))
        raise ArgumentError, "ERROR: Cannot use #{path.inspect} as a materialized path for getting the property's #{field.inspect}. Last path element must be a string with the name of the property you want to set the value for."
      else
        # Find parent container object
        begin
          parent = findParent(elems)
        rescue ArgumentError => aerr
          if(@nilGetOnPathError)
            parent = nil
          else
            raise ArgumentError, "ERROR: #{aerr.message}"
          end
        end
        unless(parent.nil?)
          # Get property for which we want to set the value from under parent
          propHash = useParentForGetPropField(parent, elems)
          if(field == :valueObj)
            retVal = propHash
          else
            retVal = propHash[field] rescue nil
          end
        end
      end
    end
    return retVal
  end

  # INTERNAL HELPER METHOD. Set the value of one of the 3 fields allowed in a property's
  #   value object ('value', 'properties', 'items').
  # @param [Object] object The object to save at that field of the property.
  # @param (see #getPropField)
  # @raise [ArgumentError] if last path component is not a property string, or if field
  #   is not one of the 3 accepted value object fields, or if trying to add 'properties'
  #   when 'items' already exists (or vice versa)
  def setPropField(field, path, object, sep='.', cgiEscaped=false)
    unless(field == 'value' or field == 'properties' or field == 'items')
      raise ArgumentError, "ERROR: Can only set valid property fields 'value', 'properties, and 'items'. #{field.inspect} is not valid."
    else
      # Parse path
      elems = parsePath(path, sep, cgiEscaped)
      # Sanity check
      if(elems.empty? or !elems.last.is_a?(String))
        raise ArgumentError, "ERROR: Cannot use #{path.inspect} as a materialized path for setting the property's #{field.inspect}. Last path element must be a string with the name of the property you want to set the #{field.inspect} for."
      else
        # Find parent container object
        begin
          parent = findParent(elems)
        rescue ArgumentError => aerr
          raise ArgumentError, "ERROR: #{aerr.message}"
        end
        propHash = useParentForSetPropField(parent, elems, field)
        if(field == 'properties' and propHash['items'])
          raise ArgumentError, "ERROR: You are trying to add sub-properties to a property that already has 'items'. Cannot have both sub-properties and items."
        elsif(field == 'items' and propHash['properties'])
          raise ArgumentError, "ERROR: You are trying to add items to a property that already has 'properties'. Cannot have both sub-properties and items."
        else
          propHash[field] = object
        end
      end
    end
    return object
  end

  # INTERNAL HELPER METHOD. Removes the 'properties' or the 'items' or the 'value' field
  #   from the value object of a given property.
  # @param [Object] object The object to save at that field of the property.
  # @param (see #getPropField)
  # @raise [ArgumentError] if last path component is not a property string, or if field
  #   is not one of the accepted value object fields
  def delPropField(field, path, sep='.', cgiEscaped=false)
    retVal = nil
    unless(field == 'properties' or field == 'items' or field == 'value')
      raise ArgumentError, "ERROR: Can only delete property fields 'properties' and 'items'. #{field.inspect} is not valid."
    else
      # Parse path
      elems = parsePath(path, sep, cgiEscaped)
      # Sanity check
      unless(!elems.empty? and elems.last.is_a?(String))
        raise ArgumentError, "ERROR: Cannot use #{path.inspect} as a materialized path for deleting a field from the property's #{field.inspect}. Last path element must be a string with the name of the property you want to set the value for."
      else
        # Find parent container object
        begin
          parent = findParent(elems)
        rescue ArgumentError => aerr
          raise ArgumentError, "ERROR: #{aerr.message}"
        end
        # Get propHash we're supposed to remove the field from
        # - note: useParentForGetPropField() will actually work nicely here
        propHash = useParentForGetPropField(parent, elems)
        # Remove the field, if possible
        if(propHash)
          retVal = propHash.delete(field)
        end
      end
    end
    return retVal
  end

  # INTERNAL HELPER METHOD. Use the parent property to get the appropriate property
  #   (last component of @elems@) so some field can be retrieved. Mainly for use
  #   by (#getPropField).
  # @param [Hash, Array] parent The parent property, probably from a (#findParent) call.
  # @param [Array] elems The path elements array, probably from (#parsePath)
  # @return [Hash] the property object (usually the value object Hash) which can be
  #   interrogated using one of the 3 fields, say.
  def useParentForGetPropField(parent, elems)
    retVal = nil
    # Need to handle self/top-level specially
    if(parent == self) # Top-level is a bit different because there is no "properties" key involved.
      if(self.acts_as?(Hash))
        retVal = self[elems.last] rescue nil
      else # self delegate object is Array
        retVal = self[elems[-2]][elems.last] rescue nil
      end
    else # not self/top-level
      # Now get the value of the final property in the path
      if(parent.acts_as?(Hash))
        retVal = parent['properties'][elems.last] rescue nil
      else # Array, i.e. items' value
        retVal = parent[elems[-2]][elems.last] rescue nil
      end
    end
    return retVal
  end

  # INTERNAL HELPER METHOD. Use the parent property to get the appropriate property
  #   (last component of @elems@) so some field can be set. Mainly for use
  #   by (#setPropField). Does NOT set the actual value, just gets the thing
  #   you will set the value ON.
  # @param (see #getPropField)
  # @param [String] field The name of the value object field which we plan on
  #   setting. Mainly needed for some validations. Will not set value at that field.
  # @return [Hash] the property object (usually the value object Hash) which can be
  #   interrogated using one of the 3 fields, say.
  # @raise [ArgumentError] if last path component is not a property string, or if field
  #   is not one of the 3 accepted value object fields, or if there is already a top-level
  #   key for the docuemnt but we're trying to add/update a different one, or if trying to
  #   add sub-properties to a property with 'items' (or vice versa)
  def useParentForSetPropField(parent, elems, field)
    propHash = nil
    unless(field == 'value' or field == 'properties' or field == 'items')
      raise ArgumentError, "ERROR: The field argument must be one of 'value', 'properties, and 'items'. #{field.inspect} is not valid."
    else
      # Use parent to get the property we're after.
      if(parent.acts_as?(Hash))
        # Top-level is a bit different because there is no "properties" key involved.
        if(parent == self)
          if(parent.acts_as?(Hash))
            if(parent.empty?) # needs the top-level key
              propHash = ( parent[elems.last] = {} )
            elsif(parent[elems.last])
              propHash = parent[elems.last]
            else # then top-level key is not one in path! wrong!
              raise ArgumentError, "ERROR: there is already a top-level key for this documents, but it is not #{elems.last}. Documents are single-rooted and can have only 1 top-level key (the doc identfier)."
            end
          end
        else # not top-level
          if(parent.acts_as?(Hash))
            if( ( (field == :value or field == :properties) and parent['items'] ) or
                ( (field == :items and parent['properties']) ) )
              if(field == :value or field == :properties)
                # Being asked to set the value or properties of a sub-property of parent
                # - if parent has items, then it can't have sub-properties and the request is illegal
                raise ArgumentError, "ERROR: You are trying to add sub-properties to a property that already has 'items'. Cannot have both sub-properties and items."
              else # field == :items
                # Begin asked to set the items of a sub-property of parent
                # - if parent has properties, then it can't have items and the request is illegal.
                raise ArgumentError, "ERROR: You are trying to add items to a property that already has sub-properties. Cannot have both sub-properties and items."
              end
            else # no "items", that's good
              if(parent['properties']) # has preperties
                if(parent['properties'][elems.last]) # has sub-property we want to set field for
                  propHash = parent['properties'][elems.last]
                else # needs sub-property we want to set field for
                  propHash = ( parent['properties'][elems.last] = {} )
                end
              else # needs properties
                parent['properties'] = { elems.last => {} }
                propHash = parent['properties'][elems.last]
              end
            end
          end
        end
      else # parent is Array, i.e. items' value (or top-level array)
        if(parent[elems[-2]]) # has something at index where we want to set a field
          if(parent[elems[-2]][elems.last]) # item at index has same top-level key where we want to set a field
            propHash = parent[elems[-2]][elems.last]
          else # item at index doesn't have same top-level key as path indicates!!
            raise ArgumentError, "ERROR: While there is an item at index #{elems[-2].inspect}, the top level key for that item is not #{elems.last}. Is your path correct, according to your model, or perhaps the document got corrupted somehow?"
          end
        else # needs an item at index where we want to set a field
          parent[elems[-2]] = { elems.last => {} }
          propHash = parent[elems[-2]][elems.last]
          parent[elems[-2]].collapse!
        end
      end
    end
    return propHash
  end

  def cleanKeys!(keys)
    keys = [keys] if(!keys.is_a?(Array))
    keys.each { |key|
      self.delete(key)
    }
  end
end
end ; end ; end # module BRL ; module Genboree ; module KB
