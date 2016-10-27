#!/usr/bin/env ruby
require 'time'
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data

  # DatabaseFileEntity- Representation of a file/document item.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml       -- default implementations from parent class
  # - #getFormatableDataStruct                -- OVERRIDDEN
  class FileEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :DbFile

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "label", "autoArchive", "createdDate", "lastModified", "description", "name", "hide", "modifiedBy", "type", "size", "storageType", "storageHost", "mimeType", "attributes" ]

    attr_accessor :label
    attr_accessor :autoArchive
    attr_accessor :name
    attr_accessor :description
    attr_accessor :name
    # The date for the file item (+String+ as YYYY/MM/DD or YYYY-MM-DD)
    attr_accessor :createdDate
    attr_accessor :lastModified
    attr_accessor :modifiedBy
    attr_accessor :hide
    attr_accessor :type
    attr_accessor :size
    attr_accessor :mimeType
    attr_accessor :storageType
    attr_accessor :storageHost
    # Custom attributes
    attr_accessor :attributes

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    def initialize(doRefs=true, label="", autoArchive="", createdDate="", lastModified="", description="", name="", hide="", modifiedBy="", type="", size="", storageType="", storageHost="", mimeType="", attributes={})
      super(doRefs)
      self.update(label, autoArchive, createdDate, lastModified, description, name, hide, modifiedBy, type, size, storageType, storageHost, mimeType, attributes)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    def update(label, autoArchive, createdDate, lastModified, description, name, hide, modifiedBy, type, size, storageType, storageHost, mimeType, attributes={})
      @refs.clear() if(@refs)
      @label, @autoArchive, @createdDate, @lastModified, @description, @name, @hide, @modifiedBy, @type, @size, @storageType, @storageHost, @mimeType, @attributes = label, autoArchive, createdDate, lastModified, description, name, hide, modifiedBy, type, size, storageType, storageHost, mimeType, attributes
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
                "createdDate" => (@createdDate.respond_to?(:rfc822) ? @createdDate.rfc822 : @createdDate.to_s),
                "lastModified" => (@lastModified.respond_to?(:rfc822) ? @lastModified.rfc822 : @lastModified.to_s),
                "description" => @description,
                "name" => @name,
                "hide" => @hide,
                "modifiedBy" => @modifiedBy,
                "type" => @type,
                "size" => @size,
                "storageType" => @storageType,
                "storageHost" => @storageHost,
                "mimeType" => @mimeType,
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
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "@createdDate: #{@createdDate.inspect} ; @lastModified: #{@lastModified.inspect}")
      # The SIMPLE_FIELD_NAMES first. Values are basic Ruby types (String, Hash, Array, Fixnum, Float, boolean, etc)
      data =
      {
        "label" => @label,
        "autoArchive" => @autoArchive,
        "createdDate" => (@createdDate.respond_to?(:rfc822) ? @createdDate.rfc822 : @createdDate.to_s),   # Should already be a String
        "lastModified" => (@lastModified.respond_to?(:rfc822) ? @lastModified.rfc822 : @lastModified.to_s), # Should already be a String
        "description" => @description,
        "name" => @name,
        "hide" => @hide,
        "modifiedBy" => @modifiedBy,
        "type" => @type,
        "size" => @size,
        "storageType" => @storageType,
        "storageHost" => @storageHost,
        "mimeType" => @mimeType,
        "attributes" => @attributes           # Hash
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end
  end # class DatabaseFileEntity < BRL::Genboree::REST::Data::AbstractEntity

  # DatabaseFileEntityList - A collection/set/lost of files/documents (
  # NOTE: the elements of this list are DatabaseFileEntity objects. Inputs are
  # assumed to correctly be instances of DatabaseFileEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class FileEntityList < EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :DbFileList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = FileEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

  end # class DatabaseFileEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
#!/usr/bin/env ruby
