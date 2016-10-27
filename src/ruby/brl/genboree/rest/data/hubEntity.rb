#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/abstract/resources/hub'

module BRL ; module Genboree ; module REST ; module Data

  # HubEntity - Representation of a Hub
  class HubEntity < BRL::Genboree::REST::Data::AbstractEntity
    extend BRL::Genboree::Abstract::Resources::Hub

    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :UCSC_HUB ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :Hub

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "name", "shortLabel", "longLabel", "email", "public" ]

    # map UCSC field names to Genboree field names where a mapping exists
    # fields in SIMPLE_FIELD_NAMES that are not in this Hash MUST have a default in the constructor
    # fields in the UCSC representation that do not have a counterpart in the Genboree representation
    #   are either FIXED such as genomesFile, which Genboree ALWAYS sets to genomes.txt, or are not
    #   currently supported, such as descriptionUrl
    UCSC_FIELD_MAP = {
      "hub" => "name",
      "shortLabel" => "shortLabel",
      "longLabel" => "longLabel",
      "email" => "email"
    }

    attr_accessor :name
    attr_accessor :shortLabel
    attr_accessor :longLabel
    attr_accessor :email
    attr_accessor :public

    # CONSTRUCTOR.
    # @param [String] name a single-word name of the directory containing the track hub files. Not displayed to hub users. This must be the first line in the hub.txt file.
    # @param [String] shortLabel the short name for the track hub. Suggested maximum length is 17 characters. Displayed
    #   as the hub name on the Track Hubs page and the track group name on the browser tracks page.
    # @param [String] longLabel a longer descriptive label for the track hub. Suggested maximum length is 80 characters.
    #   Displayed in the description field on the Track Hubs page
    # @param [String] email the contact to whom questions regarding the track hub should be directed
    # @param [0, 1] public flag indicating if the hub should be publically accessible or not
    def initialize(doRefs=true, name='', shortLabel='', longLabel='', email='', public=0)
      super(doRefs)
      self.update(name, shortLabel, longLabel, email, public)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # @see initialize
    def update(name, shortLabel, longLabel, email, public)
      @refs.clear() if(@refs)
      @name, @shortLabel, @longLabel, @email, @public = name, shortLabel, longLabel, email, public
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes:
    # - this data structure will be used in the serialization implementations
    #
    # @return A +Hash+ or +Array+ representing this entity (or collection of entities)
    #   wrapped in the standardized Genboree wrapper, if appropriate.
    #   <i>Entity class specific</i>
    def getFormatableDataStruct()
      data =  {
                "name" => @name,
                "shortLabel" => @shortLabel,
                "longLabel" => @longLabel,
                "email" => @email,
                "public" => @public
              }
      data['refs'] = @refs if(@refs)

      retVal = self.wrap(data)  # Wrap the data content in standard Genboree JSON envelope
      return retVal
    end

    # @return UCSC stanza format of this entity
    def to_ucsc()
      retVal = ""
      retVal << "hub #{@name}\n"
      retVal << "shortLabel #{@shortLabel}\n"
      retVal << "longLabel #{@longLabel}\n"
      retVal << "genomesFile genomes.txt\n"
      retVal << "email #{@email}"
      return retVal
    end

    # @param data [String] 2 column data format e.g.
    #   hub hub_name
    #   shortLabel hub_short_label
    #   longLabel hub_long_label
    #   genomesFile genomes_filelist
    #   email email_address
    # @return [HubEntity, nil] either the entity parsed from data provided or nil if an uncaught error prevented
    #   parsing of the data to that entity
    def self.from_ucsc(data)
      retVal = self.parseStanzaDataForEntity(data, BRL::Genboree::REST::Data::HubEntity)
      return retVal
    end
  end # class HubEntity < BRL::Genboree::REST::Data::AbstractEntity

  # HubEntityList - Collection/list containing multiple saved Hub
  # objects.
  # NOTE: the elements of the list are HubEntity objects. Inputs are
  #   assumed to correctly be instances of HubEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class HubEntityList < BRL::Genboree::REST::Data::EntityList
    extend BRL::Genboree::Abstract::Resources::Hub

    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :UCSC_HUB ]

    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :HubList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = HubEntity

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
  end # class HubEntityList < BRL::Genboree::REST::Data::EntityList

  # HubFullGenomeEntity - Full/Recursive representation of a Hub Genome
  class HubFullEntity < BRL::Genboree::REST::Data::AbstractEntity
    extend BRL::Genboree::Abstract::Resources::Hub

    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :UCSC_HUB ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :HubFull

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    # @todo here tracks is an Object, a hubTrackEntityList
    SIMPLE_FIELD_NAMES = [ "name", "shortLabel", "longLabel", "email", "public", "genomes" ]

    attr_accessor :name
    attr_accessor :shortLabel
    attr_accessor :longLabel
    attr_accessor :email
    attr_accessor :public
    attr_accessor :genomes

    # CONSTRUCTOR.
    # @param [String] name a single-word name of the directory containing the track hub files. Not displayed to hub users. This must be the first line in the hub.txt file.
    # @param [String] shortLabel the short name for the track hub. Suggested maximum length is 17 characters. Displayed
    #   as the hub name on the Track Hubs page and the track group name on the browser tracks page.
    # @param [String] longLabel a longer descriptive label for the track hub. Suggested maximum length is 80 characters.
    #   Displayed in the description field on the Track Hubs page
    # @param [String] email the contact to whom questions regarding the track hub should be directed
    # @param [0, 1] public a binary flag indicating if this hub should be public in Genboree or not
    # @param [Array<Hash>] genomes the underlying genome entities contained in this hub
    def initialize(doRefs=true, name='', shortLabel='', longLabel='', email='', public=0, genomes=[])
      super(doRefs)
      self.update(name, shortLabel, longLabel, email, public, genomes)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # @see initialize
    def update(name, shortLabel, longLabel, email, public, genomes)
      @refs.clear() if(@refs)
      @name, @shortLabel, @longLabel, @email, @public, @genomes = name, shortLabel, longLabel, email, public, genomes
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes:
    # - this data structure will be used in the serialization implementations
    #
    # @return A +Hash+ or +Array+ representing this entity (or collection of entities)
    #   wrapped in the standardized Genboree wrapper, if appropriate.
    #   <i>Entity class specific</i>
    def getFormatableDataStruct()
      data =  {
                "hub" => @hub,
                "shortLabel" => @shortLabel,
                "longLabel" => @longLabel,
                "email" => @email,
                "public" => @public,
                "genomes" => @genomes
              }
      data['refs'] = @refs if(@refs)

      retVal = self.wrap(data)  # Wrap the data content in standard Genboree JSON envelope
      return retVal
    end

    # NOT IMPLEMENTED
    def to_ucsc()
      msg = "UCSC stanza format is not supported for the full/recursive hub genome, try detailed=hub_summary"
      err = BRL::Genboree::GenboreeError.new(:'Not Implemented', msg)
      raise err
    end

    # NOT IMPLEMENTED
    def self.from_ucsc(data)
      msg = "UCSC stanza format is not supported for the full/recursive hub genome, try detailed=hub_summary"
      err = BRL::Genboree::GenboreeError.new(:'Not Implemented', msg)
      raise err
    end
  end # class hubFullEntity < BRL::Genboree::REST::Data::AbstractEntity

  # HubFullEntityList - Collection/list containing multiple saved Full Hub
  # objects.
  # NOTE: the elements of the list are HubEntity objects. Inputs are
  #   assumed to correctly be instances of HubFullEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class HubFullEntityList < BRL::Genboree::REST::Data::EntityList
    extend BRL::Genboree::Abstract::Resources::Hub

    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :UCSC_HUB ]

    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :HubFullList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = HubFullEntity

    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

    # NOT IMPLEMENTED
    def to_ucsc()
      msg = "UCSC stanza format is not supported for the full/recursive hub genome, try detailed=hub_summary"
      err = BRL::Genboree::GenboreeError.new(:'Not Implemented', msg)
      raise err
    end

    # NOT IMPLEMENTED
    def self.from_ucsc(data)
      msg = "UCSC stanza format is not supported for the full/recursive hub genome, try detailed=hub_summary"
      err = BRL::Genboree::GenboreeError.new(:'Not Implemented', msg)
      raise err
    end

  end # class HubEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
