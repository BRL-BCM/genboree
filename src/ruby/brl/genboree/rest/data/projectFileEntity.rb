#!/usr/bin/env ruby
require 'time'
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data

  # ProjectFileEntity- Representation of a file/document item.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml       -- default implementations from parent class
  # - #getFormatableDataStruct                -- OVERRIDDEN
  class ProjectFileEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :PrjFile

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "label", "autoArchive", "archived", "date", "description", "fileName", "hide", "attributes" ]

    attr_accessor :label
    attr_accessor :autoArchive
    attr_accessor :archived
    attr_accessor :description
    attr_accessor :fileName
    # The date for the file item (+String+ as YYYY/MM/DD or YYYY-MM-DD)
    attr_accessor :date
    attr_accessor :hide
    # Custom attributes
    attr_accessor :attributes

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+label+]
    # [+autoArchive+]
    # [+archived+]
    # [+date+]
    # [+description+]
    # [+fileName+]
    def initialize(doRefs=true, label="", autoArchive="", archived="", date="", description="", fileName="", hide="", attributes={})
      super(doRefs)
      self.update(label, autoArchive, archived, date, description, fileName, hide, attributes)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+label+]
    # [+autoArchive+]
    # [+archived+]
    # [+date+] [optional; default=""] The date for the file item (+String+ as YYYY/MM/DD or YYYY-MM-DD)
    # [+description+]
    # [+fileName+]
    def update(label, autoArchive, archived, date, description, fileName, hide, attributes={})
      @refs.clear() if(@refs)
      @label, @autoArchive, @archived, @date, @description, @fileName, @hide, @attributes = label, autoArchive, archived, date, description, fileName, hide, attributes
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
                "label" => @label,
                "autoArchive" => @autoArchive,
                "archived" => @archived,
                "date" => (@date.respond_to?(:rfc822) ? @date.rfc822 : @date.to_s),
                "description" => @description,
                "fileName" => @fileName,
                "hide" => @hide,
                "attributes" => @attributes
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
        "label" => @label,
        "autoArchive" => @autoArchive,
        "archived" => @archived,
        "date" => (@date.respond_to?(:rfc822) ? @date.rfc822 : @date.to_s),            # Should already be a String though
        "description" => @description,
        "fileName" => @fileName,
        "hide" => @hide,
        "attributes" => @attributes     # Hash
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end
  end # class ProjectFileEntity < BRL::Genboree::REST::Data::AbstractEntity

  # ProjectFileEntityList - A collection/set/lost of files/documents (
  # NOTE: the elements of this list are ProjectFileEntity objects. Inputs are
  # assumed to correctly be instances of ProjectFileEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class ProjectFileEntityList < EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :PrjFileList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = ProjectFileEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

  end # class ProjectFileEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
