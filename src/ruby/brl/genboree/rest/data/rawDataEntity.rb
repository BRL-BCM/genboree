#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/extensions/bson'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data

  # WorkbenchJobEntity - Representation of a job submitted by the workbench
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml       -- default implementations from parent class
  # - #json_create, #getFormatableDataStruct  -- OVERRIDDEN
  class RawDataEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :YAML, :TABBED_PROP_NESTING, :TABBED_PROP_PATH, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :KbDoc

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ ]

    # @return [Object] The Ruby data structure/object to return in the "data" section of the wrapper. Will be converted to JSON by framework...
    attr_accessor :rawDataObj

    # CONSTRUCTOR.
    # @param [Boolean] doRefs NOT SUPPORTED. FOR INTERFACE UNIFORMITY ONLY. Always @false@.
    # @param [Object] rawDataObj The Ruby data structure/object to return in the "data" section of the wrapper. Will be converted to JSON by framework...
    def initialize(doRefs=false, rawDataObj={})
      super(false) # doRefs argument will be ignored
      self.update(rawDataObj)
    end

    # GENBOREE INTERFACE. Delegation-compliant is_a? called "acts_as?()".
    #   Override in sub-classes if the structured data representation is not a Hash or hash-like.
    #   Most entities do use Hash-like structured data representations (except lists, which indeed
    #   override this method, as you can find out for {AbstractEntityList} below).
    def acts_as?(aClass)
      return @doc.acts_as?(aClass)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # @param [Object] rawDataObj The Ruby data structure/object to return in the "data" section of the wrapper. Will be converted to JSON by framework...
    def update(rawDataObj={})
      @rawDataObj = rawDataObj
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes
    # - this data structure will be used in the serialization implementations
    # @return [Hash,Array] A {Hash} or {Array} representing this entity (or collection of entities)
    #   wrapped in the standardized Genboree wrapper, if appropriate. _Entity class specific_
    def getFormatableDataStruct()
      retVal = self.wrap(@rawDataObj)  # Wrap the data content in standard Genboree JSON envelope
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
      # The SIMPLE_FIELD_NAMES first. Values are basic Ruby types.
      data = @rawDataObj
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.from_json method to parse a JSON
    # representation. If the entity is not complex (just has the fields listed in
    # its +SIMPLE_FIELD_NAMES+ +Array+), then the default implementation will make use
    # of the #jsonCreateSimple helper method to do the conversion--no need to override.
    # @param [Hash] parsedJsonResult  The @Hash@ or @Array@ resulting from parsing the JSON string.
    # @return [WorkbenchJobEntity]  Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.from_json(parsedJsonResult)
      # Get content and status info from Common Wrapper if present. If not, content will be parsedJsonResult
      content = AbstractEntity.extractParsedContent(parsedJsonResult)
      self.new(false, content)
      return retVal
    end

    # ------------------------------------------------------------------
    # HELPERS
    # ------------------------------------------------------------------

  end # class
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
