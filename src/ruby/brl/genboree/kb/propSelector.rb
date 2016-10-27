#!/usr/local/env ruby
require 'brl/genboree/kb/kbDoc'

module BRL ; module Genboree ; module KB
# class for accessing multple/set of property names, properties, values or items
# of a kb document
# When instantiated with a Hash or an Array object (the actual doc),
#   this will delegate methods to that object unless overridden below.
#   It will also respond to additional methods added below.
# @example Instantiation
#   ps1 = PropSelector.new(aHash)
class PropSelector < Hash

  PROPNAME_SYNTAX = %r{^<.*>$}
  PROPNAME_EMPTY = %r{^<>$}
  PROPNAME_REGEX = %r{^<\/(.+)\/>$}
  PROPNAME_COMMA_SEP = %r{^<("(\S+\s*)+")+([,]("(\S+\s*)+"))*>$}
  ITEM_SYNTAX = %r{^\[.*\]$}
  ITEM_EMPTY = %r{^\[\]$}
  ITEM_COMMA_SEP = %r{^\[(\d+|FIRST|LAST)((,)(\d+|FIRST|LAST))*\]$}
  PROP_BY_VALUE_SYNTAX = %r{^\{(.*)\}$}
  PROP_BY_VALUE_EMPTY = %r{^\{\}$}
  PROP_BY_VALUE_REGEX = %r{^\{\/(.+)\/\}$}
  PROP_BY_VALUE_COMMA_SEP = %r{^\{("(\S+\s*)+")+([,]("(\S+\s*)+"))*\}$}
  #PROP_BY_VALUE_COMMA_SEP = %r{^\{("([^\",])+")+([,]("([^\",])+"))*\}$}

  attr_accessor :messages, :exitCode

  # CONSTRUCTOR. 
  # @param [Array, Hash] obj The object to delegate to.
  # @return [KbDoc]
  # @raise [ArgumentError] if @obj@ is not {Hash} or {Array} or soemthing that acts like these [through delegation]
  def initialize(obj)
    super()
    @exitCode = 0
    unless(obj.nil?)
      if(obj.acts_as?(Hash))
        self.update(obj)
      else
        @exitCode = 20
        raise ArgumentError, "ERROR: Cannot use #{obj.class} objects to instantiate {PropSelector}; if provided, must be an existing {Hash} or something that acts like it."
      end
    end
    @messages = Array.new()
  end

  # Get the 'value' or values of a property using the "path" to the property in this document.
  # The "path" is a series of property names.
  # Property names in the path is either in the form of :
  # @<>@ set of all the property names
  # @</N/>@ property name or names that matches the regexp /N/
  # @<"N">@  or @<"N1","N2">@ exact property name N in double quotes or coma separated names N1 and N2.
  # Property names in the path can also be represented in terms of their values as follows:
  # @N.{}@ property name N with all the values
  # @N.{/v1/}@ property name with the value matching the regexp /v1/
  # @N.{"v1"}@ or @N.{"v1","v2"}@ property name N with values tha exactly match v1, v1 and v2 respectively.
  # Item lists with the array indices in the form of:
  # @[N]@ where N is the 0-based index
  # @[]@ all the 0-based indices
  # @[i1, i2]@ 0-based indices i1 and i2
  # @param [String] path The path to the property for which you want the value.
  # @param [String] sep The path element separator. If provided, usually '/' and with @cgiEscaped=true@
  # @param [Boolean] cgiEscaped Indicates whether the path elements are CGI escaped or not.
  # @return [Array<String>] values stored at the property indicated by @path@ or @[]@ if the final property is not present.
  # @raise [ArgumentError] if the path does not appear to be valid in this document
  def getMultiPropValues(path, unique=false, sep='.', cgiEscaped=false)
    @exitCode = 0
    retVal = getMultiPropField('value', path, sep='.', cgiEscaped)
    retVal.uniq! if(unique)
    return retVal
  end


  # Get 'properties' of one or more property using the "path" to the property in this document.
  # The "path" is a series of property names.
  # Property names in the path is either in the form of :
  # @<>@ set of all the property names
  # @</N/>@ property name or names that matches the regexp /N/
  # @<"N">@  or @<"N1","N2">@ exact property name N in double quotes or coma separated names N1 and N2.
  # Property names in the path can also be represented in terms of their values as follows:
  # @N.{}@ property name N with all the values
  # @N.{/v1/}@ property name with the value matching the regexp /v1/
  # @N.{"v1"}@ or @N.{"v1","v2"}@ property name N with values tha exactly match v1, v1 and v2 respectively.
  # Item lists with the array indices in the form of:
  # @[N]@ where N is the 0-based index
  # @[]@ all the 0-based indices
  # @[i1,i2]@ 0-based indices i1 and i2
  # @param [String] path The path to the property for which you want the value.
  # @param [String] sep The path element separator. If provided, usually '/' and with @cgiEscaped=true@
  # @param [Boolean] cgiEscaped Indicates whether the path elements are CGI escaped or not.
  # @return [Array<Hash>] properties stored at the property indicated by @path@ or @[]@ if the final property is not present.
  # @raise [ArgumentError] if the path does not appear to be valid in this document
  def getMultiPropProperties(path, unique=false, sep='.', cgiEscaped=false)
    @exitCode = 0
    retVal = getMultiPropField('properties', path, sep='.', cgiEscaped)
    retVal.uniq! if(unique)
    return retVal
  end


  # Get 'items' of one or more property using the "path" to the property in this document.
  # The "path" is a series of property names.
  # Property names in the path is either in the form of :
  # @<>@ set of all the property names
  # @</N/>@ property name or names that matches the regexp /N/
  # @<"N">@  or @<"N1","N2">@ exact property name N in double quotes or coma separated names N1 and N2.
  # Property names in the path can also be represented in terms of their values as follows:
  # @N.{}@ property name N with all the values
  # @N.{/v1/}@ property name with the value matching the regexp /v1/
  # @N.{"v1"}@ or @N.{"v1","v2"}@ property name N with values tha exactly match v1, v1 and v2 respectively.
  # Item lists with the array indices in the form of:
  # @[N]@ where N is the 0-based index
  # @[]@ all the 0-based indices
  # @[i1,i2]@ 0-based indices i1 and i2
  # @param [String] path The path to the property for which you want the value.
  # @param [String] sep The path element separator. If provided, usually '/' and with @cgiEscaped=true@
  # @param [Boolean] cgiEscaped Indicates whether the path elements are CGI escaped or not.
  # @return [Array<Hash>] item properties stored at the property indicated by @path@ or @[]@ if the final property is not present.
  # @raise [ArgumentError] if the path does not appear to be valid in this document
  def getMultiPropItems(path, unique=false, sep='.', cgiEscaped=false)
    @exitCode = 0
    retVal = getMultiPropField('items', path, sep='.', cgiEscaped)
    retVal.uniq! if(unique)
    return retVal
  end

  # Gets the list of all the property paths from a complex 'path'
  # Complex path for example is of the form: path.name1.<"name2">.[0,2].name3.{}.name4"
  # @note Path components (property names and indices) _cannot_ have leading or trailing spaces.
  # If present, they will be stripped off before being examined.
  # @param [String] a path to the property of a document
  # @param [String] sep The path element separator. If provided, usually '/' and with @cgiEscaped=true@
  # @param [Boolean] cgiEscaped Indicates whether the path elements are CGI escaped or not.
  # @return [Array<String>] simple property paths
  # @raise [ArgumentError] if the path does not appear to be valid
  def getMultiPropPaths(path, sep='.', cgiEscaped=false)
    @exitCode = 0
    retVal = Array.new()
    elements = parsePropPath(path, sep, cgiEscaped)
    unless(elements.empty?)
      begin
      retVal = getAllPropPaths(elements, true, sep='.')
      rescue => err
        @exitCode = 21
        raise "ERROR: #{err.message}"
      end
    else
      @exitCode = 22
      raise ArgumentError, "ERROR: ELEMENT list is empty. Invalid path '#{path.inspect}'."
    end
    return retVal
  end


  # Gets the object(s) for all the property paths - Hash objects with 'value' and  ('properties' or 'items')
  # @note Object for the leaf properties will have 'value' field only.
  # @param [String] a path to the property of a document
  # @param [String] sep The path element separator. If provided, usually '/' and with @cgiEscaped=true@
  # @param [Boolean] cgiEscaped Indicates whether the path elements are CGI escaped or not.
  # @return [ArgumentError] if the path is broken (depth of the paths should be the same - Ex, <>.<>.<> could be a broken
  # path, if the second subproperty is a leaf property.) or invalid
  def getMultiObj(path, sep='.', stepsUp=0, cgiEscaped=false)
    @exitCode = 0
    retVal = Array.new
    # parse the path
    elements = parsePropPath(path, sep, cgiEscaped)
    # the aliases.
    # path with a terminal [] is same as [].<>
    # so, should get the respective values and properties
    unless(elements.empty?)
      elements << '<>' if(elements.last =~ ITEM_SYNTAX)
      # get all the individual paths
      allPropElements = getAllPropPaths(elements)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "ALLPROPPATHS: #{allPropElements.inspect}")
      kbdoc = BRL::Genboree::KB::KbDoc.new(self)
      allPropElements.each {|propPathElements|
        elems = Array.new()
        valueObj = {}
        propPathElements.pop(stepsUp)
        # use kbdoc instance
        elems = kbdoc.parsePath(propPathElements.join(sep), sep, cgiEscaped)
         #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "elems: #{elems.inspect}")
        unless(elems.empty?)
          begin
            valueObj[elems.last] = {}
            parent = kbdoc.findParent(elems)
         #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "parent: #{parent.inspect}")
          rescue ArgumentError => aerr
            @exitCode = 23
            raise ArgumentError, "ERROR: #{aerr.message}"
          end
          propHash = kbdoc.useParentForGetPropField(parent, elems)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "propHash: #{propHash.inspect}")
          unless(propHash.nil?)
            if(propHash.key?('properties'))
              valueObj[elems.last]['properties'] = propHash['properties']
              valueObj[elems.last]['value'] = propHash['value']
            elsif(propHash.key?('items'))
              valueObj[elems.last]['items'] = propHash['items']
              valueObj[elems.last]['value'] = propHash['value']
            else # reached a leaf.
              # move on with just the 'value' field captured. If no value field for leaf (possible?) return empty Hash
              valueObj[elems.last]['value'] = propHash['value'] if(propHash.key?('value'))
              @messages << "Reached LEAF_NODE: Selector '#{elems.join(sep)}' points to a leaf node. Objects from the 'value' field is returned."
            end
            retVal << valueObj
          end
          
        else
          # Caution!!??, input path was def not empty!! Parsed from kbdoc
          @exitCode = 24
          raise RuntimeError, "Elements list parsed is empty. Should not be!!! Input path is '#{path.inspect}'. Not a valid stepsUp #{stepsUp.inspect}"
        end
      }
    else
      @exitCode = 25
      raise ArgumentError, "INVALID path: Path '#{path.inspect}' seems to be empty or invalid."
    end
    #retVal.flatten!
    return retVal
  end




