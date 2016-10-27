#!/usr/bin/env ruby
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/rest/data/kbDocEntity'

module BRL ; module Genboree ; module REST ; module Data

  class KbDocVersionEntity < BRL::Genboree::REST::Data::KbDocEntity

    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :KbDocVersion

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes
    # - this data structure will be used in the serialization implementations
    # @note May need to check and remove keys added by MongoDB like "_id" or similar.
    # @return [Hash,Array] A {Hash} or {Array} representing this entity (or collection of entities)
    #   wrapped in the standardized Genboree wrapper, if appropriate. _Entity class specific_
    def getFormatableDataStruct()
      wrappedData = super()
      data = AbstractEntity.extractParsedContent(wrappedData)

      # in addition to parent's object cleaning, delete nested _id and other doc refs
      kbDoc = BRL::Genboree::KB::KbDoc.new(data)
      kbDoc.delProp("versionNum.properties.docRef") rescue nil
      kbDoc.delProp("versionNum.properties.content.value._id") rescue nil
      retVal = self.wrap(kbDoc.to_serializable)  # Wrap the data content in standard Genboree JSON envelope
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
      wrappedData = super(wrap)
      data = AbstractEntity.extractParsedContent(wrappedData)

      # in addition to parent's object cleaning, delete nested _id and other doc refs
      kbDoc = BRL::Genboree::KB::KbDoc.new(data)
      docRef = kbDoc.delProp("versionNum.docRef") rescue nil
      contentProp = kbDoc.getPropVal("versionNum.content")
      if(contentProp.acts_as?(Hash))
        contentProp.delete('_id')
        contentProp.delete(:_id)
      end
      rubyData = kbDoc.to_serializable
      retVal = (wrap ? self.wrap(rubyData) : rubyData)
      return retVal
    end
  end # class KbDocVersionEntity < BRL::Genboree::REST::Data::AbstractEntity

  class KbDocVersionEntityList < BRL::Genboree::REST::Data::KbDocEntityList
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :KbDocVersionList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = KbDocVersionEntity
  end # class KbDocVersionEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
