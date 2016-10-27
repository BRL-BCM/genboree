#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################

require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/dataStructure/singletonJsonFileCache'

module BRL ; module Genboree ; module Helpers ; module WgsMicrobiome
  # Helper to get info about WGS Microbiome columns/AVPs, using an config-based
  #   approach. In addtition to getting basic lists & info, can be used and/or enhanced to
  #   help with validation and/or programmatic metadata file dumping. (Rather than hardcoding
  #   all the specific little rules in a bunch of Ruby code, generics apply rules systematicaly
  #   and you get what you need).
  # The config-file which defines attribute<->column info has a specific structure:
  #
  # {
  #   "{attribute}" :
  #   {
  #     "type"        : "{string|float|uriStr|usrCsv|etc}",
  #     "columnInfo"  :
  #     {
  #       "{colRegexp}" :  // <- implicitly wrapped in ^$
  #       {
  #         "fromUser"    : {true|false},
  #         "required"  : [ {Array of toolIdStrs needing this column, if any} ],
  #         "optional"  : [ {Array of toolIdStrs which may take this column, if any} ]
  #       },
  #       ... {more colRegexp and objects} ...
  #     }
  #   },
  #   ... {more attributes and objects} ...
  # }
  class AvpColInfo
    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------

    # Local shortcut to {BRL::DataStructure::SingletonJsonFileCache}
    # @return [Class]
    JsonFileCache = BRL::DataStructure::SingletonJsonFileCache

    # ------------------------------------------------------------------
    # ACCESSORS
    # ------------------------------------------------------------------

    # @return [BRL::Genboree::GenboreeConfig] the loaded @GenboreeConfig@ object in
    #   use by this object.
    attr_accessor :gbConf
    # @return [String] the location of the WGS AVP<->Column configuation file.
    attr_reader :avpColConfFile

    # ------------------------------------------------------------------
    # INSTANCE METHODS
    # ------------------------------------------------------------------

    # CONSTRUCTOR.
    # @param [BRL::Genboree::GenboreeConfig] gbConf If provided, an already loaded @GenboreeConfig@
    #   object which will be reused rather than creating and loading a new config object.
    def initialize(gbConf=nil)
      # GenboreeConfig. Create if not provided.
      @gbConf = (gbConf || BRL::Genboree::GenboreeConfig.load() )
      # Need to ensure we have the gbSnifferFormatConf file cached. It's a singleton
      @avpColConfFile = @gbConf.wgsMicrobiomeAvpColConf
      unless(@avpColConfFile and File.readable?(@avpColConfFile))
        raise "ERROR: There is a problem iwth the 'wgsMicrobiomeAvpColConf' property in your Genboree config properties file. Either this property is missing or points to a file that cannot be read. Details:\n  - Genboree config file: #{@gbConf.configFile.inspect}\n  - Value of gbSnifferFormatConf property: #{@avpColConfFile.inspect}"
      end
      JsonFileCache.cacheFile(:wgsMicrobiomeAvpColConf, @avpColConfFile)
    end

    # Gets the list of Genboree attributes used to store WGS microbiome metadata column info.
    # @return [Array<String>] the attribute names
    def attributeList()
      avpColConfs = getAvpColConfs()
      return avpColConfs.keys
    end

    # Gets configuration object (Hash; structured data) for a given Genboree attribute.
    #   Can be used to get at info like "what is the value type stored at this attribute",
    #   "what are the column(s) this attribute maps to", "what tools need what columns from
    #   this attribute".
    # @param [String] attribute The Genboree attribute name. Generally a Sample AVP attribute.
    # @return [Hash] the configuration object for @attribute@.
    def attributeConfig(attribute)
      return getAvpColConf(attribute)
    end

    # Gets the list of columns which @attribute@ maps to.
    # @note The columns are actually regexps wrapped _implicitly_ with @^$@ and thus
    #   programmatic column-matching can be done. As regexps they also act as specifications
    #   for how column must be named even when repeated N times.
    # @param [String] attribute The Genboree attribute name. Generally a Sample AVP attribute.
    # @return [Array<String>] the list of columns associated with the attribute. The strings are
    #   meant to used as regexps if used programmatically.
    def columnsForAttribute(attribute)
      retVal = nil
      avpConf = getAvpColConf(attribute)
      if(avpConf)
        retVal = avpConf["columnInfo"].keys
      end
      return retVal
    end

    # Gets the column configs [only] {Hash} for a given Genboree attribute. i.e. the structured
    #   data in the "columnInfo" property from the configuration JSON file. You may just want
    #   to use {#avpConfig} directly, since it has this info plus the "type" property.
    # @param [String] attribute The Genboree attribute name. Generally a Sample AVP attribute.
    # @return [Hash] the column configuration Hash for @attribute@.
    def columnConfigsForAttribute(attribute)
      retVal = nil
      avpConf = getAvpColConf(attribute)
      if(avpConf)
        retVal = avpConf["columnInfo"]
      end
      return retVal
    end

    # Given a column--as either a straight string from a metadata file or as the regexp string used
    #   in the config file [doesn't matter]--what is the Genboree attribute for it?
    # @param [String] column The column name to get the attribute for.
    # @return [String] the attribute associated with the column.
    def attributeForColumn(column)
      retVal = nil
      column = column.strip
      avpColConfs = getAvpColConfs()
      avpColConfs.each_key { |attribute|
        avpConf = avpColConfs[attribute]
        avpConf["columnInfo"].each_key { |colPattern|
          if(column == colPattern or column =~ /^#{colPattern}$/)
            retVal = attribute
            break
          end
        }
        break if(retVal)
      }
      return retVal
    end

    # Get the complete map of attributes to column(s).
    # @return [Hash{String=>Array}] the map of attribute => column(s)
    def attribute2columnsMap()
      retVal = Hash.new { |hh,kk| hh[kk] = [] }
      avpColConfs = getAvpColConfs()
      avpColConfs.each_key { |attribute|
        avpConf = avpColConfs[attribute]
        avpConf["columnInfo"].each_key { |colPattern|
          retVal[attribute] << colPattern
        }
      }
      return retVal
    end

    # Get a complete map of column regexp Strings to the attribute, and the value type
    #   stored in that attribute (i.e. Hash of hashes).
    # @return [Hash{String=>Hash{String=>String}}] the map of column regexp string ->
    #   attribute -> value type.
    def column2attributeMap()
      retVal = Hash.new { |hh, kk| hh[kk] = {} }
      avpColConfs = getAvpColConfs()
      avpColConfs.each_key { |attribute|
        avpConf = avpColConfs[attribute]
        avpConf["columnInfo"].each_key { |colPattern|
          retVal[colPattern][attribute] = avpConf["type"]
        }
      }
      return retVal
    end

    # ------------------------------------------------------------------
    # HELPER METHODS
    # - mainly for internal use but public if needed outside this class as well
    # ------------------------------------------------------------------

    # @return [Hash{String=>Hash}] containing all the known avp-column configurations.
    def getAvpColConfs()
      # Get json object from global cache
      return JsonFileCache.getJsonObject(:wgsMicrobiomeAvpColConf, @avpColConfFile)
    end

    # @see {#avpConfig}
    def getAvpColConf(attribute)
      avpColConfs = getAvpColConfs()
      # Get format specific conf
      avpColConf = avpColConfs[attribute]
      raise "ERROR: unknown WGS Microbiome related attribute #{attribute.inspect}, cannot get configuration object (or possibly a bad config file?)." unless(avpColConf)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Config for #{attribute.inspect}:\n    #{avpColConf.inspect}") if(@verbose)
      return avpColConf
    end
  end # class AvpColInfo
end ; end ; end ; end # module BRL ; module Genboree ; module Helpers ; module WgsMicrobiome
