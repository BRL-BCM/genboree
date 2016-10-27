#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/rest/data/userEntity'
require 'brl/genboree/rest/data/textEntity'

module BRL ; module Genboree ; module REST ; module Data

  # QueryableInfoEntity - Representation of queryability of a resource
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - #json_create, #getFormatableDataStruct  -- OVERRIDDEN
  class QueryableInfoEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :QueryableInfo

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "resource", "displayName", "attrs", "queryable","templateURI", "responseFormat" ]

    # +resource+ Name of the resource
    attr_accessor :resource
    # +displayName+ Human readable resource name
    attr_accessor :displayName
    # +Queryable+ boolean reflecting whether the resource is queryable
    attr_accessor :queryable
    # +Attrs+ Core fields of the resource mapped to human-readable names
    attr_accessor :attrs
    # +templateURI+
    attr_accessor :templateURI
    # +responseFormat+
    attr_accessor :responseFormat

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any
    #   representation of this entity (i.e. make connections or save size /
    #   complexity of representation?)
    # [+displayName+] [ default=""]
    # [+resource+] [ default=""]
    # [+queryable+] [ default=false]
    # [+attrs+] [ default=[]]
    # [+templateURI+] [optional; default=""]
    def initialize(doRefs=true, resource="", queryable=false, attrs=[], templateURI="", displayName="", responseFormat="" )
      super(doRefs)
      self.update(resource, queryable, attrs, templateURI, displayName, responseFormat)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of
    #   instances rather than always making new objects
    # TODO
    def update(resource, queryable, attrs, templateURI, displayName, responseFormat)
      # Clear old values
      @refs.clear() if(@refs)
      # Set class variables to new values
      @resource, @queryable, @attrs, @templateURI, @displayName, @responseFormat = resource, queryable, attrs, templateURI, displayName, responseFormat
    end

    # Delegate all other methods to @array (eg <<, +, +length+, +each+, etc).
    # This is a standard Ruby method available to all objects. This delagtion
    # to @array is kind a like having this class inherit from Array also.
    # All array inputs are assumed to be instances of the appropriate class.
    # [+meth+] The name of the method as a +Symbol+ or +String+.
    # [+args+] All the arguments to the method will be slurped up into this local variable.
    # [+block+] If there's a code block provided (e.g. for +each+), it will be here.
    def method_missing(meth, *args, &block)
      @attrs.send(meth, *args, &block)
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.json_create method.
    # This class method defined by the JSON library allows instances of this class
    # to be created from _parsed_ JSON (i.e. a +Hash+ or +Array+ resulting from
    # JSON::parse). The default implemenation just calls AbstractEntity.from_json
    # which is likely fine for almost all subclasses.
    # [+parsedJsonResult+]  The +Hash+ or +Array+ resulting from parsing the JSON string.
    # [+returns+] Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.json_create(parsedJsonResult)
      retVal = self.jsonCreateSimple(parsedJsonResult, self::SIMPLE_FIELD_NAMES)
      return retVal
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes
    # - this data structure will be used in the serialization implementations
    # [+returns+] A +Hash+ or +Array+ representing this entity (or collection of entities)
    #             wrapped in the standardized Genboree wrapper, if appropriate.
    #             <i>Entity class specific</i>
    def getFormatableDataStruct()
      data =  {
                "resource" => @resource,
                "queryable" => @queryable,
                "attrs" => @attrs,                  # Array
                "templateURI" => @templateURI,
                "displayName" => @displayName,
                "responseFormat" => @responseFormat
              }
      data['refs'] = @refs if(@refs)

      retVal = self.wrap(data)  # Wrap the data content in standard Genboree JSON envelope
      return retVal
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
        "resource" => @resource,
        "queryable" => @queryable,
        "attrs" => @attrs,
        "templateURI" => @templateURI,
        "displayName" => @displayName,
        "responseFormat" => @responseFormat
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end
  end # class QueryableInfoEntity < BRL::Genboree::REST::Data::AbstractEntity

  # QueryableInfoEntityList - Collection/list containing multiple QueryableInfoEntities.
  # NOTE: the elements of the list are QueryableInfoEntity objects. Inputs are
  #   assumed to correctly be instances of QueryableInfoEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class QueryableInfoEntityList < BRL::Genboree::REST::Data::EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name
    # friendly) name. This is currently used in generating XML for _lists_...
    # they will be lists of tags of this type (XML makes it hard to express
    # certain natural things easily...)
    RESOURCE_TYPE = :QueryableInfoList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = QueryableInfoEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)
  end # class QueryableInfoEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
