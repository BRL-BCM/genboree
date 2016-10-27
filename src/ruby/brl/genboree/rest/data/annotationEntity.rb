#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data

  # AnnotationEntity - Representation of a genomic annotation; recommend using just 1 instance and
  # streaming data through it as a filter (since probably you have lots).
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml       -- default implementations from parent class
  # - #json_create, #getFormatableDataStruct  -- OVERRIDDEN
  class AnnotationEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :LFF, :GFF, :GFF3, :BED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :Anno

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES =  [
                            "lffClass", "lffName", "lffType", "lffSubtype", "lffChrom",
                            "lffStart", "lffStop", "lffStrand", "lffPhase", "lffScore",
                            "lffQStart", "lffQStop"
                          ]

    # Annotation class. (core LFF field)
    attr_accessor :lffClass
    # Annotation name. (core LFF field)
    attr_accessor :lffName
    # Annotation type. Track name is <tt>type:subtype</tt> (core LFF field)
    attr_accessor :lffType
    # Annotation subtype. Track name is <tt>type:subtype</tt> (core LFF field)
    attr_accessor :lffSubtype
    # Annotation chromosome/entrypoint. (core LFF field)
    attr_accessor :lffChrom
    # Annotation start coordinate (1-based, fully closed). (core LFF field)
    attr_accessor :lffStart
    # Annotation stop coordinate (1-based, fully closed). (core LFF field)
    attr_accessor :lffStop
    # Annotation strand (+ or -). (core LFF field)
    attr_accessor :lffStrand
    # Annotation phase (0,1,2). (core LFF field)
    attr_accessor :lffPhase
    # Annotation score. (core LFF field)
    attr_accessor :lffScore
    # Annotation start coordinate on the query, if any. (core LFF field)
    attr_accessor :lffQStart
    # Annotation stop coordinate on the query, if any. (core LFF field)
    attr_accessor :lffQStop
    # Annotation's custom attribute-value pairs as a +Hash+.
    attr_accessor :avpHash
    # Annotation's custom sequence field.
    attr_accessor :sequence
    # Annotation's free format comments field.
    attr_accessor :comments

    # CONSTRUCTOR.
    # [+lffClass+] [optional; default=""] Annotation class. (core LFF field)
    # [+lffName+] [optional; default=""] Annotation name. (core LFF field)
    # [+lffType+] [optional; default=""] Annotation type. Track name is <tt>type:subtype</tt> (core LFF field)
    # [+lffSubtype+] [optional; default=""] Annotation chromosome/entrypoint. (core LFF field)
    # [+lffChrom+] [optional; default=""] Annotation start coordinate (1-based, fully closed). (core LFF field)
    # [+lffStart+] [optional; default=1] Annotation stop coordinate (1-based, fully closed). (core LFF field)
    # [+lffStop+] [optional; default=1] Annotation stop coordinate (1-based, fully closed). (core LFF field)
    # [+lffStrand+] [optional; default="+"] Annotation strand (+ or -). (core LFF field)
    # [+lffPhase+] [optional; default=0] Annotation phase (0,1,2). (core LFF field)
    # [+lffScore+] [optional; default=1.0] Annotation score. (core LFF field)
    # [+lffQStart+] [optional; default="."] Annotation start coordinate on the query, if any. (core LFF field)
    # [+lffQStop=+] [optional; default="."] Annotation stop coordinate on the query, if any. (core LFF field)
    # [+avpArray+] [optional; default=AVPHash.new()] Annotation's custom sequence field. Instance of AVPHash.
    # [+sequence+] [optional; default=""] Annotation's custom sequence field.
    # [+comments+] [optional; default=""] Annotation's free format comments field.
    def initialize(lffClass="", lffName="", lffType="", lffSubtype="", lffChrom="", lffStart=1, lffStop=1,
                  lffStrand="+", lffPhase=0, lffScore=1.0, lffQStart=".", lffQStop=".",
                  avpArray=AVPHash.new(), sequence="", comments="")
      super(false)
      avpArray = AVPHash.new() if(avpArray.nil?)
      self.update(lffClass, lffName, lffType, lffSubtype, lffChrom, lffStart, lffStop,
                  lffStrand, lffPhase, lffScore, lffQStart, lffQStop, avpArray, sequence, comments)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+lffClass+] [optional; default=""] Annotation class. (core LFF field)
    # [+lffName+] [optional; default=""] Annotation name. (core LFF field)
    # [+lffType+] [optional; default=""] Annotation type. Track name is <tt>type:subtype</tt> (core LFF field)
    # [+lffSubtype+] [optional; default=""] Annotation chromosome/entrypoint. (core LFF field)
    # [+lffChrom+] [optional; default=""] Annotation start coordinate (1-based, fully closed). (core LFF field)
    # [+lffStart+] [optional; default=1] Annotation stop coordinate (1-based, fully closed). (core LFF field)
    # [+lffStop+] [optional; default=1] Annotation stop coordinate (1-based, fully closed). (core LFF field)
    # [+lffStrand+] [optional; default="+"] Annotation strand (+ or -). (core LFF field)
    # [+lffPhase+] [optional; default=0] Annotation phase (0,1,2). (core LFF field)
    # [+lffScore+] [optional; default=1.0] Annotation score. (core LFF field)
    # [+lffQStart+] [optional; default="."] Annotation start coordinate on the query, if any. (core LFF field)
    # [+lffQStop=+] [optional; default="."] Annotation stop coordinate on the query, if any. (core LFF field)
    # [+avpArray+] [optional; default=AVPHash.new()] Annotation's custom sequence field. Instance of AVPHash.
    # [+sequence+] [optional; default=""] Annotation's custom sequence field.
    # [+comments+] [optional; default=""] Annotation's free format comments field.
    def update( lffClass, lffName, lffType, lffSubtype, lffChrom, lffStart, lffStop,
                lffStrand, lffPhase, lffScore, lffQStart, lffQStop, avpArray, sequence, comments)
      @refs.clear() if(@refs)
      @avpHash.clear() unless(@avpHash.nil?)
      avpArray = AVPHash.new() if(avpArray.nil?)
      @lffClass, @lffName, @lffType, @lffSubtype, @lffChrom, @lffStart, @lffStop =
        lffClass, lffName, lffType, lffSubtype, lffChrom, lffStart, lffStop
      @lffStrand, @lffPhase, @lffScore, @lffQStart, @lffQStop, @avpHash =
        lffStrand, lffPhase, lffScore, lffQStart, lffQStop, avpArray
      @sequence, @comments = sequence, comments
    end

    # Special converter for return the annotation as a :LFF representation
    # [+returns+] This annotation in LFF format, as a +String+
    def to_lff()
      avpStr = if(@avpHash.nil?): '' else @avpHash.to_s end
      retVal = "#{@lffClass}\t#{@lffName}\t#{@lffType}\t#{@lffSubtype}\t#{@lffChrom}\t#{@lffStart}\t#{@lffStop}\t"
      retVal << "#{@lffStrand}\t#{@lffPhase}\t#{@lffScore}\t#{@lffQStart}\t#{@lffQstop}\t#{avpStr}\t#{@sequence}\t"
      retVal << "#{@comments}"
      return retVal
    end

    # Special converter for return the annotation as a :GFF representation
    # [+returns+] This annotation in GFF format, as a +String+
    def to_gff()
      avpStr = if(@avpHash.nil?): '' else @avpHash.to_s(:GTF) end
      avpStr = "transcript_id #{@lffName.gsub(/;/, '_')}; #{avpStr}"
      retVal = "#{@lffChrom}\t#{@lffType}\t#{@lffSubtype}\t#{@lffStart}\t#{@lffStop}\t#{@lffScore}\t#{@lffStrand}\t#{@lffPhase}\t#{avpStr}"
      return retVal
    end

    # Special converter for return the annotation as a :BED representation
    # [+returns+] This annotation in BED format, as a +String+
    def to_bed()
      retVal = "#{@lffChrom}\t#{@lffStart}\t#{@lffStop}\t#{@lffName}\t#{@lffScore}\t#{@lffStrand}"
      return retVal
    end
  end # class AnnotationEntity < BRL::Genboree::REST::Data::AbstractEntity

  # AVPHash - Helper class for storing the attribute-value pairs (AVPs) for a particular annotation.
  # - NOTE: NOT AN ENTITY AT THIS POINT, JUST A FANCY HASH. Maybe will be one later if needed.
  class AVPHash < Hash
    # Converts the hash to a suitable string format. Default is a format compatible with LFF.
    # [+format+] [optional; default=:LFF] Format to be compatible with. Default is :LFF, but :GFF and :BED also valid
    def to_s(format=:LFF)
        retVal = ""
      if(format == :LFF or format == :GTF or format == :GFF3)
        self.each_key { |attribute|
          value = self[attribute]
          value = value.to_s.gsub!(/;/, "_")
          if(format == :LFF)
            attribute.gsub!(/;|=/, "_")
            retVal << "#{attribute}=#{value}; "
          elsif(format == :GTF or format == :GFF or format == :GFF3) # these are synonyms esssentialy (GTF == GFF2+)
            attribute.gsub!(/ ;/, "_")
            retVal << "#{attribute} #{value}; "
          end
        }
      else # BED can't do AVPs, so nil; same for unknown formats
        retVal = nil
      end
      return retVal
    end
  end # class AVPHash < Hash
end ; end ; end ; end # module BRL ; module Genboree ; module REST ; module Data
