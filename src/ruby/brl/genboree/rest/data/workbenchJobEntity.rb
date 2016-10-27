#!/usr/bin/env ruby
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data

  # WorkbenchJobEntity - Representation of a job submitted by the workbench
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml       -- default implementations from parent class
  # - #json_create, #getFormatableDataStruct  -- OVERRIDDEN
  class WorkbenchJobEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :SUMMARY, :CONFIG ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :WkBnchJb

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "inputs", "outputs", "context", "settings" ]

    # Array of API URI's +Array+
    attr_accessor :inputs
    # Array of API URI's +Array+
    attr_accessor :outputs
    # @return [Hash] containing the context info for this job
    attr_accessor :context
    # @return [Hash] containing the settings info for this job
    attr_accessor :settings
    # @return [Hash] the preconditionSet structured data hash for this job
    attr_accessor :preconditionSet
    # @return [Hash,Array] containing the results data for this job, if it is run on-the-fly and results can formatted to be presented here
    attr_accessor :results

    # CONSTRUCTOR.
    def initialize(doRefs=true, inputs=[], outputs=[], context={}, settings={}, preconditionSet=nil, results=nil)
      super(doRefs)
      @genbConf = @toolIdStr = nil
      self.update(inputs, outputs, context, settings, preconditionSet, results)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+url+] [The url +String+ to represent
    def update(inputs, outputs, context, settings, precondtitions=nil, results=nil)
      @refs.clear() if(@refs)
      @inputs, @outputs, @context, @settings = inputs, outputs, context, settings
      @preconditionSet = preconditionSet
      @results = results
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
                "inputs" => @inputs,
                "outputs" => @outputs,
                "context" => @context,
                "settings" => @settings
              }
      data['preconditionSet'] = @preconditionSet if(@preconditionSet)
      data['results'] = @results if(@results)
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
      # The SIMPLE_FIELD_NAMES first. Values are basic Ruby types.
      data =
      {
        "inputs" => @inputs,      # Array
        "outputs" => @outputs,    # Array
        "context" => @context,    # Hash
        "settings" => @settings   # Hash
      }
      # Add preconditionSet only if available. It's supposed to be just a Hash at this point
      data['preconditionSet'] = @preconditionSet if(@preconditionSet)
      data['results'] = @results if(@results)
      data['refs'] = @refs if(@refs)
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
      retVal = super(parsedJsonResult)
      # Look for optional preconditionSet section
      precondHash = parsedJsonResult['preconditionSet']
      if(precondHash and !precondHash.empty?)
        retVal.preconditionSet = precondHash
      end
      # Look for optional results section
      results = parsedJsonResult['results']
      if(results)
        retVal.results = results
      end
      return retVal
    end

    def getSection(section)
      return case section
              when :inputs        then @inputs
              when :outputs       then @outputs
              when :context       then @context
              when :settings      then @settings
              when :preconditionSet then @preconditionSet
              when :results       then @results
              else raise ArgumentError, "#{__FILE__} : #{__method__ } => '#{section}' is not a valid WorkbenchJobEntity section."
      end
    end

    # Gets a context Hash suitable for Erubis' evaluate().
    # This is superior to using binding() for a number of reasons. Anyway, Erubis
    # will make sure there is an instance variable matching each KEY in the context Hash
    # provided to evaluate(). You can provide named parameters to this method so they
    # will also be exposed.
    # @note If @extraContext@ has the key @:toolIdStr@, this will also set the :toolConf appropriately.
    # @param [Hash{Symbol=>Object},nil] extraContext A {Hash} with any extra keys that should be present in the returned
    #   context {Hash}.
    # @return [Hash{Symbol=>Object}] the context {Hash} containing this job entity's sections and the items in @extraContext@
    def getEvalContext(extraContext=nil)
      retVal = { :inputs => @inputs, :outputs => @outputs, :context => @context, :settings => @settings, :preconditionSet => @preconditionSet, :results => @results }
      unless(extraContext.nil?)
        retVal.merge!(extraContext)
        if(extraContext.key?(:toolIdStr))
          toolConf = BRL::Genboree::Tools::ToolConf.new(extraContext[:toolIdStr])
          retVal[:toolConf] = toolConf
        end
      end
      return retVal
    end
  end # class

  class WorkbenchJobEntityList < BRL::Genboree::REST::Data::EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :WkBnchJbList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = WorkbenchJobEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)
  end # class TextEntityList < BRL::Genboree::REST::Data::EntityList

end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
