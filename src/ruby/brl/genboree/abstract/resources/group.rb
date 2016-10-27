#!/usr/bin/env ruby

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

#--
module BRL ; module Genboree ; module Abstract ; module Resources
#++

  # GroupModule - This Module implements behaviors related user Groups and is mixed into certain other classes
  module GroupModule
    # This method fetches all key-value pairs from the associated +group+
    # AVP tables.  Group is specified by group id.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+group+] DB id of the group to query AVPs for.
    # [+returns+] A +Hash+ of the AVP pairs associated with this group.
    def getAvpHash(dbu, groupId)
      retVal = {}
      group2attrRows = dbu.selectGroup2AttributesByGroupId(groupId)
      unless(group2attrRows.nil? or group2attrRows.empty?)
        group2attrRows.each { |row|
          keyRows = dbu.selectGroupAttrNameById(row['groupAttrName_id'])
          key = keyRows.first['name'] unless (keyRows.nil? or keyRows.empty?)
          valueRows = dbu.selectGroupAttrValueById(row['groupAttrValue_id'])
          value = valueRows.first['value'] unless (valueRows.nil? or valueRows.empty?)
          retVal[key] = value
        }
      end
      return retVal
    end

    # This method completely updates all of the associated AVP pairs for
    # the specified +group+.  This method examines existing AVPs and changes
    # values as appropriate, but also looks for any pairs that exist in the
    # DB but not the new +Hash+, and removes those relationships, making it
    # possible to delete AVP pairs by removing them from the +Hash+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+groupId+] DB Id of the +group+ for which to update the AVPs.
    # [+newHash+] A +Hash+ representing all of the AVP pairs to associate with
    #   the specified +group+.  This includes existing AVP pairs that are not
    #   to be changed.  Only updated, new, or missing AVP pairs will be handled.
    # [+returns+] +true+ when everything has succeeded, +false+ when any errors
    #   have occurred (check standard error for details).
    def updateAvpHash(dbu, groupId, newHash)
      retVal = true

      newHash = {} if(newHash.nil?)
      begin
        oldHash = getAvpHash(dbu, groupId)
        if(oldHash.nil? or oldHash.empty?)
          # AVP hash didn't exist before, insert all keys and values
          newHash.each { |attrName,attrValue|
            insertAvp(dbu, groupId, attrName, attrValue)
          }
        else
          # AVP hash exists, check all key/value pairs for changes
          oldHash.each_key { |oldKey|
            oldVal = oldHash[oldKey]
            if(newHash.include?(oldKey))
              if(newHash[oldKey] != oldVal)
                rowsUpdated = insertAvp(dbu, groupId, oldKey, newHash[oldKey], :update)
              end
              newHash.delete(oldKey)
            else
              keyRow = dbu.selectGroupAttrNameByName(oldKey)
              key = keyRow.first
              rowsDeleted = dbu.deleteGroup2AttributesByGroupIdAndAttrNameId(groupId, key['id'])
            end
          }
          # All remaining values in newHash will be insertions
          newHash.each { |newKey, newVal|
            insertAvp(dbu, groupId, newKey, newVal)
          }
        end
      rescue => e
        dbu.logDbError("ERROR: Unknown DB error occurred during BRL::Abstract::Resources::Group.updateAvpHash()", e)
        retVal = false
      end
      return retVal
    end

    # This method inserts a new AVP pairing into the +group+ associated AVP tables.
    # You can also update an existing relationship between a +group+ and a
    # +groupAttrName+ by setting the +mode+ parameter to the symbol +:update+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+groupId+] DB Id of the +group+ for which to associate with this AVP.
    # [+attrName+] A +String+ of the attribute name to use.
    # [+attrValue+] A +String+ of the attibute value to use.
    # [+mode+] A symbol of either +:insert+ or +:update+ to set the mode to use.
    # [+returns+] Number of rows affected in the DB.  +1+ when successful, +0+ when not.
    def insertAvp(dbu, groupId, attrName, attrValue, mode=:insert)
      retVal = nil
      # Test for uniqueness of attribute to be inserted
      attrNameExists = dbu.selectGroupAttrNameByName(attrName)
      nameId = valId = nil
      if(attrNameExists.nil? or attrNameExists.empty?)
        nameInsert = dbu.insertGroupAttrName(attrName)
        nameId = dbu.getLastInsertId(:mainDB)
      else
        nameId = attrNameExists.first['id']
      end

      # Test for uniqueness of value to be inserted
      attrValExists = dbu.selectGroupAttrValueByValue(attrValue)
      if(attrValExists.nil? or attrValExists.empty?)
        attrValInsert = dbu.insertGroupAttrValue(attrValue)
        valId = dbu.getLastInsertId(:mainDB)
      else
        valId = attrValExists.first['id']
      end

      # Create the AVP link using the group2attribute table
      if(groupId and nameId and valId)
        if(mode == :update)
          retval = dbu.updateGroup2AttributeForGroupAndAttrName(groupId, nameId, valId)
        else
          retVal = dbu.insertGroup2Attribute(groupId, nameId, valId)
        end
      end

      return retVal
    end
  end # module GroupModule

  class Group
    ENTITY_TYPE = 'groups'
    # DbUtil instance,
    attr_accessor :dbu
    # GenboreeConfig instance
    attr_accessor :genbConf
    # groupId of the group
    attr_accessor :groupId
    # groupName of the group
    attr_accessor :groupName
    # Generic field for the name (should be same as groupName)
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
    def initialize(dbu, groupId, userId, extraConfig={}, connect=true)
      @dbu, @groupId, @userId, @extraConfig, @connect = dbu, groupId, userId, extraConfig, connect
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
        @entityRow = @dbu.selectGroupById(@groupId)
        if(@entityRow and !@entityRow.empty?)
          @entityName = @groupName = @entityRow.first['groupName']
        else
          raise "ERROR: could not find group record corresponding to id #{@groupId.inspect}"
        end
      end
      # Get the attribute info for this group.
      attributesInfoRecs = @dbu.selectCoreEntityAttributesInfo(self.class::ENTITY_TYPE, [@groupName], attributeList, "Error in #{File.basename(__FILE__)}##{__method__}: Could not query user database for entity metadata.", 'groupName', 'groupId')
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
    # This method checks whether a group name is valid for insertion into the database
    #
    # [+dbu+] Instance of DbUtil, ready to do DB work.
    # [+groupName+] Name of a Genboree user group.
    # [+returns+] Error code, as a +Symbol+; :OK indicates success.
    def self.validateGroupName(dbu, groupName)
      retVal = :OK
      if(groupName.empty?)
        retVal = :GRP_INVALID_FORMAT
      elsif(self.groupNameExists(dbu, groupName))
        retVal = :GRP_ALREADY_EXISTS
      end
      return retVal
    end

    # This method returns true/false depending on whether a group name already exists within Genboree.
    #
    # [+dbu+] Instance of DbUtil, ready to do DB work.
    # [+groupName+] Name of a Genboree user group.
    # [+returns+] +true+ if the group exists already
    def self.groupNameExists(dbu, groupName)
      retVal = false
      groupRow = dbu.selectGroupByName(groupName)
      unless(groupRow.empty?)
        retVal = true
      end
      return retVal
    end

    # This method creates a group and adds the specified user as the administrator.
    # NOTE: If name isn't unique a fatal Db error will be thrown.
    #
    # [+dbu+] Instance of DbUtil, ready to do DB work.
    # [+groupName+] Name of a Genboree user group.
    # [+userId+] Id of the user who will be [the first] owner of the group.
    # [+description+] [optional; default=""] The group description.
    # [+returns+] GroupId of the record that was just created.
    def self.createGroupForUser(dbu, groupName, userId, description='')
      groupId = 0
      rowsInserted = dbu.insertGroup(groupName, description)
      if(rowsInserted == 1)
        groupId = dbu.genbDbh.func(:insert_id)
      end
      if(groupId > 0)
        # Add the user to the new group as administrator
        rowsInserted = dbu.insertUserIntoGroupById(userId, groupId, 'o')
      end
      unless(rowsInserted > 0 and groupId > 0)
        raise "There has been an error in createGroupForUser(dbu, #{groupName}, #{userId}"
      end
      return groupId
    end

    def self.hasPublicDatabases(dbu, groupId)
      groupRow = dbu.selectGroupByName(groupName)
      unless(groupRow.empty?)
        retVal = true
      end
      groups = dbu.getGroupNamesByUserId(userId)
    end

    def self.getGroupListForUser(dbu, userId, includePublic=false, requireUnlockedPublicDBs=false)
      groups = dbu.getGroupNamesByUserId(userId)
      if(includePublic)
        publicGroups = dbu.getPublicGroups(requireUnlockedPublicDBs)
        # Merge the 2 lists
        groups = (groups + publicGroups).uniq_by { |row| row['groupId'] }
      end
      return groups
    end
  end
end ; end ; end ; end
