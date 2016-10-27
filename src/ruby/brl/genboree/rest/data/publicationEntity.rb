#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/rest/data/userEntity'
require 'brl/genboree/rest/data/textEntity'

module BRL ; module Genboree ; module REST ; module Data
  # PartialPublicationEntity - Simple version of the PublicationEntity class,
  # only storing the id, title, and type for the publication.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - #getFormatableDataStruct           -- overridden implementation
  class PartialPublicationEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses
    # may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name
    # friendly) name. This is currently used in generating XML for _lists_...
    # They will be lists of tags of this type (XML makes it hard to express
    # certain natural things easily...)
    RESOURCE_TYPE = :PartialPublication

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex
    # data structure but rather some text or a number. Framework will do some
    # automatic processing and presentation of those for you.
    SIMPLE_FIELD_NAMES = [ "id", "type", "title" ]

    # +id+ Internal Genboree database ID for this Publication (unique identifier).
    attr_accessor :id
    # +type+ The type of Publication this is (journal article, talk, draft, etc.).
    attr_accessor :type
    # +title+ The title of this Publication.
    attr_accessor :title

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any
    #   representation of this entity (i.e. make connections or save size /
    #   complexity of representation?)
    # [+id+] [optional; default=nil] The Genboree ID for this Publication.
    # [+type+] [optional; default=""]
    # [+title+] [optional; default=""]
    def initialize(doRefs=true, id=nil, type="", title="")
      super(doRefs)
      self.update(id, type, title)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of
    # instances rather than always making new objects
    def update(id, type, title)
      # Clear old values
      @refs.clear() if(@refs)
      # Set class variables to new values
      @id, @type, @title = id, type, title
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.json_create method.
    # This class method defined by the JSON library allows instances of this class
    # to be created from _parsed_ JSON (i.e. a +Hash+ or +Array+ resulting from
    # JSON::parse). The default implemenation just calls AbstractEntity.from_json
    # which is likely fine for almost all subclasses.
    # [+parsedJsonResult+]  The +Hash+ or +Array+ resulting from parsing the JSON string.
    # [+returns+]           Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.json_create(parsedJsonResult)
      retVal = self.jsonCreateSimple(parsedJsonResult, self::SIMPLE_FIELD_NAMES)
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
                "id" => @id,
                "type" => @type,
                "title" => @title
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
        "id" => @id,
        "type" => @type,
        "title" => @title
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end

    # Helper method to create tab-delimited representation
    # of a partial publication entity.
    # [+returns+] Tab-delimited partial publication information.
    def to_tabbed()
      retVal = "#id\ttype\ttitle\t\n"
      retVal << "#{esc(@id)}\t#{esc(@type)}\t#{esc(@title)}\n"

      return retVal
    end

    # Class specific method to support Entity creation from tab-delimited data
    # (needs a proper header)
    def self.from_tabbed(data, opts={})
      retVal = PartialPublicationEntityList.from_tabbed(data, opts)
      raise "Unknown problem building entity" if(retVal.nil?)
      raise "Missing data line" if(retVal.size == 0)
      raise "Multiple data lines in tab-delimited data" if(retVal.size > 1)
      return retVal[0]
    end
  end # class PartialPublicationEntity < BRL::Genboree::REST::Data::AbstractEntity

  # PartialPublicationEntityList - Collection/list containing multiple saved
  # publication objects.
  # NOTE: the elements of the list are PartialPublicationEntity objects. Inputs
  #   are assumed to correctly be instances of PartialPublicationEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class PartialPublicationEntityList < BRL::Genboree::REST::Data::EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses
    # may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name
    # friendly) name. This is currently used in generating XML for _lists_...
    # They will be lists of tags of this type (XML makes it hard to express
    # certain natural things easily...)
    RESOURCE_TYPE = :PartialPublicationList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = PartialPublicationEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

    # This method creates tab-delimited representation of partial
    # publication entities from a list.
    # [+returns+] Tab-delimited partial pub list data
    def to_tabbed()
      retVal = "#id\ttype\ttitle\t\n"

      # Loop through again to append items
      self.each{|entity|
        retVal << "#{esc(entity.id)}\t#{esc(entity.type)}\t#{esc(entity.title)}\n"
      }
      return retVal
    end

    # Class specific method to support EntityList creation from mult-line
    # tab-delimited data (needs a proper header)
    def self.from_tabbed(data, opts={})
      header = nil
      retVal = PartialPublicationEntityList.new(false)
      data.each_line{ |line|
        # Skip blank or whitespace-only lines
        next if(line =~ /\s*/)

        if(header.nil?)
          # Check for a bad header line
          raise "Missing header line" unless(line =~ /^\s*#/)
          # Parse our header array
          header = line.strip.split("\t")
        else
          # Use our header to read in our data
          dataLine = line.split("\t")
          values = []
          values[6] = {}
          header.each{ |key|
            idx = header.index(key)
            if(key == "id")
              values[0] = dataLine[idx]
            elsif(key == "type")
              values[1] = dataLine[idx]
            elsif(key == "title")
              values[2] = dataLine[idx]
            else
              raise "Extra unknown columns in header and data"
            end
          }
          retVal << PartialPublicationEntity.new(false, *values)
        end
      }

      # Now return our list
      return retVal
    end
  end # class PartialPublicationEntityList < BRL::Genboree::REST::Data::EntityList

  # PublicationEntity - Representation of a publication
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - #json_create, #getFormatableDataStruct  -- OVERRIDDEN
  class PublicationEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses
    # may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name
    # friendly) name. This is currently used in generating XML for _lists_...
    # they will be lists of tags of this type (XML makes it hard to express
    # certain natural things easily...)
    RESOURCE_TYPE = :Publication

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex
    # data structure but rather some text or a number. Framework will do some
    # automatic processing and presentation of those for you.
    SIMPLE_FIELD_NAMES = [ "id", "pmid", "type", "title", "authorList", "journal", "meeting", "date", "volume", "issue", "startPage", "endPage", "abstract", "meshHeaders", "url", "state", "language" , "avpHash" ]

    # TABBED_HEADER is used by the to_tabbed() method to generate the header; should only include
    # core fields, as as user-defined attributes in the avpHash will be given their own
    # columns.
    TABBED_HEADER = [ "id", "pmid", "type", "title", "authorList", "journal", "meeting", "date", "volume", "issue", "startPage", "endPage", "abstract", "meshHeaders", "url", "state", "language"]
    # +id+ Internal Genboree database ID for this Publication (unique identifier).
    attr_accessor :id
    # +pmid+ PubMed ID (can be nil).
    attr_accessor :pmid
    # +type+ The type of Publication this is (journal article, talk, draft, etc.).
    attr_accessor :type
    # +title+ The title of this Publication.
    attr_accessor :title
    # +authorList+ The authors list for this Publication.
    attr_accessor :authorList
    # +journal+ What journal this article was published in (empty for non-journal articles).
    attr_accessor :journal
    # +meeting+ What meeting this Publication was presented at.
    attr_accessor :meeting
    # +date+ The date of this Publication.
    attr_accessor :date
    # +volume+
    attr_accessor :volume
    # +issue+
    attr_accessor :issue
    # +startPage+
    attr_accessor :startPage
    # +endPage+
    attr_accessor :endPage
    # +abstract+
    attr_accessor :abstract
    # +meshHeaders+
    attr_accessor :meshHeaders
    # +url+
    attr_accessor :url
    # +state+
    attr_accessor :state
    # +language+
    attr_accessor :language
    # +avpHash+ All of the attribute value pairs for this Publication, in a Hash
    attr_accessor :avpHash

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any
    #   representation of this entity (i.e. make connections or save size /
    #   complexity of representation?)
    # [+pmid+] [optional; default=nil]
    # [+type+] [optional; default=""]
    def initialize(doRefs=true, id=nil, pmid=nil, type="", title="", authorList="", journal="", meeting="", date=nil, volume="", issue="", startPage="", endPage="", abstract="", meshHeaders="", url="", state="", language="", avpHash=Hash.new)
      super(doRefs)

      self.update(id, pmid, type, title, authorList, journal, meeting, date, volume, issue, startPage, endPage, abstract, meshHeaders, url, state, language , avpHash )
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of
    # instances rather than always making new objects
    def update(id, pmid, type, title, authorList, journal, meeting, date, volume, issue, startPage, endPage, abstract, meshHeaders, url, state, language , avpHash)
      # Clear old values
      @refs.clear() if(@refs)
      if(avpHash.nil?)
        @avpHash = Hash.new
      else
        @avpHash = avpHash
      end
      # Set class variables to new values
      @id, @pmid, @type, @title, @authorList, @journal, @meeting, @date, @volume, @issue, @startPage, @endPage, @abstract, @meshHeaders, @url, @state, @language = id, pmid, type, title,authorList, journal, meeting, date, volume, issue, startPage, endPage, abstract, meshHeaders, url, state, language
    end

    # Delegate all other methods to @array (eg <<, +, +length+, +each+, etc).
    # This is a standard Ruby method available to all objects. This delagtion
    # to @array is kind a like having this class inherit from Array also.
    # All array inputs are assumed to be instances of the appropriate class.
    # [+meth+]    The name of the method as a +Symbol+ or +String+.
    # [+args+]    All the arguments to the method will be slurped up into this local variable.
    # [+block+]   If there's a code block provided (e.g. for +each+), it will be here.
    def method_missing(meth, *args, &block)
      @avpHash.send(meth, *args, &block)
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.json_create method.
    # This class method defined by the JSON library allows instances of this class
    # to be created from _parsed_ JSON (i.e. a +Hash+ or +Array+ resulting from
    # JSON::parse). The default implemenation just calls AbstractEntity.from_json
    # which is likely fine for almost all subclasses.
    # [+parsedJsonResult+]  The +Hash+ or +Array+ resulting from parsing the JSON string.
    # [+returns+]           Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.json_create(parsedJsonResult)
      retVal = self.jsonCreateSimple(parsedJsonResult, self::SIMPLE_FIELD_NAMES)
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
                "id" => @id,
                "pmid" => @pmid,
                "type" => @type,
                "title" => @title,
                "authorList" => @authorList,
                "journal" => @journal,
                "meeting" => @meeting,
                "date" => (@date.respond_to?(:rfc822) ? @date.rfc822 : @date.to_s),
                "volume" => @volume,
                "issue" => @issue,
                "startPage" => @startPage,
                "endPage" => @endPage,
                "abstract" => @abstract,
                "meshHeaders" => @meshHeaders,
                "url" => @url,
                "state" => @state,
                "language" => @language,
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
        "id" => @id,
        "pmid" => @pmid,
        "type" => @type,
        "title" => @title,
        "authorList" => @authorList,
        "journal" => @journal,
        "meeting" => @meeting,
        "date" => (@date.respond_to?(:rfc822) ? @date.rfc822 : @date.to_s),           # Should already be a String though
        "volume" => @volume,
        "issue" => @issue,
        "startPage" => @startPage,
        "endPage" => @endPage,
        "abstract" => @abstract,
        "meshHeaders" => @meshHeaders,
        "url" => @url,
        "state" => @state,
        "language" => @language,
        "avpHash" => @avpHash           # Hash
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
    # [+returns+] Tab delimited publication information
    def to_tabbed(attrNames=nil)
      # Construct our header (can change depending on our data)
      retVal = ''

      if(attrNames.nil? )
        retVal << "##{TABBED_HEADER.join("\t")}"
        attrNames = @avpHash.keys.sort
        attrNames.each{|field| retVal << "\t#{esc(field)}" }
      end

      # Construct our data line
      retVal << "#{esc(@id)}\t#{esc(@pmid)}\t#{esc(@type)}\t#{esc(@title)}\t#{esc(@authorList)}\t#{esc(@journal)}\t#{esc(@meeting)}\t#{esc(@date)}\t#{esc(@volume)}\t#{esc(@issue)}\t#{esc(@startPage)}\t#{esc(@endPage)}\t#{esc(@abstract)}\t#{esc(@meshHeaders)}\t#{esc(@url)}\t#{esc(@state)}\t#{esc(@language)}"
      attrNames.each{|field| retVal << "\t#{esc(@avpHash[field])}" }
      retVal << "\n"

      return retVal
    end

    # Class specific method to support Entity creation from tab-delimited data
    # (needs a proper header)
    def self.from_tabbed(data, opts={})
      retVal = PublicationEntityList.from_tabbed(data, opts)
      raise "Unknown problem building entity" if(retVal.nil?)
      raise "Missing data line" if(retVal.size == 0)
      raise "Multiple data lines in tab-delimited data" if(retVal.size > 1)
      return retVal
    end
  end # class PublicationEntity < BRL::Genboree::REST::Data::AbstractEntity

  # PublicationEntityList - Collection/list containing multiple saved publication
  # objects.
  # NOTE: the elements of the list are PublicationEntity objects. Inputs are
  #   assumed to correctly be instances of PublicationEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class PublicationEntityList < BRL::Genboree::REST::Data::EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses
    # may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name
    # friendly) name. This is currently used in generating XML for _lists_...
    # They will be lists of tags of this type (XML makes it hard to express
    # certain natural things easily...)
    RESOURCE_TYPE = :PublicationList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = PublicationEntity
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

      retVal << "##{PublicationEntity::TABBED_HEADER.join("\t")}"

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

    # Class specific method to support EntityList creation from multi-line
    # tab-delimited data (needs a proper header)
    def self.from_tabbed(data, opts={})
      header = nil
      retVal = PublicationEntityList.new(false)
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
          values[17] = {}
          header.each{ |key|
            idx = header.index(key)
            if(key == "id")
              values[0] = dataLine[idx]
            elsif(key == "pmid")
              values[1] = dataLine[idx]
            elsif(key == "type")
              values[2] = dataLine[idx]
            elsif(key == "title")
              values[3] = dataLine[idx]
            elsif(key == "authorList")
              values[4] = dataLine[idx]
            elsif(key == "journal")
              values[5] = dataLine[idx]
            elsif(key == "meeting")
              values[6] = dataLine[idx]
            elsif(key == "date")
              values[7] = dataLine[idx]
            elsif(key == "volume")
              values[8] = dataLine[idx]
            elsif(key == "issue")
              values[9] = dataLine[idx]
            elsif(key == "startPage")
              values[10] = dataLine[idx]
            elsif(key == "endPage")
              values[11] = dataLine[idx]
            elsif(key == "abstract")
              values[12] = dataLine[idx]
            elsif(key == "meshHeaders")
              values[13] = dataLine[idx]
            elsif(key == "url")
              values[14] = dataLine[idx]
            elsif(key == "state")
              values[15] = dataLine[idx]
            elsif(key == "language")
              values[16] = dataLine[idx]
            else
              raise "Duplicate columns in the header" unless(values[17][key].nil?)
              values[17][key] = dataLine[idx] unless(dataLine[idx].empty?)
            end
          }
          retVal << PublicationEntity.new(false, *values)
        end
      }

      # Now return our list
      return retVal
    end
  end # class PublicationEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
