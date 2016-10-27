#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data
  # Hash of entity names to simple attribute-value pairs

  # EntityAttributeMapEntity - Object containing a simple Hash of entity names to simple attribute-value pairs
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class ChrMapEntity < BRL::Genboree::REST::Data::EntityHash
    # Override key class constants used by inherited methods
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :ChrMap

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = Object

    # Constuctor. Matching GENBOREE INTERFACE.
    # [+doRefs+]      [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+hashMap+]     [optional; default={}] +Hash+ of individual data structures going into this collection. They can be added later if not provided to the constructor.
    def initialize(doRefs=true, hashMap={})
      # Does not CURRENTLY support doRefs in the response
      doRefs = false
      super(doRefs)
      self.update(hashMap)
    end

    # ------------------------------------------------------------------
    # OVERRIDES
    # - Unlike most of API framework, this collection's individual items are not AbstractEntities but themselves
    #   are just a plain Ruby Hash (mapping attributes to values)
    # - Thus must override certain methods which assume ELEMENT_CLASS is a subclass of AbstractEntity
    # ------------------------------------------------------------------

    # GENBOREE INTERFACE. Import (add) individual entities into this list from *raw data*.
    # For each object in "array" arg, an new instance of this classes' ELEMENT_CLASS will
    # be created and added to the list. Mainly a convenicent method to save typing everywhere.
    # - doRefs for each item will mimic @doRefs for this instance
    def importFromRawData(hashMap)
      hashMap.each_key { |key|
        item = hashMap[key]
        @hashMap[key] = item
      }
      return @hashMap
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
        "hash" => @hashMap
      }
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.from_json method to parse a JSON
    # representation. This is overridden here to loop into the +Hash+ of basic Ruby Objects
    # and create instances of their data representation classes, adding each to the collection.
    # [+parsedJsonResult+]  Just a simple Hash, resulting from parsing the json. Use as-is.
    # [+returns+]           Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.from_json(parsedJsonResult)
      # Get content and status info from Common Wrapper if present...ff not, content will be parsedJsonResult
      content = AbstractEntity.extractParsedContent(parsedJsonResult)
      status = AbstractEntity.extractParsedStatus(parsedJsonResult)
      # Create entity based on content, if content is looks correct. Else empty.
      hashMap = {}
      # This type of entity is just {'data'=>{entitiesHash}}. Also, we won't be trying to convert
      # values to some instance of AbstractEntities, since this is supposed be a simple/flat/normal key-value pair hash.
      contentHash = content
      # Look for doRefs (but unlikely)
      doRefs = (contentHash.respond_to?(:'key?') and contentHash.key?("refs"))
      # Create object instance using content
      retVal = self.new(doRefs, contentHash)
      # Set status info from parsedJsonResult, unless data wasn't wrapped in Common Wrapper
      # or status key set to nil or something, in which case default status is used.
      retVal.setStatus(status["statusCode"], status["msg"]) unless(status.nil?)
      return retVal
    end

    # Class specific method to support EntityHash creation from mult-line
    # tab-delimited data (needs a proper header)
    def self.from_tabbed(data, opts={})
      header = nil
      lineno = 1
      mapHash = Hash.new { |hh, kk|
        hh[kk] = {}
      }
      indexHash = {}
      nameIndex = nil
      fields = {}
      headerSize = 0
      data.each_line { |line|
        # Skip blank or whitespace-only lines
        next if(line !~ /\S/)
        line.strip!
        if(header.nil?)
          # Check for a bad header line
          raise BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "Missing column header line. Check that header line is a comment line beginning with '#' and containing the tab-delimited column headers.", nil, nil) unless(line =~ /^\s*#/)
          # Parse our header array
          header = line.split(/\t/)
          # The 'name' column must be there
          found = false
          header.size.times { |ii|
            if(header[ii] == 'name' or header[ii] == '#name')
              found = true
              fields['name'] = nil
              nameIndex = ii
            else # attribute name columns
              indexHash[ii] = header[ii]
              if(fields.has_key?(header[ii]))
                raise BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "Duplicate field: #{header[ii].inspect} in header.")
              else
                fields[header[ii]] = nil
              end
            end
          }
          headerSize = header.size
          raise BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "'name' field not found in header. ") if(!found)
        else
          # Use our header to read in our data
          dataLine = line.split(/\t/)
          raise BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "Wrong number of columns on line #{lineno}. Header indicates #{header.size} columns. Entity record at line #{lineno} has #{dataLine.size} columns. Aborting import of entity attributes.") unless(headerSize == dataLine.size)
          entityName = dataLine[nameIndex]
          tmpHash = mapHash[entityName]
          indexHash.each_key { |index|
            tmpHash[indexHash[index]] = dataLine[index]
          }
        end
        lineno += 1
      }
      retVal = EntityAttributeMapEntity.new(false, mapHash)
      # Now return our hash
      return retVal
    end
  end # class EntityAttributeMapEntity < BRL::Genboree::REST::Data::EntityHash
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