#############################################
# INTERNAL HELPER METHODS
#############################################


  # INTERNAL HELPER METHOD. Get the set of values of one of the 3 fields allowed in a property's
  #   value object ('value', 'properties', 'items').
  # @param [String] field Name of the value object field to get. 'value', 'property', or 'items'
  # @param [String] a path to the property of a document
  # @param [String] sep The path element separator.
  # @param [Boolean] cgiEscaped Indicates whether the path elements are CGI escaped or not.
  # @return [Array<String, Hash, Array>] the value at that field for the indicated property, if present.
  # @raise [ArgumentError] if last path component is not a property string, or if field
  #   is not one of the 3 accepted value object fields
  def getMultiPropField(field, path, sep='.', cgiEscaped=false)
    retVal = Array.new()
    unless(field == 'value' or field == 'properties' or field == 'items')
      @exitCode = 26
      raise ArgumentError, "ERROR: Can only get valid property fields 'value', 'properties', and 'items'. #{field.inspect} is not valid."
    else
      # parse the path
      elements = parsePropPath(path, sep, cgiEscaped)
      # the aliases.
      # path with a terminal [] is same as [].<>
      # so should get the respective values and properties
      elements << '<>' if(elements.last =~ ITEM_SYNTAX  and (field == 'value' or field == 'properties'))
      unless(elements.empty?)
        begin
          # get all the paths
          # Paths are multiplied based on matching a set of properties by names, item lists, or property values
          allPropElements = getAllPropPaths(elements)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "ALLPROPPATHS: #{allPropElements.inspect}")
          kbdoc = BRL::Genboree::KB::KbDoc.new(self)
          allPropElements.each {|propPathElements|
            elems = Array.new()
            ind = nil
            elems = kbdoc.parsePath(propPathElements.join(sep), sep, cgiEscaped)
            unless(elems.empty?)
              # handle items for root property - not allowed.
              if(elems.size == 1 and elems.first == kbdoc.getRootProp() and field == 'items')
                retVal = []
                @messages << "Property selector '#{path}' is valid. However the root property, '#{elems.first}' cannot have items property. Not allowed."
                break
              end
              #handle the elems separately, the last element in the list could be an item index, '[N]'
              ind = elems.pop() if(field == 'items' and elems.last.is_a?(Integer))
              parent = kbdoc.findParent(elems)
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "PARENT: #{parent.inspect}")
              propHash = kbdoc.useParentForGetPropField(parent, elems)
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "propHash: #{propHash.inspect}")
              if(propHash and propHash.key?(field))
                unless(ind.nil?)
                  retVal << propHash[field][ind]
                else
                  retVal << propHash[field]
                end
              else
                retVal = []
                @exitCode = 27
                raise ArgumentError, "Selector '#{path.inspect}' is invalid. Field '#{field}' not found for the sub document '#{elems.join(sep)}'. Invalid selector for this document model."
              end
            else
              # Caution!!??, input path was def not empty!!
              @exitCode = 28
              raise RuntimeError "Elements list parsed is empty. Should not be!!! Input path was '#{path}'."
            end
          }
        rescue ArgumentError => err
          raise ArgumentError, "ERROR: Failed to get the field property \'#{field}\' for the path '#{path}'. #{err.message}"
        end
      else
        @exitCode = 29
        raise ArgumentError, "INVALID path: #{path.inspect}. Path seems to be empty or invalid"
      end
    end
    #retVal.compact!
    retVal.flatten!
    @messages << "NOT_FOUND: No values found for the property field '#{field}' for the selector '#{path.inspect}'." if(retVal.empty?)
    return retVal
  end

  #INTERNAL HELPER METHOD: parses the path to a list of elements parsed by the 'sep'
  # @param [String] a path to the property of a document
  # @param [String] sep The path element separator.
  # @param [Boolean] cgiEscaped Indicates whether the path elements are CGI escaped or not.
  # @return [Array<String>] elements of the 'path'
  def parsePropPath(path, sep='.', cgiEscaped=false)
    # escape the delimiter within a value selector, if any
    path = path.gsub(/(\{[^\}]+\})/) { |mm| mm.gsub("#{sep}", "\v") } 
    elements = path.gsub(/\\#{Regexp.escape(sep)}/, "\v").split(/#{Regexp.escape(sep)}/).map { |xx| xx.gsub(/\v/, sep) }
    # unescape the regular delimiter (sep) and also if any for the value selector
    if(cgiEscaped)
      elements.map! { |xx| CGI.unescape(xx).strip}
    else
      elements.map! { |xx| xx.strip; xx.gsub(/\\\{/, '{').gsub(/\\\}/, '}') }
    end
    return elements
  end


  #INTERNAL HELPER METHOD: gathers all the individual property paths (elements) for a complex
  # property selector as '<>.<>.{}.[LAST,2,5,FIRST]'
  # @param [Array<String>] elements parsed from a property selector.
  # @param [Boolean] returnPaths returns individual paths if true, else returns elements.
  # @return [Array<Array, String>] elements or paths
  def getAllPropPaths(elements, returnPaths=false, sep='.')
    retVal = Array.new()
    unless(elements.empty?)
      # Check root property, do not proceed if not matched.
      fullKbdoc = self
      kbdoc = BRL::Genboree::KB::KbDoc.new(self)
      allPropElements = Array.new()
      document = Array.new()
      expPaths = Array.new()
      subdocs = Array.new()
      upVal = true
      rootProp = kbdoc.getRootProp()
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "ROOT: #{rootProp.inspect}") 
      if(rootProp == elements.first or elements.first =~ PROPNAME_EMPTY)
        allPropElements << [rootProp]
        document << fullKbdoc[rootProp]
      else
        @exitCode = 30
        raise ArgumentError,"ERROR: RootProperty, '#{elements.first}' of the path does not match to the rootproperty, '#{rootProp}' of the document."
      end
      # starts from the second element.
      # each iteration moves forward through each path element and
      # carries respective updated subdocuments and expanded paths to the next iteration
      elements[1..elements.length].each{ |elem|
        if(elem =~ PROPNAME_SYNTAX)
          expPaths, subdocs = multiElemsByPropNames(allPropElements, document, elem, sep)
        elsif(elem =~ ITEM_SYNTAX )
          expPaths, subdocs = multiElemsByItems(allPropElements, document, elem, sep)
        elsif(elem =~ PROP_BY_VALUE_SYNTAX)
         #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "allPropElements:BEFORE multiElemsByPropVals :::: #{allPropElements.inspect}")
          #upVal = (elements.size-1 == allPropElements.first.size) ?  true : false
         #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "allPropElements:Choose ancestor, move UP!!!!!!!!!!!!") if(upVal)
          allPropElements, document = multiElemsByPropVals(allPropElements, document, elem, sep)
         #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "allPropElements:AFTER multiElemsByPropVals :::: #{allPropElements.inspect}")
        else # is a string, an exact property name, append to each set of element, but after sanity checks
          expPaths, subdocs = multiElemsByPropNames(allPropElements, document, elem, true, sep)
        end
        # update the paths and sub documents for each new path
        # already updated if the elem is PROP_BY_VALUE_SYNTAX. See the method multiElemsByPropVals.
        unless(elem =~ PROP_BY_VALUE_SYNTAX)
          allPropElements, document = updatePathsNDocs(allPropElements, expPaths, subdocs)
        end
        
      }
    end
    if(returnPaths)
      allPropPaths = Array.new()
      allPropElements.each{|elementsList| allPropPaths << elementsList.join(sep)}
      retVal = allPropPaths
    else
      retVal = allPropElements
    end
    return retVal
  end



  # INTERNAL HELPER METHOD: Given an array of array of elements and the next (last) property name
  # this method returns a set of matched property names and the respective sub documents
  # 'PropNamesIdentifier' follows the syntax:
  # @<>@ set of all the property names
  # @</N/>@ property name or names that matches the regexp /N/
  # @<"N">@  or @<"N1","N2">@ exact property name N in double quotes or coma separated names N1 and N2 in double quotes.
  # @param [Array<Array>] listElements list of parsed elements
  # @param [Array<Hash>] kbdocument list of subdocuments
  # @param [String] propNamesIdentifier
  # @param [Boolean] exactPropName true if @propNamesIdentifier@ is a plain property name, for example, 'DocumentID'
  # @param [String] sep The path element separator.
  # @raise [ArgumentError] if @propNamesIdentifier@ fails to follow the syntax mentioned above and if the
  # @return [Array<Array>] retVal list of property names or item indices
  # @return [Array<Hash>] retDoc list of subdocuments for each of the elements in @retVal@
  # selector is invalid.
  def multiElemsByPropNames(listElements, kbdocument, propNamesIdentifier, exactPropName=false, sep='.')
    retVal = []
    retDoc = []
    listElements.each_with_index { |prop, ii|
      docs = []
      propNames = []
      subdoc = kbdocument[ii]
      if(subdoc.is_a?(Array) or subdoc.key?('properties'))
        propNames = subdoc.is_a?(Array) ? subdoc.first.keys() : subdoc['properties'].keys()
        if(propNamesIdentifier =~ PROPNAME_EMPTY) # regexp for "<>" :get all the propNames
          retVal << propNames
          @messages << "Matched properties - '#{propNames.inspect}' for the property name syntax '#{propNamesIdentifier}' under the property path '#{prop.join(sep)}'. " unless(propNames.empty?)
          document = []
          propNames.each {|name|
            document = subdoc.is_a?(Array) ? subdoc.first[name] : subdoc['properties'][name]
            docs << document
          }
          retDoc << docs
        elsif(propNamesIdentifier =~ PROPNAME_REGEX)#Regexp for propNames
          matchedProperties = []
          matchString = $1
          matchedProperties = propNames.map{ |xx| (xx =~ Regexp.new(matchString)) ? xx : nil  }
          matchedProperties.compact!
          if(matchedProperties.empty?)
            #@exitCode = 31
            #raise "ERROR, No property names found to match for the property '#{propNamesIdentifier}' under the path '#{prop.join(sep).inspect}'."
            retVal << [nil]
            retDoc << [nil]
          else
            matchedProperties.each {|name|
              document = subdoc.is_a?(Array) ? subdoc.first[name] : subdoc['properties'][name]
              docs << document
            }
            retVal << matchedProperties
            retDoc << docs
            @messages << "Matched properties '#{matchedProperties.inspect}' for the property name syntax '#{propNamesIdentifier}' under the property path '#{prop.join(sep)}'."
          end
        elsif(propNamesIdentifier =~ PROPNAME_COMMA_SEP) # Comma separated names, get exact match
          propNamesId = propNamesIdentifier.gsub(/<|"|>/, '')
          propHash = {}
          matchedProperties = []
          propNamesId.split(',').each { |nameTomatch| propHash[nameTomatch.strip()] = ''}
          propNames.each{ |propName| matchedProperties << propName if(propHash.key?(propName))}
          if(matchedProperties.empty?) 
            #@exitCode = 32
            #raise "ERROR, No property names found to match for the property '#{propNamesIdentifier}' under the path '#{prop.join(sep).inspect}'."
            retVal << [nil]
            retDoc << [nil]
          else
            matchedProperties.each {|name|
              document = subdoc.is_a?(Array) ? subdoc.first[name] : subdoc['properties'][name]
              docs << document
            }
            retDoc << docs
            retVal << matchedProperties
            @messages << "Matched properties '#{matchedProperties.inspect}' for the property name syntax '#{propNamesIdentifier}' under the property path '#{prop.join(sep)}'."
          end
        elsif(exactPropName) # just the property name
          document = subdoc.is_a?(Array) ? subdoc.first[propNamesIdentifier] : subdoc['properties'][propNamesIdentifier]
          # Error in property name caught here
          if(document.nil?)
            #@exitCode = 33
            #raise ArgumentError, "ERROR, No such property '#{propNamesIdentifier}' under the path '#{prop.join(sep).inspect}'. This is an invalid selector."
            retVal << [nil]
            retDoc << [nil]
          else
            retVal << [propNamesIdentifier]
            retDoc << [document]
          end
        else 
          @exitCode = 34
          raise ArgumentError, "Invalid syntax for property name. Check: '#{propNamesIdentifier.inspect}'. Supported formats for propertyNames are <>, <//> , <\"propName\"> and <\"propName1\",\"propName2\">."
        end
      else
        @exitCode = 35
        raise ArgumentError, "ERROR: Invalid input '#{propNamesIdentifier.inspect}' for the path '#{prop.join(sep)}'. You are either at a leaf node of the document or is an invalid selector for this document model."
      end
    }
     return retVal, retDoc
  end


  # INTERNAL HELPER METHOD: Given an array of array of elements and the next or last element (''PropNamesIdentifier'),
  # this method returns a set of matched property names and the respective sub documents
  # 'PropNamesIdentifier' follows the syntax:
  # @N.{}@ property name N with all the values
  # @N.{/v1/}@ property name with the value matching the regexp /v1/
  # @N.{"v1"}@ or @N.{"v1","v2"}@ property name N with values tha exactly match v1, v1 and v2 respectively.
  # @param [Array<Hash>] kbdocument list of subdocuments
  # @param [String] propNamesIdentifier
  # @param [String] sep the path element separator.
  # @param [Boolean] upVal select a level up the propVal selection or down. Select ancestor or child property
  # @return [Array<Array>] retVal list of property names or item indices
  # @return [Array<Hash>] retDoc list of subdocuments for each of the elements in @retVal@
  # @raise [ArgumentError] if @propNamesIdentifier@ fails to follow the syntax mentioned above and if the
  # selector is invalid.
  def multiElemsByPropVals(listElements, kbdocument, propNamesIdentifier, sep='.', upVal=false)
    retVal = []
    retDoc = []
    if(propNamesIdentifier =~ PROP_BY_VALUE_EMPTY)# is empty, no filtering based on property values required here
      retVal = listElements
      retDoc = kbdocument
      @messages << "Matching all the property names for the property name by value syntax: #{propNamesIdentifier}."
    else # need to filter the path based on property values
      filteredElements = listElements.dup
      filteredsubDocs = kbdocument.dup
      listElements.each_with_index { |prop, ii|
        propValue = kbdocument[ii]['value']
        if(!propValue.nil? and !propValue.empty?)
          if(propNamesIdentifier =~ PROP_BY_VALUE_REGEX)
            filteredElements.delete(prop) and filteredsubDocs.delete(kbdocument[ii]) if(propValue !~ Regexp.new($1))
          else
            escPropNamesIdentifier = propNamesIdentifier.gsub(/\\,/, "\v").gsub(/\\"/, "\a")
            # @todo Replace this with proper code:
            # This is required to process string (propPaths) with double quotations in them
            if (escPropNamesIdentifier =~ PROP_BY_VALUE_COMMA_SEP)
              matchString = escPropNamesIdentifier.gsub(/"|\{|\}/, '')
              propHash = {}
              matchString.split(',').each { |nameTomatch|
                nameTomatch.gsub!(/\v/, ",")
                nameTomatch.gsub!(/\a/, '"')
                propHash[nameTomatch.strip()] = ''
              }
              if(!propHash.key?(propValue))
                filteredElements.delete(prop) and filteredsubDocs.delete(kbdocument[ii])
                @messages << "Property value NOT_FOUND:  '#{propValue}' failed to match for the selector '#{prop.join(sep)}' from the property name syntax '#{propNamesIdentifier}' }"
              else
                @messages << "Property value FOUND: '#{propValue}' MATCHED for the selector '#{prop.join(sep)}' from the property name syntax '#{propNamesIdentifier}'. "
              end
            else
              @exitCode = 36
              raise ArgumentError, "Invalid syntax for matching property names by value. Check: '#{propNamesIdentifier.inspect}'. Supported formats are {}, {/val/}, {\"value\"} and {\"value1\",\"value2\"}."
            end
          end
        else # if propValue is empty, then restrict the selection
          filteredElements.delete(prop)
          filteredsubDocs.delete(kbdocument[ii])
        end
      }
      retVal = filteredElements
      retDoc = filteredsubDocs
    end
    if (upVal and !retVal.empty?)
      retVal.each{|ret| ret.pop()}
    end
    return retVal, retDoc
  end

  # INTERNAL HELPER METHOD: Given an array of elements and the next or last element 
  # this method returns a set of item elements and the respective sub documents
  # 'PropNamesIdentifier' follows the syntax:
  # @[N]@ where N is the 0-based index
  # @[]@ all the 0-based indices
  # @[i1,i2]@ 0-based indices i1 and i2
  # @[FIRST,LAST]@ first and last element of the item list
  # @see PropSelector.multiElemsByPropVals
  def multiElemsByItems(listElements, kbdocument, propNamesIdentifier, sep='.')
    retVal = []
    retDoc = []
    listElements.each_with_index { |prop, jj|
      subdoc = kbdocument[jj]
      itemIndex = []
      docs = []
      if(subdoc.key?('items'))
        items = subdoc['items']
        unless(items.nil?)
          if(propNamesIdentifier =~ ITEM_EMPTY)
            if(items.empty?)
              @messages << "No items found for the itemlist under the prop path '#{prop.join(sep)}' for the item list syntax '#{propNamesIdentifier}'."
            else
              items.each_index { |ii| itemIndex << "[#{ii}]" and docs << [items[ii]] }
              @messages << "#{items.size} number of items found for the itemlist under the prop path '#{prop.join(sep)}' for the item list syntax '#{propNamesIdentifier}'."
            end
            retVal << itemIndex
            retDoc << docs
          elsif(propNamesIdentifier =~ ITEM_COMMA_SEP)
            matchIndex = propNamesIdentifier.gsub(/\[|\]/, '').split(',').map {|xx| xx = (xx =~/FIRST|LAST/) ? xx : xx.to_i}
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "MatchIndex: #{matchIndex.inspect}")
            matchIndex.each {|ii|
              # Handle FIRST and LAST keywords
              ii = (ii == 'FIRST') ? 0 : ii
              ii = (ii == 'LAST') ? items.size() - 1  : ii
              unless(items[ii].nil?)
                itemIndex << "[#{ii}]"
                docs << [items[ii]]
              else
                @exitCode = 37
                raise ArgumentError, "Item has no element for index #{ii}. INVALID Index entries for #{propNamesIdentifier} under the path '#{prop.join(sep)}'."
              end
            }
            retVal << itemIndex
            retDoc << docs
          else
            @exitCode = 38
            raise ArgumentError, "Invalid syntax for item list. Check: '#{propNamesIdentifier.inspect}'. Supported formats for item lists are [], [{index}] and [{index1},{FIRST},{index3},{LAST}]"
          end
        else
          @exitCode = 39
          raise ArgumentError, "Items field has no entries under the path: #{prop.join(sep).inspect}."
        end
      else
        @exitCode = 40
        raise ArgumentError, "ERROR, path '#{prop.join(sep)}' has no 'items' field. Invalid selector for this document model."
      end
    }
    return retVal, retDoc
  end

  def updatePathsNDocs(allPropElements, expPaths, subdocs)
    newsubdocs = []
    newPaths = []
    # update
    allPropElements.each_with_index{ |prop, ii|
      expPaths[ii].each_with_index { |newName, jj|
        unless(newName.nil?)
          tmp = Marshal.load(Marshal.dump(prop))
          tmp << newName
          newPaths << tmp
          newsubdocs << subdocs[ii][jj]
        end
      }
    }
    return newPaths, newsubdocs
  end


  # get PropNames for the property path "path"
  # @param [String] path to the property of a document
  # @param [Boolean] unique true if only unique property names are to be returned
  # @param [String] sep the path element separator.
  # @param [Boolean] cgiEscaped Indicates whether the path elements are CGI escaped or not.
  # @return [Array<String>] retVal list of property names
  # incomplete and not ready to be used!!!!
  def getMultiPropNames(path, unique=false, sep='.', cgiEscaped=false)
    retVal = Array.new()
    kbdoc = BRL::Genboree::KB::KbDoc.new(self)
    begin
      elements = parsePropPath(path, sep, cgiEscaped)
      # the aliases.
      # path with a terminal [] is same as [].<>
      # so should get the respective values and properties
      path << '.<>' if(elements.last =~ ITEM_SYNTAX)
      allPaths = getMultiPropPaths(path, sep, cgiEscaped)
        allPaths.each {|propPath|
          elems = kbdoc.parsePath(propPath, sep, cgiEscaped)
          retVal << elems.last
        }
    rescue => err
      @exitCode = 41
      raise "Failed to get the property names for the path '#{path.inspect}'. #{err.message}"
    end
    retVal.uniq! if(unique)
    return retVal
  end


end
end; end; end # module BRL ; module Genboree ; module KB
