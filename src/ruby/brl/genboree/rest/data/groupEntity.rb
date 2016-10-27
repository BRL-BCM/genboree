#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data

  # DetailedGroupEntity - Representation of a user group: its name and description
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- OVERRIDDEN
  class DetailedGroupEntity < BRL::Genboree::REST::Data::AbstractEntity
    # Override key class constants used by inherited methods
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :GrpDetailed

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "name", "description" ]

    # Group name.
    attr_accessor :name
    # Group description.
    attr_accessor :description

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+name+] [optional; default=""] Use group name.
    # [+descripiton+] Description of the user group.
    def initialize(doRefs=true, name="", description="")
      super(doRefs)
      self.update(name, description)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+name+] [optional; default=""] Use group name.
    # [+descripiton+] Description of the user group.
    def update(name, description)
      @refs.clear() if(@refs)
      @name, @description = name, description
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
                "name" => @name,
                "description" => @description
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
        "name" => @name,
        "description" => @description
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end
  end # class DetailedGroupEntity < BRL::Genboree::REST::Data::AbstractEntity

  # DetailedGroupEntityList - Object containing an array of DetailedGroupEntity objects.
  # NOTE: the elements of this array are DetailedGroupEntity objects. Inputs are
  # assumed to correctly be instances of TextEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class DetailedGroupEntityList < BRL::Genboree::REST::Data::EntityList
    # Override key class constants used by inherited methods
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :GrpDetailedList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = DetailedGroupEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

  end # class DetailedGroupEntityList < BRL::Genboree::REST::Data::EntityList

  class DetailedGroupEntityWithChildren < AbstractEntity
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ] # no tabbed
    RESOURCE_TYPE = :GrpDetailedWithChildren
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"
    SIMPLE_FIELD_NAMES = [ "name", "description", "children", "isPublic" ]
    # @see #children
    DEFAULT_CHILDREN = {:dbs => [], :kbs => [], :prjs => [], :hubs => [], :redminePrjs => []}
    SIMPLE_FIELD_VALUES = [ nil, "", DEFAULT_CHILDREN, false]

    # @return [String] the name of the group
    attr_accessor :name
    # @return [String] a description for the group
    attr_accessor :description
    # @return [Hash<Symbol, Array<String>] map of child type to children of that type (e.g. :db)
    attr_accessor :children
    # @return [Boolean] true if the group is public or has public children
    attr_accessor :isPublic

    def initialize(doRefs=false, name=nil, description="", children=DEFAULT_CHILDREN, isPublic=false)
      super(doRefs)
      @name = name
      @description = description
      @children = children
      @isPublic = isPublic
    end

    def getFormatableDataStruct()
      retVal = {
        "name" => @name,
        "description" => @description,
        "children" => @children,
        "isPublic" => @isPublic
      }
      retVal["refs"] = @refs if(@refs)
      retVal = wrap(retVal) if(@doWrap)
      return retVal
    end
  end

  class DetailedGroupEntityWithChildrenList < EntityList
    RESOURCE_TYPE = :GrpDetailedWithChildrenList
    FORMATS = DetailedGroupEntityWithChildren::FORMATS
    ELEMENT_CLASS = DetailedGroupEntityWithChildren
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"
  end
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
