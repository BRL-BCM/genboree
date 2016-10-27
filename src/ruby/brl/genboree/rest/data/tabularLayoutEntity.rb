#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/rest/data/userEntity'
require 'brl/genboree/rest/data/textEntity'

module BRL ; module Genboree ; module REST ; module Data

  # TabularLayoutEntity - Representation of a saved tabular layout:
  # its name, description, userId, create date, last modification date, and two ordered
  # lists representing the display order of the columns, and the sort order.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml       -- default implementations from parent class
  # - #json_create, #getFormatableDataStruct  -- OVERRIDDEN
  class TabularLayoutEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :TabularLayout

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "name", "description", "userId", "created", "modified", "columns", "sort", "groupMode" ]

    # Name of this layout
    attr_accessor :name
    # Description of this layout
    attr_accessor :description
    # +PartialUserEntity+ object representing the creator of this layout
    attr_reader :userId
    # +Date+ this layout was created on
    attr_reader :created
    # +DateTime+ this layout was last modified by any user
    attr_reader :modified
    # A csv string that contains the columns to be displayed by this layout, in order
    attr_accessor :columns
    # A csv string that contains the sort order of this layout, by descending precedence
    attr_accessor :sort
    # The groupMode of this layout, either "", "terse", or "verbose" (nil || false == "" as well)
    attr_accessor :groupMode

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+name+] [optional; default=""] Layout name
    # [+description+] [optional; default=""] Layout description
    # [+userId+] [optional; default=empty +PartialUserEntity+] +PartialUserEntity+ who created the layout
    # [+created+] [optional; default=current date] +Date+ object for when this layout was created
    # [+modified+] [optional; default=current time] +DateTime+ object for the last time this layout was modified
    # [+columns+] [optional; default=""] The CSV list of the attributes to display as columns
    # [+sort+] [optional; default=""] The CSV list of the attributes to sort by in descending precedence
    # [+groupMode+] [optional; default=""] The group mode of this layout (either nil, "", "terse", or "verbose"
    def initialize(doRefs=true, name="", description="", userId="", created=Date.new(), lastModDate=DateTime.new(), columns="", sort="", groupMode="")
      super(doRefs)
      self.update(name, description, userId, created, lastModDate, columns, sort, groupMode)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+name+] [optional; default=""] Layout name
    # [+description+] [optional; default=""] Layout description
    # [+userId+] [optional; default=empty +PartialUserEntity+] +PartialUserEntity+ who created the layout
    # [+created+] [optional; default=current date] +Date+ object for when this layout was created
    # [+modified+] [optional; default=current time] +DateTime+ object for the last time this layout was modified
    # [+columns+] [optional; default=""] The CSV list of the attributes to display as columns
    # [+sort+] [optional; default=""] The CSV list of the attributes to sort by in descending precedence
    # [+groupMode+] [optional; default=""] The group mode of this layout (either nil, "", "terse", or "verbose"
    def update(name, description, userId, created, modified, columns, sort, groupMode)
      # Clear old values
      @refs.clear() if(@refs)

      # Set class variables to new values
      @name, @description = name, description
      @userId, @created, @modified = userId, created, modified
      @columns, @sort, @groupMode = columns, sort, groupMode
    end

    # Delegate all other methods to @array (eg <<, +, +length+, +each+, etc). This is
    # a standard Ruby method available to all objects. This delagtion to @array is kind a like having this class inherit from Array also.
    # All array inputs are assumed to be instances of the appropriate class.
    # [+meth+]    The name of the method as a +Symbol+ or +String+.
    # [+args+]    All the arguments to the method will be slurped up into this local variable.
    # [+block+]   If there's a code block provided (e.g. for +each+), it will be here.
    # FIXME: Not sure what to "send" to here
    def method_missing(meth, *args, &block)
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.json_create method.
    # This class method defined by the JSON library allows instances of this class
    # to be created from _parsed_ JSON (i.e. a +Hash+ or +Array+ resulting from JSON::parse).
    # The default implemenation just calls AbstractEntity.from_json which is likely fine for almost all subclasses.
    # [+parsedJsonResult+]  The +Hash+ or +Array+ resulting from parsing the JSON string.
    # [+returns+]           Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.json_create(parsedJsonResult)
      retVal = self.jsonCreateSimple(parsedJsonResult, self::SIMPLE_FIELD_NAMES)
      unless(retVal.nil?)
        # Get content and status info from Common Wrapper if present...
        # if not, content will be parsedJsonResult
        content = CommonWrapper.extractParsedContent(parsedJsonResult)
      end
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
                "name" => @name,
                "description" => @description,
                "userId" => @userId,
                "created" => (@created.respond_to?(:rfc822) ? @created.rfc822 : @created.to_s),
                "modified" => (@modified.respond_to?(:rfc822) ? @modified.rfc822 : @modified.to_s),
                "columns" => @columns,
                "sort" => @sort,
                "groupMode" => @groupMode
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
        "description" => @description,
        "userId" => @userId,
        "created" => (@created.respond_to?(:rfc822) ? @created.rfc822 : @created.to_s),          # Should already be a String though
        "modified" => (@modified.respond_to?(:rfc822) ? @modified.rfc822 : @modified.to_s),   # Should already be a String though
        "columns" => @columns,
        "sort" => @sort,
        "groupMode" => @groupMode
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end
  end # class TabularLayoutEntity < BRL::Genboree::REST::Data::AbstractEntity

  # TabularLayoutEntityList - Collection/list containing multiple saved tabular
  # layout objects.
  # NOTE: the elements of the list are TabularLayoutEntity objects. Inputs are
  #   assumed to correctly be instances of TabularLayoutEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class TabularLayoutEntityList < BRL::Genboree::REST::Data::EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :TabularLayoutList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = TabularLayoutEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)
  end # class TabularLayoutEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
