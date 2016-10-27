#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data

  # DetailedEntrypointEntity - Representation of an entrypoint/chromosome : its name and length and class.
  # Supports LFF format representation as well as the other usual ones.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml       -- default implementations from parent class
  # - #json_create, #getFormatableDataStruct  -- OVERRIDDEN
  class DetailedEntrypointEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :LFF, :FASTA, :CHR_BAND_PNG ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :EpDetailed

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "name", "length" ]

    # Name of the entrypoint/chromosome
    attr_accessor :name
    # Length of the entrypoint/chromosome
    attr_accessor :length
    # Ckass of the entrypoint/chromosome (usually "Chromosome" but could be something like Scaffold or Contig, etc)
    attr_accessor :entrypointClass
    attr_accessor :dbId

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+name+] [optional; default=""]  Name of the entrypoint/chromosome.
    # [+length+] [optional; default=0] Length of the entrypoint/chromosome
    def initialize(doRefs=true, name="", length=0, entrypointClass="Chromosome", dbId=nil)
      super(doRefs)
      self.update(name, length, entrypointClass, dbId)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+name+] [optional; default=""]  Name of the entrypoint/chromosome.
    # [+length+] [optional; default=0] Length of the entrypoint/chromosome
    def update(name, length, entrypointClass, dbId)
      @refs.clear() if(@refs)
      @name, @length, @entrypointClass, @dbId = name, length, entrypointClass, dbId
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
                "length" => @length,
                "entrypointClass" => @entrypointClass
              }
      data['refs'] = @refs if(@refs)
      data['dbId'] = @dbId if(!@dbId.nil?)
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
        "length" => @length,
        "entrypointClass" => @entrypointClass
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end

    # Special converter for return the chromosomes info in :LFF representation
    # [+returns+] This entrypoint in LFF format, as a +String+
    def to_lff()
      return "#{@name}\t#{@entrypointClass}\t#{@length}"
    end
  end # class DetailedEntrypointEntity < AbstractEntity

  # DetailedEntrypointEntityList - A collection/set/list of entrypoints (instances of DetailedEntrypointEntity)
  # plus a count attribute.
  # - Has _special_ provisions for dealing with "very large number of entrypoints"
  #   for cases where only some (or even none) of the entrypoints are returned but
  #   rather just the count is available for approprate user-presentation.
  # - These provisions mean that any of these can be true:
  #   - <tt>count == entrypoints.length</tt>
  #   - <tt>count > entrypoints.length        # <== entrypoints listed are just some of all those present </tt>
  #   - <tt>count > 0 and entrypoints == nil  # <== there are many entrypoints, none are listed </tt>
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.json_create         -- OVERRIDDEN
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class DetailedEntrypointEntityList < BRL::Genboree::REST::Data::EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :LFF ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :EpDetailedList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = DetailedEntrypointEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

    SIMPLE_FIELD_NAMES = [ "count", "entrypoints" ]

    # Field that contains the DetailedEntrypointEntities
    LIST_FIELD = 'entrypoints'

    # The count of the number of entrypoints
    attr_accessor :count
    # The collectior/list of entrypoints (DetailedEntrypointEntity objects)
    attr_accessor :entrypoints

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+count+] [optional; default=0] The _total_ entrypoint count. May or may not be entrypoints.length (see above)
    # [+entrypoints+] [optional; default=[]] An +Array+ of DetailedEntrypointEntity instances
    def initialize(doRefs=true, count=0, entrypoints=[])
      super(doRefs, entrypoints)
      self.update(count, entrypoints)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+count+] [optional; default=0] The _total_ entrypoint count. May or may not be entrypoints.length (see above)
    # [+entrypoints+] [optional; default=[]] An +Array+ of DetailedEntrypointEntity instances
    def update(count=0, entrypoints=[])
      @entrypoints.clear() unless(@entrypoints.nil?)
      @refs.clear() if(@refs)
      entrypoints = [] if(entrypoints.nil?)
      @count, @entrypoints = count, entrypoints
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes
    # - this data structure will be used in the serialization implementations
    # [+returns+] A +Hash+ or +Array+ representing this entity (or collection of entities)
    #             wrapped in the standardized Genboree wrapper, if appropriate.
    #             <i>Entity class specific</i>
    def getFormatableDataStruct()
      @entrypoints.each { |obj| obj.doWrap = false } # these objects are within an Array, they should NOT each be wrapped
      data =  {
                "count" => @count,
                "entrypoints" => @entrypoints
              }
      retVal = self.wrap(data)
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
        "count" => @count
      }
      # Fields whose values are AbstractEntity subclass objects
      data['entrypoints'] = dataEps = Array.new(@entrypoints.size)
      @entrypoints.each_index { |ii|
        detailedEntrypointEntity = @entrypoints[ii]
        dataEps[ii] = detailedEntrypointEntity.toStructuredData(false)
      }

      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.json_create method.
    # This class method defined by the JSON library allows instances of this class
    # to be created from _parsed-_JSON (i.e. a +Hash+ or +Array+ resulting from JSON::parse).
    # The default implemenation just calls AbstractEntity.from_json which is likely fine for almost all subclasses.
    # [+parsedJsonResult+]  The +Hash+ or +Array+ resulting from parsing the JSON string.
    # [+returns+]           Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.json_create(parsedJsonResult)
      retVal = self.jsonCreateSimple(parsedJsonResult, self::SIMPLE_FIELD_NAMES)
      unless(retVal.nil?)
        # Get content and status info from Common Wrapper if present...ff not, content will be parsedJsonResult
        content = AbstractEntity.extractParsedContent(parsedJsonResult)
        # Create entity based on content, if content is looks correct. Else empty.
        content["entrypoints"].each { |obj| # For each object in the array, convert it to a DetailedEntrypointEntity
          epEntity = DetailedEntrypointEntity.json_create(obj)
          retVal << epEntity unless(epEntity.nil?)
        }
      end
      return retVal
    end

    # Special converter for return the chromosomes info in :LFF representation
    # [+returns+] This entrypoint in LFF format, as a +String+
    def to_lff()
      buff = ""
      @entrypoints.each { |entrypoint|
        buff << entrypoint.to_lff << "\n"
      }
      return buff
    end

    # Delegate all other methods to @array (eg <<, +, +length+, +each+, etc). This is
    # a standard Ruby method available to all objects. This delagtion to @array is kind a like having this class inherit from Array also.
    # NOTE: this collection stores DetailedEntrypointEntity objects. All array
    #       inputs are assumed to be instances of DetailedEntrypointEntity.
    # All array inputs are assumed to be instances of the appropriate class.
    # [+meth+]    The name of the method as a +Symbol+ or +String+.
    # [+args+]    All the arguments to the method will be slurped up into this local variable.
    # [+block+]   If there's a code block provided (e.g. for +each+), it will be here.
    def method_missing(meth, *args, &block)
      @entrypoints.send(meth, *args, &block)
    end
  end # class DetailedEntrypointsEntity < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
