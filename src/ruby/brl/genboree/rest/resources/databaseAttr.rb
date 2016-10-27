#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/abstract/resources/database'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/analysisEntity'
require 'brl/genboree/abstract/resources/analysis'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # DatabaseAttributes - exposes information about the specific attributes
  # of a database including the AVP pair information.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::TextEntity
  # * BRL::Genboree::REST::Data::AnalysisEntity
  class DatabaseAttributes < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::DatabaseModule
    # INTERFACE: Map of what http methods this resource supports
    #   ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false).
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    # Labels, etc
    RSRC_STRS = { :type => 'grp', :label => 'database', :capital => 'Database', :pluralType => 'databases', :pluralLabel => 'databases', :pluralCap => 'Databases' }
    # Standard (mainly table-column) attrs
    STD_ATTRS = { 'name' => true, 'description' => true, 'species' => true, 'version' => true, 'public' => true }
    # Map of special attrs to table columns for simple special values (no FK, no value processing, just special map)
    SPECIAL_ATTR_MAP = { 'name' => 'refseqName', 'species' => 'refseq_species', 'version' => 'refseq_version' }
    RSRC_TYPE = 'databaseAttrs'

    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1]).strip
        @databaseName = @dbName = @entityName = Rack::Utils.unescape(@uriMatchData[2]).strip
        @attrName = Rack::Utils.unescape(@uriMatchData[3]).strip
        @aspect = (@uriMatchData[4] ? Rack::Utils.unescape(@uriMatchData[4]).strip : 'value') # currently the pattern nor code support any other attribute aspects other than value
        initStatus = initGroupAndDatabase()
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
      # variables exposed from call to initDatabaseAndDatabase() Helper
      @databaseName = @dbName = @refSeqId = @databaseDesc = @databaseAccessStr = @refseqRow = @refSeqId = nil
      # remove variables created by this class
      @attrName = @entityName = @dbName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] The +Regexp+ for this resource.
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/attribute/{attr} or /REST/v1/grp/{grp}/attribute/{attr}/value URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/attribute/([^/\?]+)(?:/([^/\?]+))?$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 8
    end

    # ATTR INTERFACE: Calls appropriate row-select-by @entityName method of dbu
    def selectEntityByName(entityName, groupName=nil)
      groupName = @groupName if(groupName.nil?)
      return @dbu.selectRefseqByNameAndGroupName(entityName, groupName)
    end

    # ATTR INTERFACE: Calls appropriate row-select by attribute name to get attr name row
    def selectAttrNameByName(attrName)
      return @dbu.selectDatabaseAttrNameByName(attrName)
    end

    # ATTR INTERFACE: Deal with getting special attribute value (if any) (used by commonAttrGet())
    def getSpecialAttrValue(row)
      retVal = nil
      # For EXAMPLE, maybe some speciall attribute contains the name for another entity and you want to get that entity's name.
      specialTableCol = SPECIAL_ATTR_MAP[@attrName]
      if(specialTableCol and row[specialTableCol])
        retVal = row[specialTableCol]
      elsif(@attrName == 'public' and row['public'])
        retVal = (row['public'] == 0)
      end
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
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "entityId = #{entityId.inspect} ; attrValMap = #{attrValMap.inspect}")
      return @dbu.updateDatabaseExposedFieldsById(entityId, attrValMap['name'], attrValMap['species'], attrValMap['version'], attrValMap['description'], attrValMap['public'])
    end

    # ATTR INTERFACE: Calls appropriate row-select-by @entityName method of dbu
    def deleteEntity2AttributeById(entityId, attrId)
      return @dbu.deleteDatabase2AttributesByDatabaseIdAndAttrNameId(entityId, attrId)
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      return commonCoreAttrGet(PERMISSIONS_ALL_READ_ONLY, 'refSeqId')
    end

    # Process a PUT operation on this resource.
    # [+returns+] Rack::Response instance
    def put()
      return commonCoreAttrPut(PERMISSIONS_RW_GET_ONLY, 'refSeqId')
    end

    # Process a DELETE operation on this resource.  This can only be
    # used on attributes that are AVP attributes.
    # [+returns+] Rack::Response instance
    def delete()
      return commonCoreAttrDelete(PERMISSIONS_RW_GET_ONLY, 'refSeqId')
    end
  end # class DatabaseAttributes
end ; end ; end # module BRL ; module REST ; module Resources
