#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/abstract/resources/hub'

module BRL ; module Genboree ; module REST ; module Data

  # HubGenomeEntity - Representation of a Hub Genome
  class HubGenomeEntity < BRL::Genboree::REST::Data::AbstractEntity
    extend BRL::Genboree::Abstract::Resources::Hub

    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :UCSC_HUB ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :HubGenome

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "genome", "description", "organism", "defaultPos", "orderKey"]

    UCSC_FIELD_MAP={
      "genome" => "genome"
    }

    attr_accessor :genome
    attr_accessor :description
    attr_accessor :organism
    attr_accessor :defaultPos
    attr_accessor :orderKey

    # CONSTRUCTOR.
    # @param [String] genome a valid UCSC database name. Each stanza must begin with this tag and each stanza must be separated by an empty line. 
    # @param [String] description
    # @param [String] organism
    # @param [String] defaultPos
    # @param [String] orderKey
    def initialize(doRefs=true, genome='', description=nil, organism=nil, defaultPos=nil, orderKey=4800)
      super(doRefs)
      self.update(genome, description, organism, defaultPos, orderKey)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # @see initialize
    def update(genome, description, organism, defaultPos, orderKey)
      @refs.clear() if(@refs)
      @genome, @description, @organism, @defaultPos, @orderKey = genome, description, organism, defaultPos, orderKey
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes:
    # - this data structure will be used in the serialization implementations
    # @returns A +Hash+ or +Array+ representing this entity (or collection of entities)
    #   wrapped in the standardized Genboree wrapper, if appropriate.
    #   <i>Entity class specific</i>
    def getFormatableDataStruct()
      data =  {
                "genome" => @genome,
                "description" => @description,
                "organism" => @organism,
                "defaultPos" => @defaultPos,
                "orderKey" => @orderKey
              }
      data['refs'] = @refs if(@refs)

      retVal = self.wrap(data)  # Wrap the data content in standard Genboree JSON envelope
      return retVal
    end

    def to_ucsc()
      retVal = ""
      retVal << "genome #{@genome}\n"
      retVal << "trackDb genome/#{@genome}/trackDb.txt"
      return retVal
    end

    # @note Genboree does not support "trackDb" fields other than the conventional {genome}/trackDb.txt
    # @todo potential hub integration will need to resolve @note
    def self.from_ucsc(data)
      retVal = self.parseStanzaDataForEntity(data, BRL::Genboree::REST::Data::HubGenomeEntity)
      return retVal
    end
  end # class HubGenomeEntity < BRL::Genboree::REST::Data::AbstractEntity

  # HubGenomeEntityList - Collection/list containing multiple saved Hub
  # objects.
  # NOTE: the elements of the list are HubGenomeEntity objects. Inputs are
  #   assumed to correctly be instances of HubGenomeEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class HubGenomeEntityList < BRL::Genboree::REST::Data::EntityList 
    extend BRL::Genboree::Abstract::Resources::Hub

    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :UCSC_HUB ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :HubGenomeList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = HubGenomeEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

    def to_ucsc()
      toUcscList = self.map{|entity| entity.to_ucsc() }
      return toUcscList.join("\n\n")
    end

    def self.from_ucsc(data)
      doRefs = false
      retVal = HubGenomeEntityList.new(doRefs)
      entities = self.parseStanzaDataForEntities(data, self::ELEMENT_CLASS)
      retVal.push(*entities)
      return retVal
    end

  end # class HubGenomeEntityList < BRL::Genboree::REST::Data::EntityList

  # HubFullGenomeEntity - Full/Recursive representation of a Hub Genome
  class HubFullGenomeEntity < BRL::Genboree::REST::Data::AbstractEntity
    extend BRL::Genboree::Abstract::Resources::Hub

    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :UCSC_HUB ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :HubFullGenome

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    # @todo here tracks is an Object, a hubTrackEntityList
    SIMPLE_FIELD_NAMES = [ "genome", "description", "organism", "defaultPos", "orderKey", "tracks" ]

    attr_accessor :genome
    attr_accessor :description
    attr_accessor :organism
    attr_accessor :defaultPos
    attr_accessor :orderKey
    attr_accessor :tracks

    # CONSTRUCTOR.
    # @param genome [String] a valid UCSC database name. Each stanza must begin with this tag and each stanza must be separated by an empty line. 
    # @param trackDb [String] the relative path of the trackDb file for the assembly designated by the genome tag. By 
    #   convention, the trackDb file is located in a subdirectory of the hub directory. However, the trackDb tag may 
    #   also specify a complete URL.
    # @param tracks [Array<Hash>] array of hubTrackEntity formattable data structs
    def initialize(doRefs=true, genome='', description=nil, organism=nil, defaultPos=nil, orderKey=4800, tracks=[])
      super(doRefs)
      self.update(genome, description, organism, defaultPos, orderKey, tracks)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # @see initialize
    def update(genome, description, organism, defaultPos, orderKey, tracks)
      @refs.clear() if(@refs)
      @genome, @description, @organism, @defaultPos, @orderKey, @tracks = genome, description, organism, defaultPos, orderKey, tracks
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes:
    # - this data structure will be used in the serialization implementations
    # @returns A +Hash+ or +Array+ representing this entity (or collection of entities)
    #   wrapped in the standardized Genboree wrapper, if appropriate.
    #   <i>Entity class specific</i>
    def getFormatableDataStruct()
      data =  {
                "genome" => @genome,
                "description" => @description,
                "organism" => @organism,
                "defaultPos" => @defaultPos,
                "orderKey" => @orderKey,
                "tracks" => @tracks
              }
      data['refs'] = @refs if(@refs)

      retVal = self.wrap(data)  # Wrap the data content in standard Genboree JSON envelope
      return retVal
    end

    def to_ucsc()
      msg = "UCSC stanza format is not supported for the full/recursive hub genome, try detailed=hub_summary"
      err = BRL::Genboree::GenboreeError.new(:'Not Implemented', msg)
      raise err
    end

    def self.from_ucsc(data)
      msg = "UCSC stanza format is not supported for the full/recursive hub genome, try detailed=hub_summary"
      err = BRL::Genboree::GenboreeError.new(:'Not Implemented', msg)
      raise err
    end
  end # class HubFullGenomeEntity < BRL::Genboree::REST::Data::AbstractEntity

  # HubFullGenomeEntityList - Collection/list containing multiple saved Hub
  # objects.
  # NOTE: the elements of the list are HubGenomeEntity objects. Inputs are
  #   assumed to correctly be instances of HubGenomeEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class HubFullGenomeEntityList < BRL::Genboree::REST::Data::EntityList
    extend BRL::Genboree::Abstract::Resources::Hub
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :UCSC_HUB ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :HubFullGenomeList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = HubFullGenomeEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

    def to_ucsc()
      msg = "UCSC stanza format is not supported for the full/recursive hub genome, try detailed=hub_summary"
      err = BRL::Genboree::GenboreeError.new(:'Not Implemented', msg)
      raise err
    end

    def self.from_ucsc(data)
      msg = "UCSC stanza format is not supported for the full/recursive hub genome, try detailed=hub_summary"
      err = BRL::Genboree::GenboreeError.new(:'Not Implemented', msg)
      raise err
    end
  end # class HubFullGenomeEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
