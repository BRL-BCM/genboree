#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/rest/data/userEntity'
require 'brl/genboree/rest/data/textEntity'

module BRL ; module Genboree ; module REST ; module Data

  # BioSampleEntity - Representation of a Bio Sample
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml       -- default implementations from parent class
  # - #json_create, #getFormatableDataStruct  -- OVERRIDDEN
  class BioSampleEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :BioSample

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "name", "type", "biomaterialState", "biomaterialProvider","biomaterialSource", "state", "avpHash" ]

    # TABBED_HEADER is used by the to_tabbed() method to generate the header; should only include
    # core fields, as as user-defined attributes in the avpHash will be given their own
    # columns. The DEFAULT_VALUES array indicates the default values for these core fields.
    TABBED_HEADER = [ "name", "type", "biomaterialState", "biomaterialProvider", "biomaterialSource", "state" ]
    DEFAULT_VALUES = [ nil, '', '', '', '', 0]

    # Name of this BioSample
    attr_accessor :name
    # +Type+
    attr_accessor :type
    # +biomaterialProvider+
    attr_accessor :biomaterialProvider
    # +biomaterialState+
    attr_accessor :biomaterialState
    # +biomaterialSource
    attr_accessor :biomaterialSource
    # +State+
    attr_accessor :state
    # +avpHash+ All of the attribute value pairs for this BioSample, in a Hash
    attr_accessor :avpHash

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+name+] [optional; default=""]
    # [+type+] [optional; default=""]
    # [+lab+] [optional; default=empty]
    # [+contributors+] [optional; default=""]
    # [+state+] [optional; default=""]
    def initialize(doRefs=true, name="", type="", biomaterialState="", biomaterialProvider="", biomaterialSource="", state="", avpHash=Hash.new)
      super(doRefs)
      self.update(name, type, biomaterialState, biomaterialProvider, biomaterialSource, state, avpHash)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+name+] [optional; default=""]
    # [+type+] [optional; default=""]
    # [+lab+] [optional; default=empty]
    # [+contributors+] [optional; default=""]
    # [+state+] [optional; default=""]

    def update(name, type, biomaterialState, biomaterialProvider, biomaterialSource, state, avpHash)
      # Clear old values
      @refs.clear() if(@refs)
      if(avpHash.nil?)
        @avpHash = Hash.new
      else
        @avpHash = {}
        avpHash.each_key { |key|
          @avpHash[key.to_s] = avpHash[key]
        }
      end
      # Set class variables to new values
      @name, @type, @biomaterialState, @biomaterialProvider, @biomaterialSource, @state = name, type, biomaterialState, biomaterialProvider, biomaterialSource, state
      # If the "name" is still nil, then maybe they are using column "sampleName" (like Qiime does for example)
      if(@name.nil? and @avpHash.key?('sampleName'))
        @name = @avpHash['sampleName']
      end
    end

    # Delegate all other methods to @array (eg <<, +, +length+, +each+, etc). This is
    # a standard Ruby method available to all objects. This delagtion to @array is kind a like having this class inherit from Array also.
    # All array inputs are assumed to be instances of the appropriate class.
    # [+meth+]    The name of the method as a +Symbol+ or +String+.
    # [+args+]    All the arguments to the method will be slurped up into this local variable.
    # [+block+]   If there's a code block provided (e.g. for +each+), it will be here.
    def method_missing(meth, *args, &block)
      meth = meth.to_s
      meth =~ /([^=]+)(=)?/
      meth, assign = $1, $2
      if(assign)
        retVal = (@avpHash[meth] = args.first)
      else
        retVal = @avpHash[meth]
      end
      return retVal
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
                "type" => @type,
                "biomaterialState" => @biomaterialState,
                "biomaterialProvider" => @biomaterialProvider,
                "biomaterialSource" => @biomaterialSource,
                "state" => @state,
                "avpHash" => @avpHash
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
        "biomaterialState" => @biomaterialState,
        "biomaterialProvider" => @biomaterialProvider,
        "biomaterialSource" => @biomaterialSource,
        "state" => @state,
        "avpHash" => @avpHash
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
    # [+columnHeader+]  true or false to output or surpress the column header
    # [+returns+] Tab delimited bioSample information
    def to_tabbed(attrNames=nil, columnHeader=true)
      retVal = ''
      # Construct our header (can change depending on our data)
      headerCols = TABBED_HEADER.dup
      if(attrNames.nil?)
        headerCols += @avpHash.keys.sort{|aa, bb| aa.to_s.downcase <=> bb.to_s.downcase }
      else
        headerCols += attrNames
      end

      # Data for the 1 record
      dataCols = Array.new(headerCols.size)
      headerCols.each_index { |ii| dataCols[ii] = esc(self.send(headerCols[ii])) }

      # Make output text
      if(columnHeader)
        headerCols.map! { |xx| esc(xx) }
        retVal = "##{headerCols.join("\t")}\n"
      end
      retVal << "#{dataCols.join("\t")}\n"
      return retVal
    end

    # Class specific method to support Entity creation from tab-delimited data
    # (needs a proper header, even if just 1 record (obviously)
    def self.from_tabbed(data, opts={})
      retVal = BioSampleEntityList.from_tabbed(data, opts)
      $stderr.puts "#{self.class}##{__method__}: retVal size = #{retVal.size}, first few:\n#{retVal.first}\n#{retVal[1]}\n"
      if(retVal.nil?)
        raise "Unknown problem building entity"
      elsif(retVal.size == 0)
        raise "Missing data lines"
      elsif(retVal.size > 1)
        raise "Multiple data lines in tab-delimited data."
      end
      return retVal[0]
    end

    def self.setDefaults(values=[])
      retVal = values
      TABBED_HEADER.each_index { |idx|
        values[idx] = DEFAULT_VALUES[idx]
      }
      # Last one will hold the custom field hash:
      values[DEFAULT_VALUES.size] = {}
      return values
    end
  end # class BioSampleEntity < BRL::Genboree::REST::Data::AbstractEntity

  # BioSampleEntityList - Collection/list containing multiple saved bioSample
  # objects.
  # NOTE: the elements of the list are BioSampleEntity objects. Inputs are
  #   assumed to correctly be instances of BioSampleEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class BioSampleEntityList < BRL::Genboree::REST::Data::EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :BioSampleList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = BioSampleEntity
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
      unless(self.empty?)
        # Create header with columns based on all sample entities
        accumAvpHash = {}
        self.map { |entity|
          accumAvpHash = accumAvpHash.merge(entity.avpHash)
        }
        headerCols = BioSampleEntity::TABBED_HEADER.dup
        headerCols += accumAvpHash.keys.sort{|aa, bb| aa.downcase <=> bb.downcase }

        # Loop through entities to get them as records
        dataRecordsText = ''
        self.each { |entity| dataRecordsText += "#{entity.to_tabbed(nil, false)}" }

        # Create output text
        headerCols.map! { |xx| esc(xx) }
        retVal = "##{headerCols.join("\t")}\n"
        retVal << dataRecordsText
      end
      return retVal
    end

    # Class specific method to support EntityList creation from mult-line
    # tab-delimited data (needs a proper header)
    def self.from_tabbed(data, opts={})
      header = nil
      retVal = BioSampleEntityList.new(false)
      lineno = 1
      data.each_line { |line|
        # Skip blank or whitespace-only lines
        next if(line !~ /\S/)
        line.strip!
        if(header.nil?)
          # Check for a bad header line
          raise BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "Missing column header line. Check that header line is a comment line beginning with '#' and containing the tab-delimited column headers.", nil, nil) unless(line =~ /^\s*#/)
          # Parse our header array
          header = line[1, line.size].split("\t")
          # Remove leading & trailing whitespace from column header names contents
          header.map! { |cell| cell.strip }
        else
          # Use our header to read in our data
          dataLine = line.split("\t", Integer::MAX32)
          # Remove leading & trailing whitespace from cell contents
          dataLine.map! { |cell| cell.strip }
          raise BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "Wrong number of columns on line #{lineno}. Header indicates #{header.size} columns. Sample record at line #{lineno} has #{dataLine.size} columns. Aborting sample import.") unless(header.size == dataLine.size)
          values = []
          # Set the defaults first (name will be set to nil...it's required so this will trigger issues)
          values = BioSampleEntity.setDefaults(values)
          # Examine each column
          header.each_index { |idx|
            key = header[idx]
            valueIdx = BioSampleEntity::TABBED_HEADER.index(key)
            if(!valueIdx.nil?) # then it's a core field
              values[valueIdx] = dataLine[idx]
            else # custom field
              customFields = values.last
              #raise BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "Duplicate columns in the header.") if(customFields.key?(key))
              customFields[key] = dataLine[idx]
            end
          }
          retVal << BioSampleEntity.new(false, *values)
        end
        lineno += 1
      }
      # Now return our list
      return retVal
    end
  end # class BioSampleEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
