#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data
  # Simple Hash of keys (strings) to values (strings)

  # AttributeValueHash - Object containing a simpe Hash containing strings keyed by attribute name.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class AttributeValueEntityHash < BRL::Genboree::REST::Data::EntityHash
    # Override key class constants used by inherited methods
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :AttrValueHash

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = Object

    # ------------------------------------------------------------------
    # OVERRIDES
    # - Unlike most of API framework, this collection's individual items are not AbstractEntities but just plain
    #   Ruby objects like Strings, Fixnum, Float, etc.
    # - Thus must override certain methods which assume ELEMENT_CLASS is a subclass of AbstractEntity
    # ------------------------------------------------------------------

    # GENBOREE INTERFACE. Import (add) individual entities into this list from *raw data*.
    # For each object in "array" arg, an new instance of this classes' ELEMENT_CLASS will
    # be created and added to the list. Mainly a convenicent method to save typing everywhere.
    # - doRefs for each item will mimic @doRefs for this instance
    def importFromRawData(hashMap)
      hashMap.each_key { |key|
        item = hashMap[key]
        @hashMap[key] = item
      }
      return @hashMap
    end

    # @api RestDataEntity
    # GENBOREE INTERFACE. Subclasses inherit; override for subclasses that generate
    # complex data representations mainly for speed (i.e. to avoid the reflection methods).
    # Inherited version works by using SIMPLE_FIELD_NAMES and reflection methods; even if you
    # just need the stuff in SIMPLE_FIELD_NAMES and don't have fields with complex data structures
    # in the representation, overriding to NOT use the reflection stuff will be faster [a little].
    #
    # Get a {Hash} or {Array} that represents this entity.
    # Generally used to convert to some String format for serialization. Especially to JSON.
    # @note Must ONLY use Ruby primitives (String, Fixnum, Float, booleans) or
    #   basic Ruby collections (Hash, Array). No custom classes.
    # @param [Boolean] wrap Indicating whether the standard Genboree wrapper should be used to
    #   contain the representation or not. Generally true, except when the representation is
    #   within a parent representation [which is likely wrapped].
    # @return [Hash,Array] representing this entity (or collection of entities)
    #   wrapped in the standardized Genboree wrapper, if appropriate.
    def toStructuredData(wrap=@doWrap)
      # The SIMPLE_FIELD_NAMES first. Values are basic Ruby types (String, Hash, Array, Fixnum, Float, boolean, etc)
      data =
      {
        "hash" => @hashMap
      }
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.from_json method to parse a JSON
    # representation. This is overridden here to loop into the +Hash+ of basic Ruby Objects
    # and create instances of their data representation classes, adding each to the collection.
    # [+parsedJsonResult+]  Just a simple Hash, resulting from parsing the json. Use as-is.
    # [+returns+]           Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.from_json(parsedJsonResult)
      # Get content and status info from Common Wrapper if present...ff not, content will be parsedJsonResult
      content = AbstractEntity.extractParsedContent(parsedJsonResult)
      status = AbstractEntity.extractParsedStatus(parsedJsonResult)
      # Create entity based on content, if content is looks correct. Else empty.
      hashMap = {}
      # This type of entity is just {'data'=>{entitiesHash}}. Also, we won't be trying to convert
      # values to some instance of AbstractEntities, since this is supposed be a simple/flat/normal key-value pair hash.
      contentHash = content
      # Look for doRefs (but unlikely)
      doRefs = (contentHash.respond_to?(:'key?') and contentHash.key?("refs"))
      # Create object instance using content
      retVal = self.new(doRefs, contentHash)
      # Set status info from parsedJsonResult, unless data wasn't wrapped in Common Wrapper
      # or status key set to nil or something, in which case default status is used.
      retVal.setStatus(status["statusCode"], status["msg"]) unless(status.nil?)
      return retVal
    end
  end # class AttributeValueDisplayEntityHash < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
