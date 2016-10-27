#!/usr/bin/env ruby

require 'brl/genboree/genboreeUtil'

require 'brl/genboree/dbUtil'

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

  # DatabaseModule - This Module implements behaviors related user Databases and is mixed into certain other classes
  module DatabaseModule
    # This method fetches all key-value pairs from the associated +database+
    # AVP tables.  Database is specified by database id.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+database+] DB id of the database to query AVPs for.
    # [+returns+] A +Hash+ of the AVP pairs associated with this database.
    def getAvpHash(dbu, databaseId)
      retVal = {}
      database2attrRows = dbu.selectDatabase2AttributesByDatabaseId(databaseId)
      unless(database2attrRows.nil? or database2attrRows.empty?)
        database2attrRows.each { |row|
          keyRows = dbu.selectDatabaseAttrNameById(row['databaseAttrName_id'])
          key = keyRows.first['name'] unless (keyRows.nil? or keyRows.empty?)
          valueRows = dbu.selectDatabaseAttrValueById(row['databaseAttrValue_id'])
          value = valueRows.first['value'] unless (valueRows.nil? or valueRows.empty?)
          retVal[key] = value
        }
      end
      return retVal
    end

    # This method completely updates all of the associated AVP pairs for
    # the specified +database+.  This method examines existing AVPs and changes
    # values as appropriate, but also looks for any pairs that exist in the
    # DB but not the new +Hash+, and removes those relationships, making it
    # possible to delete AVP pairs by removing them from the +Hash+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+databaseId+] DB Id of the +database+ for which to update the AVPs.
    # [+newHash+] A +Hash+ representing all of the AVP pairs to associate with
    #   the specified +database+.  This includes existing AVP pairs that are not
    #   to be changed.  Only updated, new, or missing AVP pairs will be handled.
    # [+returns+] +true+ when everything has succeeded, +false+ when any errors
    #   have occurred (check standard error for details).
    def updateAvpHash(dbu, databaseId, newHash)
      retVal = true

      newHash = {} if(newHash.nil?)
      begin
        oldHash = getAvpHash(dbu, databaseId)
        if(oldHash.nil? or oldHash.empty?)
          # AVP hash didn't exist before, insert all keys and values
          newHash.each { |attrName,attrValue|
            insertAvp(dbu, databaseId, attrName, attrValue)
          }
        else
          # AVP hash exists, check all key/value pairs for changes
          oldHash.each_key { |oldKey|
            oldVal = oldHash[oldKey]
            if(newHash.include?(oldKey))
              if(newHash[oldKey] != oldVal)
                rowsUpdated = insertAvp(dbu, databaseId, oldKey, newHash[oldKey], :update)
              end
              newHash.delete(oldKey)
            else
              keyRow = dbu.selectDatabaseAttrNameByName(oldKey)
              key = keyRow.first
              rowsDeleted = dbu.deleteDatabase2AttributesByDatabaseIdAndAttrNameId(databaseId, key['id'])
            end
          }
          # All remaining values in newHash will be insertions
          newHash.each { |newKey, newVal|
            insertAvp(dbu, databaseId, newKey, newVal)
          }
        end
      rescue => e
        dbu.logDbError("ERROR: Unknown DB error occurred during BRL::Abstract::Resources::Database.updateAvpHash()", e)
        retVal = false
      end
      return retVal
    end

    # This method inserts a new AVP pairing into the +database+ associated AVP tables.
    # You can also update an existing relationship between a +database+ and a
    # +databaseAttrName+ by setting the +mode+ parameter to the symbol +:update+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+databaseId+] DB Id of the +database+ for which to associate with this AVP.
    # [+attrName+] A +String+ of the attribute name to use.
    # [+attrValue+] A +String+ of the attibute value to use.
    # [+mode+] A symbol of either +:insert+ or +:update+ to set the mode to use.
    # [+returns+] Number of rows affected in the DB.  +1+ when successful, +0+ when not.
    def insertAvp(dbu, databaseId, attrName, attrValue, mode=:insert)
      retVal = nil
      # Test for uniqueness of attribute to be inserted
      attrNameExists = dbu.selectDatabaseAttrNameByName(attrName)
      nameId = valId = nil
      if(attrNameExists.nil? or attrNameExists.empty?)
        nameInsert = dbu.insertDatabaseAttrName(attrName)
        nameId = dbu.getLastInsertId(:mainDB)
      else
        nameId = attrNameExists.first['id']
      end

      # Test for uniqueness of value to be inserted
      attrValExists = dbu.selectDatabaseAttrValueByValue(attrValue)
      if(attrValExists.nil? or attrValExists.empty?)
        attrValInsert = dbu.insertDatabaseAttrValue(attrValue)
        valId = dbu.getLastInsertId(:mainDB)
      else
        valId = attrValExists.first['id']
      end

      # Create the AVP link using the database2attribute table
      if(databaseId and nameId and valId)
        if(mode == :update)
          retval = dbu.updateDatabase2AttributeForDatabaseAndAttrName(databaseId, nameId, valId)
        else
          retVal = dbu.insertDatabase2Attribute(databaseId, nameId, valId)
        end
      end

      return retVal
    end
  end # module DatabaseModule

  # Abstraction of a Genboree Database (refseq). Implements some fundamental
  # behaviors concerning databases.
  #
  class Database
    ENTITY_TYPE = 'databases'
