require 'brl/genboree/rest/data/entity'
require 'brl/genboree/rest/utilities/classifier'

module BRL; module Genboree; module REST; module Data
  class GbToRmMapEntity < AbstractEntity
    # @interface
    RESOURCE_TYPE = :GbToRmMap
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join(".")}"
    SIMPLE_FIELD_NAMES = ["gbType", "gbRsrc", "rmType", "rmRsrc"]
    SIMPLE_FIELD_VALUES = ["", nil, "", nil]

    # field names for associated entries in the SQL table this class helps with
    RECORD_FIELD_NAMES = ["gbGroup"] + SIMPLE_FIELD_NAMES

    # only support a subset of all possible Genboree resources for mappings
    SUPPORTED_GB_TYPES = ["group", "database", "file", "track", "kbCollection", "kbDoc", "kbDocProp", "kbQuestion", "kbTemplate"]

    attr_accessor :gbType
    attr_accessor :gbRsrc
    attr_accessor :rmType
    attr_accessor :rmRsrc

    def initialize(doRefs=true, gbType='', gbRsrc='', rmType='', rmRsrc='')
      super(doRefs)
      update(gbType, gbRsrc, rmType, rmRsrc)
    end

    # Create an entity from an associated database record from BRL::Genboree::DBUtil
    # @param [Hash] dbRec 
    def self.fromRecord(dbRec)
      jsonCreateSimple(dbRec)
    end

    # Create a database record from an object of this class
    def self.toRecord(groupName, entity)
      [groupName] + entity.flatten
    end

    # Infer gbType from gbRsrc
    # @param [String] gbRsrc
    # @return [String, NilClass] 
    # @note SQL enum this class helps with has been made to fit RSRC_TYPES -- can easily add
    #   a mapping if that becomes no longer possible in the future
    def self.classifyGbRsrc(gbRsrc)
      rv = nil
      classifier = BRL::Genboree::REST::Utilities::Classifier.new() # little overhead if resources already loaded
      rsrcType = classifier.classifyUrl(gbRsrc)
      rv = rsrcType if(SUPPORTED_GB_TYPES.include?(rsrcType))
      return rv
    end

    # Infer rmType from rmRsrc:
    #   keys define allowed types, their values provide a pattern to match a url against and a priority
    #   that patterns should be attempted in
    # @todo some of these Redmine resources have reserve words such as wiki/Index which is not actually a wiki
    RM_URL_TYPES = {
      # project http://10.15.55.128/genboreeKB_dev/projects/ajb-kb-test2
      "project" => {
        :priority => 1,
        :pattern => %r{/projects/[^/\?]+},
        :type => "project",
      },
      # issue http://10.15.55.128/genboreeKB_dev/issues/6
      "issue" => {
        :priority => 1,
        :pattern => %r{/issues/[^/\?]+},
        :type => "issue"
      },
      # wiki http://10.15.55.128/genboreeKB_dev/projects/ajb-kb-test2/wiki/Test
      "wiki" => {
        :priority => 2,
        :pattern => %r{/projects/[^/\?]+/wiki/[^/\?]+},
        :type => "wiki"
      },
      # board http://10.15.55.128/genboreeKB_dev/projects/ajb-kb-test2/boards/8
      "board" => {
        :priority => 2,
        :pattern => %r{/projects/[^/\?]+/boards/[^/\?]+},
        :type => "board"
      },
      # topic http://10.15.55.128/genboreeKB_dev/boards/8/topics/14
      "topic" => {
        :priority => 3,
        :pattern => %r{/boards/[^/\?]+/topics/[^/\?]+},
        :type => "topic"
      }
    }

    # Infer rmType from rmRsrc
    # @param [String] rmRsrc url
    # @return [String, NilClass] key of RM_URL_TYPES or nil if no matching type found
    # @see RM_URL_TYPES
    def self.classifyRmRsrc(rmRsrc)
      rv = nil
      uriObj = URI.parse(rmRsrc)
      typeObjs = RM_URL_TYPES.values.dup()
      typeObjs.sort! { |obj1, obj2| obj2[:priority] <=> obj1[:priority] }
      matchObj = typeObjs.find { |typeObj|
        typeObj[:pattern].match(uriObj.path)
      }
      rv = matchObj[:type] unless(matchObj.nil?)
      return rv
    end

    def flatten()
      return SIMPLE_FIELD_NAMES.map { |field| self.send(field.to_sym) }
    end

    # @interface
    def update(gbType, gbRsrc, rmType, rmRsrc)
      @gbType = gbType
      @gbRsrc = gbRsrc
      @rmType = rmType
      @rmRsrc = rmRsrc
    end

    # @interface
    def getFormatableDataStruct()
      data = {
        "gbType" => @gbType,
        "gbRsrc" => @gbRsrc,
        "rmType" => @rmType,
        "rmRsrc" => @rmRsrc
      }
      data['refs'] = @refs if(@refs)
      retVal = self.wrap(data)
      return retVal
    end
  end

  class GbToRmMapEntityList < EntityList
    RESOURCE_TYPE = :GbToRmMapList
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}" 
    ELEMENT_CLASS = GbToRmMapEntity
  end
end; end; end; end
