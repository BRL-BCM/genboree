#!/usr/bin/env ruby
require 'brl/genboree/abstract/resources/group'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # GroupAttributes - exposes information about the specific attributes
  # of a group including the AVP pair information.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::TextEntity
  # * BRL::Genboree::REST::Data::GroupEntity
  class GroupAttribute < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::GroupModule
    # INTERFACE: Map of what http methods this resource supports
    #   ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false).
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    # Labels, etc
    RSRC_STRS = { :type => 'grp', :label => 'group', :capital => 'Group', :pluralType => 'groups', :pluralLabel => 'groups', :pluralCap => 'Groups' }
    # Standard (mainly table-column) attrs
    STD_ATTRS = { 'name' => true, 'description' => true }
    # Map of special attrs to table columns for simple special values (no FK, no value processing, just special map)
    SPECIAL_ATTR_MAP = { 'name' => 'groupName' }

    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = @entityName = Rack::Utils.unescape(@uriMatchData[1]).strip
        @attrName = Rack::Utils.unescape(@uriMatchData[2]).strip
        @aspect = (@uriMatchData[3] ? Rack::Utils.unescape(@uriMatchData[3]).strip : 'value') # currently the pattern nor code support any other attribute aspects other than value
        initStatus = initGroup()
        initStatus = initCoreAttrOperation(initStatus)
      end
      return initStatus
    end

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      # variables exposed from call to initGroupAndDatabase() Helper
      @databaseName = @groupName = @groupId = @groupDesc = @groupAccessStr = @refseqRow = @refSeqId = nil
      # remove variables created by this class
      @attrName = @entityName = @dbName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] The +Regexp+ for this resource.
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/attribute/{attr} or /REST/v1/grp/{grp}/attribute/{attr}/value URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/attribute/([^/\?]+)(?:/([^/\?]+))?$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 8
    end

    # ATTR INTERFACE: Calls appropriate row-select-by @entityName method of dbu
    def selectEntityByName(entityName)
      return @dbu.selectGroupByName(entityName)
    end

    # ATTR INTERFACE: Calls appropriate row-select by attribute name to get attr name row
    def selectAttrNameByName(attrName)
      return @dbu.selectGroupAttrNameByName(attrName)
    end

    # ATTR INTERFACE: Deal with getting special attribute value (if any) (used by commonAttrGet())
    def getSpecialAttrValue(row)
      retVal = nil
      # For EXAMPLE, maybe some speciall attribute contains the name for another entity and you want to get that entity's name.
      specialTableCol = SPECIAL_ATTR_MAP[@attrName]
      if(specialTableCol and row[specialTableCol])
        retVal = row[specialTableCol]
      end
      # else, other expamples might be specially internal attributes that need processing in special ways.
      return retVal
    end

    # ATTR INTERFACE: set up Hash for correct values of STD_ATTRS (using current + payload as appropriate)
    # - if special/internal attributes are in the STD_ATTRS array, this method can be implemented to look
    #   for those and do the right thing. See analysisAttrs.rb for example...although it seems very very WRONG
    #   (using STATE_ATTRS as attributes names (keys) ?? no, those are values...)
    def updatedSpecialAttrValMap(entityRow, entityId, payloadEntity)
      attrValMap = {}
      entityText = payloadEntity.text
      # Set current values from row, update whichever is @attrName from payload
      STD_ATTRS.each_key { |attr|
        if(@attrName != attr) # Not one being changed, use Current Value:
          specialTableCol = SPECIAL_ATTR_MAP[attr]
          if(specialTableCol and entityRow[specialTableCol])
            val = entityRow[specialTableCol]
          else # default (by column name)
            val = entityRow[attr]
          end
          attrValMap[attr] = val
        else # One being changed, use New Value:
          attrValMap[attr] = entityText
        end
      }
      return attrValMap
    end

    # ATTR INTERFACE: use attrValMap correctly to update entity's std_attrs
    def updateEntityStdAttrs(entityId, attrValMap)
      return @dbu.updateGroupById(entityId, attrValMap['name'], attrValMap['description'], 0)
    end

    # ATTR INTERFACE: Calls appropriate row-select-by @entityName method of dbu
    def deleteEntity2AttributeById(entityId, attrId)
      return @dbu.deleteGroup2AttributesByGroupIdAndAttrNameId(entityId, attrId)
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      return commonCoreAttrGet(PERMISSIONS_ALL_READ_ONLY, 'groupId')
    end

    # Process a PUT operation on this resource.
    # [+returns+] Rack::Response instance
    def put()
      return commonCoreAttrPut(PERMISSIONS_RW_GET_ONLY, 'groupId')
    end

    # Process a DELETE operation on this resource.  This can only be
    # used on attributes that are AVP attributes.
    # [+returns+] Rack::Response instance
    def delete()
      return commonCoreAttrDelete(PERMISSIONS_RW_GET_ONLY, 'groupId')
    end
  end # class GroupAttributes
end ; end ; end # module BRL ; module REST ; module Resources
