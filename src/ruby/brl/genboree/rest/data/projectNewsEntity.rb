#!/usr/bin/env ruby
require 'time'
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data

  # ProjectNewsEntity- Representation of a project news item: its date and text.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml       -- default implementations from parent class
  # - #getFormatableDataStruct                -- OVERRIDDEN
  # - ProjectNewsEntity.deserialize           -- OVERRIDDEN
  class ProjectNewsEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :PrjNews

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "date", "updateText" ]

    # The date for the news item (+String+ as YYYY/MM/DD or YYYY-MM-DD)
    attr_accessor :date
    # The text of the news item; may contain HTML
    attr_accessor :newsText

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+date+] [optional; default=""] The date for the news item (+String+ as YYYY/MM/DD or YYYY-MM-DD)
    # [+newsText+] [optional; default=""] The text of the news item
    def initialize(doRefs=true, date="", newsText="")
      super(doRefs)
      self.update(date, newsText)
    end

    # OVERRIDE. Take serialized form and create entity object.
    # Overrides the generic deserialization provided in AbstractEntity class (to add some validation).
    # [+serializedIO+] IO-like object containing formatted data (typically is rack.input [i.e. a Rack::Request.body is the arg here], must respond to read(), gets(), each(), and never be closed)
    # [+formatSym+] Stringify/serialize this entity as this format (see FORMATS constant)
    # [+return+] Instance of entity object or HTTP error status name as +Symbol+
    def self.deserialize(serializedIO, formatSym, exceptionPassThrough=false, opts={})
      entity = super(serializedIO, formatSym, exceptionPassThrough, opts)
      if(entity != :'Unsupported Media Type')
        dateOk = true
        # check the date ; date field should be a string in the form YYYY/MM/DD or similar
        if(entity.is_a?(self))
          timeHash = Date._parse(entity.date)
          if(timeHash.key?(:year) and timeHash.key?(:mday) and timeHash.key?(:mon))
            # rewrite the date to have delims etc that we use normally
            timeHash[:mday], timeHash[:mon] = timeHash[:mon], timeHash[:mday] if(timeHash[:mon] > 12)
            entity.date = "#{timeHash[:year]}/#{timeHash[:mon]}/#{timeHash[:mday]}"
          else
            dateOk = false
          end
        else
          dateOk = false
        end
        unless(dateOk)
          BRL::Genboree::GenboreeUtil.logError("ERROR: bad format indicated (#{formatSym.inspect}) or bad representation (probably date) provided", nil, formatSym, entity)
          entity = :'Unsupported Media Type'
        end
      end
      return entity
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+date+] [optional; default=""] The date for the news item (+String+ as YYYY/MM/DD or YYYY-MM-DD)
    # [+newsText+] [optional; default=""] The text of the news item
    def update(date, newsText)
      @refs.clear() if(@refs)
      @date, @newsText = date, newsText
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
                "date" => (@date.respond_to?(:rfc822) ? @date.rfc822 : @date.to_s),
                "updateText" => @newsText
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
        "date" => (@date.respond_to?(:rfc822) ? @date.rfc822 : @date.to_s),     # Should already be a String though
        "updateText" => @newsText
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end
  end # class ProjectNewsEntity < BRL::Genboree::REST::Data::AbstractEntity

  # ProjectNewsEntityList - A collection/set/lost of news items (
  # NOTE: the elements of this list are ProjectNewsEntity objects. Inputs are
  # assumed to correctly be instances of ProjectNewsEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class ProjectNewsEntityList < EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :PrjNewsList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = ProjectNewsEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

    # OVERRIDE. Take serialized form and create entity object.
    # Overrides the generic deserialization provided in AbstractEntity class (to add some validation).
    # [+serializedIO+] IO-like object containing formatted data (typically is rack.input [i.e. a Rack::Request.body is the arg here], must respond to read(), gets(), each(), and never be closed)
    # [+formatSym+] Stringify/serialize this entity as this format (see FORMATS constant)
    # [+return+] Instance of entity object or HTTP error status name as +Symbol+
    def self.deserialize(serializedIO, formatSym, exceptionPassThrough=false, opts={})
      entity = super(serializedIO, formatSym, exceptionPassThrough, opts)
      if(entity != :'Unsupported Media Type' and entity.is_a?(self))
        # check the dates ; each date field should be a string in the form YYYY/MM/DD or similar
        allDatesOk = true
        entity.each_index { |ii|
          newsItem = entity[ii]
          if(newsItem.is_a?(self::ELEMENT_CLASS))
            timeHash = Date._parse(newsItem.date)
            if(timeHash.key?(:year) and timeHash.key?(:mday) and timeHash.key?(:mon))
              # rewrite the date to have delims etc that we use normally
              timeHash[:mday], timeHash[:mon] = timeHash[:mon], timeHash[:mday] if(timeHash[:mon] > 12)
              newsItem.date = "#{timeHash[:year]}/#{timeHash[:mon]}/#{timeHash[:mday]}"
              entity[ii] = newsItem
            else
              allDatesOk = false
              break
            end
          else
            allDatesOk = false
            break
          end
        }
        unless(allDatesOk)
          BRL::Genboree::GenboreeUtil.logError("ERROR: bad format indicated (#{formatSym.inspect}) or bad representation (probably date) provided", nil, formatSym, entity)
          entity = :'Unsupported Media Type'
        end
      end
      return entity
    end
  end # class ProjectNewsEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
