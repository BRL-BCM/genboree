#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/rest/data/userEntity'
require 'brl/genboree/rest/data/textEntity'

module BRL ; module Genboree ; module REST ; module Data

  # ExperimentEntity - Representation of a experiment
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - #json_create, #getFormatableDataStruct  -- OVERRIDDEN
  class ExperimentEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :Experiment

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "name", "type", "study", "bioSample", "state", "avpHash" ]

    # TABBED_HEADER is used by the to_tabbed() method to generate the header; should only include
    # core fields, as as user-defined attributes in the avpHash will be given their own
    # columns.
    TABBED_HEADER = [ "name", "type", "study", "bioSample", "state"]
    # Name of this Experiment
    attr_accessor :name
    # +Type+
    attr_accessor :type
    # +Lab+
    attr_accessor :study
    # +Contributors+
    attr_accessor :bioSample
    # +State+
    attr_accessor :state
    # +avpHash+ All of the attribute value pairs for this Experiment, in a Hash
    attr_accessor :avpHash

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any
    #   representation of this entity (i.e. make connections or save size /
    #   complexity of representation?)
    # [+name+] [optional; default=""]
    # [+type+] [optional; default=""]
    # [+study+] [optional; default=empty]
    # [+bioSample+] [optional; default=""]
    # [+state+] [optional; default=""]
    def initialize(doRefs=true, name="", type="", study="", bioSample="", state="", avpHash=Hash.new)
      super(doRefs)
      self.update(name, type, study, bioSample, state, avpHash)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of
    #   instances rather than always making new objects
    # [+name+] [optional; default=""]
    # [+type+] [optional; default=""]
    # [+study+] [optional; default=empty]
    # [+bioSample+] [optional; default=""]
    # [+state+] [optional; default=""]

    def update(name, type, study, bioSample, state, avpHash)
      # Clear old values
      @refs.clear() if(@refs)
      @avpHash = if(avpHash.nil?) then Hash.new else avpHash end
      # Set class variables to new values
      @name, @type, @study, @bioSample, @state = name, type, study, bioSample, state
    end

    # Delegate all other methods to @array (eg <<, +, +length+, +each+, etc).
    # This is a standard Ruby method available to all objects. This delagtion
    # to @array is kind a like having this class inherit from Array also.
    # All array inputs are assumed to be instances of the appropriate class.
    # [+meth+] The name of the method as a +Symbol+ or +String+.
    # [+args+] All the arguments to the method will be slurped up into this local variable.
    # [+block+] If there's a code block provided (e.g. for +each+), it will be here.
    def method_missing(meth, *args, &block)
      @avpHash.send(meth, *args, &block)
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.json_create method.
    # This class method defined by the JSON library allows instances of this class
    # to be created from _parsed_ JSON (i.e. a +Hash+ or +Array+ resulting from
    # JSON::parse). The default implemenation just calls AbstractEntity.from_json
    # which is likely fine for almost all subclasses.
    # [+parsedJsonResult+]  The +Hash+ or +Array+ resulting from parsing the JSON string.
    # [+returns+] Instance of this class, whose state comes from data within +parsedJsonResult+.
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
      data =
      {
        "name" => @name,
        "type" => @type,
        "study" => @study,
        "bioSample" => @bioSample,  # String
        "state" => @state,
        "avpHash" => @avpHash       # Hash
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
        "type" => @type,
        "study" => @study,
        "bioSample" => @bioSample,  # String
        "state" => @state,
        "avpHash" => @avpHash       # Hash
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end

    # This method will construct a tab-delimited string of the information
    # contained by this entity. If called with no attrNames array, it will
    # construct the array based on the avpHash.  If called from the EntityList's
    # to_tabbed() method, an array of attribute names will be provided based on
    # all entities' avpHashes.
    # [+attrNames+]  An array of attribute names to append to the header
    #                after the core fields have been inserted.
    # [+returns+] Tab delimited experiment information
    def to_tabbed(attrNames=nil)
      # Construct our header (can change depending on our data)
      retVal = ''

      if(attrNames.nil?)
        retVal << "##{TABBED_HEADER.join("\t")}"
        attrNames = @avpHash.keys.sort
        attrNames.each{|field| retVal << "\t#{esc(field)}" }
        retVal << "\n"
      end

      # Construct our data line
      retVal << "#{esc(@name)}\t#{esc(@type)}\t#{esc(@study)}\t#{esc(@bioSample)}\t#{esc(@state)}"

      attrNames.each{|field| retVal << "\t#{esc(@avpHash[field])}" }
      retVal << "\n"

      return retVal
    end
    # Class specific method to support Entity creation from tab-delimited data
    # (needs a proper header)
    def self.from_tabbed(data, opts={})
      retVal = ExperimentEntityList.from_tabbed(data, opts)
      raise "Unknown problem building entity" if(retVal.nil?)
      raise "Missing data line" if(retVal.size == 0)
      raise "Multiple data lines in tab-delimited data" if(retVal.size > 1)
      return retVal[0]
    end
  end # class ExperimentEntity < BRL::Genboree::REST::Data::AbstractEntity

  # ExperimentEntityList - Collection/list containing multiple experiment objects.
  # NOTE: the elements of the list are ExperimentEntity objects. Inputs are
  #   assumed to correctly be instances of ExperimentEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class ExperimentEntityList < BRL::Genboree::REST::Data::EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :ExperimentList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = ExperimentEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

    # This method constructs a tab-delimited string representation of the
    # entities contained by this list.  To accomplish this it constructs
    # an appropriate header based on the the avpHashes of all entities,
    # then calls the individual entity's to_tabbed() method, supplying
    # the array of attribute names.
    # [+returns+] A tab-delimited string representing all entities contained
    #             by the entity list.
    def to_tabbed()
      retVal = ''

      retVal << "##{ExperimentEntity::TABBED_HEADER.join("\t")}"

      attrArray = []

      attrArray = self.map{|entity| entity.avpHash.keys }
      attrArray.flatten!
      attrArray.uniq!
      attrArray.sort!{|aa, bb| aa.downcase <=> bb.downcase }
      attrArray.each_index{|ii|
        retVal << "\t#{esc(attrArray[ii])}"
      }
      retVal << "\n"
      # Loop through again to append items
      self.each{|entity|
        retVal << entity.to_tabbed(attrArray)
      }
      return retVal
    end
    # Class specific method to support EntityList creation from mult-line
    # tab-delimited data (needs a proper header)
    def self.from_tabbed(data, opts={})
      header = nil
      retVal = ExperimentEntityList.new(false)
      data.each_line{ |line|
        # Skip blank or whitespace-only lines
        next if(line =~ /^\s*$/)

        if(header.nil?)
          # Check for a bad header line
          raise "Missing header line" unless(line =~ /^\s*#/)
          # Parse our header array
          header = line[1..line.size].strip.split("\t")
        else
          # Use our header to read in our data
          dataLine = line.split("\t")
          values = []
          values[5] = {}
          header.each{ |key|
            idx = header.index(key)
            if(key == "name")
              values[0] = dataLine[idx]
            elsif(key == "type")
              values[1] = dataLine[idx]
            elsif(key == "study")
              values[2] = dataLine[idx]
            elsif(key == "bioSample")
              values[3] = dataLine[idx]
            elsif(key == "state")
              values[4] = dataLine[idx]
            else
              raise "Duplicate columns in the header" unless(values[5][key].nil?)
              values[5][key] = dataLine[idx] unless(dataLine[idx].empty?)
            end
          }
          retVal << ExperimentEntity.new(false, *values)
        end
      }

      # Now return our list
      return retVal
    end
  end # class ExperimentEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
