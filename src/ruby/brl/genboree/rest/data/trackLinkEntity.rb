#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data
  # --------------------------------------------------------------------------
  # CLASS: TrackLinkEntity
  # - Representation of a track link item, url and label
  # Common Interface Methods:
  #   . to_json(), to_yaml(), to_xml()        <-- default implementations from parent class
  #   . from_json(), from_yaml(), from_xml()  <-- default implementations from parent class
  #   . getFormatableDataStruct()             <-- OVERRIDDEN
  # --------------------------------------------------------------------------
  class TrackLinkEntity < AbstractEntity
    # Override key class constants used by inherited methods
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    RESOURCE_TYPE = :TrkLink

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    SIMPLE_FIELD_NAMES = [ "url", "linkText" ]

    attr_accessor :url, :linkText

    # CONSTRUCTOR.
    # [+doRefs+] - do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # +url+ - full URL
    # +linkText+ - link label; may contain HTML
    # +refs+ - the refs hash
    def initialize(doRefs=true, url="", linkText="")
      super(doRefs)
      self.update(url, linkText)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    def update(url, linkText)
      @refs.clear() if(@refs)
      @url, @linkText = url, linkText
    end

    # GENBOREE INTERFACE. Get an Array that represents this entity.
    def getFormatableDataStruct()
      data =  {
                "url" => @url,
                "linkText" => @linkText
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
        "url" => @url,
        "linkText" => @linkText
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end
  end # class TrackLinkEntity < AbstractEntity

  # --------------------------------------------------------------------------
  # CLASS: TrackLinkEntityList
  # - Object containing an array of TrackLinkEntity objects.
  # - NOTE: the elements of this array are -TrackLinkEntity- objects. Inputs are
  #         assumed to correctly be instances of TrackLinkEntity.
  # Common Interface Methods:
  #   . to_json(), to_yaml(), to_xml()        <-- default implementations from parent class
  #   . from_json()                           <-- OVERRIDDEN
  #   . from_yaml(), from_xml()               <-- default implementations from parent class
  #   . getFormatableDataStruct()             <-- default implementations from parent class
  # --------------------------------------------------------------------------
  class TrackLinkEntityList < EntityList
    # Override key class constants used by inherited methods
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    RESOURCE_TYPE = :TrkLinkList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    ELEMENT_CLASS = TrackLinkEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

    # CONSTRUCTOR.
    # [+doRefs+] - do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # +array+ - an Array of TrackLinkEntity instances
    def initialize(doRefs=true, array=[])
      super(doRefs, array)
    end
  end # class TrackLinkEntityList < EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
