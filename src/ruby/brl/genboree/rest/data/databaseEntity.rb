#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/rest/data/entrypointEntity'

module BRL ; module Genboree ; module REST ; module Data

  # DetailedDatabaseEntity - Representation of a user database: its name, species, version, entrypoints
  # (collection of DetailedEntrypointEntity objects)
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml       -- default implementations from parent class
  # - AbstractEntity.json_create, #getFormatableDataStruct  -- OVERRIDDEN
  class DetailedDatabaseEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :DbDetailed

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "name", "species", "version", "description", "refSeqId", "gbKey", "public" ]

    # Name of the user database.
    attr_accessor :name
    # RefSeqId of the user database (exposed to allow API users to construct links to browser, tabular, VGP, etc, views.
    attr_accessor :refSeqId
    # Species of the genome for the user database.
    attr_accessor :species
    # Version (usually assembly version) for the user database.
    attr_accessor :version
    # Description text for the user database.
    attr_accessor :description
    # Collection of entrypoints (chromosomes) in this user database (instance of DetailedEntrypointEntityList)
    attr_accessor :entrypoints
    # 'Unlocked' databases have a gbKey
    attr_accessor :gbKey
    # public: is database public: true or false (boolean)
    attr_accessor :public

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+name+] [optional; default=""] Name of the user database.
    # [+refSeqId+] [optional; default=""] RefSeqId of the user database (exposed to allow API users to construct links to browser, tabular, VGP, etc, views.
    # [+species+] [optional; default=""] Species of the genome for the user database.
    # [+version+] [optional; default=""] Version (usually assembly version) for the user database.
    # [+entrypoints+] [optional; default=DetailedEntrypointEntityList.new()] Collection of entrypoints (chromosomes) in this user database (instance of DetailedEntrypointEntityList)
    # [+gbKey+] unlock key for the database [default: empty string]
    # [+public+] [default: false]
    def initialize(doRefs=true, name="", species="", version="", description="", refSeqId="",  gbKey='', public=false, entrypoints=DetailedEntrypointEntityList.new())
      super(doRefs)
      self.update(name, species, version, description, refSeqId, entrypoints, gbKey, public)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+name+] [optional; default=""] Name of the user database.
    # [+species+] [optional; default=""] Species of the genome for the user database.
    # [+version+] [optional; default=""] Version (usually assembly version) for the user database.
    # [+refSeqId+] [optional; default=""] RefSeqId of the user database (exposed to allow API users to construct links to browser, tabular, VGP, etc, views.
    # [+entrypoints+] [optional; default=<tt>DetailedEntrypointEntityList.new()</tt>] Collection of entrypoints (chromosomes) in this user database (instance of DetailedEntrypointEntityList)
    def update(name, species, version, description, refSeqId, entrypoints, gbKey, public)
      @entrypoints.clear() unless(@entrypoints.nil?)
      @refs.clear() if(@refs)
      entrypoints = DetailedEntrypointEntityList.new() if(entrypoints.nil?)
      @name, @refSeqId, @species, @version, @description, @entrypoints, @gbKey, @public = name, refSeqId, species, version, description, entrypoints, gbKey, public
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes
    # - this data structure will be used in the serialization implementations
    # [+returns+] A +Hash+ or +Array+ representing this entity (or collection of entities)
    #             wrapped in the standardized Genboree wrapper, if appropriate.
    #             <i>Entity class specific</i>
    def getFormatableDataStruct()
      @entrypoints.doWrap = false
      @entrypoints.each { |obj| obj.doWrap = false } # these objects are within an Array, they should NOT each be wrapped
      data =  {
                "name" => @name,
                "refSeqId" => @refSeqId,
                "species" => @species,
                "version" => @version,
                "description" => @description,
                "entrypoints" => @entrypoints
              }
      data['gbKey'] = @gbKey if(@gbKey)
      data['public'] = @public
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
        "name"        => @name,
        "refSeqId"    => @refSeqId,
        "species"     => @species,
        "version"     => @version,
        "description" => @description,
        "entrypoints" => @entrypoints
      }
      # Optional fields with basic Ruby types (String, Hash, Array, Fixnum, Float, boolean, etc)
      data['gbKey']  = @gbKey if(@gbKey)
      data['public'] = @public
      # Fields whose values are AbstractEntity subclass objects
      data['entrypoints'] = @entrypoints.toStructuredData(false)

      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
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
      #$stderr.puts("parsedJsonResult: #{parsedJsonResult.inspect}")
      unless(retVal.nil?)
        # Get content and status info from Common Wrapper if present...ff not, content will be parsedJsonResult
        content = AbstractEntity.extractParsedContent(parsedJsonResult)
        # Create entity based on content, if content looks correct. Else empty.
        entrypoints = DetailedEntrypointEntityList.new(content["entrypoints"])
        retVal.entrypoints = entrypoints unless(entrypoints.nil?)
      end
      return retVal
    end
  end # class DetailedDatabaseEntity < BRL::Genboree::REST::Data::AbstractEntity
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
