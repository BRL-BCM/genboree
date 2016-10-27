#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/rest/data/userEntity'
require 'brl/genboree/rest/data/textEntity'

module BRL ; module Genboree ; module REST ; module Data

  # BioSampleSetEntity - Representation of a Bio Sample Set
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml       -- default implementations from parent class
  # - #json_create, #getFormatableDataStruct  -- OVERRIDDEN
  class BioSampleSetEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :BioSampleSet

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "name" ]
    # Defaults for the simple fields, if not provided. "nil" means "must be provided in representation!"
    SIMPLE_FIELD_VALUES = [ nil ]

    # TABBED_HEADER is used by the to_tabbed() method to generate the header; should only include
    # core fields, as as user-defined attributes in the avpHash will be given their own
    # columns. The DEFAULT_VALUES array indicates the default values for these core fields.
    TABBED_HEADER = [ "name", "sampleList", "state" ]
    DEFAULT_VALUES = [ nil,  '', 0]

    # Name of this BioSampleSet
    attr_accessor :name
    # +State+
    attr_accessor :state
    # +attributes+ All of the attribute value pairs for this BioSampleSet, in a Hash
    attr_accessor :attributes
    # +sampleList+ A list of bioSamples to be added to the bioSampleSet (by value)
    attr_accessor :sampleList
    # +refList+ API URIs for bioSamples
    attr_accessor :refList
    # +detailed+ detailed response ?
    attr_accessor :detailed
    # +bioSampleRefBase+ for constructing API URIs for bioSamples (needed when @detailed=true)
    attr_accessor :bioSampleRefBase
    # +dbu+ dbu object from the caller
    attr_accessor :dbu

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+name+] [optional; default=""]
    # [+state+] [optional; default=""]
    # [+attributes+]
    def initialize(doRefs=true, name="", state=0, attributes=Hash.new)
      super(doRefs)
      self.update(name, state, attributes)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+name+] [optional; default=""]
    # [+state+] [optional; default=""]
    # [+attributes+]
    def update(name, state, attributes)
      # Clear old values
      @refs.clear() if(@refs)
      if(attributes.nil?)
        @attributes = Hash.new
      else
        @attributes = {}
        attributes.each_key { |key|
          @attributes[key.to_s] = attributes[key]
        }
      end
      # Set class variables to new values
      @name, @state = name, state
      # If the "name" is still nil, then maybe they are using column "sampleSetName"
      if(@name.nil? and @attributes.key?('sampleSetName'))
        @name = @attributes['sampleSetName']
      end
    end

    # Sets @sampleList
    # [+bioSampleRows+]
    def makeBioSampleEntityList(detailed=true)
      t1 = Time.now
      # First, collect core bioSample info for all bioSamples in the set
      sampleRows = @dbu.selectAllBioSamplesByBioSampleSetName(@name)
      # Next get AVP info for the samples in the set
      sampleAVPHash = {} # AVP hash keyed by sample name
      samplesAVPsRows = @dbu.selectBioSamplesAVPsByBioSampleSetName(@name)
      samplesAVPsRows.each { |rec|
        sampleName = rec['name']
        avpHash = ( sampleAVPHash[sampleName] || (sampleAVPHash[sampleName] = {}) )
        avpHash[rec['attribute']] = rec['value']
      }
      # Now create Entity instances for each sample in sampleRows
      bodyData = BRL::Genboree::REST::Data::BioSampleEntityList.new(true)
      sampleRows.each { |row|
        sampleName = row['name']
        avpHash = sampleAVPHash[sampleName]
        entity = BRL::Genboree::REST::Data::BioSampleEntity.new(true, sampleName, row['type'], row['biomaterialState'], row['biomaterialProvider'], row['biomaterialSource'], row['state'], avpHash)
        entity.makeRefsHash("#{@bioSampleRefBase}/#{Rack::Utils.escape(sampleName)}") if(@bioSampleRefBase)
        bodyData << entity
      }
      return (@sampleList = bodyData)
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
        retVal = (@attributes[meth] = args.first)
      else
        retVal = @attributes[meth]
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

    # Overwrites the parent method: used for special parsing of payload
    # [+parsedJsonResult+]  Object that resulted from <tt>JSON.parse()</tt> on a JSON string or a compatible
    #                       data structure resulting from parsing XML, YAML, etc.
    # [+fieldNames+]        [optional; default=+SIMPLE_FIELD_NAMES+] A list names of simple fields, in order matching constructor argument order.
    # [+returns+]           Instance of this class or +nil+ if +parsedJsonResult+ appears bad.
    def self.jsonCreateSimple(parsedJsonResult, fieldNames=self::SIMPLE_FIELD_NAMES)
      retVal = nil
      # Get content and status info from Common Wrapper if present. If not, content will be parsedJsonResult
      content = AbstractEntity.extractParsedContent(parsedJsonResult)
      status = AbstractEntity.extractParsedStatus(parsedJsonResult)
      # For each field, extract its value from the parsed JSON object and add it to constructor arguments.
      # We need to see if the payload is 'refList' or 'bioSampleSetEntity'
      args = []
      fieldNames.each_index { |ii|
        fieldName = fieldNames[ii]
        defaultValue = ((self::SIMPLE_FIELD_VALUES.empty? or self::SIMPLE_FIELD_VALUES.size <= ii) ? nil : self::SIMPLE_FIELD_VALUES[ii])
        if(content.key?(fieldName))
          value = content[fieldName]
          args << value
        elsif(defaultValue) # then we have a default value we can use if not provided
          value = defaultValue
          args << defaultValue
        else # expected field is missing and we have no default!
          raise "Expecting '#{fieldName}' in representation, but not found."
        end
      }
      # Add resource specific values: state and attributes (This way the user does not have to necessarily add these)
      if(content['state'].nil? or content['state'].empty?)
        args <<  0
      else
        args << content['state']
      end
      if(content['attributes'].nil? or content['attributes'].empty?)
        args <<  {}
      else
        args << content['attributes']
      end
      # If everything went ok and we found everything, then args is filled with values; otherwise args is nil & there were problems.
      unless(args.nil?)
        doRefs = content.key?("refs")
        retVal = self.new(doRefs, *args) # Call new() for whatever class this method is in (through inheritance)
        # Some entities have a "refs" field. Add now if present.
        retVal.refs = content["refs"] if(doRefs)
        # Set status info from parsedJsonResult, unless data wasn't wrapped in Common Wrapper
        # or status key set to nil or something, in which case default status is used.
        retVal.setStatus(status["statusCode"], status["msg"]) unless(status.nil?)
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
      if(@detailed)
        # This does not seem cross-host compatible?
        bioSampleRows = @dbu.selectAllBioSamplesByBioSampleSetName(@name)
        makeBioSampleEntityList(bioSampleRows)
        data =  {
                  "name" => @name,
                  "state" => @state,
                  "attributes" => @attributes,
                  "sampleList" => @sampleList
                }
      else
        data =  {
                  "name" => @name
                }
      end
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
      # Rrepresentation has different info depending on @detailed
      if(@detailed)
        # The SIMPLE_FIELD_NAMES first. Values are basic Ruby types (String, Hash, Array, Fixnum, Float, boolean, etc)
        data =
        {
          "name"        => @name,
          "state"       => @state,
          "attributes"  => @attributes
        }
        # Fields whose values are AbstractEntity subclass objects
        # - just-in-time retrieval of actual sample info
        # This does not seem cross-host compatible?
        t1 = Time.now
        makeBioSampleEntityList()
        data["sampleList"] = @sampleList.toStructuredData(false)
      else
        data =
        {
          "name"        => @name
        }
      end
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end

    # This method will construct a tab-delimited string of the information
    # contained by this entity. If called with no attrNames array, it will
    # construct the array based on the attributes.  If called from the EntityList's
    # to_tabbed() method, an array of attribute names will be provided based on
    # all entities' attributeses.
    # [+attrNames+]  An array of attribute names to append to the header
    #                after the core fields have been inserted.
    # [+columnHeader+]  true or false to output or surpress the column header
    # [+returns+] Tab delimited bioSample information
    def to_tabbed(attrNames=nil, columnHeader=true)
      retVal = ''
      # Construct our header (can change depending on our data)
      if(@detailed)
        headerCols = TABBED_HEADER.dup
        if(attrNames.nil?)
          headerCols += @attributes.keys.sort{|aa, bb| aa.to_s.downcase <=> bb.to_s.downcase }
        else
          headerCols += attrNames
        end
         # Data for the 1 record
        dataCols = Array.new(headerCols.size)
        headerCols.each_index { |ii|
          if(ii == 1) # For sampleList
            bioSampleRows = @dbu.selectAllBioSamplesByBioSampleSetName(@name)
            bioSampleListArray = []
            bioSampleRows.each { |bioSample|
              bioSampleListArray << bioSample['name']
            }
            dataCols[ii] = bioSampleListArray.join(",")
          else
            dataCols[ii] = esc(self.send(headerCols[ii]))
          end
        }
        # Make output text
        if(columnHeader)
          headerCols.map! { |xx| esc(xx) }
          retVal = "##{headerCols.join("\t")}\n"
        end
        retVal << "#{dataCols.join("\t")}\n"
      else
        headerCols = [TABBED_HEADER[0]].dup()
        dataCols = Array.new(headerCols.size)
        headerCols.each_index { |ii| dataCols[ii] = esc(self.send(headerCols[ii])) }
        # Make output text
        if(columnHeader)
          headerCols.map! { |xx| esc(xx) }
          retVal = "##{headerCols.join("\t")}\n"
        end
        retVal << "#{dataCols.join("\t")}\n"
      end
      return retVal
    end

    # Class specific method to support Entity creation from tab-delimited data
    # (needs a proper header, even if just 1 record (obviously)
    def self.from_tabbed(data, opts={})
      retVal = BioSampleSetEntityList.from_tabbed(data, opts)
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
  end # class BioSampleSetEntity < BRL::Genboree::REST::Data::AbstractEntity



  # BioSampleSetEntityList - Collection/list containing multiple saved bioSample
  # objects.
  # NOTE: the elements of the list are BioSampleSetEntity objects. Inputs are
  #   assumed to correctly be instances of BioSampleSetEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class BioSampleSetEntityList < BRL::Genboree::REST::Data::EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :BioSampleSetList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = BioSampleSetEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)


    # This method constructs a tab-delimited string representation of the
    # entities contained by this list.  To accomplish this it constructs
    # an appropriate header based on the the attributes of all entities,
    # then calls the individual entity's to_tabbed() method, supplying
    # the array of attribute names.
    # [+returns+] A tab-delimited string representing all entities contained by the entity list.
    def to_tabbed()
      retVal = ''
      unless(self.empty?)
        # Create header with columns based on all sample entities
        accumAvpHash = {}
        self.map { |entity|
          accumAvpHash = accumAvpHash.merge(entity.attributes)
        }
        headerCols = BioSampleSetEntity::TABBED_HEADER.dup
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
      retVal = BioSampleSetEntityList.new(false)
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
        else
          # Use our header to read in our data
          dataLine = line.split("\t", Integer::MAX32)
          raise BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "Wrong number of columns on line #{lineno}. Header indicates #{header.size} columns. Sample set record at line #{lineno} has #{dataLine.size} columns. Aborting sample set import.") unless(header.size == dataLine.size)
          values = []
          # Set the defaults first (name will be set to nil...it's required so this will trigger issues)
          values = BioSampleSetEntity.setDefaults(values)
          # Examine each column
          header.each_index { |idx|
            key = header[idx]
            valueIdx = BioSampleSetEntity::TABBED_HEADER.index(key)
            if(!valueIdx.nil?) # then it's a core field
              values[valueIdx] = dataLine[idx]
            else # custom field
              customFields = values.last
              raise BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "Duplicate columns in the header.") if(customFields.key?(key))
              customFields[key] = dataLine[idx]
            end
           }
          retVal << BioSampleSetEntity.new(false, *values)
        end
        lineno += 1
      }
      # Now return our list
      return retVal
    end
  end # class BioSampleSetEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data

