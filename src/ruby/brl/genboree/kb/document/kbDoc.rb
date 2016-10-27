require 'cgi'
require 'delegate'

# When instantiated with a Hash or an Array object (the actual doc),
#   this will delegate methods to that object unless overridden below.
#   It will also respond to additional methods added below.
# A sort of "wrapper" around the actual doc object, which can be a Hash (most common) or maybe an Array
# @example Instantiation
#   kbDoc1 = KbDoc.new(aHash)
#   kbDoc2 = KbDoc.new(aArray)
class KbDoc < SimpleDelegator

  # Get a value of a property using the "path" to the property in this document.
  # * The "path" is a series of propety names (used as keys in the Hash at each lel)
  #   or array indicies (in the form of "[N]" where N is the 0-based index).
  # * It is assumed that the value object stored at the property indicated by @path@
  # * By default the path string is  MongoDB style. (e.g. "path.to.item.[7].score"). But this does
  #   not allow for complex property names with spaces or with "." itself, etc. Generally only safe for
  #   internal documents and unsafe for  user documents. For user documents, URL escaped paths using
  #   "/" as the delimiter are best! i.e. use @sep='/' and @cgiEscaped=true@
  #   is a GenboreeKB property value and thus has a "value" key where the actual value is stored.
  # @param [String] path The path to the property for which you want the value.
  # @param [String] sep The path element separator. If provided, usually '/' and with @cgiEscaped=true@
  # @param [Boolean] cgiEscaped Indicated whether the path elements are CGI escaped or not. Usually
  #   to be used with @sep='/'@
  # @return [Object, nil] the value stored at the property indicated by @path@ or @nil@ if no such valid path
  #   or if @nil@ itself is stored there.
  def getValByPath(path, sep='.', cgiEscaped=false)
    return getByPath('value', path, sep, cgiEscaped)
  end

  # @see #getValByPath but this is for the @'properties'@ field rather than @'value'@
  def getPropsByPath(path, sep='.', cgiEscaped=false)
    return getByPath('properties', path, sep, cgiEscaped)
  end

  # @see #getValByPath but this is for the @'items'@ field rather than @'value'@
  def getItemsByPath(path, sep='.', cgiEscaped=false)
    return getByPath('items', path, sep, cgiEscaped)
  end

  # @see #getValByPath but this is to set the value.
  # @param [Object] value The value to store ath the property indicated by @path@
  # @param (see #getValuByPath)
  def setValByPath(value, path, sep='.', cgiEscaped=false)
    return setByPath(value, 'value', path, sep, cgiEscaped)
  end

  # @see #setValByPath but this is to set the sub-properties
  def setPropsByPath(props, sep='.', cgiEscaped=false)
    return setByPath(value, 'properties', sep, cgiEscaped)
  end

  # @see #setValByPath but this is to set the sub-items
  def setItemsByPath(items, sep='.', cgiEscaped=false)
    return setByPath(value, 'items', sep, cgiEscaped)
  end

  # ------------------------------------------------------------------

  # INTERNAL HELPER. Get the content of a value object field (such as @'value'@, @'properties'@, @'items'@)
  #   using the "path" to the property in this document. Used to implement other methods of
  #   this class such as #getValByPath.
  # @param [String] field The field to get from the value object found at property @path@
  # @param [String] path The path to the property for which you want the value.
  # @param [String] sep The path element separator. If provided, usually '/' and with @cgiEscaped=true@
  # @param [Boolean] cgiEscaped Indicated whether the path elements are CGI escaped or not. Usually
  #   to be used with @sep='/'@
  # @return [Object, nil] the value stored at the property indicated by @path@ or @nil@ if no such valid path
  #   or if @nil@ itself is stored there.
  def getByPath(field, path, sep='.', cgiEscaped=false)
    # Get the keys from the path
    elems = path.split(/#{sep}/)
    # Collapse any empty paths (e.g. // or /foo//bar)
    elems.delete('')
    if(cgiEscaped)
      elems.map! { |xx| CGI.unescape(xx).strip }
    else
      elems.map! { |xx| xx.strip }
    end
    # Attempt to get the value using path as a set of keys
    # - If any level of keys doesn't exist or doesn't work, returns nil
    curr = self
    elems.each { |elem|
      if(curr.respond_to?(:'[]'))
        if(elem =~ /^\[(\d+)\]$/) # then it's an array index access
          curr = curr[$1]
        else # then it's a regular string key
          curr = curr[elem]
        end
      else # have key but have reached an object where we can't use []!
        curr = nil
      end
    }
    # Have property mentioned in path. Now want the "value" for it
    if(curr.respond_to?(:'key?') and curr.key?(field))
      retVal = curr[field]
    else # Or we have something that doesn't properly have the 'value' field
      retVal = nil
    end
    return retVal
  end

  # INTERNAL HELPER. Set the content of a value object field (such as @'value'@, @'properties'@, @'items'@)
  #   using the "path" to the property in this document. Used to implement other methods of
  #   this class such as #getValByPath.
  # @param [Object] content The new content to set in @field@ for the property indicated by @path@
  # @param [String] field The field to get from the value object found at property @path@
  # @param [String] path The path to the property for which you want the value.
  # @param [String] sep The path element separator. If provided, usually '/' and with @cgiEscaped=true@
  # @param [Boolean] cgiEscaped Indicated whether the path elements are CGI escaped or not. Usually
  #   to be used with @sep='/'@
  # @return [Object, nil] the value stored at the property indicated by @path@ or @nil@ if no such valid path
  #   or if @nil@ itself is stored there.
  def setByPath(content, field, path, sep='.', cgiEscaped=false)
    # Get the keys from the path
    elems = path.split(/#{sep}/)
    # Collapse any empty paths (e.g. // or /foo//bar)
    elems.delete('')
    if(cgiEscaped)
      elems.map! { |xx| CGI.unescape(xx).strip }
    else
      elems.map! { |xx| xx.strip }
    end
    # Attempt to get the value using path as a set of keys
    # - If any level of keys doesn't exist or doesn't work, returns nil
    curr = self
    elems.each { |elem|
      if(curr.respond_to?(:'[]'))
        if(elem =~ /^\[(\d+)\]$/) # then it's an array index access
          curr = curr[$1]
        else # then it's a regular string key
          curr = curr[elem]
        end
      else # have key but have reached an object where we can't use []!
        curr = nil
      end
    }
    # Have property mentioned in path. Now want the "value" for it
    if(curr.respond_to?(:'key?') and curr.key?(field))
      retVal = curr[field] = content
    else # Or we have something that doesn't properly have the 'value' field
      retVal = nil
    end
    return retVal
  end
end


