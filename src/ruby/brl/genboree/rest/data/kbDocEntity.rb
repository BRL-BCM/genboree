#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/extensions/bson'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/converters/nestedTabbedDocConverter'
require 'brl/genboree/kb/converters/nestedTabbedModelConverter'
require 'brl/genboree/kb/producers/nestedTabbedModelProducer'
require 'brl/genboree/kb/producers/nestedTabbedDocProducer'
require 'brl/genboree/kb/producers/fullPathTabbedModelProducer'
require 'brl/genboree/kb/producers/fullPathTabbedDocProducer'

module BRL ; module Genboree ; module REST ; module Data

  # WorkbenchJobEntity - Representation of a job submitted by the workbench
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml       -- default implementations from parent class
  # - #json_create, #getFormatableDataStruct  -- OVERRIDDEN
  class KbDocEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :YAML, :TABBED_PROP_NESTING, :TABBED_PROP_PATH, :TABBED, :TABBED_MULTI_PROP_NESTING]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :KbDoc

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "doc" ]

    # @return [Hash, BRL::Genboree::KB::KbDoc, BSON::OrderedHash] The GenboreeKB document, whatever kind it is (data doc or collection model)
    attr_accessor :doc
    # @return [BRL::Genboree::KB::KbDoc] A model to use to help produce the doc IF needed
    attr_accessor :model
    attr_accessor :haveErrors
    attr_accessor :docType

    # CONSTRUCTOR.
    # @param [Boolean] doRefs NOT SUPPORTED. FOR INTERFACE UNIFORMITY ONLY. Always @false@.
    # @param [Hash, BRL::Genboree::KB::KbDoc, BSON::OrderedHash] doc The Genboree KB document to be represented.
    def initialize(doRefs=false, doc={}, doWrap=true)
      super(false, doWrap) # doRefs argument will be ignored
      @haveErrors = nil
      self.update(doc)
    end

    # GENBOREE INTERFACE. Delegation-compliant is_a? called "acts_as?()".
    #   Override in sub-classes if the structured data representation is not a Hash or hash-like.
    #   Most entities do use Hash-like structured data representations (except lists, which indeed
    #   override this method, as you can find out for {AbstractEntityList} below).
    def acts_as?(aClass)
      return @doc.acts_as?(aClass)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # @param [Hash, BRL::Genboree::KB::KbDoc, BSON::OrderedHash] doc The Genboree KB document to be represented.
    # @return [Hash, BRL::Genboree::KB::KbDoc, BSON::OrderedHash] The Genboree KB document to be represented.
    def update(doc={})
      deletedId = doc.delete("_id")
      deletedId = doc.delete(:_id) if(deletedId.nil?)
      @doc = doc
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes
    # - this data structure will be used in the serialization implementations
    # @note May need to check and remove keys added by MongoDB like "_id" or similar.
    # @return [Hash,Array] A {Hash} or {Array} representing this entity (or collection of entities)
    #   wrapped in the standardized Genboree wrapper, if appropriate. _Entity class specific_
    def getFormatableDataStruct()
      # @doc IS a formattable data structure already.
      # @todo May need to check and remove keys added by MongoDB like "_id" or similar.
      data = @doc
      if(data.acts_as?(Hash))
        data.delete('_id')
        data.delete(:_id)
      end
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
      #data = @doc.deep_clone
      data = @doc
      if(data.acts_as?(Hash))
        data.delete('_id')
        data.delete(:_id)
      end
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
      if(content.acts_as?(Hash) and !content.empty?)
        retVal = self.new(false, content)
      else
        retVal = :'Unsupported Media Type'
      end
      return retVal
    end

    # TABBED INTERFACE. This is currently just a place holder, as it can't
    #   really do anything outside of specific entities.  This method must be
    #   overridden by subclasses with an actual implementation in order to
    #   support creation from a tab-delimited string.
    # @param [String] data A multi-line string with tab-delimited data to be parsed.  Must contain a header
    #   line (line beginning with first non-whitespace character of "#")
    # @param [Hash] opts Extra info about which exact tabbed format it is, what kind
    #   of GenboreeKB doc (data doc or collection model) is represented, and things like
    #   the collection model (for parsing doc representations only) etc are provided here via:
    #   * @:format@   - Either @:TABBED@ (same as @:TABBED_PROP_PATH@) or @:TABBED_PROP_NESTING@
    #   * @:docType@  - Either @:model@ or @:data@
    #   * @:model@    - [NOT CURRENTLY USED OR REQUIRED] A model (a {BRL::Genboree::KB::KbDoc}) to use in interpreting the data doc
    #     representation. Needed for data doc representations but not, obviously, for model representations.
    # @return Always returns @nil@ by default, but real implementations in subclasses return some
    #   kind of {BRL::Genboree::REST::Data::AbstractEntity} subclass.
    def self.from_tabbed(data, opts={})
      retVal = nil
      formatSym = ( opts[:format]   or (raise ArgumentError, "ERROR: Must provide the specific format type via a :format=>Symbol named argument.") )
      docType   = ( opts[:docType]  or (raise ArgumentError, "ERROR: Must provide the type of document in the representation via a :docType=>Symbol named argument (:data or :model).") )
      # NOTE: if, in the future, having the collection model becomes necessary for
      #   converting tabbed data docs to JSON data docs, then :model should be required and verified as follows
      #   and used in downstream methods:
      ##model = opts[:model]
      ##if(docType == :data and ( model.nil? or !model.acts_as?(Hash) or model.empty? ))
      ##  raise ArgumentError, "ERROR: :docType indicates this is a data document, but no model was supplied via :model=>KbDoc named argument to help interpret the model."
      ##end
      # Arrange parsing
      begin
        if(formatSym == :TABBED or formatSym == :TABBED_PROP_PATH)
          retVal = self.from_tabbedPropPath(data, opts)
        elsif(formatSym == :TABBED_PROP_NESTING)
          retVal = self.from_tabbedNesting(data, opts)
        else
          @serialized = AbstractEntity.representError(formatSym, retVal, "NOT_IMPLEMENTED: This resource cannot be provided in the format #{formatSym}")
          raise BRL::Genboree::GenboreeError.new(:'Not Implemented', '', nil, true)
        end
        ###################
        # The commented-out code below doesn't seem to be required as the individual parsing methods each return something
        # Also @haveErrors seem to be poorly used (use of an instance variable inside a class method??)
        # As long as this method returns either a parsed object or an Genboree error instance, we are fine
        ###################
        # Any errors from specific parsing methods?
        #if(@haveErrors)
        #  retVal = @haveErrors
        #  @serialized = AbstractEntity.representError(formatSym, retVal, "INTERNAL_ERROR: #{@serialized}")
        #end
      rescue => err
        @serialized = "FATAL: Due to an unexpected error, failed to represent this resource as #{formatSym}"
        BRL::Genboree::GenboreeUtil.logError(@serialized, err, formatSym)
        raise BRL::Genboree::GenboreeError.new(:'Internal Server Error', '', nil, true)
      end
      return retVal
    end

    def self.from_tabbedNesting(data, opts)
      docType = opts[:docType].to_sym
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "opts:\n\n#{opts.inspect}")
      # Create converter
      if(docType == :data)
        converter = BRL::Genboree::KB::Converters::NestedTabbedDocConverter.new()
      else # :model
        converter = BRL::Genboree::KB::Converters::NestedTabbedModelConverter.new()
      end
      return self.from_tabbedViaConverter(data, opts, converter)
    end

    # @todo: Implement the classes used in the method
    def self.from_tabbedPropPath(data, opts)
      docType = opts[:docType].to_sym
      # Create converter
      if(docType == :data)
        converter = BRL::Genboree::KB::Converters::FullPathTabbedDocConverter.new()
      else # :model
        converter = BRL::Genboree::KB::Converters::FullPathTabbedModelConverter.new()
      end
      return self.from_tabbedViaConverter(data, opts, converter)
    end

    def self.from_tabbedViaConverter(data, opts, converter)
      asObj = converter.parse(data) # Note that converter.convert(doc) would return it as JSON string
      # Check errors
      if(converter.errors.nil? or converter.errors.empty?)
        retVal = BRL::Genboree::REST::Data::KbDocEntity.new(false, asObj)
      else
        errMsg = "ERRORS: could not parse the tabbed format provided. "
        if(!converter.errors.is_a?(Hash))
          errMsg << "This was due to an internal server error in code that failed to detect problematic tabbed formatting or has a bug in dealing with this particular (but valid) input."
        else # errors should have info
          errMsg << "The converter encountered these errors in the input:\n"
          converter.errors.keys.sort.each { |lineno|
            errMsg << "## Line #{lineno} => #{converter.errors[lineno]}\n"
          }
        end
        retVal = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "There was an error parsing the request body, please check the format and entity type. Specifics: #{errMsg}", nil, true)
      end
      return retVal
    end

    # GENBOREE INTERFACE. Serialize resource to a supported format.
    # Not commonly overridden in subclasses except in special cases; default implementation
    # calls appropriate conversion methods.
    # @param [Symbol] formatSym Stringify/serialize this entity as this format.
    # @return [Symbol] Status {Symbol} (@:OK@ for success or other for error)
    def serialize(formatSym)
      retVal = :OK
      begin
        if(self.class::FORMATS.include?(formatSym))
          @serialized = if(formatSym == :TABBED or formatSym == :TABBED_PROP_PATH)
                          to_tabbedPropPath()
                        elsif(formatSym == :TABBED_PROP_NESTING or formatSym == :TABBED_MULTI_PROP_NESTING)
                          to_tabbedNesting()
                        else
                          super(formatSym)
                          @serialized
                        end
          if(@haveErrors)
            retVal = @haveErrors
            @serialized = AbstractEntity.representError(formatSym, retVal, "INTERNAL_ERROR: #{@serialized}")
          end
        else
          retVal = :'Not Implemented'
          @serialized = AbstractEntity.representError(formatSym, retVal, "NOT_IMPLEMENTED: This resource cannot be represented in the format #{formatSym}")
        end
      rescue => err
        @serialized = "FATAL: Due to an unexpected error, failed to represent this resource as #{formatSym}"
        retVal = :'Internal Server Error'
        BRL::Genboree::GenboreeUtil.logError(@serialized, err, formatSym)
      end
      return retVal
    end

    def to_tabbedNesting()
      if(@model) # then data doc requested, and to use @model to help produce data doc
        producer = BRL::Genboree::KB::Producers::NestedTabbedDocProducer.new(@model)
      else # no @model because model doc was one requested
        producer = BRL::Genboree::KB::Producers::NestedTabbedModelProducer.new()
      end
      return to_tabbedViaProducer(producer)
    end

    def to_tabbedPropPath()
      if(@model) # then data doc requested, and to use @model to help produce data doc
        producer = BRL::Genboree::KB::Producers::FullPathTabbedDocProducer.new(@model)
      else # no @model because model doc was one requested
        producer = BRL::Genboree::KB::Producers::FullPathTabbedModelProducer.new()
      end
      return to_tabbedViaProducer(producer)
    end

    def to_tabbedViaProducer(producer)
      # Calling without a block returns an Array of lines (else with a block that is yielded each line)
      lines = producer.produce(@doc)
      # If everything is ok, modelProducer.errors should be empty Hash
      if(producer.errors and producer.errors.empty?)
        retVal = lines.join("\n")
      else # errors
        @haveErrors = :'Expectation Failed'
        retVal = "## ERROR(S) ENCOUNTERED DUMPING DOC IN TABBED FORMAT WITH PROP NESTING INDICATORS\n## - Error message(s) follow:\n\n"
        producer.errors.keys.sort.each { |lineno|
          retVal << "## Line #{lineno} => #{producer.errors[lineno]}\n"
        }
      end
      return retVal
    end

    # ------------------------------------------------------------------
    # HELPERS
    # ------------------------------------------------------------------

    def separatorLines()
      retVal = "## #{'-'*72}\n"
      if(@doc.acts_as?(Hash))
        @doc.delete('_id')
        @doc.delete(:id)
        if(@model) # have model to work with, so this must be for a data doc
          # Work with a KbDoc
          if(@doc.is_a?(BRL::Genboree::KB::KbDoc))
            kbDoc = @doc
          else
            kbDoc = BRL::Genboree::KB::KbDoc.new(@doc)
          end
          retVal << "## DOC ID: #{kbDoc.getRootPropVal()}\n"
          retVal << "## #{'-'*72}\n"
        end
      end
      return retVal
    end

  end # class

  class KbDocEntityList < BRL::Genboree::REST::Data::EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :YAML, :TABBED_PROP_NESTING, :TABBED_PROP_PATH, :TABBED, :TABBED_MULTI_PROP_NESTING]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :KbDocList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = KbDocEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

    # @return [BRL::Genboree::KB::KbDoc] A model to use to help produce the doc IF needed
    attr_accessor :model
    attr_accessor :haveErrors

    # Constructor. Matching GENBOREE INTERFACE.
    # [+doRefs+]      [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+array+]       [optional; default=[]] +Array+ of individual data structures going into this collection. They can be added later if not provided to the constructor.
    def initialize(doRefs=true, array=[])
      super(doRefs, array)
      @haveErrors = nil
    end

    # GENBOREE INTERFACE. Serialize resource to a supported format.
    # Not commonly overridden in subclasses except in special cases; default implementation
    # calls appropriate conversion methods.
    # @param [Symbol] formatSym Stringify/serialize this entity as this format.
    # @return [Symbol] Status {Symbol} (@:OK@ for success or other for error)
    def serialize(formatSym)
      retVal = :OK
      begin
        if(self.class::FORMATS.include?(formatSym))
          @serialized = if(formatSym == :TABBED or formatSym == :TABBED_PROP_PATH)
                          to_tabbedPropPath()
                        elsif(formatSym == :TABBED_PROP_NESTING)
                          to_tabbedNesting()
                        else
                          super(formatSym)
                          @serialized
                        end
          if(@haveErrors)
            retVal = @haveErrors
            @serialized = AbstractEntity.representError(formatSym, retVal, @serialized)
          end
        else
          retVal = :'Not Implemented'
          @serialized = AbstractEntity.representError(formatSym, retVal, "NOT_IMPLEMENTED: This resource cannot be represented in the format #{formatSym}")
        end
      rescue => err
        @serialized = "FATAL: Due to an unexpected error, failed to represent this resource as #{formatSym}"
        retVal = :'Internal Server Error'
        BRL::Genboree::GenboreeUtil.logError(@serialized, err, formatSym)
      end
      return retVal
    end

    def to_tabbedNesting()
      retVal = ''
      self.each { |docEntity|
        # Make sure doc entity has model if needed
        if(@model)
          docEntity.model = @model
        end
        # Add doc separator lines
        retVal << docEntity.separatorLines()
        # Add tabbed representation of the doc
        docRep = docEntity.to_tabbedNesting()
        if(docEntity.haveErrors)
          @haveErrors = docEntity.haveErrors
          retVal = docRep
          break
        else
          # Doc rep is ok
          retVal << docRep
          # Add blank line between recs.
          retVal << "\n\n"
        end
      }
      return retVal
    end

    def to_tabbedPropPath()
      retVal = ''
      self.each { |docEntity|
        # Make sure doc entity has model if needed
        if(@model)
          docEntity.model = @model
        end
        # Add doc separator lines
        retVal << docEntity.separatorLines()
        # Add tabbed representation of the doc
        docRep = docEntity.to_tabbedPropPath()
        if(docEntity.haveErrors)
          @haveErrors = docEntity.haveErrors
          retVal = docRep
          break
        else
          # Doc rep is ok
          retVal << docRep
          # Add blank line between recs.
          retVal << "\n\n"
        end
      }
      return retVal
    end

    # List version of the from_tabbed method.
    # Goes through the payload line by line and calls the from_tabbed method of the Singleton version of the class for one document worth of data at a time
    # @param [String] data A multi-line string with tab-delimited data to be parsed.  Must contain a header
    #   line (line beginning with first non-whitespace character of "#")
    # @param [Hash] opts Extra info about which exact tabbed format it is, what kind
    #   of GenboreeKB doc (data doc or collection model) is represented, and things like
    #   the collection model (for parsing doc representations only) etc are provided here via:
    #   * @:format@   - Either @:TABBED@ (same as @:TABBED_PROP_PATH@) or @:TABBED_PROP_NESTING@
    #   * @:docType@  - Either @:model@ or @:data@
    #   * @:model@    - [NOT CURRENTLY USED OR REQUIRED] A model (a {BRL::Genboree::KB::KbDoc}) to use in interpreting the data doc
    #     representation. Needed for data doc representations but not, obviously, for model representations.
    # @return Always returns @nil@ by default, but real implementations in subclasses return some
    #   kind of {BRL::Genboree::REST::Data::AbstractEntity} subclass.
    def self.from_tabbed(data, opts={})
      retVal = nil
      formatSym = ( opts[:format]   or (raise ArgumentError, "ERROR: Must provide the specific format type via a :format=>Symbol named argument.") )
      docType   = ( opts[:docType]  or (raise ArgumentError, "ERROR: Must provide the type of document in the representation via a :docType=>Symbol named argument (:data or :model).") )
      # NOTE: if, in the future, having the collection model becomes necessary for
      #   converting tabbed data docs to JSON data docs, then :model should be required and verified as follows
      #   and used in downstream methods:
      ##model = opts[:model]
      ##if(docType == :data and ( model.nil? or !model.acts_as?(Hash) or model.empty? ))
      ##  raise ArgumentError, "ERROR: :docType indicates this is a data document, but no model was supplied via :model=>KbDoc named argument to help interpret the model."
      ##end
      # Arrange parsing 
      begin
        if(formatSym != :TABBED_MULTI_PROP_NESTING)
          # Loop over the payload and extract the documents one by one
          headerFound = false
          docBuff = ""
          dataLinesStarted = false
          docObjs = self.new(false)
          index = 1
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "data:\n#{data.inspect}")
          data.each_line { |line|
            next if(line !~ /\S/)
            if(line =~ /^#/)
              headerFound = true
              if(dataLinesStarted)
                entity = self.makeDocObj(formatSym, docBuff, opts)
                if(entity.is_a?(BRL::Genboree::GenboreeError))
                  raise entity
                else
                  docObjs << entity
                end
                index += 1
                dataLinesStarted = false
                docBuff = ""
              end
              docBuff << line
            else
              dataLinesStarted = true
              # Really only works for the first document. Since there may be only one large in the document
              unless(headerFound)
                raise BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "No header for document at index (starting from 1): #{index}", nil, true)
              else
                docBuff << line
              end
            end
          }
          if(!docBuff.empty?)
            entity = self.makeDocObj(formatSym, docBuff, opts)
            if(entity.is_a?(BRL::Genboree::GenboreeError))
              raise entity
            else
              docObjs << entity
            end
          end
          retVal = docObjs
          docBuff = ""
        else
          docObjs = self.new(false)
          converter = BRL::Genboree::KB::Converters::NestedTabbedDocConverter.new()
          asObj = converter.parse(data, true) # Note that converter.convert(doc) would return it as JSON string
          # Check errors
          if(converter.errors.nil? or converter.errors.empty?)
            asObj.each { |doc|
              currentDoc = BRL::Genboree::REST::Data::KbDocEntity.new(false, doc)
              docObjs << currentDoc
            }
            retVal = docObjs
          else
            errMsg = "ERRORS: could not parse the tabbed format provided. "
            if(!converter.errors.is_a?(Hash))
              errMsg << "This was due to an internal server error in code that failed to detect problematic tabbed formatting or has a bug in dealing with this particular (but valid) input."
            else # errors should have info
              errMsg << "The converter encountered these errors in the input:\n"
              converter.errors.keys.sort.each { |lineno|
                errMsg << "## Line #{lineno} => #{converter.errors[lineno]}\n"
              }
            end
            retVal = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "There was an error parsing the request body, please check the format and entity type. Specifics: #{errMsg}", nil, true)
          end
        end
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "ERROR:\n", err)
        raise BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', err, nil, true)
      end
      return retVal
    end

    # This method just calls the appropriate class methods defined by the singleton class of this entity
    # @param [Symbol] formatSym The format of the payload (must be one of the supported tabbed formats)
    # @param [String] data A multi-line string with tab-delimited data to be parsed.  Must contain a header
    #   line (line beginning with first non-whitespace character of "#")
    # @param [Hash] opts Extra info about which exact tabbed format it is, what kind
    #   of GenboreeKB doc (data doc or collection model) is represented, and things like
    #   the collection model (for parsing doc representations only) etc are provided here via:
    #   * @:format@   - Either @:TABBED@ (same as @:TABBED_PROP_PATH@) or @:TABBED_PROP_NESTING@
    #   * @:docType@  - Either @:model@ or @:data@
    #   * @:model@    - [NOT CURRENTLY USED OR REQUIRED] A model (a {BRL::Genboree::KB::KbDoc}) to use in interpreting the data doc
    #     representation. Needed for data doc representations but not, obviously, for model representations.
    # @return Always returns @nil@ by default, but real implementations in subclasses return some
    #   kind of {BRL::Genboree::REST::Data::AbstractEntity} subclass.
    def self.makeDocObj(formatSym, data, opts)
      retVal = nil
      begin
        if(formatSym == :TABBED or formatSym == :TABBED_PROP_PATH)
          retVal = BRL::Genboree::REST::Data::KbDocEntity.from_tabbedPropPath(data, opts)
        elsif(formatSym == :TABBED_PROP_NESTING)
          retVal = BRL::Genboree::REST::Data::KbDocEntity.from_tabbedNesting(data, opts)
        else
          # Exception handling not required
          # If user requested a format that is not implemented, the exception will be caught at the resource level
        end
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "ERROR:\n", err)
        retVal = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', '')
      end
      return retVal
    end

  end # class TextEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
