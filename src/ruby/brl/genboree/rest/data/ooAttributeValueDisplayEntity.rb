#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data
  # OOAttributeValueDisplayEntity - Object-Oriented track attribute (i.e. single) entity for holding the name, value, & info for
  #                            particular key-value pair. The display information is compatible with AttributeDisplayEntity (and is what
  #                            self.display and self.defaultDisplay are expect to point to). This is for use with heavy-weight attribute
  #                            approaches in which the attributes are stored in an Array of objects of this class. (As opposed to the slightly
  #                            lighter-weigh approach where the attributes are keys which point to instancee of AttributeValueDisplayEntity).
  #
  # Representation Template:
  # {
  #    "name" : "attribute 1",
  #    "value" : "attribute 1 value",
  #    "display" : {
  #      "rank" : 3,
  #      "color" : "#FF0077",
  #      "flags" : ""
  #    }
  # }
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- OVERRIDDEN
  class OOAttributeValueDisplayEntity < BRL::Genboree::REST::Data::AbstractEntity
    # Override key class constants used by inherited methods
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :OOAttrValueDisplay

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "name", "value", "display", "defaultDisplay" ]

    # Attribute name.
    attr_accessor :name
    # Attribute value.
    attr_accessor :value
    # Attribute display object (needs accessors: rank, color, flags). Ideally a AttributeDisplayEntity instance.
    attr_accessor :display
    # Attribute default display object (needs accessors: rank, color, flags). Ideally a AttributeDisplayEntity instance.
    attr_accessor :defaultDisplay

    # CONSTRUCTOR.
    # [+name+] Attribute name
    # [+value+] Attribute value.
    # [+displayEntity+] Attribute display object (needs accessors: rank, color, flags).
    # [+defaultDisplayEntity+] Attribute default display object (needs accessors: rank, color, flags).
    def initialize(doRefs=true, name="", value="", displayEntity=nil, defaultDisplayEntity=nil)
      super(doRefs)
      self.update(name, value, displayEntity, defaultDisplayEntity)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+name+] Attribute name
    # [+value+] Attribute value.
    # [+displayEntity+] Attribute display object (needs accessors: rank, color, flags).
    # [+defaultDisplayEntity+] Attribute default display object (needs accessors: rank, color, flags).
    def update(name, value, displayEntity, defaultDisplayEntity)
      @refs.clear() if(@refs)
      @name, @value, @display, @defaultDisplay = name, value, displayEntity, defaultDisplayEntity
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes
    # - this data structure will be used in the serialization implementations
    # [+returns+] A +Hash+ or +Array+ representing this entity (or collection of entities)
    #             wrapped in the standardized Genboree wrapper, if appropriate.
    #             <i>Entity class specific</i>
    def getFormatableDataStruct()
      # Ensure the two AttributeDisplayEntity instances are not being wrapped in the envelope!
      @display.doWrap = false if(@display)
      @defaultDisplay.doWrap = false if(@defaultDisplay)
      data =  {
                "name" => @name,
                "value" => @value,
                "display" => @display,
                "defaultDisplay" => @defaultDisplay
              }
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
        "name" => @name,
        "value" => @value
      }
      # Fields whose values are AbstractEntity subclass objects, if present
      data['display'] = (@display ? @display.toStructuredData(false) : nil)
      data['defaultDisplay'] = (@defaultDisplay ? @defaultDisplay.toStructuredData(false) : nil)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end
  end # class OOAttributeValueDisplayEntity < BRL::Genboree::REST::Data::AbstractEntity

  # OOAttributeValueDisplayEntityList - Object containing an array of OOAttributeValueDisplayEntity objects.
  # NOTE: the elements of this array are OOAttributeValueDisplayEntity objects.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class OOAttributeValueDisplayEntityList < BRL::Genboree::REST::Data::EntityList
    # Override key class constants used by inherited methods
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :OOAttrValueDisplayList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = OOAttributeValueDisplayEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)
  end # class OOAttributeValueDisplayEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
