#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'

#--
# Pre-declare namespace
module BRL ; module Genboree ; module Abstract ; module Resources
end ; end ; end ; end
# Because of misleading name ("Abstract" classes are something specific in OOP and Java,
# this has lead to confusion amongst newbies), I think this shorter Constant should
# be made available by all Abstract::Resources classes. Of course, we should only set
# the constant once, so we use const_defined?()...
Abstraction = BRL::Genboree::Abstract::Resources unless(Module.const_defined?(:Abstraction))
#++

module BRL ; module Genboree ; module Abstract ; module Resources

  # This class provides methods for managing tracks
  class BioSamples
    ENTITY_TYPE = 'bioSamples'

    # DbUtil instance,
    attr_accessor :dbu
    # GenboreeConfig instance
    attr_accessor :genbConf
    # refSeqId of the database that the tracks are in
    attr_accessor :refSeqId
    # User id (used when getting display/default settings)
    attr_accessor :userId
    # Hash for storing only attribute names and values
    attr_accessor :attributesHash
    # Array of entity attributes names (Strings) that we care about (default is nil == no filter i.e. ALL attributes)
    attr_accessor :attributeList

    # Note: dbu must already be set and connected to user data database.
    def initialize(dbu, refSeqId, userId, extraConfig={}, connect=true)
      @dbu, @refSeqId, @extraConfig, @userId, @connect = dbu, refSeqId, extraConfig, userId, connect
      @genbConf = BRL::Genboree::GenboreeConfig.load()
      @attributesHash = @attributeList = nil
    end

    def updateAttributes(attributeList=@attributeList, mapType='full', aspect='map')
      initAttributesHash()
      updateAttributesHash(attributeList, mapType, aspect)
    end

    def initAttributesHash()
      @attributesHash = Hash.new { |hh, kk|
        hh[kk] = {}
      }
    end

    # Requires @dbu to be connected to the right db
    # [+idList+] An array of [bio]SampleIds
    # [+attributeList+] - [optional; default=nil] Only get info for attributes in this array (should be array of attribute name Strings)
    # [+mapType+] type of map requested [Default: Full]
    # [+aspect+] type of aspect requested [Default: map]
    # [+returns] nil
    def updateAttributesHash(attributeList=@attributeList, mapType='full', aspect='map')
      # Make the query without any user
      if(aspect == 'map')
        if(mapType == 'full')
          attributesInfoRecs = @dbu.selectEntityAttributesInfo(:userDB, ENTITY_TYPE, "Error in #{File.basename(__FILE__)}##{__method__}: Could not query user database for entity metadata.", attributeList)
          attributesInfoRecs.each { |rec|
            @attributesHash[rec['entityName']][rec['attributeName']] = rec['attributeValue']
          }
        elsif(mapType == 'attrNames')
          attributesInfoRecs = @dbu.selectEntityAttributesNameMapInfo(:userDB, ENTITY_TYPE, "Error in #{File.basename(__FILE__)}##{__method__}: Could not query user database for entity metadata.", attributeList)
          attributesInfoRecs.each { |rec|
            @attributesHash[rec['entityName']][rec['attributeName']] = nil
          }
        elsif(mapType == 'attrValues')
          attributesInfoRecs = @dbu.selectEntityAttributesValueMapInfo(:userDB, ENTITY_TYPE, "Error in #{File.basename(__FILE__)}##{__method__}: Could not query user database for entity metadata.")
          attributesInfoRecs.each { |rec|
            @attributesHash[rec['entityName']][rec['attributeValue']] = nil
          }
        else
          raise "Unknown mapType: #{mapType.inspect}"
        end
      elsif(aspect == 'names')
        attributesInfoRecs = @dbu.selectEntityAttributes(:userDB, ENTITY_TYPE, "Error in #{File.basename(__FILE__)}##{__method__}: Could not query user database for entity metadata.")
        attributesInfoRecs.each { |rec|
          @attributesHash[rec['attributeName']][nil] = nil
        }
      elsif(aspect == 'values')
        attributesInfoRecs = @dbu.selectEntityAttributeValues(:userDB, ENTITY_TYPE, "Error in #{File.basename(__FILE__)}##{__method__}: Could not query user database for entity metadata.")
        attributesInfoRecs.each { |rec|
          @attributesHash[rec['attributeValue']][nil] = nil
        }
      else
        raise "Unknown aspect: #{aspect.inspect}"
      end
      return true
    end
  end # class BioSamples
end ; end ; end ; end # module BRL ; module Genboree ; module Abstract ; module Resources