# DbUtil instance,
    attr_accessor :dbu
    # GenboreeConfig instance
    attr_accessor :genbConf
    # refSeqId of the database
    attr_accessor :refSeqId
    # database name (refSeqName) of the database
    attr_accessor :databaseName
    # Generic field for the name (should be same as databaseName)
    attr_accessor :entityName
    # User id (used when getting display/default settings) - user on behalf of whom we're doing things
    attr_accessor :userId
    # Hash for storing only attribute names and values
    attr_accessor :attributesHash
    # Array of entity attributes names (Strings) that we care about (default is nil == no filter i.e. ALL attributes)
    attr_accessor :attributeList
    # Corresponding row from MySQL table, if applicable
    attr_accessor :entityRow

    # Note: dbu must already be set and connected to user data database.
    def initialize(dbu, refSeqId, userId, extraConfig={}, connect=true)
      @dbu, @refSeqId, @userId, @extraConfig, @connect = dbu, refSeqId, userId, extraConfig, connect
      @genbConf = BRL::Genboree::GenboreeConfig.load()
      @attributesHash = @attributeList = @entityRow = nil
    end

    def updateAttributes(attributeList=@attributeList, mapType='full', aspect='map')
      initAttributesHash()
      updateAttributesHash(attributeList, mapType, aspect)
    end

    def initAttributesHash()
      @attributesHash = Hash.new { |hh, kk| hh[kk] = {} }
    end

    # Requires @dbu to be connected to the right db
    # [+idList+] An array of [bio]SampleIds
    # [+attributeList+] - [optional; default=nil] Only get info for attributes in this array (should be array of attribute name Strings)
    # [+mapType+] type of map requested [Default: Full]
    # [+aspect+] type of aspect requested [Default: map]
    # [+returns] nil
    def updateAttributesHash(attributeList=@attributeList, mapType='full', aspect='map')
      # Get the @entityRow, if not gotten yet
      if(@entityRow.nil? or @entityRow.empty?)
        @entityRow = @dbu.selectDatabaseById(@refSeqId)
        if(@entityRow and !@entityRow.empty?)
          @entityName = @databaseName = @entityRow.first['refseqName']
        else
          raise "ERROR: could not find database record corresponding to id #{@refSeqId.inspect}"
        end
      end
      # Get the attribute info for this group.
      attributesInfoRecs = @dbu.selectCoreEntityAttributesInfo(self.class::ENTITY_TYPE, [@databaseName], attributeList, "Error in #{File.basename(__FILE__)}##{__method__}: Could not query user database for entity metadata.", 'refseqName', 'refSeqId')
      if(aspect == 'map')
        attributesInfoRecs.each { |rec|
          if(mapType == 'full')
            @attributesHash[rec['entityName']][rec['attributeName']] = rec['attributeValue']
          elsif(mapType == 'attrNames')
            @attributesHash[rec['entityName']][rec['attributeName']] = nil
          elsif(mapType == 'attrValues')
             @attributesHash[rec['entityName']][rec['attributeValue']] = nil
          else
            raise "Unknown mapType: #{mapType.inspect}"
          end
        }
      elsif(aspect == 'names')
        attributesInfoRecs.each { |rec|
          @attributesHash[rec['attributeName']][nil] = nil
        }
      elsif(aspect == 'values')
        attributesInfoRecs.each { |rec|
          @attributesHash[rec['attributeValue']][nil] = nil
        }
      else
        raise "Unknown aspect: #{aspect.inspect}"
      end
      return true
    end

    # ------------------------------------------------------------------
    # CLASS METHODS
    # ------------------------------------------------------------------
    def self.clearBrowserCacheById(dbu, refSeqId)
      databaseRows = dbu.selectRefseqById(refSeqId)
      if(!databaseRows.nil? and !databaseRows.empty?)
        databaseName = databaseRows.first['databaseName']
        self.clearBrowserCacheByDbName(dbu, databaseName)
      end
    end

    def self.clearBrowserCacheByDbName(dbu, databaseName)
      # Delete the files in the cache dir
      self.deleteBrowserCacheFiles(databaseName)
      # truncate cache table
      dbu.truncateImageCache()
    end

    def self.deleteBrowserCacheFiles(databaseName)
      path = self.getCacheDirPath(databaseName)
      if(File.exists?(path))
        FileUtils.cd(path)
        Dir.new(path).each { |fileName|
          File.delete(fileName) if(!File.directory?(fileName))
        }
      end
    end

    def self.getCacheDirPath(databaseName)
      # Get path to file from the conf file
      genbConf = BRL::Genboree::GenboreeConfig.load()
      basePath = genbConf.cacheDirBasePath + '/'
      cacheDir = genbConf.cacheDir + '/'
      path = basePath + cacheDir + databaseName
      return path
    end

  end

end ; end ; end ; end # module BRL ; module Genboree ; module Abstract ; module Resources
